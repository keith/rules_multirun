import json
import os
import signal
import shutil
import subprocess
import sys
import threading
import platform
from typing import Dict, List, NamedTuple, Union, Tuple

from python.runfiles import runfiles

_R = runfiles.Create()


class Command(NamedTuple):
    path: str
    tag: str
    args: List[str]
    env: Dict[str, str]


def _run_command(command: Command, block: bool, **kwargs) -> Union[int, subprocess.Popen]:
    if platform.system() == "Windows":
        bash = shutil.which("bash.exe")
        if not bash:
            raise SystemExit("error: bash.exe not found in PATH")

        args = [bash, "-c", f'{command.path} "$@"', "--"] + command.args
    else:
        args = [command.path] + command.args
    env = dict(os.environ)
    env.update(command.env)
    if block:
        return subprocess.check_call(args, env=env)
    else:
        return subprocess.Popen(args, env=env, **kwargs)

def _forward_stdin(procs: List[Tuple[Command, subprocess.Popen]]) -> None:
    for line in sys.stdin.readlines():
        if not line:
            break
        for (cmd, proc) in procs:
            proc.stdin.write(line.encode())
            proc.stdin.flush()
    
    for (cmd, proc) in procs:
        proc.stdin.close()

def _perform_concurrently(commands: List[Command], print_command: bool, buffer_output: bool, forward_stdin: bool) -> bool:
    kwargs = {}
    if buffer_output:
        kwargs = {
             "stdout" : subprocess.PIPE,
             "stderr" : subprocess.STDOUT
        }
    
    if forward_stdin:
        kwargs["stdin"] = subprocess.PIPE

    processes = [
        (command, _run_command(command, block=False, **kwargs))
        for command
        in commands
    ]

    threads = []
    if forward_stdin:
        stdin_thread = threading.Thread(target=_forward_stdin, args=(processes,))
        stdin_thread.start()
        threads.append(stdin_thread)

    success = True
    try:
        for command, process in processes:
            process.wait()
            if print_command and buffer_output:
                print(command.tag, flush=True)

            stdout = process.communicate()[0]
            if stdout:
                print(stdout.decode().strip(), flush=True)

            if process.returncode != 0:
                success = False
    except KeyboardInterrupt:
        for command, process in processes:
            process.send_signal(signal.SIGINT)
            process.wait()
        success = False
    finally:
        for thread in threads:
            thread.join()

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
    parallel = instructions["jobs"] == 0
    print_command: bool = instructions["print_command"]
    if parallel:
        success = _perform_concurrently(commands, print_command, instructions["buffer_output"], instructions["forward_stdin"])
    else:
        success = _perform_serially(commands, print_command, instructions["keep_going"])

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    _main(sys.argv[1], sys.argv[2:])
