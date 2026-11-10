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
