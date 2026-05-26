test_that("read_archs4_metadata legge i campi richiesti", {
  fix <- testthat::test_path("fixtures", "archs4-mini.h5")
  meta <- read_archs4_metadata(fix)
  expect_s3_class(meta, "data.frame")
  expect_equal(nrow(meta), 4)
  # Schema v2 post-ADR-0019: 7 campi storici + 7 nuovi (6 character + 1 numeric).
  expect_named(meta, c("geo_accession", "series_id", "title", "source_name_ch1",
                        "characteristics_ch1", "organism_ch1", "library_strategy",
                        "molecule_ch1", "library_source", "extract_protocol_ch1",
                        "instrument_model", "data_processing", "relation",
                        "singlecellprobability"),
               ignore.order = TRUE)
  expect_equal(meta$geo_accession[1], "GSM001")
  expect_equal(meta$series_id[2], "GSE100,GSE101")
  # Campi nuovi character: valori plausibili sui 4 sample fixture.
  expect_equal(meta$library_source[1], "transcriptomic")
  expect_equal(meta$library_source[4], "transcriptomic single cell")
  expect_equal(meta$molecule_ch1[2], "total RNA")
  expect_true(grepl("STAR", meta$data_processing[1]))
  expect_true(grepl("10x Genomics", meta$extract_protocol_ch1[4]))
  expect_true(grepl("^BioSample: ", meta$relation[1]))
  # Campo nuovo numeric: type-check esplicito + valori.
  expect_type(meta$singlecellprobability, "double")
  expect_equal(meta$singlecellprobability[1], 0.02)
  expect_equal(meta$singlecellprobability[4], 0.95)
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
