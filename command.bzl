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

def _force_opt_impl(_settings, _attr):
    return {"//command_line_option:compilation_mode": "opt"}

_force_opt = transition(
    implementation = _force_opt_impl,
    inputs = [],
    outputs = ["//command_line_option:compilation_mode"],
)

def _rlocation_path(ctx, file):
    """Produce the rlocation lookup path for the given file.

    See https://github.com/bazelbuild/bazel-skylib/issues/303.
    """
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    else:
        return ctx.workspace_name + "/" + file.short_path

def _command_impl(ctx):
    runfiles = ctx.runfiles().merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)

    for data_dep in ctx.attr.data:
        default_runfiles = data_dep[DefaultInfo].default_runfiles
        if default_runfiles != None:
            runfiles = runfiles.merge(default_runfiles)

    command = ctx.attr.command if type(ctx.attr.command) == "Target" else ctx.attr.command[0]
    default_info = command[DefaultInfo]
    executable = default_info.files_to_run.executable

    default_runfiles = default_info.default_runfiles
    if default_runfiles != None:
        runfiles = runfiles.merge(default_runfiles)

    expansion_targets = ctx.attr.data

    str_env = [
        "export %s=%s" % (k, shell.quote(ctx.expand_location(v, targets = expansion_targets)))
        for k, v in ctx.attr.environment.items()
    ]
    str_args = [
        "%s" % shell.quote(ctx.expand_location(v, targets = expansion_targets))
        for v in ctx.attr.arguments
    ]
    command_exec = " ".join(["exec $(rlocation %s)" % shell.quote(_rlocation_path(ctx, executable))] + str_args + ['"$@"\n'])

    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = "\n".join([RUNFILES_PREFIX] + str_env + [command_exec]),
        is_executable = True,
    )

    providers = [
        DefaultInfo(
            files = depset([out_file]),
            runfiles = runfiles.merge(ctx.runfiles(files = ctx.files.data + [executable])),
            executable = out_file,
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
