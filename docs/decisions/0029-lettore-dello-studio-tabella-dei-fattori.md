# ADR-0029: Il lettore dello studio — il modello scrive la tabella dei fattori, i confronti seguono da una definizione

- **Status:** Accepted (disegno approvato dal PI il 2026-11-09), **con cancello**: la misura contro Expression Atlas
  sui due insiemi di giudizio (spec §5.5) prima della corsa su tutti gli studi. Se il cancello non passa, questo ADR
  torna `Proposed`
- **Date:** 2026-11-09
- **Deciders:** Luca Vedovelli (PI); proposta di Claude dopo la prova cieca S12p e la sua diagnosi
- **Supersedes:** ADR-0028 (Stadio 2b, il giudice a valle); per gli Stadi 1 e 2, ADR-0020 (Stadio 2 per condizioni)
  quando il cancello passa
- **Superseded by:** —

## Il problema

Il 24,9% dei confronti del deliverable (473 su 1.903) non confronta bracci confrontabili. La diagnosi di S12p dice
dove nasce il difetto: in 240 casi lo Stadio 2 aveva la differenza nei fatti e ha costruito il confronto lo stesso,
in 139 lo Stadio 1 ha letto la differenza e non l'ha scritta. Un giudice a valle (ADR-0028) non ha passato il suo
cancello con nessun modello. Il PI rifiuta le pezze e le catene di regole che sostituiscono il modello, e chiede che
il modello veda quello che gli serve, anche in un passo solo.

## Le forze

- Nessuna soglia di errore accettata: ogni causa si corregge dove nasce.
- Nessun Claude nella pipeline e nella validazione pubblicata. Pipeline deterministica dopo il modello.
- Nessun curatore umano disponibile: il riferimento deve essere esterno e già esistente.
- La tesi dell'articolo: un modello locale mette ordine nei metadati di GEO e trova i confronti confrontabili.
- I 1.903 confronti del deliverable non sono più ciechi: servono allo sviluppo, non al giudizio.

## Le opzioni

1. **Correggere il prompt dello Stadio 2** (bracci uguali tranne il trattamento, niente tempo zero come controllo).
   Tocca metà dei difetti. Lo Stadio 2 continua a ricevere fatti in cui manca la differenza per tre difetti su dieci.
2. **Correggere Stadio 1 e Stadio 2 in fila.** Due cicli di calcolo e di misura, e il confronto resta una scelta del
   modello caso per caso.
3. **Tenere il giudice a valle con un modello più grande.** Il cancello di ADR-0028 è fallito con tre modelli, e le
   istruzioni non vincolano il giudizio.
4. **Un lettore per studio che scrive la tabella dei fattori (scelta).** Il modello legge il testo dello studio e la
   tabella dei campioni in una chiamata, e scrive ruoli delle colonne, fattori, livelli, livello di base e
   assegnazione. Un costruttore deterministico forma i confronti da una definizione sola.

## La decisione

Opzione 4. La definizione: due gruppi dello stesso studio sono un confronto se sono uguali in tutti i fattori tranne
uno, e in quel fattore uno dei due è al livello di base. «Uguali» vale anche per i soggetti (donatore, sesso, età,
passaggio), confrontati come insiemi. Il modello non sceglie confronti e non scrive identificativi di ontologia. Il
disegno completo è `docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md`.

**Cancello.** Riferimento esterno: la curazione di Expression Atlas su 129 studi del bacino, divisi in sviluppo (47),
giudizio A (42) e giudizio B (40). Misure: gruppi uguali a quelli dei curatori, confronti dei curatori ritrovati,
confronti non elencati giudicati con i fattori dei curatori. Termine di paragone: le stesse misure sul master S14
dello Stadio 2. Due aperture (A, poi B) prima della corsa su tutti gli studi.

## Le conseguenze

- Lo Stadio 2b (ADR-0028) esce dal piano. Il suo codice (`R/stage2b-*.R`) resta: `.s2b_norm_testo()` e il percorso
  di lancio servono al lettore.
- Gli Stadi 1 e 2 di oggi restano come termine di paragone. I master S14 e il deliverable v16 non si toccano.
- Restano Stadio 0, Stadio 3, Stadio 4 (meta-analisi a effetti casuali), dizionari, strumenti di audit.
- Le due decisioni aperte di S12p (i 280 difetti nel riferimento, dove correggere per primo) sono superate: i
  1.903 confronti letti diventano materiale di sviluppo, e la correzione è la sostituzione dei due stadi.
- Servono i testi GEO dello studio per tutti i 24.393 studi (oggi 993).
- Rischio principale: gli studi molto grandi rispetto al contesto del modello. Si misura, non si taglia.
- Una prova piccola e da buttare precede ogni codice del lettore nel pacchetto (spec §5.6).

## Aggiornamento 2026-11-10 (decisioni del PI dopo la prova S12r)

La prova da buttare sui 47 studi di sviluppo non ha soddisfatto la regola di esito (spec §5.6): il lettore v0 non fa
meglio della pipeline di oggi (`docs/findings/2026-11-09-S12r-prova-lettore-studio.md`). Il PI ha deciso («ok a
tutto», sulle due raccomandazioni dell'agente):

1. **La decisione di questo ADR resta.** Si corregge lo schema e si ripete la prova sugli stessi 47 studi, con
   Mistral e con uno o due modelli più grandi (spec §5.7), con previsioni nuove depositate prima (sessione S12r2).
   Il lettore non entra nel pacchetto prima di quella prova. Gli 82 studi di giudizio restano chiusi.
2. **Il riferimento del cancello cambia.** I confronti di Expression Atlas che usano il tempo zero come controllo
   escono dal riferimento, perché per il PI il tempo zero come controllo è sempre un errore. La regola che li
   riconosce si scrive prima della prova, per costruzione e non per elenco. La misura sul riferimento intero si
   riporta sempre accanto.

## Aggiornamento 2026-11-11 (decisioni del PI dopo la prova ripetuta S12r2)

La prova ripetuta ha migliorato le misure (gruppi identici ad Atlas 31/47 contro 14/47 di oggi, confronti
ritrovati 50/97 contro 13/97) ma la regola di esito dà no: 13 studi non chiudono contro la soglia depositata di 7
(`docs/findings/2026-11-10-S12r2-prova-ripetuta-lettore-studio.md`). Il PI ha deciso, sulle tre raccomandazioni
dell'agente:

1. **Il modello del lettore è Mistral-Small 3.2**, quello di produzione (2026-11-10). Mistral-Small-4-119B fa
   peggio e non è ripetibile.
2. **Qwen3.5-122B non si riprova** e i suoi pesi sono cancellati dal DGX (2026-11-10).
3. **Prima del Piano 2 si fa una terza prova piccola** sugli stessi 47 studi di sviluppo (sessione S12r3,
   2026-11-11): lo schema delle uscite strutturate si genera per ogni studio dalla tabella dei campioni, con
   colonne e valori a elenco chiuso e una voce per ogni valore distinto. Il modello decide ancora fattori, ruoli,
   livelli e livello di base. Il lettore non entra nel pacchetto prima di quella prova. Gli 82 studi di giudizio
   restano chiusi.

## Aggiornamento 2026-11-11 (decisione del PI nella terza prova piccola, S12r3)

**Il confronto fra due contesti esce dal riferimento del cancello.** Per il costruttore un fattore di contesto
(tipo cellulare, linea cellulare, tessuto) non ha livello di base. I curatori di Atlas confrontano anche due
tipi cellulari: 2 confronti su 97 nei 47 studi di sviluppo (`GSE75852`), che il lettore non può formare con
nessuno schema. Opzioni portate dall'agente: (1) il riferimento resta e quei confronti contano come non
ritrovati; (2) escono dal riferimento con una regola scritta prima, per nome del fattore di Atlas (`cell type`,
`cell line`, `organism part`), e la misura senza la regola si riporta accanto; (3) il contesto può avere una
base quando il testo la dichiara. **Il PI ha scelto la (2)**: una meta-analisi ha come entità un agente, una
malattia o un gene, e la (3) cambia due cose nella stessa prova. La regola vale per ogni misura contro Atlas da
qui in avanti, cancello compreso (spec §5.5, aggiornamento S12r3).

## Link

- Spec: `docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md`
- Piano: `docs/superpowers/plans/2026-11-09-lettore-studio-tabella-dei-fattori-plan.md` (+ `-HUMANE.md`)
- Finding di partenza: `docs/findings/2026-11-08-S12p-prova-cieca-stadio2b.md` (§14)
- Evidenza esplorativa: `analysis/audit/2026-11-09-lettore-studio/`
