. (Join-Path $PSScriptRoot 'lib.ps1')
$env:PATH = "$Fixtures;$env:PATH"
$env:USERPROFILE = Join-Path $env:TEMP ('coduet-home-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $env:USERPROFILE | Out-Null
$r = Join-Path $env:TEMP ('coduet-cr-' + [guid]::NewGuid().ToString('N') + '\proj'); New-Item -ItemType Directory -Force (Join-Path $r 'docs') | Out-Null; git -C $r init -q -b main
Copy-Item (Join-Path $Fixtures 'plan-new.md') (Join-Path $r 'docs\plan.md')
function When-Of([string]$o) { ($o -split "`n" | Where-Object { $_ -like 'when=*' }) -replace '^when=', '' }
$q = Join-Path $env:CODUET_HOME 'claude-quota.json'

$reset = [DateTimeOffset]::Now.ToUnixTimeSeconds() + 3600
Set-Content $q ('{"read":"x","rate_limits":{"five_hour":{"used_percentage":99,"resets_at":' + $reset + '}}}')
$out = Run-Script 'schedule-claude-return.ps1' @('-Project', $r, '-DryRun')
Assert-Eq ([DateTimeOffset]::FromUnixTimeSeconds($reset + 300).LocalDateTime.ToString('yyyy-MM-dd HH:mm')) (When-Of $out) 'time from quota file + margin'
Assert-Contains $out '--permission-mode acceptEdits' 'command: permission mode'
Assert-Contains $out 'coduet:start' 'command: resume prompt'
Assert-NotContains $out '--force' 'command: no force'
Assert-NotContains $out '--dangerously' 'command: no dangerous mode'
$ps = 'powershell -NoProfile -ExecutionPolicy Bypass -File'
Assert-Contains $out "Bash($ps \`"$Scripts\:*)" 'command: quoted script path allowed'
Assert-Contains $out "Bash($ps $Scripts\:*)" 'command: unquoted script path allowed'
Assert-Contains $out "Bash($ps $($Scripts -replace '\\', '/')/:*)" 'command: script path with / allowed'
Assert-Contains $out 'Bash(npm test)' 'command: plan verification commands allowed'
Assert-NotContains $out 'Bash(git worktree:*)' 'command: git worktree narrowed'

(Get-Item $q).LastWriteTime = (Get-Date).AddHours(-6)
$out = Run-Script 'schedule-claude-return.ps1' @('-Project', $r, '-DryRun')
Assert-Eq ((Get-Date).AddHours(5).AddMinutes(5).ToString('yyyy-MM-dd HH:mm')) (When-Of $out) 'old file: estimate'
Assert-Eq '2030-01-02 03:04' (When-Of (Run-Script 'schedule-claude-return.ps1' @('-Project', $r, '-At', '2030-01-02 03:04', '-DryRun'))) '-At'

$env:FAKE_CLAUDE_LOGGED = '0'
Assert-Contains (Run-Script 'schedule-claude-return.ps1' @('-Project', $r, '-DryRun')) 'error=not-logged-in' 'not logged in'
$env:FAKE_CLAUDE_LOGGED = '1'

$m = Join-Path $env:TEMP ('coduet-marker-' + [guid]::NewGuid().ToString('N') + '.txt'); $env:FAKE_CLAUDE_MARKER = $m
Set-Content (Join-Path $env:CODUET_HOME 'claude-return-proj.token') 'tok1'
$null = Run-Script 'claude-return.ps1' @('-Project', $r, '-Token', 'old-token')
Assert-Eq $false (Test-Path $m) 'runner: stale token does nothing'
$null = Run-Script 'claude-return.ps1' @('-Project', $r, '-Token', 'tok1')
Assert-Contains (Get-Content $m -Raw) 'claude -p' 'runner: starts claude'
Assert-Contains (Get-Content (Join-Path $env:CODUET_HOME 'claude-return-proj.log') -Raw) 'START' 'runner: log'

Finish 'claude-return.Tests.ps1'
