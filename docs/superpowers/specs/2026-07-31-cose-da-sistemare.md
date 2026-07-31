# Cose da sistemare — stato al 2026-07-31, dopo il Layer B v13

**Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Suite:** 3952 PASS / 3 FAIL / 3 ERROR / 37 SKIP — tutti e sei i problemi sono **pre-esistenti**
(§4) e nessuno tocca il codice modificato il 30-31/07.

Ogni voce è stata **verificata sul codice o sui file prodotti**, non presa da un elenco vecchio.

---

## 1. BUG che sporcano un deliverable già prodotto

### 1.1 `k_effective` è per-gene, tre punti lo usano come se fosse del cluster

`k_effective` in `cluster_pooled.parquet` ha un valore **per ogni gene** (un gene assente in alcuni
studi ha meno studi che contribuiscono). Tre punti ne pescano uno arbitrario:

| file | riga | effetto |
|---|---|---|
| `R/layer-b-summary-card.R` | 37 · `unique(cp_c$k_effective)[1L]` | il `k_effective` stampato sulla scheda del case study |
| `R/layer-b-selection.R` | 110 · `dplyr::first(k_effective)` | la tabella di pre-validazione stampata prima del build |
| `R/layer-b-plot-forest.R` | 163-164 · `unique(top_genes$k_effective)[1L]` | il `k=` nella didascalia del forest |

**Misurato sui 9 bundle prodotti: 4 schede su 9 riportano un k sbagliato.**

| case study | scheda | vero |
|---|---:|---:|
| IL1A | 3 | **4** |
| Parkinson | 9 | **10** |
| SARS-CoV-2 | 32 | **33** |
| JQ1 | 22 | **24** |

Il valore giusto è `max(k_effective)` sul cluster intero — è lo stesso criterio usato dal deliverable
(`60-deliverable-annotato.R`) e dal filtro di copertura scritto ieri. **Non è un difetto introdotto
il 30-31/07**: c'era da prima, ma nessuno aveva confrontato la scheda col deliverable.

*Costo:* ~30 min con TDD + 6 min di rebuild dei 9 bundle.

### 1.2 La summary card non mostra l'efficacia del pooling

Le colonne nuove (`k_kish`, `frazione_efficace`, `quota_top1`, `dominato`, `studio_dominante`,
`materiale_misto`, `dominato_da_modello`) stanno nel deliverable ma **non nella scheda che finisce
accanto alla figura**. Chi legge un case study vede `k_effective: 10` per Parkinson e non vede che
gli studi efficaci sono 1,8 e che il 73% del peso viene da un modello cellulare.

*Costo:* ~1 h (la scheda va anche alimentata: `.build_summary_card` oggi non riceve queste misure).

---

## 2. INTEGRAZIONE: il codice nuovo non è nella pipeline

### 2.1 Le due misure girano solo negli script di audit

`compute_pooling_effectiveness()` e `detect_mixed_material()` **non sono richiamate da nessun file
della pipeline** (verificato con grep su `R/` e `analysis/*.R`). Sono state applicate a mano in
`analysis/audit/2026-07-31-layer-b-v13/130-deliverable-arricchito.R`.

Conseguenza: **un re-pool futuro produrrebbe di nuovo un deliverable senza `k_kish`.** Vanno
innestate in `build_stage4_results()` (o in un passo di annotazione dichiarato a valle, come è stato
fatto per la coerenza con `R/stage4-coherence-annotation.R`).

*Costo:* ~2-3 h con TDD, più la decisione su dove innestarle.

### 2.2 `compute_pooling_effectiveness()` è lenta

**612 secondi** sui 32,4 milioni di righe di `per_study_de`. È scritta in R base
(`split`/`aggregate`/`vapply`). Funziona ed è testata (38 test), ma se entra nella pipeline conviene
riscriverne il cuore con `data.table` o `dplyr` su Arrow.

*Costo:* ~1-2 h. I test esistenti fanno da rete: la riscrittura deve lasciarli verdi.

---

## 3. MINORE

### 3.1 Le etichette del volcano non deduplicano per simbolo

Tabella e heatmap passano da `.rank_and_dedup_genes()`, il volcano no
(`R/layer-b-plot-volcano.R`): lo stesso simbolo su più ID Ensembl può comparire due volte fra le 15
etichette. È cosmetico — sono etichette su uno scatter, non righe di una tabella.

*Costo:* ~15 min.

---

## 4. PRE-ESISTENTI, non regressioni

| test | causa |
|---|---|
| `test-smoke-e2e-stage1.R`, `test-smoke-e2e-stage2.R` | chiamano l'API OpenAI, `OPENAI_API_KEY` assente |
| `test-stage4-dashboard.R` | binario `quarto` assente (stesso motivo per cui il render fallisce a ogni run pesante) |
| `test-stage4-gene-axis.R` (`E2 T2.4`) | tracciato in CLAUDE.md da fine maggio |

Nessuno di questi blocca nulla. Vanno però **dichiarati**, non trascinati in silenzio.

---

## 5. NON è codice: decisioni dell'utente

- **Regola «entità con un gruppo proprio»** (IL-1α contro IL-1β): chiuderebbe 1 gruppo incoerente su
  191. Costo **~9 h di re-cluster + ~28 h di re-pool**. Da riaprire solo se se ne accumulano altri
  della stessa famiglia.
- **Regole di riga su passaggio / visita / etnia / sede anatomica**: non coperte, servirebbe un
  vocabolario. La sessione del 30/07 aveva concluso che un rilevatore improvvisato lì costa più di
  quanto renda; il 31/07 ne ho scritto uno *dichiarato* per il solo asse materiale, con l'accordo
  umano misurato (19/20). Se si vuole estendere, va fatto con lo stesso metodo.
- **Verdetti di coerenza**: non toccati. Cambiarli richiede una regola applicata a tutti e 305 e un
  nuovo censimento, non correzioni mirate.

---

## 6. NON è codice: contenuto che manca al paper

- Le **narrative** dei 9 bundle (`narrative.qmd`, sezioni «Biological context / Findings /
  Discussion» sono segnaposto voluti).
- I **Methods**: il materiale è già scritto nei finding — i 114 gruppi scartati dal gate, i 6
  incoerenti col motivo, TGF-β1 spezzato in tre, l'ID sbagliato dell'acido lipoteicoico, la
  dominanza (55% dei gruppi), il meccanismo per cui il gate dei controlli interni **può concentrare
  l'errore invece di diluirlo**, e la proprietà del REM per cui l'ordinamento per FDR premia i geni
  consistenti e non quelli grandi.
