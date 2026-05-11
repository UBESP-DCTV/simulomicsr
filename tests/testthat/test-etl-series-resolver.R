## Test per R/etl-series-resolver.R
## Copertura: entrez_lookup_gse_metadata (live API) + resolve_series_id (mock + replication gold)

# ---- helper mock cache per unit test (nessuna chiamata Entrez reale) ----
mock_cache <- list(
  "GSE100" = list(srp = NA,      is_super_series = FALSE),
  "GSE101" = list(srp = "SRP001", is_super_series = FALSE),  # ha SRP
  "GSE102" = list(srp = NA,      is_super_series = TRUE),    # SuperSeries
  "GSE103" = list(srp = "SRP002", is_super_series = FALSE),  # ha SRP 2
  "GSE104" = list(srp = NA,      is_super_series = FALSE)    # NotSuper, no SRP
)

# ---- Test 1: API live (salta se NCBI_API_KEY assente) ----

test_that("entrez_lookup_gse_metadata estrae SRP e SuperSeries pattern", {
  skip_if_not(nzchar(Sys.getenv("NCBI_API_KEY")), "NCBI_API_KEY needed")
  res <- entrez_lookup_gse_metadata("GSE177616")
  expect_type(res, "list")
  expect_true(!is.na(res$srp))
  expect_match(res$srp, "^SRP[0-9]+$")
  expect_false(res$is_super_series)
  res_super <- entrez_lookup_gse_metadata("GSE145669")
  expect_true(res_super$is_super_series)
})

# ---- Test 2: single GSE ----

test_that("resolve_series_id case 1 GSE -> input echoed", {
  out <- resolve_series_id("GSE100", mock_cache)
  expect_equal(out$decision, "GSE100")
  expect_equal(out$branch, "single_gse")
})

# ---- Test 3: SuperSeries scartata ----

test_that("resolve_series_id case 1 SuperSeries + 1 NotSuper -> NotSuper", {
  out <- resolve_series_id("GSE102,GSE100", mock_cache)
  expect_equal(out$decision, "GSE100")
  expect_equal(out$branch, "clean_super_scarted")
  out2 <- resolve_series_id("GSE100,GSE102", mock_cache)
  expect_equal(out2$decision, "GSE100")
})

# ---- Test 4: srp_a_only ----

test_that("resolve_series_id case 2 NotSuper, only SRP_a -> A", {
  out <- resolve_series_id("GSE101,GSE104", mock_cache)
  expect_equal(out$decision, "GSE101")
  expect_equal(out$branch, "srp_a_only")
})

# ---- Test 5: srp_b_only ----

test_that("resolve_series_id case 2 NotSuper, only SRP_b -> B (override lower-acc)", {
  out <- resolve_series_id("GSE104,GSE101", mock_cache)
  expect_equal(out$decision, "GSE101")
  expect_equal(out$branch, "srp_b_only")
})

# ---- Test 6: tiebreak_both_srp ----

test_that("resolve_series_id case 2 NotSuper, both SRP -> lower-acc tiebreak", {
  out <- resolve_series_id("GSE101,GSE103", mock_cache)
  expect_equal(out$decision, "GSE101")
  expect_equal(out$branch, "tiebreak_both_srp")
})

# ---- Test 7: fallback_no_srp ----

test_that("resolve_series_id case 2 NotSuper, no SRP -> lower-acc fallback", {
  out <- resolve_series_id("GSE100,GSE104", mock_cache)
  expect_equal(out$decision, "GSE100")
  expect_equal(out$branch, "fallback_no_srp")
})

# ---- Test 8: replicazione gold Exp D2 sui 23 pair ----

test_that("resolve_series_id replica esattamente Exp D2 sui 23 pair del gold", {
  # testthat esegue con wd = tests/testthat; risale alla radice del pacchetto
  pkg_root      <- rprojroot::find_package_root_file()
  ext_cache_path <- file.path(pkg_root, "analysis", "scratch",
                               "exp-d-entrez-extended.rds")
  skip_if_not(file.exists(ext_cache_path), "exp-d cache not available")

  ext <- readRDS(ext_cache_path)
  # Exp A pre-classifica tutti come NotSuper -> is_super_series = FALSE
  cache <- setNames(lapply(names(ext), function(g) {
    list(srp = ext[[g]]$srp, is_super_series = FALSE)
  }), names(ext))

  expected <- read.csv(
    file.path(pkg_root, "analysis", "scratch",
              "exp-d2-23pair-classification.csv"),
    stringsAsFactors = FALSE
  )

  for (i in seq_len(nrow(expected))) {
    si  <- paste(expected$gse_a[i], expected$gse_b[i], sep = ",")
    out <- resolve_series_id(si, cache)
    expect_equal(
      out$decision,
      expected$decision[i],
      info = sprintf("Pair %s: expected %s, got %s",
                     expected$pair_key[i], expected$decision[i], out$decision)
    )
  }
})
