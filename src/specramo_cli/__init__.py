"""Specramo CLI (work in progress)."""

import sys

USAGE = "usage: specramo {init,check,upgrade}"


def main() -> int:
    if len(sys.argv) < 2 or sys.argv[1] not in {"init", "check", "upgrade"}:
        print(USAGE, file=sys.stderr)
        return 2
    print(f"specramo {sys.argv[1]}: not implemented yet", file=sys.stderr)
    return 1
