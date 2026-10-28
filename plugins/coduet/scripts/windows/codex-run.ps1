# Runs one Codex task in its own git worktree and records its status.
#   codex-run.ps1 -Project <folder> -Task <name> -PromptFile <file> [-Base <branch>] [-Effort low|medium|high] [-Max <n>]
#                 [-WorktreeDir beside|inside] [-Image <file1>,<file2>]
# Run it in the background: it ends with a single "CODEX ..." summary line (CODEX WAITING, exit 4, when Codex has no quota).
# Codex runs in a detached worker, so it goes on (and records its outcome) even if this script or the Claude session stops.
param(
  [string]$Project, [string]$Task, [string]$PromptFile, [string]$Base = '', [string]$Effort = 'medium', [int]$Max = 2,
  [string]$WorktreeDir = 'beside', [string[]]$Image = @(), [switch]$Worker, [string]$TaskFile = ''
)
. (Join-Path $PSScriptRoot 'common.ps1')

if ($Worker) {
  $TF = $TaskFile
  Task-Set $TF pid $PID
  $WT = Task-Get $TF 'worktree'; $Effort = Task-Get $TF 'effort'; $Out = Join-Path $WT '.codex-output.txt'
  $imgArgs = ((Task-Get $TF 'images') -split '\|' | Where-Object { $_ } | ForEach-Object { "-i `"$_`"" }) -join ' '
  # cmd handles redirection and quoting of paths with spaces or apostrophes reliably.
  $exe = Task-Get $TF 'codex'; if (-not $exe) { $exe = 'codex' }
  $cmdLine = "`"$exe`" exec --cd `"$WT`" --sandbox workspace-write -c model_reasoning_effort=`"$Effort`" $imgArgs -o `"$WT\.codex-esito.md`" - < `"$WT\.codex-prompt.md`" > `"$Out`" 2>&1"
  $p = Start-Process -FilePath $env:ComSpec -ArgumentList '/d', '/s', '/c', "`"$cmdLine`"" -WindowStyle Hidden -PassThru
  $p.WaitForExit(); $code = $p.ExitCode
  $tok = Codex-Tokens $Out; $ses = Codex-Session $Out
  Set-Location -LiteralPath $WT
  $files = @(git status --porcelain | Where-Object { $_ -notmatch '\.codex-' }).Count
  Task-Set $TF ended (Now-Iso); Task-Set $TF exit $code; Task-Set $TF tokens $(if ($tok) { $tok } else { '?' })
  Task-Set $TF session $ses; Task-Set $TF files $files
  $status = if (Codex-HitLimit $Out) { 'limit' } elseif ($code -eq 0) { 'done' } else { 'error' }
  Task-Set $TF status $status
  exit 0
}

if (-not ($Project -and $Task -and $PromptFile)) { 'CODEX ERROR reason=missing-parameters'; exit 1 }
$Project = (Resolve-Path -LiteralPath $Project).Path
$Name = Split-Path $Project -Leaf
$TF = Task-File $Name $Task
if ((Active-Count) -ge $Max) { "CODEX QUEUED task=$Task reason=max-$Max-active"; exit 3 }
# No quota left: don't start Codex (unknown = launch as before).
$lim = @(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'codex-limits.ps1'))
if ((Codex-Available $lim) -eq 'no') { "CODEX WAITING task=$Task reason=quota resets_at=$(Codex-ResetAt $lim)"; exit 4 }

$WT = if ($WorktreeDir -in 'inside', 'dentro') { Join-Path $Project ".codex-worktrees\$Task" } else { Join-Path (Split-Path $Project -Parent) "$Name-codex-$Task" }
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
if (-not (Select-String -Path $excl -Pattern '^\.codex-worktrees/$' -Quiet)) { Add-Content $excl '.codex-worktrees/' }
Copy-Item -LiteralPath $PromptFile (Join-Path $WT '.codex-prompt.md') -Force

Task-Set $TF project $Project; Task-Set $TF task $Task; Task-Set $TF worktree $WT
Task-Set $TF status running; Task-Set $TF started (Now-Iso); Task-Set $TF effort $Effort
Task-Set $TF images (($Image | ForEach-Object { (Resolve-Path -LiteralPath $_).Path }) -join '|')
# The detached worker may not inherit this session's PATH: give it Codex's full path.
$cx = Get-Command codex -CommandType Application -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.exe', '.cmd', '.bat' } | Select-Object -First 1
Task-Set $TF codex $(if ($cx) { $cx.Source } else { '' })
foreach ($k in 'pid', 'ended', 'exit', 'tokens', 'session', 'files') { Task-Set $TF $k '' }

# Started through WMI the worker is not a child of this process: it survives the end of the Claude session.
$wl = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Worker -TaskFile `"$TF`""
$wpid = $null
try {
  $si = New-CimInstance -CimClass (Get-CimClass Win32_ProcessStartup) -ClientOnly -Property @{ ShowWindow = [uint16]0 }
  $r = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $wl; CurrentDirectory = $WT; ProcessStartupInformation = $si } -ErrorAction Stop
  if ($r.ReturnValue -eq 0) { $wpid = $r.ProcessId }
} catch { }
if (-not $wpid) {
  $wpid = (Start-Process powershell.exe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$PSCommandPath`"", '-Worker', '-TaskFile', "`"$TF`"" -WindowStyle Hidden -PassThru).Id
}
"CODEX STARTED task=$Task worktree=$WT pid=$wpid"

Start-Sleep -Seconds 3
while ((Task-Get $TF 'status') -eq 'running') {
  $w = Task-Get $TF 'pid'; if (-not $w) { $w = $wpid }
  if (-not (Get-Process -Id $w -ErrorAction SilentlyContinue)) {
    Start-Sleep -Seconds 2
    if ((Task-Get $TF 'status') -eq 'running') { Task-Set $TF status error }
    break
  }
  Start-Sleep -Seconds 5
}
"CODEX FINISHED task=$Task status=$(Task-Get $TF 'status') files=$(Task-Get $TF 'files') tokens=$(Task-Get $TF 'tokens') session=$(Task-Get $TF 'session') worktree=$WT"
