#!/usr/bin/env bash
# Set up a Linux host from this repo. Safe to re-run.
#
#   ./install.sh                   install missing packages, link files, hook ~/.bashrc
#   ./install.sh --with-docker     also install Docker Engine from Docker's apt repo (Debian/Ubuntu only)
#   ./install.sh --no-packages     skip the package step
#   ./install.sh --check-packages  list what would be installed, then exit (combine with --with-docker)
#
# Package lists live in packages/apt.txt (Debian/Ubuntu) and packages/dnf.txt (RHEL family).
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
INSTALL_PACKAGES=1
CHECK_ONLY=0
WITH_DOCKER=0
for arg in "$@"; do
    case "$arg" in
        --no-packages) INSTALL_PACKAGES=0 ;;
        --check-packages) CHECK_ONLY=1 ;;
        --with-docker) WITH_DOCKER=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

say() { printf '%s\n' "$*"; }

SUDO=""
(( EUID != 0 )) && SUDO="sudo"

# --- 1. Packages -------------------------------------------------------------
apt_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; }
rpm_installed() { rpm -q "$1" >/dev/null 2>&1; }

# Sets PKG_MGR and MISSING for this host's package manager.
find_missing_packages() {
    local list check p
    MISSING=()
    if command -v apt-get >/dev/null 2>&1; then
        PKG_MGR=apt-get; list="$REPO/packages/apt.txt"; check=apt_installed
    elif command -v dnf >/dev/null 2>&1; then
        PKG_MGR=dnf; list="$REPO/packages/dnf.txt"; check=rpm_installed
    elif command -v yum >/dev/null 2>&1; then
        PKG_MGR=yum; list="$REPO/packages/dnf.txt"; check=rpm_installed
    else
        PKG_MGR=""
        return 0
    fi
    while IFS= read -r p; do
        p="${p%%#*}"; p="${p//[[:space:]]/}"
        [[ -z "$p" ]] && continue
        "$check" "$p" || MISSING+=("$p")
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
    [[ "$PKG_MGR" == apt-get ]] && $SUDO apt-get update -qq
    # One transaction first; if any single name is unavailable that fails as a
    # whole, so fall back to one at a time and report what could not be installed.
    if $SUDO "$PKG_MGR" install -y "${MISSING[@]}"; then
        return 0
    fi
    say "packages: batch install failed; retrying one at a time"
    local failed=() p
    for p in "${MISSING[@]}"; do
        $SUDO "$PKG_MGR" install -y "$p" || failed+=("$p")
    done
    if (( ${#failed[@]} )); then
        say "packages: could NOT install: ${failed[*]}"
    fi
}

# Docker Engine from Docker's own apt repository (Debian and Ubuntu).
DOCKER_PACKAGES=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
install_docker() {
    if ! command -v apt-get >/dev/null 2>&1; then
        say "docker: --with-docker is Debian/Ubuntu only; this family gets podman from packages/dnf.txt"
        return 0
    fi
    local ID="" VERSION_CODENAME="" UBUNTU_CODENAME=""
    # shellcheck disable=SC1091
    . /etc/os-release
    local suite="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    if [[ "$ID" != debian && "$ID" != ubuntu ]] || [[ -z "$suite" ]]; then
        say "docker: unsupported distribution '$ID'; skipping"
        return 0
    fi

    local missing=() p
    for p in "${DOCKER_PACKAGES[@]}"; do
        apt_installed "$p" || missing+=("$p")
    done
    if (( ${#missing[@]} == 0 )); then
        say "docker: all present"
    else
        say "docker: missing: ${missing[*]}"
        (( CHECK_ONLY )) && return 0
        local key=/etc/apt/keyrings/docker.asc src=/etc/apt/sources.list.d/docker.sources
        if [[ ! -s "$key" ]]; then
            $SUDO install -m 0755 -d /etc/apt/keyrings
            curl -fsSL "https://download.docker.com/linux/$ID/gpg" | $SUDO tee "$key" >/dev/null
            $SUDO chmod a+r "$key"
        fi
        if [[ ! -e "$src" && ! -e /etc/apt/sources.list.d/docker.list ]]; then
            printf 'Types: deb\nURIs: https://download.docker.com/linux/%s\nSuites: %s\nComponents: stable\nSigned-By: %s\n' \
                "$ID" "$suite" "$key" | $SUDO tee "$src" >/dev/null
            say "docker: added apt repository ($ID $suite)"
        fi
        $SUDO apt-get update -qq
        $SUDO apt-get install -y "${missing[@]}"
    fi
    (( CHECK_ONLY )) && return 0

    # Let the login user run docker without sudo (takes effect at next login).
    if (( EUID != 0 )) && ! id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
        $SUDO usermod -aG docker "$USER"
        say "docker: added $USER to the docker group; log out and back in to use it"
    fi
}

if (( CHECK_ONLY )); then
    install_packages
    (( WITH_DOCKER )) && install_docker
    exit 0
fi
if (( INSTALL_PACKAGES )); then
    install_packages || say "packages: install failed; continuing (missing tools will simply be unavailable)"
fi
if (( WITH_DOCKER )); then
    install_docker || say "docker: install failed; continuing"
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
