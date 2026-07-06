test_that("run_name_cleanup produce la side-table con override e flag", {
  cand <- tibble::tibble(cluster_id = c("c1","c2"), name = c("carnitine","ethanol"),
                         kind = c("small_molecule","small_molecule"),
                         k = c(4L,5L), top_theme = c("lps","etoh"),
                         role = c("candidate","canary"))
  member <- list(c1 = "lps treated", c2 = "ethanol vehicle")
  current_ids <- c(c1 = "CHEBI:17126", c2 = "CHEBI:16236")
  llm_fn <- function(messages) {
    if (grepl("carnitine", messages[[2]]$content))
      list(canonical_name = "lipopolysaccharide", kind = "pathogen_or_aggregate_exposure",
           confidence = "high", evidence = "lps")
    else list(canonical_name = "ethanol", kind = "small_molecule", confidence = "high", evidence = "etoh")
  }
  st <- testthat::with_mocked_bindings(
    run_name_cleanup(cand, current_ids, member, llm_fn, env = list()),
    .resolve_canonical_to_id = function(canonical_name, kind, env) {
      if (canonical_name == "lipopolysaccharide")
        list(resolved_id = "CHEBI:16412", resolved_name = canonical_name, match_strength = "STRONG")
      else list(resolved_id = "CHEBI:16236", resolved_name = canonical_name, match_strength = "STRONG")
    }, .package = "simulomicsr")
  expect_equal(st$action[st$cluster_id == "c1"], "override")
  expect_equal(st$new_id[st$cluster_id == "c1"], "CHEBI:16412")
  expect_equal(st$action[st$cluster_id == "c2"], "noop")  # canary risolve allo stesso ID
})
