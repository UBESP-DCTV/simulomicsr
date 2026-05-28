# test-stage4-e2-robustness.R — FASE E2 T7a paper-grade hardening
#
# Test post-self-review + Codex review per i 5 fix di robustezza:
#   Fix 1: warning fetch_fn esterno + gene_biotype_filter non-NULL
#   Fix 3: errori distinti per axis-missing-biotype / filter-vuoto /
#          filter-non-matcha (con lista biotypes presenti)
#   Fix 4: warning quando NA biotype + filter attivo (forward-compat
#          ARCHS4 future con biotype NA)
#   Fix 5: error esplicito quando H5 manca meta/genes/biotype (es. ARCHS4
#          v1 legacy)
#
# (Fix 2 gene_axis_summary in run_metadata sara' coperto in test
#  dedicato T7b.)

# ============================================================================
# Fix 3 — Errore distinto: axis senza gene_biotype
# ============================================================================

test_that("E2 T7a Fix 3.1 .apply_biotype_filter: axis senza gene_biotype -> errore chiaro", {
  counts <- matrix(1:9, 3, 3,
                    dimnames = list(c("A", "B", "C"),
                                     c("S1", "S2", "S3")))
  axis_no_bt <- list(
    ensembl_gene = c("A", "B", "C"),
    gene_symbol  = c("a", "b", "c")
    # gene_biotype MANCANTE
  )
  expect_error(
    simulomicsr:::.apply_biotype_filter(counts, axis_no_bt, "protein_coding"),
    "gene_biotype"
  )
})

# ============================================================================
# Fix 3 — Errore distinto: filter character(0)
# ============================================================================

test_that("E2 T7a Fix 3.2 .apply_biotype_filter: filter character(0) -> errore (suggerisce NULL)", {
  counts <- matrix(1:9, 3, 3)
  axis <- list(
    ensembl_gene = c("A", "B", "C"),
    gene_symbol  = c("a", "b", "c"),
    gene_biotype = c("protein_coding", "lncRNA", "miRNA")
  )
  expect_error(
    simulomicsr:::.apply_biotype_filter(counts, axis, character(0)),
    "vuoto"
  )
})

# ============================================================================
# Fix 3 — Errore distinto: filter typo -> mostra biotypes presenti
# ============================================================================

test_that("E2 T7a Fix 3.3 .apply_biotype_filter: filter typo non-matcha -> errore mostra biotypes presenti", {
  counts <- matrix(1:9, 3, 3)
  axis <- list(
    ensembl_gene = c("A", "B", "C"),
    gene_symbol  = c("a", "b", "c"),
    gene_biotype = c("protein_coding", "lncRNA", "miRNA")
  )
  err <- tryCatch(
    simulomicsr:::.apply_biotype_filter(counts, axis, "protein-coding"),  # typo
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "protein-coding")
  expect_match(err, "protein_coding")  # nell'elenco biotypes presenti
})

# ============================================================================
# Fix 4 — Warning su NA biotype quando filter attivo
# ============================================================================

test_that("E2 T7a Fix 4 .apply_biotype_filter: NA biotype + filter attivo -> warning count", {
  counts <- matrix(1:12, 4, 3,
                    dimnames = list(c("A", "B", "C", "D"),
                                     c("S1", "S2", "S3")))
  axis <- list(
    ensembl_gene = c("A", "B", "C", "D"),
    gene_symbol  = c("a", "b", "c", "d"),
    gene_biotype = c("protein_coding", NA_character_, "protein_coding",
                     NA_character_)
  )
  expect_warning(
    res <- simulomicsr:::.apply_biotype_filter(counts, axis, "protein_coding"),
    "2 geni con biotype=NA"
  )
  expect_equal(nrow(res$counts), 2L)  # A + C, droppati B + D (NA)
})

test_that("E2 T7a Fix 4b .apply_biotype_filter: 0 NA biotype -> nessun warning", {
  counts <- matrix(1:9, 3, 3)
  axis <- list(
    ensembl_gene = c("A", "B", "C"),
    gene_symbol  = c("a", "b", "c"),
    gene_biotype = c("protein_coding", "lncRNA", "protein_coding")
  )
  expect_silent(simulomicsr:::.apply_biotype_filter(counts, axis, "protein_coding"))
})

# ============================================================================
# Fix 5 — .h5_gene_axis error esplicito se H5 manca meta/genes/biotype
# ============================================================================

test_that("E2 T7a Fix 5 .h5_gene_axis: H5 senza meta/genes/biotype -> errore chiaro", {
  skip_if_not_installed("rhdf5")

  # Crea un H5 mock senza meta/genes/biotype (legacy schema ARCHS4 v1)
  p <- tempfile(fileext = ".h5")
  rhdf5::h5createFile(p)
  rhdf5::h5createGroup(p, "meta")
  rhdf5::h5createGroup(p, "meta/genes")
  rhdf5::h5write(c("ENSG1", "ENSG2", "ENSG3"), p, "meta/genes/ensembl_gene")
  rhdf5::h5write(c("A", "B", "C"), p, "meta/genes/symbol")
  # meta/genes/biotype MANCANTE
  on.exit(unlink(p))

  # Reset cache memo per evitare hit di un'altra run su stesso path
  rm(list = ls(envir = simulomicsr:::.h5_axis_memo),
     envir = simulomicsr:::.h5_axis_memo)

  expect_error(
    simulomicsr:::.h5_gene_axis(p),
    "meta/genes/biotype"
  )
})

# ============================================================================
# Fix 1 — Warning runtime fetch_fn esterno + gene_biotype_filter non-NULL
# ============================================================================

test_that("E2 T7a Fix 1.1 build_stage4_results warning quando fetch_fn esterno + filter non-NULL", {
  # Fixture stage3_clusters vuoto + h5_metadata vuoto + fetch_fn esterno +
  # filter default 'protein_coding' -> warning atteso.
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
  external_fetch <- function(g, s) matrix(0, 0, 0)

  # Cattura tutti i warning emessi e verifica che almeno uno match il
  # pattern E2 Fix 1 (il fixture stage3 minimal puo' emettere altri
  # warning da QC sulle colonne mancanti).
  warns <- character(0)
  res <- withCallingHandlers(
    tryCatch(
      simulomicsr::build_stage4_results(
        stage3_clusters = s3,
        h5_metadata = h5_meta,
        fetch_fn = external_fetch,
        dry_run_inputs_only = TRUE,
        gene_biotype_filter = "protein_coding"
      ),
      error = function(e) conditionMessage(e)
    ),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("fetch_fn esterno", warns)),
              info = paste("Warnings raccolti:",
                            paste(warns, collapse = "; "),
                            "| res:", res))
})

test_that("E2 T7a Fix 1.2 build_stage4_results NESSUN warning quando fetch_fn esterno + filter NULL", {
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
  external_fetch <- function(g, s) matrix(0, 0, 0)

  # Sopprimo warning attesi dal QC su fixture vuoto (Unknown column ecc)
  expect_no_warning({
    suppressWarnings(
      simulomicsr::build_stage4_results(
        stage3_clusters = s3,
        h5_metadata = h5_meta,
        fetch_fn = external_fetch,
        dry_run_inputs_only = TRUE,
        gene_biotype_filter = NULL
      )
    )
  })
})
