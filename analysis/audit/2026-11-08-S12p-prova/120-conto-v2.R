#!/usr/bin/env Rscript
# S12p, quarta parte B: il conto di Mistral con il prompt v2 contro il riferimento allargato (473), accanto a v1.
# Previsioni B1-B4 in 00-previsioni-monte.md. Non e' una prova cieca (prompt scritto dopo aver visto gli errori).
# Uso: Rscript analysis/audit/2026-11-08-S12p-prova/120-conto-v2.R > analysis/audit/2026-11-08-S12p-prova/120-out.txt
suppressPackageStartupMessages(library(jsonlite))
DIR <- "analysis/audit/2026-11-08-S12p-prova"
wilson <- function(x, n) { z <- qnorm(0.975); p <- x / n; c0 <- p + z^2 / (2 * n); r <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)); (c(c0 - r, c0 + r)) / (1 + z^2 / n) }
fmt <- function(x, n) { ci <- wilson(x, n); sprintf("%d su %d = %.1f%% [%.1f; %.1f]", x, n, 100 * x / n, 100 * ci[1], 100 * ci[2]) }
rc <- system2("sha256sum", c("-c", "--quiet", file.path(DIR, "110-uscite-v2-sha256.txt"))); if (rc != 0L) stop("impronte delle uscite v2 non verificate")
leggi <- function(f) { e <- read.delim(f, stringsAsFactors = FALSE, quote = "", na.strings = c("NA", "")); e$motivi[is.na(e$motivi)] <- ""; e$accusato <- !as.logical(e$passa); e }
v1 <- leggi("analysis/p4-output/S12p-uscite/mistral-esiti.tsv"); v2 <- leggi("analysis/p4-output/S12p-uscite-v2/mistral-esiti.tsv")
v2 <- v2[match(v1$record_id, v2$record_id), ]; if (anyNA(v2$record_id)) stop("v2 incompleto")
rif <- read.csv("analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv", stringsAsFactors = FALSE)$record_id
ext <- union(rif, read.csv(file.path(DIR, "94-difetti-finali.csv"), stringsAsFactors = FALSE)$record_id)
d <- v1$record_id %in% ext; d0 <- v1$record_id %in% rif
for (nm in c("v1", "v2")) { e <- get(nm)
  cat(sprintf("\n== Mistral %s ==\nriferimento allargato: presi %s; puliti accusati %s\n", nm, fmt(sum(e$accusato & d), sum(d)), fmt(sum(e$accusato & !d), sum(!d))))
  cat(sprintf("riferimento di S11:    presi %s; puliti accusati %s\n", fmt(sum(e$accusato & d0), sum(d0)), fmt(sum(e$accusato & !d0), sum(!d0))))
  cat(sprintf("confronti con CONDIZIONE_CON_AGENTE: %d; con ALTRA_DIFFERENZA: %d; liste non valide %d; oltre il limite %d\n",
              sum(grepl("CONDIZIONE_CON_AGENTE", e$motivi)), sum(grepl("ALTRA_DIFFERENZA", e$motivi)), sum(!as.logical(e$valida) & as.logical(e$completo)), sum(!as.logical(e$completo))))
  cat(sprintf("assi not_stated (liste valide): %.1f%%; citazioni trovate: %.1f%%\n", 100 * sum(e$assi_not_stated, na.rm = TRUE) / (11 * sum(as.logical(e$valida))), 100 * sum(e$citazioni_trovate, na.rm = TRUE) / sum(e$n_citazioni, na.rm = TRUE)))
}
cat(sprintf("\nverdetto cambiato da v1 a v2: %d confronti (difetti: presi da v1 e persi da v2 %d, nuovi presi %d; puliti: non piu' accusati %d, nuovi accusati %d)\n",
            sum(v1$accusato != v2$accusato), sum(v1$accusato & !v2$accusato & d), sum(!v1$accusato & v2$accusato & d), sum(v1$accusato & !v2$accusato & !d), sum(!v1$accusato & v2$accusato & !d)))
fa <- v2[v2$accusato & !d, ]; s <- table(unlist(strsplit(fa$motivi, " "))); s <- s[nzchar(names(s))]
cat("\nsegnali nei puliti accusati da v2 (riferimento allargato):\n"); print(sort(s, decreasing = TRUE))
cat(sprintf("\npuliti accusati da v2 con un solo segnale: %d; i segnali soli:\n", sum(!grepl(" ", fa$motivi))))
print(sort(table(fa$motivi[!grepl(" ", fa$motivi)]), decreasing = TRUE))
write.csv(data.frame(record_id = v1$record_id, difettoso = d, v1 = v1$accusato, v2 = v2$accusato, motivi_v1 = v1$motivi, motivi_v2 = v2$motivi), file.path(DIR, "120-v1-v2.csv"), row.names = FALSE)
cat("CONTO V2 FINITO\n")
