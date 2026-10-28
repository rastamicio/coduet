# Fake Codex CLI for Windows tests. $env:FAKE_CODEX_MODE: ok | reached | silent | noserver.
$args = @(($env:FAKE_CODEX_ARGS -split ' ') | Where-Object { $_ })
$mode = if ($env:FAKE_CODEX_MODE) { $env:FAKE_CODEX_MODE } else { 'ok' }
switch ($args[0]) {
  'app-server' {
    if ($mode -eq 'noserver') { [Console]::Error.WriteLine("error: unrecognized subcommand 'app-server'"); exit 2 }
    while ($null -ne ($line = [Console]::In.ReadLine())) {
      if ($mode -eq 'silent') { continue }
      if ($line -like '*"method":"initialize"*') { [Console]::Out.WriteLine('{"id":1,"result":{"userAgent":"fake/0.0.0"}}'); [Console]::Out.Flush() }
      elseif ($line -like '*account/rateLimits/read*') {
        if ($mode -eq 'reached') { $p = 100; $r = '"primary"' } else { $p = 30; $r = 'null' }
        [Console]::Out.WriteLine("{`"id`":2,`"result`":{`"rateLimits`":{`"limitId`":`"codex`",`"primary`":{`"usedPercent`":$p,`"windowDurationMins`":300,`"resetsAt`":1793210994},`"secondary`":{`"usedPercent`":10,`"windowDurationMins`":10080,`"resetsAt`":1793779590},`"planType`":`"plus`",`"rateLimitReachedType`":$r}}}")
        [Console]::Out.Flush()
      }
    }
  }
  'exec' {
    # The worker starts through WMI and gets no environment from the test: without the marker variable, leave a file in the --cd folder.
    $cd = $args[[array]::IndexOf($args, '--cd') + 1].Trim('"')
    $marker = if ($env:FAKE_CODEX_MARKER) { $env:FAKE_CODEX_MARKER } else { Join-Path $cd '.fake-codex-exec' }
    Add-Content -Path $marker -Value ("exec " + ($args -join ' '))
    $null = [Console]::In.ReadToEnd()
    'session id: fake-1'; 'tokens used'; '1234'
  }
  '--version' { 'codex-cli 0.163.0' }
}
exit 0
