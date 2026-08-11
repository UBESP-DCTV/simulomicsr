#!/usr/bin/env Rscript
# analysis/audit/2026-08-10-sensitivity/40-influenza.R
#
# PASSI 4 e 5 del programma (handout 2026-08-10 §5): quanto gli studi accusati
# spostano il risultato, e se lo spostano piu' di quanto lo sposterebbe togliere
# altrettanti dati a caso.
#
# TRE MISURE per ogni gruppo, mai una sola (§4.3):
#   - Spearman del ranking dei geni      -> cambiano i geni che si mostrano?
#   - geni significativi persi/guadagnati -> cambia la quantita' di risultato?
#   - massimo |delta logFC| fra i primi 30 -> cambia la grandezza di un effetto?
#
# IL NULLO E' APPAIATO SUI DATI RIMOSSI, non sul peso (§4.4). I 5 studi accusati
# di TGF-beta1 portano 16 bracci su 97, contro una mediana di 7 per 5 studi puliti
# estratti a caso: un nullo non appaiato confronterebbe una rimozione grande con
# rimozioni piccole e troverebbe una differenza che e' solo la quantita' di dati.
# Il peso invece NON e' un confondente (Wilcoxon p = 0,478).
#
# ⚠️ Che cosa questo non puo' dire: vedi 00-previsioni.md §0. Un bias CONCORDE e'
# invisibile a una leave-one-out, e gli studi accusati non sono piu' discordanti
# dei puliti (p = 0,168). Un esito «influenza piccola» non assolve i difetti.
#
# Budget di calcolo, da decidere PRIMA (§3):
#   MODO=sig    -> solo i geni significativi nel pooling pieno (default)
#   MODO=tutti  -> tutti i geni del cluster
#   N_NULLO=<n> -> estrazioni del nullo appaiato per gruppo (default 20; 0 = salta)
#
# ⚠️ LA SCELTA DEL MODO NON E' SOLO DI TEMPO: E' DI COSA SI PUO' MISURARE.
# La terza statistica — «quanti geni significativi si perdono» — usa la
# correzione BH, che si calcola sul DENOMINATORE dei geni poolati. Con MODO=sig
# il denominatore e' l'insieme dei geni gia' significativi, dove BH chiama
# significativo quasi tutto: il conteggio esisterebbe ma misurerebbe un'altra
# cosa. Percio' con MODO=sig le colonne dei significativi sono messe a NA, non
# riempite con un numero che sembra una risposta. Spearman e massimo |delta
# logFC| restano validi (il pooling e' per-gene indipendente, e i geni sono gli
# stessi da entrambe le parti).
#
# Uso: MODO=sig N_NULLO=20 Rscript analysis/audit/2026-08-10-sensitivity/40-influenza.R
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(arrow); library(cli); devtools::load_all(".", quiet = TRUE)
})

POOL    <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
OUT     <- "analysis/audit/2026-08-10-sensitivity"
MODO    <- Sys.getenv("MODO", "tutti")
N_NULLO <- as.integer(Sys.getenv("N_NULLO", "20"))
WORKERS <- as.integer(Sys.getenv("WORKERS", "32"))
SOLO    <- Sys.getenv("SOLO", "")   # smoke: un solo cluster_id
SEED    <- 42L
stopifnot(MODO %in% c("sig", "tutti"))
cli_alert_info("MODO = {MODO} | nullo per gruppo = {N_NULLO} | worker = {WORKERS} | seed = {SEED}")

acc <- utils::read.csv(file.path(OUT, "10-accuse-sui-bracci.csv"), stringsAsFactors = FALSE)
R   <- readRDS(file.path(OUT, "10-record-esito.rds"))
deliv <- readRDS(file.path(POOL, "deliverable-annotato.rds"))

dentro <- unique(acc[acc$stato == "dentro il pooling", c("cluster_id", "study_id")])
gruppi <- unique(dentro$cluster_id)
if (nzchar(SOLO)) gruppi <- intersect(gruppi, SOLO)
cli_alert_info("gruppi con almeno uno studio accusato DENTRO il pooling: {length(gruppi)} (studi: {nrow(dentro)})")

# bracci e campioni per (cluster, studio): l'unita' su cui si appaia il nullo
B <- R[R$esito == "braccio", ]
B$campioni <- B$n_t + B$n_c
peso_dati <- stats::aggregate(cbind(bracci = rep(1L, nrow(B)), campioni = B$campioni),
                              by = list(cluster_id = B$cluster_id, study_id = B$study_id),
                              FUN = sum)

pooled_all <- open_dataset(file.path(POOL, "cluster_pooled.parquet"))
psd_all    <- open_dataset(file.path(POOL, "per_study_de.parquet"))

ris <- list(); nullo <- list()
for (cid in gruppi) {
  et <- deliv$contrast_entity_label[match(cid, deliv$cluster_id)]
  cli_h2(sprintf("%s — %s", et, cid))
  t_g <- Sys.time()

  atteso <- as.data.frame(dplyr::filter(pooled_all, cluster_id == cid) |> dplyr::collect())
  geni_fissi <- atteso$gene_id[!is.na(atteso$FDR_BH_within_cluster) &
                                 atteso$FDR_BH_within_cluster < 0.05]
  psd <- as.data.frame(dplyr::filter(psd_all, cluster_id == cid) |> dplyr::collect())
  if (MODO == "sig") psd <- psd[psd$gene_id %in% geni_fissi, ]

  pieno <- pool_cluster_leaving_out(psd, character(0), method_label = "rem_group")
  # controllo anti-stale: il ricalcolo deve coincidere col deliverable sui geni fissi
  j <- match(geni_fissi, pieno$gene_id)
  sc <- max(abs(pieno$logFC_pool[j] - atteso$logFC_pool[match(geni_fissi, atteso$gene_id)]), na.rm = TRUE)
  if (!is.finite(sc) || sc > 1e-9) cli_abort("Il pooling ricalcolato non coincide col deliverable (scarto {sc}).")

  studi <- unique(psd$study_id)
  accusati <- dentro$study_id[dentro$cluster_id == cid]
  puliti <- setdiff(studi, accusati)
  cli_alert_info("k={length(studi)} | accusati {length(accusati)} | geni fissi {length(geni_fissi)} | scarto anti-stale {format(sc, digits=2)}")

  misura <- function(esclusi, tipo, etichetta) {
    inf <- compute_pooling_influence(
      pieno, pool_cluster_leaving_out(psd, esclusi, method_label = "rem_group"),
      geni = geni_fissi, top_n = 30L)
    # Con MODO=sig il denominatore di BH e' l'insieme dei soli geni significativi:
    # il conteggio dei significativi misurerebbe il denominatore, non l'influenza.
    if (MODO == "sig") {
      inf$n_sig_pieno <- NA_integer_; inf$n_sig_ridotto <- NA_integer_
      inf$n_sig_persi <- NA_integer_; inf$n_sig_guadagnati <- NA_integer_
    }
    pd <- peso_dati[peso_dati$cluster_id == cid & peso_dati$study_id %in% esclusi, ]
    cbind(data.frame(cluster_id = cid, entita = et, tipo = tipo, chi = etichetta,
                     modo = MODO, n_studi_tolti = length(esclusi),
                     bracci_tolti = sum(pd$bracci), campioni_tolti = sum(pd$campioni),
                     stringsAsFactors = FALSE), inf)
  }

  # --- i lavori si generano PRIMA e in modo deterministico, poi si distribuiscono.
  # Estrarre a caso dentro i worker renderebbe il nullo irriproducibile: mclapply
  # non condivide lo stato del generatore, e il seme non basterebbe.
  lavori <- list()
  # (a) leave-one-out per ogni studio accusato
  for (s in accusati) lavori[[length(lavori) + 1L]] <- list(e = s, t = "accusato (LOO)", c = s)
  # (b) rimozione in blocco = caso peggiore
  if (length(accusati) > 1L)
    lavori[[length(lavori) + 1L]] <- list(e = accusati, t = "accusati (blocco)",
                                          c = paste(accusati, collapse = "+"))
  # (c) leave-one-out per ogni studio pulito: il riferimento per-studio con cui
  # gli accusati vanno confrontati (e, appaiato sui bracci, il nullo dei singoli)
  for (s in puliti) lavori[[length(lavori) + 1L]] <- list(e = s, t = "pulito (LOO)", c = s)

  # (d) nullo APPAIATO per il blocco: insiemi di studi puliti che tolgono
  # altrettanti bracci
  if (N_NULLO > 0L && length(puliti) >= 2L) {
    set.seed(SEED)
    bersaglio <- sum(peso_dati$bracci[peso_dati$cluster_id == cid &
                                        peso_dati$study_id %in% accusati])
    bp <- peso_dati[peso_dati$cluster_id == cid & peso_dati$study_id %in% puliti, ]
    fatte <- 0L; tentativi <- 0L
    while (fatte < N_NULLO && tentativi < 400L) {
      tentativi <- tentativi + 1L
      ordine <- sample(nrow(bp))                     # cresce a caso...
      cum <- cumsum(bp$bracci[ordine])
      k <- which(cum >= bersaglio)[1L]               # ...finche' non pareggia i bracci
      if (is.na(k)) k <- length(ordine)              # non ci arriva: prende tutto il pulito
      sel <- bp$study_id[ordine[seq_len(k)]]
      if (length(setdiff(studi, sel)) < 2L) next     # deve restare una meta-analisi
      fatte <- fatte + 1L
      lavori[[length(lavori) + 1L]] <- list(e = sel, t = "nullo appaiato",
                                            c = sprintf("estrazione %d", fatte))
    }
    cli_alert_info("nullo appaiato: {fatte} estrazioni (bersaglio {bersaglio} bracci, {tentativi} tentativi)")
  }

  cli_alert_info("{length(lavori)} pooling su {WORKERS} worker")
  fatti <- parallel::mclapply(lavori, function(L) misura(L$e, L$t, L$c),
                              mc.cores = WORKERS, mc.preschedule = FALSE)
  # mclapply non alza gli errori dei figli: li restituisce come oggetti try-error.
  # Senza questo controllo un worker morto sparirebbe dal risultato in silenzio.
  rotti <- vapply(fatti, function(x) inherits(x, "try-error") || !is.data.frame(x), logical(1))
  if (any(rotti)) cli_abort("{sum(rotti)} pooling su {length(fatti)} falliti nei worker.")
  ris[[length(ris) + 1L]] <- do.call(rbind, fatti)

  cli_alert_success("{et}: {round(as.numeric(difftime(Sys.time(), t_g, units='mins')), 1)} min")
  rm(psd, atteso, pieno, fatti); gc(verbose = FALSE)
}

I <- do.call(rbind, ris)
nome_out <- sprintf("40-influenza-%s%s.csv", MODO, if (nzchar(SOLO)) "-smoke" else "")
utils::write.csv(I, file.path(OUT, nome_out), row.names = FALSE)
cli_alert_success("scritto {nome_out} ({nrow(I)} righe)")

cli_h2("Sintesi per tipo")
print(do.call(rbind, lapply(split(I, I$tipo), function(x) data.frame(
  tipo = x$tipo[1], n = nrow(x),
  spearman_med = round(stats::median(x$spearman, na.rm = TRUE), 4),
  max_dlogFC_med = round(stats::median(x$max_abs_delta_logFC, na.rm = TRUE), 3),
  sig_persi_med = stats::median(x$n_sig_persi, na.rm = TRUE),
  stringsAsFactors = FALSE))), row.names = FALSE)
