#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
export PATH="$FIXTURES:$PATH"
export HOME="$(mktemp -d)"
SR="$SCRIPTS/schedule-claude-return.sh"
R="$(mktemp -d)/proj"; mkdir -p "$R/docs"; git -C "$R" init -q -b main; cp "$FIXTURES/plan-new.md" "$R/docs/plan.md"
when_of() { echo "$1" | sed -n 's/^when=//p'; }

# Recent quota file → resets_at + margin (5 min)
RESET=$(( $(date +%s) + 3600 ))
printf '{"read":"x","rate_limits":{"five_hour":{"used_percentage":99,"resets_at":%s}}}\n' "$RESET" > "$CODUET_HOME/claude-quota.json"
out="$(bash "$SR" "$R" --dry-run)"
eval "set -- $(echo "$out" | sed -n 's/^command=//p')"; ARGS="$(printf '%s\n' "$@")"
assert_eq "$(date -d "@$((RESET + 300))" '+%Y-%m-%d %H:%M')" "$(when_of "$out")" "time from quota file + margin"
assert_contains "$ARGS" "--permission-mode
acceptEdits" "command: permission mode"
assert_contains "$ARGS" "coduet:start" "command: resume prompt"
assert_not_contains "$ARGS" "--force" "command: no force"
assert_not_contains "$ARGS" "--dangerously" "command: no dangerous mode"
assert_contains "$ARGS" 'Bash(bash "'"$SCRIPTS"'/:*)' "command: quoted script path allowed"
assert_contains "$ARGS" "Bash(bash $SCRIPTS/:*)" "command: unquoted script path allowed"
assert_contains "$ARGS" "Bash(npm test)" "command: plan verification commands allowed"
assert_not_contains "$ARGS" "Bash(git worktree:*)" "command: git worktree narrowed"

# Old quota file → now + estimate (5 h) + margin
touch -d '-6 hours' "$CODUET_HOME/claude-quota.json"
out="$(bash "$SR" "$R" --dry-run)"
exp="$(date -d "@$(( $(date +%s) + 5*3600 + 300 ))" '+%Y-%m-%d %H:%M')"
assert_eq "$exp" "$(when_of "$out")" "old file: estimate"

# --at wins
assert_eq "2030-01-02 03:04" "$(when_of "$(bash "$SR" "$R" --at "2030-01-02 03:04" --dry-run)")" "--at"

assert_contains "$(FAKE_CLAUDE_LOGGED=0 bash "$SR" "$R" --dry-run)" "error=not-logged-in" "not logged in"
assert_contains "$(PATH=/usr/bin:/bin bash "$SR" "$R" --dry-run)" "error=no-claude" "no claude"

# The runner starts claude only if it is still the latest schedule for the project
M="$(mktemp)"; export FAKE_CLAUDE_MARKER="$M"
TOKEN=tok1; echo "$TOKEN" > "$CODUET_HOME/claude-return-proj.token"
bash "$SCRIPTS/claude-return.sh" "$R" "old-token"
assert_eq "" "$(cat "$M")" "runner: stale token does nothing"
bash "$SCRIPTS/claude-return.sh" "$R" "$TOKEN"
assert_contains "$(cat "$M")" "claude -p" "runner: starts claude"
assert_contains "$(cat "$CODUET_HOME/claude-return-proj.log")" "START" "runner: log"

finish
