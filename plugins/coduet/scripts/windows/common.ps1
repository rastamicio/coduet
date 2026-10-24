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
