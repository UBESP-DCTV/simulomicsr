# analysis/p5-stage4-layer-b-build-v13.R
# Layer B sui 191 gruppi poolati del re-pool v13 (ADR-0026, ramo rem_group).
# Copia di p5-stage4-layer-b-build-v10.R con TRE differenze, tutte necessarie e
# tutte verificate prima del lancio (analysis/audit/2026-07-31-layer-b-v13/20-preflight.R):
#
#   1. percorsi Stadio 4 / Stadio 3 su v13;
#   2. `stage3_metadata` costruito dalle colonne del CONTRASTO
#      (contrast_entity / contrast_direction / contrast_control_key) invece che
#      da parse_anchor_key(): i cluster v13 sono `mode="cgroup"` (ADR-0025) e la
#      loro anchor_key ha TRE segmenti (`entita||verso||tipo-di-controllo`), non
#      i 13 dell'anchor canonico v3. extract_anchor_summary() su quella chiave
#      NON crasha ma restituisce NA su tutti i campi: ogni summary card avrebbe
#      mostrato "Anchor: ? x ? (tissue=?)". Misurato, non supposto.
#   3. l'etichetta mostrata viene da `contrast_entity_label` (risolta dall'ID)
#      via il CSV di selezione: `canonical_name` e' sbagliato su decine di
#      gruppi (per CHEBI:16330 dice "4-maleylacetoacetate" invece di DHT) e non
#      va mai usato per un'etichetta di figura.
#
# Il fix rem_group del 2026-07-23 e' gia' nel codice di pacchetto (forest,
# pannello di eterogeneita', summary card) ed e' stato riverificato.
#
# Usage:
#   setsid Rscript analysis/p5-stage4-layer-b-build-v13.R \
#     > analysis/p5-stage4-layer-b-v13.log 2>&1 < /dev/null &
# (NB: NO --vanilla — vedi CLAUDE.md.)

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

suppressPackageStartupMessages({
  devtools::load_all(".")
  library(cli)
})
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L)
  RhpcBLASctl::omp_set_num_threads(1L)
}

cli_h1("Stadio 4 Layer B batch build — v13")

stage4_dir    <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
stage3_dir    <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
stage2_path   <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
# Selezione FINALE (9 case study: 3 main + 6 supplementari), decisa sulle misure
# del 2026-07-31 e non sul k — vedi analysis/audit/2026-07-31-layer-b-v13/120-selection-finale.R.
# La prima selezione esplorativa (12 case study, con i doppioni TGF-beta1/LPS e
# Parkinson/HCC ancora aperti) resta in analysis/layer-b-selection-v13.csv.
selection_csv <- Sys.getenv("LAYER_B_SELECTION",
                            "analysis/layer-b-selection-v13-finale.csv")
h5_path       <- "analysis/input/human_gene_v2.5.h5"

stopifnot(
  dir.exists(stage4_dir),
  dir.exists(stage3_dir),
  file.exists(stage2_path),
  file.exists(selection_csv),
  file.exists(h5_path)
)

# -----------------------------------------------------------------------------
# Pre-validation della selection contro Stage 4
# -----------------------------------------------------------------------------
cli_alert_info("Pre-validation della selection...")
val <- layer_b_validate_selection(selection_csv, stage4_dir)
print(val)
if (any(!val$exists_in_stage4)) {
  cli_abort("Alcuni cluster_id sono assenti dal Layer A — interrompo.")
}

# -----------------------------------------------------------------------------
# Stage 3 metadata (per summary card) + Stage 2 master (per design_role)
# -----------------------------------------------------------------------------
cli_alert_info("Loading Stage 3 metadata + Stage 2 master...")
t_load <- Sys.time()
s3 <- load_stage3(stage3_dir)

# ⚠️ DIFFERENZA 2 (vedi testa del file). Per i cluster `cgroup` l'anchor E' il
# contrasto, e sta in tre colonne dedicate di clusters.rds. Le usiamo cosi'
# come sono: `kind_effective` <- il verso del contrasto, `agent_id` <- l'ID
# dell'entita', `tissue` <- il tipo di controllo. I nomi dei campi restano
# quelli attesi da .build_summary_card (contratto invariato), il CONTENUTO e'
# quello vero di questo ramo. Per i cluster non-cgroup (nessuno, oggi, ma il
# codice non deve mentire se domani ce ne fossero) si ricade sul parsing
# canonico.
is_cgroup <- s3$clusters$mode == "cgroup"
parsed_segs <- Map(
  extract_anchor_summary,
  s3$clusters$anchor_key, s3$clusters$level, s3$clusters$mode
)
stage3_metadata <- tibble::tibble(
  cluster_id     = s3$clusters$cluster_id,
  kind_effective = ifelse(
    is_cgroup,
    paste0("contrast/", s3$clusters$contrast_direction),
    vapply(parsed_segs, function(x) x$kind_effective %||% NA_character_, character(1L))
  ),
  agent_id = ifelse(
    is_cgroup,
    s3$clusters$contrast_entity,
    vapply(parsed_segs, function(x) x$agent_id %||% NA_character_, character(1L))
  ),
  tissue = ifelse(
    is_cgroup,
    paste0("control=", s3$clusters$contrast_control_key),
    vapply(parsed_segs, function(x) x$tissue %||% NA_character_, character(1L))
  ),
  safety_min = s3$clusters$safety_min
)

# Guardia: nessun cluster della selezione deve finire con l'anchor a NA — e'
# esattamente il fallimento silenzioso che questo file esiste per impedire.
sel_ids <- simulomicsr:::.load_layer_b_selection(selection_csv)$cluster_id
s3_sel <- stage3_metadata[stage3_metadata$cluster_id %in% sel_ids, ]
if (nrow(s3_sel) != length(sel_ids) || anyNA(s3_sel$agent_id)) {
  cli_abort(paste0(
    "stage3_metadata incompleto per la selezione: righe=", nrow(s3_sel),
    "/", length(sel_ids), ", agent_id NA=", sum(is.na(s3_sel$agent_id))))
}
cli_alert_success("stage3_metadata: anchor risolto su tutti e {nrow(s3_sel)} i cluster selezionati.")

stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
assignments <- s3$assignments
cli_alert_success(sprintf(
  "Loaded in %.1fs (clusters=%d, assignments=%d, stage2_master=%d).",
  as.numeric(difftime(Sys.time(), t_load, units = "secs")),
  nrow(s3$clusters), nrow(assignments), nrow(stage2_master)
))

# -----------------------------------------------------------------------------
# Counts cache (riusata dal Layer A)
# -----------------------------------------------------------------------------
counts_cache_dir <- file.path(
  tools::R_user_dir("simulomicsr", "cache"), "stage4-counts"
)
if (!dir.exists(counts_cache_dir)) {
  cli_abort("Stage 4 counts cache mancante: {.path {counts_cache_dir}}")
}

# -----------------------------------------------------------------------------
# per_cluster_samples_provider
# -----------------------------------------------------------------------------
cli_alert_info("Building study/group dispatch per la selection...")
selection_csv_loaded <- simulomicsr:::.load_layer_b_selection(selection_csv)
selected_cluster_meta <- s3$clusters[
  s3$clusters$cluster_id %in% selection_csv_loaded$cluster_id, ]
cp_sub_meta <- arrow::open_dataset(file.path(stage4_dir, "cluster_pooled.parquet")) |>
  dplyr::filter(cluster_id %in% selection_csv_loaded$cluster_id) |>
  dplyr::select(cluster_id, method) |>
  dplyr::collect() |>
  dplyr::distinct(cluster_id, method)
selected_cluster_meta$method <- cp_sub_meta$method[
  match(selected_cluster_meta$cluster_id, cp_sub_meta$cluster_id)
]

study_dispatch <- simulomicsr:::.build_study_dispatch_from_stage3(
  selected_cluster_meta, assignments, stage2_master
)
# ADR-0022 + ADR-0025: i cluster del deliverable (mode=cgroup, method=rem_group)
# hanno lo STESSO schema {study_id, treated, control} dei pair e si fondono nello
# study_dispatch. Senza questo merge nessun cluster si risolve: e' il bug del
# 2026-07-23. Verificato prima del lancio: 12/12 risolti, n_studi == k.
group_rem_dispatch <- simulomicsr:::.build_group_rem_dispatch_from_stage3(
  selected_cluster_meta, assignments, stage2_master,
  n_min = 2L
)
.dup_disp <- intersect(names(study_dispatch), names(group_rem_dispatch))
if (length(.dup_disp) > 0L) {
  cli_abort("cluster_id sovrapposti study/group_rem dispatch: {.dup_disp}")
}
study_dispatch <- c(study_dispatch, group_rem_dispatch)
group_dispatch <- simulomicsr:::.build_group_dispatch_from_stage3(
  selected_cluster_meta, assignments, stage2_master
)

# Guardia fail-loud: ogni cluster della selezione deve essere risolvibile PRIMA
# di iniziare a generare figure (altrimenti si scopre a meta' batch).
.unresolved <- setdiff(
  selection_csv_loaded$cluster_id,
  union(names(study_dispatch), names(group_dispatch))
)
if (length(.unresolved) > 0L) {
  cli_abort("Cluster non risolti dal dispatch: {.unresolved}")
}
cli_alert_success("Dispatch: {length(selection_csv_loaded$cluster_id)}/{length(selection_csv_loaded$cluster_id)} cluster risolti.")

per_cluster_samples_provider <- function(cluster_id) {
  if (cluster_id %in% names(study_dispatch)) {
    items <- study_dispatch[[cluster_id]]
    do.call(rbind, lapply(items, function(it) {
      data.frame(
        sample_id = c(it$treated, it$control),
        study_id  = it$study_id,
        treatment = c(rep("treated", length(it$treated)),
                      rep("control", length(it$control))),
        stringsAsFactors = FALSE
      )
    }))
  } else if (cluster_id %in% names(group_dispatch)) {
    items <- group_dispatch[[cluster_id]]
    do.call(rbind, lapply(items, function(it) {
      data.frame(
        sample_id = it$sample_ids,
        study_id  = it$study_id,
        treatment = it$treatment,
        stringsAsFactors = FALSE
      )
    }))
  } else {
    stop(sprintf("Cluster %s non risolto in study/group dispatch", cluster_id))
  }
}

# -----------------------------------------------------------------------------
# Batch build
# -----------------------------------------------------------------------------
# Efficacia del pooling + materiale, dal deliverable annotato: senza queste
# righe la scheda dice `k_effective: 10` per Parkinson e non dice che gli studi
# efficaci sono 1,8 e che il 73% del peso viene da un modello cellulare.
# Se il deliverable non c'e', il build procede lo stesso e le schede escono
# come prima (il parametro e' opzionale per design).
deliverable_path <- "analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds"
pooling_eff <- if (file.exists(deliverable_path)) {
  d <- readRDS(deliverable_path)
  cols <- intersect(
    c("cluster_id", "k_kish", "quota_top1", "frazione_efficace", "dominato",
      "studio_dominante", "materiale_misto", "classe_studio_dominante",
      "dominato_da_modello", "n_studi_model", "n_studi_primary", "n_studi_unknown"),
    names(d))
  mancanti <- setdiff(selection_csv_loaded$cluster_id, d$cluster_id)
  if (length(mancanti) > 0L) {
    cli_alert_warning("Cluster della selezione assenti dal deliverable: {mancanti}")
  }
  cli_alert_success("Efficacia del pooling caricata: {length(cols)-1} colonne su {nrow(d)} cluster.")
  d[, cols, drop = FALSE]
} else {
  cli_alert_warning("Deliverable annotato assente: le schede usciranno senza le misure di efficacia.")
  NULL
}

cli_alert_info("Build Layer B...")
t0 <- Sys.time()
result <- build_layer_b_results(
  stage4_dir                   = stage4_dir,
  selection                    = selection_csv,
  h5_path                      = h5_path,
  per_cluster_samples_provider = per_cluster_samples_provider,
  stage3_metadata              = stage3_metadata,
  pooling_effectiveness        = pooling_eff,
  config                       = layer_b_default_config()
)
wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

# -----------------------------------------------------------------------------
# Render aggregate report (NON-FATALE)
# -----------------------------------------------------------------------------
cli_alert_info("Render aggregate report...")
report_ok <- tryCatch({
  render_layer_b_report(result, file.path(result$dir, "layer_b_report.html"))
  TRUE
}, error = function(e) {
  cli_alert_warning("Render report FALLITO (non-fatale): {conditionMessage(e)}")
  cli_alert_info("I bundle per-cluster + plot sono comunque in {.path {result$dir}}")
  FALSE
})

cli_alert_success(
  "Layer B batch OK in {.field {round(wall/60, 1)} min}: {.path {result$dir}} (report_html={report_ok})"
)
