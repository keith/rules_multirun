# rules_multirun

These rules provide a simple interface for running multiple commands in
parallel with a single `bazel run` invocation. This is especially useful
for running multiple linters or formatters with a single command.

## Usage

Setup the tools you want to run:

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

Run the `multirun` target with bazel:

```sh
$ bazel run //:lint
```

See [the full API docs](doc) for more info.

## Usage with platform transitions

In case if the `multirun` rule requires a transition to other configuration than `target` then
a new `multirun`-like rule can be defined as in the following example
```bzl
load("@rules_multirun//:defs.bzl", "multirun_with_transition")

def _aws_deploy_platforms_impl(settings, attr):
    return {"//command_line_option:platforms": [":aws_lambda"]}

aws_deploy_transition = transition(
    implementation = _aws_deploy_platforms_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

aws_deploy = multirun_with_transition(
    aws_deploy_transition,
    "@bazel_tools//tools/allowlists/function_transition_allowlist"
)
```
and used in a `BUILD` file
```bzl
aws_deploy(
    name = "staging",
    commands = [
       ...
    ]
)
```


## Windows

`command` and `multirun` targets generate a Bash script, so they need a Bash
installation such as [MSYS2](https://www.msys2.org) or Git Bash. Windows cannot
execute a Bash script directly, so on Windows a `.bat` launcher is generated
alongside it and used as the target's executable. The launcher picks a shell
from `BAZEL_SH`, the registered `sh` toolchain, or `PATH`, in that order.

Windows also has to be configured to materialize a runfiles tree, because
`multirun` runs its commands from a nested binary that cannot locate them from
a runfiles manifest alone:

```
startup --windows_enable_symlinks
build --enable_runfiles
```

Creating symlinks requires Developer Mode to be enabled, or an elevated shell.


## Installation

Go to the [releases
page](https://github.com/keith/rules_multirun/releases) to grab the
WORKSPACE snippet for the latest release.

## Acknowledgements

This is a fork of the [original multirun
rules](https://github.com/ash2k/bazel-tools). Those rules have a
dependency on golang to run, which may not be desired, these rules use a
[python script](internal/multirun.py) instead.
