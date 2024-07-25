#!/bin/bash

set -euo pipefail

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---

# without this, test cases silently pass if rlocation returns a missing script
check_rlocation() {
    script=$(rlocation $1)
    if [ ! -f "$script" ]; then
        echo "Error: '$script' returned by rlocation($1) is invalid" >2
        exit 1
    fi
    echo "$script"
}

unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     ext=bash;;
    Darwin*)    ext=bash;;
    CYGWIN*)    ext=bat;;
    MINGW*)     ext=bat;;
    MSYS_NT*)   ext=bat;;
    *)          ext=bash
esac

script=$(check_rlocation _main/tests/hello.$ext)
output=$($script)
if [[ "$output" != "hello" ]]; then
  echo "Expected 'hello', got '$output'"
  exit 1
fi

script=$(check_rlocation _main/tests/validate_args_cmd.$ext)
$script
script=$(check_rlocation _main/tests/validate_chdir_location_cmd.$ext)
$script
script=$(check_rlocation _main/tests/validate_env_cmd.$ext)
$script

script=$(check_rlocation _main/tests/multirun_binary_args.exe)
$script
script=$(check_rlocation _main/tests/multirun_binary_env.exe)
$script
script=$(check_rlocation _main/tests/multirun_binary_args_location.exe)
$script

script="$(check_rlocation _main/tests/multirun_parallel.exe)"
parallel_output="$($script)"
if [[ -n "$parallel_output" ]]; then
  echo "Expected no output, got '$parallel_output'"
  exit 1
fi

script="$(check_rlocation _main/tests/multirun_parallel_no_buffer.exe)"
parallel_output="$($script)"
if [[ -n "$parallel_output" ]]; then
  echo "Expected no output, got '$parallel_output'"
  exit 1
fi

script="$(check_rlocation _main/tests/multirun_parallel_with_output.exe)"
# commands are executing in parallel, we can't test any ordering. sort output
parallel_output=$($script | sed 's=@[^/]*/=@/=g' 2>&1 | sort -f)
if [[ "$parallel_output" != "hello
hello2
Running @//tests:echo_hello
Running @//tests:echo_hello2" ]]; then
  echo "Expected output, got '$parallel_output'"
  exit 1
fi

script=$(check_rlocation _main/tests/multirun_serial.exe)
serial_output=$($script | sed 's=@[^/]*/=@/=g')
if [[ "$serial_output" != "Running @//tests:validate_args_cmd
Running @//tests:validate_env_cmd" ]]; then
  echo "Expected labeled output, got '$serial_output'"
  exit 1
fi

script=$(check_rlocation _main/tests/multirun_serial_keep_going.exe)
if serial_output=$($script | sed 's=@[^/]*/=@/=g'); then
  echo "Expected failure" >&2
  exit 1
fi

if [[ "$serial_output" != "Running @//tests:echo_and_fail
hello and fail
Running @//tests:echo_hello
hello" ]]; then
  echo "Expected labeled output, got '$serial_output'"
  exit 1
fi

script=$(check_rlocation _main/tests/multirun_serial_description.exe)
serial_output=$($script | sed 's=@[^/]*/=@/=g')
if [[ "$serial_output" != "some custom string
Running @//tests:validate_env_cmd" ]]; then
  echo "Expected labeled output, got '$serial_output'"
  exit 1
fi

script=$(check_rlocation _main/tests/multirun_serial_no_print.exe)
serial_no_output=$($script)
if [[ -n "$serial_no_output" ]]; then
  echo "Expected no output, got '$serial_no_output'"
  exit 1
fi

script=$(check_rlocation _main/tests/multirun_with_transition.exe)
serial_with_transition_output=$($script | sed 's=@[^/]*/=@/=g')
if [[ "$serial_with_transition_output" != "Running @//tests:validate_env_cmd
Running @//tests:validate_args_cmd" ]]; then
  echo "Expected labeled output, got '$serial_with_transition_output'"
  exit 1
fi

script=$(check_rlocation _main/tests/root_multirun.exe)
root_output=$($script)
if [[ "$root_output" != "hello" ]]; then
  echo "Expected 'hello' from root, got '$root_output'"
  exit 1
fi
