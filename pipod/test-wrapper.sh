#!/bin/bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

home="$tmp_dir/home"
bin="$tmp_dir/bin"
rw_dir="$tmp_dir/rw"
ro_dir="$tmp_dir/ro"
mkdir -p "$home/.claude" "$home/.codex" "$home/.pi/agent" "$bin"
mkdir -p "$home/agent-targets"/{claude,codex,pi} "$rw_dir" "$ro_dir"
ln -s ../agent-targets/claude "$home/.claude/skills"
ln -s ../agent-targets/codex "$home/.codex/agents"
ln -s ../../agent-targets/pi "$home/.pi/agent/extensions"
touch "$rw_dir/pixi.toml" "$ro_dir/pixi.toml"

cat >"$bin/podman" <<'EOF'
#!/bin/bash
printf '%s\n' "$@"
EOF
chmod +x "$bin/podman"

output=$(
    HOME="$home" PATH="$bin:/usr/bin:/bin" \
        "$script_dir/pipod" --stage-dirs "$rw_dir,$ro_dir:ro" -- echo ok
)
rw_hash=$(printf %s "$rw_dir" | sha256sum | cut -c1-12)
ro_hash=$(printf %s "$ro_dir" | sha256sum | cut -c1-12)

for expected in \
    "--userns=keep-id:uid=1000,gid=1000" \
    "$home/agent-targets/claude:/home/user/agent-targets/claude" \
    "$home/agent-targets/codex:/home/user/agent-targets/codex" \
    "$home/agent-targets/pi:/home/user/agent-targets/pi" \
    "$rw_dir:/work/$rw_hash/rw" \
    "$ro_dir:/work/$ro_hash/ro:ro" \
    "$rw_dir/.pixi-pipod:/work/$rw_hash/rw/.pixi"; do
    grep -Fx -- "$expected" <<<"$output"
done

[[ ! -e "$ro_dir/.pixi-pipod" ]]
! grep -F -- "$ro_dir/.pixi-pipod:" <<<"$output"
