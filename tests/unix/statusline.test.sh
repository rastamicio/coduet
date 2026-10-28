#!/usr/bin/env bash
. "$(dirname "$0")/lib.sh"
SL="$SCRIPTS/claude-statusline.sh"
J='{"model":{"display_name":"Opus"},"rate_limits":{"five_hour":{"used_percentage":44,"resets_at":1793160600},"seven_day":{"used_percentage":12,"resets_at":1793649600}},"cwd":"/x"}'

out="$(printf '%s' "$J" | bash "$SL")"
q="$(cat "$CODUET_HOME/claude-quota.json" 2>/dev/null)"
assert_contains "$q" '"five_hour":{"used_percentage":44,"resets_at":1793160600}' "save: rate_limits kept"
assert_contains "$q" '"read":"' "save: read time"
assert_eq "Claude 5h 44% · week 12%" "$out" "no prev: short line"

echo '{"stale":1}' > "$CODUET_HOME/claude-quota.json"
printf '%s' '{"model":{"display_name":"Opus"}}' | bash "$SL" > /dev/null
assert_eq '{"stale":1}' "$(cat "$CODUET_HOME/claude-quota.json")" "no rate_limits: file untouched"

printf '%s' 'printf '"'"'%s'"'"' "prev \"ok\""' > "$CODUET_HOME/statusline-prev.txt"
assert_eq 'prev "ok"' "$(printf '%s' "$J" | bash "$SL")" "prev: output identical"
echo 'cat' > "$CODUET_HOME/statusline-prev.txt"
assert_eq "$J" "$(printf '%s' "$J" | bash "$SL")" "prev: gets the same stdin"
rm -f "$CODUET_HOME/statusline-prev.txt"

# install / uninstall on a test HOME
export HOME="$(mktemp -d)"; mkdir -p "$HOME/.claude"
ORIG='{"model":"opus","statusLine":{"type":"command","command":"node \"C:/x y/limits.mjs\""},"hooks":{}}'
echo "$ORIG" > "$HOME/.claude/settings.json"
out="$(bash "$SCRIPTS/statusline-install.sh" install)"
assert_contains "$out" "statusline=coduet" "install: status"
assert_contains "$out" "backup=$CODUET_HOME/settings.backup-" "install: backup"
assert_contains "$out" "undo=" "install: undo"
assert_eq 'node "C:/x y/limits.mjs"' "$(cat "$CODUET_HOME/statusline-prev.txt")" "install: previous command saved"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["model"]=="opus" and d["hooks"]=={} and "claude-statusline" in d["statusLine"]["command"]' "$HOME/.claude/settings.json"
assert_eq 0 $? "install: valid JSON, other keys intact"
[ -f "$CODUET_HOME/claude-statusline.sh" ]; assert_eq 0 $? "install: script copied to a stable path"
out="$(bash "$SCRIPTS/statusline-install.sh" install)"
assert_eq 'node "C:/x y/limits.mjs"' "$(cat "$CODUET_HOME/statusline-prev.txt")" "install twice: previous command kept"
assert_eq "statusline=coduet" "$(bash "$SCRIPTS/statusline-install.sh" status)" "status: coduet"
bash "$SCRIPTS/statusline-install.sh" uninstall > /dev/null
python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))==json.loads(sys.argv[2])' "$HOME/.claude/settings.json" "$ORIG"
assert_eq 0 $? "uninstall: back to the original"
assert_eq "statusline=other" "$(bash "$SCRIPTS/statusline-install.sh" status)" "status: other"

echo '{"model":"opus"}' > "$HOME/.claude/settings.json"
bash "$SCRIPTS/statusline-install.sh" install > /dev/null
bash "$SCRIPTS/statusline-install.sh" uninstall > /dev/null
assert_eq '{"model": "opus"}' "$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' "$HOME/.claude/settings.json")" "no previous: key removed"

finish
