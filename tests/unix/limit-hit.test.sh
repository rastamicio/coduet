#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
export PATH="$FIXTURES:$PATH"
export HOME="$(mktemp -d)"
LH="$SCRIPTS/claude-limit-hit.sh"
N="$(mktemp)"; export CODUET_NOTIFY="$FIXTURES/notify-to-file"; export NOTIFY_FILE="$N"
M="$(mktemp)"; export FAKE_CODEX_MARKER="$M"
new_repo() { # plan-fixture
  local r; r="$(mktemp -d)/proj"; mkdir -p "$r/docs"
  git -C "$r" init -q -b main && git -C "$r" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  git -C "$r" branch feature/config; cp "$FIXTURES/$1" "$r/docs/plan.md"; echo "$r"
}
hit() { # dir error_type
  printf '{"session_id":"s","hook_event_name":"StopFailure","cwd":"%s","error_type":"%s","error":"429"}' "$1" "$2" | bash "$LH"
}

R="$(new_repo plan-new.md)"
FAKE_CODEX_MODE=ok hit "$R" overloaded
assert_eq "" "$(cat "$M")" "overloaded: nothing launched"
cmp -s "$FIXTURES/plan-new.md" "$R/docs/plan.md"; assert_eq 0 $? "overloaded: plan untouched"

FAKE_CODEX_MODE=ok hit "$R" rate_limit
sleep 1
assert_eq 1 "$(grep -c '^exec' "$M")" "ok: codex launched once"
assert_contains "$(cat "$R/docs/plan.md")" "**Status:** lent to Codex" "ok: task 1 lent"
assert_contains "$(cat "$R/docs/plan.md")" "Lent to Codex at " "ok: status section line"
assert_contains "$(cat "$R/docs/plan.md")" ": Task 1" "ok: status line names task 1"
assert_contains "$(cat "$N")" "Task 1" "ok: notification names the task"

: > "$M"
FAKE_CODEX_MODE=ok hit "$R" rate_limit
sleep 1
assert_eq "" "$(cat "$M")" "second hit: nothing new"

R="$(new_repo plan-new.md)"; : > "$M"; : > "$N"; rm -f "$CODUET_HOME"/claude-limit-*.txt
FAKE_CODEX_MODE=reached hit "$R" rate_limit
sleep 1
assert_eq "" "$(cat "$M")" "codex used up: nothing launched"
cmp -s "$FIXTURES/plan-new.md" "$R/docs/plan.md"; assert_eq 0 $? "codex used up: plan untouched"
assert_contains "$(cat "$N")" "Codex" "codex used up: notification"

R="$(new_repo plan-old.md)"; : > "$M"; rm -f "$CODUET_HOME"/claude-limit-*.txt
FAKE_CODEX_MODE=ok hit "$R" rate_limit
sleep 1
cmp -s "$FIXTURES/plan-old.md" "$R/docs/plan.md"; assert_eq 0 $? "old plan: file unchanged"
assert_eq "" "$(cat "$M")" "old plan: nothing launched"

finish
