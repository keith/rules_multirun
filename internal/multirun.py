import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, NamedTuple, Union


class Command(NamedTuple):
    path: Path
    tag: str
    args: List[str]
    env: Dict[str, str]


def _run_command(command: Command, block: bool, **kwargs) -> Union[int, subprocess.Popen]:
    print(os.listdir("."))
    print(os.listdir("tests"))
    args = [command.path.absolute()] + command.args
    env = dict(os.environ)
    env.update(command.env)
    if block:
        try:
            return subprocess.check_call(args, env=env)
        except FileNotFoundError:
            print(f"Error: {command.path} not found {args}", file=sys.stderr)
            raise
    else:
        return subprocess.Popen(args, env=env, **kwargs)


def _perform_concurrently(commands: List[Command], print_command: bool, buffer_output: bool) -> bool:
    kwargs = {}
    if buffer_output:
        kwargs = {
             "stdout" : subprocess.PIPE,
             "stderr" : subprocess.STDOUT
        }

    processes = [
        (command, _run_command(command, block=False, **kwargs))
        for command
        in commands
    ]

    success = True
    for command, process in processes:
        process.wait()
        if print_command and buffer_output:
            print(command.tag, flush=True)

        stdout = process.communicate()[0]
        if stdout:
            print(stdout.decode().strip(), flush=True)

        if process.returncode != 0:
            success = False

    return success


def _perform_serially(commands: List[Command], print_command: bool, keep_going: bool) -> bool:
    success = True
    for command in commands:
        if print_command:
            print(command.tag, flush=True)

        try:
            _run_command(command, block=True)
        except subprocess.CalledProcessError:
            if keep_going:
                success = False
            else:
                return False

    return success


def _main(path: str) -> None:
    with open(path) as f:
        instructions = json.load(f)

    commands = [
        Command(Path(blob["path"]), blob["tag"], blob["args"], blob["env"])
        for blob in instructions["commands"]
    ]
    parallel = instructions["jobs"] == 0
    print_command: bool = instructions["print_command"]
    if parallel:
        success = _perform_concurrently(commands, print_command, instructions["buffer_output"])
    else:
        success = _perform_serially(commands, print_command, instructions["keep_going"])

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    _main(sys.argv[-1])
