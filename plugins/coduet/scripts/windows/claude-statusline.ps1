# Claude Code status line: saves Claude's quota (rate_limits) for Coduet, then shows the user's previous status line.
# Standalone: statusline-install copies it to ~/.coduet so plugin updates don't break the status line.
$h = if ($env:CODUET_HOME) { $env:CODUET_HOME } else { Join-Path $env:USERPROFILE '.coduet' }
$utf8 = New-Object Text.UTF8Encoding $false
[Console]::InputEncoding = $utf8; [Console]::OutputEncoding = $utf8; $OutputEncoding = $utf8
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
  # Claude Code runs status line commands with Git Bash: run the previous one the same way (cmd if Git Bash is missing).
  $cmdText = [IO.File]::ReadAllText($prev)
  $gitBash = @((Join-Path $env:ProgramFiles 'Git\bin\bash.exe'), (Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe')) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
  if ($gitBash) { $in | & $gitBash -c $cmdText } else { $in | & $env:ComSpec /d /s /c $cmdText }
} elseif ($rl) {
  "Claude 5h $($rl.five_hour.used_percentage)% $([char]0x00B7) week $($rl.seven_day.used_percentage)%"
}
