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

test_that("export_minigold_csv produce file con header atteso e righe per ogni sample", {
  pool <- tibble::tibble(
    geo_accession = c("GSE1_GSM1", "GSE1_GSM2"),
    series_id     = c("GSE1", "GSE1"),
    string        = c("s1", "s2"),
    tier          = c("easy", "easy"),
    confidence_score = c(0.95, 0.95)
  )
  study_summaries <- list(GSE1 = list(title = "T1", summary = "S1"))
  multi_outputs <- list(GSE1 = list(
    model_a = list(
      design_kind = "treatment_vs_vehicle",
      replicate_groups = list(
        list(group_id = "g1", design_role = "perturbed",  sample_ids = list("GSE1_GSM1")),
        list(group_id = "g2", design_role = "vehicle_control", sample_ids = list("GSE1_GSM2"))
      )
    ),
    model_b = list(
      design_kind = "case_control_disease",
      replicate_groups = list(
        list(group_id = "g1", design_role = "case", sample_ids = list("GSE1_GSM1")),
        list(group_id = "g2", design_role = "comparison", sample_ids = list("GSE1_GSM2"))
      )
    )
  ))
  dest <- tempfile(fileext = ".csv")
  export_minigold_csv(pool, study_summaries, multi_outputs, dest)

  csv <- readr::read_csv(dest, show_col_types = FALSE)
  expect_setequal(
    colnames(csv),
    c("geo_accession","series_id","string","study_title","study_summary",
      "study_overview",
      "design_role_proposed_models","design_kind_proposed_models",
      "design_role_gold","design_kind_gold","comment_optional","tier")
  )
  expect_equal(nrow(csv), 2L)
  expect_match(csv$design_role_proposed_models[1], "model_a=perturbed")
  expect_match(csv$design_role_proposed_models[1], "model_b=case")
  expect_true(all(is.na(csv$design_role_gold)))
  # study_overview: per-studio, mostra TUTTI i sample con i ruoli proposti
  # da ogni modello (multi-line stringa)
  expect_match(csv$study_overview[1], "GSE1_GSM1: model_a=perturbed; model_b=case")
  expect_match(csv$study_overview[1], "GSE1_GSM2: model_a=vehicle_control; model_b=comparison")
  # Ordinamento: righe ordinate per (series_id, geo_accession)
  expect_equal(csv$geo_accession, sort(csv$geo_accession))
})

test_that("import_minigold_reviewed valida colonne richieste e tipi", {
  good <- tibble::tibble(
    geo_accession = c("X1", "X2"),
    series_id     = c("S1", "S1"),
    string        = c("a", "b"),
    study_title   = c("T", "T"),
    study_summary = c("S", "S"),
    study_overview = c("X1: a=x", "X2: a=x"),
    design_role_proposed_models = c("a=x", "b=y"),
    design_kind_proposed_models = c("a=x", "b=y"),
    design_role_gold = c("perturbed", "vehicle_control"),
    design_kind_gold = c("treatment_vs_vehicle", "treatment_vs_vehicle"),
    comment_optional = c("", ""),
    tier = c("easy", "easy")
  )
  csv_path <- tempfile(fileext = ".csv")
  readr::write_csv(good, csv_path)

  out <- import_minigold_reviewed(csv_path)
  expect_equal(nrow(out), 2L)
  expect_true("design_role_gold" %in% colnames(out))
})

test_that("import_minigold_reviewed solleva se design_role_gold contiene un valore fuori vocabolario", {
  bad <- tibble::tibble(
    geo_accession = "X", series_id = "S", string = "s",
    study_title = "t", study_summary = "u",
    study_overview = "",
    design_role_proposed_models = "", design_kind_proposed_models = "",
    design_role_gold = "perturbatore_inventato",  # NON nei 13 valori
    design_kind_gold = "treatment_vs_vehicle",
    comment_optional = "", tier = "easy"
  )
  csv_path <- tempfile(fileext = ".csv")
  readr::write_csv(bad, csv_path)
  expect_error(
    import_minigold_reviewed(csv_path),
    class = "simulomicsr_minigold_invalid_value"
  )
})

test_that("import_minigold_reviewed accetta righe con design_kind_gold NA (review parziale)", {
  partial <- tibble::tibble(
    geo_accession = c("X1"), series_id = c("S1"), string = "s",
    study_title = "t", study_summary = "u",
    study_overview = "",
    design_role_proposed_models = "", design_kind_proposed_models = "",
    design_role_gold = "perturbed",
    design_kind_gold = NA_character_,
    comment_optional = "", tier = "easy"
  )
  csv_path <- tempfile(fileext = ".csv")
  readr::write_csv(partial, csv_path)
  expect_no_error(out <- import_minigold_reviewed(csv_path))
  expect_equal(nrow(out), 1L)
})

test_that("eval_against_minigold ritorna tibble vuoto se multi_classify_outputs e' vuoto", {
  reviewed <- tibble::tibble(
    geo_accession = "X1", series_id = "S1",
    design_role_gold = "perturbed", tier = "easy"
  )
  out <- eval_against_minigold(reviewed, multi_classify_outputs = list())
  expect_s3_class(out, "tbl_df")
  expect_equal(nrow(out), 0L)
  expect_setequal(colnames(out), c("model", "tier", "n", "n_correct", "accuracy"))
})

test_that("eval_against_minigold calcola accuracy per modello e per tier", {
  reviewed <- tibble::tibble(
    geo_accession = c("X1", "X2", "X3", "X4"),
    series_id     = c("S1", "S1", "S2", "S2"),
    design_role_gold = c("perturbed", "vehicle_control", "case", "comparison"),
    tier = c("easy", "easy", "hard", "hard")
  )
  multi_outputs <- list(
    S1 = list(
      model_a = list(replicate_groups = list(
        list(design_role = "perturbed",       sample_ids = list("X1")),
        list(design_role = "vehicle_control", sample_ids = list("X2"))
      ))
    ),
    S2 = list(
      model_a = list(replicate_groups = list(
        list(design_role = "perturbed",       sample_ids = list("X3")),  # WRONG (gold=case)
        list(design_role = "comparison",      sample_ids = list("X4"))
      ))
    )
  )

  acc <- eval_against_minigold(reviewed, multi_outputs)
  # Per model_a: 3/4 corretti -> accuracy 0.75; easy 2/2; hard 1/2
  row_overall <- acc[acc$model == "model_a" & acc$tier == "overall", ]
  expect_equal(row_overall$accuracy, 0.75)
  row_easy <- acc[acc$model == "model_a" & acc$tier == "easy", ]
  expect_equal(row_easy$accuracy, 1.0)
  row_hard <- acc[acc$model == "model_a" & acc$tier == "hard", ]
  expect_equal(row_hard$accuracy, 0.5)
})
