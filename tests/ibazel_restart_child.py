import os
import signal
import sys
import time
from pathlib import Path


def _main() -> None:
    name = sys.argv[1]
    launch_log = Path(sys.argv[2])
    with launch_log.open("a", encoding="utf-8") as output:
        output.write(f"{name} {os.getpid()}\n")
        output.flush()

    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    while True:
        time.sleep(0.1)


if __name__ == "__main__":
    _main()
