# Runs every Windows test file. Exit code 1 if any fails.
$rc = 0
Get-ChildItem (Join-Path $PSScriptRoot 'windows') -Filter *.Tests.ps1 | ForEach-Object {
  & powershell -NoProfile -ExecutionPolicy Bypass -File $_.FullName
  if ($LASTEXITCODE -ne 0) { $rc = 1 }
}
if ($rc -eq 0) { 'ALL PASS' } else { 'SOME FAIL' }
exit $rc
