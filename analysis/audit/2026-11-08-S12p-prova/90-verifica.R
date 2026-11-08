#!/usr/bin/env Rscript
# S12p, terza parte: raccoglie la seconda lettura (senza affermazioni) e la confronta con la prima. Cancelli V1-V2 e
# previsioni Q1-Q3 di 00-previsioni-verifica.md. Scrive i confronti non confrontabili per tutte e due le letture.
# Uso: Rscript analysis/audit/2026-11-08-S12p-prova/90-verifica.R <cartella-lettori> <file-chiave> > .../90-out.txt
suppressMessages(pkgload::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(jsonlite))
a <- commandArgs(TRUE); LET <- a[1]; CHIAVE <- a[2]; DIR <- "analysis/audit/2026-11-08-S12p-prova"; SEME <- 20261108L; B <- 2000L
wilson <- function(x, n) { z <- qnorm(0.975); p <- x / n; c0 <- p + z^2 / (2 * n); r <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)); (c(c0 - r, c0 + r)) / (1 + z^2 / n) }
fmt <- function(x, n) { ci <- wilson(x, n); sprintf("%d su %d = %.1f%% [%.1f; %.1f]", x, n, 100 * x / n, 100 * ci[1], 100 * ci[2]) }
TIPI <- c("tempo_zero", "tempo_diverso", "secondo_agente", "agente_nel_controllo", "braccio_misto", "entita_diversa", "tecnica",
          "materiale_o_sede", "genotipo", "coltura", "soggetti", "altro")
ch <- fromJSON(CHIAVE, simplifyVector = FALSE); names(ch) <- vapply(ch, `[[`, "", "id")
attesi <- unlist(lapply(sort(list.files(LET, pattern = "^lotto-[0-9]+[.]txt$", full.names = TRUE)), readLines))
L <- list()
for (f in sort(list.files(file.path(LET, "risposte"), pattern = "[.]jsonl$", full.names = TRUE)))
  for (l in readLines(f, encoding = "UTF-8")) { if (!nzchar(trimws(l))) next; r <- tryCatch(fromJSON(l, simplifyVector = FALSE), error = function(e) NULL); if (!is.null(r$id)) L[[r$id]] <- r }
ok <- vapply(attesi, function(id) { r <- L[[id]]; if (is.null(r) || !isTRUE(r$confrontabile %in% c("si", "no", "incerto"))) return(FALSE)
  t <- vapply(r$difetti, function(d) if (is.null(d$tipo)) NA_character_ else d$tipo, ""); !(r$confrontabile == "no" && !length(t)) && all(t %in% TIPI) }, TRUE)
cat(sprintf("V1 copertura: pacchetti attesi %d, letture valide %d, estranee %d\n", length(attesi), sum(ok), length(setdiff(names(L), attesi))))
V <- do.call(rbind, lapply(attesi[ok], function(id) { k <- ch[[id]]; r <- L[[id]]
  data.frame(id = id, record_id = k$record_id, gruppo = k$gruppo, seconda = r$confrontabile,
             tipi2 = paste(vapply(r$difetti, function(d) d$tipo, ""), collapse = " "),
             citazioni2 = paste(vapply(r$difetti, function(d) if (is.null(d$citazione)) "" else d$citazione, ""), collapse = " || "),
             nota2 = if (is.null(r$nota)) "" else r$nota, stringsAsFactors = FALSE) }))
P <- read.csv(file.path(DIR, "70-letture.csv"), stringsAsFactors = FALSE)
V$prima <- P$confrontabile[match(V$record_id, P$record_id)]; V$tipi1 <- P$tipi[match(V$record_id, P$record_id)]
if (anyNA(V$prima)) stop("confronti della verifica senza prima lettura")
g <- function(x) V[V$gruppo == x, ]
cat(sprintf("V2 controllo positivo: difetti noti giudicati non confrontabili: %s; incerti %d (soglia 80%%)\n", fmt(sum(g("difetto_noto")$seconda == "no"), nrow(g("difetto_noto"))), sum(g("difetto_noto")$seconda == "incerto")))
cat(sprintf("Q1 i 318 ritrovati senza affermazioni: %s; incerti %d\n", fmt(sum(g("nuovo_difetto")$seconda == "no"), nrow(g("nuovo_difetto"))), sum(g("nuovo_difetto")$seconda == "incerto")))
cat(sprintf("Q2 confrontabili per la prima lettura, non confrontabili per la seconda: %s; incerti %d\n", fmt(sum(g("confrontabile_prima")$seconda == "no"), nrow(g("confrontabile_prima"))), sum(g("confrontabile_prima")$seconda == "incerto")))
kappa <- function(x, y) { po <- mean(x == y); pe <- mean(x) * mean(y) + mean(!x) * mean(!y); (po - pe) / (1 - pe) }
x <- V$prima == "no"; y <- V$seconda == "no"; k0 <- kappa(x, y)
set.seed(SEME); kb <- replicate(B, { i <- sample.int(nrow(V), replace = TRUE); kappa(x[i], y[i]) }); ci <- quantile(kb, c(.025, .975), na.rm = TRUE)
cat(sprintf("Q3 accordo fra le due letture sui %d: kappa %.2f [%.2f; %.2f] (bootstrap sui confronti, B=%d); concordi %d\n", nrow(V), k0, ci[1], ci[2], B, sum(x == y)))
# Per tipo del primo difetto della prima lettura: quanti dei 318 si ritrovano.
n <- g("nuovo_difetto"); n$tipo1 <- sub(" .*", "", n$tipi1)
t <- aggregate(cbind(n = 1, ritrovati = n$seconda == "no") ~ tipo1, data = n, FUN = sum); t <- t[order(-t$n), ]
cat("\nritrovati per tipo del primo difetto della prima lettura:\n"); print(t, row.names = FALSE)
cat(sprintf("\nstesso primo tipo nelle due letture, fra i ritrovati: %d su %d\n", sum(sub(" .*", "", n$tipi2[n$seconda == "no"]) == n$tipo1[n$seconda == "no"]), sum(n$seconda == "no")))
conf <- n[n$seconda == "no", c("record_id", "tipi1", "tipi2", "citazioni2", "nota2")]
write.csv(conf, file.path(DIR, "90-difetti-confermati.csv"), row.names = FALSE); write.csv(V, file.path(DIR, "90-letture-verifica.csv"), row.names = FALSE)
cat(sprintf("\nconfronti puliti nel riferimento, non confrontabili per tutte e due le letture: %d, in %d studi\n", nrow(conf), length(unique(sub("__.*$", "", conf$record_id)))))
cat("VERIFICA RACCOLTA\n")
