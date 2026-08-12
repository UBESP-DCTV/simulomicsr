# Il collasso delle corsie deve essere CHIAMATO dal percorso di produzione, non
# solo esistere. Stessa ragione del file gemello sui conflitti di ruolo: in
# questo progetto e' gia' successo tre volte che del codice corretto non fosse
# invocato da nessuno, e due volte era un buco del PIANO — nessun task si
# intestava il collegamento. Questi test se lo intestano.

.lane_meta <- function(gsm, title, series = "GSE1") {
  data.frame(geo_accession = gsm, title = title, series_id = series,
             characteristics_ch1 = "identico", source_name_ch1 = "identico",
             stringsAsFactors = FALSE)
}
.lane_fetch <- function(visti_env) {
  function(gse, sample_ids) {
    visti_env$cols <- sample_ids
    matrix(rpois(length(sample_ids) * 30L, 200), nrow = 30L,
           dimnames = list(paste0("G", 1:30), sample_ids))
  }
}
.lane_eligible <- function(treated, control) {
  e <- data.frame(cluster_id = "cgroup_L5_test", method = "rem_group",
                  direction_check = NA_character_, stringsAsFactors = FALSE)
  attr(e, "study_dispatch") <- list(
    cgroup_L5_test = list(list(study_id = "GSE1", treated = treated,
                               control = control)))
  e
}

test_that("le corsie arrivano SOMMATE al fit, non come repliche", {
  m <- .lane_meta(paste0("S", 1:8),
                  c(paste0("T1_S1_L00", 1:2), paste0("T2_S2_L00", 1:2),
                    paste0("C1_S3_L00", 1:2), paste0("C2_S4_L00", 1:2)))
  lk <- build_lane_library_lookup(m)
  env <- new.env()
  res <- suppressWarnings(.run_per_study_de_all(
    .lane_eligible(paste0("S", 1:4), paste0("S", 5:8)),
    fetch_fn = .lane_fetch(env), lane_lookup = lk))
  # fetch_fn riceve gli 8 campioni; il fit ne vede 4 (due per braccio)
  expect_length(env$cols, 8L)
  expect_equal(nrow(attr(res, "lane_collapses")), 4L)
  expect_equal(sum(attr(res, "lane_collapses")$n_campioni), 8L)
  expect_true(all(c("cluster_id", "study_id") %in%
                    names(attr(res, "lane_collapses"))))
})

test_that("senza la corrispondenza il percorso resta quello di sempre", {
  env <- new.env()
  res <- suppressWarnings(.run_per_study_de_all(
    .lane_eligible(paste0("S", 1:4), paste0("S", 5:8)),
    fetch_fn = .lane_fetch(env), lane_lookup = NULL))
  expect_equal(nrow(attr(res, "lane_collapses")), 0L)
  expect_length(env$cols, 8L)
})

test_that("il gate del dispatch conta le librerie: un braccio di sole corsie cade", {
  # GSE173902 in piccolo: due campioni per braccio, ma sono due corsie di una
  # libreria sola. Con la corrispondenza il confronto non deve nascere.
  m <- .lane_meta(paste0("S", 1:4),
                  c("T_S1_L001", "T_S1_L002", "C_S2_L001", "C_S2_L002"))
  lk <- build_lane_library_lookup(m)
  cl <- data.frame(cluster_id = "cgroup_L5_test", mode = "cgroup",
                   method = "rem_group", stringsAsFactors = FALSE)
  asg <- data.frame(cluster_id = "cgroup_L5_test",
                    record_id = "GSE1__cmp1", stringsAsFactors = FALSE)
  s2 <- list(list(series_id = "GSE1",
                  replicate_groups = list(
                    list(group_id = "g1", sample_ids = list("S1", "S2")),
                    list(group_id = "g2", sample_ids = list("S3", "S4"))),
                  comparisons = list(
                    list(comparison_id = "cmp1", treated_group = "g1",
                         control_group = "g2"))))
  spento <- .build_group_rem_dispatch_from_stage3(cl, asg, s2, n_min = 2L)
  acceso <- .build_group_rem_dispatch_from_stage3(cl, asg, s2, n_min = 2L,
                                                  lane_lookup = lk)
  expect_length(spento, 1L)
  expect_length(acceso, 0L)
})

test_that("un braccio con DUE librerie su piu' corsie resta ammesso", {
  m <- .lane_meta(paste0("S", 1:8),
                  c("T1_S1_L001", "T1_S1_L002", "T2_S2_L001", "T2_S2_L002",
                    "C1_S3_L001", "C1_S3_L002", "C2_S4_L001", "C2_S4_L002"))
  lk <- build_lane_library_lookup(m)
  cl <- data.frame(cluster_id = "cgroup_L5_test", mode = "cgroup",
                   method = "rem_group", stringsAsFactors = FALSE)
  asg <- data.frame(cluster_id = "cgroup_L5_test",
                    record_id = "GSE1__cmp1", stringsAsFactors = FALSE)
  s2 <- list(list(series_id = "GSE1",
                  replicate_groups = list(
                    list(group_id = "g1", sample_ids = list("S1", "S2", "S3", "S4")),
                    list(group_id = "g2", sample_ids = list("S5", "S6", "S7", "S8"))),
                  comparisons = list(
                    list(comparison_id = "cmp1", treated_group = "g1",
                         control_group = "g2"))))
  acceso <- .build_group_rem_dispatch_from_stage3(cl, asg, s2, n_min = 2L,
                                                  lane_lookup = lk)
  expect_length(acceso, 1L)
  expect_equal(acceso[["cgroup_L5_test"]][[1]]$treated, paste0("S", 1:4))
})
