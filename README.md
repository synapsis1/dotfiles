# dotfiles

Baseline setup for remote Linux hosts: tmux, shared bash config, and a Claude Code status line.

## New host

```bash
curl -fsSL https://raw.githubusercontent.com/synapsis1/dotfiles/main/bootstrap.sh | bash
```

No curl? Use `wget -qO- <same URL> | bash`. `bootstrap.sh` installs git if it is missing, clones this repo into `~/.dotfiles`, and runs `install.sh`.

`install.sh` is safe to re-run. It:

1. Installs whatever is missing from `packages/apt.txt` (Debian/Ubuntu) or `packages/dnf.txt` (RHEL family), using sudo. Skip with `--no-packages`; preview with `--check-packages`. Existing packages are not upgraded.
   - `--with-docker` (Debian/Ubuntu only) also adds Docker's apt repository, installs Docker Engine with the compose and buildx plugins, and adds you to the `docker` group. RHEL-family hosts get `podman` and `crun` from `packages/dnf.txt` instead.
2. Symlinks every file under `home/` into `$HOME`, backing up anything it replaces to `<name>.bak.<timestamp>`.
3. Appends one line to `~/.bashrc` that sources `~/.config/shell/common.sh`. The distro's `.bashrc` is otherwise untouched.
4. Creates `~/.claude/settings.json` from `templates/` only if none exists.

## Updating

```bash
git -C ~/.dotfiles pull      # files are symlinks, so edits are live immediately
~/.dotfiles/install.sh       # only needed when files were added
```

## What's here

| Path | Purpose |
|---|---|
| `home/.tmux.conf` | Mouse, OSC 52 clipboard, extended keys, truecolor |
| `home/.config/shell/common.sh` | History settings, aliases, `pbcopy` over SSH, tmux auto-attach on SSH login |
| `home/.claude/statusline.sh` | Claude Code status line (model, branch, context bar, cost) |
| `packages/apt.txt`, `packages/dnf.txt` | Packages to install, one per line |
| `templates/claude-settings.json` | Minimal Claude Code settings for a fresh host |
| `tmux-cheatsheet.md` | One-screen tmux key reference |

## Host-specific config

Put anything that belongs to one machine in `~/.bashrc.local`; `common.sh` sources it if present. Nothing host-specific, and no secrets, belong in this repo.
