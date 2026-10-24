#!/usr/bin/env bash
# Shows the state of Codex tasks recorded by Coduet.
#   codex-status.sh            -> all tasks of the last 24 hours
#   codex-status.sh <task>     -> one task
source "$(dirname "$0")/common.sh"
FILTER="$1"
found=0
for f in "$CODUET_TASKS"/*.txt; do
  [ -f "$f" ] || continue
  task="$(task_get "$f" task)"; [ -n "$FILTER" ] && [ "$task" != "$FILTER" ] && continue
  find "$f" -mmin -1440 | grep -q . || [ "$(task_get "$f" status)" = "running" ] || continue
  status="$(task_get "$f" status)"; pid="$(task_get "$f" pid)"; wt="$(task_get "$f" worktree)"
  if [ "$status" = "running" ] && [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then status="stopped"; fi
  started="$(task_get "$f" started)"
  mins=""; if [ -n "$started" ]; then
    s=$(date -d "$started" +%s 2>/dev/null || date -j -f '%Y-%m-%dT%H:%M:%S' "$started" +%s 2>/dev/null)
    [ -n "$s" ] && mins=$(( ( $(date +%s) - s ) / 60 ))
  fi
  last="$(grep -v '^\s*$' "$wt/.codex-output.txt" 2>/dev/null | grep -Ev '^(diff|index|@@|[+-])' | tail -n 1 | cut -c1-160)"
  echo "task=$task status=$status minutes=${mins:-?} tokens=$(task_get "$f" tokens) files=$(task_get "$f" files) project=$(basename "$(task_get "$f" project)")"
  [ -n "$last" ] && echo "  last: $last"
  found=1
done
[ $found -eq 0 ] && echo "no-tasks"
echo "active=$(active_count)"
