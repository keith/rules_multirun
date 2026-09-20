import sys


def _main() -> None:
    name = sys.argv[1]
    for line in sys.stdin:
        print(f"{name}: {line}", end="", flush=True)
    print(f"{name}: EOF", flush=True)


if __name__ == "__main__":
    _main()
