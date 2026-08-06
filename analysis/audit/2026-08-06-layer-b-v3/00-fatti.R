#!/usr/bin/env Rscript
# analysis/audit/2026-08-06-layer-b-v3/00-fatti.R
#
# Prepara, per ciascuno dei nove case study del Layer B, UN FILE DI FATTI: i
# numeri letti dal deliverable annotato e dai parquet dello stesso run, piu' le
# etichette INTERE dei confronti effettivamente poolati.
#
# Serve a due cose:
#   (a) il ricercatore che riscrive la narrativa parte da numeri veri invece
#       che dedurli;
#   (b) il verificatore ha una sola fonte da confrontare, con la provenienza
#       accanto a ogni cifra.
#
# ⚠️ ETICHETTE INTERE, MAI TRONCATE (stessa guardia di
# analysis/audit/2026-08-05-rilettura-214/00-materiale.R): lo script misura la
# distribuzione delle lunghezze e segnala i picchi sospetti.
#
# Uso: Rscript analysis/audit/2026-08-06-layer-b-v3/00-fatti.R

suppressPackageStartupMessages({
  library(arrow); library(cli); devtools::load_all(".", quiet = TRUE)
})

POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
S3   <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
BUNDLE <- "analysis/p4-output/20260806T022106Z-layer-b-81f379d3"
OUT  <- "analysis/audit/2026-08-06-layer-b-v3"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

IDS <- c(
  cgroup_L5_930c8dcf = "DHT (5alpha-dihydrotestosterone)",
  cgroup_L5_c0d1d837 = "enzalutamide",
  cgroup_L5_2e16719f = "TGF-beta1",
  cgroup_L5_871ae09e = "SARS-CoV-2",
  cgroup_L5_87c40ebb = "IFN-gamma",
  cgroup_L5_b71a25a2 = "JQ1",
  cgroup_L5_c3ae78cd = "Crohn disease",
  cgroup_L5_85083e38 = "Parkinson disease",
  cgroup_L5_3973fe03 = "IL1A"
)

D <- readRDS(file.path(POOL, "deliverable-annotato.rds"))

# --- per-studio: peso inverso-varianza, come nel modello ----------------------
# Stessa definizione della rilettura 2026-08-05 (§2.5 del finding): mediana di
# 1/SE^2 per studio, normalizzata dentro il cluster.
psd <- as.data.frame(read_parquet(
  file.path(POOL, "per_study_de.parquet"),
  col_select = c("cluster_id", "study_id", "SE")))
psd <- psd[psd$cluster_id %in% names(IDS) & is.finite(psd$SE) & psd$SE > 0, ]
peso_per_studio <- function(cid) {
  x <- psd[psd$cluster_id == cid, ]
  if (nrow(x) == 0L) return(data.frame(study_id = character(0), peso = numeric(0)))
  agg <- stats::aggregate(list(w = 1 / x$SE^2), by = list(study_id = x$study_id),
                          FUN = stats::median, na.rm = TRUE)
  agg$peso <- agg$w / sum(agg$w)
  agg[order(-agg$peso), c("study_id", "peso")]
}

# --- etichette intere dei confronti poolati ----------------------------------
s3  <- load_stage3(S3)
s2  <- simulomicsr:::.load_stage2_master("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl")
s2i <- new.env(hash = TRUE, parent = emptyenv())
for (st in s2) if (!is.null(st$series_id)) assign(st$series_id, st, envir = s2i)
`%||%` <- function(a, b) if (is.null(a) || !length(a) || !nzchar(a)) b else a

studi_poolati <- unique(as.data.frame(read_parquet(
  file.path(POOL, "per_study_de.parquet"), col_select = c("cluster_id", "study_id"))))

etichette_di <- function(cid) {
  asg <- s3$assignments[s3$assignments$cluster_id == cid, ]
  poolati <- studi_poolati$study_id[studi_poolati$cluster_id == cid]
  out <- list()
  for (rid in unique(asg$record_id)) {
    p <- simulomicsr:::.split_record_id(rid)
    if (is.na(p$series_id) || !exists(p$series_id, envir = s2i, inherits = FALSE)) next
    if (!(p$series_id %in% poolati)) next
    st <- get(p$series_id, envir = s2i, inherits = FALSE)
    cmp <- simulomicsr:::.lookup_cmp(st, p$suffix); if (is.null(cmp)) next
    rgl <- stats::setNames(st$replicate_groups,
                           vapply(st$replicate_groups, function(g) g$group_id, character(1)))
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    out[[length(out) + 1L]] <- list(
      studio = p$series_id,
      trattato  = tg$label_human %||% cmp$treated_group,
      controllo = cg$label_human %||% cmp$control_group,
      n_t = length(unlist(tg$sample_ids)), n_c = length(unlist(cg$sample_ids)))
  }
  out
}

# --- bersagli attesi: la STESSA lista del controllo biologico v15 -------------
ATTESI <- list(
  "CHEBI:16330"       = c("KLK3", "TMPRSS2", "FKBP5", "NKX3-1"),
  "CHEBI:68534"       = c("KLK3", "TMPRSS2", "FKBP5", "NKX3-1"),
  "HGNC:11766"        = c("SERPINE1", "CCN2", "SMAD7", "JUNB", "TGFBI", "COL1A1"),
  "NCBITaxon:2697049" = c("IFIT1", "ISG15", "MX1", "OAS1"),
  "HGNC:5438"         = c("STAT1", "GBP1", "CXCL9", "TAP1", "IRF1"),
  "CHEBI:16412"       = c("TNF", "IL6", "IL1B", "CXCL8"),
  "HGNC:5981"         = c("CXCL8", "CCL20", "CXCL1", "LCN2")
)

cp_cols <- c("cluster_id", "gene_symbol", "gene_id", "logFC_pool",
             "FDR_BH_within_cluster", "k_effective", "SE_pool", "I2")
cp <- as.data.frame(read_parquet(file.path(POOL, "cluster_pooled.parquet"),
                                 col_select = all_of(cp_cols)))
cp <- cp[cp$cluster_id %in% names(IDS), ]

conteggio <- jsonlite::fromJSON("analysis/audit/2026-08-05-rilettura-214/13-grandi-conteggio.json",
                                simplifyDataFrame = FALSE)
conteggio <- stats::setNames(conteggio, vapply(conteggio, `[[`, character(1), "cluster_id"))

tutte_lab <- character(0)

for (cid in names(IDS)) {
  r <- D[D$cluster_id == cid, ]
  pw <- peso_per_studio(cid)
  ee <- etichette_di(cid)
  cpc <- cp[cp$cluster_id == cid, ]
  # Il numero di geni TESTATI e' il numero di righe del parquet, cioe' di
  # identificativi Ensembl su cui il test e' stato fatto: si prende PRIMA
  # della dedup per simbolo, altrimenti si riporta come "testati" un numero
  # che nessun test ha prodotto (per DHT 17.733 invece di 19.186).
  n_testati <- nrow(cpc)
  cpc <- cpc[order(cpc$FDR_BH_within_cluster), ]
  # Dedup per simbolo, come fa .rank_and_dedup_genes() per le tabelle del
  # report: nella regione MHC e nelle famiglie paraloghe lo stesso simbolo ha
  # piu' ID Ensembl, e senza dedup lo stesso gene occupa piu' posti (C1R due
  # volte, SLC44A4 tre volte). Si tiene la riga piu' significativa.
  cpc <- cpc[!duplicated(ifelse(is.na(cpc$gene_symbol) | !nzchar(cpc$gene_symbol),
                                cpc$gene_id, cpc$gene_symbol)), ]
  sig <- cpc[!is.na(cpc$FDR_BH_within_cluster) & cpc$FDR_BH_within_cluster < 0.05, ]

  att <- ATTESI[[r$contrast_entity[1L]]]
  att_txt <- if (is.null(att)) {
    "  (nessun bersaglio dichiarato prima del run per questa entita')"
  } else {
    vapply(att, function(g) {
      x <- cpc[!is.na(cpc$gene_symbol) & cpc$gene_symbol == g, ]
      if (nrow(x) == 0L) return(sprintf("  %-10s NON MISURATO", g))
      sprintf("  %-10s logFC=%+.3f  FDR=%.3g  k=%d  I2=%.1f", g,
              x$logFC_pool[1L], x$FDR_BH_within_cluster[1L],
              as.integer(x$k_effective[1L]), x$I2[1L])
    }, character(1))
  }

  top30 <- utils::head(sig[order(-abs(sig$logFC_pool)), ], 30)
  topfdr <- utils::head(sig, 30)

  cnt <- conteggio[[cid]]
  cnt_txt <- if (is.null(cnt)) {
    c("  NON MISURATO: questo gruppo e' fuori dai 13 con k>=15 per cui il conteggio",
      "  confronto-per-confronto e' stato fatto il 2026-08-05. Il conteggio per questo",
      "  gruppo e' oggetto del workflow di questa sessione.")
  } else {
    studi_diff <- sort(unique(vapply(cnt$confronti_difettosi, `[[`, character(1), "studio")))
    peso_diff <- sum(pw$peso[pw$study_id %in% studi_diff])
    c(sprintf("  confronti totali          : %d", cnt$n_confronti_totali),
      sprintf("  confronti difettosi       : %d (%.1f%%)",
              length(cnt$confronti_difettosi),
              100 * length(cnt$confronti_difettosi) / cnt$n_confronti_totali),
      sprintf("  studi con >=1 difetto     : %s", paste(studi_diff, collapse = "; ")),
      sprintf("  peso di quegli studi      : %.1f%%  (mediana 1/SE^2 per studio, normalizzata)",
              100 * peso_diff),
      "  dettaglio dei confronti difettosi:",
      unlist(lapply(cnt$confronti_difettosi, function(x) c(
        sprintf("    [%s] %s  VS  %s", x$studio, x$etichetta_trattato, x$etichetta_controllo),
        sprintf("        meccanismo: %s", x$meccanismo)))))
  }

  righe <- c(
    sprintf("# FATTI VERIFICATI — %s  (%s)", IDS[[cid]], cid),
    "",
    "Tutti i numeri qui sotto sono letti dal deliverable annotato e dai parquet del",
    sprintf("run v15 in %s", POOL),
    "e dallo Stadio 3 in", S3, "",
    "## Riga del deliverable",
    "",
    sprintf("- entita' del contrasto      : %s  (%s)", r$contrast_entity, r$contrast_entity_label),
    sprintf("- verso / tipo di controllo  : %s / %s", r$contrast_direction, r$contrast_control_key),
    sprintf("- studi poolati (k_effective): %d", r$k_effective),
    sprintf("- studi efficaci (Kish)      : %.2f  (%.0f%% del k nominale)",
            r$k_kish, 100 * r$frazione_efficace),
    sprintf("- studio piu' pesante        : %s (%.2f%% del peso)%s",
            r$studio_dominante, 100 * r$quota_top1,
            if (isTRUE(r$dominato)) "  <-- DOMINA il gruppo (>=50%)" else ""),
    sprintf("- geni significativi (FDR<0,05): %d su %d testati (identificativi Ensembl: e' l'unita' del test; i simboli distinti sono %d)",
            r$n_sig, n_testati, nrow(cpc)),
    sprintf("- I2 mediano                 : %.2f%%", r$I2_med),
    sprintf("- verdetto di coerenza       : %s%s", r$coherence_verdict,
            if (!is.na(r$coherence_reason)) paste0("  — ", r$coherence_reason) else ""),
    sprintf("- materiale                  : %s (%d modello in vitro / %d tessuto di paziente / %d non classificato)",
            if (isTRUE(r$materiale_misto)) "MISTO" else "omogeneo",
            r$n_studi_model, r$n_studi_primary, r$n_studi_unknown),
    sprintf("- studi censiti -> poolati   : %d -> %d", r$n_studi_censiti, r$n_studi_poolati),
    "",
    "## Bersagli attesi dalla letteratura, fissati PRIMA del run",
    "  (analysis/audit/2026-08-02-fix/90-controllo-biologico-v15.R)",
    "",
    att_txt,
    "",
    "## I trenta geni piu' significativi (per FDR)",
    "",
    sprintf("  %-12s %9s %12s %5s %7s", "gene", "logFC", "FDR", "k", "I2"),
    sprintf("  %-12s %+9.3f %12.3g %5d %7.1f", topfdr$gene_symbol, topfdr$logFC_pool,
            topfdr$FDR_BH_within_cluster, as.integer(topfdr$k_effective), topfdr$I2),
    "",
    "## I trenta geni con effetto piu' grande (fra i significativi)",
    "",
    sprintf("  %-12s %9s %12s %5s %7s", "gene", "logFC", "FDR", "k", "I2"),
    sprintf("  %-12s %+9.3f %12.3g %5d %7.1f", top30$gene_symbol, top30$logFC_pool,
            top30$FDR_BH_within_cluster, as.integer(top30$k_effective), top30$I2),
    "",
    "## Studi poolati e loro peso (mediana 1/SE^2, normalizzata dentro il gruppo)",
    "",
    sprintf("  %-12s %7.2f%%", pw$study_id, 100 * pw$peso),
    "",
    "## Confronti imperfetti (rilettura 2026-08-05)",
    "",
    cnt_txt,
    "",
    "## Etichette INTERE dei confronti effettivamente poolati",
    "",
    unlist(lapply(ee, function(e) c(
      sprintf("  [%s] n=%d trattati vs %d controlli", e$studio, e$n_t, e$n_c),
      sprintf("      TRATTATO : %s", e$trattato),
      sprintf("      CONTROLLO: %s", e$controllo))))
  )
  for (e in ee) tutte_lab <- c(tutte_lab, e$trattato, e$controllo)

  writeLines(righe, file.path(OUT, sprintf("fatti-%s.txt", sub("^cgroup_L5_", "", cid))))
}

# --- il controllo che lo strumento veda il dato per intero --------------------
n <- nchar(tutte_lab)
cli_h2("Le etichette sono intere?")
cli_alert_info("etichette: {length(n)} | max: {max(n)} | mediana: {stats::median(n)}")
for (s in c(40, 58, 64, 80, 100)) {
  cnt <- sum(n == s)
  cli_alert_info("esattamente {s} caratteri: {cnt}{if (cnt > 5) '  <-- SOSPETTO' else ''}")
}
cli_alert_success("Scritti {length(IDS)} file di fatti in {.path {OUT}}")
