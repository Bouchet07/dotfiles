#!/usr/bin/env python3

import sys
import subprocess
from pathlib import Path

from utils import get_clipboard_password, get_next_level

FILE_PATH = (Path(__file__).parent / "../files/overthewire.txt").resolve()


def add_password(password):
    """Append the new level/password to the file."""
    level = get_next_level(FILE_PATH)
    with FILE_PATH.open("a") as f:
        f.write(f"level {level}: {password}\n")
    print(f"✅ Added: level {level}: {password}")

def main():
    if len(sys.argv) == 1:
        password = get_clipboard_password()
    elif len(sys.argv) == 2:
        password = sys.argv[1]
    else:
        print("Usage:\n  python addpass.py <password>\n  python addpass.py    # to use clipboard")
        sys.exit(1)

    if not password:
        print("Error: Password is empty.")
        sys.exit(1)

    add_password(password)

if __name__ == "__main__":
    main()

