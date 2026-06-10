# Test TDD per l'aggancio del completeness guard Stadio 2 nel path Stadio 3
# (RED ALERT FASE F4 Step 2). Il guard `complete_stage2_coverage`
# (R/stage2-normalize.R) esisteva ma era scollegato.
#
# Master a un record per studio (invariante opzione C, ADR-0020): il guard gira
# PER-STUDIO: ogni sample di input non assegnato a un replicate_group viene
# raccolto in un gruppo sintetico primary_role='unclear'.

mk_stage2_input_line <- function(record_id, gsms, series_id = NULL) {
  jsonlite::toJSON(
    list(
      record_id = record_id,
      series_id = series_id %||% sub("(#|--).*$", "", record_id),
      study_summary = "",
      samples   = lapply(gsms, function(g) list(geo_accession = g))
    ),
    auto_unbox = TRUE, null = "null"
  )
}

write_stage2_input <- function(lines) {
  path <- tempfile(fileext = ".jsonl")
  writeLines(vapply(lines, as.character, character(1L)), path)
  path
}

# --- .build_stage2_input_lookup (per-series, union sui chunk) ------------------

test_that(".build_stage2_input_lookup: series -> vettore GSM dai samples", {
  path <- write_stage2_input(list(
    mk_stage2_input_line("GSE100", c("GSM1", "GSM2", "GSM3"))
  ))
  lk <- .build_stage2_input_lookup(path)
  expect_named(lk, "GSE100")
  expect_equal(lk[["GSE100"]], c("GSM1", "GSM2", "GSM3"))
})

test_that(".build_stage2_input_lookup: chunk dello stesso studio sono UNITI per series", {
  path <- write_stage2_input(list(
    mk_stage2_input_line("GSE300#1of2", c("GSM1", "GSM2"), series_id = "GSE300"),
    mk_stage2_input_line("GSE300#2of2", c("GSM3", "GSM4"), series_id = "GSE300")
  ))
  lk <- .build_stage2_input_lookup(path)
  expect_named(lk, "GSE300")
  expect_setequal(lk[["GSE300"]], c("GSM1", "GSM2", "GSM3", "GSM4"))
})

test_that(".build_stage2_input_lookup: union di piu' file (originale + rescue)", {
  p1 <- write_stage2_input(list(mk_stage2_input_line("GSE100", c("GSM1", "GSM2"))))
  p2 <- write_stage2_input(list(
    mk_stage2_input_line("GSE100--rsc1of1", c("GSM9"), series_id = "GSE100")
  ))
  lk <- .build_stage2_input_lookup(c(p1, p2))
  expect_setequal(lk[["GSE100"]], c("GSM1", "GSM2", "GSM9"))
})

test_that(".build_stage2_input_lookup: path inesistente -> errore esplicito", {
  expect_error(.build_stage2_input_lookup("/nope/missing.jsonl"), "non esiste")
})

# --- .apply_stage2_completeness_by_series --------------------------------------

mk_study_rec <- function(series, covered_gsms) {
  list(series_id = series,
       replicate_groups = list(list(group_id = "g1",
                                    sample_ids = as.list(covered_gsms),
                                    primary_role = "treated")),
       comparisons = list())
}

test_that(".apply_stage2_completeness_by_series: sample scoperti -> gruppo unclear", {
  recs <- list(mk_study_rec("GSE1", c("GSM1", "GSM2")))
  inp  <- list(GSE1 = c("GSM1", "GSM2", "GSM3"))   # GSM3 scoperto
  out <- .apply_stage2_completeness_by_series(recs, inp)
  expect_equal(out$report$n_uncovered_total, 1L)
  expect_equal(out$report$n_records_affected, 1L)
  rg <- out$records[[1]]$replicate_groups
  roles <- vapply(rg, function(g) g$primary_role, character(1L))
  expect_true("unclear" %in% roles)
})

test_that(".apply_stage2_completeness_by_series: tutti coperti -> nessuna aggiunta", {
  recs <- list(mk_study_rec("GSE1", c("GSM1", "GSM2")))
  inp  <- list(GSE1 = c("GSM1", "GSM2"))
  out <- .apply_stage2_completeness_by_series(recs, inp)
  expect_equal(out$report$n_uncovered_total, 0L)
  expect_length(out$records[[1]]$replicate_groups, 1L)
})

test_that(".apply_stage2_completeness_by_series: studio senza entry input -> invariato", {
  recs <- list(mk_study_rec("GSE_NOINPUT", c("GSM1")))
  out <- .apply_stage2_completeness_by_series(recs, list())
  expect_equal(out$report$n_uncovered_total, 0L)
})

# --- integrazione build_stage3_clusters(stage2_input = ...) --------------------

write_study_master <- function(study, record_id = study$series_id) {
  line <- jsonlite::toJSON(
    list(record_id = record_id, valid_schema = TRUE, parsed_json = study),
    auto_unbox = TRUE, null = "null"
  )
  path <- tempfile(fileext = ".jsonl")
  writeLines(as.character(line), path)
  path
}

test_that("build_stage3_clusters(stage2_input): sample non coperto -> guard lo recupera", {
  input <- make_mock_stage3_input()
  input$stage1_master[["GSM6"]] <- make_test_sample_fact()
  study <- input$stage2_master[[1]]

  s2_master_path <- write_study_master(study, record_id = "GSE100")
  s2_input_path  <- write_stage2_input(list(
    mk_stage2_input_line("GSE100", c("GSM1", "GSM2", "GSM3", "GSM4", "GSM5", "GSM6"))
  ))

  s3 <- build_stage3_clusters(
    stage1_master = input$stage1_master,
    stage2_master = s2_master_path,
    stage2_input  = s2_input_path
  )

  comp <- s3$run_metadata$output_counts$stage2_completeness
  expect_false(is.null(comp))
  expect_equal(comp$n_uncovered_total, 1L)
  expect_equal(comp$n_records_affected, 1L)
})

test_that("build_stage3_clusters: senza stage2_input nessun guard (stage2_completeness NULL)", {
  input <- make_mock_stage3_input()
  s2_master_path <- write_study_master(input$stage2_master[[1]], record_id = "GSE100")
  s3 <- build_stage3_clusters(
    stage1_master = input$stage1_master,
    stage2_master = s2_master_path
  )
  expect_null(s3$run_metadata$output_counts$stage2_completeness)
})
