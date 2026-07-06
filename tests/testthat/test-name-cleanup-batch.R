test_that(".build_name_cleanup_input_jsonl scrive jsonl con le 4 chiavi giuste", {
  cand <- tibble::tibble(cluster_id = c("c1", "c2"), name = c("carnitine", "ethanol"),
                         kind = c("small_molecule", "small_molecule"),
                         k = c(4L, 5L), top_theme = c("lps", "etoh"),
                         role = c("candidate", "canary"))
  member <- list(c1 = "lps treated sample", c2 = "ethanol vehicle sample")
  out_path <- tempfile(fileext = ".jsonl")

  ret <- .build_name_cleanup_input_jsonl(cand, member, out_path)

  expect_identical(ret, out_path)
  expect_true(file.exists(out_path))
  df <- jsonlite::stream_in(file(out_path), verbose = FALSE)
  expect_setequal(names(df), c("record_id", "current_label", "kind", "member_metadata"))
  expect_equal(nrow(df), 2L)
  r1 <- df[df$record_id == "c1", ]
  expect_equal(r1$current_label, "carnitine")
  expect_equal(r1$kind, "small_molecule")
  expect_equal(r1$member_metadata, "lps treated sample")
  r2 <- df[df$record_id == "c2", ]
  expect_equal(r2$current_label, "ethanol")
  expect_equal(r2$member_metadata, "ethanol vehicle sample")
})

test_that(".build_name_cleanup_input_jsonl usa '' quando member_metadata manca per un cluster", {
  cand <- tibble::tibble(cluster_id = c("c1"), name = c("carnitine"),
                         kind = c("small_molecule"), k = c(4L),
                         top_theme = c("lps"), role = c("candidate"))
  member <- list()  # nessun member_metadata per c1
  out_path <- tempfile(fileext = ".jsonl")

  .build_name_cleanup_input_jsonl(cand, member, out_path)

  df <- jsonlite::stream_in(file(out_path), verbose = FALSE)
  expect_equal(df$member_metadata, "")
})

test_that(".assemble_side_table_from_predictions: override su match STRONG diverso (candidate)", {
  cand <- tibble::tibble(cluster_id = c("c1"), name = c("carnitine"),
                         kind = c("small_molecule"), k = c(4L),
                         top_theme = c("lps"), role = c("candidate"))
  current_ids <- c(c1 = "CHEBI:17126")
  predictions <- list(c1 = list(canonical_name = "lipopolysaccharide",
                                 kind = "pathogen_or_aggregate_exposure",
                                 confidence = "high", evidence = "lps evidence"))

  st <- testthat::with_mocked_bindings(
    .assemble_side_table_from_predictions(cand, current_ids, predictions, env = list()),
    .resolve_canonical_to_id = function(canonical_name, kind, env) {
      list(resolved_id = "CHEBI:16412", resolved_name = canonical_name, match_strength = "STRONG")
    }, .package = "simulomicsr")

  expect_equal(nrow(st), 1L)
  expect_equal(st$action, "override")
  expect_equal(st$new_id, "CHEBI:16412")
  expect_equal(st$llm_proposed_name, "lipopolysaccharide")
  expect_true(is.na(st$conflicting_id))
  expect_setequal(names(st), c("cluster_id", "old_id", "old_label", "new_canonical",
                               "new_id", "new_kind", "match_strength", "confidence",
                               "action", "name_recovery_source", "name_llm_unvalidatable",
                               "evidence", "llm_proposed_name", "conflicting_id"))
})

test_that(".assemble_side_table_from_predictions: canary con match STRONG diverso -> flag_review + conflicting_id", {
  cand <- tibble::tibble(cluster_id = c("c2"), name = c("ethanol"),
                         kind = c("small_molecule"), k = c(5L),
                         top_theme = c("etoh"), role = c("canary"))
  current_ids <- c(c2 = "CHEBI:16236")
  predictions <- list(c2 = list(canonical_name = "acetone",
                                 kind = "small_molecule",
                                 confidence = "high", evidence = "acetone evidence"))

  st <- testthat::with_mocked_bindings(
    .assemble_side_table_from_predictions(cand, current_ids, predictions, env = list()),
    .resolve_canonical_to_id = function(canonical_name, kind, env) {
      list(resolved_id = "CHEBI:99999", resolved_name = canonical_name, match_strength = "STRONG")
    }, .package = "simulomicsr")

  expect_equal(nrow(st), 1L)
  expect_equal(st$action, "flag_review")
  expect_true(is.na(st$new_id))
  expect_equal(st$conflicting_id, "CHEBI:99999")
  expect_equal(st$llm_proposed_name, "acetone")
})

test_that(".assemble_side_table_from_predictions: cluster senza predizione -> keep/unvalidatable, llm_proposed_name NA", {
  cand <- tibble::tibble(cluster_id = c("c3"), name = c("mystery"),
                         kind = c("small_molecule"), k = c(2L),
                         top_theme = c("mystery"), role = c("candidate"))
  current_ids <- c(c3 = "CHEBI:00000")
  predictions <- list()  # nessuna predizione per c3

  st <- .assemble_side_table_from_predictions(cand, current_ids, predictions, env = list())

  expect_equal(nrow(st), 1L)
  expect_equal(st$action, "keep")
  expect_true(st$name_llm_unvalidatable)
  expect_true(is.na(st$llm_proposed_name))
  expect_true(is.na(st$conflicting_id))
})

test_that(".assemble_side_table_from_predictions: predizione senza canonical_name -> keep, NON crasha", {
  cand <- tibble::tibble(cluster_id = c("c4"), name = c("mystery"),
                         kind = c("small_molecule"), k = c(2L),
                         top_theme = c("mystery"), role = c("candidate"))
  current_ids <- c(c4 = "CHEBI:00000")
  predictions <- list(c4 = list(kind = "small_molecule", confidence = "high"))

  st <- .assemble_side_table_from_predictions(cand, current_ids, predictions, env = list())

  expect_equal(nrow(st), 1L)
  expect_equal(st$action, "keep")
  expect_true(st$name_llm_unvalidatable)
  expect_true(is.na(st$llm_proposed_name))
})
