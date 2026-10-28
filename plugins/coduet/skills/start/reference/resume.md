# Codex quota used up: automatic resume

ChatGPT account only (with an API key: no resume). Codex doesn't restart by itself when the quota resets; partial work stays in the worktree. Three layers:
1. **Resume** by the OS scheduler: free, runs even if Claude is out of quota.
2. **Claude check** (parameter, default 20 min after): reads the outcome, tells the user, relaunches if it can.
3. **Backup notice** (parameter, default 40 min after the resume): a desktop window only if Claude didn't step in and the resume failed.

Involve the user only when Claude can't solve it.

## 1. Decide

User present: ask whether to give the unfinished Codex tasks to Claude or auto-resume. Absent: auto-resume, noted in the plan.

## 2. Times

Reset time from `codex-limits` (`resets_at` of the used-up window; `CODEX WAITING` already gives it); if `ok=0`, from the error in `.codex-output.txt`; if missing, ask the user (`/status` in Codex); if absent, use the reset estimate parameter and note it.
- Resume = reset + margin (several tasks waiting: stagger them by the concurrent limit, in the order they stopped).
- Claude check = resume + parameter (skip if off).
- Backup notice = resume + parameter.

## 3. Schedule

- Windows: `schedule-resume.ps1 -Worktree "<wt>" -Task <name> -Session <id> -ResumeAt "yyyy-MM-dd HH:mm" -WarnAt "yyyy-MM-dd HH:mm" -Effort <level>` (Task Scheduler: starts late if the PC was off, wakes it from sleep, removes itself).
- macOS/Linux: `schedule-resume.sh "<wt>" <name> <id> "YYYY-MM-DD HH:MM" "YYYY-MM-DD HH:MM" <level>` (`at`, systemd or launchd).
- Each line `scheduled=… when=…` is ok; `error=` → tell the user right away and give the manual command:
  `cd "<wt>" && codex exec resume <id> -c sandbox_mode="workspace-write" -c model_reasoning_effort="<level>" -o .codex-esito.md "Continue the task from where you stopped. Do not commit. At the end write a summary." < /dev/null`
  (`resume` has no `--sandbox`/`--cd`: run it inside the worktree; always use the session id, never `--last`; keep stdin closed (`< NUL` in cmd), or Codex waits forever when no terminal is attached.)
- **Claude check**: create a scheduled task with the session's scheduling tool that survives this session (not session-only cron). Prompt:
  "Project in <project path>. Use the coduet:start skill, reference/resume.md § Check, for the Codex task '<name>' in worktree <wt> (session <id>). First append to <wt>/.codex-ripresa.log the line '<date time> CONTROLLO CLAUDE start'; at the end '<date time> CONTROLLO CLAUDE end' with what you did."
  No suitable tool: ask the user to create it from the desktop app with that prompt.
- Update the plan's "Codex waiting for quota" line and send the "Codex quota" message with the three times.

## Check (at the scheduled time and at every session start)

First, tasks that ended while no session was watching (Codex outlives the session that launched it): in `codex-status`, `done` not yet merged → review (Step 6); `limit` → Step 8; `error` → read `.codex-output.txt`, relaunch or explain; `stopped` (process gone, no outcome) → relaunch with `codex-run` in the same worktree.

For each waiting task, read `<wt>/.codex-ripresa.log`:
- `COMPLETATO` → review (Step 6), clear the plan line, send "Resume outcome: completed".
- `ERRORE` → read `.codex-output-ripresa.txt`. Fixable (command, path, session not found) → relaunch with `codex-run` in the same worktree (same task name; the prompt says to continue from the work present). Not fixable → explain to the user; they can just reply "yes, relaunch".
- `LIMITE` → quota not back: reschedule all three for the next reset, send "Resume outcome: still no quota".
- No `AVVIO` and the resume time passed → it never started (PC off, task missing). On Windows check `Get-ScheduledTask -TaskName 'Coduet-*'`; relaunch if possible, tell the user.
- Resume time not reached → remind it in one line.

Use the session's push notification tool if available, otherwise a message.

## Measuring the Claude check's cost (first times)

Claude can't see its quota. For the first N checks (parameter; 0 = none), after the check tell the user its start and end time and what was done, and ask them to compare session and weekly usage (app settings → Usage, or `/usage`) before and after. Log each in `docs/codex-registro.md` ("Claude check cost"). After the last one, summarise and ask whether to keep the check or switch it off (`coduet:settings`); off → the backup notice is the only notice.

## Claude's return

At a start after Claude's quota reset (a scheduled `claude -p` run, or the user writes "riprendi Coduet"), after the start sequence:
- Tasks `lent to Codex` still queued (no `codex-status` entry, no worktree): set them back to `**Status:** open` for Claude.
- Running: leave them to Codex.
- Finished: strict review (`reference/handoff.md`), then merge into the base branch as in Step 6.
- Then go on with the plan.

In a scheduled `claude -p` run nobody is watching: no merge into `main`, no force push, no deletions, no questions. A decision needed → write it in the plan (blocked, why), push, and stop with a desktop notice (`notify`).
