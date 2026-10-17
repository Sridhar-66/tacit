#!/usr/bin/env python3
"""Replace one marked block in a config file with the given lines, leaving the rest as it is.

  managed_block.py FILE NAME [LINE ...]

The block runs from "-- >>> Tacit Settings: NAME" to "-- <<< Tacit Settings: NAME"; it is added
at the end when absent, and removed when no lines are given. The file is created if missing.
"""
import os
import sys


def main():
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    path, name, lines = os.path.expanduser(sys.argv[1]), sys.argv[2], sys.argv[3:]
    begin, end = f"-- >>> Tacit Settings: {name}", f"-- <<< Tacit Settings: {name}"
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except FileNotFoundError:
        text = ""
    if not lines and begin not in text:
        return 0   # nothing to remove, and no file to create for it
    if begin in text and end in text:
        head, rest = text.split(begin, 1)
        tail = rest.split(end, 1)[1]
    else:
        head, tail = text, ""
        if head and not head.endswith("\n"):
            head += "\n"
    block = f"{begin}\n" + "".join(f"{l}\n" for l in lines) + end if lines else ""
    new = head + block + tail
    if block and not new.endswith("\n"):
        new += "\n"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(new)
    os.replace(tmp, path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
