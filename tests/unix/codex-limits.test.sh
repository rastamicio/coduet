#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
. "$SCRIPTS/common.sh"
export PATH="$FIXTURES:$PATH"

out="$(FAKE_CODEX_MODE=ok bash "$SCRIPTS/codex-limits.sh")"
assert_contains "$out" "ok=1" "ok: ok=1"
assert_contains "$out" "primary_used=30" "ok: primary_used"
assert_contains "$out" "secondary_used=10" "ok: secondary_used"
assert_contains "$out" "primary_window_mins=300" "ok: window"
assert_contains "$out" "plan=plus" "ok: plan"
echo "$out" | codex_available; assert_eq 0 $? "ok: codex_available"

out="$(FAKE_CODEX_MODE=reached bash "$SCRIPTS/codex-limits.sh")"
assert_contains "$out" "reached=primary" "reached: reached"
echo "$out" | codex_available; assert_eq 1 $? "reached: codex_available"
assert_eq 1793210994 "$(echo "$out" | codex_reset_at)" "reached: codex_reset_at"

start=$(date +%s)
out="$(FAKE_CODEX_MODE=silent bash "$SCRIPTS/codex-limits.sh" --timeout 2)"
el=$(( $(date +%s) - start ))
assert_contains "$out" "ok=0" "silent: ok=0"
assert_contains "$out" "error=timeout" "silent: error"
[ "$el" -lt 5 ]; assert_eq 0 $? "silent: ends within 5 s (took $el)"
sleep 0.3
assert_eq "" "$(pgrep -f "$FIXTURES/codex" || true)" "silent: no process left"

out="$(FAKE_CODEX_MODE=noserver bash "$SCRIPTS/codex-limits.sh" --timeout 3)"
assert_contains "$out" "ok=0" "noserver: ok=0"
echo "$out" | codex_available; assert_eq 2 $? "noserver: codex_available"

finish
