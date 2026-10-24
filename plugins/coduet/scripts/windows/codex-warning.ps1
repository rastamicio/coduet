# Backup warning: shows a window only if Claude did not step in and the resume did not succeed.
#   codex-warning.ps1 -Worktree <folder> -Task <name> -Session <id> [-Effort medium]
param([string]$Worktree, [string]$Task, [string]$Session, [string]$Effort = 'medium')
$log = Join-Path $Worktree '.codex-ripresa.log'
$safe = $Task -replace '[^A-Za-z0-9_-]', '_'
# Remove both scheduled tasks of this resume once this script has run, whatever the outcome.
function Remove-Tasks { foreach ($n in "Coduet-resume-$safe", "Coduet-warning-$safe") { Unregister-ScheduledTask -TaskName $n -Confirm:$false -ErrorAction SilentlyContinue } }
$txt = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
if ($txt -match 'CONTROLLO CLAUDE' -or $txt -match 'COMPLETATO') { Remove-Tasks; exit 0 }
$why = if (-not $txt) { 'the resume never started' } elseif ($txt -match 'LIMITE') { 'the Codex quota is still used up' } else { 'the resume failed (see .codex-output-ripresa.txt)' }
$msg = "Coduet - ${Task}: $why, and Claude could not step in.`n`nTo restart it by hand, open PowerShell and run:`n`ncd `"$Worktree`"`ncodex exec resume $Session -c sandbox_mode=workspace-write -c model_reasoning_effort=$Effort `"Continue the task. Do not commit.`""
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show($msg, 'Coduet') | Out-Null
Remove-Tasks
