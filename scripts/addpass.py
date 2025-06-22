#!/usr/bin/env python

import sys
from pathlib import Path

FILE_PATH = Path("dotfiles/files/overthewire.txt")

def get_next_level(file_path):
    if not file_path.exists():
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    with file_path.open("r") as f:
        lines = f.readlines()
        if not lines:
            return 0
        last_line = lines[-1]
        try:
            last_level = int(last_line.split()[1].rstrip(":"))
            return last_level + 1
        except (IndexError, ValueError):
            print("Error: Couldn't parse last level number.")
            sys.exit(1)

def add_password(password):
    level = get_next_level(FILE_PATH)
    with FILE_PATH.open("a") as f:
        f.write(f"level {level}: {password}\n")
    print(f"Added: level {level}: {password}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python addpass.py <password>")
        sys.exit(1)

    password = sys.argv[1]
    add_password(password)
