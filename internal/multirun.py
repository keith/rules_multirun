import json
import subprocess
import sys
from typing import List, NamedTuple


class Command(NamedTuple):
    path: str
    tag: str


def _perform_concurrently(commands: List[Command]) -> bool:
    processes = [subprocess.Popen(command.path) for command in commands]
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
            subprocess.check_call(command.path)
        except subprocess.CalledProcessError:
            return False

    return True


def _main(path: str) -> None:
    with open(path) as f:
        instructions = json.load(f)

    commands = [
        Command(blob["path"], blob["tag"]) for blob in instructions["commands"]
    ]
    parallel = instructions["jobs"] == 0
    if parallel:
        success = _perform_concurrently(commands)
    else:
        success = _perform_serially(commands, instructions["print_command"])

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    _main(sys.argv[-1])
