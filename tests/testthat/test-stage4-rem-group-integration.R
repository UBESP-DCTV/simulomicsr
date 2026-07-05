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
