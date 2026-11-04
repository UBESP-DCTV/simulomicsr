#!/usr/bin/env Rscript
# S8b: congela il campione della prova. Uso: Rscript .../00-campione.R (senza --vanilla)
OUT <- "analysis/audit/2026-11-04-S8b-prova"
a3 <- readLines("analysis/audit/2026-08-16-A3/A3-studi.txt")
con <- pipe("python3 -c \"import sys,json\nfor l in open(sys.argv[1]):\n    print(json.loads(l)['series_id'])\" analysis/p4-output/A3-stage2-master-innestato.jsonl")
tutti <- sort(unique(readLines(con))); close(con)
fuori <- setdiff(tutti, a3)
stopifnot(length(a3) == 2566L, length(fuori) == 21828L)
# GSE9135 e' uno studio fantasma del master vecchio: non ha righe di input, quindi non puo' entrare
set.seed(20261104L, kind = "Mersenne-Twister", sample.kind = "Rejection")
nuovi <- sort(sample(fuori, 6000L)); gia <- sort(sample(sort(a3), 300L))
stopifnot(!length(intersect(nuovi, gia)), !anyDuplicated(nuovi), !anyDuplicated(gia), all(nuovi %in% tutti), all(gia %in% tutti))
writeLines(nuovi, file.path(OUT, "campione-nuovi.txt"))
writeLines(gia, file.path(OUT, "campione-300-gia-rigenerati.txt"))
writeLines(c(nuovi, gia), file.path(OUT, "campione-tutti.txt"))
cat("nuovi", length(nuovi), "gia'", length(gia), "\n")
cat("sha256 nuovi", digest::digest(file = file.path(OUT, "campione-nuovi.txt"), algo = "sha256"), "\n")
cat("sha256 gia' ", digest::digest(file = file.path(OUT, "campione-300-gia-rigenerati.txt"), algo = "sha256"), "\n")
cat("GSE9135 nei nuovi:", "GSE9135" %in% nuovi, "\n")
