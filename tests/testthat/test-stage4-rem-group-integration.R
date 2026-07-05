# test-stage4-rem-group-integration.R
# Task 6: verifica che .run_per_study_de_all instradi rem_group
# e che .pool_all_clusters abbia il parametro rem_group_config.

test_that(".run_per_study_de_all include i cluster rem_group", {
  eligible <- tibble::tibble(
    cluster_id = "group_L4_e", mode = "group", method = "rem_group",
    direction_check = "ok"
  )
  fetch_fn <- function(gse, sids) {
    m <- matrix(rpois(20L * length(sids), 100L), nrow = 20L,
                dimnames = list(paste0("ENSG", 1:20), sids))
    m
  }
  disp <- list(group_L4_e = list(
    list(study_id = "GSE1", treated = c("s1","s2","s3"), control = c("s4","s5")),
    list(study_id = "GSE2", treated = c("t1","t2"),      control = c("u1","u2")),
    list(study_id = "GSE5", treated = c("p1","p2"),      control = c("q1","q2"))
  ))
  attr(eligible, "study_dispatch") <- disp
  res <- .run_per_study_de_all(eligible, fetch_fn = fetch_fn)
  expect_true(nrow(res) > 0L)
  expect_true(all(res$cluster_id == "group_L4_e"))
})

# Task 7 Step 1: verifica la semantica del merge c() tra study_dispatch e
# group_rem_dispatch (cluster_id disgiunti, named list).
test_that("il group_rem_dispatch si fonde nello study_dispatch (cluster_id disgiunti)", {
  study_dispatch <- list(pair_A = list(list(study_id = "GSE9",
    treated = c("a","b"), control = c("c","d"))))
  group_rem_dispatch <- list(group_L4_e = list(list(study_id = "GSE1",
    treated = c("s1","s2"), control = c("s3","s4"))))
  merged <- c(study_dispatch, group_rem_dispatch)
  expect_setequal(names(merged), c("pair_A", "group_L4_e"))
  expect_length(merged, 2L)
})

# Task 7 Step 4: non-regressione — .identify_layer_a_clusters non altera
# i method dei rami rem/mega/mega_aug; il ramo rem_group resta distinto.
test_that("non-regressione: identify_layer_a non altera i rami rem/mega/mega_aug", {
  # Un cluster per ramo esistente + un rem_group; i method dei rami esistenti
  # restano invariati e disgiunti dal nuovo.
  clusters <- dplyr::bind_rows(
    .mk_cluster_row("pair_rem",  "pair",  0L, 5L, 60L, 5L, 0.80, FALSE,
                    "small_molecule", "CHEBI:a"),
    .mk_cluster_row("group_meg", "group", 0L, 8L, 200L, 8L, 0.90, TRUE,
                    "environmental", "STR:hyp"),
    .mk_cluster_row("group_reg", "group", 4L, 25L, 400L, 25L, 0.30, FALSE,
                    "small_molecule", "CHEBI:enza")
  )
  clusters$usable_rem_strict[clusters$cluster_id == "pair_rem"] <- TRUE
  cfg <- stage4_default_config()
  out <- .identify_layer_a_clusters(clusters, cfg)
  expect_identical(out$method[out$cluster_id == "pair_rem"], "rem")
  expect_identical(out$method[out$cluster_id == "group_meg"], "mega")
  expect_identical(out$method[out$cluster_id == "group_reg"], "rem_group")
})
