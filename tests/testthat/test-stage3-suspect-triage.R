# tests/testthat/test-stage3-suspect-triage.R
# Task 7 (v9 name-recovery plan, Fase C): triage sospetti/canary/skip da
# clusters.rds v9-pre re-cluster, SENZA accesso H5 (portata generosa).

.mini_clusters <- function() {
  tibble::tibble(
    cluster_id = c("A", "B", "C"),
    anchor_key = c("small_molecule|STR:foo|lung",
                   "small_molecule|CHEBI:68534|prostate",
                   "disease_vs_normal|MeSH:D000544|brain"),
    kind_effective_resolved = c("small_molecule", "small_molecule", "disease_vs_normal"),
    canonical_name = c("foo", "Enzalutamide", "Alzheimer's disease"),
    agent_id_resolved = c("STR:foo", "CHEBI:68534", "MeSH:D000544"),
    k = c(1L, 25L, 6L), n_studies = c(1L, 25L, 6L),
    kind_confidence = c("NONE", "STRONG", "STRONG"),
    kind_chebi_zero_roles = c(FALSE, FALSE, FALSE))
}

test_that("triage marca sospetti, canary e skip (test del brief)", {
  cl <- .mini_clusters()
  tr <- .build_suspect_triage(cl)
  expect_identical(tr$role[tr$cluster_id == "A"], "candidate")  # STR: -> sospetto
  expect_identical(tr$role[tr$cluster_id == "B"], "canary")     # noto-buono
})

test_that("vehicle_only e' sempre skip anche se altrimenti forte (a)", {
  cl <- tibble::tibble(
    cluster_id = "V", anchor_key = "vehicle_only|CHEBI:16236|liver",
    kind_effective_resolved = "vehicle_only", canonical_name = "Ethanol",
    agent_id_resolved = "CHEBI:16236", k = 10L, n_studies = 10L,
    kind_confidence = "STRONG", kind_chebi_zero_roles = FALSE)
  tr <- .build_suspect_triage(cl)
  expect_true(is.na(tr$role[tr$cluster_id == "V"]))
  expect_identical(tr$cls[tr$cluster_id == "V"], "vehicle/none")
})

test_that("nome forte + kind STRONG ma k=2 NON e' canary -> skip (b)", {
  cl <- tibble::tibble(
    cluster_id = "K2", anchor_key = "small_molecule|CHEBI:68534|prostate",
    kind_effective_resolved = "small_molecule", canonical_name = "Enzalutamide",
    agent_id_resolved = "CHEBI:68534", k = 2L, n_studies = 2L,
    kind_confidence = "STRONG", kind_chebi_zero_roles = FALSE)
  tr <- .build_suspect_triage(cl)
  expect_true(is.na(tr$role[tr$cluster_id == "K2"]))
  expect_identical(tr$cls[tr$cluster_id == "K2"], "vehicle/none")
})

test_that("kind_chebi_zero_roles=TRUE -> sospetto anche con ID forte (c)", {
  cl <- tibble::tibble(
    cluster_id = "Z", anchor_key = "small_molecule|CHEBI:17199|kidney",
    kind_effective_resolved = "small_molecule", canonical_name = "dihydroxyphthalic acid",
    agent_id_resolved = "CHEBI:17199", k = 8L, n_studies = 8L,
    kind_confidence = "STRONG", kind_chebi_zero_roles = TRUE)
  tr <- .build_suspect_triage(cl)
  expect_identical(tr$role[tr$cluster_id == "Z"], "candidate")
  expect_identical(tr$cls[tr$cluster_id == "Z"], "OMOGENEO+MAL_nominato")
})

test_that("clusters vuoto -> tibble 0 righe con lo schema atteso (d)", {
  cl <- .mini_clusters()[0, ]
  tr <- .build_suspect_triage(cl)
  expect_equal(nrow(tr), 0L)
  expect_identical(names(tr), c("cluster_id", "name", "kind", "k", "n_studies",
                                 "homog", "top_theme", "name_ok", "cls", "role"))
})

test_that("nome garbage/formale (markup HTML) -> sospetto, batte canary (e)", {
  cl <- tibble::tibble(
    cluster_id = "G", anchor_key = "small_molecule|CHEBI:99999|blood",
    kind_effective_resolved = "small_molecule",
    canonical_name = "(<i>R</i>)-laudanosine(1+)",
    agent_id_resolved = "CHEBI:99999", k = 5L, n_studies = 5L,
    kind_confidence = "STRONG", kind_chebi_zero_roles = FALSE)
  tr <- .build_suspect_triage(cl)
  expect_identical(tr$role[tr$cluster_id == "G"], "candidate")
  expect_identical(tr$cls[tr$cluster_id == "G"], "OMOGENEO+MAL_nominato")
})

test_that("round-trip CSV via .load_name_cleanup_candidates riproduce lo stesso role (f, canary-safety guard)", {
  cl <- .mini_clusters()
  tr <- .build_suspect_triage(cl)

  tmp_csv <- withr::local_tempfile(fileext = ".csv")
  utils::write.csv(tr[, c("cluster_id", "name", "kind", "k", "n_studies",
                           "homog", "top_theme", "name_ok", "cls")],
                    tmp_csv, row.names = FALSE)

  rt <- .load_name_cleanup_candidates(tmp_csv)

  kept <- tr[tr$cls != "vehicle/none", , drop = FALSE]
  expect_setequal(rt$cluster_id, kept$cluster_id)
  for (cid in kept$cluster_id) {
    expect_identical(rt$role[rt$cluster_id == cid], kept$role[kept$cluster_id == cid],
                      info = paste("cluster_id =", cid))
  }
})
