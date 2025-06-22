#!/usr/bin/env python

import sys
from pathlib import Path

FILE_PATH = Path("dotfiles/files/overthewire.txt")

def confirm(prompt="Are you sure you want to remove the last line? (y/N): "):
    answer = input(prompt).strip().lower()
    return answer == 'y' or answer == 'yes'

def remove_last_line(file_path):
    if not file_path.exists():
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    with file_path.open("r") as f:
        lines = f.readlines()

    if not lines:
        print("File is already empty.")
        return

    print(f"Last line to be removed:\n{lines[-1].rstrip()}")

    if not confirm():
        print("Aborted by user.")
        return

    with file_path.open("w") as f:
        f.writelines(lines[:-1])

    print("Last line removed successfully.")

if __name__ == "__main__":
    remove_last_line(FILE_PATH)
