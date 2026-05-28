# Plan F1 — ETL re-run Stadio 0 v2 (RED ALERT FASE F, sessione 8)

> **Data**: 2026-05-28. **Branch**: `p5-llm-anchor-classification-audit`.
> **Owner scientifico**: lucavd. **Owner esecutivo**: Claude Code.
> **Gate**: questo piano va approvato dall'utente PRIMA di scrivere codice
> di produzione (regola RED_ALERT §11 no-fretta-paper-grade + §"niente
> codice prima dell'OK").
> **Sub-decisione utente già presa**: opzione **A1** (filtro H2
> mouse-mislabeled come step esplicito post-resolver nello script F1, NON
> dentro `is_sample_classifiable`).

---

## 1. Perché questo piano (cosa è emerso in pre-flight step 3)

Il prompt sessione 8 diceva "Riusare `analysis/p4-beta-etl-build.R` con le
modifiche FASE C". Leggendo lo script end-to-end è emerso che è **stale
pre-FASE-C**: le modifiche FASE C sono state applicate **solo alle
funzioni** (`is_sample_classifiable`, `archs4_to_stage1_jsonl`), **mai
allo script orchestratore**. Cinque problemi (tutti verificati a livello
codice, non ipotizzati):

| # | Problema | Evidenza file:linea |
|---|---|---|
| 1 | H2 mouse-mislabeled non applicato | `p4-beta-etl-build.R`: 0 menzioni mouse/H2 (grep) |
| 2 | H2 va matchato su series **risolto**, non raw | H5 `meta/samples/series_id` ha 193.097 multi-GSE (`"GSE40819,GSE40820"`); rds H2 usa series risolto; match su raw cattura 3.809/9.654 |
| 3 | `molecule_ch1` droppato nel JSONL finale | `p4-beta-etl-build.R:132-140` `final_df` non include `molecule_ch1` (emesso nel raw JSONL, scartato nella ricostruzione) |
| 4 | D4 lib_size non applicato | `p4-beta-etl-build.R:41` chiama `archs4_to_stage1_jsonl` senza `lib_size_vec` → D4 skip |
| 5 | `H5_PATH` errato | `p4-beta-etl-build.R:11` `archs4-human-gene-v2.5.h5` vs reale `human_gene_v2.5.h5` |

**Pattern (audit-before-patch)**: lo script β va **riscritto come F1**, non
patchato in 5 punti. H2 (A1) è uno dei pezzi, non il solo.

**Decisione: nuovo file** `analysis/p4-fase-f-etl-build.R` (NON sovrascrivo
`p4-beta-etl-build.R`, che resta record storico riproducibile del run β
citato in NEWS/CLAUDE.md).

---

## 2. Riconciliazione matematica del bacino (paper-grade)

### 2.1 Universo e oracle

- H5 raw `human_gene_v2.5.h5`: **888.821** sample (pre-filtrato human +
  RNA-Seq by construction da Maayan Lab — vedi pre-flight step 2).
- Master rescued β (`p4-beta-stage1-master-predictions-rescued.jsonl`):
  **879.167** = post-H2 (β ha tolto 9.654 mouse-mislabeled GSE-level).
- L'audit FASE A (A1/A2/A3) è girato **sul master rescued = post-H2**.
  Quindi il TSV `analysis/audit/A3-libsize-scprob-bacino.tsv` (548.373
  righe = post A1+A2) è **già post-H2** e il bacino finale
  **508.038** = {A3-TSV survivors: `lib_size ≥ 500k` AND `scprob < 0.9`}.

**Oracle F1**: il set dei 508.038 GSM survivors nel TSV A3 è la verità
di riferimento (è ciò che ADR-0019 ha usato). F1 deve riprodurre questo
set, NON ri-derivarlo da H5 senza riferimento.

### 2.2 Commutatività D1-D4 ∧ H2

I filtri D1-D4 sono predicati **sample-intrinsic** (organism, strategy,
library_source, protocol, lib_size, scprob, string) — **non dipendono da
series_id**. H2 è il predicato `series_risolto ∈ 72_GSE`. Il set finale
`{D1∧D2∧D3∧D4 ∧ ¬H2}` è indipendente dall'ordine di applicazione. Quindi:

- F1 applica D1-D4 in `archs4_to_stage1_jsonl` (pre-resolver, per-sample),
  poi H2 post-resolver. Il set finale è identico a "H2 prima, D1-D4 dopo".
- Conta intermedia post-D1-D4 (pre-H2) NON è 508.038: include i sample
  H2 che sopravvivono a D1-D4. La conta finale post-H2 è il gate.

### 2.3 Edge case noto: GSM3612196 (1 sample)

Verifica empirica sessione 8: dei 508.038 GSM dell'oracle A3, **esattamente
1** ha `series ∈ 72 H2 GSE`: **GSM3612196** (series `GSE126753`, che in
`p4-beta-rescue-h2-suspects.rds` ha total=14, nonhuman=11, **78.6% mouse**).
β l'ha lasciato nel master rescued (H2 drop β imperfetto, oppure series
risolta del GSM ≠ GSE126753 → non catturata dal drop β keyed-su-risolto).

**Conseguenza**: un H2 filter **pulito** in F1 (drop tutti i 72 GSE su
series risolto) produrrà:
- **508.037** se il resolver F1 risolve GSM3612196 → `GSE126753` (∈ H2) →
  droppato. F1 = oracle − 1 (rimuove un residuo mouse legittimo: GSE
  78.6% murino).
- **508.038** se il resolver F1 risolve GSM3612196 → GSE diverso (multi-
  series) → non droppato. F1 = oracle esatto; il "1 in H2" dell'oracle era
  artefatto di labeling series raw vs risolto nel TSV A3.

**Gate robusto**: F1 finale ∈ {508.037, 508.038}. La differenza è
**solo** GSM3612196, da decidere esplicitamente (§5 decision point).
**Qualunque delta > 1 dall'oracle = STOP investigation** (non è l'edge
noto, è un bug nuovo).

---

## 3. Design F1 (`analysis/p4-fase-f-etl-build.R`)

Flusso ordinato:

1. **Provenance** → `analysis/p4-output/p4-fase-f-source.json`:
   - `sha256` H5 (ricalcolato via `tools` o `sha256sum`; assert ==
     valore noto CLAUDE.md `a1063426...ad5d18` → integrità dump).
   - `md5` (come β), `size_bytes`, `fetched_at`/`built_at` timestamp.
   - `package_version` (0.0.0.9025) + `git_head` sha + snapshot
     `schema_versions` post-E5 (`stage4_algorithm=v2_ensembl_gene_axis`,
     `samn_dedupe_strategy`, `gene_biotype_filter_strategy`,
     `de_covariates_strategy`) come "tag E5".
   - `h2_suspects_file` + `h2_n_gse=72` + `h2_drop_expected`.

2. **ETL H5 → raw JSONL** (D1+D2+D3+D4 + molecule emesso):
   - `H5_PATH = "analysis/input/human_gene_v2.5.h5"` (corretto).
   - Costruisce `lib_size_vec` full-length (888.821) da A3 TSV (helper T2):
     named lookup `geo → lib_size`, NA per i geo non nel TSV (= sample
     droppati da D1/D2 prima del check D4, quindi NA innocuo).
   - Chiama `archs4_to_stage1_jsonl(h5_path, raw_jsonl, skip_log,
     lib_size_vec)`. Il raw JSONL emette già `molecule_ch1` (C4).

3. **Series resolver** (riuso logica β, da cache):
   - `entrez_cache` esiste (`~/.cache/R/simulomicsr/geo-series-resolver-cache.rds`,
     4.3 MB). Verifica copertura: `todo = setdiff(unique_GSE, names(cache))`.
   - **NCBI_API_KEY richiesto SOLO se `todo` non vuoto** (modifica vs β
     che lo pretendeva sempre). Per F1 il set GSE ⊆ β → atteso `todo` ≈ 0
     → no chiamate NCBI, no key necessaria. Se `todo > 0` → `stopifnot(key)`.
   - Produce `recs$series_id_resolved` + `recs$resolver_branch` (vettoriale
     su unique_sids + match-back, come β).

4. **Filtro H2 post-resolver** (A1, NUOVO):
   - Carica `p4-beta-rescue-h2-suspects.rds` → 72 `series_id`.
   - `is_h2 <- .flag_mouse_mislabeled_h2(recs$series_id_resolved, h2_gse)`
     (helper T1).
   - Drop `recs[is_h2, ]`. Log GSM droppati + series in
     `analysis/p4-output/p4-fase-f-h2-drop-gsm.tsv` (geo, series_raw,
     series_resolved) + counter a stdout.
   - reason code concettuale: `mouse_mislabeled_upstream_h2` (nel log H2,
     non in `is_sample_classifiable`).

5. **JSONL finale** (`analysis/input/archs4-human-stage1-input-v2.jsonl`):
   - Schema contract DGX stage1: `record_id, geo_accession, series_id
     (=risolto), string, library_strategy, organism, molecule_ch1`
     (**molecule preservato**, fix problema #3).

6. **Sanity check ex-post** (gate F1):
   - (a) **Set equality vs oracle A3**: `final_geo` confrontato col set
     {A3 survivors D3+D4}. Atteso: identico a meno di GSM3612196.
     `setdiff(oracle, final)` ⊆ {GSM3612196}; `setdiff(final, oracle)`
     deve essere VUOTO (F1 non deve includere GSM extra). Delta > 1 = STOP.
   - (b) **Conta finale** ∈ {508.037, 508.038}.
   - (c) **molecule_ch1** non-NA presente: smoke 20 record random.
   - (d) **H2 drop count** loggato (atteso ≤ 9.654; non è un gate fisso,
     dipende da quanti H2 sopravvivono D1-D4 — reportato per audit).

---

## 4. Task TDD bite-sized

Ogni task: test fail → impl → test pass → commit.

### T1 — helper `.flag_mouse_mislabeled_h2(resolved_series, h2_gse)`
- File: `R/etl-archs4-utils.R` (accanto a `parse_biosample_id`).
- Ritorna logical vector: `resolved_series %in% h2_gse`. NA-safe
  (NA series → FALSE = non droppato, conservativo).
- `@keywords internal`.
- Test `tests/testthat/test-etl-archs4-utils.R`: positivo (series in lista),
  negativo (non in lista), NA (→ FALSE), vector misto, h2_gse vuoto (→ tutti
  FALSE). ~5 expect_*.

### T2 — helper `.build_libsize_vec(geo_all, a3_tsv_path)`
- File: `R/etl-archs4-utils.R`.
- Legge A3 TSV, costruisce named lookup `geo → lib_size`, ritorna vettore
  allineato a `geo_all` (NA dove assente). `length(out) == length(geo_all)`.
- `@keywords internal`.
- Test: geo tutti presenti, geo parziali (NA per assenti), ordine
  preservato, lunghezza == input. ~4 expect_*.

### T3 — script `analysis/p4-fase-f-etl-build.R`
- Implementa §3 flusso 1-6. Non-unit-testato direttamente (orchestratore
  one-shot); validato dai sanity check ex-post integrati (§3.6) che fanno
  `stop()` su violazione.
- Usa T1 + T2.

### T4 — esecuzione F1 locale + validazione + commit
- Run completo (~10-15 min wall: ~13s H5 read + ETL + resolver-da-cache +
  H2 + write + sanity).
- Verifica gate (a)-(d) PASS.
- Commit `P5 audit RED_ALERT F1: ETL re-run Stage 0 v2 input stage1`.

---

## 5. Decision point per l'utente (GSM3612196)

L'unica scelta scientifica aperta: GSM3612196 (human survivor in GSE126753,
78.6% murino).

- **Opzione (i) H2 pulito**: drop tutti i 72 GSE su series risolto. Se F1
  risolve GSM3612196 → GSE126753, viene droppato → bacino 508.037. È 1
  sample **più pulito** dell'oracle (rimuove un residuo mouse legittimo che
  β aveva lasciato). Preferenza mia: questa — coerente con "i 72 GSE sono
  mouse-mislabeled, vanno tutti".
- **Opzione (ii) match oracle esatto**: whitelist GSM3612196 per riprodurre
  508.038 bit-identico all'audit. Più conservativo ma mantiene un sample in
  un GSE 78.6% murino solo per far quadrare un numero.

In entrambi i casi il gate `setdiff(final, oracle) == ∅` + `setdiff(oracle,
final) ⊆ {GSM3612196}` regge. La scelta cambia solo se GSM3612196 entra o
no nel JSONL finale. Da decidere prima di T4 (o accettare quello che il
resolver F1 produce naturalmente e documentarlo).

---

## 6. Consistenza downstream (nota, NON in scope F1)

`build_archs4_metadata_v2` (C3, usato da Stadio 4 / F5) applica
`is_sample_classifiable` ma NON fa resolver né H2 → il suo output include
i sample H2 che sopravvivono D1-D4. **Innocuo a F5**: Stadio 4 fa lookup
metadata solo per i GSM nei cluster (post-H2 via F1→F2→F3). I GSM H2 extra
nell'RDS non vengono mai cercati. Da risolvere a F5 (restrizione al GSM set
di F1, oppure documentare come inerte). **Tracciato qui per non riscoprirlo.**

---

## 7. File toccati

| file | tipo | task |
|---|---|---|
| `R/etl-archs4-utils.R` | mod (2 helper) | T1, T2 |
| `tests/testthat/test-etl-archs4-utils.R` | mod (test) | T1, T2 |
| `analysis/p4-fase-f-etl-build.R` | new | T3 |
| `analysis/input/archs4-human-stage1-input-v2.jsonl` | output (gitignored) | T4 |
| `analysis/p4-output/p4-fase-f-source.json` | output | T4 |
| `analysis/p4-output/p4-fase-f-h2-drop-gsm.tsv` | output | T4 |
| `analysis/p4-output/p4-fase-f-skipped.tsv` | output | T4 |

Master invariato. Branch ahead. No push.
