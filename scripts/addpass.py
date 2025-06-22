#!/usr/bin/env python

import sys
from pathlib import Path

FILE_PATH = Path(__file__).parent / "../files/overthewire.txt"

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
    # If no password, use clipboard content
    if len(sys.argv) == 1:
        try:
            import pyperclip
            password = pyperclip.paste()
        except ImportError:
            # try using termux-clipboard if pyperclip is not available
            try:
                import subprocess
                password = subprocess.check_output(["termux-clipboard-get"], text=True).strip()
            except Exception as e:
                print(f"Error: {e}")
                sys.exit(1)
            print("Error: pyperclip module not found. Please install it to use clipboard functionality.")
            sys.exit(1)
    if len(sys.argv) != 2:
        print("Usage: python addpass.py <password>")
        sys.exit(1)

    password = sys.argv[1]
    add_password(password)
