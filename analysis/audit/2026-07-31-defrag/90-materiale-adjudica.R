#!/usr/bin/env Rscript
# 90-materiale-adjudica.R --- le 241 fusioni che stanno in piedi SOLO su un
# alias, con le etichette vere accanto, per giudicarle una per una.
#
# Le altre 682 (78% dei membri) sono sostenute dal nome primario dell'entita' e
# non si leggono: e' il filtro dello screen 80-, e serve a delimitare il lavoro.
#
# Precedente: il 2026-07-25 sono state adjudicate 170 coppie alias->ID allo
# stesso modo, e da li' nasce `.ALIAS_COLLISIONS`. Cinque di quelle furono poi
# RITRATTATE rileggendo il testo sorgente: il giudizio sulla coppia non basta,
# va visto il testo che l'ha prodotta. Per questo qui si stampano PIU' etichette.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

OUT <- "analysis/audit/2026-07-31-defrag"
x <- utils::read.csv(file.path(OUT, "80-da-leggere-identita.csv"), stringsAsFactors = FALSE)
x <- x[order(-x$Freq), ]
d <- readRDS(file.path(OUT, "impatto-membri-v4.rds"))
mv <- d[!is.na(d$ent_on) & !is.na(d$ent_off) & d$ent_on != d$ent_off, ]

con <- file(file.path(OUT, "90-adjudica.txt"), "w")
tutte <- character(0)
for (i in seq_len(nrow(x))) {
  s <- mv[mv$ent_off == x$da[i] & mv$ent_on == x$a[i], ]
  lab <- unique(s$tl); ctl <- unique(s$cl)
  tutte <- c(tutte, lab, ctl)
  writeLines(sprintf("[%3d] %-28s -> %-22s (%s)  %d membri, %d studi",
                     i, x$da[i], x$a[i], x$nome[i], x$Freq[i],
                     length(unique(s$study))), con)
  for (j in seq_len(min(3L, length(lab)))) {
    writeLines(sprintf("      T: %s", lab[j]), con)
  }
  writeLines(sprintf("      C: %s", paste(utils::head(ctl, 2), collapse = " | ")), con)
}
close(con)

nc <- nchar(tutte)
cat("[strumento] etichette:", length(tutte), "· max", max(nc), "· mediana", stats::median(nc), "\n")
for (lim in c(40, 58, 64, 100, 128)) cat(sprintf("            == %3d: %d\n", lim, sum(nc == lim)))
cat("coppie da giudicare:", nrow(x), "· membri:", sum(x$Freq), "\n")
cat("Scritto 90-adjudica.txt\n")
