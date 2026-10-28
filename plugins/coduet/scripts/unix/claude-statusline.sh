#!/usr/bin/env bash
# Claude Code status line: saves Claude's quota (rate_limits) for Coduet, then shows the user's previous status line.
# Standalone: statusline-install copies it to ~/.coduet so plugin updates don't break the status line.
H="${CODUET_HOME:-$HOME/.coduet}"
IN="$(cat)"
RL="$(printf '%s' "$IN" | awk '
  { s = s $0 "\n" }
  END {
    i = index(s, "\"rate_limits\":"); if (!i) exit
    s = substr(s, i + 14); sub(/^[ \t\n]*/, "", s); if (substr(s, 1, 1) != "{") exit
    d = 0
    for (k = 1; k <= length(s); k++) { c = substr(s, k, 1); if (c == "{") d++; else if (c == "}") { d--; if (!d) { print substr(s, 1, k); exit } } }
  }')"
if [ -n "$RL" ]; then
  mkdir -p "$H"
  printf '{"read":"%s","rate_limits":%s}\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$RL" > "$H/claude-quota.json.tmp" &&
    mv -f "$H/claude-quota.json.tmp" "$H/claude-quota.json"
fi
if [ -s "$H/statusline-prev.txt" ]; then
  printf '%s' "$IN" | sh -c "$(cat "$H/statusline-prev.txt")"
elif [ -n "$RL" ]; then
  pct() { printf '%s' "$RL" | sed -n "s/.*\"$1\":{[^}]*\"used_percentage\":\([0-9.]*\).*/\1/p"; }
  echo "Claude 5h $(pct five_hour)% · week $(pct seven_day)%"
fi
