# Claude Code status line: saves Claude's quota (rate_limits) for Coduet, then shows the user's previous status line.
# Standalone: statusline-install copies it to ~/.coduet so plugin updates don't break the status line.
$h = if ($env:CODUET_HOME) { $env:CODUET_HOME } else { Join-Path $env:USERPROFILE '.coduet' }
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
$in = [Console]::In.ReadToEnd()
$rl = $null
try { $rl = ($in | ConvertFrom-Json).rate_limits } catch { }
if ($rl) {
  New-Item -ItemType Directory -Force -Path $h | Out-Null
  $f = Join-Path $h 'claude-quota.json'
  $json = '{"read":"' + (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') + '","rate_limits":' + ($rl | ConvertTo-Json -Compress -Depth 5) + '}'
  [IO.File]::WriteAllText("$f.tmp", $json, (New-Object Text.UTF8Encoding $false))
  Move-Item -LiteralPath "$f.tmp" -Destination $f -Force
}
$prev = Join-Path $h 'statusline-prev.txt'
if ((Test-Path $prev) -and (Get-Item $prev).Length -gt 0) {
  $in | & $env:ComSpec /d /s /c (Get-Content $prev -Raw)
} elseif ($rl) {
  "Claude 5h $($rl.five_hour.used_percentage)% $([char]0x00B7) week $($rl.seven_day.used_percentage)%"
}
