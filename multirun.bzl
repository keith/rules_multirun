"""
Multirun is a rule for running multiple commands in a single invocation. This
can be very useful for something like running multiple linters or formatters
in a single invocation.
"""

load("@bazel_skylib//lib:shell.bzl", "shell")
load(
    "//internal:constants.bzl",
    "CommandInfo",
    "IBazelInfo",
    "RUNFILES_PREFIX",
    "rlocation_path",
    "update_attrs",
)

_BinaryArgsEnvInfo = provider(
    fields = ["args", "env", "ibazel_notify_changes", "ibazel_notify_changes_v1"],
    doc = "The arguments and environment to use when running the binary",
)

def _ibazel_command_label(label):
    value = str(label)
    if value.startswith("@@//"):
        return value[2:]
    if value.startswith("@//"):
        return value[1:]
    return value

def _binary_args_env_aspect_impl(target, ctx):
    if _BinaryArgsEnvInfo in target:
        return []

    is_executable = target.files_to_run != None and target.files_to_run.executable != None
    args = getattr(ctx.rule.attr, "args", [])
    env = dict(getattr(ctx.rule.attr, "env", {}))
    tags = getattr(ctx.rule.attr, "tags", [])
    ibazel_notify_changes_v1 = "ibazel_notify_changes_v1" in tags
    ibazel_notify_changes = "ibazel_notify_changes" in tags or ibazel_notify_changes_v1
    if IBazelInfo in target:
        ibazel_notify_changes = target[IBazelInfo].notify_changes
        ibazel_notify_changes_v1 = target[IBazelInfo].notify_changes_v1

    if RunEnvironmentInfo in target:
        env.update(target[RunEnvironmentInfo].environment)

    if is_executable and (args or env or ibazel_notify_changes):
        expansion_targets = getattr(ctx.rule.attr, "data", [])
        if expansion_targets:
            args = [
                ctx.expand_location(arg, expansion_targets)
                for arg in args
            ]
            env = {
                name: ctx.expand_location(val, expansion_targets)
                for name, val in env.items()
            }
        return [_BinaryArgsEnvInfo(
            args = args,
            env = env,
            ibazel_notify_changes = ibazel_notify_changes,
            ibazel_notify_changes_v1 = ibazel_notify_changes_v1,
        )]

    return []

_binary_args_env_aspect = aspect(
    implementation = _binary_args_env_aspect_impl,
)

def _multirun_impl(ctx):
    instructions_file = ctx.actions.declare_file(ctx.label.name + ".json")
    runner_info = ctx.attr._runner[DefaultInfo]
    runner_exe = runner_info.files_to_run.executable

    transitive_runfiles = [
        ctx.attr._bash_runfiles[DefaultInfo].default_runfiles,
        runner_info.default_runfiles,
    ]

    for data_dep in ctx.attr.data:
        default_runfiles = data_dep[DefaultInfo].default_runfiles
        if default_runfiles != None:
            transitive_runfiles.append(default_runfiles)

    commands = []
    tagged_commands = []
    runfiles_files = []
    has_ibazel_notify_changes = False
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
        ibazel_notify_changes = False
        ibazel_notify_changes_v1 = False
        if _BinaryArgsEnvInfo in command:
            args = command[_BinaryArgsEnvInfo].args
            env = command[_BinaryArgsEnvInfo].env
            ibazel_notify_changes = command[_BinaryArgsEnvInfo].ibazel_notify_changes
            ibazel_notify_changes_v1 = command[_BinaryArgsEnvInfo].ibazel_notify_changes_v1
        has_ibazel_notify_changes = has_ibazel_notify_changes or ibazel_notify_changes

        default_runfiles = default_info.default_runfiles
        if default_runfiles != None:
            transitive_runfiles.append(default_runfiles)

        if CommandInfo in command:
            tag = command[CommandInfo].description
        else:
            tag = "Running {}".format(tag_command.tag)

        commands.append(struct(
            tag = tag,
            label = _ibazel_command_label(command.label),
            path = exe.short_path,
            args = args,
            env = env,
            ibazel_notify_changes = ibazel_notify_changes,
            ibazel_notify_changes_v1 = ibazel_notify_changes_v1,
        ))

    runfiles = ctx.runfiles(files = [instructions_file, runner_exe]).merge_all(transitive_runfiles)

    if ctx.attr.jobs < 0:
        fail("'jobs' attribute should be at least 0")
    elif ctx.attr.jobs > 0 and ctx.attr.forward_stdin:
        fail("'forward_stdin' can only apply to parallel jobs ('jobs' === 0)")
    elif ctx.attr.jobs > 0 and ctx.attr.ibazel_notify_changes:
        fail("'ibazel_notify_changes' can only apply to parallel jobs ('jobs' === 0)")
    elif ctx.attr.forward_stdin and ctx.attr.ibazel_notify_changes:
        fail("'forward_stdin' and 'ibazel_notify_changes' cannot both be enabled")
    elif ctx.attr.ibazel_restart_affected_commands and not ctx.attr.ibazel_notify_changes:
        fail("'ibazel_restart_affected_commands' requires 'ibazel_notify_changes'")
    elif ctx.attr.ibazel_defer_non_notification_commands and not ctx.attr.ibazel_notify_changes:
        fail("'ibazel_defer_non_notification_commands' requires 'ibazel_notify_changes'")
    elif ctx.attr.ibazel_notify_changes and not has_ibazel_notify_changes and not ctx.attr.ibazel_restart_affected_commands:
        fail("'ibazel_notify_changes' requires at least one capable command")

    jobs = ctx.attr.jobs
    instructions = struct(
        commands = commands,
        jobs = jobs,
        print_command = ctx.attr.print_command,
        keep_going = ctx.attr.keep_going,
        buffer_output = ctx.attr.buffer_output,
        forward_stdin = ctx.attr.forward_stdin,
        ibazel_notify_changes = ctx.attr.ibazel_notify_changes,
        ibazel_restart_affected_commands = ctx.attr.ibazel_restart_affected_commands,
        ibazel_defer_non_notification_commands = ctx.attr.ibazel_defer_non_notification_commands,
        workspace_name = ctx.workspace_name,
    )
    ctx.actions.write(
        output = instructions_file,
        content = json.encode(instructions),
    )

    script = """\
multirun_script="$(rlocation {})"
instructions="$(rlocation {})"
exec "$multirun_script" "$instructions" "$@"
""".format(shell.quote(rlocation_path(ctx, runner_exe)), shell.quote(rlocation_path(ctx, instructions_file)))
    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = RUNFILES_PREFIX + script,
        is_executable = True,
    )
    launcher_files = [out_file]
    if ctx.target_platform_has_constraint(ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]):
        bash_file = out_file
        out_file = ctx.actions.declare_file(ctx.label.name + ".bat")
        ctx.actions.write(
            output = out_file,
            content = """@echo off
setlocal
if not defined RUNFILES_DIR set "RUNFILES_DIR=%~f0.runfiles"
if not defined RUNFILES_MANIFEST_FILE set "RUNFILES_MANIFEST_FILE=%~f0.runfiles_manifest"
set "RUNFILES_DIR=%RUNFILES_DIR:\\=/%"
set "RUNFILES_MANIFEST_FILE=%RUNFILES_MANIFEST_FILE:\\=/%"
if not defined BAZEL_SH set "BAZEL_SH=bash.exe"
"%BAZEL_SH%" "%~dp0{bash}" %*
exit /b %ERRORLEVEL%
""".format(bash = bash_file.basename),
            is_executable = True,
        )
        launcher_files.append(out_file)
        runfiles = runfiles.merge(ctx.runfiles(files = [bash_file]))
    return [
        DefaultInfo(
            files = depset(launcher_files),
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
        "forward_stdin": attr.bool(
            default = False,
            doc = "Whether or not to forward stdin",
        ),
        "ibazel_notify_changes": attr.bool(
            default = False,
            doc = "Forward iBazel incremental build notifications only to commands that advertise the `ibazel_notify_changes` capability.",
        ),
        "ibazel_restart_affected_commands": attr.bool(
            default = False,
            doc = "Restart non-notification commands affected by structured iBazel changes. Falls back to restarting all such commands when ownership is incomplete.",
        ),
        "ibazel_defer_non_notification_commands": attr.bool(
            default = False,
            doc = "Start notification-capable commands immediately, then start other commands after the first successful structured iBazel build event.",
        ),
        "_windows_constraint": attr.label(
            default = Label("@platforms//os:windows"),
        ),
        "_bash_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
        "_runner": attr.label(
            default = Label("//internal:multirun"),
            cfg = "target",
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

_multirun = multirun_with_transition("target")

def multirun(name, tags = [], ibazel_notify_changes = False, ibazel_restart_affected_commands = False, ibazel_defer_non_notification_commands = False, **kwargs):
    """Runs multiple commands, optionally preserving iBazel notifications.

    Commands tagged `ibazel_notify_changes`, such as `js_run_devserver`, receive
    incremental build messages on stdin. With affected-command restarts enabled,
    other commands restart only when iBazel reports their Bazel labels as affected.

    Args:
        name: A unique name for this target.
        tags: Additional tags for the generated target.
        ibazel_notify_changes: Whether to enable iBazel notification forwarding.
            This also runs commands in parallel and advertises the legacy and
            structured protocols to iBazel.
        ibazel_restart_affected_commands: Whether to restart non-notification
            commands affected by each successful structured build event.
        ibazel_defer_non_notification_commands: Whether to wait for the first
            successful structured build event before starting non-notification
            commands. Notification-capable commands still start immediately.
        **kwargs: Additional `multirun` attributes.
    """
    if ibazel_restart_affected_commands and not ibazel_notify_changes:
        fail("'ibazel_restart_affected_commands' requires 'ibazel_notify_changes'")
    if ibazel_defer_non_notification_commands and not ibazel_notify_changes:
        fail("'ibazel_defer_non_notification_commands' requires 'ibazel_notify_changes'")

    if ibazel_notify_changes:
        if kwargs.get("jobs", 0) != 0:
            fail("'ibazel_notify_changes' requires parallel jobs ('jobs' === 0)")
        if kwargs.get("forward_stdin", False):
            fail("'forward_stdin' and 'ibazel_notify_changes' cannot both be enabled")
        kwargs["jobs"] = 0
        tags = tags + [
            "ibazel_live_reload",
            "ibazel_notify_changes",
            "ibazel_notify_changes_v1",
            "supports_incremental_build_protocol",
        ]

    _multirun(
        name = name,
        ibazel_notify_changes = ibazel_notify_changes,
        ibazel_restart_affected_commands = ibazel_restart_affected_commands,
        ibazel_defer_non_notification_commands = ibazel_defer_non_notification_commands,
        tags = tags,
        **kwargs
    )
