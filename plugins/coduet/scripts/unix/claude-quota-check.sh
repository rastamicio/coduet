#!/usr/bin/env bash
# UserPromptSubmit hook: one line of context for Claude when its quota passes the handoff threshold, once per window.
# Silent (and free) otherwise, and outside Coduet projects.
source "$(dirname "$0")/common.sh"
IN="$(cat)"
CWD="$(hook_field "$IN" cwd)"; [ -n "$CWD" ] || CWD="$PWD"
PLAN="$(find_coduet_plan "$CWD")"; [ -n "$PLAN" ] || exit 0
Q="$CODUET_HOME/claude-quota.json"
[ -n "$(find "$Q" -mmin -10 2>/dev/null)" ] || exit 0
ROOT="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "$CWD")"
THR="$(coduet_param "$ROOT" 'Claude quota threshold|soglia.*quota.*Claude' 80)"
W="$CODUET_HOME/claude-quota-warned.txt"
best=''; bp=-1; br=''
for win in five_hour seven_day; do
  obj="$(sed -n "s/.*\"$win\":{\([^}]*\)}.*/\1/p" "$Q")"
  p="$(echo "$obj" | sed -n 's/.*"used_percentage":\([0-9]*\).*/\1/p')"
  r="$(echo "$obj" | sed -n 's/.*"resets_at":\([0-9]*\).*/\1/p')"
  [ -n "$p" ] && [ -n "$r" ] || continue
  [ "$p" -ge "$THR" ] || continue
  grep -qx "$win:$r" "$W" 2>/dev/null && continue
  if [ "$p" -gt "$bp" ]; then best="$win"; bp="$p"; br="$r"; fi
done
[ -n "$best" ] || exit 0
echo "$best:$br" >> "$W"
echo "Coduet: Claude quota at $bp% (resets $(hhmm "$br")). Apply coduet:start Step 7 (handoff)."
