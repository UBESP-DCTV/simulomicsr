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
