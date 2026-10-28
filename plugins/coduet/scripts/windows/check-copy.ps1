# Reports the state of a local project copy, as key=value lines.
#   check-copy.ps1 [folder] [-WorktreeDir beside|inside]
param([string]$Dir = '.', [string]$WorktreeDir = 'beside')
if (-not (Test-Path $Dir)) { 'folder=missing'; exit 1 }
Set-Location -LiteralPath $Dir
"folder=$((Get-Location).Path)"
git rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { 'git=no'; exit 0 }
'git=yes'
$remote = git remote get-url origin 2>$null
"remote=$(if ($remote) { $remote } else { 'none' })"
"branch=$(git rev-parse --abbrev-ref HEAD)"
"uncommitted=$(@(git status --porcelain).Count)"
if ($remote) {
  git fetch -q origin 2>$null; "fetch=$(if ($LASTEXITCODE -eq 0) { 'ok' } else { 'failed' })"
  $up = git rev-parse --abbrev-ref '@{u}' 2>$null
  if ($up) { "upstream=$up"; "behind=$(git rev-list --count "HEAD..$up")"; "ahead=$(git rev-list --count "$up..HEAD")" }
  else { 'upstream=none' }
}
"worktrees=$(@(git worktree list).Count - 1)"
"codex_branches=$(@(git branch --list 'codex/*').Count)"
if (Test-Path package.json) { "deps=$(if (Test-Path node_modules) { 'installed' } else { 'missing' })" }
foreach ($ex in '.env.example', '.env.sample', '.dev.vars.example') {
  if (Test-Path $ex) { $b = $ex -replace '\.(example|sample)$', ''; "secret_file=${b}:$(if (Test-Path $b) { 'present' } else { 'missing' })" }
}
$excl = Join-Path (git rev-parse --git-common-dir) 'info\exclude'
"work_files_excluded=$(if ((Test-Path $excl) -and (Select-String -Path $excl -Pattern 'codex-' -Quiet)) { 'yes' } else { 'no' })"
# With worktrees inside the project: test and tool configs that don't mention .codex-worktrees (Claude reviews each one).
if ($WorktreeDir -in 'inside', 'dentro') {
  $miss = @(); $found = $false
  $cfg = Get-ChildItem -File -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(vitest|vite|jest|playwright)\.config\.|^tsconfig\.json$|^eslint\.config\.|^\.eslintrc|^(pytest\.ini|setup\.cfg|tox\.ini|pyproject\.toml|package\.json)$' }
  foreach ($f in $cfg) {
    $t = Get-Content -LiteralPath $f.FullName -Raw
    if ($f.Name -eq 'package.json' -and $t -notmatch '"jest"') { continue }
    if ($f.Name -in 'pyproject.toml', 'setup.cfg', 'tox.ini' -and $t -notmatch 'pytest') { continue }
    $found = $true
    if ($t -notmatch 'codex-worktrees') { $miss += $f.Name }
  }
  "worktree_exclusion=$(if ($miss) { 'missing:' + ($miss -join ',') } elseif ($found) { 'ok' } else { 'no-config' })"
}
