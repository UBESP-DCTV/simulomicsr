# D2d — Il cambio del marcatore su TUTTO il corpus, con lo strumento CORRETTO.
# (La prima versione tagliava tutto prima di un `=` e mutilava 115 etichette.)
# Il re-cluster gira su tutti i confronti, non sul deliverable: l'ampiezza va
# misurata li'. Si scompone il cambio per CAUSA.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC <- "analysis/audit/2026-08-13-rerun-prep"
M  <- readRDS(file.path(SC, "D2-corpus.rds"))   # tutti i confronti del corpus

CS_OLD <- "\\b(sh|si|sg)[A-Z][A-Za-z0-9]{1,}\\b"
CI_OLD <- paste0("knock-?down|knock-?out|\\bko\\b|\\bkd\\b|crispr|cas9|transgen(e|ic)|",
                 "over-?express|\\bshrna\\b|\\bsirna\\b|\\bsgrna\\b|\\bgrna\\b|",
                 "empty vector|vector control|silenc|lentivir|\\bdegron\\b|\\bdtag\\b|\\bmaid\\b")
old <- function(x) { s <- simulomicsr:::.rp_normalize_separators(x)
  grepl(CS_OLD, s, perl = TRUE) || grepl(CI_OLD, tolower(s), perl = TRUE) }
new <- simulomicsr:::.rp_has_genetic_marker
# variante SENZA il case-sensitive su KO/KD: isola il costo di quella scelta
ko_ci <- function(x) {
  v <- simulomicsr:::.rp_marker_values(x)
  if (!length(v)) return(FALSE)
  v <- v[!grepl(simulomicsr:::.RP_GENETIC_NEG_VALUE_RX,
                tolower(vapply(v, simulomicsr:::.rp_normalize_separators, character(1))), perl = TRUE)]
  if (!length(v)) return(FALSE)
  s <- simulomicsr:::.rp_normalize_separators(paste(v, collapse = " ; "))
  s <- gsub(simulomicsr:::.RP_GENETIC_NEG_PREFIX_RX, " ", s, perl = TRUE, ignore.case = TRUE)
  new(x) || grepl("\\bko\\b|\\bkd\\b", tolower(s), perl = TRUE)
}
stopifnot(new("LNCaP-abl shKDM3B1 t=7"), !new("Kd measurement"), ko_ci("A549_RB1_ko"))

u <- unique(c(M$tl, M$cl))
mo <- vapply(u, old, logical(1)); mn <- vapply(u, new, logical(1))
mk <- vapply(u, ko_ci, logical(1))
cat("etichette distinte:", length(u), "\n")
cat("  marcatore che si ACCENDE:", sum(mn & !mo), "| che si SPEGNE:", sum(!mn & mo), "\n")
cat("  di quelle spente, quante tornerebbero con ko/kd case-INsensitive:",
    sum(!mn & mo & mk), "\n")
sp <- u[!mn & mo]
cat("\n  le etichette che perdono il marcatore (tutte):\n")
for (x in sp) cat("   ", ifelse(ko_ci(x), "[solo per il case]", "[negazione]  "),
                  substr(x, 1, 95), "\n")

f <- function(v) setNames(v, u)
M$a_old <- f(mo)[M$tl] != f(mo)[M$cl]
M$a_new <- f(mn)[M$tl] != f(mn)[M$cl]
M$a_kci <- f(mk)[M$tl] != f(mk)[M$cl]
cat("\nconfronti del corpus:", nrow(M), "\n")
cat("  asimmetria (solo marcatore): vecchia", sum(M$a_old), "| nuova", sum(M$a_new), "\n")
cat("  si ACCENDE su", sum(M$a_new & !M$a_old), "confronti | si SPEGNE su",
    sum(!M$a_new & M$a_old), "\n")
cat("  di quelli spenti, quanti tornerebbero con ko/kd case-INsensitive:",
    sum(!M$a_new & M$a_old & M$a_kci), "\n")
cat("  studi coinvolti dai cambi:",
    length(unique(M$series_id[M$a_new != M$a_old])), "\n")
z <- M[!M$a_new & M$a_old, ]
if (nrow(z)) { cat("\n  i confronti che PERDONO la segnalazione:\n")
  for (i in seq_len(min(nrow(z), 20)))
    cat(sprintf("   %s\n     T: %s\n     C: %s\n", z$series_id[i],
                substr(z$tl[i], 1, 85), substr(z$cl[i], 1, 85))) }
saveRDS(M, file.path(SC, "D2d-corpus.rds"))
