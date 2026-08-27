"""Providers and aspects for preserving executable args and environment."""

BinaryArgsEnvInfo = provider(
    fields = ["args", "env"],
    doc = "The arguments and environment to use when running the binary",
)

def _binary_args_env_aspect_impl(target, ctx):
    if BinaryArgsEnvInfo in target:
        return []

    is_executable = target.files_to_run != None and target.files_to_run.executable != None
    args = getattr(ctx.rule.attr, "args", [])
    env = dict(getattr(ctx.rule.attr, "env", {}))

    if RunEnvironmentInfo in target:
        env.update(target[RunEnvironmentInfo].environment)

    if is_executable and (args or env):
        expansion_targets = getattr(ctx.rule.attr, "data", [])
        if expansion_targets:
            args = [
                ctx.expand_location(arg, expansion_targets)
                for arg in args
            ]
            env = {
                name: ctx.expand_location(val, expansion_targets)
                for name, val in env.items()
            }
        return [BinaryArgsEnvInfo(args = args, env = env)]

    return []

binary_args_env_aspect = aspect(
    implementation = _binary_args_env_aspect_impl,
)
