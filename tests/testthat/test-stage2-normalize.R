# Test TDD per il completeness guard Stadio 2 (FASE F2 benchmark finding).
# Razionale: lo Stadio 2 LLM a volte NON assegna un replicate_group a ogni
# sample di input (viola la sua REGOLA 4 "DO NOT OMIT"; ~3.5% nel benchmark
# scalato). I sample non coperti vengono silenziosamente esclusi dal
# clustering Stadio 3 -> perdita di tracciabilita'. Il guard materializza la
# REGOLA 4 in modo deterministico: ogni sample di input non coperto finisce in
# un replicate_group sintetico primary_role='unclear' (inerte al clustering
# treated/control, ma esplicito e auditabile).

mk_rg <- function(gid, sids, role = "treated") {
  list(group_id = gid, label_human = gid, sample_ids = as.list(sids),
       primary_role = role, factor_levels = list())
}

test_that("complete_stage2_coverage: tutti coperti -> nessuna aggiunta", {
  pj <- list(series_id = "GSE1",
             replicate_groups = list(mk_rg("g1", c("A","B")), mk_rg("g2", c("C"), "control")))
  r <- complete_stage2_coverage(pj, c("A","B","C"))
  expect_equal(r$n_added, 0L)
  expect_length(r$parsed_json$replicate_groups, 2L)
})

test_that("complete_stage2_coverage: sample non coperti -> gruppo unclear sintetico", {
  pj <- list(series_id = "GSE1",
             replicate_groups = list(mk_rg("g1", c("A","B"))))
  r <- complete_stage2_coverage(pj, c("A","B","C","D"))
  expect_equal(r$n_added, 2L)
  expect_setequal(r$uncovered, c("C","D"))
  expect_length(r$parsed_json$replicate_groups, 2L)
  added <- r$parsed_json$replicate_groups[[2L]]
  expect_equal(added$primary_role, "unclear")
  expect_setequal(unlist(added$sample_ids), c("C","D"))
  # schema-shaped: ha i campi required v2
  expect_true(all(c("group_id","label_human","sample_ids","primary_role","factor_levels") %in% names(added)))
})

test_that("complete_stage2_coverage: replicate_groups vuoto/NULL -> tutti uncovered", {
  pj0 <- list(series_id = "GSE1", replicate_groups = list())
  expect_equal(complete_stage2_coverage(pj0, c("A","B"))$n_added, 2L)
  pjN <- list(series_id = "GSE1")
  expect_equal(complete_stage2_coverage(pjN, c("A","B"))$n_added, 2L)
})

test_that("complete_stage2_coverage: input vuoto -> nessuna aggiunta", {
  pj <- list(series_id = "GSE1", replicate_groups = list(mk_rg("g1", c("A"))))
  expect_equal(complete_stage2_coverage(pj, character(0))$n_added, 0L)
})

test_that("complete_stage2_coverage: dedup coverage cross-group + sample_ids vettore", {
  pj <- list(series_id = "GSE1",
             replicate_groups = list(mk_rg("g1", c("A","B")), mk_rg("g2", c("B","C"))))
  r <- complete_stage2_coverage(pj, c("A","B","C","D"))
  expect_equal(r$n_added, 1L)
  expect_equal(r$uncovered, "D")
})

test_that("audit_stage2_coverage: driver su piu' record + report", {
  recs <- list(
    list(record_id = "GSE1", parsed_json = list(series_id="GSE1", replicate_groups=list(mk_rg("g1", c("A","B"))))),
    list(record_id = "GSE2", parsed_json = list(series_id="GSE2", replicate_groups=list(mk_rg("g1", c("X","Y","Z")))))
  )
  inp <- list(GSE1 = c("A","B","C"), GSE2 = c("X","Y","Z"))
  out <- audit_stage2_coverage(recs, inp)
  expect_equal(out$n_uncovered_total, 1L)      # solo C in GSE1
  expect_equal(out$n_records_affected, 1L)
  # GSE1 ora copre C
  cov <- unlist(lapply(out$records[[1L]]$parsed_json$replicate_groups, function(g) unlist(g$sample_ids)))
  expect_true("C" %in% cov)
  # GSE2 invariato
  expect_length(out$records[[2L]]$parsed_json$replicate_groups, 1L)
})

test_that("audit_stage2_coverage: record senza input_by_record -> skip sicuro", {
  recs <- list(list(record_id = "GSEX", parsed_json = list(series_id="GSEX", replicate_groups=list(mk_rg("g1", c("A"))))))
  out <- audit_stage2_coverage(recs, list())   # nessun input noto
  expect_equal(out$n_uncovered_total, 0L)
  expect_length(out$records, 1L)
})
