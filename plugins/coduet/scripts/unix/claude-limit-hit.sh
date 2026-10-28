#!/usr/bin/env bash
# StopFailure hook (rate_limit): Claude hit its usage limit. Without spending Claude tokens, lends the plan's ready
# Claude tasks to Codex (if Codex has quota), schedules Claude's return and tells the user. Silent outside Coduet projects.
D="$(cd "$(dirname "$0")" && pwd)"
source "$D/common.sh"
IN="$(cat)"
# Claude Code puts the error type in "error" ("error_type" in some versions).
ET="$(hook_field "$IN" error_type)"; [ -n "$ET" ] || ET="$(hook_field "$IN" error)"
[ "$ET" = "rate_limit" ] || exit 0
CWD="$(hook_field "$IN" cwd)"; [ -n "$CWD" ] || CWD="$PWD"
PLAN="$(find_coduet_plan "$CWD")"; [ -n "$PLAN" ] || exit 0
command -v codex >/dev/null 2>&1 || exit 0
ROOT="$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || echo "$CWD")"; NAME="$(basename "$ROOT")"
LOG="$CODUET_HOME/claude-limit-$NAME.log"

# Once per quota window.
Q="$CODUET_HOME/claude-quota.json"; RESET=''
[ -n "$(find "$Q" -mmin -300 2>/dev/null)" ] && RESET="$(sed -n 's/.*"five_hour":{[^}]*"resets_at":\([0-9]*\).*/\1/p' "$Q")"
WIN="${RESET:-$(date '+%Y%m%d%H')}"
REG="$CODUET_HOME/claude-limit-$NAME.txt"
grep -qx "window=$WIN" "$REG" 2>/dev/null && exit 0
echo "window=$WIN" > "$REG"
echo "$(now_iso) Claude hit its limit (window $WIN), plan $PLAN" >> "$LOG"

LIM="$(bash "$D/codex-limits.sh")"
echo "$LIM" | codex_available; AV=$?
LENT=()
if [ "$AV" -ne 1 ]; then
  CFG=("$ROOT/.coduet.md" "$HOME/.claude/skills/coduet-config/SKILL.md")
  EFFORT="$(grep -Ehi 'Codex reasoning|ragionamento' "${CFG[@]}" 2>/dev/null | grep -Eoi '\| *(low|medium|high) *\|' | head -n 1 | tr -dc 'a-z')"
  MAX="$(coduet_param "$ROOT" 'Concurrent Codex|task.*contemporanei' 2)"
  WTD=beside
  grep -Ehi 'Worktree folder|Cartella dei worktree' "${CFG[@]}" 2>/dev/null | head -n 1 | grep -Eqi '\| *(inside|dentro) *\|' && WTD=inside
  mkdir -p "$CODUET_HOME/prompts"
  while IFS='|' read -r N TITLE BASE; do
    [ -n "$N" ] || continue
    P="$CODUET_HOME/prompts/$NAME-task$N.md"; bash "$D/handoff-prompt.sh" "$PLAN" "$N" "$P" > /dev/null
    OUT="$CODUET_HOME/prompts/$NAME-task$N.out"
    nohup bash "$D/codex-run.sh" "$ROOT" "task$N" "$P" --base "${BASE:-HEAD}" --effort "${EFFORT:-medium}" --max "$MAX" --worktree-dir "$WTD" \
      < /dev/null > "$OUT" 2>&1 &
    for _ in $(seq 1 50); do [ -s "$OUT" ] && break; sleep 0.2; done
    FIRST="$(head -n 1 "$OUT")"; echo "$(now_iso) Task $N: $FIRST" >> "$LOG"
    case "$FIRST" in "CODEX STARTED"*) plan_set_status "$PLAN" "$N" "lent to Codex"; LENT+=("Task $N") ;; esac
  done < <(plan_lendable "$PLAN")
fi

if [ ${#LENT[@]} -gt 0 ]; then
  LIST="$(IFS=,; echo "${LENT[*]}" | sed 's/,/, /g')"
  awk -v line="- Lent to Codex at $(date '+%Y-%m-%d %H:%M'): $LIST" '{ print } /^## Status and handoff/ { print line }' "$PLAN" > "$PLAN.tmp" && cat "$PLAN.tmp" > "$PLAN"; rm -f "$PLAN.tmp"
fi

RET=''
if coduet_param_on "$ROOT" 'automatic return|ritorno automatico'; then
  RET="$(bash "$D/schedule-claude-return.sh" "$ROOT" 2>&1)"; echo "$(now_iso) return: $RET" >> "$LOG"
fi
case "$RET" in
  *"scheduled=claude-return via="*) BACK="Claude restarts by itself at $(echo "$RET" | sed -n 's/^when=//p')." ;;
  *) # Return off or not possible: a notice when the quota should be back.
    T="${RESET:-$(( $(date +%s) + $(coduet_param "$ROOT" 'Quota reset estimate|stima.*reset' 5) * 3600 ))}"
    AT="$(date -d "@$T" '+%Y-%m-%d %H:%M' 2>/dev/null || date -r "$T" '+%Y-%m-%d %H:%M')"
    BACK="Around $AT Claude's quota is back: write \"riprendi Coduet\" to continue."
    [ -z "$CODUET_NOTIFY" ] && schedule_one "$AT" "$(printf '%q ' bash "$D/notify.sh" "Coduet - Claude is available again in $NAME: write \"riprendi Coduet\".")" claude-notice >> "$LOG" 2>&1 ;;
esac
if [ "$AV" -eq 1 ]; then MSG="Claude hit its usage limit and Codex has no quota left either: each resumes its own tasks after the reset. $BACK"
elif [ ${#LENT[@]} -gt 0 ]; then MSG="Claude hit its usage limit: lent to Codex $LIST. $BACK"
else MSG="Claude hit its usage limit: no task ready for Codex. $BACK"; fi
echo "$(now_iso) $MSG" >> "$LOG"
notify "Coduet - $MSG"
exit 0
