# rules_multirun

These rules provide a simple interface for running multiple commands in
parallel with a single `bazel run` invocation. This is especially useful
for running multiple linters or formatters with a single command.

## Usage

Setup the tools you want to run:

```bzl
load("@rules_multirun//:defs.bzl", "command", "multirun")

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

## Installation

Go to the [releases
page](https://github.com/keith/rules_multirun/releases) to grab the
WORKSPACE snippet for the latest release.

## Acknowledgements

This is a fork of the [original multirun
rules](https://github.com/ash2k/bazel-tools). Those rules have a
dependency on golang to run, which may not be desired, these rules use a
[python script](internal/multirun.py) instead.
