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

## Stato corrente (2026-05-12 — P4 β ARCHS4 ETL + gates 1+2 PASS, pending full run)

### α (consolidato, riproducibile)

Pipeline classification stage1 + stage2 sul gold-standard XLSX 130.784 sample:

- **α stage1** (Task 21, 2026-05-07) → 130.784 / 130.784 = **100.00%** schema. Dettagli NEWS 0.0.0.9009-0.0.0.9011 + ADR-0008.
- **α stage2** original (Task 22, 2026-05-10, v0.10.0 + workaround stack) → 8.532 / 8.546 cs25 = 99.84% schema, mini-gold 93.3%.
- **α stage2 re-run cs50** (ADR-0010, 2026-05-11, v0.20.2-cu129 + clean stack) → **6.649 / 6.652 cs50 = 99.96%** schema single-pass, **mini-gold 96.7%** (+3.4pp). Default flipped cs25→cs50.

### β (in corso, gates 1+2 PASS 2026-05-12)

Pipeline scalata su ARCHS4 v2.5 human bulk RNA-seq (~10x α):

- **β ETL** (Task β-1..β-6, 2026-05-12) → **888.821 sample** human + RNA-Seq, 32.905 unique GSE pre-resolver, **193.097 multi-series** risolti. Output JSONL `analysis/input/archs4-human-stage1-input.jsonl` (262 MB, gitignored).
- **β series-id-resolver SRP-driven Op D revised** (`R/etl-series-resolver.R`, Task β-4): 99.86% resolti via signal (`clean_super_scarted` 183.041 + `srp_a_only/b_only` 9.011 + minor branches), 0.54% heuristic tiebreak/fallback (1.041 sample), 0 sample droppati. Test 23-pair gold replication PASS (Exp D2).
- **β GATE #1** mini-gold format B (Task β-8, 2026-05-12): stage1+stage2 end-to-end su 100 mini-gold → schema 100% s1 + 100% s2, **accuracy binaria 98.00%** (mappato design_role_v3 → control/treated via `R/eval-stage2.R::design_role_to_binary`). +1.3pp vs α 96.7%. Wall DGX 4 min totali.
- **β GATE #2** smoke 1000 stratificato per nchar quartile (Task β-9, 2026-05-12): schema **99.50% s1 + 100% s2**, 5 LLM fail droppati lenient (0.5%), tier S=718 M=3 L=0 XL=0 (no overflow), design_kind distribution sana (case_control 40%, treatment_vs_vehicle 18%, multi_arm 17%). Stage1 wall reale ~3.5 min → **ETA stage1 full ~59h** (più alto del plan 35h ma fattibile, partition `dgx12cluster` infinite). Stage2 wall 6.6 min per 721 record → ETA stage2 full ~2.5h.

**Pipeline running config (invariata da α)**:

- **Container**: `vllm/vllm-openai:v0.20.2-cu129-ubuntu2404` (cu129 per driver 535 DGX compat).
- **Modello**: `mistralai/Mistral-Small-3.2-24B-Instruct-2506` self-hosted FP16 su DGX H100. Costo $0.
- **vLLM API**: `StructuredOutputsParams` (backend auto = xgrammar→outlines fallback). `GuidedDecodingParams` rimosso in vLLM v0.12.0.
- **Sampling** (ADR-0008): `temperature=0.0, repetition_penalty=1.1` stage1+stage2. Tier-based per-record max_tokens stage2 (S/M/L/XL → 4K/8K/16K/32K, ADR-0011).
- **Concurrency restored** (post PR #40946): `max_num_seqs=6, microbatch=50` stage2. Safe-mode (ADR-0009) declassato a fallback contingency.
- **Stage2 chunking**: `chunk_size=50` (cs50 default, ADR-0010 addendum + ADR-0013).
- **Schema validation**: structured_outputs = parser-grade by construction.

**Tag/branch attivi**:

- Tag α: `p4-vllm-upgrade-v0.20.2-complete` (commit 31c676a, addendum 89ca20e per cs50 flip).
- Branch β attivo: `p4-beta-archs4-human` (HEAD ~20 commit ahead di `master`). Tag finale `p4-beta-archs4-human-complete` post Task β-15 closing.
- **Test**: 544 PASS / 0 FAIL / 3 SKIP α-level (skip pre-esistenti OPENAI_API_KEY) + 41 PASS β resolver = 585 total tests.

**File risultato α + β attualmente sul disco**:

- α stage1: `analysis/p4-output/alpha-stage1-final.rds` (130.784 × 7, colonna `rescue_source`)
- α stage2 cs50: `analysis/p4-output/20260510T215308Z-p5-alpha-cs50-final-8db4c0/predictions.jsonl` (6649/6652 valid)
- α eval mini-gold cs50: `analysis/p4-output/phase3-h1-eval-20088.rds`
- β ETL output JSONL stage1-input: `analysis/input/archs4-human-stage1-input.jsonl` (gitignored, 262 MB)
- β ETL provenance: `analysis/p4-output/p4-beta-archs4-source.json` (committato force-add)
- β H5 source: `analysis/input/human_gene_v2.5.h5` (47.86 GB, gitignored; SHA256 `a1063426cb51986c77574d80d344918a075804c155e9b18c2e551b1077ad5d18`)
- β cache Entrez resolver: `tools::R_user_dir("simulomicsr","cache")/geo-series-resolver-cache.rds` (~25 MB, 32.905 GSE)
- β GATE #1 eval: `analysis/p4-output/20260512T142323Z-p4-beta-gate1-minigold-eval.rds` (force-add committato)
- β GATE #2 eval: `analysis/p4-output/20260512T150505Z-p4-beta-gate2-smoke1000-eval.rds` (force-add committato)

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
- **β retry/uniqfail infrastructure pre full run.** Smoke 1000 mostra ~0.5% LLM fail rate (5/1000 sample con `parsed_json$series_id` NULL). Su 888k sample = ~4.500 sample droppati. Per pareggiare α (100% schema post-recovery) servirebbe replicare il pattern α retry-rep11/temp00/uniqfail rounds anche per β stage1. Attualmente β stage2-input è lenient (warning + drop). Acceptable per gate ma da formalizzare in Task post β-15.
- **β gate2 throughput measurement bug** (cosmetico, gate-decision non impattata). Lo script `analysis/p4-beta-gate2-smoke.R` misura wall come `Sys.time()` pre/post `poll_until_done`, ma resume da job COMPLETED restituisce ~5 sec → "throughput 9996 rec/min" artefatto. Fix corretto: pull `sacct -j JID --format=Elapsed` e usare quello come wall reale. ETA stage1 full corretta calcolata a mano dal log poll iniziale: ~59h.

## Roadmap

### Immediato (post β gates 2026-05-12)

1. **β Task 10 stage1 full run** ~50-60h DGX wall. **NUOVA SESSIONE** per `validate-before-fullrun` memory rule. Input: `analysis/input/archs4-human-stage1-input.jsonl` (888.821 sample).
2. **β Task 12 stage2 full run** ~2.5-3h DGX wall (post stage1 output + Task 11 stage2-input). Input: chunked stage2 records (~17k attesi).
3. **β Task 15 closing** — NEWS bump 0.0.0.9016, tag `p4-beta-archs4-human-complete`, ff-merge → master.

### Post-β

1. **Output 3 ADR-0006**: P5 Stadio 4+5 (DESeq2/limma + metafor REM) sui β results.
2. **Rename pacchetto** (ADR-0003) prima del primo `install_github` pubblico.
3. **Migrazione a `ellmer`** come ADR separato.
4. **γ ARCHS4 mouse** (post-human consolidato; "alla fine di tutto quando human funziona"). NO γ in pianificazione attiva — gestito come variante futura.

## Dove vivere i dati che il repo NON contiene

| Asset                       | Location                                                          | Come ottenerlo / ricostruirlo                                            |
|-----------------------------|-------------------------------------------------------------------|--------------------------------------------------------------------------|
| `OPENAI_API_KEY`            | `.Renviron.local` (gitignored)                                    | Utente ricrea manualmente. Riga `OPENAI_API_KEY="sk-..."`.               |
| renv libreria               | `~/Library/Caches/.../renv/` (macOS) o `~/.cache/R/renv/` (Linux) | `renv::restore()` da `renv.lock` committato.                             |
| HGNC dump completo          | `tools::R_user_dir("simulomicsr", which="cache")/hgnc_complete_set.tsv` | Download manuale da `https://www.genenames.org/download/archive/`.   |
| Cache LLM                   | `analysis/cache/` (gitignored)                                    | Auto-popolata dai run di `tar_make`. Trasferibile via `rsync`.           |
| Pipeline state              | `analysis/_targets/` (gitignored)                                 | Auto-popolato da `tar_make`. Trasferibile via `rsync`.                   |
| ARCHS4 H5 human v2.5        | `analysis/input/human_gene_v2.5.h5` (47.86GB, gitignored)         | `wget -c https://mssm-data.s3.amazonaws.com/human_gene_v2.5.h5` (~1.5h wall). SHA256 + provenance in `analysis/p4-output/p4-beta-archs4-source.json`. |
| File risultato α stage1/2   | `analysis/p4-output/*.rds` (gitignored)                           | Output dei job DGX, ricostruibili da `analysis/p4-bundles/*-job.rds`.    |
| β ETL output JSONL          | `analysis/input/archs4-human-stage1-input.jsonl` (262MB, gitignored) | Re-generato da `Rscript analysis/p4-beta-etl-build.R` (richiede H5 + cache Entrez). Stage 4 vectorizzato ~3 sec con cache full, ~5min Stage 2 H5 re-read. |
| β cache Entrez resolver     | `tools::R_user_dir("simulomicsr", which="cache")/geo-series-resolver-cache.rds` | Re-buildabile via `entrez_lookup_gse_metadata` (~5-6h wall per 32.9k GSE @ ~1.5 GSE/s con NCBI_API_KEY). |
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
