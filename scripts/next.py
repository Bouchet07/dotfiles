#!/usr/bin/env python3

import sys
import subprocess
from pathlib import Path

import pexpect
from utils import get_clipboard_password, get_next_level, get_last_password

FILE_PATH = (Path(__file__).parent / "../files/overthewire.txt").resolve()
ADDPASS_SCRIPT = (Path(__file__).parent / "addpass.py").resolve()
HOST = "bandit.labs.overthewire.org"
PORT = "2220"

def add_password(password):
    try:
        subprocess.run(["python3", str(ADDPASS_SCRIPT), password], check=True)
    except subprocess.CalledProcessError as e:
        print("❌ Failed to add password:", e)
        sys.exit(1)

def ssh_login(level, password):
    username = f"bandit{level}"
    ssh_cmd = f"ssh {username}@{HOST} -p {PORT}"
    print(f"🔐 Logging into {username}@{HOST}:{PORT} ...")

    child = pexpect.spawn(ssh_cmd, encoding="utf-8")

    try:
        child.expect("password:", timeout=10)
        child.sendline(password)
        child.interact()
    except pexpect.exceptions.TIMEOUT:
        print("❌ Timed out waiting for password prompt.")
        child.close()
        sys.exit(1)
    except Exception as e:
        print("❌ SSH failed:", e)
        child.close()
        sys.exit(1)

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("add", "copy"):
        print("Usage: next.py [add|copy]")
        sys.exit(1)

    mode = sys.argv[1]

    if mode == "add":
        password = get_clipboard_password()
        level = get_next_level(FILE_PATH)
        add_password(password)
    else:  # mode == "copy"
        password = get_last_password(FILE_PATH)
        level = get_next_level(FILE_PATH) - 1

    ssh_login(level, password)

if __name__ == "__main__":
    main()
