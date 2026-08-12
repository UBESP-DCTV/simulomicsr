# G4 — l'indice di campione Illumina (_S<n>_) deve essere costante dentro la libreria.
# Nel nome dei file prodotti da bcl2fastq (`Nome_S#_L00#_R#_001.fastq.gz`) l'`S#`
# identifica la LIBRERIA e l'`L00#` la corsia: due file con S diverso sono due
# librerie diverse, sempre. Dove il titolo porta quel token, e' una prova di
# formato, non un'euristica.
SC <- "analysis/audit/2026-08-12-corsie"
A  <- readRDS(file.path(SC, "90-ampiezza.rds")); G <- readRDS(file.path(SC, "92-guardie.rds"))
B  <- A[A$in_multi & !A$gia_uguali, ]
sidx <- function(x) { y <- tolower(trimws(x)); m <- regexpr("[._-]s[0-9]{1,4}([._-]|$)", y)
  o <- rep(NA_character_, length(y)); k <- m > 0
  o[k] <- gsub("[^0-9]", "", regmatches(y, m)); o }
B$s <- sidx(B$title)
sp <- split(seq_len(nrow(B)), B$lib)
g4 <- vapply(sp, function(j) { v <- B$s[j]; if (all(is.na(v))) return(TRUE)
  length(unique(v[!is.na(v)])) == 1L && !anyNA(v) }, logical(1))
cat("librerie con token S#:", sum(vapply(sp, function(j) any(!is.na(B$s[j])), logical(1))),
    "su", length(sp), "\n")
cat("G4 superata:", sum(g4), "su", length(g4), "\n")
k <- G$G1 & G$G2 & G$G3
cat("G1+G2+G3:", sum(k), "-> con G4:", sum(k & g4[G$lib]), "\n")
cat("\nlibrerie che passano G1-G3 ma NON G4 (la regola unirebbe due librerie diverse):\n")
bad <- G$lib[k & !g4[G$lib]]
for (l in utils::head(bad, 10)) { j <- sp[[l]]
  cat(" ", gsub("\r", " | ", l), "->", paste(B$title[j], collapse = " ++ "), "\n") }
for (s in c("GSE173902","GSE178340","GSE115542","GSE116899")) {
  z <- G$lib[G$studio == s]
  cat(sprintf("  %-11s G4 %d/%d\n", s, sum(g4[z]), length(z)))
}
