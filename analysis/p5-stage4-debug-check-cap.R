# Check rapido: il cap max_baseline_per_arm applica davvero?
# Per i 3 cluster grandi, nrow(metadata) con cap=NA vs cap=350.
suppressPackageStartupMessages({ devtools::load_all("."); library(cli) })
`%||%` <- function(x, y) if (is.null(x)) y else x
ck <- readRDS("analysis/p5-stage4-debug-checkpoint.rds")
elig <- ck$elig; study_dispatch <- ck$study_dispatch
stage3_enriched <- ck$stage3_enriched; config <- ck$config
matcher <- make_anchor_matcher(policy = config$mega_aug$anchor_policy,
                                relaxed_segments = config$mega_aug$relaxed_segments)
for (cid in c("pair_L3_42e11afe", "pair_L4_25ee1af1", "pair_L4_9349a22f")) {
  i <- which(elig$cluster_id == cid)
  pk <- simulomicsr:::.parse_pair_anchor_key(elig$anchor_key[i], level = elig$level[i])
  de <- study_dispatch[[cid]]
  pcs <- list(
    cluster_id = cid, level = elig$level[i], anchor_key = elig$anchor_key[i],
    treated_anchor_key = pk$treated, control_anchor_key = pk$control,
    studies_in_cluster = elig$studies_in_cluster[[i]],
    treated_samples = list(unlist(lapply(de, function(d) d$treated))),
    control_samples = list(unlist(lapply(de, function(d) d$control))),
    treated_sample_studies = list(unlist(lapply(de, function(d) rep(d$study_id, length(d$treated))))),
    control_sample_studies = list(unlist(lapply(de, function(d) rep(d$study_id, length(d$control))))))
  gb <- stage3_enriched[stage3_enriched$mode == "group" &
                          stage3_enriched$level == elig$level[i], ]
  n_pair <- length(pcs$treated_samples[[1]]) + length(pcs$control_samples[[1]])
  a_na  <- simulomicsr:::.assemble_mega_aug_metadata_bidir(pcs, gb, matcher,
            direction = "both", min_baseline_studies = 2L, max_baseline_per_arm = NA_integer_)
  a_350 <- simulomicsr:::.assemble_mega_aug_metadata_bidir(pcs, gb, matcher,
            direction = "both", min_baseline_studies = 2L, max_baseline_per_arm = 350L)
  cli_alert_info("{cid}: pair={n_pair} | metadata cap=NA -> {nrow(a_na$metadata)} | cap=350 -> {nrow(a_350$metadata)} | studi cap=350 -> {nlevels(a_350$metadata$study)}")
}
