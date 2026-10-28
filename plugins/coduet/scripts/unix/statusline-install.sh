#!/usr/bin/env bash
# Adds or removes Coduet's status line in ~/.claude/settings.json, keeping the user's previous one (chained).
#   statusline-install.sh install|uninstall|status
# Prints statusline=coduet|other|none, and backup=/undo= on install. Needs python3 or node to edit JSON safely.
source "$(dirname "$0")/common.sh"
S="$HOME/.claude/settings.json"; PREV="$CODUET_HOME/statusline-prev.txt"; DEST="$CODUET_HOME/claude-statusline.sh"
CMD="bash \"$DEST\""

json() { # python code with d = settings dict; args after
  local code="$1"; shift
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$S" "$@" <<PY
import json, os, sys
p = sys.argv[1]; a = sys.argv[2:]
try:
    d = json.load(open(p, encoding="utf-8")) if os.path.exists(p) else {}
    assert isinstance(d, dict)
except Exception:
    print("error=invalid-settings"); sys.exit(2)
$code
PY
  else echo "error=no-json-tool"; return 2; fi
}
current() { json 'print(d.get("statusLine", {}).get("command", ""))'; }
save() { json "$1"'
tmp = p + ".tmp"
json.dump(d, open(tmp, "w", encoding="utf-8"), indent=2, ensure_ascii=False); os.replace(tmp, p)' "${@:2}"; }

cur="$(current)" || { echo "$cur"; exit 1; }
case "$cur" in error=*) echo "$cur"; exit 1 ;; esac
case "$1" in
  status)
    case "$cur" in *claude-statusline*) echo "statusline=coduet" ;; '') echo "statusline=none" ;; *) echo "statusline=other" ;; esac ;;
  install)
    mkdir -p "$HOME/.claude"; cp "$(dirname "$0")/claude-statusline.sh" "$DEST"
    case "$cur" in *claude-statusline*) echo "statusline=coduet"; exit 0 ;; esac
    B="$CODUET_HOME/settings.backup-$(date '+%Y%m%d-%H%M%S').json"
    [ -f "$S" ] && cp "$S" "$B"
    if [ -n "$cur" ]; then printf '%s' "$cur" > "$PREV"; else rm -f "$PREV"; fi
    save 'sl = d.get("statusLine") or {}; sl["type"] = "command"; sl["command"] = a[0]; d["statusLine"] = sl' "$CMD"
    echo "statusline=coduet"; [ -f "$B" ] && echo "backup=$B"
    echo "undo=bash \"$(cd "$(dirname "$0")" && pwd)/statusline-install.sh\" uninstall" ;;
  uninstall)
    case "$cur" in *claude-statusline*) ;; *) echo "statusline=$( [ -n "$cur" ] && echo other || echo none )"; exit 0 ;; esac
    if [ -s "$PREV" ]; then save 'd["statusLine"]["command"] = a[0]' "$(cat "$PREV")"; echo "statusline=other"
    else save 'd.pop("statusLine", None)'; echo "statusline=none"; fi
    rm -f "$PREV" ;;
  *) echo "error=usage"; exit 1 ;;
esac
