# PROVA DA BUTTARE
# 10-frasi.R — S12r5: le frasi del prompt di B0 (prompt v2) e l'estrazione delle 8 frasi da riscrivere.
#
#   Rscript analysis/audit/2026-11-12-S12r5-piu-letture/10-frasi.R        (dalla radice del repo, SENZA --vanilla)
#
# Regola (01-carta.md par. 2), scritta prima di estrarre:
#   - il prompt si divide in 7 sezioni: l'apertura (prima del primo titolo `## `) e le 6 sezioni coi titoli;
#   - una frase finisce con un punto seguito da uno spazio, o con la fine della riga (punto, due punti, punto e virgola); il
#     trattino di una voce d'elenco non fa parte della frase;
#   - candidata: una frase con almeno 10 parole, che non sia una delle due frasi dei placebo di S12r4;
#   - si estrae una frase per sezione (7) e una seconda frase dalla sezione con piu' candidate (8 in tutto),
#     con set.seed(20261112) e sample(), nell'ordine delle sezioni nel prompt.
# Nessuno studio entra in questa scelta.
S5 <- "analysis/audit/2026-11-12-S12r5-piu-letture"
F_B0 <- "analysis/audit/2026-11-11-S12r3-elenco-chiuso/21-prompt-v2.md"
t <- readChar(F_B0, file.size(F_B0), useBytes = TRUE); Encoding(t) <- "UTF-8"
righe <- strsplit(t, "\n", fixed = TRUE)[[1]]
sezione <- character(0); frasi <- list(); sez <- "Opening"
for (r in righe) {
  if (startsWith(r, "## ")) { sez <- sub("^## ", "", r); next }
  if (!nzchar(r)) next
  r <- sub("^- ", "", r)
  p <- strsplit(r, "(?<=[.]) ", perl = TRUE)[[1]]
  stopifnot(identical(paste(p, collapse = " "), r), all(grepl("[.:;]$", p)))  # le frasi ricompongono la riga; ognuna finisce con punto, due punti o punto e virgola (voci d'elenco)
  for (x in p) frasi[[length(frasi) + 1L]] <- data.frame(sezione = sez, frase = x, stringsAsFactors = FALSE)
}
D <- do.call(rbind, frasi); D$n <- seq_len(nrow(D))
D$parole <- lengths(strsplit(D$frase, "[[:space:]]+"))
PLACEBO_R4 <- c("You receive one GEO series:", "Use an empty array if there are none.")
stopifnot(all(PLACEBO_R4 %in% D$frase))
D$placebo_r4 <- D$frase %in% PLACEBO_R4
D$una_volta <- vapply(D$frase, function(x) lengths(regmatches(t, gregexpr(x, t, fixed = TRUE))) == 1L, NA)   # la frase si trova una volta sola nel prompt
D$candidata <- D$parole >= 10L & !D$placebo_r4 & D$una_volta
sez_ord <- unique(D$sezione); stopifnot(length(sez_ord) == 7L)
nc <- vapply(sez_ord, function(s) sum(D$candidata[D$sezione == s]), 0L); stopifnot(all(nc >= 1L))
set.seed(20261112L)
pesca <- function(x, k) if (length(x) == 1L) x else sample(x, k)
estratte <- integer(0)
for (s in sez_ord) estratte <- c(estratte, pesca(D$n[D$candidata & D$sezione == s], 1L))
piu <- names(nc)[which.max(nc)]
estratte <- c(estratte, pesca(setdiff(D$n[D$candidata & D$sezione == piu], estratte), 1L))
D$lettura <- ""; D$lettura[sort(estratte)] <- paste0("L", seq_along(estratte))
# la riserva: l'ordine in cui si prendono le altre candidate della stessa sezione, se una riscrittura non passa il giudizio
D$riserva <- NA_integer_
for (s in sez_ord) { i <- D$n[D$candidata & D$sezione == s & !nzchar(D$lettura)]; if (length(i)) D$riserva[i] <- order(pesca(i, length(i))) }
utils::write.csv(D[c("n", "sezione", "parole", "placebo_r4", "una_volta", "candidata", "lettura", "riserva", "frase")], file.path(S5, "10-frasi.csv"), row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("frasi %d, candidate %d; per sezione: %s; seconda frase da: %s\n", nrow(D), sum(D$candidata), paste(sprintf("%s %d", names(nc), nc), collapse = ", "), piu))
for (i in sort(estratte)) cat(sprintf("%s [%s, frase %d, %d parole]\n   %s\n", D$lettura[i], D$sezione[i], i, D$parole[i], D$frase[i]))
