load("//:defs.bzl", "command", "command_force_opt", "multirun")
load(":transitions.bzl", "command_lambda", "multirun_lambda")

sh_binary(
    name = "echo_hello",
    srcs = ["echo_hello.sh"],
)

command(
    name = "hello",
    command = "echo_hello",
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
)

multirun(
    name = "multirun_serial",
    commands = [
        ":validate_args_cmd",
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

sh_test(
    name = "test",
    srcs = ["test.sh"],
    data = [
        ":hello",
        ":multirun_binary_args",
        ":multirun_binary_args_location",
        ":multirun_binary_env",
        ":multirun_parallel",
        ":multirun_serial",
        ":multirun_serial_no_print",
        ":multirun_with_transition",
        ":validate_args_cmd",
        ":validate_chdir_location_cmd",
        ":validate_env_cmd",
    ],
    deps = ["@bazel_tools//tools/bash/runfiles"],
)
