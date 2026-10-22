# Coduet: guida completa

*Coduet è un progetto indipendente, non affiliato ad Anthropic o OpenAI.*

*Perché collegare Claude Code e Codex, come funziona Coduet e come installarlo. Testato su Windows 11 con Codex CLI 0.163.0, ottobre 2026.*

---

## 1. Perché collegare Claude e Codex

L'obiettivo è usare **due assistenti di programmazione sullo stesso progetto**, ognuno su ciò che fa meglio:

- **Claude Code** fa da regista: architettura, logica delicata, sicurezza, database, debug difficili, revisione finale e integrazione.
- **Codex** (l'agente di programmazione di OpenAI, incluso negli abbonamenti ChatGPT) fa da secondo sviluppatore: lavoro ripetitivo, test, documentazione, testi, refactoring meccanici, asset grafici e presentazioni.

### Vantaggi

- **Due quote invece di una.** Ogni abbonamento ha limiti di utilizzo, sia nelle finestre di 5 ore sia settimanali. Delegando a Codex il lavoro voluminoso ma semplice, la quota di Claude resta disponibile per le parti difficili.
- **Lavoro in parallelo.** Claude lancia Codex in background e intanto porta avanti i propri task.
- **Revisione incrociata.** Due modelli diversi trovano errori diversi. Il lavoro di Codex non entra nel progetto finché Claude non l'ha rivisto.
- **Continuità.** Se una delle due quote finisce, l'altro assistente riprende dal piano, che contiene sempre lo stato aggiornato del lavoro.
- **Nessun costo aggiuntivo.** Codex si collega con il login ChatGPT, senza chiave API e senza pagamenti a consumo.

### Quale piano ChatGPT serve

| Piano | Codex | Generazione immagini da Codex | Note |
|---|---|---|---|
| Free | Sì, quota minima | No | Va bene per provare, poco per lavorare |
| **Plus** | Sì | Sì | **Scelta consigliata per iniziare** |
| Pro | Sì, quota molto più alta | Sì | Utile se la quota Plus finisce spesso |
| Business Standard | Sì, stessa quota di Plus per postazione | Sì | Minimo 2 utenti, funzioni aziendali: non conviene a un singolo sviluppatore |

Quando la quota di Codex finisce **non parte nessun addebito automatico**: Codex si ferma. L'unica eccezione è se si sono acquistati crediti extra. Lo stesso vale per Claude, se non è attivo l'utilizzo extra nelle impostazioni.

Claude Code richiede comunque un piano Claude a pagamento.

---

## 2. Come funziona

### Lo stato vive nei file, non nelle chat

I due assistenti non si parlano direttamente: si coordinano attraverso file nel progetto.

| File | A cosa serve |
|---|---|
| Piano (es. `docs/.../piano.md`) | Elenco dei task, ognuno con `Esecutore: Claude` o `Esecutore: Codex`, e in cima la sezione **"Stato e passaggio di consegne"** |
| `CLAUDE.md` | Regole del progetto per Claude |
| `AGENTS.md` | Le stesse regole per Codex, più: non fare commit, lavorare solo sui file indicati, fermarsi se in difficoltà |
| `docs/codex-registro.md` | Registro dei task delegati: esito e token usati |
| `.coduet.md` | Configurazione di Coduet per quel progetto (facoltativa) |

Le sessioni di Codex **non compaiono nella cronologia di ChatGPT**: restano sul PC e tutto ciò che producono finisce nella cartella del progetto.

### Il flusso

1. **Domanda iniziale**: si sceglie se dividere il lavoro (completa, solo asset/test/documentazione, oppure no).
2. **Ideazione e piano**: si usano le skill di metodo (di default Superpowers). Nel piano ogni task riceve un esecutore. I task di Codex arrivano con un prompt completo e autosufficiente, perché Codex non vede la conversazione con Claude.
3. **Esecuzione in parallelo**: ogni task di Codex gira in un **git worktree** separato, su un proprio branch, al massimo 2 alla volta. Claude intanto lavora sui suoi task.
4. **Revisione**: Claude legge il risultato, esegue i test, fa la revisione, poi fa lui il commit e il merge.
5. **Passaggio di consegne**: la sezione "Stato e passaggio di consegne" permette a chiunque dei due di ripartire senza contesto.

### Quando finisce una quota

- **Finisce la quota di Claude**: l'utente lo segnala ("chiudi e passa a Codex"). Claude aggiorna il piano e fornisce il comando per far proseguire Codex.
- **Finisce la quota di Codex**: la ripresa è automatica, su tre livelli:
  1. **Ripresa**: l'Utilità di pianificazione di Windows rilancia Codex all'ora del reset. È gratuita e funziona anche se Claude ha finito la quota.
  2. **Controllo di Claude**: 20 minuti dopo, un'attività programmata di Claude legge l'esito, avvisa l'utente e, se possibile, risolve da sola.
  3. **Avviso di riserva**: 40 minuti dopo compare una finestra di Windows con il comando manuale, ma solo se Claude non è intervenuto e la ripresa non è riuscita.

Condizione: il PC deve essere acceso. Se era spento, le attività partono alla riaccensione.

### Dove gira il lavoro

Codex esiste solo sul PC, ma un progetto può essere stato sviluppato fin lì in sessioni cloud. All'avvio Coduet controlla la situazione:

| Situazione | Cosa fa Coduet |
|---|---|
| Sessione sul PC, progetto già nella cartella | Prosegue normalmente |
| Sessione sul PC, progetto solo su GitHub | Scarica il progetto, installa le dipendenze, verifica che funzioni, poi parte |
| Sessione cloud che può avviare sessioni sul PC | Modalità ibrida: Claude lavora nel cloud, una sessione sul PC esegue i task di Codex, e la comunicazione passa solo da GitHub (piano e branch) |
| Sessione cloud non collegata | Avvisa che Codex non è raggiungibile e propone di collegare il PC, oppure prosegue senza Codex |

**Lezione dalla prima prova (modalità ibrida):** una sessione cloud può avviare una sessione sul PC e darle istruzioni solo all'avvio; poi non può più scriverle. Per questo Coduet non usa i messaggi tra sessioni: la sessione cloud scrive i task di Codex nel piano su GitHub, avvia una sola sessione sul PC con l'istruzione "esegui i task Codex aperti del piano", e quella lavora da sola (Codex, test, push sul branch `codex/<task>`, stato nel piano). L'utente non fa mai da tramite: approva solo l'avvio. Se possibile, la soluzione più semplice resta lavorare direttamente in una sessione sul PC.

Altre regole emerse dalla prova, valide sempre:
- Codex si usa solo con `codex exec`, mai interattivo (in modalità interattiva si blocca a chiedere permessi).
- Ogni task Codex parte dal **branch della funzione** (la PR) e viene unito lì, non per forza su `main`.
- Se il lavoro è su più PR, il piano sta su un branch dedicato `coordinamento`, così tutte le sessioni lo vedono.
- I comandi di test si prendono dal progetto, evitando quelli lenti o che non terminano.
- Percorsi con spazi o apostrofi vanno sempre messi tra virgolette (e l'apostrofo raddoppiato negli script PowerShell).

Per evitare confusione tra copie locali e cloud, **GitHub è sempre la copia di riferimento**:
- ogni sessione, cloud o sul PC, all'inizio si allinea con GitHub e alla fine invia il proprio lavoro;
- il piano registra quale cartella del PC è "la" copia locale, e prima di scaricare il progetto Coduet cerca se ne esiste già una;
- se trova più copie, chiede quale usare e non tocca le altre;
- prima di iniziare controlla che la copia locale sia del progetto giusto, aggiornata, senza modifiche in sospeso (se ci sono, chiede cosa farne), con le dipendenze installate e funzionante;
- non cancella né sovrascrive mai cartelle o modifiche senza un ok esplicito.

Se il progetto ha già convenzioni proprie per gli asset (guide, prompt, strumenti di importazione, colore di sfondo), Coduet usa quelle.

### Asset: produzione automatica, approvazione umana

Vale per qualsiasi asset generato da Codex: immagini, sprite, icone, audio, video, modelli 3D, presentazioni. La produzione è automatica, ma **nessun asset entra nel progetto senza l'approvazione dell'utente**.

**Cosa sa produrre Codex:**

| Tipo | Come | Affidabilità |
|---|---|---|
| Immagini, sprite | Strumento integrato di generazione immagini | Buona (da verificare alla prima prova) |
| Vettoriale, icone, interfacce | Codice SVG/HTML | Molto buona |
| Audio | Codice: sintesi sonora, MIDI | Buona per effetti retro e musica semplice, scarsa per audio realistico |
| Video, animazioni | Fotogrammi via codice + ffmpeg | Animazioni grafiche sì, video realistici no |
| Modelli 3D | Codice glTF o script Blender | Forme semplici e low-poly sì, modelli organici complessi no |
| Presentazioni, documenti | Codice (HTML, PPTX) | Molto buona |

**Il ciclo:**

1. **Guida di stile e prove**: si definisce lo stile in `docs/stile-asset.md` e si parte con 2-3 asset di prova. La produzione completa parte solo quando lo stile convince.
2. **Controllo tecnico automatico**, specifico per tipo: dimensioni e frame per le immagini, durata, volume e loop per l'audio, file valido, poligoni e scala per il 3D. Se fallisce, Claude rigenera da solo, al massimo 2 volte.
3. **Pagina di anteprima** con il visualizzatore adatto (immagine, lettore audio o video, visualizzatore 3D). Per ogni asset si sceglie "Approvato" o "Da rigenerare" con una nota libera, poi un pulsante copia l'esito da incollare a Claude.
4. **Rigenerazione mirata**: Claude traduce le note in istruzioni precise e rigenera solo ciò che serve, usando la versione precedente come riferimento. Le correzioni si sommano al prompt, così gli errori non ricompaiono.
5. **Versioni e registro**: le bozze stanno in `assets/_bozze/<asset>/v1, v2...`, e solo quelle approvate entrano nel progetto. `docs/asset-registro.md` tiene prompt, note, stato e numero di rigenerazioni.

In autonomia, produzione e controlli procedono, ma gli asset restano in attesa di approvazione: il progetto va avanti con segnaposto.

### Casi particolari gestiti

| Caso | Come lo gestisce Coduet |
|---|---|
| File segreti non nel repository (`.env`, chiavi) | Li riconosce dai file di esempio e da `.gitignore`; i segreti non passano mai da chat, piano, prompt o git; l'utente li crea a mano; i task che ne hanno bisogno li fa Claude; Codex non li legge; controllo prima di ogni commit |
| File di lavoro di Coduet | Esclusi dai commit con `.git/info/exclude`, senza modificare il progetto |
| macOS e Linux | Stessi comandi Codex; ripresa con script bash e launchd (Mac) o systemd/at/cron (Linux), avvisi con `osascript` o `notify-send` (da verificare) |
| Più progetti con Codex insieme | Registro globale sul PC: al massimo 2 task Codex attivi in totale, stato della quota condiviso, riprese a scaglioni |
| GitLab, Bitbucket, altri | Funziona uguale ("PR" vale anche per le merge request) |
| Git senza repository remoto | Solo lavoro sul PC, niente modalità ibrida |
| Nessun git | Propone `git init` con l'ok dell'utente; altrimenti backup e lavoro su copie della cartella |
| Progetti senza test | Verifica con build, typecheck e lint, prova pratica dell'app e revisione più attenta; propone test solo con l'ok dell'utente |

### Due skill: `coduet:start` e `coduet:settings`

Coduet è un plugin per Claude Code con due skill:

- **`/coduet:start`** fa il lavoro: funziona sia su **progetti nuovi** sia su **progetti già avviati** (legge il piano esistente e assegna solo i task ancora aperti). Le skill richiamate a mano durante il lavoro valgono solo per quel momento e non entrano nel flusso.
- **`/coduet:settings`** cambia le impostazioni e **non contiene logica di lavoro**, così cambiare configurazione non disturba il lavoro in corso.

Le impostazioni sono:
- **Skill per fase**: per ogni fase (ideazione, piano, esecuzione, isolamento, revisione, verifica) una o più skill tra quelle installate, in ordine. Di partenza Superpowers.
- **Verifiche aggiuntive**: controlli in più che servono a un progetto (accessibilità, prestazioni, traduzioni...).
- **Parametri**: task Codex contemporanei, ragionamento predefinito, tempi della ripresa automatica, rigenerazioni automatiche degli asset, misure del consumo, ecc.

### Tre livelli di configurazione

| Livello | Dove sta | Chi lo cambia |
|---|---|---|
| Valori di partenza | Dentro il plugin | Solo chi mantiene il plugin, con un aggiornamento |
| Configurazione personale | Skill personale `coduet-config`: nel tuo account (visibile sul PC e nel cloud) se la sessione può salvarla lì, altrimenti solo sul PC | Tu, con `/coduet:settings` → "salva nella mia configurazione personale" |
| Configurazione del progetto | File `.coduet.md` nel progetto | Tu, con `/coduet:settings` → "salva per questo progetto" |

Vale sempre il livello più specifico. Gli aggiornamenti del plugin non toccano mai la configurazione personale né quella dei progetti. Le modifiche al progetto valgono subito anche per una sessione in corso, perché `coduet:start` rilegge la configurazione all'inizio di ogni fase; quelle personali valgono dalla ricarica successiva.

**Profili per piano.** Coduet è tarato su Claude Pro + ChatGPT Plus. Con `/coduet:settings` puoi indicare il tuo piano Claude e il tuo accesso a Codex, e Coduet propone i parametri adatti:

| Accesso Codex | Task in parallelo | Ragionamento | Immagini da Codex | Note |
|---|---|---|---|---|
| ChatGPT Free / Go | 1 | low | no | Solo task piccoli; la ripresa automatica scatta spesso |
| ChatGPT Plus / Business | 2 | medium | sì | Valori di partenza |
| ChatGPT Pro | 3 | medium | sì | Task più grandi |
| Chiave API | 2 | medium | sì | Niente quote, costo a consumo, tetto di spesa per sessione |

Con Claude Max, Team, Enterprise o API la quota di Claude conta meno, quindi Coduet affida a Codex solo gli asset e i task meccanici di grande volume. Con il piano Free di Claude, Claude Code non è disponibile. Chi non indica i piani resta sul profilo Plus.

Al primo utilizzo `coduet:start` propone la configurazione iniziale. Se una skill scelta per una fase non c'è (mai installata, disinstallata, rinominata), Coduet avvisa e usa un **metodo base** minimo per quella fase, finché non se ne sceglie un'altra. Per la parte Codex valgono sempre le regole di Coduet, anche se una skill di fase dice diversamente; e Coduet non modifica mai altre skill né i propri file.

### Coduet migliora a ogni utilizzo

Alla fine di ogni utilizzo `coduet:start` elenca imprevisti, comandi falliti, aggiramenti e correzioni ricevute, e propone miglioramenti **scritti in forma generale** (i dettagli del singolo progetto vanno nel suo `CLAUDE.md`). Le scelte e i valori si cambiano con `coduet:settings`; le regole di lavoro appartengono al plugin, e i miglioramenti si propongono come segnalazione (issue) al repository di Coduet.

---

## 3. Guida all'installazione (Windows)

### Prerequisiti

- Claude Code (app desktop di Claude, sezione Code, oppure terminale) con piano Claude a pagamento.
- Abbonamento ChatGPT (consigliato Plus o superiore).
- Plugin **Superpowers** installato in Claude Code (consigliato, non obbligatorio: al primo utilizzo scegli le skill da usare per ogni fase, e per le fasi senza skill c'è un metodo base).

### Passo 1: installare Codex CLI

Apri **PowerShell**, senza privilegi di amministratore:

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://chatgpt.com/codex/install.ps1 | iex"
```

Se a fine installazione chiede di avviare Codex, rispondi `n`. Chiudi e riapri PowerShell, poi:

```powershell
codex --version
```

Su macOS o Linux l'installer è `curl -fsSL https://chatgpt.com/codex/install.sh | sh`.

### Passo 2: login con l'account ChatGPT

```powershell
codex login
codex login status
```

Si apre il browser per l'accesso. Alla fine deve comparire `Logged in using ChatGPT`.

### Passo 3: primo avvio e sandbox

Non avviare mai Codex in cartelle di sistema come `C:\Windows\System32`. Usa una cartella di prova:

```powershell
mkdir $HOME\prova-codex
cd $HOME\prova-codex
codex
```

- Alla richiesta sulla sandbox scegli **"Set up default sandbox (requires Administrator permissions)"** e approva la finestra di Windows. Codex lavora così con un utente separato e limitato.
- Scrivi `/status` per vedere account, modello, permessi e quota rimasta (5 ore e settimanale).
- Esci con `/quit`.

### Passo 4: prova senza interazione

```powershell
codex exec --skip-git-repo-check --sandbox workspace-write "crea un file prova.txt con scritto ciao"
Get-Content prova.txt
```

`--skip-git-repo-check` serve solo fuori da un repository git.

### Passo 5: prova della ripresa

```powershell
codex exec resume --last --skip-git-repo-check -c sandbox_mode="workspace-write" "Che file hai creato nella sessione precedente? Scrivi il suo nome dentro ricordo.txt"
Get-Content ricordo.txt
```

Se `ricordo.txt` contiene `prova.txt`, la ripresa mantiene il contesto.

### Passo 6: prova da Claude Code

1. Chiudi e riapri l'app di Claude, così vede il comando `codex`.
2. Apri una sessione di Code sulla cartella di prova.
3. Incolla:

```
Lancia Codex in background con questo comando, nella cartella corrente:
codex exec --skip-git-repo-check --sandbox workspace-write "crea un file saluti.md con una lista di 3 saluti in lingue diverse"
Mentre Codex lavora, crea tu un file orario.txt con l'ora attuale.
Quando Codex ha finito, leggi saluti.md e dimmi cosa contiene e quanti token ha usato Codex.
```

Se Claude crea il suo file e poi riporta il contenuto di `saluti.md` e i token, il collegamento è completo.

### Passo 7: installare Coduet

In una sessione di Claude Code:

```
/plugin marketplace add rastamicio/coduet
/plugin install coduet@coduet
```

Poi `/reload-plugins` (o apri una nuova sessione).

**Aggiornamenti:** ogni volta che usi `/coduet:start`, Coduet controlla se c'è una versione nuova, ti riassume le novità e, con il tuo ok, si aggiorna da solo dalla chat (poi scrivi `/reload-plugins`). Per farlo serve il comando `claude` da terminale: se manca, Coduet ti propone di installarlo lui, una volta sola. Per installarlo a mano su Windows: `irm https://claude.ai/install.ps1 | iex` in PowerShell, poi aggiungi `%USERPROFILE%\.local\bin` al PATH se l'installazione lo chiede, e riapri l'app di Claude.

Senza il comando `claude`:
- **Claude Code da terminale**: gli aggiornamenti automatici sono spenti di default. Per attivarli: `/plugin` → **Marketplaces** → `coduet` → **Enable auto-update**.
- **App desktop di Claude** (verificato): non c'è l'aggiornamento automatico, si aggiorna dal pannello dei plugin:
  1. apri la **Directory** dei plugin (per esempio scrivendo `/plugin` in una sessione di Code) → **Plugin** → **Code**;
  2. clicca **···** accanto all'etichetta `coduet` → **Verifica aggiornamenti**;
  3. clicca l'**ingranaggio** sulla scheda Coduet e poi **Aggiorna**. Se l'app avvisa che verranno sovrascritti dei file `.in_use\...`, conferma: sono solo i contrassegni delle sessioni aperte, non modifiche tue;
  4. nelle sessioni già aperte scrivi `/reload-plugins` (o aprine una nuova).
- **Claude Code da terminale**: puoi anche aggiornare a mano quando vuoi con `/plugin marketplace update coduet`.

Se lavori anche in sessioni cloud, Coduet deve essere disponibile anche lì: un modo è dichiarare il marketplace nelle impostazioni del progetto (`.claude/settings.json`), così si carica per chiunque lavori nel repository (da verificare).

### Uso

- **Progetto nuovo**: `/coduet:start` seguito dall'idea, in linguaggio normale.
- **Progetto in corso**: lo stesso comando, oppure "dividiamo il lavoro con Codex".
- **Impostazioni**: `/coduet:settings`, oppure "impostazioni di Coduet" (anche per una sola modifica, come "metti 3 task Codex").
- **Nei thread di un progetto** i comandi con la barra non vengono eseguiti: scrivi "avvia Coduet" e "impostazioni di Coduet".
- **Dopo installazione o aggiornamento** apri una sessione o un thread nuovo.
- **Per far lavorare un progetto sul PC**: impostazioni del progetto → Ambiente → Locale → aggiungi la cartella della copia del progetto e rendila predefinita.
- **Mentre Codex lavora** Coduet te lo dice (messaggio all'avvio, lista delle attività, aggiornamenti, riepilogo); chiedi "come va Codex?" quando vuoi.

Consiglio: la prima volta provalo su un progetto piccolo.

---

## 4. Comandi verificati e problemi noti

### Comandi

| Scopo | Comando |
|---|---|
| Eseguire un task | `codex exec --cd "<cartella>" --sandbox workspace-write -c model_reasoning_effort="medium" -o "<cartella>/.codex-esito.md" "<prompt>"` |
| Riprendere una sessione | da dentro la cartella: `codex exec resume <ID> -c sandbox_mode="workspace-write" -c model_reasoning_effort="medium" -o .codex-esito.md "<prompt>"` |
| Quota e stato | `/status` dentro Codex, oppure chatgpt.com/settings/usage |
| Elenco sessioni | `codex agents`; ripresa interattiva con `codex resume <id>` |

### Problemi noti

- **`codex exec` parte in sola lettura**: senza `--sandbox workspace-write` non può scrivere file.
- **`codex exec resume` non ha `--sandbox` né `--cd`**: la sandbox si imposta con `-c sandbox_mode="workspace-write"` e il comando va lanciato da dentro la cartella. La ripresa cerca le sessioni nella cartella corrente.
- **Ragionamento disattivato di default in `exec`** ("reasoning effort: none"): va impostato con `-c model_reasoning_effort="low|medium|high"`.
- **Immagini con sfondo trasparente poco affidabili**: meglio generarle su sfondo verde pieno e scontornarle con uno script.
- **Gli asset consumano molta quota**, le immagini in particolare: conviene generarli a gruppi, a stile già approvato.
- **Codex accetta solo immagini come allegati** (`-i`): per audio, video e 3D i riferimenti si indicano con il percorso del file nel prompt.

### Versioni dei programmi

Coduet è stato verificato con **Codex CLI 0.163.0**. Codex si aggiorna spesso: a ogni avvio Coduet confronta la versione installata e, se è cambiata, controlla con `--help` che le opzioni usate esistano ancora. Se qualcosa è cambiato, avvisa, adatta i comandi e lo annota tra i miglioramenti proposti. Lo stesso vale per gli strumenti di Claude Code.

### Ancora da verificare

- Testo esatto dell'errore di limite di Codex, e se contiene l'ora del reset.
- Generazione di immagini da `codex exec`.
- Presenza di ffmpeg e Blender sul PC, se servono video o modelli 3D.
- Ripresa automatica su macOS e Linux.
- Strumento di Claude Code desktop per creare attività programmate e notifiche.
- Consumo reale del controllo automatico di Claude: da misurare nei primi 3 casi.

---

## Testo delle skill

- [`coduet:start`](../plugins/coduet/skills/start/SKILL.md)
- [`coduet:settings`](../plugins/coduet/skills/settings/SKILL.md)
