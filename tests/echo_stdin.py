import sys

def _main():
    for line in sys.stdin:
        print("From stdin: %s" % line)

if __name__ == "__main__":
    _main()