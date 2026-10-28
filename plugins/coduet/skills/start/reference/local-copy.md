# Local copy on the PC

## Check the copy (always, before starting)

Run `check-copy "<folder>"` and act on its lines:

| Line | Action |
|---|---|
| `git=no` | See "No git" below |
| `remote=` another repository | Don't touch the folder; ask for another one |
| `uncommitted=N>0` | Ask: commit, stash or discard. Never discard without an explicit ok. If almost every file shows as changed with no real diff, it's line endings: explain and set `git config core.autocrlf true` for that copy only |
| `branch=` not the working one | Switch only if nothing is pending |
| `behind>0`, `ahead=0` | `git pull` |
| `ahead>0`, `behind=0` | `git push` after telling the user |
| both > 0 | `git pull --rebase`; you resolve conflicts, ask on project choices |
| `worktrees>0` or `codex_branches>0` | Leftovers: handle with `reference/resume.md` § Check or Step 6 before creating new ones |
| `deps=missing` | Install as the README says |
| `secret_file=X:missing` | Tell the user which file to create from which example; wait for them |
| `work_files_excluded=no` | `codex-run` adds the excludes on first launch |
| `worktree_exclusion=missing:<files>` | Worktree folder `inside` only: see the parameter note in `SKILL.md` |

Then run the project's verification commands. If they already fail, say so: it's not the new work's fault.

## Find an existing copy (before downloading)

1. If the plan's "PC copy" exists, use it.
2. Otherwise ask whether the project is already on the PC and where; you can also look for a repository with the same remote in folders you can access.
3. Several copies: show path, branch, last commit date, uncommitted changes; the user picks. Don't touch the others (suggest the user archives them).
4. Write the chosen copy in the plan ("PC copy").

## Download the project (situation B)

1. Ask the folder if not given: never system folders, never a folder that already has other content. Avoid synced folders (OneDrive, synced Desktop/Documents) and, for new folders, names with spaces or apostrophes.
2. If the cloud has unpushed work, push it first.
3. `git --version` (guide installation if missing), then `git clone <url> "<folder>"`. A private repository may open the browser for login the first time: warn the user.
4. Install dependencies per the README, run the copy check, write "PC copy" in the plan.

## Propose working locally (situation C)

Working in a PC session is simpler than hybrid. Once per project, propose: set a **local default folder** for the project (project settings, local environment: add the project copy and make it default) so its threads run on the PC; or open a Code session on the PC in that folder. Menu names change between versions: describe the purpose, not only the path.

## Remote, no git

- Git with remote: normal case.
- Git without remote: only A and B work, no hybrid; suggest adding a remote to work from the cloud too.
- No git: propose `git init` and a first commit (only with ok), explaining it isolates Codex's work and allows going back. If refused: back up the folder, give each Codex task a copy at the Worktree folder path (`../<project>-codex-<task>`, or `<project>/.codex-worktrees/<task>` with `inside`: then don't copy `.codex-worktrees` itself nor dependency folders, which are found from the parent), run Codex there with `--skip-git-repo-check`, compare folders at the end leaving out `.codex-*` and bring over approved changes yourself. No hybrid, no worktrees.

## Secrets and local config

Recognise them: `.env.example`, `*.example`, `*.sample`, files in `.gitignore`, README notes, missing-variable errors. Secrets never go through chat, plan, Codex prompts or git. Tasks needing secrets go to Claude where they exist. Before each commit check no secret file is included.

## Work files

`.codex-prompt.md`, `.codex-esito.md`, `.codex-output*.txt`, `.codex-ripresa.log` stay out of commits through `.git/info/exclude` (local only; `codex-run` adds it).

## Platform notes

- Windows: Codex installs natively (sandbox "elevated"). Always quote paths; in single-quoted PowerShell strings double apostrophes (`'C:\Anna''s Files'`). Sessions stay saved: `codex resume <id>` by hand.
- macOS/Linux: install with `curl -fsSL https://chatgpt.com/codex/install.sh | sh`, then `codex login`. Quote paths.
- Never run Codex in system folders.
