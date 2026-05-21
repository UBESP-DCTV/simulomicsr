# analysis/p5-stage4-debug-problemA2-crosspool.R
# DEBUGGING Problema A — SECONDA causa (cross-pool sample overlap).
# Lo scan ha trovato 7 cluster mega_aug con sample_id duplicati MA con
# baseline pool DIVERSI per i due bracci. Ipotesi: il control pool e il
# treated pool sono cluster group distinti che condividono GSM (stesso
# sample in replicate_group assegnati a cluster diversi — duplicazione
# ARCHS4 super-series). Questo script verifica il meccanismo sui 7.
#
# Usa il checkpoint salvato da p5-stage4-debug-scan-all-mega-aug.R (veloce).
# Usage: Rscript analysis/p5-stage4-debug-problemA2-crosspool.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all("."); library(cli) })
`%||%` <- function(x, y) if (is.null(x)) y else x

cli_h1("Problema A2 — verifica cross-pool sample overlap")
ck <- readRDS("analysis/p5-stage4-debug-checkpoint.rds")
elig <- ck$elig; study_dispatch <- ck$study_dispatch
stage3_enriched <- ck$stage3_enriched; config <- ck$config
matcher <- make_anchor_matcher(policy = config$mega_aug$anchor_policy,
                                relaxed_segments = config$mega_aug$relaxed_segments)

# I 7 cluster cross-pool individuati dallo scan
targets <- c("pair_L3_69f2fe8e", "pair_L3_86228e27", "pair_L3_9e9a4909",
             "pair_L3_a426870b", "pair_L4_48af5658", "pair_L4_6155f541",
             "pair_L4_ab580ca6")

for (cid in targets) {
  cli_h2("Cluster {cid}")
  i <- which(elig$cluster_id == cid)
  parsed_key <- simulomicsr:::.parse_pair_anchor_key(elig$anchor_key[i], level = elig$level[i])
  de <- study_dispatch[[cid]]
  pcs <- list(
    cluster_id = cid, level = elig$level[i], anchor_key = elig$anchor_key[i],
    treated_anchor_key = parsed_key$treated, control_anchor_key = parsed_key$control,
    studies_in_cluster = elig$studies_in_cluster[[i]],
    treated_samples = list(unlist(lapply(de, function(d) d$treated))),
    control_samples = list(unlist(lapply(de, function(d) d$control))),
    treated_sample_studies = list(unlist(lapply(de, function(d) rep(d$study_id, length(d$treated))))),
    control_sample_studies = list(unlist(lapply(de, function(d) rep(d$study_id, length(d$control))))))
  gb <- stage3_enriched[stage3_enriched$mode == "group" &
                          stage3_enriched$level == elig$level[i], ]

  # candidate ranking — replica orchestrator: top per arm
  pair_tbl <- tibble::tibble(cluster_id = cid, level = elig$level[i],
                              anchor_key = elig$anchor_key[i])
  cands <- find_baseline_for_pair(pair_tbl, gb, matcher, direction = "both",
                                   min_baseline_studies = config$mega_aug$min_baseline_studies)
  top_c <- NULL; top_t <- NULL
  for (cnd in cands) {
    if (cnd$arm == "control" && is.null(top_c)) top_c <- cnd
    if (cnd$arm == "treated" && is.null(top_t)) top_t <- cnd
  }
  bp_c <- top_c$baseline_cluster_id %||% NA
  bp_t <- top_t$baseline_cluster_id %||% NA
  cli_alert_info("top control pool = {bp_c} | top treated pool = {bp_t}")

  # sample_ids dei due pool (da stage3_enriched)
  sids_c <- if (!is.na(bp_c)) unlist(gb$sample_ids[gb$cluster_id == bp_c]) else character()
  sids_t <- if (!is.na(bp_t)) unlist(gb$sample_ids[gb$cluster_id == bp_t]) else character()
  shared <- intersect(sids_c, sids_t)
  cli_alert_info("pool control: {length(sids_c)} sample | pool treated: {length(sids_t)} sample")
  cli_alert_info("sample CONDIVISI tra i due pool: {length(shared)}")
  if (length(shared) > 0L) {
    cli_alert_danger("primi 5 condivisi: {paste(head(shared,5), collapse=', ')}")
    # ogni shared sample compare in QUALI replicate_group/studio?
    for (s in head(shared, 3L)) {
      in_c <- gb$cluster_id[vapply(gb$sample_ids, function(x) s %in% unlist(x), logical(1L))]
      cat(sprintf("    %s -> presente nei group cluster: %s\n", s,
                  paste(in_c, collapse = ", ")))
    }
  }
}
cli_h1("Verifica A2 completata")
