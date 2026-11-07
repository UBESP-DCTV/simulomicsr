#!/usr/bin/env Rscript
# 20-ingressi.R — S9: gli ingressi della chiave d'entita' di OGNI confronto dello
# Stadio 3 del deliverable A3 v16, con l'anchor ricostruito come nel run vero.
#
# PERCHE'. La chiave d'entita' di un confronto (`.ca_member_contrast()`) dipende
# da cinque stringhe (etichette e factor_levels dei due bracci, nome dell'anchor)
# e dall'ID dell'anchor. L'anchor viene dal recupero del nome e dai due overlay:
# senza, il ramo «on-contrast» resta spento e la chiave non riproduce il
# deliverable. Questo script rifa' i passi 1-6b dello script del re-cluster
# (`analysis/p4-fase-f13-stage3-v16-tre-cambi.R`) e la cache degli anchor della
# fase 2.0 di `build_stage3_clusters()`, poi percorre i confronti ESATTAMENTE come
# `.build_contrast_group_records()` e salva gli ingressi. Non calcola le chiavi:
# lo fa `30-due-regimi.R`, su un file piccolo e in parallelo.
#
# Non scrive nulla fuori da questa cartella. Non tocca deliverable, master, Stadio 3.
#
# Uso (Rscript SENZA --vanilla: con --vanilla mancano arrow e devtools):
#   setsid nohup Rscript analysis/audit/2026-11-07-S9-greche-e-corsie/20-ingressi.R \
#     > analysis/audit/2026-11-07-S9-greche-e-corsie/log/20-ingressi.log 2>&1 < /dev/null &
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(cli); devtools::load_all(".", quiet = TRUE) })
`%||%` <- function(a, b) if (is.null(a)) b else a

OUT <- "analysis/audit/2026-11-07-S9-greche-e-corsie"
source(file.path(OUT, "01-traduzione.R"))

# Gli input del run A3 (dal log analysis/audit/2026-08-16-A3/log/recluster-a3.log,
# righe 9-16). Gli SHA-256 si verificano: un master diverso ferma lo script.
stage1_path   <- "analysis/p4-output/A3-stage1-master-innestato.jsonl"
stage2_path   <- "analysis/p4-output/A3-stage2-master-innestato.jsonl"
stage2_inputs <- c("analysis/input/archs4-human-stage2-input-v3.jsonl",
                   "analysis/input/archs4-human-stage2-rescue-v3.jsonl",
                   "analysis/input/A3-stage2-subset.jsonl",
                   "analysis/input/A3-stage2-rescue.jsonl")
h5_path <- "analysis/input/human_gene_v2.5.h5"
S3_DIR  <- "analysis/p4-output/20260818T110906Z-stage3-v16-7f986159"
meta <- jsonlite::fromJSON(file.path(S3_DIR, "run_metadata.json"))
for (p in c("stage1_master", "stage2_master")) {
  atteso <- meta$input_files[[p]]$sha256
  vero   <- digest::digest(file = meta$input_files[[p]]$path, algo = "sha256")
  if (!identical(atteso, vero)) stop("SHA-256 diverso per ", p, ": ", vero, " invece di ", atteso)
  cli_alert_success("{p}: SHA-256 uguale al run_metadata dello Stadio 3 ({substr(vero, 1, 12)}...)")
}
stopifnot(all(file.exists(stage2_inputs)), file.exists(h5_path))

ns <- asNamespace("simulomicsr")
gi <- function(n) get(n, envir = ns, inherits = FALSE)
t0 <- Sys.time()
tempo <- function() round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)

onto <- gi(".load_ontology_dicts")(refresh = TRUE)
stopifnot(isTRUE(onto$has_chembl), isTRUE(onto$has_taxonomy),
          isTRUE(onto$has_immport), isTRUE(onto$has_uniprot), !isTRUE(onto$is_fixture))
config <- stage3_default_config()

cli_h2("1-2. Stadio 2 + guardia di completezza ({tempo()} min)")
stage2_master <- gi(".load_stage2_master")(stage2_path)
stage2_master <- gi(".assert_stage2_one_record_per_series")(stage2_master)
guard <- gi(".apply_stage2_completeness_by_series")(stage2_master,
                                                     gi(".build_stage2_input_lookup")(stage2_inputs))
stage2_master <- guard$records
cli_alert_info("studi: {length(stage2_master)}; guardia: {guard$report$n_uncovered_total} campioni su {guard$report$n_records_affected} studi")
stopifnot(length(stage2_master) == 24394L, guard$report$n_uncovered_total == 18923L,
          guard$report$n_records_affected == 1448L)

cli_h2("3. Stadio 1 ({tempo()} min)")
stage1_env <- new.env(hash = TRUE)
list2env(gi(".load_stage1_master")(stage1_path), envir = stage1_env)
cli_alert_info("GSM: {length(stage1_env)}")
stopifnot(length(stage1_env) == 508037L)

cli_h2("5. Pre-passaggio anchor senza recupero ({tempo()} min)")
cache0 <- gi(".precompute_anchor_cache")(stage2_master, stage1_env, config$tier_assignment,
                                         recovery_lookup = NULL)
keys <- ls(cache0$anchors, all.names = TRUE)
kind_by_gsm <- new.env(hash = TRUE, parent = emptyenv())
role_by_gsm <- new.env(hash = TRUE, parent = emptyenv())
for (key in keys) {
  parts <- strsplit(key, "|", fixed = TRUE)[[1L]]
  sid <- parts[1L]; role <- parts[2L]
  kind <- attr(get(key, envir = cache0$anchors), "tracking_meta")$kind_effective_llm_original %||% NA_character_
  if (!exists(sid, envir = kind_by_gsm, inherits = FALSE)) {
    assign(sid, kind, envir = kind_by_gsm); assign(sid, role, envir = role_by_gsm)
  } else if (identical(get(sid, envir = role_by_gsm), "control") && identical(role, "treated")) {
    assign(sid, kind, envir = kind_by_gsm); assign(sid, role, envir = role_by_gsm)
  }
}
gsms <- ls(kind_by_gsm, all.names = TRUE)
cli_alert_info("chiavi anchor: {length(keys)}; GSM rappresentanti: {length(gsms)}")
stopifnot(length(keys) == 189966L, length(gsms) == 187288L)
rm(cache0); invisible(gc())

cli_h2("6. Lookup di recupero (cache su disco) ({tempo()} min)")
recovery_lookup <- build_name_recovery_lookup(
  h5_path = h5_path, gsms = gsms, kind_by_gsm = kind_by_gsm, ontology_env = onto,
  cache_dir = file.path(tools::R_user_dir("simulomicsr", which = "cache"), "name-recovery-lookup"))
cli_alert_info("GSM con voce: {length(ls(recovery_lookup, all.names = TRUE))}")

cli_h2("6b. Overlay v9 e fallback ({tempo()} min)")
source("analysis/audit/_gsm-lookup-helper.R")
rec_env <- build_record_gsm_lookup(stage2_path)
r2g <- function(rid) { g <- get0(rid, envir = rec_env, inherits = FALSE); if (is.null(g)) character(0) else as.character(g) }
s <- readRDS("analysis/p4-output/name-cleanup-side-table-v1.rds")
a <- load_stage3("analysis/p4-output/20260710T045849Z-stage3-v9pre-364547a7")$assignments
ov <- gi(".side_table_to_recovery_overlay")(s, a, r2g)
recovery_lookup <- gi(".overlay_recovery_lookup")(recovery_lookup, ov); n_v9 <- length(ov)
s <- readRDS("analysis/p4-output/name-cleanup-fallback-side-table.rds")
a <- load_stage3("analysis/p4-output/20260717T171550Z-stage3-v9-364547a7")$assignments
ov <- gi(".side_table_to_recovery_overlay")(s, a, r2g)
recovery_lookup <- gi(".overlay_recovery_lookup")(recovery_lookup, ov); n_fb <- length(ov)
cli_alert_info("overlay v9: {n_v9} GSM; overlay fallback: {n_fb} GSM")
stopifnot(n_v9 == 52437L, n_fb == 41470L)
rm(s, a, ov, rec_env); invisible(gc())

cli_h2("Fase 2.0: cache degli anchor con il recupero ({tempo()} min)")
cache <- gi(".precompute_anchor_cache")(stage2_master, stage1_env, config$tier_assignment,
                                        recovery_lookup = recovery_lookup)
cli_alert_info("anchor in cache: {length(cache$anchors)}")
stopifnot(length(cache$anchors) == 189966L)

# ------------------------------------------------------------------------------
# I confronti, percorsi come .build_contrast_group_records() (R/stage3-build.R).
# ------------------------------------------------------------------------------
cli_h2("Confronti ({tempo()} min)")
fl_of <- function(rg) {
  fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";")
}
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
# Tutte le stringhe dei fatti dello Stadio 1 del campione: servono SOLO a contare
# che cosa lo strumento non vede (l'anchor non si ricalcola con la traduzione).
fatti_con_G <- function(f) {
  v <- unlist(f, use.names = FALSE)
  v <- v[is.character(v)]
  length(v) > 0L && any(ha_G(v))
}

righe <- vector("list", 120000L); n <- 0L
saltati <- c(malformata = 0L, braccio_vuoto = 0L, gsm_assente = 0L)
for (study in stage2_master) {
  sid <- study$series_id
  rg_lookup <- setNames(study$replicate_groups,
                        vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  cmp_seen <- new.env(hash = TRUE, parent = emptyenv())
  for (cmp in study$comparisons) {
    tg <- rg_lookup[[cmp$treated_group]]; cg <- rg_lookup[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) { saltati["malformata"] <- saltati["malformata"] + 1L; next }
    if (length(tg$sample_ids) == 0L || length(cg$sample_ids) == 0L) {
      saltati["braccio_vuoto"] <- saltati["braccio_vuoto"] + 1L; next }
    tg_sample <- tg$sample_ids[[1L]]
    tg_facts  <- stage1_env[[tg_sample]]
    if (is.null(tg_facts)) { saltati["gsm_assente"] <- saltati["gsm_assente"] + 1L; next }
    segs <- cache$anchors[[sprintf("%s|treated", tg_sample)]]
    tm <- attr(segs, "tracking_meta")
    n_seen <- (get0(cmp$comparison_id, envir = cmp_seen, ifnotfound = 0L)) + 1L
    assign(cmp$comparison_id, n_seen, envir = cmp_seen)
    n <- n + 1L
    righe[[n]] <- list(
      record_id   = sprintf("%s__%s__%d", sid, cmp$comparison_id, n_seen),
      study       = sid,
      tl          = lab_of(tg, cmp$treated_group),
      cl          = lab_of(cg, cmp$control_group),
      tfl         = fl_of(tg),
      cfl         = fl_of(cg),
      anchor_name = tm$canonical_name    %||% NA_character_,
      anchor_id   = tm$agent_id_resolved %||% NA_character_,
      eleggibile  = .has_complete_tier_s(segs),
      fatti_G     = fatti_con_G(tg_facts),
      n_trattati  = length(tg$sample_ids),
      n_controlli = length(cg$sample_ids))
  }
}
righe <- righe[seq_len(n)]
ing <- data.frame(
  record_id   = vapply(righe, `[[`, "", "record_id"),
  study       = vapply(righe, `[[`, "", "study"),
  tl          = vapply(righe, function(r) as.character(r$tl), ""),
  cl          = vapply(righe, function(r) as.character(r$cl), ""),
  tfl         = vapply(righe, `[[`, "", "tfl"),
  cfl         = vapply(righe, `[[`, "", "cfl"),
  anchor_name = vapply(righe, function(r) as.character(r$anchor_name)[1L], ""),
  anchor_id   = vapply(righe, function(r) as.character(r$anchor_id)[1L], ""),
  eleggibile  = vapply(righe, `[[`, NA, "eleggibile"),
  fatti_G     = vapply(righe, `[[`, NA, "fatti_G"),
  n_trattati  = vapply(righe, `[[`, 0L, "n_trattati"),
  n_controlli = vapply(righe, `[[`, 0L, "n_controlli"),
  stringsAsFactors = FALSE)
stopifnot(!anyDuplicated(ing$record_id))
cli_alert_info("confronti: {nrow(ing)}; saltati come nel build: {paste(names(saltati), saltati, sep='=', collapse=', ')}")
cli_alert_info("record_id unici: {length(unique(ing$record_id))}; eleggibili: {sum(ing$eleggibile)}")

saveRDS(ing, file.path(OUT, "20-ingressi.rds"))
cli_alert_success("Scritto 20-ingressi.rds ({tempo()} min)")
