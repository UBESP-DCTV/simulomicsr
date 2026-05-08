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

## Stato corrente (2026-05-07 fine sessione P4 — α stage1 100.00% valid, Task 22 next)

- **Branch:** `p4-dgx-integration` (19+ commit ahead di master, **non pushato**).
- **Tag:** `p1-infra-llm-complete`, `p2-stage1-complete`, `p3-stage2-complete`, `p3.5b-eval-complete`, `p3.5a-eval-complete`, `p3.5c-confidence-complete`, **`p4-smoke-complete`** (Task 18+19+20 superati). P4 ancora NON `p4-dgx-complete` (manca α run Task 22 stage2).
- **Default vLLM SamplingParams aggiornato 2026-05-07**: `temperature=0.0 + repetition_penalty=1.1 + max_tokens=2048` per stage1 in `inst/extdata/p4-defaults.yml` (era max_tokens 1024). Stage2 invariato (`max_tokens=4096`). Ablation 5 setting paralleli su 1343 hard cases ha provato che rep_pen e' IL fix (0% → 84% recovery) e temperature ha contributo marginale (+1.8 pp da 0.0 a 0.4) ma porta drift contenutistico (concordance pert.kind 88% a temp 0.4 vs 100% a temp 0.0). Successiva investigation 211 residual fails (jobs 19748+19749, +5 min) ha mostrato che il vero collo di bottiglia residuo era `max_tokens=1024` per Mode B (97% dei residui = legit truncation su input multi-perturbazione) e `repetition_penalty=1.2` come escape hatch per Mode A (3% = decoder loop su `engineered_modifications[].variant`). Vedi sezioni "Ablation" + "Investigation 211 residual fails" sotto.
- **R CMD check:** 0E / 1W (pre-esistente non-P4 in `dot-openrouter_parse_response.Rd`) / 3 NOTE.
- **Test suite:** 520 PASS / 0 FAIL / 3 SKIP (skip per OPENAI_API_KEY non impostata, pre-esistente).
- **Smoke DGX end-to-end VERDE** (job 19723 su poddgx03, 2026-05-07): Mistral-Small-3.2 caricato in 125s (44.7 GiB GPU), 1 prompt JSON-strict generato in 1.44s con `parsed={'ack':'ok','n':42}`. Pipeline confermata: container → torch+CUDA → vLLM → mistral_common tokenizer → guided decoding → output JSON valido.
- **Plan Task 18 VERDE** (job 19725 poddgx02, 2026-05-07): smoke 1-GPU 100 record reali, COMPLETED in **1:35** (32s load cache hit + 31.6s gen), 100/100 schema valid, mediana confidence 0.80. Pipeline `bundle → run_p4_vllm.py → resume.py → predictions.jsonl` validata su record reali (xlsx head 100). Submit manuale (rsync+sbatch) per gpu:1/workers 1.
- **Plan Task 19 VERDE** (job 19726 poddgx02, 2026-05-07): smoke 4-GPU 100 record via `dgx_p4_submit()` non-dry-run (R-only workflow end-to-end), COMPLETED in **1:56**, 4 worker stripe 25/25/25/25, 100/100 schema valid. Per 100 record 4-GPU è leggermente più lento di 1-GPU (overhead 4× cold load > saving shard 4×); parity break a centinaia di record. Per α run (~5400 GSE / 130k sample) il 4-GPU dominerà nettamente.
- **Plan Task 20 VERDE** (job 19727 + 19728, 2026-05-07): resume verification end-to-end. Run 1 scancel a t=87s con count=2 worker file → 75 record committati, 25 todo (worker 1 killed prima di scrivere). Run 2 re-submit stesso bundle via `dgx_p4_submit(bundle, ...)`: `[main] totale=100 done=75 todo=25`, sharding 25 su 4 worker (7+6+6+6), COMPLETED in 1:54, predictions.jsonl finale = 100 unique record_id. Pattern: per riprendere basta richiamare `dgx_p4_submit()` con lo stesso bundle (run_id stabile, bundle rsync idempotente, `runs/<run_id>/` su cluster preserva worker file partial).
- **Plan Task 21 VERDE** (job 19730 poddgx02, 2026-05-07): run α stage1 130784 record xlsx, COMPLETED in **1h 18min** wall clock (09:34→10:52 UTC), molto sotto stima 3-4h. **124,979 schema valid (95.56%)** + 5,805 invalid + 0 missing (req plan ≥ 95% PASS). Throughput stabile ~5040 toks/s/worker output, 4× H100 in parallelo. Costo: $0 (DGX self-host). Coverage mini-gold v5: 100/100 (98 valid, 2 invalid). Vedi sezione "Risultati P4 α stage1" sotto.
- **Plan Task 21 retry temp 0.1** (job 19735 poddgx02, 2026-05-07): re-run dei 5805 invalid con `temperature: 0.1` (era `0.0`), COMPLETED in **7:08**. Recuperati **2,154 / 5,805 (37.1%)** → totale finale **127,133 / 130,784 = 97.21% valid** (+1.65 pp vs run originale). I 3,651 record ancora fail hanno richiesto investigation strutturata e fix vero (vedi sezione "Ablation P4 stage1 sampling params" + "Propagation rescue strategy" sotto).
- **Investigation errori 2026-05-07 + fix definitivo** (jobs 19737-19740 paralleli): trovato che il **53% degli errori clusters in 73 series** (GSE180954 da sola = 79.6% fail rate) e che **63% dei FAIL hanno duplicato OK byte-identical** in altre repliche dello stesso studio → conferma forte di non-determinismo fp16/bf16 nel guided decoder. **Strategia rescue in due fasi**: (a) propagation di parsed_json da OK sibling con stessa stringa (recupera 2308/3651 con zero rischio semantico); (b) re-run sui 1343 unique-fail con `repetition_penalty=1.1` (il fix vero che rompe il whitespace flood). Default approvato: **`temperature=0.0 + repetition_penalty=1.1`**.
- **Investigation 211 residual fails 2026-05-07** (jobs 19748+19749, +5 min DGX): caratterizzazione binaria → **Mode B (205, 97%)** = legitimate truncation a `max_tokens=1024` su input multi-perturbazione (median raw_output 3231 char vs 1748 OK con stesso config); **Mode A (6, 3%)** = decoder loop sul boundary `engineered_modifications[].variant ["object","null"]`. **Fix Mode B**: `max_tokens 1024 → 2048` (single change, recover 205/205 = 100%). **Fix Mode A**: `repetition_penalty 1.1 → 1.2` (single change, applicato solo ai 6 residual, recover 6/6 = 100%, content quality verificata). **Risultato finale α stage1: 130,784 / 130,784 = 100.00000% valid** (124,979 originali + 2,308 propagati + 1,132 recuperati rep_pen 1.1 + 205 max_tokens 2048 + 6 rep_pen 1.2). Default `p4-defaults.yml` stage1 aggiornato a `max_tokens=2048` (rep_pen 1.1 resta default; rep_pen 1.2 documentato come escape hatch). Vedi sezione "Investigation 211 residual fails" sotto.
- **Server di sviluppo cambiato**: ora R 4.6.0 (era 4.5.2 sul laptop). Dev tools nella renv project lib (`~/.cache/R/renv/library/simulomicsr-ba33d608/.../R-4.6/`). **Usare `Rscript -e '...'` SENZA `--vanilla`** — su questo server `--vanilla` perde la libpath di renv. CLAUDE.md storico era allineato al laptop, l'operational note va invertita su questo server.

### P4 implementation completata localmente (Plan Task 1-16)

15 commit P4 sul branch:

- Task 1-2: DESCRIPTION (`processx`, `yaml`) + `.gitignore` (`analysis/p4-output/`, `analysis/p4-bundles/`, `inst/dgx/python/__pycache__/`).
- Task 3-4: `R/dgx-config.R` + `R/dgx-utils.R` (helpers `.dgx_run_id`, `.dgx_render_slurm_template`, `.dgx_ssh`, `.dgx_rsync`).
- Task 5: `inst/extdata/p4-defaults.yml` (model_id, sampling per stage, slurm_defaults).
- Task 6: `R/dgx-bundle.R` (`dgx_p4_build_bundle()` stage1+stage2) + fixtures.
- Task 7-8: `inst/dgx/python/{prompts.py,resume.py,__init__.py}` (port 1:1 user message R, idempotenza JSONL).
- Task 9: `inst/dgx/python/run_p4_vllm.py` (4 worker DP via multiprocessing, vLLM offline batch + guided JSON).
- Task 10: `inst/dgx/{Dockerfile,Makefile,.dockerignore}` (workflow allineato 1:1 a `2026.scRNA_DGX/Makefile`: docker build locale → push DockerHub → singularity pull cluster, NO SSH wrapping nel Makefile, NO apptainer build remote).
- Task 11: `inst/dgx/slurm/run_p4.sh` template SLURM.
- Task 12-13: `R/dgx-submit.R` (`dgx_p4_submit/status/collect/recover`) + tests mocked processx via `testthat::local_mocked_bindings`.
- Task 14: NAMESPACE rigenerato + R CMD check cleanup (rimossi `:::` interni, `stats::` prefix per `runif`/`setNames`, `.Rbuildignore` aggiornato per laims-dgx-llm-batch-main + Makefile + .dockerignore).
- Task 15: `docs/decisions/0007-dgx-self-host-vllm.md` (ADR).
- Task 16: `vignettes/p4-dgx-setup.Rmd` (one-time guide).

**5 funzioni esportate**: `dgx_config()`, `dgx_p4_build_bundle()`, `dgx_p4_submit()`, `dgx_p4_status()`, `dgx_p4_collect()` + `dgx_p4_recover()` di servizio.

### P4 cluster setup — operativo

Sul DGX UniPD HPC (`logindgx.hpc.ict.unipd.it`, login `podhead1`, user `u0044`):

- ✅ `~/.simulomicsr-dgx.env` con HF_TOKEN.
- ✅ Directory `/home/u0044/simulomicsr-dgx/{runtime,bundles,runs,models/HF_HOME,logs}`. **NB: `/home/u0044/`, NON `/mnt/home/u0044/`** (vedi lessons learned).
- ✅ Image `lucavd/simulomicsr-vllm:latest` su DockerHub. **FROM `vllm/vllm-openai:v0.10.0`** (era v0.6.4 — bumpato 2026-05-07 per supporto `Mistral3Config`/mistral3 — vLLM 0.6.4 dava KeyError 'mistral3'). Torch 2.7.1+cu128.
- ✅ SIF `simulomicsr-vllm.sif` (~6 GB) via `singularity pull --force`.
- ✅ Modello `mistralai/Mistral-Small-3.2-24B-Instruct-2506` in HF cache (~50 GB pesi su disco, 44.7 GiB caricato in GPU bfloat16) via `make predownload-model`.
- ✅ **Smoke 1-GPU verde** (job 19723, 2:41 min end-to-end): nvidia-smi → torch → vLLM → mistral tokenizer → 1 prompt JSON-strict. Vedi `inst/dgx/slurm/smoke_1gpu.sh` e `inst/dgx/python/smoke_vllm.py`.

### Lessons learned operative durante P4 setup

1. **Path `/home/u0044/` NON `/mnt/home/u0044/`** — i compute node UniPD HPC (poddgx01/02/03) **non montano** `/mnt/home/`. Verificato col probe job 19720 su poddgx03 (`/mnt/home/u0044: No such file or directory`). Sul login (podhead1) entrambi i path puntano allo stesso dato, ma SLURM `--output`/`--error`/`--chdir` e i bind singularity DEVONO usare `/home/u0044/`. `dgx_config()` default `remote_root="/home/<user>/simulomicsr-dgx"`. Sintomo del bug: ExitCode `0:53` con job FAILED in 2 secondi senza log files (SLURM non riesce a creare `.out`/`.err`).
2. **vLLM ≥ 0.8.x richiesto per Mistral-Small-3.2** — `model_type "mistral3"` (multimodale) introdotto in transformers 4.49 a inizio 2025; vLLM v0.6.4 di Nov 2024 non lo conosce → `KeyError 'mistral3'` al load. Bumpato Dockerfile a `v0.10.0`. Inoltre il `Mistral3Config` non e' nel `TOKENIZER_MAPPING` HF: serve `tokenizer_mode="mistral"` (Tekken/`mistral_common`) e `llm.chat()` (no `apply_chat_template`).
3. **`vllm/vllm-openai:v0.6.4+` espone `python3`, NON `python`** — Dockerfile ENTRYPOINT corretto a `python3`, SLURM template chiama `python3 /opt/.../run_p4_vllm.py` esplicitamente.
4. **Nodelist default `poddgx02`** (nodo dell'utente) — `dgx_config()` default `nodelist="poddgx02"`. Validato col job 19724 il 2026-05-07: smoke poddgx02 89.9s load + 0.75s gen, identico a poddgx03 ma sul nodo dell'utente. Pass `nodelist=NULL` per lasciare scegliere lo scheduler se poddgx02 e' DRAIN/DOWN.
5. **Workflow Docker → DockerHub → Singularity allineato a scRNA_DGX**: NO SSH wrapping nel Makefile; target `pull-singularity`/`predownload-model` girano *sul login DGX dopo SSH*, non SSH-wrappati dal laptop.
6. **`--export=NONE` + `--chdir`** nelle directives SLURM — blocca env inheritance dal login (es. `SBATCH_PARTITION` dal `.bashrc`) che altrimenti override la partition. Source `~/.simulomicsr-dgx.env` esplicito *dentro* lo script.
7. **`runs/<run_id>/` deve esistere PRIMA del sbatch** — SLURM `--output`/`--error` puntano li' e fallisce con stesso signal 53 se la dir non c'e'. `dgx_p4_submit()` fa `mkdir -p` per `bundles/`, `runs/`, `runtime/python/` prima del sbatch.
8. **Esecuzione singularity diretta, NO `srun`** — `srun singularity` non e' supportato/affidabile su questo cluster. Usare `singularity exec --nv ...` direttamente come scRNA_DGX/smoke_test.sh (validato).
9. **`runtime/python/` bind-mounted, non dentro la SIF** — gli script Python (`run_p4_vllm.py`, `prompts.py`, `resume.py`) sono rsync-ati a ogni submit e bind-mountati su `/opt/simulomicsr/runtime/python` nel container. Aggiornamenti senza rebuild dell'immagine.
10. **ssh non-interattivo NON sourca `/etc/profile.d/*.sh`** (lesson Task 18-19 2026-05-07) — sintomo: `bash: line 1: sbatch: command not found` o (con path assoluto a sbatch) `sbatch: fatal: Could not establish a configuration source`. Causa: `SLURM_CONF`, modules e `PATH` SLURM sono settati solo dai profile script che il login shell carica. Fix in `R/dgx-utils.R::.dgx_ssh()`: wrap del comando remoto con `bash -lc <cmd>` per forzare login shell. Validato sul cluster reale via `dgx_p4_submit()` job 19726.

### Risultati P4 α stage1 (run 2026-05-07, job 19730)

**Run identifier**: `run_id=20260507T093437Z-alpha-xlsx-stage1-f8f6db`, slurm `19730`, nodelist `poddgx02`, 4× H100, time limit 12h, time effettivo **1h 18min** (09:34:37 → 10:52:46 UTC). Costo: $0 (self-host).

| Metrica | Valore |
|---|---|
| Records totali (xlsx post-dedup) | **130,784** |
| Schema valid | **124,979 (95.56%)** ✅ ≥95% req plan |
| Schema invalid | 5,805 (4.44%) |
| Missing (mai inviati) | 0 |
| Workers crashati | 0 |
| Throughput per worker (output) | ~5040 toks/s sostenuto |
| Cold load + warmup | ~7 min (model + torch.compile + KV cache) |
| Generation pura (slowest worker) | ~1h 12min su 32,696 record/worker |
| Mediana confidence (valid) | **0.80** (Q1=0.7, Q3=0.9) |
| Mini-gold v5 coverage | **100/100** (98 valid + 2 invalid) |
| Disease state distrib (valid) | none 68.8% / case 19.5% / disease_model 11.4% / comparison 0.3% |
| Sample con perturbations non-vuoto | 99.9% (atteso: xlsx è già pre-filtrato "relevant_sample") |

**Output locali**: `analysis/p4-output/<run_id>/predictions.jsonl` (463 MB), `analysis/p4-output/alpha-stage1-result.rds` (object completo con summary + tibble predictions/errors), `analysis/p4-bundles/alpha-stage1-{job,bundle}.rds`.

**Finding chiave — natura dei 5,805 errori (per follow-up post-α)**:

Gli errori NON sono violazioni di contenuto né classification mistakes. Sono **degenerate generation pathology** del guided decoding con greedy sampling:

- 0/5,805 errori sono "JSON-parse OK ma off-schema" (cioè zero violazioni semantiche).
- 5,802/5,805 (99.95%) NON terminano con `}` (output troncato).
- 4,709/5,805 (~81%) hanno lunghezza 1349-1400 char con coda di tab/null padding/zero — il modello in greedy mode con `GuidedDecodingParams(json=schema)` entra in loop dopo aver generato una porzione coerente di JSON e produce filler whitespace fino a `max_tokens=1024`.
- 483/5,805 sono veri truncation mid-struttura (output >2KB cut).
- Distribuzione lunghezza errori (char): min 1349, mediana 1381 (~395 token), max 3314.

**Investigation finale 2026-05-07 (vedi 2 sezioni successive)**: il fix definitivo e' `temperature=0.0 + repetition_penalty=1.1`. Default aggiornato in `inst/extdata/p4-defaults.yml`. Strategia rescue completa porta α stage1 a **99.84% valid** (130,573 / 130,784).

**Limitazione del confronto vs mini-gold v5**: il mini-gold P3.5-C/D contiene `design_role_gold`/`design_kind_gold` che sono concetti **stage 2 study-level**, mentre l'α stage1 produce `sample_facts.stage1.v3` (extraction-level: cell_context, perturbations, disease_state, ecc., senza design_role). Comparazione meaningful con mini-gold v5 si farà in **Task 22 (stage2 ~5.4k GSE)** dove l'output è direttamente `study_design.stage2.v2` con `design_role` + `design_kind`.

### Ablation P4 stage1 sampling params (2026-05-07, jobs 19737-19740)

Investigazione "una variabile alla volta" sui 1343 unique-FAIL del run α (FAIL post-retry temp 0.1, **senza duplicato OK byte-identical** in altre repliche). 4 run paralleli stesso input + retry temp 0.1 alone come baseline:

| Setting                         | Recovery (su 1343) | vs default | Wall (4 GPU) |
|---------------------------------|--------------------|------------|--------------|
| temp 0.1 alone (no rep_pen)     | **0%**             | (baseline) | ~3 min       |
| temp 0.0 + rep_pen 1.1          | **84.3%** (1132)   | +84.3 pp   | ~3 min       |
| temp 0.1 + rep_pen 1.1          | 85.2% (1144)       | +85.2 pp   | ~3 min       |
| temp 0.2 + rep_pen 1.1          | 85.5% (1148)       | +85.5 pp   | ~3 min       |
| temp 0.4 + rep_pen 1.1          | 86.1% (1156)       | +86.1 pp   | ~3 min       |

**Concordance pairwise** (sui record recuperati da entrambi):

| Pair                              | n     | pert.kind | disease.status |
|-----------------------------------|-------|-----------|----------------|
| temp 0.0+rep vs temp 0.1+rep      | 1105  | **93.8%** | **96.3%**      |
| temp 0.0+rep vs temp 0.2+rep      | 1104  | 92.2%     | 94.9%          |
| temp 0.0+rep vs temp 0.4+rep      | 1097  | 87.4%     | 91.2%          |

**Findings:**
1. **`repetition_penalty=1.1` e' IL fix definitivo**: 0% → 84-86% indipendentemente dalla temperatura. Senza rep_pen il greedy resta intrappolato in whitespace/null padding flood ai field-boundary `["string","null"]` (es. `cell_line_cellosaurus_candidate` post `cell_type_or_line_raw`). Con rep_pen 1.1 il modello e' obbligato a produrre token diversi → uscita pulita dal loop.
2. **Temperatura ha contributo marginale**: +1.8 pp totale da 0.0 a 0.4. Il guadagno NON vale il drift contenutistico (concordance pert.kind crolla a 87% a temp 0.4 — significa il 13% dei record recuperati avrebbe classificazione diversa per perturbazione).
3. **127 record (9.5%) sono irrecuperabili** da QUALUNQUE config testata — ipotesi: stringhe input con caratteri/pattern che fanno collassare lo stato del guided decoder a prescindere dal sampling. Da investigare in nuova sessione.

**Default approvato 2026-05-07**: `temperature=0.0 + repetition_penalty=1.1` per stage1 e stage2 (vedi `inst/extdata/p4-defaults.yml`). Massima riproducibilita' (greedy deterministico modulo non-determinismo bf16 vLLM) + recovery sostanziale dei degenerate cases.

Code change abilitazione `repetition_penalty`:
- `inst/dgx/python/run_p4_vllm.py::worker_main()` — accetta opzionale `repetition_penalty`/`top_p`/`min_p` da `gen` dict, li passa a `SamplingParams(**extra_kwargs)`.
- `R/dgx-bundle.R::dgx_p4_build_bundle()` — propaga gli stessi 3 campi opzionali da `stage_def` (yaml) a `generation.json` se presenti.

### Propagation rescue strategy (2026-05-07, recovery zero-cost-zero-risk)

Pattern emerso durante investigation: nel pool di 3651 FAIL post-retry temp 0.1, **2308 record (63.2%) hanno almeno un duplicato OK byte-identical** in altre repliche dello stesso studio (es. GSM5479237 OK e GSM5479238 FAIL hanno la stessa stringa "cell line: HEK293T,treatment: 1microg/mL doxycycline; 24 hours"). Inoltre **53.3% degli errori si concentra in 73 series con >50% fail rate** (GSE180954 da sola = 79.6% fail rate, 1320/1659 sample, 36% di tutti gli errori). Conferma forte di **non-determinismo fp16/bf16 nel continuous batching di vLLM** — stessi prompt vicini in batch diversi producono output diverso per fp non-associativity.

**Implicazione metodologica**: per la meta-analisi RNAseq downstream, perdere repliche biologiche di gruppi treatment/control distrugge potenza statistica. Inaccettabile.

**Soluzione propagation rescue**: per ogni FAIL con sibling OK same-string (verificato byte-identico):
1. Copia `parsed_json` dal sibling OK.
2. Patch solo `geo_accession` con quello del FAIL.
3. Marca `rescue_source = "replicate_<src_GSM>"` in colonna separata della tibble predictions (NON dentro parsed_json per non rompere lo schema strict `additionalProperties: false`).

Validita' semantica: stessa stringa di input → stesse `cell_context`, `perturbations`, `disease_state`, `patient_metadata.donor_id` (donor_id viene dalla stringa). Differiscono solo `geo_accession` (patched) e `extraction.raw_input_hash` (= identico perche' input identico). Recover lossless di 2308/3651 = 63% del residuo.

Helper: `analysis/p4-output/alpha-stage1-rescue-map.rds` contiene `fail_with_ok_map` (4 col: FAIL geo_accession, series_id, string, OK ok_geo_accession) + `unique_fail_ids` (1343 record senza sibling). Lo script di rescue e' inline (~50 righe Rscript), ricostruibile in qualunque sessione futura in pochi minuti.

### Investigation 211 residual fails (2026-05-07, jobs 19748+19749, +5 min DGX)

Phase 1 — caratterizzazione binaria dei 211 (post temp00 + rep_pen 1.1):

| Mode | n | Pattern | Diagnosi |
|---|---|---|---|
| **B — truncation** | 205 (97%) | raw_output ~3231 char, 3-5 `agent_normalized` blocks, mid-JSON cut | hit `max_tokens=1024` cap |
| **A — tab flood** | 6 (3%) | raw_output ~1410 char, 0 agent blocks, terminal tab flood | decoder loop su `engineered_modifications[].variant` boundary |

Evidence rock-solid: stesso config (temp 0.0 + rep_pen 1.1) ha prodotto OK con median raw_output 1748 char e fail con median 3231 char. Distribuzione *zero overlap*. Le 211 input string median 150 char (~1.7x le OK 92 char), heavy clustering in 43 series con ricche treatment combinations (es. "BMP4, VEGF, SCF, ACTIVIN A, FGF2, CHIR99012 plus d2 LSD1 Inhbitor" → 6 perturbazioni JSON-espanse).

Phase 2-3 — single-variable hypothesis test:

| Run | Change vs baseline | Records | Recovery |
|---|---|---|---|
| 19748: `max_tokens 1024 → 2048` | +1024 token output budget | 211 | **205/211 (97%)** ← Mode B 100% |
| 19749: `repetition_penalty 1.1 → 1.2` | rep_pen +0.1 (sui 6 residual) | 6 | **6/6 (100%)** ← Mode A 100% |

Phase 4 — verification: tutti 6 + 205 schema-valid; content quality dei 6 (rep_pen 1.2) verificata: `context_kind` corretto, `engineered_modifications[]` correttamente compilato (kind=transgene_stable/other, label coerente con input), perturbations corrette (etoposide, Nocodazole, DMSO, None), confidence 0.8-0.9. **Zero garbage**.

Mode A pinpoint architettonico: tutti 6 raw_output stallano *esattamente* dopo `"label": "..."` dentro il primo `engineered_modifications[].` Schema definisce `variant: ["object","null"]` con required nested `{label, description, is_wildtype}` se non null. Guided decoder collassa al field-boundary scegliendo tra `null`/`{`/`}`. rep_pen 1.1 insufficiente; rep_pen 1.2 rompe il loop deterministicamente.

Default policy:
- **`max_tokens=2048`** stage1 = nuovo default (era 1024). Costo trascurabile per OK normali (median 500 token, vs cap 2048).
- **`repetition_penalty=1.1`** resta default. 1.2 documentato come escape hatch nel comment yaml (potenziale content drift su 130k normali non testato).

### Riassunto recovery completo α stage1

| Fase | Records | Cumulativo | % |
|---|---|---|---|
| α stage1 originale (temp 0.0, no rep_pen) | 124,979 | 124,979 | 95.56% |
| Propagation rescue (sibling OK) | +2,308 | 127,287 | 97.33% |
| Re-run uniqfail (temp 0.0 + rep_pen 1.1, job 19739) | +1,132 | 130,573 | 99.84% |
| Re-run residual Mode B (max_tokens 2048, rep_pen 1.1, job 19748) | +205 | 130,778 | 99.99% |
| Re-run residual Mode A (max_tokens 2048, rep_pen 1.2, job 19749) | +6 | **130,784** | **100.00%** |
| Residui irrecuperabili | 0 | — | 0.00% |

Output finale: `analysis/p4-output/alpha-stage1-final.rds` (oggetto `list(predictions, errors, summary)` con colonna `rescue_source` traccia provenienza completa: `replicate_<GSM>` / `rep11_maxtok2048` / `rep12_maxtok2048` / NA per OK originali). Dimensione predictions: 130,784 × 7 col, errors 0 × 7.

### P3.5-D (2026-05-06): cheap models exploration via OpenRouter

Adapter `R/llm-client-openrouter.R` aggiunto. Provider `openrouter` nel
dispatch. Testati 14 modelli su 50 GSE × mini-gold v5 (n=100).

**Risultati conclusivi P3.5-D:**

| Modello                              | Provider     | Overall | $/sample  | Note                                     |
|--------------------------------------|--------------|---------|-----------|------------------------------------------|
| **gemini-2.5-flash**                 | OpenRouter   | **97%** | $0.0035   | Closed                                   |
| **mistral-small-3.2-24b-instruct**   | OpenRouter   | **96%** | **$0.0004** | Apache 2.0 ✓ ★ VINCITORE                |
| qwen3-30b-a3b-instruct-2507          | OpenRouter   | 95%     | $0.0006   | Apache 2.0 ✓                             |
| gpt-5.5                              | OpenAI       | 94%     | $0.046    | Closed                                   |
| gpt-5.4-mini                         | OpenAI       | 93%     | $0.005    | Closed                                   |
| claude-sonnet-4-6                    | Anthropic    | 91%     | $0.025    | Closed                                   |
| mistral-medium-3-5                   | OpenRouter   | 90%     | $0.0035   | Closed-ish                               |
| ~google/gemini-flash-latest          | OpenRouter   | 89%     | $0.0005   | Closed (alias dinamico, tilde required)  |
| mistral-small-2603                   | OpenRouter   | 86%     | $0.00015  | Apache 2.0 (più recente di 3.2 ma peggio)|
| claude-haiku-4-5                     | Anthropic    | 80%     | $0.008    | Closed                                   |
| deepseek-v4-flash                    | OpenRouter   | 80%     | $0.0003   | DeepSeek License                         |
| qwen3-max                            | OpenRouter   | 76%     | $0.0105   | Apache 2.0                               |
| deepseek-chat-v3.1                   | OpenRouter   | 71%     | $0.0009   | DeepSeek License                         |
| llama-4-maverick (MoE)               | OpenRouter   | 61%     | $0.001    | Llama 4 Community                        |
| deepseek-v3.2-speciale               | OpenRouter   | 60%     | $0.004    | DeepSeek License (32% invalid)           |
| qwen3.6-flash                        | OpenRouter   | 58%     | $0.001    | Apache 2.0                               |
| llama-3.3-70b-instruct               | OpenRouter   | 58%     | $0.0006   | Llama 3 Community                        |
| hermes-3-llama-3.1-405b              | OpenRouter   | 49%     | $0.015    | Apache 2.0 fine-tune (405B)              |
| deepseek-v4-pro                      | OpenRouter   | 48%     | $0.004    | DeepSeek License (46% invalid)           |
| qwen3.6-max-preview                  | OpenRouter   | 42%*    | $0.0156   | Apache 2.0 (parziale 30/50)              |
| gpt-5.4-nano                         | OpenAI       | 24%     | $0.0014   | Closed                                   |

**Pattern strutturali emersi:**

1. **mid-size mature (24-30B) > flagship latest** (70-405B). Mistral
   Small 3.2 24B batte Llama 3.3 70B, Llama 4 Maverick, Qwen 3 max,
   Hermes 405B, DeepSeek V3.2/V4. Per task di JSON-structured output con
   tassonomia controllata, il bottleneck NON e' capability scalata ma
   strict instruction following + schema conformance.

2. **Latest peggio del predecessore stabile**: gemini-flash-latest (89%)
   < gemini-2.5-flash (97%); mistral-small-2603 (86%) < mistral-small-3.2
   (96%); qwen3.6-flash (58%) << qwen3-30b-a3b-instruct-2507 (95%).
   I modelli piu' recenti sono ottimizzati su capability che il nostro
   task non richiede.

3. **Big open-weights (70B+) hanno alto invalid rate** (14-46%) per
   schema conformance. CAVEAT: **OpenRouter potrebbe servirli in
   quantizzazione aggressiva (Q3-Q4) vendor-side**, degradando la
   qualita'. In FP16 self-hosted potrebbero recuperare 5-15pp - da
   verificare.

4. **REPLICA mistral-small-3.2 → 96% (idem run originale)**.
   Anti-variance check OK, valore stabile.

### Decisione P4 aggiornata da P3.5-D

- **Modello scelto**: `mistral-small-3.2-24b-instruct` (Apache 2.0).
- **Hardware**: self-hosted in **FP16 nativo su DGX H100** (1 sola H100
  basta, ~48 GB VRAM, sotto i 80 GB disponibili).
- **Costo P4**: $0 (solo elettricita').
- **Tempo P4**: ~30 min su H100 con vLLM continuous batching.
- **Quality**: ~96-97% accuracy attesa (no degrado quantizzazione).

### Hardware self-hosting confermato (2026-05-06)

- **RTX 4090 (24 GB VRAM)**: gestibile per Mistral Small 3.2 in Q8 (al
  limite) o Q4. Stima P4: 3-6h. Costo $0.
- **DGX H100 (8× H100 80GB)**: gestibile in FP16/FP8 nativo. Sblocca
  rivalidazione modelli big in FP16 puro. Stima P4 mistral-small-3.2 in
  FP16: ~30 min. Costo $0.
- Decisione: P4 default su DGX FP16 (max qualita', tempo trascurabile).

### Next session: setup DGX + P4

Da fare nella prossima sessione (server linux DGX H100, NUOVA SESSIONE):

1. **Setup vLLM** sulla DGX (Ubuntu, CUDA 12.x, vLLM ≥0.6.x).
2. **Smoke test mistral-small-3.2 in FP16** (1 GSE, conferma replica
   del 96% sul mini-gold v5).
3. **P4**: run massivo ARCHS4 (~22k studi) con
   `mistralai/mistral-small-3.2-24b-instruct` in FP16 su 1 H100,
   tempo stimato ~30 min, costo $0.

NOTA: la rivalidazione dei big in FP16 NON e' nello scope (decisione
utente 2026-05-06). Mistral Small 3.2 24B e' la scelta finale.

**Riusabilita' del codice**: `R/llm-client-openrouter.R` e' compatibile
con vLLM locale: vLLM espone un endpoint OpenAI-compatible. Per
puntarlo al server locale, basta passare `model = "..."` con il path
locale e riconfigurare `.OPENROUTER_CHAT_URL` a `http://<dgx>:8000/v1/chat/completions`
(o creare un adapter `R/llm-client-vllm.R` mirror con URL parametrico).

Riferimenti:
- `analysis/run_openrouter_p35c.R` - script multi-modello sequenziale
- `analysis/run_openrouter_single.R` - script parallel single-model
- `analysis/openrouter_*.rds` - artefatti P3.5-D (non committati,
  ricostruibili da OpenRouter cache se serve)
- `R/llm-client-openrouter.R` - adapter base per vLLM local
- `inst/extdata/p35c-minigold-reviewed-v5.csv` - mini-gold riconvertito,
  100 sample reviewati per validare smoke test FP16

### Cosa P3.5-C v5 ha consegnato (vocabolario design-aware-relational)

Salto a vocabolario v5 sample-level (insight discusso in brainstorming
2026-05-05): un controllo non e' una categoria autonoma, esiste solo IN
RELAZIONE a un trattato. Schema v2 (`study_design.stage2.v2.json`):

- **Sample-level `primary_role`** (5 valori): treated, control, bystander,
  excluded, unclear. Solo informativo.
- **Comparison-level `control_type`** (7 valori): vehicle, untreated,
  genetic_negative, inducer_off, disease_normal, time_zero, secondary_arm.
  Property RELAZIONALE.
- **Comparison-level `design_kind`**: design specifico per ogni comparison
  (per studi multi_arm_treatment con sub-experiments eterogenei).

Adapter Anthropic Messages API + dispatch llm_call_structured. Multi-model
classifier (5 modelli: gpt-5.5, gpt-5.4-mini, gpt-5.4-nano, claude-haiku-4-5,
claude-sonnet-4-6). Confidence score via cross-model agreement, mini-gold
v3 reviewato dall'utente (100 sample) riconvertito v5 deterministicamente.

### Risultati P3.5-C v5

| Modello              | Easy | Hard | Overall | vs v3 |
|----------------------|------|------|---------|-------|
| **gpt-5.5**          | 96%  | 92%  | **94%** |  +3pp |
| **gpt-5.4-mini**     | 96%  | 90%  |   93%   | **+30pp** |
| claude-sonnet-4-6    | 96%  | 86%  |   91%   | +11pp |
| claude-haiku-4-5     | 100% | 60%  |   80%   |  +1pp |
| gpt-5.4-nano         | 42%  | 6%   |   24%   | -24pp |

| Metrica | Valore |
|---|---|
| Modello P4-ready scelto | **gpt-5.4-mini** (drop -1pp vs gpt-5.5, costo ~5-10x cheaper) |
| Estrapolazione P4 gpt-5.4-mini | ~$5-7k vs $32k full-gpt-5.5 (saving ~80%) |
| Architettura tier-aware ibrida | Haiku per `easy` + gpt-5.4-mini per medium/hard, P4 ~$4-5k |
| Soglia confidence raccomandata P5 | >= 0.45 (esclude tier hard) |
| Costo P3.5-C cumulativo (v3 + v5) | ~$50-60 |
| Invalid rate v5 | 3/250 (1.2%) |

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

### Cosa P3.5-B ha consegnato (eval benchmark prototipo)

- `R/eval-stage2.R`: **`design_role_to_binary()`**, **`eval_binary_accuracy()`**, **`eval_per_design_kind()`**, **`flag_granularity_disagreement()`** — tutte export pubbliche.
- `R/eval-rummageo.R`: **`fetch_rummageo_signatures()`** (cache + retry, abort se GSE non in RummaGEO official), **`parse_rummageo_labels()`**, **`rummageo_baseline_internal()`** (fallback K-means+keyword).
- `analysis/_targets.R`: 7 nuovi target eval pipeline.
- `analysis/eval/p35-benchmark.Rmd` + report HTML 838KB con 4 sezioni: binary accuracy, granularity, anchor coverage, RummaGEO head-to-head.

### Risultati P3.5-B benchmark (15 GSE, 197 sample)

| Metrica | Valore |
|---|---|
| Stage 2 binary accuracy globale | **75.1%** |
| 100% accuracy su | time_course / treatment_vs_vehicle / knockdown_panel |
| 41.7% (sotto casuale, da investigare) | treatment_vs_untreated (n=12) |
| Granularity flagged (informativo, non errore) | 22 sample |
| simulomicsr vs gold | 0.751 |
| RummaGEO (mostly internal_fallback) vs gold | 0.696 |
| **Delta** | **+5.5 pp simulomicsr beats RummaGEO** |
| Costo cumulativo P1+P2+P3+P3.5-B | ~$5-7 (P3.5-B aggiunge $0) |

12/15 GSE non indicizzati in RummaGEO official -> 145/197 sample usano fallback interno keyword-matching. 39 sample hanno label RummaGEO ufficiale.

### Cosa P3.5-A ha consegnato (scaled benchmark paper-ready)

- `R/eval-stats.R`: **`wilson_ci()`**, **`mcnemar_paired()`**, **`bootstrap_delta_ci()`**, **`holm_adjust()`** — statistica inferenziale paper-grade (tutti export, base R, no nuove deps).
- `R/p35a-select-gse.R`: **`load_rummageo_index()`** (GraphQL paginated + cache), **`keyword_design_kind_proxy()`**, **`intersect_with_xlsx_and_archs4()`**, **`stratified_sample_gse()`** (seed 1812 deterministico).
- `R/p35a-investigate-gse145941.R`: **`reclassify_verbose()`** (chain-of-thought via prompt extension), **`compare_with_gold()`** (tabella side-by-side).
- Estensione `classify_study()` + `build_prompt_stage2()` con parametro opzionale `extra_instruction` (backward compatible).
- `inst/extdata/p35a-gse-selected.csv`: 100 GSE finali con design_kind_proxy (riproducibilità set test).
- `analysis/_targets.R` esteso con ~14 nuovi target P3.5-A (suffisso `_p35a`), pipeline P3.5-B intatta per riferimento storico.
- **`analysis/eval/p35a-benchmark.html`** (980 KB): report Quarto 5 sezioni paper-ready con Wilson CI + McNemar + bootstrap delta + Holm correction + investigation GSE145941.

### Risultati P3.5-A benchmark (100 GSE, 1507 sample, gpt-5.5)

Pool candidato: 2591 GSE (RummaGEO official 34690 ∩ xlsx 5367 GSE). Selezione stratificata hybrid (seed 1812).

| Metrica | Valore | Soglia plan | Pass |
|---|---|---|---|
| **Stage 2 binary accuracy globale** | **83.7%** (n=1489) | ≥80% | ✅ |
| **simulomicsr vs RummaGEO** | **+12 pp** (83.7% vs 71.8%) | — | ✅ Big win |
| Stadio 1 validity | 100% (1507/1507) | — | ✅ |
| Stadio 2 validity | 100% (100/100) | — | ✅ |
| treatment_vs_vehicle | 94.6% (n=166) | ≥85% | ✅ |
| dose_response | 95.6% (n=45) | ≥70% | ✅ |
| multi_arm_treatment | 87.2% (n=531) | ≥70% | ✅ |
| knockdown_panel | 85.5% (n=69) | ≥70% | ✅ |
| factorial | 83.6% (n=408) | ≥70% | ✅ |
| treatment_vs_untreated | 77.3% (n=141) | ≥85% | ⚠️ -7.7 |
| time_course | 59.3% (n=54) | ≥70% | ⚠️ |
| case_control_disease | 49.1% (n=57) | ≥70% | ⚠️ sotto casuale |
| Granularity flagged | 88 sample (~4x P3.5-B) | ≥1 | ✅ |
| RummaGEO official coverage | 209/1492 paired | — | low |
| **Costo gpt-5.5 P3.5-A** | **~$68.70** (utente OpenAI billing 2026-05-03) | — | misurato |

Distribuzione `design_kind` LLM-inferita differente dal keyword_proxy (LLM ha vocabolario più ricco: aggiunge `multi_arm_treatment`, `dose_response`, `case_control_disease`, `unclear`).

**Limitations note**: `treatment_vs_untreated`, `time_course`, `case_control_disease` sotto soglia → potenziale prompt iter (P3.5-A2 separato, non scope P3.5-A).

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
- **MAI fare `git checkout -- analysis/_targets/meta/meta` MENTRE un `tar_make` è in corso** (lesson learned P3.5-A 2026-05-03): il meta viene aggiornato in tempo reale, un checkout lo riporta a stato pre-run e il job successivo non riconosce più gli oggetti già calcolati anche se i file sono ancora su disco. Recovery: rilancia `tar_make` (cache hit dei branch è veloce, ma serve lo step). Se ritorni il meta DOPO il tar_make completato, OK. La convenzione "ripristina meta prima del commit" vale solo quando NESSUN tar_make sta girando in background.
- **Hang HTTP transitorio iniziale** (lesson P3.5-A 2026-05-03): la prima call OpenAI dopo network glitch può essere catturata in I/O wait su socket (CPU 0%, processo S, TCP ESTABLISHED) senza timeout effettivo del `req_timeout(120s)` di httr2 (rare edge case). Workaround: kill + retry. Se sistemico, fix di `R/llm-client-openai.R` per timeout TCP-level più aggressivo. Vedi P1 hotfix `temperature` per altro pattern correlato.

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

## Stato corrente (2026-05-08 sera — Task 22 stage2 RESOLVED, full run pronto per nuova sessione)

**Task 21 α stage1 CHIUSO 2026-05-07** = **130,784 / 130,784 (100.00000%) valid** (vedi sezione "Risultati P4 α stage1" sopra).

**Task 22 α stage2 RESOLVED 2026-05-08** — root cause identificato, fix validati su scaled smoke, full run **DEFERRED a NUOVA SESSIONE** per handoff pulito (preferenza utente).

### Root cause Task 22

**vLLM Issue #39734** ([github](https://github.com/vllm-project/vllm/issues/39734)): scheduler v1 deadlock head-of-line per request che eccedono la KV cache disponibile pur essendo dentro `max_model_len`. Trigger nel nostro setup: record stage2 con chunk_size=50 (max ~28K token, 88% di max_model_len=32768) saturano lo scheduler che entra in loop di break-without-pop. Bug ancora presente in vLLM 0.19.x — **upgrade del container NON aiuta** (Path A obsoleto).

Riproduzione a config-grade: 1 record da 101KB su 1 GPU + `max_num_seqs=1` + `microbatch=1` STALLA immediatamente (T5e + T5f, 2026-05-08).

### Fix applicati (2026-05-08, branch `p4-dgx-integration`, NON committati)

1. **Path C — chunk_size 50→25** in `analysis/p4-stage2-build-input.R`:
   - Output: `data-raw/p4-alpha-stage2-cs25.jsonl`, **8546 record** (vs 6652 cs50), 130,784 sample preservati (zero loss).
   - Tutti record sotto ~14K token (50KB max), mai vicino al cap.
   - Validato T5g (2000 record / 4 GPU): 4/4 worker completano 500/500 (worker 3 supera 485 = 140 record oltre la danger zone v5).

2. **max_tokens 1024→4096** in `inst/extdata/p4-defaults.yml` stage2:
   - 1024 produceva 40% truncation (T5g: 1201/2000 schema valid).
   - 4096 produce **97% schema validity** (T5h 485/500 mini500 cs25).
   - I 3% residui hanno output >3K token; rescue post-hoc con `max_tokens=8192` (pattern noto da stage1 alpha 2026-05-07).

3. **`scheduler_reserve_full_isl=false`** in yaml + propagato via `R/dgx-bundle.R` + `inst/dgx/python/run_p4_vllm.py`. Defense-in-depth (Path C già evita la zona-bug).

4. **Fence-strip post-processing** in `inst/dgx/python/run_p4_vllm.py::_strip_md_fences()`. Mistral-3.2 free-gen wrappa output in ` ```json ... ``` ` markdown; senza strip avevamo `valid_schema=False` per tutti.

5. **System prompt anti-markdown** in `R/llm-stage2.R::.stage2_system_prompt`: blocco "OUTPUT FORMAT (CRITICAL)" che ribadisce JSON nudo.

R CMD `devtools::test()`: **527 PASS / 0 FAIL / 3 SKIP** (skip pre-esistenti OPENAI_API_KEY).

### Hypothesis investigation (sintesi T2-T5h, vedi spec per dettagli)

| Hypothesis | Test | Result |
|---|---|---|
| H1 — `enable_prefix_caching=False` | T5b vs T5a | RIGETTATA (stesso stall) |
| H2 — `enable_chunked_prefill=True` | T5c vs T5a | RIGETTATA (stesso stall) |
| H3 — Scheduler concurrency (max_num_seqs) | T5e (max_num_seqs=1) | RIGETTATA (stalla anche solo) |
| **H4 — Record specifico (101KB) + vLLM Issue #39734** | T5e + T5f | **CONFERMATA** |
| **H5 — Path C (chunk_size=25)** | T5g | **CONFERMATA** (4/4 worker complete) |
| **H6 — max_tokens=4096** | T5h | **CONFERMATA** (97% schema valid mini500) |

### Modifiche locali NON committate al handoff (branch `p4-dgx-integration`)

```
M  CLAUDE.md                              # questa sezione + handoff
M  R/dgx-bundle.R                         # propaga scheduler_reserve_full_isl + chunked_prefill + prefix_caching
M  R/llm-stage2.R                         # system prompt anti-markdown
M  inst/dgx/python/run_p4_vllm.py         # fence-strip + scheduler_reserve_full_isl + chunked_prefill + prefix_caching kwargs
M  inst/extdata/p4-defaults.yml           # stage2: max_tokens 4096, scheduler_reserve_full_isl=false
M  analysis/p4-stage2-build-input.R       # CHUNK_SIZE=25, output -cs25.jsonl
M  analysis/p4-stage2-build-mini2000.R    # env-var override input/output
M  tests/testthat/test-dgx-bundle.R       # assert max_tokens=4096 + scheduler_reserve_full_isl
?? analysis/p4-bundles/run-smoke-stage2.R    # parametrized smoke wrapper (nuovo)
?? analysis/p4-bundles/poll-smoke-stage2.R   # smoke poll helper (nuovo)
?? analysis/p4-bundles/analyze-smoke-stage2.R # smoke analyze (nuovo)
?? analysis/p4-bundles/smoke-stage2-template.sh # SLURM template parametrizzato (nuovo)
?? analysis/p4-stage2-build-mini50.R         # mini50 builder (nuovo)
?? data-raw/p4-alpha-stage2-cs25.jsonl       # 8546 record, ~190MB, gitignored
?? data-raw/p4-stage2-mini2000-cs25.jsonl    # mini scale test input (nuovo)
?? data-raw/p4-stage2-mini500-cs25.jsonl     # smoke max_tokens test input (nuovo)
?? data-raw/p4-stage2-mini50.jsonl           # smoke 1 GPU input (nuovo)
?? data-raw/p4-stage2-toxic-{single,mb5}.jsonl # toxic isolation test inputs (nuovi)
```

### Per ripartire (NUOVA SESSIONE — full alpha stage2-cs25 run)

1. **Triage iniziale** (5 min): verifica branch + cluster pulito.
2. **Build bundle full**: `data-raw/p4-alpha-stage2-cs25.jsonl` (8546 record).
3. **Submit** con `time = "06:00:00"` (margine vs stima 5-6h wall).
4. **Polling** progressivo via `dgx_p4_status(job, watch=TRUE)`.
5. **Eval**: `dgx_p4_collect()` + post-hoc schema validity (atteso ≥95%) + binary accuracy vs `inst/extdata/p35c-minigold-reviewed-v5.csv`.
6. **Rescue residual**: re-submit dei record `valid_schema=FALSE` con `max_tokens=8192` (atteso ~3%).

Comando ready-to-go (vedi spec investigation per dettagli):
```r
devtools::load_all()
b <- dgx_p4_build_bundle("data-raw/p4-alpha-stage2-cs25.jsonl",
                         stage = "stage2",
                         config = dgx_config(),
                         metadata = list(slug = "alpha-stage2-cs25"))
job <- dgx_p4_submit(b, time = "06:00:00")
saveRDS(job, "analysis/p4-bundles/alpha-stage2-cs25-job.rds")
```

Acceptance Plan Task 22 invariato: schema valid ≥95%, binary accuracy ≥95% target / [80,95) investigativo / <80% debug.

### Roadmap post-P4 (deferred fino a chiusura α)

1. **P4 β: ETL ARCHS4 H5 → JSONL** (700k sample / 22k studi). Plan separato.
2. **Output 3 ADR-0006**: P5 Stadio 4+5 (DESeq2/limma + metafor REM).
3. **Rename pacchetto** (ADR-0003) prima del primo `install_github` pubblico.
4. **Migrazione a `ellmer`** come ADR separato (multi-provider + batch API).
5. **P3.5-A2 cost/quality validation** ridiventerebbe rilevante solo se decidiamo di NON usare mistral-small-3.2 self-host; al momento abbandonato (P4 self-host = $0).

### Findings sotto-soglia P3.5-A (da considerare in eventuale prompt iter post-α)

1. `treatment_vs_untreated` 77.3% gpt-5.5 (sotto soglia plan 85%, n=141).
2. `time_course` 59.3% (n=54).
3. `case_control_disease` 49.1% (n=57): sotto casuale, anomalia da investigare. Probabile bug nel mapping `design_role → trtctr_predicted` per design malattia/normale.
4. GSE145941 `reclassify_verbose` 408 byte di reasoning (vedi report Sezione 5).

## Riferimenti chiave

- Spec classificatore: `docs/superpowers/specs/2026-04-29-classificatore-llm-design.md` (v5 approvata 2026-04-29; §13 References aggiunta 2026-05-02).
- Plan P1: `docs/superpowers/plans/2026-04-29-p1-infrastruttura-llm-plan.md` + HUMANE.
- Plan P2: `docs/superpowers/plans/2026-05-02-p2-stadio1-sample-facts-plan.md` + HUMANE.
- Plan P3: `docs/superpowers/plans/2026-05-02-p3-stadio2-study-design-plan.md` + HUMANE.
- **Spec P3.5-B:** `docs/superpowers/specs/2026-05-02-p3.5-eval-benchmark-design.md`.
- Plan P3.5-B: `docs/superpowers/plans/2026-05-02-p3.5b-eval-benchmark-plan.md` + HUMANE.
- **Report P3.5-B:** `analysis/eval/p35-benchmark.html` (838KB, 4 sezioni con grafici e tabelle).
- **Spec P3.5-A:** `docs/superpowers/specs/2026-05-02-p3.5a-scaled-benchmark-design.md`.
- Plan P3.5-A: `docs/superpowers/plans/2026-05-02-p3.5a-scaled-benchmark-plan.md` + HUMANE.
- **Report P3.5-A:** `analysis/eval/p35a-benchmark.html` (980 KB, 5 sezioni con Wilson CI + McNemar + bootstrap + Holm + investigation GSE145941).
- **ADR-0006 stato dell'arte:** `docs/decisions/0006-stato-arte-vs-simulomicsr.md` — analisi competitor 2024-2026 + benchmark RummaGEO integrale + decisione P3-B confermata.
- **ADR-0007 DGX self-host vLLM:** `docs/decisions/0007-dgx-self-host-vllm.md` — decisione bespoke minimale dentro simulomicsr (no fork laimsdgxllm) + workflow Docker→DockerHub→Singularity.
- **Spec P4:** `docs/superpowers/specs/2026-05-06-p4-dgx-integration-design.md`.
- **Plan P4:** `docs/superpowers/plans/2026-05-06-p4-dgx-integration-plan.md` (23 task, 16 completati locale).
- **Investigation Task 22 stalls (RESOLVED 2026-05-08):** `docs/superpowers/specs/2026-05-08-task22-stage2-vllm-stalls-investigation.md` — root cause vLLM Issue #39734, fix Path C (chunk_size=25) + max_tokens=4096 + scheduler_reserve_full_isl=False + fence-strip post-proc, validato T5g/T5h.
- **Vignette P4 setup:** `vignettes/p4-dgx-setup.Rmd` (one-time guide utente).
- ADR-0005 server migration: `docs/decisions/0005-server-migration-trigger.md`.
- ADR generali: `docs/decisions/`.
- README utente: `README.md`.
- News versioni: `NEWS.md`.

## Hardware self-hosting disponibile (annotazione 2026-05-06)

Per fasi successive (post-P3.5-D, prima di P4 server-switch ADR-0005)
considerare alternative self-host invece/oltre OpenRouter:

- **RTX 4090 (24 GB VRAM, server Linux)**: gestibile per modelli ≤30B in
  Q4-Q8 via vLLM. Mistral Small 3.2 24B su 4090 con continuous batching:
  stima 3-6h per ARCHS4 (22k studi). Costo $0, privacy totale, niente
  rate limit.
- **DGX H100 (8× H100 80GB = 640GB VRAM)**: sblocca modelli da 70B-400B+
  in FP16 con tensor parallel. Candidati per benchmark futuro:
  - Qwen 2.5 72B Instruct
  - Llama 3.3 70B Instruct
  - Mistral Large 2 (123B)
  - Mixtral 8x22B (141B MoE)
  - DeepSeek-V3 (671B MoE) -- gestibile su 8×H100
  Stima P4 con 70B su DGX: ~30 min totali. Sblocca anche multi-modello
  consensus cross-family senza dipendenze API.

Se vogliamo testare modelli > 70B prima di P4, andare diretti su DGX.
Se vogliamo replicare il vincitore OpenRouter (mistral-small-3.2) a costo
zero, andare su 4090.

Decisione rimandata a chiusura P3.5-D.
