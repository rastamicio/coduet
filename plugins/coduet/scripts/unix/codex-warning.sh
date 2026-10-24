#!/usr/bin/env bash
# Backup warning: shows a desktop notice only if Claude did not step in and the resume did not succeed.
#   codex-warning.sh <worktree> <task> <session-id> [effort]
WT="$1"; TASK="$2"; SES="$3"; EFFORT="${4:-medium}"
LOG="$WT/.codex-ripresa.log"
TXT="$(cat "$LOG" 2>/dev/null)"
echo "$TXT" | grep -q 'CONTROLLO CLAUDE' && exit 0
echo "$TXT" | grep -q 'COMPLETATO' && exit 0
if [ -z "$TXT" ]; then WHY="the resume never started"
elif echo "$TXT" | grep -q LIMITE; then WHY="the Codex quota is still used up"
else WHY="the resume failed (see .codex-output-ripresa.txt)"; fi
MSG="Coduet - $TASK: $WHY, and Claude could not step in. To restart it by hand: cd \"$WT\" && codex exec resume $SES -c sandbox_mode=workspace-write -c model_reasoning_effort=$EFFORT \"Continue the task. Do not commit.\""
if command -v osascript >/dev/null 2>&1; then osascript -e "display dialog \"${MSG//\"/\\\"}\" with title \"Coduet\"" >/dev/null 2>&1
elif command -v notify-send >/dev/null 2>&1; then notify-send "Coduet" "$MSG"
else { echo "$MSG" > "$HOME/Desktop/coduet-avviso.txt"; } 2>/dev/null || echo "$MSG" > "$HOME/coduet-avviso.txt"; fi
