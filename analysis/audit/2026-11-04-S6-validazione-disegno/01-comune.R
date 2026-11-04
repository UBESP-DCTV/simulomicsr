# analysis/audit/2026-11-04-S6-validazione-disegno/01-comune.R
# Rscript SENZA --vanilla: con --vanilla mancano arrow e devtools.
suppressPackageStartupMessages(library(data.table))
OUT6 <- "analysis/audit/2026-11-04-S6-validazione-disegno"
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
V15  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
LIN  <- "/mnt/wwn-0x5000039d58caca35/lincs-meta"
OLD  <- "analysis/audit/2026-08-08-validazione-esterna"
S5   <- "analysis/audit/2026-11-03-S5-gate-e-insiemi"
SEME <- 20261104L
# I file pesanti stanno fuori dal repository: si rifanno rilanciando gli script.
PES6 <- "/mnt/micron/simulomicsr-dati/2026-11-04-S6-validazione-disegno"
dir.create(PES6, showWarnings = FALSE, recursive = TRUE)
