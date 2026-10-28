. (Join-Path $PSScriptRoot 'lib.ps1')
$env:PATH = "$Fixtures;$env:PATH"
$env:USERPROFILE = Join-Path $env:TEMP ('coduet-home-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $env:USERPROFILE | Out-Null
$lh = Join-Path $Scripts 'claude-limit-hit.ps1'
$n = Join-Path $env:TEMP ('coduet-n-' + [guid]::NewGuid().ToString('N') + '.txt'); Set-Content $n ''; $env:NOTIFY_FILE = $n
$env:CODUET_NOTIFY = Join-Path $Fixtures 'notify-to-file.cmd'
Remove-Item Env:FAKE_CODEX_MARKER -ErrorAction SilentlyContinue
function New-Repo([string]$fixture) {
  $r = Join-Path $env:TEMP ('coduet-lh-' + [guid]::NewGuid().ToString('N') + '\proj'); New-Item -ItemType Directory -Force (Join-Path $r 'docs') | Out-Null
  git -C $r init -q -b main; git -C $r -c user.email=t@t -c user.name=t commit -q --allow-empty -m init; git -C $r branch feature/config
  Copy-Item (Join-Path $Fixtures $fixture) (Join-Path $r 'docs\plan.md'); return $r
}
function Hit([string]$dir, [string]$type) {
  $j = '{"session_id":"s","hook_event_name":"StopFailure","cwd":' + ($dir | ConvertTo-Json) + ',"error":"' + $type + '","last_assistant_message":"x"}'
  $null = $j | & powershell -NoProfile -ExecutionPolicy Bypass -File $lh
}
function Same([string]$a, [string]$b) { (Get-FileHash $a).Hash -eq (Get-FileHash $b).Hash }
# The Codex worker doesn't inherit the test's environment: the fake Codex leaves .fake-codex-exec in the worktree.
function Execs { @(Get-ChildItem (Split-Path $r -Parent) -Recurse -Force -Filter '.fake-codex-exec' -ErrorAction SilentlyContinue).Count }

$r = New-Repo 'plan-new.md'; $env:FAKE_CODEX_MODE = 'ok'
Hit $r 'overloaded'
Assert-Eq 0 (Execs) 'overloaded: nothing launched'
Assert-Eq $true (Same (Join-Path $Fixtures 'plan-new.md') (Join-Path $r 'docs\plan.md')) 'overloaded: plan untouched'

Hit $r 'rate_limit'; Start-Sleep -Seconds 3
$plan = Get-Content (Join-Path $r 'docs\plan.md') -Raw
Assert-Eq 1 (Execs) 'ok: codex launched once'
Assert-Contains $plan '**Status:** lent to Codex' 'ok: task 1 lent'
Assert-Contains $plan 'Lent to Codex at ' 'ok: status section line'
Assert-Contains $plan ': Task 1' 'ok: status line names task 1'
Assert-Contains (Get-Content $n -Raw) 'Task 1' 'ok: notification names the task'

$before = Execs
Hit $r 'rate_limit'; Start-Sleep -Seconds 2
Assert-Eq $before (Execs) 'second hit: nothing new'

$r = New-Repo 'plan-new.md'; Set-Content $n ''; Remove-Item (Join-Path $env:CODUET_HOME 'claude-limit-*.txt')
$env:FAKE_CODEX_MODE = 'reached'; Hit $r 'rate_limit'; Start-Sleep -Seconds 2
Assert-Eq 0 (Execs) 'codex used up: nothing launched'
Assert-Eq $true (Same (Join-Path $Fixtures 'plan-new.md') (Join-Path $r 'docs\plan.md')) 'codex used up: plan untouched'
Assert-Contains (Get-Content $n -Raw) 'Codex' 'codex used up: notification'

$r = New-Repo 'plan-old.md'; Remove-Item (Join-Path $env:CODUET_HOME 'claude-limit-*.txt')
$env:FAKE_CODEX_MODE = 'ok'; Hit $r 'rate_limit'; Start-Sleep -Seconds 2
Assert-Eq $true (Same (Join-Path $Fixtures 'plan-old.md') (Join-Path $r 'docs\plan.md')) 'old plan: file unchanged'
Assert-Eq 0 (Execs) 'old plan: nothing launched'

Finish 'limit-hit.Tests.ps1'
