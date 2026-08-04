#!/bin/bash
set -euo pipefail

image=${IMAGE:-localhost/pipod:latest}
image_repo=${IMAGE_REPO:-docker.io/julibeg/pipod}

if (($# == 0)); then
    set -- latest
fi

for tag; do
    podman push "$image" "$image_repo:$tag"
done
