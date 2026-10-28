# Claude's quota: handoff to Codex and return

Scripts are in the plugin's `scripts/windows|unix` folder (see the core skill). Not with an API-key Claude plan (no quota windows).

## At the threshold (context line `Coduet: Claude quota at <n>%…`)

1. Reach a stable point; update "Status and handoff" in detail (precise next step).
2. List open Claude tasks with `Codex-ready: yes` (and Codex tasks not launched yet). Plans without `Codex-ready` lines: judge open tasks by the Codex criteria, as before. Ask with a multiple-choice question: "Lend <n> tasks to Codex (<list>)?" — Yes (recommended) / Only some / No, I'll go on.
3. **Timeout**: before asking, launch in the background a command that waits 5 minutes (`Start-Sleep 300` / `sleep 300`). If it ends before the user answers, go on with "Yes" and say so. If the session can't be woken by a background command, or the question blocks without a timeout, write the question as text, lend the tasks right away and say the user can take them back by writing "riprendi i task".
4. For each task: `handoff-prompt <plan> <N> <file>`, then `codex-run` as in Step 5 (task name `task<N>`, base branch from the plan). `CODEX STARTED` → set `**Status:** lent to Codex`; `CODEX QUEUED`/`CODEX WAITING` → leave it open. Add `- Lent to Codex at <time>: <tasks>` under "Status and handoff".
5. Codex without quota (`codex-limits`): lend nothing; each resumes its own tasks after its reset.
6. Claude's return: if "Claude automatic return" is on, `schedule-claude-return <project>`; otherwise tell the user when the quota resets (status line file or estimate) and to write "riprendi Coduet". Send "Claude quota", commit and push the plan.

## At the limit (no Claude tokens)

The plugin's `StopFailure` hook runs `claude-limit-hit` when a turn ends on `rate_limit`, only in projects with a Coduet plan and Codex installed: it does steps 4-6 above by script (once per quota window), changes the plan only locally (no push) and shows a desktop notice. Its log: `~/.coduet/claude-limit-<project>.log`.

## Strict review of lent tasks

On top of Step 6: read the whole diff (not samples); check the architecture choices against plan and spec; run the tests and the plan's verification commands yourself; no files outside the task. Not good → fix it or redo it yourself; don't send it back to Codex. Then set the task's status to merged.
