#!/usr/bin/env python3

import sys
from pathlib import Path

FILE_PATH = (Path(__file__).parent / "../files/overthewire.txt").resolve()

def confirm(prompt="Are you sure you want to remove the last line? (y/N): "):
    """Prompt the user for confirmation."""
    answer = input(prompt).strip().lower()
    return answer in ("y", "yes")

def remove_last_line(file_path):
    """Remove the last non-empty line from the file after confirmation."""
    if not file_path.exists():
        print(f"Error: File not found: {file_path}")
        sys.exit(1)

    with file_path.open("r") as f:
        lines = [line for line in f if line.strip()]  # Ignore blank lines

    if not lines:
        print("File is already empty.")
        return

    last_line = lines[-1].rstrip()
    print(f"⚠️ Last line to be removed:\n{last_line}")

    if not confirm():
        print("Aborted by user.")
        return

    with file_path.open("w") as f:
        f.writelines(lines[:-1])
        f.write("\n")  # Ensure trailing newline if needed

    print("✅ Last line removed successfully.")

def main():
    remove_last_line(FILE_PATH)

if __name__ == "__main__":
    main()

