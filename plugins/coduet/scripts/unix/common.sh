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
