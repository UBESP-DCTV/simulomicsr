# test-stage4-e1-cache-schema.R — FASE E1 ADR-0019 D6 (integrazione T6)
#
# Test del bump cache key (.cache_key_for_fetch) + schema_versions (stage4_algorithm).
# Razionale: la cache stage4-counts pre-E1 contiene matrici con rownames=HGNC
# make.unique. Post-E1 i rownames sono Ensembl. La chiave deve cambiare per
# invalidare automaticamente la cache stale.

test_that("E1 T6.1 .cache_key_for_fetch include 'v2_ensembl' nel payload (invalida cache pre-E1)", {
  # Simula 2 hashing con la stessa funzione attuale: la chiave deve essere
  # diversa da una versione "naive" (gse + sample_ids only). Per testare
  # cleanly: replico l'algoritmo legacy e verifico che il payload nuovo
  # differisca.
  gse <- "GSE12345"
  sample_ids <- c("GSM_a", "GSM_b", "GSM_c")

  key_new <- simulomicsr:::.cache_key_for_fetch(gse, sample_ids)

  # Replica del key legacy pre-E1 (senza prefisso versione axis)
  legacy_payload <- paste0(gse, "_", paste(sort(sample_ids), collapse = "|"))
  legacy_key <- substr(
    digest::digest(legacy_payload, algo = "xxhash32", serialize = FALSE),
    1L, 8L
  )

  expect_false(identical(key_new, legacy_key),
               info = "Key post-E1 deve differire da legacy per invalidare cache stale.")
})

test_that("E1 T6.2 stage4_default_config schema_versions stage4_algorithm bumpato a v2_ensembl_gene_axis", {
  cfg <- simulomicsr::stage4_default_config()
  expect_equal(cfg$schema_versions$stage4_algorithm, "v2_ensembl_gene_axis")
})

# ============================================================================
# E2 T3 — .cache_key_for_fetch stratifica per gene_biotype_filter
# ============================================================================

test_that("E2 T3.1 cache_key_for_fetch include biotype_filter -> chiave diversa", {
  gse <- "GSE12345"
  sample_ids <- c("GSM_a", "GSM_b", "GSM_c")

  k_default <- simulomicsr:::.cache_key_for_fetch(gse, sample_ids)  # default protein_coding
  k_null    <- simulomicsr:::.cache_key_for_fetch(gse, sample_ids,
                                                    gene_biotype_filter = NULL)
  k_lncrna  <- simulomicsr:::.cache_key_for_fetch(gse, sample_ids,
                                                    gene_biotype_filter = "lncRNA")
  k_multi   <- simulomicsr:::.cache_key_for_fetch(gse, sample_ids,
                                                    gene_biotype_filter = c("protein_coding", "lncRNA"))

  # Chiavi diverse per filter diversi
  expect_false(identical(k_default, k_null))
  expect_false(identical(k_default, k_lncrna))
  expect_false(identical(k_default, k_multi))
  expect_false(identical(k_null, k_lncrna))
})

test_that("E2 T3.2 cache_key_for_fetch stesso filter -> stessa chiave (deterministico)", {
  gse <- "GSE12345"
  sample_ids <- c("GSM_a", "GSM_b")
  k1 <- simulomicsr:::.cache_key_for_fetch(gse, sample_ids,
                                              gene_biotype_filter = "protein_coding")
  k2 <- simulomicsr:::.cache_key_for_fetch(gse, sample_ids,
                                              gene_biotype_filter = "protein_coding")
  expect_identical(k1, k2)
})

test_that("E2 T3.3 cache_key_for_fetch ordine filter normalizzato (vector permutato -> stessa key)", {
  gse <- "GSE12345"
  sample_ids <- c("GSM_a", "GSM_b")
  k1 <- simulomicsr:::.cache_key_for_fetch(gse, sample_ids,
                                              gene_biotype_filter = c("protein_coding", "lncRNA"))
  k2 <- simulomicsr:::.cache_key_for_fetch(gse, sample_ids,
                                              gene_biotype_filter = c("lncRNA", "protein_coding"))
  expect_identical(k1, k2)
})
