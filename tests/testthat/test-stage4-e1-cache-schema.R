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
