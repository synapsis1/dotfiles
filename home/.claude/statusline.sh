#!/bin/bash
input=$(cat)
MODEL=$(echo "$input" | jq -r '.model.display_name')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
PCT=$(echo "$input" | jq -r '(.context_window.used_percentage // 0) | floor')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DISCORD_ENABLED=$(jq -r '.enabledPlugins."discord@claude-plugins-official" // false' ~/.claude/settings.json 2>/dev/null)
INDICATOR=""
[ "$DISCORD_ENABLED" = "true" ] && INDICATOR=" 📨"

BRANCH=$(git --no-optional-locks -C "$CWD" branch --show-current 2>/dev/null)
[ -z "$BRANCH" ] && BRANCH=$(git --no-optional-locks -C "$CWD" rev-parse --short HEAD 2>/dev/null)

# Color by usage: green < 50, yellow < 80, red otherwise
if [ "$PCT" -ge 80 ]; then C=31; elif [ "$PCT" -ge 50 ]; then C=33; else C=32; fi

WIDTH=20
FILLED=$((PCT * WIDTH / 100))
[ "$FILLED" -gt "$WIDTH" ] && FILLED=$WIDTH
BAR=""
for ((i = 0; i < WIDTH; i++)); do
  if [ "$i" -lt "$FILLED" ]; then BAR="${BAR}█"; else BAR="${BAR}░"; fi
done

# Line 1: model and branch
printf '\033[36m[%s]\033[0m' "$MODEL"
[ -n "$BRANCH" ] && printf ' \033[35m%s\033[0m' "$BRANCH"
printf '%s\n' "$INDICATOR"

# Line 2: context bar and cost
printf '\033[%sm%s\033[0m %s%%  \033[2m$%.2f\033[0m\n' "$C" "$BAR" "$PCT" "$COST"
