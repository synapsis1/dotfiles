#!/usr/bin/env bash
# Set up a Linux host from this repo. Safe to re-run.
#
#   ./install.sh                install missing packages, link files, hook ~/.bashrc
#   ./install.sh --no-packages  skip the package step
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
PACKAGES=(tmux git curl jq)
INSTALL_PACKAGES=1
[[ "${1:-}" == "--no-packages" ]] && INSTALL_PACKAGES=0

say() { printf '%s\n' "$*"; }

# --- 1. Packages -------------------------------------------------------------
install_packages() {
    local missing=() p
    for p in "${PACKAGES[@]}"; do
        command -v "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    if (( ${#missing[@]} == 0 )); then
        say "packages: all present"
        return 0
    fi
    local sudo=""
    (( EUID != 0 )) && sudo="sudo"
    if command -v apt-get >/dev/null 2>&1; then
        $sudo apt-get update -qq && $sudo apt-get install -y "${missing[@]}"
    elif command -v dnf >/dev/null 2>&1; then
        $sudo dnf install -y "${missing[@]}"
    elif command -v yum >/dev/null 2>&1; then
        $sudo yum install -y "${missing[@]}"
    else
        say "packages: no supported package manager; install manually: ${missing[*]}"
        return 0
    fi
}
if (( INSTALL_PACKAGES )); then
    install_packages || say "packages: install failed; continuing (missing tools will simply be unavailable)"
fi

# --- 2. Symlink everything under home/ into $HOME ----------------------------
link_file() {
    local src="$1" rel dest
    rel="${src#"$REPO/home/"}"
    dest="$HOME/$rel"
    mkdir -p "$(dirname "$dest")"
    if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
        say "ok      ~/$rel"
        return 0
    fi
    if [[ -e "$dest" || -L "$dest" ]]; then
        mv "$dest" "$dest.bak.$STAMP"
        say "backup  ~/$rel -> ~/$rel.bak.$STAMP"
    fi
    ln -s "$src" "$dest"
    say "link    ~/$rel"
}
while IFS= read -r -d '' f; do
    link_file "$f"
done < <(find "$REPO/home" -type f -print0 | sort -z)

# --- 3. Hook ~/.bashrc (append one line; never replace the distro's file) ----
HOOK='[ -f ~/.config/shell/common.sh ] && . ~/.config/shell/common.sh'
touch "$HOME/.bashrc"
if grep -qF '.config/shell/common.sh' "$HOME/.bashrc"; then
    say "ok      ~/.bashrc already sources common.sh"
else
    printf '\n# Shared shell config (from %s)\n%s\n' "$REPO" "$HOOK" >> "$HOME/.bashrc"
    say "hook    ~/.bashrc now sources common.sh"
fi

# --- 4. Claude Code baseline settings (only if none exist) -------------------
if [[ -e "$HOME/.claude/settings.json" ]]; then
    say "ok      ~/.claude/settings.json exists; left alone"
else
    mkdir -p "$HOME/.claude"
    cp "$REPO/templates/claude-settings.json" "$HOME/.claude/settings.json"
    say "create  ~/.claude/settings.json"
fi

say
say "Done. Open a new shell (or: source ~/.bashrc) to pick it up."
