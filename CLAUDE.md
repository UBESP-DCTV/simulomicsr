# CLAUDE.md — contesto persistente per Claude Code su `simulomicsr`

> Questo file è la **fonte canonica** del contesto del progetto per ogni sessione Claude Code, indipendentemente dalla macchina (Mac locale o server). Sostituisce la memoria locale di Claude Code (`~/.claude/projects/<path>/memory/`) che è machine-specific e non portabile.
>
> **Quando una sessione inizia in questa directory, leggi questo file per intero prima di agire.**

## Visione del progetto

`simulomicsr` è una **pipeline R per meta-analisi RNAseq cross-studio design-aware** basata su classificazione LLM dei metadati. Il nome è legacy — il pacchetto NON simula nulla.

**Positioning (ADR-0006, 2026-05-02).** simulomicsr **non** è un altro annotatore di GEO/SRA — quel campo è coperto da ARCHS4, MetaHQ (Hicks 2026), MetaSRA, e dal multi-agent metadata curation di Mondal et al. 2025. Il valore unico è la pipeline end-to-end **design-aware**: dal metadato testuale alle comparisons appaiate (`design_role` LLM-driven entro lo studio) → canonical `comparability_anchor` v3 cross-studio → pooling effect-size random-effects (`metafor` REM). L'unico competitor end-to-end vicino è RummaGEO (Maayan 2024), che però resta a livello di gene-set per-studio senza anchor canonico né effect size. **Benchmark testa-a-testa vs RummaGEO è deliverable integrale di P3.5 eval** (non aggiunta opzionale post-hoc). Vedi ADR-0006 per l'analisi competitiva completa.

Pipeline complessiva (5 stadi):
1. **Acquisizione** — bulk RNAseq da ARCHS4-like (HDF5, ~700k+ sample da GEO).
2. **Stadio 1 sample-level** (P2 ✅) — classificare ogni sample dalla stringa di metadati GEO in un record JSON `sample_facts.stage1.v3` (cell context, perturbazioni, dose, tempo, ambiguity flags). LLM: OpenAI gpt-5.5 in dev, batch API in run massivo.
3. **Stadio 2 study-level** (P3 ✅) — interpretare il design sperimentale dello studio: replicate groups, design_role per sample, comparisons con `comparability_anchor` canonicalizzato per cross-studio matching.
4. **Stadio 3 raggruppamento** — cluster cross-studio sui `comparability_anchor`.
5. **Stadio 4 DE per-studio + Stadio 5 meta-analisi** (`DESeq2`/`limma` + `metafor` REM).

## Asset chiave — gold standard

`data-raw/relevant_sample_classified.xlsx` (committato nel repo, ~10 MB).

- Foglio `relevant_sample`: 130.784 righe × 8 colonne.
- Colonne: `Column1`, `string` (input metadata), `trtctr_EP` (gold manuale autore), `geo_accession`, `series_id`, `treat`, `trtctr` (baseline shallow), `gold` (ricontrollo terzo revisore).
- Da spec §6.2: `trtctr_EP` riflette una semantica "qualunque intervento esplicito" che diverge da `design_role` — il gold "design-aware" sarà costruito a P3 mid-stage su 200-300 sample.

## Stato corrente (2026-05-02 fine sessione `simulomicsr_P3`)

- **Master HEAD:** `0c9e4f5` (P3 Task 17 pre-merge: fix non-ASCII + .Rbuildignore).
- **Tag:** `p1-infra-llm-complete` (P1), `p2-stage1-complete` (P2), `p3-stage2-complete` (P3).
- **Master locale è ahead di `origin/master`** — l'utente fa il push lui (mai automaticamente).
- **R CMD check:** 0E / 0W / 2N (note pre-esistenti: `doc` top-level generato da devtools; `cli`/`purrr`/`stringr` imports non usati da P1).
- **Test suite:** 277 PASS / 0 SKIP / 0 FAIL (i smoke E2E gated su `OPENAI_API_KEY` sono passati con key presente).

### Cosa P1 ha consegnato (infrastruttura LLM)

API esportate: `llm_call_structured()`, `cache_init()`, `cache_put`, `cache_has`, `cache_get`, `cache_stats`, `compile_schema`, `validate_json`, `normalize_gene()`, `hgnc_dump_path()`, `sha256_text`, `cache_key_for`. Adapter privati `.openai_*`. Schema envelope minimo `inst/schemas/llm-call-envelope.v1.json`. Fixture HGNC mini `inst/extdata/hgnc-fixture-mini.tsv`.

### Cosa P2 ha consegnato (Stadio 1 sample_facts)

- `inst/schemas/sample_facts.stage1.v3.json` — schema strict per OpenAI Structured Outputs.
- `R/llm-stage1.R`: `read_sample_fixtures_mini()`, `build_prompt_stage1()`, `parse_stage1_response()`, `classify_sample_row()` (internal); **`classify_sample()`** export pubblico.
- `R/eval-sampling.R`: `read_samples_input()`, `build_dev_set()` (60/30/10, seed=1812).
- `R/eval-metrics.R`: `stage1_schema_validity_rate()`, `stage1_recall_key_fields()`.
- 100 sample dev set classificati su gpt-5.5: validity 1.0, recall_pert 0.7, recall_cell 0.8.

### Cosa P3 ha consegnato (Stadio 2 study_design + anchor v3 + benchmark 15 GSE)

- `inst/schemas/study_design.stage2.v1.json` — schema strict (`factor_levels`/`fixed_factors` come array di {key, value} per OpenAI strict).
- `R/llm-stage2.R`: `build_prompt_stage2()` (internal), `parse_stage2_response()` (internal); **`classify_study()`** export pubblico.
- `R/geo-fetch.R`: **`fetch_study_summary()`** export su rentrez con cache JSONL.
- `R/anchors.R`: helpers privati `.normalize_dose/duration/cell_id`; **`make_anchor()`** v3 13 segmenti (R8/R9/R24/R25/R31 + disease override condizionato); **`make_inducer_log()`** export.
- `analysis/_targets.R`: target completi Stadio 2 driven da 15 fixture curate (`curated_stage2_gse`).
- `vignettes/stage2-classify.Rmd`: vignette user-facing offline buildable.
- `inst/extdata/stage2-fixtures-mini/`: 15 GSE benchmark stratificato (197/197 sample stage1-valid).

### Risultati run reale 15 GSE (Task 13)

| Metrica | Risultato |
|---|---|
| Validity rate | 15/15 = 100% |
| design_kind coperti | 7/10 |
| Confidence range | 0.72-0.93 (median ~0.87) |
| Comparisons cross-GSE | 55 |
| Anchor unici | 44 (11 collisioni cross-studio attese) |
| Costo cumulativo P3 | ~$5-7 (su tetto $500) |

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
- **Gold "design-aware"** su 200-300 sample. Costruzione integrata in P3.5 eval insieme al benchmark vs RummaGEO (vedi ADR-0006).
- **Integrazione MetaHQ** come upstream per `normalize_tissue()` / `normalize_disease()` in Stadio 2. ADR-0006: 188k sample annotati expert-level con propagazione UBERON/MONDO. Decisione rimandata al primo task di P3 in cui serve la normalizzazione tissue/disease robusta.
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

## Next step (per la prossima sessione — P3.5 eval)

**P3 completato (2026-05-02).** Prossima fase: **P3.5** — eval Stadio 2 + benchmark vs RummaGEO.

1. **P3.5 toccherà:** `R/eval-rummageo.R` (loader + matching), `R/eval-design-gold.R` (gold design-aware su 200-300 sample), target `eval_rummageo_benchmark` + `eval_stage2_metrics`, report Quarto in `analysis/eval/rummageo-benchmark.Rmd`. Specifiche del benchmark in ADR-0006 §"Deliverable integrale: benchmark vs RummaGEO".
2. **Server-switch** programmato per P4 (run massivo ARCHS4) — vedi ADR-0005.
3. Considerare il rename del pacchetto (ADR-0003) prima del primo `install_github` pubblico.
4. Se P3.5/P4 si avvicina al run massivo, valutare migrazione a `ellmer` come ADR separato.
5. **Prossimo step concreto:** invocare `superpowers:writing-plans` per scrivere il plan dettagliato di P3.5.

## Riferimenti chiave

- Spec classificatore: `docs/superpowers/specs/2026-04-29-classificatore-llm-design.md` (v5 approvata 2026-04-29; §13 References aggiunta 2026-05-02).
- Plan P1: `docs/superpowers/plans/2026-04-29-p1-infrastruttura-llm-plan.md` + HUMANE.
- Plan P2: `docs/superpowers/plans/2026-05-02-p2-stadio1-sample-facts-plan.md` + HUMANE.
- **ADR-0006 stato dell'arte:** `docs/decisions/0006-stato-arte-vs-simulomicsr.md` — analisi competitor 2024-2026 + benchmark RummaGEO integrale + decisione P3-B confermata.
- ADR-0005 server migration: `docs/decisions/0005-server-migration-trigger.md`.
- ADR generali: `docs/decisions/`.
- README utente: `README.md`.
- News versioni: `NEWS.md`.
