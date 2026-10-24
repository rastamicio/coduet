#!/usr/bin/env bash
# Resumes a Codex session after the quota reset (run by the scheduler).
#   codex-resume.sh <worktree> <task> <session-id> [effort]
source "$(dirname "$0")/common.sh"
WT="$1"; TASK="$2"; SES="$3"; EFFORT="${4:-medium}"
LOG="$WT/.codex-ripresa.log"; OUT="$WT/.codex-output-ripresa.txt"
cd "$WT" || exit 1
echo "$(now_iso) AVVIO ripresa" >> "$LOG"
codex exec resume "$SES" -c sandbox_mode="workspace-write" -c model_reasoning_effort="$EFFORT" \
  -o .codex-esito.md "Continue the task from where you stopped. Do not commit. At the end write a summary." > "$OUT" 2>&1
CODE=$?
if codex_hit_limit "$OUT"; then echo "$(now_iso) LIMITE ancora raggiunto" >> "$LOG"
elif [ $CODE -ne 0 ]; then echo "$(now_iso) ERRORE codice $CODE" >> "$LOG"
else echo "$(now_iso) COMPLETATO" >> "$LOG"; fi
