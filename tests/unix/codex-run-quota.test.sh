#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
export PATH="$FIXTURES:$PATH"

new_repo() {
  local r; r="$(mktemp -d)/proj"; mkdir -p "$r"
  git -C "$r" init -q -b main && git -C "$r" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  echo "$r"
}
P="$(mktemp)"; echo "Do it." > "$P"

R="$(new_repo)"
out="$(FAKE_CODEX_MODE=reached bash "$SCRIPTS/codex-run.sh" "$R" t1 "$P" --worktree-dir inside)"; code=$?
assert_contains "$out" "CODEX WAITING task=t1 reason=quota resets_at=1793210994" "reached: waiting line"
assert_eq 4 "$code" "reached: exit code 4"
assert_eq 1 "$(git -C "$R" worktree list | wc -l | tr -d ' ')" "reached: no worktree"

R="$(new_repo)"
out="$(FAKE_CODEX_MODE=noserver bash "$SCRIPTS/codex-run.sh" "$R" t2 "$P" --worktree-dir inside)"
assert_contains "$out" "CODEX FINISHED task=t2 status=done" "noserver: launches as before"

R="$(new_repo)"
out="$(FAKE_CODEX_MODE=ok bash "$SCRIPTS/codex-run.sh" "$R" t3 "$P" --worktree-dir inside)"
assert_contains "$out" "CODEX FINISHED task=t3 status=done" "ok: launches"

finish
