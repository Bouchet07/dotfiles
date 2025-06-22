#!/usr/bin/env python3

import sys
import subprocess
from pathlib import Path

FILE_PATH = (Path(__file__).parent / "../files/overthewire.txt").resolve()

def copy_to_clipboard(text):
    """Copy the given text to clipboard using pyperclip or Termux fallback."""
    try:
        import pyperclip
        pyperclip.copy(text)
        return True
    except ImportError:
        pass  # Try termux fallback

    try:
        subprocess.run(["termux-clipboard-set"], input=text.encode(), check=True)
        return True
    except Exception as e:
        print("❌ Clipboard copy failed:", e)
        return False

def copy_last_password(file_path):
    """Copy the password from the last line in the file to clipboard."""
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

    print(f"📋 Copying {level} password: {password}")
    if copy_to_clipboard(password):
        print("✅ Password copied to clipboard.")
    else:
        print("⚠️ Failed to copy password to clipboard. Make sure pyperclip or termux-clipboard-set is available.")
        sys.exit(1)

def main():
    copy_last_password(FILE_PATH)

if __name__ == "__main__":
    main()

