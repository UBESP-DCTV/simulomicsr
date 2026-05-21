# analysis/p5-stage4-validate-cap-bigclusters.R
# Validazione end-to-end del cap baseline pool (Problema B) attraverso
# build_stage4_results. Prende i 3 cluster mega_aug PIU' GRANDI (fino a 7122
# sample non cappati) + i loro baseline pool, e gira la pipeline Stadio 4
# completa con max_baseline_per_arm=350. Verifica:
#   - build_stage4_results completa senza crash ne' OOM;
#   - i cluster grandi sono in cluster_pooled (processati, non skippati);
#   - dream gira (motore ADR-0015) e in tempi/memoria ragionevoli grazie al cap.
#
# Usage: Rscript analysis/p5-stage4-validate-cap-bigclusters.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all("."); library(cli) })
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L); RhpcBLASctl::omp_set_num_threads(1L)
}
`%||%` <- function(x, y) if (is.null(x)) y else x

cli_h1("Validazione cap baseline pool — cluster mega_aug grandi")

stage3_dir  <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
h5_path     <- "analysis/input/human_gene_v2.5.h5"
stage2_path <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"
# I 3 cluster mega_aug piu' grandi (da p5-stage4-debug-problemB-clustersize).
BIG <- c("pair_L4_25ee1af1", "pair_L3_42e11afe", "pair_L4_9349a22f")

cli_alert_info("Loading stage3 + stage2_master...")
s3 <- load_stage3(stage3_dir)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)

# Pre-filter stage2_master vs H5 (come fullrun)
h5_axis <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_set <- new.env(hash = TRUE, parent = emptyenv())
for (s in h5_axis) assign(s, TRUE, envir = h5_set)
for (st_i in seq_along(stage2_master)) {
  rgs <- stage2_master[[st_i]]$replicate_groups
  for (rg_i in seq_along(rgs)) {
    sids <- as.character(unlist(rgs[[rg_i]]$sample_ids))
    valid <- sids[vapply(sids, exists, logical(1L), envir = h5_set, inherits = FALSE)]
    stage2_master[[st_i]]$replicate_groups[[rg_i]]$sample_ids <- as.list(valid)
  }
}
rm(h5_axis, h5_set); invisible(gc(verbose = FALSE))

config <- stage4_default_config()
config$mega_aug$legacy_monodirectional <- FALSE
cli_alert_info("max_baseline_per_arm = {config$mega_aug$max_baseline_per_arm}")

# Baseline group cluster per i pick big (stesso control_anchor_key, stesso level)
parse_ck <- function(ak, lv) {
  s <- ak
  if (lv %in% c(0L, 1L)) s <- sub("__CT_[^_].*$", "", s)
  p <- strsplit(s, "__VS__", fixed = TRUE)[[1L]]
  if (length(p) != 2L) NA_character_ else p[2L]
}
cl <- s3$clusters
big_rows <- cl[cl$cluster_id %in% BIG, ]
baseline_cids <- character(0L)
for (i in seq_len(nrow(big_rows))) {
  ck <- parse_ck(big_rows$anchor_key[i], big_rows$level[i])
  if (is.na(ck)) next
  m <- cl$cluster_id[cl$mode == "group" & cl$level == big_rows$level[i] &
                       cl$anchor_key == ck]
  baseline_cids <- unique(c(baseline_cids, m))
}
keep_cids <- unique(c(BIG, baseline_cids))
clusters_subset    <- cl[cl$cluster_id %in% keep_cids, ]
assignments_subset <- s3$assignments[s3$assignments$cluster_id %in% keep_cids, ]
cli_alert_info("Subset: {nrow(clusters_subset)} clusters / {nrow(assignments_subset)} assignments")

# h5_metadata per tutti i sample referenziati
s2_idx <- new.env(hash = TRUE, parent = emptyenv())
for (st in stage2_master) if (!is.null(st$series_id)) assign(st$series_id, st, envir = s2_idx)
collect_sids <- function(record_id) {
  parts <- regmatches(record_id, regexpr("__", record_id), invert = TRUE)[[1L]]
  if (length(parts) < 2L) return(character(0L))
  ser <- parts[1L]; suf <- parts[2L]
  if (!exists(ser, envir = s2_idx, inherits = FALSE)) return(character(0L))
  st <- get(ser, envir = s2_idx, inherits = FALSE)
  rg_lookup <- setNames(st$replicate_groups,
                         vapply(st$replicate_groups, `[[`, character(1L), "group_id"))
  cmp <- NULL
  for (c in st$comparisons) if (identical(c$comparison_id, suf)) { cmp <- c; break }
  if (!is.null(cmp)) {
    tg <- rg_lookup[[cmp$treated_group]]; cg <- rg_lookup[[cmp$control_group]]
    return(c(as.character(unlist(tg$sample_ids)), as.character(unlist(cg$sample_ids))))
  }
  rg <- rg_lookup[[suf]]
  if (!is.null(rg)) return(as.character(unlist(rg$sample_ids)))
  character(0L)
}
all_samples <- unique(unlist(lapply(assignments_subset$record_id, collect_sids)))
gse_for_sid <- character(length(all_samples)); names(gse_for_sid) <- all_samples
for (st in stage2_master) for (rg in st$replicate_groups) {
  sids <- as.character(unlist(rg$sample_ids))
  hit <- intersect(sids, all_samples)
  if (length(hit) > 0L) gse_for_sid[hit] <- st$series_id
}
ok <- !(gse_for_sid == "" | is.na(gse_for_sid))
all_samples <- all_samples[ok]; gse_for_sid <- gse_for_sid[ok]
h5_metadata <- tibble::tibble(sample_id = all_samples, gsm = all_samples,
                               gse = unname(gse_for_sid), lib_size = 1e7L)
cli_alert_success("h5_metadata: {nrow(h5_metadata)} sample")

cli_h2("build_stage4_results (cluster grandi, cap attivo)")
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
cli_alert_success("build_stage4_results OK in {round(wall/60,1)} min")

cli_h2("Validazione")
cp <- result$cluster_pooled
diag <- result$qc_report$mega_aug_diagnostics %||% tibble::tibble()
for (cid in BIG) {
  n_rows <- sum(cp$cluster_id == cid)
  np <- result$non_processable
  if (n_rows > 0L) {
    cli_alert_success("{cid}: {n_rows} gene rows (processato)")
  } else {
    reason <- if (cid %in% np$cluster_id) np$reason[np$cluster_id == cid][1L] else "ASSENTE"
    cli_alert_danger("{cid}: NON processato — {reason}")
  }
}
if (nrow(diag) > 0L) {
  cli_alert_info("mega_aug_diagnostics:")
  print(as.data.frame(diag[, c("cluster_id", "comparison_kind_overall",
    "n_baseline_studies_augmented_control", "n_baseline_studies_augmented_treated",
    "bidir_collapsed_to_mono")]), row.names = FALSE)
}
cli_alert_info("cluster_pooled: {nrow(cp)} righe / {length(unique(cp$cluster_id))} cluster | metodi: {paste(sort(unique(cp$method)),collapse=',')}")
cli_alert_info("non_processable: {nrow(result$non_processable)}")
cli_h1("Validazione cap completata")
