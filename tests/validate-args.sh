#!/bin/bash

set -euo pipefail

if [[ "$1" != "foo" ]]; then
  echo "error: expected first arg to be 'foo', got '$1'"
  exit 1
fi

if [[ $# -ne 1 ]]; then
  echo "error: expected 1 arg, got $#, args: $*"
  exit 1
fi
