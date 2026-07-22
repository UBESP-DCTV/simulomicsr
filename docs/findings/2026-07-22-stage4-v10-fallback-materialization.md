# v10 — Materializzazione dell'LLM-fallback finale: risultati del re-pool Stadio 4

**Data:** 2026-07-22
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Stato:** ✅ pipeline v10 END-TO-END completa (re-cluster Stadio 3 v10 + re-pool Stadio 4 v10).

## 0. Idea in una riga

Dopo il v9 (de-frammentazione via overlay Mistral sui sospetti k≥2), restava una coda
di **158.751 cluster indeterminati** (`agent_id_resolved` = `UNK`/`STR:`, il 50% del
corpus). Il v10 chiude la coda: **LLM-fallback finale su TUTTI gli indeterminati** (non
un campione) → side-table completa → secondo overlay nel re-cluster → re-pool. Risultato:
le meta-analisi cross-studio nominate (rem_group) crescono **161 → 184** e le bandiera
guadagnano potenza (breast k_eff 22→30, colorectal 18→27, hepatocellular 28→34,
enzalutamide 27→30), **senza degradare l'omogeneità**.

## 1. Cosa è stato fatto

| Passo | Output | Esito |
|---|---|---|
| **1-2 Funnel + indeterminati** | `analysis/audit/2026-07-19-v9-*` | 158.751 indeterminati (50% dei cluster); **96% sono k=1** (frammenti mono-studio) |
| **3 Fallback Mistral (DGX)** | side-table 113.475 record | **override 50.246 (44,3%)**, keep 62.578, 100% valid_schema, **canary 0 override** |
| **4 Simulazione impatto** | `2026-07-19-v9-fallback-impact-*` | 79% override isolati (rumore k=1); 21% si fondono (2.706 in esistenti, 2.301 nuove) |
| **4-bis (C) Guadagno poolabile** | `2026-07-20-v9-fallback-poolable-gain.*` | riproduce il gate rem_group: **+22 nuove, +41 rafforzate, +151 k_eff** (validato: breast 23≈22 v9) |
| **5 Gate** | — | decisione utente **A — materializzare** |
| **v10 re-cluster** | `20260720T180625Z-stage3-v10-364547a7` | 2 overlay (v9 56.427 + fallback 43.185 GSM), wall 7,6h, disease UNK 9.748→6.276 |
| **v10 re-pool** | `simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032` | 714 cluster, wall 50,6h, ANTI-STALE PASS |

## 2. Il fallback: recupero alto, ma dominato dai frammenti k=1

Run Mistral su **113.475** indeterminati STR:/UNK (DGX poddgx02, 34 min, 100% valid_schema):
**override 50.246 (44,3%)**, keep 62.578 (55,2%), noop 496, flag_review 155; **0 override
sugli 871 canary** (precision-gate integro). new_id: MeSH 22.375, CHEBI 12.378,
NCBITaxon 7.975, HGNC 7.518. **Ma il 99,7% degli override è su cluster k=1** — l'upside
dipende interamente dalla coalescenza (molti frammenti che convergono sullo stesso anchor).

## 3. Risultato centrale: rem_group 161 → 184, omogeneità invariata

Re-gate (`analysis/audit/2026-07-20-stage4-v10-regate.R`, out `-regate-out.txt`):

| Metrica | v8 | v9 | **v10** |
|---|---:|---:|---:|
| Cluster poolati (tot) | 503 | 631 | **714** |
| Righe `cluster_pooled` | 8,6M | 10,9M | **12,4M** |
| **rem_group poolati (cluster)** | 70 | 161 | **184** |
| Righe pooled rem_group | 1,14M | 2,74M | **3,14M** |
| Significant FDR<0,05 (tot) | 1,12M | 1,23M | **1,45M** |

**Omogeneità (I²) — il controllo anti-minestrone (PASSA):**

| I²_med quantili [0/25/50/75/100] | v9 | v10 |
|---|---|---|
| | 0 / 52 / **79,9** / 90,5 / 98,1 | 0 / 58 / **77,6** / 90,1 / 98,1 |

L'I² v10 (mediana 77,6) è **leggermente più basso** di v9 (79,9), range identico [0–98,1].
Nessuna esplosione: le fusioni uniscono lo STESSO nome (breast+breast), non nomi diversi →
**meta-analisi coerenti, non minestroni**.

## 4. Validazione: la simulazione (opzione C) ha predetto il risultato reale

Il punto metodologicamente più forte: l'analisi di guadagno poolabile (passo 4-bis, che
riproduce il gate rem_group senza re-pool) ha **predetto** i k_eff materializzati entro ±1-3
(lo scarto è l'over-stima da salto-filtro-H5, dichiarata a priori come upper bound):

| Entità | C-sim predetto | v10 reale | v9 |
|---|---:|---:|---:|
| breast (MeSH:D001943) | 30 | **30** | 22 |
| colorectal (MeSH:D015179) | 28 | **27** | 18 |
| hepatocellular (MeSH:D006528) | 37 | **34** | 28 |
| enzalutamide (CHEBI:68534) | 32 | **30** | 27 |
| SARS-CoV-2 (NCBITaxon:2697049) | 21 | **20** | 19 |
| M. tuberculosis (NCBITaxon:1773) | 26 | **26** | 25 |

Bandiera tutte presenti tra i rem_group v10 (enzalutamide n_sig 3193, SARS 1646, breast,
prostate, tamoxifen k_eff 8, fulvestrant 8, vemurafenib, hepatocellular n_sig 3576,
colorectal 1037, LPS 3823). k_eff massimo dei rem_group v10 = 58.

## 5. Limite onesto (invariato dal v9): L7 e il rumore k=1

- **79% degli override (39.906) restano k=1 isolati**: rinominati correttamente (etichetta
  migliore nel catalogo) ma non poolabili — valore cosmetico, non di pooling.
- **71 entità nominate restano NON poolabili** (k_eff<3): il gate di controllo interno
  (treated-only, **limite L7**, `project_stage4_borrowed_controls_rejected`) morde ancora
  gli studi senza contrasto in-study. La de-frammentazione non lo aggira.
- Il guadagno reale (+23 rem_group cluster, +151 k_eff sul corpus) si concentra nelle
  entità che HANNO controlli interni — le bandiera, che infatti crescono.

## 6. Verifiche di robustezza

- **ANTI-STALE PASS**: `Methods = mega, mega_aug, rem, rem_group`; 714 processati ≠ 631 v9;
  rem_group 3.136.676 righe ≠ v9 2.743.484. Cache counts (method-independent) riusata by-design.
- **Config uniformity**: run_metadata v10 identico a v9 (de_engine dream, rem_group_strategy
  `v1_per_study_rem_named_groups`, max_baseline_per_arm, biotype protein_coding).
- **De-frag predetta = reale** (Stadio 3): breast 326 vs 325 predetto, colorectal 170 vs 167,
  hepatocell 191 vs 190.
- Dashboard quarto fallita (non-fatale, binario assente).

## 7. Deliverable / artefatti

- Re-cluster v10: `analysis/p4-output/20260720T180625Z-stage3-v10-364547a7/` (gitignored).
- Re-pool v10: `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032/`
  (`cluster_pooled.parquet` 489 MB, `per_study_de.parquet` 2,2 GB, `run_metadata.json`).
- Side-table fallback: `analysis/p4-output/name-cleanup-fallback-side-table.rds`.
- Script: `analysis/p5-name-cleanup-fallback-run.R`, `analysis/p4-fase-f8-stage3-v10-final.R`,
  `analysis/p4-fase-f5-stage4-layer-a-rebuild-v10.R`.
- Analisi: `analysis/audit/2026-07-19-v9-*` (funnel/impatto), `2026-07-20-v9-fallback-poolable-gain.*`,
  `2026-07-20-stage4-v10-regate.*` + `-remgroup-processed.csv`.

## 8. Prossimo

Layer B (case-study publication-grade) sui **184 rem_group nominati** (23 nuovi rispetto a v9)
= plan separato a valle. Master invariato.
