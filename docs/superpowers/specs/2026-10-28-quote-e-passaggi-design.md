# Quote e passaggi tra Claude e Codex (design)

Data: 28/10/2026. Versione prevista: 0.6.0. Stato: da approvare.

## Obiettivo

Claude è l'agente principale e la sua quota è la risorsa da proteggere. Quando sta per finire, il lavoro passa a Codex (se Codex ha quota); al reset Claude riparte da solo, riprende quello che Codex non ha ancora iniziato e rivede tutto quello che Codex ha fatto prima del merge. La quota di Codex si legge in modo esatto invece di indovinarla dal testo dell'errore.

Vincoli: nessun token speso in più quando non serve; nessun cambiamento per chi non attiva le nuove funzioni; niente che si rompa nei flussi attuali.

## Cosa sappiamo (prove del 28/10/2026, Windows 11, Codex CLI 0.163.0)

- **Codex**: `codex exec --json` non riporta i limiti. `codex app-server` sì: richiesta `account/rateLimits/read` → `rateLimits.primary` (5 ore) e `rateLimits.secondary` (settimana), ciascuno con `usedPercent`, `resetsAt` (secondi Unix) e `windowDurationMins`; più `planType` e `rateLimitReachedType`. Risposta in circa un secondo, nessun consumo di quota.
  - Protocollo: una riga JSON per messaggio. `{"id":1,"method":"initialize","params":{"clientInfo":{"name":"coduet","version":"<v>"}}}`, poi `{"method":"initialized"}`, poi `{"id":2,"method":"account/rateLimits/read","params":{"excludeResetCreditDetails":true}}`.
  - Windows (PowerShell 5.1): con le pipe .NET l'app-server non risponde; con stdin da file si chiude all'EOF prima di rispondere. Funziona: `cmd /d /c (type in.jsonl & ping -n <s> 127.0.0.1 >nul) | codex app-server --listen stdio:// > out.jsonl`, lettura di `out.jsonl` ogni 200 ms, `taskkill /T /F` alla risposta o al timeout.
- **Claude**: `rate_limits.five_hour` / `seven_day` (`used_percentage`, `resets_at`) arrivano solo allo script della barra di stato, solo con abbonamento Pro/Max e dopo la prima risposta. Nell'app desktop la barra di stato sembra non girare (un file scritto dalla barra di stato non si è aggiornato durante sessioni dell'app).
- **Hook `StopFailure`**: parte quando un turno finisce per errore dell'API; `error_type` = `rate_limit` per il limite d'uso. Esegue un comando, il risultato viene ignorato; non riporta l'orario di reset.

## Componenti

### 1. Script `codex-limits` (nuovo, Windows e Unix)

- Uscita `key=value`: `ok`, `primary_used`, `primary_resets_at`, `primary_window_mins`, `secondary_used`, `secondary_resets_at`, `secondary_window_mins`, `plan`, `reached`, `error`.
- Timeout 20 s; chiude sempre i processi che ha avviato; file temporanei in una cartella propria, cancellata alla fine.
- `ok=0` (versione di Codex senza app-server, errore, timeout) → chi lo usa torna al comportamento attuale.
- Funzione `codex_available` in `common`: Codex ha quota se `reached` è vuoto e entrambe le percentuali sono sotto 100.

Usi:
- `codex-run`: prima di creare il worktree, se Codex non ha quota risponde `CODEX WAITING task=… reason=quota resets_at=…` senza lanciare nulla. Il task va in stato "in attesa di quota" e la ripresa si pianifica come oggi.
- `schedule-resume` (lato skill, `reference/resume.md`): l'orario di ripresa è `resets_at` (della finestra esaurita) + margine. Il testo dell'errore e la stima in ore restano come riserva quando `ok=0`.
- `codex_hit_limit` resta invariato come riserva.

### 2. Quota di Claude

**Barra di stato (terminale)** — opzionale, si attiva da `coduet:settings` con ok esplicito:
- Script `claude-statusline` (Windows e Unix): legge lo stdin, se c'è `rate_limits` lo scrive in modo atomico in `~/.coduet/claude-quota.json` (`{ "read": <ISO UTC>, "rate_limits": {…} }`), poi esegue la barra di stato precedente dell'utente con lo stesso stdin e ne stampa l'uscita; se non c'era, stampa una riga breve con le percentuali.
- Installazione: la barra di stato attuale in `~/.claude/settings.json` viene salvata in `~/.coduet/statusline-prev.txt` e sostituita con lo script di Coduet; copia di backup di `settings.json` prima della modifica; comando per tornare indietro mostrato all'utente. Mai sovrascrivere senza ok; mai perdere la barra di stato precedente.

**Hook `UserPromptSubmit`** (sempre presente nel plugin, costo zero se non serve):
- Script `claude-quota-check`: se `~/.coduet/claude-quota.json` manca o è più vecchio di 10 minuti, non stampa nulla.
- Se `five_hour.used_percentage` (o `seven_day`) è ≥ soglia e per quella finestra (`resets_at`) non ha già avvisato, stampa una riga di contesto: `Coduet: Claude quota at <n>% (resets <ora>). Apply coduet:start Step 7 (handoff).` e registra l'avviso in `~/.coduet/claude-quota-warned.txt`.
- Agisce solo se la cartella corrente ha un piano Coduet (vedi § 6).

**Nuovo parametro**: "Claude quota threshold for handoff (%)", default 80. Con chiave API: non usato.

### 3. Task pronti per Codex

- Nel piano, ogni task con `Executor: Claude` ha anche `**Codex-ready:** yes|no`. `no` per sicurezza (auth, permessi, accesso ai dati), segreti e configurazioni locali, migrazioni del database; `yes` per il resto, comprese architettura e logica. Si decide quando si scrive il piano (Step 3), nessun costo dopo.
- Il prompt non si scrive in anticipo. Nuovo script `handoff-prompt` lo compone da un modello fisso: obiettivo "Implement Task <N> (<titolo>) of the plan <percorso>, following its steps and the decisions in it", le regole standard dello Step 3 (niente commit, solo i file del task, niente segreti, riepilogo finale), i comandi di verifica del piano. Costo per Claude: zero.
- Nuovo stato del task: `lent to Codex`. Branch base: quello del task nel piano.

### 4. Passaggio (Step 7 riscritto)

**Avviso alla soglia (terminale)**:
1. Claude arriva a un punto stabile, aggiorna "Status and handoff".
2. Chiede con una domanda a scelta multipla: "Passo a Codex N task (<elenco>)?" — Sì (consigliato) / Solo alcuni / No, continuo io.
3. Senza risposta in 5 minuti procede con "Sì" e lo scrive. Meccanismo: prima della domanda Claude lancia in background un comando che attende 5 minuti; se termina senza che l'utente abbia risposto, Claude riceve la notifica e procede. Dove la domanda blocca il turno senza timeout, Claude scrive la domanda come testo e usa lo stesso meccanismo. **Da verificare nella prima fase del piano**; se non funziona, Claude passa i task subito e lo dice (l'utente può riprenderli con "riprendi i task").
4. Per ogni task `Codex-ready: yes` aperto: `handoff-prompt`, poi `codex-run` (rispettando il limite di task contemporanei, gli altri restano in coda), stato `lent to Codex`. Messaggio "Claude quota".
5. Pianifica il ritorno di Claude (§ 5).

**Al limite (app desktop, o se l'avviso non è bastato)** — hook `StopFailure`, matcher `rate_limit`, script `claude-limit-hit`:
1. Esce subito se la cartella non ha un piano Coduet (§ 6) o se non è una sessione sul PC con Codex installato.
2. `codex-limits`: se Codex non ha quota, salta al punto 4.
3. Per i task `Codex-ready: yes` aperti e non già prestati: `handoff-prompt` + `codex-run` fino al limite; scrive nel piano lo stato `lent to Codex` (solo nel file locale, nessun push) e una riga nella sezione "Status and handoff".
4. Pianifica il ritorno di Claude (§ 5) se attivo, altrimenti una notifica all'orario stimato di reset: "Claude è di nuovo disponibile: scrivi 'riprendi Coduet'".
5. Notifica immediata sul PC: quali task sono partiti, quando torna Claude.
6. Idempotente: un secondo `StopFailure` nella stessa finestra non rilancia nulla (registro `~/.coduet/claude-limit-<progetto>.txt`).

**Entrambe le quote finite**: nessun task viene prestato; la ripresa di Codex segue `reference/resume.md` (orario esatto da `codex-limits`), il ritorno di Claude il § 5. Ognuno riparte con i suoi task.

### 5. Ritorno automatico di Claude

- Opzionale, si attiva da `coduet:settings`; richiede il comando `claude` con login fatto una volta (`reference/updates.md` spiega come installarlo; si aggiunge il login).
- Script `schedule-claude-return` (Windows: Task Scheduler come `schedule-resume`, con `StartWhenAvailable`, `WakeToRun`, si cancella da solo; Unix: `at`, systemd o launchd): all'orario `resets_at` + margine avvia, nella cartella del progetto, `claude -p "Use the coduet:start skill: resume after Claude's quota reset." --permission-mode acceptEdits --allowedTools <script di Coduet, git, comandi di verifica del piano>`, con stdin chiuso e uscita in `~/.coduet/claude-return-<progetto>.log`.
- Orario di reset: `five_hour.resets_at` da `claude-quota.json` se letto nelle ultime 5 ore; altrimenti ora attuale + parametro "Quota reset estimate if unknown (hours)".
- Ripresa (nuovo § in `reference/resume.md`, "Claude's return"): sequenza di avvio normale, poi
  - task `lent to Codex` ancora in coda → tornano `Executor: Claude`, status open;
  - in corso → restano a Codex;
  - finiti → revisione severa (§ 7), poi merge nel branch base come oggi.
  - Poi Claude continua il piano. In modalità `-p` non fa merge su `main`, non fa push forzati, non cancella nulla: se serve una decisione, scrive nel piano e termina con una notifica.

### 6. Quando gli hook agiscono

Solo se nella cartella corrente (o nella radice del repository) c'è un piano con la sezione "Status and handoff" e `.coduet.md` o la riga "PC copy". Altrimenti escono subito senza stampare nulla. Mai nelle sessioni cloud (Codex non c'è).

### 7. Revisione severa dei task prestati

In aggiunta allo Step 6: lettura completa del diff (non a campione), verifica che le scelte di architettura rispettino piano e specifica, test e verifiche del piano eseguiti da Claude, nessun file fuori da quelli del task. Se non va: Claude sistema o rifà il task, senza rimandarlo a Codex.

## File toccati

- Nuovi: `scripts/{windows,unix}/codex-limits`, `claude-statusline`, `claude-quota-check`, `claude-limit-hit`, `handoff-prompt`, `schedule-claude-return`; `hooks/hooks.json` del plugin.
- Modificati: `scripts/*/codex-run` (controllo quota prima del lancio), `scripts/*/common` (`codex_available`), `skills/start/SKILL.md` (parametro, `Codex-ready` allo Step 3, Step 7 riscritto, Step 8 con orario esatto; il testo resta snello, i dettagli in `reference/`), `skills/start/reference/resume.md` (orario esatto, ritorno di Claude), `skills/start/reference/updates.md` (login di `claude`), `skills/settings/SKILL.md` (attivazione barra di stato e ritorno automatico, con domande a scelta multipla), `skills/test/SKILL.md` (collaudo dei nuovi pezzi), README, `docs/guida.md`, CHANGELOG, `plugin.json` (0.6.0).

## Prove

- `codex-limits`: su Windows e Unix, con Codex loggato (valori presenti), senza login (`ok=0`), con un finto `codex` lento (timeout, nessun processo rimasto).
- `claude-statusline`: con e senza barra di stato precedente; stdin senza `rate_limits`; uscita identica alla barra precedente.
- `claude-quota-check`: file mancante, vecchio, sotto soglia, sopra soglia (una sola riga per finestra), cartella senza piano Coduet (nessuna uscita).
- `claude-limit-hit`: con input `StopFailure` simulato; Codex con e senza quota (finto `codex-limits`); seconda esecuzione idempotente; cartella senza piano.
- `handoff-prompt`: prompt corretto per un task di un piano di esempio.
- Collaudo guidato (`coduet:test`) esteso con una simulazione completa in un repository di prova: soglia, passaggio, ritorno pianificato (senza attendere il reset).
- Da verificare all'inizio del piano, prima del resto: `StopFailure` gira nell'app desktop; il timeout di 5 minuti della domanda; `claude -p` avviato dal pianificatore di Windows con permessi limitati.

## Fuori da questo lavoro

Domande cliccabili in tutte le impostazioni, thread di log, messaggi da togliere (gruppo B); default della cartella dei worktree e altre decisioni per la 1.0 (gruppo C).
