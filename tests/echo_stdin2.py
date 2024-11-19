import sys

def _main():
    for line in sys.stdin.readlines():
        print("From stdin2: %s" % line)

if __name__ == "__main__":
    _main()