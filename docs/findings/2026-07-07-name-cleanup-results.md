# Name-cleanup (scope A) — fix resolver citochine + full run T13

**Data:** 2026-07-07
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Commit:** `36756ac` (fix resolver), `d6587c8` (fix current_ids full-run)
**Feature:** name-cleanup Mistral, path batch DGX (spec/plan `docs/superpowers/{specs,plans}/2026-07-06-name-cleanup-mistral-*`)

## Sintesi

Lo smoke del 2026-07-07 (job 29665) aveva mostrato che **Mistral era
semanticamente 13/13 corretto** ma il **resolver ontologico deterministico**
mancava le citochine full-name (Recall 69,2%, canary false-alarm 1/4). Due fix
mirati (resolver + un difetto dello script full-run) hanno portato lo smoke a
**13/13 recall, 0 false-alarm**, e il full run T13 su **193 cluster (125
candidate + 68 canary)** a metriche affidabili: **83 override, 65 noop, 14
flag_review, 31 keep**.

## Causa radice #1 — resolver citochine (`.resolve_canonical_to_id`)

Confermata sui dizionari reali (non ipotesi):

1. **Vocabolario `kind` libero di Mistral.** Lo schema `name_cleanup.v1.json`
   ha `kind: {type: string}` senza enum: Mistral emette `"cytokine"`,
   `"pathogen"`, `"vehicle_control"`… che NON matchano gli enum dello `switch`
   del resolver → dispatch nel **catch-all** `list(try_chebi, try_mesh,
   try_hgnc, try_taxon)` dove **MeSH precede HGNC** → `"interferon beta"` →
   `MeSH:D016899` invece di `HGNC:IFNB1`, `"TNF-alpha"` → `MeSH:D014409`.
2. **I full-name non sono symbol HGNC.** `"interleukin-6"` ≠ `IL6` → miss anche
   col dispatch giusto.
3. **Variante ortografica ChEBI.** `"17-beta-estradiol"` non matcha l'alias
   `"17β-estradiol"` (CHEBI:16469).

### Fix (TDD, precision-gated, commit `36756ac`)

- `.canonicalize_resolver_kind`: allinea il vocabolario libero agli enum
  (`cytokine`→`cytokine_stim`, `pathogen`→`pathogen_or_aggregate_exposure`,
  `vehicle_control`→`vehicle_only`, + varianti di formato di enum canonici).
- `try_cytokine` nel ramo `cytokine_stim`: lookup **WHOLE-STRING**
  ImmPort/HGNC/UniProt sul nome intero + gate whitelist citochine
  (`.is_cytokine_symbol`). **NON** usa `.normalize_cytokine_to_hgnc`
  (name-recovery Stadio 3) perché quella spezza la stringa in token: la review
  adversariale ha trovato che il token-stealing darebbe override **spuri**
  (`"IL-6 receptor"` = IL6R → `HGNC:IL6`). Il resolver è precision-gated e il
  nome è già canonicalizzato dall'LLM → match sul nome intero.
- `.normalize_greek_stereo`: 2º tentativo in `try_chebi`
  (`"17-beta-estradiol"`→`"17β-estradiol"`), ancorato a una cifra e
  ri-validato su ChEBI (nessun falso positivo; `"beta-estradiol"` già risolto
  resta intatto).

**Verifica:** 45 test resolve (0 fail) + end-to-end sui dizionari reali 19/19
(5 casi fixati, 10 non-regressione, 4 leak-guard → NONE).

## Causa radice #2 — `current_ids` full-run (`p5-name-cleanup-run.R`)

Lo script full-run costruiva `current_ids = s3$clusters$anchor_key`
(stringa completa `kind|ID|tissue|…`), ma `.apply_name_cleanup_policy`
confronta l'ID corrente col `resolved_id` **ontologico** del resolver →
`identical()` sempre FALSE → **noop mai raggiunto** → override/flag_review
gonfiati: **48/62** flag_review e **17/100** override erano *noop mascherati*
(ID ontologico già identico). Nello smoke non emergeva perché lì
`current_ids = .resolve_canonical_to_id(current_label)$resolved_id` (ID puro).

### Fix (commit `d6587c8`)

`current_ids = extract_anchor_summary(anchor_key, level, mode)$agent_id`
(level/mode dedotti dal `cluster_id` `group_L<n>_…`). Estrazione validata: 0 NA
su 193.

## Risultati

### Smoke (gate, sulle stesse predictions job 29665, resolver fixato)

| Metrica | Pre-fix | Post-fix |
|---|---:|---:|
| Recall (mislabel recuperati) | 69,2% (9/13) | **100,0% (13/13)** |
| Precision (override giusti) | 81,8% | **100,0%** |
| Canary false-alarm | 25% (1/4) | **0,0% (0/4)** |

Gate `recall≥70% && false_alarm==0` → **PASS**.

### Full run T13 (job 29670, 193 record, wall 1m31s, 193/193 valid_schema)

| Azione | Pre-fix current_ids | Corretto |
|---|---:|---:|
| override | 100 | **83** |
| noop | 0 | **65** |
| flag_review | 62 | **14** |
| keep | 31 | **31** |

- **83 override** = correzioni genuine di cluster mal-etichettati (composti
  oscuri → disease/drug/gene). Distribuzione new_id: CHEBI 34, HGNC 13, MeSH 36.
- **65 noop** = già corretti (48 canary concordi + 17 candidate).
- **14 flag_review** = disaccordi NON applicati (review umana): mix di (a)
  mismatch di formato HGNC numero-vs-symbol (`KRAS` HGNC:6407 vs HGNC:KRAS,
  `SF3B1`, `TP53` — stesso gene, falso disaccordo), (b) Mistral più specifico
  (Leukemia→AML, Liver Neoplasms→HCC), (c) vere riclassificazioni
  (estradiol→Promegestone, JQ1).
- **31 keep** = resolver NONE: gap di copertura (Infliximab anticorpo non in
  ChEBI, `glioblastoma` non risolto via MeSH, varianti genetiche
  `EGFR exon 19 deletion`, composti research NVP-CGM097).

### Scope B (sottoprodotto diagnostico, `.measure_fragmentation`)

**31 entità** risolvono a un ID condiviso da ≥2 cluster distinti (candidate a
merge cross-cluster), **max k_merged_est 91** studi. Segnale che uno scope B
(merge cross-cluster) riunirebbe una frazione non banale del corpus. Deliverable
`analysis/p4-output/name-cleanup-fragmentation-v1.csv`.

## Limiti / TODO (non bloccanti, coerenti coi TODO noti)

1. **Mismatch HGNC numero-vs-symbol** nell'anchor_key (`HGNC:6407`) vs resolver
   (`HGNC:KRAS`): gonfia i flag_review sui geni. Conservativo (nessun override
   errato), ma andrebbe normalizzato per una misura pulita dei disaccordi geni.
2. **Gap copertura resolver** (glioblastoma via MeSH, anticorpi monoclonali non
   in ChEBI, varianti genetiche): materia del **LLM-fallback finale** già
   previsto (DECISIONE C precision-gated) sui residui.

## Deliverable

- Side-table: `analysis/p4-output/name-cleanup-side-table-v1.rds`
- Frammentazione: `analysis/p4-output/name-cleanup-fragmentation-v1.csv`
- Smoke side-table: `analysis/audit/name-cleanup-smoke-sidetable.{rds,csv}`
