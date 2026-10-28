#!/usr/bin/env bash
# Runs one Codex task in its own git worktree and records its status.
#   codex-run.sh <project-folder> <task-name> <prompt-file> [--base <branch>] [--effort <low|medium|high>] [--max <n>]
#                [--worktree-dir beside|inside] [--image <file>]...
# Run it in the background: it ends with a single "CODEX ..." summary line.
# Codex runs in a detached worker, so it goes on (and records its outcome) even if this script or the Claude session stops.
source "$(dirname "$0")/common.sh"

if [ "$1" = "--worker" ]; then # internal: --worker <task-file> <effort> <skip> [-i <image>]...
  TF="$2"; EFFORT="$3"; SKIP="$4"; shift 4
  task_set "$TF" pid "$$"
  WT="$(task_get "$TF" worktree)"; OUT="$WT/.codex-output.txt"
  codex exec --cd "$WT" --sandbox workspace-write -c model_reasoning_effort="$EFFORT" $SKIP "$@" \
    -o "$WT/.codex-esito.md" - < "$WT/.codex-prompt.md" > "$OUT" 2>&1
  CODE=$?
  TOK="$(codex_tokens "$OUT")"; SES="$(codex_session "$OUT")"
  FILES="$(git -C "$WT" status --porcelain | grep -v '\.codex-' | wc -l | tr -d ' ')"
  task_set "$TF" ended "$(now_iso)"; task_set "$TF" exit "$CODE"; task_set "$TF" tokens "${TOK:-?}"
  task_set "$TF" session "$SES"; task_set "$TF" files "$FILES"
  if codex_hit_limit "$OUT"; then STATUS=limit; elif [ "$CODE" -eq 0 ]; then STATUS=done; else STATUS=error; fi
  task_set "$TF" status "$STATUS"
  exit 0
fi

PROJECT="$(cd "$1" && pwd)"; TASK="$2"; PROMPT="$3"; shift 3
BASE=""; EFFORT="medium"; MAX=2; WTDIR="beside"; IMGS=()
while [ $# -gt 0 ]; do case "$1" in
  --base) BASE="$2"; shift 2;; --effort) EFFORT="$2"; shift 2;; --max) MAX="$2"; shift 2;; --image) IMGS+=(-i "$2"); shift 2;;
  --worktree-dir) WTDIR="$2"; shift 2;;
  *) shift;; esac; done
NAME="$(basename "$PROJECT")"
TF="$(task_file "$NAME" "$TASK")"

if [ "$(active_count)" -ge "$MAX" ]; then
  echo "CODEX QUEUED task=$TASK reason=max-$MAX-active"; exit 3
fi

case "$WTDIR" in inside|dentro) WT="$PROJECT/.codex-worktrees/$TASK";; *) WT="$(dirname "$PROJECT")/$NAME-codex-$TASK";; esac
cd "$PROJECT" || exit 1
if [ ! -d "$WT" ]; then
  [ -z "$BASE" ] && BASE="$(git rev-parse --abbrev-ref HEAD)"
  git worktree add -q "$WT" -b "codex/$TASK" "$BASE" || { echo "CODEX ERROR task=$TASK reason=worktree"; exit 1; }
fi
EXCL="$(git rev-parse --git-common-dir)/info/exclude"
grep -q '.codex-' "$EXCL" 2>/dev/null || printf '%s\n' '.codex-*' 'riprendi-codex.*' 'avviso-riserva.*' >> "$EXCL"
grep -qx '.codex-worktrees/' "$EXCL" 2>/dev/null || echo '.codex-worktrees/' >> "$EXCL"
cp "$PROMPT" "$WT/.codex-prompt.md"

task_set "$TF" project "$PROJECT"; task_set "$TF" task "$TASK"; task_set "$TF" worktree "$WT"
task_set "$TF" status running; task_set "$TF" started "$(now_iso)"; task_set "$TF" effort "$EFFORT"
for k in pid ended exit tokens session files; do task_set "$TF" "$k" ""; done
SKIP=""; git -C "$WT" rev-parse >/dev/null 2>&1 || SKIP="--skip-git-repo-check"
# New session and no terminal: the worker survives the end of this script and of the Claude session.
if command -v setsid >/dev/null 2>&1; then DET=(setsid nohup); else DET=(nohup); fi
"${DET[@]}" bash "$0" --worker "$TF" "$EFFORT" "$SKIP" "${IMGS[@]}" </dev/null >/dev/null 2>&1 &
PID=$!
echo "CODEX STARTED task=$TASK worktree=$WT pid=$PID"

wait "$PID"
while [ "$(task_get "$TF" status)" = "running" ] && kill -0 "$(task_get "$TF" pid)" 2>/dev/null; do sleep 5; done
[ "$(task_get "$TF" status)" = "running" ] && task_set "$TF" status error
echo "CODEX FINISHED task=$TASK status=$(task_get "$TF" status) files=$(task_get "$TF" files) tokens=$(task_get "$TF" tokens) session=$(task_get "$TF" session) worktree=$WT"
