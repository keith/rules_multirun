#!/bin/bash

set -euo pipefail

if [[ "$PWD" == "$BUILD_WORKSPACE_DIRECTORY" ]]; then
  echo "error: expected to run from default pwd" >&2
  exit 1
fi
