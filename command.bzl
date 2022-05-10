"""
This is a simple rule for defining a runnable command that can be used in a
multirun definition
"""

load("@bazel_skylib//lib:shell.bzl", "shell")
load("//internal:constants.bzl", "RUNFILES_PREFIX")

def _command_impl(ctx):
    runfiles = ctx.runfiles().merge(ctx.attr._bash_runfiles[DefaultInfo].default_runfiles)

    for data_dep in ctx.attr.data:
        default_runfiles = data_dep[DefaultInfo].default_runfiles
        if default_runfiles != None:
            runfiles = runfiles.merge(default_runfiles)

    default_info = ctx.attr.command[DefaultInfo]
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
    command_exec = " ".join(["exec ./%s" % shell.quote(executable.short_path)] + str_args + ['"$@"\n'])

    out_file = ctx.actions.declare_file(ctx.label.name + ".bash")
    ctx.actions.write(
        output = out_file,
        content = "\n".join([RUNFILES_PREFIX] + str_env + [command_exec]),
        is_executable = True,
    )
    return [
        DefaultInfo(
            files = depset([out_file]),
            runfiles = runfiles.merge(ctx.runfiles(files = ctx.files.data + [executable])),
            executable = out_file,
        ),
    ]

command = rule(
    implementation = _command_impl,
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
            cfg = "target",
        ),
        "_bash_runfiles": attr.label(
            default = Label("@bazel_tools//tools/bash/runfiles"),
        ),
    },
    executable = True,
)
