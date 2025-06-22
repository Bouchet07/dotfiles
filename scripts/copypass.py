#!/usr/bin/env python3

import sys
import subprocess
from pathlib import Path

from utils import get_last_password, copy_to_clipboard

FILE_PATH = (Path(__file__).parent / "../files/overthewire.txt").resolve()


def main():
    password = get_last_password(FILE_PATH)

    # Extract level number for display
    try:
        with FILE_PATH.open() as f:
            lines = [line.strip() for line in f if line.strip()]
            level_part = lines[-1].split(":")[0].strip()
    except Exception:
        level_part = "last level"

    print(f"📋 Copying {level_part} password: {password}")
    if copy_to_clipboard(password):
        print("✅ Password copied to clipboard.")
    else:
        print("⚠️ Failed to copy password to clipboard. Make sure pyperclip or termux-clipboard-set is available.")
        sys.exit(1)

if __name__ == "__main__":
    main()

