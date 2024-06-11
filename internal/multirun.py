import json
import os
import shutil
import subprocess
import sys
import platform
from multiprocessing.pool import ThreadPool
from typing import Dict, List, NamedTuple, Tuple, Union

from python.runfiles import runfiles

_R = runfiles.Create()


class Command(NamedTuple):
    path: str
    tag: str
    args: List[str]
    env: Dict[str, str]


def _run_command(
    command: Command,
    check_call: bool,
    started_processes: List[subprocess.Popen],
    **kwargs,
) -> Union[int, Tuple[subprocess.Popen, bytes, bytes]]:
    if platform.system() == "Windows":
        bash = shutil.which("bash.exe")
        if not bash:
            raise SystemExit("error: bash.exe not found in PATH")

        args = [bash, "-c", f'{command.path} "$@"', "--"] + command.args
    else:
        args = [command.path] + command.args
    env = dict(os.environ)
    env.update(command.env)
    if check_call:
        return subprocess.check_call(args, env=env)
    else:
        p = subprocess.Popen(args, env=env, **kwargs)
        started_processes.append(p)
        stdout, stderr = p.communicate()
        return p, stdout, stderr


def _perform_concurrently(commands: List[Command], concurrency: int, print_command: bool, buffer_output: bool) -> bool:
    kwargs = {}
    if buffer_output:
        kwargs = {
             "stdout" : subprocess.PIPE,
             "stderr" : subprocess.STDOUT
        }

    with ThreadPool(concurrency) as tp:
        started_processes = []
        results = [
            (command, tp.apply_async(_run_command, args=(command, False, started_processes), kwds=kwargs))
            for command
            in commands
        ]

        success = True
        try:
            for command, result in results:
                process, stdout, _ = result.get()
                if print_command and buffer_output:
                    print(command.tag, flush=True)

                if stdout:
                    print(stdout.decode().strip(), flush=True)

                if process.returncode != 0:
                    success = False
        except KeyboardInterrupt:
            for process in started_processes:
                process.kill()
                process.wait()
            success = False

        return success


def _perform_serially(commands: List[Command], print_command: bool, keep_going: bool) -> bool:
    success = True
    for command in commands:
        if print_command:
            print(command.tag, flush=True)

        try:
            _run_command(command, True, [])
        except subprocess.CalledProcessError:
            if keep_going:
                success = False
            else:
                return False
        except KeyboardInterrupt:
            return False

    return success


def _script_path(workspace_name: str, path: str) -> str:
    # Even on Windows runfiles require forward slashes.
    if path.startswith("../"):
        return _R.Rlocation(path[3:])
    else:
        return _R.Rlocation(f"{workspace_name}/{path}")


def _main(instructions_path: str, extra_args: List[str]) -> None:
    with open(instructions_path) as f:
        instructions = json.load(f)

    workspace_name = instructions["workspace_name"]
    commands = [
        Command(_script_path(workspace_name, blob["path"]), blob["tag"],
                blob["args"] + extra_args, blob["env"])
        for blob in instructions["commands"]
    ]
    concurrency = len(commands) if instructions["jobs"] == 0 else instructions["jobs"]
    print_command: bool = instructions["print_command"]
    if concurrency == 1:
        success = _perform_serially(commands, print_command, instructions["keep_going"])
    else:
        success = _perform_concurrently(commands, concurrency, print_command, instructions["buffer_output"])

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    _main(sys.argv[1], sys.argv[2:])
