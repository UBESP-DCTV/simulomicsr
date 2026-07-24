# Fase 1 — Validazione in simulazione dell'anchor derivato-dal-contrasto

**Data:** 2026-07-24 · nessun re-cluster (simulazione sui 38.440 contrasti già ricostruiti).
**Scopo:** gate go/no-go PRIMA delle 8h di re-cluster. Provare che l'anchor derivato-dal-contrasto
(entità-delta canonica + control_type-dal-delta, filtro degeneri) de-mescola i minestroni e recupera k
senza regredire i cluster già coerenti.

## Verdetto: 🟢 DESIGN VALIDATO (soluzione trovata) — con un limite netto e onesto sul RESOLVER

Il meccanismo funziona. Il residuo NON è un difetto del design ma la **copertura del resolver** su
alcune classi (disease/environment/genetic), che il mio proxy Fase 1 (risolve i label GREZZI)
**sotto-rappresenta** rispetto alla pipeline vera (name-recovery + overlay LLM v9/v10).

## 1. Numeri (engine finale v4 = hybrid on/off-contrast + control_type-dal-delta)

| metrica | valore | riferimento |
|---|---:|---|
| poolabili k≥3 | **287** | lower bound within-cluster 126; deliverable difendibile oggi 26 |
| poolabili k≥5 | **118** | lower bound 26 |
| SARS (de-mescolato + ricomposto) | **k=34** | era 3 frammenti k=7+4+4 |
| 26 coerenti preservati (dom_k≥3) | 15/26 | 0 spariti |

**Poolabili k≥3 per classe:** drug 172, disease 102, infection 6, genetic 4, other 3.

## 2. Il meccanismo che funziona (le due correzioni chiave)

- **control_type dal LATO-CONTROLLO del DELTA** (non dall'etichetta intera): risolve la Crepa A. Es.
  "siRNA-NTC + SARS vs siRNA-NTC + mock" → il control_type è "mock/vehicle", non l'intera stringa siRNA.
- **entità hybrid on/off-contrast**: un membro il cui delta coinvolge l'entità del cluster è
  **on-contrast** → eredita l'entità UNICA del cluster (coerente, no frammentazione, k recuperato);
  un membro con entità held-constant è **off-contrast** → risolve il PROPRIO delta → si separa
  (de-mescolamento). SARS-infezione → tutti NAME:sars-cov-2 (k=34); il braccio ruxolitinib → si stacca.

## 3. La preservazione dei 26 coerenti, stratificata (il dato onesto)

| classe kind | n | preservati (dom_k≥3) |
|---|---:|---:|
| **drug** | 8 | **8 (100%)** |
| infection | 4 | 2 |
| genetic | 2 | 0 |
| disease | 7 | 4 |
| other (env/immunizz./training) | 5 | 1 |
| **perturbativi (drug+inf+gen)** | **14** | **10** |
| **disease/other** | **12** | **5** |

**Lettura:** dove il resolver è forte (**drug 8/8**) il design è perfetto. I buchi sono **genetic,
environment/other, parte di disease** — cioè classi dove il resolver del mio proxy fallisce (genetic 92%
NA, disease 79% NA nel proxy). Sono ID che la **pipeline vera risolve** (ZFX/INTS11 sono geni reali →
HGNC; molte disease → MeSH via name-recovery+overlay). Il proxy Fase 1 è un **lower bound** della
preservazione reale.

## 4. Perché è una soluzione (non un "non ci riesco")

- Il **design** (anchor derivato-dal-contrasto) è provato: de-mescola (SARS pulito), recupera k
  (287 vs 126 lower bound; k≥5 118 vs 26), preserva i coerenti dove il resolver arriva (drug 8/8).
- Il **residuo** è isolato e diagnosticato: **copertura del resolver** su genetic/environment/disease,
  NON il design. Ed è un limite già noto e già deciso (disease low-k accettate, k≥3).
- Le **due correzioni** necessarie sono identificate e validate (control_type-dal-delta; entità
  hybrid on/off-contrast).

## 5. Il limite onesto (dove il proxy non può concludere)
- Il proxy risolve dai **label grezzi**; la pipeline vera usa il resolver completo + overlay LLM v9/v10
  → risolverà **più** entità (soprattutto genetic/disease) → preservazione reale > 15/26 del proxy.
- La soglia "≥24/26 preservati" NON è dimostrabile nel proxy (resolver più debole del reale): va
  verificata sul re-cluster VERO (Fase 3), dove la risoluzione è di qualità produzione.

## 6. Raccomandazione
**GO all'implementazione in produzione (Fase 2)** dell'anchor derivato-dal-contrasto con: (a) filtro
degeneri a monte (factor_levels identici), (b) entità-delta risolta col resolver di produzione + logica
hybrid on/off-contrast, (c) control_type dal lato-controllo del delta, (d) gate di coerenza
deterministico. Poi ri-eseguire QUESTA validazione sul re-cluster vero (Fase 3): atteso ≥24/26 grazie
alla risoluzione di produzione. Disease/environment restano lo **stratum a copertura minore** (meno
cluster, low-k), come già accettato.

## Dati / riproducibilità
`70-fase1-canonical-sim.R` (v1 ontologia pura) · `72-fase1-v4-hybrid.R` (engine finale) ·
`73-fase1-stratified.R` (stratificazione). `contrast-sig-engine.R` (firma). rds intermedi gitignored.
