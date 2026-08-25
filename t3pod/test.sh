#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

home="$tmp_dir/home"
project="$tmp_dir/project"
bin="$tmp_dir/bin"
mkdir -p "$home" "$project" "$bin"

cat >"$bin/podman" <<'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
chmod +x "$bin/podman"

output=$(HOME="$home" PATH="$bin:/usr/bin:/bin" "$script_dir/t3pod" "$project")
for expected in \
    "127.0.0.1:3773:3773" \
    "$home/.t3-container-state:/data" \
    "/work/project" \
    "T3CODE_HOME=/data" \
    "t3" \
    "--no-browser" \
    "--host" \
    "0.0.0.0" \
    "--port" \
    "3773"; do
    grep -Fqx -- "$expected" <<<"$output" || {
        echo "Missing Podman argument: $expected" >&2
        exit 1
    }
done

[[ "$output" == *$'--workdir\n/work/project'* ]]

debug_output=$(
    HOME="$home" PATH="$bin:/usr/bin:/bin" "$script_dir/t3pod" --debug "$project"
)
[[ "$debug_output" == *$'bash' ]]
if grep -Fqx -- "127.0.0.1:3773:3773" <<<"$debug_output"; then
    echo "Debug mode published the T3 port" >&2
    exit 1
fi

printf 't3pod launcher OK\n'
