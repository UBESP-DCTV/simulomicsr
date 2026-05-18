# test-stage3-fixture-mini.R — integration test Stage 3 su stage2-fixtures-mini
#
# Nota sul formato fixture:
#   - *-sample-facts.json : array di sample_facts stage1.v3 (compatibile con
#     stage1_master indicizzato per GSM).
#   - *-study-summary.json: solo {series_id, title, summary, overall_design},
#     NON il full stage2 schema con replicate_groups + comparisons.
#
# Strategia: costruiamo stage2_master sintetico a partire dai sample-facts:
#   - samples con is_negative_control=TRUE  → gruppo "ctrl"
#   - samples con is_negative_control=FALSE → gruppo "trt"
#   - se entrambi i gruppi hanno ≥1 sample → 1 comparison "ctrl" vs "trt"
#   - GSE con solo un tipo di sample → group-mode solo (nessuna comparison)

test_that("Stage 3 end-to-end su stage2-fixtures-mini (5 GSE)", {
  skip_if_not_installed("jsonlite")

  fixture_dir <- system.file("extdata/stage2-fixtures-mini",
                              package = "simulomicsr")
  skip_if(nchar(fixture_dir) == 0L || !dir.exists(fixture_dir),
          "fixture dir non trovata")

  # --- 1. Identifica i primi 5 GSE che hanno entrambi i file ---
  sf_files  <- list.files(fixture_dir, pattern = "-sample-facts\\.json$",
                           full.names = TRUE)
  gse_ids   <- sub("-sample-facts\\.json$", "", basename(sf_files))
  gse_ids   <- gse_ids[1:min(5L, length(gse_ids))]

  # --- 2. Carica sample-facts → stage1_master (named list per GSM) ---
  stage1_master <- list()
  gse_gsm_map   <- list()  # gse_id → character vector di GSM

  for (gse in gse_ids) {
    sf_path    <- file.path(fixture_dir, sprintf("%s-sample-facts.json", gse))
    facts_list <- jsonlite::fromJSON(sf_path, simplifyVector = FALSE)
    gsm_ids    <- character(0L)
    for (fact in facts_list) {
      gsm <- fact$geo_accession
      if (!is.null(gsm) && !is.na(gsm) && nchar(gsm) > 0L) {
        stage1_master[[gsm]] <- fact
        gsm_ids <- c(gsm_ids, gsm)
      }
    }
    gse_gsm_map[[gse]] <- list(facts = facts_list, gsms = gsm_ids)
  }

  # --- 3. Costruisce stage2_master sintetico da sample-facts ---
  # I file study-summary.json contengono solo {series_id, title, summary,
  # overall_design} (NON il full stage2 schema). Costruiamo replicate_groups +
  # comparisons a partire da is_negative_control nelle sample-facts.

  stage2_master <- list()

  for (gse in gse_ids) {
    facts_list <- gse_gsm_map[[gse]]$facts
    gsm_ids    <- gse_gsm_map[[gse]]$gsms

    if (length(gsm_ids) == 0L) next

    ctrl_gsms <- character(0L)
    trt_gsms  <- character(0L)

    for (i in seq_along(facts_list)) {
      fact   <- facts_list[[i]]
      gsm    <- fact$geo_accession
      if (is.null(gsm) || is.na(gsm) || nchar(gsm) == 0L) next

      perts  <- fact$perturbations
      is_neg <- if (length(perts) > 0L) {
        isTRUE(perts[[1L]]$is_negative_control)
      } else {
        FALSE
      }

      if (is_neg) ctrl_gsms <- c(ctrl_gsms, gsm)
      else        trt_gsms  <- c(trt_gsms, gsm)
    }

    # Costruisce replicate groups
    rgs <- list()
    if (length(ctrl_gsms) > 0L) {
      rgs[[length(rgs) + 1L]] <- list(
        group_id    = "ctrl",
        sample_ids  = ctrl_gsms,
        n           = length(ctrl_gsms),
        primary_role = "control"
      )
    }
    if (length(trt_gsms) > 0L) {
      rgs[[length(rgs) + 1L]] <- list(
        group_id    = "trt",
        sample_ids  = trt_gsms,
        n           = length(trt_gsms),
        primary_role = "treated"
      )
    }

    # Costruisce comparisons (solo se entrambi i gruppi presenti)
    cmps <- list()
    if (length(ctrl_gsms) > 0L && length(trt_gsms) > 0L) {
      cmps[[1L]] <- list(
        comparison_id = "c1",
        treated_group = "trt",
        control_group = "ctrl",
        control_type  = "untreated",
        design_kind   = "treatment_vs_untreated"
      )
    }

    stage2_master[[length(stage2_master) + 1L]] <- list(
      series_id        = gse,
      replicate_groups = rgs,
      comparisons      = cmps
    )
  }

  skip_if(length(stage1_master) == 0L, "stage1_master vuoto — fixture non caricata")
  skip_if(length(stage2_master) == 0L, "stage2_master vuoto — fixture non costruita")

  # --- 4. Esegui orchestrator Stage 3 ---
  s3 <- build_stage3_clusters(stage1_master, stage2_master)

  # --- 5. Verifica struttura output ---
  expect_s3_class(s3, "stage3_result")
  expect_true(nrow(s3$assignments) > 0L)
  expect_true(nrow(s3$clusters) > 0L)
  expect_true(all(s3$assignments$level %in% 0L:4L))
  expect_true(all(s3$assignments$mode %in% c("pair", "group")))

  # Almeno un cluster L0 pair se ci sono comparisons
  if (any(s3$clusters$mode == "pair")) {
    levels_present <- unique(s3$clusters$level[s3$clusters$mode == "pair"])
    expect_true(0L %in% levels_present)
  }

  # --- 6. Idempotenza: run_id stabile per stessi input ---
  s3b <- build_stage3_clusters(stage1_master, stage2_master)
  expect_equal(s3$run_metadata$run_id, s3b$run_metadata$run_id)

  # --- 7. Round-trip su disco (richiede arrow) ---
  skip_if_not_installed("arrow")
  skip_if_not_installed("withr")
  tmp_dir <- withr::local_tempdir()
  write_stage3_to_dir(s3, tmp_dir)
  s3_loaded <- load_stage3(tmp_dir)
  expect_equal(nrow(s3$assignments), nrow(s3_loaded$assignments))
})
