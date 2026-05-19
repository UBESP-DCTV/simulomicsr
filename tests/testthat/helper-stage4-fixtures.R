#' Costruisce input mock eligible_clusters + h5_metadata per i test Stage 4
#'
#' Restituisce list con:
#' - clusters: tibble Stage 3 clusters (3 cluster: 1 REM proper, 1 MEGA strict, 1 MEGA-AUG pair)
#' - h5_metadata: tibble (sample_id, gsm, gse, lib_size) con 30 sample
#' - mode "controlled fail": alcuni sample con lib_size sotto soglia
#' @keywords internal
make_test_stage4_input <- function(seed = 42L) {
  set.seed(seed)
  clusters <- tibble::tibble(
    cluster_id = c("pair_L0_aaaaaaaa", "group_L0_bbbbbbbb", "pair_L0_cccccccc"),
    mode = factor(c("pair", "group", "pair"), levels = c("pair", "group")),
    level = c(0L, 0L, 0L),
    anchor_key = c("TEST_PAIR_KEY", "TEST_GROUP_KEY", "TEST_AUG_KEY"),
    k = c(3L, 5L, 2L),
    n_total = c(18L, 30L, 12L),
    n_treated = c(9L, NA_integer_, 6L),
    n_control = c(9L, NA_integer_, 6L),
    safety_min = c(1.0, 0.8, 1.0),
    safety_geom_mean = c(1.0, 0.85, 1.0),
    usable_rem_strict = c(TRUE, FALSE, FALSE),
    usable_rem_relaxed = c(TRUE, FALSE, TRUE),
    usable_mega_strict = c(FALSE, TRUE, FALSE),
    usable_mega_relaxed = c(FALSE, TRUE, FALSE),
    direction_check = factor(c("canonical", "na", "canonical"),
                              levels = c("canonical", "swapped", "ambiguous",
                                         "indeterminate", "na")),
    n_studies = c(3L, 5L, 2L),
    studies_in_cluster = list(
      c("GSE001", "GSE002", "GSE003"),
      c("GSE001", "GSE002", "GSE003", "GSE004", "GSE005"),
      c("GSE006", "GSE007")
    )
  )

  # 7 GSE x 6 sample = 42 sample, lib_size random N(1.2e6, 4e5), alcuni sotto 500k
  gse_ids <- paste0("GSE00", 1:7)
  h5_metadata <- tibble::tibble(
    sample_id = paste0("GSM", sprintf("%06d", 1:42)),
    gsm = paste0("GSM", sprintf("%06d", 1:42)),
    gse = rep(gse_ids, each = 6),
    lib_size = pmax(50000L, as.integer(rnorm(42, mean = 1.2e6, sd = 4e5)))
  )

  list(clusters = clusters, h5_metadata = h5_metadata)
}
