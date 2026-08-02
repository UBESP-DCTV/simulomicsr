# Test per l'indice nel record_id: lo Stadio 2 puo' emettere lo stesso
# comparison_id piu' volte nello stesso studio, su bracci diversi (291 studi,
# 746 casi su 754 misurati 2026-08-02). Senza un indice il record_id non e'
# una chiave e .lookup_cmp risolve sempre la prima occorrenza.

test_that(".lookup_cmp risolve l'indice quando il record_id lo porta", {
  # Lo Stadio 2 emette lo stesso comparison_id piu' volte nello stesso studio
  # (291 studi, 746 casi su 754 con bracci DIVERSI). Senza indice si poola
  # sempre il primo braccio: misurato, 7 gruppi del deliverable perdono uno
  # studio intero e uno ne poola uno sbagliato.
  study <- list(comparisons = list(
    list(comparison_id = "cmp_a", treated_group = "g1", control_group = "g0"),
    list(comparison_id = "cmp_a", treated_group = "g2", control_group = "g0"),
    list(comparison_id = "cmp_b", treated_group = "g3", control_group = "g0")
  ))
  # con indice: pesca l'occorrenza giusta
  expect_identical(simulomicsr:::.lookup_cmp(study, "cmp_a__1")$treated_group, "g1")
  expect_identical(simulomicsr:::.lookup_cmp(study, "cmp_a__2")$treated_group, "g2")
  expect_identical(simulomicsr:::.lookup_cmp(study, "cmp_b__1")$treated_group, "g3")
  # senza indice: comportamento IDENTICO a prima (retrocompatibilita' con v13)
  expect_identical(simulomicsr:::.lookup_cmp(study, "cmp_a")$treated_group, "g1")
  expect_null(simulomicsr:::.lookup_cmp(study, "cmp_z"))
  # un indice fuori intervallo non deve inventare un braccio
  expect_null(simulomicsr:::.lookup_cmp(study, "cmp_a__9"))
  # un comparison_id che contiene "__" e finisce per numero NON va scambiato
  # per un indice se quell'id esiste tale e quale
  study2 <- list(comparisons = list(
    list(comparison_id = "grp_01__vs__grp_02", treated_group = "gX", control_group = "g0")))
  expect_identical(simulomicsr:::.lookup_cmp(study2, "grp_01__vs__grp_02")$treated_group, "gX")
})

test_that("il record_id nuovo resta parsabile dagli strumenti esistenti", {
  rid <- "GSE12345__grp_0002_vs_grp_0007__2"
  # `.split_record_id` splitta sul PRIMO "__": la serie resta corretta
  expect_identical(simulomicsr:::.split_record_id(rid)$series_id, "GSE12345")
  # la convenzione usata dagli script di audit continua a valere
  expect_identical(sub("__.*$", "", rid), "GSE12345")
  # e il suffisso porta l'indice fino a .lookup_cmp
  expect_identical(simulomicsr:::.split_record_id(rid)$suffix,
                   "grp_0002_vs_grp_0007__2")
})
