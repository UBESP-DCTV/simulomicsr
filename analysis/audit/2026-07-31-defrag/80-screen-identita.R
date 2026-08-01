#!/usr/bin/env Rscript
# 80-screen-identita.R --- quante fusioni assegnano un'identita' SBAGLIATA?
#
# Leggendo le prime ~220 coppie ne ho contate almeno 25 sbagliate, tutte della
# stessa forma: una sigla di 4-5 lettere che e' alias di un gene ma negli studi
# significa altro (`msap` = atrofia multisistemica, non MTAP; `copd` = la
# malattia, non ARCN1; `mos2` = disolfuro di molibdeno, non GPKOW). Un conteggio
# a impressione non e' una misura: qui si conta.
#
# IL METRO (lo stesso di 40-id-vs-membri.R, che esiste per questo): il token ha
# agganciato un ALIAS. La domanda e' se l'entita' agganciata sia quella giusta.
# Se il NOME PRIMARIO dell'entita' contiene il token (o viceversa), il match e'
# sostenuto dal nome — `tgfb`->TGFB1, `hypoxia`->Hypoxia. Se no, il match sta in
# piedi solo sull'alias, ed e' li' che vivono gli errori.
#
# ⚠️ E' un FILTRO, non un verdetto: `r5020`->promegestone e `4oht`->afimoxifene
# sono corretti e non passano il filtro (sinonimi commerciali). Serve a
# delimitare quanto c'e' da leggere, non a decidere.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

OUT <- "analysis/audit/2026-07-31-defrag"
norm <- function(x) gsub("[^a-z0-9]", "", tolower(as.character(x)))

d <- readRDS(file.path(OUT, "impatto-membri-v4.rds"))
mv <- d[!is.na(d$ent_on) & !is.na(d$ent_off) & d$ent_on != d$ent_off, ]
tb <- as.data.frame(table(da = mv$ent_off, a = mv$ent_on), stringsAsFactors = FALSE)
tb <- tb[tb$Freq > 0, ]; tb <- tb[order(-tb$Freq), ]

env <- simulomicsr:::.load_ontology_dicts()
tb$nome <- vapply(tb$a, function(id) tryCatch(
  simulomicsr:::.resolve_contrast_entity_label(id, env = env)$label %||% NA_character_,
  error = function(e) NA_character_), character(1L))
tb$tok <- norm(sub("^STR:", "", tb$da))
tb$nm  <- norm(tb$nome)
tb$sostenuto <- mapply(function(t, n) {
  if (!nzchar(t) || !nzchar(n)) return(FALSE)
  grepl(t, n, fixed = TRUE) || grepl(n, t, fixed = TRUE)
}, tb$tok, tb$nm)

cat("================ SCREEN DI IDENTITA' SU TUTTE LE FUSIONI ================\n")
cat(sprintf("  coppie totali: %d · membri: %d\n", nrow(tb), sum(tb$Freq)))
cat(sprintf("  sostenute dal NOME primario : %4d coppie (%5.1f%%) · %4d membri (%5.1f%%)\n",
            sum(tb$sostenuto), 100*mean(tb$sostenuto),
            sum(tb$Freq[tb$sostenuto]), 100*sum(tb$Freq[tb$sostenuto])/sum(tb$Freq)))
cat(sprintf("  DA LEGGERE (solo alias)     : %4d coppie (%5.1f%%) · %4d membri (%5.1f%%)\n",
            sum(!tb$sostenuto), 100*mean(!tb$sostenuto),
            sum(tb$Freq[!tb$sostenuto]), 100*sum(tb$Freq[!tb$sostenuto])/sum(tb$Freq)))

cat("\n  --- per lunghezza del token: dove si concentra il rischio ---\n")
b <- cut(nchar(tb$tok), c(0, 4, 5, 6, 8, Inf),
         labels = c("4", "5", "6", "7-8", "9+"))
t <- data.frame(
  lunghezza = levels(b),
  coppie = as.integer(table(b)),
  sostenute = as.integer(tapply(tb$sostenuto, b, sum)),
  pct_sostenute = round(100 * as.numeric(tapply(tb$sostenuto, b, mean)), 1),
  membri = as.integer(tapply(tb$Freq, b, sum)))
print(t, row.names = FALSE)

x <- tb[!tb$sostenuto, c("da", "a", "nome", "Freq")]
write.csv(x, file.path(OUT, "80-da-leggere-identita.csv"), row.names = FALSE)
cat("\n  --- le 40 piu' grosse fra quelle da leggere ---\n")
print(utils::head(x, 40), row.names = FALSE)
cat("\nScritto 80-da-leggere-identita.csv\n")
