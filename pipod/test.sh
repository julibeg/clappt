#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
image=${IMAGE:-localhost/pipod:latest}
output_dir=$(mktemp -d)
trap 'rm -rf "$output_dir"' EXIT

run_tests() {
    "$script_dir/test-wrapper.sh"

    podman run --rm --pull=never \
        "--userns=keep-id:uid=1001,gid=1001" --user=user \
        --security-opt label=disable --volume "$output_dir:/output" \
        "$image" bash -lc '
            set -euo pipefail
            test "$(id -u):$(id -g)" = 1001:1001
            git --version
            fd --version
            rg --version
            python --version
            python3 --version
            ruff --version
            shellcheck --version
            pnpm --version
            pnpm config get minimumReleaseAge | grep -Fx 2880
            pixi --version
            rustc --version
            cargo --version
            claude --version
            codex --version
            pi --version
            firecrawl --version
            nextflow -version
            playwright --version
            playwright screenshot --browser chromium \
                "data:text/html,<h1>Playwright works</h1>" /output/playwright.png
            test -s /output/playwright.png
        '

    echo "Image OK"
}

run_tests 2>&1 | tee "$script_dir/test.log"
