#!/usr/bin/env Rscript
# analysis/audit/2026-08-21-S3-test-retest/50-inversione-GSE144269.R
#
# Il modulo RISPOSTE.csv dice che in GSE144269 i bracci sono invertiti nella
# meta-analisi «Carcinoma, Hepatocellular»: il TRATTATO e' tutto non-tumor, il
# CONTROLLO tutto tumor (metadato H5 e titoli lo confermano, 56 e 61 campioni).
# Qui si guarda se l'inversione si vede nei DATI, con marcatori fissati dalla
# letteratura prima di aprire il risultato (up nel HCC: GPC3 AFP MKI67 TOP2A
# CDC20 CCNB1; down: CYP2E1 CYP3A4 ALB APOA1 CRP SAA1), e quanto pesa lo studio.
# Solo misura: nessuna correzione.
#
# Uso: Rscript analysis/audit/2026-08-21-S3-test-retest/50-inversione-GSE144269.R
suppressPackageStartupMessages(library(arrow))
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
CID <- "cgroup_L5_bd19fe42"
x <- as.data.frame(arrow::open_dataset(file.path(POOL, "per_study_de.parquet")) |>
                     dplyr::filter(cluster_id == CID) |> dplyr::collect())
cat("colonne:", paste(names(x), collapse = " "), "\n")
UP <- c("GPC3","AFP","MKI67","TOP2A","CDC20","CCNB1"); DOWN <- c("CYP2E1","CYP3A4","ALB","APOA1","CRP","SAA1")
sp <- if ("study_id" %in% names(x)) "study_id" else stop("manca study_id")
lf <- intersect(c("logFC","log2FC","yi"), names(x))[1]; gs <- intersect(c("gene_symbol","symbol"), names(x))[1]
cat("studi:", paste(unique(x[[sp]]), collapse = " "), "| colonna effetto:", lf, "\n\n")
m <- x[x[[gs]] %in% c(UP, DOWN), c(sp, gs, lf)]
ag <- aggregate(m[[lf]], list(s = m[[sp]], g = m[[gs]]), mean)
tb <- reshape(ag, idvar = "g", timevar = "s", direction = "wide"); names(tb) <- sub("^x\\.", "", names(tb))
tb <- tb[match(c(UP, DOWN), tb$g), ]; tb$atteso <- rep(c("up","down"), each = 6)
print(data.frame(lapply(tb, function(v) if (is.numeric(v)) round(v, 2) else v)), row.names = FALSE)
cat("\nconcordanza di segno coi marcatori attesi, per studio:\n")
for (s in unique(x[[sp]])) if (s %in% names(tb)) {
  att <- ifelse(tb$atteso == "up", 1, -1); v <- sign(tb[[s]]); ok <- !is.na(v)
  cat(sprintf("  %-12s %2d/%2d\n", s, sum(v[ok] == att[ok]), sum(ok)))
}
# correlazione genome-wide fra studi: uno studio invertito va contro tutti gli altri
w <- aggregate(x[[lf]], list(s = x[[sp]], g = x[[if ("gene_id" %in% names(x)) "gene_id" else gs]]), mean)
W <- reshape(w, idvar = "g", timevar = "s", direction = "wide"); names(W) <- sub("^x\\.", "", names(W))
cat("\ncorrelazione di Spearman fra studi sull'effetto, tutti i geni:\n")
print(round(cor(W[, -1], use = "pairwise.complete.obs", method = "spearman"), 2))
# quanto pesa: k_kish e quota del piu' pesante dal deliverable
d <- readRDS(file.path(POOL, "deliverable-annotato.rds")); r <- d[d$cluster_id == CID, ]
cat(sprintf("\nnel deliverable: k_effective=%s k_kish=%.2f quota_top1=%.1f%% n_sig=%s\n", r$k_effective, r$k_kish, 100*r$quota_top1, r$n_sig))
# Il peso REM vero degli studi sta in analysis/audit/2026-11-02-inversioni-194/30-pesi-rem.R
