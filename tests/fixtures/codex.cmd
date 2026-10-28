@rem Arguments go through an environment variable: powershell -File would read a lone "-" as a parameter name.
@set "FAKE_CODEX_ARGS=%*"
@powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fake-codex.ps1"
