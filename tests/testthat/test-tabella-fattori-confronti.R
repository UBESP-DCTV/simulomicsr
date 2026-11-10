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

# --- Task 4: i soggetti come insiemi ---------------------------------------
sogg <- function(d) data.frame(donatore = d, row.names = sprintf("GSM%d", 1:10), stringsAsFactors = FALSE)
test_that("perturbazione: donatori senza valori comuni, in parte comuni, uguali", {
  # linea A: GSM1-2 veicolo, GSM3-4 farmaco. linea B: GSM5-6 veicolo, GSM7-8 farmaco.
  d <- c("d1", "d2", "d3", "d4",   "d5", "d6", "d5", "d7",   "d1", "d2")
  r <- tf_confronti(tf_finta(sogg(d), c(donatore = "donatore")))
  expect_equal(nrow(r$confronti), 1L)
  expect_equal(r$confronti$avvisi[[1]], "soggetti_in_parte:donatore")
  expect_equal(r$confronti$esito, "confronto con avviso")
  expect_equal(sum(r$registro$motivo == "soggetti_disgiunti"), 1L)
  expect_equal(r$registro$dettaglio[r$registro$motivo == "soggetti_disgiunti"], "donatore")
  d[3:4] <- c("d1", "d2"); d[7:8] <- c("d5", "d6")
  r2 <- tf_confronti(tf_finta(sogg(d), c(donatore = "donatore")))
  expect_equal(r2$confronti$esito, c("confronto", "confronto"))
})
tab_stato <- function(s, tipi) {
  campioni <- sprintf("GSM%d", 1:4)
  livelli <- data.frame(malattia = c("sano", "sano", "malato", "malato"), row.names = campioni)
  fattori <- data.frame(nome = "malattia", tipo = "stato", base = "sano")
  tf_confronti(tf_tabella(campioni, livelli, fattori, data.frame(s, row.names = campioni), tipi))
}
test_that("stato: donatori diversi avviso, sesso senza valori comuni nessun confronto, età per intervalli", {
  tab <- tab_stato
  r <- tab(list(don = c("a", "b", "c", "d")), c(don = "donatore"))
  expect_equal(r$confronti$avvisi[[1]], "soggetti_diversi:don")
  r <- tab(list(sex = c("F", "F", "M", "M")), c(sex = "sesso"))
  expect_equal(r$registro$motivo, "soggetti_disgiunti")
  r <- tab(list(sex = c("F", "M", "M", "M")), c(sex = "sesso"))
  expect_equal(r$confronti$avvisi[[1]], "soggetti_in_parte:sex")
  r <- tab(list(eta = c("34 years", "51 years", "40 years", "62 years")), c(eta = "eta"))
  expect_equal(r$confronti$esito, "confronto")
  r <- tab(list(eta = c("4 years", "6 years", "40 years", "62 years")), c(eta = "eta"))
  expect_equal(r$registro$motivo, "soggetti_disgiunti")
  r <- tab(list(eta = c("adult", "adult", "fetal", "fetal")), c(eta = "eta"))
  expect_equal(r$registro$motivo, "soggetti_disgiunti")
})
test_that("età: unità diverse non si confrontano per intervalli (Ruling Task 4)", {
  # 6-8 mesi contro 7-9 anni: i numeri si sovrappongono, le età no.
  r <- tab_stato(list(eta = c("6 months", "8 months", "7 years", "9 years")), c(eta = "eta"))
  expect_equal(r$registro$motivo, "soggetti_disgiunti")
  expect_equal(.tf_soggetti(c("34 Years", "51 years"), c("40 years"), "eta", "stato"), "uguali")
  expect_equal(.tf_soggetti(c("30-40 years"), c("35 years"), "eta", "stato"), "nessun_confronto")
})
test_that("soggetti: i valori vuoti non contano; un braccio senza valori dà un avviso (Ruling Task 4)", {
  r <- tab_stato(list(don = c("a", "b", NA, NA)), c(don = "donatore"))
  expect_equal(r$confronti$avvisi[[1]], "soggetti_non_scritti:don")
  expect_equal(r$confronti$esito, "confronto con avviso")
  r <- tab_stato(list(don = c(NA, NA, NA, NA)), c(don = "donatore"))
  expect_equal(r$confronti$esito, "confronto")
  r <- tab_stato(list(sex = c("F", TF_NON_SCRITTO, "F", "")), c(sex = "sesso"))
  expect_equal(r$confronti$esito, "confronto")
})
test_that(".tf_soggetti: la tabella della regola, riga per riga", {
  u <- c("a", "b"); p <- c("b", "c"); d <- c("c", "d")
  for (s in c("donatore", "passaggio", "lotto", "coppia", "sesso", "eta")) {
    expect_equal(.tf_soggetti(u, u, s, "perturbazione"), "uguali")
    expect_equal(.tf_soggetti(u, p, s, "perturbazione"), "avviso_in_parte")
    expect_equal(.tf_soggetti(u, d, s, "perturbazione"), "nessun_confronto")
    expect_equal(.tf_soggetti(u, u, s, "stato"), "uguali")
  }
  for (s in c("donatore", "passaggio", "lotto", "coppia")) {
    expect_equal(.tf_soggetti(u, p, s, "stato"), "avviso_diversi")
    expect_equal(.tf_soggetti(u, d, s, "stato"), "avviso_diversi")
  }
  for (s in c("sesso", "eta")) {
    expect_equal(.tf_soggetti(u, p, s, "stato"), "avviso_in_parte")
    expect_equal(.tf_soggetti(u, d, s, "stato"), "nessun_confronto")
  }
})
test_that("più colonne di soggetto: tutte quelle che tolgono il confronto stanno nel dettaglio", {
  s <- list(sex = c("F", "F", "M", "M"), eta = c("adult", "adult", "fetal", "fetal"), don = c("a", "b", "c", "d"))
  r <- tab_stato(s, c(sex = "sesso", eta = "eta", don = "donatore"))
  expect_equal(r$registro$motivo, "soggetti_disgiunti"); expect_equal(r$registro$dettaglio, "eta, sex")
})
