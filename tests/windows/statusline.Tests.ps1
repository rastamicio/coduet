. (Join-Path $PSScriptRoot 'lib.ps1')
$sl = Join-Path $Scripts 'claude-statusline.ps1'
function Run-SL([string]$in) { (($in | & powershell -NoProfile -ExecutionPolicy Bypass -File $sl) -join "`n") }
$j = '{"model":{"display_name":"Opus"},"rate_limits":{"five_hour":{"used_percentage":44,"resets_at":1793160600},"seven_day":{"used_percentage":12,"resets_at":1793649600}},"cwd":"/x"}'
$q = Join-Path $env:CODUET_HOME 'claude-quota.json'

$out = Run-SL $j
$saved = Get-Content $q -Raw
Assert-Contains $saved '"five_hour":{"used_percentage":44,"resets_at":1793160600}' 'save: rate_limits kept'
Assert-Contains $saved '"read":"' 'save: read time'
Assert-Eq 'Claude 5h 44% · week 12%' $out 'no prev: short line'

Set-Content $q '{"stale":1}'
$null = Run-SL '{"model":{"display_name":"Opus"}}'
Assert-Eq '{"stale":1}' (Get-Content $q -Raw).Trim() 'no rate_limits: file untouched'

$p = Join-Path $env:CODUET_HOME 'statusline-prev.txt'
Set-Content $p 'echo prev "ok"' -NoNewline
Assert-Eq 'prev "ok"' (Run-SL $j) 'prev: output identical'
Set-Content $p 'findstr /c:"cwd"' -NoNewline
Assert-Contains (Run-SL $j) '"cwd":"/x"' 'prev: gets the same stdin'
Remove-Item $p

# install / uninstall on a test profile
$env:USERPROFILE = Join-Path $env:TEMP ('coduet-home-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force (Join-Path $env:USERPROFILE '.claude') | Out-Null
$st = Join-Path $env:USERPROFILE '.claude\settings.json'
$orig = '{"model":"opus","statusLine":{"type":"command","command":"node \"C:/x y/limits.mjs\""},"hooks":{}}'
Set-Content $st $orig
$out = Run-Script 'statusline-install.ps1' @('install')
Assert-Contains $out 'statusline=coduet' 'install: status'
Assert-Contains $out "backup=$env:CODUET_HOME\settings.backup-" 'install: backup'
Assert-Contains $out 'undo=' 'install: undo'
Assert-Eq 'node "C:/x y/limits.mjs"' (Get-Content $p -Raw) 'install: previous command saved'
$d = Get-Content $st -Raw | ConvertFrom-Json
Assert-Eq 'opus' $d.model 'install: other keys intact'
Assert-Contains $d.statusLine.command 'claude-statusline' 'install: command set'
Assert-Eq $true (Test-Path (Join-Path $env:CODUET_HOME 'claude-statusline.ps1')) 'install: script copied to a stable path'
$null = Run-Script 'statusline-install.ps1' @('install')
Assert-Eq 'node "C:/x y/limits.mjs"' (Get-Content $p -Raw) 'install twice: previous command kept'
Assert-Eq 'statusline=coduet' (Run-Script 'statusline-install.ps1' @('status')) 'status: coduet'
$null = Run-Script 'statusline-install.ps1' @('uninstall')
Assert-Eq ($orig | ConvertFrom-Json | ConvertTo-Json -Compress) (Get-Content $st -Raw | ConvertFrom-Json | ConvertTo-Json -Compress) 'uninstall: back to the original'
Assert-Eq 'statusline=other' (Run-Script 'statusline-install.ps1' @('status')) 'status: other'

Set-Content $st '{"model":"opus"}'
$null = Run-Script 'statusline-install.ps1' @('install')
$null = Run-Script 'statusline-install.ps1' @('uninstall')
Assert-Eq '{"model":"opus"}' (Get-Content $st -Raw | ConvertFrom-Json | ConvertTo-Json -Compress) 'no previous: key removed'

Finish 'statusline.Tests.ps1'
