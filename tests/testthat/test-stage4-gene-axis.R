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

test_that("E1 T1.1 input vuoto: list con 3 componenti vuoti (E2 estende gene_biotype)", {
  res <- simulomicsr:::.parse_gene_axis(
    ensembl = character(0),
    symbol  = character(0)
  )
  expect_type(res, "list")
  expect_named(res, c("ensembl_gene", "gene_symbol", "gene_biotype"))
  expect_equal(res$ensembl_gene, character(0))
  expect_equal(res$gene_symbol, character(0))
  expect_equal(res$gene_biotype, character(0))
})

# ============================================================================
# T1.2 — input semplice singleton
# ============================================================================

test_that("E1 T1.2 singleton: 1 ensembl + 1 symbol -> impacchettati (E2: gene_biotype NA se non fornito)", {
  res <- simulomicsr:::.parse_gene_axis(
    ensembl = "ENSG00000123456",
    symbol  = "MYGENE"
  )
  expect_equal(res$ensembl_gene, "ENSG00000123456")
  expect_equal(res$gene_symbol, "MYGENE")
  expect_true(is.na(res$gene_biotype))
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

# ============================================================================
# T2 — .attach_gene_annotation: setta rownames = ensembl + attr gene_symbol
# ============================================================================

test_that("E1 T2.1 attach_gene_annotation: rownames = ensembl + attr gene_symbol named", {
  counts <- matrix(1:12, nrow = 3, ncol = 4)
  colnames(counts) <- c("GSM1", "GSM2", "GSM3", "GSM4")
  axis <- list(
    ensembl_gene = c("ENSG_A", "ENSG_B", "ENSG_C"),
    gene_symbol  = c("SYM_A", "SYM_B", "SYM_C")
  )
  res <- simulomicsr:::.attach_gene_annotation(counts, axis)

  expect_equal(rownames(res), c("ENSG_A", "ENSG_B", "ENSG_C"))
  expect_equal(colnames(res), c("GSM1", "GSM2", "GSM3", "GSM4"))
  expect_equal(res, counts, ignore_attr = TRUE)  # contenuto identico

  gs <- attr(res, "gene_symbol")
  expect_type(gs, "character")
  expect_equal(unname(gs), c("SYM_A", "SYM_B", "SYM_C"))
  expect_equal(names(gs), c("ENSG_A", "ENSG_B", "ENSG_C"))
})

test_that("E1 T2.2 attach_gene_annotation: lookup subset via attr funziona post-filter", {
  counts <- matrix(1:9, nrow = 3, ncol = 3)
  axis <- list(
    ensembl_gene = c("ENSG_A", "ENSG_B", "ENSG_C"),
    gene_symbol  = c("SYM_A", NA_character_, "SYM_C")
  )
  res <- simulomicsr:::.attach_gene_annotation(counts, axis)

  # Simula un filterByExpr post-fit che ritorna solo ENSG_A + ENSG_C:
  filtered <- res[c("ENSG_A", "ENSG_C"), , drop = FALSE]
  # L'attr non e' propagato dal subset standard di matrici. Devo recuperarlo
  # dall'originale.
  gs_orig <- attr(res, "gene_symbol")
  expect_equal(unname(gs_orig[c("ENSG_A", "ENSG_C")]), c("SYM_A", "SYM_C"))
  # NA symbol risolto correttamente
  expect_true(is.na(gs_orig["ENSG_B"]))
})

test_that("E1 T2.3 attach_gene_annotation: mismatch lunghezza axis vs nrow(counts) -> errore", {
  counts <- matrix(1:6, nrow = 2, ncol = 3)
  axis <- list(
    ensembl_gene = c("ENSG_A", "ENSG_B", "ENSG_C"),
    gene_symbol  = c("SYM_A", "SYM_B", "SYM_C")
  )
  expect_error(
    simulomicsr:::.attach_gene_annotation(counts, axis),
    "nrow"
  )
})

# ============================================================================
# E2 T1 — .parse_gene_axis accetta biotype come 3° arg (ADR-0019 D7)
# ============================================================================

test_that("E2 T1.1 parse_gene_axis include biotype quando fornito", {
  res <- simulomicsr:::.parse_gene_axis(
    ensembl = c("ENSG_A", "ENSG_B", "ENSG_C"),
    symbol  = c("A", "B", "C"),
    biotype = c("protein_coding", "lncRNA", "protein_coding")
  )
  expect_named(res, c("ensembl_gene", "gene_symbol", "gene_biotype"))
  expect_equal(res$gene_biotype, c("protein_coding", "lncRNA", "protein_coding"))
})

test_that("E2 T1.2 parse_gene_axis biotype default NULL: gene_biotype = NA cross-row", {
  # Retrocompat: chiamatori pre-E2 non passano biotype -> tutti NA.
  res <- simulomicsr:::.parse_gene_axis(
    ensembl = c("ENSG_A", "ENSG_B"),
    symbol  = c("A", "B")
  )
  expect_named(res, c("ensembl_gene", "gene_symbol", "gene_biotype"))
  expect_true(all(is.na(res$gene_biotype)))
})

test_that("E2 T1.3 parse_gene_axis biotype lunghezza mismatch: errore", {
  expect_error(
    simulomicsr:::.parse_gene_axis(
      ensembl = c("ENSG_A", "ENSG_B"),
      symbol  = c("A", "B"),
      biotype = "protein_coding"
    ),
    "stessa lunghezza"
  )
})

test_that("E2 T1.4 parse_gene_axis biotype NA accettato (gene non annotato Ensembl biotype)", {
  res <- simulomicsr:::.parse_gene_axis(
    ensembl = c("ENSG_A", "ENSG_B"),
    symbol  = c("A", "B"),
    biotype = c("protein_coding", NA_character_)
  )
  expect_true(is.na(res$gene_biotype[2]))
})

# ============================================================================
# E2 T1.5 — .attach_gene_annotation: attr gene_biotype anche quando presente
# ============================================================================

test_that("E2 T1.5 attach_gene_annotation: setta attr gene_biotype named se presente in axis", {
  counts <- matrix(1:9, nrow = 3, ncol = 3)
  axis <- list(
    ensembl_gene = c("ENSG_A", "ENSG_B", "ENSG_C"),
    gene_symbol  = c("A", "B", "C"),
    gene_biotype = c("protein_coding", "lncRNA", "miRNA")
  )
  res <- simulomicsr:::.attach_gene_annotation(counts, axis)
  bt <- attr(res, "gene_biotype")
  expect_type(bt, "character")
  expect_equal(unname(bt), c("protein_coding", "lncRNA", "miRNA"))
  expect_equal(names(bt), c("ENSG_A", "ENSG_B", "ENSG_C"))
})

# ============================================================================
# E2 T2 — .apply_biotype_filter: helper puro subset counts + axis
# ============================================================================

test_that("E2 T2.1 apply_biotype_filter NULL: ritorna invariato (retrocompat)", {
  counts <- matrix(1:9, nrow = 3, ncol = 3,
                    dimnames = list(c("ENSG_A", "ENSG_B", "ENSG_C"),
                                     c("GSM1", "GSM2", "GSM3")))
  axis <- list(
    ensembl_gene = c("ENSG_A", "ENSG_B", "ENSG_C"),
    gene_symbol  = c("A", "B", "C"),
    gene_biotype = c("protein_coding", "lncRNA", "miRNA")
  )
  res <- simulomicsr:::.apply_biotype_filter(counts, axis, NULL)
  expect_equal(nrow(res$counts), 3L)
  expect_equal(res$gene_axis$gene_biotype,
               c("protein_coding", "lncRNA", "miRNA"))
})

test_that("E2 T2.2 apply_biotype_filter 'protein_coding' filtra a 1 gene", {
  counts <- matrix(1:9, nrow = 3, ncol = 3,
                    dimnames = list(c("ENSG_A", "ENSG_B", "ENSG_C"),
                                     c("GSM1", "GSM2", "GSM3")))
  axis <- list(
    ensembl_gene = c("ENSG_A", "ENSG_B", "ENSG_C"),
    gene_symbol  = c("A", "B", "C"),
    gene_biotype = c("protein_coding", "lncRNA", "miRNA")
  )
  res <- simulomicsr:::.apply_biotype_filter(counts, axis, "protein_coding")
  expect_equal(nrow(res$counts), 1L)
  expect_equal(res$gene_axis$ensembl_gene, "ENSG_A")
  expect_equal(res$gene_axis$gene_biotype, "protein_coding")
  expect_equal(rownames(res$counts), "ENSG_A")
})

test_that("E2 T2.3 apply_biotype_filter vector c('protein_coding','lncRNA') union", {
  counts <- matrix(1:9, nrow = 3, ncol = 3,
                    dimnames = list(c("ENSG_A", "ENSG_B", "ENSG_C"),
                                     c("GSM1", "GSM2", "GSM3")))
  axis <- list(
    ensembl_gene = c("ENSG_A", "ENSG_B", "ENSG_C"),
    gene_symbol  = c("A", "B", "C"),
    gene_biotype = c("protein_coding", "lncRNA", "miRNA")
  )
  res <- simulomicsr:::.apply_biotype_filter(counts, axis,
                                              c("protein_coding", "lncRNA"))
  expect_equal(nrow(res$counts), 2L)
  expect_setequal(res$gene_axis$ensembl_gene, c("ENSG_A", "ENSG_B"))
})

test_that("E2 T2.4 apply_biotype_filter biotype non esistente -> errore", {
  counts <- matrix(1:9, nrow = 3, ncol = 3)
  axis <- list(
    ensembl_gene = c("ENSG_A", "ENSG_B", "ENSG_C"),
    gene_symbol  = c("A", "B", "C"),
    gene_biotype = c("protein_coding", "lncRNA", "miRNA")
  )
  # L'attesa era "0 geni", cioe' il messaggio PRIMA del fix T7a (commit 0f1dd59,
  # 2026-05-28), che lo ha reso diagnostico elencando i biotype davvero presenti.
  # Il codice e' giusto: era il test a essere rimasto indietro, e ha fatto rumore
  # per due mesi coprendo la vera domanda «la suite e' verde?».
  err <- expect_error(
    simulomicsr:::.apply_biotype_filter(counts, axis, "nonexistent_biotype"),
    "non matcha alcun biotype"
  )
  # e deve dire QUALI biotype ci sono, che e' il motivo per cui il messaggio
  # e' stato cambiato
  expect_match(conditionMessage(err), "protein_coding")
  expect_match(conditionMessage(err), "nonexistent_biotype")
})

test_that("E2 T2.5 apply_biotype_filter preserva NA biotype solo se nel filter NA-aware", {
  counts <- matrix(1:9, nrow = 3, ncol = 3,
                    dimnames = list(c("ENSG_A", "ENSG_B", "ENSG_C"),
                                     c("GSM1", "GSM2", "GSM3")))
  axis <- list(
    ensembl_gene = c("ENSG_A", "ENSG_B", "ENSG_C"),
    gene_symbol  = c("A", "B", "C"),
    gene_biotype = c("protein_coding", NA_character_, "protein_coding")
  )
  # NA biotype non matcha 'protein_coding' di default -> droppato.
  res <- simulomicsr:::.apply_biotype_filter(counts, axis, "protein_coding")
  expect_equal(nrow(res$counts), 2L)
  expect_setequal(res$gene_axis$ensembl_gene, c("ENSG_A", "ENSG_C"))
})
