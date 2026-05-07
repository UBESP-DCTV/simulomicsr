# P4 — Integrazione DGX UniPD HPC per run massivo Stadio 1+2

- **Status:** Approved (2026-05-06), implementato + smoke E2E validato (2026-05-07)
- **Phase:** P4 (run massivo classificazione LLM)
- **Approvals:** Luca Vedovelli (utente)
- **Riferimenti:**
  - CLAUDE.md sezione "Next session: setup DGX + P4"
  - P3.5-D (decisione modello: `mistral-small-3.2-24b-instruct`, vincitore 96% accuracy)
  - ADR-0005 server-migration trigger
  - Esempio collega `laims-dgx-llm-batch-main/` (riferimento, non importato)
  - Esempio interno `2026.scRNA_DGX/` (stesso cluster, stesso pattern Apptainer + 8 GPU)

## ⚠️ Update 2026-05-07 — Diff rispetto al design originale

Smoke E2E validato (job 19723 su poddgx03 + 19724 su poddgx02). Le sezioni
sotto descrivono il design originale; la realta' implementata diverge in
alcuni punti chiave. **Per stato corrente, vedi:**

- [`docs/decisions/0007-dgx-self-host-vllm.md`](../../decisions/0007-dgx-self-host-vllm.md) — sezione "Update 2026-05-07"
- `CLAUDE.md` — sezione "Lessons learned operative durante P4 setup"

**Delta principali** rispetto a quanto scritto nelle sezioni 3-7 di questa
spec:

| Aspetto | Design (questa spec) | Implementato 2026-05-07 |
|---|---|---|
| Image base | `vllm/vllm-openai:v0.6.4` | **`v0.10.0`** (v0.6.4 dava `KeyError 'mistral3'`) |
| Path remoto | `/mnt/home/u0044/...` | **`/home/u0044/...`** (compute non monta `/mnt/home/`) |
| Esecuzione singularity | `srun singularity exec` | **`singularity exec` diretto** (no srun) |
| Init vLLM | `LLM(model=..., dtype=bfloat16, trust_remote_code=True)` | aggiunge **`tokenizer_mode="mistral"`** + `config_format="mistral"` + `load_format="mistral"` (Mistral-3.2 e' multimodale) |
| Sampling | `SamplingParams(guided_json=schema)` | **`GuidedDecodingParams(json=schema)`** (API v1 vLLM 0.10) |
| Generazione | `llm.generate(prompts)` con `apply_chat_template` | **`llm.chat(messages=...)`** (Tekken tokenizer non supporta apply_chat_template) |
| `nodelist` default | `poddgx02` hardcoded nel design | `dgx_config()` con default `"poddgx02"`, override a `NULL` per scheduler-pick |
| `runs/<run_id>/` | atteso pre-esistente | `dgx_p4_submit()` fa `mkdir -p` esplicito (SLURM `--output` fallisce signal 53 senza dir) |

## 1. Obiettivo

Definire l'infrastruttura **bespoke minimale** dentro `simulomicsr` per eseguire run massivi di classificazione LLM (Stadio 1 sample-level + Stadio 2 study-level) sulla **DGX UniPD HPC** (`logindgx.hpc.ict.unipd.it`, partition `dgx12cluster`, account `dctv_dgx`, nodelist `poddgx02`) con il modello self-hosted `mistralai/Mistral-Small-3.2-24B-Instruct-2506` in bfloat16 su 4× H100 in data-parallel via vLLM.

Output P4:

- **Pacchetto R esteso** con 5 nuove funzioni esportate (`dgx_config()`, `dgx_p4_build_bundle()`, `dgx_p4_submit()`, `dgx_p4_status()`, `dgx_p4_collect()`) per il control plane locale.
- **Payload remoto** in `inst/dgx/` (Apptainer def, slurm template, script Python vLLM) trasferito al cluster con un singolo `rsync`.
- **Run α** (smoke E2E sui 130k sample del xlsx, ~3-4h Stadio 1 + ~10-15min Stadio 2) per validare end-to-end.
- **Run β** (full ARCHS4 700k sample / 22k studi) **deferred** a milestone successiva: richiede ETL ARCHS4 H5 → JSONL non incluso in questo design. L'infrastruttura α gira su β senza modifiche, cambia solo il file di input.

## 2. Razionale

### Perché bespoke minimale (non fork di laimsdgxllm)

L'esempio `laims-dgx-llm-batch-main` del collega è battle-tested sull'esatto cluster, ma:

1. È pensato per **workflow multi-prompt riutilizzabile** (R package self-contained, registry SQLite, recover_job, watch progress). P4 ha **un solo tipo di run** ricorrente; quell'astrazione è overhead.
2. Backend `transformers` single-record loop. Per 700k sample il throughput sarebbe inaccettabile (50-100h+). Ci serve **vLLM continuous batching** che il pacchetto del collega non ha.
3. Modelli hardcoded `gpt-oss-20b/120b` con account/path `dctv_dgx`/`u0043`. Per usarlo dovremmo cambiare ~80% del codice.
4. Aggiungere un pacchetto R esterno come dipendenza di `simulomicsr` aumenta la superficie di manutenzione senza beneficio chiaro.

Bespoke minimale tiene tutto dentro `simulomicsr`: ~100 righe R + ~150 righe Python + 1 Apptainer def + 1 SLURM template. Riusa **pattern e formati file** di `laimsdgxllm` (manifest.json, predictions.jsonl, status.json) per leggibilità ma non ne importa il codice.

### Perché 4× H100 data-parallel (non 1× o 8×)

- **1× H100**: throughput insufficiente per Stadio 1 su 700k sample (50-100h, vicino al wall time max 7gg, richiede resume/checkpoint complessi).
- **8× H100**: massimo throughput ma satura `poddgx02` per altri colleghi. Politica HPC raccomanda di non monopolizzare il nodo se non strettamente necessario.
- **4× H100**: ~4× speedup (Stadio 1 in ~14-25h, Stadio 2 in ~30 min), nodo non saturato, niente resume necessario per α (130k → ~4h), per β resume incrementale comunque presente come safety.

vLLM **data-parallel** (1 modello per GPU, input shardato) è preferito a tensor-parallel per un 24B FP16: il modello entra largo in 80GB, niente comm overhead inter-GPU.

### Perché vLLM offline batch (non server mode)

vLLM offre due modi:
- **`vllm serve`** (server HTTP OpenAI-compat): richiederebbe un job SLURM "always on", che il cluster non garantisce. Inoltre 4 server in ascolto su porte distinte complicano l'orchestrazione.
- **`LLM().generate(prompts)`** (offline batch): un singolo processo Python, continuous batching identico al server, niente HTTP overhead, niente port management. Stesso file di input → stesso file di output, deterministico.

L'adapter HTTP esistente `R/llm-client-openrouter.R` non viene riusato lato cluster: P4 ha il suo control plane R locale che parla via SSH/SLURM/file, non HTTP.

### Perché vLLM guided JSON

vLLM supporta nativamente Structured Outputs via `SamplingParams(guided_json=schema)`. Compila lo schema in grammatica e forza il decoder a emettere SOLO token che mantengono validità schema. Tasso di output schema-valid atteso ≈ 100% (vs ~98.8% gpt-5.5/P3.5-A). Per un modello "small" 24B questo è critico: senza guided decoding mistral può sbavare sul JSON in modo non recuperabile.

### Perché resume incrementale (option ii della discussione)

Il file `predictions.jsonl` è la **sola fonte di verità del progresso**. Su restart, il Python all'avvio legge gli `record_id` già scritti e li toglie dall'input prima di partire. Costo: ~10 righe Python in più. Beneficio: per run β (14-25h) salva potenzialmente decine di ore di burn rate. Niente registry SQLite, niente checkpoint binari.

### Perché input JSONL neutro

Il bundle accetta `input.jsonl` con righe `{record_id, string}` (Stadio 1) o `{record_id, study_summary, samples}` (Stadio 2). Lo stesso codice gira su:
- **α**: 130k sample dal xlsx (`relevant_sample_classified.xlsx` colonna `string`)
- **β**: 700k sample da ARCHS4 H5 (extraction non in scope)
- Run futuri di test/dev/sanity check.

## 3. Architettura

```
                         LAPTOP (R control plane)                                CLUSTER (UniPD HPC)
   ┌───────────────────────────────────────────────────────┐    ┌─────────────────────────────────────────────┐
   │  R helpers in simulomicsr (~100 righe)                │    │  Login: logindgx.hpc.ict.unipd.it           │
   │                                                       │    │                                             │
   │  dgx_p4_build_bundle(input_jsonl, stage, ...)         │    │  /mnt/home/u0044/simulomicsr-dgx/           │
   │     → costruisce bundle locale                        │    │      bundles/<run_id>/                      │
   │                                                       │    │      runtime/current.sif                    │
   │  dgx_p4_submit(bundle, slurm_args)                    │ ─→ │      models/HF_HOME/   (~50GB pesi)         │
   │     rsync bundle → remote                             │    │      runs/<run_id>/                         │
   │     ssh sbatch slurm/run_p4.sh                        │    │          predictions.jsonl  (append)        │
   │                                                       │    │          errors.jsonl                       │
   │  dgx_p4_status(job, watch=TRUE) → squeue + status.json│    │          status.json        (live)          │
   │                                                       │    │          slurm-<jobid>.{out,err}            │
   │  dgx_p4_collect(run_id, dest)                         │ ←─ │  Compute: poddgx02 (4× H100)                │
   │     rsync runs/<run_id>/ → analysis/p4-output/        │    │      Apptainer .sif (vLLM 0.6.x)            │
   │                                                       │    │        Python: 4 worker DP, guided JSON     │
   └───────────────────────────────────────────────────────┘    └─────────────────────────────────────────────┘
```

**Flusso end-to-end**:

1. **Locale**: `dgx_p4_build_bundle()` legge input JSONL, aggiunge `prompt.txt` + `schema.json` (riusa `inst/schemas/sample_facts.stage1.v3.json` o `study_design.stage2.v2.json`) + `manifest.json` con `run_id` UUID + `generation.json`.
2. **Locale**: `dgx_p4_submit()` rsync del bundle al login node, poi `ssh ... sbatch run_p4.sh <run_id>`. Ritorna oggetto `job` con `run_id` + `slurm_job_id`.
3. **Cluster**: SLURM alloca 4 H100 su `poddgx02`, lancia container Apptainer. Lo script Python `run_p4_vllm.py` carica mistral-small-3.2 4 volte (data-parallel via `multiprocessing` con `CUDA_VISIBLE_DEVICES` distinto per worker), shard l'input round-robin, ogni worker scrive su `predictions.worker_<i>.jsonl`. Step finale di concat produce `predictions.jsonl`.
4. **Locale**: `dgx_p4_status()` SSH `squeue -j <slurm_job_id>` + scaricamento `status.json`. Watch loop opzionale.
5. **Locale**: `dgx_p4_collect()` rsync di `runs/<run_id>/` indietro, parse JSONL, ritorna `list(predictions, errors, summary)`.

**Punto di idempotenza**: `predictions.jsonl` (post-concat, oppure i `predictions.worker_<i>.jsonl` durante il run) sono la sola fonte di verità del progresso. Su restart (ri-`sbatch` con stesso `run_id`), Python all'avvio legge gli `record_id` già scritti, li toglie dall'input, riparte.

**Cosa NON c'è (deliberatamente)**:
- SQLite registry — un singolo `manifest.json` + cartella `runs/<run_id>/` bastano
- chunk planner — vLLM continuous batching gestisce il batching interno
- multi-prompt scheduler — un run = una stage = un prompt template
- recover_job machinery — il `run_id` è lo stato, basta scriverselo
- retry policies a livello di singolo record — un record che fa errore va in `errors.jsonl` e si itera offline su quelli alla fine

## 4. Componenti (file)

| File | Stato | Responsabilità | LOC stimato |
|---|---|---|---|
| `R/dgx-config.R` | NUOVO | `dgx_config()` con default UniPD HPC hardcoded (`login_user="u0044"`, `mail_user="luca.vedovelli@unipd.it"`, partition/account/nodelist), validazione, override | ~80 |
| `R/dgx-bundle.R` | NUOVO | `dgx_p4_build_bundle(input_jsonl, stage, config, ...)`: genera `manifest.json`, `prompt.txt`, `schema.json`, `generation.json`, `status.json`, copia `input.jsonl` | ~100 |
| `R/dgx-submit.R` | NUOVO | `dgx_p4_submit()`, `dgx_p4_status()` (con watch), `dgx_p4_collect()`, `dgx_p4_recover()` | ~150 |
| `R/dgx-utils.R` | NUOVO | helpers privati `.dgx_ssh()`, `.dgx_rsync()` via `processx`, `.dgx_run_id()` (UUID), `.dgx_render_slurm_template()` | ~80 |
| `inst/dgx/Dockerfile` | NUOVO | Dockerfile FROM `vllm/vllm-openai:v0.6.4`, COPY python/, ENTRYPOINT run_p4_vllm.py | ~20 |
| `inst/dgx/Makefile` | NUOVO | target `build`/`push`/`pull-cluster` per workflow docker→DockerHub→singularity | ~30 |
| `inst/dgx/slurm/run_p4.sh` | NUOVO | template SLURM con placeholder `__RUN_ID__`, `__USER__`, `__TIME__`, `__MAIL_USER__`, partition/account/nodelist hardcoded; bind mount bundle/run/HF_HOME, srun apptainer exec | ~50 |
| `inst/dgx/python/run_p4_vllm.py` | NUOVO | entry: parse args, load schema, init 4 worker `multiprocessing.Process` con `CUDA_VISIBLE_DEVICES`, shard input, concat output | ~120 |
| `inst/dgx/python/prompts.py` | NUOVO | `render_prompt_stage1(template, record)`, `render_prompt_stage2(...)`, port 1:1 dei prompt R esistenti | ~60 |
| `inst/dgx/python/resume.py` | NUOVO | `existing_record_ids(predictions_path)`, `filter_input(input_records, done_ids)` | ~30 |
| `inst/extdata/p4-defaults.yml` | NUOVO | catalogo: model_id, sampling defaults per stage (max_tokens 1024/4096, temp 0), HF cache hint | ~25 |
| `tests/testthat/test-dgx-config.R` | NUOVO | default UniPD HPC + override + path computation | ~60 |
| `tests/testthat/test-dgx-bundle.R` | NUOVO | build bundle con input mini, struttura JSONL/manifest valida, schema embedded valido | ~80 |
| `tests/testthat/fixtures/p4-input-mini.jsonl` | NUOVO | 5 record stage1-style + 3 record stage2-style per test | ~10 |
| `DESCRIPTION` | modificato | aggiunge `processx` agli `Imports` (attualmente non presente, verificato 2026-05-06) | — |
| `NAMESPACE` | rigenerato roxygen | export 5 funzioni `dgx_*` | — |
| `vignettes/p4-dgx-setup.Rmd` | NUOVO | guida one-time setup: SSH key, HF token, `apptainer build`, smoke run | ~80 righe |
| `analysis/p4-output/` | NUOVO (gitignored) | destinazione `dgx_p4_collect()` | — |
| `.gitignore` | esteso | ignora `analysis/p4-output/` | +1 riga |
| `docs/decisions/0007-dgx-self-host-vllm.md` | NUOVO | ADR-0007 cattura decisione "no OpenAI for P4, no laimsdgxllm fork, mistral-small-3.2 self-host on DGX" | ~60 righe |

**Totale stimato**: ~1100 righe nuove (650 R/Python + 250 test + 200 docs).

## 5. Bundle format (locale → remoto)

```
bundles/<run_id>/
├── manifest.json         # run_id, stage, model_id, created_at, record_count, schema_id
├── input.jsonl           # 1 riga per record. Stage1: {record_id, string}. Stage2: {record_id, study_summary, samples}.
├── prompt.txt            # template (testo Italiano, identico a R/llm-stage1.R / R/llm-stage2.R)
├── schema.json           # JSON Schema da inst/schemas/<stage>.json
├── generation.json       # {temperature: 0, max_tokens: <stage-default>, dtype: "bfloat16", guided_json: true}
└── status.json           # stato iniziale "created"; aggiornato live durante il run
```

**Output** (cluster → locale):

```
runs/<run_id>/
├── predictions.jsonl     # 1 riga per record_id, append-only
├── predictions.worker_*.jsonl   # file per-worker durante il run, mergiati a fine job
├── errors.jsonl          # record con parse error / OOM / schema violation
├── status.json           # {state, started_at, records: {total, completed, failed}, current_eta}
├── run_summary.json      # snapshot finale: durata, throughput, totals, model_id, slurm_job_id
└── slurm-<jobid>.out/.err   # stdout/stderr del job (controllo manuale)
```

Schema riga `predictions.jsonl`:
```json
{
  "record_id": "GSM12345",
  "raw_output": "{\"cell_context\":...}",
  "parsed_json": {"cell_context": "...", "...": "..."},
  "valid_schema": true,
  "worker_id": 2,
  "ts": "2026-05-06T14:23:01Z"
}
```

## 6. Container — Docker build locale + DockerHub + Singularity pull

**Pattern adottato (allineato a `2026.scRNA_DGX`)**: docker build locale → push DockerHub → `singularity pull` sul login node DGX. Niente `apptainer build --fakeroot` remoto. Razionale:

- Evita `--fakeroot` (può non essere abilitato su tutti i cluster).
- Build su laptop e' tipicamente piu' rapida del compile su login node.
- DockerHub fornisce versioning + immutabilita' delle immagini.
- Stesso flusso che l'utente gia' usa per `lucavd/sc-benchmark` su `poddgx02`.

**`inst/dgx/Dockerfile`**:

```dockerfile
# CUDA 12.1+ richiesto da vLLM 0.6.x. Driver DGX UniPD HPC (poddgx02)
# verificato compatibile con CUDA 12 dal progetto 2026.scRNA_DGX.
FROM vllm/vllm-openai:v0.6.4

LABEL maintainer="simulomicsr" \
      model="mistralai/Mistral-Small-3.2-24B-Instruct-2506" \
      purpose="P4 batch classification stage1+stage2"

# Dependencies extra per il nostro runtime
RUN pip install --no-cache-dir jsonschema orjson pyyaml

# Copia gli script Python custom
COPY python /opt/simulomicsr/runtime/python

ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/opt/simulomicsr/runtime/python \
    HF_HOME=/work/models/HF_HOME \
    TRANSFORMERS_CACHE=/work/models/HF_HOME

# Override l'entrypoint vllm/vllm-openai (api_server) con il nostro batch runner
ENTRYPOINT ["python", "/opt/simulomicsr/runtime/python/run_p4_vllm.py"]
```

**Build & deploy workflow** (allineato 1:1 a `2026.scRNA_DGX/Makefile` — niente SSH wrapping nel Makefile, target separati per laptop e cluster):

```sh
# === LAPTOP, dalla radice del pacchetto ===
cd inst/dgx
make build         # docker build -t lucavd/simulomicsr-vllm:latest .
make push          # docker push lucavd/simulomicsr-vllm:latest

# === LOGIN NODE DGX (dopo SSH) ===
ssh u0044@logindgx.hpc.ict.unipd.it
cd ~/simulomicsr-dgx/runtime/
module load singularity/4.2.0
make -f /path/al/repo/inst/dgx/Makefile pull-singularity     # produce simulomicsr-vllm.sif
make -f /path/al/repo/inst/dgx/Makefile predownload-model    # huggingface-cli, ~50 GB
```

Tempo: docker build locale ~3-5 min (cache hit per layer vllm), push DockerHub 1-2 min, singularity pull cluster 2-5 min, predownload modello 10-15 min.

**Versioning**: il SLURM job referenzia `simulomicsr-vllm.sif` (filename consistente con `$(IMAGE_NAME).sif` del Makefile). Cambio di immagine = nuovo `make pull-singularity`.

**Driver caveat**: i driver NVIDIA su `poddgx02` potrebbero non essere all'ultima major. Se vLLM 0.6.4 fallisce con `CUDA driver too old`, fallback documentati:
- `vllm/vllm-openai:v0.5.5` (CUDA 11.8 compat)
- Self-build da `nvidia/cuda:12.1-runtime` + `pip install vllm==0.6.4`

Il test smoke 1 GPU (Plan Task 18) e' lo screening: se carica e genera senza errori CUDA, siamo allineati.

**Pesi modello fuori dal SIF**: `HF_HOME` bind-mounted da `/mnt/home/u0044/simulomicsr-dgx/models/HF_HOME`. **Pre-download UNA VOLTA** sul login node:

```sh
# Su login node, con HF_TOKEN esportato (~/.simulomicsr-dgx.env)
. ~/.simulomicsr-dgx.env
singularity exec \
  --bind /mnt/home/u0044/simulomicsr-dgx/models/HF_HOME:/work/models/HF_HOME \
  /mnt/home/u0044/simulomicsr-dgx/runtime/current.sif \
  huggingface-cli download mistralai/Mistral-Small-3.2-24B-Instruct-2506 \
  --token "$HF_TOKEN"
# Aspetta ~10-15 min, ~50GB scaricati una volta sola.
```

Dopo questo step, i job SLURM partono con cache hit (cold load ~30-60s) e **non hanno bisogno di rete o `HF_TOKEN`** a runtime.

## 7. SLURM template

```bash
#!/bin/bash
#SBATCH --job-name=simulomicsr-p4-__RUN_ID_SHORT__
#SBATCH --partition=dgx12cluster
#SBATCH --account=dctv_dgx
#SBATCH --nodelist=poddgx02
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=32
#SBATCH --mem=200G
#SBATCH --gres=gpu:4
#SBATCH --time=__TIME__
#SBATCH --mail-user=__MAIL_USER__
#SBATCH --mail-type=ALL
#SBATCH --output=/mnt/home/__USER__/simulomicsr-dgx/runs/__RUN_ID__/slurm-%j.out
#SBATCH --error=/mnt/home/__USER__/simulomicsr-dgx/runs/__RUN_ID__/slurm-%j.err

set -euo pipefail
module load singularity/4.2.0
module load slurm/slurm/23.02.7

REMOTE_ROOT=/mnt/home/__USER__/simulomicsr-dgx
RUN_ID=__RUN_ID__

mkdir -p $REMOTE_ROOT/runs/$RUN_ID $REMOTE_ROOT/models/HF_HOME

srun /cm/shared/apps/singularity/4.2.0/bin/singularity exec \
  --nv \
  --bind $REMOTE_ROOT/bundles/$RUN_ID:/work/bundle \
  --bind $REMOTE_ROOT/runs/$RUN_ID:/work/run \
  --bind $REMOTE_ROOT/models/HF_HOME:/work/models/HF_HOME \
  --env HF_TOKEN=$HF_TOKEN \
  $REMOTE_ROOT/runtime/current.sif \
  --bundle /work/bundle --output /work/run --workers 4
```

`HF_TOKEN` letto dal login node da `~/.simulomicsr-dgx.env` (chmod 600), esportato prima dello sbatch via wrapper script `dgx_p4_submit()` lato R.

## 8. Script Python `run_p4_vllm.py`

**Architettura processo**: 4 worker `multiprocessing.Process`, ciascuno con `CUDA_VISIBLE_DEVICES=<i>` distinto. Ogni worker monta un'istanza vLLM:

```python
from vllm import LLM, SamplingParams
llm = LLM(
    model="mistralai/Mistral-Small-3.2-24B-Instruct-2506",
    tensor_parallel_size=1,
    dtype="bfloat16",
    gpu_memory_utilization=0.90,
)
```

**Sharding**: dopo filtro resume (skip ID già in qualunque `predictions.worker_*.jsonl`), gli N record da fare vengono splittati round-robin in 4 fette uguali. Ogni worker scrive su `predictions.worker_<i>.jsonl` separato. Niente race condition, niente file lock. A fine job, step di concat finale produce `predictions.jsonl` unico.

**Inferenza**:
```python
sampling = SamplingParams(
    max_tokens=stage_max_tokens,    # 1024 stage1, 4096 stage2
    temperature=0.0,
    guided_json=schema_dict,        # vLLM structured output guarantito
)
outputs = llm.generate(prompts, sampling)
```

vLLM continuous batching: passa la lista intera dei prompt del worker, vLLM ottimizza il batching internamente (concurrency ~24 stage1, ~12 stage2 stimata su 1 H100 80GB).

**Status update**: ogni worker scrive parziali in `status.worker_<i>.json` ogni 100 record. Step di aggregazione (in-loop o post) somma in `status.json` globale. Throughput visibile da locale via `cat ~/simulomicsr-dgx/runs/<run_id>/status.json`.

**Errori**: try/except per record. Un record che fa OOM o panica vLLM viene loggato in `errors.jsonl` con stack trace e il worker prosegue. Niente fail-fast del job intero.

## 9. R API (utente finale)

```r
library(simulomicsr)

cfg <- dgx_config()      # default: u0044, luca.vedovelli@unipd.it, dctv_dgx, poddgx02
# override possibile:
# cfg <- dgx_config(login_user = "altro", mail_user = "altro@unipd.it")

# build neutro
bundle <- dgx_p4_build_bundle(
  input_jsonl = "data-raw/p4-alpha-input.jsonl",  # o stage2 input
  stage       = "stage1",                          # o "stage2"
  config      = cfg,
  metadata    = list(slug = "alpha-xlsx-stage1")
)

# submit
job <- dgx_p4_submit(bundle, time = "12:00:00", config = cfg)
# job: list(run_id, slurm_job_id, bundle_path, remote_path, submitted_at)

# poll
dgx_p4_status(job)              # snapshot
dgx_p4_status(job, watch = TRUE)  # blocca + tail status.json fino a stato terminale

# recovery dopo restart R
job2 <- dgx_p4_recover(run_id = "20260507T093012Z-alpha-xlsx-stage1-a3f9", config = cfg)

# collect
result <- dgx_p4_collect(job, dest = "analysis/p4-output/")
# result$predictions: data.frame con record_id, parsed_json (list-col), valid_schema, worker_id, ts
# result$errors:      data.frame con record falliti
# result$summary:     run_summary
```

5 funzioni esportate: `dgx_config`, `dgx_p4_build_bundle`, `dgx_p4_submit`, `dgx_p4_status`, `dgx_p4_collect` + 1 di servizio `dgx_p4_recover`.

## 10. Configuration & secrets

| Asset | Location | Setup |
|---|---|---|
| SSH key login DGX | `~/.ssh/id_rsa` (o agent-loaded) | già esistente, uso quotidiano |
| Docker login | laptop `~/.docker/config.json` | one-time: `docker login` con account `lucavd` |
| `HF_TOKEN` (Mistral 3.2 gated) | login node `~/.simulomicsr-dgx.env` chmod 600 | one-time: `ssh u0044@... ; echo 'export HF_TOKEN=hf_xxx' > ~/.simulomicsr-dgx.env`. Usato SOLO durante il pre-download del modello (Step setup 17.5 nel plan). I job SLURM successivi pescano da cache HF_HOME e non lo richiedono. |
| EULA HF Mistral 3.2 | accettata su huggingface.co | one-time, account web |
| Modello in HF cache | login node `/mnt/home/u0044/simulomicsr-dgx/models/HF_HOME/` | one-time: `singularity exec ... huggingface-cli download mistralai/Mistral-Small-3.2-24B-Instruct-2506`. ~50GB, 10-15 min. Dopo: zero rete, zero token a runtime. |
| Docker image | DockerHub `lucavd/simulomicsr-vllm:latest` (+ `:v1`, `:v2`, ...) | `make -C inst/dgx build push` da laptop |
| Singularity SIF | login node `/mnt/home/u0044/simulomicsr-dgx/runtime/current.sif` | `singularity pull --force current.sif docker://lucavd/simulomicsr-vllm:latest` (~6-8 GB) |
| `dgx_config()` defaults | hardcoded nel pacchetto | `login_user="u0044"`, `mail_user="luca.vedovelli@unipd.it"`, root path `/mnt/home/u0044/simulomicsr-dgx/`, partition/account/nodelist UniPD HPC |

**Niente** `OPENAI_API_KEY` necessaria per P4 (abbandoniamo OpenAI).

**Nuove dipendenze R**: `processx` (per SSH/rsync), da aggiungere a `Imports` in `DESCRIPTION` (verificato 2026-05-06: non presente).

## 11. Error handling — granularità

| Livello | Failure mode | Risposta |
|---|---|---|
| SSH/rsync | network down, key non autorizzata | `cli::cli_abort()` lato R |
| sbatch | quota / queue rejection | parse stderr, abort con messaggio attuabile |
| SLURM job | OOM nodo, walltime, kill admin | `state="failed"` da `squeue`. R suggerisce: "puoi ri-submittare con stesso run_id, riprenderà" |
| vLLM worker | crash su record patologico | record in `errors.jsonl`, worker prosegue |
| Schema validation | guided JSON edge case fail | `valid_schema=false`, `raw_output` preservato |
| Resume | file output corrotto a metà riga | parse riga-by-riga skip invalid; ultimi N record rifatti (costo trascurabile) |

## 12. Testing strategy

**Test unitari R (offline, deterministici, in CI)**:

- `test-dgx-config.R`: default UniPD HPC + override + path computation
- `test-dgx-bundle.R`: build bundle con input mini, verifica struttura JSONL/manifest, schema embedded valido, prompt rendering coerente con `R/llm-stage1.R` / `R/llm-stage2.R`
- Niente test che invocano SSH/SLURM in CI (troppo fragile, dipendenza esterna)

**Smoke test manuali sul cluster** (in ordine):

1. **Smoke 1 GPU 100 record stage1** — `--workers 1 --gres=gpu:1`, input mini di 100 record, verifica E2E in <10 min, output schema-valid 100/100
2. **Smoke 4 GPU 100 record stage1** — stesso input, 4 worker, verifica concat dei `predictions.worker_*.jsonl`
3. **Smoke resume** — kill manuale del job a metà, ri-`sbatch`, verifica che riparte solo dai record mancanti
4. **Run α completo Stadio 1** — 130k sample xlsx, 4 GPU, ~3-4h. Confronto con mini-gold v5 P3.5-D (100 sample reviewati): atteso ~96% accuracy
5. **Run α Stadio 2** — sui ~5.4k studi GSE che ne escono. Confronto con benchmark P3.5-A (100 GSE gold): atteso binary ≥80%

**Acceptance per chiusura P4 setup**:

- **Stadio 1 accuracy ≥ 95%** su mini-gold v5 (n=100 reviewati). Riferimento P3.5-D: mistral-small-3.2 ha fatto 96% sul mini-gold v5 — soglia 95% è quel risultato meno 1pp di tolleranza per varianza cross-run.
- **Stadio 2 accuracy ≥ 95%** (target aspirazionale) su sub-set sovrapponibile a P3.5-A. Riferimento doppio: P3.5-D mistral-small-3.2 mini-gold = 96%, ma P3.5-A gpt-5.5 su 1489 sample = 83.7% (più diversità → numeri più bassi). Soglia 95% è ambiziosa: se non raggiunta, **fallback investigativo** prima di promuovere a β:
  - Se accuracy ∈ [80%, 95%): setup tecnico OK, ma quality gap richiede prompt iter / test ulteriore. Documentare in addendum spec, decidere se bloccare β o accettare con riserva.
  - Se accuracy < 80%: probabile bug (prompt rendering Python ≠ R, schema parsing, guided JSON edge case). Debug obbligatorio prima di β.
- Throughput stage 1: ≥ 50 record/min/GPU (target ~14h per 130k su 4 GPU)
- Throughput stage 2: ≥ 10 record/min/GPU (target ~30 min per 5.4k su 4 GPU)
- 0 crash di worker su run α completo
- Resume verificato manualmente

β è fuori scope di questo design.

## 13. Layout file

```
simulomicsr/
├── R/
│   ├── dgx-config.R           # NEW
│   ├── dgx-bundle.R           # NEW
│   ├── dgx-submit.R           # NEW
│   └── dgx-utils.R            # NEW
│
├── inst/
│   ├── dgx/                   # NEW — payload remoto
│   │   ├── Dockerfile         # docker build context (FROM vllm/vllm-openai:v0.6.4)
│   │   ├── Makefile           # build / push / pull-cluster targets
│   │   ├── slurm/
│   │   │   └── run_p4.sh
│   │   └── python/
│   │       ├── run_p4_vllm.py
│   │       ├── prompts.py
│   │       └── resume.py
│   │
│   ├── extdata/
│   │   └── p4-defaults.yml    # NEW
│   │
│   └── schemas/               # GIÀ ESISTE, riusato
│
├── analysis/
│   └── p4-output/             # NEW (gitignored)
│
├── tests/testthat/
│   ├── test-dgx-config.R      # NEW
│   ├── test-dgx-bundle.R      # NEW
│   └── fixtures/
│       └── p4-input-mini.jsonl   # NEW
│
├── vignettes/
│   └── p4-dgx-setup.Rmd       # NEW
│
└── docs/
    ├── decisions/
    │   └── 0007-dgx-self-host-vllm.md   # NEW (ADR)
    └── superpowers/specs/
        └── 2026-05-06-p4-dgx-integration-design.md   # questo doc
```

## 14. Out of scope

Esplicitamente NON inclusi in P4 design (futuri):

- **ETL ARCHS4 H5 → JSONL** per run β (700k sample). Plan separato.
- **Rivalidazione modelli > 70B in FP16** sulla DGX (ADR-0006 menzione). Non serve per P4.
- **Migrazione a `ellmer`** come client LLM multi-provider. Discussa fine 2026-05-02, rimandata.
- **Server vLLM long-running** stile `vllm serve`. Cluster non lo supporta in modo affidabile.
- **Distributed inference cross-node** (multi-node tensor parallel). Non serve per 24B.
- **Retry policies sofisticate** a livello di record (exponential backoff, etc). Errori vanno in `errors.jsonl` per ispezione manuale.
- **Costi cloud / OpenRouter fallback**. P4 è 100% self-hosted.

## 15. Decisioni differite (eventuali)

- **Promuovere `inst/dgx/python/` a sotto-pacchetto Python distribuibile**: solo se in futuro lo riusiamo in altri progetti. Per ora resta payload privato.
- **`getOption("simulomicsr.dgx.*")` per config**: se mai il pacchetto avrà più utenti, promuoviamo i default hardcoded a opzioni R. Per ora resta hardcoded `u0044`.
- **Web UI / dashboard per monitoring run**: il `cat status.json` via SSH è sufficiente per ora.
