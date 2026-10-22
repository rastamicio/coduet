---
name: start
description: Usa all'avvio di un progetto, o in un progetto in corso quando l'utente vuole dividere il lavoro con Codex: chiede se dividerlo e coordina piano, esecuzione parallela, revisione, consegne e ripresa automatica.
---

# Coduet: start (Claude Code + Codex)

Questa skill (parte del plugin Coduet) fa da regista. Il metodo di lavoro (ideazione, piano, esecuzione, revisione) lo danno le skill indicate nella sezione "Configurazione"; questa skill aggiunge la divisione del lavoro con Codex CLI (account ChatGPT dell'utente), il ciclo di approvazione degli asset, il passaggio di consegne quando una quota finisce e la ripresa automatica di Codex.

Rispondi nella lingua dell'utente. L'utente descrive il progetto e risponde alle domande delle skill in modo normale: non chiedergli formati di prompt particolari.

**Questa skill vale per qualsiasi progetto.** Adatta ogni regola al progetto in cui ti trovi (linguaggio, strumenti, comandi, convenzioni) invece di presumere un caso particolare. Dove scrive "GitHub" si intende il repository remoto del progetto (GitHub, GitLab, Bitbucket o altro); dove scrive "PR" vale anche per le merge request.

## Configurazione

Le scelte modificabili hanno tre livelli; per ogni voce vale il livello più specifico:
1. **Valori di partenza**: le tabelle qui sotto, che arrivano con il plugin e cambiano solo con un aggiornamento del plugin.
2. **Configurazione personale**: la skill personale `coduet-config` dell'utente, se esiste. Contiene solo le voci che l'utente ha cambiato. Caricala con il tool Skill (oppure leggine il `SKILL.md`).
3. **Configurazione del progetto**: il file `.coduet.md` del progetto, se esiste (vedi "Come si applica la configurazione").

Le scelte si cambiano solo con la skill `coduet:settings` (o su richiesta esplicita dell'utente), mai durante il lavoro di propria iniziativa. Non modificare mai i file del plugin.

### Skill per fase

| Fase | Skill da caricare con il tool Skill (in ordine) |
|---|---|
| Ideazione | `superpowers:brainstorming` |
| Piano | `superpowers:writing-plans` |
| Esecuzione dei task di Claude | `superpowers:subagent-driven-development` |
| Isolamento dei task di Codex | `superpowers:using-git-worktrees` |
| Revisione | `superpowers:requesting-code-review` |
| Verifica finale | `superpowers:verification-before-completion` |

### Verifiche aggiuntive

| Fase | Verifica |
|---|---|
| (nessuna) | |

### Parametri

| Parametro | Valore |
|---|---|
| Domanda iniziale sulla divisione con Codex | chiedi sempre |
| Soglia "lavoro piccolo" (task) sotto cui proporre di non usare Codex | 4 |
| Task Codex contemporanei, in totale su tutti i progetti | 2 |
| Ragionamento Codex predefinito | medium |
| Asset di prova per tipo prima della produzione | 2-3 |
| Rigenerazioni automatiche di un asset dopo un controllo fallito | 2 |
| Nuovi tentativi di Codex dopo una revisione negativa | 1 |
| Stima del reset quota se non noto (ore dall'errore) | 5 |
| Margine della ripresa dopo il reset (minuti) | 5 |
| Controllo di Claude dopo la ripresa | attivo, dopo 20 minuti |
| Avviso di riserva dopo la ripresa (minuti) | 40 |
| Misure del consumo del controllo di Claude | 3 |

### Come si applica la configurazione

- **Ordine**: valori di partenza, poi `coduet-config`, poi `.coduet.md`. Il file del progetto sta nella radice del progetto o, se il lavoro è su più branch, nello stesso posto del piano (vedi "Dove sta il piano"). Le voci che un livello non contiene restano quelle del livello precedente.
- **Rileggi la configurazione del progetto all'inizio di ogni fase e prima di ogni task Codex**: così le modifiche fatte con le impostazioni valgono subito, anche per una sessione già in corso. Le modifiche alla configurazione personale valgono invece dalla ricarica successiva della skill.
- **Primo utilizzo**: se la skill personale `coduet-config` non esiste, all'avvio proponi all'utente in una riga di fare la configurazione iniziale con `coduet:settings` (un paio di minuti). Se preferisce di no, prosegui con i valori di partenza.
- **Skill per fase, in tre livelli**:
  1. la skill (o le skill) indicate per quella fase, se sono installate;
  2. se una skill indicata non è disponibile (disinstallata, rinominata, mai installata), dillo all'utente in una riga e proponi di scegliere un'alternativa con `coduet:settings`; nel frattempo usa il livello 3;
  3. il **metodo base** qui sotto.
- **Più skill per la stessa fase**: usale nell'ordine indicato, una dopo l'altra. Ricorda all'utente, la prima volta, che più skill per fase consumano più quota.
- **Conflitti tra regole**: per il metodo di lavoro di Claude valgono le skill di fase. Per tutto ciò che riguarda Codex (uso solo di `codex exec`, branch `codex/<task>`, revisione prima dell'unione, segreti, registro globale, ripresa) valgono le regole di questa skill, anche se una skill di fase dice diversamente.
- **Questa skill non modifica mai altre skill**: sceglie solo quali usare.
- **Verifiche aggiuntive**: eseguile nella fase indicata, oltre a quelle previste.

### Metodo base (quando per una fase non c'è nessuna skill)

| Fase | Metodo base |
|---|---|
| Ideazione | Domande una alla volta su obiettivo, utenti, vincoli e cosa resta fuori; proponi 2-3 approcci con pro e contro; scrivi una breve specifica e falla approvare |
| Piano | Task piccoli e indipendenti, ciascuno con file coinvolti, passi, comando di verifica ed esecutore; ordinati per dipendenze; piano salvato in un file e approvato dall'utente |
| Esecuzione dei task di Claude | Un task alla volta; dopo ogni task esegui la verifica, fai un commit e aggiorna il piano |
| Isolamento dei task di Codex | `git worktree add` come descritto al Passo 5 |
| Revisione | Fa quello che chiedeva il task? I comandi di verifica passano? Nessun segreto né file di lavoro nel diff? Nessun file fuori dal perimetro? Stile coerente con il progetto? Casi limite e errori gestiti? |
| Verifica finale | Esegui tutti i comandi di verifica, controlla ogni requisito uno per uno, mostra le prove; non dichiarare finito senza prove |

## Prima di tutto: configurazione e riprese in sospeso

A ogni avvio o ripresa della skill, **per prima cosa** leggi la configurazione (valori di partenza, `coduet-config`, `.coduet.md`) e controlla che le skill di fase siano disponibili. Poi, se nel piano la riga "Codex in attesa di quota" non è "nessuno", oppure esistono file `.codex-ripresa.log` nei worktree `../<progetto>-codex-*`, applica il Passo 8.6 prima di proseguire (in una sessione cloud, che non vede i file sul PC, basati solo sullo stato scritto nel piano). Se esiste `assets/_bozze/anteprima.html` con asset in attesa di approvazione, ricordalo all'utente. Se in `docs/codex-registro.md` ci sono "Proposte per migliorare Coduet" non ancora discusse, ricordale all'utente in una riga.

## Passo preliminare: dove si trova il progetto

Codex è installato solo sul PC dell'utente. Prima di tutto:
- **Sistema operativo del PC**: Windows, macOS o Linux. I comandi di Codex sono gli stessi; cambiano script, pianificazione e avvisi (vedi Passo 8 e le note per sistema in fondo).
- **Git e repository remoto**: vedi "Progetti senza git o senza repository remoto" qui sotto.

Poi capisci in quale situazione sei:

| Situazione | Come riconoscerla | Cosa fare |
|---|---|---|
| A. Sessione sul PC, progetto già nella cartella | `codex --version` funziona e la cartella contiene il progetto (repository git) | Fai i controlli della copia locale (sotto), poi prosegui |
| B. Sessione sul PC, progetto solo su GitHub (finora sviluppato in cloud) | `codex` funziona, ma la cartella è vuota o non contiene il progetto | Scarica il progetto (sotto), poi prosegui |
| C. Sessione cloud che può avviare sessioni sul PC | Sei in un ambiente cloud (Linux) e puoi avviare una sessione sul PC dell'utente o eseguire comandi lì | Modalità ibrida (sotto) |
| D. Sessione cloud non collegata al PC | Ambiente cloud senza accesso al PC | Codex non è raggiungibile: dillo all'utente e proponi di collegare il PC o di aprire una sessione sul PC; altrimenti prosegui senza Codex |

### Regola d'oro: GitHub è la copia di riferimento

Vale quando il progetto ha un repository remoto (vedi "Progetti senza git o senza repository remoto" per gli altri casi).

- Ogni sessione, cloud o sul PC, **all'inizio** si allinea con GitHub e **alla fine** (o prima di passare il lavoro all'altra parte) invia su GitHub tutto il lavoro salvato. Non lasciare mai lavoro solo in locale o solo nel cloud quando si cambia ambiente.
- Nel piano, nella sezione "Stato e passaggio di consegne", la riga **"Copia sul PC"** indica il percorso dell'unica copia locale da usare. Il piano sta su GitHub, quindi lo vedono sia le sessioni cloud sia quelle sul PC.
- Non cancellare, spostare o sovrascrivere mai cartelle o modifiche dell'utente senza il suo ok esplicito.

### Dove sta il piano

- Se si lavora su un solo branch (o su `main`), il piano sta in quel branch.
- Se il lavoro è distribuito su più branch o PR (una per funzione), il piano **non** va messo nel branch di una singola funzione, perché le altre sessioni non lo vedrebbero. Usa un branch dedicato `coordinamento`, che contiene solo il piano e i registri: tutte le sessioni lo leggono con `git fetch` e `git show origin/coordinamento:<percorso piano>` e lo aggiornano con commit su quel branch.
- I registri del progetto (`docs/codex-registro.md`) e il file di configurazione del progetto stanno nello stesso posto del piano.
- `AGENTS.md` deve stare dove Codex lavora: proponilo all'utente come piccola PR su `main` da unire subito (senza repository remoto: un commit su `main`, con il suo ok). Finché non è unito, includi le sue regole all'inizio di ogni prompt per Codex.

### Se più PR vengono riunite in una

Se decidi (o l'utente decide) di riunire più branch o PR in una sola:
1. Chiedi prima conferma all'utente.
2. Registra nel piano quali PR confluiscono, in quale branch e perché.
3. Chiudi le PR assorbite con un commento che rimanda alla nuova.
4. Aggiorna il **branch di base** di tutti i task Codex aperti o in coda che puntavano ai branch assorbiti; i branch `codex/*` già esistenti vanno riallineati sul nuovo branch di base prima della revisione.
5. Aggiorna anche lo stato nel piano e il registro del progetto.

### Progetti senza git o senza repository remoto

- **Git con repository remoto** (GitHub, GitLab, Bitbucket...): caso normale, tutto come descritto.
- **Git senza repository remoto**: funzionano solo le situazioni A e B; la modalità ibrida (C) non è possibile, perché cloud e PC non hanno un punto in comune. Dillo all'utente e proponi di aggiungere un repository remoto se vuole lavorare anche dal cloud.
- **Nessun git**: proponi all'utente di attivarlo (`git init` e un primo commit), spiegando che serve a separare il lavoro di Codex e a tornare indietro. Solo con il suo ok. Se rifiuta: fai prima un backup della cartella, poi per ogni task Codex lavora su una copia `../<progetto>-codex-<task>`; alla fine confronta le due cartelle, rivedi le differenze e riporta tu le modifiche approvate. Niente modalità ibrida né worktree.

### File segreti e configurazioni locali

Molti progetti hanno file che non stanno nel repository: `.env`, chiavi, credenziali, configurazioni locali.
- **Riconoscili**: file di esempio (`.env.example`, `*.example`, `*.sample`), file elencati in `.gitignore`, istruzioni nel README, errori di build o test per variabili mancanti.
- **I segreti non passano mai** dalla chat, dal piano, dai prompt per Codex o da git. Se in una copia mancano, di' all'utente quali file creare e da quale esempio partire, e aspetta che li crei lui.
- Se un task ha bisogno di segreti per funzionare o per essere verificato, assegnalo a Claude nell'ambiente dove i segreti esistono, non a Codex.
- Nei prompt per Codex aggiungi: "Non leggere, stampare o modificare file di segreti o configurazioni locali (`.env` e simili)."
- Prima di ogni commit controlla che nessun file di segreti venga incluso.

### File di lavoro della skill

I file che la skill crea per sé (`.codex-prompt.md`, `.codex-esito.md`, `.codex-output*.txt`, `.codex-ripresa.log`, gli script di ripresa) non devono finire nei commit. Aggiungili a `.git/info/exclude` della copia locale: vale solo su quella copia e non modifica il progetto.

### Cercare una copia già esistente (prima di scaricare)

1. Se il piano indica già una "Copia sul PC" e quella cartella esiste, usala.
2. Altrimenti chiedi all'utente se ha già scaricato il progetto e dove. Puoi anche cercare tra le cartelle a cui hai accesso un repository con lo stesso indirizzo remoto (`git remote -v`).
3. Se trovi **più copie**, mostrale all'utente (percorso, branch, data dell'ultimo commit, modifiche non salvate) e chiedigli quale usare. Le altre non si toccano: suggerisci all'utente di archiviarle o eliminarle lui, così non si confonde.
4. Registra la copia scelta nel piano ("Copia sul PC").

### Controlli della copia locale (sempre, prima di iniziare)

Sulla copia scelta, o appena scaricata:
1. **Progetto giusto**: `git remote -v` deve puntare al repository del progetto. Se la cartella non è un repository git o punta a un altro repository, non toccarla e chiedi all'utente un'altra cartella.
2. **Modifiche non salvate** (`git status`): se ci sono, chiedi all'utente se salvarle con un commit, metterle da parte (`git stash`) o scartarle. Non scartarle mai senza un ok esplicito.
3. **Fine riga di Windows**: se `git status` mostra come modificati moltissimi file senza vere differenze, il problema sono le terminazioni di riga (CRLF). Spiegalo all'utente e imposta `git config core.autocrlf true` solo per quella copia, prima di qualsiasi commit.
4. **Branch**: controlla su quale branch è la copia. Se non è quello su cui si lavora, passa a quello giusto solo se non ci sono modifiche in sospeso.
5. **Allineamento con il remoto** (`git fetch`, poi confronta):
   - se la copia è solo indietro: `git pull`;
   - se ha commit locali non ancora sul remoto: inviali (`git push`) dopo averlo detto all'utente;
   - se è sia avanti sia indietro: `git pull --rebase`; se ci sono conflitti, risolvili tu e chiedi all'utente quando toccano scelte di progetto.
6. **Lavoro precedente di Codex**: controlla `git worktree list` e i branch `codex/*` rimasti da sessioni precedenti; gestiscili con il Passo 8.6 o con la revisione (Passo 6) prima di crearne di nuovi.
7. **Segreti e configurazioni locali**: verifica che ci siano quelli necessari (vedi sopra); se mancano, dillo all'utente.
8. **File di lavoro della skill** esclusi in `.git/info/exclude` (vedi sopra).
9. **Dipendenze**: se mancano (es. nessuna cartella `node_modules`) o sono cambiate dall'ultima volta, installale come indicato nel README.
10. **Funziona**: esegui i comandi di verifica del progetto (test, build, o quanto indicato in "Progetti senza test"). Se falliscono già prima di iniziare, dillo all'utente: non è colpa del lavoro nuovo.

### Scaricare il progetto sul PC (B, e C quando non esiste una copia)

1. Se l'utente non ha già indicato la cartella, chiedigliela. Mai cartelle di sistema, e mai una cartella che contiene già altro.
2. Se nel cloud ci sono modifiche non ancora sul remoto, falle inviare prima (push), altrimenti il PC parte da una versione vecchia.
3. Verifica `git --version`; se manca, guida l'utente a installare Git per il suo sistema.
4. `git clone <url del repository> <cartella>`. Per un repository privato, la prima volta può aprirsi il browser per l'accesso: avvisa l'utente.
5. Installa le dipendenze come indicato nel README (es. `npm install`, verificando prima `node --version`).
6. Fai i controlli della copia locale (sopra) e registra la cartella nel piano come "Copia sul PC".

### Modalità ibrida (C): il repository remoto è il canale, non i messaggi

Verificato sul campo: una sessione cloud può **avviare** una sessione sul PC e darle istruzioni solo all'avvio. Dopo non può più scriverle, e quella sessione può non comparire nella lista di Code dell'utente. Quindi:

- **Non chiedere mai all'utente di fare da tramite** (incollare compiti, rispondere a permessi, cercare la sessione sul PC o il suo terminale). L'unica azione dell'utente è approvare l'avvio della sessione sul PC.
- **Tutta la comunicazione passa dal repository remoto**: il piano (con i task Codex e i loro prompt completi) e i branch `codex/*`.
- **Flusso:**
  1. La sessione cloud scrive nel piano tutti i task `Esecutore: Codex` pronti, con prompt completo e branch di base, e fa push del piano (vedi "Dove sta il piano").
  2. Verifica che il plugin Coduet sia installato anche sul PC (altrimenti chiedi all'utente di installarlo). Avvia **una sola** sessione sul PC, nella "Copia sul PC", con questo prompt di avvio (autosufficiente):
     "Usa la skill coduet:start nel ruolo Esecutore sul PC, con la configurazione del progetto se c'è. Repository <url>, copia locale <percorso>. Il piano è <percorso del piano> sul branch <branch del piano>. Esegui tutti i task con Esecutore: Codex e stato aperto, poi fermati. Comandi di verifica del progetto: <comandi>."
  3. La sessione cloud continua il suo lavoro e ogni tanto fa `git fetch` per vedere i branch `codex/*` e lo stato nel piano; quando un task risulta pronto, lo rivede e lo unisce (Passo 6).
  4. Se servono altri task Codex, li aggiunge al piano e avvia una nuova sessione sul PC con lo stesso prompt.
- Se invece la sessione cloud ha strumenti per eseguire comandi direttamente sul PC (con tempo massimo breve), avvia Codex staccato (es. `Start-Process` in PowerShell o `nohup` in bash, output su file) e controlla periodicamente i file di esito.
- Prima di avviare la sessione sul PC, la sessione cloud invia sul remoto il proprio lavoro salvato.
- Assegna a Codex file diversi da quelli su cui sta lavorando Claude.
- La ripresa automatica (Passo 8) e il registro globale girano sul PC: li gestisce la sessione sul PC.

### Ruolo Esecutore sul PC

Quando una sessione sul PC viene avviata con il ruolo "Esecutore sul PC":
0. **Pulizia e lavoro lasciato a metà.** Rimuovi i worktree che il piano segna come da rimuovere. Se il piano o il registro globale mostrano operazioni di un Esecutore precedente rimaste aperte (task "in corso" senza esito, worktree o branch `codex/*` senza commit o senza push, righe attive nel registro globale senza un processo Codex in esecuzione), chiudile prima di tutto: completa commit e push se il lavoro è valido, altrimenti riporta il task ad "aperto"; sistema registro e stato, e scrivi nel piano cosa hai trovato e cosa hai fatto.
1. Fai i controlli della copia locale (sopra) e il Passo 1 (Codex, versione, permessi).
2. Leggi il piano dal branch indicato. Per ogni task `Esecutore: Codex` aperto, in ordine e rispettando il registro globale, segui i Passi 5 e 5-bis (controlli tecnici compresi) partendo dal branch di base del task.
3. Quando Codex finisce, lancia tu i comandi di verifica del progetto, correggi i piccoli errori, fai il commit sul branch `codex/<task>` (nel messaggio di commit riporta il riepilogo di Codex e i token usati, perché i file di lavoro non vengono inviati) e il push. Non unire nulla: l'unione la fa la sessione che ha scritto il piano, dopo la revisione.
4. Aggiorna lo stato del task nel piano (pronto per revisione, bloccato e perché, in attesa di quota) e fai push del piano.
5. Se un task richiede una decisione dell'utente, segnalo nel piano come bloccato e passa al successivo; alla fine riepiloga.
6. Quando i task sono finiti, scrivi nel piano le proposte del Passo 9 (se ce ne sono) e fermati.

## Modalità: progetto nuovo o già avviato

- **Progetto nuovo** (cartella vuota o quasi, nessun piano): segui tutti i passi.
- **Progetto già avviato** (c'è codice e/o un piano, ad esempio in `docs/` o `docs/superpowers/plans/`): salta il Passo 2. Leggi il piano più recente, il `CLAUDE.md` e lo stato del repository (`git status`, `git log -10 --oneline`). Al Passo 3 non riscrivere il piano: aggiungi la sezione "Stato e passaggio di consegne" se manca e l'etichetta `Esecutore` solo ai task non ancora completati. Se non esiste un piano, chiedi all'utente su cosa vuole lavorare e scrivilo con la skill della riga "Piano".

## Passo 0: chiedere se dividere il lavoro

Chiedi con AskUserQuestion (una sola domanda):
"Vuoi dividere il lavoro con Codex?"
- Sì, divisione completa
- Solo asset, test e documentazione
- No, faccio tutto io

Non chiedere se Codex non è raggiungibile (situazione D, oppure Codex mancante o non collegato al Passo 1): dillo in una riga e prosegui senza. Se il parametro "Domanda iniziale sulla divisione con Codex" è impostato su un valore fisso, non chiedere e applicalo, dicendolo in una riga. Se la risposta è "No", segui le fasi senza la parte Codex. Se il lavoro previsto ha meno task della soglia "lavoro piccolo", proponi "No" spiegandolo in una riga, ma lascia decidere all'utente.

## Passo 1: controllo di Codex

Esegui `codex --version` e `codex login status` sul PC (nella modalità ibrida lo fa l'Esecutore sul PC; la sessione cloud ne legge l'esito nel piano).
- Se manca o non risulta collegato, dillo all'utente e prosegui senza Codex.
- **Controllo della versione.** Questa skill è stata verificata con Codex CLI **0.163.0**. Se la versione installata è diversa, esegui `codex exec --help` e `codex exec resume --help` e controlla che esistano ancora le opzioni usate qui: `--sandbox workspace-write`, `--cd`, `-o`, `-c`, il sottocomando `resume` con ID sessione e prompt. Se qualcosa manca o è cambiato, avvisa l'utente, adatta i comandi per questa sessione e annota la differenza come proposta del Passo 9.
- Vale lo stesso per Claude Code: se uno strumento che questa skill usa (attività programmate, notifiche, esecuzione in background) non esiste più o ha cambiato nome, usa l'equivalente disponibile oppure chiedi all'utente come procedere, e annotalo come proposta del Passo 9.
- **Permessi di Claude Code**: se Claude Code chiede ogni volta il permesso per lanciare Codex, proponi all'utente di autorizzare una sola volta i comandi `codex exec` e `codex exec resume` (regola di permesso nelle impostazioni del progetto). Non autorizzare altro senza chiedere.
- La quota Codex è limitata e non si vede da qui: prima di assegnare molto lavoro a Codex chiedi all'utente quanta gliene resta (`/status` dentro Codex, oppure chatgpt.com/settings/usage), e controlla lo stato quota nel registro globale.

## Passo 2: ideazione (solo progetto nuovo)

Carica la skill della riga "Ideazione" e seguila normalmente.

## Passo 3: piano con esecutore

Carica la skill della riga "Piano" e seguila, con queste aggiunte obbligatorie.

1. In cima al piano aggiungi:

```
## Stato e passaggio di consegne
- Ultimo aggiornamento: <data e ora>
- Copia sul PC: <percorso della copia locale da usare, oppure "nessuna">
- In corso: <task>
- Prossimo passo: <cosa fare, abbastanza preciso da poter ripartire senza contesto>
- Codex in esecuzione: <task, cartella worktree e ID sessione, oppure "nessuno">
- Codex in attesa di quota: <task, ID sessione, ora di ripresa, ora del controllo di Claude, comando manuale, oppure "nessuno">
- Asset in attesa di approvazione: <elenco, oppure "nessuno">
```

2. Ogni task riceve una riga `**Esecutore:** Claude` oppure `**Esecutore:** Codex`.

Criteri di assegnazione:
- **Claude**: architettura, logica di dominio delicata, sicurezza (autenticazione, permessi, segreti, controllo degli accessi ai dati), migrazioni del database, debug difficili, integrazione, revisione finale e tutto ciò che richiede segreti o configurazioni locali.
- **Codex**: lavoro ripetitivo o meccanico che segue schemi già presenti nel codice, test, documentazione, testi e traduzioni, refactoring meccanici, asset (immagini, audio, video, 3D) e presentazioni.
- Con la risposta "Solo asset, test e documentazione" assegna a Codex soltanto quelle tre categorie.
- In caso di dubbio, il task va a Claude.

3. Ogni task di Codex indica il **branch di base** (il branch della funzione o PR su cui il lavoro dovrà essere unito, non per forza `main`) e uno **stato** (aperto, in coda, in corso, pronto per revisione, bloccato, unito). Contiene poi un **prompt per Codex** completo e autosufficiente, perché Codex non vede questa conversazione:
- obiettivo e file da creare o modificare (percorsi esatti);
- file esistenti da prendere come modello;
- vincoli del progetto;
- comandi per verificare il lavoro, presi dal progetto (`CLAUDE.md`, README, script): solo comandi rapidi che terminano da soli; escludi suite lente o che non finiscono (vedi "Progetti senza test" se non ce ne sono);
- "Non fare commit. Non modificare file fuori da quelli indicati. Non leggere, stampare o modificare file di segreti o configurazioni locali. Alla fine scrivi un riepilogo di cosa hai fatto e cosa non sei riuscito a fare."

4. **Coerenza con le decisioni prese.** Prima di affidare un prompt a Codex, e di nuovo prima di lanciarlo se è passato del tempo, confrontalo con le decisioni già prese nel progetto: piano, documenti di decisioni o specifiche, `CLAUDE.md`, `AGENTS.md`, valori scelti dall'utente in conversazione. Se il prompt li contraddice o è rimasto indietro, aggiornalo; se non è chiaro quale versione valga, chiedi all'utente.
5. Mostra all'utente la divisione dei task e chiedi conferma prima di eseguire.

## Passo 4: AGENTS.md

Se il progetto non ha un `AGENTS.md`, crealo con le regole del progetto (le stesse del `CLAUDE.md`, se esiste) più queste:
- lavora solo sui file indicati nel prompt;
- non fare commit e non cambiare branch;
- non leggere, stampare o modificare file di segreti o configurazioni locali;
- non toccare i task marcati `Esecutore: Claude`;
- se non riesci a completare il task, fermati e spiega perché invece di improvvisare.

## Passo 5: esecuzione in parallelo

Per ogni task di Codex:

**Codex si usa solo con `codex exec`, mai in modalità interattiva** (verificato sul campo: in modalità interattiva si ferma a chiedere permessi che nessuno può dare). Se un comando è fuori dai suoi permessi, con `exec` fallisce invece di bloccarsi: i test e i comandi che richiedono più permessi li lancia la sessione Claude, non Codex.

1. Crea un worktree separato partendo dal **branch di base** del task (skill della riga "Isolamento", oppure a mano):
   `git worktree add ../<progetto>-codex-<task> -b codex/<task> <branch di base>`
2. Salva il prompt del task in `<worktree>/.codex-prompt.md`.
3. Lancia Codex in background con il tool Bash (`run_in_background: true`), salvando tutto l'output:

```
codex exec --cd "<worktree>" --sandbox workspace-write -c model_reasoning_effort="<livello>" -o "<worktree>/.codex-esito.md" "<prompt per Codex>" > "<worktree>/.codex-output.txt" 2>&1
```

   - `--sandbox workspace-write` è obbligatorio: senza, Codex parte in sola lettura e non può scrivere (verificato).
   - Livello di ragionamento: `low` per compiti banali, il valore del parametro "Ragionamento Codex predefinito" di norma, `high` per compiti lunghi o complessi. Senza `-c model_reasoning_effort`, `exec` parte con ragionamento "none".
   - Aggiungi `--skip-git-repo-check` solo se la cartella non è un repository git.
   - Annota nel piano l'ID della sessione (riga `session id:` all'inizio di `.codex-output.txt`).
4. Al massimo il numero indicato dal parametro "Task Codex contemporanei" (di partenza 2), **in totale su tutti i progetti** dell'utente, perché la quota Codex è una sola: controlla e aggiorna il registro globale (vedi "Registro globale di Codex").
5. Mentre Codex lavora, esegui i task di Claude con la skill della riga "Esecuzione". Non restare in attesa.
6. Aggiorna la sezione "Stato e passaggio di consegne" a ogni traguardo, non solo alla fine.

### Registro globale di Codex (più progetti insieme)

La quota Codex è unica per tutti i progetti dell'utente. Sul PC tieni un registro condiviso in `~/.coduet/registro.md` (cartella utente; crealo se manca):
- **Task attivi**: progetto, task, worktree, ora di avvio. Aggiungi la riga quando lanci Codex e toglila quando finisce.
- **Stato quota**: se un task si ferma per limite di utilizzo, scrivi "Quota esaurita fino a <ora del reset>".
- **Prima di lanciare un task** in qualsiasi progetto: se è già raggiunto il numero di task attivi del parametro "Task Codex contemporanei", metti il task in coda nel piano; se la quota risulta esaurita, non lanciarlo e pianificalo per dopo il reset (Passo 8).
- **Alla ripresa** dopo un reset, se più progetti hanno task in attesa, riavviali a scaglioni (rispettando il parametro "Task Codex contemporanei"), nell'ordine in cui si erano fermati.
- Righe più vecchie di 24 ore senza un processo Codex attivo sono residui: verificale e toglile.
- Il registro sta sul PC: nella modalità ibrida lo legge e aggiorna la sessione sul PC.

## Passo 5-bis: asset e ciclo di approvazione

Vale per qualsiasi asset generato da Codex: immagini, sprite, icone, audio, video, modelli 3D, presentazioni. La produzione è automatica, l'approvazione è sempre dell'utente: nessun asset entra nel progetto senza il suo ok.

### Cosa sa produrre Codex

| Tipo | Come | Note |
|---|---|---|
| Immagini, sprite | Strumento integrato di generazione immagini (account ChatGPT a pagamento) | Da verificare alla prima prova. Sfondo trasparente poco affidabile: chiedi uno sfondo a tinta unita (#00FF00 di default, oppure il colore previsto dal progetto) e scontorna con uno script |
| Vettoriale, icone, interfacce | Codice SVG/HTML | Affidabile |
| Audio | Codice: sintesi sonora (es. Python che scrive WAV), MIDI | Buono per effetti retro e musica semplice; non adatto ad audio realistico |
| Video, animazioni | Fotogrammi generati via codice + ffmpeg (se installato) | Animazioni grafiche sì, video realistici no |
| Modelli 3D | Codice che scrive glTF, o script Blender (se installato) | Forme semplici e low-poly sì, modelli organici complessi no |
| Presentazioni, documenti | Codice (HTML, PPTX) | Affidabile |

Se un asset richiesto rientra nei casi "no", dillo all'utente prima di iniziare e proponi un'alternativa (stile più semplice, strumento esterno, asset di libreria).

### Prima di produrre

- **Se il progetto ha già convenzioni per gli asset** (guide, prompt, strumenti di importazione, colore di sfondo per lo scontorno, cartelle), usa quelle al posto delle indicazioni di questa skill. Cercale in `docs/`, nel README e negli script del progetto prima di creare qualsiasi cosa.
- Se manca, crea con l'utente `docs/stile-asset.md`: stile, palette, dimensioni, formati, durata e volume per l'audio, poligoni e scala per il 3D, più i riferimenti approvati.
- Parti con gli **asset di prova** indicati dal parametro (di partenza 2-3) per tipo e passa alla produzione completa solo quando l'utente approva lo stile.
- Le bozze vanno in `assets/_bozze/<asset>/v<n>.<ext>`; solo gli asset approvati vengono copiati nella cartella definitiva. Le bozze non devono arrivare nel branch di base: prima dell'unione toglile dal branch `codex/<task>` (nella modalità ibrida possono viaggiare su quel branch solo per farle vedere all'utente).
- Gli asset consumano molta quota Codex (le immagini in particolare): producili a gruppi.

### Ciclo per ogni gruppo di asset

1. **Produzione**: prompt a Codex con riferimento alla guida di stile. Come riferimento visivo allega immagini con `-i <file>`; per gli altri tipi indica nel prompt il percorso dei file di riferimento.
2. **Controllo tecnico automatico** (prima che l'utente veda nulla), per tipo:
   - immagini/sprite: dimensioni, formato, sfondo scontornabile, numero e allineamento dei frame, coerenza tra frame (guardali);
   - audio: si apre, formato e frequenza di campionamento, durata, picchi e clipping, silenzi iniziali e finali, loop senza scatti;
   - video: si apre, durata, risoluzione, fps, codec;
   - 3D: file valido, numero di poligoni, scala e orientamento, texture presenti, render di anteprima;
   - presentazioni e documenti: si aprono, impaginazione (guardali), testi.
   Se un controllo fallisce, rigenera da solo con il prompt corretto, al massimo quante volte indica il parametro "Rigenerazioni automatiche"; poi segnala il problema all'utente.
3. **Pagina di anteprima**: crea `assets/_bozze/anteprima.html` con il visualizzatore adatto a ogni tipo (immagine o GIF animata, `<audio>`, `<video>`, `<model-viewer>` per il 3D). Per ogni asset: nome, versione, pulsanti "Approvato" / "Da rigenerare", campo nota, e in fondo un pulsante "Copia esito" che produce un testo come `run_v2: ok | jump_v1: rigenera - il braccio sparisce nel frame 3`. Chiedi all'utente di aprirla e incollarti l'esito.
4. **Rigenerazione mirata**: traduci le note dell'utente in istruzioni precise. Rigenera solo ciò che serve (un frame, un'animazione, un suono), passa la versione precedente come riferimento e aggiungi la correzione al prompt cumulativo dell'asset, così l'errore non ricompare. Le rigenerazioni chieste dall'utente non hanno un limite, ma vanno contate.
5. **Approvazione**: copia la versione approvata nella cartella definitiva e, se è un buon riferimento di stile, aggiungila a `docs/stile-asset.md`.

### Registro e lavoro in autonomia

- `docs/asset-registro.md`: per ogni asset, ogni versione con prompt, esito del controllo tecnico, nota dell'utente, stato (bozza / approvato / scartato) e numero di rigenerazioni. Si può sempre tornare a una versione precedente.
- In autonomia (utente assente) produzione e controlli tecnici procedono, ma gli asset restano "in attesa di approvazione": il resto del progetto va avanti con segnaposto, e al ritorno l'utente trova la pagina di anteprima pronta.

## Passo 6: revisione e integrazione

Quando un task di Codex termina:
1. Leggi `.codex-esito.md`, `.codex-output.txt` e il diff del worktree. Aggiorna il registro globale (task non più attivo). Nella modalità ibrida questi file restano sul PC (sono esclusi dai commit): la sessione che rivede legge il riepilogo e i token che l'Esecutore ha scritto nel piano e nel messaggio di commit, più il diff del branch `codex/<task>`.
2. Se l'output contiene un errore di limite di utilizzo, vai al Passo 8. Se il task produceva asset, applica prima il ciclo del Passo 5-bis.
3. **Allinea il branch di Codex** con lo stato attuale del suo branch di base (`git fetch` e merge o rebase del branch di base su `codex/<task>`). Se ci sono conflitti, risolvili tu: Codex non risolve mai conflitti. Se il conflitto tocca scelte di progetto, chiedi all'utente.
4. Esegui i comandi di verifica del task.
5. Fai la revisione con la skill della riga "Revisione". Controlla anche che nessun file di segreti o di lavoro della skill sia nel diff.
6. Se va bene, fai il commit sul branch `codex/<task>` (se non l'ha già fatto l'Esecutore sul PC) e uniscilo **nel suo branch di base** (non in `main`, se la base è un'altra PR). Se non va bene, correggi tu oppure rilancia Codex con istruzioni più precise (al massimo quanti tentativi indica il parametro "Nuovi tentativi di Codex", poi il task passa a Claude).
7. Rimuovi il worktree: `git worktree remove ../<progetto>-codex-<task>`. Nella modalità ibrida il worktree sta sul PC: segna nel piano che va rimosso e lo rimuove l'Esecutore alla sessione successiva.
8. Aggiungi una riga a `docs/codex-registro.md`: data, task, esito, token usati (li stampa Codex alla fine).

Prima di dichiarare finito il lavoro usa la skill della riga "Verifica finale".

### Progetti senza test

Se il progetto non ha test, verifica con quello che c'è, in quest'ordine:
1. build, compilazione, typecheck, lint, se esistono;
2. prova pratica: avvia l'applicazione e controlla che parta senza errori; per interfacce web apri la pagina e guardala (screenshot) nei punti toccati dal task;
3. revisione del codice più attenta, e task di Codex più piccoli, così il diff resta leggibile.
Quando ha senso, proponi all'utente di aggiungere qualche test come parte del task. Solo con il suo ok.

## Passo 7: quota di Claude e passaggio di consegne

Nessuna delle due quote produce addebiti automatici con questa configurazione: quando finisce, il lavoro si ferma.

**Quota di Claude in esaurimento.** Non puoi vederla da solo: è l'utente a dirtelo ("chiudi e passa a Codex"), oppure lo vedi dagli avvisi di limite. Allora:
1. Fermati a un punto stabile e aggiorna "Stato e passaggio di consegne" con istruzioni dettagliate.
2. Decidi quali task aperti possono passare a Codex: solo quelli che rispettano i criteri di assegnazione a Codex. Cambia il loro esecutore in `Codex`, scrivi per ciascuno il prompt completo e il branch di base, e fai push del piano. I task delicati restano a Claude e aspettano.
3. Prepara i worktree per quei task (Passo 5) e scrivi per l'utente i comandi pronti da lanciare nel terminale, uno per task, nella forma del Passo 5 (oppure, nella modalità ibrida, avvia l'Esecutore sul PC).
4. Avvisa che il lavoro di Codex andrà rivisto da Claude alla ripresa.

**Ripresa dopo un'interruzione.** Fai il controllo delle riprese in sospeso, leggi "Stato e passaggio di consegne", controlla `git worktree list` e i branch `codex/*`, rivedi il lavoro fatto in tua assenza e solo poi continua.

## Passo 8: quota di Codex esaurita e ripresa automatica

Codex non riparte da solo quando la quota si azzera; il lavoro parziale resta nel worktree. Il sistema ha tre livelli:
1. **Ripresa** con il pianificatore del sistema operativo: gratuita, parte anche se Claude ha finito la quota.
2. **Controllo di Claude** (parametro, di partenza 20 minuti dopo): legge l'esito, avvisa l'utente, rilancia se può.
3. **Avviso di riserva** (parametro, di partenza 40 minuti dopo la ripresa): compare solo se Claude non è intervenuto e la ripresa non è riuscita.

L'utente va coinvolto solo quando Claude non può risolvere da solo. Aggiorna sempre anche lo stato quota nel registro globale.

### 8.1 Decidere

Se l'utente è presente, chiedigli se riassegnare a Claude i task Codex non completati o metterli in ripresa automatica. Se non è presente, scegli la ripresa automatica e scrivilo nel piano.

### 8.2 Orari

Ricava l'ora del reset dal messaggio d'errore in `.codex-output.txt`. Se non c'è, chiedila all'utente (`/status` in Codex). Se l'utente non è presente, usa la stima del parametro "Stima del reset quota" e scrivilo nel piano.
- Ripresa = reset + parametro "Margine della ripresa" (con più progetti in attesa, a scaglioni: vedi registro globale).
- Controllo di Claude = ripresa + il tempo indicato dal parametro (se il controllo è disattivato, salta il livello 2).
- Avviso di riserva = ripresa + parametro "Avviso di riserva".

### 8.3 Comando di ripresa (verificato)

Da dentro la cartella del worktree (la ripresa cerca le sessioni nella cartella corrente):

```
codex exec resume <SESSION_ID> -c sandbox_mode="workspace-write" -c model_reasoning_effort="<livello>" -o .codex-esito.md "Continua il task da dove ti eri fermato. Non fare commit. Alla fine scrivi un riepilogo."
```

- `<livello>` è lo stesso usato per il task (di norma il parametro "Ragionamento Codex predefinito"); negli script qui sotto sostituisci `medium` con quel valore.
- `codex exec resume` non ha `--sandbox` né `--cd`: la sandbox si imposta con `-c sandbox_mode="workspace-write"` (verificato), la cartella lanciando il comando da dentro il worktree.
- Mantiene il contesto della sessione precedente (verificato).
- Usa sempre l'ID della sessione, non `--last`, perché nel worktree potrebbero esserci più sessioni.
- Se la ripresa fallisce perché la sessione non si trova, ripiega su un nuovo `codex exec --sandbox workspace-write` nello stesso worktree, con il prompt in `.codex-prompt.md` e l'istruzione di continuare dal lavoro già presente.

### 8.4 Script e attività di Windows

Crea `<worktree>/riprendi-codex.ps1` (sostituisci i segnaposto):

```powershell
$wt = '<worktree in formato Windows>'
$task = '<nome task>'
$sessione = '<SESSION_ID>'
$log = Join-Path $wt '.codex-ripresa.log'
$out = Join-Path $wt '.codex-output-ripresa.txt'
$prompt = 'Continua il task da dove ti eri fermato. Non fare commit. Alla fine scrivi un riepilogo.'
Set-Location $wt
"$(Get-Date -Format s) AVVIO ripresa" | Add-Content $log
try {
  codex exec resume $sessione -c sandbox_mode="workspace-write" -c model_reasoning_effort="medium" -o .codex-esito.md $prompt *> $out
  $codice = $LASTEXITCODE
} catch { $codice = 1; $_ | Out-String | Add-Content $out }
$testo = Get-Content $out -Raw -ErrorAction SilentlyContinue
if ($testo -match '(?i)usage limit|rate limit|limit reached') { "$(Get-Date -Format s) LIMITE ancora raggiunto" | Add-Content $log }
elseif ($codice -ne 0) { "$(Get-Date -Format s) ERRORE codice $codice" | Add-Content $log }
else { "$(Get-Date -Format s) COMPLETATO" | Add-Content $log }
Unregister-ScheduledTask -TaskName "Codex-ripresa-$task" -Confirm:$false -ErrorAction SilentlyContinue
```

Crea `<worktree>/avviso-riserva.ps1`:

```powershell
$wt = '<worktree in formato Windows>'
$task = '<nome task>'
$sessione = '<SESSION_ID>'
$log = Join-Path $wt '.codex-ripresa.log'
$testo = Get-Content $log -Raw -ErrorAction SilentlyContinue
$manuale = "cd '$wt'; codex exec resume $sessione -c sandbox_mode=`"workspace-write`" -c model_reasoning_effort=`"medium`" -o .codex-esito.md `"Continua il task da dove ti eri fermato. Non fare commit.`""
if ($testo -notmatch 'CONTROLLO CLAUDE' -and $testo -notmatch 'COMPLETATO') {
  if (-not $testo) { $motivo = 'la ripresa non e mai partita' }
  elseif ($testo -match 'LIMITE') { $motivo = 'la quota di Codex e ancora esaurita' }
  else { $motivo = 'la ripresa ha dato errore (dettagli in .codex-output-ripresa.txt)' }
  (New-Object -ComObject WScript.Shell).Popup("Codex - $task`n`n$motivo, e Claude non e riuscito a intervenire.`n`nComando per ripartire a mano (PowerShell):`n$manuale", 0, "Codex - $task", 48) | Out-Null
}
Unregister-ScheduledTask -TaskName "Codex-riserva-$task" -Confirm:$false -ErrorAction SilentlyContinue
```

Registra le due attività (dal tool Bash: `powershell -NoProfile -Command "..."`):

```powershell
$s = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun
$a1 = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "<worktree>\riprendi-codex.ps1"'
Register-ScheduledTask -TaskName 'Codex-ripresa-<task>' -Action $a1 -Trigger (New-ScheduledTaskTrigger -Once -At '<ora ripresa>') -Settings $s
$a2 = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File "<worktree>\avviso-riserva.ps1"'
Register-ScheduledTask -TaskName 'Codex-riserva-<task>' -Action $a2 -Trigger (New-ScheduledTaskTrigger -Once -At '<ora avviso di riserva>') -Settings $s
```

- `-StartWhenAvailable`: se il PC era spento, l'attività parte appena viene riacceso.
- `-WakeToRun`: prova a risvegliare il PC dalla sospensione.
- Se la registrazione fallisce, avvisa subito l'utente nella conversazione con il comando manuale.

### 8.4-bis Script e pianificazione su macOS e Linux (non ancora provati)

Stessa logica degli script Windows, in bash:
- `riprendi-codex.sh`: entra nel worktree, scrive `AVVIO` nel log, lancia lo stesso `codex exec resume`, scrive `COMPLETATO`, `ERRORE` o `LIMITE` nel log.
- `avviso-riserva.sh`: se nel log non c'è `CONTROLLO CLAUDE` né `COMPLETATO`, mostra l'avviso con il motivo e il comando manuale.
- Pianificazione:
  - **macOS**: un LaunchAgent (`~/Library/LaunchAgents/<nome>.plist` con `StartCalendarInterval`, caricato con `launchctl load`), rimosso dopo l'esecuzione; in alternativa `at`, se attivo.
  - **Linux**: `systemd-run --user --on-calendar='<data ora>' <script>`; in alternativa `at` o una riga cron da rimuovere dopo l'esecuzione.
- Avvisi: **macOS** `osascript -e 'display dialog "<testo>"'`; **Linux** `notify-send "Codex" "<testo>"` (se manca, scrivi l'avviso in un file sul Desktop).
- Metti sempre i percorsi tra virgolette.
- Alla prima esecuzione reale verifica che tutto funzioni e annota l'esito come proposta del Passo 9.

### 8.5 Controllo di Claude

Crea un'attività programmata di Claude Code sul computer dell'utente, all'ora del controllo, usando lo strumento di pianificazione disponibile nella sessione. Non usare pianificazioni che valgono solo per la sessione corrente: devono sopravvivere alla chiusura. Se non c'è uno strumento adatto, chiedi all'utente di crearla dall'app desktop con il prompt qui sotto.

Prompt dell'attività (completo e autosufficiente):

"Progetto in <percorso progetto>. Usa la skill coduet:start, Passo 8.6, per il task Codex '<nome task>' nel worktree <worktree> (sessione <SESSION_ID>). Appena inizi scrivi in <worktree>/.codex-ripresa.log la riga '<data ora> CONTROLLO CLAUDE inizio'; alla fine '<data ora> CONTROLLO CLAUDE fine' con una breve descrizione di cosa hai fatto (solo lettura, rilancio, revisione)."

### 8.6 Cosa fa il controllo (anche all'inizio di ogni sessione)

Per ogni task in "Codex in attesa di quota", leggi `.codex-ripresa.log`:
- **`COMPLETATO`** → fai la revisione (Passo 6), svuota la riga nel piano e avvisa l'utente dell'esito.
- **`ERRORE`** → leggi `.codex-output-ripresa.txt`. Se è un problema che puoi risolvere (comando, percorso, sessione non trovata), rilancia tu Codex in background (Passo 8.3, con il ripiego se serve), aspetta l'esito e procedi. Se non puoi risolverlo, avvisa l'utente spiegando il problema; non serve che incolli comandi: basta che risponda, per esempio "sì, rilancia".
- **`LIMITE`** → la quota di Codex non è ancora tornata: ripianifica ripresa, controllo e avviso di riserva per il reset successivo, aggiorna il registro globale e avvisa l'utente.
- **Nessun `AVVIO`** con l'ora di ripresa già passata → la ripresa non è partita (PC spento o attività mancante). Controlla le attività pianificate (su Windows `Get-ScheduledTask -TaskName 'Codex-*'`), rilancia tu se possibile, poi avvisa l'utente.
- **Ora di ripresa non ancora arrivata** → ricordalo all'utente in una riga.

Per avvisare l'utente usa lo strumento di notifica disponibile nella sessione (notifica push); se non c'è, scrivi l'esito come messaggio della sessione.

### 8.7 Misura del consumo (prime volte, secondo il parametro)

L'utente vuole sapere quanto costa il controllo di Claude, per decidere se tenerlo o tornare all'avviso con comando manuale. Claude non vede la percentuale della propria quota, quindi:
- nelle prime volte in cui il controllo di Claude parte (quante ne indica il parametro "Misure del consumo"; 0 = nessuna), dopo averlo fatto comunica all'utente l'orario di inizio e fine e cosa è stato fatto, e chiedigli di confrontare la percentuale della sessione e del limite settimanale (impostazioni dell'app → Utilizzo, oppure `/usage` in Claude Code) prima e dopo quell'orario;
- annota ogni misura in `docs/codex-registro.md` (sezione "Consumo del controllo di Claude");
- dopo l'ultima misura riassumi i dati e chiedi all'utente se tenere il controllo o disattivarlo (con `coduet:settings`). Se lo disattiva, il livello 2 non si usa più: l'avviso di riserva diventa l'unico avviso e compare ogni volta che la ripresa non riesce.

## Passo 9: alla fine di ogni utilizzo, migliorare Coduet

Alla fine del lavoro (o quando l'utente chiude la sessione, o al passaggio di consegne):
1. Elenca in breve le situazioni impreviste, i comandi falliti, gli aggiramenti che hai dovuto fare e le correzioni che l'utente ti ha dato su come lavorare.
2. Per ognuna proponi una correzione, **scritta in forma generale**: valida per la maggior parte dei progetti, senza nomi, percorsi, numeri di PR o dettagli del progetto in cui è emersa. I dettagli del singolo progetto vanno nel suo `CLAUDE.md` o nella sua documentazione.
3. Distingui:
   - **scelte e valori** (skill per fase, verifiche, parametri): si cambiano con `coduet:settings`, per il progetto o nella configurazione personale;
   - **regole di lavoro**: appartengono al plugin, che non va modificato localmente. Proponi all'utente un testo pronto da inviare come segnalazione (issue) al repository del plugin, indicato nel suo `plugin.json` alla voce `repository`; se l'utente mantiene il plugin, proponigli la modifica direttamente nel repository del plugin, con un nuovo numero di versione.
4. Se non è il momento, annota le proposte in `docs/codex-registro.md`, sezione "Proposte per migliorare Coduet", e riproponile all'utilizzo successivo.

## Da verificare sul campo (quando lo verifichi, annotalo come proposta del Passo 9)

- Testo esatto dell'errore di limite di Codex e se contiene l'ora del reset.
- Generazione immagini da `codex exec`.
- Presenza di ffmpeg e Blender sul PC, se servono video o modelli 3D (`ffmpeg -version`, `blender --version`).
- Strumento disponibile in Claude Code desktop per creare attività programmate e notifiche.
- Script e pianificazione su macOS e Linux (Passo 8.4-bis).

## Note per Windows

- Codex è installato nativamente su Windows con sandbox "elevated".
- Non lanciare mai Codex in cartelle di sistema (es. `C:\Windows\System32`).
- **Percorsi con spazi o apostrofi** (es. `Lavori di Anna`, `Anna's Files`): metti sempre i percorsi tra virgolette; nelle stringhe PowerShell tra apici singoli raddoppia l'apostrofo (`'C:\...\Anna''s Files\...'`). Per cartelle nuove proponi nomi senza spazi né apostrofi.
- Evita cartelle sincronizzate (OneDrive, Desktop o Documenti se sincronizzati): rallentano e possono bloccare i file.
- Le sessioni di Codex restano salvate: si possono riprendere a mano con `codex resume <id>` e vedere con `codex agents`.

## Note per macOS e Linux

- Installazione di Codex: `curl -fsSL https://chatgpt.com/codex/install.sh | sh`, poi `codex login`.
- Non lanciare Codex in cartelle di sistema; metti sempre i percorsi tra virgolette.
- Ripresa automatica: vedi Passo 8.4-bis.
