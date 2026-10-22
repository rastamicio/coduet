# Changelog

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
