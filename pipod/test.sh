#!/bin/bash
set -euo pipefail

image=${IMAGE:-localhost/pipod:latest}
output_dir=$(mktemp -d)
trap 'rm -rf "$output_dir"' EXIT

podman run --rm --pull=never "--userns=keep-id:uid=1000,gid=1000" --user=user \
    --security-opt label=disable --volume "$output_dir:/output" \
    "$image" bash -lc '
        git --version
        fd --version
        rg --version
        pnpm --version
        test "$(pnpm config get minimum-release-age)" = 2880
        pixi --version
        rustc --version
        cargo --version
        claude --version
        codex --version
        pi --version
        playwright --version
        playwright screenshot --browser chromium \
            "data:text/html,<h1>Playwright works</h1>" /output/playwright.png
        test -s /output/playwright.png
    '

echo "Image OK"
