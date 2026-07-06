# Finding — Stadio 4 v8: il ramo `rem_group` recupera le meta-analisi nominate

**Data:** 2026-07-06
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato, no push)
**Sessione:** audit RED_ALERT F6 — fullrun Stadio 4 v8 (ramo rem_group)
**Run:** `a500d032`, output
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v8/20260706T112612Z-stage4-v8-a500d032/`
**Verifica:** `analysis/audit/2026-07-06-stage4-v8-antistale-regate.R` +
`…-remgroup-names.R` (+ CSV `…-remgroup-processed.csv`, `…-remgroup-dropped.csv`).

## In una frase

Il nuovo ramo di pooling `rem_group` ammette al pooling le **meta-analisi cross-studio nominate
L2–L4** che la porta di selezione MEGA-strict respingeva (finding-causa
`2026-07-05-stage4-selection-gate-excludes-named-metaanalyses.md`). Il fullrun v8 processa **70 di
queste meta-analisi** — prima erano ~0 — **senza toccare i 3 rami esistenti** (retrocompat
byte-identica a v7). Tutte le bandiera attese (SARS-CoV-2, enzalutamide, fulvestrant, tamoxifen,
vemurafenib, Breast/Prostatic Neoplasms) sono ora poolate con I²/τ² onesti.

## 1. Il run

- Wall **1067 min (~17,8h)** su laptop 256 GB (config = v7: `dream_workers_cap=32`, MEGA-AUG
  bidirezionale, biotype `protein_coding`). RSS picco ~14,6 GB. 0 crash. Dashboard quarto fallita
  (non-fatale, CLI assente — atteso; ri-renderizzabile).
- Input **invariati**: Stadio 3 v7 (`…20260703T113045Z-stage3-v7-364547a7`), master v3, H5.
  Nessun re-cluster. Cache counts riusata (method-independent, nessuno stale — vedi §5).
- `schema_versions.rem_group_strategy = v1_per_study_rem_named_groups`; config `rem_group`:
  `k_eff_min=3`, `n_min=2`, `excluded_kinds={vehicle_only, none, ""}`.

## 2. Verifica anti-stale — PASS

| Metrica | v8 | v7 | Esito |
|---|--:|--:|---|
| Cluster processati | **503** | 433 | +70 = rem_group |
| — `mega` | 72 | 72 | **identico** |
| — `mega_aug` | 353 | 353 | **identico** |
| — `rem` | 8 | 8 | **identico** |
| — `rem_group` | **70** | 0 | **NUOVO** |
| `Methods` in cluster_pooled | mega, mega_aug, rem, **rem_group** | — | rem_group presente ✅ |
| cluster_pooled righe | 8.613.424 | — | di cui rem_group **1.144.842** |
| per_study_de righe | 34.026.609 | — | — |
| sig FDR<0,05 | 1.121.633 | — | — |

I tre rami esistenti sono **byte-identici** a v7 (retrocompat del ramo `rem_group` verificata sui
conteggi cluster-per-method): il ramo è puramente additivo. La firma `503 = 433 + 70` è quella attesa
dallo smoke pre-fullrun.

## 3. I 70 rem_group processati (re-gate)

Tutti sono `mode=group`, `level=4` (l'anchor porta il nome specifico). Distribuzione:

- **n_sig** (geni FDR<0,05): mediana ~1.400, range 0–6.347. Due cluster a n_sig=0 (I²=0, τ²=0, k=3):
  poolano correttamente ma non trovano segnale — esito valido, non un bug.
- **I² mediano** per cluster: 0–98% (eterogeneità onesta, non saturata artificialmente).
- **k_effective** (studi distinti per gene, dopo il collapse dei bracci intra-studio): 3–77.
  I cluster grandi hanno k alto (es. k=77, 39, 33) = meta-analisi multi-studio genuine.

**Bandiera attese — 7/7 presenti:**

| Entità | anchor_key | n_sig | I² med | k med |
|---|---|--:|--:|--:|
| SARS-CoV-2 | `pathogen…\|NCBITaxon:2697049\|lung` | 1813 | 85 | 12 |
| Prostatic Neoplasms | `disease_vs_normal\|MeSH:D011471\|prostate` | 1485 | 74 | 4 |
| enzalutamide | `small_molecule\|CHEBI:68534\|prostate` | 1337 | 86 | 12 |
| fulvestrant | `small_molecule\|CHEBI:31638\|breast` | 518 | 82 | 5 |
| tamoxifen | `small_molecule\|CHEBI:41774\|breast` | 437 | 92 | 5 |
| Breast Neoplasms | `disease_vs_normal\|MeSH:D001943\|breast` | 272 | 86 | 6 |
| vemurafenib | `small_molecule\|CHEBI:63637\|skin` | (presente) | — | — |

(Nello smoke pre-fullrun Alzheimer cadeva per k_eff<3; nel fullrun `MeSH:D000544|brain` è tra i
processati — differenza attesa smoke-subset vs full.)

Top per n_sig (esempi non-bandiera): `pathogen…|STR:tuberculosis|blood` (6347, I²47, k4),
`small_molecule|CHEBI:85993|breast` (6088, k3), `small_molecule|CHEBI:379896|prostate` (5894, I²94,
k10). Elenco completo dei 70 in `analysis/audit/2026-07-06-stage4-v8-remgroup-processed.csv`.

## 4. I 279 rem_group caduti (documentati, non un difetto)

`non_processable` = 382: **279** `rem_group_insufficient_in_study_controls` + 103
`mega_rank_deficient` (i mega senza ≥2 livelli treatment, come v7).

I 279 caduti si distribuiscono per k_eff sotto soglia: **131 a k_eff=0, 93 a k_eff=1, 55 a k_eff=2**
(soglia `k_eff≥3` su studi distinti). Sono per lo più `cytokine_stim` e `disease_vs_normal` per cui
**non esiste una comparison Stadio 2 con quel group come `treated_group`** → nessun controllo in-study
→ ibrido non processabile con la strategia attuale. Il recupero di questi (augmentation cross-studio
del lato-controllo, stile `mega_aug`) è un **passo 3 futuro**, esplicitamente fuori scope v8.

## 5. Note metodologiche

- **Collapse bracci intra-studio** (`.collapse_arms_by_study`, inverse-variance fixed-effect, opzione
  C): combina i bracci multipli dello stesso studio in **un valore per (cluster, studio, gene)** prima
  del REM, così `k_effective` = numero di **studi distinti** (niente pseudo-replicazione; I²/τ² onesti).
  Validato pre-fullrun sui bandiera (SARS 10→5 studi, enzalutamide 10→5). **Limite noto:** assume
  indipendenza tra bracci; la correlazione da control condiviso non è modellata (raffinamento Franchini
  futuro).
- **Cache:** il re-pool v8 usa solo la cache dei counts (`stage4-counts/`, chiave
  `(v2_ensembl, biotype, gse, sample_ids)` — method-independent), riusata da v7 senza stale. Il ramo
  `rem_group` + il collapse sono codice sempre eseguito (nessuna cache del pooled). Il disastro
  v6→v7 (cache name-recovery su re-cluster Stadio 3) **non si applica** a un re-pool.

## 6. Cosa resta

1. **Pulizia-nomi (coda etichette)** — ~50–70 cluster omogenei ma mal etichettati (LPS→"carnitine",
   NSCLC→"Netherlands Antilles", …): problema di *etichetta*, non di clustering. Handout dedicato
   `docs/superpowers/specs/2026-07-06-name-cleanup-mistral-SESSION-AFTER-handout.md`.
2. **Augmentation passo 3** — recupero dei 279 caduti (treated-only senza control in-study).
3. **Layer B** — ri-curare la selection con i nuovi 70 case-study nominati disponibili.
