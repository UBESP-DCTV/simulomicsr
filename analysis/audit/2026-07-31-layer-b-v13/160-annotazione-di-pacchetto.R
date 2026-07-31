#!/usr/bin/env Rscript
# 160-annotazione-di-pacchetto.R --- la funzione di pacchetto riproduce il
# deliverable costruito a mano?
#
# `annotate_stage4_deliverable()` sostituisce la sequenza di script di audit che
# fin qui cuciva insieme etichette, coerenza, efficacia e materiale. Prima di
# metterla nel percorso del re-pool va provato che dia lo STESSO risultato: una
# funzione testata su fixture che diverge sui dati veri e' peggio di nessuna
# funzione, perche' sposta l'errore dove nessuno lo cerca piu'.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/160-annotazione-di-pacchetto.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(cli) })

POOL   <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
V13    <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
DEL    <- "analysis/audit/2026-07-29-etichette-v13"
OUT    <- "analysis/audit/2026-07-31-layer-b-v13"

atteso <- readRDS(file.path(DEL, "deliverable-v13-poolato.rds"))

cp <- arrow::open_dataset(file.path(POOL, "cluster_pooled.parquet")) |>
  dplyr::select(cluster_id, gene_id, k_effective, FDR_BH_within_cluster, I2, tau2) |>
  dplyr::collect()
ps <- arrow::open_dataset(file.path(POOL, "per_study_de.parquet")) |>
  dplyr::select(cluster_id, gene_id, study_id, SE) |> dplyr::collect()
cli_alert_info("poolate {nrow(cp)} righe, per-braccio {nrow(ps)}")

cl <- readRDS(file.path(V13, "clusters.rds"))
meta <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(cl, stage4_default_config()))
meta <- meta[meta$cluster_id %in% unique(cp$cluster_id), ]

# etichette dei membri, per l'asse del materiale
asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% unique(cp$cluster_id), ]
asg$study <- sub("__.*$", "", asg$record_id)
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
need <- unique(asg$record_id)
lab <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
for (study in s2) {
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    rid <- sprintf("%s__%s", study$series_id, cmp$comparison_id)
    if (!rid %in% need) next
    t <- rgl[[cmp$treated_group]]; c <- rgl[[cmp$control_group]]
    if (is.null(t) || is.null(c)) next
    assign(rid, c(lab_of(t, cmp$treated_group), lab_of(c, cmp$control_group)), envir = lab)
  }
}
rm(s2); gc(verbose = FALSE)
righe <- list()
for (i in seq_len(nrow(asg))) {
  e <- get0(asg$record_id[i], envir = lab, inherits = FALSE)
  if (is.null(e)) next
  righe[[length(righe) + 1L]] <- data.frame(
    cluster_id = asg$cluster_id[i], study_id = asg$study[i], label = e,
    stringsAsFactors = FALSE)
}
membri <- do.call(rbind, righe)

v <- utils::read.csv(file.path(DEL, "verdetti-poolato-v13.csv"), stringsAsFactors = FALSE)
meta$ckey <- paste0(meta$contrast_entity, "||", meta$contrast_direction, "||",
                    meta$contrast_control_key)
v_in <- v[v$ckey %in% meta$ckey, ]
cli_alert_info("verdetti che attaccano: {nrow(v_in)} su {nrow(v)}")

t0 <- Sys.time()
d <- annotate_stage4_deliverable(
  cluster_pooled = cp, per_study_de = ps, cluster_meta = meta,
  member_labels = membri, coherence_verdicts = v_in,
  coherence_source = "rilettura-sui-poolati-2026-07-30")
cli_alert_success("annotato in {round(as.numeric(difftime(Sys.time(), t0, units='secs')))}s: {nrow(d)} righe")

# --- confronto con il deliverable costruito a mano --------------------------
cli_h2("Confronto con il deliverable attuale")
if (!setequal(d$cluster_id, atteso$cluster_id)) {
  cli_abort("insiemi di cluster diversi!")
}
a <- atteso[match(d$cluster_id, atteso$cluster_id), ]

confronta <- function(col, tol = 0) {
  if (!col %in% names(d) || !col %in% names(a)) {
    cat(sprintf("  %-26s ASSENTE in uno dei due\n", col)); return(invisible(NULL))
  }
  x <- d[[col]]; y <- a[[col]]
  ug <- if (is.numeric(x) && is.numeric(y)) {
    all(is.na(x) == is.na(y)) && max(abs(x - y), na.rm = TRUE) <= tol
  } else {
    all((is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & as.character(x) == as.character(y)))
  }
  n_div <- if (is.numeric(x) && is.numeric(y)) sum(abs(x - y) > tol, na.rm = TRUE)
           else sum(!((is.na(x) & is.na(y)) | (!is.na(x) & !is.na(y) & as.character(x) == as.character(y))))
  cat(sprintf("  %-26s %s%s\n", col, if (ug) "IDENTICA" else "DIVERSA",
              if (ug) "" else sprintf(" (%d righe)", n_div)))
}

# Tolleranze: il deliverable attuale e' stato scritto ARROTONDANDO (k_kish a due
# decimali, quota_top1 a quattro, frazione_efficace a tre), quindi il confronto
# va fatto alla precisione con cui e' stato salvato. `I2_med` e' un caso a se':
# lo script vecchio calcolava la mediana DENTRO Arrow, che la approssima
# (t-digest); la funzione di pacchetto la calcola esatta in R. Le due
# differiscono fino a 0,93 su 190 righe su 191: **la nuova e' quella giusta**.
tolleranze <- c(k_effective = 0, n_sig = 0, I2_med = 1,
                contrast_entity = 0, contrast_entity_label = 0,
                coherence_verdict = 0, k_kish = 0.005, quota_top1 = 5e-5,
                frazione_efficace = 5e-4, dominato = 0, studio_dominante = 0,
                materiale_misto = 0, n_studi_model = 0, n_studi_primary = 0,
                classe_studio_dominante = 0, dominato_da_modello = 0)
for (col in names(tolleranze)) confronta(col, tol = tolleranze[[col]])

saveRDS(d, file.path(OUT, "deliverable-da-pacchetto.rds"))
cli_alert_success("Scritto deliverable-da-pacchetto.rds")
