#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

release_workflows=(
  "$repo_root/.github/workflows/build-on-tag.yml"
  "$repo_root/.github/workflows/ci.yml"
)

for workflow in "${release_workflows[@]}"; do
  rel="${workflow#"$repo_root"/}"
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
    printf '%s must not create or push release tags from a scheduled workflow\n' "${workflow#"$repo_root"/}" >&2
    failed=1
  fi
done < <(find "$repo_root/.github/workflows" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)

ci_workflow="$repo_root/.github/workflows/ci.yml"
ci_enhancements_workflow="$repo_root/.github/workflows/ci-enhancements.yml"
for workflow in "$ci_workflow" "$ci_enhancements_workflow"; do
  if ! rg -Fq "github.event_name == 'pull_request' ||" "$workflow" ||
    ! rg -Fq "&& 'ubuntu-latest' || vars.PREFER_SELF_HOSTED != 'false' && fromJSON" "$workflow"; then
    printf '%s must route every pull request to hosted runners while preserving explicit runner preference\n' "${workflow#"$repo_root"/}" >&2
    failed=1
  fi
done

if ! rg -Fq "github.event_name == 'workflow_dispatch' && (github.ref != 'refs/heads/main' || inputs.runner == 'github-hosted')" "$ci_workflow" ||
  ! rg -Fq "github.event_name == 'workflow_dispatch' && github.ref != 'refs/heads/main'" "$ci_enhancements_workflow"; then
  printf 'CI workflows must keep non-main manual runs on hosted runners\n' >&2
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

if ! awk '
  $0 == "      - name: Run Load Tests" { in_step = 1; next }
  in_step && /^      - name:/ { exit }
  in_step && $0 == "        env:" { has_env = 1 }
  in_step && $0 == "          BASE_URL: http://127.0.0.1:5099" { has_base_url = 1 }
  END { exit !(has_env && has_base_url) }
' "$repo_root/.github/workflows/ci-enhancements.yml"; then
  printf '.github/workflows/ci-enhancements.yml load test must receive its local BASE_URL through step environment\n' >&2
  failed=1
fi

if ! python3 - "$repo_root/.github/workflows" <<'PYTHON'
import re
import sys
from pathlib import Path

workflow_dir = Path(sys.argv[1])
texts = {path.name: path.read_text() for path in workflow_dir.glob("*.yml")}
for name, text in texts.items():
    for line_number, line in enumerate(text.splitlines(), 1):
        match = re.match(r"^\s*uses:\s*([^\s#]+)", line)
        if not match:
            continue
        action = match.group(1)
        if action.startswith("./"):
            continue
        if "@" not in action or not re.fullmatch(r"[0-9a-f]{40}", action.rsplit("@", 1)[1]):
            raise SystemExit(f"{name}:{line_number} must pin its action to a full commit SHA")

ci = texts["ci.yml"]
enhancements = texts["ci-enhancements.yml"]

for job in ("performance-regression", "dependency-scanning", "container-scanning"):
    match = re.search(rf"(?ms)^  {re.escape(job)}:\n(.*?)(?=^  [A-Za-z0-9_-]+:\n|\Z)", enhancements)
    if not match:
        raise SystemExit(f"ci-enhancements.yml is missing {job}")
    if re.search(r"(?m)^\s*continue-on-error:\s*true\s*$", match.group(1)):
        raise SystemExit(f"ci-enhancements.yml {job} must fail when its checks fail")

if "pnpm audit --prod --audit-level high || true" in enhancements:
    raise SystemExit("pnpm audit failures must not be suppressed")
if not re.search(r"uses: aquasecurity/trivy-action@[0-9a-f]{40}", enhancements):
    raise SystemExit("Trivy must be pinned to a full commit SHA")
if not re.search(r"exit-code:\s*['\"]?1['\"]?", enhancements):
    raise SystemExit("Trivy must fail on HIGH/CRITICAL findings")
PYTHON
then
  printf 'CI action pinning or security scan policy checks failed\n' >&2
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
