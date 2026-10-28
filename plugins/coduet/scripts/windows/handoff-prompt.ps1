# Writes the Codex prompt for lending a Claude task of the plan to Codex. Costs Claude no tokens.
#   handoff-prompt.ps1 -Plan <plan> -Task <number> -Out <output-file>
param([string]$Plan, [string]$Task, [string]$Out)
. (Join-Path $PSScriptRoot 'common.ps1')
$Plan = (Resolve-Path -LiteralPath $Plan).Path
$root = git -C (Split-Path $Plan -Parent) rev-parse --show-toplevel 2>$null
$root = if ($LASTEXITCODE -eq 0 -and $root) { $root -replace '/', '\' } else { Split-Path $Plan -Parent }
$rel = $Plan.Substring($root.Length).TrimStart('\') -replace '\\', '/'
$lines = Get-Content -LiteralPath $Plan -Encoding UTF8
$title = ($lines | Where-Object { $_ -match "^### Task ${Task}:\s*(.*)$" } | Select-Object -First 1) -replace "^### Task ${Task}:\s*", ''
$block = @(); $cur = $false
foreach ($l in $lines) {
  if ($l -match '^### Task (\d+):') { $cur = ($Matches[1] -eq $Task) } elseif ($l -match '^## ') { $cur = $false }
  if ($cur) { $block += $l }
}
$verify = @(); $in = $false
foreach ($l in $lines) {
  if ($l -match '^## Verification commands') { $in = $true; continue }
  if ($l -match '^#') { $in = $false }
  if ($in -and $l.Trim()) { $verify += $l }
}
$text = @(
  "Implement Task $Task ($title) of the plan $rel, following its steps and the decisions recorded in the plan and its spec.",
  'The task as written in the plan (your copy of the plan file may be older):',
  '') + $block + @(
  '',
  "Do not commit. Do not modify files other than those listed in the task. Do not read, print or modify secret or local config files (.env and similar). Do not touch other tasks. If you can't finish, stop and explain. At the end write a summary of what you did and what you could not do."
)
if ($verify.Count) { $text += @('', 'Verification commands:') + $verify }
[IO.File]::WriteAllLines($Out, [string[]]$text, (New-Object Text.UTF8Encoding $false))
"prompt=$Out"
