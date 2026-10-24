#!/usr/bin/env bash
# Coduet update helper.
#   coduet-update.sh check   -> prints installed/latest versions and whether an update exists
#   coduet-update.sh apply   -> updates the marketplace and the plugin with the claude CLI
# Output: key=value lines. Errors are appended to ~/.coduet/aggiornamento.log.
source "$(dirname "$0")/common.sh"
MODE="${1:-check}"
LOG="$CODUET_HOME/aggiornamento.log"
MANIFEST="$PLUGIN_ROOT/.claude-plugin/plugin.json"

CLAUDE="$(find_claude)"
echo "cli=${CLAUDE:-missing}"

# Installed version and marketplace name.
INSTALLED=""; MARKET=""
if [ -n "$CLAUDE" ]; then
  LIST="$("$CLAUDE" plugin list 2>/dev/null)"
  MARKET="$(echo "$LIST" | sed -n 's/.*coduet@\([A-Za-z0-9_.-]*\).*/\1/p' | head -n 1)"
  INSTALLED="$(echo "$LIST" | awk '/coduet@/{f=1;next} f&&/Version:/{print $2; exit}')"
fi
[ -z "$INSTALLED" ] && INSTALLED="$(json_field "$MANIFEST" version)"
echo "installed=$INSTALLED"
echo "marketplace=${MARKET:-coduet}"

if [ "$MODE" = "check" ]; then
  REPO="$(json_field "$MANIFEST" repository)"
  RAW="$(echo "$REPO" | sed -E 's#https://github.com/([^/]+)/([^/]+).*#https://raw.githubusercontent.com/\1/\2/main#')"
  LATEST="$(curl -fsSL --max-time 10 "$RAW/plugins/coduet/.claude-plugin/plugin.json" 2>/dev/null | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  if [ -z "$LATEST" ]; then echo "latest=unknown"; echo "update=unknown"; exit 0; fi
  echo "latest=$LATEST"
  echo "$(date '+%Y-%m-%d %H:%M') $LATEST" > "$CODUET_HOME/ultimo-controllo.txt"
  if [ "$INSTALLED" = "$LATEST" ]; then echo "update=no"
  elif [ "$(printf '%s\n%s\n' "$INSTALLED" "$LATEST" | sort -V | tail -n 1)" = "$LATEST" ]; then echo "update=yes"
  else echo "update=no"; fi
  echo "changelog=$RAW/CHANGELOG.md"
  exit 0
fi

if [ "$MODE" = "apply" ]; then
  if [ -z "$CLAUDE" ]; then echo "result=no-cli"; exit 2; fi
  M="${MARKET:-coduet}"
  OUT1="$("$CLAUDE" plugin marketplace update "$M" 2>&1)"; R1=$?
  OUT2="$("$CLAUDE" plugin update "coduet@$M" 2>&1)"; R2=$?
  AFTER="$("$CLAUDE" plugin list 2>/dev/null | awk '/coduet@/{f=1;next} f&&/Version:/{print $2; exit}')"
  echo "before=$INSTALLED"
  echo "after=${AFTER:-unknown}"
  if [ $R1 -eq 0 ] && [ $R2 -eq 0 ]; then echo "result=ok"; exit 0; fi
  { echo "$(now_iso) update failed"; echo "$OUT1"; echo "$OUT2"; } >> "$LOG"
  echo "result=error"; echo "log=$LOG"
  echo "manual=$CLAUDE plugin marketplace update $M && $CLAUDE plugin update coduet@$M"
  exit 1
fi
echo "usage: coduet-update.sh check|apply"; exit 2
