#!/usr/bin/env python3

import sys
import subprocess
from pathlib import Path

FILE_PATH = (Path(__file__).parent / "../files/overthewire.txt").resolve()

def get_next_level(file_path):
    """Return the next level number based on the last line in the file."""
    if not file_path.exists():
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    with file_path.open("r") as f:
        lines = [line.strip() for line in f if line.strip()]  # skip blank lines

    if not lines:
        return 0

    last_line = lines[-1]
    try:
        # Expected format: level X: password
        level_str = last_line.split()[1].rstrip(":")
        return int(level_str) + 1
    except (IndexError, ValueError):
        print("Error: Couldn't parse last level number.")
        sys.exit(1)

def get_clipboard_password():
    """Try to get clipboard content via pyperclip or termux-clipboard-get."""
    try:
        import pyperclip
        return pyperclip.paste().strip()
    except ImportError:
        pass  # Try termux fallback

    try:
        result = subprocess.check_output(["termux-clipboard-get"], text=True).strip()
        return result
    except Exception:
        print("Error: Could not read from clipboard. Install `pyperclip` or use `termux-clipboard-get`.")
        sys.exit(1)

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

