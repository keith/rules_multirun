"""
These rules provide a simple interface for running multiple commands,
optionally in parallel, with a single bazel run invocation. This is especially
useful for running multiple linters or formatters with a single command.
"""

load(":command.bzl", _command = "command", _command_force_opt = "command_force_opt", _command_with_transition = "command_with_transition")
load(":multirun.bzl", _multirun = "multirun", _multirun_with_transition = "multirun_with_transition")

command = _command
command_force_opt = _command_force_opt
command_with_transition = _command_with_transition

multirun = _multirun
multirun_with_transition = _multirun_with_transition
