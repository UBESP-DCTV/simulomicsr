test_that("load_rummageo_index parsa cassetta mock con SuperSeries", {
  fixture_path <- testthat::test_path("fixtures", "rummageo-index-mock.json")
  result <- .parse_rummageo_index_response(
    jsonlite::read_json(fixture_path, simplifyVector = FALSE)
  )
  expect_s3_class(result, "tbl_df")
  expect_setequal(result$gse,
                  c("GSE100001", "GSE100002", "GSE100003", "GSE100004"))
  expect_equal(nrow(result), 4L)
  expect_equal(result$n_signatures[result$gse == "GSE100002"], 3L)
})

test_that("load_rummageo_index usa cache se presente", {
  tmp_dir <- withr::local_tempdir()
  fixture_path <- testthat::test_path("fixtures", "rummageo-index-mock.json")
  fixture_data <- jsonlite::read_json(fixture_path, simplifyVector = FALSE)
  parsed <- .parse_rummageo_index_response(fixture_data)
  jsonlite::write_json(parsed, file.path(tmp_dir, "rummageo-index.json"),
                       auto_unbox = TRUE)
  result <- load_rummageo_index(cache_dir = tmp_dir, api_base = "http://localhost:0")
  expect_equal(nrow(result), 4L)
})

test_that("keyword_design_kind_proxy classifica esempi rappresentativi", {
  cases <- list(
    list(string = "si-GAPDH knockdown HEK293",       expected = "knockdown_panel"),
    list(string = "+Dox induced shRNA TP53",         expected = "knockdown_panel"),
    list(string = "0Gy sham 10Gy irradiation MCF7",  expected = "treatment_vs_untreated"),
    list(string = "DMSO vehicle trametinib 1uM",     expected = "treatment_vs_vehicle"),
    list(string = "0h 6h 24h time course",           expected = "time_course"),
    list(string = "glioblastoma patient healthy normal", expected = "disease_vs_normal"),
    list(string = "conditioned media transwell coculture bystander", expected = "mediated_effect"),
    list(string = "WT mouse TP53 -/- knockout mouse", expected = "knockout_vs_wt"),
    list(string = "+drug +siRNA factorial",          expected = "factorial"),
    list(string = "random nondescript",              expected = "unknown")
  )
  for (case in cases) {
    expect_equal(
      keyword_design_kind_proxy(case$string),
      case$expected,
      info = paste("Failed on:", case$string)
    )
  }
})

test_that("keyword_design_kind_proxy applica priorita' factorial > altri", {
  expect_equal(
    keyword_design_kind_proxy("+drug +siRNA factorial DMSO vehicle 0h 6h 24h"),
    "factorial"
  )
})

test_that("keyword_design_kind_proxy e' vectorized", {
  strings <- c("si-GAPDH", "DMSO vehicle drug", "random")
  expected <- c("knockdown_panel", "treatment_vs_vehicle", "unknown")
  expect_equal(keyword_design_kind_proxy(strings), expected)
})

test_that("intersect_with_xlsx_and_archs4 produce intersect corretta", {
  rummageo_idx <- tibble::tibble(
    gse = c("GSE_A", "GSE_B", "GSE_C", "GSE_NOT_IN_XLSX"),
    n_signatures = c(2L, 2L, 2L, 5L)
  )
  xlsx_df <- tibble::tibble(
    geo_accession = c("GSM_A1", "GSM_A2", "GSM_B1", "GSM_C1", "GSM_D1"),
    series_id = c("GSE_A", "GSE_A", "GSE_B", "GSE_C", "GSE_D"),
    string = c("a", "a", "b", "c", "d"),
    trtctr_EP = c("treated", "control", "treated", "control", "treated")
  )
  archs4_studies <- c("GSE_A", "GSE_B", "GSE_NOT_IN_XLSX")
  pool <- intersect_with_xlsx_and_archs4(rummageo_idx, xlsx_df, archs4_studies)
  expect_setequal(pool$gse, c("GSE_A", "GSE_B"))
  expect_true(all(c("gse", "n_signatures", "n_samples_xlsx",
                    "in_archs4") %in% names(pool)))
  expect_equal(pool$n_samples_xlsx[pool$gse == "GSE_A"], 2L)
})

test_that("intersect_with_xlsx_and_archs4 con archs4_studies = NULL ammette tutto", {
  rummageo_idx <- tibble::tibble(gse = c("GSE_A", "GSE_B"), n_signatures = c(2L, 2L))
  xlsx_df <- tibble::tibble(
    geo_accession = c("GSM_A1", "GSM_B1"),
    series_id = c("GSE_A", "GSE_B"),
    string = c("a", "b"),
    trtctr_EP = c("treated", "treated")
  )
  pool <- intersect_with_xlsx_and_archs4(rummageo_idx, xlsx_df,
                                          archs4_studies = NULL)
  expect_setequal(pool$gse, c("GSE_A", "GSE_B"))
  expect_true(all(is.na(pool$in_archs4)))
})

test_that("stratified_sample_gse rispetta target distribution con seed", {
  set.seed(NULL)
  pool <- tibble::tibble(
    gse = sprintf("GSE%05d", 1:200),
    design_kind_proxy = c(
      rep("factorial", 20),
      rep("time_course", 20),
      rep("mediated_effect", 5),
      rep("treatment_vs_vehicle", 50),
      rep("knockdown_panel", 30),
      rep("disease_vs_normal", 30),
      rep("treatment_vs_untreated", 25),
      rep("unknown", 20)
    ),
    n_signatures = sample.int(20L, 200L, replace = TRUE),
    n_samples_xlsx = sample.int(40L, 200L, replace = TRUE)
  )
  target <- c(
    factorial = 15L, time_course = 15L, mediated_effect = 10L,
    treatment_vs_vehicle = 20L, knockdown_panel = 15L,
    disease_vs_normal = 15L, treatment_vs_untreated = 10L
  )
  result_1 <- stratified_sample_gse(pool, target, seed = 1812L)
  result_2 <- stratified_sample_gse(pool, target, seed = 1812L)
  expect_equal(result_1$gse, result_2$gse)
  expect_equal(nrow(result_1), 100L)
  expect_equal(sum(result_1$design_kind_proxy == "factorial"), 15L)
  expect_equal(sum(result_1$design_kind_proxy == "mediated_effect"), 5L)
  expect_equal(sum(result_1$design_kind_proxy == "treatment_vs_vehicle"), 25L)
})

test_that("stratified_sample_gse non usa unknown nella stratificazione", {
  pool <- tibble::tibble(
    gse = sprintf("GSE%05d", 1:50),
    design_kind_proxy = c(rep("factorial", 30), rep("unknown", 20)),
    n_signatures = 10L,
    n_samples_xlsx = 10L
  )
  target <- c(factorial = 10L)
  result <- stratified_sample_gse(pool, target, seed = 1812L)
  expect_equal(nrow(result), 10L)
  expect_true(all(result$design_kind_proxy == "factorial"))
})
