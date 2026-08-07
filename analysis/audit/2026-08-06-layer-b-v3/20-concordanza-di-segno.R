#!/usr/bin/env Rscript
# analysis/audit/2026-08-06-layer-b-v3/20-concordanza-di-segno.R
#
# CHIUDE UN DISACCORDO CON UNA MISURA, invece che con un giudizio.
#
# Cinque delle nove narrative si erano fermate sulla stessa domanda: con un I^2
# fra 90 e 99, si puo' dire che «gli studi concordano sul segno dell'effetto»?
# Il contestatore obiettava, giustamente, che l'I^2 misura l'eccesso di varianza
# fra studi e NON la concordanza di direzione, e che il materiale a
# disposizione (deliverable + geni poolati) non contiene i segni per studio.
#
# Ma i segni per studio ci sono: stanno in `per_study_de.parquet`. La domanda
# non e' una questione di opinione, e' una misura mai fatta. Qui si fa.
#
# DEFINIZIONE. Per ogni bersaglio atteso dalla letteratura (la stessa lista
# fissata PRIMA del run in 90-controllo-biologico-v15.R) si contano gli studi
# che riportano quel gene, e fra questi quelli il cui logFC ha lo STESSO segno
# della stima poolata. Si riportano due cifre: la frazione concorde e il numero
# di studi su cui e' calcolata. Nessuna soglia, nessun test: il numero e' il
# risultato.
#
# Uso: Rscript analysis/audit/2026-08-06-layer-b-v3/20-concordanza-di-segno.R

suppressPackageStartupMessages({ library(arrow); library(cli) })

POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
OUT  <- "analysis/audit/2026-08-06-layer-b-v3"

ATTESI <- list(
  cgroup_L5_930c8dcf = c("KLK3", "TMPRSS2", "FKBP5", "NKX3-1"),
  cgroup_L5_c0d1d837 = c("KLK3", "TMPRSS2", "FKBP5", "NKX3-1"),
  cgroup_L5_2e16719f = c("SERPINE1", "CCN2", "SMAD7", "JUNB", "TGFBI", "COL1A1"),
  cgroup_L5_871ae09e = c("IFIT1", "ISG15", "MX1", "OAS1"),
  cgroup_L5_87c40ebb = c("STAT1", "GBP1", "CXCL9", "TAP1", "IRF1")
)

cp <- as.data.frame(read_parquet(
  file.path(POOL, "cluster_pooled.parquet"),
  col_select = c("cluster_id", "gene_id", "gene_symbol", "logFC_pool",
                 "FDR_BH_within_cluster", "k_effective")))
cp <- cp[cp$cluster_id %in% names(ATTESI), ]

psd <- as.data.frame(read_parquet(
  file.path(POOL, "per_study_de.parquet"),
  col_select = c("cluster_id", "study_id", "gene_id", "logFC")))
psd <- psd[psd$cluster_id %in% names(ATTESI), ]

righe <- list()
for (cid in names(ATTESI)) {
  cpc <- cp[cp$cluster_id == cid, ]
  for (g in ATTESI[[cid]]) {
    r <- cpc[!is.na(cpc$gene_symbol) & cpc$gene_symbol == g, ]
    if (nrow(r) == 0L) next
    r <- r[order(r$FDR_BH_within_cluster), ][1L, ]
    x <- psd[psd$cluster_id == cid & psd$gene_id == r$gene_id & is.finite(psd$logFC), ]
    # Un braccio per riga: si collassa per studio prendendo il segno della
    # MEDIANA dei suoi bracci, cosi' uno studio con piu' confronti non conta
    # piu' volte (stessa logica del collasso dei bracci nel pooling).
    if (nrow(x) == 0L) next
    per_studio <- stats::aggregate(list(logFC = x$logFC),
                                   by = list(study_id = x$study_id),
                                   FUN = stats::median, na.rm = TRUE)
    n_studi <- nrow(per_studio)
    n_conc <- sum(sign(per_studio$logFC) == sign(r$logFC_pool))
    righe[[length(righe) + 1L]] <- data.frame(
      cluster_id = cid, gene = g,
      logFC_pool = r$logFC_pool, k_pooled = r$k_effective,
      n_studi_con_il_gene = n_studi, n_concordi = n_conc,
      frazione_concorde = n_conc / n_studi, stringsAsFactors = FALSE)
  }
}
tab <- do.call(rbind, righe)
utils::write.csv(tab, file.path(OUT, "concordanza-di-segno.csv"), row.names = FALSE)

cli_h2("Concordanza di segno per studio, sui bersagli fissati prima del run")
for (cid in unique(tab$cluster_id)) {
  t <- tab[tab$cluster_id == cid, ]
  cli_alert_info("{sub('cgroup_L5_','',cid)}: {sum(t$n_concordi)}/{sum(t$n_studi_con_il_gene)} stime per-studio concordi col segno poolato ({sprintf('%.1f%%', 100*sum(t$n_concordi)/sum(t$n_studi_con_il_gene))})")
  for (i in seq_len(nrow(t))) {
    cli_alert(sprintf("   %-9s logFC %+6.3f  %2d/%2d studi concordi (%.0f%%)",
                      t$gene[i], t$logFC_pool[i], t$n_concordi[i],
                      t$n_studi_con_il_gene[i], 100 * t$frazione_concorde[i]))
  }
}
cli_alert_success("Scritto {.path {file.path(OUT, 'concordanza-di-segno.csv')}}")
