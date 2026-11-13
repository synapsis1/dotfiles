#!/usr/bin/env bash
# Set up a Linux host from this repo. Safe to re-run.
#
#   ./install.sh                   install missing packages, link files, hook ~/.bashrc
#   ./install.sh --no-packages     skip the package step
#   ./install.sh --check-packages  list packages that would be installed, then exit
#
# Package lists live in packages/apt.txt (Debian/Ubuntu) and packages/dnf.txt (RHEL family).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
INSTALL_PACKAGES=1
CHECK_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --no-packages) INSTALL_PACKAGES=0 ;;
        --check-packages) CHECK_ONLY=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

say() { printf '%s\n' "$*"; }

# --- 1. Packages -------------------------------------------------------------
# Sets PKG_MGR and MISSING for this host's package manager.
find_missing_packages() {
    local list is_installed p
    MISSING=()
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MGR=apt-get; list="$REPO/packages/apt.txt"
        is_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; }
    elif command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
        PKG_MGR=$(command -v dnf >/dev/null 2>&1 && echo dnf || echo yum); list="$REPO/packages/dnf.txt"
        is_installed() { rpm -q "$1" >/dev/null 2>&1; }
    else
        PKG_MGR=""
        return 0
    fi
    while IFS= read -r p; do
        p="${p%%#*}"; p="${p//[[:space:]]/}"
        [[ -z "$p" ]] && continue
        is_installed "$p" || MISSING+=("$p")
    done < "$list"
}

install_packages() {
    find_missing_packages
    if [[ -z "$PKG_MGR" ]]; then
        say "packages: no supported package manager; skipping"
        return 0
    fi
    if (( ${#MISSING[@]} == 0 )); then
        say "packages: all present"
        return 0
    fi
    say "packages: missing: ${MISSING[*]}"
    (( CHECK_ONLY )) && return 0
    local sudo=""
    (( EUID != 0 )) && sudo="sudo"
    if [[ "$PKG_MGR" == apt-get ]]; then
        $sudo apt-get update -qq && $sudo apt-get install -y "${MISSING[@]}"
    else
        $sudo "$PKG_MGR" install -y "${MISSING[@]}"
    fi
}
if (( CHECK_ONLY )); then
    install_packages
    exit 0
fi
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
