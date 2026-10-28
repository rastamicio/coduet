# Reads Codex's usage limits through `codex app-server` (JSON-RPC over stdio, one message per line).
#   codex-limits.ps1 [-TimeoutSec <seconds>]
# Prints ok, primary_*/secondary_* (used, resets_at, window_mins), plan, reached; error when ok=0. Uses no quota.
# Why cmd and files: with PowerShell 5.1 .NET pipes app-server never answers, and with stdin from a file it exits at EOF
# before answering. A cmd pipe that keeps stdin open, with output to a file, works.
param([int]$TimeoutSec = 20)
. (Join-Path $PSScriptRoot 'common.ps1')

$ver = ''
try { $ver = (Get-Content (Join-Path $PluginRoot '.claude-plugin\plugin.json') -Raw | ConvertFrom-Json).version } catch { }
$codex = (Get-Command codex -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1).Source
if (-not $codex) { 'ok=0'; 'error=codex-not-found'; exit 0 }

$dir = Join-Path $env:TEMP ('coduet-limits-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
$inFile = Join-Path $dir 'in.jsonl'; $outFile = Join-Path $dir 'out.jsonl'
# ASCII: no BOM before the first message.
Set-Content -Path $inFile -Encoding Ascii -Value @(
  "{`"id`":1,`"method`":`"initialize`",`"params`":{`"clientInfo`":{`"name`":`"coduet`",`"version`":`"$ver`"}}}",
  '{"method":"initialized"}',
  '{"id":2,"method":"account/rateLimits/read","params":{"excludeResetCreditDetails":true}}'
)
# ping keeps stdin open past the timeout, so app-server doesn't exit before answering.
$hold = $TimeoutSec + 2
$cmdLine = "/d /c (type `"$inFile`" & ping -n $hold 127.0.0.1 >nul) | `"$codex`" app-server --listen stdio:// > `"$outFile`" 2>nul"

function Out-Window($name, $w) {
  if ($w) { "${name}_used=$($w.usedPercent)"; "${name}_resets_at=$($w.resetsAt)"; "${name}_window_mins=$($w.windowDurationMins)" }
  else { "${name}_used="; "${name}_resets_at="; "${name}_window_mins=" }
}

# ping keeps the cmd alive, so the cmd can't tell us app-server ended: look for any live descendant besides cmd, ping, conhost.
function Server-Alive($rootId) {
  $all = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, Name -ErrorAction SilentlyContinue)
  $ids = @($rootId); $i = 0
  while ($i -lt $ids.Count) {
    foreach ($c in $all) {
      if ($c.ParentProcessId -ne $ids[$i] -or $ids -contains $c.ProcessId) { continue }
      if ($c.Name -notin @('cmd.exe', 'PING.EXE', 'ping.exe', 'conhost.exe')) { return $true }
      $ids += $c.ProcessId
    }
    $i++
  }
  return $false
}

$proc = $null
try {
  $proc = Start-Process -FilePath $env:ComSpec -ArgumentList $cmdLine -WindowStyle Hidden -PassThru
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  $r = $null; $gone = $false; $nextCheck = (Get-Date).AddSeconds(1.5)
  while ((Get-Date) -lt $deadline -and -not $r) {
    Start-Sleep -Milliseconds 200
    if (-not (Test-Path $outFile)) { continue }
    $lines = @()
    try { $lines = Get-Content -Path $outFile -Encoding UTF8 -ErrorAction Stop } catch { continue }
    foreach ($line in $lines) {
      if ($line -notmatch '"id":2') { continue }
      try { $msg = $line | ConvertFrom-Json } catch { continue }  # line still being written
      if ($msg.PSObject.Properties['error'] -and $msg.error) { throw "$($msg.error.message)" }
      $r = $msg.result
    }
    # One more read after the server is gone: its last line may have landed after this pass read the file.
    if (-not $r -and $gone) { throw 'app-server-exited' }
    if (-not $r) { $gone = $proc.HasExited -or ((Get-Date) -gt $nextCheck -and -not (Server-Alive $proc.Id)) }
    if ((Get-Date) -gt $nextCheck) { $nextCheck = (Get-Date).AddSeconds(1) }
  }
  if (-not $r) { throw 'timeout' }
  $rl = $r.rateLimits
  Out-Window 'primary' $rl.primary
  Out-Window 'secondary' $rl.secondary
  "plan=$($rl.planType)"
  "reached=$($rl.rateLimitReachedType)"
  'ok=1'
} catch {
  'ok=0'
  "error=$($_.Exception.Message)"
} finally {
  # taskkill /T closes the cmd, ping and app-server started here, nothing else.
  if ($proc -and -not $proc.HasExited) { & taskkill.exe /PID $proc.Id /T /F 2>$null | Out-Null }
  Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
}
