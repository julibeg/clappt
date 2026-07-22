#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
t3_version=$(pnpm view t3 version)
playwright_version=$(pnpm view playwright version)

# bake the host pixi binary into the image instead of exposing it through a
# runtime bind mount
build_tmp_dir="$script_dir/build-tmp"
mkdir -p "$build_tmp_dir"
trap 'rm -rf "$build_tmp_dir"' EXIT
cp "$(realpath "$(command -v pixi)")" "$build_tmp_dir/pixi-build"

# forward optional build flags and retain a complete log; pipefail preserves the
# podman exit status through tee
podman build \
  --build-arg "T3_VERSION=$t3_version" \
  --build-arg "PLAYWRIGHT_VERSION=$playwright_version" \
  --tag t3code:latest \
  "$@" "$script_dir" 2>&1 | tee "$script_dir/build.log"
