# TDD per il riassemblaggio dei chunk Stadio 2 (RED ALERT FASE F4).
#
# Difetto (docs/findings/2026-06-01-stage3-stage4-chunked-study-sample-resolution-bug.md):
# uno studio splittato in N chunk compare come N record con la stessa series_id;
# Stadio 3 (record_id = series__group) e Stadio 4 (.index_stage2_master per
# series, last-wins) assumono un record per studio -> sopravvive solo l'ultimo
# chunk, gli altri campioni vengono persi/misrisolti.
#
# Fix: `.reassemble_stage2_chunks()` fonde i record con la stessa series_id in
# UN record, namespacizzando per chunk i group_id/comparison_id (no union per id:
# 639 group_id omonimi hanno primary_role in conflitto sui dati reali). Il merge
# biologico lo fa il clustering per-anchor a valle.

mk_group <- function(gid, sids, role = "treated") {
  list(group_id = gid, sample_ids = as.list(sids), primary_role = role,
       factor_levels = list())
}
mk_cmp <- function(cid, tg, cg, ctype = "vehicle") {
  list(comparison_id = cid, treated_group = tg, control_group = cg,
       control_type = ctype)
}
mk_study <- function(series, groups = list(), comparisons = list()) {
  list(series_id = series, replicate_groups = groups, comparisons = comparisons)
}

test_that("riassemblaggio: 2 chunk stessa series -> 1 record con tutti i gruppi", {
  s2 <- list(
    mk_study("GSE_X", list(mk_group("A", c("GSM1", "GSM2")))),
    mk_study("GSE_X", list(mk_group("B", c("GSM3", "GSM4"))))
  )
  out <- .reassemble_stage2_chunks(s2)$stage2_master
  expect_length(out, 1L)
  expect_equal(out[[1]]$series_id, "GSE_X")
  gids <- vapply(out[[1]]$replicate_groups, function(g) g$group_id, character(1L))
  expect_length(gids, 2L)
  all_s <- sort(unlist(lapply(out[[1]]$replicate_groups, function(g) as.character(g$sample_ids))))
  expect_equal(all_s, c("GSM1", "GSM2", "GSM3", "GSM4"))
})

test_that("riassemblaggio: group_id omonimi con ruoli in conflitto NON vengono uniti", {
  # Stesso group_id 'g1' nei due chunk ma ruoli diversi -> namespacing per chunk
  s2 <- list(
    mk_study("GSE_Y", list(mk_group("g1", c("GSM1", "GSM2"), "treated"))),
    mk_study("GSE_Y", list(mk_group("g1", c("GSM3", "GSM4"), "control")))
  )
  out <- .reassemble_stage2_chunks(s2)$stage2_master[[1]]
  expect_length(out$replicate_groups, 2L)        # NON collassati in 1
  gids <- vapply(out$replicate_groups, function(g) g$group_id, character(1L))
  expect_equal(length(unique(gids)), 2L)         # id resi unici
  roles <- vapply(out$replicate_groups, function(g) g$primary_role, character(1L))
  expect_setequal(roles, c("treated", "control")) # ogni chunk tiene il suo ruolo
})

test_that("riassemblaggio: i riferimenti delle comparisons seguono il rename dei gruppi", {
  s2 <- list(
    mk_study("GSE_Z",
             list(mk_group("t", c("GSM1")), mk_group("c", c("GSM2"), "control")),
             list(mk_cmp("cmp1", "t", "c"))),
    mk_study("GSE_Z",
             list(mk_group("t", c("GSM3")), mk_group("c", c("GSM4"), "control")),
             list(mk_cmp("cmp1", "t", "c")))
  )
  out <- .reassemble_stage2_chunks(s2)$stage2_master[[1]]
  expect_length(out$comparisons, 2L)             # cmp1 di entrambi i chunk sopravvive
  gids <- vapply(out$replicate_groups, function(g) g$group_id, character(1L))
  # ogni comparison punta a group_id ESISTENTI nel record riassemblato
  for (cmp in out$comparisons) {
    expect_true(cmp$treated_group %in% gids)
    expect_true(cmp$control_group %in% gids)
  }
  # e i due cmp1 puntano a gruppi DIVERSI (quelli del proprio chunk)
  tg <- vapply(out$comparisons, function(c) c$treated_group, character(1L))
  expect_equal(length(unique(tg)), 2L)
})

test_that("riassemblaggio: series a chunk singolo resta invariata", {
  s2 <- list(mk_study("GSE_S", list(mk_group("g1", c("GSM1", "GSM2")))))
  out <- .reassemble_stage2_chunks(s2)$stage2_master
  expect_length(out, 1L)
  expect_identical(out[[1]], s2[[1]])
})

test_that("riassemblaggio: idempotente", {
  s2 <- list(
    mk_study("GSE_X", list(mk_group("A", c("GSM1")))),
    mk_study("GSE_X", list(mk_group("B", c("GSM2"))))
  )
  once  <- .reassemble_stage2_chunks(s2)$stage2_master
  twice <- .reassemble_stage2_chunks(once)$stage2_master
  expect_identical(once, twice)
})

test_that("riassemblaggio: report conteggi", {
  s2 <- list(
    mk_study("GSE_X", list(mk_group("A", c("GSM1")))),
    mk_study("GSE_X", list(mk_group("B", c("GSM2")))),
    mk_study("GSE_S", list(mk_group("g", c("GSM9"))))
  )
  rep <- .reassemble_stage2_chunks(s2)$report
  expect_equal(rep$n_records_in, 3L)
  expect_equal(rep$n_records_out, 2L)
  expect_equal(rep$n_series_multichunk, 1L)
})

# --- integrazione: il difetto chunked e' chiuso end-to-end --------------------

test_that("build_stage3_clusters: stage2 chunked stesso group_id non collide piu'", {
  fact <- make_test_sample_fact()
  s1 <- list(GSM1 = fact, GSM2 = fact, GSM3 = fact, GSM4 = fact)
  # 2 chunk dello stesso studio, stesso label 'tumor', campioni disgiunti
  s2 <- list(
    mk_study("GSET", list(mk_group("tumor", c("GSM1", "GSM2")))),
    mk_study("GSET", list(mk_group("tumor", c("GSM3", "GSM4"))))
  )
  s3 <- suppressMessages(build_stage3_clusters(s1, s2))
  asg <- s3$assignments[s3$assignments$mode == "group" & s3$assignments$level == 0, ]
  # Pre-fix: 2 record fisici -> 1 solo record_id 'GSET__tumor' (collisione).
  # Post-fix: namespacing per chunk -> 2 record_id distinti.
  expect_equal(length(unique(asg$record_id)), 2L)
})

test_that("Stadio 4 dispatch: dopo riassemblaggio tutti i campioni dei chunk sono risolti", {
  # Studio a 2 chunk senza collisione group_id (A in chunk1, B in chunk2)
  s2 <- list(
    mk_study("GSE_X", list(mk_group("A", c("GSM1", "GSM2")))),
    mk_study("GSE_X", list(mk_group("B", c("GSM3", "GSM4"))))
  )
  reasm <- .reassemble_stage2_chunks(s2)$stage2_master
  ec  <- tibble::tibble(cluster_id = "CL1", mode = "group", method = "mega")
  # record_id namespaced come li produce Stadio 3 post-riassemblaggio
  gids <- vapply(reasm[[1]]$replicate_groups, function(g) g$group_id, character(1L))
  asg <- tibble::tibble(record_id = paste0("GSE_X__", gids),
                        cluster_id = "CL1", mode = "group", level = 0L,
                        anchor_key = "k")
  disp <- .build_group_dispatch_from_stage3(ec, asg, reasm)
  got <- sort(unique(unlist(lapply(disp[["CL1"]], function(d) d$sample_ids))))
  expect_equal(got, c("GSM1", "GSM2", "GSM3", "GSM4"))
})
