load("//:defs.bzl", "multirun_with_transition")

def _platform_transition_impl(settings, attr):
    return {"//command_line_option:platforms": [":lambda"]}

platform_transition = transition(
    implementation = _platform_transition_impl,
    inputs = [],
    outputs = ["//command_line_option:platforms"],
)

multirun_lambda = multirun_with_transition(
    platform_transition,
    "@bazel_tools//tools/allowlists/function_transition_allowlist",
)
