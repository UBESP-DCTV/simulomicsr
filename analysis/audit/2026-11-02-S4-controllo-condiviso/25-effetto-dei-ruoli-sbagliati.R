#!/usr/bin/env Rscript
# analysis/audit/2026-11-02-S4-controllo-condiviso/25-effetto-dei-ruoli-sbagliati.R
# I bracci con i ruoli sbagliati nel deliverable (vedi 20-rifit-bracci.R): che cosa cambia nella
# loro meta-analisi con i ruoli giusti. Stessa catena di produzione, cambia solo quel braccio.
# Solo misura: il deliverable non viene toccato.
# Uso: Rscript analysis/audit/2026-11-02-S4-controllo-condiviso/25-effetto-dei-ruoli-sbagliati.R
source("analysis/audit/2026-11-02-S4-controllo-condiviso/01-comune.R")
suppressPackageStartupMessages(library(dplyr))
B <- readRDS(file.path(PESANTI, "bracci.rds")); A <- B$A; corsie <- B$corsie
ris <- fread(file.path(OUT, "20-rifit-bracci.csv"))
sb <- ris[ruoli_giusti_per_posizione == FALSE]
d <- as.data.table(readRDS(file.path(POOL, "deliverable-annotato.rds")))
v <- as.data.table(utils::read.csv(file.path(RIL, "verdetti-194.csv"), stringsAsFactors = FALSE))
sel113 <- v[n_studi_difettosi == 0 & verdetto_finale == "corretta" & etichetta_non_chiude != "True", cluster_id]
cat(sprintf("bracci con i ruoli sbagliati: %d\n\n", nrow(sb)))

righe <- list()
for (k in seq_len(nrow(sb))) {
  cid <- sb$cluster_id[k]; sid <- sb$study_id[k]; br <- sb$braccio[k]
  a <- A[cluster_id == cid & study_id == sid & braccio == br]
  x <- as.data.table(open_dataset(file.path(POOL, "per_study_de.parquet")) |>
    dplyr::filter(cluster_id == !!cid) |> dplyr::collect())
  asse <- asse_geni(); x[, pos := match(gene_id, asse)]
  x[, braccio := segna_bracci(pos, n_treated, n_control), by = study_id]
  tr <- strsplit(a$gsm_t, ",", fixed = TRUE)[[1]]; co <- strsplit(a$gsm_c, ",", fixed = TRUE)[[1]]
  m <- .fetch_counts_cached(sid, c(tr, co), h5_path = NULL, gene_biotype_filter = "protein_coding")
  st <- attr(m, "gene_symbol"); m <- m[, c(tr, co), drop = FALSE]; attr(m, "gene_symbol") <- st
  fr <- factor(c(rep("treated", length(tr)), rep("control", length(co))), levels = c("control", "treated"))
  f <- as.data.table(.run_limma_voom_de(m, fr, sid, cid, direction_flip = FALSE))
  y <- copy(x)
  iv <- y[study_id == sid & braccio == br, which = TRUE]
  j <- match(y$gene_id[iv], f$gene_id); stopifnot(!anyNA(j))
  y$logFC[iv] <- f$logFC[j]; y$SE[iv] <- f$SE[j]
  catena <- function(z) {
    st <- z[, {w <- 1 / SE^2; .(y = sum(w * logFC) / sum(w), se = sqrt(1 / sum(w)))}, by = .(study_id, gene_id)]
    r <- rem_gruppo(st[, .(gene_id, y, se)], cid)
    t2 <- r[FDR < 0.05, .(cluster_id, gene_id, tau2)]
    e <- if (nrow(t2)) as.data.table(compute_pooling_effectiveness(
      as.data.frame(z[, .(cluster_id, gene_id, study_id, SE)]), as.data.frame(t2))) else
      data.table(quota_top1 = NA_real_, k_kish = NA_real_, studio_dominante = NA_character_)
    pesi <- if (nrow(t2)) as.data.table(.compute_study_gene_weights(
      as.data.frame(z[, .(cluster_id, gene_id, study_id, SE)]), as.data.frame(t2)))[study_id == sid, median(quota)] else NA_real_
    list(n_sig = nrow(t2), I2 = median(r$I2, na.rm = TRUE), q = e$quota_top1, kish = e$k_kish, dom = e$studio_dominante, peso = pesi, r = r)
  }
  p <- catena(x); q <- catena(y)
  g <- merge(p$r[, .(gene_id, a = logFC_pool)], q$r[, .(gene_id, b = logFC_pool)], by = "gene_id")
  dd <- d[cluster_id == cid]
  cat(sprintf("%s in «%s» (braccio %d, %d contro %d; trattati veri fra i primi: %d)\n", sid, dd$contrast_entity_label, br,
              a$n_t, a$n_c, sb$trattati_veri_fra_i_primi[k]))
  cat(sprintf("  riproduco il deliverable: geni significativi %d su disco, %d qui; quota %.3f su disco, %.3f qui\n", dd$n_sig, p$n_sig, dd$quota_top1, p$q))
  cat(sprintf("  geni significativi %d -> %d | I2 mediano %.1f -> %.1f | quota_top1 %.3f -> %.3f | kish %.2f -> %.2f | dominante %s -> %s\n",
              p$n_sig, q$n_sig, p$I2, q$I2, p$q, q$q, p$kish, q$kish, p$dom, q$dom))
  cat(sprintf("  peso mediano dello studio: %.3f -> %.3f | Spearman logFC poolati: %.3f | nei 113: %s, nei 37 prima: %s, dopo: %s\n\n",
              p$peso, q$peso, cor(g$a, g$b, method = "spearman"), cid %in% sel113,
              cid %in% sel113 && p$q <= .5, cid %in% sel113 && !is.na(q$q) && q$q <= .5))
  righe[[k]] <- data.table(study_id = sid, cluster_id = cid, entita = dd$contrast_entity_label, braccio = br, n_t = a$n_t, n_c = a$n_c,
                           trattati_veri_fra_i_primi = sb$trattati_veri_fra_i_primi[k], sig_prima = p$n_sig, sig_dopo = q$n_sig,
                           I2_prima = p$I2, I2_dopo = q$I2, quota_prima = p$q, quota_dopo = q$q, peso_prima = p$peso, peso_dopo = q$peso,
                           in113 = cid %in% sel113)
}
fwrite(rbindlist(righe), file.path(OUT, "25-effetto.csv"))
