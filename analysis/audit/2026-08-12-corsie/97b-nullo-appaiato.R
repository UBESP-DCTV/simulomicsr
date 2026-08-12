# FASE 5b — IL CONTROLLO NEGATIVO: togliere UNO STUDIO SPOSTA SEMPRE.
#
# La sessione del 2026-08-10 ha stabilito che una misura di influenza senza un
# nullo appaiato non dice nulla: qualunque rimozione muove una meta-analisi, e
# tanto piu' quanto il gruppo e' piccolo. Qui, per ognuno dei 6 gruppi in cui
# GSE173902 cade, si toglie a turno OGNI ALTRO studio e si guarda dove si
# colloca la rimozione di GSE173902 nella distribuzione delle altre.
#
# Limite dichiarato in partenza: con k = 3 o 4 le "altre rimozioni" sono 2 o 3,
# e un percentile su 3 valori non e' una statistica. Serve a vedere se
# GSE173902 e' il piu' influente, non a dare un p.
#
# I pooling sono indipendenti e si parallelizzano. REML non usa numeri casuali e
# l'ordine di mclapply e' deterministico: il risultato non dipende dal numero di
# worker. CONTROLLO: la prima esecuzione, seriale, dava sul gruppo di
# S. epidermidis 0,102 (GSE173902) / 0,637 (GSE188576) / 0,416 (GSE237052);
# devono ricomparire identici qui sotto.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-12-corsie"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
R   <- readRDS(file.path(SC, "30-entry-annotate.rds")); R <- R[R$esito == "ammessa", ]
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
cid <- unique(R$cluster_id[R$cade])
cat("gruppi in cui GSE173902 cade:", length(cid), "\n")

psd <- arrow::read_parquet(file.path(DEL, "per_study_de.parquet"))
psd <- psd[psd$cluster_id %in% cid, ]

lavori <- do.call(rbind, lapply(cid, function(cc) {
  data.frame(cluster_id = cc,
             tolto = sort(unique(psd$study_id[psd$cluster_id == cc])),
             stringsAsFactors = FALSE)
}))
cat("pooling da fare:", nrow(lavori), "\n")

pieni <- lapply(cid, function(cc) {
  p <- pool_cluster_leaving_out(psd[psd$cluster_id == cc, ], character(0))
  list(pieno = p, sig = p$gene_id[!is.na(p$FDR_BH_within_cluster) &
                                    p$FDR_BH_within_cluster < 0.05])
})
names(pieni) <- cid
cat("pooling pieni fatti:", format(Sys.time(), "%H:%M:%S"), "\n")

res <- parallel::mclapply(seq_len(nrow(lavori)), function(i) {
  cc <- lavori$cluster_id[i]; s <- lavori$tolto[i]
  d <- psd[psd$cluster_id == cc, ]
  rid <- pool_cluster_leaving_out(d, s)
  inf <- compute_pooling_influence(pieni[[cc]]$pieno, rid, pieni[[cc]]$sig)
  data.frame(cluster_id = cc, tolto = s, accusato = identical(s, "GSE173902"),
             k = length(unique(d$study_id)), n_sig_pieno = length(pieni[[cc]]$sig),
             spearman = inf$spearman, n_sig_persi = inf$n_sig_persi,
             frazione_persa = inf$n_sig_persi / max(1L, length(pieni[[cc]]$sig)),
             stringsAsFactors = FALSE)
}, mc.cores = 14L)
male <- vapply(res, function(z) !is.data.frame(z), logical(1))
if (any(male)) stop("pooling falliti: ", sum(male))
cat("pooling ridotti fatti:", format(Sys.time(), "%H:%M:%S"), "\n")

E <- merge(do.call(rbind, res), del[, c("cluster_id", "contrast_entity_label")],
           by = "cluster_id")
cat("\n=== DOVE SI COLLOCA GSE173902 FRA LE RIMOZIONI DELLO STESSO GRUPPO ===\n")
for (cc in cid) {
  z <- E[E$cluster_id == cc, ]
  a <- z[z$accusato, ]; b <- z[!z$accusato, ]
  cat(sprintf("%-28s k=%2d | GSE173902: spearman %6.3f persi %3.0f%% | altri: spearman %s | persi %s | e' il piu' influente: %s\n",
      substr(z$contrast_entity_label[1], 1, 26), z$k[1], a$spearman,
      100 * a$frazione_persa,
      paste(sprintf("%.2f", b$spearman), collapse = "/"),
      paste(sprintf("%.0f%%", 100 * b$frazione_persa), collapse = "/"),
      if (a$frazione_persa >= max(b$frazione_persa)) "SI" else "NO"))
}
write.csv(E, file.path(SC, "97b-nullo-appaiato.csv"), row.names = FALSE)
cat("\nscritto.\n")
