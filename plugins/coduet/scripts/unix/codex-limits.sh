#!/usr/bin/env bash
# Reads Codex's usage limits through `codex app-server` (JSON-RPC over stdio, one message per line).
#   codex-limits.sh [--timeout <seconds>]
# Prints ok, primary_*/secondary_* (used, resets_at, window_mins), plan, reached; error when ok=0. Uses no quota.
D="$(cd "$(dirname "$0")" && pwd)"
. "$D/common.sh"
TIMEOUT=20
[ "$1" = "--timeout" ] && TIMEOUT="$2"
VER="$(json_field "$PLUGIN_ROOT/.claude-plugin/plugin.json" version)"

TMP="$(mktemp -d)"; IN="$TMP/in"; OUT="$TMP/out.jsonl"
mkfifo "$IN"
codex app-server --listen stdio:// < "$IN" > "$OUT" 2>/dev/null &
CPID=$!
exec 3>"$IN"   # keeps Codex's stdin open until we have the answer
printf '%s\n' "{\"id\":1,\"method\":\"initialize\",\"params\":{\"clientInfo\":{\"name\":\"coduet\",\"version\":\"${VER:-0}\"}}}" \
  '{"method":"initialized"}' \
  '{"id":2,"method":"account/rateLimits/read","params":{"excludeResetCreditDetails":true}}' >&3 2>/dev/null

LINE=''; ERR='timeout'
end=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$end" ]; do
  LINE="$(grep '"id":2' "$OUT" 2>/dev/null | head -n 1)"
  [ -n "$LINE" ] && break
  kill -0 "$CPID" 2>/dev/null || { ERR='app-server-exited'; break; }
  sleep 0.2
done
exec 3>&-
kill "$CPID" 2>/dev/null; wait "$CPID" 2>/dev/null
rm -rf "$TMP"

if [ -z "$LINE" ]; then echo "ok=0"; echo "error=$ERR"; exit 0; fi
case "$LINE" in *'"error":'*)
  echo "ok=0"; echo "error=$(echo "$LINE" | sed -n 's/.*"message":"\([^"]*\)".*/\1/p')"; exit 0 ;;
esac
window() { # name
  local w; w="$(echo "$LINE" | sed -n "s/.*\"$1\":{\([^}]*\)}.*/\1/p")"
  echo "$1_used=$(echo "$w" | sed -n 's/.*"usedPercent":\([0-9.]*\).*/\1/p')"
  echo "$1_resets_at=$(echo "$w" | sed -n 's/.*"resetsAt":\([0-9]*\).*/\1/p')"
  echo "$1_window_mins=$(echo "$w" | sed -n 's/.*"windowDurationMins":\([0-9]*\).*/\1/p')"
}
window primary
window secondary
echo "plan=$(echo "$LINE" | sed -n 's/.*"planType":"\([^"]*\)".*/\1/p')"
echo "reached=$(echo "$LINE" | sed -n 's/.*"rateLimitReachedType":"\([^"]*\)".*/\1/p')"
echo "ok=1"
