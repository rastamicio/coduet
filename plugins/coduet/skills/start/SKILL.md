---
name: start
description: Use when the user says "avvia Coduet", "start Coduet", "coduet start", "dividiamo il lavoro con Codex", "split the work with Codex" or similar, at the start of a project or in one already running. Splits the work between Claude and Codex CLI and coordinates plan, parallel runs, review, handoffs and automatic resume.
---

# Coduet: start (Claude Code + Codex)

This skill directs the work. The working method (brainstorm, plan, execution, review) comes from the phase skills in "Configuration"; this skill adds: splitting work with Codex CLI (the user's ChatGPT account), the asset approval loop, handoffs when a quota runs out, and Codex's automatic resume.

- **Reply in the user's language.** Every message below is a template: translate it.
- Works for any project: adapt commands and conventions to the project at hand. "GitHub" means the project's remote (GitHub, GitLab, ...); "PR" includes merge requests.
- **Load a reference file only when its step happens** (paths are relative to this skill's folder). Don't read them up front.
- **Scripts** live in the plugin folder, two levels above this skill: `scripts/windows/*.ps1` (run with `powershell -NoProfile -ExecutionPolicy Bypass -File "<script>" <args>`) and `scripts/unix/*.sh` (run with `bash "<script>" <args>`). They print `key=value` lines. Use them instead of writing commands by hand.

## Messages to the user

The user can't see Codex, schedulers or checks. Say what is happening at **every** step, one or two lines each, starting with `Coduet ·`. Never stay silent while waiting.

| When | Message (template) |
|---|---|
| Start | `Coduet · <where: PC session in <folder> / cloud session / ...>. Codex: <available vX / not reachable from here, because ...>.` |
| Checks done | `Coduet · Project copy ok (branch X, up to date, tests pass)` or what is wrong and what you'll do. |
| Plan split | `Coduet · Plan: N tasks to Claude, M to Codex.` + short list, then ask to confirm. |
| Codex starts | `Coduet · ▶ Codex started: <task> (<time>, est. <n> min). I'll tell you when it finishes; meanwhile you can keep writing to me.` |
| Codex queued | `Coduet · ⏳ <task> queued: <n> Codex tasks already running.` |
| Progress | Only on a new step or when asked: `Coduet · Codex on <task>, <n> min: <last line in plain words>.` |
| Waiting idle | `Coduet · Waiting for Codex (<task>, <n> min). Nothing else to do meanwhile.` |
| Codex done | `Coduet · ✓ Codex finished <task>: <n> files, <tokens> tokens. Now I review it.` |
| Review | `Coduet · Review of <task>: <merged into X / fixed and merged / sent back to Codex / taken over by me>.` |
| Codex quota | `Coduet · ⏸ Codex quota used up on <task>. Work so far is kept. Auto-resume at <time>; I check at <time>; if both fail you get a desktop notice at <time>. Nothing for you to do.` |
| Resume outcome | `Coduet · ↻ Resume of <task>: <completed / still no quota, rescheduled for <time> / failed: <reason>, <what you did>>.` |
| Claude quota | `Coduet · Claude quota running low: saved the state, <n> tasks handed to Codex, the rest waits for me.` |
| Update | `Coduet · ⬆ Coduet <new> available (you have <old>): <highlights>.` After updating: `Coduet · Updated to <new>. Open a new session/thread to use it; this one continues on <old>.` |
| End | `Coduet · ■ Done: <summary>. Codex: <n> tasks, <tokens> tokens.` |

If the session has a task list, add one item per Codex task (`Codex: <task>`) and update it at each change.

## Configuration

Three levels, the most specific wins: (1) defaults below, shipped with the plugin; (2) the user's personal skill `coduet-config` (account or `~/.claude/skills/coduet-config/SKILL.md`; not visible from cloud sessions), only changed values; (3) the project file `.coduet.md` (root, or next to the plan). Values change only through `coduet:settings` or an explicit user request. Never edit plugin files.

**Phase skills** (load with the Skill tool, in order):

| Phase | Skill |
|---|---|
| Brainstorm | `superpowers:brainstorming` |
| Plan | `superpowers:writing-plans` |
| Claude's tasks | `superpowers:subagent-driven-development` |
| Codex isolation | `superpowers:using-git-worktrees` |
| Review | `superpowers:requesting-code-review` |
| Final check | `superpowers:verification-before-completion` |

Extra checks: none.

**Parameters:**

| Parameter | Default |
|---|---|
| Claude plan / Codex access | not set |
| Delegation rule | save Claude's quota |
| Ask whether to split with Codex | always |
| "Small job" threshold (tasks) | 4 |
| Concurrent Codex tasks, all projects | 2 |
| Codex reasoning | medium |
| Worktree folder | beside |
| Trial assets per type | 2-3 |
| Automatic asset regenerations | 2 |
| Codex retries after a failed review | 1 |
| Quota reset estimate if unknown (hours) | 5 |
| Resume margin after reset (minutes) | 5 |
| Claude check after resume | on, after 20 minutes |
| Backup notice after resume (minutes) | 40 |
| Measurements of the Claude check's cost | 3 |
| Image generation with Codex | yes |
| Codex spending cap per session (API key only) | none |

Worktree folder: `beside` = `../<project>-codex-<task>`; `inside` = `<project>/.codex-worktrees/<task>` (project folder stays tidy, dependencies like `node_modules` are found from the parent folders). `inside` needs the project's test runners and tools to skip `.codex-worktrees/`: `check-copy --worktree-dir inside` lists configs that don't (`worktree_exclusion=missing:…`); before the first Codex task propose the exclusion for each one (e.g. Vitest `exclude`, Jest `testPathIgnorePatterns`, pytest `norecursedirs`, tsconfig `exclude`) and edit only with the user's ok; without it, use `beside` for this project and say so. `no-config` → check the runners' defaults yourself. Warn once that `git clean -x` in the main copy would delete the worktrees. Italian names (`accanto`/`dentro`) mean the same.

Defaults equal Claude Pro + ChatGPT Plus. Other plans: `reference/profiles.md`. If a phase skill is missing, say so in one line, suggest `coduet:settings`, and use `reference/base-method.md`. Several skills for a phase run in order. For the Claude method the phase skills win; for everything about Codex, this skill wins. Re-read `.coduet.md` at each phase and before each Codex task; changes apply to work started after them.

## Start sequence (every start or resume)

1. **Configuration**: read the three levels; check the phase skills exist.
2. **First use**: if `coduet-config` doesn't exist, offer in one line the initial setup (`coduet:settings`, about 2 minutes: plans, phase skills, `claude` command, local folder). If declined, go on with defaults.
3. **Where you are** (table below) and the Start message.
4. **Updates** (PC sessions only): run `coduet-update check`. If `update=yes`, follow `reference/updates.md`. If `cli=missing`, also see there. If the check fails, say nothing.
5. **Pending work** (`~/.coduet/registro.md` from versions before 0.4 is no longer used; ignore it): if the plan's "Codex waiting for quota" isn't "none", or `codex-status` shows tasks, apply `reference/resume.md` § Check first. Remind pending asset approvals (`assets/_bozze/anteprima.html`) and undiscussed improvement proposals in `docs/codex-registro.md`.
6. **Plans not set**: if Claude plan or Codex access are "not set" and `~/.coduet/preferenze.txt` doesn't say `plans: don't ask`, offer once, at a stable moment: "Set now" / "Leave it" / "Don't ask again" (writes that line). Not in cloud sessions.

### Where you are: which sessions can run Codex

Codex is installed only on the user's computer, so Codex tasks run only where its commands work.

| Situation | How to tell | What to do |
|---|---|---|
| A. PC session, project in the folder | `codex --version` works, folder is the project | `check-copy`, then go on |
| B. PC session, project only on the remote | `codex` works, folder empty or other | Download it: `reference/local-copy.md` |
| C. Cloud session linked to the PC | cloud (Linux) and you can run commands or start sessions on the PC | Propose working locally; else hybrid: `reference/hybrid.md` |
| D. Cloud session, no PC | no way to reach the PC | Codex unreachable: say why and how to fix (open a session on the PC, or set the project's local default folder); go on without Codex if the user wants |

In A and B, also read `reference/local-copy.md` the first time on a project (copy checks, secrets, no-git projects). Golden rule with a remote: every session syncs with it at the start and pushes at the end; the plan's "PC copy" line names the only local copy to use. Never delete, move or overwrite user files or changes without an explicit ok.

## Mode

- **New project** (no code, no plan): all steps.
- **Running project**: skip Step 2; read the latest plan, `CLAUDE.md`, `git status`, `git log -10 --oneline`. Don't rewrite the plan: add the status section and `Executor` only to open tasks. No plan: ask what to work on and write one.

## Step 0: split or not

Ask with AskUserQuestion: "Split the work with Codex?" — Yes, full split / Only assets, tests and docs / No, I'll do it all. Don't ask if Codex is unreachable (say it). If the parameter is fixed, apply it and say so. Below the small-job threshold, suggest "No" in one line but let the user choose.

## Step 1: Codex check

`codex --version` and `codex login status`. Missing or logged out → say so, go on without Codex. Verified with Codex CLI **0.163.0**: on another version, check `codex exec --help` and `codex exec resume --help` still have `--sandbox workspace-write`, `--cd`, `-o`, `-c`, `resume <id> <prompt>`; adapt and note it for Step 9. If Claude Code asks permission at every Codex launch, offer to allow the Coduet scripts once (project permission rule); nothing else. Before assigning a lot to Codex, ask how much quota is left (`/status` in Codex or chatgpt.com/settings/usage).

## Step 2: brainstorm (new project only)

Load the Brainstorm skill and follow it.

## Step 3: plan with executors

Load the Plan skill, with these additions:

1. At the top of the plan:
```
## Status and handoff
- Last update: <date time>
- PC copy: <path or "none">
- In progress: <task>
- Next step: <precise enough to restart without context>
- Codex running: <task, worktree, session id, or "none">
- Codex waiting for quota: <task, session id, resume time, check time, or "none">
- Assets awaiting approval: <list or "none">
```
2. Each task gets `**Executor:** Claude` or `**Executor:** Codex`.
   - **Claude**: architecture, delicate domain logic, security (auth, permissions, secrets, data access), DB migrations, hard debugging, integration, final review, anything needing secrets or local config.
   - **Codex**: repetitive or mechanical work following existing patterns, tests, docs, copy and translations, mechanical refactors, assets, presentations.
   - Apply the delegation rule (`reference/profiles.md` if not the default). "Only assets, tests and docs" → only those. When in doubt, Claude.
3. Each Codex task has a **base branch** (the feature/PR branch it merges into, not necessarily `main`), a **status** (open, queued, running, ready for review, blocked, merged) and a self-contained **prompt** (Codex doesn't see this chat): goal and exact files; files to use as models; project constraints; quick verification commands that end on their own; and always: "Do not commit. Do not modify files other than those listed. Do not read, print or modify secret or local config files (.env and similar). At the end write a summary of what you did and what you could not do."
4. Before handing a prompt to Codex (and again before launch if time passed), compare it with decisions already made (plan, specs, `CLAUDE.md`, `AGENTS.md`, what the user said). Update it, or ask if unclear.
5. Send the "Plan split" message and wait for confirmation.

## Step 4: AGENTS.md

If missing, create it with the project rules (as in `CLAUDE.md`) plus: work only on the files in the prompt; no commits, no branch changes; never touch secret or local config files; don't touch `Executor: Claude` tasks; if you can't finish, stop and explain. With several branches, propose it as a small PR to `main`; until merged, put its rules at the top of each Codex prompt.

## Step 5: parallel execution

**Codex runs only through `codex exec` (the scripts), never interactively**: interactive mode stops on permission prompts nobody can answer. Any `codex exec` run outside the scripts needs stdin closed (`< /dev/null`, cmd `< NUL`): with no terminal (e.g. the desktop app) it waits for stdin forever.

For each Codex task:
1. Write the prompt to a file (e.g. scratch folder).
2. Launch with the Bash tool and `run_in_background: true`:
   - Windows: `codex-run.ps1 -Project "<folder>" -Task <name> -PromptFile "<file>" -Base <base branch> -Effort <level> -Max <concurrent> -WorktreeDir <beside|inside>`
   - macOS/Linux: `codex-run.sh "<folder>" <name> "<file>" --base <base branch> --effort <level> --max <concurrent> --worktree-dir <beside|inside>`

   The script creates the worktree (path from the Worktree folder parameter) on branch `codex/<task>`, excludes work files from git, records the task in `~/.coduet/tasks/` (the shared registry across projects), runs Codex in workspace-write in a detached process (it keeps running and records its outcome even if this session ends) and ends with one line `CODEX FINISHED task=… status=done|limit|error files=… tokens=… session=… worktree=…`. `CODEX QUEUED` means the concurrent limit is reached: mark the task queued and launch it when one finishes. Effort: `low` trivial, the parameter normally, `high` long or complex.
3. Send "Codex starts", add the task-list item, write session and worktree in the plan.
4. Meanwhile do Claude's tasks with the execution skill. Don't wait idle.
5. **Progress**: if a task runs long and you're not doing anything visible, run `codex-status` every 3-5 minutes (use the session's wait/monitor tool if available) and send "Progress" only when something new appears. When the user asks "how is Codex doing?", run `codex-status` and report all tasks.
6. When the background run finishes you are notified: read its last line and send "Codex done" (or go to Step 8 for `status=limit`).

Assets (images, audio, video, 3D, presentations): follow `reference/assets.md`.

## Step 6: review and merge

1. Read `.codex-esito.md`, the end of `.codex-output.txt` and the worktree diff. With `status=limit` → Step 8; with assets → the approval loop first.
2. Bring `codex/<task>` up to date with its base branch; you resolve conflicts (Codex never does), asking the user when they touch project choices.
3. Run the verification commands. No tests? Use build/typecheck/lint, then run the app and look at the touched parts, then a more careful review.
4. Review with the Review skill; check the diff has no secrets and no `.codex-*` files.
5. Good → commit on `codex/<task>` and merge **into its base branch**. Not good → fix it, or relaunch Codex with sharper instructions (up to the retries parameter, then Claude takes it).
6. `git worktree remove "<worktree>"` (the path in the `CODEX FINISHED` line or the registry); one line in `docs/codex-registro.md` (date, task, outcome, tokens); send "Review".

Before saying the work is finished, use the Final check skill.

## Step 7: Claude's quota and handoff

Claude can't see its own quota: the user says so, or limit warnings appear. Launch Codex tasks as soon as they're ready, never at the end: a launched task survives Claude stopping, an unlaunched one waits for the next session. Then: stop at a stable point and update "Status and handoff" in detail; move to Codex only open tasks that meet the Codex criteria (prompt and base branch for each); launch them as in Step 5 (or give the user the ready launch commands if you must stop now); send "Claude quota"; Claude reviews that work when back. When resuming after an interruption: do the start sequence, read the status, check worktrees and `codex/*` branches, review what was done meanwhile, then continue.

## Step 8: Codex quota used up

With an API key there's no reset: no resume; follow the spending cap. With a ChatGPT account, read `reference/resume.md` and follow it. In short: ask the user (if present) whether to give the tasks to Claude or auto-resume; otherwise auto-resume. Schedule resume and backup notice with `schedule-resume`, schedule Claude's check, update the plan, send "Codex quota".

## Step 9: at the end, improve Coduet

List unexpected situations, failed commands, workarounds and the user's corrections. For each, propose a fix written **in general form** (no project names, paths or PR numbers; project specifics go in its `CLAUDE.md`). Values and choices → `coduet:settings`; working rules → a ready-to-send issue for the plugin repository (`repository` in `plugin.json`), or a change in that repository if the user maintains it. If it's not the moment, note them in `docs/codex-registro.md` ("Coduet improvement proposals"). If an update was postponed, remind it in one line. Send "End".
