<!-- Generated with Stardoc: http://skydoc.bazel.build -->

These rules provide a simple interface for running multiple commands,
optionally in parallel, with a single bazel run invocation. This is especially
useful for running multiple linters or formatters with a single command.

<a id="command"></a>

## command

<pre>
load("@rules_multirun//:defs.bzl", "command")

command(<a href="#command-name">name</a>, <a href="#command-data">data</a>, <a href="#command-arguments">arguments</a>, <a href="#command-command">command</a>, <a href="#command-description">description</a>, <a href="#command-environment">environment</a>, <a href="#command-ibazel_notify_changes">ibazel_notify_changes</a>,
        <a href="#command-ibazel_notify_changes_v1">ibazel_notify_changes_v1</a>, <a href="#command-run_from_workspace_root">run_from_workspace_root</a>)
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
| <a id="command-ibazel_notify_changes"></a>ibazel_notify_changes |  Forward legacy iBazel incremental build notifications to this command when its `multirun` enables notification forwarding.   | Boolean | optional |  `False`  |
| <a id="command-ibazel_notify_changes_v1"></a>ibazel_notify_changes_v1 |  Also forward structured `IBAZEL_EVENT` notifications to this command. This implies `ibazel_notify_changes`.   | Boolean | optional |  `False`  |
| <a id="command-run_from_workspace_root"></a>run_from_workspace_root |  If true, the command will be run from the workspace root instead of the execution root   | Boolean | optional |  `False`  |


<a id="command_force_opt"></a>

## command_force_opt

<pre>
load("@rules_multirun//:defs.bzl", "command_force_opt")

command_force_opt(<a href="#command_force_opt-name">name</a>, <a href="#command_force_opt-data">data</a>, <a href="#command_force_opt-arguments">arguments</a>, <a href="#command_force_opt-command">command</a>, <a href="#command_force_opt-description">description</a>, <a href="#command_force_opt-environment">environment</a>, <a href="#command_force_opt-ibazel_notify_changes">ibazel_notify_changes</a>,
                  <a href="#command_force_opt-ibazel_notify_changes_v1">ibazel_notify_changes_v1</a>, <a href="#command_force_opt-run_from_workspace_root">run_from_workspace_root</a>)
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
| <a id="command_force_opt-ibazel_notify_changes"></a>ibazel_notify_changes |  Forward legacy iBazel incremental build notifications to this command when its `multirun` enables notification forwarding.   | Boolean | optional |  `False`  |
| <a id="command_force_opt-ibazel_notify_changes_v1"></a>ibazel_notify_changes_v1 |  Also forward structured `IBAZEL_EVENT` notifications to this command. This implies `ibazel_notify_changes`.   | Boolean | optional |  `False`  |
| <a id="command_force_opt-run_from_workspace_root"></a>run_from_workspace_root |  If true, the command will be run from the workspace root instead of the execution root   | Boolean | optional |  `False`  |


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


<a id="multirun"></a>

## multirun

<pre>
load("@rules_multirun//:defs.bzl", "multirun")

multirun(<a href="#multirun-name">name</a>, <a href="#multirun-tags">tags</a>, <a href="#multirun-ibazel_notify_changes">ibazel_notify_changes</a>, <a href="#multirun-ibazel_restart_affected_commands">ibazel_restart_affected_commands</a>,
         <a href="#multirun-ibazel_defer_non_notification_commands">ibazel_defer_non_notification_commands</a>, <a href="#multirun-kwargs">**kwargs</a>)
</pre>

Runs multiple commands, optionally preserving iBazel notifications.

Commands tagged `ibazel_notify_changes`, such as `js_run_devserver`, receive
incremental build messages on stdin. With affected-command restarts enabled,
other commands restart only when iBazel reports their Bazel labels as affected.


**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="multirun-name"></a>name |  A unique name for this target.   |  none |
| <a id="multirun-tags"></a>tags |  Additional tags for the generated target.   |  `[]` |
| <a id="multirun-ibazel_notify_changes"></a>ibazel_notify_changes |  Whether to enable iBazel notification forwarding. This also runs commands in parallel and advertises the legacy and structured protocols to iBazel.   |  `False` |
| <a id="multirun-ibazel_restart_affected_commands"></a>ibazel_restart_affected_commands |  Whether to restart non-notification commands affected by each successful structured build event.   |  `False` |
| <a id="multirun-ibazel_defer_non_notification_commands"></a>ibazel_defer_non_notification_commands |  Whether to wait for the first successful structured build event before starting non-notification commands. Notification-capable commands still start immediately.   |  `False` |
| <a id="multirun-kwargs"></a>kwargs |  Additional `multirun` attributes.   |  none |


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


