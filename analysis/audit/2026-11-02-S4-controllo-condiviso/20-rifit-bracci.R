#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-S4-controllo-condiviso/20-rifit-bracci.R
# Cancello 3: rifa' il fit limma-voom di TUTTI i 1.903 bracci e lo confronta col parquet.
# Assegna trattato e controllo PER NOME di campione. Dove i primi n_t colonne in cache non sono
# i trattati, rifa' anche il fit PER POSIZIONE, come .run_per_study_de_all: la chiave di
# .fetch_counts_cached() ignora l'ordine dei campioni, quindi la matrice ha le colonne nell'ordine
# della PRIMA richiesta, e la produzione assegna i ruoli per posizione.
# Se il fit per posizione riproduce il parquet, il braccio ha i ruoli sbagliati nel deliverable.
# Uso: WORKERS=64 Rscript analysis/audit/2026-11-02-S4-controllo-condiviso/20-rifit-bracci.R
source("analysis/audit/2026-11-02-S4-controllo-condiviso/01-comune.R")
library(parallel)

B <- readRDS(file.path(PESANTI, "bracci.rds"))
A <- B$A; corsie <- B$corsie
x <- leggi_bracci_parquet(unique(A$cluster_id))
setkey(x, cluster_id, study_id, braccio)
stopifnot(all(x$direction_applied == "none"))

prendi_conte <- function(sid, gsm) {
  m <- .fetch_counts_cached(sid, gsm, h5_path = NULL, gene_biotype_filter = "protein_coding")
  stopifnot(setequal(colnames(m), gsm))
  m
}
fit_per_nome <- function(m, tratt, contr, cid, sid) {
  st <- attr(m, "gene_symbol")
  m <- m[, c(tratt, contr), drop = FALSE]; attr(m, "gene_symbol") <- st
  tr <- factor(c(rep("treated", length(tratt)), rep("control", length(contr))),
               levels = c("control", "treated"))
  cl <- .collapse_technical_lanes(m, tr, corsie)
  if (nrow(cl$log) > 0L) { attr(cl$counts, "gene_symbol") <- st; m <- cl$counts; tr <- cl$treatment }
  as.data.table(.run_limma_voom_de(m, tr, sid, cid, direction_flip = FALSE))
}

lavoro <- function(i) {
  a <- A[i]
  tr <- strsplit(a$gsm_t, ",", fixed = TRUE)[[1]]; co <- strsplit(a$gsm_c, ",", fixed = TRUE)[[1]]
  m <- prendi_conte(a$study_id, c(tr, co))
  primi <- colnames(m)[seq_along(tr)]
  f <- fit_per_nome(m, tr, co, a$cluster_id, a$study_id)
  v <- x[.(a$cluster_id, a$study_id, a$braccio)]
  j <- match(v$gene_id, f$gene_id)
  out <- data.table(i = i, n_prod = nrow(v), n_rifit = nrow(f), geni_mancanti = sum(is.na(j)),
             d_logFC = max(abs(v$logFC - f$logFC[j]), na.rm = TRUE),
             d_SE = max(abs(v$SE - f$SE[j]), na.rm = TRUE),
             rho_logFC = suppressWarnings(cor(v$logFC, f$logFC[j], use = "complete.obs")),
             trattati_veri_fra_i_primi = sum(primi %in% tr),
             ruoli_giusti_per_posizione = all(primi %in% tr),
             pos_d_logFC = NA_real_, pos_d_SE = NA_real_)
  if (!out$ruoli_giusti_per_posizione) {
    # i ruoli cadono per posizione sulle colonne come stanno in cache, come in produzione
    fp <- factor(c(rep("treated", length(tr)), rep("control", length(co))), levels = c("control", "treated"))
    st <- attr(m, "gene_symbol")
    cl <- .collapse_technical_lanes(m, fp, corsie)
    mp <- m; if (nrow(cl$log) > 0L) { attr(cl$counts, "gene_symbol") <- st; mp <- cl$counts; fp <- cl$treatment }
    p <- as.data.table(.run_limma_voom_de(mp, fp, a$study_id, a$cluster_id, direction_flip = FALSE))
    jp <- match(v$gene_id, p$gene_id)
    out[, `:=`(pos_d_logFC = max(abs(v$logFC - p$logFC[jp]), na.rm = TRUE),
               pos_d_SE = max(abs(v$SE - p$SE[jp]), na.rm = TRUE))]
  }
  out
}
t0 <- Sys.time()
ris <- mclapply(seq_len(nrow(A)), function(i) tryCatch(lavoro(i), error = function(e)
  data.table(i = i, n_prod = NA_integer_, n_rifit = NA_integer_, geni_mancanti = NA_integer_,
             d_logFC = NA_real_, d_SE = NA_real_, rho_logFC = NA_real_,
             trattati_veri_fra_i_primi = NA_integer_, ruoli_giusti_per_posizione = NA,
             pos_d_logFC = NA_real_, pos_d_SE = NA_real_,
             errore = conditionMessage(e))), mc.cores = WORKERS, mc.preschedule = FALSE)
ris <- rbindlist(ris, fill = TRUE)
ris <- cbind(A[ris$i, .(cluster_id, study_id, braccio, n_t, n_c)], ris)
fwrite(ris, file.path(OUT, "20-rifit-bracci.csv"))
cat(sprintf("rifit di %d bracci in %.1f min\n", nrow(ris), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
if ("errore" %in% names(ris) && any(!is.na(ris$errore))) {
  print(unique(ris[!is.na(errore), .(errore)])[1:5]); stop("CANCELLO 3: fit in errore")
}
ris[, scarto := d_logFC > 1e-6 | d_SE > 1e-6]
multi <- A[, .N, by = .(cluster_id, study_id)][N > 1L]
ris[, multi_braccio := paste(cluster_id, study_id) %in% multi[, paste(cluster_id, study_id)]]
cat(sprintf("CANCELLO 3, come depositato, sui %d bracci degli studi multi-braccio: con scarto %d\n",
            sum(ris$multi_braccio), sum(ris$scarto & ris$multi_braccio)))
cat(sprintf("su tutti i %d bracci: con scarto %d | gene set diversi %d | ruoli sbagliati per posizione %d\n",
            nrow(ris), sum(ris$scarto), sum(ris$geni_mancanti > 0 | ris$n_prod != ris$n_rifit),
            sum(!ris$ruoli_giusti_per_posizione)))
sp <- ris[scarto | !ruoli_giusti_per_posizione]
print(sp[, .(cluster_id, study_id, braccio, n_t, n_c, multi_braccio, primi_giusti = trattati_veri_fra_i_primi,
             rho_logFC = round(rho_logFC, 3), d_logFC = signif(d_logFC, 3), pos_d_logFC = signif(pos_d_logFC, 3),
             pos_d_SE = signif(pos_d_SE, 3))])
# Un braccio con scarto e' spiegato solo se il fit per posizione lo riproduce. Altrimenti
# l'abbinamento fra bracci e campioni non e' provato e rho non vale: ci si ferma.
ignoti <- sp[scarto & (is.na(pos_d_logFC) | pos_d_logFC > 1e-6 | pos_d_SE > 1e-6)]
if (nrow(ignoti) > 0L) { print(ignoti); stop("CANCELLO 3: scarti senza spiegazione, ci si ferma") }
cat(sprintf("abbinamento provato: %d bracci per nome, %d per posizione, 0 senza spiegazione\n",
            sum(!ris$scarto), sum(ris$scarto)))
fwrite(ris, file.path(OUT, "20-rifit-bracci.csv"))
