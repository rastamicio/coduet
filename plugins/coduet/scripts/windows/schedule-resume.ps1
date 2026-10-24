# Schedules the automatic resume and the backup warning with Windows Task Scheduler.
#   schedule-resume.ps1 -Worktree <folder> -Task <name> -Session <id> -ResumeAt "yyyy-MM-dd HH:mm" -WarnAt "yyyy-MM-dd HH:mm" [-Effort medium]
# Tasks run when the user is logged on, start late if the PC was asleep, and are removed after they run.
param([string]$Worktree, [string]$Task, [string]$Session, [string]$ResumeAt, [string]$WarnAt, [string]$Effort = 'medium')
$safe = $Task -replace '[^A-Za-z0-9_-]', '_'
function Sched([string]$name, [string]$script, [string]$when) {
  $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $PSScriptRoot $script)`" -Worktree `"$Worktree`" -Task `"$Task`" -Session `"$Session`" -Effort `"$Effort`""
  $at = [datetime]::ParseExact($when, 'yyyy-MM-dd HH:mm', $null)
  $action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
  $trigger = New-ScheduledTaskTrigger -Once -At $at
  $trigger.EndBoundary = $at.AddDays(2).ToString('s')
  $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DeleteExpiredTaskAfter (New-TimeSpan -Hours 1)
  try {
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings -Force -ErrorAction Stop | Out-Null
    "scheduled=$name when=$when"
  } catch { "scheduled=$name error=$($_.Exception.Message)" }
}
Sched "Coduet-resume-$safe" 'codex-resume.ps1' $ResumeAt
Sched "Coduet-warning-$safe" 'codex-warning.ps1' $WarnAt
