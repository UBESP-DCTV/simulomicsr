#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/B2-influenza-loo.R
#
# QUANTO SI SPOSTA UNA META-ANALISI SE SI TOLGONO GLI STUDI ACCUSATI.
#
# Tre misure per ogni gruppo (una sola non basta: sullo stesso gruppo si vedono
# Spearman 0,99 e scarti di 2-3 unita' di logFC sui primi geni):
#   - Spearman del ranking dei geni  -> cambiano QUALI geni si mostrano?
#   - geni significativi persi/vinti -> cambia QUANTO risultato c'e'?
#   - max |delta logFC| fra i primi 30 -> cambia la GRANDEZZA di un effetto?
#
# Lo strumento e' di pacchetto (`pool_cluster_leaving_out`), e non serve un
# re-pool: la catena e' collasso dei bracci per studio + `.pool_rem_cluster`.
#
# PROVA DI ACCETTAZIONE, dentro lo script: per ogni gruppo il ri-pooling PIENO
# deve riprodurre `cluster_pooled.parquet` del deliverable. Se non lo riproduce,
# la misura della rimozione non vuol dire niente e lo script si ferma.
#
# ⚠️ CHE COSA QUESTO NON MISURA (dichiarato prima di misurare). Una leave-one-out
# trova gli studi DISCORDANTI. I difetti censiti — secondo agente, materiale
# diverso, passaggio, donatore — producono in larga parte uno studio che misura
# comunque il contrasto voluto, con un bias plausibilmente CONCORDE. Un bias
# concorde e' invisibile a questo disegno. «Influenza piccola» NON assolve il
# difetto.
#
# Uso: WORKERS=16 Rscript analysis/audit/2026-08-20-rilettura-194/B2-influenza-loo.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(arrow); library(cli); library(parallel); devtools::load_all(".", quiet = TRUE)
})
OUT     <- "analysis/audit/2026-08-20-rilettura-194"
POOL    <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
WORKERS <- as.integer(Sys.getenv("WORKERS", "16"))

d   <- readRDS(file.path(POOL, "deliverable-annotato.rds"))
dif <- utils::read.csv(file.path(OUT, "difetti.csv"), stringsAsFactors = FALSE)
acc <- unique(dif[, c("cluster_id", "study_id")])
cid_acc <- sort(unique(acc$cluster_id))
cli_alert_info("gruppi con almeno un'accusa: {length(cid_acc)} | studi accusati: {nrow(acc)}")

cli_alert_info("leggo per_study_de dei gruppi accusati...")
psd <- as.data.frame(read_parquet(file.path(POOL, "per_study_de.parquet")))
psd <- psd[psd$cluster_id %in% cid_acc, ]
cli_alert_info("righe per-braccio: {nrow(psd)}")
cli_alert_info("leggo cluster_pooled (per la prova di accettazione)...")
cp <- as.data.frame(read_parquet(file.path(POOL, "cluster_pooled.parquet")))
cp <- cp[cp$cluster_id %in% cid_acc, ]

psd_by <- split(psd, psd$cluster_id); rm(psd)
cp_by  <- split(cp,  cp$cluster_id);  rm(cp); invisible(gc(FALSE))

nome <- function(cid) {
  i <- match(cid, d$cluster_id)
  n <- d$contrast_entity_label[i]
  if (is.na(n) || !nzchar(n)) d$contrast_entity[i] else n
}

una <- function(cid) {
  x  <- psd_by[[cid]]
  vero <- cp_by[[cid]]
  studi <- acc$study_id[acc$cluster_id == cid]
  studi <- intersect(studi, unique(x$study_id))

  pieno <- tryCatch(pool_cluster_leaving_out(x), error = function(e) NULL)
  if (is.null(pieno) || nrow(pieno) == 0L)
    return(data.frame(cluster_id = cid, esito = "ri-pooling pieno fallito", stringsAsFactors = FALSE))

  # --- PROVA DI ACCETTAZIONE: il pieno riproduce il deliverable? --------------
  m <- merge(pieno[, c("gene_id", "logFC_pool", "SE_pool", "p_value_pool", "tau2", "I2", "k_effective")],
             vero[, c("gene_id", "logFC_pool", "SE_pool", "p_value_pool", "tau2", "I2", "k_effective")],
             by = "gene_id", suffixes = c("_mio", "_vero"))
  sc <- c(logFC = max(abs(m$logFC_pool_mio - m$logFC_pool_vero), na.rm = TRUE),
          SE    = max(abs(m$SE_pool_mio - m$SE_pool_vero), na.rm = TRUE),
          p     = max(abs(m$p_value_pool_mio - m$p_value_pool_vero), na.rm = TRUE),
          tau2  = max(abs(m$tau2_mio - m$tau2_vero), na.rm = TRUE),
          I2    = max(abs(m$I2_mio - m$I2_vero), na.rm = TRUE),
          k     = max(abs(m$k_effective_mio - m$k_effective_vero), na.rm = TRUE))
  scarto_max <- max(sc, na.rm = TRUE)

  if (!length(studi))
    return(data.frame(cluster_id = cid, esito = "nessuno studio accusato nel pooling",
                      scarto_accettazione = scarto_max, n_geni_confronto = nrow(m),
                      stringsAsFactors = FALSE))

  geni <- pieno$gene_id[!is.na(pieno$FDR_BH_within_cluster) &
                          pieno$FDR_BH_within_cluster < 0.05]
  ridotto <- tryCatch(pool_cluster_leaving_out(x, studi_esclusi = studi), error = function(e) NULL)
  if (is.null(ridotto))
    return(data.frame(cluster_id = cid, esito = "ri-pooling ridotto fallito",
                      scarto_accettazione = scarto_max, stringsAsFactors = FALSE))

  inf <- compute_pooling_influence(pieno, ridotto, geni)
  cbind(data.frame(cluster_id = cid, esito = "ok", scarto_accettazione = scarto_max,
                   n_geni_confronto = nrow(m), n_studi_tolti = length(studi),
                   stringsAsFactors = FALSE), inf)
}

cli_alert_info("giro {length(cid_acc)} gruppi su {WORKERS} worker...")
t0 <- Sys.time()
res <- mclapply(cid_acc, function(c) tryCatch(una(c), error = function(e)
  data.frame(cluster_id = c, esito = paste("errore:", conditionMessage(e)), stringsAsFactors = FALSE)),
  mc.cores = WORKERS)
R <- do.call(rbind, lapply(res, function(x) {
  cols <- c("cluster_id","esito","scarto_accettazione","n_geni_confronto","n_studi_tolti",
            "n_geni_richiesti","n_geni_confrontati","n_geni_spariti","spearman",
            "n_sig_pieno","n_sig_ridotto","n_sig_persi","n_sig_guadagnati",
            "max_abs_delta_logFC","gene_max_delta","k_pieno","k_ridotto")
  for (cc in setdiff(cols, names(x))) x[[cc]] <- NA
  x[, cols]
}))
cli_alert_success("fatto in {round(as.numeric(difftime(Sys.time(), t0, units='mins')),1)} min")

# --- LA PROVA DI ACCETTAZIONE, sul totale ------------------------------------
cli_h1("PROVA DI ACCETTAZIONE: il ri-pooling pieno riproduce il deliverable?")
s <- R$scarto_accettazione[is.finite(R$scarto_accettazione)]
cli_alert_info("gruppi verificati: {length(s)} | scarto massimo su tutti: {format(max(s), scientific = TRUE, digits = 3)}")
if (max(s) > 1e-6) {
  print(R[order(-R$scarto_accettazione), c("cluster_id","scarto_accettazione")][1:10, ])
  cli_abort("PROVA FALLITA: il ri-pooling non riproduce cluster_pooled. La misura non vale.")
}
cli_alert_success("PROVA superata: scarto <= 1e-6 su tutti i gruppi.")

R$entita <- vapply(R$cluster_id, nome, character(1))
R$k      <- d$k_effective[match(R$cluster_id, d$cluster_id)]
R$pct_sig_persi <- 100 * R$n_sig_persi / pmax(1L, R$n_sig_pieno)

ok <- R[R$esito == "ok", ]
cli_h1("Quanto si sposta il risultato togliendo gli accusati")
cli_alert_info("gruppi misurati: {nrow(ok)}")
cli_alert_info("  Spearman: mediana {sprintf('%.3f', stats::median(ok$spearman, na.rm=TRUE))} | minimo {sprintf('%.3f', min(ok$spearman, na.rm=TRUE))}")
cli_alert_info("  geni significativi persi: mediana {sprintf('%.1f%%', stats::median(ok$pct_sig_persi, na.rm=TRUE))} | massimo {sprintf('%.1f%%', max(ok$pct_sig_persi, na.rm=TRUE))}")
cli_alert_info("  max |delta logFC| fra i primi 30: mediana {sprintf('%.3f', stats::median(ok$max_abs_delta_logFC, na.rm=TRUE))}")
cli_alert_info("  gruppi che perdono piu' della meta' dei geni significativi: {sum(ok$pct_sig_persi > 50, na.rm=TRUE)}")
cli_alert_info("  gruppi che scendono sotto k=3 togliendo gli accusati: {sum(ok$k_ridotto < 3, na.rm=TRUE)}")

cli_h2("I quindici gruppi piu' spostati (per geni significativi persi)")
print(utils::head(ok[order(-ok$pct_sig_persi),
  c("entita","k","n_studi_tolti","spearman","n_sig_pieno","n_sig_persi","pct_sig_persi","max_abs_delta_logFC")], 15),
  row.names = FALSE, digits = 3)

utils::write.csv(R, file.path(OUT, "B2-influenza-loo.csv"), row.names = FALSE)
cli_alert_success("Scritto B2-influenza-loo.csv")
