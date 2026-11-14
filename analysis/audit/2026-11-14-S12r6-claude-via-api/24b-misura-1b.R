# PROVA DA BUTTARE
# 24b-misura-1b.R — S12r6: la misura accanto, con i tre studi di Fable (schema v1 vincolato) completati dopo che il PI
# ha alzato il limite di spesa (25-deviazioni.md §3). Esegue il testo di 24-misura.R con UNA SOLA riga sostituita: la
# cartella di uscita e del registro (DIR_OUT), che diventa DIR_1B, una cartella fuori dal repository. Li' sta un
# registro uguale a 23-uscite-sha256.txt, salvo che la riga di V-fable-corsa1 punta a una copia di V-fable-corsa1b.jsonl
# (SHA-256 in 23b-uscita-sha256.txt) col nome V-fable-corsa1.jsonl: 24-misura.R accetta solo i nomi corsa1 e corsa2.
# Tutto il resto (misure, semi, cancelli) e' quello del programma depositato. Le uscite si copiano in S6 col prefisso 24b-.
#   DIR_1B=<cartella fuori dal repo> [S12R6_OGGETTI=<file.rds>] Rscript .../24b-misura-1b.R > .../24b-out.txt 2>&1   (SENZA --vanilla)
S6 <- "analysis/audit/2026-11-14-S12r6-claude-via-api"; D <- Sys.getenv("DIR_1B")
stopifnot(nzchar(D), !startsWith(normalizePath(D, mustWork = FALSE), normalizePath(".")), !nzchar(Sys.getenv("PROVA")))
dir.create(D, showWarnings = FALSE, recursive = TRUE)
sha <- function(f) unname(tools::sha256sum(f))
b <- utils::read.table(file.path(S6, "23b-uscita-sha256.txt"), col.names = c("sha", "file"), colClasses = "character")
stopifnot(nrow(b) == 1L, identical(sha(b$file), b$sha))
copia <- file.path(normalizePath(D), "V-fable-corsa1.jsonl"); file.copy(b$file, copia, overwrite = TRUE); stopifnot(identical(sha(copia), b$sha))
r <- utils::read.table(file.path(S6, "23-uscite-sha256.txt"), col.names = c("sha", "file"), colClasses = "character")
i <- which(basename(r$file) == "V-fable-corsa1.jsonl"); stopifnot(length(i) == 1L, nrow(r) == 16L)
r$sha[i] <- b$sha; r$file[i] <- copia
writeLines(paste(r$sha, r$file, sep = "  "), file.path(D, "23-uscite-sha256.txt"))
tx <- readLines(file.path(S6, "24-misura.R")); riga <- "DIR_OUT <- if (SECCO) PROVA else S6"; j <- which(tx == riga); stopifnot(length(j) == 1L)
tx[j] <- 'DIR_OUT <- Sys.getenv("DIR_1B")'
cat(sprintf("24b-misura-1b.R: 24-misura.R (sha256 %s) con la riga %d sostituita; V-fable-corsa1 = V-fable-corsa1b.jsonl (%s)\n", sha(file.path(S6, "24-misura.R")), j, b$sha))
eval(parse(text = tx, keep.source = FALSE), envir = globalenv())
