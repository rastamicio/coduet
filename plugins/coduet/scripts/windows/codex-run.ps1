# Runs one Codex task in its own git worktree and records its status.
#   codex-run.ps1 -Project <folder> -Task <name> -PromptFile <file> [-Base <branch>] [-Effort low|medium|high] [-Max <n>] [-Image <file1>,<file2>]
# Run it in the background: it ends with a single "CODEX ..." summary line.
param(
  [Parameter(Mandatory)][string]$Project, [Parameter(Mandatory)][string]$Task,
  [Parameter(Mandatory)][string]$PromptFile, [string]$Base = '', [string]$Effort = 'medium', [int]$Max = 2, [string[]]$Image = @()
)
. (Join-Path $PSScriptRoot 'common.ps1')
$Project = (Resolve-Path -LiteralPath $Project).Path
$Name = Split-Path $Project -Leaf
$TF = Task-File $Name $Task
if ((Active-Count) -ge $Max) { "CODEX QUEUED task=$Task reason=max-$Max-active"; exit 3 }

$WT = Join-Path (Split-Path $Project -Parent) "$Name-codex-$Task"
Set-Location -LiteralPath $Project
if (-not (Test-Path -LiteralPath $WT)) {
  if (-not $Base) { $Base = git rev-parse --abbrev-ref HEAD }
  git worktree add -q "$WT" -b "codex/$Task" "$Base"
  if ($LASTEXITCODE -ne 0) { "CODEX ERROR task=$Task reason=worktree"; exit 1 }
}
$excl = Join-Path (git rev-parse --git-common-dir) 'info\exclude'
if (-not ((Test-Path $excl) -and (Select-String -Path $excl -Pattern '\.codex-' -Quiet))) {
  Add-Content $excl ".codex-*`nriprendi-codex.*`navviso-riserva.*"
}
Copy-Item -LiteralPath $PromptFile (Join-Path $WT '.codex-prompt.md') -Force

$Out = Join-Path $WT '.codex-output.txt'
Task-Set $TF project $Project; Task-Set $TF task $Task; Task-Set $TF worktree $WT
Task-Set $TF status running; Task-Set $TF started (Now-Iso); Task-Set $TF effort $Effort

# cmd handles redirection and quoting of paths with spaces or apostrophes reliably.
$imgArgs = ($Image | ForEach-Object { "-i `"$((Resolve-Path -LiteralPath $_).Path)`"" }) -join ' '
$cmdLine = "codex exec --cd `"$WT`" --sandbox workspace-write -c model_reasoning_effort=`"$Effort`" $imgArgs -o `"$WT\.codex-esito.md`" - < `"$WT\.codex-prompt.md`" > `"$Out`" 2>&1"
$p = Start-Process -FilePath $env:ComSpec -ArgumentList '/d', '/s', '/c', "`"$cmdLine`"" -WindowStyle Hidden -PassThru
Task-Set $TF pid $p.Id
"CODEX STARTED task=$Task worktree=$WT pid=$($p.Id)"
$p.WaitForExit(); $code = $p.ExitCode

$tok = Codex-Tokens $Out; $ses = Codex-Session $Out
Set-Location -LiteralPath $WT
$files = @(git status --porcelain | Where-Object { $_ -notmatch '\.codex-' }).Count
Task-Set $TF ended (Now-Iso); Task-Set $TF exit $code; Task-Set $TF tokens $(if ($tok) { $tok } else { '?' })
Task-Set $TF session $ses; Task-Set $TF files $files
$status = if (Codex-HitLimit $Out) { 'limit' } elseif ($code -eq 0) { 'done' } else { 'error' }
Task-Set $TF status $status
"CODEX FINISHED task=$Task status=$status files=$files tokens=$(if ($tok) { $tok } else { '?' }) session=$ses worktree=$WT"
