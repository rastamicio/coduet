# Adds or removes Coduet's status line in ~/.claude/settings.json, keeping the user's previous one (chained).
#   statusline-install.ps1 install|uninstall|status
# Prints statusline=coduet|other|none, and backup=/undo= on install.
param([string]$Action)
. (Join-Path $PSScriptRoot 'common.ps1')
$s = Join-Path $env:USERPROFILE '.claude\settings.json'
$prev = Join-Path $CoduetHome 'statusline-prev.txt'
$dest = Join-Path $CoduetHome 'claude-statusline.ps1'
$cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File `"$dest`""
$utf8 = New-Object Text.UTF8Encoding $false

$d = if (Test-Path $s) { Get-Content $s -Raw -Encoding UTF8 | ConvertFrom-Json } else { New-Object PSObject }
$cur = if ($d.PSObject.Properties['statusLine'] -and $d.statusLine.command) { [string]$d.statusLine.command } else { '' }
function Save { [IO.File]::WriteAllText($s, ($d | ConvertTo-Json -Depth 20), $utf8) }
function Kind { if ($cur -like '*claude-statusline*') { 'coduet' } elseif ($cur) { 'other' } else { 'none' } }

switch ($Action) {
  'status' { "statusline=$(Kind)" }
  'install' {
    New-Item -ItemType Directory -Force -Path (Split-Path $s -Parent) | Out-Null
    Copy-Item (Join-Path $PSScriptRoot 'claude-statusline.ps1') $dest -Force
    if ((Kind) -eq 'coduet') { 'statusline=coduet'; break }
    $b = Join-Path $CoduetHome ('settings.backup-' + (Get-Date).ToString('yyyyMMdd-HHmmss') + '.json')
    if (Test-Path $s) { Copy-Item $s $b }
    if ($cur) { [IO.File]::WriteAllText($prev, $cur, $utf8) } elseif (Test-Path $prev) { Remove-Item $prev }
    if ($d.PSObject.Properties['statusLine']) { $d.statusLine | Add-Member -Force NoteProperty type 'command'; $d.statusLine | Add-Member -Force NoteProperty command $cmd }
    else { $d | Add-Member -Force NoteProperty statusLine ([pscustomobject]@{ type = 'command'; command = $cmd }) }
    Save
    'statusline=coduet'; if (Test-Path $b) { "backup=$b" }
    "undo=powershell -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" uninstall"
  }
  'uninstall' {
    if ((Kind) -ne 'coduet') { "statusline=$(Kind)"; break }
    if ((Test-Path $prev) -and (Get-Item $prev).Length -gt 0) { $d.statusLine.command = [IO.File]::ReadAllText($prev); 'statusline=other' }
    else { $d.PSObject.Properties.Remove('statusLine'); 'statusline=none' }
    Save
    if (Test-Path $prev) { Remove-Item $prev }
  }
  default { 'error=usage'; exit 1 }
}
