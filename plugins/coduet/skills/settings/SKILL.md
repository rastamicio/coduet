---
name: settings
description: Use when the user says "impostazioni di Coduet", "Coduet settings", "configura Coduet" or similar, wants to see or change Coduet's settings (phase skills, extra checks, parameters, plans), for the initial setup, or to save them for a project or personally.
---

# Coduet: settings

Only shows and changes the configuration used by `coduet:start`. **No working logic**: it starts no tasks, doesn't touch project code or running work, never edits plugin files or other skills. Reply in the user's language, in simple sentences.

## Three levels

The most specific wins:
1. **Defaults**: the "Configuration" section of `coduet:start` (plan profiles in its `reference/profiles.md`). Read only; they change with plugin updates.
2. **Personal**: the user's skill `coduet-config`. In the account → seen by PC and cloud sessions; only on the PC (`~/.claude/skills/coduet-config/SKILL.md`) → only that PC. Holds only values that differ from the defaults. Older copies may use Italian names: match them by meaning.
3. **Project**: `.coduet.md`, at the root or next to the plan (the `coordinamento` branch when work spans several branches). Only values the project changes.

## Modes

- **Full** (see or review the settings): all steps.
- **Quick** (a precise change, e.g. "set 3 Codex tasks"): show that item, current and new value, go to Step 6.
- **Plans** (set or change subscriptions, or called by `coduet:start`): Step 3b, then Step 6.
- **Claude's quota** ("Coduet should notice when Claude runs out"): Step 4b, then Step 6.
- **Initial setup** (no `coduet-config`, or called at first use): the single guided setup below.

## Initial setup (one pass, about 2 minutes)

Tell the user at the start what it covers, then:
1. **Plans**: Step 3b.
2. **Phase skills**: Step 3, with the obvious choice preselected for each phase so a confirmation is enough.
3. **`claude` command** (PC sessions): run `coduet-update check` from the plugin's `scripts` folder (`windows/coduet-update.ps1` or `unix/coduet-update.sh`); if `cli=missing`, offer to install it as in `coduet:start` → `reference/updates.md`. It enables updating Coduet from the chat.
4. **Codex**: `codex --version` and `codex login status`; if missing, give the install command for the system and say Coduet works without it until installed.
5. **Where to launch Coduet**: explain in 3 lines — Codex runs only in sessions on the PC (a Code session in the project folder, or a project whose threads use a local default folder: project settings → local environment → add the project folder and make it default); cloud sessions can plan and review but can't run Codex. Offer to help set the local folder.
6. **Claude's quota** (PC sessions, Claude Pro/Max): Step 4b.
7. Ask whether to see extra checks and parameters too (suggested: no, defaults).
8. Save to the personal configuration (Step 6). If nothing differs from the defaults, still write the file with the plans (so the setup isn't offered again).

## Step 1: read

Defaults, `coduet-config` if present (Skill tool or its `SKILL.md`), `.coduet.md` if in a project, and the list of installed skills with descriptions.

## Step 2: show

Short tables with the value in use for each item and which level it comes from: phase skills (mark the missing ones), extra checks, parameters.

## Step 3: phase skills

For each phase (Brainstorm, Plan, Claude's tasks, Codex isolation, Review, Final check):
1. Find installed skills suited to that phase from their name and description.
2. AskUserQuestion, multi-select: current skill (if installed) first, then up to 3 alternatives (the user can type another), then "None: base method". Group phases, up to 4 questions per call.
3. Several skills for one phase: ask the order and warn they use more quota.

## Step 3b: plans and profile

1. AskUserQuestion:
   - **Claude plan**: Pro, Max, Team or Enterprise, API/Console.
   - **Codex access**: ChatGPT Free, Go, Plus, Pro, Business/Enterprise/Edu, API key.
2. Take the matching profile and show only the values that would change (current, profile).
3. A profile value conflicting with a manual choice already in `coduet-config`: don't overwrite; ask which to keep.
4. API key: ask the spending cap per session (or "none"); remind that Codex is pay-per-use.
5. Claude Free: Claude Code isn't available, so Coduet can't run.

Changing subscription later: redo this step.

## Step 4: extra checks

Offer checks Coduet doesn't do by itself, with examples fitting the project (accessibility, performance, dependency security, copy and translations, mobile behaviour, asset licences, privacy) or the user's own. Ask the phase for each (usually Review or Final check). Allow removing existing ones.

## Step 4b: Claude's quota

Explain in two lines: in terminal sessions Coduet can read Claude's quota from the status line and lend tasks to Codex at the threshold; in the desktop app the status line doesn't run, so it acts only when the limit is hit. Then two multiple-choice questions (AskUserQuestion), one recommended option each:
1. **Status line**: "Turn on (recommended)" / "No". On → run `statusline-install install` from the plugin's `scripts` folder; show `backup=` and the `undo=` command; the user's previous status line keeps working (chained). `error=` → say so, change nothing. Check first with `statusline-install status`.
2. **Claude automatic return** (restart Claude by itself when its quota resets): "Turn on (recommended)" if `claude auth status` works, else "Only a notice (recommended)" and explain the one-time login (`coduet:start` → `reference/updates.md`). On → parameter `Claude automatic return` = `on`.

## Step 5: parameters

Show the parameter table with a one-line explanation each and ask which to change. Check values make sense and explain risky ones: more concurrent Codex tasks burn quota faster (sensible: 1-4); switching off the Claude check leaves only the backup notice; 0 automatic regenerations sends every faulty asset to the user; a Claude quota threshold above 90% may leave no room to hand tasks over (sensible: 70-85); Worktree folder `inside` keeps the projects folder tidy and reuses dependencies, but the project's test runners must skip `.codex-worktrees/` (coduet:start proposes the change before the first task).

## Step 6: save

Show the changes (old, new) and ask with AskUserQuestion:
- **Save for this project**: write or update `.coduet.md` with only the changed items, where all project sessions see it, and push it. Running sessions apply it from their next phase.
- **Save in my personal configuration**: write the full updated `coduet-config` with the template below. Valid from the next sessions in all projects (except items a project overrides). For a running session, give the user a prompt to reload `coduet:start`. Where:
  - **In the account**, if the session has a tool to propose or save skills: use it (valid everywhere).
  - **Only on the PC** otherwise: write `~/.claude/skills/coduet-config/SKILL.md` and **say so clearly**: only sessions on this PC see it; cloud sessions and other computers use the defaults. If it differs from the defaults and the user also works in the cloud, explain they can add the same skill to their account from the app settings (skills section) and must keep both copies aligned.
  - Two copies: update the one in use and remind to align the other.
- **Cancel**: change nothing.

"For this project" outside a project: say so and offer the other two.

### `coduet-config` template

```markdown
---
name: coduet-config
description: Personal configuration of the Coduet plugin. Not used on its own: coduet:start and coduet:settings read it.
---

# Coduet personal configuration

Last update: <date>. Only items that differ from the plugin defaults.

## Phase skills

| Phase | Skill (in order) |
|---|---|
| <phase> | <skill> |

## Extra checks

| Phase | Check |
|---|---|
| <phase> | <check> |

## Parameters

| Parameter | Value |
|---|---|
| <parameter> | <value> |
```

Drop empty sections. An item that goes back to its default is removed. Write the content in the user's language if they prefer; parameter names may stay in English.

## Rules

- Change nothing without the explicit choice of Step 6.
- Requests to change how Coduet works (not just values) are plugin changes: offer a ready-to-send issue for the plugin repository (`repository` in `plugin.json`).
- Don't touch running work: just say when changes take effect.
