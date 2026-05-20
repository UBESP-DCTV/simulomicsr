# analysis/p5-stage4-smoke5.R
# Smoke 5-cluster pre-fullrun Stadio 4 — gate del Layer A full
#
# Wall budget: <= 10 min. Validation:
#   - cluster_pooled non vuoto (rows > 0 per ogni cluster pick)
#   - methods esercitati: "mega" + "mega_aug" (REM strict assente in questo
#     Stage 3 build — vedi nota sotto)
#   - run_metadata$run_id deterministico (8 char xxhash)
#   - write_stage4_to_dir produce i 5 file + dashboard HTML
#
# Cluster picks (smallest-n_total per ogni categoria, deterministico):
#   1. MEGA strict k=5            (group, n_studies==5,  n_total minimo)
#   2. MEGA strict n_studies>=10  (group, k>=10,         n_total minimo)
#   3. MEGA-AUG pair k=2 #1       (pair,  rem_relaxed,   n_total minimo)
#   4. MEGA-AUG pair k=2 #2       (pair,  rem_relaxed,   2o n_total minimo)
#   5. MEGA-AUG pair k=2 #3       (pair,  rem_relaxed,   3o n_total minimo)
#
# Nota gap REM strict: stage3 dir 20260519T055547Z-stage3-2153addc ha
# sum(usable_rem_strict) == 0 (verificato 2026-05-20). Il pick IFIT1 del
# plan originale (pair_L2_de50bf31 -> REM proper) e' in usable_rem_relaxed
# ma NON in usable_rem_strict, quindi Layer A v1 lo esclude come REM.
# IFIT1 golden anchor validation rimane TODO post-revisione thresholds REM.
#
# Usage:
#   Rscript analysis/p5-stage4-smoke5.R 2>&1 | tee /tmp/stage4-smoke5.log
# (NB: NO --vanilla su R 4.6.0 + renv 1.1.4 — renv lib_path corretta nel
# project, --vanilla disabilita renv e perderebbe simulomicsr/devtools libs.)

# Limita OpenBLAS thread per evitare oversubscription (default su 32-core dgx
# starta ~30 BLAS threads per ogni op, deteriora throughput per matrici piccole).
Sys.setenv(OPENBLAS_NUM_THREADS = "4", OMP_NUM_THREADS = "4")

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(dplyr)
  library(cli)
})
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(4L)
  RhpcBLASctl::omp_set_num_threads(4L)
}

# SMOKE_PICKS env var permette validazione veloce (es. "2" = solo i primi 2
# picks, ~3-5 min) prima di estendere al gate completo a 5 picks.
n_picks <- as.integer(Sys.getenv("SMOKE_PICKS", unset = "5"))
stopifnot(n_picks >= 1L, n_picks <= 5L)

stage3_dir <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
h5_path    <- "analysis/input/human_gene_v2.5.h5"
stage2_path <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"

stopifnot(dir.exists(stage3_dir), file.exists(h5_path), file.exists(stage2_path))

cli_alert_info("Loading stage3 + stage2_master...")
s3 <- load_stage3(stage3_dir)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
cli_alert_success("stage3: {.val {nrow(s3$clusters)}} clusters / {.val {nrow(s3$assignments)}} assignments; stage2_master: {.val {length(stage2_master)}} studies")

# ---- Cluster picks ---------------------------------------------------------

cl <- s3$clusters

# Pick 1: MEGA strict k=5, smallest n_total >= 10
pick1 <- cl |>
  dplyr::filter(mode == "group", usable_mega_strict, n_studies == 5L,
                 n_total >= 10L) |>
  dplyr::arrange(n_total) |>
  dplyr::slice(1L) |>
  dplyr::pull(cluster_id)

# Pick 2: MEGA strict n_studies>=10, smallest n_total
pick2 <- cl |>
  dplyr::filter(mode == "group", usable_mega_strict, n_studies >= 10L) |>
  dplyr::arrange(n_total) |>
  dplyr::slice(1L) |>
  dplyr::pull(cluster_id)

# Pick 3-5: MEGA-AUG pair k=2, smallest n_total (3 distinct)
pick345 <- cl |>
  dplyr::filter(mode == "pair", k == 2L, usable_rem_relaxed) |>
  dplyr::arrange(n_total, cluster_id) |>
  dplyr::slice(1:3) |>
  dplyr::pull(cluster_id)

# Ordine picks: mega_aug small first (~12 sample, dream veloce) per validare
# il path gap-fix critical, poi mega (33-30 sample, dream piu' lento).
pick_ids <- c(pick345, pick1, pick2)
stopifnot(length(pick_ids) == 5L, !anyNA(pick_ids))
pick_ids <- pick_ids[seq_len(n_picks)]
cli_alert_info("SMOKE_PICKS={n_picks} -> {.val {length(pick_ids)}} cluster picks selezionati")

cli_alert_info("Smoke 5 cluster picks:")
for (i in seq_along(pick_ids)) {
  cli_li("{.field {i}}: {pick_ids[i]}")
}

# ---- Subset stage3 outputs + build h5_metadata -----------------------------

clusters_subset <- s3$clusters[s3$clusters$cluster_id %in% pick_ids, ]
assignments_subset <- s3$assignments[s3$assignments$cluster_id %in% pick_ids, ]

cli_alert_info("Subset: {.val {nrow(clusters_subset)}} clusters / {.val {nrow(assignments_subset)}} assignments")

# Costruisci h5_metadata minimo per i sample referenziati dai picks. Per il
# baseline pool MEGA-AUG dobbiamo includere TUTTI i sample dei group cluster
# che condividono l'anchor_key parsato (control_anchor_key) — risolto a
# build-time da .enrich_group_baseline_sample_ids, ma h5_metadata QC deve
# coprire anche quelli, altrimenti vengono droppati. Aggiungiamo i sample
# di OGNI group cluster allo stesso livello L che condivide anchor_key con
# i pair_L_*__VS__... dei picks.

# 1. sample IDs dai picks via assignments + stage2_master
s2_idx <- new.env(hash = TRUE, parent = emptyenv())
for (st in stage2_master) {
  if (!is.null(st$series_id)) assign(st$series_id, st, envir = s2_idx)
}
collect_sids <- function(record_id) {
  parts <- regmatches(record_id, regexpr("__", record_id), invert = TRUE)[[1L]]
  if (length(parts) < 2L) return(character(0L))
  ser <- parts[1L]; suf <- parts[2L]
  if (!exists(ser, envir = s2_idx, inherits = FALSE)) return(character(0L))
  st <- get(ser, envir = s2_idx, inherits = FALSE)
  rg_lookup <- setNames(st$replicate_groups,
                         vapply(st$replicate_groups, `[[`, character(1L),
                                "group_id"))
  cmp <- NULL
  for (c in st$comparisons) if (identical(c$comparison_id, suf)) { cmp <- c; break }
  if (!is.null(cmp)) {
    tg <- rg_lookup[[cmp$treated_group]]; cg <- rg_lookup[[cmp$control_group]]
    return(c(as.character(unlist(tg$sample_ids)),
             as.character(unlist(cg$sample_ids))))
  }
  rg <- rg_lookup[[suf]]
  if (!is.null(rg)) return(as.character(unlist(rg$sample_ids)))
  character(0L)
}

picked_samples <- unique(unlist(lapply(assignments_subset$record_id, collect_sids)))
cli_alert_info("Sample IDs dai picks: {.val {length(picked_samples)}}")

# 2. Per i MEGA-AUG picks, identifica baseline group cluster con stesso
#    control_anchor_key allo stesso level, e includi i loro sample IDs.
parse_ck <- function(anchor_key, level) {
  s <- anchor_key
  if (level %in% c(0L, 1L)) s <- sub("__CT_[^_].*$", "", s)
  p <- strsplit(s, "__VS__", fixed = TRUE)[[1L]]
  if (length(p) != 2L) NA_character_ else p[2L]
}

pair_picks <- clusters_subset[clusters_subset$mode == "pair", ]
baseline_cids <- character(0L)
for (i in seq_len(nrow(pair_picks))) {
  ck <- parse_ck(pair_picks$anchor_key[i], pair_picks$level[i])
  if (is.na(ck)) next
  match_rows <- cl[cl$mode == "group" &
                     cl$level == pair_picks$level[i] &
                     cl$anchor_key == ck, ]
  baseline_cids <- unique(c(baseline_cids, match_rows$cluster_id))
}
cli_alert_info("Baseline group cluster matchati per MEGA-AUG picks: {.val {length(baseline_cids)}}")

# Includi assignments + sample dei baseline nel subset (per dispatch + h5_metadata)
baseline_assignments <- s3$assignments[s3$assignments$cluster_id %in% baseline_cids, ]
baseline_samples <- unique(unlist(lapply(baseline_assignments$record_id, collect_sids)))
cli_alert_info("Sample IDs baseline: {.val {length(baseline_samples)}}")

all_samples <- unique(c(picked_samples, baseline_samples))
cli_alert_info("Sample IDs totali (picks + baseline): {.val {length(all_samples)}}")

# 3. Subset stage3_clusters + stage3_assignments per coprire baseline cluster
#    (necessario per .enrich_group_baseline_sample_ids al build-time).
clusters_subset <- s3$clusters[
  s3$clusters$cluster_id %in% c(pick_ids, baseline_cids), ]
assignments_subset <- s3$assignments[
  s3$assignments$cluster_id %in% c(pick_ids, baseline_cids), ]
cli_alert_info("Subset esteso: {.val {nrow(clusters_subset)}} clusters / {.val {nrow(assignments_subset)}} assignments")

# 4. h5_metadata minimo: tutti i sample con lib_size=1e7 (placeholder sopra
#    soglia QC). Il sample_id mappa a se stesso come gsm; gse via stage2.
h5_metadata <- tibble::tibble(
  sample_id = all_samples,
  gsm       = all_samples,
  gse       = vapply(all_samples, function(sid) {
    for (st in stage2_master) {
      for (rg in st$replicate_groups) {
        if (sid %in% as.character(unlist(rg$sample_ids))) return(st$series_id)
      }
    }
    NA_character_
  }, character(1L)),
  lib_size  = 1e7L
)
cli_alert_info("h5_metadata: {.val {nrow(h5_metadata)}} sample (lib_size placeholder 1e7)")
stopifnot(!anyNA(h5_metadata$gse))

# ---- Build Stage 4 results -------------------------------------------------

config <- stage4_default_config()
# Attiva MEGA-AUG bidirezionale (T5/T21). Override del default conservativo
# legacy_monodirectional=TRUE finche' il flip a FALSE non viene fatto post-
# smoke verde. Il smoke serve proprio a validare end-to-end il bidir flow.
config$mega_aug$legacy_monodirectional <- FALSE
cli_alert_info("MEGA-AUG mode: bidirezionale (anchor_policy={config$mega_aug$anchor_policy}, direction={config$mega_aug$direction})")

cli_alert_info("Building Stage 4 results...")
t0 <- Sys.time()
result <- build_stage4_results(
  stage3_clusters    = clusters_subset,
  h5_metadata        = h5_metadata,
  config             = config,
  h5_path            = h5_path,
  stage3_run_id      = s3$run_metadata$run_id,
  h5_path_for_hash   = h5_path,
  stage3_assignments = assignments_subset,
  stage2_master      = stage2_master
)
wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cli_alert_success("build_stage4_results done in {round(wall, 1)} sec")

# ---- Validation gate -------------------------------------------------------

cli_alert_info("Smoke gate validation:")
cli_li("run_id: {result$run_metadata$run_id}")
stopifnot(nchar(result$run_metadata$run_id) == 8L)

cli_li("cluster_pooled rows: {nrow(result$cluster_pooled)}")
stopifnot(nrow(result$cluster_pooled) > 0L)

methods_observed <- sort(unique(result$cluster_pooled$method))
cli_li("methods observed: {paste(methods_observed, collapse=', ')}")
# Picks 1-3 -> mega_aug; picks 4-5 -> mega. Validation method-aware.
if (n_picks >= 1L) stopifnot("mega_aug" %in% methods_observed)
if (n_picks >= 4L) stopifnot("mega" %in% methods_observed)

# Verifica ogni pick e' (a) in cluster_pooled con n_rows>0 OPPURE (b) in
# qc_drops_cluster con un motivo valido (mega_rank_deficient,
# mega_aug_disjoint_strict_skipped, ...). Issue #1 handoff rilassato:
# il fix #2 fullrun introduce skip intenzionale di cluster rank-deficient
# e il bidir disjoint_policy="strict" introduce un nuovo skip.
qc_drops_cluster <- result$qc_report$qc_drops_cluster %||% tibble::tibble()
mega_aug_diag    <- result$qc_report$mega_aug_diagnostics %||% tibble::tibble()

n_processed <- 0L; n_skipped <- 0L
for (cid in pick_ids) {
  n_rows <- sum(result$cluster_pooled$cluster_id == cid)
  if (n_rows > 0L) {
    cli_li("{cid}: {n_rows} gene rows in cluster_pooled (processed)")
    n_processed <- n_processed + 1L
  } else {
    # Cerca in qc_drops_cluster
    drop_row <- qc_drops_cluster[qc_drops_cluster$cluster_id == cid, ]
    if (nrow(drop_row) >= 1L) {
      cli_li("{cid}: SKIPPED with reason '{drop_row$reason[1L]}'")
      stopifnot(grepl("^(mega_rank_deficient|mega_aug_disjoint_strict_skipped)",
                       drop_row$reason[1L]))
      n_skipped <- n_skipped + 1L
    } else {
      stop(sprintf("Pick %s NON e' in cluster_pooled NE' in qc_drops_cluster", cid))
    }
  }
}
cli_alert_info("Picks summary: processed={n_processed} / skipped={n_skipped} / total={length(pick_ids)}")
stopifnot(n_processed >= 1L)  # almeno 1 cluster deve essere processato per gate validation

# Diagnostica bidir per pair pick (MEGA-AUG)
if (nrow(mega_aug_diag) > 0L) {
  cli_alert_info("MEGA-AUG bidir diagnostics ({nrow(mega_aug_diag)} cluster):")
  for (i in seq_len(nrow(mega_aug_diag))) {
    cli_li(sprintf(
      "  %s: overall=%s | ctrl=%s (n_aug=%d, pool=%s) | trt=%s (n_aug=%d, pool=%s)",
      mega_aug_diag$cluster_id[i],
      mega_aug_diag$comparison_kind_overall[i],
      mega_aug_diag$comparison_kind_control[i] %||% "NA",
      mega_aug_diag$n_baseline_studies_augmented_control[i],
      mega_aug_diag$baseline_pool_id_control[i],
      mega_aug_diag$comparison_kind_treated[i] %||% "NA",
      mega_aug_diag$n_baseline_studies_augmented_treated[i],
      mega_aug_diag$baseline_pool_id_treated[i]
    ))
  }
} else {
  cli_alert_warning("MEGA-AUG bidir diagnostics VUOTO -- atteso non vuoto in bidir mode con pair picks")
}

# ---- Write smoke output + dashboard ---------------------------------------

smoke_dir <- file.path(
  "analysis/p4-output",
  sprintf("%s-stage4-smoke5-%s",
          format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC"),
          result$run_metadata$run_id)
)
cli_alert_info("Writing to {smoke_dir}")
write_stage4_to_dir(result, smoke_dir)

cli_alert_info("Rendering dashboard...")
render_stage4_dashboard(smoke_dir)

cli_alert_success("Smoke 5 OK — output in {.path {smoke_dir}}")
