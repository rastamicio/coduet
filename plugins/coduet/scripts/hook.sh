#!/usr/bin/env bash
# Runs a Coduet hook script for this system, passing the hook's stdin through.
#   hook.sh <name>   (claude-quota-check, claude-limit-hit)
D="$(cd "$(dirname "$0")" && pwd)"
case "${OS:-}$(uname -s 2>/dev/null)" in
  *Windows_NT*|*MINGW*|*MSYS*|*CYGWIN*)
    exec powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$D/windows/$1.ps1" 2>/dev/null || echo "$D/windows/$1.ps1")" ;;
  *) exec bash "$D/unix/$1.sh" ;;
esac
