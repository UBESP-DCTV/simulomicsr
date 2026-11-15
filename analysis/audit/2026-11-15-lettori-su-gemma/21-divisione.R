# 21-divisione.R — la divisione degli studi di Gemma in una parte APERTA e una parte CHIUSA.
#
# Perche': i 47 studi di sviluppo sono stati usati sei volte per scegliere la forma del lettore. Sugli studi di
# Gemma si misurano piu' lettori e, se serve, si cambia ancora qualcosa. Una parte che nessun lettore legge prima
# di una decisione del PI da' alla fine un numero che non dipende da quelle scelte.
#
# Regola (per costruzione, senza guardare disegni, viste o uscite): lo studio GEO e' CHIUSO se i primi 7 caratteri
# esadecimali dello SHA-256 del suo numero GEO (il testo «GSE12345», UTF-8, senza a capo), letti come intero, sono
# divisibili per 3. Circa un terzo degli studi. La regola non usa un seme e non dipende dall'elenco.
# Parte chiusa: niente uscite di un modello e niente misura fino a una decisione del PI. La vista e lo schema si
# possono generare (non contengono il disegno di Gemma). I disegni di Gemma della parte chiusa sono gia' su disco e
# gia' passati per l'adattatore (30-esiti.csv conta fattori, gruppi e confronti): non li ho letti uno per uno.
#
#   Rscript analysis/audit/2026-11-15-lettori-su-gemma/21-divisione.R        (SENZA --vanilla)
# Scrive 21-divisione.csv (gse, parte, voci_gemma) e stampa i conti.
DIR <- "analysis/audit/2026-11-15-lettori-su-gemma"; GEMMA <- "analysis/audit/2026-11-15-gemma-riferimento"
parte_gemma <- function(gse) {
  h <- vapply(gse, function(g) digest::digest(enc2utf8(g), algo = "sha256", serialize = FALSE), "")
  ifelse(strtoi(substr(h, 1L, 7L), 16L) %% 3L == 0L, "chiusa", "aperta")
}
if (sys.nframe() == 0L) {
  voci <- utils::read.csv(file.path(GEMMA, "11-da-scaricare.csv"), stringsAsFactors = FALSE)
  esiti <- utils::read.csv(file.path(GEMMA, "30-esiti.csv"), stringsAsFactors = FALSE)
  v <- voci[voci$parte == "gemma" & voci$shortName %in% esiti$shortName[esiti$esito == "tabella"], ]
  d <- data.frame(gse = sort(unique(v$gse)), stringsAsFactors = FALSE)
  d$parte <- unname(parte_gemma(d$gse)); d$voci_gemma <- as.integer(table(v$gse)[d$gse])
  # controllo positivo della regola: un valore calcolato a mano con sha256sum
  stopifnot(identical(digest::digest("GSE1", algo = "sha256", serialize = FALSE),
                      system2("bash", c("-c", shQuote("printf GSE1 | sha256sum | cut -d' ' -f1")), stdout = TRUE)))
  utils::write.csv(d, file.path(DIR, "21-divisione.csv"), row.names = FALSE)
  cat(sprintf("studi di Gemma con una tabella: %d (voci %d); parte aperta %d studi (%d voci), parte chiusa %d studi (%d voci)\n",
              nrow(d), sum(d$voci_gemma), sum(d$parte == "aperta"), sum(d$voci_gemma[d$parte == "aperta"]),
              sum(d$parte == "chiusa"), sum(d$voci_gemma[d$parte == "chiusa"])))
}
