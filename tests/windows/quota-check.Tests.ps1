. (Join-Path $PSScriptRoot 'lib.ps1')
$qc = Join-Path $Scripts 'claude-quota-check.ps1'
$r = Join-Path $env:TEMP ('coduet-qc-' + [guid]::NewGuid().ToString('N') + '\proj'); New-Item -ItemType Directory -Force (Join-Path $r 'docs') | Out-Null; git -C $r init -q -b main
$e = Join-Path $env:TEMP ('coduet-qe-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $e | Out-Null; git -C $e init -q -b main
$env:USERPROFILE = Join-Path $env:TEMP ('coduet-home-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $env:USERPROFILE | Out-Null
$q = Join-Path $env:CODUET_HOME 'claude-quota.json'
function Quota($five, $seven, $resets = 1793160600) {
  Set-Content $q ('{"read":"x","rate_limits":{"five_hour":{"used_percentage":' + $five + ',"resets_at":' + $resets + '},"seven_day":{"used_percentage":' + $seven + ',"resets_at":1793649600}}}')
}
function Run($dir) {
  $j = '{"session_id":"s","hook_event_name":"UserPromptSubmit","cwd":' + ($dir | ConvertTo-Json) + ',"prompt":"hi"}'
  $o = ($j | & powershell -NoProfile -ExecutionPolicy Bypass -File $qc) -join "`n"
  return "$o|code=$LASTEXITCODE"
}

Quota 85 10
Assert-Eq '|code=0' (Run $e) 'no plan: silent'
Copy-Item (Join-Path $Fixtures 'plan-new.md') (Join-Path $r 'docs\plan.md')
Remove-Item $q
Assert-Eq '|code=0' (Run $r) 'no quota file: silent'
Quota 85 10; (Get-Item $q).LastWriteTime = (Get-Date).AddMinutes(-11)
Assert-Eq '|code=0' (Run $r) 'stale file: silent'
Set-Content $q '{"read":"x","rate_limits":{"five_hour":{"used_perc'
Assert-Eq '|code=0' (Run $r) 'truncated file: silent'
Quota 79 10
Assert-Eq '|code=0' (Run $r) '79%: silent'
Quota 80 10
$out = Run $r
Assert-Contains $out 'Coduet: Claude quota at 80% (resets ' '80%: warning'
Assert-Contains $out 'Apply coduet:start Step 7 (handoff).' '80%: instruction'
Assert-Eq '|code=0' (Run $r) 'same window: warned once'
Quota 20 85 1793170000
Assert-Contains (Run $r) 'Claude quota at 85%' 'seven_day counts'
Remove-Item (Join-Path $env:CODUET_HOME 'claude-quota-warned.txt')
Set-Content (Join-Path $r '.coduet.md') "| Parameter | Value |`n|---|---|`n| Claude quota threshold for handoff (%) | 90 |"
Quota 85 10 1793180000
Assert-Eq '|code=0' (Run $r) '.coduet.md threshold 90: silent at 85%'

# Claude Code sends UTF-8: a folder name outside ASCII must still be found.
$OutputEncoding = New-Object Text.UTF8Encoding $false
$u = Join-Path $env:TEMP ('coduet-qu-' + [guid]::NewGuid().ToString('N') + "\citt$([char]0x00E0)"); New-Item -ItemType Directory -Force (Join-Path $u 'docs') | Out-Null; git -C $u init -q -b main
Copy-Item (Join-Path $Fixtures 'plan-new.md') (Join-Path $u 'docs\plan.md')
Remove-Item (Join-Path $env:CODUET_HOME 'claude-quota-warned.txt') -ErrorAction SilentlyContinue
Quota 85 10 1793190000
Assert-Contains (Run $u) 'Claude quota at 85%' 'non-ASCII folder: warning'

Finish 'quota-check.Tests.ps1'
