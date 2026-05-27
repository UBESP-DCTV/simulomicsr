# test-stage3-e0-biosample-dedupe.R — FASE E0 ADR-0019 D9
#
# Test per:
#   T1 — .build_pair_records / .build_group_records portano treated/control_sample_ids
#   T2 — .build_biosample_lookup / .build_donor_lookup
#   T3 — .enrich_cluster_metadata con i due lookup (fix n_distinct_donors + nuovo
#        n_distinct_biosamples)
#   T4 — .summarize_clusters cabla i lookup e produce colonna nel cluster tibble
#   T5 — schema_versions registra dedupe_strategy
#
# Fixture mock: usa make_mock_stage3_input() da helper-stage3-fixtures.R
# (GSM1..GSM5, 1 studio GSE100, 1 pair-comparison c1 + group-mode).

# ============================================================================
# T1 — record builders espongono sample_ids
# ============================================================================

test_that("T1 .build_pair_records: record contiene treated_sample_ids + control_sample_ids", {
  input <- make_mock_stage3_input()
  ta <- stage3_default_config()$tier_assignment
  recs <- simulomicsr:::.build_pair_records(
    input$stage2_master, input$stage1_master, ta, cache = NULL
  )

  expect_equal(length(recs), 1L)  # 1 comparison c1
  rec <- recs[[1L]]

  expect_true("treated_sample_ids" %in% names(rec))
  expect_true("control_sample_ids" %in% names(rec))
  expect_equal(rec$treated_sample_ids, c("GSM1", "GSM2"))
  expect_equal(rec$control_sample_ids, c("GSM3", "GSM4"))
})

test_that("T1 .build_group_records: record contiene treated_sample_ids; control_sample_ids = NA", {
  input <- make_mock_stage3_input()
  ta <- stage3_default_config()$tier_assignment
  recs <- simulomicsr:::.build_group_records(
    input$stage2_master, input$stage1_master, ta, cache = NULL
  )

  # 3 replicate_groups => 3 record
  expect_equal(length(recs), 3L)
  rec_g1 <- recs[[1L]]

  expect_true("treated_sample_ids" %in% names(rec_g1))
  expect_true("control_sample_ids" %in% names(rec_g1))
  expect_equal(rec_g1$treated_sample_ids, c("GSM1", "GSM2"))
  # group-mode: nessun control side semantico -> character(0). Evita di
  # contare un NA artificiale nel pool downstream (sample-level dedupe).
  expect_identical(rec_g1$control_sample_ids, character(0))
})

# ============================================================================
# T2 — lookup helpers (biosample + donor)
# ============================================================================

test_that("T2 .build_biosample_lookup: named char vec geo_accession -> SAMN", {
  archs4_meta <- tibble::tibble(
    sample_id    = c("GSM100", "GSM101", "GSM102", "GSM103"),
    series_id    = c("GSE1",   "GSE1",   "GSE2",   "GSE2"),
    biosample_id = c("SAMN001", "SAMN002", "SAMN001", NA_character_)
  )
  lk <- simulomicsr:::.build_biosample_lookup(archs4_meta)

  expect_type(lk, "character")
  expect_named(lk, c("GSM100", "GSM101", "GSM102", "GSM103"))
  expect_equal(lk[["GSM100"]], "SAMN001")
  expect_equal(lk[["GSM102"]], "SAMN001")  # cross-GSE duplicato
  expect_true(is.na(lk[["GSM103"]]))
})

test_that("T2 .build_biosample_lookup: NULL input -> NULL (fallback ok)", {
  expect_null(simulomicsr:::.build_biosample_lookup(NULL))
})

test_that("T2 .build_biosample_lookup: archs4_meta senza colonna biosample_id -> NULL", {
  archs4_meta <- tibble::tibble(sample_id = "GSM100", series_id = "GSE1", gpl = "GPL1")
  expect_null(simulomicsr:::.build_biosample_lookup(archs4_meta))
})

test_that("T2 .build_donor_lookup: named char vec geo_accession -> donor_id", {
  stage1 <- list(
    "GSM100" = list(donor = list(donor_id = "patient_5")),
    "GSM101" = list(donor = list(donor_id = "patient_5")),  # stesso donor intra-studio
    "GSM102" = list(donor = list(donor_id = "patient_6")),
    "GSM103" = list(donor = NULL),                          # no donor info
    "GSM104" = list()                                       # no donor field
  )
  lk <- simulomicsr:::.build_donor_lookup(stage1)

  expect_type(lk, "character")
  expect_setequal(names(lk), c("GSM100", "GSM101", "GSM102", "GSM103", "GSM104"))
  expect_equal(lk[["GSM100"]], "patient_5")
  expect_equal(lk[["GSM102"]], "patient_6")
  expect_true(is.na(lk[["GSM103"]]))
  expect_true(is.na(lk[["GSM104"]]))
})

test_that("T2 .build_donor_lookup: accetta environment (post Phase 1.5 build_stage3_clusters)", {
  s1_env <- new.env(hash = TRUE)
  s1_env$GSM100 <- list(donor = list(donor_id = "A"))
  s1_env$GSM101 <- list(donor = list(donor_id = "B"))
  lk <- simulomicsr:::.build_donor_lookup(s1_env)

  expect_type(lk, "character")
  expect_setequal(names(lk), c("GSM100", "GSM101"))
  expect_equal(lk[["GSM100"]], "A")
  expect_equal(lk[["GSM101"]], "B")
})

test_that("T2 .build_donor_lookup: NULL/empty -> NULL", {
  expect_null(simulomicsr:::.build_donor_lookup(NULL))
  expect_null(simulomicsr:::.build_donor_lookup(list()))
  expect_null(simulomicsr:::.build_donor_lookup(new.env()))
})

# ============================================================================
# T3 — .enrich_cluster_metadata con biosample_lookup + donor_lookup
# ============================================================================

test_that("T3 enrich con biosample_lookup: conta SAMN distinti, duplicati cross-GSE collassano", {
  # 2 record (1 studio ciascuno) con 6 sample totali:
  #   GSE1: GSM1 (SAMN-A), GSM2 (SAMN-B), GSM3 (SAMN-A) <- duplicato intra-studio
  #   GSE2: GSM4 (SAMN-A), GSM5 (SAMN-C), GSM6 (SAMN-D)
  # SAMN-A appare in 2 studi diversi -> e' un cross-GSE dup VERO
  # Atteso: 4 BioSample distinti (A, B, C, D)
  cluster_records <- list(
    list(series_id = "GSE1",
         treated_sample_ids = c("GSM1", "GSM2"),
         control_sample_ids = c("GSM3")),
    list(series_id = "GSE2",
         treated_sample_ids = c("GSM4", "GSM5"),
         control_sample_ids = c("GSM6"))
  )
  bio_lk <- c(GSM1 = "SAMN-A", GSM2 = "SAMN-B", GSM3 = "SAMN-A",
              GSM4 = "SAMN-A", GSM5 = "SAMN-C", GSM6 = "SAMN-D")
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records  = cluster_records,
    biosample_lookup = bio_lk
  )
  expect_equal(result$n_distinct_biosamples, 4L)
})

test_that("T3 enrich con biosample_lookup: NA non collassa (sample senza SAMN = identita' distinta)", {
  cluster_records <- list(
    list(series_id = "GSE1",
         treated_sample_ids = c("GSM1", "GSM2"),
         control_sample_ids = character(0))
  )
  # GSM1 senza SAMN, GSM2 con SAMN-X
  bio_lk <- c(GSM1 = NA_character_, GSM2 = "SAMN-X")
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records  = cluster_records,
    biosample_lookup = bio_lk
  )
  # 1 SAMN known + 1 NA non-collassante = 2 identita' biologiche distinte
  expect_equal(result$n_distinct_biosamples, 2L)
})

test_that("T3 enrich biosample_lookup NULL -> n_distinct_biosamples = NA_integer_", {
  cluster_records <- list(
    list(series_id = "GSE1",
         treated_sample_ids = c("GSM1", "GSM2"),
         control_sample_ids = character(0))
  )
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records  = cluster_records,
    biosample_lookup = NULL
  )
  expect_true(is.na(result$n_distinct_biosamples))
  expect_type(result$n_distinct_biosamples, "integer")
})

test_that("T3 enrich con donor_lookup: conta donor sample-level (fix sotto-stima pre-E0)", {
  # Scenario che esponeva il bug pre-E0:
  # 1 record con 4 sample: 3 donor distinti dentro il SOLO gruppo treated.
  # Pre-E0 (fallback first-sample) -> contava 1 donor.
  # Post-E0 (donor_lookup sample-level) -> conta 3 donor.
  cluster_records <- list(
    list(series_id = "GSE1",
         treated_sample_ids = c("GSM1", "GSM2", "GSM3"),
         control_sample_ids = c("GSM4"),
         stage1_facts = list(donor = list(donor_id = "D1")))  # primo sample, fallback
  )
  donor_lk <- c(GSM1 = "D1", GSM2 = "D2", GSM3 = "D3", GSM4 = "D4")
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    donor_lookup    = donor_lk
  )
  expect_equal(result$n_distinct_donors, 4L)
})

test_that("T3 enrich donor_lookup NULL -> fallback legacy (stage1_facts primo sample) preservato", {
  # Mantiene retrocompat con i 2 test esistenti di test-stage3-metadata.R
  cluster_records <- list(
    list(series_id = "GSE100", stage1_facts = list(donor = list(donor_id = "D1"))),
    list(series_id = "GSE100", stage1_facts = list(donor = list(donor_id = "D2"))),
    list(series_id = "GSE200", stage1_facts = list(donor = list(donor_id = "D1"))),
    list(series_id = "GSE200", stage1_facts = list(donor = NULL))
  )
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    donor_lookup    = NULL
  )
  expect_equal(result$n_distinct_donors, 2L)  # D1 + D2, NULL escluso
})

test_that("T3 enrich con donor_lookup: NA non collassa", {
  cluster_records <- list(
    list(series_id = "GSE1",
         treated_sample_ids = c("GSM1", "GSM2"),
         control_sample_ids = character(0))
  )
  donor_lk <- c(GSM1 = NA_character_, GSM2 = "D-known")
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records = cluster_records,
    donor_lookup    = donor_lk
  )
  # 1 known + 1 NA non-collassante
  expect_equal(result$n_distinct_donors, 2L)
})

test_that("T3 enrich sample non presente nel lookup -> trattato come NA non-collassante", {
  cluster_records <- list(
    list(series_id = "GSE1",
         treated_sample_ids = c("GSM1", "GSM_UNK"),
         control_sample_ids = character(0))
  )
  bio_lk <- c(GSM1 = "SAMN-X")  # GSM_UNK assente
  result <- simulomicsr:::.enrich_cluster_metadata(
    cluster_records  = cluster_records,
    biosample_lookup = bio_lk
  )
  expect_equal(result$n_distinct_biosamples, 2L)  # SAMN-X + 1 unknown
})

# ============================================================================
# T4 — .summarize_clusters cablato (lookups + schema + col output)
# ============================================================================

test_that("T4 build_stage3_clusters: clusters tibble include colonna n_distinct_biosamples", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(
    stage1_master   = input$stage1_master,
    stage2_master   = input$stage2_master,
    config          = stage3_default_config(),
    archs4_metadata = NULL
  )
  expect_true("n_distinct_biosamples" %in% names(s3$clusters))
  expect_type(s3$clusters$n_distinct_biosamples, "integer")
})

test_that("T4 build_stage3_clusters: archs4_metadata con biosample_id -> n_distinct_biosamples calcolato", {
  input <- make_mock_stage3_input()
  archs4_meta <- tibble::tibble(
    sample_id    = c("GSM1", "GSM2", "GSM3", "GSM4", "GSM5"),
    series_id    = c("GSE100", "GSE100", "GSE100", "GSE100", "GSE100"),
    gpl          = c("GPL1", "GPL1", "GPL1", "GPL1", "GPL1"),
    # GSM1=GSM2 stesso SAMN (technical replicate same individual)
    biosample_id = c("SAMN-A", "SAMN-A", "SAMN-B", "SAMN-C", "SAMN-D")
  )
  s3 <- build_stage3_clusters(
    stage1_master   = input$stage1_master,
    stage2_master   = input$stage2_master,
    config          = stage3_default_config(),
    archs4_metadata = archs4_meta
  )
  # Cluster pair c1: 4 sample (GSM1,GSM2,GSM3,GSM4) -> 3 SAMN distinti (A,B,C)
  if (nrow(s3$clusters) > 0L) {
    pair_clusters <- s3$clusters[s3$clusters$mode == "pair", ]
    if (nrow(pair_clusters) > 0L) {
      # almeno un cluster pair deve avere n_distinct_biosamples == 3
      expect_true(any(pair_clusters$n_distinct_biosamples == 3L))
    }
  }
})

test_that("T4 build_stage3_clusters: archs4_metadata SENZA biosample_id -> n_distinct_biosamples = NA", {
  input <- make_mock_stage3_input()
  archs4_meta <- tibble::tibble(
    sample_id = c("GSM1", "GSM2", "GSM3", "GSM4", "GSM5"),
    series_id = c("GSE100", "GSE100", "GSE100", "GSE100", "GSE100"),
    gpl       = c("GPL1", "GPL1", "GPL1", "GPL1", "GPL1")
  )
  s3 <- build_stage3_clusters(
    stage1_master   = input$stage1_master,
    stage2_master   = input$stage2_master,
    config          = stage3_default_config(),
    archs4_metadata = archs4_meta
  )
  if (nrow(s3$clusters) > 0L) {
    expect_true(all(is.na(s3$clusters$n_distinct_biosamples)))
  }
})

# ============================================================================
# T5 — schema_versions registra dedupe_strategy
# ============================================================================

test_that("T5 stage3_default_config: schema_versions include dedupe_strategy = 'biosample_samn_unique'", {
  cfg <- stage3_default_config()
  expect_true("dedupe_strategy" %in% names(cfg$schema_versions))
  expect_equal(cfg$schema_versions$dedupe_strategy, "biosample_samn_unique")
})

test_that("T5 build_stage3_clusters: run_metadata$schema_versions registra dedupe_strategy", {
  input <- make_mock_stage3_input()
  s3 <- build_stage3_clusters(
    stage1_master = input$stage1_master,
    stage2_master = input$stage2_master,
    config        = stage3_default_config()
  )
  expect_equal(s3$run_metadata$schema_versions$dedupe_strategy,
               "biosample_samn_unique")
})
