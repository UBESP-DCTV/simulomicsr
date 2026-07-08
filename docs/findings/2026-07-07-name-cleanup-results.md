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

## Review umana dei 14 flag_review (letta sui metadati grezzi)

I disaccordi **non applicati** si sono rivelati un mix istruttivo. Due presunti
*canary* (cluster ritenuti ben nominati) erano **gravemente mal-etichettati** —
il che indebolisce l'assunzione del canary come puro controllo di
non-regressione: un "falso allarme" può essere un vero positivo.

| Anchor attuale (nome vero) | Metadati grezzi | Verdetto |
|---|---|---|
| **D-cicloserina** (antibiotico) | `500 nM JQ1 (DMSO)`, H23 lung | Mistral ha ragione → JQ1 (`CHEBI:137113`) |
| **metil-(S)-3-idrossipalmitato** (lipide) | `100 nM 4-hydroxytamoxifen`, MCF7 | Mistral ha ragione → afimoxifene (`CHEBI:44616`) |
| estradiolo | `10nM Estradiol **+ 10 nM R5020**` | **Nessuno dei due**: è una co-somministrazione → serve un ID-combo |
| gene **APOE** | `apoe genotype: e4`, `4_4`, astrociti iPSC | L'attuale è giusto. È un *genotipo*, non "overexpression" (il `kind` è scorretto) |
| **Influenza A virus** (`11320`) | reassortant A/PR/1934, A/WSN/1933, PR8 | L'attuale è giusto e più specifico |
| cloruro di calcio diidrato / calcium(2+) | `1.2 mM calcium`, `1.8 mM CaCl2` | Mistral propone `calcium atom` (elemento neutro): **peggiora**. L'agente è Ca²⁺ |
| Leukemia / Liver Neoplasms / Lung Neoplasms | linee THP-1/MOLM13, HCC, adenocarcinoma | Mistral è **più specifico** (AML, HCC, adenocarcinoma polmonare) |

## Identità del gene: frammentazione misurata e chiusa

Il caso APOE ha fatto emergere un difetto **a monte**: lo stesso gene aveva due
identificatori. `R/anchors.R` emette `HGNC:<hgnc_int>`; il recupero-nome
(citochine, K2 genetico) emetteva `HGNC:<simbolo>`.

**Misura sugli anchor v7** (278.433 cluster group):

| | |
|---|---:|
| cluster con gene come agente | 39.096 |
| formato numerico (`HGNC:6407`) | 37.160 |
| formato sigla (`HGNC:KRAS`) | 1.936 |
| geni presenti in **entrambi** i formati | 61 |
| gruppi che si **fonderebbero** (anchor completo identico) | **80** (160 cluster) |
| **meta-analisi oggi perse** (sotto k≥3, che unendo la superano) | **3** — PF4, TGFB1, TNF |
| meta-analisi già fatte che guadagnerebbero studi | 2 |
| cluster poolati nello Stadio 4 v8 con gene come agente | 5 / 503 (1 frammentato) |
| alias non canonici (terzo ID) | **0** |

**Natura dell'errore: omissione, non commissione.** I pool esistenti sono
corretti; si perdono 3 meta-analisi e un po' di potenza. Non giustifica un
re-cluster dedicato (~20h); il fix è nel codice e si materializzerà al prossimo
re-cluster.

### Fix (commit `bb802ae`, `8dcd91e`)

- **ID gene canonico = `HGNC:<numero>`** (stabile: i simboli vengono rinominati);
  il simbolo resta l'etichetta leggibile — stesso pattern di
  `gene_id`/`gene_symbol` nello Stadio 4 (FASE E1). Allineati
  `.normalize_cytokine_to_hgnc`, il path K2 genetico e il resolver name-cleanup.
- `.canonicalize_gene_id()`: `HGNC:KRAS` ≡ `HGNC:6407` nei confronti della policy.
- Nuovo ramo `genetic_perturbation` (kind emessi da Mistral: `genetic_variant`,
  `genetic_knockdown`, `gene_mutation`, `protein_overexpression`, …) → gene
  **prima** di ChEBI, **senza fallback MeSH** (per una perturbazione genetica
  MeSH è il namespace sbagliato). `try_gene` fa match whole-string su
  simbolo/alias HGNC **+ nome esteso via UniProt** (`androgen receptor` →
  `HGNC:644`). Canary precisione: 8/8 NULL (tamoxifen, DMSO, LPS, prostate
  cancer, hypoxia, control, vehicle → nessun gene spurio).
- **Cache `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` v4 → v5** (obbligatorio: altrimenti
  il prossimo re-cluster servirebbe un lookup stale).

### Effetto sul full run (re-eval, stesse predictions)

| Azione | prima | dopo |
|---|---:|---:|
| override | 83 | **83** |
| flag_review | 14 | **10** |
| noop | 65 | **67** |
| keep | 31 | **33** |

- I 4 falsi allarmi sui geni (KRAS, SF3B1, TP53, APOE) → **noop** (l'anchor era giusto).
- `androgen receptor`: `MeSH:D011944` → **`HGNC:644`** (namespace corretto per un knockdown).
- `GFP` e `HPV16 E7`: prima forzati su un MeSH spurio → ora **keep** (non sono geni umani).

## Limiti / TODO (non bloccanti)

1. **`R/stage3-anchor-levels.R:154` fabbrica `HGNC:<target grezzo>`** per i target
   `mediated_effect` che HGNC non conosce (es. `HGNC:DTMYC`). Stessa classe del
   fix "I2" già chiuso in `name-recovery.R:346` (*non fabbricare ID inesistenti*):
   andrebbe `STR:<slug>`. Impatto: 5 sigle non risolvibili negli anchor v7.
2. **Gap copertura resolver**: `glioblastoma` (MeSH miss), anticorpi monoclonali
   (Infliximab, non in ChEBI), varianti genetiche (`EGFR exon 19 deletion`),
   reagenti generici (siRNA, GFP) → `keep`. Materia del **LLM-fallback finale**
   già previsto (DECISIONE C, precision-gated).
3. **Combo non modellate**: il cluster `estradiolo + R5020` mostra che una
   co-somministrazione non ha oggi un ID unico (la pipeline ha un ID-combo `+`
   per i composti, non usato qui).
4. Il `kind` `genetic_overexpression` su cluster che sono in realtà **genotipi**
   (APOE e4/e3) è scientificamente scorretto — questione di classificazione K2,
   non di risoluzione ID.

## Deliverable

- Side-table: `analysis/p4-output/name-cleanup-side-table-v1.rds`
- Frammentazione: `analysis/p4-output/name-cleanup-fragmentation-v1.csv`
- Smoke side-table: `analysis/audit/name-cleanup-smoke-sidetable.{rds,csv}`
