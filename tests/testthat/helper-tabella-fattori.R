# Aiuti per i test della tabella dei fattori (ADR-0029).
# Studio finto: 2 linee x (veicolo, farmaco) a 24 h, piu' un tempo zero. 10 campioni.
tf_finta <- function(soggetti = NULL, tipo_soggetto = NULL) {
  campioni <- sprintf("GSM%d", 1:10)
  livelli <- data.frame(
    trattamento = rep(c("veicolo", "farmaco", "veicolo", "farmaco", "veicolo"), each = 2),
    linea       = rep(c("A", "A", "B", "B", "A"), each = 2),
    tempo       = rep(c("24 h", "24 h", "24 h", "24 h", "0 h"), each = 2),
    row.names = campioni, stringsAsFactors = FALSE)
  fattori <- data.frame(nome = c("trattamento", "linea", "tempo"),
                        tipo = c("perturbazione", "contesto", "tempo"),
                        base = c("veicolo", NA, NA), stringsAsFactors = FALSE)
  tf_tabella(campioni, livelli, fattori, soggetti, tipo_soggetto)
}

# Fixture di Expression Atlas (E-GEOD-52778, studio di sviluppo) e un legame run -> GSM finto ma vero
# per questo studio: SRR1039508 e' GSM1275862 e i numeri crescono insieme.
fx <- function(f) testthat::test_path("fixtures", "atlas", f)
legame_finto <- function(run) data.frame(run = run, gsm = sprintf("GSM%d", 1275862L + as.integer(sub("SRR", "", run)) - 1039508L))
