. (Join-Path $PSScriptRoot 'lib.ps1')
$env:PATH = "$Fixtures;$env:PATH"
function New-Repo {
  $r = Join-Path $env:TEMP ('coduet-repo-' + [guid]::NewGuid().ToString('N') + '\proj')
  New-Item -ItemType Directory -Force -Path $r | Out-Null
  git -C $r init -q -b main; git -C $r -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
  return $r
}
$p = Join-Path $env:TEMP ('coduet-prompt-' + [guid]::NewGuid().ToString('N') + '.md'); Set-Content $p 'Do it.'

$r = New-Repo; $env:FAKE_CODEX_MODE = 'reached'
$out = Run-Script 'codex-run.ps1' @('-Project', $r, '-Task', 't1', '-PromptFile', $p, '-WorktreeDir', 'inside'); $code = $LASTEXITCODE
Assert-Contains $out 'CODEX WAITING task=t1 reason=quota resets_at=1793210994' 'reached: waiting line'
Assert-Eq 4 $code 'reached: exit code 4'
Assert-Eq 1 @(git -C $r worktree list).Count 'reached: no worktree'

$r = New-Repo; $env:FAKE_CODEX_MODE = 'noserver'
$out = Run-Script 'codex-run.ps1' @('-Project', $r, '-Task', 't2', '-PromptFile', $p, '-WorktreeDir', 'inside')
Assert-Contains $out 'CODEX FINISHED task=t2 status=done' 'noserver: launches as before'

$r = New-Repo; $env:FAKE_CODEX_MODE = 'ok'
$out = Run-Script 'codex-run.ps1' @('-Project', $r, '-Task', 't3', '-PromptFile', $p, '-WorktreeDir', 'inside')
Assert-Contains $out 'CODEX FINISHED task=t3 status=done' 'ok: launches'

Finish 'codex-run-quota.Tests.ps1'
