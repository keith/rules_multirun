import json
import os
import signal
import shutil
import subprocess
import sys
import threading
import time
import platform
from dataclasses import dataclass
from typing import Dict, List, NamedTuple, Optional

from python.runfiles import runfiles

_R = runfiles.Create()


class Command(NamedTuple):
    path: str
    tag: str
    args: List[str]
    env: Dict[str, str]


@dataclass
class CommandRun:
    command: Command
    process: subprocess.Popen
    start_time: float
    end_time: Optional[float] = None

    @classmethod
    def start(cls, command: Command, **kwargs) -> "CommandRun":
        start_time = time.monotonic()
        return cls(command, _run_command(command, **kwargs), start_time)

    def wait_for_exit(self) -> None:
        self.process.wait()
        self.end_time = time.monotonic()

    @property
    def duration(self) -> float:
        if self.end_time:
            return self.end_time - self.start_time
        else:
            raise ValueError("end_time has not been set, wait for the command to finish")


def _run_command(command: Command, **kwargs) -> subprocess.Popen:
    if platform.system() == "Windows":
        bash = os.environ.get("BAZEL_SH") or shutil.which("bash.exe")
        if not bash:
            raise SystemExit("error: bash not found. On Windows, install MSYS2, Git Bash or Cygwin and set BAZEL_SH environment variable.")

        args = [bash, "-c", f'{command.path} "$@"', "--"] + command.args
    else:
        args = [command.path] + command.args
    env = dict(os.environ)
    env.update(command.env)
    return subprocess.Popen(args, env=env, universal_newlines=True, bufsize=1, **kwargs)

def _forward_stdin(runs: List[CommandRun]) -> None:
    runs_with_stdin = [r for r in runs if r.process.stdin is not None]
    for line in sys.stdin.readlines():
        if not line:
            break
        for run in runs_with_stdin:
            run.process.stdin.write(line)
            run.process.stdin.flush()

    for run in runs_with_stdin:
        run.process.stdin.close()

def _print_durations(runs: List[CommandRun]) -> None:
    print("Command durations:", file=sys.stderr)
    for run in sorted(runs, key=lambda run: run.duration, reverse=True):
        print(f"  {run.duration:8.2f}s  {run.command.tag}", file=sys.stderr)
    sys.stderr.flush()

def _perform_concurrently(commands: List[Command], print_command: bool, buffer_output: bool, forward_stdin: bool) -> bool:
    kwargs = {}
    if buffer_output:
        kwargs = {
             "stdout" : subprocess.PIPE,
             "stderr" : subprocess.STDOUT
        }

    if forward_stdin:
        kwargs["stdin"] = subprocess.PIPE

    runs = [CommandRun.start(command, **kwargs) for command in commands]

    exit_threads = [threading.Thread(target=run.wait_for_exit) for run in runs]
    for thread in exit_threads:
        thread.start()

    threads = list(exit_threads)

    if forward_stdin:
        stdin_thread = threading.Thread(target=_forward_stdin, args=(runs,))
        stdin_thread.start()
        threads.append(stdin_thread)

    success = True
    try:
        for run in runs:
            if print_command and buffer_output:
                print(run.command.tag, flush=True)

            stdout = ""
            if run.process.stdout:
                for line in iter(run.process.stdout.readline, ''):
                    stdout += line

            run.process.wait()
            if stdout:
                print(stdout.strip(), flush=True)

            if run.process.returncode != 0:
                success = False

        if print_command:
            for thread in exit_threads:
                thread.join()
            _print_durations(runs)
    except KeyboardInterrupt:
        for run in runs:
            run.process.send_signal(signal.SIGINT)
            run.process.wait()
        success = False
    finally:
        for thread in threads:
            thread.join()

    return success


def _perform_serially(commands: List[Command], print_command: bool, keep_going: bool) -> bool:
    runs = []
    success = True
    for command in commands:
        if print_command:
            print(command.tag, flush=True)

        run = CommandRun.start(command)
        runs.append(run)
        try:
            run.wait_for_exit()
        except KeyboardInterrupt:
            run.process.kill()
            run.process.wait()
            return False

        if run.process.returncode != 0:
            success = False
            if not keep_going:
                break

    if print_command:
        _print_durations(runs)

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
