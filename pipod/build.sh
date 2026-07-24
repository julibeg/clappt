#!/bin/bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
image=${IMAGE:-localhost/pipod:latest}

exec podman build --pull=always --tag "$image" "$@" "$script_dir"
