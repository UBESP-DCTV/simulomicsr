test_that("tf_gruppi: cinque gruppi da due campioni", {
  g <- tf_gruppi(tf_finta())
  expect_equal(nrow(g), 5L); expect_true(all(g$n == 2L))
  expect_setequal(g$campioni[[which(g$trattamento == "veicolo" & g$tempo == "0 h")]], c("GSM9", "GSM10"))
})
test_that("tf_tabella rifiuta gli ingressi incompleti, con classe", {
  t <- unclass(tf_finta())
  liv <- t$livelli; liv$tempo[3] <- NA
  expect_error(tf_tabella(t$campioni, liv, t$fattori), class = "simulomicsr_tf_campione_senza_livello")
  f <- t$fattori; f$base[1] <- "placebo"
  expect_error(tf_tabella(t$campioni, t$livelli, f), class = "simulomicsr_tf_base_ignota")
  f <- t$fattori; f$base[3] <- "0 h"
  expect_error(tf_tabella(t$campioni, t$livelli, f), class = "simulomicsr_tf_base_non_ammessa")
  f <- t$fattori; f$tipo[2] <- "tessuto"
  expect_error(tf_tabella(t$campioni, t$livelli, f), class = "simulomicsr_tf_tipo_ignoto")
  expect_error(tf_tabella(c(t$campioni[-1], "GSM2"), t$livelli, t$fattori), class = "simulomicsr_tf_campioni_doppi")
  expect_error(tf_tabella(t$campioni, t$livelli, t$fattori,
                          soggetti = data.frame(d = letters[1:10], row.names = t$campioni)),
               class = "simulomicsr_tf_soggetto_senza_tipo")
})
test_that("tf_gruppi: la chiave si costruisce per colonna (Review Focus 5)", {
  campioni <- sprintf("GSM%d", 1:4)
  livelli <- data.frame(x = c("a|b", "a|b", "a", "a"), y = c("c", "c", "b|c", "b|c"),
                        row.names = campioni, stringsAsFactors = FALSE)
  fattori <- data.frame(nome = c("x", "y"), tipo = c("contesto", "contesto"), base = c(NA, NA))
  expect_equal(nrow(tf_gruppi(tf_tabella(campioni, livelli, fattori))), 2L)
})
test_that("tf_gruppi: «non scritto» è un livello come gli altri nella chiave", {
  t <- unclass(tf_finta()); t$livelli$tempo[1] <- TF_NON_SCRITTO      # GSM1 si stacca da GSM2
  expect_equal(nrow(tf_gruppi(tf_tabella(t$campioni, t$livelli, t$fattori))), 6L)
})
