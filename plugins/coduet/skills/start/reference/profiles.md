# Plan profiles

Defaults equal Claude Pro + ChatGPT Plus ("not set"). `coduet:settings` saves a profile's values in the personal configuration; the user can tweak them.

**Codex access** (only these parameters change):

| Parameter | ChatGPT Free / Go | Plus, Business (default) | Pro | API key |
|---|---|---|---|---|
| Concurrent Codex tasks | 1 | 2 | 3 | 2 |
| Codex reasoning | low | medium | medium | medium |
| Small-job threshold | 6 | 4 | 3 | 4 |
| Trial assets per type | 1-2 | 2-3 | 3 | 2 |
| Automatic regenerations | 1 | 2 | 3 | 1 |
| Image generation with Codex | no | yes | yes | yes |
| Spending cap per session | none | none | none | ask the user |

Enterprise, Edu and others: Plus profile unless the user says otherwise.

**Claude plan:**

| Claude plan | Delegation rule |
|---|---|
| Pro (default) | save Claude's quota |
| Max, Team, Enterprise, API/Console | only where Codex pays off |

Claude Free has no Claude Code: Coduet can't run.

**Effects:**
- *Save Claude's quota*: Step 3 criteria as written.
- *Only where Codex pays off*: give Codex only assets and high-volume mechanical tasks; the rest to Claude.
- *Image generation = no*: never ask Codex for images; propose vector or code graphics, library assets, or user-provided images.
- *API key*: pay per use, no quota reset, no Step 8 resume. Sum the tokens Codex prints per task; before passing the cap, stop and ask.
- *Free/Go*: small quota; give Codex only small tasks and expect the resume to trigger often.
