# Fake claude CLI for Windows tests. $env:FAKE_CLAUDE_LOGGED = '0' -> not logged in.
if ($args[0] -eq 'auth' -and $args[1] -eq 'status') { if ($env:FAKE_CLAUDE_LOGGED -eq '0') { 'Not logged in'; exit 1 } else { 'Logged in'; exit 0 } }
if ($env:FAKE_CLAUDE_MARKER) { Add-Content -Path $env:FAKE_CLAUDE_MARKER -Value ('claude ' + ($args -join ' ')) }
exit 0
