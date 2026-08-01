"""Internal constants shared between multiple bzl files"""

# https://github.com/bazelbuild/bazel/blob/4ff441b13db6b6f5d5d317881c6383f510709b19/tools/bash/runfiles/runfiles.bash#L50-L64

RUNFILES_PREFIX = """#!/usr/bin/env bash

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

WINDOWS_LAUNCHER_BAT = """@echo off
setlocal

set "BASH_PATH=%BAZEL_SH%"
if not defined BASH_PATH if exist "{bash_path}" set "BASH_PATH={bash_path}"
if not defined BASH_PATH call :find_bash
if not defined BASH_PATH (
  echo Error: bash.exe was not found on PATH. Install MSYS2 or Git Bash, or set BAZEL_SH.>&2
  exit /b 1
)
for %%i in ("%BASH_PATH%") do set "PATH=%%~dpi;%PATH%"

if not defined RUNFILES_MANIFEST_FILE if exist "%~f0.runfiles_manifest" set "RUNFILES_MANIFEST_FILE=%~f0.runfiles_manifest"
if not defined RUNFILES_DIR if exist "%~f0.runfiles" set "RUNFILES_DIR=%~f0.runfiles"
if defined RUNFILES_MANIFEST_FILE set "RUNFILES_MANIFEST_FILE=%RUNFILES_MANIFEST_FILE:\\=/%"
if defined RUNFILES_DIR set "RUNFILES_DIR=%RUNFILES_DIR:\\=/%"

set "SCRIPT_PATH=%~dpn0.bash"
set "SCRIPT_PATH=%SCRIPT_PATH:\\=/%"

"%BASH_PATH%" "%SCRIPT_PATH%" %*
exit /b %ERRORLEVEL%

:find_bash
for /f "delims=" %%i in ('where bash.exe 2^>nul') do (
  if not defined BASH_PATH set "BASH_PATH=%%i"
)
exit /b 0
"""

SH_TOOLCHAIN_TYPE = "@bazel_tools//tools/sh:toolchain_type"

def windows_launcher_bat(ctx):
    """Render the Windows `.bat` launcher for the current target.

    Args:
        ctx: The rule context. The rule must register `SH_TOOLCHAIN_TYPE`.
    Returns:
        The contents of the `.bat` launcher.
    """
    sh_toolchain = ctx.toolchains[SH_TOOLCHAIN_TYPE]
    bash_path = sh_toolchain.path if sh_toolchain else ""
    return WINDOWS_LAUNCHER_BAT.format(bash_path = bash_path.replace("/", "\\"))

CommandInfo = provider(
    fields = {
        "description": "A string describing the command, printed during multiruns.",
        "bash_script": """The `.bash` script implementing the command, if there is one.

On Windows the executable of a `command` is a `.bat` launcher that shells out to
Bash. `multirun` already runs its commands from inside Bash, so it invokes this
script directly instead of paying for a bash -> cmd -> bash round trip (and
losing argument quoting along the way).
""",
    },
    doc = "Information about commands used by their multirun.",
)

WINDOWS_CONSTRAINT_ATTRS = {
    "_windows_constraint": attr.label(default = "@platforms//os:windows"),
}

def is_windows(ctx):
    """Returns True when the target platform is Windows.

    Args:
        ctx: The rule context. The rule must include `WINDOWS_CONSTRAINT_ATTRS`.
    Returns:
        Whether the target platform is Windows.
    """
    constraint = ctx.attr._windows_constraint[platform_common.ConstraintValueInfo]
    return ctx.target_platform_has_constraint(constraint)

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
