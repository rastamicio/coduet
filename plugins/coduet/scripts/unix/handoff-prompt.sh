#!/usr/bin/env bash
# Writes the Codex prompt for lending a Claude task of the plan to Codex. Costs Claude no tokens.
#   handoff-prompt.sh <plan> <task-number> <output-file>
source "$(dirname "$0")/common.sh"
PLAN="$1"; N="$2"; OUT="$3"
ROOT="$(git -C "$(dirname "$PLAN")" rev-parse --show-toplevel 2>/dev/null || dirname "$PLAN")"
REL="${PLAN#"$ROOT"/}"
TITLE="$(sed -n "s/^### Task $N:[[:space:]]*//p" "$PLAN" | head -n 1)"
BLOCK="$(awk -v n="$N" '/^### Task [0-9]+:/ { t = $3; sub(/:$/, "", t); f = (t == n) } /^## / { f = 0 } f' "$PLAN")"
VERIFY="$(awk '/^## Verification commands/ { f = 1; next } /^#/ { f = 0 } f && NF' "$PLAN")"
{
  echo "Implement Task $N ($TITLE) of the plan $REL, following its steps and the decisions recorded in the plan and its spec."
  echo "The task as written in the plan (your copy of the plan file may be older):"
  echo; echo "$BLOCK"
  echo
  echo "Do not commit. Do not modify files other than those listed in the task. Do not read, print or modify secret or local config files (.env and similar). Do not touch other tasks. If you can't finish, stop and explain. At the end write a summary of what you did and what you could not do."
  if [ -n "$VERIFY" ]; then echo; echo "Verification commands:"; echo "$VERIFY"; fi
} > "$OUT"
echo "prompt=$OUT"
