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

test_that("overlay canonicalizza cytokine/pathogen GREZZI di Mistral a kind-anchor", {
  # Mistral emette `new_kind` in vocabolario libero: "cytokine"/"pathogen" NON
  # fanno scattare il branch (b) di .extract_anchor_segments (che vuole
  # cytokine_stim / pathogen_or_aggregate_exposure) -> merge mancato. L'overlay
  # deve tradurli alla forma canonica.
  side <- tibble::tibble(
    cluster_id = c("group_L4_C", "group_L4_P"),
    new_id = c("HGNC:6019", "NCBITaxon:2697049"),
    new_canonical = c("IL6", "SARS-CoV-2"),
    new_kind = c("cytokine", "pathogen"),
    action = c("override", "override"))
  asg <- tibble::tibble(cluster_id = c("group_L4_C","group_L4_P"),
                        record_id  = c("GSE1__grp1","GSE2__grp2"))
  r2g <- function(rid) if (rid == "GSE1__grp1") "GSM1" else "GSM2"
  ov <- .side_table_to_recovery_overlay(side, asg, r2g)
  expect_identical(ov[["GSM1"]]$kind, "cytokine_stim")
  expect_identical(ov[["GSM2"]]$kind, "pathogen_or_aggregate_exposure")
})

test_that("overlay scarta i genetic_* NON-anchor (kind -> NA, niente iniezione)", {
  # "genetic_mutation"/"genetic_variant" iniziano per genetic_ -> farebbero
  # scattare il branch (b) e inietterebbero un kind NON-anchor -> un-bucketing.
  # Vanno scartati (kind NA) cosi' (b) fa no-op e resta il kind deterministico.
  side <- tibble::tibble(
    cluster_id = c("group_L0_M", "group_L0_V"),
    new_id = c("HGNC:11998", "HGNC:6407"),
    new_canonical = c("TP53", "KRAS"),
    new_kind = c("genetic_mutation", "genetic_variant"),
    action = c("override", "override"))
  asg <- tibble::tibble(cluster_id = c("group_L0_M","group_L0_V"),
                        record_id  = c("GSE1__g","GSE2__g"))
  r2g <- function(rid) if (rid == "GSE1__g") "GSM1" else "GSM2"
  ov <- .side_table_to_recovery_overlay(side, asg, r2g)
  expect_true(is.na(ov[["GSM1"]]$kind))   # genetic_mutation scartato
  expect_true(is.na(ov[["GSM2"]]$kind))   # genetic_variant scartato
  expect_identical(ov[["GSM1"]]$agent_id, "HGNC:11998")  # ID e nome restano
  expect_identical(ov[["GSM1"]]$canonical_name, "TP53")
})

test_that("overlay lascia invariati i kind anchor-validi e i non-(b)", {
  # genetic_knockout (anchor) e cytokine_stim (gia' canonico) invariati; disease
  # e small_molecule non fanno scattare (b) -> passano intatti (kind deterministico
  # a valle governa comunque, l'overlay corregge solo l'agent_id).
  side <- tibble::tibble(
    cluster_id = c("group_L0_K", "group_L4_S", "group_L4_D", "group_L4_Z"),
    new_id = c("HGNC:1", "CHEBI:16236", "MeSH:D001943", "HGNC:2"),
    new_canonical = c("g", "ethanol", "Breast Neoplasms", "il"),
    new_kind = c("genetic_knockout", "cytokine_stim", "disease_vs_normal", "small_molecule"),
    action = rep("override", 4))
  asg <- tibble::tibble(cluster_id = c("group_L0_K","group_L4_S","group_L4_D","group_L4_Z"),
                        record_id  = c("A__g","B__g","C__g","D__g"))
  r2g <- function(rid) sub("__.*$", "", rid)
  ov <- .side_table_to_recovery_overlay(side, asg, r2g)
  expect_identical(ov[["A"]]$kind, "genetic_knockout")
  expect_identical(ov[["B"]]$kind, "cytokine_stim")
  expect_identical(ov[["C"]]$kind, "disease_vs_normal")
  expect_identical(ov[["D"]]$kind, "small_molecule")
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
