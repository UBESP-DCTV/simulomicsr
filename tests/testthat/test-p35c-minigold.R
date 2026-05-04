.mock_gse_tiers <- function() {
  tibble::tibble(
    series_id = c(paste0("GSE_E", 1:10), paste0("GSE_H", 1:10)),
    confidence_score = c(rep(0.95, 10), rep(0.4, 10)),
    tier = c(rep("easy", 10), rep("hard", 10))
  )
}

.mock_samples <- function() {
  # 5 sample per ogni GSE
  tidyr::expand_grid(
    series_id = c(paste0("GSE_E", 1:10), paste0("GSE_H", 1:10)),
    sample_idx = 1:5
  ) |>
    dplyr::mutate(
      geo_accession = paste0(series_id, "_GSM", sample_idx),
      string = paste("fake string for", geo_accession)
    ) |>
    dplyr::select(geo_accession, series_id, string)
}

test_that("sample_minigold_stratified: 50/50 easy/hard", {
  set.seed(1812)
  out <- sample_minigold_stratified(
    gse_tiers = .mock_gse_tiers(),
    samples_table = .mock_samples(),
    target_n = 100L,
    min_gse_per_tier = 5L
  )
  expect_equal(nrow(out), 100L)
  expect_equal(sum(out$tier == "easy"), 50L)
  expect_equal(sum(out$tier == "hard"), 50L)
})

test_that("sample_minigold_stratified: distribuisce su almeno min_gse_per_tier", {
  set.seed(1812)
  out <- sample_minigold_stratified(
    gse_tiers = .mock_gse_tiers(),
    samples_table = .mock_samples(),
    target_n = 100L,
    min_gse_per_tier = 5L
  )
  easy_gse <- length(unique(out$series_id[out$tier == "easy"]))
  hard_gse <- length(unique(out$series_id[out$tier == "hard"]))
  expect_gte(easy_gse, 5L)
  expect_gte(hard_gse, 5L)
})

test_that("sample_minigold_stratified e' deterministico col seed", {
  set.seed(1812)
  out1 <- sample_minigold_stratified(
    gse_tiers = .mock_gse_tiers(),
    samples_table = .mock_samples(),
    target_n = 50L,
    min_gse_per_tier = 5L
  )
  set.seed(1812)
  out2 <- sample_minigold_stratified(
    gse_tiers = .mock_gse_tiers(),
    samples_table = .mock_samples(),
    target_n = 50L,
    min_gse_per_tier = 5L
  )
  expect_equal(out1$geo_accession, out2$geo_accession)
})

test_that("sample_minigold_stratified: solleva se non ci sono abbastanza GSE per un tier", {
  small <- tibble::tibble(
    series_id = c("GSE_E1", "GSE_H1"),
    confidence_score = c(0.95, 0.4),
    tier = c("easy", "hard")
  )
  expect_error(
    sample_minigold_stratified(
      gse_tiers = small,
      samples_table = .mock_samples()[1:5, ],
      target_n = 100L,
      min_gse_per_tier = 5L
    ),
    class = "simulomicsr_minigold_insufficient_gse"
  )
})
