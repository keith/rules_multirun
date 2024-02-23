<!-- Generated with Stardoc: http://skydoc.bazel.build -->

Multirun is a rule for running multiple commands in a single invocation. This
can be very useful for something like running multiple linters or formatters
in a single invocation.

<a id="multirun"></a>

## multirun

<pre>
multirun(<a href="#multirun-name">name</a>, <a href="#multirun-data">data</a>, <a href="#multirun-buffer_output">buffer_output</a>, <a href="#multirun-commands">commands</a>, <a href="#multirun-jobs">jobs</a>, <a href="#multirun-keep_going">keep_going</a>, <a href="#multirun-print_command">print_command</a>)
</pre>



**ATTRIBUTES**


| Name  | Description | Type | Mandatory | Default |
| :------------- | :------------- | :------------- | :------------- | :------------- |
| <a id="multirun-name"></a>name |  A unique name for this target.   | <a href="https://bazel.build/concepts/labels#target-names">Name</a> | required |  |
| <a id="multirun-data"></a>data |  The list of files needed by the commands at runtime. See general comments about `data` at https://docs.bazel.build/versions/master/be/common-definitions.html#common-attributes   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="multirun-buffer_output"></a>buffer_output |  Buffer the output of the commands and print it after the command has finished. Only for parallel execution.   | Boolean | optional |  `True`  |
| <a id="multirun-commands"></a>commands |  Targets to run   | <a href="https://bazel.build/concepts/labels">List of labels</a> | optional |  `[]`  |
| <a id="multirun-jobs"></a>jobs |  The expected concurrency of targets to be executed. Default is set to 1 which means sequential execution. Setting to 0 means that there is no limit concurrency.   | Integer | optional |  `1`  |
| <a id="multirun-keep_going"></a>keep_going |  Keep going after a command fails. Only for sequential execution.   | Boolean | optional |  `False`  |
| <a id="multirun-print_command"></a>print_command |  Print what command is being run before running it.   | Boolean | optional |  `True`  |


<a id="multirun_with_transition"></a>

## multirun_with_transition

<pre>
multirun_with_transition(<a href="#multirun_with_transition-cfg">cfg</a>, <a href="#multirun_with_transition-allowlist">allowlist</a>)
</pre>



**PARAMETERS**


| Name  | Description | Default Value |
| :------------- | :------------- | :------------- |
| <a id="multirun_with_transition-cfg"></a>cfg |  <p align="center"> - </p>   |  none |
| <a id="multirun_with_transition-allowlist"></a>allowlist |  <p align="center"> - </p>   |  `None` |


