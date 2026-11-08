#!/usr/bin/env Rscript
# S12p, quarta parte A: quanto si vede senza modello. Per ogni confronto, le coppie «chiave: valore» di
# characteristics_ch1 (e source_name_ch1) di ogni campione; il codice confronta i bracci. Regole: 00-previsioni-monte.md.
# Uso: Rscript analysis/audit/2026-11-08-S12p-prova/100-senza-modello.R > analysis/audit/2026-11-08-S12p-prova/100-out.txt
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-08-S12p-prova/aiuti.R")
wilson <- function(x, n) { z <- qnorm(0.975); p <- x / n; c0 <- p + z^2 / (2 * n); r <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)); (c(c0 - r, c0 + r)) / (1 + z^2 / n) }
fmt <- function(x, n) { ci <- wilson(x, n); sprintf("%d su %d = %.1f%% [%.1f; %.1f]", x, n, 100 * x / n, 100 * ci[1], 100 * ci[2]) }
h5 <- H5_CAMPI(); ten <- TENUTI()
ing <- lapply(readLines(gzfile(INGR), encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
ent <- setNames(vapply(ing, function(r) paste(r$entita_proposta, r$etichetta_trattato), ""), vapply(ing, `[[`, "", "record_id"))
rif <- read.csv("analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv", stringsAsFactors = FALSE)$record_id
nuovi <- read.csv(file.path(DIR, "94-difetti-finali.csv"), stringsAsFactors = FALSE)$record_id
difettoso <- ten$record_id %in% union(rif, nuovi)
cat(sprintf("riferimento allargato: %d difettosi, %d puliti\n", sum(difettoso), sum(!difettoso)))

# coppie chiave: valore di un campione (testo con la riparazione della codifica dello Stadio 2b)
coppie <- function(ch, src) {
  ch <- .s2b_norm_testo(ifelse(is.na(ch), "", ch)); src <- .s2b_norm_testo(ifelse(is.na(src), "", src))
  pz <- if (nzchar(ch)) strsplit(ch, ",(?=\\s*[^,:]{1,60}:\\s)", perl = TRUE)[[1]] else character()
  k <- tolower(trimws(sub(":.*$", "", pz))); v <- tolower(trimws(sub("^[^:]*:", "", pz)))
  ok <- grepl(":", pz) & nzchar(k); out <- setNames(v[ok], k[ok])
  if (nzchar(src)) out <- c(out, source_name = tolower(trimws(src)))
  out[!duplicated(names(out))]
}
parole <- function(x) { w <- strsplit(gsub("[[:punct:]]+", " ", tolower(x)), "\\s+")[[1]]; unique(w[nchar(w) >= 3]) }
REPLICA <- c("replicate", "replica", "rep", "batch", "lane", "run")
analizza <- function(i) {
  t <- ten[i, ]; gt <- strsplit(t$gsm_t, ",")[[1]]; gc <- strsplit(t$gsm_c, ",")[[1]]
  ht <- h5[match(gt, h5$geo_accession), ]; hc <- h5[match(gc, h5$geo_accession), ]
  ct <- lapply(seq_len(nrow(ht)), function(j) coppie(ht$characteristics_ch1[j], ht$source_name_ch1[j]))
  cc <- lapply(seq_len(nrow(hc)), function(j) coppie(hc$characteristics_ch1[j], hc$source_name_ch1[j]))
  chiavi <- unique(c(unlist(lapply(ct, names)), unlist(lapply(cc, names))))
  n_strutt <- min(vapply(c(ct, cc), length, 1L))
  w_ent <- parole(ent[[t$record_id]])
  accuse <- character(); mescolate <- character(); entita <- character()
  for (k in chiavi) {
    vt <- vapply(ct, function(x) if (k %in% names(x)) x[[k]] else NA_character_, ""); vc <- vapply(cc, function(x) if (k %in% names(x)) x[[k]] else NA_character_, "")
    tutti <- c(vt, vc)
    if (any(strsplit(k, "[^a-z]+")[[1]] %in% REPLICA)) next                       # chiave di replica
    if (sum(!is.na(tutti)) >= 2 && length(unique(tutti[!is.na(tutti)])) == length(tutti)) next   # identificativo
    st <- unique(vt[!is.na(vt)]); sc <- unique(vc[!is.na(vc)])
    diversa <- length(st) && length(sc) && !setequal(st, sc)
    if (diversa && any(vapply(st, function(v) any(parole(v) %in% w_ent), TRUE))) { entita <- c(entita, k); next }
    if (diversa) accuse <- c(accuse, k)
    if (length(st) > 1 || length(sc) > 1) mescolate <- c(mescolate, k)
  }
  tec <- .s2b_tecnica_h5(ht, hc); tec_div <- any(tec %in% c("disgiunta", "parziale"))
  data.frame(record_id = t$record_id, n = length(gt) + length(gc), n_strutt = n_strutt, entita = paste(entita, collapse = "|"),
             accuse = paste(accuse, collapse = "|"), tecnica = tec_div, accusa = length(accuse) > 0 || tec_div,
             mescolato = length(mescolate) > 0, chiavi_mescolate = paste(mescolate, collapse = "|"), stringsAsFactors = FALSE)
}
R <- do.call(rbind, lapply(seq_len(nrow(ten)), analizza)); R$difettoso <- difettoso
cat(sprintf("A1 difetti presi senza modello: %s\n", fmt(sum(R$accusa & R$difettoso), sum(R$difettoso))))
cat(sprintf("A2 puliti accusati senza modello: %s\n", fmt(sum(R$accusa & !R$difettoso), sum(!R$difettoso))))
cat(sprintf("A3 difetti con un braccio mescolato: %s\n", fmt(sum(R$mescolato & R$difettoso), sum(R$difettoso))))
cat(sprintf("A4 puliti con un braccio mescolato: %s\n", fmt(sum(R$mescolato & !R$difettoso), sum(!R$difettoso))))
cat(sprintf("A5 confronti con almeno 2 chiavi strutturate in ogni campione: %s\n", fmt(sum(R$n_strutt >= 2), nrow(R))))
cat(sprintf("   confronti con un campione per braccio (il codice non puo' accusare): %d; confronti senza chiave dell'entita' trovata: %d\n", sum(R$n == 2), sum(!nzchar(R$entita))))
cat(sprintf("   difetti presi solo dalla tecnica dell'H5: %d\n", sum(R$tecnica & !nzchar(R$accuse) & R$difettoso)))
# che cosa accusa i puliti: le chiavi piu' frequenti
k <- table(unlist(strsplit(R$accuse[R$accusa & !R$difettoso], "\\|"))); cat("\nchiavi che accusano i puliti (le 20 piu' frequenti):\n"); print(head(sort(k, decreasing = TRUE), 20))
k <- table(unlist(strsplit(R$accuse[R$accusa & R$difettoso], "\\|"))); cat("\nchiavi che accusano i difetti (le 20 piu' frequenti):\n"); print(head(sort(k, decreasing = TRUE), 20))
# per famiglia dei difetti del riferimento allargato (tipo della lettura per i 280; famiglia di S11 per i 193)
P <- read.csv(file.path(DIR, "94-difetti-finali.csv"), stringsAsFactors = FALSE)
tipo <- setNames(sub(" .*", "", P$tipi2), P$record_id)
cat("\npresi senza modello fra i 280, per tipo della seconda lettura:\n")
x <- R[R$record_id %in% names(tipo), ]; x$tipo <- tipo[x$record_id]; print(aggregate(cbind(n = 1, presi = x$accusa) ~ tipo, x, sum))
write.csv(R, file.path(DIR, "100-senza-modello.csv"), row.names = FALSE)
cat("MISURA FINITA\n")
