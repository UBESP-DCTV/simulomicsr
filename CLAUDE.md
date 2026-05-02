# CLAUDE.md — contesto persistente per Claude Code su `simulomicsr`

> Questo file è la **fonte canonica** del contesto del progetto per ogni sessione Claude Code, indipendentemente dalla macchina (Mac locale o server). Sostituisce la memoria locale di Claude Code (`~/.claude/projects/<path>/memory/`) che è machine-specific e non portabile.
>
> **Quando una sessione inizia in questa directory, leggi questo file per intero prima di agire.**

## Visione del progetto

`simulomicsr` è una **pipeline R per meta-analisi RNAseq cross-studio** basata su classificazione LLM dei metadati. Il nome è legacy — il pacchetto NON simula nulla.

Pipeline complessiva (5 stadi):
1. **Acquisizione** — bulk RNAseq da ARCHS4-like (HDF5, ~700k+ sample da GEO).
2. **Stadio 1 sample-level** (P2 ✅) — classificare ogni sample dalla stringa di metadati GEO in un record JSON `sample_facts.stage1.v3` (cell context, perturbazioni, dose, tempo, ambiguity flags). LLM: OpenAI gpt-5.5 in dev, batch API in run massivo.
3. **Stadio 2 study-level** (P3 — next) — interpretare il design sperimentale dello studio: replicate groups, design_role per sample, comparisons con `comparability_anchor` canonicalizzato per cross-studio matching.
4. **Stadio 3 raggruppamento** — cluster cross-studio sui `comparability_anchor`.
5. **Stadio 4 DE per-studio + Stadio 5 meta-analisi** (`DESeq2`/`limma` + `metafor` REM).

## Asset chiave — gold standard

`data-raw/relevant_sample_classified.xlsx` (committato nel repo, ~10 MB).

- Foglio `relevant_sample`: 130.784 righe × 8 colonne.
- Colonne: `Column1`, `string` (input metadata), `trtctr_EP` (gold manuale autore), `geo_accession`, `series_id`, `treat`, `trtctr` (baseline shallow), `gold` (ricontrollo terzo revisore).
- Da spec §6.2: `trtctr_EP` riflette una semantica "qualunque intervento esplicito" che diverge da `design_role` — il gold "design-aware" sarà costruito a P3 mid-stage su 200-300 sample.

## Stato corrente (2026-05-02 fine sessione `simulimicsr_p2`)

- **Master HEAD:** `9d131c9` (P2 Task 13: bump 0.0.0.9003 + NEWS aggiornati).
- **Tag:** `p1-infra-llm-complete` (P1), `p2-stage1-complete` (P2).
- **Master locale è ahead di `origin/master`** — l'utente fa il push lui (mai automaticamente).
- **R CMD check:** 0E / 0W / 2N (note pre-esistenti, no regressioni).
- **Test suite:** 157 PASS / 2 SKIP / 0 FAIL (i 2 SKIP sono smoke E2E gated su `OPENAI_API_KEY`).

### Cosa P1 ha consegnato (infrastruttura LLM)

API esportate: `llm_call_structured()`, `cache_init()`, `cache_put`, `cache_has`, `cache_get`, `cache_stats`, `compile_schema`, `validate_json`, `normalize_gene()`, `hgnc_dump_path()`, `sha256_text`, `cache_key_for`. Adapter privati `.openai_*`. Schema envelope minimo `inst/schemas/llm-call-envelope.v1.json`. Fixture HGNC mini `inst/extdata/hgnc-fixture-mini.tsv`.

### Cosa P2 ha consegnato (Stadio 1 sample_facts)

- `inst/schemas/sample_facts.stage1.v3.json` — schema strict per OpenAI Structured Outputs (`additionalProperties:false` ovunque, tutti `required`, optionals come union null, vocab spec §3.1-§3.12).
- `R/llm-stage1.R`: `read_sample_fixtures_mini()`, `build_prompt_stage1()`, `parse_stage1_response()`, `classify_sample_row()`, `.stage1_invalid_record()` (internal); **`classify_sample()`** export pubblico.
- `R/eval-sampling.R`: `read_samples_input()`, `build_dev_set()` (60/30/10, seed=1812).
- `R/eval-metrics.R`: `stage1_schema_validity_rate()`, `stage1_recall_key_fields()`.
- `inst/extdata/sample-fixtures-mini.tsv` (8 sample stratificati, seed=20260502).
- `analysis/_targets.R`: 10 target fino a `eval_stage1_report` HTML via `tar_render`.
- Vignette `vignettes/stage1-classify.Rmd`.
- Eval Quarto `analysis/eval/stage1-eval.Rmd`.

### Risultati run reale Task 11 (100 sample gpt-5.5)

| Metrica | Osservato | Soglia | Status |
|---|---|---|---|
| `validity_rate` | 1.000 | > 0.95 | ✅ |
| `recall_perturbation` | 0.700 | > 0.7 | ✅ |
| `recall_cell_type` | 0.800 | > 0.85 | ⚠️ -0.05 (17 sample con `context_kind=unclear` legittimi) |

- elapsed 19 min, costo cumulativo P2 ~$3.09 (su tetto $500).
- Distribuzione kind: 32 small_molecule, 17 none, 10 knockdown, 10 vehicle_only, 9 unclear, 8 cytokine, 4 (none-array), 4 pathogen, 3 overexpression, 2 knockout, 1 environmental.
- Distribuzione context: 54 cell_line_in_vitro, 17 unclear, 11 primary_culture, 10 primary_tissue, 2 co_culture, 2 iPSC, 2 tumor_extracted, 1 organoid, 1 xenograft.
- Confidence median 0.88 (range 0.52-0.97).

## Hotfix P1 emersi durante P2 (importanti per supportare gpt-5.5+)

1. **`temperature` opzionale** (`R/llm-client-openai.R`, commit `7fcba3c`). Default cambiato da `0` a `NULL`; il body include `temperature` solo se non-NULL. Causa: gpt-5.5 (reasoning model) ritorna 400 `unsupported_value` su qualunque temperature esplicita.
2. **`simplifyVector = FALSE`** in `.openai_parse_response()` (commit `321e601`). Causa: `TRUE` collassava un array JSON di 1 elemento in scalare R, fallendo la validazione dello schema (campi `array` ricevevano scalari).

NON re-introdurre `temperature = 0` come default. Per output deterministici su modelli storici (gpt-4o, gpt-5.4-mini), passare `temperature = 0` esplicito dal chiamante.

## Convenzioni operative dell'utente

### Tracciabilità — ogni decisione documentata

L'utente vuole una traccia strutturata di TUTTO. Mai prendere una decisione architetturale senza scriverla in modo durevole prima di committare codice che la riflette.

- **ADR** (decisioni architetturali) → `docs/decisions/NNNN-<slug>.md`. Template in `docs/decisions/template.md`.
- **Spec** (brainstorming/design) → `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
- **Plan** (implementazione) → `docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md` + companion HUMANE per la review umana.
- **Commit atomici** con messaggi italiani descrittivi formato `P<N> Task <M>: <azione>`. Sono il "come tecnico" complementare all'ADR.

A fine milestone: raccogliere materiale da ADR/spec per generare/aggiornare vignette o capitoli del futuro manuale.

### Git workflow

- **Branch per fase:** `p<N>-<slug>` (es. `p2-stage1`).
- **Merge fast-forward only** su master a fine fase. Tag `p<N>-<slug>-complete`.
- **MAI fare `git push`** — l'utente lo fa lui, sempre. Master locale può essere molti commit ahead.
- **MAI usare `--no-verify` o `--no-gpg-sign`** salvo richiesta esplicita.
- Pulire `renv/settings.json` (untracked, autogenerato) e ripristinare `analysis/_targets/.gitignore` + `analysis/_targets/meta/meta` (rigenerati da `tar_make`) prima di ogni commit.

### Convenzioni codice

- **Italiano nei commenti, docstring, messaggi commit, error messages.** ASCII per i caratteri accentati nei file Rd generati da roxygen (usare `§`/`—` o equivalenti `sec.`/`--` nel roxygen `#'`).
- Funzioni interne: `@keywords internal`. Solo i veri entry point sono `@export`.
- TDD bite-sized (test → fail → impl → pass → commit) per ogni step di plan.
- Pacchetto: testato con `Rscript --vanilla -e 'devtools::test()'` (bypass renv conflict; vedi sotto).

### Note operative tecniche ricorrenti

- **renv 0.16.0 (lockfile) vs renv 1.1.4 (installato):** il bootstrapper avvisa ad ogni session R. Conseguenza: `Rscript -e ...` (no vanilla) non trova `devtools` perché renv intercetta il libpath. Workaround: `Rscript --vanilla -e ...` bypassa renv e usa system libs (devtools/targets installati globalmente). Per i test che richiedono la API key, esportarla manualmente: `OPENAI_API_KEY="$KEY" Rscript --vanilla -e ...`.
- **`callr_function = NULL` per `tar_make`:** indispensabile quando i target di Stadio 1 chiamano OpenAI. callr crea sub-process R che NON ereditano la API key dal parent. Senza `callr_function = NULL`, fallisce con `simulomicsr_openai_missing_key`.
- **`format = "qs"` non disponibile su CRAN per R 4.5.2** → P2 usa `format = "rds"` per `tar_option_set`.
- **`sample_facts_validator` storizza un PATH allo schema, non il validator compilato** — i contesti V8 di `jsonvalidate` non sono serializzabili in RDS. `compile_schema()` viene chiamato inline nei target di partition (`sample_facts_validated`/`sample_facts_invalid`).

## Decisioni rinviate (da considerare quando matureranno)

- **ADR-0003 — rinome pacchetto.** "simulomicsr" non riflette la pipeline. Da affrontare prima del primo `install_github` pubblico.
- **Vocabolari extra** (Cellosaurus, DrugBank, ChEMBL, MeSH, CAS, NCBITaxonomy, MGI). Necessari per Stadio 2 (P3) o plan separato.
- **Gold "design-aware"** su 200-300 sample. P3 mid-stage, quando il prototipo Stadio 2 funziona.
- **Migrazione a `ellmer`** come client LLM (multi-provider, batch API più ergonomico). Discussa fine 2026-05-02, rimandata a P3+ come ADR separato. P1 attuale (`R/llm-client.R` + adapter) è già pronta per essere sostituita.
- **Cache cross-modello.** P1 attuale partiziona per `(provider, model, messages)` (deviazione consapevole dalla spec §5.4). Se P3 vorrà cache cross-modello, ADR dedicato.
- **Migrazione su server con più spazio.** ADR-0005 documenta il trigger (prima di P4 — run massivo ARCHS4) e la procedura.

## Dove vivere i dati che il repo NON contiene

| Asset | Location | Come ottenerlo / ricostruirlo |
|---|---|---|
| `OPENAI_API_KEY` | `.Renviron.local` (gitignored) | Utente ricrea manualmente. Riga `OPENAI_API_KEY="sk-..."`. |
| renv libreria | `~/Library/Caches/.../renv/` (macOS) o `~/.cache/R/renv/` (Linux) | `renv::restore()` da `renv.lock` committato. |
| HGNC dump completo | `tools::R_user_dir("simulomicsr", which="cache")/hgnc_complete_set.tsv` | Download manuale da `https://www.genenames.org/download/archive/`. P2 funziona con la fixture mini bundled. |
| Cache LLM | `analysis/cache/` (gitignored) | Auto-popolata dai run di `tar_make`. Trasferibile via `rsync` per evitare re-spending. |
| Pipeline state | `analysis/_targets/` (gitignored) | Auto-popolato da `tar_make`. Trasferibile via `rsync`. |
| ARCHS4 H5, matrici espressione | `analysis/input/` (gitignored) | Download diretto sul server da NCBI/ARCHS4 (non transitano da locale). |

## Next step (per la prossima sessione)

1. **Confermare scope di P3.** Default: Stadio 2 (study_design, comparability_anchor, fetch metadati GEO).
2. P3 toccherà: `R/llm-stage2.R` (prompt + classify per GSE), `R/anchors.R` (`make_anchor()`), `R/geo-fetch.R` (study_summary da NCBI), schema `inst/schemas/study_design.stage2.v1.json`, target `study_designs`/`comparisons_table` in `analysis/_targets.R`.
3. P3 può girare interamente in locale. Server-switch è programmato per P4 — vedi ADR-0005.
4. Considerare il rename del pacchetto (ADR-0003) prima di P3 se si vuole evitare confusione downstream.
5. Se P3 si avvicina al run massivo, valutare migrazione a `ellmer` come ADR separato.

## Riferimenti chiave

- Spec classificatore: `docs/superpowers/specs/2026-04-29-classificatore-llm-design.md` (v5 approvata 2026-04-29).
- Plan P1: `docs/superpowers/plans/2026-04-29-p1-infrastruttura-llm-plan.md` + HUMANE.
- Plan P2: `docs/superpowers/plans/2026-05-02-p2-stadio1-sample-facts-plan.md` + HUMANE.
- ADR: `docs/decisions/`.
- README utente: `README.md`.
- News versioni: `NEWS.md`.
