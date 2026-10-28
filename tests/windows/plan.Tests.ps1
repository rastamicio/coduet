. (Join-Path $PSScriptRoot 'lib.ps1')
. (Join-Path $Scripts 'common.ps1')

$r = Join-Path $env:TEMP ('coduet-plan-' + [guid]::NewGuid().ToString('N') + '\proj')
New-Item -ItemType Directory -Force -Path (Join-Path $r 'docs\plans'), (Join-Path $r '.codex-worktrees\x\docs') | Out-Null
git -C $r init -q -b main
Copy-Item (Join-Path $Fixtures 'plan-new.md') (Join-Path $r 'docs\plans\feature.md')
Copy-Item (Join-Path $Fixtures 'plan-new.md') (Join-Path $r '.codex-worktrees\x\docs\copy.md')
$plan = Join-Path $r 'docs\plans\feature.md'
Assert-Eq $plan (Find-CoduetPlan $r) 'find: plan in docs\plans'
Assert-Eq $plan (Find-CoduetPlan (Join-Path $r 'docs')) 'find: from a subfolder'
$e = Join-Path $env:TEMP ('coduet-empty-' + [guid]::NewGuid().ToString('N')); New-Item -ItemType Directory $e | Out-Null
git -C $e init -q -b main; Set-Content (Join-Path $e 'notes.md') '# Notes'
Assert-Eq '' (Find-CoduetPlan $e) 'find: no plan'

Assert-Eq '1|Parser for the config file|feature/config' ((Plan-Lendable (Join-Path $Fixtures 'plan-new.md')) -join ';') 'lendable: only task 1'
Assert-Eq '' ((Plan-Lendable (Join-Path $Fixtures 'plan-old.md')) -join ';') 'lendable: old plan has none'

$c = Join-Path $env:TEMP ('coduet-copy-' + [guid]::NewGuid().ToString('N') + '.md'); Copy-Item (Join-Path $Fixtures 'plan-new.md') $c
Plan-SetStatus $c 1 'lent to Codex'
$d = Compare-Object (Get-Content (Join-Path $Fixtures 'plan-new.md')) (Get-Content $c) | Where-Object SideIndicator -eq '=>'
Assert-Eq 1 @($d).Count 'set_status: one line changed'
Assert-Eq '**Status:** lent to Codex' $d.InputObject 'set_status: new value'
Assert-Eq '' ((Plan-Lendable $c) -join ';') 'set_status: task 1 no longer lendable'

$o = Join-Path $env:TEMP ('coduet-prompt-' + [guid]::NewGuid().ToString('N') + '.md')
$out = Run-Script 'handoff-prompt.ps1' @('-Plan', $plan, '-Task', '1', '-Out', $o)
Assert-Eq "prompt=$o" $out 'handoff: output line'
$txt = Get-Content $o -Raw
Assert-Contains $txt 'Implement Task 1 (Parser for the config file) of the plan docs/plans/feature.md' 'handoff: goal'
Assert-Contains $txt 'Do not commit.' 'handoff: rules'
Assert-Contains $txt '(.env and similar)' 'handoff: secrets rule'
Assert-Contains $txt 'npm run lint' 'handoff: verification commands'
Assert-Contains $txt '**Base branch:** feature/config' 'handoff: task block inlined'
Assert-Contains $txt '- [ ] Step 1: write the test' 'handoff: task steps inlined'
Assert-NotContains $txt 'Token refresh' 'handoff: other tasks not inlined'

Finish 'plan.Tests.ps1'
