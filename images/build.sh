#!/bin/bash

root_dir=$(dirname "$(realpath "$0")")

apptainer build -F "$root_dir/img.sif" "$root_dir/img.def"
