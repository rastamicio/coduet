. (Join-Path $PSScriptRoot 'lib.ps1')
. (Join-Path $Scripts 'common.ps1')
$env:PATH = "$Fixtures;$env:PATH"
function Leftover { @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*fake-codex*' }).Count }

$env:FAKE_CODEX_MODE = 'ok'; $out = Run-Script 'codex-limits.ps1'
Assert-Contains $out 'ok=1' 'ok: ok=1'
Assert-Contains $out 'primary_used=30' 'ok: primary_used'
Assert-Contains $out 'secondary_used=10' 'ok: secondary_used'
Assert-Contains $out 'primary_window_mins=300' 'ok: window'
Assert-Contains $out 'plan=plus' 'ok: plan'
Assert-Eq 'yes' (Codex-Available ($out -split "`n")) 'ok: Codex-Available'

$env:FAKE_CODEX_MODE = 'reached'; $out = Run-Script 'codex-limits.ps1'
Assert-Contains $out 'reached=primary' 'reached: reached'
Assert-Eq 'no' (Codex-Available ($out -split "`n")) 'reached: Codex-Available'
Assert-Eq '1793210994' (Codex-ResetAt ($out -split "`n")) 'reached: Codex-ResetAt'

$env:FAKE_CODEX_MODE = 'silent'; $t = Get-Date; $out = Run-Script 'codex-limits.ps1' @('-TimeoutSec', '2')
$el = ((Get-Date) - $t).TotalSeconds
Assert-Contains $out 'ok=0' 'silent: ok=0'
Assert-Contains $out 'error=timeout' 'silent: error'
Assert-Eq $true ($el -lt 8) "silent: ends quickly (took $el s)"
Start-Sleep -Milliseconds 500
Assert-Eq 0 (Leftover) 'silent: no process left'

$env:FAKE_CODEX_MODE = 'noserver'; $t = Get-Date; $out = Run-Script 'codex-limits.ps1' @('-TimeoutSec', '15')
$el = ((Get-Date) - $t).TotalSeconds
Assert-Contains $out 'ok=0' 'noserver: ok=0'
Assert-Contains $out 'error=app-server-exited' 'noserver: error'
Assert-Eq $true ($el -lt 10) "noserver: doesn't wait for the timeout (took $el s)"
Assert-Eq 'unknown' (Codex-Available ($out -split "`n")) 'noserver: Codex-Available'

Finish 'codex-limits.Tests.ps1'
