# Run by Task Scheduler: restarts Claude in the project, unless a newer return was scheduled meanwhile.
#   claude-return.ps1 -Project <folder> -Token <token> [-TaskName <name>]
param([string]$Project, [string]$Token, [string]$TaskName = '')
. (Join-Path $PSScriptRoot 'common.ps1')
if ($TaskName) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue }
$name = Split-Path $Project -Leaf
$tf = Join-Path $CoduetHome "claude-return-$name.token"
if (-not (Test-Path $tf) -or (Get-Content $tf -Raw).Trim() -ne $Token) { exit 0 }
$log = Join-Path $CoduetHome "claude-return-$name.log"
$cl = Find-Claude
if (-not $cl) { Add-Content $log "$(Now-Iso) ERROR no claude"; exit 1 }
Add-Content $log "$(Now-Iso) START"
# cmd closes stdin (< NUL): without a terminal claude would wait for it.
$p = Start-Process -FilePath $env:ComSpec -ArgumentList '/d', '/s', '/c', "`"`"$cl`" $(Claude-ReturnArgs) < NUL >> `"$log`" 2>&1`"" -WorkingDirectory $Project -WindowStyle Hidden -PassThru -Wait
Add-Content $log "$(Now-Iso) END exit=$($p.ExitCode)"
