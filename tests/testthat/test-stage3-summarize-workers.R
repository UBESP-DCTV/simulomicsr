# LA FASE PIU' LENTA DEL RE-CLUSTER, A PEZZI.
#
# `summarize_clusters` ha preso 8 h 15 m sulle 9 h 21 m del re-cluster v16
# (l'88%) e gira su un core solo: un `for` su 322.417 cluster indipendenti. Il
# corpo del ciclo non ha effetti collaterali -- legge e restituisce una riga --
# quindi si puo' dividere fra piu' worker con `fork`, che non rifa' le fasi
# precedenti e tiene la memoria di base condivisa.
#
# LA CONDIZIONE: il risultato dev'essere IDENTICO, non equivalente. Con
# `mc.preschedule = TRUE` i blocchi sono contigui e l'ordine e' conservato.

.sw_fixture <- function(n_cluster = 6L) {
  set.seed(42)
  cids <- sprintf("cgroup_L5_%02d", seq_len(n_cluster))
  assignments <- do.call(rbind, lapply(seq_along(cids), function(i) {
    data.frame(cluster_id = cids[i], mode = "cgroup", level = 5L,
               anchor_key = paste0("k", i),
               record_id = sprintf("GSE%d__cmp%d", i, 1:3),
               stringsAsFactors = FALSE)
  }))
  recs <- list()
  for (i in seq_along(cids)) for (j in 1:3) {
    rid <- sprintf("GSE%d__cmp%d", i, j)
    segs <- c(kind = "cytokine_stim", agent = paste0("HGNC:", i))
    attr(segs, "tracking_meta") <- list(canonical_name = paste0("ent", i))
    recs[[rid]] <- list(record_id = rid, mode = "cgroup", series_id = sprintf("GSE%d", i),
                        treated_anchor_segments = segs,
                        n_treated_group = 3L, n_control_group = 3L,
                        treated_sample_ids = sprintf("S%d_%d_t", i, 1:3),
                        control_sample_ids = sprintf("S%d_%d_c", i, 1:3),
                        hard_filters = list(), stage1_facts = list())
  }
  list(assignments = assignments, eligible = recs)
}

test_that("in serie e a pezzi il risultato e' IDENTICO", {
  f <- .sw_fixture(6L)
  cfg <- stage3_default_config()
  a <- .summarize_clusters(f$assignments, list(), list(), cfg, NULL,
                           eligible_cgroup = f$eligible, workers = 1L)
  b <- .summarize_clusters(f$assignments, list(), list(), cfg, NULL,
                           eligible_cgroup = f$eligible, workers = 3L)
  expect_identical(a, b)
  expect_equal(nrow(a), 6L)
})

test_that("l'ORDINE dei cluster non cambia col numero di pezzi", {
  f <- .sw_fixture(11L)   # numero primo: i blocchi non si dividono tondi
  cfg <- stage3_default_config()
  a <- .summarize_clusters(f$assignments, list(), list(), cfg, NULL,
                           eligible_cgroup = f$eligible, workers = 1L)
  for (w in c(2L, 4L, 8L)) {
    b <- .summarize_clusters(f$assignments, list(), list(), cfg, NULL,
                             eligible_cgroup = f$eligible, workers = w)
    expect_identical(a$cluster_id, b$cluster_id, info = paste("workers =", w))
    expect_identical(a, b, info = paste("workers =", w))
  }
})

test_that("il default resta il comportamento di sempre", {
  f <- .sw_fixture(4L)
  cfg <- stage3_default_config()
  expect_identical(
    .summarize_clusters(f$assignments, list(), list(), cfg, NULL,
                        eligible_cgroup = f$eligible),
    .summarize_clusters(f$assignments, list(), list(), cfg, NULL,
                        eligible_cgroup = f$eligible, workers = 1L))
})
