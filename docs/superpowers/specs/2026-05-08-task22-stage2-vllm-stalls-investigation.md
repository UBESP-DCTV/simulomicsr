# Task 22 stage2 — investigation stall vLLM (CLOSED 2026-05-11)

**Stato**: **CLOSED 2026-05-11, superseded by ADR-0010 vLLM upgrade.**

Root cause (Issue #39734 vLLM scheduler v1 deadlock) e' stata fixata
upstream da PR #40946 (mergiata 2026-04-27, in v0.20.0+). ADR-0010
(2026-05-10) ha validato l'upgrade a v0.20.2-cu129 con gate hierarchical
PASS (HARD+SOFT entrambi). Phase 5 cleanup ha rimosso lo stack di
workaround documentato qui (safe-mode, disable_guided_decoding,
chunk_size=25, fence-strip, heuristic recovery). ADR-0013 ha re-flippato
default a cs50 dopo evidence H1 (96.7% vs 93.3% baseline, +3.4pp).

Questo doc resta come **record storico** dell'investigation, utile per:
- Riferimento al modus operandi diagnostic (T5a-T5h matrix smoke).
- Documentazione del bug pattern per future regressioni vLLM.
- Audit della catena decisioni 2026-05-08 → 2026-05-11.

**Stato originale 2026-05-08**: Root cause identificato vLLM **Issue #39734**. Bug ancora presente in vLLM 0.19.x — upgrade del container NON aiuta. **Path C (chunk_size=25 in `analysis/p4-stage2-build-input.R`) confermato come fix operativo** via T5g (2000 record / 4 GPU completati 100%, worker 3 supera la danger zone). Ulteriore fix richiesto: bump `max_tokens` 1024→4096 per ottenere 97% schema validity (validato T5h, 485/500). Fix `scheduler_reserve_full_isl=False` aggiunto come defense-in-depth.

**Branch**: `p4-dgx-integration` (modifiche committate? — verificare prima di nuova sessione).

## TL;DR

Il run α stage2 ha impattato il bug vLLM **Issue #39734**: quando `scheduler_reserve_full_isl=True` (default v1 engine), `can_fit_full_sequence()` ritorna False per request che eccedono la KV cache disponibile pur essendo dentro `max_model_len`. Lo scheduler **break dal loop senza pop il request dalla queue** → head-of-line blocking permanente. Bug riproducibile a config-grade: 1 record da 101KB (~28K token) su 1 GPU + `max_num_seqs=1` + `microbatch=1` STALLA immediatamente.

**Mitigazione applicata (Path C)**: ridurre chunk_size 50→25 in `analysis/p4-stage2-build-input.R` → tutti record stage2 sotto ~50KB / ~14K token, mai vicino al cap KV. Validato sul cluster con T5g (2000 record / 4 GPU = 500/worker, worker 3 supera la danger zone v5 di 345/worker e completa 500/500 in 51 min).

**Path A (vLLM upgrade) e Path B (vllm serve)**: scartati. Issue #39734 è ancora presente in 0.19.x (verificato 2026-05-08 via web research).

## Resolution 2026-05-08

### Root cause

**vLLM Issue #39734**: `vllm/v1/core/sched/scheduler.py` quando `scheduler_reserve_full_isl=True` (default v1 engine), il `can_fit_full_sequence()` ritorna False per request che eccedono la KV cache disponibile pur essendo dentro `max_model_len`. Lo scheduler **break dal loop senza pop il request dalla queue** → head-of-line blocking permanente di tutti i request del worker. GPU 0%, CPU in `futex_wait`.

Trigger condition esatta nel nostro setup:
- KV cache totale per H100 (80GB): 149,472 tokens (vLLM log)
- max_model_len: 32,768
- Max concurrency teorica: 4.56x (149472/32768)
- Record stage2 con chunk_size=50: max 101,198 byte = ~28K token (88% del cap)
- Quando il record entra in queue con altri waiting + max_num_seqs=4, lo scheduler trova che il batch non sta nella KV cache → break senza pop → HoL blocking.

Workaround documentati dall'issue:
1. `scheduler_reserve_full_isl=False` (CLI: `--no-scheduler-reserve-full-isl`)
2. Allineare `max_model_len` alla actual KV cache capacity per request

### Fix applicati

1. **Path C — chunk_size 50→25** in `analysis/p4-stage2-build-input.R`:
   - Tutti record stage2 sotto ~14K token, max ~50KB
   - Output: `data-raw/p4-alpha-stage2-cs25.jsonl` con **8546 record** (vs 6652 con cs=50), 130,784 sample preservati (zero loss).
   - Validato su T5g (2000 record / 4 GPU): 4/4 worker completano 500/500. Worker 3 supera 485 record (140 oltre la danger zone v5).

2. **max_tokens 1024→4096** in `inst/extdata/p4-defaults.yml` stage2:
   - 1024 produceva 40% truncation (T5g: 1201/2000 valid).
   - 4096 produce 97% schema validity (T5h 485/500 mini500 cs25).
   - I 3% residui hanno output >3000 token (record cs25 fortemente strutturati con molti comparison + factor_levels). Rescue post-hoc con `max_tokens=8192` (pattern consolidato da stage1 alpha investigation 2026-05-07).

3. **`scheduler_reserve_full_isl=false`** aggiunto a `inst/extdata/p4-defaults.yml` stage2 + propagato via `R/dgx-bundle.R` + `inst/dgx/python/run_p4_vllm.py` come defense-in-depth (Path C già evita la zona-bug).

4. **Fence-strip post-processing** in `inst/dgx/python/run_p4_vllm.py`:
   - Mistral-3.2 free-gen (disable_guided_decoding=true) wrappa output in ```` ```json ... ``` ```` markdown fences. `json.loads()` falliva → `valid_schema=False` per tutti.
   - Fix: helper `_strip_md_fences()` rimuove le fences prima di `json.loads`.

5. **System prompt anti-markdown** in `R/llm-stage2.R::.stage2_system_prompt`:
   - Aggiunto blocco "OUTPUT FORMAT (CRITICAL)" che ribadisce: solo JSON nudo, no fences, no testo prima/dopo.

### Test passing — gating

- **Smoke 1 GPU mini50** (4 config: T2 baseline, T3 prefix_off, T4 chunked_on, T4b combo): tutti 50/50 in ~336s (smoke base OK)
- **Scaled 4 GPU mini2000 cs50** (T5a baseline, T5b prefix_off, T5c chunked_on, T5d combo): tutti stallano worker 3 a 345 record (riproduzione del bug v5)
- **Toxic isolation 1 GPU** (T5e single record 101KB, T5f exact microbatch): entrambi stallano subito → bug deterministico nel record 101KB
- **Path C validation 4 GPU mini2000 cs25** (T5g baseline): 4/4 worker completano 500/500 in 51 min, **stall risolto**
- **max_tokens validation 4 GPU mini500 cs25** (T5h max_tokens=4096): 485/500 = **97% schema validity** vs 60% con 1024
- **R CMD test**: 527 PASS / 0 FAIL / 3 SKIP (post fix)

### Hypothesis investigation summary

| Hypothesis | Test | Result |
|---|---|---|
| H1 — `enable_prefix_caching=False` | T5b vs T5a | RIGETTATA (stesso stall) |
| H2 — `enable_chunked_prefill=True` | T5c vs T5a | RIGETTATA (stesso stall) |
| H3 — Scheduler concurrency | T5e (max_num_seqs=1) | RIGETTATA (stalla anche solo) |
| **H4 — Record specifico (101KB) vs vLLM bug** | **T5e + Issue #39734** | **CONFERMATA** |
| H5 — Path C (chunk_size=25) | T5g | **CONFERMATA** |
| H6 — max_tokens=4096 sufficiente | T5h | CONFERMATA al 97% (8192 per residual) |

L'utente esclude esplicitamente il fallback su API a pagamento (OpenAI, Anthropic, OpenRouter). La soluzione resta DGX self-host.

## Contesto

### Input

- `data-raw/p4-alpha-stage2.jsonl` — **6,652 record**, costruito 2026-05-07 da `analysis/p4-output/alpha-stage1-final.rds` via `analysis/p4-stage2-build-input.R` (tracked, branch `p4-dgx-integration`).
- Aggregazione: 5,367 series_id distinti (4,157 single-GSE + 1,210 SuperSeries comma-string).
- Chunking: studi con >50 sample splittati in chunks da 50 → 1,555 chunks aggiuntivi in 270 studi (max 148 chunks per GSE145668,GSE145669 con 7382 sample).
- **Tutti 130,784 sample sono coperti** (zero loss, verificato post-build).
- Distribuzione byte size record: median 17 KB, p99 80 KB, max 101 KB.
- Distribuzione token stimata (3.5 char/token): median ~5K token/prompt, p99 ~23K, max ~29K.

### Configurazione decisa per α stage2 (decisioni utente 2026-05-07)

- **1B**: `study_summary = ""` (no rentrez fetch — baseline; iterare se accuracy < 95%)
- **2B**: SuperSeries (record_id "GSEX,GSEY") tenute come record con study_summary vuoto
- **3 split**: studi >50 sample splittati in sub-chunks invece che subsample (no sample loss)
- **DGX time budget**: `time = "06:00:00"` (≈ 8x l'expected 30 min iniziale, su richiesta utente "stai largo")

### Pipeline modifiche (tutte sul branch `p4-dgx-integration`, non committate)

**File modificati durante l'investigation** (snapshot al momento del park):

1. `inst/extdata/p4-defaults.yml` — stage2:
   - `max_tokens: 1024` (era 4096, ridotto durante investigation)
   - `max_model_len: 32768` (era 16384 in P3, bumpato per chunk_size 50)
   - `disable_guided_decoding: true` (nuovo)
   - `microbatch: 5` (nuovo, per drain KV cache tra batch)
   - `enforce_eager: true` (nuovo)
   - `max_num_seqs: 4` (nuovo)
   - `repetition_penalty: 1.1` (invariato)
   - `temperature: 0.0` (invariato)

2. `inst/dgx/python/run_p4_vllm.py` — added:
   - `torch._dynamo.config.cache_size_limit = 256` + `accumulated_cache_size_limit = 1024` early
   - `disable_guided_decoding` switch in worker_main (skip GuidedDecodingParams se true)
   - `enforce_eager` + `max_num_seqs` LLM constructor kwargs
   - Microbatch loop: itera `llm.chat()` su sotto-batch di N record con write incrementale per microbatch (era singolo `llm.chat()` su tutti 1663 record/worker)

3. `inst/dgx/python/prompts.py` — stage2:
   - Compact JSON (`separators=(",", ":")`) invece di `indent=2` (-30% byte)
   - `record["series_id"]` (canonical GSE) usato per il prompt (era `record["record_id"]`)
   - `chunk_metadata` opzionale renderizzato come righe `chunk: X/Y`, `study_total_samples: N`

4. `R/dgx-bundle.R` — propaga al `generation.json`: `microbatch`, `disable_guided_decoding`, `enforce_eager`, `max_num_seqs` se presenti in `stage_def`.

5. `R/llm-stage2.R::.stage2_system_prompt` — addendum su `input_truncated`/`partial_chunk` flag per chunked input.

6. `analysis/p4-stage2-build-input.R` — script generatore JSONL stage2 (nuovo, tracked).

7. `analysis/p4-stage2-eval.R` — skeleton eval con post-hoc schema validation (nuovo, tracked, non eseguito).

8. `/tmp/stage2-autorestart.sh` — bash autorestart loop con cold-load grace 12 min, stall detect 10 min, max 12 cycles (file temporaneo, non in repo).

### Test suite

R CMD `devtools::test()` = **526 PASS / 0 FAIL / 3 SKIP** dopo tutte le modifiche (verificato 2026-05-07 dopo task 11).

## Cronologia stalli osservati

Tutti i job sotto sono stati eseguiti su `poddgx02` UniPD HPC (4× H100), modello Mistral-Small-3.2-24B-Instruct-2506 in bfloat16.

### Job 19778 — guided decoding xgrammar (FALLITO)

- **Config**: guided JSON via xgrammar, max_tokens=4096, max_model_len=32768, max_num_seqs=default (~5).
- **Pattern**: stallato IMMEDIATAMENTE all'inizio della generazione. CPU 99% / GPU 0% sostenuto.
- **Diagnostica live**: `srun --jobid=... nvidia-smi` mostra GPU util=0%; `srun --jobid=... ps` mostra worker python a 99% CPU per ~2h40m. `wchan` dei worker = futex_wait dopo l'observazione iniziale.
- **Root cause identificato**: `slurm-19778.err` contiene
  ```
  torch._dynamo hit config.recompile_limit (8)
  function: 'apply_token_bitmask_inplace_kernel_indices_torch_compile'
  last reason: 1/7: len(indices) == 23
  ```
  xgrammar genera kernel torch.compile separati per ogni `len(indices)` (numero di token attivi nella mask grammar). Lo schema stage2.v2 ha più shape variants di stage1 → satura il cache_size_limit=8 di torch._dynamo → fallback su Python loop su CPU → GPU starvation. Stage1 alpha aveva lo stesso warning ma con max_tokens=2048 e schema più semplice il rallentamento era tollerabile.
- **Cancellato dopo 2h40m** (164 min) senza un singolo predizione scritta.

### Job 19800 — guided + cache_size_limit=256 (FALLITO)

- **Mitigazione tentata**: `os.environ["TORCHDYNAMO_CACHE_SIZE_LIMIT"]="256"` + `torch._dynamo.config.cache_size_limit = 256` + `accumulated_cache_size_limit = 1024` aggiunti in `worker_main` PRIMA dell'import vLLM.
- **Pattern**: GPU 66-76% per i primi 10-20 min (warmup ok), poi GPU 0% sostenuto.
- **Root cause**: `slurm-19800.err` mostra ancora `torch._dynamo hit config.recompile_limit (256)` — anche 256 non basta. `len(indices)` ha più di 256 shape variants nel mask kernel xgrammar.
- **Cancellato dopo ~40 min**.

### Job 19801 — disable_guided_decoding=true (FALLITO con NUOVA modalità)

- **Mitigazione tentata**: bypassato xgrammar via `gen.disable_guided_decoding=true`. SamplingParams senza `guided_decoding`/`guided_json`. Generazione free-JSON; validazione schema POST-HOC R-side (validator esiste in `eval-stage2.R`).
- **Pattern v3**: GPU 94-97% sostenute per **~20 minuti** di generazione healthy. Poi GPU/CPU = 0%, workers in `futex_wait_queue_me`. NESSUN errore in slurm.err. Predictions scritte: zero (single big `llm.chat()` su 1663 record/worker non ha ancora flushato).
- **Root cause sospettato**: vLLM v1 engine + offline batch + prompt molto lunghi (~20K token) + max_tokens 2048 → KV cache slot leak / scheduler deadlock. Il fenomeno appare dopo che ~325-340 record per worker sono stati ELABORATI (ma non scritti, perché un singolo `llm.chat()` su 1663 ritorna solo a fine batch).
- **Cancellato dopo ~30 min** quando GPU sostenuta a 0% per 5 sample × 5s.

### Job 19802 — microbatch=25, write incrementale (FALLITO)

- **Mitigazione tentata**: code change in `run_p4_vllm.py` per fare `llm.chat()` su microbatch di 25 invece di 1663 record/worker, con write append-only DOPO ogni microbatch (vediamo progress reale, KV cache si drena tra microbatch).
- **Pattern**: 13 microbatches (= 325 record/worker = 1300 totale) processati con successo in ~30 min. Throughput sostenuto ~80 record/min, GPU 96%. Slurm log emette riga `[worker N] microbatch K-(K+24)/1663 in Xs` per ogni microbatch. Poi al microbatch 14, GPU = 0% sostenuto, `slurm.out` non avanza, `predictions.worker_*.jsonl` ferme a 325/335 per worker.
- **Verificato**: `sstat` mostra +1 sec di CPU time in 5 min wall = workers in `futex_wait`, non solo idle GPU.
- **Cancellato dopo 30+ min**.

### Job 19803 — microbatch=5, enforce_eager=true, max_num_seqs=4 (FALLITO)

- **Mitigazione tentata**: ridotto microbatch da 25 a 5; `enforce_eager=True` (no CUDA graph capture); `max_num_seqs=4` (limita continuous batching). Anche `max_tokens: 2048 → 1024` (limita decode time per record per evitare runaway che blocca KV slot).
- **Pattern**: warmup veloce (no CUDA graph capture). Generazione healthy per 30+ min. **Throughput dimezzato vs v4** (~32-35 record/min globale invece di ~80) — costo dell'enforce_eager + max_num_seqs=4. Ma stabile.
- A ~50 min dal submit, GPU = 0% sostenuto. **Stesso pattern del 19802**: workers in futex_wait, predictions ferme.
- Predictions accumulati prima dello stall: **1340 record** (340 + 330 + 335 + 335 per worker rispettivamente). Distribuzione round-robin con leggera asymmetria normale.
- **Cancellato a ~50 min**.

### Job 19808/19809/19810/19811 — autorestart resume cycles (FALLITI tutti, IMMEDIATELY)

- **Mitigazione tentata**: bash autorestart loop (`/tmp/stage2-autorestart.sh`) che monitora il SLURM job e fa `scancel + sbatch` quando rileva 10 min senza progress (con grace 12 min iniziali per cold load). Resume basato su `predictions.worker_*.jsonl` esistente sul cluster — `resume.py` skippa record con record_id già presenti.
- **Pattern**: ogni cycle di restart vede pred=1340 (i 1340 record di v5 cycle 0). Submit nuovo SLURM job; cold load completes in ~7 min (anche più veloce su cycle 2+ perché HF cache è warm). Workers entrano in fase generazione (`[worker N] generazione su 1328 record` — i restanti 1328 = 1663-335). **Zero progress per 11+ min dopo cold load**. GPU 0% sostenuto. Pred resta a 1340.
- **Differenza chiave vs v5 cycle 0**: cycle 0 ha processato 1340 record con success per ~30 min PRIMA di stallare. I cycle 1+ stallano IMMEDIATAMENTE all'inizio della generazione. Stesso `disable_guided_decoding`, stesso microbatch, stesso eager, stessi codici.
- **Tentato max_num_seqs=1 (job 19810)**: stesso comportamento, stallo immediato. Concorrenza a 1 non aiuta.
- **Tentato cycles**: 4-5 cycles con questa autorestart logic, tutti uguali. Predictions ferme a 1340. SLURM jobs 19806, 19807, 19808, 19809, 19810, 19811 (tutti scancelled).

### Pattern indagato e rifiutato: "record specifico tossico"

- Ipotesi: il record alla position 336+ del worker stripe è "tossico" e blocca il batch.
- Records che worker 0/1/2/3 dovrebbero processare next al resume:
  | Worker | Pos | Global idx | Record_id | n_samples | bytes |
  |---|---|---|---|---|---|
  | 0 | 340 | 1360 | GSE120502#4of5 | 50 | 91860 |
  | 1 | 330 | 1321 | GSE85353,GSE85356#1of2 | 50 | **100515** |
  | 2 | 335 | 1342 | GSE120176,GSE120177 | 8 | 11193 |
  | 3 | 335 | 1343 | GSE120183 | 13 | 18788 |
- Worker 2 e 3 hanno record SUCCESSIVI piccoli (11KB, 18KB) → molto sotto la mediana del batch processato in v5 cycle 0. Eppure stallano anche loro.
- Conclusione: il bug NON è solo dei record grandi. Il primo cycle ha già processato con successo 5 record >80KB (verificato in input.jsonl). Il bug emerge dalla COMBINAZIONE prefill grosso + lookup KV cache + state interno del scheduler vLLM.

## Diagnosi consolidata

Il fenomeno è classificabile come **deadlock o pathological state in vLLM 0.10.1.dev1+gbcc0a3cbe** (versione del container `vllm/vllm-openai:v0.10.0`) quando:

1. Si elaborano molti prompt molto lunghi (~20K+ token medio) in offline batch mode (`llm.chat()`).
2. Lo schema o il pattern di output causa shape variation che satura il torch._dynamo cache (specifico a guided decoding xgrammar).
3. Anche senza guided decoding, dopo ~325-350 record processati / worker, lo scheduler di vLLM entra in deadlock irrecoverable. Restart non aiuta perché il bug si manifesta sui PRIMI record successivi alla resume position.

Possibili cause (non investigate completamente):
- Memory leak in vLLM v1 engine accumulato su prefill ripetuti grossi
- Bug di paged-attention quando KV cache è usata oltre una soglia con prompt eterogenei
- Race condition nel scheduler con `max_model_len=32768` e prompt vicini al limite

## Indizi NON ancora esplorati (input per next session)

### Indizi vLLM (forse risolutivi)

1. **Bumping a vLLM 0.11.x**: il container `vllm/vllm-openai:v0.10.0` può essere obsoleto. Versioni recenti (>=0.11) hanno fix sostanziali a paged attention e scheduler v1. Rebuild Docker image.
2. **Backend guided decoding alternativo**: `outlines` o `lm-format-enforcer` non sono installati nell'immagine attuale. Aggiungere `pip install outlines` al Dockerfile e provare `LLM(guided_decoding_backend="outlines")`. **Possibile fix per il caso 19778** (xgrammar è il bottleneck primario).
3. **vLLM online server (`vllm serve`) invece di offline batch**: spostare a un OpenAI-compatible HTTP server in container, e farlo chiamare da R via `R/llm-client-openrouter.R` adattato a localhost. Online server ha scheduler diverso (production-tested), molto più stabile per workload prolungati.
4. **`enable_chunked_prefill=true`** in LLM constructor: gestisce prompt lunghi in chunked prefill incrementale, riduce KV cache pressure.
5. **`max_model_len` ridotto a ~16K**: limita per-request KV slot, più concorrenza, meno fragmentazione paged-attn. Implica però troncare i prompt che superano (split chunks più piccoli a 25 sample/chunk).

### Indizi input (ridurre superficie)

1. **Rebuild input con chunk_size=25**: tutti i prompt sotto ~50KB / ~14K token. ~10,500 record totali (~1.6x current). Test se il bug sparisce con prompt più piccoli (proxy della causa).
2. **Sequenza di processing diversa**: ordinare records dal più piccolo al più grande prima del round-robin sharding. Workers warm-up gradualmente. Forse il bug emerge solo con prompt grandi su engine "fresco".

### Indizi infrastruttura

1. **enable_prefix_caching=False**: disabilita prefix cache (default true in v1). Forse il prefix cache si corrompe su prompt eterogenei lunghi.
2. **Singularity overlay R/W**: forse il container readonly causa problemi con file di stato vLLM. `singularity exec --writable-tmpfs ...`.
3. **Single GPU smoke test su tutti i 6652 record**: bypass del data parallelism. 1 worker su 1 GPU, batch più piccolo. Più lento ma forse più stabile.

## Stato persistente

### Sul cluster DGX (preservato)

- `runs/20260508T010911Z-alpha-stage2-v5-3422c3/predictions.worker_0.jsonl` — 340 records
- `runs/20260508T010911Z-alpha-stage2-v5-3422c3/predictions.worker_1.jsonl` — 330 records
- `runs/20260508T010911Z-alpha-stage2-v5-3422c3/predictions.worker_2.jsonl` — 335 records
- `runs/20260508T010911Z-alpha-stage2-v5-3422c3/predictions.worker_3.jsonl` — 335 records
- **Totale: 1340 records preservati**

Questi record sono stage2.v2 free-JSON (no guided), validità schema da verificare post-hoc. Possono essere collected via `dgx_p4_collect()` per inspection / parziale eval.

### Sul laptop locale (modifiche non committate)

```
M  CLAUDE.md
M  DESCRIPTION                            # Version bump 9011 -> 9012
M  NEWS.md
M  R/dgx-bundle.R
M  R/llm-stage2.R
M  inst/dgx/python/prompts.py
M  inst/dgx/python/run_p4_vllm.py
M  inst/extdata/p4-defaults.yml
?? analysis/p4-stage2-build-input.R         # tracked
?? analysis/p4-stage2-eval.R                # tracked
?? data-raw/p4-alpha-stage2.jsonl           # 181 MB — gitignored come .jsonl in data-raw/
?? docs/superpowers/specs/2026-05-08-task22-stage2-vllm-stalls-investigation.md
# Gitignored (NON nello status):
#   analysis/p4-bundles/alpha-stage2-bundle.rds
#   analysis/p4-bundles/alpha-stage2-job.rds
#   analysis/p4-bundles/<run_id>/...
#   analysis/p4-output/<run_id>/...
```

Tests: `devtools::test()` passa 526/526 (3 skip OPENAI_API_KEY pre-existing).

## Next session plan — full alpha stage2-cs25 run

Tutto pronto per il full run. Plan operativo (da NUOVA SESSIONE per handoff pulito):

### Triage iniziale (5 min)

1. Verificare branch `p4-dgx-integration`, modifiche fix committate.
2. Pulire i runs vecchi residual stage2 sul cluster (opzionale): `runs/20260508T010911Z-alpha-stage2-v5-3422c3/` (1340 record obsoleti) e i runs `T5*` smoke.

### Submit full alpha stage2-cs25

```r
devtools::load_all()
cfg <- dgx_config()  # default poddgx02
b <- dgx_p4_build_bundle(
  input_jsonl = "data-raw/p4-alpha-stage2-cs25.jsonl",  # 8546 record, max ~47KB
  stage = "stage2",
  config = cfg,
  metadata = list(slug = "alpha-stage2-cs25"),
  bundle_dir_root = "analysis/p4-bundles"
)
job <- dgx_p4_submit(b, time = "06:00:00")  # generoso
saveRDS(job, "analysis/p4-bundles/alpha-stage2-cs25-job.rds")
```

### Tempo stimato

- 8546 record / 4 worker = ~2137/worker
- Throughput T5h con max_tokens=4096: ~10-15 sec/record (output medi 2-3K token)
- Per worker: ~5.5h
- Wall stimato: **5-6h** (ben dentro time=06:00:00)

### Polling

```r
job <- readRDS("analysis/p4-bundles/alpha-stage2-cs25-job.rds")
dgx_p4_status(job, watch = TRUE, interval = 60)
```

### Eval atteso

`analysis/p4-stage2-eval.R` skeleton esiste. Per il full run:

1. `dgx_p4_collect(job)` → raccoglie predictions.jsonl
2. Schema validity post-hoc (atteso ≥95% — basato su T5h 97% mini500)
3. Spot-check qualitativo 10-20 predictions
4. Binary accuracy vs `inst/extdata/p35c-minigold-reviewed-v5.csv` (100 sample, 16 GSE)
   - Target ≥95% (acceptance hard)
   - Investigative [80%, 95%) — analizzare residuals per pattern
   - Bug < 80% — debug prima di proseguire

### Rescue residual truncated (3% atteso)

I record con output >3K token saranno troncati a max_tokens=4096. Strategia (analoga a stage1 alpha investigation 2026-05-07):

1. Identifica record con `valid_schema=FALSE` AND raw_output non termina con `}`
2. Re-submit solo quei record con `gen-overrides='{"max_tokens": 8192}'`
3. Merge con il run principale

Helper: `analysis/p4-bundles/run-smoke-stage2.R` supporta override `max_tokens` via `--gen-overrides '{"max_tokens": 8192}'`.

### Acceptance Task 22 (dal Plan P4)

- Schema valid rate ≥ 95% — atteso PASS (T5h 97% su mini500 cs25)
- Stage2 binary accuracy ≥ 95% target / [80,95) investigativo / <80% debug

## Riferimenti

- vLLM Issue #39734: <https://github.com/vllm-project/vllm/issues/39734>
- Plan P4 Task 22: `docs/superpowers/plans/2026-05-06-p4-dgx-integration-plan.md` lines 3231-3326.
- ADR-0007 DGX self-host: `docs/decisions/0007-dgx-self-host-vllm.md`.
- ADR-0008 vLLM sampling defaults: `docs/decisions/0008-vllm-sampling-defaults.md`.
- Spec P4 design: `docs/superpowers/specs/2026-05-06-p4-dgx-integration-design.md`.
