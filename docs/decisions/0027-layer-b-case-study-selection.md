# ADR-0027: Quali case study vanno nel paper

- **Status:** Accepted
- **Date:** 2026-07-30
- **Deciders:** lucavd (decisione esplicita), Claude (proposta e misure)
- **Supersedes:** la selezione Layer B del 2026-05-24 (15 case study) e quella v10 del 2026-07-23
  (18 case study), entrambe costruite su cluster poi risultati incoerenti
- **Superseded by:** —

## Context and Problem Statement

Il deliverable poolato (re-pool v13, 2026-07-30) contiene **191 meta-analisi**, di cui 185 coerenti.
Il Layer B genera per ogni gruppo un bundle di figure publication-grade; la macchina esiste
(ADR-0017) e costa ~12 minuti. La domanda non è tecnica ma editoriale: **quante e quali** meta-analisi
mostrare nel paper.

Le due selezioni precedenti (15 case study nel maggio 2026, 18 nel luglio) sono state costruite su
cluster che la verifica di coerenza ha poi bocciato — la vetrina v10 era 0/9 sui flagship. Questa è
la prima selezione fatta **dopo** che la coerenza è stata misurata e la biologia verificata.

Il paper è metodologico: i case study servono a dimostrare che la pipeline produce biologia vera,
non a fare scoperte. Il criterio è quindi **la forza della dimostrazione**, non il numero.

## Decision

**Main paper: 2 figure, 3 gruppi.**

1. **DHT contro enzalutamide nella stessa figura.** `CHEBI:16330` (agonista del recettore
   androgenico, k=23) e `CHEBI:68534` (antagonista, k=19) sono due gruppi costruiti
   indipendentemente da studi diversi, e danno effetti di **segno opposto sugli stessi quattro
   bersagli** — KLK3 (+2,27 / −1,60), TMPRSS2 (+1,78 / −0,92), FKBP5 (+2,32 / −1,22), NKX3-1
   (+1,37 / −1,24). È controllo positivo e negativo in una figura sola, e nessun difetto strutturale
   può produrlo per caso.
2. **Un solo caso ad alto k**, con forest plot e I²: TGF-β1 (`HGNC:11766`, k=49) **oppure** LPS
   (`CHEBI:16412`, k=35). Serve a mostrare che cosa guadagna il pooling cross-studio.

**Supplementari: 5-6, scelti per copertura di tipo, non per bellezza.**

- un patogeno — SARS-CoV-2 (`NCBITaxon:2697049`, k=33);
- una citochina — IFN-γ (`HGNC:5438`, k=19, effetti molto grandi: CXCL9 +11,17, IDO1 +9,76);
- una malattia — Parkinson (`MeSH:D010300`, k=10) o carcinoma epatocellulare (`MeSH:D006528`, k=10);
- un farmaco oncologico — JQ1 (`CHEBI:137113`, k=24, 9.501 geni significativi);
- **almeno uno dei 6 gruppi dichiarati incoerenti**, mostrato come esempio di ciò che il metodo
  dichiara invece di nascondere.

## Decision Drivers

- **La coppia agonista/antagonista vale più di tre casi separati**: è l'unica evidenza che nessuna
  pipeline concorrente mostra, e verifica la *direzione* dell'effetto, non solo la sua presenza.
- **Un paper che mostra solo successi è meno credibile di uno che mostra dove il metodo si ferma**:
  da qui l'obbligo di un gruppo incoerente nei supplementari.
- I supplementari coprono i **tipi** di perturbazione che la pipeline gestisce (patogeno, citochina,
  malattia, farmaco), non i gruppi con i numeri più belli.

## Considered Options

1. **3 gruppi nel main.** Respinta: il terzo non aggiunge un'evidenza di natura diversa, e diluisce.
2. **Solo casi "vincenti".** Respinta per il motivo di credibilità sopra.
3. **Selezione automatica per punteggio** (come lo shortlist del 2026-05-24). Respinta: quel metodo
   ha prodotto le due vetrine poi ritrattate, perché ordinava per potenza e non per coerenza.

## Consequences

### Positive

- La figura principale è una **verifica**, non una vetrina: chi legge può controllare il segno.
- I limiti del metodo entrano nel paper come materiale, non come nota a piè di pagina.

### Negative / rischi dichiarati

- I gruppi scelti hanno I² fra 94 e 100: gli studi concordano sul **segno** ma non sulla
  **magnitudine**, e questo va scritto accanto alle figure, non omesso.
- Restano fuori 180 meta-analisi che nessuno guarderà una per una: la loro qualità poggia sul
  censimento e sul controllo strutturale, non su un'ispezione visiva.

### Neutre

- La decisione non tocca il codice né richiede run pesanti.

## Validation

Il Layer B va eseguito su questa selezione e i bundle vanno **guardati**, non solo generati: il
forest dice se un gruppo da 49 studi è dominato da due, la heatmap se i campioni si separano per
studio invece che per trattamento, il GO se le vie sono quelle attese. Se emerge una di queste cose,
è un finding e va riportato — anche se costringe a cambiare questa selezione.

## Links

- Handout operativo: `docs/superpowers/specs/2026-07-31-layer-b-NEXT-SESSION-HANDOUT.md`
- Risultati del re-pool e controllo biologico: `docs/findings/2026-07-30-repool-v13-risultati.md`
- Deliverable annotato: `analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.csv`
- Macchina Layer B: ADR-0017
- Selezione del ramo del deliverable: ADR-0026
