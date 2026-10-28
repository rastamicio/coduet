#!/usr/bin/env bash
# Reports the state of a local project copy, as key=value lines.
#   check-copy.sh [folder] [--worktree-dir beside|inside]
source "$(dirname "$0")/common.sh"
DIR="."; WTDIR="beside"
while [ $# -gt 0 ]; do case "$1" in --worktree-dir) WTDIR="$2"; shift 2;; *) DIR="$1"; shift;; esac; done
cd "$DIR" 2>/dev/null || { echo "folder=missing"; exit 1; }
echo "folder=$(pwd)"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then echo "git=no"; exit 0; fi
echo "git=yes"
echo "remote=$(git remote get-url origin 2>/dev/null || echo none)"
echo "branch=$(git rev-parse --abbrev-ref HEAD)"
echo "uncommitted=$(git status --porcelain | wc -l | tr -d ' ')"
if git remote get-url origin >/dev/null 2>&1; then
  git fetch -q origin 2>/dev/null && echo "fetch=ok" || echo "fetch=failed"
  UP="$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null)"
  if [ -n "$UP" ]; then
    echo "upstream=$UP"
    echo "behind=$(git rev-list --count HEAD.."$UP")"
    echo "ahead=$(git rev-list --count "$UP"..HEAD)"
  else echo "upstream=none"; fi
fi
echo "worktrees=$(( $(git worktree list | wc -l) - 1 ))"
echo "codex_branches=$(git branch --list 'codex/*' | wc -l | tr -d ' ')"
[ -f package.json ] && { [ -d node_modules ] && echo "deps=installed" || echo "deps=missing"; }
for ex in .env.example .env.sample .dev.vars.example; do
  base="${ex%.example}"; base="${base%.sample}"
  [ -f "$ex" ] && { [ -f "$base" ] && echo "secret_file=$base:present" || echo "secret_file=$base:missing"; }
done
grep -q 'codex-' .git/info/exclude 2>/dev/null && echo "work_files_excluded=yes" || echo "work_files_excluded=no"
# With worktrees inside the project: test and tool configs that don't mention .codex-worktrees (Claude reviews each one).
if [ "$WTDIR" = inside ] || [ "$WTDIR" = dentro ]; then
  MISS=""; FOUND=0
  for f in vitest.config.* vite.config.* jest.config.* playwright.config.* tsconfig.json eslint.config.* .eslintrc* pytest.ini setup.cfg tox.ini pyproject.toml package.json; do
    [ -f "$f" ] || continue
    case "$f" in
      package.json) grep -q '"jest"' "$f" || continue;;
      pyproject.toml|setup.cfg|tox.ini) grep -q 'pytest' "$f" || continue;;
    esac
    FOUND=1; grep -q 'codex-worktrees' "$f" || MISS="$MISS${MISS:+,}$f"
  done
  if [ -n "$MISS" ]; then echo "worktree_exclusion=missing:$MISS"; elif [ $FOUND -eq 1 ]; then echo "worktree_exclusion=ok"; else echo "worktree_exclusion=no-config"; fi
fi
