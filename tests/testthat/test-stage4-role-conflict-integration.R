# La guardia sui conflitti di ruolo deve essere CHIAMATA, non solo esistere.
#
# Questo progetto ha gia' pagato tre volte lo stesso difetto: codice scritto,
# testato e mai invocato dal percorso di produzione (la scheda nuova del Layer B,
# il fornitore dei confronti imperfetti, `bersagli_attesi_provider`). Due di quei
# tre erano buchi del PIANO, non dell'esecuzione: nessun task si intestava il
# collegamento. Questi test si intestano il collegamento.

test_that("il campione ambiguo non arriva al fit: viene tolto da entrambi i bracci", {
  eligible <- data.frame(
    cluster_id      = "cgroup_L5_test",
    method          = "rem_group",
    direction_check = NA_character_,
    stringsAsFactors = FALSE
  )
  attr(eligible, "study_dispatch") <- list(
    cgroup_L5_test = list(
      list(study_id = "GSE1",
           treated  = c("S1", "S2", "S3", "SX"),
           control  = c("SX", "S4", "S5"))
    )
  )
  visti <- NULL
  fetch_fn <- function(gse, sample_ids) {
    visti <<- sample_ids
    m <- matrix(rpois(length(sample_ids) * 20L, 100), nrow = 20L,
                dimnames = list(paste0("G", 1:20), sample_ids))
    m
  }
  suppressWarnings(res <- .run_per_study_de_all(eligible, fetch_fn = fetch_fn))

  # SX non deve comparire, e nessun campione due volte
  expect_false("SX" %in% visti)
  expect_equal(anyDuplicated(visti), 0L)
  expect_setequal(visti, c("S1", "S2", "S3", "S4", "S5"))
})

test_that("lo scarto e' registrato nell'attributo, non solo nel warning", {
  eligible <- data.frame(cluster_id = "cgroup_L5_test", method = "rem_group",
                         direction_check = NA_character_, stringsAsFactors = FALSE)
  attr(eligible, "study_dispatch") <- list(
    cgroup_L5_test = list(
      list(study_id = "GSE1", treated = c("S1", "S2", "SX"),
           control = c("SX", "S4", "S5"))))
  fetch_fn <- function(gse, sample_ids) {
    matrix(rpois(length(sample_ids) * 20L, 100), nrow = 20L,
           dimnames = list(paste0("G", 1:20), sample_ids))
  }
  suppressWarnings(res <- .run_per_study_de_all(eligible, fetch_fn = fetch_fn))
  log <- attr(res, "role_conflicts")
  expect_equal(nrow(log), 1L)
  expect_equal(log$cluster_id, "cgroup_L5_test")
  expect_equal(log$study_id, "GSE1")
  expect_equal(log$n_dropped, 1L)
  expect_true(log$usable)
})

test_that("un confronto che sopravvive solo grazie agli ambigui non entra", {
  eligible <- data.frame(cluster_id = "cgroup_L5_test", method = "rem_group",
                         direction_check = NA_character_, stringsAsFactors = FALSE)
  attr(eligible, "study_dispatch") <- list(
    cgroup_L5_test = list(
      # dopo lo scarto di SX e SY il controllo resta con 1 solo campione
      list(study_id = "GSE1", treated = c("S1", "S2", "SX", "SY"),
           control = c("SX", "SY", "S3"))))
  chiamato <- FALSE
  fetch_fn <- function(gse, sample_ids) { chiamato <<- TRUE
    matrix(rpois(length(sample_ids) * 20L, 100), nrow = 20L,
           dimnames = list(paste0("G", 1:20), sample_ids)) }
  suppressWarnings(res <- .run_per_study_de_all(eligible, fetch_fn = fetch_fn))
  expect_false(chiamato)                 # non si e' nemmeno andati a prendere i conteggi
  expect_equal(nrow(res), 0L)
  expect_false(attr(res, "role_conflicts")$usable)
})

test_that("senza conflitti nulla cambia e il registro resta vuoto", {
  eligible <- data.frame(cluster_id = "cgroup_L5_test", method = "rem_group",
                         direction_check = NA_character_, stringsAsFactors = FALSE)
  attr(eligible, "study_dispatch") <- list(
    cgroup_L5_test = list(
      list(study_id = "GSE1", treated = c("S1", "S2"), control = c("S3", "S4"))))
  visti <- NULL
  fetch_fn <- function(gse, sample_ids) { visti <<- sample_ids
    matrix(rpois(length(sample_ids) * 20L, 100), nrow = 20L,
           dimnames = list(paste0("G", 1:20), sample_ids)) }
  res <- .run_per_study_de_all(eligible, fetch_fn = fetch_fn)
  expect_equal(visti, c("S1", "S2", "S3", "S4"))
  expect_equal(nrow(attr(res, "role_conflicts")), 0L)
})

test_that("la guardia vale anche per i rami rem e mega_aug, non solo rem_group", {
  for (m in c("rem", "mega_aug")) {
    eligible <- data.frame(cluster_id = "c1", method = m,
                           direction_check = NA_character_, stringsAsFactors = FALSE)
    attr(eligible, "study_dispatch") <- list(
      c1 = list(list(study_id = "GSE1", treated = c("S1", "S2", "SX"),
                     control = c("SX", "S3", "S4"))))
    visti <- NULL
    fetch_fn <- function(gse, sample_ids) { visti <<- sample_ids
      matrix(rpois(length(sample_ids) * 20L, 100), nrow = 20L,
             dimnames = list(paste0("G", 1:20), sample_ids)) }
    suppressWarnings(.run_per_study_de_all(eligible, fetch_fn = fetch_fn))
    expect_false("SX" %in% visti, info = m)
  }
})
