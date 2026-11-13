# dotfiles

Baseline setup for remote Linux hosts: tmux, shared bash config, and a Claude Code status line.

## New host

```bash
git clone https://github.com/synapsis1/dotfiles.git ~/.dotfiles && ~/.dotfiles/install.sh
```

`install.sh` is safe to re-run. It:

1. Installs `tmux`, `git`, `curl` and `jq` if missing (apt, dnf or yum; uses sudo). Skip with `--no-packages`.
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
| `templates/claude-settings.json` | Minimal Claude Code settings for a fresh host |
| `tmux-cheatsheet.md` | One-screen tmux key reference |

## Host-specific config

Put anything that belongs to one machine in `~/.bashrc.local`; `common.sh` sources it if present. Nothing host-specific, and no secrets, belong in this repo.
