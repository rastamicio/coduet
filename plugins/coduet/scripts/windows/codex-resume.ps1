# Resumes a Codex session after the quota reset (run by the scheduler).
#   codex-resume.ps1 -Worktree <folder> -Task <name> -Session <id> [-Effort medium]
param([string]$Worktree, [string]$Task, [string]$Session, [string]$Effort = 'medium')
. (Join-Path $PSScriptRoot 'common.ps1')
$log = Join-Path $Worktree '.codex-ripresa.log'; $out = Join-Path $Worktree '.codex-output-ripresa.txt'
Set-Location -LiteralPath $Worktree
Add-Content $log "$(Now-Iso) AVVIO ripresa"
# stdin from NUL: without a terminal, codex exec waits for stdin to close before starting.
$cmdLine = "codex exec resume $Session -c sandbox_mode=`"workspace-write`" -c model_reasoning_effort=`"$Effort`" -o .codex-esito.md `"Continue the task from where you stopped. Do not commit. At the end write a summary.`" < NUL > `"$out`" 2>&1"
$p = Start-Process -FilePath $env:ComSpec -ArgumentList '/d', '/s', '/c', "`"$cmdLine`"" -WindowStyle Hidden -PassThru -Wait
if (Codex-HitLimit $out) { Add-Content $log "$(Now-Iso) LIMITE ancora raggiunto" }
elseif ($p.ExitCode -ne 0) { Add-Content $log "$(Now-Iso) ERRORE codice $($p.ExitCode)" }
else { Add-Content $log "$(Now-Iso) COMPLETATO" }
# Remove this scheduled task now that it has run (last line: nothing may follow it).
Unregister-ScheduledTask -TaskName "Coduet-resume-$($Task -replace '[^A-Za-z0-9_-]', '_')" -Confirm:$false -ErrorAction SilentlyContinue
