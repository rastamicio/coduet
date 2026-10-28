# Schedules Claude's automatic return in a project after its quota resets (Windows Task Scheduler).
#   schedule-claude-return.ps1 -Project <folder> [-At "yyyy-MM-dd HH:mm"] [-DryRun]
# Time: -At, else five_hour.resets_at from the status line (if read in the last 5 hours), else now + the reset
# estimate; plus the resume margin. One task per project: a newer one replaces the older.
param([string]$Project, [string]$At = '', [switch]$DryRun)
. (Join-Path $PSScriptRoot 'common.ps1')
$Project = (Resolve-Path -LiteralPath $Project).Path
$name = Split-Path $Project -Leaf
$cl = Find-Claude
if (-not $cl) { 'error=no-claude'; exit 1 }
& $cl auth status *> $null
if ($LASTEXITCODE -ne 0) { 'error=not-logged-in'; exit 1 }

if (-not $At) {
  $q = Join-Path $CoduetHome 'claude-quota.json'; $r = $null
  if ((Test-Path $q) -and (Get-Item $q).LastWriteTime -gt (Get-Date).AddHours(-5)) {
    try { $r = [long](Get-Content $q -Raw | ConvertFrom-Json).rate_limits.five_hour.resets_at } catch { }
  }
  $t = if ($r) { [DateTimeOffset]::FromUnixTimeSeconds($r).LocalDateTime } else { (Get-Date).AddHours([int](Coduet-Param $Project 'Quota reset estimate|stima.*reset' '5')) }
  $At = $t.AddMinutes([int](Coduet-Param $Project 'Resume margin|margine.*ripresa' '5')).ToString('yyyy-MM-dd HH:mm')
}
"when=$At"
if ($DryRun) { "command=`"$cl`" $(Claude-ReturnArgs $Project)"; exit 0 }
$token = [guid]::NewGuid().ToString('N')
Set-Content -Path (Join-Path $CoduetHome "claude-return-$name.token") -Value $token
$safe = $name -replace '[^A-Za-z0-9_-]', '_'
$tn = "Coduet-ClaudeReturn-$safe"
$arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $PSScriptRoot 'claude-return.ps1')`" -Project `"$Project`" -Token $token -TaskName $tn"
$when = [datetime]::ParseExact($At, 'yyyy-MM-dd HH:mm', $null)
$trigger = New-ScheduledTaskTrigger -Once -At $when
$trigger.EndBoundary = $when.AddDays(2).ToString('s')
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DeleteExpiredTaskAfter (New-TimeSpan -Hours 1)
try {
  Register-ScheduledTask -TaskName $tn -Action (New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg) -Trigger $trigger -Settings $settings -Force -ErrorAction Stop | Out-Null
  "scheduled=claude-return via=taskscheduler when=$At"
} catch { "scheduled=claude-return error=$($_.Exception.Message)" }
