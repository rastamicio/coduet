#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
QC="$SCRIPTS/claude-quota-check.sh"
R="$(mktemp -d)/proj"; mkdir -p "$R/docs"; git -C "$R" init -q -b main
E="$(mktemp -d)"; git -C "$E" init -q -b main
export HOME="$(mktemp -d)"
quota() { # five seven [resets]
  printf '{"read":"x","rate_limits":{"five_hour":{"used_percentage":%s,"resets_at":%s},"seven_day":{"used_percentage":%s,"resets_at":1793649600}}}\n' "$1" "${3:-1793160600}" "$2" > "$CODUET_HOME/claude-quota.json"
}
run() { printf '{"session_id":"s","hook_event_name":"UserPromptSubmit","cwd":"%s","prompt":"hi"}' "$1" | bash "$QC"; echo "code=$?"; }

quota 85 10
assert_eq "code=0" "$(run "$E")" "no plan: silent"
cp "$FIXTURES/plan-new.md" "$R/docs/plan.md"
rm -f "$CODUET_HOME/claude-quota.json"
assert_eq "code=0" "$(run "$R")" "no quota file: silent"
quota 85 10; touch -d '-11 minutes' "$CODUET_HOME/claude-quota.json"
assert_eq "code=0" "$(run "$R")" "stale file: silent"
printf '{"read":"x","rate_limits":{"five_hour":{"used_perc' > "$CODUET_HOME/claude-quota.json"
assert_eq "code=0" "$(run "$R")" "truncated file: silent"
quota 79 10
assert_eq "code=0" "$(run "$R")" "79%: silent"
quota 80 10
out="$(run "$R")"
assert_contains "$out" "Coduet: Claude quota at 80% (resets " "80%: warning"
assert_contains "$out" "Apply coduet:start Step 7 (handoff)." "80%: instruction"
assert_eq "code=0" "$(run "$R")" "same window: warned once"
quota 20 85 1793170000
assert_contains "$(run "$R")" "Claude quota at 85%" "seven_day counts"
rm -f "$CODUET_HOME/claude-quota-warned.txt"
printf '| Parameter | Value |\n|---|---|\n| Claude quota threshold for handoff (%%) | 90 |\n' > "$R/.coduet.md"
quota 85 10 1793180000
assert_eq "code=0" "$(run "$R")" ".coduet.md threshold 90: silent at 85%"

finish
