#!/usr/bin/env Rscript
# analysis/audit/2026-08-10-sensitivity/20-peso-contaminato.R
#
# PASSO 1, seconda meta': ricalcolare il PESO CONTAMINATO dei 13 gruppi grandi.
# Il numero pubblicato e' sbagliato per DUE motivi indipendenti, e questo script
# li separa invece di sommarli:
#
#   LA REGOLA. Il peso pubblicato e' «mediana di 1/SE^2 per studio, normalizzata
#   dentro il gruppo» (finding 2026-08-05 §2.5, script 2026-08-06/10-*.R:64-76).
#   Misura i BRACCI, non gli studi: niente collasso inverse-variance, e niente
#   tau^2. Il peso del random-effects e' 1/(SE_studio^2 + tau^2).
#
#   LA LISTA. Gli studi accusati venivano dal censimento, che elencava confronti
#   non presenti nel pooling (10-bracci-poolati.R): 44 accuse su 85 cadono sotto
#   `n_min`, e per due gruppi interi NESSUNA accusa e' dentro il deliverable.
#
# Le quattro celle: {regola vecchia, regola di pacchetto} x {lista vecchia,
# lista corretta}. La cella (vecchia, vecchia) e' il CASO DI ACCETTAZIONE: deve
# riprodurre il numero pubblicato, altrimenti non ho capito la regola che sto
# correggendo.
#
# Uso: Rscript analysis/audit/2026-08-10-sensitivity/20-peso-contaminato.R
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(arrow); library(cli); devtools::load_all(".", quiet = TRUE)
})

POOL   <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
OUT    <- "analysis/audit/2026-08-10-sensitivity"
GRANDI <- "analysis/audit/2026-08-05-rilettura-214/13-grandi-conteggio.json"
PUBBL  <- "analysis/audit/2026-08-06-layer-b-v3/confronti-imperfetti-conteggio.json"

acc_rows <- utils::read.csv(file.path(OUT, "10-accuse-sui-bracci.csv"), stringsAsFactors = FALSE)
g13 <- jsonlite::fromJSON(GRANDI, simplifyDataFrame = FALSE)
ids <- vapply(g13, `[[`, character(1), "cluster_id")

# --- le due liste di studi accusati -------------------------------------------
lista_vecchia <- do.call(rbind.data.frame, c(lapply(g13, function(x) {
  s <- sort(unique(vapply(x$confronti_difettosi, `[[`, character(1), "studio")))
  if (!length(s)) return(NULL)
  data.frame(cluster_id = x$cluster_id, study_id = s, stringsAsFactors = FALSE)
}), list(stringsAsFactors = FALSE)))

dentro <- acc_rows[acc_rows$stato == "dentro il pooling", c("cluster_id", "study_id")]
lista_corretta <- unique(dentro)

cli_alert_info("studi accusati — lista vecchia (censimento): {nrow(lista_vecchia)} coppie (cluster, studio)")
cli_alert_info("studi accusati — lista corretta (accusa DENTRO il pooling): {nrow(lista_corretta)}")

# --- dati ---------------------------------------------------------------------
psd <- as.data.frame(read_parquet(file.path(POOL, "per_study_de.parquet"),
  col_select = c("cluster_id", "study_id", "gene_id", "SE")))
psd <- psd[psd$cluster_id %in% ids & is.finite(psd$SE) & psd$SE > 0, ]
cli_alert_info("per_study_de sui 13 gruppi: {nrow(psd)} righe")

pooled <- as.data.frame(read_parquet(file.path(POOL, "cluster_pooled.parquet"),
  col_select = c("cluster_id", "gene_id", "tau2", "FDR_BH_within_cluster")))
pooled <- pooled[pooled$cluster_id %in% ids, ]
sig <- pooled[!is.na(pooled$FDR_BH_within_cluster) & pooled$FDR_BH_within_cluster < 0.05, ]
cli_alert_info("geni nel poolato: {nrow(pooled)} | significativi (FDR<0,05): {nrow(sig)}")

# --- regola VECCHIA: mediana di 1/SE^2 sui bracci, senza collasso, senza tau2 --
peso_vecchia <- function(cid, studi) {
  x <- psd[psd$cluster_id == cid, ]
  if (nrow(x) == 0L) return(NA_real_)
  agg <- stats::aggregate(list(w = 1 / x$SE^2), by = list(study_id = x$study_id),
                          FUN = stats::median, na.rm = TRUE)
  agg$peso <- agg$w / sum(agg$w)
  if (!length(studi)) return(0)
  sum(agg$peso[agg$study_id %in% studi])
}

# --- regola di PACCHETTO: collasso per studio + tau^2, sui geni significativi --
peso_pacchetto <- function(lista) {
  compute_pooling_weight_shares(
    per_arm = psd[, c("cluster_id", "gene_id", "study_id", "SE")],
    tau2    = sig[, c("cluster_id", "gene_id", "tau2")],
    studi   = lista)
}

pv_vv <- vapply(ids, function(c) peso_vecchia(c, lista_vecchia$study_id[lista_vecchia$cluster_id == c]), numeric(1))
pv_vc <- vapply(ids, function(c) peso_vecchia(c, lista_corretta$study_id[lista_corretta$cluster_id == c]), numeric(1))
pp_v  <- peso_pacchetto(lista_vecchia)
pp_c  <- peso_pacchetto(lista_corretta)

# --- CASO DI ACCETTAZIONE: (regola vecchia, lista vecchia) == pubblicato -------
cli_h2("Caso di accettazione — riprodurre il numero pubblicato")
pub <- jsonlite::fromJSON(PUBBL, simplifyDataFrame = FALSE)
pub_peso <- setNames(vapply(pub, function(x) as.numeric(x$peso), numeric(1)),
                     vapply(pub, `[[`, character(1), "cluster_id"))
com <- intersect(ids, names(pub_peso))
scarto <- abs(pv_vv[com] - pub_peso[com])
cli_alert_info("gruppi confrontabili: {length(com)} | scarto massimo: {format(max(scarto), digits=3)}")
if (max(scarto) > 1e-6) {
  print(data.frame(cluster_id = com, mio = pv_vv[com], pubblicato = pub_peso[com]))
  cli_abort("Non riproduco il numero pubblicato: la regola vecchia non e' quella che credo.")
}
cli_alert_success("PASSA: la regola vecchia e' riprodotta esattamente (scarto < 1e-6)")

# --- tabella ------------------------------------------------------------------
deliv <- readRDS(file.path(POOL, "deliverable-annotato.rds"))
T <- data.frame(
  cluster_id = ids,
  entita = deliv$contrast_entity_label[match(ids, deliv$cluster_id)],
  k = deliv$k_effective[match(ids, deliv$cluster_id)],
  studi_vecchi = vapply(ids, function(c) sum(lista_vecchia$cluster_id == c), integer(1)),
  studi_corretti = vapply(ids, function(c) sum(lista_corretta$cluster_id == c), integer(1)),
  peso_pubblicato = 100 * pv_vv,
  peso_regola_nuova_lista_vecchia = 100 * pp_v$quota_mediana[match(ids, pp_v$cluster_id)],
  peso_regola_vecchia_lista_nuova = 100 * pv_vc,
  peso_CORRETTO = 100 * pp_c$quota_mediana[match(ids, pp_c$cluster_id)],
  stringsAsFactors = FALSE)
T <- T[order(-T$k), ]

cli_h2("Peso contaminato: che cosa cambia, e per colpa di che cosa")
print(T, row.names = FALSE, digits = 3)

cli_h2("Mediane sui 13 gruppi")
cli_alert_info("pubblicato .......................... {sprintf('%.1f%%', median(T$peso_pubblicato))}")
cli_alert_info("solo regola corretta ................ {sprintf('%.1f%%', median(T$peso_regola_nuova_lista_vecchia))}")
cli_alert_info("solo lista corretta ................. {sprintf('%.1f%%', median(T$peso_regola_vecchia_lista_nuova))}")
cli_alert_info("CORRETTO (regola + lista) ........... {sprintf('%.1f%%', median(T$peso_CORRETTO))}")
cli_alert_info("gruppi con peso contaminato NULLO: {sum(T$peso_CORRETTO == 0)} ({paste(T$entita[T$peso_CORRETTO == 0], collapse=', ')})")

utils::write.csv(T, file.path(OUT, "20-peso-contaminato.csv"), row.names = FALSE)
cli_alert_success("scritto 20-peso-contaminato.csv")
