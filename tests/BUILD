load("@rules_python//python:py_binary.bzl", "py_binary")
load("@rules_python//python:py_test.bzl", "py_test")
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")
load("@rules_shell//shell:sh_test.bzl", "sh_test")
load("//:defs.bzl", "command", "command_force_opt", "multirun")
load(":custom_executable.bzl", "custom_executable")
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

py_binary(
    name = "echo_stdin",
    srcs = ["echo_stdin.py"],
    visibility = ["//:__subpackages__"],
)

command(
    name = "echo_stdin_cmd",
    command = "echo_stdin",
)

py_binary(
    name = "echo_stdin2",
    srcs = ["echo_stdin2.py"],
    visibility = ["//:__subpackages__"],
)

command(
    name = "echo_stdin2_cmd",
    command = "echo_stdin2",
)

multirun(
    name = "multirun_echo_stdin",
    commands = [
        "echo_stdin_cmd",
        "echo_stdin2_cmd",
    ],
    forward_stdin = True,
    jobs = 0,
)

py_binary(
    name = "ibazel_capable_child",
    srcs = ["ibazel_child.py"],
    args = ["capable"],
    main = "ibazel_child.py",
    tags = ["ibazel_notify_changes"],
)

py_binary(
    name = "ibazel_plain_child",
    srcs = ["ibazel_child.py"],
    args = ["plain"],
    main = "ibazel_child.py",
)

py_binary(
    name = "ibazel_wrapped_child",
    srcs = ["ibazel_child.py"],
    args = ["wrapped"],
    main = "ibazel_child.py",
)

command(
    name = "ibazel_capable_command",
    arguments = ["wrapped"],
    command = ":ibazel_wrapped_child",
    ibazel_notify_changes_v1 = True,
)

multirun(
    name = "ibazel_multirun",
    commands = [
        ":ibazel_capable_child",
        ":ibazel_capable_command",
        ":ibazel_plain_child",
    ],
    ibazel_notify_changes = True,
)

py_test(
    name = "ibazel_streaming_test",
    srcs = ["ibazel_streaming_test.py"],
    args = ["$(rootpath :ibazel_multirun)"],
    data = [":ibazel_multirun"],
)

py_binary(
    name = "ibazel_restart_child",
    srcs = ["ibazel_restart_child.py"],
    main = "ibazel_restart_child.py",
)

command(
    name = "ibazel_restart_rpc",
    arguments = ["rpc"],
    command = ":ibazel_restart_child",
    data = ["ibazel_restart_rpc_input.txt"],
)

command(
    name = "ibazel_restart_electron",
    arguments = ["electron"],
    command = ":ibazel_restart_child",
    data = ["ibazel_restart_electron_input.txt"],
)

multirun(
    name = "ibazel_restart_multirun",
    commands = [
        ":ibazel_restart_rpc",
        ":ibazel_restart_electron",
    ],
    ibazel_notify_changes = True,
    ibazel_restart_affected_commands = True,
)

multirun(
    name = "ibazel_deferred_restart_multirun",
    commands = [
        ":ibazel_restart_rpc",
        ":ibazel_restart_electron",
    ],
    ibazel_defer_non_notification_commands = True,
    ibazel_notify_changes = True,
    ibazel_restart_affected_commands = True,
)

py_test(
    name = "ibazel_restart_test",
    srcs = ["ibazel_restart_test.py"],
    args = ["$(rootpath :ibazel_restart_multirun)"],
    data = [":ibazel_restart_multirun"],
)

py_test(
    name = "ibazel_deferred_restart_test",
    srcs = ["ibazel_restart_test.py"],
    args = [
        "$(rootpath :ibazel_deferred_restart_multirun)",
        "deferred",
    ],
    data = [":ibazel_deferred_restart_multirun"],
    main = "ibazel_restart_test.py",
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

sh_binary(
    name = "validate_binary_locations",
    srcs = ["validate-locations.sh"],
    args = ["$(rlocationpath :hello)"],
    data = [
        ":hello",
        ":hello2",
    ],
    env = {"FOO_ENV": "$(rlocationpath :hello2)"},
)

multirun(
    name = "multirun_binary_locations",
    commands = [":validate_binary_locations"],
)

custom_executable(
    name = "validate_custom_executable_rule_env",
)

command(
    name = "command_custom_executable_rule_env",
    command = ":validate_custom_executable_rule_env",
)

multirun(
    name = "multirun_custom_executable_rule_env",
    commands = [":validate_custom_executable_rule_env"],
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

sh_binary(
    name = "default_pwd",
    srcs = ["default-pwd.sh"],
)

command(
    name = "default_pwd_cmd",
    command = ":default_pwd",
)

sh_binary(
    name = "workspace_pwd",
    srcs = ["workspace-pwd.sh"],
)

command(
    name = "workspace_pwd_cmd",
    command = ":workspace_pwd",
    run_from_workspace_root = True,
)

sh_test(
    name = "test",
    srcs = ["test.sh"],
    data = [
        ":command_custom_executable_rule_env",
        ":default_pwd_cmd",
        ":echo_and_fail_cmd",
        ":hello",
        ":hello2",
        ":ibazel_deferred_restart_multirun",
        ":ibazel_restart_multirun",
        ":multirun_binary_args",
        ":multirun_binary_args_location",
        ":multirun_binary_env",
        ":multirun_binary_locations",
        ":multirun_custom_executable_rule_env",
        ":multirun_echo_stdin",
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
        ":workspace_pwd_cmd",
    ],
    deps = ["@bazel_tools//tools/bash/runfiles"],
)
