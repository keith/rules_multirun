#!/bin/bash

set -euo pipefail

# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v2 ---

# The .bat launcher only exists on Windows, where it is what `bazel run` and
# `bazel test` actually execute, since Windows cannot execute a Bash script
# directly.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) ;;
  *) exit 0 ;;
esac

# PATH varies when running vs testing; this makes it more like running.
export PATH=/usr/bin:/bin

launcher=$(rlocation rules_multirun/tests/hello.bat)
output=$("$launcher")
if [[ "$output" != "hello" ]]; then
  echo "Expected 'hello', got '$output'"
  exit 1
fi

launcher=$(rlocation rules_multirun/tests/multirun_serial.bat)
output=$("$launcher" | sed 's=@[^/]*/=@/=g')
if [[ "$output" != "Running @//tests:validate_args_cmd
Running @//tests:validate_env_cmd" ]]; then
  echo "Expected labeled output, got '$output'"
  exit 1
fi

# cmd.exe is happy to mangle arguments. Make sure they survive verbatim,
# including spaces, delayed expansion characters and percent signs.
launcher=$(rlocation rules_multirun/tests/echo_args_cmd.bat)
output=$("$launcher" "a b" 'c!d' 'e%f' '')
if [[ "$output" != "arg: a b
arg: c!d
arg: e%f
arg: " ]]; then
  echo "Expected verbatim arguments, got '$output'"
  exit 1
fi

# A multirun runs its commands from a nested Python runner, which has to quote
# arguments the way MSYS2 Bash expects, or a double quote swallows everything
# after it.
launcher=$(rlocation rules_multirun/tests/echo_args_multirun.bash)
output=$("$launcher" 'q"z' "a b")
if [[ "$output" != 'arg: q"z
arg: a b' ]]; then
  echo "Expected verbatim multirun arguments, got '$output'"
  exit 1
fi

# Failures must be propagated rather than swallowed by the launcher.
launcher=$(rlocation rules_multirun/tests/echo_and_fail_cmd.bat)
if "$launcher" > /dev/null; then
  echo "Expected a non-zero exit code"
  exit 1
fi
