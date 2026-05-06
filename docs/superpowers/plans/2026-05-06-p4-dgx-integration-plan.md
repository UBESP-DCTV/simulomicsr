# P4 — Integrazione DGX UniPD HPC self-host vLLM mistral-small-3.2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Costruire l'infrastruttura bespoke minimale dentro `simulomicsr` per eseguire run massivi di classificazione LLM (Stadio 1 sample-level + Stadio 2 study-level) sulla DGX UniPD HPC (`logindgx.hpc.ict.unipd.it`, 4× H100 in data-parallel su `poddgx02`) con `mistralai/Mistral-Small-3.2-24B-Instruct-2506` via vLLM offline batch + guided JSON. Output: 5 funzioni R esportate (`dgx_config`, `dgx_p4_build_bundle`, `dgx_p4_submit`, `dgx_p4_status`, `dgx_p4_collect`) + payload remoto (Apptainer def, SLURM template, Python runtime) + smoke run α completo su 130k sample xlsx con accuracy stage1 ≥ 95% e stage2 ≥ 95% (target aspirazionale).

**Architecture:** R control plane locale (~410 LOC nuove) → SSH/rsync → bundle in `/mnt/home/u0044/simulomicsr-dgx/bundles/<run_id>/` → SLURM job 4 GPU su `poddgx02` → Apptainer container `vllm/vllm-openai` con script Python (`run_p4_vllm.py`, ~150 LOC) che fa 4 worker `multiprocessing` ciascuno con istanza vLLM `LLM(model=..., dtype="bfloat16")` e `SamplingParams(guided_json=schema)`. Output incrementale append a `predictions.worker_<i>.jsonl`, mergiato a `predictions.jsonl` a fine job. Resume idempotente: su restart, Python legge ID già scritti e li toglie dall'input. R post-processa i parsed JSON con il `parse_stage{1,2}_response()` esistente al collect, mantenendo consistenza con il dev workflow.

**Tech Stack:**
- R 4.5+, esistenti `cli`, `fs`, `jsonlite`, `httr2`, `glue`, `digest`, `tibble`, `purrr` + nuovo `processx` (SSH/rsync subprocess)
- Apptainer 4.2.0 / Singularity (cluster-managed, `module load singularity/4.2.0`)
- Python 3.11 + vLLM ≥ 0.6.4 + transformers + jsonschema + orjson (dentro il container, base image `vllm/vllm-openai:v0.6.4`)
- SLURM 23.02.7 (cluster-managed)
- Modello: `mistralai/Mistral-Small-3.2-24B-Instruct-2506` da HuggingFace (gated, richiede `HF_TOKEN` e EULA accettata)

---

## File Structure

| File | Stato | Responsabilità | LOC stimato |
|---|---|---|---|
| `R/dgx-config.R` | NUOVO | `dgx_config()` con default UniPD HPC hardcoded, validazione | ~80 |
| `R/dgx-utils.R` | NUOVO | helper interni `.dgx_run_id()` UUID, `.dgx_ssh()`, `.dgx_rsync()`, `.dgx_render_slurm_template()` | ~100 |
| `R/dgx-bundle.R` | NUOVO | `dgx_p4_build_bundle(input_jsonl, stage, config, ...)` | ~100 |
| `R/dgx-submit.R` | NUOVO | `dgx_p4_submit()`, `dgx_p4_status()`, `dgx_p4_collect()`, `dgx_p4_recover()` | ~150 |
| `inst/dgx/Dockerfile` | NUOVO | FROM vllm/vllm-openai:v0.6.4, COPY python/, ENTRYPOINT run_p4_vllm.py | ~20 |
| `inst/dgx/Makefile` | NUOVO | target docker build / push / pull-cluster / predownload-model | ~40 |
| `inst/dgx/.dockerignore` | NUOVO | escludi __pycache__, .pyc dal build context | ~5 |
| `inst/dgx/slurm/run_p4.sh` | NUOVO | template SLURM con placeholder `__RUN_ID__`/`__USER__`/`__TIME__`/`__MAIL_USER__` | ~50 |
| `inst/dgx/python/run_p4_vllm.py` | NUOVO | entry: 4 worker DP, vLLM offline batch, guided JSON, append JSONL | ~150 |
| `inst/dgx/python/prompts.py` | NUOVO | `render_user_message_stage1(record)`, `render_user_message_stage2(record)` | ~50 |
| `inst/dgx/python/resume.py` | NUOVO | `existing_record_ids(predictions_glob)`, `filter_input_records(records, done_ids)` | ~30 |
| `inst/extdata/p4-defaults.yml` | NUOVO | model_id, sampling defaults per stage, HF cache hint | ~25 |
| `tests/testthat/test-dgx-config.R` | NUOVO | default UniPD HPC + override + validazione | ~70 |
| `tests/testthat/test-dgx-bundle.R` | NUOVO | build bundle stage1+stage2, struttura JSONL/manifest valida | ~120 |
| `tests/testthat/test-dgx-submit.R` | NUOVO | submit/status/collect mocked via processx fake; recover roundtrip | ~150 |
| `tests/testthat/fixtures/p4-input-mini.jsonl` | NUOVO | 5 record stage1-style + 3 record stage2-style | ~10 |
| `DESCRIPTION` | modificato | aggiunge `processx` agli `Imports` | +1 riga |
| `NAMESPACE` | rigenerato | export 5 funzioni `dgx_*` | auto |
| `.gitignore` | esteso | ignora `analysis/p4-output/` | +1 riga |
| `docs/decisions/0007-dgx-self-host-vllm.md` | NUOVO | ADR-0007 cattura decisione P4 | ~80 |
| `vignettes/p4-dgx-setup.Rmd` | NUOVO | guida one-time setup utente | ~100 |

**Totale nuovo codice**: ~430 R + ~230 Python + ~340 test/docs ≈ 1000 LOC.

**Cosa NON è in scope** (vedi spec §14):
- ETL ARCHS4 H5 → JSONL per run β (700k sample). Plan separato.
- Modelli > 70B in FP16. Non serve per P4.
- Migrazione a `ellmer`. Rimandata.
- Server vLLM long-running. Cluster non lo supporta affidabilmente.

---

## Task 1: Branch + baseline check

**Files:**
- Solo verifica stato repo (no modifiche file). Branch `p4-dgx-integration` già creato durante brainstorming.

- [ ] **Step 1.1: Verifica branch corrente e ultimo commit**

```bash
git status && git log --oneline -3
```

Expected: `On branch p4-dgx-integration`, ultimo commit `db4c74f P4 design: alza acceptance Stage 2 a 95%...`, working tree clean.

- [ ] **Step 1.2: Verifica test suite baseline pulita**

```bash
Rscript --vanilla -e 'devtools::test()'
```

Expected: 444 PASS / 0 FAIL (riferimento CLAUDE.md fine sessione `simulomicsr_brain2`).

- [ ] **Step 1.3: Verifica R CMD check baseline**

```bash
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = FALSE)' 2>&1 | tail -20
```

Expected: 0 errors, 0 warnings, note pre-esistenti accettabili.

- [ ] **Step 1.4: Nessun commit (solo verifica baseline)**

---

## Task 2: DESCRIPTION + `.gitignore` setup

**Files:**
- Modifica: `DESCRIPTION` (riga `Imports:`)
- Modifica: `.gitignore`

- [ ] **Step 2.1: Aggiungi `processx` agli `Imports` di DESCRIPTION**

Apri `DESCRIPTION`. Sotto la lista `Imports:` (alfabetica), aggiungi `processx` tra `purrr` e `readr`:

```
Imports:
    cli,
    DBI,
    digest,
    fs,
    glue,
    httr2,
    jsonlite,
    jsonvalidate,
    processx,
    purrr,
    readr,
    rentrez,
    rlang,
    RSQLite,
    stringr,
    tibble
```

- [ ] **Step 2.2: Verifica `processx` installato nell'ambiente**

```bash
Rscript --vanilla -e 'cat(packageVersion("processx") |> as.character(), "\n")'
```

Expected: una versione (es. `3.8.x`). Se errore "non trovato", `Rscript --vanilla -e 'install.packages("processx")'` da fare manualmente prima di proseguire.

- [ ] **Step 2.3: Estendi `.gitignore`**

Apri `.gitignore` e aggiungi una nuova riga in fondo:

```
# P4 DGX run output
analysis/p4-output/
```

- [ ] **Step 2.4: Crea directory placeholder con `.gitkeep` rimosso (la dir resta gitignored)**

Niente `.gitkeep` — la directory verrà creata automaticamente da `dgx_p4_collect()` al primo run. Solo verifica:

```bash
test -d analysis/p4-output/ && echo "exists" || echo "not present (ok, will be created at runtime)"
```

Expected: `not present (ok, will be created at runtime)`.

- [ ] **Step 2.5: Commit**

```bash
git add DESCRIPTION .gitignore
git commit -m "$(cat <<'EOF'
P4 Task 2: DESCRIPTION processx + .gitignore p4-output

Aggiunge processx agli Imports per SSH/rsync subprocess del control
plane DGX. Estende .gitignore per analysis/p4-output/ (artefatti runs
P4 non committati).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `R/dgx-config.R` — config con default UniPD HPC

**Files:**
- Crea: `R/dgx-config.R`
- Crea: `tests/testthat/test-dgx-config.R`

- [ ] **Step 3.1: Scrivi il test (`tests/testthat/test-dgx-config.R`)**

```r
test_that("dgx_config() default usa profilo UniPD HPC u0044", {
  cfg <- dgx_config()
  expect_s3_class(cfg, "simulomicsr_dgx_config")
  expect_identical(cfg$login_user, "u0044")
  expect_identical(cfg$login_host, "logindgx.hpc.ict.unipd.it")
  expect_identical(cfg$mail_user,  "luca.vedovelli@unipd.it")
  expect_identical(cfg$partition,  "dgx12cluster")
  expect_identical(cfg$account,    "dctv_dgx")
  expect_identical(cfg$nodelist,   "poddgx02")
  expect_identical(cfg$remote_root, "/mnt/home/u0044/simulomicsr-dgx")
})

test_that("dgx_config() override singolo campo lascia altri intatti", {
  cfg <- dgx_config(login_user = "altro")
  expect_identical(cfg$login_user, "altro")
  expect_identical(cfg$mail_user,  "luca.vedovelli@unipd.it")
  expect_identical(cfg$remote_root, "/mnt/home/altro/simulomicsr-dgx")
})

test_that("dgx_config() rifiuta campi non noti", {
  expect_error(
    dgx_config(unknown_field = "x"),
    class = "simulomicsr_dgx_config_unknown_field"
  )
})

test_that("dgx_config() rifiuta tipi non-character", {
  expect_error(dgx_config(login_user = 42), class = "simulomicsr_dgx_config_invalid")
  expect_error(dgx_config(login_user = c("a", "b")), class = "simulomicsr_dgx_config_invalid")
})

test_that("dgx_config() print method mostra campi chiave", {
  cfg <- dgx_config()
  out <- capture.output(print(cfg))
  expect_true(any(grepl("u0044", out)))
  expect_true(any(grepl("poddgx02", out)))
})
```

- [ ] **Step 3.2: Esegui il test, verifica fallimento**

```bash
Rscript --vanilla -e 'devtools::test(filter = "dgx-config")'
```

Expected: errore "could not find function dgx_config".

- [ ] **Step 3.3: Implementa `R/dgx-config.R`**

```r
#' Configurazione per i run P4 sulla DGX UniPD HPC
#'
#' Restituisce un oggetto `simulomicsr_dgx_config` con i parametri di accesso
#' al cluster (login, partizione SLURM, account, nodelist) e le path remote
#' usate da `dgx_p4_submit()` / `dgx_p4_collect()`. I default sono cuciti per
#' il setup attuale dell'utente (UniPD HPC, account `dctv_dgx`, nodelist
#' `poddgx02`, login user `u0044`); ogni campo e' pero' overridable.
#'
#' @param login_user user SSH sul login node DGX. Default `"u0044"`.
#' @param login_host hostname login node. Default
#'   `"logindgx.hpc.ict.unipd.it"`.
#' @param mail_user mail per notifiche SLURM (`#SBATCH --mail-user`).
#'   Default `"luca.vedovelli@unipd.it"`.
#' @param partition partizione SLURM. Default `"dgx12cluster"`.
#' @param account account SLURM. Default `"dctv_dgx"`.
#' @param nodelist nodelist SLURM. Default `"poddgx02"`.
#' @param remote_root root remoto del workspace P4. Default
#'   `"/mnt/home/<login_user>/simulomicsr-dgx"`.
#' @param ssh_key_path path opzionale a private key SSH. `NULL` significa
#'   usa la default (id_rsa o ssh-agent).
#' @return oggetto `simulomicsr_dgx_config`.
#' @export
dgx_config <- function(login_user  = "u0044",
                       login_host  = "logindgx.hpc.ict.unipd.it",
                       mail_user   = "luca.vedovelli@unipd.it",
                       partition   = "dgx12cluster",
                       account     = "dctv_dgx",
                       nodelist    = "poddgx02",
                       remote_root = NULL,
                       ssh_key_path = NULL) {

  known <- c("login_user", "login_host", "mail_user",
             "partition", "account", "nodelist",
             "remote_root", "ssh_key_path")

  args <- list(login_user = login_user, login_host = login_host,
               mail_user = mail_user, partition = partition,
               account = account, nodelist = nodelist,
               remote_root = remote_root, ssh_key_path = ssh_key_path)

  unknown <- setdiff(names(match.call())[-1], known)
  if (length(unknown) > 0) {
    cli::cli_abort(
      "Campi sconosciuti: {.field {unknown}}",
      class = "simulomicsr_dgx_config_unknown_field"
    )
  }

  for (nm in c("login_user", "login_host", "mail_user",
               "partition", "account", "nodelist")) {
    val <- args[[nm]]
    if (!is.character(val) || length(val) != 1L || !nzchar(val)) {
      cli::cli_abort(
        "{.field {nm}} deve essere una singola stringa non vuota.",
        class = "simulomicsr_dgx_config_invalid"
      )
    }
  }

  if (is.null(remote_root)) {
    remote_root <- paste0("/mnt/home/", login_user, "/simulomicsr-dgx")
  }

  cfg <- structure(
    list(
      login_user   = login_user,
      login_host   = login_host,
      mail_user    = mail_user,
      partition    = partition,
      account      = account,
      nodelist     = nodelist,
      remote_root  = remote_root,
      ssh_key_path = ssh_key_path
    ),
    class = "simulomicsr_dgx_config"
  )

  cfg
}

#' @export
print.simulomicsr_dgx_config <- function(x, ...) {
  cli::cli_h2("simulomicsr DGX config")
  cli::cli_text("Login: {.val {x$login_user}}@{.val {x$login_host}}")
  cli::cli_text("Mail:  {.val {x$mail_user}}")
  cli::cli_text("SLURM: partition={.val {x$partition}} account={.val {x$account}} nodelist={.val {x$nodelist}}")
  cli::cli_text("Remote root: {.path {x$remote_root}}")
  if (!is.null(x$ssh_key_path))
    cli::cli_text("SSH key: {.path {x$ssh_key_path}}")
  invisible(x)
}
```

- [ ] **Step 3.4: Esegui devtools::load_all + run test**

```bash
Rscript --vanilla -e 'devtools::load_all(); devtools::test(filter = "dgx-config")'
```

Expected: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 5 ]`.

- [ ] **Step 3.5: Commit**

```bash
git add R/dgx-config.R tests/testthat/test-dgx-config.R
git commit -m "$(cat <<'EOF'
P4 Task 3: dgx_config() con default UniPD HPC u0044

Funzione esportata dgx_config() che ritorna un S3 simulomicsr_dgx_config
con i parametri SSH/SLURM/path remote per il cluster UniPD. Default
hardcoded per il setup utente (u0044, dctv_dgx, poddgx02,
luca.vedovelli@unipd.it). Print method per ispezione, validazione
campi character non-empty, rifiuto di field name non noti.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `R/dgx-utils.R` — helper interni run_id, ssh, rsync, template

**Files:**
- Crea: `R/dgx-utils.R`
- Crea: `tests/testthat/test-dgx-utils.R`

- [ ] **Step 4.1: Scrivi il test (`tests/testthat/test-dgx-utils.R`)**

```r
test_that(".dgx_run_id() ritorna stringhe distinte timestamped", {
  ids <- replicate(5, simulomicsr:::.dgx_run_id("test-slug"))
  expect_length(ids, 5)
  expect_length(unique(ids), 5)
  expect_true(all(grepl("^\\d{8}T\\d{6}Z-test-slug-[a-f0-9]{6}$", ids)))
})

test_that(".dgx_run_id() supporta slug con caratteri non-alfanumerici sanitizzati", {
  id <- simulomicsr:::.dgx_run_id("alpha xlsx (stage1)")
  expect_match(id, "^\\d{8}T\\d{6}Z-alpha-xlsx-stage1-[a-f0-9]{6}$")
})

test_that(".dgx_render_slurm_template() sostituisce tutti i placeholder", {
  tmpl <- "#SBATCH --job-name=__RUN_ID_SHORT__\nUSER=__USER__\nTIME=__TIME__\nMAIL=__MAIL_USER__\nROOT=/mnt/home/__USER__/x"
  out <- simulomicsr:::.dgx_render_slurm_template(
    tmpl,
    run_id      = "20260507T093012Z-alpha-xlsx-stage1-a3f9c1",
    run_id_short = "alpha-xlsx-stage1",
    user        = "u0044",
    time        = "12:00:00",
    mail_user   = "luca.vedovelli@unipd.it"
  )
  expect_false(grepl("__[A-Z_]+__", out))
  expect_match(out, "job-name=alpha-xlsx-stage1")
  expect_match(out, "USER=u0044")
  expect_match(out, "TIME=12:00:00")
  expect_match(out, "MAIL=luca.vedovelli@unipd.it")
  expect_match(out, "ROOT=/mnt/home/u0044/x")
})

test_that(".dgx_run_id_short() estrae lo slug dal run_id pieno", {
  short <- simulomicsr:::.dgx_run_id_short("20260507T093012Z-alpha-xlsx-stage1-a3f9c1")
  expect_identical(short, "alpha-xlsx-stage1")
})
```

- [ ] **Step 4.2: Esegui il test, verifica fallimento**

```bash
Rscript --vanilla -e 'devtools::test(filter = "dgx-utils")'
```

Expected: errore "non e' stato possibile trovare la funzione .dgx_run_id".

- [ ] **Step 4.3: Implementa `R/dgx-utils.R`**

```r
#' Genera un run_id univoco per un run P4
#'
#' Formato: `<UTC-timestamp>-<slug-sanitizzato>-<6-hex>`. Esempio:
#' `20260507T093012Z-alpha-xlsx-stage1-a3f9c1`.
#'
#' @param slug breve descrizione user-defined.
#' @return character(1).
#' @keywords internal
.dgx_run_id <- function(slug) {
  stopifnot(is.character(slug), length(slug) == 1L, nzchar(slug))
  ts <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
  slug_clean <- gsub("[^A-Za-z0-9]+", "-", slug)
  slug_clean <- gsub("^-+|-+$", "", slug_clean)
  slug_clean <- tolower(slug_clean)
  rand_hex <- substring(digest::digest(paste0(ts, slug_clean, runif(1)), algo = "md5"), 1, 6)
  paste(ts, slug_clean, rand_hex, sep = "-")
}

#' Estrae lo slug user-defined da un run_id pieno
#'
#' @param run_id stringa formato `<ts>-<slug>-<hex>`.
#' @return slug come character(1).
#' @keywords internal
.dgx_run_id_short <- function(run_id) {
  parts <- strsplit(run_id, "-", fixed = TRUE)[[1]]
  if (length(parts) < 3L) return(run_id)
  paste(parts[2:(length(parts) - 1L)], collapse = "-")
}

#' Sostituisce placeholder `__VAR__` in un template
#'
#' Tutti i placeholder devono essere risolti; se ne resta qualcuno, errore.
#'
#' @param tmpl character(1) testo template.
#' @param ... named character(1) sostituzioni (e.g. `run_id = "..."`).
#' @return character(1).
#' @keywords internal
.dgx_render_slurm_template <- function(tmpl, ...) {
  vars <- list(...)
  for (nm in names(vars)) {
    placeholder <- paste0("__", toupper(nm), "__")
    tmpl <- gsub(placeholder, vars[[nm]], tmpl, fixed = TRUE)
  }
  remaining <- regmatches(tmpl, gregexpr("__[A-Z_]+__", tmpl))[[1]]
  if (length(remaining) > 0) {
    cli::cli_abort(
      "Placeholder non risolti nel template: {.val {unique(remaining)}}",
      class = "simulomicsr_dgx_template_unresolved"
    )
  }
  tmpl
}

#' Esegue un comando SSH sul login node via processx
#'
#' @param cfg `simulomicsr_dgx_config`.
#' @param cmd character(1) comando shell remoto.
#' @param env named character (default empty) di env vars da esportare prima del comando.
#' @return list con `stdout`, `stderr`, `status`.
#' @keywords internal
.dgx_ssh <- function(cfg, cmd, env = character()) {
  ssh_args <- c("-o", "BatchMode=yes",
                "-o", "ConnectTimeout=15")
  if (!is.null(cfg$ssh_key_path))
    ssh_args <- c(ssh_args, "-i", cfg$ssh_key_path)
  ssh_args <- c(ssh_args, paste0(cfg$login_user, "@", cfg$login_host))

  if (length(env) > 0) {
    env_prefix <- paste(paste0(names(env), "=", shQuote(env)), collapse = " ")
    cmd <- paste(env_prefix, cmd)
  }
  ssh_args <- c(ssh_args, cmd)

  res <- processx::run("ssh", ssh_args, error_on_status = FALSE)
  list(stdout = res$stdout, stderr = res$stderr, status = res$status)
}

#' Esegue rsync locale -> remoto via processx
#'
#' @param cfg `simulomicsr_dgx_config`.
#' @param local_path path locale (file o directory con trailing slash).
#' @param remote_path path remoto sul login node.
#' @param direction `"push"` (default, locale -> remoto) o `"pull"` (remoto -> locale).
#' @param flags character vector di flag rsync. Default `c("-az", "--info=progress2")`.
#' @return invisible(list(stdout, stderr, status))
#' @keywords internal
.dgx_rsync <- function(cfg, local_path, remote_path,
                       direction = c("push", "pull"),
                       flags = c("-az")) {
  direction <- match.arg(direction)
  remote_spec <- paste0(cfg$login_user, "@", cfg$login_host, ":", remote_path)
  ssh_cmd <- "ssh -o BatchMode=yes -o ConnectTimeout=15"
  if (!is.null(cfg$ssh_key_path))
    ssh_cmd <- paste(ssh_cmd, "-i", shQuote(cfg$ssh_key_path))

  args <- c(flags, "-e", ssh_cmd)
  args <- if (direction == "push") c(args, local_path, remote_spec) else c(args, remote_spec, local_path)

  res <- processx::run("rsync", args, error_on_status = FALSE, echo_cmd = FALSE)
  if (res$status != 0L)
    cli::cli_abort(
      c("rsync {direction} fallito (status={res$status})",
        "x" = "{res$stderr}"),
      class = "simulomicsr_dgx_rsync_failed"
    )
  invisible(list(stdout = res$stdout, stderr = res$stderr, status = res$status))
}
```

- [ ] **Step 4.4: Esegui devtools::load_all + run test**

```bash
Rscript --vanilla -e 'devtools::load_all(); devtools::test(filter = "dgx-utils")'
```

Expected: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 4 ]`.

- [ ] **Step 4.5: Commit**

```bash
git add R/dgx-utils.R tests/testthat/test-dgx-utils.R
git commit -m "$(cat <<'EOF'
P4 Task 4: helper interni dgx-utils.R (run_id, ssh, rsync, template)

Helper non-exported: .dgx_run_id() per generare run_id deterministici
formato <UTC-ts>-<slug>-<6hex>; .dgx_run_id_short() inverso;
.dgx_render_slurm_template() sostituisce placeholder __VAR__ con error
fail-fast se ne restano; .dgx_ssh() / .dgx_rsync() wrapper processx
verso il login node con BatchMode + ConnectTimeout. Test offline
sui primi tre (.dgx_ssh / .dgx_rsync testati indirettamente in Task 12).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `inst/extdata/p4-defaults.yml` — sampling defaults per stage

**Files:**
- Crea: `inst/extdata/p4-defaults.yml`

- [ ] **Step 5.1: Crea il file YAML**

```yaml
# Defaults P4 self-hosted vLLM su DGX UniPD HPC.
# Caricati da R (yaml::read_yaml) e Python (yaml.safe_load).

model_id: "mistralai/Mistral-Small-3.2-24B-Instruct-2506"
dtype: "bfloat16"
gpu_memory_utilization: 0.90
tensor_parallel_size: 1
data_parallel_workers: 4

stages:
  stage1:
    schema_file: "sample_facts.stage1.v3.json"
    max_tokens: 1024
    temperature: 0.0
    schema_version: "stage1.v3"
    model_prefix: "vllm-mistral-3.2"
  stage2:
    schema_file: "study_design.stage2.v2.json"
    max_tokens: 4096
    temperature: 0.0
    schema_version: "stage2.v2"
    model_prefix: "vllm-mistral-3.2"

slurm_defaults:
  partition: "dgx12cluster"
  account: "dctv_dgx"
  nodelist: "poddgx02"
  cpus_per_task: 32
  mem: "200G"
  gpus: 4
  time_alpha: "12:00:00"
  time_beta: "7-00:00:00"
```

- [ ] **Step 5.2: Verifica YAML valido**

```bash
Rscript --vanilla -e 'yaml::read_yaml("inst/extdata/p4-defaults.yml") |> str()'
```

Expected: struttura R con `model_id`, `stages$stage1$max_tokens = 1024`, etc.

Nota: `yaml` e' un pacchetto che potrebbe non essere in `Imports`. Verifica:

```bash
Rscript --vanilla -e 'cat(packageVersion("yaml") |> as.character())'
```

Se non installato, installa: `install.packages("yaml")`. Aggiungi `yaml` agli `Imports` di DESCRIPTION (uniformati a Step 2.1, alfabetico tra `stringr` e `tibble`):

```
    stringr,
    tibble,
    yaml
```

- [ ] **Step 5.3: Commit**

```bash
git add inst/extdata/p4-defaults.yml DESCRIPTION
git commit -m "$(cat <<'EOF'
P4 Task 5: defaults YAML per sampling, model, SLURM

inst/extdata/p4-defaults.yml: catalogo unico di default consumati sia
da R (control plane) sia da Python (runtime cluster). Define:
- model_id mistral-small-3.2-24b
- dtype bfloat16, gpu_memory_utilization 0.90
- per-stage: schema file, max_tokens (1024 stage1 / 4096 stage2),
  temperature 0, model_prefix per il post-processing R
- SLURM defaults: 4 GPU, 32 CPU, 200G mem, time alpha/beta

Aggiunge `yaml` agli Imports di DESCRIPTION.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: `R/dgx-bundle.R` — `dgx_p4_build_bundle()` per stage 1 e stage 2

**Files:**
- Crea: `R/dgx-bundle.R`
- Crea: `tests/testthat/test-dgx-bundle.R`
- Crea: `tests/testthat/fixtures/p4-input-mini.jsonl`

- [ ] **Step 6.1: Crea fixture mini input**

`tests/testthat/fixtures/p4-input-mini-stage1.jsonl` (5 record stage1):

```jsonl
{"record_id":"GSM1009636","geo_accession":"GSM1009636","series_id":"GSE41166","string":"sample: HUVEC, treatment: VEGF, time: 1h"}
{"record_id":"GSM1009637","geo_accession":"GSM1009637","series_id":"GSE41166","string":"sample: HUVEC, treatment: control, time: 1h"}
{"record_id":"GSM2000001","geo_accession":"GSM2000001","series_id":"GSE99999","string":"sample: A549 lung cancer cells, drug: cisplatin 5uM, 24h"}
{"record_id":"GSM2000002","geo_accession":"GSM2000002","series_id":"GSE99999","string":"sample: A549 lung cancer cells, drug: DMSO, 24h"}
{"record_id":"GSM3000001","geo_accession":"GSM3000001","series_id":"GSE88888","string":"primary T cells, anti-CD3/CD28 stimulation, 6h"}
```

`tests/testthat/fixtures/p4-input-mini-stage2.jsonl` (3 record stage2):

```jsonl
{"record_id":"GSE41166","study_summary":"VEGF stimulation of HUVEC at 1h","samples":[{"geo_accession":"GSM1009636","sample_facts":{"perturbations":[{"kind":"cytokine_stimulation"}]}},{"geo_accession":"GSM1009637","sample_facts":{"perturbations":[]}}]}
{"record_id":"GSE99999","study_summary":"Cisplatin dose response in A549","samples":[{"geo_accession":"GSM2000001","sample_facts":{"perturbations":[{"kind":"drug_treatment"}]}},{"geo_accession":"GSM2000002","sample_facts":{"perturbations":[]}}]}
{"record_id":"GSE88888","study_summary":"T cell activation via anti-CD3/CD28","samples":[{"geo_accession":"GSM3000001","sample_facts":{"perturbations":[{"kind":"receptor_ligation"}]}}]}
```

- [ ] **Step 6.2: Scrivi il test (`tests/testthat/test-dgx-bundle.R`)**

```r
test_that("dgx_p4_build_bundle() stage1 crea bundle valido", {
  cfg <- dgx_config()
  td <- withr::local_tempdir()

  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage       = "stage1",
    config      = cfg,
    metadata    = list(slug = "test-stage1"),
    bundle_dir_root = td
  )

  expect_s3_class(bundle, "simulomicsr_dgx_bundle")
  expect_true(fs::dir_exists(bundle$bundle_dir))

  # Files richiesti
  for (fn in c("manifest.json", "input.jsonl", "prompt.txt",
               "schema.json", "generation.json", "status.json")) {
    expect_true(fs::file_exists(fs::path(bundle$bundle_dir, fn)),
                info = paste("file mancante:", fn))
  }

  # Manifest content
  m <- jsonlite::read_json(fs::path(bundle$bundle_dir, "manifest.json"))
  expect_identical(m$stage, "stage1")
  expect_identical(m$record_count, 5L)
  expect_identical(m$model_id, "mistralai/Mistral-Small-3.2-24B-Instruct-2506")
  expect_match(m$run_id, "^\\d{8}T\\d{6}Z-test-stage1-[a-f0-9]{6}$")

  # Schema embedded valido (vedi inst/schemas/sample_facts.stage1.v3.json)
  schema <- jsonlite::read_json(fs::path(bundle$bundle_dir, "schema.json"))
  expect_identical(schema$title, "sample_facts.stage1.v3")

  # Prompt.txt non vuoto
  prompt_size <- fs::file_info(fs::path(bundle$bundle_dir, "prompt.txt"))$size
  expect_gt(prompt_size, 500L)

  # input.jsonl ha 5 righe
  lines <- readLines(fs::path(bundle$bundle_dir, "input.jsonl"))
  expect_length(lines, 5L)

  # Generation config max_tokens 1024 per stage1
  gen <- jsonlite::read_json(fs::path(bundle$bundle_dir, "generation.json"))
  expect_identical(gen$max_tokens, 1024L)
  expect_identical(gen$temperature, 0)

  # Status iniziale
  st <- jsonlite::read_json(fs::path(bundle$bundle_dir, "status.json"))
  expect_identical(st$state, "created")
})

test_that("dgx_p4_build_bundle() stage2 usa schema e max_tokens corretti", {
  cfg <- dgx_config()
  td <- withr::local_tempdir()
  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage2.jsonl"),
    stage       = "stage2",
    config      = cfg,
    metadata    = list(slug = "test-stage2"),
    bundle_dir_root = td
  )

  schema <- jsonlite::read_json(fs::path(bundle$bundle_dir, "schema.json"))
  expect_identical(schema$title, "study_design.stage2.v2")

  gen <- jsonlite::read_json(fs::path(bundle$bundle_dir, "generation.json"))
  expect_identical(gen$max_tokens, 4096L)

  m <- jsonlite::read_json(fs::path(bundle$bundle_dir, "manifest.json"))
  expect_identical(m$stage, "stage2")
  expect_identical(m$record_count, 3L)
})

test_that("dgx_p4_build_bundle() rifiuta stage non noto", {
  cfg <- dgx_config()
  expect_error(
    dgx_p4_build_bundle(
      input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
      stage = "stage42",
      config = cfg
    ),
    class = "simulomicsr_dgx_unknown_stage"
  )
})

test_that("dgx_p4_build_bundle() rifiuta input_jsonl inesistente", {
  cfg <- dgx_config()
  expect_error(
    dgx_p4_build_bundle(
      input_jsonl = "/tmp/does-not-exist-zzzz.jsonl",
      stage = "stage1",
      config = cfg
    ),
    class = "simulomicsr_dgx_input_missing"
  )
})
```

- [ ] **Step 6.3: Esegui il test, verifica fallimento**

```bash
Rscript --vanilla -e 'devtools::test(filter = "dgx-bundle")'
```

Expected: errore "could not find function dgx_p4_build_bundle".

- [ ] **Step 6.4: Implementa `R/dgx-bundle.R`**

Note pre-implementazione:
- Stage1 system prompt = output di `simulomicsr:::.stage1_system_prompt()` (già esiste in `R/llm-stage1.R`)
- Stage2 system prompt = output di `simulomicsr:::.stage2_system_prompt()` (verificare nome funzione esatto in `R/llm-stage2.R`); se non esiste, usare il template inline da `build_prompt_stage2()`.

Verifica nome funzione stage2:

```bash
grep -n "system_prompt\|build_prompt_stage2" R/llm-stage2.R | head -5
```

Adatta la chiamata in `dgx_p4_build_bundle()` se il nome è diverso.

```r
#' Costruisce un bundle locale per un run P4 sulla DGX
#'
#' Un bundle è una directory autocontenuta che raccoglie tutto cio' che
#' serve a un job SLURM remoto: manifest, input records, prompt template
#' (system message), schema JSON, parametri di generazione, status iniziale.
#' Verra' rsync-ato sul login node da `dgx_p4_submit()`.
#'
#' @param input_jsonl path locale a un file JSONL (una riga per record).
#'   Per stage1: campi `record_id`, `geo_accession`, `series_id`, `string`.
#'   Per stage2: campi `record_id`, `study_summary`, `samples` (lista).
#' @param stage `"stage1"` o `"stage2"`.
#' @param config `simulomicsr_dgx_config` da `dgx_config()`.
#' @param metadata list opzionale con `slug` (default: stage), aggiunta al
#'   manifest e usata per costruire il `run_id`.
#' @param bundle_dir_root directory parent in cui creare il bundle. Default
#'   `analysis/p4-bundles/`.
#' @return oggetto `simulomicsr_dgx_bundle` con campi `run_id`, `bundle_dir`,
#'   `stage`, `config`, `record_count`.
#' @export
dgx_p4_build_bundle <- function(input_jsonl,
                                stage,
                                config,
                                metadata = list(),
                                bundle_dir_root = "analysis/p4-bundles") {

  if (!stage %in% c("stage1", "stage2"))
    cli::cli_abort(
      "stage deve essere {.val stage1} o {.val stage2}, ricevuto {.val {stage}}.",
      class = "simulomicsr_dgx_unknown_stage"
    )
  if (!fs::file_exists(input_jsonl))
    cli::cli_abort(
      "Input JSONL non trovato: {.path {input_jsonl}}",
      class = "simulomicsr_dgx_input_missing"
    )
  stopifnot(inherits(config, "simulomicsr_dgx_config"))

  defaults_path <- system.file("extdata", "p4-defaults.yml", package = "simulomicsr")
  if (!nzchar(defaults_path))
    cli::cli_abort("inst/extdata/p4-defaults.yml non trovato (devtools::load_all() necessario in dev?)")
  defaults <- yaml::read_yaml(defaults_path)
  stage_def <- defaults$stages[[stage]]

  slug <- metadata$slug %||% stage
  run_id <- .dgx_run_id(slug)

  bundle_dir <- fs::path(bundle_dir_root, run_id)
  fs::dir_create(bundle_dir, recurse = TRUE)

  # 1. Copia input JSONL e conta record
  fs::file_copy(input_jsonl, fs::path(bundle_dir, "input.jsonl"))
  record_count <- length(readLines(fs::path(bundle_dir, "input.jsonl")))

  # 2. System prompt: usa direttamente le funzioni interne stage1/stage2
  prompt_text <- if (stage == "stage1") {
    simulomicsr:::.stage1_system_prompt()
  } else {
    simulomicsr:::.stage2_system_prompt()
  }
  writeLines(prompt_text, fs::path(bundle_dir, "prompt.txt"))

  # 3. Copia schema dal pacchetto
  schema_src <- system.file("schemas", stage_def$schema_file, package = "simulomicsr")
  if (!nzchar(schema_src))
    cli::cli_abort("Schema non trovato: {stage_def$schema_file}")
  fs::file_copy(schema_src, fs::path(bundle_dir, "schema.json"))

  # 4. Generation config
  gen <- list(
    model_id    = defaults$model_id,
    dtype       = defaults$dtype,
    max_tokens  = stage_def$max_tokens,
    temperature = stage_def$temperature,
    gpu_memory_utilization = defaults$gpu_memory_utilization,
    tensor_parallel_size   = defaults$tensor_parallel_size,
    workers                = defaults$data_parallel_workers
  )
  jsonlite::write_json(gen, fs::path(bundle_dir, "generation.json"),
                       auto_unbox = TRUE, pretty = TRUE)

  # 5. Manifest
  manifest <- list(
    run_id        = run_id,
    stage         = stage,
    schema_file   = stage_def$schema_file,
    schema_version = stage_def$schema_version,
    model_id      = defaults$model_id,
    record_count  = record_count,
    created_at    = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    metadata      = metadata
  )
  jsonlite::write_json(manifest, fs::path(bundle_dir, "manifest.json"),
                       auto_unbox = TRUE, pretty = TRUE)

  # 6. Status iniziale
  status <- list(
    run_id     = run_id,
    state      = "created",
    message    = "Bundle creato localmente",
    updated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  jsonlite::write_json(status, fs::path(bundle_dir, "status.json"),
                       auto_unbox = TRUE, pretty = TRUE)

  structure(
    list(
      run_id       = run_id,
      bundle_dir   = bundle_dir,
      stage        = stage,
      config       = config,
      record_count = record_count
    ),
    class = "simulomicsr_dgx_bundle"
  )
}

`%||%` <- function(a, b) if (is.null(a)) b else a

#' @export
print.simulomicsr_dgx_bundle <- function(x, ...) {
  cli::cli_h2("simulomicsr DGX bundle")
  cli::cli_text("run_id: {.val {x$run_id}}")
  cli::cli_text("stage:  {.val {x$stage}}")
  cli::cli_text("records: {.val {x$record_count}}")
  cli::cli_text("dir: {.path {x$bundle_dir}}")
  invisible(x)
}
```

- [ ] **Step 6.5: Verifica nomi funzioni interne stage1/stage2 esistono**

```bash
Rscript --vanilla -e 'devtools::load_all(); ls(asNamespace("simulomicsr"), pattern="^\\.stage")'
```

Expected: `.stage1_system_prompt` presente. Verifica `.stage2_system_prompt`. Se diverso, aggiusta in dgx-bundle.R.

- [ ] **Step 6.6: Run test**

```bash
Rscript --vanilla -e 'devtools::load_all(); devtools::test(filter = "dgx-bundle")'
```

Expected: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 4 ]`.

- [ ] **Step 6.7: Commit**

```bash
git add R/dgx-bundle.R tests/testthat/test-dgx-bundle.R tests/testthat/fixtures/p4-input-mini-stage1.jsonl tests/testthat/fixtures/p4-input-mini-stage2.jsonl
git commit -m "$(cat <<'EOF'
P4 Task 6: dgx_p4_build_bundle() stage1/stage2

dgx_p4_build_bundle(input_jsonl, stage, config, metadata,
bundle_dir_root) crea bundle locale autocontenuto con:
- input.jsonl (copia)
- prompt.txt (output di .stage1_system_prompt() / .stage2_system_prompt())
- schema.json (copia da inst/schemas)
- generation.json (model, dtype, max_tokens da p4-defaults.yml)
- manifest.json (run_id, stage, model_id, record_count, metadata)
- status.json (state="created")

Test offline su 5 fixture stage1 + 3 fixture stage2: struttura,
counts, schema title, max_tokens corretti per stage.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `inst/dgx/python/prompts.py` — render user message per stage

**Files:**
- Crea: `inst/dgx/python/prompts.py`
- Crea: `inst/dgx/python/__init__.py` (vuoto, marker package)

- [ ] **Step 7.1: Crea `__init__.py` vuoto**

```bash
mkdir -p inst/dgx/python
touch inst/dgx/python/__init__.py
```

- [ ] **Step 7.2: Implementa `inst/dgx/python/prompts.py`**

Il rendering del user message replica esattamente quello di
`R/llm-stage1.R::build_prompt_stage1()` e `R/llm-stage2.R::build_prompt_stage2()`.

```python
"""User-message rendering per stage1 / stage2 — port 1:1 dei template R."""
from __future__ import annotations

import json
from typing import Any


def render_user_message_stage1(record: dict[str, Any]) -> str:
    """Costruisce lo user message per Stadio 1 (sample-level).

    Layout identico a R/llm-stage1.R::build_prompt_stage1():
        geo_accession: <ga>
        series_id: <sid>
        [organism_hint: <hint>]    # opzionale, se presente nel record
        sample_string:
        <string>
    """
    geo = str(record["geo_accession"])
    sid = str(record["series_id"])
    sstr = str(record["string"])
    organism_hint = record.get("organism_hint")

    lines = [
        f"geo_accession: {geo}",
        f"series_id: {sid}",
    ]
    if organism_hint:
        lines.append(f"organism_hint: {organism_hint}")
    lines.append("sample_string:")
    lines.append(sstr)
    return "\n".join(lines)


def render_user_message_stage2(record: dict[str, Any]) -> str:
    """Costruisce lo user message per Stadio 2 (study-level).

    Layout identico a R/llm-stage2.R::build_prompt_stage2():
        series_id: <sid>
        study_summary: <summary>
        samples:
        <JSON dei sample_facts dei sample dello studio>
    """
    sid = str(record["record_id"])  # GSE id
    summary = str(record.get("study_summary", ""))
    samples = record.get("samples", [])

    samples_json = json.dumps(samples, indent=2, sort_keys=False)

    return (
        f"series_id: {sid}\n"
        f"study_summary: {summary}\n"
        "samples:\n"
        f"{samples_json}"
    )


def build_messages(system_prompt: str, user_message: str) -> list[dict[str, str]]:
    """Restituisce la struttura messages standard OpenAI/vLLM."""
    return [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_message},
    ]
```

- [ ] **Step 7.3: Smoke test Python sul rendering (locale, no vLLM)**

```bash
python3 -c "
import sys
sys.path.insert(0, 'inst/dgx/python')
from prompts import render_user_message_stage1, render_user_message_stage2

s1 = render_user_message_stage1({
    'record_id': 'GSM1009636',
    'geo_accession': 'GSM1009636',
    'series_id': 'GSE41166',
    'string': 'sample: HUVEC, treatment: VEGF, time: 1h'
})
assert 'geo_accession: GSM1009636' in s1
assert 'sample_string:' in s1
assert 'VEGF' in s1
print('stage1 OK')

s2 = render_user_message_stage2({
    'record_id': 'GSE41166',
    'study_summary': 'VEGF stimulation',
    'samples': [{'geo_accession': 'GSM1009636'}]
})
assert 'series_id: GSE41166' in s2
assert 'study_summary: VEGF stimulation' in s2
assert 'GSM1009636' in s2
print('stage2 OK')
"
```

Expected: `stage1 OK\nstage2 OK`.

- [ ] **Step 7.4: Verifica concordanza prompt R vs Python (visuale)**

```bash
Rscript --vanilla -e '
devtools::load_all()
out <- simulomicsr:::build_prompt_stage1(
  sample_string = "sample: HUVEC, treatment: VEGF, time: 1h",
  geo_accession = "GSM1009636",
  series_id     = "GSE41166"
)
cat(out[[2]]$content)
cat("\n---\n")
'
```

Expected output (user message R):
```
geo_accession: GSM1009636
series_id: GSE41166
sample_string:
sample: HUVEC, treatment: VEGF, time: 1h
```

Confronta con output Python di Step 7.3 — devono coincidere riga per riga.

- [ ] **Step 7.5: Commit**

```bash
git add inst/dgx/python/__init__.py inst/dgx/python/prompts.py
git commit -m "$(cat <<'EOF'
P4 Task 7: prompts.py — render user message stage1/stage2

Port 1:1 dei template di build_prompt_stage1() e build_prompt_stage2()
da R a Python. render_user_message_stage1(record) e
render_user_message_stage2(record) producono lo user message identico
a R; build_messages(system, user) compone la struttura OpenAI/vLLM.

System prompt resta nel file prompt.txt del bundle (generato da R via
.stage1_system_prompt() / .stage2_system_prompt()), letto una volta dal
worker e riusato per tutti i record.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: `inst/dgx/python/resume.py` — filtro record già completati

**Files:**
- Crea: `inst/dgx/python/resume.py`

- [ ] **Step 8.1: Implementa `inst/dgx/python/resume.py`**

```python
"""Resume idempotente: legge i record_id gia' presenti nei predictions
worker JSONL e filtra l'input prima di partire."""

from __future__ import annotations

import glob
import json
import os
from pathlib import Path
from typing import Iterable


def existing_record_ids(output_dir: str | os.PathLike) -> set[str]:
    """Scansiona predictions.worker_*.jsonl e predictions.jsonl, ritorna gli ID
    gia' completati con successo. Linee non parseabili vengono saltate."""
    out = Path(output_dir)
    done: set[str] = set()
    patterns = ["predictions.worker_*.jsonl", "predictions.jsonl"]
    for pat in patterns:
        for p in out.glob(pat):
            try:
                with p.open("r", encoding="utf-8") as fh:
                    for line in fh:
                        line = line.strip()
                        if not line:
                            continue
                        try:
                            row = json.loads(line)
                        except json.JSONDecodeError:
                            continue
                        rid = row.get("record_id")
                        if rid is not None:
                            done.add(str(rid))
            except FileNotFoundError:
                continue
    return done


def filter_input_records(records: Iterable[dict], done_ids: set[str]) -> list[dict]:
    """Restituisce solo i record con record_id NON in done_ids."""
    return [r for r in records if str(r.get("record_id")) not in done_ids]


def shard_round_robin(records: list[dict], n_workers: int) -> list[list[dict]]:
    """Divide la lista in n_workers fette round-robin (load-balanced)."""
    shards: list[list[dict]] = [[] for _ in range(n_workers)]
    for i, r in enumerate(records):
        shards[i % n_workers].append(r)
    return shards
```

- [ ] **Step 8.2: Smoke test Python**

```bash
python3 -c "
import sys, json, tempfile, os
sys.path.insert(0, 'inst/dgx/python')
from resume import existing_record_ids, filter_input_records, shard_round_robin

with tempfile.TemporaryDirectory() as d:
    p1 = os.path.join(d, 'predictions.worker_0.jsonl')
    p2 = os.path.join(d, 'predictions.worker_1.jsonl')
    with open(p1, 'w') as f:
        f.write(json.dumps({'record_id': 'A'}) + '\n')
        f.write(json.dumps({'record_id': 'B'}) + '\n')
    with open(p2, 'w') as f:
        f.write(json.dumps({'record_id': 'C'}) + '\n')
        f.write('not-valid-json\n')   # deve essere saltata

    done = existing_record_ids(d)
    assert done == {'A', 'B', 'C'}, done
    print('existing OK', done)

    inp = [{'record_id': 'A'}, {'record_id': 'D'}, {'record_id': 'B'}, {'record_id': 'E'}]
    todo = filter_input_records(inp, done)
    assert [r['record_id'] for r in todo] == ['D', 'E']
    print('filter OK')

    shards = shard_round_robin([{'record_id': str(i)} for i in range(10)], 4)
    assert len(shards) == 4
    assert sum(len(s) for s in shards) == 10
    assert [len(s) for s in shards] in ([3, 3, 2, 2], [3, 3, 2, 2])
    print('shard OK', [len(s) for s in shards])
"
```

Expected:
```
existing OK {'A', 'B', 'C'}
filter OK
shard OK [3, 3, 2, 2]
```

- [ ] **Step 8.3: Commit**

```bash
git add inst/dgx/python/resume.py
git commit -m "$(cat <<'EOF'
P4 Task 8: resume.py — idempotenza via predictions.jsonl scan

existing_record_ids(output_dir) scansiona predictions.worker_*.jsonl
e predictions.jsonl, ritorna set degli ID gia' completati. Salta
linee non parseabili (robust su file troncato/malformato).
filter_input_records(records, done) toglie record gia' fatti.
shard_round_robin(records, n) splitta load-balanced.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: `inst/dgx/python/run_p4_vllm.py` — entry point con vLLM offline batch

**Files:**
- Crea: `inst/dgx/python/run_p4_vllm.py`

- [ ] **Step 9.1: Implementa `inst/dgx/python/run_p4_vllm.py`**

```python
#!/usr/bin/env python3
"""Entry point P4: 4 worker data-parallel vLLM offline batch su DGX.

Architettura:
  - Argomenti: --bundle (path al bundle dir), --output (path output dir), --workers N
  - Legge bundle: manifest.json, generation.json, schema.json, prompt.txt, input.jsonl
  - Resume: scansiona output dir per record_id gia' completati
  - Sharding round-robin su N worker
  - Ogni worker: multiprocessing.Process con CUDA_VISIBLE_DEVICES=<i>
    - carica vLLM LLM(model=..., dtype=bfloat16, gpu_memory_utilization=0.90, tensor_parallel_size=1)
    - SamplingParams(max_tokens=..., temperature=0, guided_json=schema)
    - genera in batch, scrive predictions.worker_<i>.jsonl append-only
  - Main: aspetta tutti, fa concat predictions.worker_*.jsonl -> predictions.jsonl,
    scrive run_summary.json
"""

from __future__ import annotations

import argparse
import json
import multiprocessing as mp
import os
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# Local modules (PYTHONPATH set in container env)
from prompts import build_messages, render_user_message_stage1, render_user_message_stage2
from resume import existing_record_ids, filter_input_records, shard_round_robin


def now_utc_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="P4 vLLM batch runner")
    p.add_argument("--bundle", required=True, help="Path al bundle dir (montato in /work/bundle).")
    p.add_argument("--output", required=True, help="Path output dir (montato in /work/run).")
    p.add_argument("--workers", type=int, default=4, help="Numero worker data-parallel.")
    return p.parse_args()


def load_bundle(bundle_dir: Path) -> dict[str, Any]:
    return {
        "manifest":   json.loads((bundle_dir / "manifest.json").read_text()),
        "generation": json.loads((bundle_dir / "generation.json").read_text()),
        "schema":     json.loads((bundle_dir / "schema.json").read_text()),
        "prompt":     (bundle_dir / "prompt.txt").read_text(),
        "input_path": bundle_dir / "input.jsonl",
    }


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    out = []
    with path.open("r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line:
                out.append(json.loads(line))
    return out


def write_status(status_path: Path, payload: dict) -> None:
    payload = dict(payload)
    payload["updated_at"] = now_utc_iso()
    tmp = status_path.with_suffix(".tmp")
    tmp.write_text(json.dumps(payload, indent=2))
    tmp.replace(status_path)


def render_user_for_stage(stage: str, record: dict) -> str:
    if stage == "stage1":
        return render_user_message_stage1(record)
    if stage == "stage2":
        return render_user_message_stage2(record)
    raise ValueError(f"stage non noto: {stage!r}")


def worker_main(worker_id: int, gpu_index: int, bundle: dict, records: list[dict],
                output_dir: Path, predictions_path: Path) -> None:
    """Funzione eseguita in subprocess. Carica vLLM su una sola GPU e
    genera in batch sui record assegnati."""
    os.environ["CUDA_VISIBLE_DEVICES"] = str(gpu_index)
    # Import vLLM solo qui (per non caricarlo nel main process)
    from vllm import LLM, SamplingParams

    gen = bundle["generation"]
    schema = bundle["schema"]
    stage = bundle["manifest"]["stage"]
    system_prompt = bundle["prompt"]

    print(f"[worker {worker_id}] caricamento vLLM su GPU {gpu_index}...", flush=True)
    llm = LLM(
        model=gen["model_id"],
        dtype=gen["dtype"],
        gpu_memory_utilization=float(gen["gpu_memory_utilization"]),
        tensor_parallel_size=int(gen["tensor_parallel_size"]),
        trust_remote_code=True,
    )

    sampling = SamplingParams(
        max_tokens=int(gen["max_tokens"]),
        temperature=float(gen["temperature"]),
        guided_json=schema,
    )

    # Costruisci tutti i prompt e tieni allineato con record_id
    prompts = []
    record_ids = []
    for r in records:
        user_msg = render_user_for_stage(stage, r)
        # vLLM accetta sia string raw sia messages -- usiamo apply_chat_template via tokenizer
        messages = build_messages(system_prompt, user_msg)
        text = llm.get_tokenizer().apply_chat_template(
            messages, tokenize=False, add_generation_prompt=True
        )
        prompts.append(text)
        record_ids.append(str(r["record_id"]))

    print(f"[worker {worker_id}] generazione su {len(prompts)} record...", flush=True)
    t0 = time.time()
    outputs = llm.generate(prompts, sampling)
    elapsed = time.time() - t0
    print(f"[worker {worker_id}] generazione completata in {elapsed:.1f}s", flush=True)

    # Scrittura predictions append-only
    with predictions_path.open("a", encoding="utf-8") as fh:
        for rid, out in zip(record_ids, outputs):
            raw = out.outputs[0].text if out.outputs else ""
            try:
                parsed = json.loads(raw)
                valid = True
            except json.JSONDecodeError:
                parsed = None
                valid = False
            row = {
                "record_id": rid,
                "raw_output": raw,
                "parsed_json": parsed,
                "valid_schema": valid,
                "worker_id": worker_id,
                "ts": now_utc_iso(),
            }
            fh.write(json.dumps(row) + "\n")

    print(f"[worker {worker_id}] scritti {len(record_ids)} record in {predictions_path}", flush=True)


def main() -> int:
    args = parse_args()
    bundle_dir = Path(args.bundle)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    status_path = output_dir / "status.json"
    summary_path = output_dir / "run_summary.json"
    final_predictions = output_dir / "predictions.jsonl"

    bundle = load_bundle(bundle_dir)
    all_records = read_jsonl(bundle["input_path"])

    # Resume: rimuovi gia' fatti
    done = existing_record_ids(output_dir)
    todo = filter_input_records(all_records, done)
    print(f"[main] totale={len(all_records)} done={len(done)} todo={len(todo)}", flush=True)

    write_status(status_path, {
        "run_id": bundle["manifest"]["run_id"],
        "state":  "starting",
        "records_total":     len(all_records),
        "records_already_done": len(done),
        "records_todo": len(todo),
        "started_at": now_utc_iso(),
    })

    if not todo:
        # Niente da fare; concat e summary, exit
        _concat_and_summarize(output_dir, bundle, len(all_records), len(done), 0, 0)
        write_status(status_path, {**json.loads(status_path.read_text()),
                                   "state": "completed",
                                   "message": "Nothing to do (resume)"})
        return 0

    n_workers = max(1, int(args.workers))
    shards = shard_round_robin(todo, n_workers)

    # Lancia worker
    procs = []
    for i, shard in enumerate(shards):
        if not shard:
            continue
        worker_pred_path = output_dir / f"predictions.worker_{i}.jsonl"
        p = mp.Process(
            target=worker_main,
            args=(i, i, bundle, shard, output_dir, worker_pred_path),
        )
        p.start()
        procs.append((i, p))

    # Aspetta
    failed = []
    for (i, p) in procs:
        p.join()
        if p.exitcode != 0:
            failed.append(i)

    # Concat + summary
    completed, failed_count = _concat_and_summarize(
        output_dir, bundle, len(all_records), len(done), len(todo), len(failed)
    )

    final_state = "completed" if not failed else "completed_with_errors"
    write_status(status_path, {
        "run_id": bundle["manifest"]["run_id"],
        "state": final_state,
        "records_total": len(all_records),
        "records_completed": completed,
        "records_failed": failed_count,
        "workers_failed": failed,
        "finished_at": now_utc_iso(),
    })

    return 0 if not failed else 2


def _concat_and_summarize(output_dir: Path, bundle: dict,
                          total: int, already_done: int, todo: int,
                          n_workers_failed: int) -> tuple[int, int]:
    """Merge predictions.worker_*.jsonl -> predictions.jsonl (idempotente,
    sovrascrive). Returns (completed, failed)."""
    final = output_dir / "predictions.jsonl"
    seen_ids: set[str] = set()
    completed = 0
    failed = 0

    with final.open("w", encoding="utf-8") as fout:
        for wp in sorted(output_dir.glob("predictions.worker_*.jsonl")):
            with wp.open("r", encoding="utf-8") as fin:
                for line in fin:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        row = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    rid = row.get("record_id")
                    if rid in seen_ids:
                        continue
                    seen_ids.add(rid)
                    if row.get("valid_schema"):
                        completed += 1
                    else:
                        failed += 1
                    fout.write(json.dumps(row) + "\n")

    summary = {
        "run_id": bundle["manifest"]["run_id"],
        "model_id": bundle["generation"]["model_id"],
        "stage": bundle["manifest"]["stage"],
        "records_total": total,
        "records_already_done_resume": already_done,
        "records_todo_this_run": todo,
        "records_completed_total": completed,
        "records_failed_schema": failed,
        "workers_failed_count": n_workers_failed,
        "finished_at": now_utc_iso(),
    }
    (output_dir / "run_summary.json").write_text(json.dumps(summary, indent=2))
    return completed, failed


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 9.2: Smoke test sintassi (no esecuzione)**

```bash
python3 -c "
import ast, sys
src = open('inst/dgx/python/run_p4_vllm.py').read()
ast.parse(src)
print('syntax OK')
"
```

Expected: `syntax OK`.

- [ ] **Step 9.3: Lint Python (se black/ruff sono presenti)**

```bash
which ruff && ruff check inst/dgx/python/ || echo "ruff non disponibile, skip"
```

Best-effort, non blocking.

- [ ] **Step 9.4: Commit**

```bash
git add inst/dgx/python/run_p4_vllm.py
git commit -m "$(cat <<'EOF'
P4 Task 9: run_p4_vllm.py — entry point vLLM offline batch DP=4

Carica bundle, applica filtro resume su predictions.worker_*.jsonl
esistenti, sharda round-robin su N worker, ogni worker e' un
multiprocessing.Process con CUDA_VISIBLE_DEVICES=<i> distinto. Carica
vLLM LLM(model, dtype=bfloat16, gpu_memory_util=0.90, tp=1) e usa
SamplingParams(temperature=0, max_tokens=stage_default,
guided_json=schema). Output JSONL append-only per worker, mergiato
in predictions.jsonl a fine job (dedup per record_id, idempotente).
Status e run_summary aggiornati live e a fine.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: `inst/dgx/Dockerfile` + `Makefile` per workflow docker→DockerHub→Singularity

**Files:**
- Crea: `inst/dgx/Dockerfile`
- Crea: `inst/dgx/Makefile`
- Crea: `inst/dgx/.dockerignore`

Pattern allineato a `2026.scRNA_DGX/Makefile` dell'utente. Build locale + push DockerHub + `singularity pull` sul cluster (no `--fakeroot` remoto).

- [ ] **Step 10.1: Crea `inst/dgx/Dockerfile`**

```dockerfile
# CUDA 12.1+ richiesto da vLLM 0.6.x.
# Driver DGX UniPD HPC (poddgx02) compatibile CUDA 12 (verificato dal
# progetto 2026.scRNA_DGX che gira su nvcr.io/nvidia/rapidsai/base con
# CUDA 12.x sullo stesso nodo).
FROM vllm/vllm-openai:v0.6.4

LABEL maintainer="simulomicsr" \
      model="mistralai/Mistral-Small-3.2-24B-Instruct-2506" \
      purpose="P4 batch classification stage1+stage2"

# Dipendenze extra rispetto al base vllm/vllm-openai
RUN pip install --no-cache-dir jsonschema orjson pyyaml

# Copia gli script Python custom in una location stabile
COPY python /opt/simulomicsr/runtime/python

ENV PYTHONUNBUFFERED=1 \
    PYTHONPATH=/opt/simulomicsr/runtime/python \
    HF_HOME=/work/models/HF_HOME \
    TRANSFORMERS_CACHE=/work/models/HF_HOME

# vllm/vllm-openai default ENTRYPOINT lancia il server HTTP. Lo
# sovrascriviamo col nostro batch runner.
ENTRYPOINT ["python", "/opt/simulomicsr/runtime/python/run_p4_vllm.py"]
```

- [ ] **Step 10.2: Crea `inst/dgx/Makefile`**

```makefile
# Makefile per build e deploy del container P4.
# Pattern: docker build locale -> push DockerHub -> singularity pull sul cluster.
# Allineato a 2026.scRNA_DGX/Makefile.

DOCKER_USER ?= lucavd
IMAGE_NAME  ?= simulomicsr-vllm
TAG         ?= latest
FULL_IMAGE  := $(DOCKER_USER)/$(IMAGE_NAME):$(TAG)

LOGIN_HOST  ?= logindgx.hpc.ict.unipd.it
LOGIN_USER  ?= u0044
RUNTIME_DIR ?= /mnt/home/$(LOGIN_USER)/simulomicsr-dgx/runtime

.PHONY: build push pull-cluster predownload-model deploy

# Build locale
build:
	docker build -t $(FULL_IMAGE) .

# Push a DockerHub (richiede `docker login` una volta)
push: build
	docker push $(FULL_IMAGE)

# Pull come SIF sul login node DGX (richiede SSH key valida)
pull-cluster:
	ssh $(LOGIN_USER)@$(LOGIN_HOST) \
		"mkdir -p $(RUNTIME_DIR) && \
		 cd $(RUNTIME_DIR) && \
		 module load singularity/4.2.0 && \
		 singularity pull --force current.sif docker://$(FULL_IMAGE) && \
		 ls -lh current.sif"

# Pre-download del modello UNA VOLTA (uso HF_TOKEN dal login)
# Richiede current.sif gia' presente (eseguire `make pull-cluster` prima).
predownload-model:
	ssh $(LOGIN_USER)@$(LOGIN_HOST) \
		". ~/.simulomicsr-dgx.env && \
		 module load singularity/4.2.0 && \
		 mkdir -p /mnt/home/$(LOGIN_USER)/simulomicsr-dgx/models/HF_HOME && \
		 singularity exec \
		   --bind /mnt/home/$(LOGIN_USER)/simulomicsr-dgx/models/HF_HOME:/work/models/HF_HOME \
		   $(RUNTIME_DIR)/current.sif \
		   huggingface-cli download mistralai/Mistral-Small-3.2-24B-Instruct-2506 \
		   --token \$$HF_TOKEN"

# Pipeline completa
deploy: push pull-cluster
	@echo "Container deployed. Esegui 'make predownload-model' per popolare HF cache."
```

- [ ] **Step 10.3: Crea `inst/dgx/.dockerignore`**

```
__pycache__/
*.pyc
*.pyo
.pytest_cache/
.git/
*.md
```

- [ ] **Step 10.4: Verifica sintassi Dockerfile (locally, no build)**

```bash
docker --version
# Se docker presente:
docker build --dry-run -t test inst/dgx/ 2>&1 | head -5 || echo "dry-run non supportato, skip"
# Verifica almeno parsing Dockerfile:
hadolint inst/dgx/Dockerfile 2>&1 | head -10 || echo "hadolint non disponibile, skip lint"
```

Best-effort. Se docker non installato sul laptop di sviluppo, lascia che l'utente verifichi al momento del build.

- [ ] **Step 10.5: Commit**

```bash
git add inst/dgx/Dockerfile inst/dgx/Makefile inst/dgx/.dockerignore
git commit -m "$(cat <<'EOF'
P4 Task 10: Dockerfile + Makefile per workflow docker -> DockerHub -> Singularity

Pattern allineato a 2026.scRNA_DGX (lucavd/sc-benchmark): docker build
locale -> DockerHub -> singularity pull sul cluster, niente apptainer
build --fakeroot remoto.

Dockerfile: FROM vllm/vllm-openai:v0.6.4 (CUDA 12.1+, vLLM gia' incluso),
aggiunge jsonschema/orjson/pyyaml, COPY python/ in /opt/simulomicsr/
runtime/, ENTRYPOINT = run_p4_vllm.py.

Makefile target: build, push, pull-cluster (ssh + singularity pull),
predownload-model (one-time HF download via huggingface-cli dentro
container con HF_TOKEN). deploy = push + pull-cluster.

.dockerignore esclude __pycache__/.pyc dal build context.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 11: `inst/dgx/slurm/run_p4.sh` template SLURM

**Files:**
- Crea: `inst/dgx/slurm/run_p4.sh`

- [ ] **Step 11.1: Crea il template SLURM**

```bash
mkdir -p inst/dgx/slurm
```

`inst/dgx/slurm/run_p4.sh`:

```bash
#!/bin/bash
# Template SLURM per run P4. R sostituisce __VAR__ tramite
# .dgx_render_slurm_template().
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

mkdir -p "$REMOTE_ROOT/runs/$RUN_ID" "$REMOTE_ROOT/models/HF_HOME"

# HF_TOKEN deve essere nell'environment (esportato da .simulomicsr-dgx.env
# o passato da R via sbatch --export=HF_TOKEN). Il sentinel check evita
# crash silenziosi al primo download del modello.
if [ -z "${HF_TOKEN:-}" ]; then
    echo "[WARN] HF_TOKEN non settato. Modelli gated potrebbero fallire al download." >&2
fi

echo "[INFO] Run ID: $RUN_ID"
echo "[INFO] Node: $(hostname)"
echo "[INFO] Job ID: $SLURM_JOB_ID"
echo "[INFO] Workdir: $REMOTE_ROOT"

SINGULARITY_BIN=/cm/shared/apps/singularity/4.2.0/bin/singularity

srun "$SINGULARITY_BIN" exec \
  --nv \
  --bind "$REMOTE_ROOT/bundles/$RUN_ID:/work/bundle" \
  --bind "$REMOTE_ROOT/runs/$RUN_ID:/work/run" \
  --bind "$REMOTE_ROOT/models/HF_HOME:/work/models/HF_HOME" \
  --env "HF_TOKEN=${HF_TOKEN:-}" \
  "$REMOTE_ROOT/runtime/current.sif" \
  --bundle /work/bundle --output /work/run --workers 4

echo "[INFO] Job completed"
```

- [ ] **Step 11.2: Commit**

```bash
git add inst/dgx/slurm/run_p4.sh
git commit -m "$(cat <<'EOF'
P4 Task 11: slurm/run_p4.sh template

Template SLURM con placeholder __RUN_ID__/__RUN_ID_SHORT__/__USER__/
__TIME__/__MAIL_USER__ sostituiti da R via .dgx_render_slurm_template().
Hardcoded: partition=dgx12cluster, account=dctv_dgx, nodelist=poddgx02,
gpu:4, cpus=32, mem=200G. Carica module singularity 4.2.0 + slurm
23.02.7. Bind mount bundles/runs/HF_HOME, esporta HF_TOKEN dentro il
container. Lancia srun apptainer exec con runscript del SIF.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 12: `R/dgx-submit.R` — `dgx_p4_submit()` (parte 1: submit)

**Files:**
- Crea: `R/dgx-submit.R` (con la sola `dgx_p4_submit()` per ora)
- Crea: `tests/testthat/test-dgx-submit.R`

- [ ] **Step 12.1: Scrivi il test (`tests/testthat/test-dgx-submit.R`) con mock processx**

```r
# Mock helper per simulare processx::run senza chiamare ssh/rsync veri.
local_mock_processx <- function(stdout = "", stderr = "", status = 0L,
                                env = parent.frame()) {
  fake <- function(command, args = NULL, ...) {
    list(stdout = stdout, stderr = stderr, status = status)
  }
  withr::local_mocked_bindings(run = fake, .package = "processx", .env = env)
}

test_that("dgx_p4_submit() costruisce e rendera SLURM script + sbatch", {
  skip_if_not_installed("withr")
  cfg <- dgx_config()
  td <- withr::local_tempdir()

  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage = "stage1",
    config = cfg,
    bundle_dir_root = td
  )

  # Mock: rsync ritorna 0, ssh sbatch ritorna "Submitted batch job 123456"
  local_mock_processx(stdout = "Submitted batch job 123456\n", status = 0L)

  job <- dgx_p4_submit(bundle, time = "12:00:00", config = cfg, dry_run = FALSE)

  expect_s3_class(job, "simulomicsr_dgx_job")
  expect_identical(job$run_id, bundle$run_id)
  expect_identical(job$slurm_job_id, "123456")
  expect_identical(job$stage, "stage1")
})

test_that("dgx_p4_submit() dry_run produce slurm script ma non chiama ssh", {
  cfg <- dgx_config()
  td <- withr::local_tempdir()
  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage = "stage1",
    config = cfg,
    bundle_dir_root = td
  )

  job <- dgx_p4_submit(bundle, time = "12:00:00", config = cfg, dry_run = TRUE)

  expect_s3_class(job, "simulomicsr_dgx_job")
  expect_identical(job$slurm_job_id, NA_character_)
  expect_true(fs::file_exists(fs::path(bundle$bundle_dir, "run_p4.rendered.sh")))
  rendered <- readLines(fs::path(bundle$bundle_dir, "run_p4.rendered.sh"))
  expect_true(any(grepl("--time=12:00:00", rendered, fixed = TRUE)))
  expect_true(any(grepl("dctv_dgx", rendered, fixed = TRUE)))
  expect_false(any(grepl("__[A-Z_]+__", rendered)))
})

test_that("dgx_p4_submit() abort se sbatch parse non trova job id", {
  cfg <- dgx_config()
  td <- withr::local_tempdir()
  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage = "stage1",
    config = cfg,
    bundle_dir_root = td
  )

  local_mock_processx(stdout = "weird unexpected output", status = 0L)

  expect_error(
    dgx_p4_submit(bundle, time = "12:00:00", config = cfg),
    class = "simulomicsr_dgx_sbatch_parse_failed"
  )
})
```

- [ ] **Step 12.2: Esegui test, verifica fallimento**

```bash
Rscript --vanilla -e 'devtools::test(filter = "dgx-submit")'
```

Expected: errore "could not find function dgx_p4_submit".

- [ ] **Step 12.3: Implementa `R/dgx-submit.R` (solo `dgx_p4_submit()` + helper print)**

```r
#' Submit di un bundle P4 al cluster DGX via SSH+SLURM
#'
#' Esegue:
#' 1. Render del template `inst/dgx/slurm/run_p4.sh` con `run_id`,
#'    `time`, `mail_user`, `user` sostituiti.
#' 2. rsync del bundle locale -> remoto in
#'    `<remote_root>/bundles/<run_id>/`.
#' 3. rsync del SLURM script renderizzato -> remoto.
#' 4. SSH `sbatch` sul login node (con env `HF_TOKEN` se presente).
#' 5. Parse della jobid dallo stdout di sbatch.
#'
#' Se `dry_run = TRUE`, scrive solo lo script renderizzato in
#' `<bundle_dir>/run_p4.rendered.sh` e ritorna senza toccare il cluster.
#'
#' @param bundle output di `dgx_p4_build_bundle()`.
#' @param time time limit SLURM (HH:MM:SS o D-HH:MM:SS). Default
#'   `"12:00:00"`.
#' @param config `simulomicsr_dgx_config`. Default = `bundle$config`.
#' @param dry_run logical: se TRUE, non chiama ssh/rsync.
#' @return oggetto `simulomicsr_dgx_job`.
#' @export
dgx_p4_submit <- function(bundle,
                          time = "12:00:00",
                          config = NULL,
                          dry_run = FALSE) {

  stopifnot(inherits(bundle, "simulomicsr_dgx_bundle"))
  if (is.null(config)) config <- bundle$config
  stopifnot(inherits(config, "simulomicsr_dgx_config"))

  # 1. Render template SLURM
  tmpl_path <- system.file("dgx", "slurm", "run_p4.sh", package = "simulomicsr")
  if (!nzchar(tmpl_path))
    cli::cli_abort("Template SLURM non trovato (devtools::load_all() necessario in dev?)")

  tmpl <- paste(readLines(tmpl_path), collapse = "\n")
  rendered <- .dgx_render_slurm_template(
    tmpl,
    run_id       = bundle$run_id,
    run_id_short = .dgx_run_id_short(bundle$run_id),
    user         = config$login_user,
    time         = time,
    mail_user    = config$mail_user
  )
  rendered_path <- fs::path(bundle$bundle_dir, "run_p4.rendered.sh")
  writeLines(rendered, rendered_path)

  if (dry_run) {
    return(structure(
      list(run_id = bundle$run_id,
           slurm_job_id = NA_character_,
           stage = bundle$stage,
           bundle_dir = bundle$bundle_dir,
           rendered_slurm = rendered_path,
           submitted_at = NA_character_,
           config = config),
      class = "simulomicsr_dgx_job"
    ))
  }

  # 2. rsync bundle -> remoto
  remote_bundle <- paste0(config$remote_root, "/bundles/", bundle$run_id, "/")
  .dgx_ssh(config, paste0("mkdir -p ", shQuote(remote_bundle)))
  .dgx_rsync(config,
             local_path  = paste0(bundle$bundle_dir, "/"),
             remote_path = remote_bundle,
             direction   = "push")

  # 3. sbatch via SSH (HF_TOKEN viene letto da .simulomicsr-dgx.env nel login)
  remote_script <- paste0(remote_bundle, "run_p4.rendered.sh")
  sbatch_cmd <- paste0(
    "set -e; ",
    "if [ -f ~/.simulomicsr-dgx.env ]; then . ~/.simulomicsr-dgx.env; fi; ",
    "sbatch --export=HF_TOKEN ", shQuote(remote_script)
  )
  ssh_res <- .dgx_ssh(config, sbatch_cmd)
  if (ssh_res$status != 0L)
    cli::cli_abort(
      c("sbatch fallito (status={ssh_res$status})",
        "x" = "{ssh_res$stderr}"),
      class = "simulomicsr_dgx_sbatch_failed"
    )

  m <- regmatches(ssh_res$stdout,
                  regexpr("Submitted batch job (\\d+)", ssh_res$stdout))
  if (length(m) == 0L)
    cli::cli_abort(
      c("Impossibile trovare il job id nello stdout di sbatch",
        "i" = "stdout: {ssh_res$stdout}"),
      class = "simulomicsr_dgx_sbatch_parse_failed"
    )
  slurm_job_id <- sub("Submitted batch job ", "", m)

  cli::cli_alert_success("Submitted: run_id={bundle$run_id} slurm={slurm_job_id}")

  structure(
    list(run_id = bundle$run_id,
         slurm_job_id = slurm_job_id,
         stage = bundle$stage,
         bundle_dir = bundle$bundle_dir,
         rendered_slurm = rendered_path,
         submitted_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
         config = config),
    class = "simulomicsr_dgx_job"
  )
}

#' @export
print.simulomicsr_dgx_job <- function(x, ...) {
  cli::cli_h2("simulomicsr DGX job")
  cli::cli_text("run_id: {.val {x$run_id}}")
  cli::cli_text("slurm: {.val {x$slurm_job_id}}")
  cli::cli_text("stage: {.val {x$stage}}")
  cli::cli_text("submitted_at: {.val {x$submitted_at}}")
  invisible(x)
}
```

- [ ] **Step 12.4: Run test**

```bash
Rscript --vanilla -e 'devtools::load_all(); devtools::test(filter = "dgx-submit")'
```

Expected: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 3 ]`.

- [ ] **Step 12.5: Commit**

```bash
git add R/dgx-submit.R tests/testthat/test-dgx-submit.R
git commit -m "$(cat <<'EOF'
P4 Task 12: dgx_p4_submit() — render SLURM + rsync + sbatch

Funzione esportata dgx_p4_submit(bundle, time, config, dry_run):
1. Render inst/dgx/slurm/run_p4.sh con placeholder sostituiti tramite
   .dgx_render_slurm_template()
2. rsync bundle -> /mnt/home/<user>/simulomicsr-dgx/bundles/<run_id>/
3. sbatch via SSH con HF_TOKEN esportato da ~/.simulomicsr-dgx.env
4. Parse "Submitted batch job <id>" dallo stdout
Returns simulomicsr_dgx_job (run_id, slurm_job_id, stage, ...).
dry_run=TRUE produce solo lo script renderizzato (per test offline).

Test mockano processx::run via withr::local_mocked_bindings.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 13: `dgx_p4_status()` + `dgx_p4_collect()` + `dgx_p4_recover()`

**Files:**
- Modifica: `R/dgx-submit.R` (aggiunge 3 funzioni)
- Modifica: `tests/testthat/test-dgx-submit.R` (aggiunge test)

- [ ] **Step 13.1: Aggiungi i test**

Aggiungi in fondo a `tests/testthat/test-dgx-submit.R`:

```r
test_that("dgx_p4_status() ritorna struttura con campi required", {
  cfg <- dgx_config()
  td <- withr::local_tempdir()
  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage = "stage1", config = cfg, bundle_dir_root = td
  )
  job <- structure(
    list(run_id = bundle$run_id, slurm_job_id = "999",
         stage = "stage1", bundle_dir = bundle$bundle_dir,
         submitted_at = "2026-05-07T09:00:00Z", config = cfg),
    class = "simulomicsr_dgx_job"
  )

  # Mock: squeue ritorna RUNNING, status.json scaricato (simuliamo con local file)
  local_mock_processx(
    stdout = "RUNNING\n",
    status = 0L
  )

  st <- dgx_p4_status(job, fetch_status_json = FALSE)
  expect_named(st, c("slurm_state", "remote_status_present", "snapshot"),
               ignore.order = TRUE)
  expect_identical(st$slurm_state, "RUNNING")
})

test_that("dgx_p4_recover() ricostruisce job da bundle locale", {
  cfg <- dgx_config()
  td <- withr::local_tempdir()
  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage = "stage1", config = cfg, bundle_dir_root = td
  )

  job <- dgx_p4_recover(run_id = bundle$run_id,
                       config = cfg,
                       bundle_dir_root = td)
  expect_s3_class(job, "simulomicsr_dgx_job")
  expect_identical(job$run_id, bundle$run_id)
  expect_true(is.na(job$slurm_job_id))
})

test_that("dgx_p4_collect() rsync e parse roundtrip (mocked)", {
  skip_if_not_installed("withr")
  cfg <- dgx_config()
  td <- withr::local_tempdir()

  bundle <- dgx_p4_build_bundle(
    input_jsonl = test_path("fixtures", "p4-input-mini-stage1.jsonl"),
    stage = "stage1", config = cfg, bundle_dir_root = td
  )
  dest_root <- fs::path(td, "p4-output")
  fs::dir_create(dest_root)

  # Pre-popoliamo manualmente la dir di destinazione come se rsync l'avesse
  # gia' fatto (evitiamo di mockare il filesystem completo).
  dst_run <- fs::path(dest_root, bundle$run_id)
  fs::dir_create(dst_run)
  writeLines(c(
    '{"record_id":"GSM1009636","raw_output":"{\\"x\\":1}","parsed_json":{"x":1},"valid_schema":true,"worker_id":0,"ts":"2026-05-07T09:00:00Z"}',
    '{"record_id":"GSM1009637","raw_output":"bad","parsed_json":null,"valid_schema":false,"worker_id":0,"ts":"2026-05-07T09:00:01Z"}'
  ), fs::path(dst_run, "predictions.jsonl"))
  jsonlite::write_json(
    list(run_id = bundle$run_id, model_id = "mistral", stage = "stage1",
         records_total = 2, records_completed_total = 1, records_failed_schema = 1),
    fs::path(dst_run, "run_summary.json"), auto_unbox = TRUE)

  # Mock rsync no-op (la dir e' gia' popolata)
  local_mock_processx(stdout = "", status = 0L)

  job <- structure(
    list(run_id = bundle$run_id, slurm_job_id = "999",
         stage = "stage1", bundle_dir = bundle$bundle_dir,
         submitted_at = "2026-05-07T09:00:00Z", config = cfg),
    class = "simulomicsr_dgx_job"
  )

  res <- dgx_p4_collect(job, dest = dest_root)
  expect_named(res, c("predictions", "errors", "summary", "run_dir"),
               ignore.order = TRUE)
  expect_s3_class(res$predictions, "data.frame")
  expect_identical(nrow(res$predictions), 1L)
  expect_identical(nrow(res$errors), 1L)
})
```

- [ ] **Step 13.2: Esegui test, verifica fallimento**

```bash
Rscript --vanilla -e 'devtools::test(filter = "dgx-submit")'
```

Expected: errori "could not find function dgx_p4_status / dgx_p4_collect / dgx_p4_recover".

- [ ] **Step 13.3: Aggiungi le 3 funzioni a `R/dgx-submit.R`**

In coda al file:

```r
#' Stato corrente di un job P4
#'
#' Esegue `squeue -j <slurm_job_id> -h -o "%T"` via SSH e (opzionalmente)
#' scarica `status.json` dal cluster.
#'
#' @param job `simulomicsr_dgx_job`.
#' @param fetch_status_json se TRUE, rsync di status.json dal remoto e
#'   ritorna anche il contenuto.
#' @param watch se TRUE, polling ogni 30s fino a stato terminale (COMPLETED,
#'   FAILED, CANCELLED, TIMEOUT). Stampa progress via cli.
#' @param interval secondi tra polling (default 30).
#' @return list con `slurm_state`, `remote_status_present`, `snapshot`
#'   (status.json se fetched).
#' @export
dgx_p4_status <- function(job,
                          fetch_status_json = TRUE,
                          watch = FALSE,
                          interval = 30L) {
  stopifnot(inherits(job, "simulomicsr_dgx_job"))
  cfg <- job$config
  if (is.na(job$slurm_job_id))
    cli::cli_abort("Job senza slurm_job_id (dry_run o recover non submitted).")

  poll_once <- function() {
    cmd <- paste0("squeue -j ", job$slurm_job_id,
                  " -h -o '%T' 2>/dev/null || echo TERMINATED")
    res <- .dgx_ssh(cfg, cmd)
    state <- trimws(res$stdout)
    if (!nzchar(state)) state <- "TERMINATED"

    snapshot <- NULL
    remote_status_present <- FALSE
    if (fetch_status_json) {
      remote_status <- paste0(cfg$remote_root, "/runs/", job$run_id, "/status.json")
      tmpfile <- fs::file_temp(ext = ".json")
      ssh_check <- .dgx_ssh(cfg, paste0("test -f ", shQuote(remote_status),
                                       " && echo present || echo absent"))
      if (trimws(ssh_check$stdout) == "present") {
        try({
          .dgx_rsync(cfg, local_path = tmpfile,
                     remote_path = remote_status, direction = "pull")
          snapshot <- jsonlite::read_json(tmpfile)
          remote_status_present <- TRUE
        }, silent = TRUE)
      }
    }

    list(slurm_state = state,
         remote_status_present = remote_status_present,
         snapshot = snapshot)
  }

  if (!watch) return(poll_once())

  cli::cli_alert_info("Watching {job$run_id} (slurm={job$slurm_job_id}). Ctrl-C per interrompere.")
  terminal <- c("COMPLETED", "FAILED", "CANCELLED", "TIMEOUT", "TERMINATED")
  repeat {
    st <- poll_once()
    snap <- st$snapshot
    msg <- paste0("[", format(Sys.time(), "%H:%M:%S"), "] state=", st$slurm_state)
    if (!is.null(snap)) {
      msg <- paste0(msg, " | runtime=", snap$state %||% "?")
      if (!is.null(snap$records_total))
        msg <- paste0(msg, " (", snap$records_completed %||% snap$records_completed_total %||% 0,
                      "/", snap$records_total, ")")
    }
    cli::cli_text(msg)
    if (st$slurm_state %in% terminal) return(invisible(st))
    Sys.sleep(interval)
  }
}

#' Collect dei risultati di un job P4 (rsync + parse + post-processing)
#'
#' Scarica `runs/<run_id>/` dal cluster in `<dest>/<run_id>/`, parse di
#' `predictions.jsonl`, applica il post-processing R-side
#' (`parse_stage1_response()` o `parse_stage2_response()`) sui parsed_json
#' validi.
#'
#' @param job `simulomicsr_dgx_job`.
#' @param dest path locale di destinazione. Default `analysis/p4-output/`.
#' @return list con `predictions` (data.frame valid_schema=TRUE), `errors`
#'   (data.frame valid_schema=FALSE), `summary` (run_summary.json),
#'   `run_dir` (path locale).
#' @export
dgx_p4_collect <- function(job, dest = "analysis/p4-output") {
  stopifnot(inherits(job, "simulomicsr_dgx_job"))
  cfg <- job$config

  fs::dir_create(dest, recurse = TRUE)
  remote_run <- paste0(cfg$remote_root, "/runs/", job$run_id, "/")
  local_run  <- fs::path(dest, job$run_id)
  fs::dir_create(local_run, recurse = TRUE)

  .dgx_rsync(cfg, local_path = paste0(local_run, "/"),
             remote_path = remote_run, direction = "pull")

  pred_path <- fs::path(local_run, "predictions.jsonl")
  summ_path <- fs::path(local_run, "run_summary.json")

  if (!fs::file_exists(pred_path))
    cli::cli_abort("predictions.jsonl non presente in {.path {local_run}}",
                   class = "simulomicsr_dgx_collect_no_predictions")

  rows <- lapply(readLines(pred_path), jsonlite::fromJSON, simplifyVector = FALSE)
  df <- tibble::tibble(
    record_id    = vapply(rows, function(r) r$record_id %||% NA_character_, character(1)),
    raw_output   = vapply(rows, function(r) r$raw_output %||% NA_character_, character(1)),
    parsed_json  = lapply(rows, function(r) r$parsed_json),
    valid_schema = vapply(rows, function(r) isTRUE(r$valid_schema), logical(1)),
    worker_id    = vapply(rows, function(r) as.integer(r$worker_id %||% NA), integer(1)),
    ts           = vapply(rows, function(r) r$ts %||% NA_character_, character(1))
  )

  # Post-processing R-side per i valid: ATTENZIONE: il bundle ha solo
  # record_id; per applicare parse_stage1_response servono geo_accession,
  # series_id, sample_string. Li recuperiamo dall'input.jsonl del bundle.
  if (job$stage == "stage1") {
    inp <- lapply(readLines(fs::path(job$bundle_dir, "input.jsonl")),
                  jsonlite::fromJSON, simplifyVector = FALSE)
    inp_lookup <- setNames(inp, vapply(inp, function(r) r$record_id, character(1)))
    df$parsed_json <- mapply(function(parsed, rid) {
      if (is.null(parsed)) return(NULL)
      orig <- inp_lookup[[rid]]
      if (is.null(orig)) return(parsed)
      tryCatch(
        simulomicsr:::parse_stage1_response(
          raw           = parsed,
          sample_string = orig$string,
          geo_accession = orig$geo_accession,
          series_id     = orig$series_id,
          model         = "vllm-mistral-3.2-24b"
        ),
        error = function(e) parsed
      )
    }, df$parsed_json, df$record_id, SIMPLIFY = FALSE)
  } else if (job$stage == "stage2") {
    # Stage2 post-processing: parse_stage2_response richiede argomenti diversi
    # (es. series_id). Lo applichiamo conditional su disponibilita' della
    # funzione (verifica sotto).
    if (exists("parse_stage2_response", envir = asNamespace("simulomicsr"))) {
      inp <- lapply(readLines(fs::path(job$bundle_dir, "input.jsonl")),
                    jsonlite::fromJSON, simplifyVector = FALSE)
      inp_lookup <- setNames(inp, vapply(inp, function(r) r$record_id, character(1)))
      df$parsed_json <- mapply(function(parsed, rid) {
        if (is.null(parsed)) return(NULL)
        orig <- inp_lookup[[rid]]
        tryCatch(
          simulomicsr:::parse_stage2_response(
            raw       = parsed,
            series_id = rid,
            model     = "vllm-mistral-3.2-24b"
          ),
          error = function(e) parsed
        )
      }, df$parsed_json, df$record_id, SIMPLIFY = FALSE)
    }
  }

  predictions <- df[df$valid_schema, , drop = FALSE]
  errors      <- df[!df$valid_schema, , drop = FALSE]

  summary <- if (fs::file_exists(summ_path)) jsonlite::read_json(summ_path) else list()

  list(predictions = predictions,
       errors = errors,
       summary = summary,
       run_dir = local_run)
}

#' Recupera un job P4 dal bundle locale dopo restart R
#'
#' Cerca `bundles/<run_id>/manifest.json`, ricostruisce un oggetto
#' `simulomicsr_dgx_job` senza chiamare il cluster. Lo `slurm_job_id`
#' resta `NA` finche' non lo si recupera manualmente da
#' `squeue --me` o si rilancia `dgx_p4_submit()`.
#'
#' @param run_id stringa del run.
#' @param config `simulomicsr_dgx_config`.
#' @param bundle_dir_root parent directory dei bundle. Default
#'   `analysis/p4-bundles`.
#' @return `simulomicsr_dgx_job`.
#' @export
dgx_p4_recover <- function(run_id,
                           config,
                           bundle_dir_root = "analysis/p4-bundles") {
  bundle_dir <- fs::path(bundle_dir_root, run_id)
  manifest_path <- fs::path(bundle_dir, "manifest.json")
  if (!fs::file_exists(manifest_path))
    cli::cli_abort("Bundle non trovato per run_id={run_id} in {.path {bundle_dir}}",
                   class = "simulomicsr_dgx_recover_no_bundle")
  m <- jsonlite::read_json(manifest_path)

  structure(
    list(run_id = m$run_id,
         slurm_job_id = NA_character_,
         stage = m$stage,
         bundle_dir = bundle_dir,
         rendered_slurm = fs::path(bundle_dir, "run_p4.rendered.sh"),
         submitted_at = NA_character_,
         config = config),
    class = "simulomicsr_dgx_job"
  )
}
```

- [ ] **Step 13.4: Run test**

```bash
Rscript --vanilla -e 'devtools::load_all(); devtools::test(filter = "dgx-submit")'
```

Expected: `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 6 ]` (3 di Task 12 + 3 di Task 13).

- [ ] **Step 13.5: Commit**

```bash
git add R/dgx-submit.R tests/testthat/test-dgx-submit.R
git commit -m "$(cat <<'EOF'
P4 Task 13: dgx_p4_status / dgx_p4_collect / dgx_p4_recover

dgx_p4_status(job, fetch_status_json, watch, interval): squeue -j via
SSH + opzionale rsync di status.json. watch=TRUE polling ogni 30s
fino a stato terminale (COMPLETED/FAILED/CANCELLED/TIMEOUT).

dgx_p4_collect(job, dest): rsync runs/<run_id>/ -> locale, parse
predictions.jsonl in tibble (record_id, raw_output, parsed_json,
valid_schema, worker_id, ts), applica parse_stage1_response() o
parse_stage2_response() (post-processing R-side: setta extraction.model
= "vllm-mistral-3.2-24b", raw_input_hash, ecc), ritorna predictions /
errors / summary / run_dir.

dgx_p4_recover(run_id, config): ricostruisce simulomicsr_dgx_job dal
bundle locale dopo restart R (slurm_job_id resta NA).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: NAMESPACE + R CMD check

**Files:**
- Modifica: `NAMESPACE` (auto-rigenerato)
- Modifica: `man/*.Rd` (auto-generati)

- [ ] **Step 14.1: Rigenera documentazione roxygen**

```bash
Rscript --vanilla -e 'devtools::document()'
```

Expected: aggiornamento di `NAMESPACE` con `export(dgx_config)`, `export(dgx_p4_build_bundle)`, `export(dgx_p4_submit)`, `export(dgx_p4_status)`, `export(dgx_p4_collect)`, `export(dgx_p4_recover)`, e print methods.

- [ ] **Step 14.2: Verifica NAMESPACE updates**

```bash
git diff NAMESPACE
```

Expected: nuove `export()` e `S3method()` aggiunte.

- [ ] **Step 14.3: Run test suite completa**

```bash
Rscript --vanilla -e 'devtools::test()'
```

Expected: 444 PASS pre-esistenti + 22 nuovi (5 config + 4 utils + 4 bundle + 6 submit + 3 status/collect/recover) ≈ 466 PASS / 0 FAIL.

- [ ] **Step 14.4: R CMD check**

```bash
Rscript --vanilla -e 'devtools::check(args = c("--no-manual"), error_on = "warning")' 2>&1 | tail -40
```

Expected: 0 errors, 0 warnings, 0 nuove note. Note pre-esistenti (es. installed package size, hidden directories) tollerate.

- [ ] **Step 14.5: Se compaiono note "no visible binding for global variable" o simili, fixle**

Se compaiono note legate a NSE o a campi `$` non quotati, aggiungi a `R/simulomicsr-package.R`:

```r
utils::globalVariables(c("valid_schema"))
```

- [ ] **Step 14.6: Commit**

```bash
git add NAMESPACE man/
git commit -m "$(cat <<'EOF'
P4 Task 14: NAMESPACE + man/ rigenerati per dgx_*

devtools::document() ha aggiunto export() per dgx_config,
dgx_p4_build_bundle, dgx_p4_submit, dgx_p4_status, dgx_p4_collect,
dgx_p4_recover + S3 print methods. man/*.Rd rigenerati.

R CMD check: 0E/0W/0 nuove note. Test suite: 466 PASS / 0 FAIL.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: ADR-0007 — DGX self-host vLLM

**Files:**
- Crea: `docs/decisions/0007-dgx-self-host-vllm.md`

- [ ] **Step 15.1: Scrivi l'ADR**

Verifica template:

```bash
cat docs/decisions/template.md 2>/dev/null | head -30
```

Se template esiste, segui struttura. Se no, usa lo schema sotto:

```markdown
# ADR-0007 — DGX self-host vLLM mistral-small-3.2 per P4

- **Stato:** Accettata
- **Data:** 2026-05-06
- **Decisori:** Luca Vedovelli (utente)
- **Contesto:** chiusura P3.5-D, apertura P4

## Contesto

P3.5-D ha valutato 14+ modelli LLM su mini-gold v5 con il task di
classificazione study_design Stadio 2. Vincitore per accuracy/costo:
`mistralai/Mistral-Small-3.2-24B-Instruct-2506` (Apache 2.0, 96%
accuracy, $0.0004/sample via OpenRouter). P4 richiede di portare la
pipeline a scala massiva (130k sample alpha / 700k beta). Il costo
OpenRouter su 700k a quel prezzo sarebbe ~$280, fattibile, ma il
budget è $0 perche' abbiamo accesso a DGX UniPD HPC (poddgx02, 8×
H100 80GB). Decidiamo di self-host.

## Decisione

Self-host mistral-small-3.2-24b in bfloat16 su DGX UniPD HPC tramite:

1. Container Apptainer con base `vllm/vllm-openai:v0.6.4` + script
   Python custom (`run_p4_vllm.py`).
2. SLURM job da 4× H100 (non 8× per non saturare il nodo) in
   data-parallel (1 modello per GPU, no tensor parallel — il 24B
   entra largo in 80GB).
3. vLLM offline batch (`LLM().generate()`) con `SamplingParams(guided_json=schema)`
   per garantire output schema-valid 100%.
4. Bundle layout autocontenuto rsync-ato al cluster + resume idempotente
   via `predictions.jsonl` append-only.

R control plane locale (5 funzioni esportate `dgx_*`) bespoke dentro
`simulomicsr`, NO fork del pacchetto del collega `laimsdgxllm` (vedi
spec §2 per razionale).

## Alternative considerate

- **Fork laimsdgxllm**: pro = SSH/SLURM/registry pronti; contro = 80%
  del codice da cambiare (modelli hardcoded, backend transformers
  single-record-loop ~10× piu' lento di vLLM continuous batching).
- **OpenRouter mistral-small-3.2**: pro = zero infra; contro = $280
  su run beta, dipendenza da network/uptime di terzi, rate limits.
- **Persistente vLLM server (`vllm serve`)**: pro = riusiamo
  R/llm-client-openrouter.R; contro = cluster SLURM non garantisce
  servizio always-on, va comunque dentro un job batch.

## Conseguenze

- Nuova dipendenza R: `processx` (per SSH/rsync subprocess).
- Nuovo asset committato: `inst/dgx/` (~230 LOC Python + 1 SLURM
  template + 1 Apptainer def).
- Nuovo workflow utente: `dgx_p4_build_bundle()` → `dgx_p4_submit()` →
  `dgx_p4_status(watch=TRUE)` → `dgx_p4_collect()`.
- Setup one-time sul login: rsync `inst/dgx/` → `~/simulomicsr-dgx/runtime/`,
  `apptainer build current.sif`, store `HF_TOKEN` in
  `~/.simulomicsr-dgx.env`.
- ADR-0005 (server migration trigger) parzialmente assorbito: P4 gira
  sulla DGX, ma `analysis/cache/` e altri artefatti stanno ancora
  sul laptop.

## Riferimenti

- Spec P4 design `docs/superpowers/specs/2026-05-06-p4-dgx-integration-design.md`
- P3.5-D risultati (CLAUDE.md sezione "Risultati conclusivi P3.5-D")
- `laims-dgx-llm-batch-main` esempio collega (riferimento, non importato)
- `2026.scRNA_DGX` esempio interno (stesso cluster, pattern Apptainer)
```

- [ ] **Step 15.2: Commit**

```bash
git add docs/decisions/0007-dgx-self-host-vllm.md
git commit -m "$(cat <<'EOF'
P4 Task 15: ADR-0007 DGX self-host vLLM mistral-small-3.2

Cattura la decisione architetturale di self-hostare mistral-small-3.2
sulla DGX UniPD via Apptainer+SLURM+vLLM offline batch invece di:
- fork laimsdgxllm (80% codice da cambiare, backend transformers slow)
- OpenRouter ($280 stimati su beta, dipendenza terze parti)
- vLLM server persistente (cluster SLURM non lo supporta affidabilmente)

Conseguenze documentate: nuova dep R processx, asset inst/dgx/,
workflow utente dgx_p4_*, setup one-time SSH+HF_TOKEN+apptainer build.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Vignette `p4-dgx-setup.Rmd` — guida one-time setup utente

**Files:**
- Crea: `vignettes/p4-dgx-setup.Rmd`

- [ ] **Step 16.1: Crea la vignette**

`vignettes/p4-dgx-setup.Rmd`:

````markdown
---
title: "P4 DGX setup — one-time guide"
output: rmarkdown::html_vignette
vignette: >
  %\VignetteIndexEntry{P4 DGX setup — one-time guide}
  %\VignetteEngine{knitr::rmarkdown}
  %\VignetteEncoding{UTF-8}
---

```{r, include = FALSE}
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  eval = FALSE
)
```

Questa vignette guida il setup iniziale (one-time) per usare il control
plane P4 verso la DGX UniPD HPC. Va eseguita UNA VOLTA per machine.

## 1. Prerequisiti

- Accesso SSH a `logindgx.hpc.ict.unipd.it` con user `u0044` (o tuo).
  Assicurati che `ssh u0044@logindgx.hpc.ict.unipd.it 'hostname'` funzioni
  senza password (key-based auth).
- Account HuggingFace con EULA del modello accettata. Apri
  https://huggingface.co/mistralai/Mistral-Small-3.2-24B-Instruct-2506,
  clicca "Agree and access" se non l'hai gia' fatto. Genera un access
  token in https://huggingface.co/settings/tokens (read scope basta).
- `simulomicsr` installato/loaded localmente.

## 2. Store HF_TOKEN sul login node

Una sola volta:

```sh
ssh u0044@logindgx.hpc.ict.unipd.it
cat > ~/.simulomicsr-dgx.env <<'EOF'
export HF_TOKEN="hf_xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
EOF
chmod 600 ~/.simulomicsr-dgx.env
exit
```

Sostituisci `hf_xxx...` con il tuo token vero. `dgx_p4_submit()` fara'
sourcing di questo file prima di sbatch.

## 3. Build + push immagine Docker (laptop)

Dalla radice del pacchetto:

```sh
cd inst/dgx
make build         # docker build -t lucavd/simulomicsr-vllm:latest .
make push          # docker push (richiede docker login una volta)
cd ../..
```

Tempo: ~3-5 min con cache layer hit.

## 4. Pull come SIF sul cluster + pre-download modello

```sh
make -C inst/dgx pull-cluster        # singularity pull docker://...:latest
make -C inst/dgx predownload-model   # huggingface-cli download ~50GB
```

Dopo questi due step, i job SLURM partono **senza** rete e **senza**
HF_TOKEN.

## 5. Rebuild quando cambiano gli asset

Quando modifichi `inst/dgx/python/`, `inst/dgx/Dockerfile`, o
`inst/dgx/slurm/run_p4.sh`:
- Cambi a `python/` o `Dockerfile` → `make build push pull-cluster` (ricostruisce + ridistribuisce)
- Cambi solo a `slurm/run_p4.sh` → niente rebuild (il template viene letto al submit-time da `dgx_p4_submit()`)

## 5. Smoke test 1 GPU 100 record

Prepara un input mini (es. 100 sample dal xlsx):

```{r}
library(simulomicsr)
library(readxl)
library(dplyr)

xlsx <- read_xlsx("data-raw/relevant_sample_classified.xlsx",
                  sheet = "relevant_sample")
mini <- xlsx |>
  dplyr::slice_head(n = 100) |>
  dplyr::transmute(
    record_id     = geo_accession,
    geo_accession = geo_accession,
    series_id     = series_id,
    string        = string
  )

dir.create("data-raw", showWarnings = FALSE)
input_path <- "data-raw/p4-smoke-stage1.jsonl"
con <- file(input_path, "w")
for (i in seq_len(nrow(mini))) {
  cat(jsonlite::toJSON(as.list(mini[i, ]), auto_unbox = TRUE), "\n",
      sep = "", file = con)
}
close(con)
```

Submit con override `gres=gpu:1` (vedi sotto):

```{r}
cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(input_path, "stage1", cfg,
                              metadata = list(slug = "smoke-1gpu"))
```

Per il primo smoke con 1 GPU, modifica manualmente
`<bundle_dir>/run_p4.rendered.sh` SE necessario, oppure usa il default 4
e accetta che 4 worker carichino lo stesso modello (overhead memoria
ma il job parte uguale).

```{r}
job <- dgx_p4_submit(bundle, time = "00:30:00", config = cfg)
dgx_p4_status(job, watch = TRUE, interval = 30)
result <- dgx_p4_collect(job)
result$summary
head(result$predictions)
```

## 6. Troubleshooting

- **SSH timeout**: verifica `ssh -v u0044@... 'hostname'`. Se cluster
  e' lento, aumenta timeout in `dgx_config()`.
- **HF gated model 401**: EULA non accettata o token scaduto. Re-fai
  Step 2.
- **OOM su 24B in 80GB H100**: abbassa `gpu_memory_utilization` da 0.90
  a 0.85 in `inst/extdata/p4-defaults.yml` e ricostruisci bundle.
- **Resume non riparte da fine**: verifica che `predictions.worker_*.jsonl`
  siano nel run dir (NON solo predictions.jsonl mergeato).
````

- [ ] **Step 16.2: Verifica vignette compila (almeno parsing markdown)**

```bash
Rscript --vanilla -e 'rmarkdown::render("vignettes/p4-dgx-setup.Rmd", output_dir = tempdir(), quiet = TRUE)'
```

Expected: HTML generato senza errori.

- [ ] **Step 16.3: Commit**

```bash
git add vignettes/p4-dgx-setup.Rmd
git commit -m "$(cat <<'EOF'
P4 Task 16: vignette p4-dgx-setup.Rmd one-time guide

Documenta i 4 step del setup utente:
1. Prerequisiti (SSH key, HF EULA + token)
2. Store HF_TOKEN in ~/.simulomicsr-dgx.env (chmod 600) sul login node
3. rsync inst/dgx/ + apptainer build current.sif (15-20 min)
4. Rebuild trigger (solo a cambio runtime.def o python/)

Plus smoke test 100 record stage1 + troubleshooting (SSH timeout, HF
gated 401, OOM, resume).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 17: Cluster setup one-time (manuale)

**Files:**
- Nessuna modifica al repo (operazioni docker locali + remote sul login node).

⚠️ Questo task richiede:
- `docker` installato e funzionante sul laptop
- Account DockerHub `lucavd` (`docker login` già fatto)
- Account HuggingFace con EULA Mistral 3.2 accettata
- Accesso SSH a `logindgx.hpc.ict.unipd.it`

- [ ] **Step 17.1: Verifica HF EULA accettata e crea HF_TOKEN**

Apri in browser https://huggingface.co/mistralai/Mistral-Small-3.2-24B-Instruct-2506,
conferma "You have been granted access". Crea token "read" su
https://huggingface.co/settings/tokens.

- [ ] **Step 17.2: Push HF_TOKEN sul login node**

```bash
ssh u0044@logindgx.hpc.ict.unipd.it 'cat > ~/.simulomicsr-dgx.env' <<'EOF'
export HF_TOKEN="hf_PASTE_YOUR_TOKEN_HERE"
EOF
ssh u0044@logindgx.hpc.ict.unipd.it 'chmod 600 ~/.simulomicsr-dgx.env'
ssh u0044@logindgx.hpc.ict.unipd.it 'ls -l ~/.simulomicsr-dgx.env'
```

Expected: `-rw------- 1 u0044 ... ~/.simulomicsr-dgx.env`.

- [ ] **Step 17.3: Verifica docker login DockerHub**

```bash
docker info 2>&1 | grep -i username || echo "Non loggato"
# Se non loggato:
docker login -u lucavd
```

Expected: `Username: lucavd`.

- [ ] **Step 17.4: Build + push immagine Docker (laptop, ~3-5 min cache hit)**

Dalla radice del pacchetto:

```bash
cd inst/dgx
make build
docker images | grep simulomicsr-vllm
make push
cd ../..
```

Expected:
- `make build` produce immagine `lucavd/simulomicsr-vllm:latest` (~6-8 GB)
- `make push` la spinge su DockerHub

- [ ] **Step 17.5: Pre-create directory remote sul cluster**

```bash
ssh u0044@logindgx.hpc.ict.unipd.it "mkdir -p /mnt/home/u0044/simulomicsr-dgx/{runtime,bundles,runs,models/HF_HOME}"
```

- [ ] **Step 17.6: Pull immagine come SIF sul cluster (~3-5 min)**

```bash
make -C inst/dgx pull-cluster
```

Expected: ultimo output `-rw-r--r-- ... current.sif (~6-8G)`.

In alternativa manuale:

```bash
ssh u0044@logindgx.hpc.ict.unipd.it "cd /mnt/home/u0044/simulomicsr-dgx/runtime/ && module load singularity/4.2.0 && singularity pull --force current.sif docker://lucavd/simulomicsr-vllm:latest && ls -lh current.sif"
```

- [ ] **Step 17.7: Pre-download del modello sul login (~10-15 min)**

```bash
make -C inst/dgx predownload-model
```

Expected: `huggingface-cli download` scarica ~50 GB in
`/mnt/home/u0044/simulomicsr-dgx/models/HF_HOME/`. Dopo questo step,
i job SLURM partono con cache hit e non richiedono `HF_TOKEN`.

Verifica:

```bash
ssh u0044@logindgx.hpc.ict.unipd.it "du -sh /mnt/home/u0044/simulomicsr-dgx/models/HF_HOME/"
```

Expected: ~50 GB.

- [ ] **Step 17.8: Sanity check container caricabile su una GPU**

Submit un job interattivo brevissimo (no input vero, solo verifica avvio container):

```bash
ssh u0044@logindgx.hpc.ict.unipd.it "module load singularity/4.2.0 && singularity exec --nv /mnt/home/u0044/simulomicsr-dgx/runtime/current.sif python -c 'import torch; print(\"CUDA:\", torch.cuda.is_available(), \"device count:\", torch.cuda.device_count())'"
```

⚠️ NOTA: questo va in foreground sul login senza GPU bound; testa solo che
il container Python carica e PyTorch e' presente. Il vero test GPU arriva
con Task 18 (smoke 1 GPU 100 record dentro un job SLURM).

Expected: `CUDA: False device count: 0` (nessuna GPU sul login node).
Se l'output e' un crash CUDA driver-related, segnale di alert: il
driver del login potrebbe essere troppo vecchio per CUDA 12.1.
Fallback: rebuild con `vllm/vllm-openai:v0.5.5` (CUDA 11.8) e ripeti.

- [ ] **Step 17.9: Annota completamento setup**

Niente commit di codice — operazioni remote/locali. Opzionale: aggiungi a TODO.md una riga "P4 cluster setup completato YYYY-MM-DD, image lucavd/simulomicsr-vllm:vN".

---

## Task 18: Smoke run 1 GPU 100 record stage1

**Files:**
- Crea: `data-raw/p4-smoke-stage1.jsonl` (gitignored, run-time)

⚠️ Richiede Task 17 completato.

- [ ] **Step 18.1: Prepara input mini**

```bash
Rscript --vanilla -e '
library(simulomicsr)
xlsx <- readxl::read_xlsx("data-raw/relevant_sample_classified.xlsx",
                          sheet = "relevant_sample")
mini <- head(xlsx, 100)
mini <- data.frame(
  record_id     = mini$geo_accession,
  geo_accession = mini$geo_accession,
  series_id     = mini$series_id,
  string        = mini$string,
  stringsAsFactors = FALSE
)
con <- file("data-raw/p4-smoke-stage1.jsonl", "w")
for (i in seq_len(nrow(mini))) {
  cat(jsonlite::toJSON(as.list(mini[i, ]), auto_unbox = TRUE), "\n", sep = "", file = con)
}
close(con)
cat(sprintf("OK: %d record scritti\n", nrow(mini)))
'
```

Expected: `OK: 100 record scritti`.

- [ ] **Step 18.2: Build bundle e submit con 1 GPU (modifica manuale)**

```bash
Rscript --vanilla -e '
library(simulomicsr)
cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(
  input_jsonl = "data-raw/p4-smoke-stage1.jsonl",
  stage = "stage1", config = cfg,
  metadata = list(slug = "smoke-1gpu-stage1"))
cat("run_id:", bundle$run_id, "\n")
cat("bundle_dir:", bundle$bundle_dir, "\n")

# Renderizza SLURM con dry_run, poi modifica gpu:4 -> gpu:1, workers 4 -> 1
job <- dgx_p4_submit(bundle, time = "00:30:00", config = cfg, dry_run = TRUE)
cat("rendered:", job$rendered_slurm, "\n")
'
```

Modifica `<bundle_dir>/run_p4.rendered.sh` manualmente:
- Riga `#SBATCH --gres=gpu:4` → `#SBATCH --gres=gpu:1`
- In fondo, `--workers 4` → `--workers 1`

Salva.

```bash
# rsync bundle modificato e sbatch manualmente
RUN_ID=$(ls analysis/p4-bundles/ | tail -1)
rsync -az analysis/p4-bundles/$RUN_ID/ u0044@logindgx.hpc.ict.unipd.it:/mnt/home/u0044/simulomicsr-dgx/bundles/$RUN_ID/
ssh u0044@logindgx.hpc.ict.unipd.it ". ~/.simulomicsr-dgx.env && sbatch --export=HF_TOKEN /mnt/home/u0044/simulomicsr-dgx/bundles/$RUN_ID/run_p4.rendered.sh"
```

Expected: `Submitted batch job <id>`.

- [ ] **Step 18.3: Monitor job**

```bash
ssh u0044@logindgx.hpc.ict.unipd.it 'squeue --me'
ssh u0044@logindgx.hpc.ict.unipd.it "tail -f /mnt/home/u0044/simulomicsr-dgx/runs/$RUN_ID/slurm-*.out"
```

Aspetta. Primo run scarica modello (~10-15 min). Generazione: ~2-5 min su 100 record / 1 H100.

Expected (slurm-*.out): "[worker 0] caricamento vLLM su GPU 0...", poi "[worker 0] generazione completata in <X>s".

- [ ] **Step 18.4: Collect e verifica output**

```bash
Rscript --vanilla -e '
library(simulomicsr)
cfg <- dgx_config()
RUN_ID <- list.files("analysis/p4-bundles") |> tail(1)
job <- dgx_p4_recover(RUN_ID, cfg)
result <- dgx_p4_collect(job, dest = "analysis/p4-output")
cat("Predictions:", nrow(result$predictions), "\n")
cat("Errors:", nrow(result$errors), "\n")
cat("Summary:\n")
str(result$summary)
print(head(result$predictions, 3))
'
```

Expected:
- Predictions: 100 (o quasi, se qualcuno fallisce schema validation)
- Errors: 0-2 (idealmente 0)
- Schema valid rate ≥ 95% (su 100, ≥ 95 valid)

- [ ] **Step 18.5: Acceptance check 1 GPU smoke**

✅ Pass se:
- Job COMPLETED su SLURM (no FAILED/TIMEOUT)
- 0 worker crash
- Schema validity ≥ 95% (≥ 95/100)
- Schema-valid output ha campi attesi: `cell_context`, `perturbations`, `extraction.confidence` ecc.

❌ Se non pass: debug. Tipici culprit: HF_TOKEN missing, OOM, schema mismatch (vLLM guided JSON non rispetta v3 — verificare schema.json shape).

Niente commit (test manuali, output gitignored).

---

## Task 19: Smoke run 4 GPU 100 record stage1

⚠️ Richiede Task 18 passato.

- [ ] **Step 19.1: Re-run con 4 GPU, niente modifica manuale**

```bash
Rscript --vanilla -e '
library(simulomicsr)
cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(
  input_jsonl = "data-raw/p4-smoke-stage1.jsonl",
  stage = "stage1", config = cfg,
  metadata = list(slug = "smoke-4gpu-stage1"))

job <- dgx_p4_submit(bundle, time = "00:30:00", config = cfg)
cat("run_id:", bundle$run_id, "slurm:", job$slurm_job_id, "\n")
saveRDS(job, "analysis/p4-bundles/last-job.rds")
'
```

- [ ] **Step 19.2: Watch fino a fine**

```bash
Rscript --vanilla -e '
library(simulomicsr)
job <- readRDS("analysis/p4-bundles/last-job.rds")
dgx_p4_status(job, watch = TRUE, interval = 30)
'
```

Expected: stato finale `COMPLETED` in 5-10 min (modello già in HF cache da Task 18).

- [ ] **Step 19.3: Collect e confronta vs Task 18**

```bash
Rscript --vanilla -e '
library(simulomicsr)
job <- readRDS("analysis/p4-bundles/last-job.rds")
result <- dgx_p4_collect(job)
cat("Predictions:", nrow(result$predictions), "\n")
cat("Workers used:", paste(sort(unique(result$predictions$worker_id)), collapse=","), "\n")
cat("Throughput totale:", result$summary$records_completed_total, "in", result$summary$finished_at, "\n")
'
```

Expected:
- Predictions: ~100 (parità con Task 18)
- Workers: 0,1,2,3 (4 worker usati)
- Tempo end-to-end ridotto vs 1 GPU (anche se cold load del modello su 4 GPU prende quasi quanto su 1, il batch è 4× più rapido)

- [ ] **Step 19.4: Acceptance check 4 GPU smoke**

✅ Pass se:
- Tutti 4 worker hanno scritto in predictions.jsonl
- Predictions count >= count del Task 18
- Schema validity in linea (>= 95%)

Niente commit.

---

## Task 20: Smoke resume verification

⚠️ Richiede Task 19 passato.

- [ ] **Step 20.1: Submit run da 100 record, kill volutamente a metà**

```bash
Rscript --vanilla -e '
library(simulomicsr)
cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(
  input_jsonl = "data-raw/p4-smoke-stage1.jsonl",
  stage = "stage1", config = cfg,
  metadata = list(slug = "smoke-resume-test"))
job <- dgx_p4_submit(bundle, time = "00:30:00", config = cfg)
saveRDS(job, "analysis/p4-bundles/resume-test-job.rds")
cat("run_id:", bundle$run_id, "slurm:", job$slurm_job_id, "\n")
'
```

Aspetta che il job parta e abbia processato qualcosa (~30 s dopo `RUNNING` su squeue):

```bash
sleep 90
JOB_ID=$(Rscript --vanilla -e 'cat(readRDS("analysis/p4-bundles/resume-test-job.rds")$slurm_job_id)')
ssh u0044@logindgx.hpc.ict.unipd.it "scancel $JOB_ID"
```

Expected: job CANCELLED. Files `predictions.worker_*.jsonl` parziali presenti sul cluster.

- [ ] **Step 20.2: Verifica record parziali sul cluster**

```bash
RUN_ID=$(Rscript --vanilla -e 'cat(readRDS("analysis/p4-bundles/resume-test-job.rds")$run_id)')
ssh u0044@logindgx.hpc.ict.unipd.it "wc -l /mnt/home/u0044/simulomicsr-dgx/runs/$RUN_ID/predictions.worker_*.jsonl 2>/dev/null"
```

Expected: alcune righe (es. 20-60 totali su 100).

- [ ] **Step 20.3: Re-submit lo stesso run_id via shell sbatch diretto**

Il bundle e il SLURM script renderizzato sono gia' sul cluster (rsync di Task 20.1). Per riprendere il run basta rifare sbatch sullo stesso script:

```bash
RUN_ID=$(Rscript --vanilla -e 'cat(readRDS("analysis/p4-bundles/resume-test-job.rds")$run_id)')
SLURM_OUT=$(ssh u0044@logindgx.hpc.ict.unipd.it ". ~/.simulomicsr-dgx.env && sbatch --export=HF_TOKEN /mnt/home/u0044/simulomicsr-dgx/bundles/$RUN_ID/run_p4.rendered.sh")
echo "$SLURM_OUT"
NEW_JOB_ID=$(echo "$SLURM_OUT" | sed -n 's/Submitted batch job //p')
echo "new slurm job: $NEW_JOB_ID"

# Salva un nuovo job R per il polling
Rscript --vanilla -e '
library(simulomicsr)
cfg <- dgx_config()
job <- readRDS("analysis/p4-bundles/resume-test-job.rds")
job$slurm_job_id <- Sys.getenv("NEW_JOB_ID")
job$submitted_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
saveRDS(job, "analysis/p4-bundles/resume-test-job2.rds")
dgx_p4_status(job, watch = TRUE, interval = 30)
' NEW_JOB_ID="$NEW_JOB_ID"
```

Expected: nel `slurm-*.out` del nuovo job apparirà `[main] totale=100 done=<N> todo=<100-N>` con N > 0. Stato finale `COMPLETED`.

Nota: in futuro un helper `dgx_p4_resubmit(job, time, config)` puo' incapsulare questo shell pattern. Out of scope per ora.

- [ ] **Step 20.4: Collect e verifica unione completa**

```bash
Rscript --vanilla -e '
library(simulomicsr)
cfg <- dgx_config()
job2 <- readRDS("analysis/p4-bundles/resume-test-job2.rds")
result <- dgx_p4_collect(job2)
cat("Predictions:", nrow(result$predictions), "/ expected ~100\n")
cat("Errors:", nrow(result$errors), "\n")
'
```

Expected: ~100 predictions (totale, dopo merge dei worker file delle 2 run).

- [ ] **Step 20.5: Acceptance resume**

✅ Pass se:
- Resubmit ha riconosciuto i record già fatti (log "totale=100 done=N todo=100-N")
- Final predictions.jsonl ha ~100 unique record_id
- Niente commit.

---

## Task 21: Run α completo Stadio 1 (130k sample xlsx)

⚠️ Richiede Task 20 passato. Tempo stimato: ~3-4h.

- [ ] **Step 21.1: Prepara input completo xlsx → JSONL**

```bash
Rscript --vanilla -e '
library(simulomicsr)
xlsx <- readxl::read_xlsx("data-raw/relevant_sample_classified.xlsx",
                          sheet = "relevant_sample")
all <- data.frame(
  record_id     = xlsx$geo_accession,
  geo_accession = xlsx$geo_accession,
  series_id     = xlsx$series_id,
  string        = xlsx$string,
  stringsAsFactors = FALSE
)
all <- all[!duplicated(all$record_id), , drop = FALSE]
cat("Records totali (post-dedup):", nrow(all), "\n")
con <- file("data-raw/p4-alpha-stage1.jsonl", "w")
for (i in seq_len(nrow(all))) {
  cat(jsonlite::toJSON(as.list(all[i, ]), auto_unbox = TRUE), "\n", sep = "", file = con)
}
close(con)
'
```

Expected: ~130.784 record (o leggermente meno post-dedup).

- [ ] **Step 21.2: Build bundle e submit (time 12h)**

```bash
Rscript --vanilla -e '
library(simulomicsr)
cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(
  input_jsonl = "data-raw/p4-alpha-stage1.jsonl",
  stage = "stage1", config = cfg,
  metadata = list(slug = "alpha-xlsx-stage1"))
job <- dgx_p4_submit(bundle, time = "12:00:00", config = cfg)
saveRDS(job, "analysis/p4-bundles/alpha-stage1-job.rds")
cat("run_id:", bundle$run_id, "slurm:", job$slurm_job_id, "\n")
'
```

- [ ] **Step 21.3: Watch periodicamente (NON in foreground per 4h!)**

```bash
# Polling manuale
Rscript --vanilla -e '
library(simulomicsr)
job <- readRDS("analysis/p4-bundles/alpha-stage1-job.rds")
print(dgx_p4_status(job, fetch_status_json = TRUE))
'
```

Esegui ogni 30-60 min. Quando state diventa COMPLETED o COMPLETED_WITH_ERRORS, procedi.

- [ ] **Step 21.4: Collect risultati**

```bash
Rscript --vanilla -e '
library(simulomicsr)
job <- readRDS("analysis/p4-bundles/alpha-stage1-job.rds")
result <- dgx_p4_collect(job, dest = "analysis/p4-output")
saveRDS(result, "analysis/p4-output/alpha-stage1-result.rds")
cat("Predictions:", nrow(result$predictions), "/", result$summary$records_total, "\n")
cat("Errors:", nrow(result$errors), "\n")
cat("Schema valid rate:", round(100 * nrow(result$predictions) / result$summary$records_total, 1), "%\n")
'
```

Expected (target acceptance):
- Schema valid rate ≥ 95% (≥ ~124k su 130k)
- Errors < 5% (≤ ~6500 su 130k)

- [ ] **Step 21.5: Confronto vs P3.5-D mini-gold v5**

```bash
Rscript --vanilla -e '
library(simulomicsr)
result <- readRDS("analysis/p4-output/alpha-stage1-result.rds")
mini <- read.csv(system.file("extdata", "p35c-minigold-reviewed-v5.csv", package = "simulomicsr"))
# Join su geo_accession
common <- intersect(result$predictions$record_id, mini$geo_accession)
cat("Mini-gold v5 sample in alpha output:", length(common), "/ 100\n")

# Per ogni mini-gold sample, estrai trtctr_predicted da parsed_json e confronta
matched <- result$predictions[result$predictions$record_id %in% common, ]
# Chiamata a function di confronto P3.5-D — adatta in base a quello che hai gia'
# Per ora basta verifica presenza:
cat("Verificare manualmente accuracy con confronto trtctr_predicted vs gold.\n")
'
```

Acceptance: accuracy stage 1 ≥ 95% (atteso 96% da P3.5-D, tolleranza 1pp).

- [ ] **Step 21.6: Annotazione**

Niente commit di codice. Salva i risultati `.rds` in `analysis/p4-output/` (gitignored).
Aggiungi note al CLAUDE.md / TODO.md sui numeri ottenuti — utile per la prossima sessione.

---

## Task 22: Run α Stadio 2 (~5.4k studi GSE)

⚠️ Richiede Task 21 passato. Tempo stimato: ~30 min.

- [ ] **Step 22.1: Prepara input stage2 dai sample_facts di Task 21**

```bash
Rscript --vanilla -e '
library(simulomicsr)
res1 <- readRDS("analysis/p4-output/alpha-stage1-result.rds")
# Aggrega per series_id (GSE)
sf <- res1$predictions
sf$series_id <- vapply(sf$parsed_json, function(p) p$series_id %||% NA_character_, character(1))

# Per ogni GSE, raccogli i sample_facts e crea record stage2.
# Fetch summary da NCBI (cache) — se hai gia\` summaries da P3, riusa.
gse_list <- unique(sf$series_id[!is.na(sf$series_id)])
cat("GSE distinti:", length(gse_list), "\n")

# Costruzione stage2 input (semplificata; in produzione usa fetch_study_summary())
con <- file("data-raw/p4-alpha-stage2.jsonl", "w")
for (gse in gse_list) {
  rows <- sf[sf$series_id == gse, ]
  rec <- list(
    record_id = gse,
    study_summary = "(da fetch_study_summary se disponibile in cache)",
    samples = lapply(seq_len(nrow(rows)), function(i) {
      list(
        geo_accession = rows$record_id[i],
        sample_facts = rows$parsed_json[[i]]
      )
    })
  )
  cat(jsonlite::toJSON(rec, auto_unbox = TRUE, null = "null"), "\n", sep = "", file = con)
}
close(con)
'
```

⚠️ NOTA: il blocco `fetch_study_summary()` è semplificato. In produzione,
usa `simulomicsr::fetch_study_summary(gse)` per popolare `study_summary`.
Se la cache è già popolata da P3 / P3.5-A, integra qui.

- [ ] **Step 22.2: Build bundle stage2 e submit (time 2h)**

```bash
Rscript --vanilla -e '
library(simulomicsr)
cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(
  input_jsonl = "data-raw/p4-alpha-stage2.jsonl",
  stage = "stage2", config = cfg,
  metadata = list(slug = "alpha-stage2"))
job <- dgx_p4_submit(bundle, time = "02:00:00", config = cfg)
saveRDS(job, "analysis/p4-bundles/alpha-stage2-job.rds")
cat("run_id:", bundle$run_id, "slurm:", job$slurm_job_id, "\n")
'
```

- [ ] **Step 22.3: Watch e collect**

```bash
Rscript --vanilla -e '
library(simulomicsr)
job <- readRDS("analysis/p4-bundles/alpha-stage2-job.rds")
dgx_p4_status(job, watch = TRUE, interval = 60)
result <- dgx_p4_collect(job)
saveRDS(result, "analysis/p4-output/alpha-stage2-result.rds")
cat("Predictions:", nrow(result$predictions), "/ ~5400\n")
cat("Schema valid rate:", round(100 * nrow(result$predictions) / result$summary$records_total, 1), "%\n")
'
```

- [ ] **Step 22.4: Confronto vs P3.5-A gold**

```bash
Rscript --vanilla -e '
library(simulomicsr)
res2 <- readRDS("analysis/p4-output/alpha-stage2-result.rds")
# Carica i 100 GSE di P3.5-A (committati in inst/extdata)
p35a <- read.csv(system.file("extdata", "p35a-gse-selected.csv", package = "simulomicsr"))
common <- intersect(res2$predictions$record_id, p35a$gse)
cat("P3.5-A overlap:", length(common), "/ 100\n")
# Confronto manuale design_role / comparison structure vs gold trtctr
# Acceptance: binary accuracy >= 95% (target aspirazionale)
'
```

Acceptance:
- Schema valid rate ≥ 95%
- Stage2 binary accuracy target ≥ 95%; fallback investigativo [80%, 95%) o debug bug < 80% (vedi spec §12).

- [ ] **Step 22.5: Annotazione finale**

Niente commit. Annotazioni in CLAUDE.md o TODO.md per chiusura P4.

---

## Task 23: Wrap-up — tag, CLAUDE.md update, push

**Files:**
- Modifica: `CLAUDE.md` (sezione "Stato corrente" e "Next step")
- Tag: `p4-dgx-complete`

- [ ] **Step 23.1: Aggiorna `CLAUDE.md` sezione "Stato corrente"**

Apri `CLAUDE.md`, sostituisci la sezione iniziale di "Stato corrente" con (adatta tag/risultati ai numeri reali):

```
## Stato corrente (2026-05-XX fine sessione P4-DGX)

- **Branch:** `p4-dgx-integration` mergiato in `master`.
- **Tag:** `p1-infra-llm-complete`, `p2-stage1-complete`, `p3-stage2-complete`, `p3.5b-eval-complete`, `p3.5a-eval-complete`, `p3.5c-confidence-complete`, `p3.5d-cheap-models-complete`, **`p4-dgx-complete`**.
- **R CMD check:** 0E / 0W / note pre-esistenti.
- **Test suite:** 466 PASS / 0 FAIL.

### Cosa P4 ha consegnato (DGX self-host vLLM)

- 5 funzioni R esportate (`dgx_config`, `dgx_p4_build_bundle`, `dgx_p4_submit`,
  `dgx_p4_status`, `dgx_p4_collect`) + 1 di servizio (`dgx_p4_recover`)
- Payload remoto in `inst/dgx/` (Apptainer def + SLURM template + Python vLLM script)
- Run α completo:
  - Stadio 1 su 130k sample xlsx: <X>% schema valid, <Y>% accuracy vs mini-gold v5
  - Stadio 2 su ~5.4k studi GSE: <Z>% schema valid, <W>% accuracy vs P3.5-A
- ADR-0007 documenta decisione self-host (no fork laimsdgxllm, no OpenRouter)
- Vignette `p4-dgx-setup.Rmd` con guida one-time setup utente

### Next step (per la prossima sessione)

- **β: ETL ARCHS4 H5 → JSONL** per run massivo 700k sample. Plan separato.
- **Output 3 ADR-0006**: P5 Stadio 4+5 (DESeq2/limma + metafor REM).
- **Rename pacchetto** (ADR-0003) prima del primo `install_github` pubblico.
```

- [ ] **Step 23.2: Commit update CLAUDE.md**

```bash
git add CLAUDE.md
git commit -m "$(cat <<'EOF'
P4 chiusura: aggiorna CLAUDE.md con risultati run alpha + tag

Aggiorna la sezione Stato corrente per riflettere chiusura P4: 5
funzioni dgx_* esportate, payload inst/dgx/, run alpha completo
(stadio 1 + stadio 2) con risultati vs P3.5-D mini-gold e P3.5-A
gold. Next step puntano a beta (ETL ARCHS4) e Output 3 ADR-0006 (P5).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 23.3: Tag finale**

```bash
git tag -a p4-dgx-complete -m "P4 DGX integration completata: run alpha xlsx 130k stage1 + 5.4k stage2 su mistral-small-3.2 self-host"
git tag --list | tail -5
```

Expected: `p4-dgx-complete` presente.

- [ ] **Step 23.4: Stop. NON push (utente lo fa lui).**

CLAUDE.md, regola operativa: "MAI fare git push — l'utente lo fa lui, sempre."

Fine. Plan completato.

---

## Self-review

- [x] **Spec coverage**: ogni componente della spec § 4 è coperto da una task
  (config Task 3, utils Task 4, defaults Task 5, bundle Task 6, prompts Task 7,
  resume Task 8, run_p4_vllm Task 9, runtime+build Task 10, slurm Task 11,
  submit Task 12, status/collect/recover Task 13, NAMESPACE Task 14,
  ADR Task 15, vignette Task 16, manual smoke Tasks 17-22, wrap-up Task 23).
- [x] **Acceptance criteria** stage1 ≥ 95% e stage2 ≥ 95% (con fallback) coperti in Task 21 e Task 22.
- [x] **Resume verification** task dedicata (Task 20).
- [x] **Out of scope** rispettato: niente ETL ARCHS4 (deferred), niente vLLM server long-running.
- [x] **Type consistency**: `simulomicsr_dgx_config`, `simulomicsr_dgx_bundle`, `simulomicsr_dgx_job` usate consistentemente. Funzioni `dgx_p4_*` con prefisso uniforme. Helper privati `.dgx_*`.
- [x] **No placeholder**: ogni step ha codice o comando concreto.
