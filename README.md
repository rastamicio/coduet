# Coduet

**Dividi il lavoro di un progetto tra Claude Code e Codex CLI.**

Coduet è un plugin per Claude Code. Claude fa da regista (architettura, logica delicata, sicurezza, revisione) e affida a Codex, l'agente di programmazione incluso negli abbonamenti ChatGPT, il lavoro ripetitivo: test, documentazione, testi, refactoring meccanici, asset. I due lavorano in parallelo, si passano il lavoro quando una quota finisce, e nulla entra nel progetto senza revisione.

> Coduet è un progetto indipendente, **non affiliato ad Anthropic o OpenAI**. Claude, Claude Code, Codex e ChatGPT sono marchi dei rispettivi proprietari.

## Cosa fa

- **Divide il lavoro**: all'avvio chiede se usare Codex; nel piano ogni task riceve un esecutore (Claude o Codex) con un prompt completo per Codex.
- **Lavoro in parallelo e isolato**: ogni task di Codex gira con `codex exec` in un git worktree separato, su un branch `codex/<task>`. Il worktree può stare accanto al progetto (predefinito) o dentro, in `.codex-worktrees/` (impostazione *Cartella dei worktree*). Codex gira in un processo a parte: se la sessione di Claude si chiude, finisce il lavoro lo stesso.
- **Revisione prima dell'unione**: Claude verifica, rivede e unisce; i conflitti li risolve Claude, mai Codex.
- **Passaggio di consegne**: lo stato del lavoro vive nel piano, così Claude e Codex possono riprendere l'uno dal punto dell'altro.
- **Quota di Claude protetta**: Claude è il regista e la sua quota è la più preziosa. Quando sta per finire (80%, nel terminale) Coduet propone di prestare a Codex i task di Claude pronti; quando arriva al limite (anche nell'app desktop) li presta da solo con uno script, senza spendere token di Claude. Al reset Claude può ripartire da solo, riprende i task che Codex non ha ancora iniziato e rivede con più attenzione quelli che ha fatto.
- **Ripresa automatica**: se finisce la quota di Codex, la ripresa viene pianificata all'ora esatta del reset (letta da Codex), con un controllo successivo e un avviso di riserva. Prima di lanciare un task Coduet controlla che Codex abbia ancora quota.
- **Asset con approvazione**: immagini, audio, video, 3D e presentazioni passano da controlli automatici e da una pagina di anteprima; entrano nel progetto solo se approvati.
- **Progetti locali, cloud o ibridi**: funziona in una sessione sul PC, oppure da una sessione cloud che affida i task di Codex a una sessione sul PC, comunicando tramite il repository.
- **Configurabile**: skill di metodo per ogni fase (di partenza [Superpowers](https://github.com/obra/superpowers)), verifiche aggiuntive e parametri, a livello personale o per progetto.

## Requisiti

- Claude Code (terminale o app desktop) con un piano Claude a pagamento (Pro, Max, Team, Enterprise o API): con il piano Free di Claude, Claude Code non è disponibile.
- [Codex CLI](https://developers.openai.com/codex) installato **sul PC**, collegato a un account ChatGPT o a una chiave API.

| Accesso Codex | Come lavora Coduet |
|---|---|
| ChatGPT Free / Go | Funziona in modo ridotto: un task alla volta, solo task piccoli, niente immagini generate da Codex |
| ChatGPT Plus / Business | Configurazione di partenza |
| ChatGPT Pro | Più task in parallelo e task più grandi |
| Chiave API | Nessuna quota ma costo a consumo, con tetto di spesa per sessione |

Indica i tuoi piani con `/coduet:settings` e Coduet propone i parametri adatti.
- `git`. Un repository remoto (GitHub, GitLab...) è necessario solo per la modalità ibrida cloud + PC.
- Facoltativo: il plugin Superpowers. Senza, Coduet usa un metodo base per ogni fase.

Coduet è stato verificato su Windows 11 con Codex CLI 0.163.0. Su macOS e Linux usa script equivalenti, provati in ambiente di test ma non ancora su un Mac o un PC Linux reale: il collaudo (`/coduet:test`) ti dice se funzionano.

## Installazione

1. **Installa Codex CLI** e fai il login con l'account ChatGPT (`codex login`). La [guida completa](docs/guida.md#3-guida-allinstallazione-windows) spiega i passi e le prove da fare.
2. **Installa Coduet** in una sessione di Claude Code:

   ```
   /plugin marketplace add rastamicio/coduet
   /plugin install coduet@coduet
   ```

   Poi `/reload-plugins` o apri una nuova sessione.

## Uso

| Cosa scrivere | A cosa serve |
|---|---|
| `/coduet:start <idea>` oppure **"avvia Coduet"** | Avvia un progetto nuovo, o riprende un progetto esistente dividendo il lavoro con Codex |
| `/coduet:settings` oppure **"impostazioni di Coduet"** | Mostra e cambia le impostazioni (anche una sola, es. "metti 3 task Codex") |
| `/coduet:test` oppure **"collauda Coduet"** | Collaudo guidato di circa 5 minuti su un repository di prova: lancio di Codex, avviso di fine, un asset, ripresa simulata, controllo aggiornamenti |

Nei thread di un progetto i comandi con la barra non vengono eseguiti: usa le frasi in grassetto.

### Dove si può usare

Codex è installato sul tuo PC, quindi i task di Codex partono solo da sessioni che girano sul PC.

| Dove sei | Cosa fa Coduet |
|---|---|
| Sessione di Code sul PC, nella cartella del progetto | Tutto |
| Thread di un progetto con cartella locale predefinita (vedi sotto) | Tutto |
| Sessione o thread nel cloud, con il PC collegato | Piano e revisione nel cloud; i task di Codex li esegue una sessione sul PC (modalità ibrida) |
| Sessione nel cloud senza PC | Solo il lavoro di Claude: Coduet ti dice che Codex non è raggiungibile e come risolvere |

Coduet te lo dice comunque al primo messaggio: dove sta girando e se Codex è raggiungibile.

### Cosa vedi mentre lavora

Ogni passo ha un messaggio breve che inizia con `Coduet ·`: dove sei e se Codex c'è, controlli della copia, divisione del piano, **▶ Codex avviato** (task, ora, durata stimata), **✓ Codex finito** (file, token), esito della revisione, **⏸ quota Codex esaurita** con gli orari di ripresa, controllo e avviso, **↻ esito della ripresa**, **⬆ aggiornamento disponibile**, **■ fine**. Ogni task di Codex compare anche nella lista delle attività. Puoi chiedere in ogni momento "come va Codex?".

**Dopo l'installazione o un aggiornamento** apri una sessione (o un thread) nuova: quelle già aperte continuano con la versione di prima.

Al primo utilizzo Coduet propone una configurazione iniziale unica (circa 2 minuti): piani, skill per fase, comando `claude`, cartella locale. Consiglio: poi fai il collaudo.

## Far lavorare un progetto in locale

Codex funziona solo sul PC. I progetti dell'app di Claude possono lavorare nel cloud: in quel caso Coduet usa una modalità ibrida più complessa. Per farli lavorare direttamente sul PC:

1. apri le impostazioni del progetto, sezione **Ambiente**;
2. in **Locale**, attiva l'uso del tuo dispositivo e aggiungi tra le cartelle la copia del progetto sul PC (la cartella che contiene `.git`);
3. impostala come **predefinita**.

Da quel momento i thread del progetto lavorano in quella cartella. Coduet te lo propone da solo quando si accorge di essere nel cloud con il PC collegato.

## Configurazione

Per ogni voce vale il livello più specifico:

| Livello | Dove sta |
|---|---|
| Valori di partenza | Dentro il plugin |
| Configurazione personale | Skill personale `coduet-config`, creata da `/coduet:settings`: nel tuo account se la sessione può salvarla lì, altrimenti solo sul PC (vedi sotto) |
| Configurazione del progetto | File `.coduet.md` nel progetto |

Gli aggiornamenti del plugin non toccano mai la tua configurazione personale né quella dei progetti.

**Profili per piano**: in `/coduet:settings` puoi indicare il tuo piano Claude e il tuo accesso a Codex; Coduet propone i valori adatti (vedi Requisiti). Senza indicazioni vale il profilo Plus.

Se `coduet-config` viene salvata solo sul PC (succede, per esempio, nell'app desktop), le sessioni cloud e gli altri computer non la vedono e usano i valori di partenza. `/coduet:settings` te lo segnala e ti spiega come caricarla anche nel tuo account.

## Aggiornamenti

**Avviso automatico.** Ogni volta che usi `/coduet:start`, Coduet controlla se è uscita una versione più recente, ti riassume le novità e ti chiede se aggiornare.

**Aggiornamento dalla chat (consigliato).** Se sul PC è disponibile il comando `claude` da terminale, rispondi "Aggiorna ora": uno script del plugin aggiorna marketplace e plugin, controlla che la versione sia cambiata e te lo conferma; poi apri una sessione o un thread nuovo. Se qualcosa va storto ti mostra il comando da incollare in un terminale e salva i dettagli in `~/.coduet/aggiornamento.log`. Se il comando manca, Coduet se ne accorge e ti propone di installarlo lui, una volta sola, con il tuo ok. Per installarlo a mano:

- Windows (PowerShell): `irm https://claude.ai/install.ps1 | iex`. Se l'installazione avvisa che la cartella non è nel PATH, aggiungila con:
  `[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","User") + ";$env:USERPROFILE\.local\bin", "User")`
  poi riapri PowerShell e l'app di Claude.
- macOS e Linux: `curl -fsSL https://claude.ai/install.sh | bash`

Verifica con `claude plugin list`: deve comparire `coduet@coduet`.

**Senza il comando `claude`:**
- **App desktop di Claude** (verificato): non c'è l'aggiornamento automatico, si aggiorna dal pannello dei plugin:
  1. apri la **Directory** dei plugin (per esempio scrivendo `/plugin` in una sessione di Code) → **Plugin** → **Code**;
  2. clicca **···** accanto all'etichetta `coduet` → **Verifica aggiornamenti**;
  3. clicca l'**ingranaggio** sulla scheda Coduet e poi **Aggiorna**. Se l'app avvisa che verranno sovrascritti dei file `.in_use\...`, conferma: sono solo i contrassegni delle sessioni aperte, non modifiche tue;
  4. nelle sessioni già aperte scrivi `/reload-plugins` (o aprine una nuova).
- **Claude Code da terminale**: puoi anche aggiornare a mano quando vuoi con `/plugin marketplace update coduet`.

Le novità di ogni versione sono nel [CHANGELOG](CHANGELOG.md).

## Sicurezza e privacy

- Codex viene lanciato solo con la sandbox `workspace-write`: può scrivere solo nella cartella del task.
- Il lavoro di Codex sta su branch separati e viene unito solo dopo verifica e revisione.
- I segreti (`.env` e simili) non passano mai da chat, piano, prompt o git, e Codex riceve l'istruzione di non leggerli.
- Le operazioni ripetitive (aggiornamento, lancio e stato di Codex, ripresa) usano **script inclusi nel plugin** (`plugins/coduet/scripts`), leggibili, invece di comandi scritti al momento.
- La ripresa automatica crea **attività pianificate sul tuo PC** che lanciano quegli script; si rimuovono da sole dopo l'esecuzione.
- Il codice del progetto viene inviato sia ad Anthropic sia a OpenAI. Per codice riservato valuta prima, e controlla nelle impostazioni dei due servizi l'uso dei dati per l'addestramento.
- Il controllo aggiornamenti legge due file pubblici dal repository di Coduet su GitHub (`plugin.json` e `CHANGELOG.md`), a ogni avvio di Coduet; non invia nessun dato del progetto. Gli aggiornamenti, e l'eventuale installazione del comando `claude`, avvengono solo con il tuo ok.
- Coduet è fatto di istruzioni in testo: leggile prima di installarlo. Aggiornando, ti fidi anche delle versioni future.

## Contribuire

Coduet migliora con l'uso: alla fine di ogni lavoro propone correzioni scritte in forma generale. Se ne trovi una utile a tutti, apri una [segnalazione](https://github.com/rastamicio/coduet/issues).

## Documentazione

- [Guida completa](docs/guida.md): perché, come funziona, installazione passo passo, comandi verificati e problemi noti.
- Testo delle skill (in inglese, Coduet risponde nella tua lingua): [`coduet:start`](plugins/coduet/skills/start/SKILL.md) con i file di [riferimento](plugins/coduet/skills/start/reference), [`coduet:settings`](plugins/coduet/skills/settings/SKILL.md), [`coduet:test`](plugins/coduet/skills/test/SKILL.md).
- Script: [`plugins/coduet/scripts`](plugins/coduet/scripts). Test automatici delle skill: [`plugins/coduet/evals`](plugins/coduet/evals) (`claude plugin eval plugins/coduet`, consuma quota).

## Licenza

[MIT](LICENSE). Fornito "così com'è", senza garanzie.
