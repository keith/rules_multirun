import ctypes
import json
import os
import shlex
import subprocess
import sys
import tempfile
import time
import unittest
from ctypes import wintypes
from pathlib import Path

from internal import multirun


@unittest.skipUnless(os.name == "nt", "requires Windows and Git Bash or MSYS2")
class WindowsProcessTest(unittest.TestCase):
    def command(self, path, args):
        return multirun.Command(str(path).replace("\\", "/"), "child", "//:child", args, {"PYTHONPATH": os.pathsep.join(sys.path)}, False, False)

    def script(self, directory, body, filename="command with spaces.sh"):
        path = Path(directory) / filename
        path.write_text("#!/usr/bin/env bash\n" + body, encoding="utf-8")
        return path

    def test_arguments_and_exit_status(self):
        with tempfile.TemporaryDirectory() as directory:
            path = self.script(directory, 'printf "<%s>\\n" "$@"; exit 23\n')
            args = ["", "two words", "$HOME", "a&b", "a;b", "雪"]
            process = multirun._run_command(self.command(path, args), False, stdout=subprocess.PIPE, encoding="utf-8")
            output, _ = process.communicate(timeout=20)
            self.assertEqual(process.returncode, 23)
            self.assertEqual(output.splitlines(), ["<" + arg + ">" for arg in args])

    def test_supervisor_termination_kills_descendants(self):
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.WaitForSingleObject.argtypes = [wintypes.HANDLE, wintypes.DWORD]
        kernel.WaitForSingleObject.restype = wintypes.DWORD
        kernel.TerminateProcess.argtypes = [wintypes.HANDLE, wintypes.UINT]
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        with tempfile.TemporaryDirectory() as directory:
            pids = Path(directory) / "pids.json"
            executable = shlex.quote(sys.executable.replace("\\", "/"))
            fixture = shlex.quote(str(Path(__file__).resolve()).replace("\\", "/"))
            path = self.script(directory, f'exec {executable} {fixture} --child "$1"\n', "child.sh")
            process = multirun._run_command(self.command(path, [str(pids)]), False)
            handles = []
            try:
                deadline = time.monotonic() + 20
                while not pids.exists() and time.monotonic() < deadline:
                    self.assertIsNone(process.poll(), "child exited before publishing PIDs")
                    time.sleep(0.05)
                self.assertTrue(pids.exists(), "child did not start")
                for pid in json.loads(pids.read_text()):
                    handle = kernel.OpenProcess(0x100001, False, pid)  # SYNCHRONIZE | PROCESS_TERMINATE
                    self.assertTrue(handle, ctypes.WinError(ctypes.get_last_error()))
                    handles.append(handle)
                process.terminate()
                process.wait(timeout=10)
                for handle in handles:
                    self.assertEqual(kernel.WaitForSingleObject(handle, 10000), 0, "descendant survived supervisor")
            finally:
                if process.poll() is None:
                    process.kill()
                process.wait(timeout=10)
                for handle in handles:
                    kernel.TerminateProcess(handle, 1)
                    kernel.CloseHandle(handle)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--child":
        child = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(120)"])
        destination = Path(sys.argv[2])
        temporary = destination.with_suffix(".tmp")
        temporary.write_text(json.dumps([os.getpid(), child.pid]))
        temporary.replace(destination)
        child.wait()
    else:
        unittest.main()
