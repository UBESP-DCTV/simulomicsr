# IL REGISTRO DEGLI SCARTI DEL DISPATCH (2026-08-13, decisione utente D7).
#
# `n_min` e' la porta che decide quali confronti entrano nel pooling, ed e' la
# piu' selettiva di tutte: sul deliverable v15 lascia fuori 2.531 confronti su
# 4.726. Fino a oggi lo faceva con un `next` silenzioso — nessuna traccia su
# disco di che cosa fosse caduto e perche'. Una selezione silenziosa non e'
# auditabile: il 2026-08-10 e' costato una misura sbagliata (85 confronti
# "accusati" di cui 47 non erano nemmeno nel poolato).

.dd_s2 <- function(n_treated = 2L, n_control = 2L) {
  list(list(series_id = "GSE1",
            replicate_groups = list(
              list(group_id = "g1", sample_ids = as.list(paste0("T", seq_len(n_treated)))),
              list(group_id = "g2", sample_ids = as.list(paste0("C", seq_len(n_control))))),
            comparisons = list(
              list(comparison_id = "cmp1", treated_group = "g1", control_group = "g2"))))
}
.dd_cl <- function() data.frame(cluster_id = "cgroup_L5_x", mode = "cgroup",
                                method = "rem_group", stringsAsFactors = FALSE)
.dd_asg <- function() data.frame(cluster_id = "cgroup_L5_x",
                                 record_id = "GSE1__cmp1", stringsAsFactors = FALSE)

test_that("un confronto ammesso non lascia scarti", {
  d <- .build_group_rem_dispatch_from_stage3(.dd_cl(), .dd_asg(), .dd_s2(), n_min = 2L)
  expect_length(d, 1L)
  expect_equal(nrow(attr(d, "scarti")), 0L)
})

test_that("il confronto che cade per n_min lascia il suo motivo, col conteggio", {
  d <- .build_group_rem_dispatch_from_stage3(.dd_cl(), .dd_asg(), .dd_s2(1L, 3L),
                                             n_min = 2L)
  expect_length(d, 0L)
  s <- attr(d, "scarti")
  expect_equal(nrow(s), 1L)
  expect_equal(s$motivo, "n_min")
  expect_equal(s$cluster_id, "cgroup_L5_x")
  expect_equal(s$study_id, "GSE1")
  expect_equal(s$n_treated, 1L)
  expect_equal(s$n_control, 3L)
})

test_that("il registro distingue le corsie dal numero di campioni", {
  # due corsie della stessa libreria: due CAMPIONI ma UNA replica. Il motivo
  # deve dire che il braccio e' sceso per il collasso, non che aveva un campione.
  m <- data.frame(geo_accession = c("T1", "T2", "C1", "C2"),
                  title = c("A_S1_L001", "A_S1_L002", "B_S2_L001", "B_S2_L002"),
                  series_id = "GSE1", characteristics_ch1 = "uguale",
                  source_name_ch1 = "uguale", stringsAsFactors = FALSE)
  lk <- build_lane_library_lookup(m)
  d <- .build_group_rem_dispatch_from_stage3(.dd_cl(), .dd_asg(), .dd_s2(2L, 2L),
                                             n_min = 2L, lane_lookup = lk)
  expect_length(d, 0L)
  s <- attr(d, "scarti")
  expect_equal(s$motivo, "n_min_dopo_collasso_corsie")
  expect_equal(s$n_treated, 2L)          # i campioni sono due
  expect_equal(s$n_bio_treated, 1L)      # la libreria e' una
  expect_equal(s$n_bio_control, 1L)
})

test_that("il doppione di chiave (studio, braccio trattato) e' registrato a parte", {
  s2 <- .dd_s2()
  s2[[1]]$comparisons <- list(
    list(comparison_id = "cmp1", treated_group = "g1", control_group = "g2"),
    list(comparison_id = "cmp2", treated_group = "g1", control_group = "g2"))
  asg <- data.frame(cluster_id = "cgroup_L5_x",
                    record_id = c("GSE1__cmp1", "GSE1__cmp2"), stringsAsFactors = FALSE)
  d <- .build_group_rem_dispatch_from_stage3(.dd_cl(), asg, s2, n_min = 2L)
  expect_length(d[["cgroup_L5_x"]], 1L)
  s <- attr(d, "scarti")
  expect_equal(nrow(s), 1L)
  expect_equal(s$motivo, "doppione_studio_braccio")
})

test_that("il registro ha sempre lo stesso schema, anche vuoto", {
  # chi lo legge da disco non deve scoprire che le colonne compaiono solo
  # quando qualcosa cade.
  vuoto <- .empty_dispatch_drop_log()
  expect_equal(nrow(vuoto), 0L)
  expect_equal(names(vuoto),
               c("cluster_id", "study_id", "treated_group", "motivo",
                 "n_treated", "n_control", "n_bio_treated", "n_bio_control"))
  d <- .build_group_rem_dispatch_from_stage3(.dd_cl(), .dd_asg(), .dd_s2(1L, 3L),
                                             n_min = 2L)
  expect_equal(names(attr(d, "scarti")), names(vuoto))
})

test_that("il registro sopravvive fino a qc_report (l'attributo non si perde)", {
  # `c(study_dispatch, group_rem_dispatch)` butta via gli attributi: il build
  # deve leggerli PRIMA della fusione delle due liste. E' lo stesso modo di
  # fallire che ha tenuto il registro dei conflitti di ruolo fuori dal disco.
  d <- .build_group_rem_dispatch_from_stage3(.dd_cl(), .dd_asg(), .dd_s2(1L, 3L),
                                             n_min = 2L)
  unito <- c(list(), d)
  expect_null(attr(unito, "scarti"))          # si perde davvero
  expect_equal(nrow(attr(d, "scarti")), 1L)   # ma la variabile originale ce l'ha
  # e il build legge quella: riga R/stage4-build.R con `attr(group_rem_dispatch,`
  src <- readLines(testthat::test_path("..", "..", "R", "stage4-build.R"))
  expect_true(any(grepl('qc_report\\$dispatch_drops <- attr\\(group_rem_dispatch, "scarti"\\)', src)))
})
