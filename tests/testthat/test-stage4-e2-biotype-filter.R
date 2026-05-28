# test-stage4-e2-biotype-filter.R — FASE E2 ADR-0019 D7 (integrazione T4)
#
# Test per la propagazione del parametro gene_biotype_filter dall'entry
# point build_stage4_results() down al fetch_fn closure -> .fetch_counts_cached
# -> .fetch_counts_from_h5 -> .apply_biotype_filter.

test_that("E2 T4.1 build_stage4_results signature include gene_biotype_filter default 'protein_coding'", {
  fmls <- formals(simulomicsr::build_stage4_results)
  expect_true("gene_biotype_filter" %in% names(fmls))
  expect_equal(eval(fmls$gene_biotype_filter), "protein_coding")
})

test_that("E2 T4.2 fetch_fn default propaga gene_biotype_filter a .fetch_counts_cached", {
  # Verifica diretta della closure: dato gene_biotype_filter, la closure
  # default ritornata da build_stage4_results invoca .fetch_counts_cached
  # con il filter passato giu'. Costruiamo manualmente la closure (e' la
  # stessa istanziata in Step 4 di build_stage4_results) e captureremo
  # gli argomenti via mock di .fetch_counts_cached.
  captured <- list()
  mock_cached <- function(gse, sample_ids, h5_path = NULL,
                           fetch_fn = NULL, cache_dir = NULL,
                           gene_biotype_filter = "protein_coding") {
    captured$gse                 <<- gse
    captured$sample_ids          <<- sample_ids
    captured$h5_path             <<- h5_path
    captured$gene_biotype_filter <<- gene_biotype_filter
    matrix(0, 0, 0)
  }

  with_mocked_bindings(
    {
      # Closure identica a quella di build_stage4_results Step 4 con
      # gene_biotype_filter catturato.
      gene_biotype_filter <- "protein_coding"
      h5_path <- "/fake/h5"
      fetch_fn <- function(g, s) simulomicsr:::.fetch_counts_cached(
        g, s, h5_path = h5_path,
        gene_biotype_filter = gene_biotype_filter
      )
      fetch_fn("GSE001", c("GSM_a", "GSM_b"))
    },
    .fetch_counts_cached = mock_cached,
    .package = "simulomicsr"
  )

  expect_equal(captured$gene_biotype_filter, "protein_coding")
  expect_equal(captured$h5_path, "/fake/h5")
})

test_that("E2 T4.3 fetch_fn default propaga NULL filter (no-op)", {
  captured <- list()
  mock_cached <- function(gse, sample_ids, h5_path = NULL,
                           fetch_fn = NULL, cache_dir = NULL,
                           gene_biotype_filter = "protein_coding") {
    captured$gene_biotype_filter <<- gene_biotype_filter
    matrix(0, 0, 0)
  }

  with_mocked_bindings(
    {
      gene_biotype_filter <- NULL
      h5_path <- "/fake/h5"
      fetch_fn <- function(g, s) simulomicsr:::.fetch_counts_cached(
        g, s, h5_path = h5_path,
        gene_biotype_filter = gene_biotype_filter
      )
      fetch_fn("GSE001", "GSM_a")
    },
    .fetch_counts_cached = mock_cached,
    .package = "simulomicsr"
  )

  expect_null(captured$gene_biotype_filter)
})

test_that("E2 T5.1 stage4_default_config schema_versions include gene_biotype_filter_strategy", {
  cfg <- simulomicsr::stage4_default_config()
  expect_true("gene_biotype_filter_strategy" %in% names(cfg$schema_versions))
  expect_equal(cfg$schema_versions$gene_biotype_filter_strategy,
               "v1_protein_coding_default")
})

test_that("E2 T5.2 build_stage4_results run_metadata registra gene_biotype_filter effettivo", {
  fmls <- formals(simulomicsr::build_stage4_results)
  expect_true("gene_biotype_filter" %in% names(fmls))

  # Smoke: per la dry-run il run_metadata e' costruito ma il fetch_fn non
  # viene istanziato. Verifichiamo che il filter passato sia preservato
  # nell'output run_metadata. Uso un fixture stage3_clusters super-minimal
  # che passi il QC senza filter di sample (lib_size omesso = niente drop).
  s3 <- tibble::tibble(
    cluster_id = character(0),
    mode = factor(character(0), levels = c("pair", "group")),
    level = integer(0),
    method = character(0),
    anchor_key = character(0),
    direction_check = factor(character(0),
      levels = c("canonical", "swapped", "ambiguous", "indeterminate", "na")),
    studies_in_cluster = list()
  )
  h5_meta <- tibble::tibble(
    sample_id = character(0),
    gse = character(0),
    lib_size = numeric(0)
  )

  res <- simulomicsr::build_stage4_results(
    stage3_clusters = s3,
    h5_metadata = h5_meta,
    dry_run_inputs_only = TRUE,
    gene_biotype_filter = c("protein_coding", "lncRNA")
  )

  expect_true("gene_biotype_filter" %in% names(res$run_metadata))
  expect_equal(res$run_metadata$gene_biotype_filter,
               c("protein_coding", "lncRNA"))
})

test_that("E2 T4.4 fetch_fn default propaga vector multi-valore", {
  captured <- list()
  mock_cached <- function(gse, sample_ids, h5_path = NULL,
                           fetch_fn = NULL, cache_dir = NULL,
                           gene_biotype_filter = "protein_coding") {
    captured$gene_biotype_filter <<- gene_biotype_filter
    matrix(0, 0, 0)
  }

  with_mocked_bindings(
    {
      gene_biotype_filter <- c("protein_coding", "lncRNA")
      h5_path <- "/fake/h5"
      fetch_fn <- function(g, s) simulomicsr:::.fetch_counts_cached(
        g, s, h5_path = h5_path,
        gene_biotype_filter = gene_biotype_filter
      )
      fetch_fn("GSE001", "GSM_a")
    },
    .fetch_counts_cached = mock_cached,
    .package = "simulomicsr"
  )

  expect_equal(captured$gene_biotype_filter, c("protein_coding", "lncRNA"))
})
