#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

target_major="$(sed -n 's/.*<TargetFramework>net\([0-9][0-9]*\)\..*/\1/p' "$repo_root/src/slskd/slskd.csproj" | head -n1)"

if [ -z "$target_major" ]; then
  printf 'unable to read slskd target framework major version\n' >&2
  exit 1
fi

while IFS= read -r project; do
  project_path="${project#"$repo_root"/}"
  target_framework="$(sed -n 's/.*<TargetFramework>\([^<]*\)<\/TargetFramework>.*/\1/p' "$project" | head -n1)"
  if [ "$target_framework" != "net${target_major}.0" ]; then
    printf '%s targets %s; first-party projects under src/tests/tools must target net%s.0\n' \
      "$project_path" "${target_framework:-no single target framework}" "$target_major" >&2
    failed=1
  fi
done < <(find "$repo_root/src" "$repo_root/tests" "$repo_root/tools" -name '*.csproj' -print | sort)

pinned_sdk_major="$(sed -n 's/.*"version": "\([0-9][0-9]*\)\..*/\1/p' "$repo_root/global.json" | head -n1)"
if [ "$pinned_sdk_major" != "$target_major" ]; then
  printf 'global.json pins .NET %s but the application targets .NET %s\n' \
    "${pinned_sdk_major:-no SDK version}" "$target_major" >&2
  failed=1
fi

expect_literal() {
  local file="$1"
  local literal="$2"

  if ! grep -Fq -- "$literal" "$repo_root/$file"; then
    printf '%s is missing literal: %s\n' "$file" "$literal" >&2
    failed=1
  fi
}

expect_literal packaging/linux/install-from-release.sh "aspnetcore-runtime-${target_major}.0"
expect_literal packaging/proxmox-lxc/setup-inside-ct.sh "aspnetcore-runtime-${target_major}.0"
expect_literal packaging/proxmox-lxc/README.md ".NET ${target_major}"
expect_literal packaging/flatpak/io.github.slskd.slskdn.yml "Runtime/${target_major}.0."
expect_literal packaging/flatpak/io.github.slskd.slskdn.yml "dotnet-runtime-${target_major}.0."
expect_literal packaging/flatpak/FLATHUB_SUBMISSION.md ".NET ${target_major}.0 runtime"
expect_literal docs/FEATURES.md ".NET ${target_major}.0 or later"
expect_literal docs/dev/e2e-testing-guide.md ".NET ${target_major}.0 SDK"
expect_literal CONTRIBUTING.md ".NET ${target_major}.0 SDK"
workflow=".github/workflows/e2e-tests.yml"
if ! rg -q "^  DOTNET_VERSION: '${target_major}\.0\.[0-9]+'$" "$repo_root/$workflow"; then
  printf '%s must pin the application .NET %s.0 runtime version\n' "$workflow" "$target_major" >&2
  failed=1
fi
expect_literal "$workflow" 'dotnet-version: ${{ env.DOTNET_VERSION }}'

expect_dotnet_setup_temp_dir() {
  local workflow_path="$1"
  local workflow_name="${workflow_path#"$repo_root"/}"

  if ! python3 - "$workflow_path" "$workflow_name" <<'PYTHON'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
name = sys.argv[2]
blocks = re.split(r"(?m)(?=^      - )", path.read_text())
steps = [
    block
    for block in blocks
    if re.search(r"(?m)^        uses: actions/setup-dotnet@v6\s*$", block)
]
if not steps:
    print(f"{name} has no setup-dotnet steps", file=sys.stderr)
    raise SystemExit(1)

failed = False
for number, step in enumerate(steps, start=1):
    if not re.search(
        r"(?m)^          TMPDIR: \$\{\{ runner\.temp \}\}\s*$", step
    ):
        print(
            f"{name} setup-dotnet step {number} must set TMPDIR to ${{{{ runner.temp }}}}",
            file=sys.stderr,
        )
        failed = True
if failed:
    raise SystemExit(1)
print(f"{name}: all {len(steps)} setup-dotnet steps use runner.temp for TMPDIR")
PYTHON
  then
    failed=1
  fi
}

expect_dotnet_setup_temp_dir "$repo_root/.github/workflows/ci.yml"
expect_dotnet_setup_temp_dir "$repo_root/.github/workflows/ci-enhancements.yml"


if rg -n '\.NET 8\.0|\.NET 8|aspnetcore-runtime-8\.0|dotnet-runtime-8\.0|dotnet-version: .8\.0\.x.' \
  "$repo_root/packaging/flatpak" \
  "$repo_root/packaging/proxmox-lxc" \
  "$repo_root/docs/FEATURES.md" \
  "$repo_root/docs/dev/e2e-testing-guide.md" \
  "$repo_root/CONTRIBUTING.md" >&2; then
  printf 'Active package/docs runtime references must match net%s.0, not .NET 8.\n' "$target_major" >&2
  failed=1
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi

printf '.NET runtime/package matrix matches the application target framework.\n'
