#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
. "$SCRIPTS/common.sh"

R="$(mktemp -d)/proj"; mkdir -p "$R/docs/plans" "$R/.codex-worktrees/x/docs"
git -C "$R" init -q -b main
cp "$FIXTURES/plan-new.md" "$R/docs/plans/feature.md"
cp "$FIXTURES/plan-new.md" "$R/.codex-worktrees/x/docs/copy.md"
assert_eq "$R/docs/plans/feature.md" "$(find_coduet_plan "$R")" "find: plan in docs/plans"
assert_eq "$R/docs/plans/feature.md" "$(find_coduet_plan "$R/docs")" "find: from a subfolder"
E="$(mktemp -d)"; git -C "$E" init -q -b main; echo "# Notes" > "$E/notes.md"
assert_eq "" "$(find_coduet_plan "$E")" "find: no plan"

assert_eq "1|Parser for the config file|feature/config" "$(plan_lendable "$FIXTURES/plan-new.md")" "lendable: only task 1"
assert_eq "" "$(plan_lendable "$FIXTURES/plan-old.md")" "lendable: old plan has none"

C="$(mktemp)"; cp "$FIXTURES/plan-new.md" "$C"
plan_set_status "$C" 1 "lent to Codex"
assert_eq "1" "$(diff "$FIXTURES/plan-new.md" "$C" | grep -c '^>')" "set_status: one line changed"
assert_contains "$(diff "$FIXTURES/plan-new.md" "$C")" "> **Status:** lent to Codex" "set_status: new value"
assert_eq "" "$(plan_lendable "$C")" "set_status: task 1 no longer lendable"

O="$(mktemp)"
out="$(bash "$SCRIPTS/handoff-prompt.sh" "$R/docs/plans/feature.md" 1 "$O")"
assert_eq "prompt=$O" "$out" "handoff: output line"
txt="$(cat "$O")"
assert_contains "$txt" "Implement Task 1 (Parser for the config file) of the plan docs/plans/feature.md" "handoff: goal"
assert_contains "$txt" "Do not commit." "handoff: rules"
assert_contains "$txt" "(.env and similar)" "handoff: secrets rule"
assert_contains "$txt" "npm run lint" "handoff: verification commands"
assert_contains "$txt" "**Base branch:** feature/config" "handoff: task block inlined"
assert_contains "$txt" "- [ ] Step 1: write the test" "handoff: task steps inlined"
assert_not_contains "$txt" "Token refresh" "handoff: other tasks not inlined"

finish
