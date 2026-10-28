# Minimal assertions for Coduet's script tests (no external dependencies).
$RepoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$Scripts = Join-Path $RepoRoot 'plugins\coduet\scripts\windows'
$Fixtures = Join-Path $RepoRoot 'tests\fixtures'
$script:Pass = 0; $script:Fail = 0
function Assert-Eq($expected, $actual, [string]$name) {
  if ("$expected" -eq "$actual") { $script:Pass++ } else { $script:Fail++; Write-Output "FAIL ${name}: expected [$expected] got [$actual]" }
}
function Assert-Contains([string]$text, [string]$needle, [string]$name) {
  if ($text.Contains($needle)) { $script:Pass++ } else { $script:Fail++; Write-Output "FAIL ${name}: [$needle] not in [$text]" }
}
function Assert-NotContains([string]$text, [string]$needle, [string]$name) {
  if ($text.Contains($needle)) { $script:Fail++; Write-Output "FAIL ${name}: [$needle] found in [$text]" } else { $script:Pass++ }
}
# Child scripts write UTF-8 (status line): decode their output the same way.
[Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
# Isolated Coduet home for each test file.
$env:CODUET_HOME = Join-Path $env:TEMP ('coduet-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $env:CODUET_HOME | Out-Null
function Run-Script([string]$name, [string[]]$arguments = @()) {
  $out = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Scripts $name) @arguments
  return ($out -join "`n")
}
function Finish([string]$file) {
  Write-Output "${file}: PASS $script:Pass FAIL $script:Fail"
  if ($script:Fail -gt 0) { exit 1 } else { exit 0 }
}
