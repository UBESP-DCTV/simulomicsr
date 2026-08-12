# FASE 2 — I candidati, sull'unita' GIUSTA (l'entry del dispatch).
#
# RISULTATO GIA' ACQUISITO E CHE CAMBIA IL DISEGNO (script 20):
#   * il BioSample copre il 100% dei campioni MA NON e' un criterio: in GSE178340
#     le quattro corsie della STESSA libreria (ATRA1_S4_L001..L004) hanno QUATTRO
#     BioSample distinti. E l'unico SAMN condiviso del corpus (GSE98984) copre
#     quattro campioni che stanno sui DUE bracci opposti: dedurne identita'
#     collasserebbe trattato e controllo.
#   * lo stesso vale per SRX: quattro SRX per quattro corsie.
#   -> l'identificatore autoritativo NON risolve il problema. Resta il titolo,
#      che e' un'euristica, e va confermato da un segnale NON lessicale (script 40).
#
# Qui si generano i CANDIDATI, con le tre regole separate per poterne misurare
# il contributo una per una, e si registra ogni entry che scenderebbe sotto n_min.
SC <- "analysis/audit/2026-08-12-corsie"
D  <- readRDS(file.path(SC, "10-dispatch.rds"))
M  <- readRDS(file.path(SC, "20-metadati.rds"))
R  <- D$R[D$R$esito == "ammessa", ]
tit <- setNames(M$title, M$gsm)

# --- le tre regole, separate --------------------------------------------------
r_lane  <- function(y) gsub("[._-]l0*[0-9]{1,3}([._-]|$)", "\\1", y)          # _L001
r_lane2 <- function(y) gsub("[._-]lane[ _-]?0*[0-9]{1,3}([._-]|$)", "\\1", y) # _lane1
r_run   <- function(y) gsub("[._-]run[ _-]?0*[0-9]{1,3}([._-]|$)", "\\1", y)  # _run1
coda    <- function(y) gsub("[._-]+$", "", y)
norm    <- function(x) tolower(trimws(x))

varianti <- list(
  nessuna = function(x) coda(norm(x)),
  lane    = function(x) coda(r_lane(norm(x))),
  lane2   = function(x) coda(r_lane2(norm(x))),
  run     = function(x) coda(r_run(norm(x))),
  tutte   = function(x) coda(r_run(r_lane2(r_lane(norm(x)))))
)

conta <- function(gsms, f) length(unique(f(tit[gsms])))
split_gsm <- function(s) strsplit(s, ",")

cat("=== QUANTE ENTRY SCENDONO SOTTO n_min=2, PER REGOLA ===\n")
esiti <- list()
for (nm in names(varianti)) {
  f <- varianti[[nm]]
  nt <- vapply(split_gsm(R$gsm_treated), conta, integer(1), f = f)
  nc <- vapply(split_gsm(R$gsm_control), conta, integer(1), f = f)
  cade <- (nt < 2L) | (nc < 2L)
  tocca <- (nt < R$n_treated) | (nc < R$n_control)
  esiti[[nm]] <- data.frame(nt = nt, nc = nc, cade = cade, tocca = tocca)
  cat(sprintf("  %-8s entry toccate %4d | entry che cadono %4d | cluster toccati %3d\n",
              nm, sum(tocca), sum(cade), length(unique(R$cluster_id[tocca]))))
}
E <- esiti[["tutte"]]
R$n_bio_treated <- E$nt; R$n_bio_control <- E$nc
R$cade <- E$cade; R$tocca <- E$tocca

cat("\n=== LE ENTRY TOCCATE (regola completa) ===\n")
T <- R[R$tocca, ]
T <- T[order(T$study_id, T$cluster_id), ]
for (i in seq_len(nrow(T))) {
  g_t <- strsplit(T$gsm_treated[i], ",")[[1]]; g_c <- strsplit(T$gsm_control[i], ",")[[1]]
  cat(sprintf("%-11s %s  trattati %2d->%2d  controlli %2d->%2d  %s\n",
      T$study_id[i], substr(T$cluster_id[i], 1, 20),
      T$n_treated[i], T$n_bio_treated[i], T$n_control[i], T$n_bio_control[i],
      if (T$cade[i]) "*** CADE ***" else ""))
  cat("      T:", paste(utils::head(tit[g_t], 5), collapse = " | "), "\n")
  cat("      C:", paste(utils::head(tit[g_c], 5), collapse = " | "), "\n")
}
cat("\nstudi coinvolti:", paste(sort(unique(T$study_id)), collapse = ", "), "\n")

saveRDS(R, file.path(SC, "30-entry-annotate.rds"))
write.csv(R[, c("cluster_id","study_id","treated_group","n_treated","n_control",
                "n_bio_treated","n_bio_control","tocca","cade")],
          file.path(SC, "30-entry-annotate.csv"), row.names = FALSE)
cat("\nscritto.\n")
