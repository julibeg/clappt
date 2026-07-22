#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
output_dir="$script_dir/playwright-test-output"
mkdir -p "$output_dir"

podman run --rm --pull=never \
  -v "$output_dir:/output" \
  t3code:latest bash -lc '
    playwright --version
    playwright screenshot --browser chromium \
      "data:text/html,<h1>Playwright works</h1>" /output/playwright.png
    test -s /output/playwright.png
  '

echo "Playwright OK: $output_dir/playwright.png"
