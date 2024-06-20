load("//:defs.bzl", "command", "command_force_opt", "multirun")
load(":transitions.bzl", "command_lambda", "multirun_lambda")

sh_binary(
    name = "echo_hello",
    srcs = ["echo_hello.sh"],
    visibility = ["//:__subpackages__"],
)

command(
    name = "hello",
    command = "echo_hello",
)

sh_binary(
    name = "echo_hello2",
    srcs = ["echo_hello2.sh"],
    visibility = ["//:__subpackages__"],
)

command(
    name = "hello2",
    command = "echo_hello2",
)

sh_binary(
    name = "echo_and_fail",
    srcs = ["echo_and_fail.sh"],
    visibility = ["//:__subpackages__"],
)

command(
    name = "echo_and_fail_cmd",
    command = "echo_and_fail",
)

sh_binary(
    name = "validate_args",
    srcs = ["validate-args.sh"],
)

command(
    name = "validate_args_cmd",
    arguments = ["foo"],
    command = "validate_args",
)

command(
    name = "validate_args_cmd_description",
    arguments = ["foo"],
    command = "validate_args",
    description = "some custom string",
)

sh_binary(
    name = "validate_chdir_location",
    srcs = ["validate-chdir-location.sh"],
    deps = ["@bazel_tools//tools/bash/runfiles"],
)

command_force_opt(
    name = "validate_chdir_location_cmd",
    arguments = ["$(rlocationpath :hello)"],
    command = "validate_chdir_location",
    data = [":hello"],
)

sh_binary(
    name = "validate_env",
    srcs = ["validate-env.sh"],
)

command_lambda(
    name = "validate_env_cmd",
    command = "validate_env",
    environment = {"FOO_ENV": "foo"},
)

multirun(
    name = "multirun_parallel",
    commands = [
        ":validate_args_cmd",
        ":validate_env_cmd",
    ],
    jobs = 0,
    print_command = False,
)

multirun(
    name = "multirun_parallel_no_buffer",
    buffer_output = False,
    commands = [
        ":validate_args_cmd",
        ":validate_env_cmd",
    ],
    jobs = 0,
)

multirun(
    name = "multirun_parallel_with_output",
    buffer_output = True,
    commands = [
        ":echo_hello",
        ":echo_hello2",
    ],
    jobs = 0,
)

multirun(
    name = "multirun_serial",
    commands = [
        ":validate_args_cmd",
        ":validate_env_cmd",
    ],
)

multirun(
    name = "multirun_serial_keep_going",
    commands = [
        ":echo_and_fail",
        ":echo_hello",
    ],
    keep_going = True,
)

multirun(
    name = "multirun_serial_description",
    commands = [
        ":validate_args_cmd_description",
        ":validate_env_cmd",
    ],
)

multirun(
    name = "multirun_serial_no_print",
    commands = [
        ":validate_args_cmd",
        ":validate_env_cmd",
    ],
    print_command = False,
)

sh_binary(
    name = "validate_binary_args",
    srcs = ["validate-args.sh"],
    args = ["foo"],
)

multirun(
    name = "multirun_binary_args",
    commands = [":validate_binary_args"],
)

sh_binary(
    name = "validate_binary_env",
    srcs = ["validate-env.sh"],
    env = {"FOO_ENV": "foo"},
)

multirun(
    name = "multirun_binary_env",
    commands = [":validate_binary_env"],
)

platform(
    name = "lambda",
    constraint_values = [
    ],
)

multirun_lambda(
    name = "multirun_with_transition",
    commands = [
        ":validate_env_cmd",
        ":validate_args_cmd",
    ],
)

sh_binary(
    name = "validate_binary_args_location",
    srcs = ["validate-chdir-location.sh"],
    args = ["$(rlocationpath :hello)"],
    data = [":hello"],
)

multirun(
    name = "multirun_binary_args_location",
    commands = [":validate_binary_args_location"],
)

multirun(
    name = "root_multirun",
    commands = ["//:root_command"],
    jobs = 0,
    print_command = False,
)

sh_test(
    name = "test",
    srcs = ["test.sh"],
    data = [
        ":echo_and_fail_cmd",
        ":hello",
        ":hello2",
        ":multirun_binary_args",
        ":multirun_binary_args_location",
        ":multirun_binary_env",
        ":multirun_parallel",
        ":multirun_parallel_no_buffer",
        ":multirun_parallel_with_output",
        ":multirun_serial",
        ":multirun_serial_description",
        ":multirun_serial_keep_going",
        ":multirun_serial_no_print",
        ":multirun_with_transition",
        ":root_multirun",
        ":validate_args_cmd",
        ":validate_args_cmd_description",
        ":validate_chdir_location_cmd",
        ":validate_env_cmd",
    ],
    deps = ["@bazel_tools//tools/bash/runfiles"],
)

sh_test(
    name = "test2",
    srcs = ["test2.sh"],
    data = [
        ":echo_and_fail_cmd",
        ":hello",
        ":hello2",
        ":multirun_binary_args",
        ":multirun_binary_args_location",
        ":multirun_binary_env",
        ":multirun_parallel",
        ":multirun_parallel_no_buffer",
        ":multirun_parallel_with_output",
        ":multirun_serial",
        ":multirun_serial_description",
        ":multirun_serial_keep_going",
        ":multirun_serial_no_print",
        ":multirun_with_transition",
        ":root_multirun",
        ":validate_args_cmd",
        ":validate_args_cmd_description",
        ":validate_chdir_location_cmd",
        ":validate_env_cmd",
    ],
    deps = ["@bazel_tools//tools/bash/runfiles"],
)
