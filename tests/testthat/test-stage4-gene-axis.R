# test-stage4-gene-axis.R — FASE E1 ADR-0019 D6
#
# Test per helper .parse_gene_axis(): valida + impacchetta i due vettori
# gene-level (ensembl_gene + symbol) letti da ARCHS4 H5 in un oggetto
# leggibile dal counts cache.
#
# Decisione utente 2026-05-27 (E1, opzione A): schema breaking pulito —
# colonna chiave del DE diventa gene_id (Ensembl, univoco), gene_symbol
# annotation separata. Risolve paralogi ADR-0016 Decision 2 (KIR3DL2 x43,
# HLA, ...) in modo deterministico vs make.unique().
#
# Riferimenti:
#   - R/stage4-counts-cache.R::.h5_gene_axis (refactor T2)
#   - docs/decisions/0019-archs4-metadata-exploitation-v2.md §D6
#   - docs/decisions/0016-stage4-mega-aug-crash-fixes-baseline-pool-cap.md
#     §Decisione 2 (resa obsoleta da E1)

# ============================================================================
# T1.1 — input vuoto
# ============================================================================

test_that("E1 T1.1 input vuoto: list con ensembl/gene_symbol entrambi vuoti", {
  res <- simulomicsr:::.parse_gene_axis(
    ensembl = character(0),
    symbol  = character(0)
  )
  expect_type(res, "list")
  expect_named(res, c("ensembl_gene", "gene_symbol"))
  expect_equal(res$ensembl_gene, character(0))
  expect_equal(res$gene_symbol, character(0))
})

# ============================================================================
# T1.2 — input semplice singleton
# ============================================================================

test_that("E1 T1.2 singleton: 1 ensembl + 1 symbol -> impacchettati", {
  res <- simulomicsr:::.parse_gene_axis(
    ensembl = "ENSG00000123456",
    symbol  = "MYGENE"
  )
  expect_equal(res$ensembl_gene, "ENSG00000123456")
  expect_equal(res$gene_symbol, "MYGENE")
})

# ============================================================================
# T1.3 — lunghezze mismatch -> errore
# ============================================================================

test_that("E1 T1.3 lunghezze mismatch: errore chiaro", {
  expect_error(
    simulomicsr:::.parse_gene_axis(
      ensembl = c("ENSG1", "ENSG2"),
      symbol  = "A"
    ),
    "stessa lunghezza"
  )
})

# ============================================================================
# T1.4 — ensembl duplicati -> errore (safety net per future ARCHS4 versions)
# ============================================================================

test_that("E1 T1.4 ensembl duplicati: errore (axis non puo' essere axis se duplicato)", {
  expect_error(
    simulomicsr:::.parse_gene_axis(
      ensembl = c("ENSG1", "ENSG2", "ENSG1"),
      symbol  = c("A", "B", "A2")
    ),
    "duplicat"
  )
})

# ============================================================================
# T1.5 — ensembl NA -> errore (early fail, ARCHS4 v2.5 ha 0 NA confermato)
# ============================================================================

test_that("E1 T1.5 ensembl NA: errore (early fail)", {
  expect_error(
    simulomicsr:::.parse_gene_axis(
      ensembl = c("ENSG1", NA_character_, "ENSG3"),
      symbol  = c("A", "B", "C")
    ),
    "NA"
  )
})

test_that("E1 T1.5b ensembl stringa vuota: errore (trattato come NA logico)", {
  expect_error(
    simulomicsr:::.parse_gene_axis(
      ensembl = c("ENSG1", "", "ENSG3"),
      symbol  = c("A", "B", "C")
    ),
    "vuot"
  )
})

# ============================================================================
# T1.6 — symbol duplicati OK (paralogi reali: KIR3DL2 x43, HLA, ...)
# ============================================================================

test_that("E1 T1.6 symbol duplicati: ammessi (paralogi); ensembl resta univoco", {
  res <- simulomicsr:::.parse_gene_axis(
    ensembl = c("ENSG_KIR_1", "ENSG_KIR_2", "ENSG_KIR_3"),
    symbol  = c("KIR3DL2", "KIR3DL2", "KIR3DL2")  # 3 paralogi, stesso symbol
  )
  expect_equal(res$ensembl_gene, c("ENSG_KIR_1", "ENSG_KIR_2", "ENSG_KIR_3"))
  expect_equal(res$gene_symbol, c("KIR3DL2", "KIR3DL2", "KIR3DL2"))
})

# ============================================================================
# T1.7 — symbol NA accettato (gene non annotato HGNC) -> NA_character_
# ============================================================================

test_that("E1 T1.7 symbol NA accettato: gene Ensembl senza HGNC symbol", {
  res <- simulomicsr:::.parse_gene_axis(
    ensembl = c("ENSG1", "ENSG2", "ENSG3"),
    symbol  = c("A", NA_character_, "C")
  )
  expect_equal(res$ensembl_gene, c("ENSG1", "ENSG2", "ENSG3"))
  expect_true(is.na(res$gene_symbol[2]))
})

# ============================================================================
# T1.8 — input numerici/factor -> coerce a character
# ============================================================================

test_that("E1 T1.8 factor input: coerced a character", {
  res <- simulomicsr:::.parse_gene_axis(
    ensembl = factor(c("ENSG1", "ENSG2")),
    symbol  = factor(c("A", "B"))
  )
  expect_type(res$ensembl_gene, "character")
  expect_type(res$gene_symbol, "character")
  expect_equal(res$ensembl_gene, c("ENSG1", "ENSG2"))
  expect_equal(res$gene_symbol, c("A", "B"))
})
