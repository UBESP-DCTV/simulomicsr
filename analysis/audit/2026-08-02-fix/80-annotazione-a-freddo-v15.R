#!/usr/bin/env Rscript
# analysis/audit/2026-08-02-fix/80-annotazione-a-freddo-v15.R
#
# Rifà SOLO l'annotazione del deliverable, partendo dai parquet gia' scritti.
#
# Perche' esiste: il re-pool v15 del 2026-08-04/05 ha completato tutti e 351 i
# cluster e scritto `cluster_pooled.parquet` + `per_study_de.parquet` (31 ore di
# calcolo), poi si e' fermato sulla guardia dei verdetti orfani — che sta FUORI
# dal tryCatch apposta, e ha funzionato come doveva. Rilanciare lo script intero
# rifarebbe 31 ore di pooling per rieseguire un passo che dura minuti.
#
# Lo script di re-pool lo dice gia' di suo (righe 369-372): «i parquet sono gia'
# scritti sopra e sono il deliverable primario [...] resta solo la costruzione
# delle etichette e la scrittura, che possono essere rifatte a freddo se
# falliscono». Questo e' quel "a freddo".
#
# NESSUNA LOGICA DUPLICATA: `meta_ann`, `membri_ann` e la chiamata ad
# `annotate_stage4_deliverable()` sono copiati alla lettera dal blocco
# corrispondente del re-pool (righe 328-443), compreso il fix F2 che risolve i
# `record_id` a TRE segmenti con `.split_record_id()`/`.lookup_cmp()` invece di
# ricostruirli in avanti.
#
# LA GUARDIA SUI VERDETTI ORFANI RESTA FATALE, ed e' voluto: e' la difesa contro
# il fallimento silenzioso a favore della conclusione comoda (col pre-filtro, il
# 2026-08-01, il gruppo `adenoma` con verdetto di INCOERENZA usciva marcato
# `coherent`). Se questo script si ferma, il file dei verdetti va aggiornato —
# non la guardia.
#
# ⚠️ Il pre-filtro dello Stadio 2 contro l'asse dei campioni dell'H5, che il
# re-pool fa alle righe 121-146, qui NON serve e non viene fatto: tocca i
# `sample_ids` dei replicate_groups, mentre questo script usa solo le loro
# ETICHETTE (`label_human`) e i cluster gia' poolati. Dichiarato per non
# lasciare pensare che sia una dimenticanza.
#
# Uso:
#   POOL_DIR=<dir del re-pool> STAGE3_DIR=<dir stadio 3 v15> \
#   VERDETTI_PATH=<csv verdetti> \
#     Rscript analysis/audit/2026-08-02-fix/80-annotazione-a-freddo-v15.R

suppressPackageStartupMessages({
  library(cli); library(arrow)
  devtools::load_all(".", quiet = TRUE)
})

pool_dir      <- Sys.getenv("POOL_DIR", "")
stage3_dir    <- Sys.getenv("STAGE3_DIR", "")
verdetti_path <- Sys.getenv("VERDETTI_PATH", "")
stage2_path   <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

if (!nzchar(pool_dir) || !dir.exists(pool_dir))   cli_abort("POOL_DIR mancante o inesistente.")
if (!nzchar(stage3_dir) || !dir.exists(stage3_dir)) cli_abort("STAGE3_DIR mancante o inesistente.")
if (!nzchar(verdetti_path) || !file.exists(verdetti_path))
  cli_abort("VERDETTI_PATH mancante o inesistente. Obbligatorio, come nel re-pool.")

cli_h1("Annotazione a freddo del deliverable v15")
cli_alert_info("pool:     {.path {pool_dir}}")
cli_alert_info("stadio 3: {.path {stage3_dir}}")
cli_alert_info("verdetti: {.path {verdetti_path}}")

t0 <- Sys.time()
s3 <- load_stage3(stage3_dir)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
cluster_pooled <- as.data.frame(read_parquet(file.path(pool_dir, "cluster_pooled.parquet")))
per_study_de   <- as.data.frame(read_parquet(file.path(pool_dir, "per_study_de.parquet")))
cli_alert_success(paste0(
  "Caricati: ", nrow(s3$clusters), " cluster stadio 3 | ",
  length(unique(cluster_pooled$cluster_id)), " cluster poolati | ",
  nrow(cluster_pooled), " righe pooled | ", nrow(per_study_de), " righe per-studio ",
  "(wall ", round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), " sec)"))

config <- stage4_default_config()

s2_idx <- new.env(hash = TRUE, parent = emptyenv())
for (st in stage2_master) if (!is.null(st$series_id)) assign(st$series_id, st, envir = s2_idx)

# --- meta_ann: identico al re-pool (righe 328-332) -----------------------------
meta_ann <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(s3$clusters, config))
meta_ann <- meta_ann[meta_ann$cluster_id %in% unique(cluster_pooled$cluster_id), ]
meta_ann$ckey <- paste0(meta_ann$contrast_entity, "||", meta_ann$contrast_direction,
                        "||", meta_ann$contrast_control_key)
cli_alert_info("meta_ann: {nrow(meta_ann)} gruppi poolati")

# --- guardia FATALE sui verdetti orfani: identica al re-pool (righe 334-350) ---
vv <- utils::read.csv(verdetti_path, stringsAsFactors = FALSE)
fuori <- setdiff(vv$ckey, meta_ann$ckey)
if (length(fuori) > 0L) {
  stop("VERDETTI ORFANI (", length(fuori), "): ", paste(fuori, collapse = "; "),
       "\n  Il loro gruppo non e' nel poolato: senza aggiornarli (FASE D0ter)",
       " un gruppo INCOERENTE verrebbe marcato `coherent`.")
}
verdetti_ann <- vv
cli_alert_success("Verdetti: {nrow(vv)} tutti agganciati a un gruppo poolato.")

# --- membri_ann: identico al re-pool (righe 378-426), fix F2 incluso -----------
asg_ann <- s3$assignments[s3$assignments$cluster_id %in% meta_ann$cluster_id, ]
asg_ann$study <- sub("__.*$", "", asg_ann$record_id)
lab_env <- new.env(hash = TRUE, parent = emptyenv())
.lab_of <- function(rg, gid) {
  if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
}
need_ann <- unique(asg_ann$record_id)
for (rid in need_ann) {
  parsed <- simulomicsr:::.split_record_id(rid)
  if (is.na(parsed$series_id)) next
  if (!exists(parsed$series_id, envir = s2_idx, inherits = FALSE)) next
  study <- get(parsed$series_id, envir = s2_idx, inherits = FALSE)
  cmp <- simulomicsr:::.lookup_cmp(study, parsed$suffix)
  if (is.null(cmp)) next
  rgl <- stats::setNames(
    study$replicate_groups,
    vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
  if (is.null(tg) || is.null(cg)) next
  assign(rid, c(.lab_of(tg, cmp$treated_group), .lab_of(cg, cmp$control_group)),
         envir = lab_env)
}
agganciati <- sum(vapply(need_ann, function(r) exists(r, envir = lab_env, inherits = FALSE), logical(1)))
cli_alert_info("record_id agganciati alle etichette: {agganciati}/{length(need_ann)}")
if (agganciati == 0L)
  stop("ZERO record agganciati: e' il difetto F2 (record_id a tre segmenti). ",
       "Le colonne del materiale uscirebbero NA in silenzio. FERMARSI.")

membri_ann <- do.call(rbind, lapply(seq_len(nrow(asg_ann)), function(i) {
  e <- get0(asg_ann$record_id[i], envir = lab_env, inherits = FALSE)
  if (is.null(e)) return(NULL)
  data.frame(cluster_id = asg_ann$cluster_id[i], study_id = asg_ann$study[i],
             label = e, stringsAsFactors = FALSE)
}))

# --- il deliverable ------------------------------------------------------------
deliverable <- annotate_stage4_deliverable(
  cluster_pooled = cluster_pooled,
  per_study_de   = per_study_de,
  cluster_meta   = meta_ann,
  member_labels  = membri_ann,
  coherence_verdicts = verdetti_ann,
  coherence_source   = Sys.getenv("COHERENCE_SOURCE", "rilettura-D0ter-2026-08-02"))

deliverable$stage3_clusters_sha256 <- digest::digest(
  file = file.path(stage3_dir, "clusters.rds"), algo = "sha256")

saveRDS(deliverable, file.path(pool_dir, "deliverable-annotato.rds"))

# Il CSV: due colonne (`gpl_platforms`, `studies_in_cluster`) sono LISTE, e
# write.csv non le sa scrivere ("unimplemented type 'list'"). Si appiattiscono
# separandole con ";" — l'RDS resta la fonte primaria e le conserva come liste.
# Senza questo il CSV usciva vuoto (1,4 KB di sola intestazione) e nessuno se ne
# sarebbe accorto leggendo solo il conteggio di righe stampato a schermo.
deliv_csv <- deliverable
for (nm in names(deliv_csv)) {
  if (is.list(deliv_csv[[nm]]))
    deliv_csv[[nm]] <- vapply(deliv_csv[[nm]],
                              function(x) paste(unlist(x), collapse = ";"), character(1))
}
utils::write.csv(deliv_csv, file.path(pool_dir, "deliverable-annotato.csv"), row.names = FALSE)

cli_alert_success(paste0(
  "Deliverable annotato: ", nrow(deliverable), " meta-analisi | dominate da un ",
  "solo studio ", sum(deliverable$dominato, na.rm = TRUE), " | meno di 2 studi ",
  "efficaci ", sum(deliverable$k_kish < 2, na.rm = TRUE)))
cli_alert_info(paste0(
  "coerenza: coherent ", sum(deliverable$coherence_verdict == "coherent", na.rm = TRUE),
  " | incoerenti ", sum(deliverable$coherence_verdict != "coherent", na.rm = TRUE),
  " | NA ", sum(is.na(deliverable$coherence_verdict))))
