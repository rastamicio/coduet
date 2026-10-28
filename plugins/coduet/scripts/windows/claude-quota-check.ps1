# UserPromptSubmit hook: one line of context for Claude when its quota passes the handoff threshold, once per window.
# Silent (and free) otherwise, and outside Coduet projects.
. (Join-Path $PSScriptRoot 'common.ps1')
# Raw bytes decoded as UTF-8 (Claude Code sends UTF-8): with [Console]::InputEncoding set, the tests got an empty stdin on PowerShell 5.1.
$ms = New-Object IO.MemoryStream; [Console]::OpenStandardInput().CopyTo($ms); $in = (New-Object Text.UTF8Encoding $false).GetString($ms.ToArray()).TrimStart([char]0xFEFF)
$cwd = ''; try { $cwd = ($in | ConvertFrom-Json).cwd } catch { }
if (-not $cwd) { $cwd = (Get-Location).Path }
if (-not (Find-CoduetPlan $cwd)) { exit 0 }
$q = Join-Path $CoduetHome 'claude-quota.json'
if (-not (Test-Path $q) -or (Get-Item $q).LastWriteTime -lt (Get-Date).AddMinutes(-10)) { exit 0 }
$rl = $null; try { $rl = (Get-Content $q -Raw | ConvertFrom-Json).rate_limits } catch { exit 0 }
if (-not $rl) { exit 0 }
$thr = [int](Coduet-Param (Repo-Root $cwd) 'Claude quota threshold|soglia.*quota.*Claude' '80')
$w = Join-Path $CoduetHome 'claude-quota-warned.txt'
$warned = if (Test-Path $w) { @(Get-Content $w) } else { @() }
$best = $null; $bp = -1; $br = 0
foreach ($win in 'five_hour', 'seven_day') {
  $o = $rl.$win
  if (-not $o -or $null -eq $o.used_percentage -or -not $o.resets_at) { continue }
  $p = [int]$o.used_percentage
  if ($p -lt $thr -or $warned -contains "${win}:$($o.resets_at)") { continue }
  if ($p -gt $bp) { $best = $win; $bp = $p; $br = [long]$o.resets_at }
}
if (-not $best) { exit 0 }
Add-Content -Path $w -Value "${best}:$br"
"Coduet: Claude quota at $bp% (resets $(HHmm $br)). Apply coduet:start Step 7 (handoff)."
