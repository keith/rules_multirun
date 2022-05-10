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
