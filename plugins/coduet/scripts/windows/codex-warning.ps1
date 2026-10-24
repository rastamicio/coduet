# Backup warning: shows a window only if Claude did not step in and the resume did not succeed.
#   codex-warning.ps1 -Worktree <folder> -Task <name> -Session <id> [-Effort medium]
param([string]$Worktree, [string]$Task, [string]$Session, [string]$Effort = 'medium')
$log = Join-Path $Worktree '.codex-ripresa.log'
$txt = if (Test-Path $log) { Get-Content $log -Raw } else { '' }
if ($txt -match 'CONTROLLO CLAUDE' -or $txt -match 'COMPLETATO') { exit 0 }
$why = if (-not $txt) { 'the resume never started' } elseif ($txt -match 'LIMITE') { 'the Codex quota is still used up' } else { 'the resume failed (see .codex-output-ripresa.txt)' }
$msg = "Coduet - ${Task}: $why, and Claude could not step in.`n`nTo restart it by hand, open PowerShell and run:`n`ncd `"$Worktree`"`ncodex exec resume $Session -c sandbox_mode=workspace-write -c model_reasoning_effort=$Effort `"Continue the task. Do not commit.`""
Add-Type -AssemblyName PresentationFramework
[System.Windows.MessageBox]::Show($msg, 'Coduet') | Out-Null
