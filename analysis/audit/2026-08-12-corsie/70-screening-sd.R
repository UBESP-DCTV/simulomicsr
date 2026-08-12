# FASE 2b — LA RICERCA DEI FALSI NEGATIVI, senza guardare le stringhe.
#
# Il rilevatore lessicale trova solo cio' che il titolo dichiara. Se un
# sottomettente ha spezzato una libreria in corsie SENZA scriverlo nel titolo, il
# rilevatore e' cieco. Serve un segnale che venga dai DATI.
#
# Statistica scelta, e perche'. In un confronto a due gruppi limma-voom stima
#     SE(logFC) ~= sd * sqrt(1/n1 + 1/n2)
# quindi
#     sd_stimata = SE / sqrt(1/n1 + 1/n2)
# e' la deviazione standard intra-gruppo AL NETTO della numerosita'. Confrontare
# SE fra studi non dice nulla (chi ha piu' campioni ha SE minore per costruzione);
# confrontare sd_stimata si': uno studio le cui repliche sono corsie ha una sd
# vera di sequenziamento, molto piu' piccola di quella biologica dei suoi pari.
#
# Il confronto e' DENTRO il cluster (stessa biologia, stessi geni) e sui geni
# significativi del poolato, per non misurare rumore di fondo.
SC  <- "analysis/audit/2026-08-12-corsie"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
R   <- readRDS(file.path(SC, "30-entry-annotate.rds"))

psd <- arrow::read_parquet(file.path(DEL, "per_study_de.parquet"))
pol <- arrow::read_parquet(file.path(DEL, "cluster_pooled.parquet"),
                           col_select = c("cluster_id", "gene_id", "FDR_BH_within_cluster"))
sig <- pol[!is.na(pol$FDR_BH_within_cluster) & pol$FDR_BH_within_cluster < 0.05,
           c("cluster_id", "gene_id")]
rm(pol); invisible(gc())
cat("geni significativi (cluster,gene):", nrow(sig), "\n")
d <- merge(psd, sig, by = c("cluster_id", "gene_id"))
rm(psd); invisible(gc())
cat("righe per-braccio sui geni significativi:", nrow(d), "\n")

d$sd_stim <- d$SE / sqrt(1/d$n_treated + 1/d$n_control)
d <- d[is.finite(d$sd_stim) & d$sd_stim > 0, ]

# una riga per (cluster, studio, braccio): la mediana sui geni
agg <- stats::aggregate(list(sd_stim = d$sd_stim, SE = d$SE),
                        by = list(cluster_id = d$cluster_id, study_id = d$study_id,
                                  n_treated = d$n_treated, n_control = d$n_control),
                        FUN = stats::median)
agg$n_geni <- stats::aggregate(list(n = d$sd_stim),
                        by = list(cluster_id = d$cluster_id, study_id = d$study_id,
                                  n_treated = d$n_treated, n_control = d$n_control),
                        FUN = length)$n
cat("coppie (cluster,studio,braccio):", nrow(agg), "| cluster:",
    length(unique(agg$cluster_id)), "\n")

# rapporto con la mediana degli ALTRI studi dello stesso cluster
agg$rapporto <- NA_real_; agg$n_altri <- NA_integer_
for (cc in unique(agg$cluster_id)) {
  i <- which(agg$cluster_id == cc)
  for (j in i) {
    altri <- setdiff(i, which(agg$cluster_id == cc & agg$study_id == agg$study_id[j]))
    if (length(altri) >= 2L) {
      agg$rapporto[j] <- agg$sd_stim[j] / stats::median(agg$sd_stim[altri])
      agg$n_altri[j]  <- length(unique(agg$study_id[altri]))
    }
  }
}
A <- agg[!is.na(agg$rapporto), ]
cat("confrontabili (>=2 altri bracci nel cluster):", nrow(A), "\n")

cat("\n=== DISTRIBUZIONE DEL RAPPORTO sd_stimata / mediana degli altri ===\n")
print(round(stats::quantile(A$rapporto, c(0.001, 0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 1)), 3))

noti <- unique(R$study_id[R$tocca])
A$noto <- A$study_id %in% noti
cat("\n=== DOVE STANNO I QUATTRO STUDI GIA' NOTI ===\n")
for (s in noti) {
  z <- A[A$study_id == s, ]
  if (!nrow(z)) { cat(sprintf("  %-11s nessun braccio confrontabile\n", s)); next }
  cat(sprintf("  %-11s bracci %2d | rapporto %s | percentile %s\n", s, nrow(z),
      paste(round(z$rapporto, 3), collapse = ", "),
      paste(round(100 * stats::ecdf(A$rapporto)(z$rapporto), 1), collapse = ", ")))
}

cat("\n=== I 30 BRACCI CON LA sd PIU' ANOMALA (candidati non lessicali) ===\n")
B <- A[order(A$rapporto), ][1:min(30, nrow(A)), ]
B$gia_noto <- ifelse(B$noto, "NOTO", "")
print(B[, c("cluster_id", "study_id", "n_treated", "n_control", "sd_stim",
            "rapporto", "n_altri", "n_geni", "gia_noto")], row.names = FALSE)

saveRDS(A, file.path(SC, "70-sd-screening.rds"))
write.csv(A[order(A$rapporto), ], file.path(SC, "70-sd-screening.csv"), row.names = FALSE)
cat("\nscritto.\n")
