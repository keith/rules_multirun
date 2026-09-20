import ctypes
import json
import os
import platform
import shutil
import signal
import subprocess
import sys
import threading
import time
from ctypes import wintypes
from typing import Dict, List, NamedTuple, Tuple, Union

from python.runfiles import runfiles

_R = runfiles.Create()
_IBAZEL_EVENT_PREFIX = "IBAZEL_EVENT "
_POLL_SECONDS = 0.05
_RESTART_TIMEOUT_SECONDS = 5


class Command(NamedTuple):
    path: str
    tag: str
    label: str
    args: List[str]
    env: Dict[str, str]
    ibazel_notify_changes: bool
    ibazel_notify_changes_v1: bool


class _JobBasicLimits(ctypes.Structure):
    _fields_ = [
        ("PerProcessUserTimeLimit", ctypes.c_longlong),
        ("PerJobUserTimeLimit", ctypes.c_longlong),
        ("LimitFlags", wintypes.DWORD),
        ("MinimumWorkingSetSize", ctypes.c_size_t),
        ("MaximumWorkingSetSize", ctypes.c_size_t),
        ("ActiveProcessLimit", wintypes.DWORD),
        ("Affinity", ctypes.c_size_t),
        ("PriorityClass", wintypes.DWORD),
        ("SchedulingClass", wintypes.DWORD),
    ]


class _JobExtendedLimits(ctypes.Structure):
    _fields_ = [
        ("BasicLimitInformation", _JobBasicLimits),
        ("IoInfo", ctypes.c_ulonglong * 6),
        ("ProcessMemoryLimit", ctypes.c_size_t),
        ("JobMemoryLimit", ctypes.c_size_t),
        ("PeakProcessMemoryUsed", ctypes.c_size_t),
        ("PeakJobMemoryUsed", ctypes.c_size_t),
    ]


def _run_windows_child(args: List[str]) -> int:
    # Join before spawning: MSYS exec can reparent native children, so PID-tree
    # termination and assigning a job after Popen both miss descendants.
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
    kernel.CreateJobObjectW.restype = wintypes.HANDLE
    kernel.SetInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD]
    kernel.SetInformationJobObject.restype = wintypes.BOOL
    kernel.GetCurrentProcess.argtypes = []
    kernel.GetCurrentProcess.restype = wintypes.HANDLE
    kernel.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
    kernel.AssignProcessToJobObject.restype = wintypes.BOOL
    job = kernel.CreateJobObjectW(None, None)
    if not job:
        raise ctypes.WinError(ctypes.get_last_error())
    limits = _JobExtendedLimits()
    limits.BasicLimitInformation.LimitFlags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    if not kernel.SetInformationJobObject(job, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
        raise ctypes.WinError(ctypes.get_last_error())
    if not kernel.AssignProcessToJobObject(job, kernel.GetCurrentProcess()):
        raise ctypes.WinError(ctypes.get_last_error())
    # The non-inheritable handle lives until this supervisor exits, including
    # forced termination. Closing it then kills every descendant in the job.
    return subprocess.call(args)


def _run_command(command: Command, block: bool, **kwargs) -> Union[int, subprocess.Popen]:
    if platform.system() == "Windows":
        bash = os.environ.get("BAZEL_SH") or shutil.which("bash.exe")
        if not bash:
            raise SystemExit("error: bash not found. On Windows, install MSYS2, Git Bash or Cygwin and set BAZEL_SH environment variable.")

        args = [sys.executable, __file__, "--windows-child", bash, "-c", '"$0" "$@"; exit $?', command.path] + command.args
    else:
        args = [command.path] + command.args
    env = dict(os.environ)
    env.update(command.env)
    if platform.system() == "Windows":
        env["PYTHONPATH"] = os.pathsep.join(sys.path)
    if block:
        return subprocess.check_call(args, env=env)
    else:
        return subprocess.Popen(args, env=env, universal_newlines=True, bufsize=1, **kwargs)

def _forward_stdin(procs: List[Tuple[Command, subprocess.Popen]], filter_structured_events: bool = False) -> None:
    for line in sys.stdin:
        if not line:
            break
        for (command, proc) in procs:
            if filter_structured_events and line.startswith("IBAZEL_EVENT ") and not command.ibazel_notify_changes_v1:
                continue
            try:
                proc.stdin.write(line)
                proc.stdin.flush()
            except BrokenPipeError:
                pass

    for (_, proc) in procs:
        try:
            proc.stdin.close()
        except BrokenPipeError:
            pass


class _ManagedProcess:
    def __init__(self, command: Command, start: bool = True) -> None:
        self.command = command
        self._lock = threading.Lock()
        self._process = self._start() if start else None

    def _start(self) -> subprocess.Popen:
        kwargs = {
            "stdin": subprocess.PIPE if self.command.ibazel_notify_changes else subprocess.DEVNULL,
        }
        if platform.system() == "Windows":
            kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
        else:
            kwargs["start_new_session"] = True
        return _run_command(self.command, block=False, **kwargs)

    def start(self) -> None:
        with self._lock:
            if self._process is None:
                self._process = self._start()

    def write(self, line: str) -> None:
        with self._lock:
            process = self._process
            if process is None or process.stdin is None:
                return
            try:
                process.stdin.write(line)
                process.stdin.flush()
            except BrokenPipeError:
                pass

    def poll(self) -> Union[int, None]:
        with self._lock:
            return None if self._process is None else self._process.poll()

    def close_stdin(self) -> None:
        with self._lock:
            process = self._process
            if process is None or process.stdin is None:
                return
            try:
                process.stdin.close()
            except BrokenPipeError:
                pass

    def wait(self, timeout: float) -> bool:
        with self._lock:
            if self._process is None:
                return True
            try:
                self._process.wait(timeout=timeout)
                return True
            except subprocess.TimeoutExpired:
                return False

    def restart(self, reason: str) -> None:
        with self._lock:
            print(f"Restarting {self.command.tag}: {reason}", flush=True)
            self._terminate_locked()
            self._process = self._start()

    def terminate(self) -> None:
        with self._lock:
            self._terminate_locked()

    def _terminate_locked(self) -> None:
        process = self._process
        if process is None:
            return
        if process.poll() is not None:
            return
        if platform.system() == "Windows":
            process.terminate()
        else:
            try:
                os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError:
                return
        try:
            process.wait(timeout=_RESTART_TIMEOUT_SECONDS)
            return
        except subprocess.TimeoutExpired:
            pass
        if platform.system() == "Windows":
            process.kill()
        else:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                return
        process.wait(timeout=_RESTART_TIMEOUT_SECONDS)


def _parse_ibazel_event(line: str) -> Union[dict, None]:
    if not line.startswith(_IBAZEL_EVENT_PREFIX):
        return None
    try:
        payload = json.loads(line[len(_IBAZEL_EVENT_PREFIX):])
    except (TypeError, ValueError):
        return None
    if payload.get("version") != 1 or payload.get("type") != "build_completed":
        return None
    return payload


def _restart_reason(command: Command, event: dict, restart_affected_commands: bool) -> Union[str, None]:
    if not restart_affected_commands or command.ibazel_notify_changes or not event.get("success"):
        return None
    if not event.get("affected_targets_complete", False):
        return "change ownership incomplete"
    if command.label in event.get("affected_targets", []):
        return f"{command.label} affected"
    return None


def _raise_keyboard_interrupt(_signum, _frame) -> None:
    raise KeyboardInterrupt


def _route_ibazel_events(
    processes: List[_ManagedProcess],
    restart_affected_commands: bool,
    defer_non_notification_commands: bool,
    input_closed: threading.Event,
    shutdown: threading.Event,
) -> None:
    initial_build = True
    for line in sys.stdin:
        for process in processes:
            command = process.command
            if not command.ibazel_notify_changes:
                continue
            if line.startswith(_IBAZEL_EVENT_PREFIX) and not command.ibazel_notify_changes_v1:
                continue
            process.write(line)

        event = _parse_ibazel_event(line)
        if event is None:
            continue
        if initial_build:
            if defer_non_notification_commands and event.get("success"):
                for process in processes:
                    if not process.command.ibazel_notify_changes:
                        process.start()
            if not defer_non_notification_commands or event.get("success"):
                initial_build = False
            continue
        for process in processes:
            reason = _restart_reason(process.command, event, restart_affected_commands)
            if reason is not None:
                process.restart(reason)

    input_closed.set()
    for process in processes:
        if process.command.ibazel_notify_changes:
            process.close_stdin()
        else:
            process.terminate()
    for process in processes:
        if process.command.ibazel_notify_changes and not process.wait(_RESTART_TIMEOUT_SECONDS):
            process.terminate()
    shutdown.set()


def _perform_ibazel_concurrently(
    commands: List[Command],
    restart_affected_commands: bool,
    defer_non_notification_commands: bool,
) -> bool:
    processes = [
        _ManagedProcess(
            command,
            start=not defer_non_notification_commands or command.ibazel_notify_changes,
        )
        for command in commands
    ]
    input_closed = threading.Event()
    shutdown = threading.Event()
    event_thread = threading.Thread(
        target=_route_ibazel_events,
        args=(
            processes,
            restart_affected_commands,
            defer_non_notification_commands,
            input_closed,
            shutdown,
        ),
        daemon=True,
    )
    event_thread.start()

    success = True
    previous_sigterm = None
    if platform.system() != "Windows":
        previous_sigterm = signal.signal(signal.SIGTERM, _raise_keyboard_interrupt)
    try:
        while not shutdown.is_set():
            if input_closed.is_set():
                time.sleep(_POLL_SECONDS)
                continue
            returncodes = [process.poll() for process in processes]
            if any(returncode not in (None, 0) for returncode in returncodes):
                success = False
                break
            if all(returncode is not None for returncode in returncodes):
                break
            time.sleep(_POLL_SECONDS)
    except KeyboardInterrupt:
        success = False
    finally:
        shutdown.set()
        for process in processes:
            process.terminate()
        event_thread.join(timeout=_RESTART_TIMEOUT_SECONDS)
        if previous_sigterm is not None:
            signal.signal(signal.SIGTERM, previous_sigterm)
    return success

def _perform_concurrently(commands: List[Command], print_command: bool, buffer_output: bool, forward_stdin: bool, ibazel_notify_changes: bool) -> bool:
    kwargs = {}
    if buffer_output:
        kwargs = {
             "stdout" : subprocess.PIPE,
             "stderr" : subprocess.STDOUT
        }

    if forward_stdin:
        kwargs["stdin"] = subprocess.PIPE

    processes = []
    for command in commands:
        command_kwargs = dict(kwargs)
        if ibazel_notify_changes:
            command_kwargs["stdin"] = (
                subprocess.PIPE
                if command.ibazel_notify_changes
                else subprocess.DEVNULL
            )
        processes.append(
            (command, _run_command(command, block=False, **command_kwargs))
        )

    threads = []
    if forward_stdin:
        stdin_thread = threading.Thread(target=_forward_stdin, args=(processes,))
        stdin_thread.start()
        threads.append(stdin_thread)

    if ibazel_notify_changes:
        ibazel_processes = [
            (command, process)
            for command, process in processes
            if command.ibazel_notify_changes
        ]
        ibazel_thread = threading.Thread(target=_forward_stdin, args=(ibazel_processes, True))
        ibazel_thread.start()
        threads.append(ibazel_thread)

    success = True
    try:
        for command, process in processes:
            if print_command and buffer_output:
                print(command.tag, flush=True)

            stdout = ""
            if process.stdout:
                for line in iter(process.stdout.readline, ''):
                    stdout += line

            process.wait()
            if stdout:
                print(stdout.strip(), flush=True)

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
        Command(_script_path(workspace_name, blob["path"]), blob["tag"], blob.get("label", ""),
                blob["args"] + extra_args, blob["env"],
                blob.get("ibazel_notify_changes", False) or blob.get("ibazel_notify_changes_v1", False),
                blob.get("ibazel_notify_changes_v1", False))
        for blob in instructions["commands"]
    ]
    parallel = instructions["jobs"] == 0
    print_command: bool = instructions["print_command"]
    if parallel and instructions.get("ibazel_notify_changes", False):
        success = _perform_ibazel_concurrently(
            commands,
            instructions.get("ibazel_restart_affected_commands", False),
            instructions.get("ibazel_defer_non_notification_commands", False),
        )
    elif parallel:
        success = _perform_concurrently(
            commands,
            print_command,
            instructions["buffer_output"],
            instructions["forward_stdin"],
            instructions.get("ibazel_notify_changes", False),
        )
    else:
        success = _perform_serially(commands, print_command, instructions["keep_going"])

    sys.exit(0 if success else 1)


if __name__ == "__main__":
    if sys.argv[1] == "--windows-child":
        sys.exit(_run_windows_child(sys.argv[2:]))
    _main(sys.argv[1], sys.argv[2:])
