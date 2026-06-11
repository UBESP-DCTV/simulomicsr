# TDD per .chunk_conditions() — RED ALERT FASE F4 opzione C, coda D2 (ADR-0020).
#
# Divide le condizioni di UNO studio in chunk il cui peso (somma nchar dei facts
# del rappresentante) non eccede un budget di caratteri, RIPETENDO (broadcast) le
# condizioni di controllo/baseline in ogni chunk affinche' i confronti
# trattato-vs-controllo si possano formare entro ogni chunk. Per gli studi che
# stanno nel budget e' un no-op (un solo chunk con tutte le condizioni).
# Builder fixture in helper-stage2-signature.R.

# costruisce una condizione fittizia con un peso (n_char) e flag controllo
mk_cond <- function(id, n_char, control = FALSE) {
  pert <- if (control) {
    list(mk_pert(kind = "vehicle_only", agent_raw = "DMSO", negctrl = TRUE))
  } else {
    list(mk_pert(agent_raw = paste0("drug_", id)))
  }
  facts <- mk_facts(geo = paste0("GSM_", id), perts = pert)
  list(condition_id = id, geo_accession = paste0("GSM_", id),
       sample_facts = facts, n_replicates = 2L,
       member_sample_ids = list(paste0("GSM_", id)),
       signature = id, n_char = n_char)
}

test_that("studio entro budget -> un solo chunk con tutte le condizioni", {
  conds <- list(mk_cond("a", 1000), mk_cond("b", 1000), mk_cond("c", 1000, control = TRUE))
  chunks <- .chunk_conditions(conds, budget_chars = 100000)
  expect_length(chunks, 1L)
  expect_length(chunks[[1]], 3L)
})

test_that("studio oltre budget -> piu' chunk", {
  conds <- lapply(1:10, function(i) mk_cond(letters[i], 3000))
  chunks <- .chunk_conditions(conds, budget_chars = 10000)
  expect_gt(length(chunks), 1L)
})

test_that("ogni chunk rispetta il budget (somma n_char <= budget)", {
  conds <- lapply(1:10, function(i) mk_cond(letters[i], 3000))
  chunks <- .chunk_conditions(conds, budget_chars = 10000)
  for (ch in chunks) {
    tot <- sum(vapply(ch, function(c) c$n_char, numeric(1)))
    expect_lte(tot, 10000)
  }
})

test_that("le condizioni di controllo sono presenti (broadcast) in OGNI chunk", {
  conds <- c(
    list(mk_cond("ctrl", 2000, control = TRUE)),
    lapply(1:8, function(i) mk_cond(paste0("t", i), 3000))
  )
  chunks <- .chunk_conditions(conds, budget_chars = 10000)
  expect_gt(length(chunks), 1L)
  for (ch in chunks) {
    ids <- vapply(ch, function(c) c$condition_id, character(1))
    expect_true("ctrl" %in% ids)
  }
})

test_that("ogni condizione non-controllo appare in esattamente un chunk", {
  conds <- c(
    list(mk_cond("ctrl", 1000, control = TRUE)),
    lapply(1:8, function(i) mk_cond(paste0("t", i), 3000))
  )
  chunks <- .chunk_conditions(conds, budget_chars = 10000)
  treated <- paste0("t", 1:8)
  appearances <- table(unlist(lapply(chunks, function(ch)
    intersect(vapply(ch, function(c) c$condition_id, character(1)), treated))))
  expect_setequal(names(appearances), treated)
  expect_true(all(appearances == 1L))
})

test_that("controlli oltre la frazione del budget -> fallback partizione semplice", {
  # controlli totali 8000 > 30% di budget 10000 (=3000) -> niente broadcast
  conds <- c(
    lapply(1:4, function(i) mk_cond(paste0("ctrl", i), 2000, control = TRUE)),
    lapply(1:6, function(i) mk_cond(paste0("t", i), 3000))
  )
  chunks <- .chunk_conditions(conds, budget_chars = 10000, broadcast_max_frac = 0.3)
  all_ids <- unlist(lapply(chunks, function(ch)
    vapply(ch, function(c) c$condition_id, character(1))))
  expect_true(all(table(all_ids) == 1L))  # nessuna ripetizione (no broadcast)
  expect_length(all_ids, 10L)
})

test_that("controlli entro la frazione del budget -> broadcast attivo", {
  # 1 controllo 2000 < 30% di budget 10000 (=3000) -> broadcast
  conds <- c(list(mk_cond("ctrl", 2000, control = TRUE)),
             lapply(1:8, function(i) mk_cond(paste0("t", i), 3000)))
  chunks <- .chunk_conditions(conds, budget_chars = 10000, broadcast_max_frac = 0.3)
  expect_gt(length(chunks), 1L)
  for (ch in chunks) {
    ids <- vapply(ch, function(c) c$condition_id, character(1))
    expect_true("ctrl" %in% ids)
  }
})

test_that("nessuna condizione di controllo -> partizione semplice senza broadcast", {
  conds <- lapply(1:6, function(i) mk_cond(letters[i], 4000))
  chunks <- .chunk_conditions(conds, budget_chars = 10000)
  all_ids <- unlist(lapply(chunks, function(ch)
    vapply(ch, function(c) c$condition_id, character(1))))
  expect_setequal(all_ids, letters[1:6])
  expect_length(all_ids, 6L)  # nessuna ripetizione
})

# --- tetto condizioni trattate per chunk (rescue F4: bounda l'output LLM) ---
# Il budget caratteri limita l'INPUT; l'output LLM (confronti) scala col numero di
# condizioni TRATTATE per chunk. Un tetto esplicito sul numero di trattati per
# chunk bounda direttamente l'output, restando broadcast-safe (i controlli non
# contano contro il tetto, restano in ogni chunk).

test_that("tetto trattati/chunk: spezza anche se il budget non e' raggiunto", {
  # budget enorme -> il char budget da solo non spezzerebbe mai; il tetto si'.
  conds <- c(list(mk_cond("ctrl", 1000, control = TRUE)),
             lapply(1:9, function(i) mk_cond(paste0("t", i), 1000)))
  chunks <- .chunk_conditions(conds, budget_chars = 1000000,
                              max_treated_per_chunk = 3L)
  expect_length(chunks, 3L)  # 9 trattati / 3 = 3 chunk
})

test_that("tetto trattati/chunk: ogni chunk ha al piu' N trattati, controlli esclusi dal conteggio", {
  conds <- c(list(mk_cond("ctrl", 1000, control = TRUE)),
             lapply(1:9, function(i) mk_cond(paste0("t", i), 1000)))
  chunks <- .chunk_conditions(conds, budget_chars = 1000000,
                              max_treated_per_chunk = 3L)
  for (ch in chunks) {
    ids <- vapply(ch, function(c) c$condition_id, character(1))
    n_treated <- sum(!grepl("^ctrl", ids))
    expect_lte(n_treated, 3L)
    expect_true("ctrl" %in% ids)  # broadcast preservato
  }
})

test_that("tetto trattati/chunk: si applica anche senza controlli (partizione semplice)", {
  conds <- lapply(1:6, function(i) mk_cond(letters[i], 1000))
  chunks <- .chunk_conditions(conds, budget_chars = 1000000,
                              max_treated_per_chunk = 2L)
  expect_length(chunks, 3L)  # 6 / 2 = 3
  all_ids <- unlist(lapply(chunks, function(ch)
    vapply(ch, function(c) c$condition_id, character(1))))
  expect_setequal(all_ids, letters[1:6])  # copertura, nessuna perdita
})

test_that("tetto trattati/chunk default Inf: comportamento invariato (retrocompat)", {
  conds <- lapply(1:10, function(i) mk_cond(letters[i], 3000))
  chunks_default <- .chunk_conditions(conds, budget_chars = 10000)
  chunks_inf     <- .chunk_conditions(conds, budget_chars = 10000,
                                      max_treated_per_chunk = Inf)
  expect_equal(length(chunks_default), length(chunks_inf))
})

test_that("tetto trattati/chunk si combina col budget: vince il vincolo piu' stretto", {
  # budget 10000 con trattati da 3000 -> ~3/chunk per budget; tetto 2 piu' stretto
  conds <- lapply(1:6, function(i) mk_cond(letters[i], 3000))
  chunks <- .chunk_conditions(conds, budget_chars = 10000,
                              max_treated_per_chunk = 2L)
  for (ch in chunks) {
    expect_lte(length(ch), 2L)
  }
})
