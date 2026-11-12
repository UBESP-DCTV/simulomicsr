# PROVA DA BUTTARE
# aiuti-misura-r5.R — S12r5: la misura di una lettura (quella di S12r4, senza cambi) e la regola sulla discordanza
# di 00-previsioni.md. `source()` dopo devtools::load_all("."). Legge SOLO i 47 studi di sviluppo.
# Carica aiuti-misura-r4.R di S12r4 con una sola riga cambiata: al posto di 10-forme.R carica 10-letture.R, che
# carica 10-forme.R (senza la riga della forma finale, vedi li') e aggiunge le letture L1-L8.
local({
  f <- "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/aiuti-misura-r4.R"
  x <- readLines(f, warn = FALSE, encoding = "UTF-8")
  i <- which(x == 'source("analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/10-forme.R")'); stopifnot(length(i) == 1L)
  x[i] <- 'source("analysis/audit/2026-11-12-S12r5-piu-letture/10-letture.R")'
  eval(parse(text = x, encoding = "UTF-8", keep.source = FALSE), envir = globalenv())
})
USCITE_R5 <- "analysis/p4-output/S12r5-letture"
scrivi_r5 <- function(d, f) utils::write.csv(d, file.path(S5, f), row.names = FALSE, na = "")
imp <- function(x) substr(digest::digest(enc2utf8(x), algo = "sha256", serialize = FALSE), 1L, 16L)

# ---- i 9 errori di lettura di B0 (finding di S12r4): 4 che costano gruppi o confronti, 5 che non costano ----
ERRORI_B0 <- data.frame(
  errore = c("GSE46665:sigle dei pazienti come malattie", "GSE57945:sesso come fattore", "GSE60340:colonna del trattamento non vista",
             "GSE49155:fattore doppio", "GSE46665:tempo ripetuto come secondo fattore", "GSE50760:source_name_ch1 come donatore",
             "GSE66573:source_name_ch1 come donatore", "GSE71595:source_name_ch1 come donatore", "GSE75852:tempo che ripete il tipo cellulare"),
  costa = c(TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE), stringsAsFactors = FALSE)
ERRORI_B0$studio <- sub(":.*$", "", ERRORI_B0$errore)
STUDI_CON_ERRORE <- unique(ERRORI_B0$studio); STUDI_CHE_COSTANO <- unique(ERRORI_B0$studio[ERRORI_B0$costa])
stopifnot(length(STUDI_CON_ERRORE) == 8L, setequal(STUDI_CHE_COSTANO, QUATTRO), all(STUDI_CON_ERRORE %in% sv$gse))

# Lo stato di ognuno dei 9 errori in una corsa: TRUE presente, FALSE assente, NA senza tabella dei fattori.
# I 4 che costano: i predicati di 10-forme.R (colonna errore_di_lettura). I 5 che non costano: predicati sulle
# colonne `fonti` e `soggetti` della tabella per studio, scritti qui e provati sulle 31 corse di S12r4 contro gli
# stati letti in 27-stati.csv (13-cancello-strumento.R). `tab`: la tabella per studio di misura_forma() o le
# righe di una corsa di 24-per-studio.csv.
fattori_di <- function(fonti) {                               # "tipo:colonna+colonna | ..." -> tipo e colonne
  if (is.na(fonti)) return(NULL)
  if (!nzchar(fonti)) return(data.frame(tipo = character(0), colonne = character(0)))
  p <- strsplit(fonti, " | ", fixed = TRUE)[[1]]
  data.frame(tipo = sub(":.*$", "", p), colonne = sub("^[^:]*:", "", p), stringsAsFactors = FALSE)
}
stato_errori <- function(tab) {
  riga <- function(g) tab[match(g, tab$studio), ]
  vapply(seq_len(nrow(ERRORI_B0)), function(i) {
    e <- ERRORI_B0$errore[i]; r <- riga(ERRORI_B0$studio[i]); f <- fattori_di(r$fonti)
    if (ERRORI_B0$costa[i]) return(as.logical(r$errore_di_lettura))
    if (is.null(f)) return(NA)
    if (grepl("source_name_ch1 come donatore", e, fixed = TRUE))
      return("source_name_ch1" %in% sub(":[^:]*$", "", strsplit(r$soggetti, " | ", fixed = TRUE)[[1]]))   # ruolo subject, di ogni specie
    col <- strsplit(f$colonne, "+", fixed = TRUE)
    if (grepl("tempo ripetuto come secondo fattore", e, fixed = TRUE))                                   # un fattore time letto fuori dalla colonna `time`, e un altro fattore che legge `time`
      return(any(vapply(seq_len(nrow(f)), function(j) f$tipo[j] == "time" && !("time" %in% col[[j]]) &&
                          any(vapply(col[-j], function(z) "time" %in% z, NA)), NA)))
    if (grepl("tempo che ripete il tipo cellulare", e, fixed = TRUE)) return(any(f$tipo == "time"))
    stop("errore senza predicato: ", e)
  }, NA)
}

# ---- le tre chiavi di una lettura per studio: la firma della tabella dei fattori, i gruppi, i confronti ----
# firma: firma_fattori() di 10-forme.R (tipo, colonne di fonte, partizione dei campioni e indice della base di ogni
# fattore, piu' i soggetti); una lettura senza tabella dei fattori (uscita non valida o studio oltre il contesto)
# ha la chiave "senza tabella". gruppi e confronti: gli insiemi di campioni; uno studio non chiuso ha la chiave
# "non chiuso" (due letture non chiuse hanno la stessa chiave di gruppi e di confronti).
camp_ins <- function(x) paste(sort(as.character(unlist(x))), collapse = ",")
chiavi_lettura <- function(m) {
  data.frame(studio = sv$gse,
    firma = ifelse(is.na(m$tab$firma), "senza tabella", m$tab$firma),
    gruppi = vapply(sv$gse, function(g) { r <- m$lett[[g]]; if (!r$chiuso) return("non chiuso")
      imp(paste(sort(vapply(split(names(r$partizione), unname(r$partizione)), camp_ins, "")), collapse = ";")) }, ""),
    confronti = vapply(sv$gse, function(g) { r <- m$lett[[g]]; if (!r$chiuso) return("non chiuso")
      k <- r$confronti; if (!nrow(k)) return("nessun confronto")
      imp(paste(sort(sprintf("%s>%s", vapply(k$trattato, camp_ins, ""), vapply(k$controllo, camp_ins, ""))), collapse = ";")) }, ""),
    stringsAsFactors = FALSE, row.names = NULL)
}
# La firma non vede se lo studio chiude: quando un livello e' scritto in una forma che lo schema non lega, due
# letture con la stessa firma possono essere una chiusa e una no (13-out.txt: GSE50499, GSE83687 in S12r4). Per
# questo la chiave della regola principale e' `tutto` = firma + gruppi + confronti: due letture sono concordi solo
# se hanno la stessa tabella dei fattori, gli stessi gruppi e gli stessi confronti. La sola firma si riporta accanto.
chiave_tutto <- function(ch) paste(ch$firma, ch$gruppi, ch$confronti, sep = "/")
# K: matrice studi x letture di chiavi. Uno studio e' SEGNALATO se le letture hanno due o piu' chiavi distinte.
n_distinte <- function(K) apply(K, 1L, function(z) length(unique(z)))
segnalato <- function(K) n_distinte(K) >= 2L

# ---- la regola di esito (00-previsioni.md): la differenza fra la quota di studi segnalati fra gli 8 studi con un
# errore di B0 e la quota fra gli altri 39, con l'IC 95% per ricampionamento degli studi (B = 2000, seme 20261112).
# Un ricampionamento senza studi con errore o senza studi senza errore non da' la differenza e si conta a parte.
differenza_quote <- function(segn, con_errore = sv$gse %in% STUDI_CON_ERRORE, B_ = B, seme = SEME) {
  stopifnot(length(segn) == 47L, is.logical(segn), !anyNA(segn))
  d <- function(i) mean(segn[i][con_errore[i]]) - mean(segn[i][!con_errore[i]])
  set.seed(seme); b <- vapply(seq_len(B_), function(k) d(sample.int(47L, replace = TRUE)), 0)
  list(con = sum(segn & con_errore), n_con = sum(con_errore), senza = sum(segn & !con_errore), n_senza = sum(!con_errore),
       diff = d(seq_len(47L)), ic = unname(stats::quantile(b, c(0.025, 0.975), na.rm = TRUE)), vuoti = sum(is.na(b)))
}
esito_regola <- function(segn) {
  q <- differenza_quote(segn); costano <- sum(segn[sv$gse %in% STUDI_CHE_COSTANO])
  a <- q$ic[1] > 0; b <- costano >= 3L
  list(q = q, costano = costano, a = a, b = b, esito = if (a && b) "si'" else "no")
}
