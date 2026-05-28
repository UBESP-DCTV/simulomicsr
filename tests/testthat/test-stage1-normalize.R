# Test TDD per il guard deterministico is_zero_timepoint (FASE F2 root-cause).
# Razionale: lo Stadio 1 LLM puo' marcare is_zero_timepoint=TRUE su sample
# senza alcuna evidenza temporale (duration value_raw/value_hours nulli).
# E' uno stato semanticamente invalido: non esiste "tempo zero" senza tempo.
# A valle, la REGOLA 2 di Stadio 2 declassa quei sample a control/time_zero,
# corrompendo il design DE. Il guard forza is_zero_timepoint=FALSE quando
# non c'e' evidenza reale di t=0, alla sorgente (pre-build input Stadio 2).

test_that(".has_zero_timepoint_evidence: value_hours numerico e' autoritativo", {
  expect_true(.has_zero_timepoint_evidence(list(value_raw = NULL, value_hours = 0,  is_zero_timepoint = TRUE)))
  expect_false(.has_zero_timepoint_evidence(list(value_raw = "24h", value_hours = 24, is_zero_timepoint = TRUE)))
  expect_false(.has_zero_timepoint_evidence(list(value_raw = NULL, value_hours = 0.5, is_zero_timepoint = TRUE)))
})

test_that(".has_zero_timepoint_evidence: nessuna info => FALSE (caso GSE183194)", {
  # value_raw e value_hours entrambi nulli: il modello NON ha evidenza di t=0.
  expect_false(.has_zero_timepoint_evidence(list(value_raw = NULL, value_hours = NULL, is_zero_timepoint = TRUE)))
  expect_false(.has_zero_timepoint_evidence(list(value_raw = "",   value_hours = NULL, is_zero_timepoint = TRUE)))
  expect_false(.has_zero_timepoint_evidence(list(value_raw = NA_character_, value_hours = NA_real_, is_zero_timepoint = TRUE)))
})

test_that(".has_zero_timepoint_evidence: fallback testo t0/baseline quando value_hours nullo", {
  for (v in c("0", "0h", "0 h", "t0", "t=0", "time(hours): 0", "baseline", "day 0", "d0", "0 hours", "0 min")) {
    expect_true(.has_zero_timepoint_evidence(list(value_raw = v, value_hours = NULL, is_zero_timepoint = TRUE)),
                info = paste("atteso TRUE per value_raw =", v))
  }
  for (v in c("24h", "48 hours", "6 days", "30 min", "2 weeks", "10h")) {
    expect_false(.has_zero_timepoint_evidence(list(value_raw = v, value_hours = NULL, is_zero_timepoint = TRUE)),
                 info = paste("atteso FALSE per value_raw =", v))
  }
})

test_that(".normalize_duration_zt: forza is_zero_timepoint=FALSE senza evidenza, preserva con evidenza", {
  # senza evidenza -> forzato FALSE
  d1 <- .normalize_duration_zt(list(value_raw = NULL, value_hours = NULL, is_zero_timepoint = TRUE))
  expect_false(d1$duration$is_zero_timepoint)
  expect_true(d1$changed)
  # con evidenza numerica -> resta TRUE
  d2 <- .normalize_duration_zt(list(value_raw = NULL, value_hours = 0, is_zero_timepoint = TRUE))
  expect_true(d2$duration$is_zero_timepoint)
  expect_false(d2$changed)
  # gia' FALSE senza evidenza -> invariato, no change
  d3 <- .normalize_duration_zt(list(value_raw = NULL, value_hours = NULL, is_zero_timepoint = FALSE))
  expect_false(d3$duration$is_zero_timepoint)
  expect_false(d3$changed)
  # value_hours>0 ma flag TRUE (incoerente) -> forzato FALSE
  d4 <- .normalize_duration_zt(list(value_raw = "24h", value_hours = 24, is_zero_timepoint = TRUE))
  expect_false(d4$duration$is_zero_timepoint)
  expect_true(d4$changed)
})

test_that("normalize_stage1_facts_zt: itera tutte le perturbations e conta correzioni", {
  facts <- list(
    perturbations = list(
      list(kind = "small_molecule", duration = list(value_raw = NULL, value_hours = NULL, is_zero_timepoint = TRUE)),
      list(kind = "small_molecule", duration = list(value_raw = "0",  value_hours = NULL, is_zero_timepoint = TRUE)),
      list(kind = "small_molecule", duration = list(value_raw = "24h", value_hours = 24,  is_zero_timepoint = FALSE))
    )
  )
  out <- normalize_stage1_facts_zt(facts)
  expect_false(out$facts$perturbations[[1]]$duration$is_zero_timepoint)  # forzato
  expect_true(out$facts$perturbations[[2]]$duration$is_zero_timepoint)   # evidenza "0"
  expect_false(out$facts$perturbations[[3]]$duration$is_zero_timepoint)  # invariato
  expect_equal(out$n_corrected, 1L)
})

test_that("normalize_stage1_facts_zt: robusto a facts senza perturbations / perturbations vuote", {
  expect_equal(normalize_stage1_facts_zt(list())$n_corrected, 0L)
  expect_equal(normalize_stage1_facts_zt(list(perturbations = list()))$n_corrected, 0L)
  # perturbation senza duration -> non crasha
  f <- list(perturbations = list(list(kind = "differentiation")))
  expect_equal(normalize_stage1_facts_zt(f)$n_corrected, 0L)
})
