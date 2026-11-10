# S12r, Task 1 — divisione dei 129 studi di Expression Atlas in sviluppo, giudizio A, giudizio B.
# Uso: Rscript analysis/audit/2026-11-09-lettore-studio/30-divisione.R   (senza --vanilla)
# Legge SOLO i primi tre campi di 20-atlas-studi-nostri.txt (accession, GSE, 1 se fra i 993 studi gia' letti).
# I campi dal quinto in poi contengono i nomi dei tipi di fattore di Atlas: non si leggono (studi di giudizio chiusi).
# Regola (depositata in 00-previsioni.md): nei_993 == 1 -> sviluppo; altrimenti numero del GSE modulo 3:
# 0 -> sviluppo, 1 -> giudizio_A, 2 -> giudizio_B.
DIR <- "analysis/audit/2026-11-09-lettore-studio"
righe <- readLines(file.path(DIR, "20-atlas-studi-nostri.txt"))
campi <- lapply(strsplit(righe, " ", fixed = TRUE), function(x) x[1:3])
d <- data.frame(accession = vapply(campi, `[`, "", 1L),
                gse       = vapply(campi, `[`, "", 2L),
                nei_993   = as.integer(vapply(campi, `[`, "", 3L)),
                stringsAsFactors = FALSE)
stopifnot(nrow(d) == 129L, !anyDuplicated(d$accession), !anyDuplicated(d$gse),
          all(grepl("^E-GEOD-[0-9]+$", d$accession)), all(grepl("^GSE[0-9]+$", d$gse)),
          all(d$nei_993 %in% 0:1),
          identical(sub("^E-GEOD-", "", d$accession), sub("^GSE", "", d$gse)))
n <- as.numeric(sub("^GSE", "", d$gse))
d$parte <- ifelse(d$nei_993 == 1L, "sviluppo",
                  c("sviluppo", "giudizio_A", "giudizio_B")[n %% 3 + 1])
d <- d[order(n), ]
conta <- table(d$parte)[c("sviluppo", "giudizio_A", "giudizio_B")]
stopifnot(identical(as.integer(conta), c(47L, 42L, 40L)))
write.table(d, file.path(DIR, "30-divisione.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
cat(sprintf("sviluppo %d, giudizio_A %d, giudizio_B %d\n", conta[[1]], conta[[2]], conta[[3]]))
