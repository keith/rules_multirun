#!/bin/bash

set -euo pipefail

if [[ ! "$PWD" -ef "$BUILD_WORKSPACE_DIRECTORY" ]]; then
  echo "error: expected to run from workspace root" >&2
  exit 1
fi
