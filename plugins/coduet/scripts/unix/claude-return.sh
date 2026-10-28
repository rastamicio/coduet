#!/usr/bin/env bash
# Run by the scheduler: restarts Claude in the project, unless a newer return was scheduled meanwhile.
#   claude-return.sh <project> <token>
source "$(dirname "$0")/common.sh"
PROJECT="$1"; NAME="$(basename "$PROJECT")"
[ "$(cat "$CODUET_HOME/claude-return-$NAME.token" 2>/dev/null)" = "$2" ] || exit 0
LOG="$CODUET_HOME/claude-return-$NAME.log"
CL="$(find_claude)"; [ -n "$CL" ] || { echo "$(now_iso) ERROR no claude" >> "$LOG"; exit 1; }
echo "$(now_iso) START" >> "$LOG"
cd "$PROJECT" || exit 1
eval "$(claude_return_cmd "$CL" "$PROJECT")" < /dev/null >> "$LOG" 2>&1
RC=$?; echo "$(now_iso) END exit=$RC" >> "$LOG"
