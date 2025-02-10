"Simple executable rule to exercise RunEnvironmentInfo handling"

def _custom_executable_impl(ctx):
    executable = ctx.actions.declare_file(ctx.label.name + ".bash")

    # Create the runfiles object
    runfiles = ctx.attr._bash_runfiles[DefaultInfo].default_runfiles

    # Write the script content to the executable
    ctx.actions.write(
        output = executable,
        content = """#!/bin/bash

set -euo pipefail

if [[ "$FOO_ENV" != "foo" ]]; then
  echo "error: expected FOO_ENV to be 'foo', got '$FOO_ENV'"
  exit 1
fi
""",
        is_executable = True,
    )

    return [
        DefaultInfo(
            files = depset([executable]),
            runfiles = runfiles,
            executable = executable,
        ),
        RunEnvironmentInfo(
            environment = {
                "FOO_ENV": "foo",
            },
        ),
    ]

custom_executable = rule(
    implementation = _custom_executable_impl,
    attrs = {
        "_bash_runfiles": attr.label(
            default = "@bazel_tools//tools/bash/runfiles",
        ),
    },
    executable = True,
)
