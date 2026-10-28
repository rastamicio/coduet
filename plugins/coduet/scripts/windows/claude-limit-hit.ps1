# StopFailure hook (rate_limit): Claude hit its usage limit. Without spending Claude tokens, lends the plan's ready
# Claude tasks to Codex (if Codex has quota), schedules Claude's return and tells the user. Silent outside Coduet projects.
. (Join-Path $PSScriptRoot 'common.ps1')
[Console]::InputEncoding = New-Object Text.UTF8Encoding $false
$in = [Console]::In.ReadToEnd()
$j = $null; try { $j = $in | ConvertFrom-Json } catch { exit 0 }
# Claude Code puts the error type in "error" ("error_type" in some versions).
$et = if ($j.error_type) { $j.error_type } else { $j.error }
if ($et -ne 'rate_limit') { exit 0 }
$cwd = if ($j.cwd) { $j.cwd } else { (Get-Location).Path }
$plan = Find-CoduetPlan $cwd; if (-not $plan) { exit 0 }
if (-not (Get-Command codex -ErrorAction SilentlyContinue)) { exit 0 }
$root = Repo-Root $cwd; $name = Split-Path $root -Leaf
$log = Join-Path $CoduetHome "claude-limit-$name.log"
function Log([string]$t) { Add-Content -Path $log -Value "$(Now-Iso) $t" }

# Once per quota window.
$q = Join-Path $CoduetHome 'claude-quota.json'; $reset = $null
if ((Test-Path $q) -and (Get-Item $q).LastWriteTime -gt (Get-Date).AddHours(-5)) {
  try { $reset = [long](Get-Content $q -Raw | ConvertFrom-Json).rate_limits.five_hour.resets_at } catch { }
}
$win = if ($reset) { "$reset" } else { (Get-Date).ToString('yyyyMMddHH') }
$reg = Join-Path $CoduetHome "claude-limit-$name.txt"
if ((Test-Path $reg) -and (Get-Content $reg) -contains "window=$win") { exit 0 }
Set-Content -Path $reg -Value "window=$win"
Log "Claude hit its limit (window $win), plan $plan"

$lim = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'codex-limits.ps1'))
$av = Codex-Available $lim
$lent = @()
if ($av -ne 'no') {
  $effort = Coduet-ParamWord $root 'Codex reasoning|ragionamento' 'low|medium|high' 'medium'
  $max = Coduet-Param $root 'Concurrent Codex|task.*contemporanei' '2'
  $wtd = Coduet-ParamWord $root 'Worktree folder|Cartella dei worktree' 'inside|dentro|beside|accanto' 'beside'
  $pd = Join-Path $CoduetHome 'prompts'; New-Item -ItemType Directory -Force -Path $pd | Out-Null
  foreach ($row in @(Plan-Lendable $plan)) {
    $n, $title, $base = $row -split '\|', 3
    $p = Join-Path $pd "$name-task$n.md"; $out = Join-Path $pd "$name-task$n.out"
    $null = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'handoff-prompt.ps1') -Plan $plan -Task $n -Out $p
    if (Test-Path $out) { Remove-Item $out }
    # Recorded before the launch: a task must never look open while Codex may be running it.
    Plan-SetStatus $plan $n 'lent to Codex'
    $a = "-NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $PSScriptRoot 'codex-run.ps1')`" -Project `"$root`" -Task task$n -PromptFile `"$p`" -Base `"$base`" -Effort $effort -Max $max -WorktreeDir $wtd -SkipQuotaCheck"
    Start-Process powershell.exe -ArgumentList $a -WindowStyle Hidden -RedirectStandardOutput $out | Out-Null
    for ($i = 0; $i -lt 150 -and -not ((Test-Path $out) -and (Get-Item $out).Length -gt 0); $i++) { Start-Sleep -Milliseconds 200 }
    $first = if (Test-Path $out) { [string](Get-Content $out -TotalCount 1) } else { '' }
    Log "Task ${n}: $(if ($first) { $first } else { 'no answer yet, kept as lent' })"
    if ($first -match '^CODEX (QUEUED|WAITING|ERROR)') { Plan-SetStatus $plan $n 'open' } else { $lent += "Task $n" }
  }
}

if ($lent.Count) {
  $line = "- Lent to Codex at $((Get-Date).ToString('yyyy-MM-dd HH:mm')): $($lent -join ', ')"
  $lines = foreach ($l in Get-Content -LiteralPath $plan -Encoding UTF8) { $l; if ($l -match '^## Status and handoff') { $line } }
  [IO.File]::WriteAllLines($plan, [string[]]$lines, (New-Object Text.UTF8Encoding $false))
}

$ret = ''
if (Coduet-ParamOn $root 'automatic return|ritorno automatico') {
  $ret = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'schedule-claude-return.ps1') -Project $root) -join "`n"
  Log "return: $ret"
}
if ($ret -match 'scheduled=claude-return via=') {
  $back = "Claude restarts by itself at $(($ret -split "`n" | Where-Object { $_ -like 'when=*' }) -replace '^when=', '')."
} else {
  # Return off or not possible: a notice when the quota should be back.
  $t = if ($reset) { [DateTimeOffset]::FromUnixTimeSeconds($reset).LocalDateTime } else { (Get-Date).AddHours([int](Coduet-Param $root 'Quota reset estimate|stima.*reset' '5')) }
  $back = "Around $($t.ToString('yyyy-MM-dd HH:mm')) Claude's quota is back: write 'riprendi Coduet' to continue."
  if (-not $env:CODUET_NOTIFY) {
    $tn = 'Coduet-ClaudeNotice-' + ($name -replace '[^A-Za-z0-9_-]', '_')
    $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $PSScriptRoot 'notify.ps1')`" -Message `"Coduet - Claude is available again in ${name}: write 'riprendi Coduet'.`" -TaskName $tn"
    $tr = New-ScheduledTaskTrigger -Once -At $t; $tr.EndBoundary = $t.AddDays(2).ToString('s')
    $st = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -DeleteExpiredTaskAfter (New-TimeSpan -Hours 1)
    try { Register-ScheduledTask -TaskName $tn -Action (New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg) -Trigger $tr -Settings $st -Force -ErrorAction Stop | Out-Null }
    catch { Log "notice error: $($_.Exception.Message)" }
  }
}
$msg = if ($av -eq 'no') { "Claude hit its usage limit and Codex has no quota left either: each resumes its own tasks after the reset. $back" }
  elseif ($lent.Count) { "Claude hit its usage limit: lent to Codex $($lent -join ', '). $back" }
  else { "Claude hit its usage limit: no task ready for Codex. $back" }
Log $msg
Notify "Coduet - $msg"
exit 0
