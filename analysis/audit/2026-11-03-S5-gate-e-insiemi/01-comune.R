# analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R
# Percorsi e funzioni comuni. Rscript SENZA --vanilla: con --vanilla mancano arrow e devtools.
# Riusa rho, struttura_coppia, var_t1, rem_gruppo e librerie della sessione sul controllo condiviso.
source("analysis/audit/2026-11-02-S4-controllo-condiviso/01-comune.R")
OUT5 <- "analysis/audit/2026-11-03-S5-gate-e-insiemi"
PES5 <- "/mnt/micron/simulomicsr-dati/2026-11-03-S5-gate-e-insiemi"
dir.create(PES5, showWarnings = FALSE, recursive = TRUE)
SEME <- 20261103L
B_BOOT <- 2000L
H5 <- "analysis/input/human_gene_v2.5.h5"
A3_S3 <- "analysis/p4-output/20260818T110906Z-stage3-v16-7f986159"
A3_S2 <- "analysis/p4-output/A3-stage2-master-innestato.jsonl"
RIF_POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/archivio/20260815T193851Z-stage4-v16-3e31e59d"
RIF_S3 <- "analysis/p4-output/20260815T231154Z-stage3-v16-7f986159"
RIF_S2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

# Bootstrap percentile della mediana. L'unita' e' il gruppo (lo studio per il movimento).
ic_mediana <- function(x, B = B_BOOT, seme = SEME) {
  x <- x[is.finite(x)]
  set.seed(seme)
  b <- replicate(B, stats::median(sample(x, replace = TRUE)))
  c(stima = stats::median(x), lo = unname(stats::quantile(b, 0.025)), hi = unname(stats::quantile(b, 0.975)), n = length(x))
}
