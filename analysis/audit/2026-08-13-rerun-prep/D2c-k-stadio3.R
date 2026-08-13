# D2c — L'effetto di D2 dove agisce davvero: il `k` dello STADIO 3.
# Il gate scarta il MEMBRO prima del clustering, quindi il cluster perde lo
# studio se non ha altri membri. Il `k_effective` (poolato) e' un'altra cosa: i
# 5 confronti segnalati hanno tutti un braccio sotto `n_min` e non erano poolati.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-13-rerun-prep"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
D   <- readRDS(file.path(SC, "D2b-deliverable.rds"))
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))

k_s3_ora  <- tapply(D$study_id, D$cluster_id, function(x) length(unique(x)))
E <- D[!D$asim_new, ]
k_s3_dopo <- tapply(E$study_id, E$cluster_id, function(x) length(unique(x)))
cid <- names(k_s3_ora); k2 <- ifelse(is.na(k_s3_dopo[cid]), 0L, k_s3_dopo[cid])
cat("=== k dello STADIO 3, prima e dopo lo scarto dei membri ===\n")
for (c0 in cid[k_s3_ora != k2])
  cat(sprintf("  %-20s k %2d -> %2d   %s\n", c0, k_s3_ora[c0], k2[c0],
              del$canonical_name[match(c0, del$cluster_id)]))
cat("gruppi che perdono almeno uno studio:", sum(k_s3_ora != k2),
    "| che scendono sotto 3:", sum(k2 < 3L), "\n")
cat("\n=== k_effective (poolato): invariato? ===\n")
P <- D[D$poolato, ]; Q <- P[!P$asim_new, ]
ke1 <- tapply(P$study_id, P$cluster_id, function(x) length(unique(x)))
ke2 <- tapply(Q$study_id, Q$cluster_id, function(x) length(unique(x)))
cid2 <- names(ke1); ke2f <- ifelse(is.na(ke2[cid2]), 0L, ke2[cid2])
cat("gruppi col k_eff cambiato da D2:", sum(ke1 != ke2f), "\n")
