# Coduet update helper.
#   coduet-update.ps1 check   -> installed/latest versions and whether an update exists
#   coduet-update.ps1 apply   -> updates the marketplace and the plugin with the claude CLI
# Output: key=value lines. Errors are appended to ~/.coduet/aggiornamento.log.
param([string]$Mode = 'check')
. (Join-Path $PSScriptRoot 'common.ps1')
$Log = Join-Path $CoduetHome 'aggiornamento.log'
$Manifest = Join-Path $PluginRoot '.claude-plugin\plugin.json'
$Claude = Find-Claude
"cli=$(if ($Claude) { $Claude } else { 'missing' })"

function Installed-Version {
  if (-not $Claude) { return '' }
  $list = & $Claude plugin list 2>$null
  $hit = $false
  foreach ($l in $list) {
    if ($l -match 'coduet@') { $hit = $true; continue }
    if ($hit -and $l -match 'Version:\s*(\S+)') { return $Matches[1] }
  }
  return ''
}
$Market = 'coduet'
if ($Claude) {
  $m = (& $Claude plugin list 2>$null) | Select-String -Pattern 'coduet@([A-Za-z0-9_.-]+)' | Select-Object -First 1
  if ($m) { $Market = $m.Matches[0].Groups[1].Value }
}
$man = Get-Content $Manifest -Raw | ConvertFrom-Json
$Installed = Installed-Version
if (-not $Installed) { $Installed = $man.version }
"installed=$Installed"
"marketplace=$Market"

if ($Mode -eq 'check') {
  $raw = $man.repository -replace '^https://github.com/([^/]+)/([^/]+).*$', 'https://raw.githubusercontent.com/$1/$2/main'
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $latest = (Invoke-RestMethod -UseBasicParsing -TimeoutSec 10 "$raw/plugins/coduet/.claude-plugin/plugin.json").version
  } catch { $latest = '' }
  if (-not $latest) { 'latest=unknown'; 'update=unknown'; exit 0 }
  "latest=$latest"
  Set-Content (Join-Path $CoduetHome 'ultimo-controllo.txt') "$((Get-Date).ToString('yyyy-MM-dd HH:mm')) $latest"
  $upd = 'no'
  try { if ([version]$latest -gt [version]$Installed) { $upd = 'yes' } } catch { if ($latest -ne $Installed) { $upd = 'yes' } }
  "update=$upd"
  "changelog=$raw/CHANGELOG.md"
  exit 0
}

if ($Mode -eq 'apply') {
  if (-not $Claude) { 'result=no-cli'; exit 2 }
  $o1 = & $Claude plugin marketplace update $Market 2>&1; $r1 = $LASTEXITCODE
  $o2 = & $Claude plugin update "coduet@$Market" 2>&1; $r2 = $LASTEXITCODE
  $after = Installed-Version
  "before=$Installed"
  "after=$(if ($after) { $after } else { 'unknown' })"
  if ($r1 -eq 0 -and $r2 -eq 0) { 'result=ok'; exit 0 }
  Add-Content $Log "$(Now-Iso) update failed"; Add-Content $Log ($o1 | Out-String); Add-Content $Log ($o2 | Out-String)
  'result=error'; "log=$Log"
  "manual=& `"$Claude`" plugin marketplace update $Market; & `"$Claude`" plugin update coduet@$Market"
  exit 1
}
'usage: coduet-update.ps1 check|apply'; exit 2
