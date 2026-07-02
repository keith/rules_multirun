#!/usr/bin/env bash

# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v2 ---

set -euo pipefail

if [[ $# != 1 ]]; then
  echo "error: expected one argument, got $#: $@"
  exit 1
fi

arg_hello="$(rlocation "$1")"
arg_output="$($arg_hello)"

if [[ "$arg_output" != hello ]]; then
  echo "error: expected arg '$arg_hello' to print 'hello', got '$arg_output'"
  exit 1
fi

env_hello="$(rlocation "$FOO_ENV")"
env_output="$($env_hello)"

if [[ "$env_output" != hello2 ]]; then
  echo "error: expected FOO_ENV '$env_hello' to print 'hello2', got '$env_output'"
  exit 1
fi
