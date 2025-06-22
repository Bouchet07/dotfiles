import subprocess
import sys

def get_clipboard_password():
    try:
        import pyperclip
        return pyperclip.paste().strip()
    except ImportError:
        try:
            result = subprocess.check_output(["termux-clipboard-get"], text=True).strip()
            return result
        except Exception as e:
            print("❌ Could not read clipboard:", e)
            sys.exit(1)

def get_next_level(file_path):
    if not file_path.exists():
        print("File not found:", file_path)
        sys.exit(1)
    with file_path.open() as f:
        lines = [line for line in f if line.strip()]
    if not lines:
        return 0
    try:
        last_line = lines[-1]
        last_level = int(last_line.split()[1].rstrip(":"))
        return last_level + 1
    except Exception:
        print("❌ Could not parse last level number.")
        sys.exit(1)