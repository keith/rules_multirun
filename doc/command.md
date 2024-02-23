<!-- Generated with Stardoc: http://skydoc.bazel.build -->

This is a simple rule for defining a runnable command that can be used in a
multirun definition

<a id="command"></a>

## command

<pre>
command(<a href="#command-name">name</a>, <a href="#command-data">data</a>, <a href="#command-arguments">arguments</a>, <a href="#command-command">command</a>, <a href="#command-description">description</a>, <a href="#command-environment">environment</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="command-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="command-data"></a>data |  The list of files needed by this command at runtime. See general comments about `data` at https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="command-arguments"></a>arguments |  List of command line arguments. Subject to $(location) expansion. See https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location   | List of strings | optional |  `[]`  |
| <a id="command-command"></a>command |  Target to run   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="command-description"></a>description |  A string describing the command printed during multiruns   | String | optional |  `""`  |
| <a id="command-environment"></a>environment |  Dictionary of environment variables. Subject to $(location) expansion. See https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |


<a id="command_force_opt"></a>

## command_force_opt

<pre>
command_force_opt(<a href="#command_force_opt-name">name</a>, <a href="#command_force_opt-data">data</a>, <a href="#command_force_opt-arguments">arguments</a>, <a href="#command_force_opt-command">command</a>, <a href="#command_force_opt-description">description</a>, <a href="#command_force_opt-environment">environment</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="command_force_opt-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="command_force_opt-data"></a>data |  The list of files needed by this command at runtime. See general comments about `data` at https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="command_force_opt-arguments"></a>arguments |  List of command line arguments. Subject to $(location) expansion. See https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location   | List of strings | optional |  `[]`  |
| <a id="command_force_opt-command"></a>command |  Target to run   | <a href="https://bazel.build/concepts/labels">Label</a> | required |  |
| <a id="command_force_opt-description"></a>description |  A string describing the command printed during multiruns   | String | optional |  `""`  |
| <a id="command_force_opt-environment"></a>environment |  Dictionary of environment variables. Subject to $(location) expansion. See https://docs.bazel.build/versions/master/skylark/lib/ctx.html#expand_location   | <a href="https://bazel.build/rules/lib/dict">Dictionary: String -> String</a> | optional |  `{}`  |


<a id="command_with_transition"></a>

## command_with_transition

<pre>
command_with_transition(<a href="#command_with_transition-cfg">cfg</a>, <a href="#command_with_transition-allowlist">allowlist</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="command_with_transition-cfg"></a>cfg |  <p align="center"> - </p>   |  none |
| <a id="command_with_transition-allowlist"></a>allowlist |  <p align="center"> - </p>   |  `None` |


