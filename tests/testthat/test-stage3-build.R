# test-stage3-build.R — test dell'orchestrator build_stage3_clusters

test_that("build_stage3_clusters restituisce stage3_result S3 con le 5 componenti", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(
    stage1_master   = input$stage1_master,
    stage2_master   = input$stage2_master,
    config          = stage3_default_config(),
    archs4_metadata = NULL
  )

  expect_s3_class(s3, "stage3_result")
  expect_named(s3, c("assignments", "clusters", "record_summary",
                      "non_clusterable", "run_metadata"),
               ignore.order = TRUE)

  expect_s3_class(s3$assignments,     "tbl_df")
  expect_s3_class(s3$clusters,        "tbl_df")
  expect_s3_class(s3$record_summary,  "tbl_df")
  expect_s3_class(s3$non_clusterable, "tbl_df")
  expect_type(s3$run_metadata, "list")
})

test_that("run_metadata contiene run_id + schema_versions + output_counts", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(
    stage1_master = input$stage1_master,
    stage2_master = input$stage2_master,
    config        = stage3_default_config()
  )

  rm <- s3$run_metadata
  expect_match(rm$run_id, "^[0-9a-f]{8}$")
  # Anchor v3.1 (ADR-0018): aggiunge "resolver" alle schema_versions.
  # FASE E0 (ADR-0019 D9): aggiunge "dedupe_strategy" alle schema_versions.
  expect_named(rm$schema_versions,
               c("anchor", "stage3_algorithm", "sample_facts", "study_design",
                 "resolver", "dedupe_strategy"),
               ignore.order = TRUE)
  expect_equal(rm$schema_versions$anchor, "v3.1.1")
  expect_equal(rm$schema_versions$resolver, "v1.1.0")
  expect_equal(rm$schema_versions$dedupe_strategy, "biosample_samn_unique")
  expect_true("output_counts" %in% names(rm))
  # Anchor v3.1: ontology_releases registrato per riproducibilita' paper-grade
  expect_true("ontology_releases" %in% names(rm))
})

test_that("idempotenza: stesso input -> stesso run_id", {
  input <- make_mock_stage3_input()
  s3a <- build_stage3_clusters(input$stage1_master, input$stage2_master,
                                config = stage3_default_config())
  s3b <- build_stage3_clusters(input$stage1_master, input$stage2_master,
                                config = stage3_default_config())
  expect_equal(s3a$run_metadata$run_id, s3b$run_metadata$run_id)
})

test_that("assignments ha colonne obbligatorie (record_id, mode, level, cluster_id, anchor_key)", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master,
                               config = stage3_default_config())
  req_cols <- c("record_id", "mode", "level", "cluster_id", "anchor_key")
  expect_true(all(req_cols %in% names(s3$assignments)))
})

test_that("clusters ha colonne obbligatorie (cluster_id, mode, level, anchor_key, k, n_total)", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master,
                               config = stage3_default_config())
  if (nrow(s3$clusters) > 0L) {
    req_cols <- c("cluster_id", "mode", "level", "anchor_key",
                  "k", "n_total", "safety_min",
                  "usable_rem_strict", "usable_rem_relaxed",
                  "usable_mega_strict", "usable_mega_relaxed")
    expect_true(all(req_cols %in% names(s3$clusters)))
  } else {
    # Anche tibble vuoto deve avere le colonne
    req_cols <- c("cluster_id", "mode", "level", "anchor_key",
                  "k", "n_total", "safety_min")
    expect_true(all(req_cols %in% names(s3$clusters)))
  }
})

test_that("non_clusterable ha colonne (record_id, mode, reason, details)", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master,
                               config = stage3_default_config())
  req_cols <- c("record_id", "mode", "reason", "details")
  expect_true(all(req_cols %in% names(s3$non_clusterable)))
})

test_that("pair record GSE100__c1 produce assignment a L0..L4 (5 righe per record)", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master,
                               config = stage3_default_config())
  # c1 e' eligible (n=2 per lato, direction canonical)
  pair_asg <- s3$assignments[s3$assignments$record_id == "GSE100__c1" &
                               s3$assignments$mode == "pair", ]
  # 5 livelli L0..L4 -> 5 righe
  expect_equal(nrow(pair_asg), 5L)
  expect_setequal(pair_asg$level, 0L:4L)
})

test_that("record_summary contiene GSE100__c1 con min_viable_level_rem (pair)", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master,
                               config = stage3_default_config())
  rs_pair <- s3$record_summary[s3$record_summary$record_id == "GSE100__c1" &
                                  s3$record_summary$mode == "pair", ]
  expect_equal(nrow(rs_pair), 1L)
  # k=1 (unico studio) -> usable_rem_relaxed richiede k>=2 -> NONE
  # oppure il test controlla solo la presenza della colonna
  expect_true("min_viable_level_rem" %in% names(rs_pair))
})

test_that("output_counts in run_metadata include n_records_input_stage2", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master,
                               config = stage3_default_config())
  oc <- s3$run_metadata$output_counts
  expect_true("n_records_input_stage2" %in% names(oc))
  expect_equal(oc$n_records_input_stage2, 1L)  # 1 studio nel mock
})

test_that("input vuoto stage2 -> empty assignments + clusters + non_clusterable", {
  s3 <- build_stage3_clusters(
    stage1_master = list(),
    stage2_master = list(),
    config        = stage3_default_config()
  )
  expect_s3_class(s3, "stage3_result")
  expect_equal(nrow(s3$assignments), 0L)
  expect_equal(nrow(s3$clusters), 0L)
  expect_equal(nrow(s3$non_clusterable), 0L)
})

test_that("anchor_key L0 e L4 differenti per stesso record (L4 ha meno segmenti)", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(input$stage1_master, input$stage2_master,
                               config = stage3_default_config())
  asg_pair <- s3$assignments[s3$assignments$record_id == "GSE100__c1" &
                               s3$assignments$mode == "pair", ]
  if (nrow(asg_pair) >= 5L) {
    key_l0 <- asg_pair$anchor_key[asg_pair$level == 0L]
    key_l4 <- asg_pair$anchor_key[asg_pair$level == 4L]
    # L0 ha piu' segmenti (13+13 + CT) di L4 (3+3 + CT)
    expect_true(nchar(key_l0) > nchar(key_l4))
  }
})

# --- Test Task 10: thread recovery lookup nel build Stadio 3 -------------------

# Fixture: sample_fact disease-case senza mesh_id_candidate -> agent_id = "UNK"
# Retrocompat: stage2_role="treated" + disease_state$status="case" + no active
# perturbation -> is_disease_design = TRUE -> ramo disease -> mesh_raw = "unknown"
# -> agent_id = "UNK".
.make_unk_disease_fact <- function() {
  list(
    perturbations = list(list(
      kind             = "none",
      agent_normalized = list(id = "unknown", preferred_name = "unknown",
                              type = "unclear"),
      dose             = list(value_raw = "nodose"),
      duration         = list(value_raw = "N/A"),
      phase            = "exposure"
    )),
    cell_context = list(
      cell_type_or_line_raw           = "blood",
      cell_line_cellosaurus_candidate = NULL,
      context_kind                    = "primary_tissue",
      cell_state                      = "basal",
      subcellular_fraction            = NULL,
      tissue                          = "blood",
      engineered_modifications        = list()
    ),
    disease_state = list(status = "case", mesh_id_candidate = NULL)
  )
}

# Stage2 mock minimale con 1 studio, 2 gruppi, 1 comparison; GSM_UNK = trattato.
# Usato sia dal test di .precompute_anchor_cache sia da build_stage3_clusters.
.make_unk_stage_input <- function(gsm_id = "GSM_UNK_DISEASE") {
  unk_fact  <- .make_unk_disease_fact()
  ctrl_fact <- make_test_sample_fact()   # agente noto -> anchor non-UNK
  ctrl_fact$perturbations[[1]]$kind <- "none"
  ctrl_fact$perturbations[[1]]$agent_normalized <- list(id = "unknown",
                                                         preferred_name = "vehicle",
                                                         type = "vehicle")
  ctrl_gsm  <- paste0(gsm_id, "_ctrl")
  list(
    stage1_master = stats::setNames(
      list(unk_fact, unk_fact, ctrl_fact, ctrl_fact),
      c(gsm_id, paste0(gsm_id, "2"), ctrl_gsm, paste0(ctrl_gsm, "2"))
    ),
    stage2_master = list(list(
      series_id        = "GSE_UNK_TEST",
      replicate_groups = list(
        list(group_id = "g1", sample_ids = c(gsm_id, paste0(gsm_id, "2")),
             n = 2L, primary_role = "treated"),
        list(group_id = "g2", sample_ids = c(ctrl_gsm, paste0(ctrl_gsm, "2")),
             n = 2L, primary_role = "control")
      ),
      comparisons = list(list(
        comparison_id = "c_unk",
        treated_group = "g1",
        control_group = "g2",
        control_type  = "untreated",
        design_kind   = "case_control_disease"
      ))
    ))
  )
}

test_that(".precompute_anchor_cache con recovery_lookup non-NULL sostituisce UNK con agente recuperato", {
  gsm_id   <- "GSM_UNK_DISEASE"
  input    <- .make_unk_stage_input(gsm_id)
  ta       <- stage3_default_config()$tier_assignment
  s1_env   <- list2env(input$stage1_master, hash = TRUE)

  # Recovery lookup: il GSM_UNK ottiene identita' recuperata da GEO metadata
  rec_env <- new.env(hash = TRUE, parent = emptyenv())
  assign(gsm_id, list(
    kind           = "disease_vs_normal",
    agent_id       = "MeSH:D011279",
    canonical_name = "Prostatic Neoplasms",
    recovery_source = "GEO_CHARACTERISTICS_PARSE"
  ), envir = rec_env)

  cache_with <- simulomicsr:::.precompute_anchor_cache(
    input$stage2_master, s1_env, ta, recovery_lookup = rec_env
  )

  key <- sprintf("%s|treated", gsm_id)
  expect_true(exists(key, envir = cache_with$anchors, inherits = FALSE))
  segs_with <- get(key, envir = cache_with$anchors, inherits = FALSE)
  # Con recovery: agent_id deve essere quello recuperato, non "UNK"
  expect_equal(segs_with$agent_id, "MeSH:D011279")
  # Campo di traccia: recovery_source presente (indica recovery attivo).
  # tracking_meta e' un attr(), non un list element (vedere stage3-anchor-levels.R)
  tm_with <- attr(segs_with, "tracking_meta")
  expect_equal(tm_with$recovery_source, "GEO_CHARACTERISTICS_PARSE")
})

test_that(".precompute_anchor_cache con recovery_lookup = NULL preserva agent_id UNK (retrocompat)", {
  gsm_id <- "GSM_UNK_DISEASE"
  input  <- .make_unk_stage_input(gsm_id)
  ta     <- stage3_default_config()$tier_assignment
  s1_env <- list2env(input$stage1_master, hash = TRUE)

  cache_null <- simulomicsr:::.precompute_anchor_cache(
    input$stage2_master, s1_env, ta, recovery_lookup = NULL
  )

  key <- sprintf("%s|treated", gsm_id)
  expect_true(exists(key, envir = cache_null$anchors, inherits = FALSE))
  segs_null <- get(key, envir = cache_null$anchors, inherits = FALSE)
  # Senza recovery: agent_id resta "UNK" (comportamento originale invariato)
  expect_equal(segs_null$agent_id, "UNK")
  # Nessun campo recovery_source nel tracking_meta quando recovery = NULL.
  # tracking_meta e' un attr(), non un list element.
  tm_null <- attr(segs_null, "tracking_meta")
  expect_false("recovery_source" %in% names(tm_null))
})

test_that("build_stage3_clusters con name_recovery_lookup = NULL non regredisce (retrocompat)", {
  # Stesso input del mock esistente: nessun UNK, recovery_lookup = NULL
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(
    stage1_master        = input$stage1_master,
    stage2_master        = input$stage2_master,
    config               = stage3_default_config(),
    name_recovery_lookup = NULL
  )
  expect_s3_class(s3, "stage3_result")
  # Assignment per la comparison c1 deve essere presente (retrocompat esatta)
  pair_asg <- s3$assignments[s3$assignments$record_id == "GSE100__c1" &
                               s3$assignments$mode == "pair", ]
  expect_equal(nrow(pair_asg), 5L)
})
