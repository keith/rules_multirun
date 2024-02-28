"""Internal constants shared between multiple bzl files"""

# https://github.com/bazelbuild/bazel/blob/4ff441b13db6b6f5d5d317881c6383f510709b19/tools/bash/runfiles/runfiles.bash#L50-L64

RUNFILES_PREFIX = """#!/bin/bash

# --- begin runfiles.bash initialization v2 ---
# Copy-pasted from the Bazel Bash runfiles library v2.
set -uo pipefail; f=bazel_tools/tools/bash/runfiles/runfiles.bash
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \\
 source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \\
 source "$0.runfiles/$f" 2>/dev/null || \\
 source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \\
 source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \\
 { echo>&2 "ERROR: cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v2 ---

# Export RUNFILES_* envvars (and a couple more) for subprocesses.
runfiles_export_envvars

"""

CommandInfo = provider(
    fields = ["description"],
    doc = "Information about commands used by their multirun.",
)

def update_attrs(attrs, cfg, allowlist):
    """Conditionally update attributes.

    Args:
        attrs: Attributes dictionary.
        cfg: The command configuration.
        allowlist: Optional allow list label that will be applied to the configuration transition.
    Returns:
        Updated attributes dictionary.
    """
    if type(cfg) == "transition":
        # Configurations declared as StarlarkDefinedConfigTransition instances
        # (https://github.com/bazelbuild/bazel/blob/e2189245/src/main/java/com/google/devtools/build/lib/analysis/starlark/StarlarkRuleClassFunctions.java#L443)
        # require a "_allowlist_function_transition" attribute in the rule definition at
        # https://github.com/bazelbuild/bazel/blob/e2189245/src/main/java/com/google/devtools/build/lib/analysis/starlark/StarlarkRuleClassFunctions.java#L924-L933
        # Set the provided allow list label or default one .
        attrs["_allowlist_function_transition"] = attr.label(default = allowlist or "@bazel_tools//tools/allowlists/function_transition_allowlist")

    return attrs

def rlocation_path(ctx, file):
    """Produce the rlocation lookup path for the given file.

    See https://github.com/bazelbuild/bazel-skylib/issues/303.
    """
    if file.short_path.startswith("../"):
        return file.short_path[3:]
    else:
        return ctx.workspace_name + "/" + file.short_path
