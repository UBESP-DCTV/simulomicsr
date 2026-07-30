# test-layer-b-gene-coverage-filter.R --- TDD per il filtro di copertura sui
# geni mostrati nelle figure Layer B.
#
# PERCHE' ESISTE. Misurato il 2026-07-31 sui bundle veri: la tabella dei top 30
# geni e la heatmap, ordinate per FDR, sono guidate da geni misurati in POCHI
# studi. Su SARS-CoV-2 (k=33) il k mediano dei primi venti e' 6,5 e tutti e venti
# stanno sotto meta' del k pieno; su IFN-gamma (k=19) il k mediano dei primi
# trenta e' 4.
#
# IL MECCANISMO, verificato: con k basso il random-effects non riesce a stimare
# tau^2, lo pone a ZERO, l'errore standard collassa e l'FDR precipita. Su
# SARS-CoV-2 il 56,6% dei geni a k=2 ha tau^2=0 contro lo 0% a k>=21, e nove dei
# primi dieci geni per FDR hanno tau^2=0 e I^2=0. Quegli stessi geni sono a
# conteggio zero nella maggior parte dei campioni (correlazione fra k e frazione
# di zeri: Spearman -0,813), e ComBat li salta esplicitamente, quindi nella
# heatmap restano segnale di studio.
#
# Filtrando i geni sotto meta' del k del cluster, la frazione mediana di zeri fra
# i trenta mostrati passa da ~50-68% a ~0-4,5%.
#
# LE COSE CHE QUESTI TEST DIFENDONO:
#  1. il filtro non deve MAI svuotare una figura in silenzio: se non resta nulla
#     si torna indietro e lo si dichiara;
#  2. quanti geni sono stati tolti dev'essere VISIBILE (niente tagli silenziosi);
#  3. la soglia e' un parametro di config, non un numero sepolto nel codice.

.cp_fixture <- function() {
  data.frame(
    cluster_id = "c1",
    gene_id    = paste0("ENSG", 1:6),
    gene_symbol = c("ALTO1", "ALTO2", "ALTO3", "BASSO1", "BASSO2", "BASSO3"),
    logFC_pool = c(1, 1, 1, 5, 5, 5),
    FDR_BH_within_cluster = c(0.01, 0.02, 0.03, 1e-30, 1e-29, 1e-28),
    k_effective = c(20L, 19L, 18L, 2L, 2L, 3L),
    stringsAsFactors = FALSE
  )
}

test_that("tiene i geni misurati in almeno la frazione richiesta di studi", {
  out <- .filter_genes_by_coverage(.cp_fixture(), min_k_frac = 0.5)

  expect_equal(nrow(out$genes), 3L)
  expect_setequal(out$genes$gene_symbol, c("ALTO1", "ALTO2", "ALTO3"))
  expect_equal(out$n_dropped, 3L)
  expect_equal(out$k_max, 20L)
  expect_equal(out$k_min_richiesto, 10L)
  expect_false(out$fallback)
})

test_that("i geni piu' significativi vengono tolti se la copertura e' bassa", {
  # BASSO1..3 hanno FDR di trenta ordini di grandezza migliore: senza filtro
  # sarebbero i primi tre. E' esattamente il caso da intercettare.
  senza <- .cp_fixture()
  primi_senza <- senza$gene_symbol[order(senza$FDR_BH_within_cluster)][1:3]
  expect_setequal(primi_senza, c("BASSO1", "BASSO2", "BASSO3"))

  out <- .filter_genes_by_coverage(senza, min_k_frac = 0.5)
  expect_false(any(c("BASSO1", "BASSO2", "BASSO3") %in% out$genes$gene_symbol))
})

test_that("min_k_frac = 0 non tocca nulla", {
  out <- .filter_genes_by_coverage(.cp_fixture(), min_k_frac = 0)
  expect_equal(nrow(out$genes), 6L)
  expect_equal(out$n_dropped, 0L)
  expect_false(out$fallback)
})

test_that("se il filtro svuoterebbe la figura si torna indietro E LO SI DICE", {
  # Un cluster in cui nessun gene raggiunge la soglia non deve produrre una
  # figura vuota: il lettore penserebbe "nessun risultato" invece di "filtro
  # troppo severo". Si restituisce l'insieme intero con fallback = TRUE.
  cp <- .cp_fixture()
  cp$k_effective <- rep(2L, 6L)
  cp$k_effective[1L] <- 40L   # k_max alto, tutti gli altri sotto soglia
  cp <- cp[-1L, ]             # tolgo l'unico che passerebbe
  cp$k_effective[1L] <- 2L
  attr(cp, "k_max_override") <- NULL

  out <- .filter_genes_by_coverage(cp, min_k_frac = 0.5, k_max = 40L)
  expect_true(out$fallback)
  expect_equal(nrow(out$genes), nrow(cp))
  expect_equal(out$n_dropped, 0L)
})

test_that("k_max si puo' imporre dall'esterno invece di dedurlo dai geni mostrati", {
  # Il k del cluster e' il MASSIMO su tutti i geni, non su quelli sopravvissuti
  # a un filtro precedente: dedurlo dal sottoinsieme sbagliato abbasserebbe la
  # soglia proprio quando serve di piu'.
  cp <- .cp_fixture()
  cp <- cp[cp$k_effective <= 3L, ]      # solo i geni a bassa copertura
  dedotto <- .filter_genes_by_coverage(cp, min_k_frac = 0.5)
  imposto <- .filter_genes_by_coverage(cp, min_k_frac = 0.5, k_max = 20L)

  expect_equal(dedotto$k_min_richiesto, 2L)   # meta' di 3, arrotondato in su
  expect_equal(imposto$k_min_richiesto, 10L)
  expect_true(imposto$fallback)               # nessuno passa -> si torna indietro
})

test_that("un cluster senza colonna k_effective passa indenne invece di fallire", {
  cp <- .cp_fixture()
  cp$k_effective <- NULL
  out <- .filter_genes_by_coverage(cp, min_k_frac = 0.5)
  expect_equal(nrow(out$genes), 6L)
  expect_equal(out$n_dropped, 0L)
  expect_true(is.na(out$k_max))
})

test_that("k_effective NA non fa passare il gene di nascosto", {
  cp <- .cp_fixture()
  cp$k_effective[4L] <- NA_integer_
  out <- .filter_genes_by_coverage(cp, min_k_frac = 0.5)
  expect_false("BASSO1" %in% out$genes$gene_symbol)
})

test_that("input vuoto non fallisce", {
  vuoto <- .cp_fixture()[0L, ]
  out <- .filter_genes_by_coverage(vuoto, min_k_frac = 0.5)
  expect_equal(nrow(out$genes), 0L)
  expect_equal(out$n_dropped, 0L)
})

test_that("la soglia sta nella config, con un default dichiarato", {
  cfg <- layer_b_default_config()
  expect_true("top_genes_min_k_frac" %in% names(cfg))
  expect_equal(cfg$top_genes_min_k_frac, 0.5)
})

test_that("la nota per la caption dice quanti geni sono stati tolti e perche'", {
  out <- .filter_genes_by_coverage(.cp_fixture(), min_k_frac = 0.5)
  nota <- .coverage_filter_note(out)

  expect_true(grepl("3", nota))          # quanti tolti
  expect_true(grepl("10", nota))         # la soglia in studi
  expect_true(nzchar(nota))
  # niente filtro -> niente nota: non si sporca la caption per nulla
  expect_equal(.coverage_filter_note(
    .filter_genes_by_coverage(.cp_fixture(), min_k_frac = 0)), "")
})

test_that("la nota dichiara ESPLICITAMENTE quando si e' tornati indietro", {
  cp <- .cp_fixture()
  cp <- cp[cp$k_effective <= 3L, ]
  out <- .filter_genes_by_coverage(cp, min_k_frac = 0.5, k_max = 20L)
  nota <- .coverage_filter_note(out)

  expect_true(nzchar(nota))
  expect_match(nota, "no gene|not applied|disabled", ignore.case = TRUE)
})
