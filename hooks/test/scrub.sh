#!/bin/bash

# exit immediately if sed fails
set -e

# handle SIGPIPE gracefully (when downstream closes)
trap '' PIPE

sed -u -e "s|hello|hi|g"
