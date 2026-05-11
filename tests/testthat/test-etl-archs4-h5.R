test_that("read_archs4_metadata legge i campi richiesti", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  meta <- read_archs4_metadata(fix)
  expect_s3_class(meta, "data.frame")
  expect_equal(nrow(meta), 4)
  expect_named(meta, c("geo_accession", "series_id", "title", "source_name_ch1",
                        "characteristics_ch1", "organism_ch1", "library_strategy"),
               ignore.order = TRUE)
  expect_equal(meta$geo_accession[1], "GSM001")
  expect_equal(meta$series_id[2], "GSE100,GSE101")
})

test_that("archs4_to_stage1_jsonl emette JSONL con filtri applicati", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  out <- tempfile(fileext = ".jsonl")
  res <- archs4_to_stage1_jsonl(fix, out)
  expect_s3_class(res, "list")
  expect_true("included" %in% names(res))
  expect_true("skipped" %in% names(res))
  # GSM001 + GSM002 = passano (human + RNA-Seq + string >= 20).
  # GSM003 = mouse, skippato.
  # GSM004 = scRNA-Seq + string short, skippato.
  expect_equal(res$included, 2L)
  expect_equal(res$skipped, 2L)
  # Verifica JSONL content
  lines <- readLines(out)
  expect_equal(length(lines), 2L)
  rec1 <- jsonlite::fromJSON(lines[1])
  expect_equal(rec1$geo_accession, "GSM001")
  expect_true(grepl("^title: MCF7 tam 24h,source: MCF7,", rec1$string))
})
