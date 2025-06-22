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
        
def get_last_password(file_path):
    if not file_path.exists():
        print("❌ File not found:", file_path)
        sys.exit(1)
    with file_path.open() as f:
        lines = [line.strip() for line in f if line.strip()]
    if not lines:
        print("❌ File is empty.")
        sys.exit(1)
    try:
        _, password = lines[-1].split(":", 1)
        return password.strip()
    except Exception:
        print("❌ Could not parse last password.")
        sys.exit(1)