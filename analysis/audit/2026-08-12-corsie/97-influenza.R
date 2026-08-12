# FASE 5 — CHE COSA CAMBIA NEL RISULTATO POOLATO, misurato e non argomentato.
#
# Due effetti distinti, tenuti separati perche' sono due cose diverse:
#   (A) i 6 confronti di GSE173902 spariscono  -> 6 gruppi perdono uno studio;
#   (B) i 3 confronti che restano (GSE115542, GSE178340, GSE116899) cambiano
#       logFC/SE perche' le corsie sono sommate -> il loro contributo si sposta.
#
# Il ri-pooling usa la macchina di produzione (`pool_cluster_leaving_out`, che
# riproduce `cluster_pooled.parquet` con scarto nullo, verificato il 2026-08-10),
# e l'influenza si misura sui geni SIGNIFICATIVI del pooling pieno, insieme fisso.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-12-corsie"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
R   <- readRDS(file.path(SC, "30-entry-annotate.rds")); R <- R[R$esito == "ammessa", ]
M   <- readRDS(file.path(SC, "20-metadati.rds"))
lk  <- readRDS(file.path(SC, "94-lookup.rds"))
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
h5  <- "analysis/input/human_gene_v2.5.h5"

cid <- unique(R$cluster_id[R$tocca])
psd <- arrow::read_parquet(file.path(DEL, "per_study_de.parquet"))
psd <- psd[psd$cluster_id %in% cid, ]
pol <- arrow::read_parquet(file.path(DEL, "cluster_pooled.parquet"))
pol <- pol[pol$cluster_id %in% cid, ]

cat("=== ACCETTAZIONE: il ri-pooling riproduce il pubblicato? ===\n")
for (cc in cid) {
  a <- pool_cluster_leaving_out(psd[psd$cluster_id == cc, ], character(0))
  b <- pol[pol$cluster_id == cc, ]
  m <- merge(a[, c("gene_id", "logFC_pool", "SE_pool", "tau2", "I2")],
             b[, c("gene_id", "logFC_pool", "SE_pool", "tau2", "I2")], by = "gene_id")
  cat(sprintf("  %s geni %5d | scarto max logFC %.3e  SE %.3e  tau2 %.3e  I2 %.3e\n",
      substr(cc, 1, 18), nrow(m),
      max(abs(m$logFC_pool.x - m$logFC_pool.y)), max(abs(m$SE_pool.x - m$SE_pool.y)),
      max(abs(m$tau2.x - m$tau2.y)), max(abs(m$I2.x - m$I2.y))))
}

# ---- (B) le tre entry che restano: DE rifatto con le corsie sommate ---------
acc <- as.character(rhdf5::h5read(h5, "meta/samples/geo_accession"))
gid <- as.character(rhdf5::h5read(h5, "meta/genes/ensembl_gene"))
leggi <- function(g) { i <- match(g, acc)
  x <- rhdf5::h5read(h5, "data/expression", index = list(i, NULL))
  m <- t(x); rownames(m) <- gid; colnames(m) <- g; m }

T <- R[R$tocca & !R$cade, ]
nuovi <- list()
for (r in seq_len(nrow(T))) {
  gt <- strsplit(T$gsm_treated[r], ",")[[1]]; gc_ <- strsplit(T$gsm_control[r], ",")[[1]]
  cnt <- leggi(c(gt, gc_))
  trt <- factor(c(rep("treated", length(gt)), rep("control", length(gc_))),
                levels = c("control", "treated"))
  z <- .collapse_technical_lanes(cnt, trt, lk)
  nuovi[[length(nuovi) + 1L]] <-
    .run_limma_voom_de(z$counts, z$treatment, T$study_id[r], T$cluster_id[r])
  cat(sprintf("rifatto %s %s: %d -> %d colonne\n", T$study_id[r],
              substr(T$cluster_id[r], 1, 18), ncol(cnt), ncol(z$counts)))
}
rhdf5::h5closeAll()
N <- do.call(rbind, nuovi)

# ---- il nuovo per_study_de: entry cadute tolte, entry collassate sostituite --
psd2 <- psd[!(psd$cluster_id %in% R$cluster_id[R$cade] & psd$study_id == "GSE173902"), ]
for (r in seq_len(nrow(T))) {
  k <- psd2$cluster_id == T$cluster_id[r] & psd2$study_id == T$study_id[r]
  psd2 <- psd2[!k, ]
}
psd2 <- rbind(psd2[, names(N)], N[, names(N)])
cat("\nper_study_de: righe", nrow(psd), "->", nrow(psd2), "\n")

# ---- l'influenza, gene per gene sui significativi del pieno ------------------
out <- list()
for (cc in cid) {
  pieno  <- pool_cluster_leaving_out(psd[psd$cluster_id == cc, ], character(0))
  nuovo  <- pool_cluster_leaving_out(psd2[psd2$cluster_id == cc, ], character(0))
  sig <- pieno$gene_id[!is.na(pieno$FDR_BH_within_cluster) &
                         pieno$FDR_BH_within_cluster < 0.05]
  inf <- compute_pooling_influence(pieno, nuovo, sig)
  ks <- length(unique(psd$study_id[psd$cluster_id == cc]))
  kn <- length(unique(psd2$study_id[psd2$cluster_id == cc]))
  out[[length(out) + 1L]] <- data.frame(
    cluster_id = cc, k_prima = ks, k_dopo = kn, n_sig_prima = length(sig),
    inf, stringsAsFactors = FALSE)
}
E <- merge(do.call(rbind, out), del[, c("cluster_id", "canonical_name")], by = "cluster_id")
cat("\n=== INFLUENZA SUL RISULTATO POOLATO ===\n")
print(E[order(E$k_prima), ], row.names = FALSE)
write.csv(E, file.path(SC, "97-influenza.csv"), row.names = FALSE)
saveRDS(list(E = E, psd2 = psd2), file.path(SC, "97-influenza.rds"))
cat("\nscritto.\n")
