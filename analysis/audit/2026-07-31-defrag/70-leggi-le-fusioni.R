#!/usr/bin/env Rscript
# 70-leggi-le-fusioni.R --- ogni fusione, col NOME che l'ID promette accanto,
# per poterle giudicare una per una invece di sommarle.
#
# Nasce da due errori trovati leggendo: `mito` -> *Vasconcellea candicans* (una
# pianta) e `msa_p` -> MTAP (un gene, mentre negli studi MSA-P e' l'atrofia
# multisistemica parkinsoniana). Entrambi passano lunghezza e univocita': li
# vede solo chi confronta il TOKEN con il NOME dell'entita'.
#
# Stampa anche un'etichetta di membro per ogni fusione, perche' il token da solo
# non basta a capire che cosa misuri lo studio.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

OUT <- "analysis/audit/2026-07-31-defrag"
d <- readRDS(file.path(OUT, "impatto-membri-v4.rds"))
mv <- d[!is.na(d$ent_on) & !is.na(d$ent_off) & d$ent_on != d$ent_off, ]
tb <- as.data.frame(table(da = mv$ent_off, a = mv$ent_on), stringsAsFactors = FALSE)
tb <- tb[tb$Freq > 0, ]; tb <- tb[order(-tb$Freq), ]
cat("coppie totali:", nrow(tb), "· membri:", sum(tb$Freq), "\n")

env <- simulomicsr:::.load_ontology_dicts()
nm <- function(id) tryCatch(
  simulomicsr:::.resolve_contrast_entity_label(id, env = env)$label %||% NA_character_,
  error = function(e) NA_character_)

con <- file(file.path(OUT, "70-fusioni-da-leggere.txt"), "w")
writeLines(sprintf("%-30s %-22s %5s  %-42s  %s",
                   "TOKEN", "ID", "membri", "NOME CHE L'ID PROMETTE",
                   "esempio di etichetta trattata"), con)
writeLines(strrep("-", 160), con)
for (i in seq_len(nrow(tb))) {
  ex <- mv$tl[mv$ent_off == tb$da[i] & mv$ent_on == tb$a[i]][1]
  writeLines(sprintf("%-30s %-22s %5d  %-42s  %s",
                     substr(tb$da[i], 1, 30), substr(tb$a[i], 1, 22), tb$Freq[i],
                     substr(nm(tb$a[i]) %||% "?", 1, 42), substr(ex %||% "", 1, 60)), con)
}
close(con)
cat("Scritto 70-fusioni-da-leggere.txt\n")

# copertura: quante fusioni servono per coprire il 90% dei membri?
cum <- cumsum(tb$Freq) / sum(tb$Freq)
cat(sprintf("le prime %d coppie coprono il 50%% dei membri · le prime %d il 90%%\n",
            which(cum >= 0.5)[1], which(cum >= 0.9)[1]))
