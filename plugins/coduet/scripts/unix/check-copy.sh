#!/usr/bin/env bash
# Reports the state of a local project copy, as key=value lines.
#   check-copy.sh [folder]
source "$(dirname "$0")/common.sh"
DIR="${1:-.}"
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
