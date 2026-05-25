# Design spec — Post-hoc ontology override per LLM anchor classification

- **Date:** 2026-05-25
- **Status:** Approved (decisione utente 2026-05-25 → ADR-0018)
- **ADR:** `docs/decisions/0018-llm-anchor-ontology-override.md`
- **Plan:** `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-plan.md`
- **Audit drive:** `docs/findings/2026-05-24-llm-anchor-classification-audit.md`
- **Branch:** `p5-llm-anchor-classification-audit` (esistente, continuiamo qui)

## 1. Context

L'audit 2026-05-24 ha quantificato che il LLM Mistral-Small-3.2 emette `agent_normalized` con tre classi di errore sistematico:

1. **Field-swap** (23.87%): numero ID nel campo `preferred_name` invece di `id`
2. **Pure hallucination** (0.97%): numero inesistente in alcun vocabolario
3. **`kind_effective` mismatch**: cytokine 99.3% wrong, pathogen 97.6% wrong (validation vs ChEBI `has_role`)

Effetto: pooling DE Stage 4 è valido (anchor stringa deterministica cross-studio), ma interpretazione biologica invalida.

Decision (ADR-0018, opzione 2): aggiungere un **resolver downstream deterministico** in `R/anchors.R` che usa ChEBI/HGNC/MeSH dictionary come ground-truth per (a) canonicalizzare l'`agent_id` e (b) inferire o validare il `kind_effective`. Stage 1/2 master output INVARIATI; rebuild Stage 3 + Stage 4 + Layer B.

## 2. Goals e non-goals

**Goals**

- G1: Recuperare il **95-100% dei field-swap** ChEBI/HGNC/MeSH via lookup deterministico
- G2: Validare il **`kind_effective`** contro ChEBI `has_role` quando disponibile; override quando mismatch
- G3: Conservare il LLM original output **per ogni cluster** (tracciabilità paper-grade)
- G4: Stage 3 schema `v3.1` con versioning trasparente (forward-compatible con futuri override)
- G5: Reproducibility: ontology release date registrata in `run_metadata.json`; resolver è codice TDD-tested
- G6: Layer B rebuild deve restituire una shortlist con **<5% dei case study con kind/agent wrong** (audit post-rebuild come gate)

**Non-goals**

- NG1: Non re-runniamo Stage 1 o Stage 2 LLM
- NG2: Non risolviamo i compound LLM-oscuri senza ChEBI roles (es. CHEBI:17199, CHEBI:17236) — restano flagged "unvalidatable" come paper caveat
- NG3: Non normalizziamo le stringhe libere ("Hypoxia", "contact inhibition", "siRNA") — restano come `STR:lowercase`
- NG4: Non aggiungiamo nuovi segmenti all'anchor v3.1 (resta 13 segmenti); cambia solo il **contenuto** del segmento `agent_id` e del segmento `kind_effective`
- NG5: Non implementiamo network refresh automatico delle ontologie — il refresh è esplicito (user-triggered)
- NG6: Non rebuild Stage 1 chunks input / Stage 2 chunks input (sono input artefatti, immutati)

## 3. Architecture overview

```
Stage 1 master              Stage 2 master           Stage 3 build (NEW)        Stage 4 build              Layer B build
(879k samples)              (39k predictions)        anchor_key v3.1              (rebuild)                  (rebuild)
   |                            |                         |
   |                            |                         |
   +-> (unchanged)              +-> (unchanged)           +--> R/anchors.R::          
                                                          |    resolve_agent_canonical()   
                                                          |    infer_kind_from_ontology()  
                                                          |    
                                                          +--> R/stage3-anchor-levels.R::
                                                          |    extract_anchor_segments() v3.1
                                                          |    -> uses resolved agent_id
                                                          |    -> uses resolved kind_effective
                                                          |
                                                          +--> clusters.rds v3.1
                                                               + agent_id_llm_original
                                                               + agent_id_resolved
                                                               + kind_effective_llm_original
                                                               + kind_effective_resolved
                                                               + resolution_source
                                                               + kind_overridden
                                                               + kind_override_reason
```

Tre punti di intervento:

1. **`R/ontology-lookup.R`** (NUOVO): loader + accessor functions per ChEBI, HGNC, MeSH dictionary. Cache su `tools::R_user_dir("simulomicsr","cache")`.
2. **`R/anchors.R`** (MODIFY): `.resolve_agent_id` esistente refactorato. Nuova funzione `resolve_agent_canonical()` (pubblica come `@keywords internal`) + `infer_kind_from_ontology()`.
3. **`R/stage3-anchor-levels.R`** (MODIFY): `extract_anchor_segments()` riceve metadata stage2 e usa il nuovo resolver; emette segmento `agent_id` canonicalizzato e `kind_effective` resolved; popola le 6 tracking columns nel `clusters$` output.

NO modifiche a Stage 4 logic. Stage 4 legge `clusters.rds` e usa `cluster_id` come prima — solo che adesso cluster_id sono diversi (riflettono nuovo anchor_key).

## 4. Components — design dettaglio

### 4.1 `R/ontology-lookup.R` (NUOVO)

**Exports (internal):**

```r
.load_ontology_dicts(refresh = FALSE)   # carica ChEBI+HGNC+MeSH in env, memoizzato
.ontology_release_meta()                # ritorna list con release dates + sha256 dei file dump
.chebi_lookup_id(chebi_int)             # restituisce primary_name, ascii_name, is_obsolete, parent_id
.chebi_lookup_alias(name_lower)         # restituisce chebi_int + match_type (PRIMARY/SYNONYM/IUPAC)
.chebi_roles(chebi_int)                 # vector di role_name
.hgnc_lookup_hgnc(hgnc_int)             # symbol, name, locus_group, locus_type
.hgnc_lookup_entrez(entrez_int)         # symbol, hgnc_int
.hgnc_lookup_symbol(symbol_lower)       # hgnc_int, primary_symbol
.mesh_lookup_ui(ui_str)                 # mh (heading), tree_branches, tree_top
.mesh_lookup_term(term_lower)           # ui
```

**Internal storage:** environment singleton `.ontology_env` con i RDS pre-built (ChEBI 16MB, HGNC ~5MB, MeSH ~3MB) caricati lazily.

**Path convention:**
```
tools::R_user_dir("simulomicsr","cache")/
  chebi/chebi-lookup.rds      # build da analysis/p5-audit-chebi-build-dict.R
  hgnc-lookup.rds             # build da analysis/p5-audit-hgnc-mesh-build-dict.R
  mesh-lookup.rds             # idem
```

I builder script esistenti (commit `7a0e20c`) sono riutilizzati. NON aggiungiamo network download alla pipeline runtime; se il file manca, la pipeline aborta con istruzione chiara di ricostruire.

### 4.2 `R/anchors.R::resolve_agent_canonical()`

Sostituisce concettualmente `.resolve_agent_id()` esistente. La firma:

```r
resolve_agent_canonical <- function(agent_normalized, ontology_dicts = .load_ontology_dicts()) {
  # Returns list(
  #   canonical_id    = character(1),     # es. "CHEBI:17126" o "HGNC:5028" o "MeSH:D016899" o "STR:hypoxia" o "UNK"
  #   canonical_name  = character(1),     # nome leggibile, es. "carnitine"
  #   resolution_source = character(1)    # enum: see below
  # )
}
```

**Decision table (input → output):**

| Input `agent_normalized` | resolution_source | canonical_id | Esempi |
|---|---|---|---|
| `id_database="CHEBI"`, `id` non-empty AND `id` numerico valid in ChEBI | `CHEBI_DIRECT` | `CHEBI:<id>` | LLM ha emesso correttamente |
| `id_database="CHEBI"`, `id` empty AND `preferred_name` numerico valid in ChEBI | `CHEBI_FIELDSWAP` | `CHEBI:<preferred_name>` | Field-swap recovery (la stragrande maggioranza dei 54k CHEBI:NNN) |
| `id_database="CHEBI"`, `id` ed `preferred_name` numerici NOT in ChEBI, MA `id` numerico in HGNC | `WRONG_DB_to_HGNC` | `HGNC:<id>` | Recovery 198 cluster |
| `id_database="HGNC"`, simile pattern → HGNC primary | `HGNC_DIRECT` o `HGNC_FIELDSWAP` | `HGNC:<id>` | 7.209 + recovery |
| `id_database="MeSH"`, simile pattern → MeSH primary | `MESH_DIRECT` o `MESH_FIELDSWAP` | `MeSH:<id>` | (MeSH usato per disease descriptors) |
| `id_database` empty, `preferred_name` matcha ChEBI alias case-insensitive | `STRING_ALIAS_CHEBI` | `CHEBI:<lookup_id>` | "Resiquimod", "Polyinosinic-polycytidylic acid" |
| `id_database` empty, `preferred_name` matcha HGNC symbol | `STRING_ALIAS_HGNC` | `HGNC:<lookup_id>` | "VEGFA", "TP53" |
| `id_database` empty, `preferred_name` matcha MeSH entry term | `STRING_ALIAS_MESH` | `MeSH:<lookup_ui>` | "Interferon beta" |
| `agent_normalized.type == "vehicle"` AND `preferred_name` non-empty | `LLM_VEHICLE_LITERAL` | `STR:<preferred_name_lower>` | "DMSO", "PBS", "control" |
| `id` ed `preferred_name` MeSH naked Dxxxxxx, valid in MeSH | `MESH_NAKED` | `MeSH:<ui>` | "D011279" (anche se hallucinated come UI) |
| Tutti i lookup fail | `HALLUCINATED_OR_FALLBACK` | `STR:<agent_raw_lower>` o `UNK` se anche agent_raw empty | "CHEBI:12345" non in ChEBI |
| `agent_normalized` null OR `type == "none"` | `NO_AGENT` | `UNK` | Cluster trasversale senza treatment-specific anchor |

**Casi speciali da gestire:**

- **ChEBI secondary IDs** (es. `12345` → mergiato in `16888`): il resolver normalizza a primary_id. Output `canonical_id = "CHEBI:16888"` + `resolution_source = "CHEBI_SECONDARY_REDIRECT"`.
- **HGNC entrez_id**: numerico puro che valida via `entrez_id` colonna HGNC. Output `canonical_id = "HGNC:<hgnc_int>"` (NON Entrez:<n>; canonicalizziamo a HGNC).
- **ChEMBL IDs naked** (es. "CHEMBL1201626"): conserviamo come `ChEMBL:<id>` perché il dump ChEMBL non è caricato (out of scope, sono ~3.617 cluster, dropped fine in fallback bucket).
- **Cellosaurus IDs** (es. "CVCL_0023"): conserviamo `STR:<lower>`, non c'è dictionary Cellosaurus locale.

**Coverage attesa (estrapolata da audit):**

| resolution_source bucket | n cluster atteso | % |
|---|---:|---:|
| CHEBI_DIRECT + CHEBI_FIELDSWAP + STRING_ALIAS_CHEBI + CHEBI_SECONDARY | ~100.000 | 37.5% |
| HGNC_* (tutti) | ~12.000 | 4.5% |
| MeSH_* (tutti) | ~7.000 | 2.6% |
| STR fallback (string libero) | ~75.000 | 28% |
| NO_AGENT (LLM emit "none"/null) | ~65.000 | 24% |
| HALLUCINATED_OR_FALLBACK pure | ~3.000 | 1.1% |

### 4.3 `R/anchors.R::infer_kind_from_ontology()`

Funzione separata che, dato un `canonical_id` (output di `resolve_agent_canonical`), suggerisce un `kind_effective` se ChEBI `has_role` permette.

```r
infer_kind_from_ontology <- function(canonical_id, ontology_dicts = .load_ontology_dicts()) {
  # Returns list(
  #   kind_resolved = character(1) | NA_character_,
  #   role_evidence = character(1) | NA_character_,   # es. "cytokine; interferon inducer"
  #   confidence    = character(1)                    # "STRONG" | "MEDIUM" | "WEAK" | "NONE"
  # )
}
```

**Decision table:**

| canonical_id pattern + role | kind_resolved | confidence |
|---|---|---|
| CHEBI:N AND has_role matches "cytokine OR interleukin OR interferon OR chemokine OR growth factor OR interferon inducer" | `cytokine_stim` | STRONG |
| CHEBI:N AND has_role matches "TLR agonist OR adjuvant OR lipopolysaccharide OR pathogen-associated OR bacterial toxin OR viral OR virion" | `pathogen_or_aggregate_exposure` | STRONG |
| CHEBI:N AND has_role matches "solvent OR vehicle OR polar solvent OR aprotic solvent OR protic solvent" | `vehicle_only` | STRONG |
| CHEBI:N AND has_role matches "antibiotic OR antimicrobial" | `pathogen_or_aggregate_exposure` | MEDIUM |
| CHEBI:N AND has_role matches "drug OR antineoplastic" but NO cytokine/pathogen role | `small_molecule` | MEDIUM |
| CHEBI:N AND has_role matches "metabolite" (human/mouse/E.coli/etc) | `small_molecule` | WEAK |
| HGNC:N (any gene) | `NA` (kind not inferrable from gene alone — needs `perturbation_kind` separately) | NONE |
| MeSH:D* AND tree_branch starts with "C04" (Neoplasms) OR "C..." (disease branches) | `disease_vs_normal` | STRONG |
| MeSH:D* AND tree_branch starts with "D" (Chemicals) | `small_molecule` | MEDIUM |
| STR:hypoxia / contact inhibition / X-ray radiation | NA (string match — TBD if we want hardcoded mapping) | NONE |
| Anything else | `NA` | NONE |

**Override policy:**

| LLM `kind_effective` | Ontology `kind_resolved` confidence | Action |
|---|---|---|
| Any | STRONG, matches LLM | `kind_overridden=FALSE`, `resolved=LLM` |
| Any (incl LLM = small_molecule generic) | STRONG, differs from LLM | **`kind_overridden=TRUE`**, `resolved=ontology`, `reason=ONTOLOGY_OVERRIDE_STRONG` |
| Any | MEDIUM, differs from LLM | LLM preserved (conservative); flag `kind_overridden_pending=TRUE` per audit |
| Any | WEAK, differs from LLM | LLM preserved; no flag |
| Any | NONE | LLM preserved; no flag |
| `cytokine_stim` LLM with NO ontology evidence available | NONE | LLM preserved; flag `kind_unvalidatable=TRUE` |

Il principio è **conservativo**: override solo quando ChEBI ha role evidence STRONG. Per Ethanol-as-cytokine, ChEBI ha "polar solvent | neurotoxin | CNS depressant" → kind STRONG=`vehicle_only` → override.

Per Carnitine-as-pathogen, ChEBI ha "human metabolite | mouse metabolite" → kind WEAK=`small_molecule` → **NON override** (conservative). Però aggiungo flag che permette di filtrarli in Layer B selection.

In alternativa per Carnitine: **WEAK evidence di "metabolite" è inconsistente con kind `pathogen`** → potremmo upgrade WEAK → STRONG quando *contradicts* LLM in modo categorico. Decisione design: introduco `contradiction_evidence` boolean. Ethanol → polar_solvent ∧ kind=cytokine_stim → contradiction. Carnitine → metabolite ∧ kind=pathogen → contradiction. Doxorubicin → drug ∧ kind=small_molecule → no contradiction.

Override condition rivista:

```
override IF (
  ontology_confidence == STRONG
) OR (
  ontology_confidence == WEAK_OR_MEDIUM
  AND llm_kind in {cytokine_stim, pathogen_or_aggregate_exposure}
  AND llm_kind NOT IN inferred_compatible_kinds(role_evidence)
)
```

Cioè: se LLM dice `cytokine_stim` ma le role evidence sono "metabolite" / "solvent" / "lipid" / etc — **override** anche con evidence WEAK. La logica si chiama "kind_assertion_contradiction": il LLM ha fatto un'affermazione forte (cytokine_stim) che è inconsistente con qualunque role evidence.

### 4.4 `R/stage3-anchor-levels.R::extract_anchor_segments()` MODIFY

Funzione esistente che produce i 13 segmenti dell'anchor_key dato uno study/comparison. Modifiche:

- Segmento 2 (`agent_id`): popolato da `resolve_agent_canonical(agent_normalized)$canonical_id`
- Segmento 1 (`kind_effective`): popolato da `kind_effective_resolved` (default LLM, override se ontology STRONG o contradiction)

Output `clusters.rds` aggiunge per ogni cluster_id:

| Column | Type | Source |
|---|---|---|
| `agent_id_llm_original` | chr | `agent_normalized` raw concat (legacy behavior) |
| `agent_id_resolved` | chr | output canonical_id |
| `resolution_source` | chr | enum (vedi 4.2) |
| `kind_effective_llm_original` | chr | LLM raw |
| `kind_effective_resolved` | chr | post-override |
| `kind_overridden` | lgl | TRUE se cambia da LLM |
| `kind_override_reason` | chr | "STRONG_CONFIDENCE_MATCH" / "LLM_CONTRADICTION_DETECTED" / NA |

**Anchor v3.1 schema bump:** `run_metadata.json` di Stage 3 deve avere `schema_versions.anchor = "v3.1"`. Stage 4 NON ha bisogno di modifiche (legge cluster_id + anchor_key opaco).

### 4.5 Cluster ID stability

Cluster_id corrente = `xxh32(anchor_key)`. Cambiando il contenuto di `agent_id` (e potenzialmente `kind_effective`), gli hash cambieranno per la maggior parte dei cluster — anche se gli studi sono "gli stessi".

Conseguenze:
- `analysis/layer-b-selection.csv` corrente (commit `8c97dc4`) diventa OBSOLETO → re-shortlist su nuovo Stage 3 (script `analysis/p5-stage4-layer-b-shortlist.R` può essere ri-eseguito identical).
- `analysis/p4-output/20260523T032601Z-stage4-96c43acb/` (Layer A old) resta su disco come baseline pre-fix per **diff comparison**. NON viene cancellato.

## 5. Edge cases e handling

| Caso | Comportamento |
|---|---|
| ChEBI secondary ID (`12345` mergiato in `16888`) | `canonical = CHEBI:16888`, `resolution_source = CHEBI_SECONDARY_REDIRECT`, `canonical_name` = primary di 16888 |
| ChEBI obsoleto con `parent_id` set | `canonical = CHEBI:<parent_id>`, source = `CHEBI_OBSOLETE_REDIRECT` |
| HGNC entrez_id puro (es. `10000` = AKT3) | `canonical = HGNC:<corresponding hgnc_int>`, source = `HGNC_ENTREZ_MAPPED` |
| MeSH UI inesistente (`D011279` con disease kind context) | `canonical = MeSH:<input>`, source = `MESH_HALLUCINATED`, `canonical_name = NA`. LLM kind preserved. |
| ChEMBL ID naked (`CHEMBL1201626`) | `canonical = ChEMBL:<id>`, source = `CHEMBL_NAKED_NOLOOKUP` (no ChEMBL dictionary loaded) |
| ChEBI ID con `id_database = NULL` ma `preferred_name` numerico (PATH 1) | tentativo lookup ChEBI primary; se match → `CHEBI_DIRECT_NO_DB`; else HGNC fallback |
| LLM emette `id_database = "ChEMBL"` ma id-num è in CHEBI | `WRONG_DB_to_CHEBI`, canonical CHEBI |
| Stringa libera che NON matcha alias né symbol né term | `STR:<lowercase>`, source = `STRING_NO_ALIAS_MATCH` |
| `agent_normalized.type == "none"` AND `kind_effective == "none"` (cluster trasversale) | `canonical = UNK`, source = `NO_AGENT`. **Non override `kind_effective`** (trasversale è semantic legitimate) |
| Compound CHEBI con zero `has_role` (es. CHEBI:17199, CHEBI:17236) | `canonical = CHEBI:<id>`, `kind_resolved = NA` confidence=NONE → LLM kind preserved, flag `kind_unvalidatable=TRUE` |

## 6. Versioning + reproducibility

`run_metadata.json` di Stage 3 nuovo deve registrare:

```json
{
  "schema_versions": {
    "anchor": "v3.1",
    "stage3_algorithm": "v1",
    "resolver": "v1.0.0"
  },
  "ontology_releases": {
    "chebi": {
      "release_dir": "/home/user/.cache/R/simulomicsr/chebi/",
      "file_modified_max": "2026-05-01T19:39:00Z",
      "sha256_compounds": "...",
      "sha256_names": "...",
      "sha256_relation": "...",
      "n_compounds": 205310
    },
    "hgnc": {
      "downloaded_from": "https://storage.googleapis.com/public-download-files/hgnc/tsv/tsv/hgnc_complete_set.txt",
      "n_records": 44989,
      "sha256": "..."
    },
    "mesh": {
      "release_year": "2025",
      "downloaded_from": "https://nlmpubs.nlm.nih.gov/projects/mesh/2025/asciimesh/d2025.bin",
      "n_descriptors": 30956,
      "sha256": "..."
    }
  },
  ...
}
```

Storage location finale per le 3 RDS dictionaries: `tools::R_user_dir("simulomicsr","cache")`. Pipeline aborta se mancanti, con istruzione di ricostruire.

## 7. Validation strategy

### 7.1 TDD coverage

Test file nuovi:

- `tests/testthat/test-ontology-lookup.R` — load + lookup ChEBI/HGNC/MeSH (uses fixture mini-dict)
- `tests/testthat/test-anchors-resolve-canonical.R` — resolve_agent_canonical su 30+ fixture (uno per ogni branch decision table)
- `tests/testthat/test-anchors-infer-kind.R` — infer_kind_from_ontology su 20+ fixture
- `tests/testthat/test-stage3-anchor-v31.R` — integration test: stage2 sample → anchor_key v3.1

Test fixture mini-dict: subset di ChEBI/HGNC/MeSH con i 30-50 compound noti dell'audit (Carnitine, Ethanol, Resiquimod, DMSO, etc.). File `inst/extdata/ontology-fixtures-mini/`.

### 7.2 Smoke gate (pre-fullrun)

Smoke 3-GSE su Stage 3 nuovo: lancio `build_stage3` sui 3 GSE noti (1 con CHEBI valid agent, 1 con CHEBI field-swap, 1 con MeSH disease). Verifico:
- `agent_id_resolved` corretto
- `kind_overridden=TRUE` per Carnitine/Ethanol/Pregnanetriol (i casi paradigmatici)
- `clusters.rds` schema include nuove colonne

Smoke 3-cluster su Stage 4 nuovo: prendo i 3 cluster smoke (qualunque cluster_id post-rebuild che corrisponde ai vecchi smoke), verifico che il pooling DE produca risultati coerenti (n_sig, max_logFC nello stesso ordine di magnitude).

### 7.3 Full rebuild validation gates

1. **Stage 3 rebuild**: deve produrre lo stesso N di studies (39.247) ma cluster_id diversi. Diff vs `analysis/p4-output/20260519T055547Z-stage3-2153addc/clusters.rds`:
   - n_cluster totali ± 5% accettabile
   - n_cluster con `kind_overridden=TRUE` deve essere consistente con audit predictions (~5000-7000 cluster con kind cytokine/pathogen wrong)
2. **Stage 4 rebuild**: 622/622 pooled OK (no change atteso). wall <= 35h laptop / <= 6h DGX.
3. **Layer B re-shortlist**: i 4 critically wrong (Carnitine, Ethanol, dihydroxyphthalic, Pregnanetriol) **devono non comparire** o comparire con kind corretto. Audit `analysis/p5-audit-15-layer-b.R` re-run su nuova selection → expect <5% misclassification.

## 8. Operational planning

Vedi `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-plan.md` per task-by-task.

Suddivisione per sessione (gate utente tra blocchi):

| Sessione | Task | Wall | Gate |
|---|---|---|---|
| S1 | Task 0-5 (impl + test + smoke isolato) | 4-6h | Verifica TDD all green + smoke OK |
| S2 | Task 6-7 (Stage 3 rebuild full + diff) | 1-3h | Diff statistics utente review |
| S3 | Task 8-9 (Stage 4 rebuild full) | 4-6h DGX o 28h laptop | Pooling identico a old in entità |
| S4 | Task 10-11 (Layer B re-shortlist + batch) | 30 min | Layer B audit post-rebuild, <5% misclassification |
| S5 | Task 12-14 (close: ADR Accepted + paper Methods + master merge) | 1-2h | User-driven merge |

## 9. Open questions

- **OQ1**: La sezione 4.3 propone override quando ontology=STRONG OR contradicts-LLM. Conservativo enough? Alternativa: override solo STRONG, lasciare contradiction casi a flag manual review. **Decisione: come da spec; rivedibile a S2 dopo aver visto le stats reali**.
- **OQ2**: Stringhe libere ("Hypoxia", "siRNA", "transplantation", "X-ray radiation") sono interpretate via STR:lowercase. Vogliamo aggiungere un hardcoded mini-dictionary per le top-30 stringhe libere? (Hypoxia → kind=environmental confirmed, siRNA → kind=genetic_knockdown confirmed, etc.). **Mio suggerimento: NO per ora, lo facciamo solo se Layer B post-rebuild dimostra che è necessario**.
- **OQ3**: Il refresh delle ontologie è user-triggered. Documentare nella vignette `p5-ontology-refresh.Rmd`? **Sì, opzionale post-paper**.
- **OQ4**: ChEBI release 2026-05-01 ha N=205.310 compounds. Tra qualche mese sarà cambiato. La pipeline storica deve ricostruire i dataset usando **lo stesso ChEBI release**. Mettiamo il sha256 dei file `.tsv.gz` in `run_metadata.json` per pinning. Replication: l'utente che vuole rieseguire deve avere quello stesso file. È accettabile.
- **OQ5 (paper Methods)**: bisogna citare le ontology releases nel paper. ChEBI version 2026-05-01 (e relativo DOI), HGNC release, MeSH 2025. Aggiungere alla bibliografia post-paper draft.

## 10. Out of scope

- Stage 1 prompt redesign (Opzione 4 dell'ADR)
- Stage 2 LLM re-prompt (Opzione 3)
- ChEMBL dictionary lookup (~3.6k cluster, accettiamo come fallback)
- Cellosaurus dictionary lookup (~50-100 cluster cell line agents)
- Hardcoded STRING_LIBERO → kind mapping (Hypoxia, siRNA, ecc.) — vedi OQ2
- ChEBI ontology hierarchy walking (parent classes via `is_a`): troppo complesso per il valore aggiunto vs `has_role`-based check
- Cross-species ontology mapping (MGI mouse → HGNC human): not needed for human ARCHS4 dataset

## 11. Riferimenti

- Audit report: `docs/findings/2026-05-24-llm-anchor-classification-audit.md`
- ADR-0018: `docs/decisions/0018-llm-anchor-ontology-override.md`
- Plan: `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-plan.md`
- HUMANE companion: `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-HUMANE.md`
- ChEBI flat files schema: https://ftp.ebi.ac.uk/pub/databases/chebi/flat_files/README
- HGNC TSV: https://storage.googleapis.com/public-download-files/hgnc/tsv/tsv/hgnc_complete_set.txt
- MeSH descriptor format: https://www.nlm.nih.gov/databases/download/mesh.html
- Anchor v3 spec (esistente): `R/stage3-anchor-levels.R::.extract_anchor_segments` + `R/anchor-parse.R::parse_anchor_key`
