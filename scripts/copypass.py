#!/usr/bin/env python

import sys
import subprocess
from pathlib import Path

FILE_PATH = Path("dotfiles/files/overthewire.txt")

def copy_to_clipboard(text):
    try:
        import pyperclip
        pyperclip.copy(text)
    except (ImportError, Exception):
        # Fallback for Termux
        try:
            subprocess.run(['termux-clipboard-set'], input=text.encode(), check=True)
        except Exception as e:
            print("Clipboard copy failed:", e)
            sys.exit(1)

def copy_last_password(file_path):
    if not file_path.exists():
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    with file_path.open("r") as f:
        lines = [line.strip() for line in f if line.strip()]

    if not lines:
        print("File is empty.")
        sys.exit(1)

    last_line = lines[-1]

    try:
        level_part, password = last_line.split(":", 1)
        level = level_part.strip()
        password = password.strip()
    except ValueError:
        print("Error: Unexpected line format.")
        sys.exit(1)

    print(f"Copying {level} password: {password}")
    copy_to_clipboard(password)
    print("Password copied to clipboard.")

if __name__ == "__main__":
    copy_last_password(FILE_PATH)
