# FASE 4 — L'effetto sulle 214, calcolato dal dispatch (non da un CSV di agente).
SC  <- "analysis/audit/2026-08-12-corsie"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
R   <- readRDS(file.path(SC, "30-entry-annotate.rds"))

# k = numero di STUDI distinti con almeno un'entry (e' cosi' che il ramo rem_group
# collassa i bracci per studio prima del pooling)
k_ora  <- tapply(R$study_id, R$cluster_id, function(z) length(unique(z)))
Rp     <- R[!R$cade, ]
k_dopo <- tapply(Rp$study_id, Rp$cluster_id, function(z) length(unique(z)))

d <- data.frame(cluster_id = names(k_ora), k_ora = as.integer(k_ora),
                stringsAsFactors = FALSE)
d$k_dopo <- as.integer(k_dopo[d$cluster_id]); d$k_dopo[is.na(d$k_dopo)] <- 0L
d <- merge(d, del[, c("cluster_id", "k_effective", "canonical_name", "contrast_entity",
                      "n_sig", "k_kish", "dominato")], by = "cluster_id", all.x = TRUE)

cat("=== ACCETTAZIONE: il k ricalcolato coincide con k_effective del deliverable? ===\n")
cat("  righe:", nrow(d), "| scarto massimo:", max(abs(d$k_ora - d$k_effective)),
    "| righe con scarto != 0:", sum(d$k_ora != d$k_effective), "\n")
if (any(d$k_ora != d$k_effective)) print(d[d$k_ora != d$k_effective, ])

cat("\n=== CHE COSA CAMBIA CON n_min BIOLOGICO ===\n")
ch <- d[d$k_dopo != d$k_ora, ]
ch <- ch[order(ch$k_ora), ]
print(ch[, c("cluster_id", "canonical_name", "contrast_entity", "k_ora", "k_dopo",
             "n_sig", "k_kish", "dominato")], row.names = FALSE)
cat("\nrighe che scendono sotto k>=3 (escono dal deliverable):",
    sum(ch$k_dopo < 3L), "\n")
if (any(ch$k_dopo < 3L)) print(ch[ch$k_dopo < 3L, c("cluster_id","canonical_name","k_ora","k_dopo")],
                               row.names = FALSE)
write.csv(d, file.path(SC, "50-k-prima-dopo.csv"), row.names = FALSE)
saveRDS(d, file.path(SC, "50-k-prima-dopo.rds"))
cat("\nscritto.\n")
