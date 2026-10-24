---
name: test
description: Use only when the user asks to test Coduet ("collauda Coduet", "test Coduet", "prova Coduet", "Coduet self-test"). Runs a short guided check on a throwaway repository: Codex launch, completion notice, a cheap asset, a simulated resume and the update check.
---

# Coduet: test

A guided check that Coduet works on this computer, in about 5 minutes and a few thousand Codex tokens. It never touches the user's projects. Reply in the user's language; prefix messages with `Coduet test ·`. Scripts are in the plugin folder, two levels above this skill (`scripts/windows/*.ps1` or `scripts/unix/*.sh`, see `coduet:start`).

Create a task list with the steps below and tick them off. For each step report ✓ or ✗ with the reason in one line; on ✗ continue with the next step when it doesn't depend on it.

1. **Where**: must be a session on the PC. In a cloud session stop and explain how to run it on the PC (open a Code session on the PC, or use a project with a local default folder).
2. **Tools**: `git --version`, `codex --version`, `codex login status`, and `coduet-update check` (reports `cli=` and versions). Report each.
3. **Sandbox repo**: create `coduet-test` in the system temp folder (Windows `$env:TEMP`, else `/tmp`), `git init`, one commit with a `README.md`. If it already exists from a previous test, ask before replacing it.
4. **Codex task**: prompt file: "Create hello.txt containing the single line: Coduet ok. Do not commit. At the end write a one-line summary." Launch `codex-run` with `--effort low` in the background and send the "Codex starts" message as in `coduet:start`. While it runs, run `codex-status` once and show the output.
5. **Completion**: when notified, check the line `CODEX FINISHED … status=done`, that `hello.txt` exists in the worktree, and report tokens. Send the "Codex done" message.
6. **Asset (cheap)**: ask Codex in the same way for `icon.svg`, a 64×64 SVG with a coloured circle, no image generation. Check the file is valid SVG.
7. **Resume (simulated)**: schedule with `schedule-resume` a resume of the task's session at now + 2 minutes and the backup notice at now + 4 minutes. Tell the user what will happen. After about 3 minutes (session wait tool, or ask the user to write "go"), read `.codex-ripresa.log` in the worktree: expect `AVVIO` and `COMPLETATO`. Then append the line `<now> CONTROLLO CLAUDE test` so the backup notice stays silent, and say so. To also see the notice window, the user can ask to skip that line.
8. **Clean up**: with the user's ok, remove the worktree, the `coduet-test` folder, the test task files in `~/.coduet/tasks/` and any leftover scheduled tasks (`Coduet-*`).
9. **Summary**: a table step → ✓/✗ → note, total Codex tokens, and for each ✗ the likely fix. Offer a ready-to-send issue text (general, no personal paths) for the plugin repository if something in Coduet itself failed.
