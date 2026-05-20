# Esplorazione: quanti pair Layer A hanno baseline pool effettivamente
# augmentante (sample non sovrapposti) vs baseline 100% sovrapposto al pair?
#
# Risposta empirica alla discovery dello smoke 5-pick 2026-05-20:
# 3/3 pair smallest n_total avevano baseline 100% overlapped.
#
# Output: tabella distribuzione coverage per i 345 pair Layer A.
#
# Wall budget: <= 5 min.

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(dplyr)
  library(cli)
})

s3_dir <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
stage2_path <- "analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds"

cli_alert_info("Loading stage3 + stage2_master...")
s3 <- load_stage3(s3_dir)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)

# Subset Layer A
cl <- s3$clusters
layer_a_pair <- cl[cl$mode == "pair" & cl$k == 2L & cl$usable_rem_relaxed, ]
layer_a_group <- cl[cl$mode == "group" & cl$usable_mega_strict & cl$n_studies >= 5L, ]
# Group baseline pool eligibili per match (n_studies >= 2 e' il filtro bidir):
all_groups <- cl[cl$mode == "group", ]
cli_alert_info("Pair Layer A k=2: {nrow(layer_a_pair)}; group totale (qualsiasi n): {nrow(all_groups)}")

# Enrich con sample_ids + sample_studies per i group (richiesto per
# determinare overlap reale a livello sample)
enriched_groups <- simulomicsr:::.enrich_group_baseline_sample_ids(
  all_groups, s3$assignments, stage2_master
)

# Per ogni pair, costruisci il set di sample del pair e cerca il top
# baseline pool candidate sul control_anchor con anchor_policy=relaxed,
# poi misura n_sample_baseline_unique (post-dedup vs pair samples).
matcher <- make_anchor_matcher(policy = "relaxed")

# Helper: estrai sample del pair (treated + control) via assignments
s2_idx <- new.env(hash = TRUE, parent = emptyenv())
for (st in stage2_master) {
  if (!is.null(st$series_id)) assign(st$series_id, st, envir = s2_idx)
}
extract_pair_samples <- function(pair_row, assignments) {
  rids <- assignments$record_id[assignments$cluster_id == pair_row$cluster_id]
  sids <- character(0L)
  for (rid in rids) {
    parsed <- simulomicsr:::.split_record_id(rid)
    if (is.na(parsed$series_id)) next
    if (!exists(parsed$series_id, envir = s2_idx, inherits = FALSE)) next
    study <- get(parsed$series_id, envir = s2_idx, inherits = FALSE)
    rg_lookup <- setNames(study$replicate_groups,
                           vapply(study$replicate_groups, `[[`,
                                   character(1L), "group_id"))
    cmp <- NULL
    for (c in study$comparisons) {
      if (identical(c$comparison_id, parsed$suffix)) { cmp <- c; break }
    }
    if (!is.null(cmp)) {
      tg <- rg_lookup[[cmp$treated_group]]; cg <- rg_lookup[[cmp$control_group]]
      sids <- c(sids, as.character(unlist(tg$sample_ids)),
                       as.character(unlist(cg$sample_ids)))
    }
  }
  unique(sids)
}

# Iter sui pair Layer A — limit a un sample stratificato per velocita'
N_SAMPLE <- 50L  # subset rapido per esplorazione; estensione completa = ~345
set.seed(42L)
sample_idx <- sort(sample(nrow(layer_a_pair), min(N_SAMPLE, nrow(layer_a_pair))))
pair_subset <- layer_a_pair[sample_idx, ]
cli_alert_info("Esplorazione su {nrow(pair_subset)} pair (random sample seed=42)")

# Pre-parse di tutti i group anchor
group_parsed <- vector("list", nrow(enriched_groups))
for (i in seq_len(nrow(enriched_groups))) {
  group_parsed[[i]] <- tryCatch(
    parse_anchor_canonical(enriched_groups$anchor_key[i],
                             level = enriched_groups$level[i]),
    error = function(e) NULL
  )
}

# Iter
results <- vector("list", nrow(pair_subset))
for (k in seq_len(nrow(pair_subset))) {
  pair_row <- pair_subset[k, ]
  pair_samples <- extract_pair_samples(pair_row, s3$assignments)
  pair_studies <- pair_row$studies_in_cluster[[1L]]

  parsed_pair <- tryCatch(
    parse_pair_anchor_key(pair_row$anchor_key, pair_row$level),
    error = function(e) NULL
  )
  if (is.null(parsed_pair)) {
    results[[k]] <- list(cluster_id = pair_row$cluster_id, status = "parse_fail")
    next
  }

  # Cerca tutti i group baseline candidati sullo stesso level + match control
  # ranking top per n_studies desc
  best_ctrl_id <- NA_character_
  best_ctrl_overlap_sids <- 0L
  best_ctrl_extra_sids   <- 0L
  best_ctrl_baseline_n   <- 0L
  best_ctrl_studies_extra <- 0L

  idx <- which(enriched_groups$level == pair_row$level &
                 enriched_groups$n_studies >= 2L)
  for (j in idx) {
    gp <- group_parsed[[j]]
    if (is.null(gp)) next
    if (!matcher(parsed_pair$control, gp)) next
    bs_sids    <- enriched_groups$sample_ids[[j]]
    bs_studies <- enriched_groups$studies_in_cluster[[j]]
    extra_sids <- length(setdiff(bs_sids, pair_samples))
    if (extra_sids > best_ctrl_extra_sids ||
          (is.na(best_ctrl_id) && extra_sids == 0L)) {
      best_ctrl_id <- enriched_groups$cluster_id[j]
      best_ctrl_overlap_sids <- length(intersect(bs_sids, pair_samples))
      best_ctrl_extra_sids   <- extra_sids
      best_ctrl_baseline_n   <- length(bs_sids)
      best_ctrl_studies_extra <- length(setdiff(bs_studies, pair_studies))
    }
  }
  if (best_ctrl_baseline_n == 0L && is.na(best_ctrl_id)) {
    # Nessun match — il pair non e' augmentable
    results[[k]] <- list(cluster_id = pair_row$cluster_id,
                          status = "no_match",
                          baseline_n = 0L, extra_sids = 0L)
  } else {
    results[[k]] <- list(
      cluster_id          = pair_row$cluster_id,
      status              = "match",
      baseline_id         = best_ctrl_id,
      baseline_n_total    = best_ctrl_baseline_n,
      overlap_sids        = best_ctrl_overlap_sids,
      extra_sids          = best_ctrl_extra_sids,
      extra_studies       = best_ctrl_studies_extra
    )
  }
}

# Summary
df <- do.call(rbind, lapply(results, function(r) {
  data.frame(
    cluster_id   = r$cluster_id,
    status       = r$status,
    baseline_n   = if ("baseline_n_total" %in% names(r)) r$baseline_n_total else 0L,
    extra_sids   = if ("extra_sids" %in% names(r)) r$extra_sids else 0L,
    extra_studies = if ("extra_studies" %in% names(r)) r$extra_studies else 0L,
    stringsAsFactors = FALSE
  )
}))

cli_alert_success("Esplorazione completata su {nrow(df)} pair")
cat("\n=== Status distribution ===\n")
print(table(df$status))

cat("\n=== Extra sample distribution (post-dedup vs pair) ===\n")
cat("  0 extra (100% sovrapposto): ", sum(df$extra_sids == 0L & df$status == "match"), "\n")
cat("  1-5 extra              : ", sum(df$extra_sids >= 1L & df$extra_sids <= 5L), "\n")
cat("  6-20 extra             : ", sum(df$extra_sids >= 6L & df$extra_sids <= 20L), "\n")
cat("  21-100 extra           : ", sum(df$extra_sids >= 21L & df$extra_sids <= 100L), "\n")
cat("  > 100 extra            : ", sum(df$extra_sids > 100L), "\n")

cat("\nMedian extra sids (match status):", median(df$extra_sids[df$status == "match"]), "\n")
cat("Mean   extra sids (match status):", round(mean(df$extra_sids[df$status == "match"]), 1), "\n")

cat("\n=== Extra studies (baseline che aggiungono studi nuovi) ===\n")
cat("  0 extra studies (sample da stessi studi del pair):", sum(df$extra_studies == 0L & df$status == "match"), "\n")
cat("  >= 1 extra studies (cross-study augmentation):", sum(df$extra_studies >= 1L), "\n")

cat("\n=== Sample con augmentation effettiva (extra_sids > 0) ===\n")
print(head(df[df$extra_sids > 0L & df$status == "match", ], 10))

cat("\n=== Fraction stimata di pair con augmentation effettiva nel registry ===\n")
n_aug <- sum(df$extra_sids > 0L & df$status == "match")
cat(sprintf("  %d / %d nel sample (%.1f%%) -> proiezione su %d Layer A pair ~ %d-%d con augmentation effettiva\n",
             n_aug, nrow(df), 100 * n_aug / nrow(df),
             nrow(layer_a_pair),
             round(0.9 * nrow(layer_a_pair) * n_aug / nrow(df)),
             round(1.1 * nrow(layer_a_pair) * n_aug / nrow(df))))

saveRDS(df, "analysis/p4-output/p5-mega-aug-coverage-explore.rds")
cat("\nSaved to: analysis/p4-output/p5-mega-aug-coverage-explore.rds\n")
