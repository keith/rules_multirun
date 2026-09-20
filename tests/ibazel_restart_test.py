import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

_TIMEOUT_SECONDS = 60 if os.name == "nt" else 10


def _event(
    path: str,
    kind: str = "source",
    success: bool = True,
    affected_targets: list[str] | None = None,
    affected_targets_complete: bool = True,
) -> str:
    payload = {
        "version": 1,
        "type": "build_completed",
        "success": success,
        "changes": [{"path": path, "kind": kind}],
        "affected_targets": affected_targets or [],
        "affected_targets_complete": affected_targets_complete,
    }
    return "IBAZEL_EVENT " + json.dumps(payload, separators=(",", ":"))


def _wait_for_launches(path: Path, expected: dict[str, int]) -> None:
    deadline = time.monotonic() + _TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        launches = _launches(path)
        if all(launches.count(name) >= count for name, count in expected.items()):
            return
        time.sleep(0.05)
    raise AssertionError(f"Timed out waiting for launches {expected}: {launches}")


def _launches(path: Path) -> list[str]:
    if not path.exists():
        return []
    return [line.split()[0] for line in path.read_text(encoding="utf-8").splitlines()]


def _wait_for_processes_to_exit(path: Path) -> None:
    pids = [int(line.split()[1]) for line in path.read_text(encoding="utf-8").splitlines()]
    deadline = time.monotonic() + _TIMEOUT_SECONDS
    while time.monotonic() < deadline:
        alive = []
        for pid in pids:
            try:
                os.kill(pid, 0)
                alive.append(pid)
            except ProcessLookupError:
                pass
        if not alive:
            return
        time.sleep(0.05)
    raise AssertionError(f"Child processes still running: {alive}")


def _main() -> None:
    if os.name == "nt":
        # Python's extracted zip omits runfiles symlinks needed by shell children.
        os.environ["RUNFILES_MANIFEST_FILE"] = os.path.join(os.environ["TEST_SRCDIR"], "MANIFEST")
    with tempfile.TemporaryDirectory() as temp_dir:
        launch_log = Path(temp_dir) / "launches.txt"
        command = [os.path.abspath(sys.argv[1]), str(launch_log)]
        deferred = len(sys.argv) > 2 and sys.argv[2] == "deferred"
        if os.name == "nt" and not command[0].endswith(".bat"):
            bash = os.environ.get("BAZEL_SH") or shutil.which("bash.exe")
            assert bash is not None
            command.insert(0, bash)

        process = subprocess.Popen(command, stdin=subprocess.PIPE, text=True)
        assert process.stdin is not None
        try:
            if deferred:
                process.stdin.write(
                    _event(
                        "pplx/rust/initial.rs",
                        success=False,
                        affected_targets=["//tests:ibazel_restart_rpc"],
                    )
                    + "\n"
                )
                process.stdin.flush()
                time.sleep(0.2)
                assert _launches(launch_log) == []

            process.stdin.write(
                _event("pplx/rust/initial.rs", affected_targets=["//tests:ibazel_restart_rpc"]) + "\n"
            )
            process.stdin.flush()
            _wait_for_launches(launch_log, {"rpc": 1, "electron": 1})
            time.sleep(0.2)
            assert _launches(launch_log).count("rpc") == 1

            process.stdin.write(
                _event(
                    "pplx/rust/src/lib.rs",
                    success=False,
                    affected_targets=["//tests:ibazel_restart_rpc"],
                )
                + "\n"
            )
            process.stdin.flush()
            time.sleep(0.2)
            assert _launches(launch_log).count("rpc") == 1

            process.stdin.write(
                _event(
                    "pplx/rust/src/lib.rs",
                    affected_targets=["//tests:ibazel_restart_rpc"],
                )
                + "\n"
            )
            process.stdin.flush()
            _wait_for_launches(launch_log, {"rpc": 2, "electron": 1})

            process.stdin.write(
                _event("pplx/frontend/apps/renderer/BUILD.bazel", "graph") + "\n"
            )
            process.stdin.flush()
            time.sleep(0.2)
            launches = _launches(launch_log)
            assert launches.count("rpc") == 2
            assert launches.count("electron") == 1

            process.stdin.write(
                _event(
                    "MODULE.bazel",
                    "graph",
                    affected_targets_complete=False,
                )
                + "\n"
            )
            process.stdin.flush()
            _wait_for_launches(launch_log, {"rpc": 3, "electron": 2})
        finally:
            process.stdin.close()
            try:
                process.wait(timeout=_TIMEOUT_SECONDS)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()

        assert process.returncode == 0

        if os.name != "nt":
            termination_log = Path(temp_dir) / "termination-launches.txt"
            termination_process = subprocess.Popen(
                [sys.argv[1], str(termination_log)],
                stdin=subprocess.PIPE,
                text=True,
            )
            if deferred:
                assert termination_process.stdin is not None
                termination_process.stdin.write(
                    _event("pplx/rust/initial.rs", affected_targets=["//tests:ibazel_restart_rpc"])
                    + "\n"
                )
                termination_process.stdin.flush()
            _wait_for_launches(termination_log, {"rpc": 1, "electron": 1})
            termination_process.terminate()
            termination_process.wait(timeout=_TIMEOUT_SECONDS)
            _wait_for_processes_to_exit(termination_log)


if __name__ == "__main__":
    _main()
