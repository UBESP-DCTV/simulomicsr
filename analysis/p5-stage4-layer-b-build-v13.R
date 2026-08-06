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

# I percorsi stanno TUTTI qui e il deliverable si DERIVA: prima era cablato 180
# righe piu' in basso, e chi aggiornava questi due non lo vedeva (misurato
# 2026-08-02: il join sarebbe riuscito in silenzio sulla figura 2 del paper,
# perche' il cluster_id di un cgroup e' l'hash della sola chiave del
# contrasto e coincide fra run diversi).
stage4_dir  <- Sys.getenv("STAGE4_DIR", "")
stage3_dir  <- Sys.getenv("STAGE3_DIR", "")
if (!nzchar(stage4_dir) || !nzchar(stage3_dir))
  stop("STAGE4_DIR e STAGE3_DIR sono obbligatorie: il Layer B non deve poter ",
       "illustrare un run diverso da quello che misura.")
deliverable_path <- Sys.getenv("LAYER_B_DELIVERABLE",
                               file.path(stage4_dir, "deliverable-annotato.rds"))
stage2_path   <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
# Selezione FINALE (9 case study: 3 main + 6 supplementari), decisa sulle misure
# del 2026-07-31 e non sul k — vedi analysis/audit/2026-07-31-layer-b-v13/120-selection-finale.R.
# La prima selezione esplorativa (12 case study, con i doppioni TGF-beta1/LPS e
# Parkinson/HCC ancora aperti) resta in analysis/layer-b-selection-v13.csv.
# NB: nessun default — il CSV v13 porta 181 numeri del run vecchio cablati a
# mano nella colonna `notes`, e finirebbero ristampati sulle schede del run
# nuovo (secondo canale, indipendente da deliverable_path sopra).
selection_csv <- Sys.getenv("LAYER_B_SELECTION", "")
if (!nzchar(selection_csv))
  stop("LAYER_B_SELECTION e' obbligatoria: il CSV di v13 porta 181 numeri ",
       "cablati nelle note e finirebbero stampati sulle schede del run nuovo.")
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
# Efficacia del pooling + materiale, dal deliverable annotato dello STESSO run
# (deliverable_path e' derivato da stage4_dir in testa al file — vedi sopra):
# senza queste righe la scheda dice `k_effective: 10` per Parkinson e non dice
# che gli studi efficaci sono 1,8 e che il 73% del peso viene da un modello
# cellulare. Non e' piu' opzionale: un deliverable mancante o incompleto ferma
# il batch invece di produrre schede silenziosamente senza le misure.
if (!file.exists(deliverable_path))
  cli::cli_abort(c("Deliverable annotato assente in {.path {deliverable_path}}.",
                   i = "Le misure devono venire dallo stesso run delle figure: ",
                   i = "non si ripiega su un file di audit di un altro run."))
d <- readRDS(deliverable_path)
cols <- intersect(
  c("cluster_id", "k_kish", "quota_top1", "frazione_efficace", "dominato",
    "studio_dominante", "materiale_misto", "classe_studio_dominante",
    "dominato_da_modello", "n_studi_model", "n_studi_primary", "n_studi_unknown"),
  names(d))
mancanti <- setdiff(selection_csv_loaded$cluster_id, d$cluster_id)
if (length(mancanti) > 0L) {
  cli_abort("Cluster della selezione assenti dal deliverable: {mancanti}")
}
cli_alert_success("Efficacia del pooling caricata: {length(cols)-1} colonne su {nrow(d)} cluster.")
pooling_eff <- d[, cols, drop = FALSE]

# -----------------------------------------------------------------------------
# Confronti imperfetti: SOLO dove esiste un conteggio vero.
#
# CORREZIONE 2026-08-06. La versione precedente prendeva il peso da
# `peso_citati` (analysis/audit/2026-08-05-rilettura-214/verdetti-con-peso.csv),
# la quota degli studi CITATI nelle motivazioni della rilettura, estratti con
# un'espressione regolare -- una stima che il progetto stesso dichiara cieca
# (finding 2026-08-05 §5.4: mediana 87%, perche' raccoglie anche gli studi
# citati come *puliti*). Per i tre case study fuori dai tredici gruppi grandi
# quel numero veniva stampato accanto a due punti di domanda: «? confronti
# imperfetti su ? (100,0% del peso stimato)» per IL1A. Un numero inaffidabile
# con l'aspetto di una misura, in un documento da articolo.
#
# Ora la fonte e' una sola: `confronti-imperfetti-conteggio.json`, prodotto da
# analysis/audit/2026-08-06-layer-b-v3/10-conteggio-e-peso.R, che tiene insieme
#   - i tredici gruppi con k>=15 contati il 2026-08-05, e
#   - i tre case study contati il 2026-08-06 (contatore + due critici
#     simmetrici + arbitro),
# e ricalcola il peso per TUTTI con la stessa regola: quota degli studi che il
# CONTEGGIO identifica come portatori di almeno un confronto difettoso
# (mediana 1/SE^2 per studio, normalizzata dentro il gruppo). Sui sedici
# gruppi il numero cambia in sei casi -- IL1A da 100,0% a 10,1%, Parkinson da
# 60,1% a 12,6%.
#
# Un gruppo senza conteggio non riceve un peso: .lb_confronti_imperfetti_txt()
# dichiara "not measured for this group".
conteggio_path <- "analysis/audit/2026-08-06-layer-b-v3/confronti-imperfetti-conteggio.json"
if (!file.exists(conteggio_path)) {
  cli_alert_warning(paste0(
    "Conteggio dei confronti imperfetti assente in {.path {conteggio_path}}: ",
    "ogni scheda dichiarera' \"not measured\"."
  ))
  confronti_imperfetti_provider <- NULL
} else {
  conteggio_tab <- jsonlite::fromJSON(conteggio_path, simplifyDataFrame = FALSE)
  conteggio_by_id <- stats::setNames(
    conteggio_tab, vapply(conteggio_tab, `[[`, character(1), "cluster_id"))
  senza_conteggio <- setdiff(selection_csv_loaded$cluster_id, names(conteggio_by_id))
  if (length(senza_conteggio) > 0L) {
    cli_alert_warning(paste0(
      "Cluster della selezione senza conteggio dei confronti imperfetti ",
      "(dichiareranno \"not measured\"): {paste(senza_conteggio, collapse = ', ')}"
    ))
  }
  confronti_imperfetti_provider <- function(cluster_id) {
    g <- conteggio_by_id[[cluster_id]]
    if (is.null(g)) return(NULL)
    list(n = g$n, tot = g$tot, peso = g$peso)
  }
}

# -----------------------------------------------------------------------------
# Narrative firmate: una per case study, in analysis/layer-b-narratives/.
#
# Sono testo scientifico scritto e verificato (ricerca bibliografica, verifica
# indipendente di ogni cifra contro deliverable e parquet, contestazione e
# difesa), NON un testo generato dalle colonne del deliverable: quella strada
# (.narrativa_bozza(), 2026-08-05) produceva nove testi formalmente corretti e
# senza contenuto scientifico, ed e' stata ritirata.
#
# Un gruppo senza file non riceve un testo generico: il documento dichiara che
# la narrativa non e' disponibile, e il run_metadata lo registra.
narrative_dir <- "analysis/layer-b-narratives"
narrative_provider <- function(cluster_id) {
  p <- file.path(narrative_dir, sprintf("%s.md", cluster_id))
  if (!file.exists(p)) return(NULL)
  paste(readLines(p, warn = FALSE), collapse = "\n")
}
senza_narrativa <- selection_csv_loaded$cluster_id[
  !file.exists(file.path(narrative_dir, sprintf("%s.md", selection_csv_loaded$cluster_id)))]
if (length(senza_narrativa) > 0L) {
  cli_alert_warning(
    "Case study senza narrativa firmata: {paste(senza_narrativa, collapse = ', ')}")
} else {
  cli_alert_success("Narrative firmate presenti per tutti i {nrow(selection_csv_loaded)} case study.")
}

# -----------------------------------------------------------------------------
# Bersagli attesi (controllo biologico): STESSA lista, letteralmente, di
# analysis/audit/2026-08-02-fix/90-controllo-biologico-v15.R (7 entita', 31
# bersagli, fissati dalla letteratura PRIMA di guardare i risultati) -- non se
# ne inventa una seconda qui. E' un argomento del CHIAMANTE
# (bersagli_attesi_provider, R/layer-b-build.R): il pacchetto non porta una
# tabella interna di bersagli (vedi .narrativa_bozza()).
#
# Prima di questo collegamento il parametro esisteva gia' in
# build_layer_b_results() ma non veniva mai passato: ogni scheda dichiarava
# "nessun bersaglio noto ritrovato per questo gruppo" anche quando i bersagli
# erano nel parquet al k pieno (es. TGF-beta1: PMEPA1 +2,879 FDR 8,6e-39 k=59).
#
# `d` (il deliverable annotato, gia' caricato sopra per pooling_eff) porta
# `contrast_entity` -- la STESSA colonna che 90-controllo-biologico-v15.R usa
# per trovare la riga di ciascuna entita' (`D$contrast_entity == a$ent`).
ATTESI <- list(
  list(ent = "CHEBI:16330",       geni = c("KLK3", "TMPRSS2", "FKBP5", "NKX3-1")),
  list(ent = "CHEBI:68534",       geni = c("KLK3", "TMPRSS2", "FKBP5", "NKX3-1")),
  list(ent = "HGNC:11766",        geni = c("SERPINE1", "CCN2", "SMAD7", "JUNB", "TGFBI", "COL1A1")),
  list(ent = "NCBITaxon:2697049", geni = c("IFIT1", "ISG15", "MX1", "OAS1")),
  list(ent = "HGNC:5438",         geni = c("STAT1", "GBP1", "CXCL9", "TAP1", "IRF1")),
  list(ent = "CHEBI:16412",       geni = c("TNF", "IL6", "IL1B", "CXCL8")),
  list(ent = "HGNC:5981",         geni = c("CXCL8", "CCL20", "CXCL1", "LCN2"))
)
ATTESI_BY_ENT <- stats::setNames(
  lapply(ATTESI, `[[`, "geni"),
  vapply(ATTESI, `[[`, character(1), "ent")
)
bersagli_attesi_provider <- function(cluster_id) {
  ent <- d$contrast_entity[d$cluster_id == cluster_id]
  if (length(ent) == 0L || is.na(ent[1L])) return(character(0))
  geni <- ATTESI_BY_ENT[[ent[1L]]]
  if (is.null(geni)) character(0) else geni
}

cli_alert_info("Build Layer B...")
t0 <- Sys.time()
result <- build_layer_b_results(
  stage4_dir                    = stage4_dir,
  selection                     = selection_csv,
  h5_path                       = h5_path,
  per_cluster_samples_provider  = per_cluster_samples_provider,
  stage3_metadata               = stage3_metadata,
  bersagli_attesi_provider      = bersagli_attesi_provider,
  pooling_effectiveness         = pooling_eff,
  confronti_imperfetti_provider = confronti_imperfetti_provider,
  narrative_provider            = narrative_provider,
  config                        = layer_b_default_config()
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
