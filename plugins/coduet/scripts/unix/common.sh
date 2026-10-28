#!/usr/bin/env bash
# Shared helpers for Coduet scripts (macOS and Linux).

CODUET_HOME="${CODUET_HOME:-$HOME/.coduet}"
CODUET_TASKS="$CODUET_HOME/tasks"
PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$CODUET_TASKS"

now_iso() { date '+%Y-%m-%dT%H:%M:%S'; }

# Prints the path of the claude CLI, or nothing.
find_claude() {
  if command -v claude >/dev/null 2>&1; then command -v claude; return; fi
  if [ -x "$HOME/.local/bin/claude" ]; then echo "$HOME/.local/bin/claude"; return; fi
}

# Reads a JSON string field from a small flat JSON file (no jq needed).
json_field() { # file field
  sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$1" | head -n 1
}

# Task record: one key=value file per task in $CODUET_TASKS.
task_file() { # project task
  echo "$CODUET_TASKS/$(echo "$1__$2" | tr -c 'A-Za-z0-9_.\n-' '_').txt"
}
task_set() { # file key value
  local f="$1" k="$2" v="$3" tmp
  tmp="$(mktemp)"
  [ -f "$f" ] && grep -v "^$k=" "$f" > "$tmp"
  echo "$k=$v" >> "$tmp"
  mv "$tmp" "$f"
}
task_get() { # file key
  [ -f "$1" ] && sed -n "s/^$2=//p" "$1" | tail -n 1
}
active_count() {
  local n=0 f pid
  for f in "$CODUET_TASKS"/*.txt; do
    [ -f "$f" ] || continue
    [ "$(task_get "$f" status)" = "running" ] || continue
    pid="$(task_get "$f" pid)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then n=$((n+1)); fi
  done
  echo "$n"
}

# Parses a Codex output file.
codex_tokens() { awk 'f{gsub(/[^0-9]/,""); if($0!=""){print; exit}} /tokens used/{f=1}' "$1" 2>/dev/null | tail -n 1; }
codex_session() { sed -n 's/^session id:[[:space:]]*//p' "$1" 2>/dev/null | head -n 1; }
codex_hit_limit() { grep -Eiq 'usage limit|rate limit|limit reached' "$1" 2>/dev/null; }

# Reads codex-limits output on stdin. Returns 0 = Codex has quota, 1 = used up, 2 = unknown.
codex_available() {
  local k v ok='' p=0 s=0 r=''
  while IFS='=' read -r k v; do
    case "$k" in ok) ok="$v" ;; primary_used) p="${v%%.*}" ;; secondary_used) s="${v%%.*}" ;; reached) r="$v" ;; esac
  done
  [ "$ok" = 1 ] || return 2
  [ -z "$r" ] && [ "${p:-0}" -lt 100 ] && [ "${s:-0}" -lt 100 ] && return 0
  return 1
}
# Reads codex-limits output on stdin; prints resets_at of the used-up window (secondary if both), or nothing.
codex_reset_at() {
  local k v p=0 s=0 r='' pr='' sr=''
  while IFS='=' read -r k v; do
    case "$k" in primary_used) p="${v%%.*}" ;; secondary_used) s="${v%%.*}" ;; reached) r="$v" ;;
      primary_resets_at) pr="$v" ;; secondary_resets_at) sr="$v" ;; esac
  done
  if [ "${s:-0}" -ge 100 ] || [ "$r" = secondary ]; then echo "$sr"
  elif [ "${p:-0}" -ge 100 ] || [ -n "$r" ]; then echo "$pr"; fi
}

# Coduet plan: a .md file at the repository root or under docs/ (3 levels) with "## Status and handoff" and "PC copy:".
# Prints its path (the most recently modified if several), or nothing.
find_coduet_plan() { # dir
  local root f best=''
  root="$(git -C "$1" rev-parse --show-toplevel 2>/dev/null || (cd "$1" && pwd))"
  while IFS= read -r f; do
    grep -q '^## Status and handoff' "$f" 2>/dev/null && grep -q 'PC copy:' "$f" 2>/dev/null || continue
    if [ -z "$best" ] || [ "$f" -nt "$best" ]; then best="$f"; fi
  done < <( { find "$root" -maxdepth 1 -name '*.md' -type f; [ -d "$root/docs" ] && find "$root/docs" -maxdepth 4 -name '*.md' -type f \
    -not -path '*/.codex-worktrees/*' -not -path '*/node_modules/*'; } 2>/dev/null )
  [ -n "$best" ] && echo "$best"
}
# One line "<N>|<title>|<base branch>" per task with Executor Claude, Codex-ready yes, Status open.
plan_lendable() { # plan
  awk '
    function flush() { if (n != "" && tolower(ex) == "claude" && tolower(cr) == "yes" && tolower(st) == "open") print n "|" ti "|" br }
    /^### Task [0-9]+:/ { flush(); n = $3; sub(/:$/, "", n); ti = $0; sub(/^### Task [0-9]+:[ \t]*/, "", ti); ex = cr = st = br = ""; next }
    /^## / { flush(); n = ""; next }
    n != "" && /\*\*Executor:\*\*/    { ex = $0; sub(/.*\*\*Executor:\*\*[ \t]*/, "", ex); sub(/[ \t]+$/, "", ex) }
    n != "" && /\*\*Codex-ready:\*\*/ { cr = $0; sub(/.*\*\*Codex-ready:\*\*[ \t]*/, "", cr); sub(/[ \t]+$/, "", cr) }
    n != "" && /\*\*Status:\*\*/      { st = $0; sub(/.*\*\*Status:\*\*[ \t]*/, "", st); sub(/[ \t]+$/, "", st) }
    n != "" && /\*\*Base branch:\*\*/ { br = $0; sub(/.*\*\*Base branch:\*\*[ \t]*/, "", br); sub(/[ \t]+$/, "", br) }
    END { flush() }' "$1"
}
# Changes only the Status line of task N.
plan_set_status() { # plan N status
  local tmp; tmp="$(mktemp)"
  awk -v n="$2" -v st="$3" '
    /^### Task [0-9]+:/ { t = $3; sub(/:$/, "", t); cur = (t == n) }
    /^## / { cur = 0 }
    cur && /\*\*Status:\*\*/ { sub(/\*\*Status:\*\*.*/, "**Status:** " st) }
    { print }' "$1" > "$tmp" && cat "$tmp" > "$1"
  rm -f "$tmp"
}

# Value of a parameter from the project's .coduet.md, else the personal coduet-config, else the default.
# The parameter line is matched by an extended regex (names may be translated); the value is the last number on it.
coduet_param() { # project-root regex default
  local f v
  for f in "$1/.coduet.md" "$HOME/.claude/skills/coduet-config/SKILL.md"; do
    [ -f "$f" ] || continue
    v="$(grep -Ei "$2" "$f" | tail -n 1 | grep -Eo '[0-9]+' | tail -n 1)"
    [ -n "$v" ] && { echo "$v"; return; }
  done
  echo "$3"
}
# Hook input: prints the value of a top-level string field ("cwd", "error_type", ...).
hook_field() { # json field
  printf '%s' "$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n 1
}
# Local HH:MM of a Unix time.
hhmm() { date -d "@$1" '+%H:%M' 2>/dev/null || date -r "$1" '+%H:%M'; }

# Schedules a shell command once (at, systemd-run or a LaunchAgent). Prints scheduled=<label> via=… when=… or error.
schedule_one() { # when command label
  local when="$1" cmd="$2" label="$3"
  # macOS ships "at" with its daemon off: jobs would never run, so it uses launchd below.
  if command -v at >/dev/null 2>&1 && [ "$(uname)" != "Darwin" ]; then
    echo "$cmd" | at "$(date -d "$when" '+%H:%M %Y-%m-%d' 2>/dev/null || date -j -f '%Y-%m-%d %H:%M' "$when" '+%H:%M %m/%d/%Y')" 2>/dev/null && { echo "scheduled=$label via=at when=$when"; return 0; }
  fi
  if command -v systemd-run >/dev/null 2>&1; then
    systemd-run --user --quiet --on-calendar="$when" --unit="coduet-$label-$(date +%s)" bash -c "$cmd" 2>/dev/null && { echo "scheduled=$label via=systemd when=$when"; return 0; }
  fi
  if [ "$(uname)" = "Darwin" ]; then
    local id="dev.coduet.$label.$(date +%s)" plist="$HOME/Library/LaunchAgents/$id.plist"
    local Y M Dd H Mi; read -r Y M Dd H Mi <<< "$(echo "$when" | tr '-' ' ' | tr ':' ' ')"
    cat > "$plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>$id</string>
<key>ProgramArguments</key><array><string>/bin/bash</string><string>-c</string><string>$cmd; launchctl unload "$plist"; rm -f "$plist"</string></array>
<key>StartCalendarInterval</key><dict><key>Month</key><integer>$((10#$M))</integer><key>Day</key><integer>$((10#$Dd))</integer><key>Hour</key><integer>$((10#$H))</integer><key>Minute</key><integer>$((10#$Mi))</integer></dict>
</dict></plist>
EOF
    launchctl load "$plist" && { echo "scheduled=$label via=launchd when=$when"; return 0; }
  fi
  echo "scheduled=$label via=none error=no-scheduler"; return 1
}

# The command that restarts Claude in a project after its quota resets (headless, limited permissions):
# Coduet's scripts (quoted or not, as the skill runs them), read-only git, commit/merge/push without force,
# worktree list/add/remove, and the plan's verification commands.
claude_return_cmd() { # claude-path project
  local s="$PLUGIN_ROOT/scripts/unix" plan v t
  t="Bash(bash \"$s/:*),Bash(bash $s/:*),Bash(git status:*),Bash(git diff:*),Bash(git log:*),Bash(git add:*),Bash(git commit:*)"
  t="$t,Bash(git merge:*),Bash(git worktree list:*),Bash(git worktree add:*),Bash(git worktree remove:*),Bash(git fetch:*),Bash(git push)"
  plan="$(find_coduet_plan "$2")"
  if [ -n "$plan" ]; then
    while IFS= read -r v; do [ -n "$v" ] && t="$t,Bash($v),Bash($v:*)"; done < <(awk '/^## Verification commands/ { f = 1; next } /^#/ { f = 0 } f && NF' "$plan")
  fi
  printf '%q -p %q --permission-mode acceptEdits --allowedTools %q' "$1" \
    "Use the coduet:start skill: resume after Claude's quota reset." "$t,Read,Edit,Write,Grep,Glob"
}

# True if a yes/no parameter is switched on in .coduet.md or the personal coduet-config.
coduet_param_on() { # project-root regex
  local f l
  for f in "$1/.coduet.md" "$HOME/.claude/skills/coduet-config/SKILL.md"; do
    [ -f "$f" ] || continue
    l="$(grep -Ei "$2" "$f" | tail -n 1)"
    [ -n "$l" ] && { echo "$l" | grep -Eqi '\| *(on|yes|sì|si|attivo|attiva) *\|'; return; }
  done
  return 1
}
# Desktop notice that doesn't block (CODUET_NOTIFY overrides, for tests).
notify() { # message
  if [ -n "$CODUET_NOTIFY" ]; then "$CODUET_NOTIFY" "$1"
  elif command -v osascript >/dev/null 2>&1; then osascript -e "display notification \"${1//\"/\\\"}\" with title \"Coduet\"" >/dev/null 2>&1
  elif command -v notify-send >/dev/null 2>&1 && notify-send "Coduet" "$1" 2>/dev/null; then :
  else { echo "$1" >> "$HOME/Desktop/coduet-avviso.txt"; } 2>/dev/null || echo "$1" >> "$HOME/coduet-avviso.txt"; fi
}
