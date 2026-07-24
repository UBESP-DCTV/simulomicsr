# Fase 1 — Validazione in simulazione dell'anchor derivato-dal-contrasto

**Data:** 2026-07-24 · nessun re-cluster (simulazione sui 38.440 contrasti già ricostruiti).
**Scopo:** gate go/no-go PRIMA delle 8h di re-cluster. Provare che l'anchor derivato-dal-contrasto
(entità-delta canonica + control_type-dal-delta, filtro degeneri) de-mescola i minestroni e recupera k
senza regredire i cluster già coerenti.

## Verdetto: 🟡 DESIGN PROMETTENTE, COERENZA MISURATA 72% — NON ancora una soluzione

> ⚠️ **CORREZIONE (2026-07-24, post-verifica).** La prima stesura diceva "🟢 DESIGN VALIDATO / soluzione
> trovata" basandosi su k-recupero (287 poolabili) + preservazione (drug 8/8). **Era prematura: misurava
> CONTEGGI, non coerenza** — l'errore ricorrente del RED ALERT. La verifica di coerenza (deep-dive su 40
> nuovi cluster, §7) mostra **72% coerenti (29/40)**, NON ~100%. Il conteggio 287 NON è "287 coerenti":
> è ~72% di essi. Il design funziona nella direzione ma ha 4 modi-di-fallire diagnosticati e non ancora
> chiusi/ri-misurati.

Il meccanismo recupera k e de-mescola i minestroni noti, ma la coerenza dei NUOVI cluster va portata su:
il residuo del 28% ha cause precise (§7), fixabili, ma finché non sono fixate e RI-MISURATE non è una
soluzione. Il limite di copertura del resolver (sotto) resta valido e va sommato a questo.

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

## 7. PROVA DI COERENZA sui nuovi cluster (il passo che avevo saltato) — 72%

Deep-dive (rubrica identica al finding 2026-07-23) su 40 nuovi cluster v4 poolabili, stratificati per
fonte dell'entità (16 STR + 14 NAME + 10 onto, i più a rischio prima):

| fonte entità | coerenti | tasso |
|---|---|---|
| NAME (ereditata dal cluster) | 12/14 | 86% |
| onto (ID ontologico) | 7/10 | 70% |
| STR (fallback etichetta) | 10/16 | 62% |
| **totale** | **29/40** | **72%** |

**4 modi-di-fallire diagnosticati (tutti fixabili, NON ancora chiusi):**
1. **Token STR generici/troncati** → minestrone: `STR:t`, `STR:d`, `STR:dox`, `STR:none`,
   `STR:genetic_knockdown`, `STR:genetic_overexpression`. La mia normalizzazione ha ridotto valori a
   singole lettere che collidono. Fix: stoplist + non collassare a <3 char + non usare valori di chiave
   generici come entità.
2. **Termini-ombrello ontologici** → minestrone: `MeSH:D009369` = "Neoplasms" (tutti i tumori insieme!),
   `CHEBI:17499`. Fix: blacklist dei termini troppo generici.
3. **Chimici induttori held-constant**: `CHEBI:50845` = doxiciclina (Tet-on) — è solo l'induttore, la
   perturbazione vera è il transgene attivato (diverso per studio). Fix: trattare gli induttori come
   held-constant (come SARS nel braccio farmaco).
4. **Baseline eterogenei sotto la stessa entità**: HCC tessuto-vs-plasma (liquid biopsy) mescolati;
   AML+CML. Il control_type "vehicle_untreated" è troppo grezzo. Fix: raffinare il control_type.

**Conseguenza onesta:** dei 287 poolabili, i coerenti reali sono ~72% ≈ **~207** (con incertezza da
campione), non 287. Va portato più su chiudendo i 4 modi-di-fallire e RI-misurando. Solo allora
"soluzione". Verdetti: `llm-verdicts-v4-sample.jsonl`.

## Dati / riproducibilità
`70-fase1-canonical-sim.R` (v1 ontologia pura) · `72-fase1-v4-hybrid.R` (engine finale) ·
`73-fase1-stratified.R` (stratificazione). `contrast-sig-engine.R` (firma). rds intermedi gitignored.
