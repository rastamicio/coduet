#!/usr/bin/env bash
# Schedules the automatic resume and the backup warning (macOS and Linux).
#   schedule-resume.sh <worktree> <task> <session-id> <resume "YYYY-MM-DD HH:MM"> <warning "YYYY-MM-DD HH:MM"> [effort]
# Uses "at" when available, otherwise systemd-run (Linux) or a LaunchAgent (macOS).
D="$(cd "$(dirname "$0")" && pwd)"
source "$D/common.sh"
WT="$1"; TASK="$2"; SES="$3"; RESUME="$4"; WARN="$5"; EFFORT="${6:-medium}"
q() { printf '%q ' "$@"; }
CMD1="$(q bash "$D/codex-resume.sh" "$WT" "$TASK" "$SES" "$EFFORT")"
CMD2="$(q bash "$D/codex-warning.sh" "$WT" "$TASK" "$SES" "$EFFORT")"

schedule_one "$RESUME" "$CMD1" resume
schedule_one "$WARN" "$CMD2" warning
