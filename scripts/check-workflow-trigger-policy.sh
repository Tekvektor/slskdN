#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

release_workflows=(
  "$repo_root/.github/workflows/build-on-tag.yml"
  "$repo_root/.github/workflows/ci.yml"
)

for workflow in "${release_workflows[@]}"; do
  rel="${workflow#$repo_root/}"
  if [ ! -f "$workflow" ]; then
    printf '%s is missing\n' "$rel" >&2
    failed=1
    continue
  fi
done

if ! rg -q "build-main-\*" "$repo_root/.github/workflows/build-on-tag.yml"; then
  printf '.github/workflows/build-on-tag.yml must trigger on build-main-* tags\n' >&2
  failed=1
fi

if ! rg -q "build-dev-\*" "$repo_root/.github/workflows/build-on-tag.yml"; then
  printf '.github/workflows/build-on-tag.yml must trigger on build-dev-* tags\n' >&2
  failed=1
fi

if ! rg -q "build-dev-\*" "$repo_root/docs/build.md"; then
  printf 'docs/build.md must document build-dev-* tag builds\n' >&2
  failed=1
fi

if rg -n 'branches:\s*\[.*(master|main).*\]' "$repo_root/.github/workflows/build-on-tag.yml" >&2; then
  printf 'build-on-tag.yml must not run release builds on branch pushes\n' >&2
  failed=1
fi

if ! rg -q 'build-dev-\*|build-main-\*|[0-9]\{8,10\}-slskdn' "$repo_root/.github/workflows/ci.yml"; then
  printf '.github/workflows/ci.yml must keep release builds tag-addressable\n' >&2
  failed=1
fi

if rg -n '\[0-9\]\+\.\[0-9\]\+\.\[0-9\]\+' "$repo_root/.github/workflows/ci.yml" "$repo_root/.github/workflows/ci-enhancements.yml" >&2; then
  printf 'GitHub tag filters are globs; do not use regex + quantifiers in release tag patterns\n' >&2
  failed=1
fi

while IFS= read -r workflow; do
  if rg -q '^\s*schedule:' "$workflow" && rg -q 'git (tag|push origin .*\$?NEW_VERSION|push origin .*\$?\{.*version.*\})' "$workflow"; then
    printf '%s must not create or push release tags from a scheduled workflow\n' "${workflow#$repo_root/}" >&2
    failed=1
  fi
done < <(find "$repo_root/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)

ci_workflow="$repo_root/.github/workflows/ci.yml"
if ! rg -Fq "github.event_name == 'pull_request' || (github.event_name == 'workflow_dispatch' && (github.ref != 'refs/heads/main' || inputs.runner == 'github-hosted'))" "$ci_workflow" ||
  ! rg -Fq "&& 'ubuntu-latest' || vars.PREFER_SELF_HOSTED != 'false' && fromJSON" "$ci_workflow"; then
  printf '.github/workflows/ci.yml must force pull requests and non-main manual runs onto hosted runners\n' >&2
  failed=1
fi

if ! python3 - "$ci_workflow" <<'PYTHON'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
push = re.search(r"(?ms)^  push:\n(.*?)(?=^  [A-Za-z0-9_-]+:\n|\Z)", text)
if not push or not re.search(r"(?m)^    tags:\n", push.group(1)):
    raise SystemExit("CI must preserve its release tag triggers")
if re.search(r"(?m)^    branches(?:-ignore)?:", push.group(1)):
    raise SystemExit("CI builds must not be added to branch pushes")
PYTHON
then
  printf '.github/workflows/ci.yml must keep builds tag-triggered\n' >&2
  failed=1
fi

if ! awk '
  $0 == "  load-testing:" { in_job = 1; next }
  in_job && /^  [A-Za-z0-9_-]+:$/ { exit }
  in_job && $0 == "    runs-on: ubuntu-latest" { found = 1 }
  END { exit !found }
' "$repo_root/.github/workflows/ci-enhancements.yml"; then
  printf '.github/workflows/ci-enhancements.yml load-testing must use an isolated hosted runner\n' >&2
  failed=1
fi

for release_job in publish docker release; do
  if ! awk -v job="$release_job" '
    $0 == "  " job ":" { in_job = 1; next }
    in_job && /^  [A-Za-z0-9_-]+:$/ { exit }
    in_job && index($0, "if: startsWith(github.ref, '\''refs/tags/'\'')") > 0 { found = 1 }
    END { exit !found }
  ' "$ci_workflow"; then
    printf '.github/workflows/ci.yml job %s must stay tag-gated\n' "$release_job" >&2
    failed=1
  fi
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi

printf 'Workflow release triggers preserve the tag-only build policy.\n'
