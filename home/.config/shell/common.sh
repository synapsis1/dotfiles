# Shared interactive bash config, sourced from ~/.bashrc on every host.
# Host-specific additions belong in ~/.bashrc.local (not tracked).

# Only for interactive shells
case $- in
    *i*) ;;
    *) return ;;
esac

# --- History: large, de-duplicated, shared between open shells ---------------
shopt -s histappend
HISTCONTROL=ignoreboth
HISTSIZE=100000
HISTFILESIZE=1000000
case ";${PROMPT_COMMAND:-};" in
    *"history -a; history -n"*) ;;
    *) PROMPT_COMMAND="history -a; history -n${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac

# --- Aliases -----------------------------------------------------------------
alias gs='git status'
alias opus='claude --model opus'
alias sonnet='claude --model sonnet'
alias fable='claude --model fable'

# --- pbcopy: pipe text to the LOCAL clipboard over SSH (OSC 52) --------------
# Usage: pbcopy < file     or     some-command | pbcopy
if ! command -v pbcopy >/dev/null 2>&1; then
    pbcopy() {
        printf "\033]52;c;%s\a" "$(base64 | tr -d '\n')"
    }
fi

# --- Host-specific overrides -------------------------------------------------
[ -f "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"

# --- tmux: attach to (or create) the "main" session on SSH logins ------------
# Keep this last: it blocks until you detach.
if [[ -n "$SSH_TTY" && -z "$TMUX" ]] && command -v tmux >/dev/null 2>&1; then
    tmux new-session -A -s main
fi
