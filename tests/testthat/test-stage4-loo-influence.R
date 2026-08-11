# test-stage4-loo-influence.R --- TDD per R/stage4-loo-influence.R
#
# PERCHE' ESISTE. Il deliverable dichiara 214 meta-analisi; di 13 sappiamo quali
# confronti un lettore umano ha giudicato spuri. La domanda scientifica non e'
# «quel gruppo e' coerente?» (verdetto: sugli stessi 213 gruppi Mistral ne dice
# 24 incoerenti e la lettura umana 96) ma «quanto quei confronti SPOSTANO il
# risultato». Questi due strumenti misurano lo spostamento.
#
# LA COSA CHE QUESTI TEST DIFENDONO. Il ri-pooling deve misurare ESATTAMENTE
# l'oggetto del deliverable, non un suo parente: i bracci vanno collassati per
# studio con l'inverso della varianza PRIMA del random-effects — e' l'ordine che
# la produzione usa (.pool_all_clusters), ed e' lo stesso errore gia' commesso
# il 2026-07-31 pesando i bracci invece degli studi. Se il collasso sparisce, o
# se si sposta dopo il pooling, questi test devono fallire.
#
# E l'insieme dei geni deve restare FISSO fra pieno e ridotto: `FDR_BH_within_cluster`
# si ricalcola su un denominatore diverso a ogni rimozione, e il 3,5% dei geni ha
# k_effective = 2 e sparisce sotto leave-one-out. Confrontare due classifiche
# costruite su denominatori diversi misurerebbe il denominatore.

# --- fixture: due studi con effetto concorde + un terzo discordante -----------
.finto_per_study <- function() {
  # Schema di per_study_de.parquet per intero: .collapse_arms_by_study ricostruisce
  # la riga collassata colonna per colonna e su uno schema parziale fallisce con
  # "numbers of columns of arguments do not match" — cioe' tardi e in modo oscuro.
  lfc <- c( 2.0,  2.1, -2.0,     # g1: x discorda
            1.0,  1.1,  1.05,    # g2: tutti concordi
            0.5,  0.45, 0.5)     # g3: tutti concordi
  data.frame(
    cluster_id = "c1",
    gene_id = rep(c("g1", "g2", "g3"), each = 3),
    gene_symbol = rep(c("A", "B", "C"), each = 3),
    study_id = rep(c("GSE_a", "GSE_b", "GSE_x"), times = 3),
    logFC = lfc,
    SE = 0.1,
    p_value = 2 * stats::pnorm(-abs(lfc / 0.1)),
    t_stat = lfc / 0.1,
    n_treated = 3L,
    n_control = 3L,
    direction_applied = "as_is",
    stringsAsFactors = FALSE)
}

test_that("pool_cluster_leaving_out rifiuta subito uno schema incompleto", {
  # Senza guardia il fallimento arriva dentro il collasso, come un errore di
  # rbind: illeggibile, e solo se lo studio ha piu' di un braccio.
  x <- .finto_per_study()
  x$n_control <- NULL

  expect_error(pool_cluster_leaving_out(x), "n_control")
})

test_that("pool_cluster_leaving_out senza esclusioni riproduce il pooling di produzione", {
  # IL CASO DI ACCETTAZIONE dello strumento: la catena dev'essere identica a
  # quella che ha prodotto cluster_pooled.parquet.
  x <- .finto_per_study()
  atteso <- .pool_rem_cluster(.collapse_arms_by_study(x), method_label = "rem_group")

  out <- pool_cluster_leaving_out(x, character(0), method_label = "rem_group")

  expect_equal(as.data.frame(out), as.data.frame(atteso))
})

test_that("pool_cluster_leaving_out toglie davvero lo studio", {
  x <- .finto_per_study()

  pieno   <- pool_cluster_leaving_out(x, character(0))
  ridotto <- pool_cluster_leaving_out(x, "GSE_x")

  expect_equal(unique(pieno$k_effective), 3)
  expect_equal(unique(ridotto$k_effective), 2)
  # su g1 lo studio discordante teneva la stima vicino a zero: tolto, sale
  expect_gt(ridotto$logFC_pool[ridotto$gene_id == "g1"],
            pieno$logFC_pool[pieno$gene_id == "g1"])
})

test_that("pool_cluster_leaving_out collassa i bracci PRIMA di poolare", {
  # GSE_a con due bracci deve contare come UNO studio, non due.
  x <- .finto_per_study()
  doppio <- x[x$study_id == "GSE_a", ]
  doppio$logFC <- doppio$logFC + 0.02
  x2 <- rbind(x, doppio)

  out <- pool_cluster_leaving_out(x2, character(0))

  expect_equal(unique(out$k_effective), 3)
})

test_that("pool_cluster_leaving_out con uno studio solo non produce geni", {
  # Il REM richiede >= 2 studi per gene: e' il motivo per cui l'insieme dei geni
  # va fissato prima, invece di lasciarlo cambiare sotto la rimozione.
  x <- .finto_per_study()

  out <- pool_cluster_leaving_out(x, c("GSE_b", "GSE_x"))

  expect_equal(nrow(out), 0L)
})

test_that("pool_cluster_leaving_out ignora uno studio che non c'e'", {
  x <- .finto_per_study()

  expect_equal(as.data.frame(pool_cluster_leaving_out(x, "GSE_inesistente")),
               as.data.frame(pool_cluster_leaving_out(x, character(0))))
})

test_that("pool_cluster_leaving_out regge l'input vuoto", {
  vuoto <- .finto_per_study()[0, ]

  out <- pool_cluster_leaving_out(vuoto, "GSE_a")

  expect_s3_class(out, "data.frame")
  expect_equal(nrow(out), 0L)
})

# --- l'influenza --------------------------------------------------------------

test_that("compute_pooling_influence da' influenza nulla quando nulla cambia", {
  x <- .finto_per_study()
  p <- pool_cluster_leaving_out(x, character(0))

  out <- compute_pooling_influence(p, p, geni = p$gene_id)

  expect_equal(out$spearman, 1)
  expect_equal(out$max_abs_delta_logFC, 0)
  expect_equal(out$n_sig_persi, 0L)
  expect_equal(out$n_sig_guadagnati, 0L)
  expect_equal(out$n_geni_confrontati, 3L)
  expect_equal(out$n_geni_spariti, 0L)
})

test_that("compute_pooling_influence conta i geni spariti e non li usa", {
  # Un gene presente nel pieno e assente nel ridotto non puo' entrare in una
  # correlazione: va CONTATO, non ignorato in silenzio.
  x <- .finto_per_study()
  pieno <- pool_cluster_leaving_out(x, character(0))
  ridotto <- pieno[pieno$gene_id != "g3", ]

  out <- compute_pooling_influence(pieno, ridotto, geni = pieno$gene_id)

  expect_equal(out$n_geni_confrontati, 2L)
  expect_equal(out$n_geni_spariti, 1L)
})

test_that("compute_pooling_influence misura il massimo scarto di logFC", {
  x <- .finto_per_study()
  pieno <- pool_cluster_leaving_out(x, character(0))
  ridotto <- pieno
  ridotto$logFC_pool[ridotto$gene_id == "g2"] <- ridotto$logFC_pool[ridotto$gene_id == "g2"] + 1.5

  out <- compute_pooling_influence(pieno, ridotto, geni = pieno$gene_id)

  expect_equal(out$max_abs_delta_logFC, 1.5)
  expect_equal(out$gene_max_delta, "g2")
})

test_that("compute_pooling_influence limita lo scarto ai primi N del PIENO", {
  # I primi N si fissano sul pooling pieno: se si ri-ordinasse il ridotto, si
  # misurerebbe un insieme di geni diverso a ogni rimozione.
  x <- .finto_per_study()
  pieno <- pool_cluster_leaving_out(x, character(0))
  pieno <- pieno[order(pieno$p_value_pool), ]
  ultimo <- pieno$gene_id[nrow(pieno)]
  ridotto <- pieno
  ridotto$logFC_pool[ridotto$gene_id == ultimo] <- ridotto$logFC_pool[ridotto$gene_id == ultimo] + 9

  out <- compute_pooling_influence(pieno, ridotto, geni = pieno$gene_id, top_n = 2L)

  expect_equal(out$max_abs_delta_logFC, 0)
})

test_that("compute_pooling_influence conta i significativi persi e guadagnati", {
  x <- .finto_per_study()
  pieno <- pool_cluster_leaving_out(x, character(0))
  pieno$FDR_BH_within_cluster <- c(0.01, 0.2, 0.01)
  ridotto <- pieno
  ridotto$FDR_BH_within_cluster <- c(0.2, 0.01, 0.01)

  out <- compute_pooling_influence(pieno, ridotto, geni = pieno$gene_id)

  expect_equal(out$n_sig_pieno, 2L)
  expect_equal(out$n_sig_ridotto, 2L)
  expect_equal(out$n_sig_persi, 1L)
  expect_equal(out$n_sig_guadagnati, 1L)
})

test_that("compute_pooling_influence regge il ridotto vuoto", {
  # Succede davvero: un gruppo k=3 a cui si tolgono due studi.
  x <- .finto_per_study()
  pieno <- pool_cluster_leaving_out(x, character(0))

  out <- compute_pooling_influence(pieno, pieno[0, ], geni = pieno$gene_id)

  expect_equal(out$n_geni_confrontati, 0L)
  expect_equal(out$n_geni_spariti, 3L)
  expect_true(is.na(out$spearman))
})
