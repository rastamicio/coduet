# Quote e passaggi tra Claude e Codex: piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Coduet 0.6.0 legge la quota di Codex in modo esatto, si accorge della quota di Claude (soglia nel terminale, limite nell'app desktop), presta a Codex i task di Claude pronti e fa ripartire Claude da solo al reset.

**Architecture:** Tutta la logica sta in script (`scripts/windows/*.ps1`, `scripts/unix/*.sh`, stessi nomi, uscita `key=value`) e in due hook del plugin che escono subito se il progetto non usa Coduet. Le skill aggiungono solo poche righe nel nucleo e i dettagli in `reference/`. Le nuove funzioni (barra di stato, ritorno automatico) si attivano solo da `coduet:settings`.

**Tech Stack:** PowerShell 5.1+, bash, hook di Claude Code (`hooks/hooks.json`), `codex app-server` (JSON-RPC su stdio), Task Scheduler / at / systemd / launchd.

**Spec:** `docs/superpowers/specs/2026-10-28-quote-e-passaggi-design.md`

## Global Constraints

- Testo delle skill in inglese; README, `docs/guida.md`, CHANGELOG in italiano. Mai nomi di progetti personali, percorsi o casi dell'utente nel plugin.
- Nucleo `skills/start/SKILL.md` snello: ogni dettaglio nuovo va in `reference/`; nel nucleo solo rimandi di una riga.
- Script: stessi nomi su Windows e Unix, uscita solo righe `key=value` (o la riga `CODEX …` già esistente), helper in `common`. Rispettano `CODUET_HOME`.
- Niente si cancella o sovrascrive senza ok esplicito; `~/.claude/settings.json` si modifica solo con backup e comando per tornare indietro.
- Segreti mai in chat, prompt, piano, git, log.
- Nessun cambiamento di comportamento per chi non attiva le nuove funzioni e per i piani senza le nuove righe (`Codex-ready`, `Status`).
- Gli hook agiscono solo se c'è un piano Coduet (sezione `## Status and handoff`) e mai nelle sessioni cloud; altrimenti escono con codice 0 senza stampare nulla.
- Parametro nuovo: "Claude quota threshold for handoff (%)", default 80.
- `codex-limits`: timeout 20 s; Windows con pipe di cmd (`(type in.jsonl & ping -n <s> 127.0.0.1 >nul) | codex app-server --listen stdio:// > out.jsonl`), lettura ogni 200 ms, `taskkill /T /F` alla fine.
- Sessione `claude -p` di ritorno: niente merge su `main`, niente push forzati, niente cancellazioni.
- Versione 0.6.0 in `plugin.json`, voce nel CHANGELOG.

## Review Focus

- Piano scritto con versioni precedenti (nessuna riga `Codex-ready`/`Status`): gli hook non prestano nulla e non modificano il file. Test in Task 3 (`plan-lendable` su piano vecchio → nessuna riga).
- Due `StopFailure` di fila nella stessa finestra di quota: nessun task lanciato due volte. Test in Task 6.
- Barra di stato precedente dell'utente con virgolette e spazi nel comando: la sua uscita deve restare identica. Test in Task 4.
- File `claude-quota.json` scritto a metà o JSON non valido: lo script di controllo non stampa nulla e non va in errore. Test in Task 5.
- `codex app-server` che non risponde o una versione di Codex senza app-server: nessun processo resta aperto e `codex-run` si comporta come oggi. Test in Task 1 e Task 2.

---

### Task 0: Verifiche sul PC (prima di tutto il resto)

Nessun codice del plugin. Si esegue sul PC di Windows (sessione sul PC o Remote Control), in una cartella temporanea, e si annota l'esito in fondo a questo piano (§ Esiti delle verifiche). Se una verifica fallisce, fermarsi e tornare dall'utente prima dei task che ne dipendono.

- [ ] **Step 1: Come girano i comandi degli hook su Windows.** In un progetto di prova con `.claude/settings.local.json` aggiungere un hook `UserPromptSubmit` di tipo command `bash -c "echo bash-ok >> \"$TEMP/coduet-hook.txt\""` e uno `powershell -NoProfile -Command "Add-Content $env:TEMP\coduet-hook.txt ps-ok"`. Mandare un messaggio da una sessione dell'app desktop e da `claude` nel terminale. Atteso: si sa quale delle due forme gira in ciascun ambiente. Decide la forma del comando in `hooks/hooks.json` (Task 5).
- [ ] **Step 2: `StopFailure` nell'app desktop.** Nello stesso progetto, hook `StopFailure` con matcher `rate_limit` che scrive lo stdin in un file. Non si può forzare il limite: verificare almeno che un `StopFailure` con un altro errore (per esempio un modello inesistente con `--model nonexistent` nel terminale) scriva il file, e cercare nella documentazione dell'app se gli hook dei plugin girano nelle sessioni dell'app. Atteso: hook eseguito e campi `error_type`, `cwd` presenti.
- [ ] **Step 3: Timeout della domanda.** In una sessione del terminale e dell'app: Claude lancia `sleep 60` (o `Start-Sleep 60`) in background e pone una domanda a scelta multipla. Atteso: si sa se la fine del comando risveglia Claude mentre la domanda è aperta. Decide il testo dello Step 7 (Task 8).
- [ ] **Step 4: `claude -p` dal pianificatore.** Dopo il login di `claude`, un'attività di Task Scheduler una tantum avvia, in un repository di prova, `claude -p "Write OK in ok.txt" --permission-mode acceptEdits --allowedTools "Write" < NUL`. Atteso: `ok.txt` creato, nessuna finestra in attesa. Decide il comando di `schedule-claude-return` (Task 7).
- [ ] **Step 5: Annotare gli esiti** in § Esiti delle verifiche e fare commit del piano.

### Task 1: Script `codex-limits` e base dei test

**Files:**
- Create: `tests/unix/lib.sh`, `tests/run.sh`, `tests/windows/lib.ps1`, `tests/run.ps1` (i test stanno fuori dal plugin, così non vengono installati)
- Create: `tests/fixtures/codex` (bash) e `tests/fixtures/codex.cmd` + `tests/fixtures/fake-codex.ps1`: finto Codex. `app-server` legge righe JSON da stdin e risponde secondo `FAKE_CODEX_MODE`: `ok` (risponde a `initialize` e a `account/rateLimits/read` con primary 30% e secondary 10%, `resetsAt` fissi), `reached` (primary 100, `rateLimitReachedType` = `primary`), `silent` (non risponde mai), `noserver` (esce con codice 2 e "unknown command"). `exec` stampa un output come quello reale e scrive `session id: fake-1`.
- Create: `plugins/coduet/scripts/unix/codex-limits.sh`, `plugins/coduet/scripts/windows/codex-limits.ps1`
- Modify: `plugins/coduet/scripts/unix/common.sh`, `plugins/coduet/scripts/windows/common.ps1`
- Test: `tests/unix/codex-limits.test.sh`, `tests/windows/codex-limits.Tests.ps1`

**Interfaces:**
- Produces: `codex-limits [--timeout <s>]` / `codex-limits.ps1 [-TimeoutSec <s>]` → righe `ok=1|0`, `primary_used=`, `primary_resets_at=`, `primary_window_mins=`, `secondary_used=`, `secondary_resets_at=`, `secondary_window_mins=`, `plan=`, `reached=`, e `error=<testo>` solo se `ok=0`. Codice di uscita sempre 0.
- Produces in `common`: `codex_available` (bash: legge l'uscita di `codex-limits` da stdin, ritorna 0 se `ok=1`, `reached` vuoto e entrambe le percentuali < 100; 1 se esaurita; 2 se `ok=0`) e `Codex-Available([string[]]$lines)` (PowerShell: `'yes'|'no'|'unknown'`). Anche `codex_reset_at` / `Codex-ResetAt`: `resets_at` della finestra esaurita (secondary se entrambe), vuoto se nessuna.
- Test helpers: `assert_eq <atteso> <reale> <nome>`, `assert_contains <testo> <ago> <nome>`; `Assert-Eq`, `Assert-Contains` in PowerShell. `run.sh`/`run.ps1` eseguono tutti i file di test e stampano `PASS n` / `FAIL n` con codice di uscita ≠ 0 se qualcosa fallisce.

- [ ] **Step 1: Scrivere i test** in `tests/unix/codex-limits.test.sh` (PATH con `tests/fixtures` davanti):
  - `ok`: `ok=1`, `primary_used=30`, `secondary_used=10`, `primary_window_mins=300`; `codex_available` → 0.
  - `reached`: `reached=primary`; `codex_available` → 1; `codex_reset_at` = `resetsAt` della primary.
  - `silent` con `--timeout 2`: `ok=0`, `error=timeout`, finisce in meno di 5 s, nessun processo `fake`/`codex` rimasto (`pgrep -f fixtures/codex` vuoto).
  - `noserver`: `ok=0`, `codex_available` → 2.
  - Stessi quattro casi in `tests/windows/codex-limits.Tests.ps1` (processi rimasti: `Get-CimInstance Win32_Process` filtrato su `fake-codex`).
- [ ] **Step 2: Eseguire** `bash tests/run.sh`. Atteso: FAIL (script mancante).
- [ ] **Step 3: Implementare `codex-limits.sh`**: messaggi del protocollo come nella spec (`clientInfo.name` = `coduet`, `version` = versione da `plugin.json`), coprocesso o FIFO con stdin tenuto aperto, lettura della riga con `"id":2`, parsing con `sed` (niente `jq`), kill del gruppo di processi alla fine.
- [ ] **Step 4: Implementare `codex-limits.ps1`** con la pipe di cmd descritta nella spec (§ "Cosa sappiamo"): file `in.jsonl` in ASCII senza BOM, `Start-Process $env:ComSpec` nascosto, attesa della riga con `"id":2` in `out.jsonl`, `taskkill /T /F` e cancellazione della cartella temporanea nel `finally`.
- [ ] **Step 5: Eseguire** `bash tests/run.sh` (cloud) e `powershell -NoProfile -ExecutionPolicy Bypass -File tests/run.ps1` (PC). Atteso: PASS.
- [ ] **Step 6: Prova reale sul PC**: `codex-limits.ps1` con il vero Codex → `ok=1` e percentuali plausibili.
- [ ] **Step 7: Commit** `codex-limits: read Codex quota from codex app-server`.

### Task 2: Controllo della quota prima del lancio

**Files:**
- Modify: `plugins/coduet/scripts/unix/codex-run.sh`, `plugins/coduet/scripts/windows/codex-run.ps1`
- Test: `tests/unix/codex-run-quota.test.sh`, `tests/windows/codex-run-quota.Tests.ps1`

**Interfaces:**
- Consumes: `codex-limits`, `codex_available`, `codex_reset_at` (Task 1).
- Produces: nuova riga di uscita di `codex-run` `CODEX WAITING task=<t> reason=quota resets_at=<unix>` (codice di uscita 4), nessun worktree creato. Con `codex_available` = 2 (sconosciuto) lancia come oggi.

- [ ] **Step 1: Test** in un repository git temporaneo: `FAKE_CODEX_MODE=reached` → uscita contiene `CODEX WAITING`, `reason=quota`, nessun worktree (`git worktree list` con una sola voce), codice 4. `FAKE_CODEX_MODE=noserver` → parte come oggi (riga finale `CODEX FINISHED`). `FAKE_CODEX_MODE=ok` → `CODEX FINISHED … status=done`.
- [ ] **Step 2: Eseguire i test**. Atteso: FAIL sul primo caso.
- [ ] **Step 3: Implementare** il controllo dopo quello dei task contemporanei e prima della creazione del worktree.
- [ ] **Step 4: Eseguire i test** su Linux e sul PC. Atteso: PASS.
- [ ] **Step 5: Commit** `codex-run: wait instead of launching when Codex has no quota`.

### Task 3: Piano: task prestabili e prompt di passaggio

**Files:**
- Modify: `plugins/coduet/scripts/unix/common.sh`, `plugins/coduet/scripts/windows/common.ps1`
- Create: `plugins/coduet/scripts/unix/handoff-prompt.sh`, `plugins/coduet/scripts/windows/handoff-prompt.ps1`
- Create: `tests/fixtures/plan-new.md` (piano con `## Status and handoff`, PC copy, tre task: Claude/Codex-ready yes/Status open; Claude/Codex-ready no/Status open; Claude/Codex-ready yes/Status done; sezione "Verification commands"), `tests/fixtures/plan-old.md` (stesso piano senza righe `Codex-ready` e `Status`)
- Test: `tests/unix/plan.test.sh`, `tests/windows/plan.Tests.ps1`

**Interfaces:**
- Formato nel piano (scritto dallo Step 3 della skill): titolo `### Task <N>: <titolo>`, righe `**Executor:** Claude|Codex`, `**Codex-ready:** yes|no`, `**Status:** open|queued|running|lent to Codex|ready for review|blocked|merged|done`, `**Base branch:** <branch>`.
- Produces in `common`: `find_coduet_plan <dir>` / `Find-CoduetPlan $dir` → percorso del piano (file `.md` nella radice git o in `docs/` fino a 3 livelli, escluse `.codex-worktrees` e `node_modules`, che contiene `## Status and handoff` e una riga `PC copy:`), vuoto se nessuno. `plan_lendable <plan>` / `Plan-Lendable $plan` → una riga `<N>|<titolo>|<base branch>` per ogni task con Executor Claude, Codex-ready yes, Status open. `plan_set_status <plan> <N> <status>` / `Plan-SetStatus` → cambia solo la riga `**Status:**` di quel task.
- Produces: `handoff-prompt <plan> <N> <file di uscita>` → scrive il prompt e stampa `prompt=<file>`. Contenuto: "Implement Task <N> (<titolo>) of the plan <percorso relativo>, following its steps and the decisions recorded in the plan and its spec.", le regole standard dello Step 3 della skill (copiate parola per parola), e i comandi della sezione "Verification commands" del piano se c'è.

- [ ] **Step 1: Test**: `find_coduet_plan` trova `plan-new.md` copiato in un repo temporaneo sotto `docs/plans/`, vuoto per un repo senza piano; `plan_lendable plan-new.md` → esattamente una riga che inizia con `1|`; `plan_lendable plan-old.md` → nessuna riga; `plan_set_status plan-new.md 1 "lent to Codex"` → solo la riga Status del Task 1 cambia (`diff` di una riga); `handoff-prompt` contiene "Implement Task 1", "Do not commit." e il comando di verifica della fixture.
- [ ] **Step 2: Eseguire i test**. Atteso: FAIL.
- [ ] **Step 3: Implementare** helper e `handoff-prompt` (parsing per sezioni `### Task`, niente dipendenze esterne).
- [ ] **Step 4: Eseguire i test** su Linux e sul PC. Atteso: PASS.
- [ ] **Step 5: Commit** `plan helpers and handoff-prompt for lending Claude's tasks to Codex`.

### Task 4: Barra di stato che salva la quota di Claude

**Files:**
- Create: `plugins/coduet/scripts/unix/claude-statusline.sh`, `plugins/coduet/scripts/windows/claude-statusline.ps1`
- Create: `plugins/coduet/scripts/unix/statusline-install.sh`, `plugins/coduet/scripts/windows/statusline-install.ps1`
- Test: `tests/unix/statusline.test.sh`, `tests/windows/statusline.Tests.ps1`

**Interfaces:**
- Produces: `claude-statusline` (stdin = JSON della barra di stato): se c'è `rate_limits`, scrive in modo atomico `$CODUET_HOME/claude-quota.json` = `{"read":"<ISO UTC>","rate_limits":<oggetto originale>}`; poi, se `$CODUET_HOME/statusline-prev.txt` esiste, esegue quel comando con lo stesso stdin e ne stampa l'uscita invariata; altrimenti stampa `Claude 5h <n>% · week <m>%` (o niente se mancano).
- Produces: `statusline-install install|uninstall|status` → righe `statusline=coduet|other|none`, `backup=<file>`, `undo=<comando>`. `install`: backup di `~/.claude/settings.json` in `$CODUET_HOME/settings.backup-<data>.json`, salva il comando precedente in `statusline-prev.txt`, imposta `statusLine` sullo script di Coduet, verifica che il JSON resti valido. `uninstall`: rimette il comando precedente (o toglie la chiave). Su Unix la modifica del JSON si fa con `python3` se c'è, altrimenti con `node`, altrimenti `error=no-json-tool` senza toccare il file.

- [ ] **Step 1: Test**: stdin con `rate_limits` → file scritto con `five_hour` e `read`; stdin senza → file non toccato; con `statusline-prev.txt` = un comando con spazi e virgolette (`printf '%s' "prev \"ok\""`) l'uscita è esattamente `prev "ok"`; `install` su un `settings.json` di prova (con `HOME` temporanea) con una `statusLine` esistente → backup creato, `statusline-prev.txt` = vecchio comando, JSON valido, altre chiavi intatte; `uninstall` → file uguale all'originale (a parte la formattazione).
- [ ] **Step 2: Eseguire i test**. Atteso: FAIL.
- [ ] **Step 3: Implementare** i due script per piattaforma.
- [ ] **Step 4: Eseguire i test** su Linux e sul PC. Atteso: PASS.
- [ ] **Step 5: Commit** `claude-statusline: save Claude's quota and chain the user's status line`.

### Task 5: Hook di controllo della soglia

**Files:**
- Create: `plugins/coduet/hooks/hooks.json`, `plugins/coduet/scripts/unix/claude-quota-check.sh`, `plugins/coduet/scripts/windows/claude-quota-check.ps1`, `plugins/coduet/scripts/hook.sh` (smistamento: su Windows chiama lo script `.ps1`, altrove lo `.sh`; la forma esatta del comando dipende dal Task 0, Step 1)
- Test: `tests/unix/quota-check.test.sh`, `tests/windows/quota-check.Tests.ps1`

**Interfaces:**
- Consumes: `find_coduet_plan` (Task 3), `claude-quota.json` (Task 4).
- Produces: `hooks.json` con `UserPromptSubmit` → `claude-quota-check` e `StopFailure` (matcher `rate_limit`) → `claude-limit-hit` (Task 6). `claude-quota-check` legge lo stdin dell'hook (`cwd`), la soglia da `.coduet.md` o dalla configurazione personale (riga `Claude quota threshold for handoff (%)`, default 80), e stampa al massimo la riga: `Coduet: Claude quota at <n>% (resets <HH:MM>). Apply coduet:start Step 7 (handoff).` Registra l'avviso in `$CODUET_HOME/claude-quota-warned.txt` (`<resets_at>`), una volta per finestra.

- [ ] **Step 1: Test**: nessun piano → nessuna uscita; file quota mancante, più vecchio di 10 minuti, o JSON troncato → nessuna uscita e codice 0; 79% → nessuna uscita; 80% → la riga; seconda chiamata con stesso `resets_at` → nessuna uscita; `seven_day` 85% e `five_hour` 20% → la riga con 85%; soglia 90 in `.coduet.md` e 85% → nessuna uscita.
- [ ] **Step 2: Eseguire i test**. Atteso: FAIL.
- [ ] **Step 3: Implementare** script e `hooks.json` (con `${CLAUDE_PLUGIN_ROOT}`).
- [ ] **Step 4: Eseguire i test** su Linux e sul PC; poi sul PC verificare con `claude` nel terminale che un messaggio in un progetto senza piano non mostri nulla. Atteso: PASS.
- [ ] **Step 5: Commit** `hooks: warn Claude once when its quota passes the handoff threshold`.

### Task 6: Hook al limite: presta i task a Codex

**Files:**
- Create: `plugins/coduet/scripts/unix/claude-limit-hit.sh`, `plugins/coduet/scripts/windows/claude-limit-hit.ps1`
- Test: `tests/unix/limit-hit.test.sh`, `tests/windows/limit-hit.Tests.ps1`

**Interfaces:**
- Consumes: `find_coduet_plan`, `plan_lendable`, `plan_set_status`, `handoff-prompt` (Task 3), `codex-limits`/`codex_available` (Task 1), `codex-run` (Task 2), `schedule-claude-return` (Task 7; se lo script non c'è o il ritorno automatico non è attivo, solo notifica).
- Produces: stdin = JSON di `StopFailure`. Se `error_type` ≠ `rate_limit`, nessun piano, o `codex` non installato → esce. Registro `$CODUET_HOME/claude-limit-<progetto>.txt` con `window=<resets_at o data+ora arrotondata all'ora>`: stessa finestra → esce. Con Codex disponibile: per ogni riga di `plan_lendable`, `handoff-prompt` e `codex-run` in background (parametri del piano/configurazione: effort, max, cartella dei worktree), `plan_set_status … "lent to Codex"` per quelli partiti, aggiunge in "Status and handoff" la riga `- Lent to Codex at <ora>: <elenco>`. Poi pianifica il ritorno (Task 7) e mostra una notifica (stessa tecnica di `codex-warning`). Uscita su `$CODUET_HOME/claude-limit-<progetto>.log`.

- [ ] **Step 1: Test** (repo temporaneo con `plan-new.md`, `FAKE_CODEX_MODE`, notifica sostituita da `CODUET_NOTIFY=echo`): `error_type=overloaded` → nulla; `ok` → Task 1 diventa `lent to Codex`, `codex-run` invocato una volta (marker del finto Codex), riga aggiunta in "Status and handoff"; seconda chiamata identica → nessun nuovo lancio; `reached` → nessun lancio, Status invariato, notifica con orario; piano vecchio → nessuna modifica al file (`sha256sum` uguale).
- [ ] **Step 2: Eseguire i test**. Atteso: FAIL.
- [ ] **Step 3: Implementare**.
- [ ] **Step 4: Eseguire i test** su Linux e sul PC. Atteso: PASS.
- [ ] **Step 5: Commit** `claude-limit-hit: lend ready tasks to Codex when Claude hits its limit`.

### Task 7: Ritorno automatico di Claude

**Files:**
- Create: `plugins/coduet/scripts/unix/schedule-claude-return.sh`, `plugins/coduet/scripts/windows/schedule-claude-return.ps1`
- Test: `tests/unix/claude-return.test.sh`, `tests/windows/claude-return.Tests.ps1`

**Interfaces:**
- Consumes: `find_claude` (common), `claude-quota.json`.
- Produces: `schedule-claude-return <progetto> [--at "YYYY-MM-DD HH:MM"] [--dry-run]` → `scheduled=claude-return via=<…> when=<…>` oppure `error=no-claude|not-logged-in|no-scheduler`. Orario: `--at`, altrimenti `five_hour.resets_at` di `claude-quota.json` se letto nelle ultime 5 ore, altrimenti ora + parametro "Quota reset estimate if unknown (hours)"; più il margine "Resume margin after reset (minutes)". Comando pianificato: nella cartella del progetto, `claude -p "Use the coduet:start skill: resume after Claude's quota reset." --permission-mode acceptEdits --allowedTools <elenco>` con stdin chiuso e uscita in `$CODUET_HOME/claude-return-<progetto>.log` (forma esatta dal Task 0, Step 4). Windows: attività `Coduet-ClaudeReturn-<progetto>` con le stesse opzioni di `schedule-resume.ps1` e cancellazione automatica. Una sola attività per progetto (la nuova sostituisce la vecchia).
- `--allowedTools`: `Bash(powershell*)`, `Bash(bash*)` limitati agli script di Coduet tramite percorso, `Bash(git status*)`, `Bash(git diff*)`, `Bash(git log*)`, `Bash(git add*)`, `Bash(git commit*)`, `Bash(git merge*)`, `Bash(git worktree*)`, `Bash(git fetch*)`, `Bash(git push)` (senza `--force`), più i comandi di verifica del piano; `Read`, `Edit`, `Write`, `Grep`, `Glob`.

- [ ] **Step 1: Test** con `--dry-run` (stampa il comando invece di pianificarlo): orario da `claude-quota.json` recente = `resets_at` + margine; file vecchio → ora + stima; `claude` assente (PATH vuoto) → `error=no-claude`; il comando contiene `--permission-mode acceptEdits` e non contiene `--force` né `--dangerously`.
- [ ] **Step 2: Eseguire i test**. Atteso: FAIL.
- [ ] **Step 3: Implementare** (riusare `schedule_one` di `schedule-resume.sh` spostandolo in `common.sh`; su Windows la parte Task Scheduler di `schedule-resume.ps1` in una funzione di `common.ps1`).
- [ ] **Step 4: Eseguire i test** su Linux e sul PC; sul PC una pianificazione reale a +2 minuti in un repository di prova con un piano senza task aperti. Atteso: PASS, log scritto, attività sparita.
- [ ] **Step 5: Commit** `schedule-claude-return: restart Claude when its quota resets`.

### Task 8: Skill e riferimenti

**Files:**
- Modify: `plugins/coduet/skills/start/SKILL.md`, `plugins/coduet/skills/start/reference/resume.md`, `plugins/coduet/skills/start/reference/updates.md`, `plugins/coduet/skills/settings/SKILL.md`, `plugins/coduet/skills/test/SKILL.md`
- Create: `plugins/coduet/skills/start/reference/handoff.md`

**Interfaces:**
- Consumes: tutti gli script dei Task 1-7 con i nomi e le uscite definiti sopra.

- [ ] **Step 1: `start/SKILL.md`** (aggiunte brevi, il file non deve crescere più di ~1,5 KB): parametro nuovo nella tabella; Step 3 punto 2: ogni task Claude riceve `Codex-ready` (no per sicurezza, segreti e configurazioni locali, migrazioni) e ogni task `Status`; Step 5: `CODEX WAITING` → task "waiting for quota", vai allo Step 8; Step 7 sostituito da tre righe che rimandano a `reference/handoff.md` (avviso alla soglia, hook al limite, ritorno); Step 8: orario da `codex-limits`; Start sequence punto 5: "Claude's return" in `reference/resume.md`; messaggio "Claude quota" aggiornato con i task prestati e l'orario di ritorno.
- [ ] **Step 2: `reference/handoff.md`**: la procedura dello Step 7 della spec (§ 4), il meccanismo del timeout secondo il Task 0 Step 3, la revisione severa (§ 7).
- [ ] **Step 3: `reference/resume.md`**: § 2 Times usa `codex-limits` (riserva: testo dell'errore, poi stima); nuovo § "Claude's return" (§ 5 della spec, comprese le regole della modalità `-p`).
- [ ] **Step 4: `reference/updates.md`**: come fare il login di `claude` e perché serve (ritorno automatico).
- [ ] **Step 5: `settings/SKILL.md`**: Step 5 spiega il nuovo parametro; nuovo passo "Claude quota" nella configurazione iniziale e in modalità completa: due domande a scelta multipla con un'opzione consigliata — barra di stato (Attiva, consigliato / No) con `statusline-install`, e ritorno automatico (Attiva, consigliato se `claude` è loggato / Solo notifica).
- [ ] **Step 6: `test/SKILL.md`**: passi di collaudo per `codex-limits`, `claude-quota-check` con un `claude-quota.json` finto, `claude-limit-hit` con stdin finto, `schedule-claude-return --dry-run`, tutto nel repository di prova.
- [ ] **Step 7: Rilettura** contro le Global Constraints (inglese, niente nomi personali, nucleo snello: `wc -c` di `start/SKILL.md` ≤ 18,7 KB).
- [ ] **Step 8: Commit** `skills: handoff to Codex on Claude's quota, exact Codex resets, Claude's return`.

### Task 9: Documentazione, versione e verifica finale

**Files:**
- Modify: `README.md`, `docs/guida.md`, `CHANGELOG.md`, `plugins/coduet/.claude-plugin/plugin.json`

- [ ] **Step 1: README e guida** (italiano): cosa fa ora Coduet quando finisce la quota di Claude, come attivare barra di stato e ritorno automatico, limiti noti (nell'app desktop niente avviso alla soglia, solo al limite; il ritorno automatico richiede il login di `claude`).
- [ ] **Step 2: CHANGELOG** voce `## 0.6.0` nello stile delle precedenti; `plugin.json` version `0.6.0`.
- [ ] **Step 3: Verifiche**: `bash tests/run.sh` e `tests/run.ps1` tutti PASS; `claude plugin validate plugins/coduet` (o il validatore usato per le versioni precedenti) senza errori; JSON di `hooks.json`, `plugin.json`, `marketplace.json` validi.
- [ ] **Step 4: Collaudo** sul PC con `coduet:test` aggiornato, in un repository di prova.
- [ ] **Step 5: Commit** `Coduet 0.6.0: quota-aware handoff between Claude and Codex`, poi PR verso `main` (merge solo dopo ok dell'utente).

## Esiti delle verifiche

Prove sul PC Windows 11 di Tia, 28/10/2026.

- **Step 1, comandi degli hook:** con `claude` nel terminale gli hook girano in Git Bash (`$0=/usr/bin/bash`): `bash "${CLAUDE_PLUGIN_ROOT}/scripts/hook.sh" <nome>` funziona e passa lo stdin allo script PowerShell. Prova completa con `claude-quota-check`: avviso dato una sola volta. Nell'app desktop non ancora provato.
- **Step 2, `StopFailure`:** scatta in `claude -p` (provato con un modello inesistente). Il tipo di errore è nel campo `error`, non `error_type`: gli script leggono entrambi. Nell'app desktop non ancora provato.
- **Step 3, timeout della domanda:** non provato. Lo Step 7 contiene già il ripiego (senza risveglio, Claude aspetta la risposta).
- **Step 4, `claude -p` dal pianificatore:** riuscito. Un'attività una tantum ha avviato `claude -p ... --permission-mode acceptEdits --allowedTools "Write,Bash(git status:*)" < NUL`: file creato, `git status` eseguito senza richieste, nessuna finestra rimasta aperta, circa 20 s. Nota: nelle sessioni Remote Control il classificatore della modalità automatica blocca `Register-ScheduledTask`, quindi l'attività di prova l'ha registrata l'utente.
- **Suite di test:** Linux e Windows tutte verdi (Windows su 1535596).
