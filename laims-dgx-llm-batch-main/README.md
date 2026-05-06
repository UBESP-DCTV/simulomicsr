# laimsdgxllm

R package for batch LLM inference on a remote DGX/HPC cluster via SSH + SLURM + Apptainer/Singularity.

The user works in R on a laptop or workstation. The package handles reproducible bundles, remote runtime bootstrap, SLURM job submission, and result collection. No persistent service or public endpoint is involved.

## Requirements

- R with packages: `cli`, `DBI`, `fs`, `jsonlite`, `processx`, `RSQLite`, `yaml`
- SSH key for the DGX login node (`~/.ssh/<login_user>.key` by default)
- Access to `logindgx.hpc.ict.unipd.it`

## Installation

```r
# from the repo root
devtools::install()
# or during development
devtools::load_all()
```

## Quick start

```r
library(laimsdgxllm)

cfg <- dgx_config(
  login_user  = "u0043",
  mail_user   = "you@example.org"
)

# Bootstrap the managed runtime once (or when package assets change)
ensure_runtime("20B", config = cfg)
```

---

## Example 1 — single prompt, structured output

Extract a short summary from each clinical note.

```r
library(laimsdgxllm)

cfg <- dgx_config(
  login_user = "u0043",
  mail_user  = "you@example.org"
)

records <- data.frame(
  id   = c("pt001", "pt002", "pt003"),
  note = c(
    "Patient reports mild headache and nausea since yesterday.",
    "Discharge note: type-2 diabetes, hypertension, stable.",
    "Follow-up after appendectomy. No complications reported."
  ),
  stringsAsFactors = FALSE
)

schema <- list(
  type       = "object",
  properties = list(
    conditions = list(type = "array", items = list(type = "string")),
    severity   = list(type = "string", enum = I(c("mild", "moderate", "severe", "none")))
  ),
  required = I(c("conditions", "severity"))
)

job <- extract_batch(
  records         = records,
  id_col          = "id",
  text_col        = "note",
  prompt_template = "Extract all medical conditions and the overall severity level.",
  schema          = schema,
  model           = "20B",
  metadata        = list(slug = "clinical-extract"),
  config          = cfg
)

# Poll status
job_status(job)

# Collect when completed
results <- collect_results(job)
results$parsed$predictions
```

---

## Example 2 — two prompts over the same records

The package runs one prompt per job. For multiple prompts, create a bundle per prompt
and submit them independently. They can run concurrently on the cluster.

```r
library(laimsdgxllm)

cfg <- dgx_config(
  login_user = "u0043",
  mail_user  = "you@example.org"
)

records <- data.frame(
  id   = c("rec01", "rec02"),
  text = c(
    "Patient with fever, cough, and fatigue for three days.",
    "Elderly patient, confusion onset, no fever."
  ),
  stringsAsFactors = FALSE
)

# --- Prompt A: extract symptoms ---

schema_symptoms <- list(
  type       = "object",
  properties = list(
    symptoms = list(type = "array", items = list(type = "string"))
  ),
  required = I("symptoms")
)

bundle_symptoms <- create_bundle(
  records         = records,
  id_col          = "id",
  text_col        = "text",
  prompt_template = "List all symptoms mentioned in the clinical note.",
  schema          = schema_symptoms,
  model           = "20B",
  metadata        = list(slug = "symptoms"),
  config          = cfg
)

# --- Prompt B: classify urgency ---

schema_urgency <- list(
  type       = "object",
  properties = list(
    urgency = list(type = "string", enum = I(c("low", "medium", "high", "emergency"))),
    reason  = list(type = "string")
  ),
  required = I(c("urgency", "reason"))
)

bundle_urgency <- create_bundle(
  records         = records,
  id_col          = "id",
  text_col        = "text",
  prompt_template = "Classify the urgency of the clinical situation and explain why.",
  schema          = schema_urgency,
  model           = "20B",
  metadata        = list(slug = "urgency"),
  config          = cfg
)

# Submit both — they run concurrently on the cluster
job_symptoms <- submit_job(bundle_symptoms, config = cfg)
job_urgency  <- submit_job(bundle_urgency,  config = cfg)

# Check status independently
job_status(job_symptoms)
job_status(job_urgency)

# Collect when each is done
res_symptoms <- collect_results(job_symptoms)
res_urgency  <- collect_results(job_urgency)

res_symptoms$parsed$predictions
res_urgency$parsed$predictions
```

---

## Job lifecycle

```r
# List all known runs
jobs_list()

# Sync and inspect a specific job
job_status(job, refresh = TRUE)

# Watch live until terminal state
progress(job, watch = TRUE)

# Recover a job handle after restarting R
job <- recover_job("run-20260322T013154Z-hello-world-88b717")
```

---

## Operational notes

**MXFP4 warning** — `MXFP4 quantization requires Triton >= 3.4.0, we will default to dequantizing the model to bf16` appears on stderr for `openai/gpt-oss-20b`. This is expected: the model is loaded in bfloat16, which fits on a single H100 80GB. Not an error.

**HF Hub warning** — `You are sending unauthenticated requests to the HF Hub` appears if no `HF_TOKEN` is set in the container environment. The model loads from the persistent HF cache on first use. On subsequent jobs the cache is reused.

**Runtime bootstrap** — `ensure_runtime()` builds the `.sif` on the login node the first time and whenever package assets change (detected via hash). Subsequent calls reuse the existing image without rebuilding.

**SLURM time limit** — the default `time = "00:05:00"` is tight for the first run of a model (cold HF cache). On subsequent runs the model loads from the persistent cache in ~2 s. For cold-start jobs or many records, pass `slurm = list(time = "01:00:00")` to `submit_job()` or `extract_batch()`.

---

## Defaults

| Parameter    | Default              |
|-------------|----------------------|
| login host  | `logindgx.hpc.ict.unipd.it` |
| user root   | `/mnt/projects/dctv/dgx/<login_user>` |
| partition   | `dgx12cluster`       |
| account     | `dctv_dgx`           |
| nodelist    | `poddgx02`           |
| GPU         | 1× H100 80GB (fixed) |
| CPUs        | 4                    |
| RAM         | 32G                  |
| time limit  | 00:05:00             |

All defaults can be overridden in `dgx_config()` or per-job via `slurm = list(...)`.

---

## Repository layout

```
R/                        R package source
inst/config/models.yml    canonical model catalog (20B / 120B)
inst/runtime/             assets used by the managed runtime bootstrap
inst/templates/           SLURM job script template
docs/architecture.md      system architecture
docs/roadmap.md           known gaps and next steps
docs/schema_guide.md      how to write output schemas
```
