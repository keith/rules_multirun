#!/bin/bash

set -euo pipefail

output=$(./tests/hello.bash)
if [[ "$output" != "hello" ]]; then
  echo "Expected 'hello', got '$output'"
  exit 1
fi

./tests/validate_args_cmd.bash
./tests/validate_env_cmd.bash

parallel_output="$(./tests/multirun_parallel.bash)"
if [[ -n "$parallel_output" ]]; then
  echo "Expected no output, got '$parallel_output'"
  exit 1
fi

serial_output=$(./tests/multirun_serial.bash)
if [[ "$serial_output" != "Running @//tests:validate_args_cmd
Running @//tests:validate_env_cmd" ]]; then
  echo "Expected labeled output, got '$serial_output'"
  exit 1
fi

serial_no_output=$(./tests/multirun_serial_no_print.bash)
if [[ -n "$serial_no_output" ]]; then
  echo "Expected no output, got '$serial_no_output'"
  exit 1
fi
