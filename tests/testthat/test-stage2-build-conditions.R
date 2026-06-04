# TDD per .build_study_conditions() — RED ALERT FASE F4 opzione C (ADR-0020).
#
# Raggruppa i campioni di UNO studio per design_signature in condizioni distinte.
# Ogni condizione: condition_id stabile, rappresentante deterministico (GSM
# minimo alfabetico), n_replicates, member_sample_ids (ordinati), sample_facts
# del rappresentante. L'ordine delle condizioni e' deterministico (per firma),
# indipendente dall'ordine dei campioni in input.
# Builder fixture in helper-stage2-signature.R.

# campioni: 2 condizioni (drugA x3, drugB x2)
two_cond_samples <- function() {
  fa <- function(g) mk_facts(geo = g, perts = list(mk_pert(agent_raw = "drugA")))
  fb <- function(g) mk_facts(geo = g, perts = list(mk_pert(agent_raw = "drugB")))
  list(
    mk_sample("GSM3", fa("GSM3")),
    mk_sample("GSM1", fa("GSM1")),
    mk_sample("GSM5", fb("GSM5")),
    mk_sample("GSM2", fa("GSM2")),
    mk_sample("GSM4", fb("GSM4"))
  )
}

test_that("campioni con 2 firme distinte producono 2 condizioni", {
  conds <- .build_study_conditions(two_cond_samples())
  expect_length(conds, 2L)
})

test_that("n_replicates e member_sample_ids riflettono i gruppi di firma", {
  conds <- .build_study_conditions(two_cond_samples())
  by_n <- vapply(conds, function(c) c$n_replicates, integer(1))
  expect_setequal(by_n, c(3L, 2L))
  # la condizione con 3 membri ha drugA su GSM1/2/3
  c3 <- conds[[which(by_n == 3L)]]
  expect_identical(c3$member_sample_ids, list("GSM1", "GSM2", "GSM3"))
  c2 <- conds[[which(by_n == 2L)]]
  expect_identical(c2$member_sample_ids, list("GSM4", "GSM5"))
})

test_that("il rappresentante e' il GSM minimo alfabetico tra i membri", {
  conds <- .build_study_conditions(two_cond_samples())
  reps <- vapply(conds, function(c) c$geo_accession, character(1))
  expect_setequal(reps, c("GSM1", "GSM4"))
})

test_that("tutte repliche della stessa condizione -> 1 condizione", {
  s <- lapply(c("GSM2", "GSM1", "GSM3"),
              function(g) mk_sample(g, mk_facts(geo = g)))
  conds <- .build_study_conditions(s)
  expect_length(conds, 1L)
  expect_identical(conds[[1]]$n_replicates, 3L)
  expect_identical(conds[[1]]$member_sample_ids, list("GSM1", "GSM2", "GSM3"))
  expect_identical(conds[[1]]$geo_accession, "GSM1")
})

test_that("l'ordine delle condizioni e' deterministico sotto permutazione input", {
  s <- two_cond_samples()
  a <- .build_study_conditions(s)
  b <- .build_study_conditions(rev(s))
  ids_a <- vapply(a, function(c) c$condition_id, character(1))
  ids_b <- vapply(b, function(c) c$condition_id, character(1))
  reps_a <- vapply(a, function(c) c$geo_accession, character(1))
  reps_b <- vapply(b, function(c) c$geo_accession, character(1))
  expect_identical(ids_a, ids_b)
  expect_identical(reps_a, reps_b)
})

test_that("sample_facts emessi sono quelli del rappresentante", {
  # due repliche stessa firma ma donor_id diverso (non-firma): il repr e' GSM1
  s <- list(
    mk_sample("GSM2", mk_facts(geo = "GSM2", donor_id = "Z")),
    mk_sample("GSM1", mk_facts(geo = "GSM1", donor_id = "A"))
  )
  conds <- .build_study_conditions(s)
  expect_length(conds, 1L)
  expect_identical(conds[[1]]$geo_accession, "GSM1")
  expect_identical(conds[[1]]$sample_facts$patient_metadata$donor_id, "A")
})

test_that("condition_id sono distinti e non vuoti", {
  conds <- .build_study_conditions(two_cond_samples())
  ids <- vapply(conds, function(c) c$condition_id, character(1))
  expect_length(unique(ids), 2L)
  expect_true(all(nzchar(ids)))
})
