test_that("studies_in_cluster + n_studies da series_id dei records", {
  cluster_records <- list(
    list(series_id = "GSE100"),
    list(series_id = "GSE100"),
    list(series_id = "GSE200"),
    list(series_id = "GSE300")
  )
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    archs4_metadata = NULL
  )
  expect_setequal(result$studies_in_cluster, c("GSE100", "GSE200", "GSE300"))
  expect_equal(result$n_studies, 3L)
})

test_that("n_distinct_donors da stage1_facts$donor (quando presente)", {
  cluster_records <- list(
    list(series_id = "GSE100", stage1_facts = list(donor = list(donor_id = "D1"))),
    list(series_id = "GSE100", stage1_facts = list(donor = list(donor_id = "D2"))),
    list(series_id = "GSE200", stage1_facts = list(donor = list(donor_id = "D1"))),  # D1 ripetuto cross-GSE
    list(series_id = "GSE200", stage1_facts = list(donor = NULL))                    # no donor info
  )
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    archs4_metadata = NULL
  )
  # D1 + D2 = 2 distinct (D1 cross-GSE collassa, NULL escluso)
  expect_equal(result$n_distinct_donors, 2L)
})

test_that("n_distinct_donors NA quando nessun record ha donor info", {
  cluster_records <- list(
    list(series_id = "GSE100", stage1_facts = list(donor = NULL)),
    list(series_id = "GSE200", stage1_facts = list(donor = NULL))
  )
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    archs4_metadata = NULL
  )
  expect_true(is.na(result$n_distinct_donors))
})

test_that("gpl_platforms enrichment quando archs4_metadata e' fornito", {
  cluster_records <- list(
    list(series_id = "GSE100"),
    list(series_id = "GSE200")
  )
  # Mock archs4_metadata: data.frame con (series_id, gpl)
  archs4_meta <- tibble::tibble(
    series_id = c("GSE100", "GSE200", "GSE300"),
    gpl       = c("GPL16791", "GPL11154", "GPL16791")
  )
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    archs4_metadata = archs4_meta
  )
  expect_setequal(result$gpl_platforms, c("GPL16791", "GPL11154"))
  expect_equal(result$n_gpl_distinct, 2L)
})

test_that("gpl_platforms = NULL/empty quando archs4_metadata NULL", {
  cluster_records <- list(
    list(series_id = "GSE100")
  )
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    archs4_metadata = NULL
  )
  expect_true(length(result$gpl_platforms) == 0L || is.na(result$n_gpl_distinct))
})
