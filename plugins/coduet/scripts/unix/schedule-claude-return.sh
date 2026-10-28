#!/usr/bin/env bash
# Schedules Claude's automatic return in a project after its quota resets.
#   schedule-claude-return.sh <project> [--at "YYYY-MM-DD HH:MM"] [--dry-run]
# Time: --at, else five_hour.resets_at from the status line (if read in the last 5 hours), else now + the reset
# estimate; plus the resume margin. One schedule per project: a newer one replaces the older.
source "$(dirname "$0")/common.sh"
PROJECT="$(cd "$1" && pwd)"; shift; AT=''; DRY=''
while [ $# -gt 0 ]; do case "$1" in --at) AT="$2"; shift 2 ;; --dry-run) DRY=1; shift ;; *) shift ;; esac; done
NAME="$(basename "$PROJECT")"
CL="$(find_claude)"; [ -n "$CL" ] || { echo "error=no-claude"; exit 1; }
"$CL" auth status >/dev/null 2>&1 || { echo "error=not-logged-in"; exit 1; }

if [ -z "$AT" ]; then
  Q="$CODUET_HOME/claude-quota.json"; R=''
  [ -n "$(find "$Q" -mmin -300 2>/dev/null)" ] && R="$(sed -n 's/.*"five_hour":{[^}]*"resets_at":\([0-9]*\).*/\1/p' "$Q")"
  [ -n "$R" ] || R=$(( $(date +%s) + $(coduet_param "$PROJECT" 'Quota reset estimate|stima.*reset' 5) * 3600 ))
  R=$(( R + $(coduet_param "$PROJECT" 'Resume margin|margine.*ripresa' 5) * 60 ))
  AT="$(date -d "@$R" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$R" '+%Y-%m-%d %H:%M')"
fi
echo "when=$AT"
if [ -n "$DRY" ]; then echo "command=$(claude_return_cmd "$CL" "$PROJECT")"; exit 0; fi
TOKEN="$(date +%s)$$"
echo "$TOKEN" > "$CODUET_HOME/claude-return-$NAME.token"
schedule_one "$AT" "$(printf '%q ' bash "$(dirname "$0")/claude-return.sh" "$PROJECT" "$TOKEN")" "claude-return"
