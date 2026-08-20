#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/B3-nulli.R
#
# E' IL DIFETTO, O E' SOLO IL TOGLIERE DATI?
#
# B2 misura quanto si sposta una meta-analisi togliendo gli studi accusati. Da
# sola quella misura non dice nulla: togliere QUALUNQUE studio sposta il
# risultato. La domanda vera e' se gli accusati spostino PIU' di studi puliti
# equivalenti.
#
# Il confronto: per ogni gruppo, la rimozione degli accusati contro N rimozioni
# casuali di studi PULITI dello stesso gruppo. Si riporta il PERCENTILE della
# rimozione accusata fra quelle pulite: 0,50 = indistinguibile, 1,00 = sposta
# piu' di ogni rimozione pulita.
#
# ⚠️ IL DIFETTO DEL NULLO DEL 2026-08-10, che qui si corregge. Quel nullo
# pareggiava i BRACCI ma finiva per togliere 1,35 volte piu' STUDI degli
# accusati (2,3 volte su TGF-beta1): conservativo nella direzione sbagliata, e
# il suo p = 0,765 non provava indistinguibilita'. Qui le estrazioni pulite
# hanno lo STESSO NUMERO DI STUDI degli accusati, e fra le estrazioni possibili
# si scelgono quelle col numero di BRACCI piu' vicino. Lo scarto residuo di
# bracci e' riportato, non nascosto.
#
# La randomizzazione e' con seme fisso per gruppo: due esecuzioni danno gli
# stessi nulli.
#
# Uso: WORKERS=32 N_NULLI=20 Rscript analysis/audit/2026-08-20-rilettura-194/B3-nulli.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(arrow); library(cli); library(parallel); devtools::load_all(".", quiet = TRUE)
})
OUT     <- "analysis/audit/2026-08-20-rilettura-194"
POOL    <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
WORKERS <- as.integer(Sys.getenv("WORKERS", "32"))
N_NULLI <- as.integer(Sys.getenv("N_NULLI", "20"))

d   <- readRDS(file.path(POOL, "deliverable-annotato.rds"))
dif <- utils::read.csv(file.path(OUT, "difetti.csv"), stringsAsFactors = FALSE)
acc <- unique(dif[, c("cluster_id", "study_id")])
cid_acc <- sort(unique(acc$cluster_id))

cli_alert_info("leggo per_study_de dei {length(cid_acc)} gruppi accusati...")
psd <- as.data.frame(read_parquet(file.path(POOL, "per_study_de.parquet")))
psd <- psd[psd$cluster_id %in% cid_acc, ]
psd_by <- split(psd, psd$cluster_id); rm(psd); invisible(gc(FALSE))
cli_alert_info("gruppi in memoria: {length(psd_by)}")

# bracci per studio: una riga del dispatch = un braccio. Qui si contano dalle
# combinazioni distinte (n_treated, n_control) per studio, che e' l'unita' con
# cui il pooling vede i bracci prima del collasso.
bracci_di <- function(x) {
  u <- unique(x[, c("study_id", "n_treated", "n_control")])
  tapply(rep(1L, nrow(u)), u$study_id, sum)
}

nome <- function(cid) {
  i <- match(cid, d$cluster_id)
  n <- d$contrast_entity_label[i]
  if (is.na(n) || !nzchar(n)) d$contrast_entity[i] else n
}

una <- function(cid) {
  x <- psd_by[[cid]]
  tutti  <- unique(x$study_id)
  accusa <- intersect(acc$study_id[acc$cluster_id == cid], tutti)
  puliti <- setdiff(tutti, accusa)
  nb <- bracci_di(x)
  if (!length(accusa) || length(puliti) < length(accusa) + 1L)
    return(data.frame(cluster_id = cid, esito = "nulli non costruibili",
                      n_accusati = length(accusa), n_puliti = length(puliti),
                      stringsAsFactors = FALSE))

  pieno <- pool_cluster_leaving_out(x)
  if (nrow(pieno) == 0L)
    return(data.frame(cluster_id = cid, esito = "pooling pieno vuoto", stringsAsFactors = FALSE))
  geni <- pieno$gene_id[!is.na(pieno$FDR_BH_within_cluster) & pieno$FDR_BH_within_cluster < 0.05]

  misura <- function(studi) {
    r <- tryCatch(pool_cluster_leaving_out(x, studi_esclusi = studi), error = function(e) NULL)
    if (is.null(r) || nrow(r) == 0L) return(NULL)
    compute_pooling_influence(pieno, r, geni)
  }
  vero <- misura(accusa)
  if (is.null(vero))
    return(data.frame(cluster_id = cid, esito = "rimozione accusata non poolabile",
                      stringsAsFactors = FALSE))

  # estrazioni pulite: stesso NUMERO DI STUDI, bracci il piu' vicino possibile
  set.seed(sum(utf8ToInt(cid)))
  target_bracci <- sum(nb[accusa], na.rm = TRUE)
  cand <- replicate(min(400L, 40L * N_NULLI),
                    sample(puliti, length(accusa)), simplify = FALSE)
  cand <- unique(cand)
  dist <- vapply(cand, function(s) abs(sum(nb[s], na.rm = TRUE) - target_bracci), numeric(1))
  cand <- cand[order(dist)][seq_len(min(N_NULLI, length(cand)))]

  nulli <- lapply(cand, misura)
  keep  <- !vapply(nulli, is.null, logical(1))
  nulli <- nulli[keep]; cand <- cand[keep]
  if (length(nulli) < 3L)
    return(data.frame(cluster_id = cid, esito = "troppo pochi nulli riusciti",
                      n_nulli = length(nulli), stringsAsFactors = FALSE))

  # percentile: quanto la rimozione accusata sposta, fra le pulite.
  # Spearman piu' BASSO = piu' spostamento, quindi si inverte il verso.
  pct <- function(v_vero, v_nulli, basso_e_peggio) {
    if (basso_e_peggio) mean(v_nulli >= v_vero) else mean(v_nulli <= v_vero)
  }
  sp_n  <- vapply(nulli, function(z) z$spearman, numeric(1))
  sig_n <- vapply(nulli, function(z) z$n_sig_persi / max(1L, z$n_sig_pieno), numeric(1))
  dl_n  <- vapply(nulli, function(z) z$max_abs_delta_logFC, numeric(1))

  data.frame(
    cluster_id = cid, esito = "ok",
    n_accusati = length(accusa), n_puliti = length(puliti), n_nulli = length(nulli),
    bracci_accusati = target_bracci,
    bracci_nulli_mediana = stats::median(vapply(cand, function(s) sum(nb[s], na.rm = TRUE), numeric(1))),
    spearman_vero = vero$spearman,
    spearman_nulli_mediana = stats::median(sp_n),
    percentile_spearman = pct(vero$spearman, sp_n, TRUE),
    pct_sig_vero = vero$n_sig_persi / max(1L, vero$n_sig_pieno),
    pct_sig_nulli_mediana = stats::median(sig_n),
    percentile_sig = pct(vero$n_sig_persi / max(1L, vero$n_sig_pieno), sig_n, FALSE),
    delta_vero = vero$max_abs_delta_logFC,
    delta_nulli_mediana = stats::median(dl_n),
    percentile_delta = pct(vero$max_abs_delta_logFC, dl_n, FALSE),
    stringsAsFactors = FALSE)
}

cli_alert_info("giro {length(cid_acc)} gruppi x {N_NULLI} nulli su {WORKERS} worker...")
t0 <- Sys.time()
res <- mclapply(cid_acc, function(c) tryCatch(una(c), error = function(e)
  data.frame(cluster_id = c, esito = paste("errore:", conditionMessage(e)), stringsAsFactors = FALSE)),
  mc.cores = WORKERS)
cols <- c("cluster_id","esito","n_accusati","n_puliti","n_nulli","bracci_accusati",
          "bracci_nulli_mediana","spearman_vero","spearman_nulli_mediana","percentile_spearman",
          "pct_sig_vero","pct_sig_nulli_mediana","percentile_sig",
          "delta_vero","delta_nulli_mediana","percentile_delta")
R <- do.call(rbind, lapply(res, function(x) {
  for (cc in setdiff(cols, names(x))) x[[cc]] <- NA
  x[, cols]
}))
cli_alert_success("fatto in {round(as.numeric(difftime(Sys.time(), t0, units='mins')),1)} min")

R$entita <- vapply(R$cluster_id, nome, character(1))
ok <- R[R$esito == "ok", ]

cli_h1("Gli accusati spostano piu' di studi puliti equivalenti?")
cli_alert_info("gruppi con un nullo costruibile: {nrow(ok)} su {nrow(R)}")
cli_alert_info("motivi di esclusione: {paste(names(table(R$esito[R$esito!='ok'])), table(R$esito[R$esito!='ok']), collapse=' | ')}")
if (nrow(ok) > 0) {
  cli_h2("Percentile della rimozione accusata fra le pulite (0,50 = indistinguibile)")
  for (v in c("percentile_spearman", "percentile_sig", "percentile_delta")) {
    p <- ok[[v]]
    w <- suppressWarnings(stats::wilcox.test(p, mu = 0.5))
    cli_alert_info("{v}: mediana {sprintf('%.3f', stats::median(p, na.rm=TRUE))} | sopra 0,90: {sum(p > 0.9, na.rm=TRUE)}/{sum(!is.na(p))} | Wilcoxon p = {sprintf('%.4f', w$p.value)}")
  }
  cli_h2("Il nullo e' appaiato? (bracci tolti: accusati contro nulli)")
  cli_alert_info("rapporto mediano bracci_nulli / bracci_accusati: {sprintf('%.2f', stats::median(ok$bracci_nulli_mediana / pmax(1, ok$bracci_accusati), na.rm=TRUE))}")
  cli_alert_info("(1,00 = appaiato; il nullo del 2026-08-10 stava a 1,35 sugli studi)")

  cli_h2("I quindici gruppi in cui gli accusati spostano di piu' del previsto")
  print(utils::head(ok[order(-ok$percentile_sig),
    c("entita","n_accusati","pct_sig_vero","pct_sig_nulli_mediana","percentile_sig","percentile_spearman")], 15),
    row.names = FALSE, digits = 3)
}

utils::write.csv(R, file.path(OUT, "B3-nulli.csv"), row.names = FALSE)
cli_alert_success("Scritto B3-nulli.csv")
