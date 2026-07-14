#!/bin/bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
build_tmp_dir="$script_dir/build-tmp"
pixi_build_file="$build_tmp_dir/pixi-build"
mkdir -p "$build_tmp_dir"
trap 'rm -rf "$build_tmp_dir"' EXIT
cp "$(realpath "$(command -v pixi)")" "$pixi_build_file"

podman build --tag t3code:latest "$@" "$script_dir" 2>&1 \
  | tee "$script_dir/build.log"
