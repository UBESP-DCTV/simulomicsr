#!/usr/bin/env Rscript
# 140-verifica-filtro.R --- il filtro di copertura ha davvero cambiato le figure?
#
# Un fix che passa i test ma non si vede nell'artefatto non e' un fix. Qui si
# confrontano le tabelle dei top geni PRODOTTE prima e dopo, sui cluster che
# compaiono in entrambi i build, e si misura la sola cosa che conta: il k dei
# geni mostrati, e quanti di quei geni sono a conteggio quasi tutto zero.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/140-verifica-filtro.R <dir_nuova>

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(cli) })

args <- commandArgs(trailingOnly = TRUE)
NUOVA  <- if (length(args) >= 1L) args[1L] else stop("serve la dir del build nuovo")
VECCHIA <- "analysis/p4-output/20260730T160606Z-layer-b-c279e308"
OUT <- "analysis/audit/2026-07-31-layer-b-v13"

d <- readRDS("analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds")

cid_n <- basename(list.dirs(NUOVA, recursive = FALSE))
cid_v <- basename(list.dirs(VECCHIA, recursive = FALSE))
comuni <- intersect(cid_n, cid_v)
cli_alert_info("cluster in entrambi i build: {length(comuni)}")

leggi <- function(dir, cid) {
  p <- file.path(dir, cid, "top_genes.csv")
  if (!file.exists(p)) return(NULL)
  utils::read.csv(p, stringsAsFactors = FALSE)
}

righe <- list()
for (cid in comuni) {
  v <- leggi(VECCHIA, cid); n <- leggi(NUOVA, cid)
  if (is.null(v) || is.null(n)) next
  k_cluster <- d$k_effective[match(cid, d$cluster_id)]
  lab <- d$contrast_entity_label[match(cid, d$cluster_id)]
  righe[[length(righe) + 1L]] <- data.frame(
    cluster_id = cid, etichetta = lab, k_cluster = k_cluster,
    n_geni_prima = nrow(v), n_geni_dopo = nrow(n),
    k_mediano_prima = stats::median(v$k_effective),
    k_mediano_dopo  = stats::median(n$k_effective),
    k_min_prima = min(v$k_effective), k_min_dopo = min(n$k_effective),
    sotto_meta_prima = sum(v$k_effective < 0.5 * k_cluster),
    sotto_meta_dopo  = sum(n$k_effective < 0.5 * k_cluster),
    geni_cambiati = length(setdiff(n$gene_id, v$gene_id)),
    stringsAsFactors = FALSE)
}
tab <- do.call(rbind, righe)

cli_h2("Tabella dei top geni: prima e dopo il filtro")
for (i in seq_len(nrow(tab))) {
  cat(sprintf("  %-30s k=%2d | k mediano %4.1f -> %4.1f | k minimo %2d -> %2d | sotto meta' %2d -> %2d | %2d geni nuovi\n",
              substr(tab$etichetta[i], 1, 30), tab$k_cluster[i],
              tab$k_mediano_prima[i], tab$k_mediano_dopo[i],
              tab$k_min_prima[i], tab$k_min_dopo[i],
              tab$sotto_meta_prima[i], tab$sotto_meta_dopo[i],
              tab$geni_cambiati[i]))
}
cat(sprintf("\n  geni sotto meta' del k: %d -> %d in totale\n",
            sum(tab$sotto_meta_prima), sum(tab$sotto_meta_dopo)))

# --- la caption dichiara il filtro? ----------------------------------------
cli_h2("La caption dichiara il taglio? (nessun taglio silenzioso)")
n_dichiara <- 0L
for (cid in cid_n) {
  p <- file.path(NUOVA, cid, "captions.json")
  if (!file.exists(p)) next
  txt <- paste(readLines(p, warn = FALSE), collapse = " ")
  if (grepl("fewer than", txt, fixed = TRUE) || grepl("not applied", txt, fixed = TRUE)) {
    n_dichiara <- n_dichiara + 1L
  }
}
cat(sprintf("  bundle con la nota del filtro nelle caption: %d su %d\n",
            n_dichiara, length(cid_n)))

# --- quanti dei geni mostrati sono quasi tutti zero? ------------------------
# Si rileggono i conteggi veri per i quattro cluster gia' misurati il 2026-07-31,
# cosi' il confronto e' con un numero pubblicato, non con un'impressione.
STAGE3 <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
H5     <- "analysis/input/human_gene_v2.5.h5"
CIDS <- intersect(c("cgroup_L5_930c8dcf", "cgroup_L5_c0d1d837",
                    "cgroup_L5_87c40ebb", "cgroup_L5_2e16719f"), cid_n)

if (length(CIDS) > 0L) {
  s3 <- load_stage3(STAGE3)
  meta <- s3$clusters[s3$clusters$cluster_id %in% CIDS, ]
  meta$method <- "rem_group"
  s2 <- simulomicsr:::.load_stage2_master(STAGE2)
  disp <- simulomicsr:::.build_group_rem_dispatch_from_stage3(
    meta, s3$assignments, s2, n_min = 2L)
  rm(s2); gc(verbose = FALSE)
  fetch <- function(g, s) simulomicsr:::.fetch_counts_cached(g, s, h5_path = H5)

  cli_h2("Geni mostrati con oltre meta' dei campioni a conteggio zero")
  vecchio <- utils::read.csv(file.path(OUT, "heatmap-verifica.csv"), stringsAsFactors = FALSE)
  for (cid in CIDS) {
    top <- leggi(NUOVA, cid)
    campioni <- do.call(rbind, lapply(disp[[cid]], function(it) data.frame(
      sample_id = c(it$treated, it$control), study_id = it$study_id,
      treatment = c(rep("treated", length(it$treated)), rep("control", length(it$control))),
      stringsAsFactors = FALSE)))
    campioni <- campioni[!duplicated(campioni$sample_id), ]
    cm <- simulomicsr:::.assemble_cluster_counts(cid, campioni, fetch)
    g <- intersect(top$gene_id, rownames(cm$counts))
    zeri <- vapply(g, function(gg) mean(cm$counts[gg, ] == 0), numeric(1L))
    lab <- d$contrast_entity_label[match(cid, d$cluster_id)]
    prima <- vecchio[grepl(substr(lab, 1, 6), vecchio$cluster, fixed = TRUE), ]
    cat(sprintf("  %-28s DOPO: %2d/%2d geni >50%% zeri, zeri mediani %5.1f%%",
                substr(lab, 1, 28), sum(zeri > 0.5), length(g),
                100 * stats::median(zeri)))
    if (nrow(prima) > 0L) {
      cat(sprintf("   (PRIMA: %d/%d, %.1f%%)",
                  sum(prima$zeri_pct > 50), nrow(prima), stats::median(prima$zeri_pct)))
    }
    cat("\n")
  }
}

utils::write.csv(tab, file.path(OUT, "verifica-filtro.csv"), row.names = FALSE)
cli_alert_success("Scritta verifica-filtro.csv")
