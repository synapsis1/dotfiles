#!/usr/bin/env bash
# First-time setup for a host that may not have git yet.
#
#   curl -fsSL https://raw.githubusercontent.com/synapsis1/dotfiles/main/bootstrap.sh | bash
#   wget -qO-  https://raw.githubusercontent.com/synapsis1/dotfiles/main/bootstrap.sh | bash
#
# Installs git if missing, clones (or updates) the repo into ~/.dotfiles, then runs install.sh.
set -euo pipefail

REPO_URL="https://github.com/synapsis1/dotfiles.git"
DEST="${DOTFILES_DIR:-$HOME/.dotfiles}"

SUDO=""
(( EUID != 0 )) && SUDO="sudo"

if ! command -v git >/dev/null 2>&1; then
    echo "bootstrap: installing git"
    if command -v apt-get >/dev/null 2>&1; then
        $SUDO apt-get update -qq && $SUDO apt-get install -y git
    elif command -v dnf >/dev/null 2>&1; then
        $SUDO dnf install -y git
    elif command -v yum >/dev/null 2>&1; then
        $SUDO yum install -y git
    else
        echo "bootstrap: no supported package manager found; install git and re-run" >&2
        exit 1
    fi
fi

if [[ -d "$DEST/.git" ]]; then
    echo "bootstrap: updating $DEST"
    git -C "$DEST" pull --ff-only
else
    echo "bootstrap: cloning into $DEST"
    git clone "$REPO_URL" "$DEST"
fi

exec "$DEST/install.sh" "$@"
