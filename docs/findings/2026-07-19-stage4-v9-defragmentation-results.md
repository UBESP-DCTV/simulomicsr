# v9 — De-frammentazione via overlay Mistral: risultati del re-pool Stadio 4

**Data:** 2026-07-19
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Stato:** ✅ pipeline v9 END-TO-END completa (re-cluster v9-final + re-pool Stadio 4 v9).

## 0. Idea in una riga

Portare le correzioni-nome di Mistral (side-table del name-cleanup, run T13) **dentro**
il re-cluster Stadio 3 come overlay `GSM → identità`, così i frammenti della stessa
entità — prima dispersi sotto nomi-spazzatura (`STR:`/`UNK`) — **si fondono** e le
meta-analisi cross-studio nominate guadagnano potenza.

## 1. Cosa è stato fatto (Fase D, Task 11-15)

| Passo | Output | Esito |
|---|---|---|
| **Task 11** re-cluster **v9-pre** (deterministico, NO overlay) | `20260710T045849Z-stage3-v9pre-364547a7` | 317.202 cluster, cache lookup **v6**, fix STR:/CHEMBL: (0 `ChEMBL:` misto) |
| **Task 12** Mistral sui sospetti (DGX, scope **k≥2**) | side-table 7.176 record (0 fail schema) | override 3646 · keep 2972 · noop 513 · flag_review 45 · **canary 0 override** |
| **Task 13** gate + **fix canonicalizzazione kind** (TDD, commit `4daa6e7`) | `.canonicalize_overlay_kind` | `cytokine`→`cytokine_stim`, `pathogen`→`pathogen_or_aggregate_exposure`, scarta `genetic_*` non-anchor |
| **Task 14a** re-cluster **v9-final** (con overlay) | `20260717T171550Z-stage3-v9-364547a7` | 316.823 cluster, **42.773 con `LLM_NAME_CLEANUP`** (56.427 GSM corretti) |
| **Task 14b** re-pool **Stadio 4 v9** | `simulomicsr-stage4-v9/20260719T105254Z-stage4-v9-a500d032` | 631 cluster poolati, 10,9M righe, wall 2478 min |

**Pre-flight kind (Task 13, obbligatorio).** Sul side-table k≥2 (3646 override) il `new_kind`
di Mistral è vocabolario libero: 109 `cytokine` + 329 `pathogen` **grezzi** (non fanno scattare
il branch (b) di `.extract_anchor_segments` → merge mancato) e 21 `genetic_*` NON-anchor
(`genetic_mutation/variant/disorder/…` → farebbero scattare (b) iniettando un kind non-anchor →
un-bucketing). Fix: canonicalizzazione STRETTA in `.side_table_to_recovery_overlay`
(NON `.canonicalize_resolver_kind`, che mapperebbe genetic→`genetic_perturbation` non-anchor).
Suite `name-cleanup|anchor|stage3`: 1441 PASS / 0 FAIL.

## 2. Risultato centrale: la de-frammentazione avviene, senza minestroni

### 2.1 Stadio 3 v9-final: i frammenti si fondono

Confronto v9-pre (deterministico) → v9-final (con overlay), sui cluster con quel nome:

| Segnale | v9-pre | v9-final |
|---|---:|---:|
| `agent_id_resolved == UNK` | 99.076 | **69.296** (−29.780) |
| `agent_id_resolved` MeSH | 19.910 | **44.462** (+24.552) |
| `disease_vs_normal` UNK residui | 25.086 | **9.748** (−15.338) |

### 2.2 Stadio 4 v9: più meta-analisi nominate, omogeneità invariata

Re-gate (`analysis/audit/2026-07-19-stage4-v9-regate.R`, output `…-regate-out.txt`):

| Metrica | v8 | v9 |
|---|---:|---:|
| Cluster poolati (tot) | 503 | **631** |
| Righe `cluster_pooled` | 8.613.424 | **10.924.174** |
| **rem_group poolati (cluster)** | **70** | **161** (+130%) |
| Righe pooled rem_group | 1.144.842 | **2.743.484** |
| Significant FDR<0,05 (tot) | 1.121.633 | **1.233.838** |

**Omogeneità (I²) dei rem_group — il controllo anti-minestrone.** Le fusioni uniscono lo
STESSO nome (breast+breast, non malattie diverse), quindi l'I² deve restare nel range v8.
Confermato:

| I²_med quantili [0/25/50/75/100] | v8 | v9 |
|---|---|---|
| | 0 / 39,6 / 74,2 / 90,7 / 98,4 | 0 / 52 / **79,9** / 90,5 / 98,1 |

L'I² v9 è marginalmente più alto (mediana 79,9 vs 74,2) — atteso: più studi per entità = più
eterogeneità biologica **reale** tra studi della stessa malattia, non un mix di entità diverse.
**Nessuna esplosione dell'I²**: gli estremi (0 e ~98) e la coda alta (Q75 ~90) sono identici a v8.
Le fusioni sono meta-analisi coerenti, non minestroni.

### 2.3 Bandiera (7/7) + nuove entità

Tutte le meta-analisi bandiera del v8 sono presenti tra i rem_group v9, più nuove entità
emerse dalla de-frammentazione:

| Entità | n. cluster rem_group | k_eff (studi poolati) | I²_med | n_sig max |
|---|---:|---|---|---:|
| SARS-CoV-2 (NCBITaxon:2697049) | 2 | 3–18 | 60–90 | 2368 |
| enzalutamide (CHEBI:68534) | 1 | 26 | 96 | 1920 |
| M. tuberculosis (NCBITaxon:1773) | 1 | 25 | 91 | 1559 |
| hepatocellular carcinoma (MeSH:D006528) | 4 | 5–26 | 76–96 | 1528 |
| prostate cancer (MeSH:D011471) | 4 | 3–19 | 76–93 | 595 |
| breast cancer (MeSH:D001943) | 3 | 6–22 | 80–96 | 995 |
| fulvestrant (CHEBI:31638) | 1 | 5 | 82 | 518 |
| tamoxifen (CHEBI:41774) | 1 | 5 | 92 | 437 |
| colorectal (MeSH:D015179) | 1 | 17 | 83 | 348 |
| LPS (CHEBI:16412) | 2 | 4–5 | 58–89 | 3823 |
| vemurafenib (CHEBI:63637) | 1 | 3 | 0 | 19 |

## 3. Limite onesto: `k_effective` << studi-membri del cluster (L7)

La de-frammentazione aumenta il **pool** di studi per entità, ma il **k_effective** realmente
poolato resta molto minore. Esempio breast cancer (MeSH:D001943):

- cluster Stadio 3 `group_L4_5d10ee81` "Breast Neoplasms" = **277 studi-membri** (2359 campioni);
- poolato come rem_group con **k_eff = 22** studi distinti.

Il divario 277→22 è dovuto a (a) collapse-by-study (bracci multipli intra-studio → 1) e
soprattutto (b) il **gate di controllo interno**: gli studi treated-only senza controllo nello
stesso studio cadono (**limite L7**, `project_paper_known_limitations`, chiuso 2026-07-09 come
non recuperabile in modo difendibile). La de-frammentazione porta breast rem_group da **k=6 (v8)
a k_eff=22 (v9)** — un guadagno reale di potenza, ma il collo di bottiglia resta il disegno
sperimentale degli studi sorgente, non il name-recovery.

## 4. Verifiche di robustezza

- **Anti-stale** (re-pool non riusa output vecchio): `Methods = mega, mega_aug, rem, rem_group`;
  631 processati ≠ 503 v8; by_method rem_group 2.743.484 righe ≠ v8. Cache counts
  (method-independent) riusata by-design; il ramo rem_group è sempre eseguito.
- **0 crash df-residui** sul full run (fix `0c41848` validato di nuovo).
- **Canary safety**: 0 canary con `override` nel side-table (nessun falso allarme).
- **Fix casing/target** (Fase A) materializzati: 0 `ChEMBL:` misto, 0 `HGNC:<raw>` non-numerico.

## 5. Deliverable / artefatti

- Re-cluster v9-final: `analysis/p4-output/20260717T171550Z-stage3-v9-364547a7/` (gitignored).
- Re-pool v9: `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v9/20260719T105254Z-stage4-v9-a500d032/`
  (`cluster_pooled.parquet` 429 MB, `per_study_de.parquet` 1,9 GB, `run_metadata.json`).
- Re-gate: `analysis/audit/2026-07-19-stage4-v9-regate.R` +
  `-remgroup-processed.csv` + `-regate-out.txt`.
- Side-table Mistral v9: `analysis/p4-output/name-cleanup-side-table-v1.rds`;
  triage k≥2 `analysis/audit/2026-07-09-stage4-popB-coherence-triage-v9-k2.csv`.

## 6. Prossimo

Layer B (case-study publication-grade) sui nuovi 161 rem_group nominati = **plan separato a valle**
(non parte di questo closeout). Master invariato.
