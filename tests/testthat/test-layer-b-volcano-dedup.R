# test-layer-b-volcano-dedup.R --- TDD: le etichette del volcano non devono
# ripetere lo stesso simbolo.
#
# PERCHE' ESISTE. Tabella e heatmap passano da `.rank_and_dedup_genes()`; il
# volcano no. Nella regione MHC lo stesso simbolo ha piu' ID Ensembl su aplotipi
# alternativi — `UBD` ne ha SEI nel gruppo SARS-CoV-2, tre con valori identici —
# quindi la stessa etichetta poteva comparire piu' volte fra le 15 del volcano,
# occupando posti che spettavano ad altri geni.
#
# E' cosmetico rispetto ai bug sui numeri, ma e' lo stesso difetto gia' corretto
# altrove: lasciarlo in un solo punto significa che la stessa figura racconta
# due cose diverse a seconda del pannello.

.cp_volcano_fixture <- function() {
  tibble::tibble(
    cluster_id = "cl_v",
    gene_id = c("ENSG_UBD_1", "ENSG_UBD_2", "ENSG_UBD_3",
                "ENSG_X", "ENSG_Y", "ENSG_Z"),
    gene_symbol = c("UBD", "UBD", "UBD", "GENE_X", "GENE_Y", "GENE_Z"),
    method = "rem_group",
    # i tre UBD hanno il punteggio piu' alto: senza dedup occuperebbero
    # tre delle etichette disponibili
    logFC_pool = c(5, 5, 5, 4, 3, 2),
    SE_pool = 0.1, p_value_pool = 1e-10,
    tau2 = 0, I2 = 0, Q = NA_real_, Q_pval = NA_real_,
    k_effective = 20L, n_baseline_studies_augmented = NA_integer_,
    FDR_BH_within_cluster = c(1e-20, 1e-20, 1e-20, 1e-15, 1e-10, 1e-5),
    direction_applied = "none")
}

test_that("uno stesso simbolo compare una volta sola fra le etichette", {
  cfg <- layer_b_default_config()
  cfg$top_n_volcano_labels <- 3L
  lab <- simulomicsr:::.volcano_labels(.cp_volcano_fixture(), cfg)
  etichette <- lab[!is.na(lab)]

  expect_equal(anyDuplicated(etichette), 0L)
  expect_true("UBD" %in% etichette)
  expect_equal(length(etichette), 3L)
})

test_that("i posti liberati dalla dedup vanno ai geni successivi", {
  # Senza dedup le tre etichette sarebbero UBD, UBD, UBD; con la dedup devono
  # essere UBD + i due geni che seguono per punteggio.
  cfg <- layer_b_default_config()
  cfg$top_n_volcano_labels <- 3L
  etichette <- simulomicsr:::.volcano_labels(.cp_volcano_fixture(), cfg)
  etichette <- etichette[!is.na(etichette)]

  expect_setequal(etichette, c("UBD", "GENE_X", "GENE_Y"))
})

test_that("i geni senza simbolo restano etichettati con l'ID e non si fondono", {
  cp <- .cp_volcano_fixture()
  cp$gene_symbol <- c(NA, "", NA, "GENE_X", "GENE_Y", "GENE_Z")
  cfg <- layer_b_default_config(); cfg$top_n_volcano_labels <- 3L
  etichette <- simulomicsr:::.volcano_labels(cp, cfg)
  etichette <- etichette[!is.na(etichette)]

  # tre righe senza simbolo sono tre geni DIVERSI: vanno tenute distinte
  expect_equal(anyDuplicated(etichette), 0L)
  expect_true(all(grepl("^ENSG_", utils::head(etichette, 3L))))
})

test_that("nessun gene significativo -> nessuna etichetta, senza errore", {
  cp <- .cp_volcano_fixture()
  cp$FDR_BH_within_cluster <- 0.9
  lab <- simulomicsr:::.volcano_labels(cp, layer_b_default_config())
  expect_true(all(is.na(lab)))
})

test_that("il vettore delle etichette e' lungo quanto le righe in ingresso", {
  # Il chiamante lo assegna come colonna: se cambia lunghezza, il plot sballa.
  cp <- .cp_volcano_fixture()
  expect_equal(length(simulomicsr:::.volcano_labels(cp, layer_b_default_config())),
               nrow(cp))
})
