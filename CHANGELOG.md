# Changelog

## 0.4.0

- **Più leggero**: la skill principale è un quarto di prima (circa 16 KB invece di 62 KB). Le parti usate solo in certi casi (asset, ripresa, modalità ibrida, copia locale, aggiornamenti, profili) stanno in file di riferimento caricati solo quando servono. Il testo delle skill è in inglese; Coduet risponde sempre nella lingua dell'utente.
- **Script veri invece di comandi scritti al momento**, per Windows (PowerShell) e macOS/Linux (bash): aggiornamento, controllo della copia locale, lancio e stato di Codex, pianificazione della ripresa, ripresa e avviso di riserva. Più affidabili e meno token.
- **Aggiornamento dalla chat più affidabile**: lo script aggiorna, verifica la versione prima e dopo, e se fallisce mostra il comando da incollare e salva un log.
- **Messaggi a ogni passo** (`Coduet · …`): dove sta girando e se Codex è raggiungibile, avvio e fine di ogni task Codex (file, token), revisione, quota esaurita con gli orari di ripresa, esito della ripresa, aggiornamenti.
- **Avviso quando Codex finisce**: Codex gira in background e Claude viene avvisato appena termina, senza dover controllare.
- **Registro dei task** in `~/.coduet/tasks/`, condiviso tra progetti: limite di task contemporanei rispettato in automatico, stato su richiesta.
- **Configurazione iniziale unica**: piani, skill per fase, comando `claude`, Codex e dove avviare Coduet, in un solo passaggio.
- **Collaudo guidato** `/coduet:test` ("collauda Coduet"): verifica in pochi minuti lancio di Codex, avviso di fine, asset, ripresa simulata e aggiornamenti, su un repository di prova.
- **Test automatici delle skill** (`evals/`) e **icona** del plugin.

## 0.3.0

- **Si vede quando Codex lavora**: messaggio all'avvio di ogni task, voce nella lista delle attività, aggiornamenti brevi nei task lunghi, riepilogo alla fine (esito, file, token) e stato su richiesta ("come va Codex?").
- **Avvio a parole**: Coduet si avvia anche scrivendo "avvia Coduet" o "dividiamo il lavoro con Codex", utile dove i comandi con la barra non funzionano (per esempio i thread di progetto). Lo stesso per le impostazioni ("impostazioni di Coduet").
- **Lavoro in locale**: in una sessione cloud con il PC collegato, Coduet propone di impostare la cartella locale predefinita del progetto, così i thread lavorano direttamente sul PC.
- README: come avviare Coduet nei vari contesti, quando serve una sessione nuova, come far lavorare un progetto in locale.

## 0.2.1

- Il controllo aggiornamenti si fa sempre a ogni avvio di `coduet:start` (il limite di uno al giorno resta solo per i controlli a metà sessione), così una versione pubblicata in giornata si vede subito. Su richiesta dell'utente controlla subito.
- Dopo l'aggiornamento, dove `/reload-plugins` non è disponibile (per esempio nei thread di progetto), Coduet suggerisce di aprire un thread nuovo.

## 0.2.0

- **Profili per piano**: Coduet si adatta agli abbonamenti dell'utente. `coduet:settings` chiede piano Claude e accesso a Codex (ChatGPT Free, Go, Plus, Pro, Business o chiave API) e propone i parametri adatti: task in parallelo, ragionamento, soglia di delega, asset di prova, rigenerazioni, immagini, tetto di spesa.
- Il profilo Plus coincide con i valori di sempre: chi non indica i piani non vede differenze.
- Con ChatGPT Free/Go Coduet non chiede immagini a Codex e gli affida solo task piccoli; con chiave API non pianifica riprese per quota e rispetta un tetto di spesa; con Claude Max/Team/Enterprise/API delega a Codex solo dove conviene.
- Chi usa già Coduet riceve una sola proposta di indicare i piani, in un momento stabile; le scelte fatte a mano e le impostazioni dei progetti vengono rispettate, e il lavoro già in corso non cambia.

## 0.1.2

- `coduet:start` controlla se è uscita una versione più recente di Coduet (all'avvio, all'inizio delle fasi nelle sessioni lunghe e alla fine del lavoro, al massimo una volta al giorno) e riassume le novità di tutte le versioni saltate.
- Aggiornamento dalla chat: con il tuo ok, se sul PC c'è il comando `claude`, Coduet si aggiorna da solo per tutte le sessioni; poi basta scrivere `/reload-plugins`.
- Se sul PC manca il comando `claude`, Coduet propone di installarlo (una volta sola, con il tuo ok), sistema il PATH e verifica che veda il plugin.
- README e guida: procedura di aggiornamento nell'app desktop e installazione del comando `claude`.

## 0.1.1

- `coduet:start` e `coduet:settings`: se la configurazione personale `coduet-config` può essere salvata solo sul PC (per esempio nell'app desktop), lo dice chiaramente e spiega come portarla anche nell'account, così da valere anche nelle sessioni cloud.
- README e guida: istruzioni per gli aggiornamenti nell'app desktop, dove l'aggiornamento automatico non è disponibile e si aggiorna con `/plugin marketplace update coduet`.

## 0.1.0

Prima versione pubblica.

- Skill `coduet:start`: divisione del lavoro tra Claude Code e Codex CLI, piano con esecutore e stato, esecuzione con `codex exec` in worktree separati, revisione e unione, ciclo di approvazione degli asset, passaggio di consegne, ripresa automatica (Windows verificato; macOS e Linux da provare), modalità ibrida cloud + PC, registro globale dei task Codex, gestione di segreti, progetti senza git o senza test, proposte di miglioramento a fine lavoro.
- Skill `coduet:settings`: configurazione su tre livelli (valori di partenza, configurazione personale `coduet-config`, file di progetto `.coduet.md`), con modalità completa, rapida e iniziale.
