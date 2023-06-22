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

# PATH varies when running vs testing, this makes it more like running to validate the actual behavior. Specifically '.' is included for tests but not runs
export PATH=/usr/bin:/bin

script=$(rlocation rules_multirun/tests/hello.bash)
output=$($script)
if [[ "$output" != "hello" ]]; then
  echo "Expected 'hello', got '$output'"
  exit 1
fi

script=$(rlocation rules_multirun/tests/validate_args_cmd.bash)
$script
script=$(rlocation rules_multirun/tests/validate_chdir_location_cmd.bash)
$script
script=$(rlocation rules_multirun/tests/validate_env_cmd.bash)
$script

script=$(rlocation rules_multirun/tests/multirun_binary_args.bash)
$script
script=$(rlocation rules_multirun/tests/multirun_binary_env.bash)
$script
script=$(rlocation rules_multirun/tests/multirun_binary_args_location.bash)
$script

script="$(rlocation rules_multirun/tests/multirun_parallel.bash)"
parallel_output="$($script)"
if [[ -n "$parallel_output" ]]; then
  echo "Expected no output, got '$parallel_output'"
  exit 1
fi

script=$(rlocation rules_multirun/tests/multirun_serial.bash)
serial_output=$($script | sed 's=@[^/]*/=@/=g')
if [[ "$serial_output" != "Running @//tests:validate_args_cmd
Running @//tests:validate_env_cmd" ]]; then
  echo "Expected labeled output, got '$serial_output'"
  exit 1
fi

script=$(rlocation rules_multirun/tests/multirun_serial_no_print.bash)
serial_no_output=$($script)
if [[ -n "$serial_no_output" ]]; then
  echo "Expected no output, got '$serial_no_output'"
  exit 1
fi

script=$(rlocation rules_multirun/tests/multirun_with_transition.bash)
serial_with_transition_output=$($script | sed 's=@[^/]*/=@/=g')
if [[ "$serial_with_transition_output" != "Running @//tests:validate_env_cmd
Running @//tests:validate_args_cmd" ]]; then
  echo "Expected labeled output, got '$serial_with_transition_output'"
  exit 1
fi

script=$(rlocation rules_multirun/tests/root_multirun.bash)
cat "$script"
root_output=$($script)
if [[ "$root_output" != "hello" ]]; then
  echo "Expected 'hello' from root, got '$output'"
  exit 1
fi
