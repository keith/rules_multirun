"""
Multirun is a rule for running multiple commands in a single invocation. This
can be very useful for something like running multiple linters or formatters
in a single invocation.
"""

load("@bazel_skylib//lib:shell.bzl", "shell")
load(
    "//internal:constants.bzl",
    "CommandInfo",
    "RUNFILES_PREFIX",
    "rlocation_path",
    "update_attrs",
)

_BinaryArgsEnvInfo = provider(
    fields = ["args", "env"],
    doc = "The arguments and environment to use when running the binary",
)

def _binary_args_env_aspect_impl(target, ctx):
    if _BinaryArgsEnvInfo in target:
        return []

    is_executable = target.files_to_run != None and target.files_to_run.executable != None
    args = getattr(ctx.rule.attr, "args", [])
    env = getattr(ctx.rule.attr, "env", {})

    if is_executable and (args or env):
        expansion_targets = getattr(ctx.rule.attr, "data")
        if expansion_targets:
            args = [
                ctx.expand_location(arg, expansion_targets)
                for arg in args
            ]
            env = {
                name: ctx.expand_location(val, expansion_targets)
                for name, val in env.items()
            }
        return [_BinaryArgsEnvInfo(args = args, env = env)]

    return []

_binary_args_env_aspect = aspect(
    implementation = _binary_args_env_aspect_impl,
)

def _multirun_impl(ctx):
    instructions_file = ctx.actions.declare_file(ctx.label.name + ".json")
    runner_info = ctx.attr._runner[DefaultInfo]
    runner_exe = runner_info.files_to_run.executable

    runfiles = ctx.runfiles(files = [instructions_file, runner_exe])
    runfiles = runfiles.merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)
    runfiles = runfiles.merge(runner_info.default_runfiles)

    for data_dep in ctx.attr.data:
        default_runfiles = data_dep[DefaultInfo].default_runfiles
        if default_runfiles != None:
            runfiles = runfiles.merge(default_runfiles)

    commands = []
    tagged_commands = []
    runfiles_files = []
    for command in ctx.attr.commands:
        tagged_commands.append(struct(tag = str(command.label), command = command))

    for tag_command in tagged_commands:
        command = tag_command.command

        default_info = command[DefaultInfo]
        if default_info.files_to_run == None:
            fail("%s is not executable" % command.label, attr = "commands")
        exe = default_info.files_to_run.executable
        if exe == None:
            fail("%s does not have an executable file" % command.label, attr = "commands")
        runfiles_files.append(exe)

        args = []
        env = {}
        if _BinaryArgsEnvInfo in command:
            args = command[_BinaryArgsEnvInfo].args
            env = command[_BinaryArgsEnvInfo].env

        default_runfiles = default_info.default_runfiles
        if default_runfiles != None:
            runfiles = runfiles.merge(default_runfiles)

        if CommandInfo in command:
            tag = command[CommandInfo].description
        else:
            tag = "Running {}".format(tag_command.tag)

        commands.append(struct(
            tag = tag,
            path = exe.short_path,
            args = args,
            env = env,
        ))

    if ctx.attr.jobs < 0:
        fail("'jobs' attribute should be at least 0")

    jobs = ctx.attr.jobs
    instructions = struct(
        commands = commands,
        jobs = jobs,
        print_command = ctx.attr.print_command,
        keep_going = ctx.attr.keep_going,
        buffer_output = ctx.attr.buffer_output,
    )
    ctx.actions.write(
        output = instructions_file,
        content = instructions.to_json(),
    )

    script = """\
multirun_script="$(rlocation {})"
instructions="$(rlocation {})"
exec "$multirun_script" -f "$instructions"
""".format(shell.quote(rlocation_path(ctx, runner_exe)), shell.quote(rlocation_path(ctx, instructions_file)))
    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = RUNFILES_PREFIX + script,
        is_executable = True,
    )
    return [
        DefaultInfo(
            files = depset([out_file]),
            runfiles = runfiles.merge(ctx.runfiles(files = runfiles_files + ctx.files.data)),
            executable = out_file,
        ),
    ]

def multirun_with_transition(cfg, allowlist = None):
    """Creates a multirun rule which transitions all commands to the given configuration.

    This is useful if you have a project-specific configuration that you want
    to apply to all of your commands. See also command_with_transition.

    Args:
        cfg: The transition to force on the dependent commands.
        allowlist: The transition allowlist to use for the given cfg. Not necessary in newer bazel versions.
    """
    attrs = {
        "commands": attr.label_list(
            mandatory = False,
            allow_files = True,
            aspects = [_binary_args_env_aspect],
            doc = "Targets to run",
            cfg = cfg,
        ),
        "data": attr.label_list(
            doc = "The list of files needed by the commands at runtime. See general comments about `data` at https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes",
            allow_files = True,
        ),
        "jobs": attr.int(
            default = 1,
            doc = "The expected concurrency of targets to be executed. Default is set to 1 which means sequential execution. Setting to 0 means that there is no limit concurrency.",
        ),
        "print_command": attr.bool(
            default = True,
            doc = "Print what command is being run before running it.",
        ),
        "keep_going": attr.bool(
            default = False,
            doc = "Keep going after a command fails. Only for sequential execution.",
        ),
        "buffer_output": attr.bool(
            default = False,
            doc = "Buffer the output of the commands and print it after each command has finished. Only for parallel execution.",
        ),
        "_bash_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
        "_runner": attr.label(
            default = Label("//internal:multirun"),
            cfg = "exec",
            executable = True,
        ),
    }

    return rule(
        implementation = _multirun_impl,
        attrs = update_attrs(attrs, cfg, allowlist),
        executable = True,
        doc = """\
A multirun composes multiple command rules in order to run them in a single
bazel invocation, optionally in parallel. This can have a major performance
improvement both in build time and run time depending on your tools.

```bzl
load("@rules_multirun//:defs.bzl", "command", "multirun")
load("@rules_python//python:defs.bzl", "py_binary")

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

multirun(
    name = "lint",
    commands = [
        "lint-something",
        "lint-something-else",
    ],
    jobs = 0, # Set to 0 to run in parallel, defaults to sequential
)
```

With this configuration you can `bazel run :lint` and it will run both both
linters in parallel. If you would like to run them serially you can omit the `jobs` attribute.

NOTE: If your commands change files in the workspace you might want to prefer
sequential execution to avoid race conditions when changing the same file from
multiple tools.
""",
    )

multirun = multirun_with_transition("target")
