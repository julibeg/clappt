#!/bin/bash
set -euo pipefail

script_dir=$(cd "$(dirname "$0")" && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

home="$tmp_dir/home"
bin="$tmp_dir/bin"
rw_dir="$tmp_dir/rw"
ro_dir="$tmp_dir/ro"
mkdir -p "$home/.claude" "$home/.codex" "$home/.pi/agent" \
    "$home/.config/pnpm" "$home/.config/firecrawl-cli" \
    "$home/.local/share/claude" "$home/.local/share/pnpm/store" "$bin"
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
        "$script_dir/pipod" --publish 127.0.0.1:8000:8000 \
        --stage-dirs "$rw_dir,$ro_dir:ro" -- pi --version
)
rw_hash=$(printf %s "$rw_dir" | sha256sum | cut -c1-12)
ro_hash=$(printf %s "$ro_dir" | sha256sum | cut -c1-12)

for expected in \
    "--pids-limit=-1" \
    "--tz=local" \
    "--userns=keep-id:uid=1001,gid=1001" \
    "--publish" \
    "127.0.0.1:8000:8000" \
    "PNPM_CONFIG_IGNORE_SCRIPTS=true" \
    "PNPM_CONFIG_STORE_DIR=/home/user/.local/share/pnpm/store" \
    "$home/agent-targets/claude:/home/user/agent-targets/claude" \
    "$home/agent-targets/codex:/home/user/agent-targets/codex" \
    "$home/agent-targets/pi:/home/user/agent-targets/pi" \
    "$home/.config/firecrawl-cli:/home/user/.config/firecrawl-cli" \
    "$home/.local/share/pnpm/store:/home/user/.local/share/pnpm/store" \
    "$rw_dir:/work/$rw_hash/rw" \
    "$ro_dir:/work/$ro_hash/ro:ro" \
    "$rw_dir/.pixi-containers:/work/$rw_hash/rw/.pixi"; do
    grep -Fqx -- "$expected" <<<"$output" || {
        >&2 echo "ERROR: missing Podman argument: $expected"
        exit 1
    }
done

[[ "$output" == *$'pi\n--model\nopenai-codex/gpt-5.6-sol\n--thinking\nmedium\n--version' ]]
[[ ! -e "$ro_dir/.pixi-containers" ]]
if grep -Fq -- "$ro_dir/.pixi-containers:" <<<"$output"; then
    exit 1
fi
for forbidden in \
    "$home/.config:/home/user/.config:ro" \
    "$home/.local/share/claude:/home/user/.local/share/claude"; do
    if grep -Fqx -- "$forbidden" <<<"$output"; then
        exit 1
    fi
done
