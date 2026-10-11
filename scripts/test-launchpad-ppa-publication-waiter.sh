#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
temporary_directory="$(mktemp -d)"
trap 'rm -rf "$temporary_directory"' EXIT

mock_bin="$temporary_directory/bin"
mkdir -p "$mock_bin"

cat > "$mock_bin/curl" <<'MOCK_CURL'
#!/usr/bin/env bash
set -euo pipefail

request="$*"
printf '%s\n' "$request" >> "$MOCK_LAUNCHPAD_CURL_LOG"

if [[ "$request" == *"ws.op=getPublishedSources"* ]]; then
    cat <<'JSON'
{"entries":[{"source_package_version":"2026101120.slskdn.349-1ppa202610112158~jammy","status":"Published","distro_series_link":"https://api.launchpad.net/1.0/ubuntu/jammy","self_link":"https://api.launchpad.net/1.0/~keefshape/+archive/ubuntu/slskdn/+sourcepub/18831043"}]}
JSON
elif [[ "$request" == *"ws.op=getBuilds"* ]]; then
    cat <<'JSON'
{"entries":[{"distro_series_link":"https://api.launchpad.net/1.0/ubuntu/jammy","buildstate":"Successfully built"}]}
JSON
elif [[ "$request" == *"ws.op=getPublishedBinaries"* ]]; then
    if [[ "$request" == *"version="* ]]; then
        printf '{"entries":[]}\n'
    else
        cat <<'JSON'
{"entries":[{"binary_package_version":"2026101120.slskdn.349-1ppa202610112158~jammy","status":"Published","distro_arch_series_link":"https://api.launchpad.net/1.0/ubuntu/jammy/amd64"}]}
JSON
    fi
else
    echo "Unexpected Launchpad API request: $request" >&2
    exit 1
fi
MOCK_CURL

chmod +x "$mock_bin/curl"

package_version="2026101120.slskdn.349-1ppa202610112158~jammy"
curl_log="$temporary_directory/curl.log"
output="$temporary_directory/waiter-output.log"

if ! MOCK_LAUNCHPAD_CURL_LOG="$curl_log" \
    LAUNCHPAD_API_ROOT="https://api.launchpad.test/1.0" \
    LAUNCHPAD_PUBLICATION_TIMEOUT_SECONDS=3 \
    LAUNCHPAD_PUBLICATION_POLL_SECONDS=1 \
    PATH="$mock_bin:$PATH" \
    "$repo_root/scripts/wait-for-launchpad-ppa-publication.sh" \
    "$package_version" jammy >"$output" 2>&1; then
    cat "$output" >&2
    exit 1
fi

if ! grep -Fqx "Launchpad published slskdn $package_version for Ubuntu jammy." "$output"; then
    cat "$output" >&2
    echo "The waiter did not confirm the exact published binary." >&2
    exit 1
fi

binary_query="$(grep -F 'ws.op=getPublishedBinaries' "$curl_log")"
if [[ "$binary_query" == *"version="* ]]; then
    echo "The waiter passed a version filter to Launchpad's binary query." >&2
    exit 1
fi

printf 'Launchpad PPA publication waiter handles stale version-filtered binary queries.\n'
