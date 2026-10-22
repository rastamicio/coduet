---
name: settings
description: Usa quando l'utente vuole vedere o cambiare le impostazioni di Coduet (skill per fase, verifiche aggiuntive, parametri), per la configurazione iniziale, o per salvarle per un progetto o nella sua configurazione personale.
---

# Coduet: settings

Questa skill (parte del plugin Coduet) serve solo a vedere e modificare la configurazione usata da `coduet:start`. **Non contiene logica di lavoro**: non avvia task, non tocca il codice del progetto, non interferisce con il lavoro in corso, non modifica mai i file del plugin né altre skill.

Rispondi nella lingua dell'utente, con frasi semplici.

## I tre livelli della configurazione

Per ogni voce vale il livello più specifico:
1. **Valori di partenza**: la sezione "Configurazione" della skill `coduet:start`, dentro il plugin. Si leggono, non si modificano: cambiano solo con un aggiornamento del plugin.
2. **Configurazione personale**: la skill personale `coduet-config` dell'utente. Se è salvata nel suo account la vedono sia le sessioni sul PC sia quelle cloud; se è salvata solo sul PC (`~/.claude/skills/coduet-config/SKILL.md`) la vedono solo le sessioni su quel PC. Contiene solo le voci che l'utente ha cambiato rispetto ai valori di partenza.
3. **Configurazione del progetto**: il file `.coduet.md` del progetto, nella radice oppure, se il lavoro è su più branch, nello stesso posto del piano (branch `coordinamento`). Contiene solo le voci che il progetto cambia.

## Modalità

- **Completa** (l'utente chiede di vedere o rivedere le impostazioni): segui tutti i passi.
- **Rapida** (l'utente chiede una modifica precisa, per esempio "metti 3 task Codex"): mostra solo quella voce, valore attuale e nuovo, e vai al Passo 6.
- **Configurazione iniziale** (la skill `coduet-config` non esiste, o la richiama `coduet:start` al primo utilizzo): fai il Passo 3 (skill per fase); chiedi se vuole vedere anche verifiche aggiuntive e parametri (risposta proposta: no, valori di partenza); poi salva nella configurazione personale.

## Passo 1: leggere

Leggi i valori di partenza (sezione "Configurazione" di `coduet:start`), la skill `coduet-config` se esiste (caricala con il tool Skill o leggine il `SKILL.md`) e, se sei in un progetto, il file `.coduet.md`. Leggi anche l'elenco delle skill installate con nome e descrizione.

## Passo 2: mostrare

Mostra un riepilogo breve, in tabelle, con il valore in uso per ogni voce e da quale livello viene:
- skill per fase, segnando quelle non installate;
- verifiche aggiuntive;
- parametri.

## Passo 3: skill per fase

Per ogni fase (Ideazione, Piano, Esecuzione dei task di Claude, Isolamento dei task di Codex, Revisione, Verifica finale):
1. Trova tra le skill installate quelle adatte a quella fase, leggendone nome e descrizione.
2. Chiedi con AskUserQuestion, con scelta multipla: la skill attuale (se installata) proposta per prima, poi le alternative trovate (al massimo 3; l'utente può scriverne un'altra), poi "Nessuna: metodo base". Raggruppa più fasi nella stessa chiamata (al massimo 4 domande per volta).
3. Se l'utente sceglie più skill per la stessa fase, chiedigli l'ordine e avvisalo che più skill per fase consumano più quota.
4. Se una fase ha una sola opzione ovvia, proponila già come prima scelta, così basta confermare.

## Passo 4: verifiche aggiuntive

Chiedi se vuole aggiungere controlli che Coduet non fa di suo. Proponi esempi adatti al progetto (accessibilità, prestazioni, sicurezza delle dipendenze, testi e traduzioni, comportamento su telefono, licenze degli asset, privacy) più la possibilità di scriverne uno suo. Per ognuno chiedi in quale fase farlo (di solito Revisione o Verifica finale). Permetti anche di togliere verifiche esistenti.

## Passo 5: parametri

Mostra la tabella dei parametri con una spiegazione di una riga ciascuno e chiedi quali cambiare. Controlla che i valori abbiano senso e spiega l'effetto delle scelte rischiose, per esempio:
- più task Codex contemporanei consumano la quota più in fretta (valori sensati: 1-4);
- disattivare il controllo di Claude lascia solo l'avviso di riserva;
- 0 rigenerazioni automatiche significa che ogni asset difettoso arriva all'utente.

## Passo 6: salvare

Mostra il riepilogo delle modifiche (valore vecchio, valore nuovo) e chiedi con AskUserQuestion:
- **Salva per questo progetto**: scrivi o aggiorna `.coduet.md` con le sole voci cambiate. Mettilo dove lo vedono tutte le sessioni del progetto (radice, oppure branch `coordinamento` se il lavoro è su più branch) e invialo sul repository remoto. Le sessioni in corso lo applicano dall'inizio della fase successiva.
- **Salva nella mia configurazione personale**: scrivi la versione completa aggiornata della skill personale `coduet-config` (nuova se non esiste, aggiornamento se esiste), usando il modello qui sotto. Vale dalle prossime sessioni in tutti i progetti, tranne per le voci che un progetto cambia nel suo `.coduet.md`; per una sessione già in corso, dai all'utente il prompt per ricaricare `coduet:start`. Dove salvarla:
  - **Nell'account**, se la sessione ha uno strumento per proporre o salvare skill nell'account dell'utente: usalo. Così vale ovunque, sul PC e nel cloud.
  - **Solo sul PC**, se quello strumento non c'è (per esempio nell'app desktop): scrivi il file `~/.claude/skills/coduet-config/SKILL.md`. Poi **dillo chiaramente all'utente**: questa configurazione la vedono solo le sessioni su questo PC; le sessioni cloud e gli altri computer usano i valori di partenza. Se le scelte salvate differiscono dai valori di partenza e l'utente lavora anche nel cloud, spiegagli che può aggiungere la stessa skill al suo account dalle impostazioni dell'app (sezione delle skill), caricando quel file o creando una skill `coduet-config` con lo stesso contenuto, e che dopo ogni modifica dovrà aggiornare anche quella copia. Se le scelte coincidono con i valori di partenza, basta dirgli che per ora nel cloud non cambia nulla.
  - Se esistono **due copie** (account e PC), aggiorna quella che stai usando e ricorda all'utente di allineare l'altra.
- **Annulla**: non cambiare niente.

Se l'utente sceglie "per questo progetto" ma non sei in un progetto, diglielo e proponi le altre due opzioni.

### Modello della skill personale `coduet-config`

```markdown
---
name: coduet-config
description: Configurazione personale del plugin Coduet. Non va usata da sola: la leggono coduet:start e coduet:settings.
---

# Configurazione personale di Coduet

Ultimo aggiornamento: <data>. Contiene solo le voci diverse dai valori di partenza del plugin; per le altre valgono quelli.

## Skill per fase

| Fase | Skill (in ordine) |
|---|---|
| <fase> | <skill> |

## Verifiche aggiuntive

| Fase | Verifica |
|---|---|
| <fase> | <verifica> |

## Parametri

| Parametro | Valore |
|---|---|
| <parametro> | <valore> |
```

Togli le sezioni vuote. Se dopo una modifica una voce torna uguale al valore di partenza, toglila.

## Regole

- Non cambiare nulla senza la scelta esplicita del Passo 6.
- Non modificare i file del plugin né le regole di lavoro di `coduet:start`: se l'utente chiede di cambiare come funziona Coduet (non solo scelte e valori), spiegagli che è una modifica al plugin e proponigli un testo pronto da inviare come segnalazione al repository del plugin (indicato nel suo `plugin.json` alla voce `repository`).
- Non modificare altre skill: puoi solo scegliere quali usare.
- Se nel progetto c'è un lavoro in corso, non toccarlo: di' solo da quando varranno le modifiche.
