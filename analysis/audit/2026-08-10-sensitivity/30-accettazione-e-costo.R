#!/usr/bin/env Rscript
# analysis/audit/2026-08-10-sensitivity/30-accettazione-e-costo.R
#
# PASSO 3: il caso di accettazione dello strumento LOO sui dati veri, e la misura
# del costo che serve a decidere il budget di calcolo (handout §3: ricetta
# letterale ~34 h, collasso una volta per cluster ~12 h, geni significativi «un
# ordine di grandezza in meno» — quest'ultima mai misurata).
#
# CASO DI ACCETTAZIONE: pool_cluster_leaving_out(psd, nessuna esclusione) deve
# riprodurre cluster_pooled.parquet con scarto ZERO su tutte e otto le quantita'.
# Se non lo fa, la sensitivity analysis misurerebbe un oggetto che il deliverable
# non contiene, e ogni numero a valle sarebbe senza senso.
#
# I cluster di prova sono scelti per coprire i casi che possono rompere la catena:
# un k=3 dove il collasso e' un'operazione vuota, un k=15 con molti studi a piu'
# bracci, e il k=59 che e' la figura 2 del paper.
#
# Uso: Rscript analysis/audit/2026-08-10-sensitivity/30-accettazione-e-costo.R
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(arrow); library(cli); devtools::load_all(".", quiet = TRUE)
})

POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
OUT  <- "analysis/audit/2026-08-10-sensitivity"

PROVA <- c(piccolo = "cgroup_L5_00fd9348",   # k=3, collasso vuoto
           palbociclib = "cgroup_L5_b6b8bc00", # k=15, molti bracci multipli
           TGFB1 = "cgroup_L5_2e16719f")      # k=59, la figura 2

QUANT <- c("logFC_pool", "SE_pool", "p_value_pool", "tau2", "I2", "Q",
           "k_effective", "FDR_BH_within_cluster")

righe <- list()
for (nome in names(PROVA)) {
  cid <- PROVA[[nome]]
  cli_h2(sprintf("%s — %s", nome, cid))

  t0 <- Sys.time()
  psd <- as.data.frame(read_parquet(file.path(POOL, "per_study_de.parquet"))) |>
    subset(cluster_id == cid)
  t_lettura <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  atteso <- as.data.frame(read_parquet(file.path(POOL, "cluster_pooled.parquet"))) |>
    subset(cluster_id == cid)

  n_bracci_multipli <- sum(duplicated(paste(psd$study_id, psd$gene_id, sep = "|")))
  cli_alert_info("per_study_de {nrow(psd)} righe, {length(unique(psd$study_id))} studi, {n_bracci_multipli} coppie studio-gene con piu' di un braccio")

  # --- pooling pieno, geni TUTTI ---------------------------------------------
  t0 <- Sys.time()
  ott <- pool_cluster_leaving_out(psd, character(0), method_label = "rem_group")
  t_pieno <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  j <- match(ott$gene_id, atteso$gene_id)
  cli_alert_info("geni: ricalcolati {nrow(ott)} | nel parquet {nrow(atteso)} | agganciati {sum(!is.na(j))}")
  if (anyNA(j) || nrow(ott) != nrow(atteso)) cli_abort("Insieme di geni diverso: la catena non e' quella della produzione.")

  scarti <- vapply(QUANT, function(q) {
    a <- ott[[q]]; b <- atteso[[q]][j]
    na_a <- is.na(a); na_b <- is.na(b)
    if (!identical(na_a, na_b)) return(NA_real_)   # NA in posizioni diverse = fallimento
    if (all(na_a)) return(0)
    max(abs(a[!na_a] - b[!na_b]))
  }, numeric(1))
  print(data.frame(quantita = QUANT, scarto_massimo = scarti), row.names = FALSE)
  if (anyNA(scarti)) cli_abort("NA in posizioni diverse fra ricalcolo e parquet.")
  if (max(scarti) > 0) cli_abort("Scarto non nullo: {max(scarti)}")
  cli_alert_success("ACCETTAZIONE PASSA: scarto 0 su tutte e otto le quantita'")

  # --- costo: geni tutti contro soli geni significativi ----------------------
  sig <- atteso$gene_id[!is.na(atteso$FDR_BH_within_cluster) &
                          atteso$FDR_BH_within_cluster < 0.05]
  psd_sig <- psd[psd$gene_id %in% sig, ]
  t0 <- Sys.time()
  invisible(pool_cluster_leaving_out(psd_sig, character(0), method_label = "rem_group"))
  t_sig <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

  cli_alert_info("costo di UN pooling: geni tutti {round(t_pieno,1)} s | soli significativi ({length(sig)} geni) {round(t_sig,1)} s")

  righe[[nome]] <- data.frame(
    nome = nome, cluster_id = cid, k = length(unique(psd$study_id)),
    n_geni = nrow(atteso), n_geni_sig = length(sig),
    bracci_multipli = n_bracci_multipli,
    sec_lettura = t_lettura, sec_pooling_tutti = t_pieno, sec_pooling_sig = t_sig,
    stringsAsFactors = FALSE)
  rm(psd, psd_sig, atteso, ott); gc(verbose = FALSE)
}

C <- do.call(rbind, righe)
utils::write.csv(C, file.path(OUT, "30-costo.csv"), row.names = FALSE)

cli_h2("Preventivo per il programma")
# 25 coppie (studio, gruppo) accusate + rimozione in blocco per gruppo + nullo appaiato
acc <- utils::read.csv(file.path(OUT, "10-accuse-sui-bracci.csv"), stringsAsFactors = FALSE)
d <- unique(acc[acc$stato == "dentro il pooling", c("cluster_id", "study_id")])
n_gruppi <- length(unique(d$cluster_id))
n_loo <- nrow(d) + n_gruppi        # una LOO per studio accusato + un blocco per gruppo
for (n_nullo in c(0, 20, 50)) {
  n_tot <- n_loo + n_nullo * n_gruppi
  for (modo in c("sec_pooling_tutti", "sec_pooling_sig")) {
    medio <- mean(C[[modo]])
    cli_alert_info(sprintf("%3d estrazioni nulle -> %4d pooling | %-18s ~ %.1f h",
                           n_nullo, n_tot, modo, n_tot * medio / 3600))
  }
}
cli_alert_success("scritto 30-costo.csv")
