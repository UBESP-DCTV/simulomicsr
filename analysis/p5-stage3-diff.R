#!/usr/bin/env Rscript
# analysis/p5-stage3-diff.R
#
# Diff comparison Stage 3 v3 (baseline 2026-05-19) vs v3.1 (post-ontology-override)
# (ADR-0018, plan 2026-05-25 Sessione S2 Task 7).
#
# Usage: Rscript analysis/p5-stage3-diff.R <new_stage3_dir>
#   <new_stage3_dir>: path della directory generata da p5-stage3-rebuild-v31.R
#
# Output:
#   - stdout: tabelle riassunto
#   - docs/findings/<DATE>-stage3-v31-diff.md: report paper-grade

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

suppressPackageStartupMessages({
  library(dplyr); library(tibble); library(cli)
  devtools::load_all(".", quiet = TRUE)
})

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) {
  stop("Usage: Rscript analysis/p5-stage3-diff.R <new_stage3_dir>")
}
new_dir <- args[[1L]]
old_dir <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"

stopifnot(dir.exists(new_dir), dir.exists(old_dir))

cli_h1("Loading Stage 3 baseline vs v3.1")
cli_alert_info("old: {old_dir}")
cli_alert_info("new: {new_dir}")

old <- readRDS(file.path(old_dir, "clusters.rds"))
new <- readRDS(file.path(new_dir, "clusters.rds"))

cli_alert_success("old clusters: {nrow(old)}")
cli_alert_success("new clusters: {nrow(new)}")

# ----------------- Aggregate stats per mode x level -----------------
cli_h2("Aggregate counts per mode x level")
old_mxl <- old |>
  count(mode, level, name = "n_old")
new_mxl <- new |>
  count(mode, level, name = "n_new")
mxl <- full_join(old_mxl, new_mxl, by = c("mode", "level")) |>
  mutate(delta = n_new - n_old,
         delta_pct = round(100 * (n_new - n_old) / n_old, 1))
print(mxl)

# ----------------- Resolution source distribution (NEW only) -----------------
cli_h2("resolution_source distribution (new v3.1)")
if (!"resolution_source" %in% names(new)) {
  cli_alert_danger("Colonna resolution_source assente in new clusters.rds! Aborting diff.")
  quit(status = 1L)
}

res_src <- new |>
  count(resolution_source, sort = TRUE) |>
  mutate(pct = round(100 * n / sum(n), 2))
print(res_src, n = 50)

# ----------------- kind_overridden % per kind_effective -----------------
cli_h2("kind_overridden distribution")
if (!"kind_overridden" %in% names(new)) {
  cli_alert_danger("Colonna kind_overridden assente.")
} else {
  ko_summary <- new |>
    summarise(
      n_total = n(),
      n_overridden = sum(kind_overridden, na.rm = TRUE),
      pct_overridden = round(100 * sum(kind_overridden, na.rm = TRUE) / n(), 2)
    )
  print(ko_summary)

  cli_alert_info("Override reason breakdown:")
  ovr_rs <- new |>
    filter(kind_overridden) |>
    count(kind_override_reason, sort = TRUE) |>
    mutate(pct = round(100 * n / sum(n), 2))
  print(ovr_rs)
}

# ----------------- v3.1.1: kind_chebi_zero_roles flag -------------------
if ("kind_chebi_zero_roles" %in% names(new)) {
  cli_h2("v3.1.1 flag: kind_chebi_zero_roles distribution")
  zr_summary <- new |>
    summarise(
      n_total = n(),
      n_zero_roles = sum(kind_chebi_zero_roles, na.rm = TRUE),
      pct_zero_roles = round(100 * sum(kind_chebi_zero_roles, na.rm = TRUE) / n(), 2)
    )
  print(zr_summary)

  cli_alert_info("Top kind_effective per flag kind_chebi_zero_roles=TRUE:")
  zr_kinds <- new |>
    filter(kind_chebi_zero_roles) |>
    count(kind_effective_resolved, sort = TRUE)
  print(head(zr_kinds, 10))
}

# ----------------- Audit 4 critically wrong Layer B cases -----------------
cli_h2("Audit 4 critically wrong Layer B cases (old -> new)")

target_old_ids <- c(
  "pair_L4_25ee1af1",   # Carnitine (CHEBI:17126) - LLM=pathogen
  "pair_L4_875da822",   # dihydroxyphthalic (CHEBI:17199) - LLM=pathogen
  "pair_L4_8feddd0d",   # Ethanol (CHEBI:16236) - LLM=cytokine_stim
  "pair_L4_6a3ba59f"    # Pregnanetriol (MeSH:D011279) - LLM=disease_vs_normal
)

old_targets <- old |>
  filter(cluster_id %in% target_old_ids) |>
  select(cluster_id, anchor_key, mode, level, k, n_total)

cli_alert_info("OLD:")
print(old_targets)

# Estrai agent_id_resolved + kind dal pattern atteso e cerca i match nel new
target_specs <- list(
  list(agent = "CHEBI:17126", tissue = "blood",    label = "Carnitine"),
  list(agent = "CHEBI:17199", tissue = "blood",    label = "dihydroxyphthalic"),
  list(agent = "CHEBI:16236", tissue = "skin",     label = "Ethanol"),
  list(agent = "MeSH:D011279",tissue = "prostate", label = "Pregnanetriol")
)

cli_alert_info("NEW (matched by agent_id_resolved + tissue + mode=pair + level=4):")
for (sp in target_specs) {
  cli_text("---")
  cli_alert_info("Target: {sp$label} ({sp$agent}, tissue={sp$tissue})")
  matches <- new |>
    filter(mode == "pair", level == 4L,
           agent_id_resolved == sp$agent,
           grepl(sp$tissue, anchor_key, ignore.case = TRUE))
  if (nrow(matches) == 0L) {
    cli_alert_warning("  No exact match. Try fallback by agent only:")
    matches <- new |>
      filter(agent_id_resolved == sp$agent) |>
      head(5)
  }
  if (nrow(matches) > 0L) {
    print(
      matches |>
        select(cluster_id, mode, level, anchor_key,
               kind_effective_llm_original, kind_effective_resolved,
               kind_overridden, kind_override_reason,
               agent_id_llm_original, resolution_source,
               canonical_name, k, n_total) |>
        head(5)
    )
  } else {
    cli_alert_danger("  ZERO matches in new clusters!")
  }
}

# ----------------- Tracking column completeness check -----------------
cli_h2("Tracking columns completeness")
new_tracking <- c("agent_id_llm_original", "agent_id_resolved", "resolution_source",
                  "kind_effective_llm_original", "kind_effective_resolved",
                  "kind_overridden", "kind_override_reason", "canonical_name")
missing_cols <- setdiff(new_tracking, names(new))
if (length(missing_cols) > 0L) {
  cli_alert_danger("Missing tracking columns: {paste(missing_cols, collapse=', ')}")
} else {
  cli_alert_success("All 8 main tracking columns present.")
}

# ----------------- Markdown report -----------------
cli_h2("Generating markdown report")

today <- format(Sys.Date(), "%Y-%m-%d")
report_path <- sprintf("docs/findings/%s-stage3-v31-diff.md", today)

new_meta <- jsonlite::fromJSON(file.path(new_dir, "run_metadata.json"),
                                simplifyVector = TRUE)
old_meta <- jsonlite::fromJSON(file.path(old_dir, "run_metadata.json"),
                                simplifyVector = TRUE)

md <- c(
  sprintf("# Stage 3 v3 -> v3.1 diff report (%s)", today),
  "",
  sprintf("**Old:** `%s` (run_id `%s`, anchor `%s`)",
          old_dir, old_meta$run_id, old_meta$schema_versions$anchor),
  sprintf("**New:** `%s` (run_id `%s`, anchor `%s`)",
          new_dir, new_meta$run_id, new_meta$schema_versions$anchor),
  "",
  "## 1. Aggregate counts",
  "",
  knitr::kable(mxl, format = "markdown"),
  "",
  "## 2. resolution_source distribution (new)",
  "",
  knitr::kable(res_src, format = "markdown"),
  "",
  "## 3. kind_overridden",
  ""
)
if (exists("ko_summary")) {
  md <- c(md, knitr::kable(ko_summary, format = "markdown"), "")
  if (exists("ovr_rs") && nrow(ovr_rs) > 0L) {
    md <- c(md, "### Override reason breakdown", "", knitr::kable(ovr_rs, format = "markdown"), "")
  }
}
md <- c(md,
  "## 4. Layer B critically wrong: before vs after",
  "",
  knitr::kable(old_targets, format = "markdown"),
  ""
)

dir.create(dirname(report_path), showWarnings = FALSE, recursive = TRUE)
writeLines(md, report_path)
cli_alert_success("Report written: {report_path}")
