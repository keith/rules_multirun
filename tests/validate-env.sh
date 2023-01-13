#!/bin/bash

set -euo pipefail

if [[ "$FOO_ENV" != "foo" ]]; then
  echo "error: expected FOO_ENV to be 'foo', got '$FOO_ENV'"
  exit 1
fi
