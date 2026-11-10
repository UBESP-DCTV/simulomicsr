test_that("la definizione: due confronti, uno per linea, e il conto delle coppie torna", {
  r <- tf_confronti(tf_finta())
  expect_equal(nrow(r$confronti), 2L); expect_equal(nrow(r$registro), 8L)
  a <- r$confronti[vapply(r$confronti$contesto, function(k) k[["linea"]] == "A", TRUE), ]
  expect_equal(a$trattato[[1]], c("GSM3", "GSM4")); expect_equal(a$controllo[[1]], c("GSM1", "GSM2"))
  expect_equal(a$livello_base, "veicolo"); expect_equal(a$esito, "confronto")
})
test_that("il tempo zero non è un controllo", {
  r <- tf_confronti(tf_finta())
  expect_false(any(unlist(r$confronti$controllo) %in% c("GSM9", "GSM10")))
  g <- tf_gruppi(tf_finta())
  zero <- g$gruppo[g$tempo == "0 h"]; farm <- g$gruppo[g$trattamento == "farmaco" & g$linea == "A"]
  riga <- r$registro[(r$registro$gruppo_a %in% c(zero, farm)) & (r$registro$gruppo_b %in% c(zero, farm)), ]
  expect_equal(riga$motivo, "piu_di_un_fattore"); expect_equal(riga$dettaglio, "tempo, trattamento")
})
test_that("la seconda perturbazione: farmaco + siRNA contro veicolo senza siRNA non è un confronto", {
  campioni <- sprintf("GSM%d", 1:6)
  livelli <- data.frame(farmaco = rep(c("veicolo", "X", "veicolo"), each = 2),
                        sirna = rep(c("siCtrl", "siY", "siY"), each = 2), row.names = campioni)
  fattori <- data.frame(nome = c("farmaco", "sirna"), tipo = "perturbazione", base = c("veicolo", "siCtrl"))
  r <- tf_confronti(tf_tabella(campioni, livelli, fattori))
  expect_equal(nrow(r$confronti), 2L)
  expect_setequal(r$confronti$fattore, c("farmaco", "sirna"))
  dentro <- r$confronti[r$confronti$fattore == "farmaco", ]
  expect_equal(dentro$trattato[[1]], c("GSM3", "GSM4")); expect_equal(dentro$controllo[[1]], c("GSM5", "GSM6"))
  expect_equal(dentro$contesto[[1]][["sirna"]], "siY")
  expect_equal(r$registro$motivo, "piu_di_un_fattore")
})
test_that("«non scritto» non è una differenza e si marca", {
  t <- unclass(tf_finta()); t$livelli$tempo[1:2] <- TF_NON_SCRITTO
  r <- tf_confronti(tf_tabella(t$campioni, t$livelli, t$fattori))
  a <- r$confronti[vapply(r$confronti$trattato, function(x) "GSM3" %in% x, TRUE), ]
  expect_equal(a$esito, "confronto con avviso"); expect_equal(a$avvisi[[1]], "non_scritto:tempo")
})
test_that("fattore senza livello di base, nessuno al livello di base, n_min", {
  campioni <- sprintf("GSM%d", 1:5)
  livelli <- data.frame(f = c("A", "A", "B", "B", "veicolo"), piattaforma = "p1", row.names = campioni)
  fattori <- data.frame(nome = c("f", "piattaforma"), tipo = c("perturbazione", "tecnico"), base = c("veicolo", NA))
  r <- tf_confronti(tf_tabella(campioni, livelli, fattori))
  expect_equal(nrow(r$confronti), 0L)
  expect_setequal(r$registro$motivo, c("nessuno_al_base", "n_min", "n_min"))
  livelli$piattaforma <- c("p1", "p1", "p2", "p2", "p1"); livelli$f <- "veicolo"
  r2 <- tf_confronti(tf_tabella(campioni, livelli, fattori))
  expect_true(all(r2$registro$motivo == "fattore_senza_base"))
})
test_that("uno studio con un solo gruppo dà tabelle vuote con le colonne giuste (Review Focus 4)", {
  campioni <- c("GSM1", "GSM2"); livelli <- data.frame(f = c("a", "a"), row.names = campioni)
  r <- tf_confronti(tf_tabella(campioni, livelli, data.frame(nome = "f", tipo = "contesto", base = NA)))
  expect_equal(nrow(r$confronti), 0L); expect_equal(nrow(r$registro), 0L)
  expect_true(all(c("id", "fattore", "trattato", "controllo", "avvisi", "esito") %in% names(r$confronti)))
  expect_true(all(c("gruppo_a", "gruppo_b", "motivo", "dettaglio") %in% names(r$registro)))
})
