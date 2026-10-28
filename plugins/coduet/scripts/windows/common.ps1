# Shared helpers for Coduet scripts (Windows PowerShell 5.1+).
$ErrorActionPreference = 'Continue'
$CoduetHome = if ($env:CODUET_HOME) { $env:CODUET_HOME } else { Join-Path $env:USERPROFILE '.coduet' }
$CoduetTasks = Join-Path $CoduetHome 'tasks'
$PluginRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
New-Item -ItemType Directory -Force -Path $CoduetTasks | Out-Null

function Now-Iso { (Get-Date).ToString('yyyy-MM-ddTHH:mm:ss') }

function Find-Claude {
  $c = Get-Command claude -ErrorAction SilentlyContinue
  if ($c) { return $c.Source }
  $p = Join-Path $env:USERPROFILE '.local\bin\claude.exe'
  if (Test-Path $p) { return $p }
  return $null
}

function Task-File([string]$project, [string]$task) {
  $n = ("$project" + '__' + "$task") -replace '[^A-Za-z0-9_.-]', '_'
  Join-Path $CoduetTasks "$n.txt"
}
function Task-Set([string]$file, [string]$key, [string]$value) {
  $lines = @()
  if (Test-Path $file) { $lines = @(Get-Content $file | Where-Object { $_ -notlike "$key=*" }) }
  $lines += "$key=$value"
  Set-Content -Path $file -Value $lines -Encoding UTF8
}
function Task-Get([string]$file, [string]$key) {
  if (-not (Test-Path $file)) { return '' }
  $l = Get-Content $file | Where-Object { $_ -like "$key=*" } | Select-Object -Last 1
  if ($l) { return $l.Substring($key.Length + 1) } else { return '' }
}
function Active-Count {
  $n = 0
  Get-ChildItem $CoduetTasks -Filter *.txt -ErrorAction SilentlyContinue | ForEach-Object {
    if ((Task-Get $_.FullName 'status') -eq 'running') {
      $procId = Task-Get $_.FullName 'pid'
      if ($procId -and (Get-Process -Id $procId -ErrorAction SilentlyContinue)) { $n++ }
    }
  }
  return $n
}

function Codex-Tokens([string]$out) {
  if (-not (Test-Path $out)) { return '' }
  $lines = Get-Content $out
  for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    if ($lines[$i] -match 'tokens used') {
      for ($j = $i + 1; $j -lt $lines.Count; $j++) { $d = $lines[$j] -replace '[^0-9]', ''; if ($d) { return $d } }
    }
  }
  return ''
}
function Codex-Session([string]$out) {
  if (-not (Test-Path $out)) { return '' }
  $m = Select-String -Path $out -Pattern '^session id:\s*(\S+)' | Select-Object -First 1
  if ($m) { return $m.Matches[0].Groups[1].Value } else { return '' }
}
function Codex-HitLimit([string]$out) {
  if (-not (Test-Path $out)) { return $false }
  return [bool](Select-String -Path $out -Pattern 'usage limit|rate limit|limit reached' -Quiet)
}

# Reads codex-limits output lines. 'yes' = Codex has quota, 'no' = used up, 'unknown' = could not read.
function Limits-Map([string[]]$lines) {
  $m = @{}
  foreach ($l in $lines) { $i = $l.IndexOf('='); if ($i -gt 0) { $m[$l.Substring(0, $i)] = $l.Substring($i + 1) } }
  return $m
}
function Codex-Available([string[]]$lines) {
  $m = Limits-Map $lines
  if ($m['ok'] -ne '1') { return 'unknown' }
  $p = [double]('0' + $m['primary_used']); $s = [double]('0' + $m['secondary_used'])
  if (-not $m['reached'] -and $p -lt 100 -and $s -lt 100) { return 'yes' } else { return 'no' }
}
# resets_at of the used-up window (secondary if both), or ''.
function Codex-ResetAt([string[]]$lines) {
  $m = Limits-Map $lines
  $p = [double]('0' + $m['primary_used']); $s = [double]('0' + $m['secondary_used'])
  if ($s -ge 100 -or $m['reached'] -eq 'secondary') { return $m['secondary_resets_at'] }
  if ($p -ge 100 -or $m['reached']) { return $m['primary_resets_at'] }
  return ''
}

# Coduet plan: a .md file at the repository root or under docs\ (3 levels) with "## Status and handoff" and "PC copy:".
# Returns its path (the most recently modified if several), or ''.
function Find-CoduetPlan([string]$dir) {
  $root = git -C $dir rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $root) { $root = (Resolve-Path -LiteralPath $dir).Path } else { $root = $root -replace '/', '\' }
  $files = @(Get-ChildItem -LiteralPath $root -Filter *.md -File -ErrorAction SilentlyContinue)
  $docs = Join-Path $root 'docs'
  if (Test-Path -LiteralPath $docs) {
    $files += @(Get-ChildItem -LiteralPath $docs -Filter *.md -File -Recurse -Depth 3 -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -notmatch '\\(\.codex-worktrees|node_modules)\\' })
  }
  $best = $files | Where-Object {
    (Select-String -LiteralPath $_.FullName -Pattern '^## Status and handoff' -Quiet) -and (Select-String -LiteralPath $_.FullName -Pattern 'PC copy:' -SimpleMatch -Quiet)
  } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($best) { return $best.FullName } else { return '' }
}
function Plan-Field([string]$line, [string]$name) {
  if ($line -match ('\*\*' + $name + ':\*\*\s*(.*?)\s*$')) { return $Matches[1] } else { return $null }
}
# One line "<N>|<title>|<base branch>" per task with Executor Claude, Codex-ready yes, Status open.
function Plan-Lendable([string]$plan) {
  $out = @(); $t = $null
  $flush = { if ($t -and $t.ex -eq 'claude' -and $t.cr -eq 'yes' -and $t.st -eq 'open') { "$($t.n)|$($t.ti)|$($t.br)" } }
  foreach ($l in Get-Content -LiteralPath $plan -Encoding UTF8) {
    if ($l -match '^### Task (\d+):\s*(.*)$') { $out += & $flush; $t = @{ n = $Matches[1]; ti = $Matches[2]; ex = ''; cr = ''; st = ''; br = '' }; continue }
    if ($l -match '^## ') { $out += & $flush; $t = $null; continue }
    if (-not $t) { continue }
    foreach ($f in @(@('Executor', 'ex'), @('Codex-ready', 'cr'), @('Status', 'st'), @('Base branch', 'br'))) {
      $v = Plan-Field $l $f[0]; if ($null -ne $v) { $t[$f[1]] = $(if ($f[1] -eq 'br') { $v } else { $v.ToLower() }) }
    }
  }
  $out += & $flush
  return $out
}
# Changes only the Status line of task N.
function Plan-SetStatus([string]$plan, [string]$n, [string]$status) {
  $cur = $false
  $lines = foreach ($l in Get-Content -LiteralPath $plan -Encoding UTF8) {
    if ($l -match '^### Task (\d+):') { $cur = ($Matches[1] -eq $n) } elseif ($l -match '^## ') { $cur = $false }
    if ($cur -and $l -match '\*\*Status:\*\*') { $l = $l -replace '\*\*Status:\*\*.*', "**Status:** $status" }
    $l
  }
  [IO.File]::WriteAllLines($plan, [string[]]$lines, (New-Object Text.UTF8Encoding $false))
}

# Value of a parameter from the project's .coduet.md, else the personal coduet-config, else the default.
# The parameter line is matched by a regex (names may be translated); the value is the last number on it.
function Coduet-Param([string]$root, [string]$regex, [string]$default) {
  foreach ($f in @((Join-Path $root '.coduet.md'), (Join-Path $env:USERPROFILE '.claude\skills\coduet-config\SKILL.md'))) {
    if (-not (Test-Path -LiteralPath $f)) { continue }
    $l = Get-Content -LiteralPath $f -Encoding UTF8 | Where-Object { $_ -match $regex } | Select-Object -Last 1
    if ($l) { $n = [regex]::Matches($l, '\d+'); if ($n.Count) { return $n[$n.Count - 1].Value } }
  }
  return $default
}
# Local HH:mm of a Unix time.
function HHmm([long]$unix) { ([DateTimeOffset]::FromUnixTimeSeconds($unix)).LocalDateTime.ToString('HH:mm') }
function Repo-Root([string]$dir) {
  $r = git -C $dir rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -eq 0 -and $r) { return ($r -replace '/', '\') } else { return $dir }
}

# Arguments that restart Claude in a project after its quota resets (headless, limited permissions).
function Claude-ReturnArgs {
  $s = Join-Path $PluginRoot 'scripts\windows'
  $tools = "Bash(powershell -NoProfile -ExecutionPolicy Bypass -File $s\:*),Bash(git status:*),Bash(git diff:*),Bash(git log:*),Bash(git add:*),Bash(git commit:*),Bash(git merge:*),Bash(git worktree:*),Bash(git fetch:*),Bash(git push),Read,Edit,Write,Grep,Glob"
  return "-p `"Use the coduet:start skill: resume after Claude's quota reset.`" --permission-mode acceptEdits --allowedTools `"$tools`""
}

# True if a yes/no parameter is switched on in .coduet.md or the personal coduet-config.
function Coduet-ParamOn([string]$root, [string]$regex) {
  foreach ($f in @((Join-Path $root '.coduet.md'), (Join-Path $env:USERPROFILE '.claude\skills\coduet-config\SKILL.md'))) {
    if (-not (Test-Path -LiteralPath $f)) { continue }
    $l = Get-Content -LiteralPath $f -Encoding UTF8 | Where-Object { $_ -match $regex } | Select-Object -Last 1
    if ($l) { return [bool]($l -match '\|\s*(on|yes|sì|si|attivo|attiva)\s*\|') }
  }
  return $false
}
function Coduet-ParamWord([string]$root, [string]$regex, [string]$words, [string]$default) {
  foreach ($f in @((Join-Path $root '.coduet.md'), (Join-Path $env:USERPROFILE '.claude\skills\coduet-config\SKILL.md'))) {
    if (-not (Test-Path -LiteralPath $f)) { continue }
    $l = Get-Content -LiteralPath $f -Encoding UTF8 | Where-Object { $_ -match $regex } | Select-Object -Last 1
    if ($l -and $l -match "\|\s*($words)\s*\|") { return $Matches[1].ToLower() }
  }
  return $default
}
# Desktop notice that doesn't block the caller ($env:CODUET_NOTIFY overrides, for tests).
function Notify([string]$msg) {
  if ($env:CODUET_NOTIFY) { & $env:CODUET_NOTIFY $msg; return }
  Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$(Join-Path $PSScriptRoot 'notify.ps1')`"", '-Message', "`"$($msg -replace '"', "'")`""
}
