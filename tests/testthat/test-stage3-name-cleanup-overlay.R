test_that("overlay mappa i GSM dei cluster override all'identita' corretta", {
  side <- tibble::tibble(
    cluster_id = c("group_L4_A", "group_L4_B"),
    new_id = c("CHEBI:68534", NA), new_canonical = c("Enzalutamide", NA),
    new_kind = c("small_molecule", NA), action = c("override", "flag_review"))
  asg <- tibble::tibble(cluster_id = c("group_L4_A","group_L4_B"),
                        record_id  = c("GSE1__grp1","GSE2__grp2"))
  r2g <- function(rid) if (rid == "GSE1__grp1") c("GSM1","GSM2") else "GSM9"
  ov <- .side_table_to_recovery_overlay(side, asg, r2g)
  expect_setequal(names(ov), c("GSM1","GSM2"))           # solo override
  expect_identical(ov[["GSM1"]]$agent_id, "CHEBI:68534")
  expect_identical(ov[["GSM1"]]$recovery_source, "LLM_NAME_CLEANUP")
  expect_false("GSM9" %in% names(ov))                     # flag_review escluso
})

test_that("overlay vince sul recovery deterministico per i GSM rivisti", {
  env <- new.env(hash = TRUE, parent = emptyenv())
  assign("GSM1", list(kind="small_molecule", agent_id="CHEBI:2decenal",
                      canonical_name="2-decenal", recovery_source="CHEBI"), envir=env)
  assign("GSMx", list(kind="disease", agent_id="MeSH:D1", canonical_name="x",
                      recovery_source="MESH"), envir=env)
  ov <- list(GSM1 = list(kind="small_molecule", agent_id="CHEBI:68534",
                         canonical_name="Enzalutamide", recovery_source="LLM_NAME_CLEANUP"))
  out <- .overlay_recovery_lookup(env, ov)
  expect_identical(get("GSM1", envir=out)$agent_id, "CHEBI:68534")
  expect_identical(get("GSMx", envir=out)$agent_id, "MeSH:D1")  # invariato
})
