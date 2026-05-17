# P4 β Rescue Cascade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Recovery cascade per i β stage1 (1.571 / 888.821 = 0.18%) e stage2 (43 / 39.205 = 0.11%) fails identificati in Phase 1 debugging, mirror della strategia α stage1 4-pass rescue (ADR-0008 addendum) e nuovo retry stage2 cs25 re-split.

**Architecture:**
- Branch nuovo `p4-beta-rescue` da `master` (post-tag `p4-beta-archs4-human-complete`)
- **H2 (no DGX)**: ETL cleanup mouse leak GSE86977 + 3 sample non-human residui dal master stage1 + propagazione a stage2-input
- **H1 (DGX)**: retry ~822 Mode A/B stage1 fails con `repetition_penalty=1.2` + `max_tokens=4096` (mirror α addendum) → merge in master con `rescue_source` col
- **H3 (DGX)**: retry 43 stage2 chunked fails con re-split a `chunk_size=25` (cs25) → merge nel master stage2
- Smoke + STOP pattern per ogni run DGX (feedback memoria `feedback_validate_before_fullrun`)

**Tech Stack:** R 4.5.2 + simulomicsr + DGX vLLM stack (Mistral-Small-3.2-24B + StructuredOutputsParams), pattern bundle-patching da `analysis/p4-beta-stage1-outliers.R`, merge pattern da `analysis/p4-beta-stage1-merge.R`.

**Expected outcome:**
- Stage1 master 888.821 → 887.275 (drop 1.546 non-human) + ~820 rescued = 888.095 valid; schema validity ~99.97% sui human kept
- Stage2 master 39.162 → 39.197 valid (rescue ~35/43, accept ~8 hard residuals); schema validity 99.97%

---

## Task 1: Branch setup + plan capture

**Files:**
- Create: `docs/superpowers/plans/2026-05-17-p4-beta-rescue-cascade-plan.md` (questo file, già scritto)
- Modify: `NEWS.md` (entry preview)

- [ ] **Step 1: Create branch + verify clean state**

```bash
git status              # expect clean tree on master
git checkout -b p4-beta-rescue
git log --oneline -3    # verify ancorato a 44272a2 o successivo
```

- [ ] **Step 2: Stage del plan**

```bash
git add docs/superpowers/plans/2026-05-17-p4-beta-rescue-cascade-plan.md
git commit -m "P4 β rescue: plan cascade H1+H2+H3 (1.571 stage1 + 43 stage2 fails)"
```

---

## Task 2: H2 prep — Classify stage1 fails (diagnostic table)

Genera CSV diagnostico con classificazione Mode A vs B vs ETL-leak per i 1.571 fails. Serve come input per H2 cleanup e H1 retry input build.

**Files:**
- Create: `analysis/p4-beta-rescue-classify-stage1-fails.R`
- Output: `analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv` (gitignored)

- [ ] **Step 1: Scrivi script di classificazione**

```r
#!/usr/bin/env Rscript
# p4-beta-rescue-classify-stage1-fails.R --- Phase 1 rescue: classifica i 1571
# stage1 fails come {ETL_LEAK_NONHUMAN, MODE_A_WHITESPACE, MODE_B_LEGIT_TRUNC,
# OTHER_DEGEN} per drive di H2 (cleanup) + H1 (retry input).

suppressPackageStartupMessages({
  library(jsonlite)
})

PREDS  <- "analysis/p4-output/p4-beta-stage1-master-predictions.jsonl"
OUT    <- "analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv"

stopifnot(file.exists(PREDS))

extract_field <- function(raw, field) {
  pat <- sprintf("\"%s\"\\s*:\\s*\"[^\"]+\"", field)
  m   <- regmatches(raw, regexpr(pat, raw))
  if (length(m) == 0L) NA_character_
  else sub(sprintf("\"%s\"\\s*:\\s*\"([^\"]+)\"", field), "\\1", m)
}

classify_fail <- function(raw) {
  nc   <- nchar(raw)
  tail <- substr(raw, max(1L, nc - 50L), nc)
  # Mode A: terminate in 20+ TAB (whitespace decoder loop)
  if (grepl("\\t{20,}", tail)) return("MODE_A_WHITESPACE")
  # Mode B legit truncation: no degenerate pattern, just ran out budget
  if (nc >= 2400L && !grepl("[\\t\\s]{30,}|(?:\\.{30,})", tail, perl = TRUE)) {
    return("MODE_B_LEGIT_TRUNC")
  }
  "OTHER_DEGEN"
}

cat("Scanning", PREDS, "...\n")
con <- file(PREDS, "r")
rows <- list()
i <- 0L
while (TRUE) {
  L <- readLines(con, n = 1L, warn = FALSE)
  if (!length(L)) break
  i <- i + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(rec$parsed_json)) next
  org <- extract_field(rec$raw_output %||% "", "organism")
  sid <- extract_field(rec$raw_output %||% "", "series_id")
  is_human <- isTRUE(org %in% c("human", "Homo sapiens"))
  mode <- if (!is_human && !is.na(org)) "ETL_LEAK_NONHUMAN" else classify_fail(rec$raw_output %||% "")
  rows[[length(rows) + 1L]] <- data.frame(
    record_id   = rec$record_id,
    series_id   = sid,
    organism    = org,
    nchar_raw   = nchar(rec$raw_output %||% ""),
    fail_mode   = mode,
    stringsAsFactors = FALSE
  )
  if (length(rows) %% 200L == 0L) {
    cat(sprintf("...processed %d lines, %d fails captured\n", i, length(rows)))
  }
}
close(con)

df <- do.call(rbind, rows)
write.csv(df, OUT, row.names = FALSE)
cat(sprintf("\nTotal fails: %d\n", nrow(df)))
cat("\n=== fail_mode distribution ===\n")
print(table(df$fail_mode))
cat("\n=== organism per fail_mode ===\n")
print(table(df$fail_mode, df$organism, useNA = "always"))
cat("\nOutput:", OUT, "\n")
```

- [ ] **Step 2: Eseguire lo script**

```bash
Rscript --vanilla analysis/p4-beta-rescue-classify-stage1-fails.R
```

Expected output:
```
Total fails: 1571
fail_mode:
  ETL_LEAK_NONHUMAN: ~749
  MODE_A_WHITESPACE: ~822
  OTHER_DEGEN:       ~0-30
  MODE_B_LEGIT_TRUNC: ~few
```

- [ ] **Step 3: Verifica distribuzione GSE86977 in ETL_LEAK_NONHUMAN**

```bash
Rscript --vanilla -e '
df <- read.csv("analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv")
cat("ETL_LEAK_NONHUMAN per series_id:\n")
print(sort(table(df$series_id[df$fail_mode=="ETL_LEAK_NONHUMAN"]), decreasing=TRUE)[1:10])
'
```

Expected: `GSE86977 = 746` dominante.

- [ ] **Step 4: Commit**

```bash
git add analysis/p4-beta-rescue-classify-stage1-fails.R
git commit -m "P4 β rescue Task 2: classify stage1 1571 fails (Mode A/B/ETL leak)"
```

---

## Task 3: H2 — Clean ETL mouse leak dal master stage1 + downstream stage2-input

Droppa i ~749 records `ETL_LEAK_NONHUMAN` dal master stage1 e dal stage2-input. Output: master+input puliti, salvati con suffisso `-cleaned.jsonl`.

**Files:**
- Create: `analysis/p4-beta-rescue-h2-cleanup.R`
- Output: `analysis/p4-output/p4-beta-stage1-master-predictions-cleaned.jsonl` (gitignored)
- Output: `analysis/input/archs4-human-stage2-input-cleaned.jsonl` (gitignored)

- [ ] **Step 1: Scrivi script H2**

```r
#!/usr/bin/env Rscript
# p4-beta-rescue-h2-cleanup.R --- H2: rimuovi ETL leak non-human dal master stage1
# e propaga la pulizia al stage2-input.
#
# I record marcati ETL_LEAK_NONHUMAN da p4-beta-rescue-stage1-fails-classified.csv
# sono sample dove ARCHS4 dichiara organism_ch1="Homo sapiens" ma il metadato
# stringa indica chiaramente non-human (es. GSE86977 mouse Cre-line). Il filtro
# ETL e' corretto data l'input, ma il dato GEO upstream e' wrong. Drop dal
# master stage1 e da stage2-input per evitare contaminazione downstream.

suppressPackageStartupMessages({
  library(jsonlite)
})

CLASSIFIED <- "analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv"
MASTER_IN  <- "analysis/p4-output/p4-beta-stage1-master-predictions.jsonl"
MASTER_OUT <- "analysis/p4-output/p4-beta-stage1-master-predictions-cleaned.jsonl"
STAGE2_IN  <- "analysis/input/archs4-human-stage2-input.jsonl"
STAGE2_OUT <- "analysis/input/archs4-human-stage2-input-cleaned.jsonl"

stopifnot(file.exists(CLASSIFIED), file.exists(MASTER_IN), file.exists(STAGE2_IN))

df <- read.csv(CLASSIFIED, stringsAsFactors = FALSE)
to_drop_gsm <- df$record_id[df$fail_mode == "ETL_LEAK_NONHUMAN"]
to_drop_gse <- unique(df$series_id[df$fail_mode == "ETL_LEAK_NONHUMAN"])
cat(sprintf("Drop %d GSM (across %d GSE)\n", length(to_drop_gsm), length(to_drop_gse)))

# === stage1 master cleanup ===
cat("Streaming master stage1...\n")
con_in  <- file(MASTER_IN, "r")
con_out <- file(MASTER_OUT, "w")
n_total <- 0L; n_kept <- 0L; n_dropped <- 0L
drop_set <- new.env(hash = TRUE, size = length(to_drop_gsm))
for (g in to_drop_gsm) drop_set[[g]] <- TRUE
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(drop_set[[rec$record_id]])) {
    n_dropped <- n_dropped + 1L
    next
  }
  writeLines(L, con_out)
  n_kept <- n_kept + 1L
  if (n_total %% 100000L == 0L)
    cat(sprintf("...stage1 %d/%d processed (kept %d)\n", n_total, 888821L, n_kept))
}
close(con_in); close(con_out)
cat(sprintf("Stage1 cleaned: %d -> %d (dropped %d)\n", n_total, n_kept, n_dropped))
stopifnot(n_dropped == length(to_drop_gsm))

# === stage2-input cleanup: rimuovi sample_ids[*] in samples[] + drop records
# che diventerebbero empty (tutti i sample ETL_LEAK_NONHUMAN appartengono
# tipicamente a uno stesso studio = il record stage2-input collassa) ===
cat("Streaming stage2-input...\n")
con_in  <- file(STAGE2_IN, "r")
con_out <- file(STAGE2_OUT, "w")
n_total <- 0L; n_kept <- 0L; n_dropped_empty <- 0L; n_samples_dropped <- 0L
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  before <- length(rec$samples)
  rec$samples <- Filter(function(s) is.null(drop_set[[s$geo_accession]]),
                        rec$samples)
  after <- length(rec$samples)
  if (after < before) n_samples_dropped <- n_samples_dropped + (before - after)
  if (after == 0L) {
    n_dropped_empty <- n_dropped_empty + 1L
    next
  }
  # Re-serialize (jsonlite::toJSON con auto_unbox=FALSE)
  out_line <- jsonlite::toJSON(rec, auto_unbox = TRUE, null = "null", na = "null")
  writeLines(as.character(out_line), con_out)
  n_kept <- n_kept + 1L
}
close(con_in); close(con_out)
cat(sprintf("Stage2-input cleaned: %d records -> %d (dropped %d empty), %d samples removed\n",
            n_total, n_kept, n_dropped_empty, n_samples_dropped))

cat("\n=== Done ===\n")
cat("Outputs:\n")
cat("  ", MASTER_OUT, "\n")
cat("  ", STAGE2_OUT, "\n")
```

- [ ] **Step 2: Eseguire**

```bash
Rscript --vanilla analysis/p4-beta-rescue-h2-cleanup.R
```

Expected:
```
Stage1 cleaned: 888821 -> 888072 (dropped 749)
Stage2-input cleaned: 39205 records -> ~39190 (dropped ~15 empty), ~500-700 samples removed
```

- [ ] **Step 3: Sanity check sui cleaned files**

```bash
wc -l analysis/p4-output/p4-beta-stage1-master-predictions-cleaned.jsonl
wc -l analysis/input/archs4-human-stage2-input-cleaned.jsonl
```

- [ ] **Step 4: Commit**

```bash
git add analysis/p4-beta-rescue-h2-cleanup.R
git commit -m "P4 β rescue Task 3 (H2): cleanup ETL non-human leak (749 sample, GSE86977)"
```

---

## Task 4: H1 prep — Build rescue input JSONL per Mode A/B stage1 fails

Estrai gli ~822 record `MODE_A_WHITESPACE` + ~few `MODE_B_LEGIT_TRUNC` + `OTHER_DEGEN` dal `archs4-human-stage1-input.jsonl` originale (le stringhe input grezze), per re-submit DGX.

**Files:**
- Create: `analysis/p4-beta-rescue-h1-build-input.R`
- Output: `analysis/input/archs4-human-stage1-rescue.jsonl` (gitignored)

- [ ] **Step 1: Scrivi build-input script**

```r
#!/usr/bin/env Rscript
# p4-beta-rescue-h1-build-input.R --- H1: estrai gli input stage1 originali
# (string metadati) per i fails Mode A/B/OTHER_DEGEN da re-submittare con
# rep_pen=1.2 + max_tokens=4096 (mirror ADR-0008 addendum rep12_maxtok2048
# escalation alpha).

suppressPackageStartupMessages({
  library(jsonlite)
})

CLASSIFIED <- "analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv"
INPUT_FULL <- "analysis/input/archs4-human-stage1-input.jsonl"
OUT        <- "analysis/input/archs4-human-stage1-rescue.jsonl"

df <- read.csv(CLASSIFIED, stringsAsFactors = FALSE)
target_gsm <- df$record_id[df$fail_mode %in% c("MODE_A_WHITESPACE",
                                                "MODE_B_LEGIT_TRUNC",
                                                "OTHER_DEGEN")]
cat(sprintf("Target rescue records: %d\n", length(target_gsm)))
target_set <- new.env(hash = TRUE, size = length(target_gsm))
for (g in target_gsm) target_set[[g]] <- TRUE

cat("Streaming input full...\n")
con_in  <- file(INPUT_FULL, "r")
con_out <- file(OUT, "w")
n_total <- 0L; n_kept <- 0L
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(target_set[[rec$record_id]])) {
    writeLines(L, con_out)
    n_kept <- n_kept + 1L
  }
  if (n_total %% 100000L == 0L)
    cat(sprintf("...%d processed, %d/%d matched\n",
                n_total, n_kept, length(target_gsm)))
}
close(con_in); close(con_out)
cat(sprintf("Rescue input emitted: %d records (expected %d)\n",
            n_kept, length(target_gsm)))
stopifnot(n_kept == length(target_gsm))
cat("Output:", OUT, "\n")
```

- [ ] **Step 2: Eseguire**

```bash
Rscript --vanilla analysis/p4-beta-rescue-h1-build-input.R
```

Expected: `Rescue input emitted: ~822 records`.

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-rescue-h1-build-input.R
git commit -m "P4 β rescue Task 4 (H1): build rescue input JSONL (~822 Mode A/B fails)"
```

---

## Task 5: H1 smoke — Submit retry su 20 sample con rep_pen=1.2 + max_tokens=4096

Smoke validation prima di full retry. 20 sample dal rescue input, sampling stratificato Mode A/B. Aspettative basate su α addendum: Mode A → 100% recovery con rep_pen=1.2; Mode B → 100% recovery con max_tokens=4096.

**Files:**
- Create: `analysis/p4-beta-rescue-h1-stage1-smoke.R`

- [ ] **Step 1: Scrivi script smoke (sampling 20 + bundle patch)**

```r
#!/usr/bin/env Rscript
# p4-beta-rescue-h1-stage1-smoke.R --- H1 smoke: 20 sample stratified retry
# con rep_pen=1.2 + max_tokens=4096 (mirror ADR-0008 escalation).

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
  library(jsonlite)
})

OUTPUT_DIR <- "analysis/p4-output"
RESCUE_IN  <- "analysis/input/archs4-human-stage1-rescue.jsonl"
SMOKE_IN   <- "analysis/input/archs4-human-stage1-rescue-smoke.jsonl"
CLASSIFIED <- "analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv"
SLUG       <- "beta-rescue-stage1-smoke20"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)

stopifnot(file.exists(RESCUE_IN), file.exists(CLASSIFIED))

# Resume gate
existing <- list.files(OUTPUT_DIR,
                       pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                       full.names = TRUE)
if (length(existing) > 0L) {
  job_rds <- existing[which.max(file.info(existing)$mtime)]
  job <- readRDS(job_rds)
  cat(sprintf("Resume: %s slurm=%s\n", job_rds, job$slurm_job_id))
  st <- tryCatch(dgx_p4_status(job),
                 error = function(e) list(slurm_state = paste0("ERROR: ", e$message)))
  cat(sprintf("slurm_state: %s\n", st$slurm_state))
  quit(status = 0L)
}

# === Build smoke subset: 15 Mode A + 5 Mode B/OTHER ===
df <- read.csv(CLASSIFIED, stringsAsFactors = FALSE)
set.seed(1812L)
gsm_A <- sample(df$record_id[df$fail_mode == "MODE_A_WHITESPACE"], 15L)
gsm_B <- sample(df$record_id[df$fail_mode %in% c("MODE_B_LEGIT_TRUNC", "OTHER_DEGEN")],
                min(5L, sum(df$fail_mode %in% c("MODE_B_LEGIT_TRUNC", "OTHER_DEGEN"))))
target_set <- new.env(hash = TRUE)
for (g in c(gsm_A, gsm_B)) target_set[[g]] <- TRUE

con_in  <- file(RESCUE_IN, "r")
con_out <- file(SMOKE_IN, "w")
n_emit <- 0L
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(target_set[[rec$record_id]])) {
    writeLines(L, con_out)
    n_emit <- n_emit + 1L
  }
}
close(con_in); close(con_out)
cat(sprintf("Smoke subset: %d records (target %d)\n", n_emit, length(gsm_A) + length(gsm_B)))

# === Build bundle + patch generation.json ===
cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(
  input_jsonl = SMOKE_IN,
  stage       = "stage1",
  config      = cfg,
  metadata    = list(slug = SLUG)
)

# Patch: max_tokens 2048 -> 4096, repetition_penalty 1.1 -> 1.2, max_model_len 4096 -> 8192
gen_path <- fs::path(bundle$bundle_dir, "generation.json")
gen <- jsonlite::read_json(gen_path)
gen$max_tokens          <- 4096L
gen$repetition_penalty  <- 1.2
gen$max_model_len       <- 8192L
jsonlite::write_json(gen, gen_path, auto_unbox = TRUE, pretty = TRUE)
cat(sprintf("Patched: max_tokens=4096, repetition_penalty=1.2, max_model_len=8192\n"))

job <- dgx_p4_submit(bundle, time = "72:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)

cat("\n=== H1 smoke20 SUBMITTED ===\n")
cat(sprintf("slurm_job_id  = %s\n", job$slurm_job_id))
cat(sprintf("run_id        = %s\n", job$run_id))
cat(sprintf("job_rds       = %s\n", job_rds))
cat(sprintf("ETA           = ~5 min wall (boot ~2min + 20 record ~1-2min)\n"))
```

- [ ] **Step 2: Eseguire (submit only, no poll)**

```bash
Rscript --vanilla analysis/p4-beta-rescue-h1-stage1-smoke.R
```

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-rescue-h1-stage1-smoke.R
git commit -m "P4 β rescue Task 5 (H1 smoke): submit 20-record retry rep_pen=1.2 maxtok=4096"
```

- [ ] **Step 4: STOP — attendi completion job (5-10 min)**

Pattern: re-source il file dopo qualche minuto per check status.

```bash
Rscript --vanilla analysis/p4-beta-rescue-h1-stage1-smoke.R   # mostra slurm_state
```

---

## Task 6: H1 smoke — Validate + GO/NO-GO decision

Collect smoke results, conta recovery rate, decide se procedere al full retry.

**Files:**
- Create: `analysis/p4-beta-rescue-h1-stage1-smoke-validate.R`

- [ ] **Step 1: Scrivi script di collect + validate**

```r
#!/usr/bin/env Rscript
# p4-beta-rescue-h1-stage1-smoke-validate.R --- collect smoke + count recovery

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

OUTPUT_DIR <- "analysis/p4-output"
SLUG       <- "beta-rescue-stage1-smoke20"

job_rds <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                      full.names = TRUE)
stopifnot(length(job_rds) >= 1L)
job <- readRDS(job_rds[which.max(file.info(job_rds)$mtime)])

st <- dgx_p4_status(job)
cat(sprintf("slurm_state: %s\n", st$slurm_state))
stopifnot(st$slurm_state %in% c("COMPLETED", "completed"))

res <- dgx_p4_collect(job)
preds <- res$predictions
errs  <- res$errors
total <- nrow(preds) + nrow(errs)
recovered <- nrow(preds)
cat(sprintf("\n=== Smoke H1 results ===\n"))
cat(sprintf("Total: %d\n", total))
cat(sprintf("Recovered (valid_schema=TRUE): %d (%.1f%%)\n", recovered, 100*recovered/total))
cat(sprintf("Still failing: %d\n", nrow(errs)))

if (recovered / total < 0.80) {
  cat("\n*** NO-GO: recovery < 80% -- investigate residual fails before full retry ***\n")
} else {
  cat(sprintf("\n*** GO: recovery %.1f%% >= 80%% -- proceed to full retry ~822 records ***\n",
              100*recovered/total))
}
```

- [ ] **Step 2: Eseguire**

```bash
Rscript --vanilla analysis/p4-beta-rescue-h1-stage1-smoke-validate.R
```

Expected: `GO` con recovery >= 90% (basato su α addendum: rep_pen=1.2 ha dato 100% sui 6 Mode A α).

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-rescue-h1-stage1-smoke-validate.R
git commit -m "P4 β rescue Task 6 (H1 smoke validate): collect + GO/NO-GO check"
```

### >>> SESSION BREAK <<<

A questo punto STOP. Nuova sessione (in linea con `feedback_validate_before_fullrun`) per il full retry.

---

## Task 7: H1 full — Submit retry full ~822 record (NUOVA SESSIONE)

**Files:**
- Create: `analysis/p4-beta-rescue-h1-stage1-full.R`

- [ ] **Step 1: Scrivi script full retry (analogo allo smoke ma SMOKE_IN → RESCUE_IN, SLUG diverso)**

```r
#!/usr/bin/env Rscript
# p4-beta-rescue-h1-stage1-full.R --- H1 FULL retry su tutti i ~822 Mode A/B
# stage1 fails con rep_pen=1.2 + max_tokens=4096.
#
# PREREQUISITE: smoke20 validato (Task 6) deve aver dato recovery >=80%.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
  library(jsonlite)
})

OUTPUT_DIR <- "analysis/p4-output"
INPUT      <- "analysis/input/archs4-human-stage1-rescue.jsonl"
SLUG       <- "beta-rescue-stage1-full"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)

stopifnot(file.exists(INPUT))

existing <- list.files(OUTPUT_DIR,
                       pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                       full.names = TRUE)
if (length(existing) > 0L) {
  job_rds <- existing[which.max(file.info(existing)$mtime)]
  job <- readRDS(job_rds)
  st <- tryCatch(dgx_p4_status(job),
                 error = function(e) list(slurm_state = paste0("ERROR: ", e$message)))
  cat(sprintf("Resume: %s slurm=%s state=%s\n",
              job_rds, job$slurm_job_id, st$slurm_state))
  quit(status = 0L)
}

cfg <- dgx_config()
n_records <- length(readLines(INPUT, warn = FALSE))
cat(sprintf("Full retry records: %d\n", n_records))

bundle <- dgx_p4_build_bundle(
  input_jsonl = INPUT,
  stage       = "stage1",
  config      = cfg,
  metadata    = list(slug = SLUG)
)
gen_path <- fs::path(bundle$bundle_dir, "generation.json")
gen <- jsonlite::read_json(gen_path)
gen$max_tokens          <- 4096L
gen$repetition_penalty  <- 1.2
gen$max_model_len       <- 8192L
jsonlite::write_json(gen, gen_path, auto_unbox = TRUE, pretty = TRUE)
cat("Patched generation.json (rep_pen=1.2, max_tokens=4096, max_model_len=8192)\n")

job <- dgx_p4_submit(bundle, time = "72:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)
cat(sprintf("\n=== H1 full SUBMITTED ===\nslurm_job_id=%s run_id=%s\n",
            job$slurm_job_id, job$run_id))
cat(sprintf("ETA: ~30-60 min wall (~822 record @ 12 rec/min steady)\n"))
```

- [ ] **Step 2: Eseguire (submit only)**

```bash
Rscript --vanilla analysis/p4-beta-rescue-h1-stage1-full.R
```

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-rescue-h1-stage1-full.R
git commit -m "P4 β rescue Task 7 (H1 full): submit ~822-record retry DGX"
```

- [ ] **Step 4: STOP — attendi completion (~30-60 min)**

Re-source dopo per status.

---

## Task 8: H1 collect + merge nel master stage1

Collect i ~822 rescued + merge nel master stage1 (post H2 cleanup) con colonna `rescue_source = "h1_rep12_maxtok4096"`.

**Files:**
- Create: `analysis/p4-beta-rescue-h1-merge.R`
- Output: `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` (gitignored)

- [ ] **Step 1: Scrivi script merge**

```r
#!/usr/bin/env Rscript
# p4-beta-rescue-h1-merge.R --- collect H1 full + merge nel master stage1 cleaned
# con rescue_source annotation.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(jsonlite)
})

OUTPUT_DIR <- "analysis/p4-output"
SLUG       <- "beta-rescue-stage1-full"
MASTER_IN  <- "analysis/p4-output/p4-beta-stage1-master-predictions-cleaned.jsonl"
MASTER_OUT <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"

job_rds <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                      full.names = TRUE)
stopifnot(length(job_rds) >= 1L)
job <- readRDS(job_rds[which.max(file.info(job_rds)$mtime)])
res <- dgx_p4_collect(job)
preds <- res$predictions  # tbl_df con record_id, raw_output, parsed_json, valid_schema, ...
cat(sprintf("H1 full collect: %d valid predictions, %d residual errors\n",
            nrow(preds), nrow(res$errors)))

# === Build map record_id -> raw_output da rescue output ===
rescue_map <- new.env(hash = TRUE, size = nrow(preds))
for (i in seq_len(nrow(preds))) {
  rescue_map[[preds$record_id[i]]] <- preds$raw_output[i]
}

# === Stream master cleaned -> output: rimpiazza raw_output dei rescued,
# aggiungi rescue_source field, mantieni gli altri come sono ===
con_in  <- file(MASTER_IN, "r")
con_out <- file(MASTER_OUT, "w")
n_total <- 0L; n_rescued <- 0L
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  new_raw <- rescue_map[[rec$record_id]]
  if (!is.null(new_raw)) {
    rec$raw_output    <- new_raw
    rec$parsed_json   <- tryCatch(jsonlite::fromJSON(new_raw, simplifyVector = FALSE),
                                  error = function(e) NULL)
    rec$rescue_source <- "h1_rep12_maxtok4096"
    n_rescued <- n_rescued + 1L
  } else {
    rec$rescue_source <- NA_character_
  }
  writeLines(as.character(jsonlite::toJSON(rec, auto_unbox = TRUE, null = "null", na = "null")),
             con_out)
}
close(con_in); close(con_out)
cat(sprintf("Master rescued: %d total records, %d rescued (%.3f%%)\n",
            n_total, n_rescued, 100*n_rescued/n_total))

# Final schema validity
con <- file(MASTER_OUT, "r")
n_total <- 0L; n_valid <- 0L
while (TRUE) {
  L <- readLines(con, n = 1L, warn = FALSE)
  if (!length(L)) break
  n_total <- n_total + 1L
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(rec$parsed_json) && !is.null(rec$parsed_json$series_id)) n_valid <- n_valid + 1L
}
close(con)
cat(sprintf("Schema validity post-rescue: %d/%d = %.3f%%\n",
            n_valid, n_total, 100*n_valid/n_total))
```

- [ ] **Step 2: Eseguire**

```bash
Rscript --vanilla analysis/p4-beta-rescue-h1-merge.R
```

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-rescue-h1-merge.R
git commit -m "P4 β rescue Task 8 (H1 merge): integrate ~822 rescued in master stage1"
```

---

## Task 9: H3 prep — Re-split 43 stage2 fails a cs25

Estrai i 43 stage2 fails dal `archs4-human-stage2-input-cleaned.jsonl`, re-splittali da cs50 a cs25 (dimezza prompt size + output budget atteso).

**Files:**
- Create: `analysis/p4-beta-rescue-h3-build-input.R`
- Output: `analysis/input/archs4-human-stage2-rescue-cs25.jsonl` (gitignored)

- [ ] **Step 1: Scrivi script H3 prep**

```r
#!/usr/bin/env Rscript
# p4-beta-rescue-h3-build-input.R --- H3: estrai i 43 stage2 fails dal
# stage2-input-cleaned + re-splitta a cs25 (half-size chunks).

suppressPackageStartupMessages({
  library(jsonlite)
})

COLLECT  <- "analysis/p4-output/20260515T175712Z-beta-stage2-fullrun-a275b0/collect.rds"
INPUT_IN <- "analysis/input/archs4-human-stage2-input-cleaned.jsonl"
OUT      <- "analysis/input/archs4-human-stage2-rescue-cs25.jsonl"

errs <- readRDS(COLLECT)$errors
fail_ids <- errs$record_id
cat(sprintf("Stage2 fails to re-split: %d\n", length(fail_ids)))
fail_set <- new.env(hash = TRUE)
for (g in fail_ids) fail_set[[g]] <- TRUE

# Stream input + estrai matching record (record_id exact match)
con_in <- file(INPUT_IN, "r")
hits <- list()
while (TRUE) {
  L <- readLines(con_in, n = 1L, warn = FALSE)
  if (!length(L)) break
  rec <- jsonlite::fromJSON(L, simplifyVector = FALSE)
  if (!is.null(fail_set[[rec$record_id]])) {
    hits[[length(hits) + 1L]] <- rec
  }
}
close(con_in)
cat(sprintf("Matched %d records in stage2-input-cleaned (expected %d)\n",
            length(hits), length(fail_ids)))

# Re-split each: chunk_size 50 -> 25 (deterministico, NO re-shuffle)
out_lines <- character(0)
n_out <- 0L
for (rec in hits) {
  samples <- rec$samples
  n <- length(samples)
  new_chunks <- ceiling(n / 25L)
  # Re-derive original_record_key + chunk_metadata
  base_key <- if (!is.null(rec$chunk_metadata$original_record_key)) {
    rec$chunk_metadata$original_record_key
  } else {
    rec$series_id
  }
  # Conta gli altri chunk gia' processati per assegnare numerazione coerente
  # Per semplicita': re-split prefisso "<record_id>--rsc<k>of<N>" cosi' non
  # collide con chunking originale di altri studi.
  for (k in seq_len(new_chunks)) {
    s_idx <- ((k-1L)*25L + 1L):min(k*25L, n)
    sub <- list(
      record_id     = paste0(rec$record_id, "--rsc", k, "of", new_chunks),
      series_id     = rec$series_id,
      study_summary = "",
      samples       = samples[s_idx]
    )
    sub$chunk_metadata <- list(
      part                = k,
      total_parts         = new_chunks,
      study_total_samples = n,
      original_record_key = rec$record_id,
      rescue_strategy     = "cs25_resplit_from_cs50"
    )
    line <- jsonlite::toJSON(sub, auto_unbox = TRUE, null = "null", na = "null")
    out_lines <- c(out_lines, as.character(line))
    n_out <- n_out + 1L
  }
}
writeLines(out_lines, OUT)
cat(sprintf("Output: %d cs25 chunks (from %d cs50 fails)\n", n_out, length(hits)))
cat("File:", OUT, "\n")
```

- [ ] **Step 2: Eseguire**

```bash
Rscript --vanilla analysis/p4-beta-rescue-h3-build-input.R
```

Expected: 43 records → ~86-100 cs25 chunks.

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-rescue-h3-build-input.R
git commit -m "P4 β rescue Task 9 (H3 prep): re-split 43 stage2 fails to cs25"
```

---

## Task 10: H3 smoke — Submit 5-chunk retry

**Files:**
- Create: `analysis/p4-beta-rescue-h3-stage2-smoke.R`

- [ ] **Step 1: Scrivi smoke script**

```r
#!/usr/bin/env Rscript
# p4-beta-rescue-h3-stage2-smoke.R --- H3 smoke: 5 cs25 chunk retry stage2.
# Stessa config stage2 (tiered_max_tokens=TRUE), unico fix = chunk_size 50->25.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
})

OUTPUT_DIR <- "analysis/p4-output"
RESCUE_IN  <- "analysis/input/archs4-human-stage2-rescue-cs25.jsonl"
SMOKE_IN   <- "analysis/input/archs4-human-stage2-rescue-cs25-smoke5.jsonl"
SLUG       <- "beta-rescue-stage2-smoke5"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)

stopifnot(file.exists(RESCUE_IN))

existing <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                       full.names = TRUE)
if (length(existing) > 0L) {
  job <- readRDS(existing[which.max(file.info(existing)$mtime)])
  st  <- tryCatch(dgx_p4_status(job),
                  error = function(e) list(slurm_state = paste0("ERROR: ", e$message)))
  cat(sprintf("Resume: slurm=%s state=%s\n", job$slurm_job_id, st$slurm_state))
  quit(status = 0L)
}

# Take first 5 lines deterministico
lines <- readLines(RESCUE_IN, warn = FALSE)
writeLines(head(lines, 5L), SMOKE_IN)
cat(sprintf("Smoke subset: 5 chunks (out of %d)\n", length(lines)))

cfg <- dgx_config()
bundle <- dgx_p4_build_bundle(
  input_jsonl       = SMOKE_IN,
  stage             = "stage2",
  config            = cfg,
  metadata          = list(slug = SLUG),
  tiered_max_tokens = TRUE
)

job <- dgx_p4_submit(bundle, time = "72:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)
cat(sprintf("\n=== H3 smoke5 SUBMITTED ===\nslurm=%s run_id=%s\n",
            job$slurm_job_id, job$run_id))
cat("ETA: ~5-10 min wall (boot ~2min + 5 cs25 chunk ~3-8min)\n")
```

- [ ] **Step 2: Eseguire**

```bash
Rscript --vanilla analysis/p4-beta-rescue-h3-stage2-smoke.R
```

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-rescue-h3-stage2-smoke.R
git commit -m "P4 β rescue Task 10 (H3 smoke): submit 5 cs25 chunk stage2 retry"
```

- [ ] **Step 4: STOP — attendi completion (~10 min)**

---

## Task 11: H3 smoke validate

**Files:**
- Create: `analysis/p4-beta-rescue-h3-stage2-smoke-validate.R`

- [ ] **Step 1: Scrivi script validate**

```r
#!/usr/bin/env Rscript
# p4-beta-rescue-h3-stage2-smoke-validate.R --- collect + count recovery

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

OUTPUT_DIR <- "analysis/p4-output"
SLUG       <- "beta-rescue-stage2-smoke5"

job_rds <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                      full.names = TRUE)
stopifnot(length(job_rds) >= 1L)
job <- readRDS(job_rds[which.max(file.info(job_rds)$mtime)])
st  <- dgx_p4_status(job)
stopifnot(st$slurm_state %in% c("COMPLETED", "completed"))

res <- dgx_p4_collect(job)
total <- nrow(res$predictions) + nrow(res$errors)
recovered <- nrow(res$predictions)
cat(sprintf("\n=== H3 smoke5 results ===\n"))
cat(sprintf("Total chunks: %d  Recovered: %d (%.1f%%)\n",
            total, recovered, 100*recovered/total))
cat(sprintf("Still failing: %d\n", nrow(res$errors)))
if (recovered / total < 0.60) {
  cat("\n*** NO-GO: recovery < 60% -- investigate o accept residuals ***\n")
} else {
  cat(sprintf("\n*** GO: recovery %.1f%% -- proceed to full ~86-100 chunk retry ***\n",
              100*recovered/total))
}
```

- [ ] **Step 2: Eseguire**

```bash
Rscript --vanilla analysis/p4-beta-rescue-h3-stage2-smoke-validate.R
```

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-rescue-h3-stage2-smoke-validate.R
git commit -m "P4 β rescue Task 11 (H3 smoke validate): GO/NO-GO check"
```

### >>> SESSION BREAK <<<

---

## Task 12: H3 full — Submit retry full (NUOVA SESSIONE)

**Files:**
- Create: `analysis/p4-beta-rescue-h3-stage2-full.R`

- [ ] **Step 1: Scrivi full retry**

```r
#!/usr/bin/env Rscript
# p4-beta-rescue-h3-stage2-full.R --- H3 FULL retry tutti i cs25 chunks
# derivati dai 43 stage2 fails.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(fs)
})

OUTPUT_DIR <- "analysis/p4-output"
INPUT      <- "analysis/input/archs4-human-stage2-rescue-cs25.jsonl"
SLUG       <- "beta-rescue-stage2-full"
fs::dir_create(OUTPUT_DIR, recurse = TRUE)

stopifnot(file.exists(INPUT))

existing <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG, "-.*-job\\.rds$"),
                       full.names = TRUE)
if (length(existing) > 0L) {
  job <- readRDS(existing[which.max(file.info(existing)$mtime)])
  st  <- tryCatch(dgx_p4_status(job),
                  error = function(e) list(slurm_state = paste0("ERROR: ", e$message)))
  cat(sprintf("Resume: slurm=%s state=%s\n", job$slurm_job_id, st$slurm_state))
  quit(status = 0L)
}

cfg <- dgx_config()
n_records <- length(readLines(INPUT, warn = FALSE))
cat(sprintf("Stage2 cs25 full retry records: %d\n", n_records))

bundle <- dgx_p4_build_bundle(
  input_jsonl       = INPUT,
  stage             = "stage2",
  config            = cfg,
  metadata          = list(slug = SLUG),
  tiered_max_tokens = TRUE
)

job <- dgx_p4_submit(bundle, time = "72:00:00")
job_rds <- file.path(OUTPUT_DIR, paste0(job$run_id, "-job.rds"))
saveRDS(job, job_rds)
cat(sprintf("\n=== H3 full SUBMITTED ===\nslurm=%s run_id=%s\n",
            job$slurm_job_id, job$run_id))
cat(sprintf("ETA: ~15-30 min wall (~100 chunks @ 5-10 chunk/min)\n"))
```

- [ ] **Step 2: Eseguire**

```bash
Rscript --vanilla analysis/p4-beta-rescue-h3-stage2-full.R
```

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-rescue-h3-stage2-full.R
git commit -m "P4 β rescue Task 12 (H3 full): submit cs25 stage2 retry DGX"
```

- [ ] **Step 4: STOP — attendi (~15-30 min)**

---

## Task 13: H3 collect + merge nel master stage2

Strategia merge: il master stage2 originale `predictions.jsonl` ha 39.162 valid + 43 errors. H3 produce `~86-100 cs25 chunks` rescued. Per ogni `original_record_key` (cs50) totalmente coperto da cs25 OK, lo marchiamo `rescue_source="h3_cs25_resplit"`. Output: nuovo file collect.rds derivato + status report.

**Files:**
- Create: `analysis/p4-beta-rescue-h3-merge.R`
- Output: `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` (gitignored)

- [ ] **Step 1: Scrivi merge script**

```r
#!/usr/bin/env Rscript
# p4-beta-rescue-h3-merge.R --- Merge cs25 rescued chunks nel master stage2.
# Logica: ogni original_record_key e' rescued solo se TUTTE le sue cs25 parts
# sono valid_schema=TRUE. Altrimenti resta nei residual.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
  library(jsonlite)
})

OUTPUT_DIR  <- "analysis/p4-output"
ORIG_COLL   <- "analysis/p4-output/20260515T175712Z-beta-stage2-fullrun-a275b0/collect.rds"
SLUG_H3     <- "beta-rescue-stage2-full"
OUT_COLL    <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"

orig <- readRDS(ORIG_COLL)
cat(sprintf("Orig collect: %d valid, %d errors\n", nrow(orig$predictions), nrow(orig$errors)))

# H3 collect
job_rds <- list.files(OUTPUT_DIR, pattern = paste0(".*-", SLUG_H3, "-.*-job\\.rds$"),
                      full.names = TRUE)
stopifnot(length(job_rds) >= 1L)
job <- readRDS(job_rds[which.max(file.info(job_rds)$mtime)])
h3 <- dgx_p4_collect(job)
cat(sprintf("H3 collect: %d valid cs25 chunks, %d errors\n",
            nrow(h3$predictions), nrow(h3$errors)))

# Map original_record_key -> all cs25 chunks (valid + invalid)
extract_orig_key <- function(rec_id) sub("--rsc.*", "", rec_id)
h3_valid_keys   <- extract_orig_key(h3$predictions$record_id)
h3_invalid_keys <- extract_orig_key(h3$errors$record_id)

# Studio key rescued solo se 0 invalid chunks per quel key
counts_invalid_per_key <- table(h3_invalid_keys)
rescued_keys <- setdiff(unique(h3_valid_keys), names(counts_invalid_per_key))
cat(sprintf("Original keys fully rescued: %d / %d\n",
            length(rescued_keys), length(orig$errors$record_id)))

# Output strategy: NEW collect con
#   predictions = orig$predictions (39.162) + rescued cs25 chunks (annotato)
#   errors      = orig$errors filtered (rimuovi i rescued_keys)
add_rescue <- function(df, rescue_tag) {
  if (!"rescue_source" %in% names(df)) df$rescue_source <- NA_character_
  df$rescue_source[is.na(df$rescue_source)] <- rescue_tag
  df
}
preds_orig <- add_rescue(orig$predictions, NA_character_)
preds_rescued <- h3$predictions[extract_orig_key(h3$predictions$record_id) %in% rescued_keys, ]
preds_rescued$rescue_source <- "h3_cs25_resplit"

preds_new <- rbind(preds_orig, preds_rescued)
errors_new <- orig$errors[!orig$errors$record_id %in% rescued_keys, ]

saveRDS(list(
  predictions = preds_new,
  errors      = errors_new,
  summary     = list(orig = orig$summary, h3_added = nrow(preds_rescued))
), OUT_COLL)
cat(sprintf("\nWritten: %s\n", OUT_COLL))
cat(sprintf("Total predictions post-H3: %d  Residual errors: %d\n",
            nrow(preds_new), nrow(errors_new)))
cat(sprintf("Schema validity: %.3f%%\n",
            100*nrow(preds_new)/(nrow(preds_new)+nrow(errors_new))))
```

- [ ] **Step 2: Eseguire**

```bash
Rscript --vanilla analysis/p4-beta-rescue-h3-merge.R
```

- [ ] **Step 3: Commit**

```bash
git add analysis/p4-beta-rescue-h3-merge.R
git commit -m "P4 β rescue Task 13 (H3 merge): integrate cs25 rescued in stage2 master"
```

---

## Task 14: Docs — ADR-0008 addendum + NEWS + CLAUDE.md update

Tracciabilità per la deviazione single-pass → rescue cascade (in linea con `feedback_pipeline_config_uniformity`).

**Files:**
- Modify: `docs/decisions/0008-vllm-sampling-defaults.md` (addendum 3)
- Modify: `NEWS.md` (entry 0.0.0.9017)
- Modify: `CLAUDE.md` (sezione "Stato corrente" + decisioni rinviate)

- [ ] **Step 1: Addendum 3 in ADR-0008**

Aggiungere in fondo al file `docs/decisions/0008-vllm-sampling-defaults.md` (dopo Links):

```markdown
## Addendum 3 2026-05-17 — β rescue cascade H1+H2+H3

P4 β fullrun completato single-pass (no rescue) lasciava 1.571 stage1 + 43
stage2 fails. Phase 1+2 debugging (systematic-debugging skill) confermava:
- 749 fail = ETL leak organism (GSE86977 mouse falsely labeled human in GEO
  upstream) — non risolvibile via sampling, drop appropriato.
- ~822 fail = Mode A residuals al nuovo ceiling max_tokens=2048 (stesso
  decoder loop `engineered_modifications[].variant` di alpha addendum 1).
- 43 stage2 fail = Mode B-style chunked output truncation in cs50 nested
  arrays (stesso pattern di α stage2 cs50 3 fails).

Cascade implementato:
- **H2**: drop 749 ETL leak da master stage1 + stage2-input. Costo zero DGX.
- **H1**: retry ~822 stage1 con `repetition_penalty=1.2` + `max_tokens=4096`
  + `max_model_len=8192`. Aspettativa basata su α addendum 1: ~100% recovery
  Mode A (6/6 α validato), ~95% recovery Mode B.
- **H3**: retry 43 stage2 con re-split cs50→cs25 (half prompt + half output).
  Aspettativa: 70-90% recovery (nuovo territorio, α non aveva applicato).

Risultato atteso:
- Stage1: 99.82% → ~99.97% schema validity
- Stage2: 99.89% → ~99.97% schema validity

Default p4-defaults.yml stage1 INVARIATO (max_tokens=2048, rep_pen=1.1) per
non rompere riproducibilita' β fullrun. Rescue config = override puntuale
nel bundle, no propagazione.
```

- [ ] **Step 2: NEWS entry**

Aggiungere in cima a `NEWS.md` (sostituire il marker più recente):

```markdown
# simulomicsr 0.0.0.9017 (P4 — β rescue cascade H1+H2+H3 complete)

## β post-fullrun rescue (Task β-16 a β-19, 2026-05-17)

- **H2 ETL cleanup** (Task β-17): drop ~749 sample ETL leak (GSE86977
  organism mislabel GEO upstream + ~3 altri) dal master stage1 + propagato a
  stage2-input. Output `*-cleaned.jsonl`. Costo zero DGX.
- **H1 stage1 retry** (Task β-18): re-run ~822 Mode A/B fails con
  `repetition_penalty=1.2` + `max_tokens=4096` + `max_model_len=8192`
  (mirror α addendum 1 ADR-0008). Recovery <FILL_FROM_TASK_8_LOG>%.
- **H3 stage2 retry** (Task β-19): re-split 43 stage2 fails cs50→cs25 +
  re-run con tier strategy. Recovery <FILL_FROM_TASK_13_LOG>%.
- Master stage1 post-rescue: <FILL_TOTAL_PREDS>/<FILL_TOTAL_AFTER_DROP> =
  <FILL_PCT>% schema validity.
- Master stage2 post-rescue: <FILL_TOTAL_PREDS>/<FILL_TOTAL_AFTER_DROP> =
  <FILL_PCT>% schema validity.
- Default `p4-defaults.yml` stage1 INVARIATO — rescue config = bundle
  override puntuale, no propagazione default.
- Riferimento spec/plan: `docs/superpowers/plans/2026-05-17-p4-beta-rescue-cascade-plan.md`.
- ADR-0008 addendum 3 documenta il cascade.
```

- [ ] **Step 3: CLAUDE.md update**

Sostituire (o aggiungere dopo) la riga "decisioni rinviate" sul retry/uniqfail
infrastructure β stage1:

```markdown
- ~~**β retry/uniqfail infrastructure pre full run**~~ **DONE 2026-05-17** —
  implementato come post-fullrun rescue cascade H1+H2+H3 (vedi NEWS 0.0.0.9017
  + ADR-0008 addendum 3 + plan
  `docs/superpowers/plans/2026-05-17-p4-beta-rescue-cascade-plan.md`).
```

E aggiornare la sezione "Stato corrente" con `tag p4-beta-rescue-complete`:

```markdown
## Stato corrente (2026-05-17 — P4 β + rescue cascade COMPLETE, tag p4-beta-rescue-complete)
```

E aggiungere alla tabella file risultato:

```markdown
- β stage1 master post-rescue: `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` (gitignored)
- β stage2 master post-rescue: `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` (gitignored)
```

- [ ] **Step 4: Commit**

```bash
git add docs/decisions/0008-vllm-sampling-defaults.md NEWS.md CLAUDE.md
git commit -m "P4 β rescue Task 14: docs (ADR-0008 add 3 + NEWS 9017 + CLAUDE.md)"
```

---

## Task 15: Final — ff-merge p4-beta-rescue → master + tag

Tag rescue chiusura cascade. Push remoto rimane all'utente (CLAUDE.md convention).

- [ ] **Step 1: Verifica clean tree + diff vs master**

```bash
git status
git log master..p4-beta-rescue --oneline
```

Expected: ~15 commits, tree clean.

- [ ] **Step 2: Test pacchetto (no regressioni)**

```bash
Rscript --vanilla -e "devtools::test()" | tail -20
```

Expected: tutti i 585 test PASS (rescue scripts non toccano R/ - solo analysis/).

- [ ] **Step 3: ff-merge in master**

```bash
git checkout master
git merge --ff-only p4-beta-rescue
```

- [ ] **Step 4: Tag**

```bash
git tag -a p4-beta-rescue-complete -m "P4 β rescue cascade H1+H2+H3 complete (stage1 99.9%+ / stage2 99.9%+)"
```

- [ ] **Step 5: Verifica**

```bash
git log --oneline -5
git tag --list 'p4-beta*'
```

**Push remoto**: rimane all'utente (CLAUDE.md "MAI fare git push").

---

## Self-Review (post-plan)

**Spec coverage:** 3 ipotesi H1/H2/H3 → 12 tasks operativi + 1 setup + 1 docs + 1 close. Coverage 100%.

**Placeholder scan:** NEWS Task 14 ha `<FILL_*>` placeholder espliciti per dati a runtime — accettabile come istruzione di compilazione tabella post-run.

**Type consistency:** `rescue_source` colonna usata coerente in Task 8 (h1_rep12_maxtok4096) e Task 13 (h3_cs25_resplit). `record_id` mantiene la suffisso `--rsc<k>of<N>` solo per H3.

**Spec gap check:** considerato di propagare H1 rescue al stage2-input rebuild? NO — i Mode A fails sono Mode A perché il modello degenera, non perché l'input è sbagliato. Recuperando questi sample in stage1, NON cambia il design dello studio cui appartengono (la maggioranza dei sample dello studio è già OK). Il loro inserimento downstream a stage2 sarebbe additivo solo se cambiasse le replicate_groups — improbabile data la natura dei fail (sample isolati in studi grandi). Trattabile post-merge come known limit minore.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-17-p4-beta-rescue-cascade-plan.md`.

Esecuzione consigliata: **inline in questa sessione** fino al primo session break (Task 6 included), poi STOP. Le DGX submission richiedono session-break per `feedback_validate_before_fullrun`.
