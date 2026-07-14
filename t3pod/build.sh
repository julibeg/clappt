#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# bake the host pixi binary into the image instead of exposing a system binary
# through a runtime bind mount
build_tmp_dir="$script_dir/build-tmp"
pixi_build_file="$build_tmp_dir/pixi-build"
mkdir -p "$build_tmp_dir"
trap 'rm -rf "$build_tmp_dir"' EXIT
cp "$(realpath "$(command -v pixi)")" "$pixi_build_file"

# forward optional build flags and retain a complete log; pipefail preserves the
# podman exit status through tee
podman build --tag t3code:latest "$@" "$script_dir" 2>&1 \
  | tee "$script_dir/build.log"
