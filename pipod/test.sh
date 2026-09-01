#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
image=${IMAGE:-localhost/pipod:latest}
podman_data_home=${XDG_DATA_HOME:-$HOME/.local/share}
podman_config_home=${XDG_CONFIG_HOME:-$HOME/.config}
output_dir=$(mktemp -d)
config_dir=$output_dir/config
wrapper_home=$output_dir/home
mkdir -p "$config_dir/pnpm" "$wrapper_home/.codex"
printf 'minimumReleaseAge: 1\n' >"$config_dir/pnpm/config.yaml"
trap 'rm -rf "$output_dir"' EXIT

run_tests() {
    "$script_dir/test-wrapper.sh"

    podman run --rm --pull=never \
        "--userns=keep-id:uid=1001,gid=1001" --user=user \
        --security-opt label=disable \
        --volume "$config_dir:/home/user/.config:ro" \
        --volume "$wrapper_home/.codex:/home/user/.codex" \
        --volume "$output_dir:/output" \
        "$image" bash -lc '
            set -euo pipefail
            test "$(id -u):$(id -g)" = 1001:1001
            git --version
            hook_repo=$(mktemp -d)
            git -C "$hook_repo" init --quiet
            git -C "$hook_repo" config user.name Test
            git -C "$hook_repo" config user.email test@example.com
            git -C "$hook_repo" commit --quiet --allow-empty \
                -m Subject -m "Short body."
            long_line=$(printf "%073d" 0)
            printf "%s\n" "$long_line" >"$hook_repo/long-subject"
            printf "Subject\n\n%s\n" "$long_line" >"$hook_repo/long-body"
            for message in "$hook_repo/long-subject" "$hook_repo/long-body"; do
                if git -C "$hook_repo" commit --quiet --allow-empty \
                    -F "$message" 2>"$hook_repo/error"; then
                    echo "Long commit-message line was accepted" >&2
                    exit 1
                fi
                grep -F "exceeds 72 characters" "$hook_repo/error"
            done
            rm -rf "$hook_repo"
            fd --version
            rg --version
            python --version
            python3 --version
            test "$MPLCONFIGDIR" = /home/user/.cache/matplotlib
            test "$UV_LINK_MODE" = copy
            test "$UV_PROJECT_ENVIRONMENT" = /opt/uv-project-environment
            test -w "$UV_PROJECT_ENVIRONMENT"
            python -c "import matplotlib, numpy, pandas, scipy, seaborn, sklearn"
            ruff --version
            uv --version
            shellcheck --version
            npm config get min-release-age | grep -Fx 2
            pnpm --version
            pnpm config get minimumReleaseAge | grep -Fx 2880
            pixi --version
            rustc --version
            cargo --version
            claude --version
            codex --version
            pi --version
            firecrawl --version
            t3 --version
            t3 connect link --help >/dev/null
            status=$(t3 connect status --json)
            jq -e \
                '\''.relayClient.status | strings | select(. != "unsupported")'\'' \
                <<<"$status" >/dev/null
            set +e
            timeout 5 t3 --no-browser --host 127.0.0.1 --port 3773 \
                >/tmp/t3-start.log 2>&1
            t3_status=$?
            set -e
            if [[ $t3_status -ne 124 ]]; then
                cat /tmp/t3-start.log >&2
                exit 1
            fi
            playwright --version
            playwright screenshot --browser chromium \
                "data:text/html,<h1>Playwright works</h1>" /output/playwright.png
            test -s /output/playwright.png
        '

    HOME="$wrapper_home" XDG_CONFIG_HOME="$podman_config_home" \
        XDG_DATA_HOME="$podman_data_home" \
        "$script_dir/pipod" --image "$image" codex --version

    echo "Image OK"
}

run_tests 2>&1 | tee "$script_dir/test.log"
