# Changelog

## 0.1.1

- `coduet:start` e `coduet:settings`: se la configurazione personale `coduet-config` può essere salvata solo sul PC (per esempio nell'app desktop), lo dice chiaramente e spiega come portarla anche nell'account, così da valere anche nelle sessioni cloud.
- README e guida: istruzioni per gli aggiornamenti nell'app desktop, dove l'aggiornamento automatico non è disponibile e si aggiorna con `/plugin marketplace update coduet`.

## 0.1.0

Prima versione pubblica.

- Skill `coduet:start`: divisione del lavoro tra Claude Code e Codex CLI, piano con esecutore e stato, esecuzione con `codex exec` in worktree separati, revisione e unione, ciclo di approvazione degli asset, passaggio di consegne, ripresa automatica (Windows verificato; macOS e Linux da provare), modalità ibrida cloud + PC, registro globale dei task Codex, gestione di segreti, progetti senza git o senza test, proposte di miglioramento a fine lavoro.
- Skill `coduet:settings`: configurazione su tre livelli (valori di partenza, configurazione personale `coduet-config`, file di progetto `.coduet.md`), con modalità completa, rapida e iniziale.
