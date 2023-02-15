import json
import os
import subprocess
import sys
from typing import Dict, List, NamedTuple


class Command(NamedTuple):
    path: str
    tag: str
    args: List[str]
    env: Dict[str, str]


def _run_command(command: Command, block: bool):
    args = [command.path] + command.args
    env = dict(os.environ)
    env.update(command.env)
    if block:
        return subprocess.check_call(args, env=env)
    else:
        return subprocess.Popen(args, env=env)


def _perform_concurrently(commands: List[Command]) -> bool:
    processes = [_run_command(command, block=False) for command in commands]
    success = True
    for process in processes:
        process.wait()
        if process.returncode != 0:
            success = False

    return success


def _perform_serially(commands: List[Command], print_command: bool) -> bool:
    for command in commands:
        if print_command:
            print(f"Running {command.tag}")

        try:
            _run_command(command, block=True)
        except subprocess.CalledProcessError:
            return False

    return True


def _main(path: str) -> None:
    with open(path) as f:
        instructions = json.load(f)

    commands = [
        Command(blob["path"], blob["tag"], blob["args"], blob["env"])
        for blob in instructions["commands"]
    ]
    parallel = instructions["jobs"] == 0
    if parallel:
        success = _perform_concurrently(commands)
    else:
        success = _perform_serially(commands, instructions["print_command"])

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    _main(sys.argv[-1])
