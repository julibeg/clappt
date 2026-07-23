#!/bin/bash

set -euo pipefail

repo_dir=$(cd "$(dirname "$0")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

home="$tmp_dir/home"
bin="$tmp_dir/bin"
rw_dir="$tmp_dir/rw"
ro_dir="$tmp_dir/ro"
mkdir -p "$home/.claude" "$home/.codex" "$home/.pi/agent" "$bin"
mkdir "$rw_dir" "$ro_dir"
touch "$rw_dir/pixi.toml" "$ro_dir/pixi.toml"

cat >"$bin/apptainer" <<'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
chmod +x "$bin/apptainer"

output=$(
    unset MAMBA_ROOT_PREFIX CONDA_PREFIX
    HOME="$home" PATH="$bin:/usr/bin:/bin" \
        "$repo_dir/clappt" --stage-dirs "$rw_dir,$ro_dir:ro"
)
rw_hash=$(printf %s "$rw_dir" | sha256sum | cut -c1-12)
ro_hash=$(printf %s "$ro_dir" | sha256sum | cut -c1-12)

grep -Fx -- "$rw_dir:/work/$rw_hash/rw" <<<"$output"
grep -Fx -- "$ro_dir:/work/$ro_hash/ro:ro" <<<"$output"
grep -Fx -- "$rw_dir/.pixi-clappt:/work/$rw_hash/rw/.pixi" <<<"$output"
[[ ! -e "$ro_dir/.pixi-clappt" ]]
! grep -F -- "$ro_dir/.pixi-clappt:" <<<"$output"
