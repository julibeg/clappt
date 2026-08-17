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
set -euo pipefail
for arg in "$@"; do
    if [[ "$arg" == *:/work ]]; then
        work_dir=${arg%:/work}
        [[ -w "$work_dir" ]]
        touch "$work_dir/test-write"
    fi
done
printf '%s\n' "$@"
EOF
chmod +x "$bin/apptainer"

output=$(
    unset MAMBA_ROOT_PREFIX CONDA_PREFIX
    HOME="$home" PATH="$bin:/usr/bin:/bin" \
        "$repo_dir/clappt" --gpu --stage-dirs "$rw_dir,$ro_dir:ro" \
            -- pi --version
)
rw_hash=$(printf %s "$rw_dir" | sha256sum | cut -c1-12)
ro_hash=$(printf %s "$ro_dir" | sha256sum | cut -c1-12)

grep -Fx -- "--nv" <<<"$output"
work_mount=$(grep -E '^[^:]+:/work$' <<<"$output")
[[ "$work_mount" == */work:/work ]]
work_line=$(grep -n -E '^[^:]+:/work$' <<<"$output" | cut -d: -f1)
rw_line=$(grep -n -F "$rw_dir:/work/$rw_hash/rw" <<<"$output" | cut -d: -f1)
((work_line < rw_line))
grep -Fx -- "$rw_dir:/work/$rw_hash/rw" <<<"$output"
grep -Fx -- "$ro_dir:/work/$ro_hash/ro:ro" <<<"$output"
grep -Fx -- "$rw_dir/.pixi-containers:/work/$rw_hash/rw/.pixi" <<<"$output"
[[ "$output" == *$'--pwd\n/work'* ]]
[[ ! -e "$ro_dir/.pixi-containers" ]]
if grep -F -- "$ro_dir/.pixi-containers:" <<<"$output"; then
    exit 1
fi
[[ "$output" == *$'pi\n--model\nopenai-codex/gpt-5.6-sol\n--thinking\nmedium\n--version' ]]

output=$(
    unset MAMBA_ROOT_PREFIX CONDA_PREFIX
    HOME="$home" PATH="$bin:/usr/bin:/bin" "$repo_dir/clappt" -- echo hi
)
if grep -Eq '^[^:]+:/work$' <<<"$output"; then
    exit 1
fi
