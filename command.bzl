"""
This is a simple rule for defining a runnable command that can be used in a
multirun definition
"""

load("@bazel_skylib//lib:shell.bzl", "shell")
load(
    "//internal:constants.bzl",
    "CommandInfo",
    "RUNFILES_PREFIX",
    "update_attrs",
)
load("//internal/bazel-lib:windows_utils.bzl", "BATCH_RLOCATION_FUNCTION")
load("@aspect_bazel_lib//lib:paths.bzl", "BASH_RLOCATION_FUNCTION", "to_rlocation_path")

_COMMAND_LAUNCHER_BAT_TMPL = """@echo off
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION
set RUNFILES_LIB_DEBUG=0
{BATCH_RLOCATION_FUNCTION}
{envs}

call :rlocation "{command}" command_path
::echo rlocation({command}) returns %command_path%
::echo command bat launcher
::echo RUNFILES_MANIFEST_FILE=!RUNFILES_MANIFEST_FILE!
::echo launching: {exec}%command_path% {args}
{exec}%command_path% {args}
"""

def _force_opt_impl(_settings, _attr):
    return {"//command_line_option:compilation_mode": "opt"}

_force_opt = transition(
    implementation = _force_opt_impl,
    inputs = [],
    outputs = ["//command_line_option:compilation_mode"],
)

def _command_impl(ctx):
    is_windows = ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo])
    command = ctx.attr.command if type(ctx.attr.command) == "Target" else ctx.attr.command[0]
    executable = command[DefaultInfo].files_to_run.executable

    expansion_targets = ctx.attr.data
    shell_type = "bash" if not is_windows or executable.extension in ["bash", "sh"] else "cmd"
    if (shell_type == "bash"):
        str_args = [
            "%s" % shell.quote(ctx.expand_location(v, targets = expansion_targets))
            for v in ctx.attr.arguments
        ]
    else:
        str_args = [
            "%s" % shell.quote(ctx.expand_location(v, targets = expansion_targets))
            for v in ctx.attr.arguments
        ]

    if not is_windows:    
        str_env = [
            "export %s=%s" % (k, shell.quote(ctx.expand_location(v, targets = expansion_targets)))
            for k, v in ctx.attr.environment.items()
        ]
        command_exec = " ".join(["exec $(rlocation %s)" % shell.quote(to_rlocation_path(ctx, executable))] + str_args + ['"$@"\n'])
        #print(command_exec)
        launcher = ctx.actions.declare_file(ctx.label.name + ".bash")
        ctx.actions.write(
            output = launcher,
            content = "\n".join([RUNFILES_PREFIX] + str_env + [command_exec]),
            is_executable = True,
        )
    else:
        str_env = [
            "set \"%s=%s\"" % (k, ctx.expand_location(v, targets = expansion_targets))
            for k, v in ctx.attr.environment.items()
        ]
        launcher = ctx.actions.declare_file(ctx.label.name + ".bat")
        ctx.actions.write(
            output = launcher,
            content = _COMMAND_LAUNCHER_BAT_TMPL.format(
                envs = "\n".join(str_env),
                exec = "%BAZEL_SH% " if shell_type == "bash" else "",
                command = to_rlocation_path(ctx, executable),
                args = " ".join(str_args),
                BATCH_RLOCATION_FUNCTION = BATCH_RLOCATION_FUNCTION,
            ),
            is_executable = True,
        )

    runfiles = ctx.runfiles(files = ctx.files.data + ctx.files._bash_runfiles + [executable])
    runfiles = runfiles.merge_all([
        d[DefaultInfo].default_runfiles
        for d in ctx.attr.data + [command]
    ])

    providers = [
        DefaultInfo(
            files = depset([launcher]),
            runfiles = runfiles,
            executable = launcher,
        ),
    ]

    if ctx.attr.description:
        providers.append(
            CommandInfo(
                description = ctx.attr.description,
            ),
        )

    return providers

def command_with_transition(cfg, allowlist = None, doc = None):
    """Create a command rule with a transition to the given configuration.

    This is useful if you have a project-specific configuration that you want
    to apply to all of your commands. See also multirun_with_transition.

    Args:
        cfg: The transition to force on the dependent targets.
        allowlist: The transition allowlist to use for the given cfg. Not necessary in newer bazel versions.
        doc: The documentation to use for the rule. Only necessary if you're generating documentation with stardoc for your custom rules.
    """

    attrs = {
        "arguments": attr.string_list(
            doc = "List of command line arguments. Subject to $(location) expansion. See https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location",
        ),
        "data": attr.label_list(
            doc = "The list of files needed by this command at runtime. See general comments about `data` at https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes",
            allow_files = True,
        ),
        "environment": attr.string_dict(
            doc = "Dictionary of environment variables. Subject to $(location) expansion. See https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location",
        ),
        "command": attr.label(
            mandatory = True,
            allow_files = True,
            executable = True,
            doc = "Target to run",
            cfg = cfg,
        ),
        "description": attr.string(
            doc = "A string describing the command printed during multiruns",
        ),
        "_bash_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
        "_windows_constraint": attr.label(
            default = "@platforms//os:windows"
        ),
    }

    return rule(
        implementation = _command_impl,
        attrs = update_attrs(attrs, cfg, allowlist),
        executable = True,
        doc = doc or """\
A command is a wrapper rule for some other target that can be run like a
command line tool. You can customize the command to run with specific arguments
or environment variables you would like to be passed. Then you can compose
multiple commands into a multirun rule to run them in a single bazel
invocation, and in parallel if desired.

```bzl
load("@rules_multirun//:defs.bzl", "multirun", "command")

sh_binary(
    name = "some_linter",
    ...
)

py_binary(
    name = "some_other_linter",
    ...
)

command(
    name = "lint-something",
    command = ":some_linter",
    arguments = ["check"], # Optional arguments passed directly to the tool
)

command(
    name = "lint-something-else",
    command = ":some_other_linter",
    environment = {"CHECK": "true"}, # Optional environment variables set when invoking the command
    data = ["..."] # Optional runtime data dependencies
)
```
    """,
    )

command = command_with_transition("target")
command_force_opt = command_with_transition(
    _force_opt,
    doc = """\
A command that forces the compilation mode of the dependent targets to opt. This can be useful if your tools have improved performance if built with optimizations. See the documentation for command for more examples. If you'd like to always use this variation you can import this directly and rename it for convenience like:

```bzl
load("@rules_multirun//:defs.bzl", "multirun", command = "command_force_opt")
```
    """,
)
