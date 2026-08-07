suppressPackageStartupMessages({library(arrow); library(dplyr)})
S4 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
OUT<- "/home/user/simulomicsr/analysis/audit/2026-08-08-validazione-esterna"
del<- as.data.frame(readRDS(file.path(S4,"deliverable-annotato.rds")))
ss <- read.csv(file.path(OUT,"scartati-studi-slot.csv"))

cat("=== IL SOLO GRUPPO CHE AGGANCIA UN'ENTITA' DELLE 214 (livello b) ===\n")
b <- ss[ss$liv=="b_solo_entita",]
print(b[,c("cluster_id","study_id","contrast_entity","stesso_pool","stesso_cens",
           "altrove_pool","altrove_cens")])
tgt <- del[del$contrast_entity=="CHEBI:4167",]
cat("i suoi 2 GSE sono nel pool di", tgt$cluster_id, "?",
    b$study_id %in% unlist(readRDS(file.path(S4,"deliverable-annotato.rds"))$studies_in_cluster[del$contrast_entity=="CHEBI:4167"]), "\n")

cat("\n=== I 206 STUDI-SLOT DEI 137, RIPARTIZIONE FINALE ===\n")
cat("totale studi-slot:", nrow(ss), " GSE distinti:", length(unique(ss$study_id)), "\n")
cat("  gia' poolati in qualcuna delle 214 (altra entita'):", sum(ss$altrove_pool),
    "slot /", length(unique(ss$study_id[ss$altrove_pool])), "GSE\n")
cat("  in nessun pool delle 214:", sum(!ss$altrove_pool),
    "slot /", length(unique(ss$study_id[!ss$altrove_pool])), "GSE\n")
cat("  in nessun pool ne' censimento:", sum(!ss$altrove_pool & !ss$altrove_cens),
    "slot /", length(unique(ss$study_id[!ss$altrove_pool & !ss$altrove_cens])), "GSE\n")
ind <- ss[!ss$altrove_pool,]
cat("  entita' distinte fra gli indipendenti:", length(unique(ind$contrast_entity)),
    " gruppi distinti:", length(unique(ind$cluster_id)), "\n")
cat("  di questi indipendenti, quanti su entita' PRESENTI fra le 214:",
    sum(ind$liv %in% c("a_identico","a_ent_dir","b_solo_entita")), "\n")

cat("\n=== TABELLA DEI FILE ===\n")
for (f in list.files(OUT, pattern="^scartati-.*\\.csv$")) {
  x <- read.csv(file.path(OUT,f)); cat(sprintf("  %-34s %4d righe, %2d col\n", f, nrow(x), ncol(x)))
}
