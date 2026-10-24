#!/usr/bin/env bash
# Schedules the automatic resume and the backup warning (macOS and Linux).
#   schedule-resume.sh <worktree> <task> <session-id> <resume "YYYY-MM-DD HH:MM"> <warning "YYYY-MM-DD HH:MM"> [effort]
# Uses "at" when available, otherwise systemd-run (Linux) or a LaunchAgent (macOS).
D="$(cd "$(dirname "$0")" && pwd)"
WT="$1"; TASK="$2"; SES="$3"; RESUME="$4"; WARN="$5"; EFFORT="${6:-medium}"
q() { printf '%q ' "$@"; }
CMD1="$(q bash "$D/codex-resume.sh" "$WT" "$TASK" "$SES" "$EFFORT")"
CMD2="$(q bash "$D/codex-warning.sh" "$WT" "$TASK" "$SES" "$EFFORT")"

schedule_one() { # when command label
  local when="$1" cmd="$2" label="$3"
  if command -v at >/dev/null 2>&1; then
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
schedule_one "$RESUME" "$CMD1" resume
schedule_one "$WARN" "$CMD2" warning
