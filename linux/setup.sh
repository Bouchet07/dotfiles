#!/usr/bin/env bash
# Idempotent Linux / Hermes 2 setup & dotfile symlinker (counterpart to setup.ps1)
set -euo pipefail

NO_INSTALL=0
UPDATE_TOOLS=0
for arg in "$@"; do
  case "$arg" in
    --no-install|-n) NO_INSTALL=1 ;;
    --update|-u)     UPDATE_TOOLS=1 ;;
    -h|--help)
      echo "Usage: $0 [--no-install] [--update]"
      exit 0
      ;;
  esac
done

DOTFILES_LINUX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$HOME/.local/bin" "$HOME/utils"

cyan=$'\033[36m'
white=$'\033[97m'
gray=$'\033[90m'
reset=$'\033[0m'

printf "\n${cyan}── Linux / Hermes Setup ───────────────────────────${reset}\n"
printf "  ${gray}Source:${reset} ${white}%s${reset}\n" "$DOTFILES_LINUX"

# --- 1. Rootless CLI binaries in ~/.local/bin ---
printf "\n ${cyan}Packages (~/.local/bin)${reset}\n"
if [ "$NO_INSTALL" -eq 1 ]; then
  printf "    ${gray}Skipping package check (--no-install).${reset}\n"
else
  UPDATE_TOOLS="$UPDATE_TOOLS" python3 - <<'EOF'
import os, shutil, tarfile, tempfile, urllib.request

update = os.environ.get("UPDATE_TOOLS") == "1"
bin_dir = os.path.expanduser("~/.local/bin")

def latest_tag(repo):
    req = urllib.request.Request(f"https://github.com/{repo}/releases/latest", method="HEAD")
    with urllib.request.urlopen(req) as resp:
        return resp.geturl().rstrip("/").split("/")[-1]

specs = [
    ("junegunn/fzf",       lambda t: f"https://github.com/junegunn/fzf/releases/download/{t}/fzf-{t.lstrip('v')}-linux_amd64.tar.gz", "fzf"),
    ("BurntSushi/ripgrep", lambda t: f"https://github.com/BurntSushi/ripgrep/releases/download/{t}/ripgrep-{t}-x86_64-unknown-linux-musl.tar.gz", "rg"),
    ("sharkdp/fd",         lambda t: f"https://github.com/sharkdp/fd/releases/download/{t}/fd-{t}-x86_64-unknown-linux-musl.tar.gz", "fd"),
    ("ajeetdsouza/zoxide", lambda t: f"https://github.com/ajeetdsouza/zoxide/releases/download/{t}/zoxide-{t.lstrip('v')}-x86_64-unknown-linux-musl.tar.gz", "zoxide"),
]

with tempfile.TemporaryDirectory() as tmp:
    for repo, url_fn, bin_name in specs:
        dst = os.path.join(bin_dir, bin_name)
        if os.path.exists(dst) and not update:
            print(f"    \033[90m· {bin_name:<12} already installed\033[0m")
            continue
        tag = latest_tag(repo)
        print(f"    \033[36m→\033[0m \033[97m{bin_name:<12}\033[0m \033[90minstalling {tag}...\033[0m")
        tgz = os.path.join(tmp, f"{bin_name}.tar.gz")
        urllib.request.urlretrieve(url_fn(tag), tgz)
        with tarfile.open(tgz, "r:gz") as tf:
            member = next(m for m in tf.getmembers() if os.path.basename(m.name) == bin_name and m.isfile())
            with tf.extractfile(member) as src, open(dst, "wb") as f:
                shutil.copyfileobj(src, f)
            os.chmod(dst, 0o755)
EOF
fi

# --- 2. Symlink configs ---
printf "\n ${cyan}Symlinks${reset}\n"
link_file() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    printf "    ${gray}· %-24s -> %s${reset}\n" "${dst/#$HOME/\~}" "${src/#$HOME/\~}"
    return
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "${dst}.bak"
    printf "    ${gray}! Backed up existing %s -> %s.bak${reset}\n" "${dst/#$HOME/\~}" "${dst/#$HOME/\~}"
  fi

  ln -s "$src" "$dst"
  printf "    ${cyan}→${reset} ${white}%-24s${reset} ${gray}-> %s${reset}\n" "${dst/#$HOME/\~}" "${src/#$HOME/\~}"
}

link_file "$DOTFILES_LINUX/.tmux.conf" "$HOME/.tmux.conf"
link_file "$DOTFILES_LINUX/.bashrc"    "$HOME/.bashrc"
link_file "$DOTFILES_LINUX/.inputrc"   "$HOME/.inputrc"
link_file "$DOTFILES_LINUX/tsetup"     "$HOME/utils/tsetup"

printf "\n ${cyan}Done.${reset}\n"
