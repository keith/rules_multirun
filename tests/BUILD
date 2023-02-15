load("//:defs.bzl", "command", "multirun")

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

command(
    name = "validate_chdir_location_cmd",
    arguments = ["$(rlocationpath :hello)"],
    command = "validate_chdir_location",
    data = [":hello"],
)

sh_binary(
    name = "validate_env",
    srcs = ["validate-env.sh"],
)

command(
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
    args = ["foo"],
    srcs = ["validate-args.sh"],
)

multirun(
    name = "multirun_binary_args",
    commands = [":validate_binary_args"],
)

sh_binary(
    name = "validate_binary_env",
    env = {"FOO_ENV": "foo"},
    srcs = ["validate-env.sh"],
)

multirun(
    name = "multirun_binary_env",
    commands = [":validate_binary_env"],
)

sh_test(
    name = "test",
    srcs = ["test.sh"],
    data = [
        ":hello",
        ":multirun_binary_args",
        ":multirun_binary_env",
        ":multirun_parallel",
        ":multirun_serial",
        ":multirun_serial_no_print",
        ":validate_args_cmd",
        ":validate_chdir_location_cmd",
        ":validate_env_cmd",
    ],
    deps = ["@bazel_tools//tools/bash/runfiles"],
)
