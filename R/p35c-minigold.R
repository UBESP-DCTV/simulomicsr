#' Sampling stratificato per mini-gold design-aware
#'
#' Estrae N sample distribuiti 50/50 easy/hard, con almeno `min_gse_per_tier`
#' GSE distinti per tier (per evitare di studiare un singolo GSE anomalo).
#' Algoritmo: per ogni tier, seleziona min_gse_per_tier GSE casuali, e
#' campiona uniformemente i sample fino a target_n / 2.
#'
#' Errori tipizzati:
#' - `simulomicsr_minigold_insufficient_gse` se un tier ha meno di
#'   min_gse_per_tier GSE.
#'
#' @param gse_tiers tibble con colonne `series_id`, `confidence_score`, `tier`
#' @param samples_table tibble con `geo_accession`, `series_id`, `string`
#'   (tutti i sample candidati)
#' @param target_n totale sample (50/50 easy/hard)
#' @param min_gse_per_tier minimo numero GSE distinti da coprire per tier
#'
#' @return tibble con colonne geo_accession, series_id, string, tier,
#'   confidence_score
#'
#' @export
sample_minigold_stratified <- function(gse_tiers,
                                       samples_table,
                                       target_n = 100L,
                                       min_gse_per_tier = 15L) {
  stopifnot(target_n %% 2L == 0L)
  per_tier_n <- target_n %/% 2L

  out <- list()
  for (t in c("easy", "hard")) {
    pool <- gse_tiers[gse_tiers$tier == t, ]
    if (nrow(pool) < min_gse_per_tier) {
      rlang::abort(
        sprintf("Tier '%s' ha solo %d GSE (richiesti almeno %d).",
                t, nrow(pool), min_gse_per_tier),
        class = "simulomicsr_minigold_insufficient_gse",
        tier = t, n_gse = nrow(pool)
      )
    }
    # Garantisce copertura minima selezionando prima i GSE "seed",
    # poi campiona uniformemente da tutti i sample del tier.
    seed_gse <- pool$series_id[sample.int(nrow(pool), min_gse_per_tier)]
    all_gse <- pool$series_id
    samples_pool <- samples_table[samples_table$series_id %in% all_gse, ]
    take <- min(nrow(samples_pool), per_tier_n)
    # Garantisce che i seed_gse siano inclusi: prima prende un sample per GSE seed,
    # poi riempie il resto con campionamento uniforme dal pool residuo.
    seed_samples <- samples_pool[samples_pool$series_id %in% seed_gse, ]
    seed_picked_idx <- sample.int(nrow(seed_samples), min(nrow(seed_samples), take))
    seed_picked <- seed_samples[seed_picked_idx, ]
    residual_pool <- samples_pool[!(samples_pool$geo_accession %in% seed_picked$geo_accession), ]
    n_residual <- take - nrow(seed_picked)
    if (n_residual > 0 && nrow(residual_pool) > 0) {
      res_idx <- sample.int(nrow(residual_pool), min(nrow(residual_pool), n_residual))
      picked <- rbind(seed_picked, residual_pool[res_idx, ])
    } else {
      picked <- seed_picked
    }
    picked$tier <- t
    picked <- dplyr::left_join(
      picked,
      gse_tiers[, c("series_id", "confidence_score")],
      by = "series_id"
    )
    out[[t]] <- picked
  }
  dplyr::bind_rows(out)
}
