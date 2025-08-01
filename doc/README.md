<!-- Generated with Stardoc: http://skydoc.bazel.build -->

These rules provide a simple interface for running multiple commands,
optionally in parallel, with a single bazel run invocation. This is especially
useful for running multiple linters or formatters with a single command.

<a id="command"></a>

## command

<pre>
load("@rules_multirun//:defs.bzl", "command")

command(<a href="#command-name">name</a>, <a href="#command-data">data</a>, <a href="#command-arguments">arguments</a>, <a href="#command-command">command</a>, <a href="#command-description">description</a>, <a href="#command-environment">environment</a>, <a href="#command-run_from_workspace_root">run_from_workspace_root</a>)
</pre>

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

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="command-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="command-data"></a>data |  The list of files needed by this command at runtime. See general comments about `data` in Bazel's [typical attributes](https://bazel.build/reference/be/common-definitions#typical-attributes) docs.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="command-arguments"></a>arguments |  List of command line arguments. Subject to [`$(location)` expansion](https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location). Note that `args` defined on the target of the command aren't available to starlark code so may need to be duplicated here; see [#77](https://github.com/keith/rules_multirun/issues/77).   | List of strings | optional |  `[]`  |
| <a id="command-command"></a>command |  Target to run   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="command-description"></a>description |  A string describing the command printed during multiruns   | String | optional |  `""`  |
| <a id="command-environment"></a>environment |  Dictionary of environment variables. Subject to [`$(location)` expansion](https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="command-run_from_workspace_root"></a>run_from_workspace_root |  If true, the command will be run from the workspace root instead of the execution root   | Boolean | optional |  `False`  |


<a id="command_force_opt"></a>

## command_force_opt

<pre>
load("@rules_multirun//:defs.bzl", "command_force_opt")

command_force_opt(<a href="#command_force_opt-name">name</a>, <a href="#command_force_opt-data">data</a>, <a href="#command_force_opt-arguments">arguments</a>, <a href="#command_force_opt-command">command</a>, <a href="#command_force_opt-description">description</a>, <a href="#command_force_opt-environment">environment</a>, <a href="#command_force_opt-run_from_workspace_root">run_from_workspace_root</a>)
</pre>

A command that forces the compilation mode of the dependent targets to opt. This can be useful if your tools have improved performance if built with optimizations. See the documentation for command for more examples. If you'd like to always use this variation you can import this directly and rename it for convenience like:

```bzl
load("@rules_multirun//:defs.bzl", "multirun", command = "command_force_opt")
```

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="command_force_opt-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="command_force_opt-data"></a>data |  The list of files needed by this command at runtime. See general comments about `data` in Bazel's [typical attributes](https://bazel.build/reference/be/common-definitions#typical-attributes) docs.   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="command_force_opt-arguments"></a>arguments |  List of command line arguments. Subject to [`$(location)` expansion](https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location). Note that `args` defined on the target of the command aren't available to starlark code so may need to be duplicated here; see [#77](https://github.com/keith/rules_multirun/issues/77).   | List of strings | optional |  `[]`  |
| <a id="command_force_opt-command"></a>command |  Target to run   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="command_force_opt-description"></a>description |  A string describing the command printed during multiruns   | String | optional |  `""`  |
| <a id="command_force_opt-environment"></a>environment |  Dictionary of environment variables. Subject to [`$(location)` expansion](https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location)   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |
| <a id="command_force_opt-run_from_workspace_root"></a>run_from_workspace_root |  If true, the command will be run from the workspace root instead of the execution root   | Boolean | optional |  `False`  |


<a id="multirun"></a>

## multirun

<pre>
load("@rules_multirun//:defs.bzl", "multirun")

multirun(<a href="#multirun-name">name</a>, <a href="#multirun-data">data</a>, <a href="#multirun-buffer_output">buffer_output</a>, <a href="#multirun-commands">commands</a>, <a href="#multirun-forward_stdin">forward_stdin</a>, <a href="#multirun-jobs">jobs</a>, <a href="#multirun-keep_going">keep_going</a>, <a href="#multirun-print_command">print_command</a>)
</pre>

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

**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="multirun-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="multirun-data"></a>data |  The list of files needed by the commands at runtime. See general comments about `data` at https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="multirun-buffer_output"></a>buffer_output |  Buffer the output of the commands and print it after each command has finished. Only for parallel execution.   | Boolean | optional |  `False`  |
| <a id="multirun-commands"></a>commands |  Targets to run   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="multirun-forward_stdin"></a>forward_stdin |  Whether or not to forward stdin   | Boolean | optional |  `False`  |
| <a id="multirun-jobs"></a>jobs |  The expected concurrency of targets to be executed. Default is set to 1 which means sequential execution. Setting to 0 means that there is no limit concurrency.   | Integer | optional |  `1`  |
| <a id="multirun-keep_going"></a>keep_going |  Keep going after a command fails. Only for sequential execution.   | Boolean | optional |  `False`  |
| <a id="multirun-print_command"></a>print_command |  Print what command is being run before running it.   | Boolean | optional |  `True`  |


<a id="command_with_transition"></a>

## command_with_transition

<pre>
load("@rules_multirun//:defs.bzl", "command_with_transition")

command_with_transition(<a href="#command_with_transition-cfg">cfg</a>, <a href="#command_with_transition-allowlist">allowlist</a>, <a href="#command_with_transition-doc">doc</a>)
</pre>

Create a command rule with a transition to the given configuration.

This is useful if you have a project-specific configuration that you want
to apply to all of your commands. See also multirun_with_transition.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="command_with_transition-cfg"></a>cfg |  The transition to force on the dependent targets.   |  none |
| <a id="command_with_transition-allowlist"></a>allowlist |  The transition allowlist to use for the given cfg. Not necessary in newer bazel versions.   |  `None` |
| <a id="command_with_transition-doc"></a>doc |  The documentation to use for the rule. Only necessary if you're generating documentation with stardoc for your custom rules.   |  `None` |


<a id="multirun_with_transition"></a>

## multirun_with_transition

<pre>
load("@rules_multirun//:defs.bzl", "multirun_with_transition")

multirun_with_transition(<a href="#multirun_with_transition-cfg">cfg</a>, <a href="#multirun_with_transition-allowlist">allowlist</a>)
</pre>

Creates a multirun rule which transitions all commands to the given configuration.

This is useful if you have a project-specific configuration that you want
to apply to all of your commands. See also command_with_transition.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="multirun_with_transition-cfg"></a>cfg |  The transition to force on the dependent commands.   |  none |
| <a id="multirun_with_transition-allowlist"></a>allowlist |  The transition allowlist to use for the given cfg. Not necessary in newer bazel versions.   |  `None` |


