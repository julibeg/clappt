#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
image=${IMAGE:-localhost/pipod:latest}

podman build --pull=always \
    --build-arg "AGENT_CACHE_BUST=$(date -u +%s)" \
    --tag "$image" "$@" "$script_dir" 2>&1 \
    | tee "$script_dir/build.log"
