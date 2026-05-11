# CLAUDE.md — contesto persistente per Claude Code su `simulomicsr`

> Fonte canonica del contesto del progetto per ogni sessione Claude Code,
> indipendentemente dalla macchina (laptop o server). Sostituisce la
> memoria locale di Claude Code (`~/.claude/projects/<path>/memory/`)
> che è machine-specific e non portabile.
>
> **Quando una sessione inizia in questa directory, leggi questo file
> per intero prima di agire.**

## Visione del progetto

`simulomicsr` è una **pipeline R per meta-analisi RNAseq cross-studio
design-aware** basata su classificazione LLM dei metadati. Il nome è
legacy — il pacchetto NON simula nulla.

**Positioning (ADR-0006).** simulomicsr **non** è un altro annotatore
di GEO/SRA — quel campo è coperto da ARCHS4, MetaHQ (Hicks 2026),
MetaSRA, e dal multi-agent metadata curation di Mondal et al. 2025. Il
valore unico è la pipeline end-to-end **design-aware**: dal metadato
testuale alle comparisons appaiate (`design_role` LLM-driven entro lo
studio) → canonical `comparability_anchor` v3 cross-studio → pooling
effect-size random-effects (`metafor` REM). L'unico competitor end-to-end
vicino è RummaGEO (Maayan 2024), che però resta a livello di gene-set
per-studio senza anchor canonico né effect size. **Benchmark
testa-a-testa vs RummaGEO è deliverable integrale di P3.5 eval** (non
aggiunta opzionale post-hoc).

Pipeline complessiva (5 stadi):

1. **Acquisizione** — bulk RNAseq da ARCHS4-like (HDF5, ~700k+ sample da GEO).
2. **Stadio 1 sample-level** (P2 ✅) — classificare ogni sample dalla
   stringa di metadati GEO in un record JSON `sample_facts.stage1.v3`
   (cell context, perturbazioni, dose, tempo, ambiguity flags).
3. **Stadio 2 study-level** (P3 ✅) — interpretare il design
   sperimentale dello studio: replicate groups, design_role per sample,
   comparisons con `comparability_anchor` canonicalizzato per
   cross-studio matching.
4. **Stadio 3 raggruppamento** — cluster cross-studio sui
   `comparability_anchor`.
5. **Stadio 4 DE per-studio + Stadio 5 meta-analisi**
   (`DESeq2`/`limma` + `metafor` REM).

## Asset chiave — gold standard

`data-raw/relevant_sample_classified.xlsx` (committato nel repo, ~10 MB).

- Foglio `relevant_sample`: 130.784 righe × 8 colonne.
- Colonne: `Column1`, `string` (input metadata), `trtctr_EP` (gold
  manuale autore), `geo_accession`, `series_id`, `treat`, `trtctr`
  (baseline shallow), `gold` (ricontrollo terzo revisore).
- `trtctr_EP` riflette una semantica "qualunque intervento esplicito"
  che diverge da `design_role` — il gold "design-aware" è in
  `inst/extdata/p35c-minigold-reviewed-v5.csv` (100 sample, P3.5-C/D).

## Stato corrente (2026-05-11 — P4 α stage2 CHIUSO + ADR-0010 vLLM upgrade complete)

Pipeline classification stage1 + stage2 **completa e validata + upgraded**:

- **α stage1** (Task 21, 2026-05-07) → 130.784 / 130.784 = **100.00%** schema. Dettagli NEWS 0.0.0.9009-0.0.0.9011 + ADR-0008.
- **α stage2** original (Task 22, 2026-05-10, v0.10.0 + workaround stack) → 8.532 / 8.546 cs25 = 99.84% schema, mini-gold 93.3%.
- **α stage2 re-run cs50** (ADR-0010, 2026-05-11, v0.20.2-cu129 + clean stack) → **6.649 / 6.652 cs50 = 99.96%** schema single-pass, **mini-gold 96.7%** (+3.4pp). Default flipped cs25→cs50.

**Pipeline running config (post ADR-0010, 2026-05-11)**:

- **Container**: `vllm/vllm-openai:v0.20.2-cu129-ubuntu2404` (cu129 per driver 535 DGX compat).
- **Modello**: `mistralai/Mistral-Small-3.2-24B-Instruct-2506` self-hosted FP16 su DGX H100. Costo $0.
- **vLLM API**: `StructuredOutputsParams` (backend auto = xgrammar→outlines fallback). `GuidedDecodingParams` rimosso in vLLM v0.12.0.
- **Sampling** (ADR-0008): `temperature=0.0, repetition_penalty=1.1` stage1+stage2. Tier-based per-record max_tokens stage2 (S/M/L/XL → 4K/8K/16K/32K, ADR-0011).
- **Concurrency restored** (post PR #40946): `max_num_seqs=6, microbatch=50` stage2. Safe-mode (ADR-0009) declassato a fallback contingency.
- **Stage2 chunking**: `chunk_size=50` in `analysis/p4-stage2-build-input.R::CHUNK_SIZE` (default cs50 dopo H1 evidence +3.4pp, ADR-0010 addendum + ADR-0013). cs25 fallback se variance dataset diverso.
- **Schema validation**: structured_outputs = parser-grade by construction. Heuristic recovery Python+R **rimossa** (Phase 5 cleanup ADR-0010).
- **Tag attivo**: `p4-vllm-upgrade-v0.20.2-complete` (commit 31c676a, addendum 89ca20e per cs50 flip).
- **Branch attivo**: `master`. **Test**: 544 PASS / 0 FAIL / 3 SKIP (skip pre-esistenti OPENAI_API_KEY).

**File risultato α**:

- `analysis/p4-output/alpha-stage1-final.rds` (130.784 × 7, colonna `rescue_source` traccia provenienza)
- `analysis/p4-output/alpha-stage2-cs25-final.rds` (legacy v0.10.0 alpha, conservato per audit storico)
- `analysis/p4-output/20260510T215308Z-p5-alpha-cs50-final-8db4c0/predictions.jsonl` (cs50 v0.20.2 alpha, 6649/6652 valid)
- `analysis/p4-output/phase3-h1-eval-20088.rds` (H1 mini-gold cs50 eval)

## Convenzioni operative dell'utente

### Tracciabilità — ogni decisione documentata

Mai prendere una decisione architetturale senza scriverla in modo
durevole prima di committare codice che la riflette.

- **ADR** (decisioni architetturali) → `docs/decisions/NNNN-<slug>.md`. Template in `docs/decisions/template.md`.
- **Spec** (brainstorming/design) → `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
- **Plan** (implementazione) → `docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md` + companion HUMANE per la review umana.
- **Commit atomici** con messaggi italiani descrittivi formato `P<N> Task <M>: <azione>`. Sono il "come tecnico" complementare all'ADR.

A fine milestone: raccogliere materiale da ADR/spec per generare /
aggiornare vignette o capitoli del futuro manuale.

### Git workflow

- **Branch per fase:** `p<N>-<slug>` (es. `p2-stage1`).
- **Merge fast-forward only** su master a fine fase. Tag `p<N>-<slug>-complete`.
- **MAI fare `git push`** — l'utente lo fa lui, sempre. Master locale può essere molti commit ahead.
- **MAI usare `--no-verify` o `--no-gpg-sign`** salvo richiesta esplicita.
- Pulire `renv/settings.json` (untracked, autogenerato) e ripristinare `analysis/_targets/.gitignore` + `analysis/_targets/meta/meta` (rigenerati da `tar_make`) prima di ogni commit.

### Convenzioni codice

- **Italiano nei commenti, docstring, messaggi commit, error messages.**
  ASCII per i caratteri accentati nei file Rd generati da roxygen
  (usare `§`/`—` o equivalenti `sec.`/`--` nel roxygen `#'`).
- Funzioni interne: `@keywords internal`. Solo i veri entry point sono `@export`.
- TDD bite-sized (test → fail → impl → pass → commit) per ogni step di plan.

### Note operative tecniche ricorrenti

- **renv 0.16.0 (lockfile) vs renv 1.1.4 (installato):** `Rscript -e ...` (no vanilla) può non trovare `devtools` perché renv intercetta il libpath. Workaround: `Rscript --vanilla -e ...` bypassa renv e usa system libs (devtools/targets installati globalmente). **Sul server DGX (R 4.6.0)** è il contrario: usare `Rscript -e ...` SENZA `--vanilla` (renv lib path corretta nel project).
- **`callr_function = NULL` per `tar_make`:** indispensabile quando i target chiamano OpenAI. callr crea sub-process R che NON ereditano la API key dal parent.
- **`format = "qs"` non disponibile su CRAN per R 4.5.2** → P2 usa `format = "rds"` per `tar_option_set`.
- **`sample_facts_validator` storizza un PATH allo schema, non il validator compilato** — i contesti V8 di `jsonvalidate` non sono serializzabili in RDS. `compile_schema()` viene chiamato inline nei target di partition.
- **MAI fare `git checkout -- analysis/_targets/meta/meta` MENTRE un `tar_make` è in corso**: il meta viene aggiornato in tempo reale, un checkout lo riporta a stato pre-run e il job successivo non riconosce più gli oggetti già calcolati. La convenzione "ripristina meta prima del commit" vale solo quando NESSUN tar_make sta girando in background.
- **Hang HTTP transitorio iniziale**: la prima call OpenAI dopo network glitch può essere catturata in I/O wait su socket (CPU 0%, processo S, TCP ESTABLISHED) senza timeout effettivo del `req_timeout(120s)` di httr2 (rare edge case). Workaround: kill + retry.
- **NON re-introdurre `temperature = 0` come default** in `R/llm-client-openai.R` (gpt-5.5 reasoning models ritornano 400 `unsupported_value` su qualunque temperature esplicita). Per output deterministici su modelli storici (gpt-4o, gpt-5.4-mini), passare `temperature = 0` esplicito dal chiamante.

### Note operative DGX (P4 cluster)

- **Path `/home/u0044/` NON `/mnt/home/u0044/`** — i compute node UniPD HPC non montano `/mnt/home/`. Sintomo del bug: ExitCode `0:53` con job FAILED in 2 secondi senza log files.
- **ssh non-interattivo NON sourca `/etc/profile.d/*.sh`** → `SLURM_CONF` mancante. Fix in `R/dgx-utils.R::.dgx_ssh()`: wrap del comando remoto con `bash -lc <cmd>` per forzare login shell.
- **Esecuzione singularity diretta, NO `srun`** — `srun singularity` non è supportato/affidabile su questo cluster. Usare `singularity exec --nv ...` direttamente.
- Vignette setup completa: `vignettes/p4-dgx-setup.Rmd`.

## Decisioni rinviate

- **ADR-0003 — rinome pacchetto.** "simulomicsr" non riflette la pipeline. Da affrontare prima del primo `install_github` pubblico.
- **ADR-0010 — vLLM upgrade evaluation.** Aprire SOLO dopo chiusura α + tag p4-dgx-complete; vLLM Issue #39734 non risolto upstream nemmeno in 0.19.x.
- **Vocabolari extra** (Cellosaurus, DrugBank, ChEMBL, MeSH, CAS, NCBITaxonomy, MGI). Necessari per Stadio 2 esteso (post-α).
- **Gold "design-aware"** scaled su 200-300 sample. Mini-gold v5 attuale è 100 sample.
- **Integrazione MetaHQ** come upstream per `normalize_tissue()` / `normalize_disease()` in Stadio 2.
- **Migrazione a `ellmer`** come client LLM (multi-provider, batch API più ergonomico). ADR separato post-α.
- **Cache cross-modello.** P1 attuale partiziona per `(provider, model, messages)`. Se servisse cache cross-modello, ADR dedicato.
- **Migrazione su server con più spazio.** ADR-0005 documenta trigger e procedura.
- **Findings sotto-soglia P3.5-A** (eventuale prompt iter post-α): `treatment_vs_untreated` 77.3% (n=141), `time_course` 59.3% (n=54), `case_control_disease` 49.1% (n=57, sotto casuale).

## Roadmap post-α

1. **Cleanup CLAUDE.md + audit specs/plans + tag p4-dgx-complete + merge** (in corso 2026-05-10).
2. **P4 β: ETL ARCHS4 H5 → JSONL** (700k sample / 22k studi). Plan separato.
3. **Output 3 ADR-0006**: P5 Stadio 4+5 (DESeq2/limma + metafor REM).
4. **Rename pacchetto** (ADR-0003) prima del primo `install_github` pubblico.
5. **Migrazione a `ellmer`** come ADR separato.

## Dove vivere i dati che il repo NON contiene

| Asset                       | Location                                                          | Come ottenerlo / ricostruirlo                                            |
|-----------------------------|-------------------------------------------------------------------|--------------------------------------------------------------------------|
| `OPENAI_API_KEY`            | `.Renviron.local` (gitignored)                                    | Utente ricrea manualmente. Riga `OPENAI_API_KEY="sk-..."`.               |
| renv libreria               | `~/Library/Caches/.../renv/` (macOS) o `~/.cache/R/renv/` (Linux) | `renv::restore()` da `renv.lock` committato.                             |
| HGNC dump completo          | `tools::R_user_dir("simulomicsr", which="cache")/hgnc_complete_set.tsv` | Download manuale da `https://www.genenames.org/download/archive/`.   |
| Cache LLM                   | `analysis/cache/` (gitignored)                                    | Auto-popolata dai run di `tar_make`. Trasferibile via `rsync`.           |
| Pipeline state              | `analysis/_targets/` (gitignored)                                 | Auto-popolato da `tar_make`. Trasferibile via `rsync`.                   |
| ARCHS4 H5, matrici          | `analysis/input/` (gitignored)                                    | Download diretto sul server da NCBI/ARCHS4.                              |
| File risultato α stage1/2   | `analysis/p4-output/*.rds` (gitignored)                           | Output dei job DGX, ricostruibili da `analysis/p4-bundles/*-job.rds`.    |
| Bundle/runtime DGX          | `analysis/p4-bundles/` (gitignored)                               | Generati da `dgx_p4_build_bundle()`.                                     |

## Riferimenti chiave

### ADR (decisioni architetturali, in `docs/decisions/`)

- 0001 sistema-tracking · 0002 struttura-research-compendium · 0004 renv-riconciliato · 0005 server-migration-trigger
- **0006 stato-arte-vs-simulomicsr** — analisi competitor 2024-2026 + benchmark RummaGEO + decisione P3-B
- **0007 dgx-self-host-vllm** — bespoke minimale dentro simulomicsr + workflow Docker→DockerHub→Singularity
- **0008 vllm-sampling-defaults** — temperature=0.0, repetition_penalty=1.1 stage1+stage2
- **0009 stage2-safe-mode-vllm-deadlock** — `max_num_seqs=1, microbatch=1` stage2 deadlock-proof Issue #39734
- **0011 tier-based-max-tokens** — single-pass strategy per stage2 con per-record max_tokens proporzionato
- **0012 stage2-schema-multi-axis-limitation** — known limit `primary_role` mono-axis vs design factoriali (paper-grade note)

### Specs / plans (in `docs/superpowers/`)

- Spec classificatore: `specs/2026-04-29-classificatore-llm-design.md` (v5 approvata 2026-04-29).
- Plan P1-P4: `plans/<date>-p<N>-*.md` + companion HUMANE.
- Spec investigation Task 22: `specs/2026-05-08-task22-stage2-vllm-stalls-investigation.md` (RESOLVED).

### Report Quarto

- `analysis/eval/p35-benchmark.html` (838 KB) — P3.5-B prototipo (15 GSE, 197 sample).
- `analysis/eval/p35a-benchmark.html` (980 KB) — P3.5-A scaled (100 GSE, 1507 sample, paper-ready: Wilson CI + McNemar + bootstrap + Holm).

### Documentazione storica

- **`docs/model-evaluation-history.md`** — valutazioni P3.5-C (5 modelli closed) + P3.5-D (21 modelli OpenRouter) + pattern strutturali + decisione mistral-small-3.2.

### Vignette + utenti

- `vignettes/p4-dgx-setup.Rmd` — one-time guide setup DGX.
- `README.md`, `NEWS.md` — entry point utente + storia versioni.
