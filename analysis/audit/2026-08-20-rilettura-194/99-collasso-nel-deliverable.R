A3 <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
d <- readRDS(file.path(A3,"deliverable-annotato.rds"))
sospette <- c("STR:ifn","STR:il_1","STR:tgf","STR:tnf","STR:nf_b","STR:17_estradiol","STR:tgf_1")
cat("=== entita' collassate presenti fra le 194? ===\n")
hit <- d[d$contrast_entity %in% sospette, ]
if (nrow(hit)==0) cat("  NESSUNA delle sette forme collassate e' entita' di un gruppo del deliverable.\n")
if (nrow(hit)>0) print(hit[,c("cluster_id","contrast_entity","contrast_entity_label","k_effective")])
cat("\n=== TUTTE le entita' STR: del deliverable (le non risolte a ontologia) ===\n")
s <- d[startsWith(d$contrast_entity,"STR:"), c("contrast_entity","k_effective","cluster_id")]
cat("  gruppi con entita' STR:", nrow(s), "su", nrow(d), "\n")
if (nrow(s)) print(s[order(-s$k_effective),], row.names=FALSE)
