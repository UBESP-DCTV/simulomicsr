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

test_that("run_name_cleanup degrada a keep/unvalidatable su output LLM atomico (non abortisce l'intero run)", {
  # Riproduce il caso reale vLLM: un top-level JSON scalare parsato con
  # `fromJSON(..., simplifyVector=FALSE)` produce un vettore atomico
  # (es. character(1)), non una list. `out$canonical_name` su un atomico e'
  # un errore R fuori dal tryCatch dell'orchestratore: senza il fix
  # abortirebbe l'intero lapply sui cluster.
  cand <- tibble::tibble(cluster_id = c("c1"), name = c("carnitine"),
                         kind = c("small_molecule"), k = c(4L),
                         top_theme = c("lps"), role = c("candidate"))
  member <- list(c1 = "lps treated")
  current_ids <- c(c1 = "CHEBI:17126")
  llm_fn <- function(messages) "oops"  # output atomico, non-list

  st <- run_name_cleanup(cand, current_ids, member, llm_fn, env = list())

  expect_equal(nrow(st), 1L)
  expect_equal(st$cluster_id, "c1")
  expect_equal(st$action, "keep")
  expect_true(st$name_llm_unvalidatable)
})
