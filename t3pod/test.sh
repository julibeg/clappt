#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
image=${T3POD_IMAGE:-localhost/t3code:latest}
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

assert_arg() {
    grep -Fx -- "$2" <<<"$1" >/dev/null || {
        printf 'Missing Podman argument: %s\n' "$2" >&2
        return 1
    }
}

test_launcher() {
    local home="$tmpdir/home"
    local project="$tmpdir/project"
    local output

    mkdir -p \
        "$home/.cache/uv" \
        "$home/.codex" \
        "$home/.local/bin" \
        "$home/.local/share/pnpm" \
        "$home/agent-memory" \
        "$home/git/agents-stuff" \
        "$home/git/clappt/hooks" \
        "$home/micromamba/envs/cli-utils" \
        "$project" \
        "$tmpdir/fake-bin"
    touch "$home/.claude.json" "$home/.local/bin/claude"
    cat >"$tmpdir/fake-bin/podman" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@"
EOF
    chmod +x "$tmpdir/fake-bin/podman"

    output=$(
        HOME="$home" \
            MAMBA_ROOT_PREFIX="$home/micromamba" \
            PATH="$tmpdir/fake-bin:/usr/bin:/bin" \
            "$script_dir/t3pod" "$project"
    )

    assert_arg "$output" \
        "PATH=/usr/local/bin:/home/user/micromamba/envs/cli-utils/bin:/home/user/.local/bin:/root/.local/share/pnpm/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/sbin:/bin"
    assert_arg "$output" "$home/.t3-container-state:/data"
    assert_arg "$output" "$home/.cache/uv:/home/user/.cache/uv"
    assert_arg "$output" "$home/.codex:/home/user/.codex"
    assert_arg "$output" "$home/.local/share/pnpm:/root/.local/share/pnpm:ro"
    assert_arg "$output" "$project:/work/project"
    assert_arg "$output" "127.0.0.1:3773:3773"
    assert_arg "$output" "T3CODE_HOME=/data"
    grep -F \
        "export PATH=\"/usr/local/bin:/home/user/micromamba/envs/cli-utils/bin:/home/user/.local/bin:/root/.local/share/pnpm/bin:\$PATH\"" \
        <<<"$output" >/dev/null
}

test_image() {
    local state="$tmpdir/state"
    local codex_home="$tmpdir/codex-home"
    local fake_pnpm="$tmpdir/fake-pnpm"
    local output="$tmpdir/output"

    command -v podman >/dev/null || {
        echo "podman is required to test $image" >&2
        return 1
    }
    podman image exists "$image" || {
        echo "Image $image does not exist; run ./build.sh first" >&2
        return 1
    }

    mkdir -p "$state" "$codex_home" "$fake_pnpm/bin" "$output"
    cat >"$fake_pnpm/bin/codex" <<'EOF'
#!/usr/bin/env bash
echo 'host pnpm Codex shadowed the image installation' >&2
exit 99
EOF
    chmod +x "$fake_pnpm/bin/codex"

    podman run --rm --pull=never \
        --security-opt label=disable \
        -e HOME=/home/user \
        -e T3CODE_HOME=/data \
        -v "$state:/data:rw" \
        -v "$codex_home:/home/user/.codex:rw" \
        -v "$fake_pnpm:/root/.local/share/pnpm:ro" \
        -v "$output:/output:rw" \
        "$image" \
        bash -lc '
            set -euo pipefail
            export PATH="/usr/local/bin:/root/.local/share/pnpm/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            test "$(command -v codex)" = /usr/local/bin/codex
            codex --version
            t3 --version
            t3 connect link --help >/dev/null
            status=$(t3 connect status --json)
            jq -e \
                '\''.relayClient.status | strings | select(. != "unsupported")'\'' \
                <<<"$status" >/dev/null
            pixi --version
            uv --version
            test "$UV_LINK_MODE" = copy
            test "$UV_PROJECT_ENVIRONMENT" = /opt/uv-project-environment
            test -w "$UV_PROJECT_ENVIRONMENT"
            test "$(uv cache dir)" = /home/user/.cache/uv
            playwright --version
            test -x /usr/local/bin/t3pod-entrypoint
            touch /data/test-state /home/user/.codex/test-state
            node /usr/lib/node_modules/playwright/cli.js screenshot \
                --browser chromium \
                "data:text/html,<h1>T3Pod Playwright OK</h1>" \
                /output/playwright.png
        '

    test -f "$state/test-state"
    test -f "$codex_home/test-state"
    test -s "$output/playwright.png"
}

run_tests() {
    test_launcher
    test_image
    printf 'T3Pod image and launcher OK: %s\n' "$image"
}

run_tests 2>&1 | tee "$script_dir/test.log"
