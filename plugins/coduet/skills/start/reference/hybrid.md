# Hybrid mode (cloud session + PC)

Verified: a cloud session can **start** a PC session and instruct it only at launch; afterwards it can't message it, and that session may not appear in the user's list. So:

- **Never ask the user to relay** (paste tasks, answer permissions, look for the PC session). Their only action is approving the PC session's start.
- **All communication goes through the remote**: the plan (Codex tasks with full prompts) and the `codex/*` branches.

## Where the plan lives

- One branch (or `main`): the plan is there.
- Work across several branches/PRs: not in one feature branch. Use a dedicated `coordinamento` branch with only the plan and logs; sessions read it with `git fetch` + `git show origin/coordinamento:<plan path>` and commit updates there.
- `docs/codex-registro.md` and `.coduet.md` sit next to the plan.

## Flow

1. The cloud session writes all ready `Executor: Codex` tasks (prompt, base branch) into the plan and pushes it, plus its own saved work.
2. Check Coduet is installed on the PC too. Start **one** PC session in the "PC copy" with this self-contained prompt:
   "Use the coduet:start skill in the PC Executor role, with the project configuration if present. Repository <url>, local copy <path>. The plan is <plan path> on branch <plan branch>. Run all tasks with Executor: Codex and status open, then stop. Project verification commands: <commands>."
3. Send: `Coduet · ▶ Started a PC session that runs <n> Codex tasks. I'll check the remote every few minutes and review them as they arrive.`
4. Keep working; `git fetch` periodically for `codex/*` branches and plan status; review ready tasks (Step 6), sending "Codex done"/"Review" as they arrive.
5. More Codex tasks: add them to the plan and start a new PC session the same way.
- If the cloud session can run commands on the PC directly (short timeouts), run `codex-run` detached and poll `codex-status` instead.
- Give Codex files different from those Claude is editing.
- Resume and the shared registry run on the PC: the PC session handles them.

## If several PRs are merged into one

Ask first; record in the plan which PRs merge into which branch and why; close the absorbed PRs with a link to the new one; update the base branch of all open or queued Codex tasks and rebase existing `codex/*` branches onto it before review; update status and log.

## PC Executor role

When started as "PC Executor":
0. **Cleanup**: remove worktrees the plan marks for removal. Close leftovers of a previous Executor (task "running" with no outcome, worktree or `codex/*` branch without commit/push, `codex-status` entries with no live process): commit and push valid work, otherwise set the task back to "open"; write in the plan what you found and did.
1. Copy check (`reference/local-copy.md`) and Step 1.
2. Read the plan from its branch. For each open Codex task, in order, run Step 5 (and assets loop) from the task's base branch.
3. When Codex finishes: run the verification commands, fix small errors, commit on `codex/<task>` (put Codex's summary and tokens in the commit message, since work files aren't pushed) and push. Don't merge: the plan's author does, after review.
4. Update the task status in the plan (ready for review, blocked and why, waiting for quota) and push.
5. A task needing a user decision: mark it blocked, go to the next; summarise at the end.
6. Write Step 9 proposals in the plan, then stop.
