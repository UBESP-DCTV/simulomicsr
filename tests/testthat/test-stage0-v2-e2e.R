# ============================================================================
# Stage 0 v2 cascade end-to-end — P5 audit RED_ALERT C5
# ============================================================================
# Test integration delle funzioni Stage 0 v2 (C1+C2+C3+C4) in cascata sul
# fixture archs4-mini.h5. Verifica:
# 1. coerenza tra metadata_v2 RDS (C3) e JSONL Stage 1 (C4) — stessi sample
#    sopravvissuti, stessi valori molecule_ch1.
# 2. funzionamento end-to-end del filtro Stage 0 v2 sui 4 sample fixture
#    sia attraverso build_archs4_metadata_v2 sia attraverso archs4_to_stage1_jsonl.
# 3. covariate post-LLM (aligner_class, biosample_id, lib_size,
#    singlecellprobability) tutte materializzate sui sopravvissuti.
# 4. D4 lib_size scatta in entrambi i path quando lib_size_vec piccolo.

.fixture <- function() testthat::test_path("fixtures", "archs4-mini.h5")

test_that("cascade C3+C4 - stessi sample sopravvissuti tra metadata_v2 e JSONL", {
  fix <- .fixture()
  lib_size <- c(1e7, 1e7, 1e7, 1e7)

  # C3: build metadata v2
  res_meta <- build_archs4_metadata_v2(fix, lib_size_vec = lib_size)

  # C4: build JSONL Stage 1 con stesso lib_size_vec
  jsonl_path <- tempfile(fileext = ".jsonl")
  on.exit(unlink(jsonl_path))
  res_jsonl <- archs4_to_stage1_jsonl(fix, jsonl_path, lib_size_vec = lib_size)

  # Same n_kept attraverso i due path (entrambi applicano filtro Stage 0 v2).
  expect_equal(nrow(res_meta$metadata), res_jsonl$included)
  expect_equal(res_meta$n_skipped, res_jsonl$skipped)

  # Same geo_accession sopravvissuti.
  jsonl_lines <- readLines(jsonl_path)
  jsonl_geos <- vapply(jsonl_lines, function(l) jsonlite::fromJSON(l)$geo_accession,
                        character(1L), USE.NAMES = FALSE)
  expect_setequal(jsonl_geos, res_meta$metadata$geo_accession)
})

test_that("cascade C3+C4 - molecule_ch1 coerente tra metadata_v2 e JSONL", {
  fix <- .fixture()
  lib_size <- c(1e7, 1e7, 1e7, 1e7)

  res_meta <- build_archs4_metadata_v2(fix, lib_size_vec = lib_size)
  jsonl_path <- tempfile(fileext = ".jsonl")
  on.exit(unlink(jsonl_path))
  archs4_to_stage1_jsonl(fix, jsonl_path, lib_size_vec = lib_size)

  jsonl_recs <- lapply(readLines(jsonl_path), jsonlite::fromJSON)
  for (rec in jsonl_recs) {
    meta_row <- res_meta$metadata[res_meta$metadata$geo_accession == rec$geo_accession, ]
    expect_equal(rec$molecule_ch1, meta_row$molecule_ch1,
                  info = sprintf("molecule_ch1 mismatch per %s", rec$geo_accession))
  }
})

test_that("cascade C3 - tutte le covariate post-LLM popolate sui sopravvissuti", {
  fix <- .fixture()
  res <- build_archs4_metadata_v2(fix, lib_size_vec = c(1e7, 1e7, 1e7, 1e7))
  meta <- res$metadata

  # Tutti i 2 sopravvissuti devono avere aligner_class noto (no unknown
  # per come e' popolato il fixture: GSM001=STAR, GSM002=HISAT).
  expect_true(all(as.character(meta$aligner_class) %in%
                    c("STAR", "HISAT", "Salmon", "kallisto", "RSEM",
                      "BWA", "Bowtie", "TopHat", "other")))
  # Tutti i 2 sopravvissuti devono avere biosample_id (fixture popolato).
  expect_true(all(!is.na(meta$biosample_id)))
  expect_true(all(grepl("^SAMN", meta$biosample_id)))
  # lib_size + singlecellprobability presenti.
  expect_true(all(!is.na(meta$lib_size)))
  expect_true(all(!is.na(meta$singlecellprobability)))
})

test_that("cascade C3+C4 - D4 lib_size scatta in entrambi i path coerentemente", {
  fix <- .fixture()
  # GSM001 con lib_size piccolo: D4 deve droppare in entrambi i path.
  lib_size <- c(1000L, 1e7, 1e7, 1e7)

  res_meta <- build_archs4_metadata_v2(fix, lib_size_vec = lib_size)
  jsonl_path <- tempfile(fileext = ".jsonl")
  on.exit(unlink(jsonl_path))
  res_jsonl <- archs4_to_stage1_jsonl(fix, jsonl_path, lib_size_vec = lib_size)

  # Solo GSM002 sopravvive (GSM001 D4, GSM003 organism, GSM004 strategy).
  expect_equal(res_meta$n_kept, 1L)
  expect_equal(res_jsonl$included, 1L)

  # Stesso GSM sopravvissuto.
  jsonl_geo <- jsonlite::fromJSON(readLines(jsonl_path))$geo_accession
  expect_equal(res_meta$metadata$geo_accession, "GSM002")
  expect_equal(jsonl_geo, "GSM002")
})

test_that("cascade C3+C4 - reason code drop coerenti", {
  fix <- .fixture()
  lib_size <- c(1e7, 1e7, 1e7, 1e7)
  res_meta <- build_archs4_metadata_v2(fix, lib_size_vec = lib_size)

  # GSM003 = mouse -> not_human
  # GSM004 = scRNA-Seq -> not_bulk_rnaseq
  reasons <- as.list(res_meta$skip_reasons)
  expect_equal(reasons[["not_human"]], 1L)
  expect_equal(reasons[["not_bulk_rnaseq"]], 1L)

  # Stesso skip_log via archs4_to_stage1_jsonl (con skip_log_path).
  skip_log_path <- tempfile(fileext = ".tsv")
  jsonl_path <- tempfile(fileext = ".jsonl")
  on.exit(unlink(c(skip_log_path, jsonl_path)))
  archs4_to_stage1_jsonl(fix, jsonl_path, skip_log_path = skip_log_path,
                          lib_size_vec = lib_size)
  skip_df <- read.delim(skip_log_path, sep = "\t", stringsAsFactors = FALSE)
  expect_setequal(skip_df$skip_reason, c("not_human", "not_bulk_rnaseq"))
})
