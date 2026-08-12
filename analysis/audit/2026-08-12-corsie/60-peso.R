# FASE 4b — IL PUNTO CHE IL SOLO `k` NON DICE.
#
# Se le corsie sono contate come repliche, la varianza intra-braccio stimata da
# limma-voom e' rumore di SEQUENZIAMENTO, non biologia: l'errore standard esce
# troppo piccolo e nella meta-analisi a inverso della varianza quello studio pesa
# TROPPO. Il difetto quindi NON riguarda solo le entry che cadono sotto n_min: i
# tre studi che sopravvivono (GSE115542 12->3, GSE178340 12->3, GSE116899 10->5)
# hanno anch'essi una varianza stimata su un n gonfiato.
#
# Qui si misura, con la macchina di produzione, quanto pesano davvero.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-12-corsie"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
R   <- readRDS(file.path(SC, "30-entry-annotate.rds"))

tocc <- R[R$tocca, c("cluster_id", "study_id", "cade")]
cid  <- unique(tocc$cluster_id)
cat("cluster interessati:", length(cid), "\n")

psd <- arrow::read_parquet(file.path(DEL, "per_study_de.parquet"))
psd <- psd[psd$cluster_id %in% cid, ]
pol <- arrow::read_parquet(file.path(DEL, "cluster_pooled.parquet"))
pol <- pol[pol$cluster_id %in% cid, ]
cat("per_study_de righe:", nrow(psd), "| pooled righe:", nrow(pol), "\n")

sig <- pol[!is.na(pol$FDR_BH_within_cluster) & pol$FDR_BH_within_cluster < 0.05, c("cluster_id", "gene_id")]
psd_s <- merge(psd, sig, by = c("cluster_id", "gene_id"))
tau2  <- unique(pol[, c("cluster_id", "gene_id", "tau2")])
q <- compute_pooling_weight_shares(psd_s, tau2, tocc[, c("cluster_id", "study_id")])
cat("\n=== QUOTA DI PESO DELLO STUDIO CON LE CORSIE (sui geni significativi) ===\n")
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
q <- merge(q, del[, c("cluster_id", "canonical_name", "k_effective", "n_sig", "k_kish")],
           by = "cluster_id")
q <- merge(q, unique(tocc[, c("cluster_id", "study_id")]), by = "cluster_id")
q$equipeso <- 1 / q$k_effective
q$rapporto <- q$quota_mediana / q$equipeso
print(q[order(-q$quota_mediana),
        c("canonical_name", "study_id", "k_effective", "n_sig", "k_kish",
          "quota_mediana", "equipeso", "rapporto")], row.names = FALSE)

# SE mediano dello studio con le corsie contro gli altri, nello stesso cluster
cat("\n=== SE MEDIANO: lo studio con le corsie contro gli altri dello stesso gruppo ===\n")
out <- list()
for (cc in cid) {
  d <- psd_s[psd_s$cluster_id == cc, ]
  st <- tocc$study_id[tocc$cluster_id == cc]
  a <- stats::median(d$SE[d$study_id %in% st], na.rm = TRUE)
  b <- stats::median(d$SE[!(d$study_id %in% st)], na.rm = TRUE)
  out[[length(out)+1L]] <- data.frame(cluster_id = cc, studio = st[1],
    SE_corsie = round(a, 4), SE_altri = round(b, 4), rapporto = round(a / b, 3),
    n_altri_studi = length(unique(d$study_id[!(d$study_id %in% st)])),
    stringsAsFactors = FALSE)
}
S <- merge(do.call(rbind, out), del[, c("cluster_id", "canonical_name")], by = "cluster_id")
print(S[order(S$rapporto), c("canonical_name", "studio", "SE_corsie", "SE_altri",
                             "rapporto", "n_altri_studi")], row.names = FALSE)

write.csv(q, file.path(SC, "60-peso.csv"), row.names = FALSE)
write.csv(S, file.path(SC, "60-se.csv"), row.names = FALSE)
cat("\nscritto.\n")
