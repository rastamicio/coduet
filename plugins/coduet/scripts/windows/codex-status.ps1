# Shows the state of Codex tasks recorded by Coduet.
#   codex-status.ps1 [task]
param([string]$Filter = '')
. (Join-Path $PSScriptRoot 'common.ps1')
$found = $false
Get-ChildItem $CoduetTasks -Filter *.txt -ErrorAction SilentlyContinue | ForEach-Object {
  $f = $_.FullName; $task = Task-Get $f 'task'
  if ($Filter -and $task -ne $Filter) { return }
  $status = Task-Get $f 'status'
  if ($status -ne 'running' -and $_.LastWriteTime -lt (Get-Date).AddHours(-24)) { return }
  $procId = Task-Get $f 'pid'
  if ($status -eq 'running' -and -not ($procId -and (Get-Process -Id $procId -ErrorAction SilentlyContinue))) { $status = 'stopped' }
  $mins = '?'; $st = Task-Get $f 'started'
  if ($st) { $mins = [int]((Get-Date) - [datetime]$st).TotalMinutes }
  $out = Join-Path (Task-Get $f 'worktree') '.codex-output.txt'
  $last = ''
  if (Test-Path $out) {
    $last = Get-Content $out -Tail 40 | Where-Object { $_.Trim() -and $_ -notmatch '^(diff|index|@@|[+-])' } | Select-Object -Last 1
    if ($last -and $last.Length -gt 160) { $last = $last.Substring(0, 160) }
  }
  "task=$task status=$status minutes=$mins tokens=$(Task-Get $f 'tokens') files=$(Task-Get $f 'files') project=$(Split-Path (Task-Get $f 'project') -Leaf)"
  if ($last) { "  last: $last" }
  $script:found = $true
}
if (-not $found) { 'no-tasks' }
"active=$(Active-Count)"
