# Updates and the `claude` command

## When `coduet-update check` says `update=yes`

1. At most one notice per session (unless an even newer version appears). Fetch the `changelog=` URL and send the "Update" message: installed, new, how many versions skipped, highlights of all skipped versions.
2. AskUserQuestion: "Update now" / "Later". Work never stops either way. Never update without consent.
3. **Update now** → run `coduet-update apply` and act on `result=`:
   - `ok` and `after=` the new version → "Updated" message. Open a new thread/session to use it (in project threads slash commands like `/reload-plugins` don't run; elsewhere `/reload-plugins` works). Valid for all sessions on that PC.
   - `no-cli` → offer to install the `claude` command (below); if declined, the app route: Directory → Plugins → Code → `···` next to the marketplace → Check for updates → gear on Coduet → Update.
   - `error` → show the `manual=` command for the user to paste in a terminal, and that details are in the `log=` file.
   - Marketplace from a local folder (`claude plugin marketplace list` shows a path): `git pull` there.
4. **Later** → remind it in one line only at the end (Step 9).
5. Cloud sessions: don't update; only say a new version exists.

## The `claude` command on the PC

In-chat updating needs the Claude Code CLI. The desktop app doesn't install it but shares `~/.claude`, so a plugin updated from the CLI is updated in the app too (verified).

1. `cli=missing` and `~/.coduet/claude-cli.txt` doesn't say `don't ask`: AskUserQuestion "Install now (recommended)" / "Later" / "Don't ask again", explaining in one line it lets Coduet update from the chat instead of menus. "Don't ask again" writes `don't ask` in that file.
2. Install (only with consent), official command:
   - Windows (PowerShell): `irm https://claude.ai/install.ps1 | iex`
   - macOS/Linux: `curl -fsSL https://claude.ai/install.sh | bash`
3. If its folder isn't in PATH, add it (only if missing):
   - Windows: `$d = "$env:USERPROFILE\.local\bin"; $p = [Environment]::GetEnvironmentVariable("Path","User"); if (($p -split ';') -notcontains $d) { [Environment]::SetEnvironmentVariable("Path", "$p;$d", "User") }`
   - macOS/Linux: add `export PATH="$HOME/.local/bin:$PATH"` to the shell startup file if missing.
4. Verify: `coduet-update check` must show `cli=<path>` (the script also finds `~/.local/bin` before PATH is active).
5. Tell the user to close and reopen the Claude app (and open terminals) so every session sees the command.
6. On failure: explain briefly, link https://code.claude.com/docs/en/setup, go on.
