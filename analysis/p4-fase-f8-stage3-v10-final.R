#!/usr/bin/env Rscript
# analysis/p4-fase-f8-stage3-v10-final.R --- RED ALERT FASE F6 v10:
# RE-CLUSTER Stadio 3 v10 col rework "recupero-nome" (name-recovery) PIU' DUE
# overlay di correzioni LLM: (1) side-table v9 (k>=2 suspects), (2) side-table
# FALLBACK finale (STR:/UNK, no filtro k, 50.246 override). Materializza l'upside
# poolabile misurato (opzione C 2026-07-20): +22 nuove meta-analisi rem_group,
# +41 rafforzate, +151 k_eff (breast 23->30, colorectal 18->28, hepatocell 28->37,
# enzalutamide 27->32, ...). Identico al v9-final piu' il secondo overlay.
#
# COSA FA
#   Ri-gira `build_stage3_clusters()` passando un lookup di recupero identita'
#   PIENO (GSM -> {kind, agent_id, canonical_name, recovery_source}), cosi' i
#   cluster oggi `UNK` (i minestroni: stessa tessuto/anchor ma malattie/composti
#   DIVERSI collassati insieme) si SCOMPONGONO per identita' recuperata:
#     - disease_vs_normal|UNK|<tessuto>  -> tanti cluster MeSH:Dxxxxxx / STR:<slug>
#     - small_molecule|UNK|... (degron)  -> kind flippato a genetic_* + HGNC:<gene> (K2)
#
# IL NODO: kind_by_gsm COERENTE CON L'ANCHOR (per costruzione)
#   `recover_identity()` decide il ramo di recupero (malattia vs composto vs
#   genetico) dal `llm_kind` del GSM. Questo DEVE coincidere col
#   `kind_effective_llm` che `.extract_anchor_segments()` calcola per quel GSM
#   (stesso GSM rappresentante, stesso `stage2_role`). Per garantirlo SENZA
#   ri-implementare la logica:
#     1) si fa un PRIMO passaggio anchor "a vuoto" chiamando la STESSA funzione
#        di pacchetto `.precompute_anchor_cache(..., recovery_lookup = NULL)`;
#        ogni segmento porta in `attr(., "tracking_meta")$kind_effective_llm_original`
#        esattamente il kind LLM pre-recovery;
#     2) si legge quel campo per ogni chiave "GSM|role" e si costruisce
#        `kind_by_gsm` (ENVIRONMENT hash, non named list: M3/I1 della final
#        review -- su ~10^5 GSM una named list rende `kind_by_gsm[[gsm]]` O(n^2));
#     3) si costruisce il lookup di recupero su quei GSM rappresentanti;
#     4) `build_stage3_clusters()` rifa' l'anchor cache CON il recovery: il
#        SECONDO passaggio. Coerente per costruzione perche' usa gli STESSI
#        input (stessa lista Stadio 2 gia' completata, stesso environment
#        Stadio 1) -- l'unica differenza tra i due passaggi e' `recovery_lookup`.
#   Tie-break: un GSM puo' comparire come rappresentante con DUE ruoli (treated
#   di una comparison, control di un'altra, baseline condivisa). Si preferisce
#   il kind del ruolo "treated" (il braccio caratterizzante) -- vedi §kind_by_gsm.
#   La frequenza delle collisioni e' misurata e stampata.
#
# COME LANCIARLO
#   SMOKE (default; pochi minuti; subset che targetizza i minestroni v3 + gli studi
#   degli override fallback che si fondono nelle bandiera -- valida i DUE overlay):
#       Rscript analysis/p4-fase-f8-stage3-v10-final.R
#   FULL RUN (gate utente separato, ~8h; NON lanciare senza ok; usare setsid):
#       SMOKE=0 Rscript analysis/p4-fase-f8-stage3-v10-final.R
#   Parametri opzionali via env (default = i path v9/fallback gia' prodotti):
#       SMOKE_N_STUDIES     numero max di studi nel subset smoke (default 250)
#       NR_CACHE_DIR        dir cache lookup recovery (default cache utente; "" = no cache)
#       SIDE_TABLE_V9       side-table v9 (default name-cleanup-side-table-v1.rds)
#       STAGE3_V9PRE_DIR    dir v9-pre (mappa cluster_id v9 -> record_id)
#       SIDE_TABLE_FALLBACK side-table fallback (default name-cleanup-fallback-side-table.rds)
#       STAGE3_V9FINAL_DIR  dir v9-final (mappa cluster_id fallback -> record_id)
#
# INPUT (gli stessi del build v3 `p4-fase-f4-stage3-rebuild-v3.R`):
#   analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl
#   analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl
#   analysis/input/archs4-human-stage2-input-v3.jsonl (+ rescue-v3) [completeness guard, solo FULL]
#   analysis/input/human_gene_v2.5.h5
#   (smoke) analysis/p4-output/20260611T171555Z-stage3-v3-364547a7/ [per scegliere i minestroni]
# OUTPUT: analysis/p4-output/<UTC>-stage3-v9-<run_id>/ (gitignored, schema v3 +
#   run_metadata.json con name_recovery=TRUE + release ontologiche + schema_version)
# Wall stima FULL: ~90-120 min su laptop 251GB (build ~80 min + pre-pass anchor +
#   lookup recovery). SMOKE: pochi minuti.

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

# --- Flag e parametri --------------------------------------------------------
SMOKE         <- !identical(Sys.getenv("SMOKE", "1"), "0")
SMOKE_N       <- as.integer(Sys.getenv("SMOKE_N_STUDIES", "250"))
nr_cache_env  <- Sys.getenv("NR_CACHE_DIR", unset = "__DEFAULT__")
nr_cache_dir  <- if (identical(nr_cache_env, "__DEFAULT__")) {
  file.path(tools::R_user_dir("simulomicsr", which = "cache"), "name-recovery-lookup")
} else if (!nzchar(nr_cache_env)) NULL else nr_cache_env
# In SMOKE niente cache su disco (vogliamo esercitare il path completo).
if (SMOKE) nr_cache_dir <- NULL

cli::cli_h1(sprintf("Re-cluster Stadio 3 v10 (name-recovery + overlay v9 k>=2 + overlay LLM-fallback STR/UNK) -- modalita': %s",
                    if (SMOKE) sprintf("SMOKE (max %d studi)", SMOKE_N) else "FULL RUN"))

stage1_path   <- "analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl"
stage2_path   <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
stage2_inputs <- c("analysis/input/archs4-human-stage2-input-v3.jsonl",
                   "analysis/input/archs4-human-stage2-rescue-v3.jsonl")
h5_path       <- "analysis/input/human_gene_v2.5.h5"
v3_dir        <- "analysis/p4-output/20260611T171555Z-stage3-v3-364547a7"
stopifnot(file.exists(stage1_path), file.exists(stage2_path), file.exists(h5_path))
if (!SMOKE) stopifnot(all(file.exists(stage2_inputs)))

# Fail-loud dizionari: il loader e' GRACEFUL (senza dizionari gira in qualita'
# degradata, silenziosamente). Questi assert garantiscono che v6 sia prodotto
# SOLO con tutti i dizionari necessari caricati. refresh=TRUE popola il
# singleton per il run.
local({
  onto_chk <- simulomicsr:::.load_ontology_dicts(refresh = TRUE)
  if (!isTRUE(onto_chk$has_chembl))
    stop("ChEMBL dict mancante (R_user_dir/chembl/chembl-lookup.rds): impossibile produrre v6. ",
         "Ricostruire via: Rscript analysis/p5-audit-chembl-build-dict.R")
  if (!isTRUE(onto_chk$has_taxonomy))
    stop("Taxonomy dict mancante (R_user_dir/taxonomy/taxonomy-lookup.rds): impossibile produrre v6. ",
         "Ricostruire via: Rscript analysis/p5-audit-taxonomy-build-dict.R")
  if (!isTRUE(onto_chk$has_immport))
    stop("ImmPort dict mancante (R_user_dir/immport/immport-lookup.rds): impossibile produrre v6. ",
         "Ricostruire via: Rscript analysis/p5-audit-immport-build-dict.R")
  if (!isTRUE(onto_chk$has_uniprot))
    stop("UniProt dict mancante (R_user_dir/uniprot/uniprot-lookup.rds): impossibile produrre v6. ",
         "Ricostruire via: Rscript analysis/p5-audit-uniprot-build-dict.R")
})

ns      <- asNamespace("simulomicsr")
get_int <- function(name) get(name, envir = ns, inherits = FALSE)
.load_stage2_master_fn  <- get_int(".load_stage2_master")
.load_stage1_master_fn  <- get_int(".load_stage1_master")
.assert_one_record_fn   <- get_int(".assert_stage2_one_record_per_series")
.build_input_lookup_fn  <- get_int(".build_stage2_input_lookup")
.apply_completeness_fn  <- get_int(".apply_stage2_completeness_by_series")
.precompute_cache_fn    <- get_int(".precompute_anchor_cache")
.load_ontology_dicts_fn <- get_int(".load_ontology_dicts")

config <- stage3_default_config()
cli::cli_inform("schema_versions: anchor={config$schema_versions$anchor}, resolver={config$schema_versions$resolver}")

t_start <- Sys.time()

# ---------------------------------------------------------------------------
# 1. Carica Stadio 2 master (lista di study record) + invariante 1-record/serie
# ---------------------------------------------------------------------------
cli::cli_h2("1. Carico Stadio 2 master")
stage2_master <- .load_stage2_master_fn(stage2_path)
stage2_master <- .assert_one_record_fn(stage2_master)
cli::cli_alert_success("Stadio 2: {length(stage2_master)} studi")

# ---------------------------------------------------------------------------
# 1b. (SMOKE) Subset di studi che TARGETIZZA i minestroni v3, cosi' lo smoke
#     dimostra empiricamente la scomposizione (disease|UNK -> N malattie;
#     small_molecule|UNK degron -> genetic_*). Selezione deterministica:
#     prende il cluster disease_vs_normal|UNK piu' grande + un small_molecule|UNK,
#     ne raccoglie le serie membri, e completa fino a SMOKE_N studi.
# ---------------------------------------------------------------------------
smoke_target_series <- character(0)
if (SMOKE) {
  cli::cli_h2("1b. [SMOKE] Seleziono subset di studi (target minestroni v3)")
  if (dir.exists(v3_dir) && requireNamespace("arrow", quietly = TRUE)) {
    cl_v3  <- readRDS(file.path(v3_dir, "clusters.rds"))
    asg_v3 <- arrow::read_parquet(file.path(v3_dir, "assignments.parquet"),
                                  col_select = c("record_id", "cluster_id"))
    pick_biggest <- function(kind) {
      sub <- cl_v3[!is.na(cl_v3$kind_effective_resolved) &
                     cl_v3$kind_effective_resolved == kind &
                     !is.na(cl_v3$agent_id_resolved) &
                     cl_v3$agent_id_resolved == "UNK" &
                     cl_v3$n_studies >= 2L, , drop = FALSE]
      if (nrow(sub) == 0L) return(character(0))
      sub$cluster_id[which.max(sub$n_studies)]
    }
    pick_smallmol <- function() {
      # un small_molecule|UNK piccolo (preferito per K2 degron, < 30 studi)
      sub <- cl_v3[!is.na(cl_v3$kind_effective_resolved) &
                     cl_v3$kind_effective_resolved == "small_molecule" &
                     !is.na(cl_v3$agent_id_resolved) &
                     cl_v3$agent_id_resolved == "UNK" &
                     cl_v3$n_studies >= 2L & cl_v3$n_studies <= 30L, , drop = FALSE]
      if (nrow(sub) == 0L) return(character(0))
      sub$cluster_id[which.max(sub$n_studies)]
    }
    chosen <- c(pick_biggest("disease_vs_normal"), pick_smallmol(),
                "group_L4_cc07ca23", "group_L0_686d6360")
    chosen <- unique(chosen[nzchar(chosen)])
    rid <- unique(asg_v3$record_id[asg_v3$cluster_id %in% chosen])
    smoke_target_series <- unique(sub("__.*$", "", rid))
    cli::cli_alert_info("Cluster v3 target: {paste(chosen, collapse=', ')} -> {length(smoke_target_series)} serie membri")

    # [v10] Aggiungi gli studi degli override FALLBACK che si fondono nelle bandiera
    # (new_id MeSH breast/colorectal/hepatocell) -> lo smoke esercita il 2o overlay.
    fb_path <- Sys.getenv("SIDE_TABLE_FALLBACK", "analysis/p4-output/name-cleanup-fallback-side-table.rds")
    vf_dir  <- Sys.getenv("STAGE3_V9FINAL_DIR", "analysis/p4-output/20260717T171550Z-stage3-v9-364547a7")
    if (file.exists(fb_path) && dir.exists(vf_dir)) {
      fb  <- readRDS(fb_path)
      flag_ids <- c("MeSH:D001943", "MeSH:D015179", "MeSH:D006528")  # breast/colorectal/hepatocell
      fb_cids <- fb$cluster_id[fb$action == "override" & !is.na(fb$new_id) & fb$new_id %in% flag_ids]
      asg_vf <- arrow::read_parquet(file.path(vf_dir, "assignments.parquet"),
                                    col_select = c("record_id", "cluster_id"))
      fb_rid <- unique(asg_vf$record_id[asg_vf$cluster_id %in% fb_cids])
      fb_series <- unique(sub("__.*$", "", fb_rid))
      smoke_target_series <- unique(c(smoke_target_series, fb_series))
      cli::cli_alert_info("[v10] +{length(fb_series)} serie da {length(fb_cids)} override fallback -> bandiera (tot target {length(smoke_target_series)})")
    }
  } else {
    cli::cli_alert_warning("Dir v3 assente: subset smoke = prime serie del master")
  }

  all_series <- vapply(stage2_master, function(s) as.character(s$series_id %||% NA), character(1L))
  keep_series <- intersect(smoke_target_series, all_series)
  if (length(keep_series) > SMOKE_N) keep_series <- keep_series[seq_len(SMOKE_N)]
  # completa fino a SMOKE_N con altre serie (ordine file) per un mix piu' ampio
  if (length(keep_series) < SMOKE_N) {
    extra <- setdiff(all_series, keep_series)
    keep_series <- c(keep_series, utils::head(extra, SMOKE_N - length(keep_series)))
  }
  stage2_master <- stage2_master[all_series %in% keep_series]
  cli::cli_alert_success("[SMOKE] subset: {length(stage2_master)} studi ({length(intersect(smoke_target_series, keep_series))} dai minestroni target)")
}

# ---------------------------------------------------------------------------
# 2. Completeness guard (REGOLA 4): aggiunge gruppi sintetici 'unclear' per i
#    sample di input non coperti. SOLO FULL (in SMOKE i 'unclear' sono inerti al
#    recupero e leggere i 312MB di input non aggiunge valore allo smoke).
# ---------------------------------------------------------------------------
completeness_report <- NULL
if (!SMOKE) {
  cli::cli_h2("2. Completeness guard (REGOLA 4)")
  input_by_series <- .build_input_lookup_fn(stage2_inputs)
  guard           <- .apply_completeness_fn(stage2_master, input_by_series)
  stage2_master   <- guard$records
  completeness_report <- c(guard$report, list(n_input_files = length(stage2_inputs)))
  cli::cli_alert_success("guard: {guard$report$n_uncovered_total} sample -> 'unclear' su {guard$report$n_records_affected} studi")
} else {
  cli::cli_alert_info("[SMOKE] completeness guard SALTATO (inerte al recupero)")
}

# ---------------------------------------------------------------------------
# 3. Carica Stadio 1 (facts per GSM) -> environment per O(1).
#    FULL: tutto il master. SMOKE: solo i GSM referenziati dal subset (filtra il
#    JSONL per record_id=GSM, poi usa il loader di pacchetto sulle righe tenute).
# ---------------------------------------------------------------------------
cli::cli_h2("3. Carico Stadio 1 (facts)")
if (SMOKE) {
  needed_gsm <- unique(unlist(lapply(stage2_master, function(st) {
    unlist(lapply(st$replicate_groups, function(rg) as.character(unlist(rg$sample_ids))),
           use.names = FALSE)
  }), use.names = FALSE))
  needed_gsm <- needed_gsm[!is.na(needed_gsm) & nzchar(needed_gsm)]
  cli::cli_alert_info("[SMOKE] GSM referenziati dal subset: {length(needed_gsm)}")
  lines <- readLines(stage1_path, warn = FALSE)
  rid   <- sub("^\\{\"record_id\"\\s*:\\s*\"([^\"]+)\".*", "\\1", lines)
  keep  <- rid %in% needed_gsm
  tmp_s1 <- tempfile(fileext = ".jsonl")
  writeLines(lines[keep], tmp_s1)
  rm(lines); gc()
  stage1_list <- .load_stage1_master_fn(tmp_s1)
  unlink(tmp_s1)
} else {
  stage1_list <- .load_stage1_master_fn(stage1_path)
}
stage1_env <- new.env(hash = TRUE, size = length(stage1_list))
list2env(stage1_list, envir = stage1_env)
rm(stage1_list); gc()
cli::cli_alert_success("Stadio 1: {length(stage1_env)} GSM in environment")

# ---------------------------------------------------------------------------
# 4. Ontologia (singleton, richiesta da recover_identity)
# ---------------------------------------------------------------------------
cli::cli_h2("4. Carico ontologia (MeSH + ChEBI + HGNC)")
onto <- .load_ontology_dicts_fn()
cli::cli_alert_success("Ontologia caricata")

# ---------------------------------------------------------------------------
# 5. PRIMO passaggio anchor "a vuoto" -> kind_by_gsm coerente per costruzione.
#    Riusa .precompute_anchor_cache(recovery_lookup=NULL) (STESSA funzione del
#    build); legge tracking_meta$kind_effective_llm_original per ogni "GSM|role".
# ---------------------------------------------------------------------------
cli::cli_h2("5. Pre-pass anchor (recovery=NULL) -> kind_by_gsm")
cache0 <- .precompute_cache_fn(stage2_master, stage1_env, config$tier_assignment,
                               recovery_lookup = NULL)
keys <- ls(cache0$anchors, all.names = TRUE)
cli::cli_alert_info("anchor cache pre-pass: {length(keys)} chiavi (GSM|role)")

# kind_by_gsm e role_by_gsm come ENVIRONMENT (M3/I1: named list = O(n^2) su 10^5 GSM)
kind_by_gsm <- new.env(hash = TRUE, parent = emptyenv(), size = length(keys))
role_by_gsm <- new.env(hash = TRUE, parent = emptyenv(), size = length(keys))
n_coll <- 0L; n_coll_diff <- 0L
for (key in keys) {
  parts <- strsplit(key, "|", fixed = TRUE)[[1L]]
  sid <- parts[1L]; role <- parts[2L]
  tm <- attr(get(key, envir = cache0$anchors), "tracking_meta")
  kind <- tm$kind_effective_llm_original %||% NA_character_
  if (!exists(sid, envir = kind_by_gsm, inherits = FALSE)) {
    assign(sid, kind, envir = kind_by_gsm)
    assign(sid, role, envir = role_by_gsm)
  } else {
    n_coll <- n_coll + 1L
    prev_kind <- get(sid, envir = kind_by_gsm)
    if (!identical(prev_kind, kind)) n_coll_diff <- n_coll_diff + 1L
    # Tie-break: preferisci il ruolo "treated" (braccio caratterizzante)
    if (identical(get(sid, envir = role_by_gsm), "control") && identical(role, "treated")) {
      assign(sid, kind, envir = kind_by_gsm)
      assign(sid, role, envir = role_by_gsm)
    }
  }
}
gsms <- ls(kind_by_gsm, all.names = TRUE)
cli::cli_alert_success("kind_by_gsm: {length(gsms)} GSM rappresentanti; collisioni ruolo: {n_coll} (kind divergente: {n_coll_diff})")
rm(cache0); gc()

# ---------------------------------------------------------------------------
# 6. Lookup recovery PIENO: GSM -> identita' (legge i campi GEO grezzi dall'H5)
# ---------------------------------------------------------------------------
cli::cli_h2("6. Costruisco lookup recovery (build_name_recovery_lookup)")
t_lk <- Sys.time()
recovery_lookup <- build_name_recovery_lookup(
  h5_path      = h5_path,
  gsms         = gsms,
  kind_by_gsm  = kind_by_gsm,
  ontology_env = onto,
  cache_dir    = nr_cache_dir
)
n_recovered <- length(ls(recovery_lookup, all.names = TRUE))
src_tab <- table(vapply(ls(recovery_lookup, all.names = TRUE),
                        function(g) get(g, envir = recovery_lookup)$recovery_source %||% NA,
                        character(1L)))
cli::cli_alert_success("lookup: {n_recovered}/{length(gsms)} GSM con entry (in H5) -- {round(as.numeric(difftime(Sys.time(), t_lk, units='mins')),1)} min")
cli::cli_inform("recovery_source: {paste(sprintf('%s=%d', names(src_tab), as.integer(src_tab)), collapse=', ')}")

# ---------------------------------------------------------------------------
# 6b. Overlay correzioni LLM (v10): DUE overlay in sequenza sui GSM.
#     (1) side-table v9 (k>=2 suspects), cluster_id nello spazio v9-PRE;
#     (2) side-table FALLBACK (STR:/UNK, no filtro k, 50k override), cluster_id v9-FINAL.
#     Additivi/disgiunti: il fallback ha girato sui cluster ANCORA STR/UNK DOPO v9,
#     quindi non tocca i GSM gia' corretti dall'overlay v9. Entrambi risolti a GSM
#     via le assignments della LORO dir (spazi cluster_id diversi!) e sovrapposti al
#     recovery_lookup (fallback per ultimo -> last-wins su overlap raro). Precision-
#     gated: SOLO action=="override". OPZIONALI (senza -> v9-pre-equivalente).
# ---------------------------------------------------------------------------
source("analysis/audit/_gsm-lookup-helper.R")
rec_env <- build_record_gsm_lookup(stage2_path)          # record_id -> GSM (spazio comune)
r2g <- function(rid) {
  g <- get0(rid, envir = rec_env, inherits = FALSE)
  if (is.null(g)) character(0) else as.character(g)
}
cli::cli_h2("6b. Overlay correzioni LLM (v9 + fallback)")
n_overlay_v9 <- 0L; n_overlay_fb <- 0L
{
  s <- readRDS(Sys.getenv("SIDE_TABLE_V9", "analysis/p4-output/name-cleanup-side-table-v1.rds"))
  a <- load_stage3(Sys.getenv("STAGE3_V9PRE_DIR", "analysis/p4-output/20260710T045849Z-stage3-v9pre-364547a7"))$assignments
  ov <- simulomicsr:::.side_table_to_recovery_overlay(s, a, r2g)
  recovery_lookup <- simulomicsr:::.overlay_recovery_lookup(recovery_lookup, ov)
  n_overlay_v9 <- length(ov)
  cli::cli_alert_success("overlay v9 (k>=2): {n_overlay_v9} GSM corretti (da {sum(s$action=='override',na.rm=TRUE)} override)")
}
{
  s <- readRDS(Sys.getenv("SIDE_TABLE_FALLBACK", "analysis/p4-output/name-cleanup-fallback-side-table.rds"))
  a <- load_stage3(Sys.getenv("STAGE3_V9FINAL_DIR", "analysis/p4-output/20260717T171550Z-stage3-v9-364547a7"))$assignments
  ov <- simulomicsr:::.side_table_to_recovery_overlay(s, a, r2g)
  recovery_lookup <- simulomicsr:::.overlay_recovery_lookup(recovery_lookup, ov)
  n_overlay_fb <- length(ov)
  cli::cli_alert_success("overlay fallback (STR/UNK): {n_overlay_fb} GSM corretti (da {sum(s$action=='override',na.rm=TRUE)} override)")
}

# ---------------------------------------------------------------------------
# 7. ARCHS4 metadata (gpl/biosample per .summarize_clusters). FULL: carica;
#    SMOKE: NULL (gpl_platforms vuoto, irrilevante al recupero).
# ---------------------------------------------------------------------------
archs4_meta <- if (!SMOKE) {
  cli::cli_h2("7. ARCHS4 metadata")
  load_archs4_metadata(h5_path)
} else NULL
if (!is.null(archs4_meta)) cli::cli_alert_success("ARCHS4 metadata: {nrow(archs4_meta)} sample")

# ---------------------------------------------------------------------------
# 8. SECONDO passaggio: build_stage3_clusters CON il recovery lookup.
#    Passa la lista Stadio 2 GIA' completata + l'environment Stadio 1 GIA'
#    caricato + stage2_input=NULL (guard gia' applicato, niente doppio lavoro).
#    L'unica differenza vs il pre-pass e' name_recovery_lookup -> coerente.
# ---------------------------------------------------------------------------
cli::cli_h2("8. build_stage3_clusters (recovery ON)")
t_build <- Sys.time()
s3 <- build_stage3_clusters(
  stage1_master        = stage1_env,
  stage2_master        = stage2_master,
  config               = config,
  archs4_metadata      = archs4_meta,
  stage2_input         = NULL,                 # guard gia' applicato a monte (FULL)
  name_recovery_lookup = recovery_lookup
)
cli::cli_alert_success("build wall: {round(as.numeric(difftime(Sys.time(), t_build, units='mins')),1)} min")

# ---------------------------------------------------------------------------
# 9. Arricchisci run_metadata: name_recovery + completeness (FULL) + schema
# ---------------------------------------------------------------------------
s3$run_metadata$name_recovery <- list(
  enabled               = TRUE,
  lookup_schema_version = get_int(".NAME_RECOVERY_LOOKUP_SCHEMA_VERSION"),
  n_gsm_representatives  = length(gsms),
  n_gsm_with_entry       = n_recovered,
  kind_by_gsm_source     = "kind_effective_llm_original via .precompute_anchor_cache(recovery=NULL)",
  kind_role_collisions   = n_coll,
  kind_role_collisions_divergent = n_coll_diff,
  collision_tiebreak     = "prefer treated over control",
  recovery_source_counts = as.list(src_tab),
  overlay_v9_gsm_corrected       = n_overlay_v9,
  overlay_fallback_gsm_corrected = n_overlay_fb,
  smoke                  = SMOKE
)
s3$run_metadata$schema_versions$name_recovery_lookup <- get_int(".NAME_RECOVERY_LOOKUP_SCHEMA_VERSION")
if (!is.null(completeness_report)) {
  s3$run_metadata$output_counts$stage2_completeness <- completeness_report
}

# ---------------------------------------------------------------------------
# 10. Scrivi output (schema v3: clusters.rds, assignments.parquet, ...)
# ---------------------------------------------------------------------------
ts      <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_id  <- s3$run_metadata$run_id
suffix  <- if (SMOKE) sprintf("v10smoke-%s", run_id) else sprintf("v10-%s", run_id)
out_dir <- sprintf("analysis/p4-output/%s-stage3-%s", ts, suffix)
cli::cli_h2(sprintf("10. Scrivo output in %s", out_dir))
write_stage3_to_dir(s3, out_dir)

# ---------------------------------------------------------------------------
# 11. Sanity post-run
# ---------------------------------------------------------------------------
cl <- s3$clusters
asg <- s3$assignments
agent <- cl$agent_id_resolved
kind  <- cl$kind_effective_resolved
is_unk <- !is.na(agent) & agent == "UNK"
is_str <- !is.na(agent) & startsWith(agent, "STR:")
is_mesh <- !is.na(agent) & startsWith(agent, "MeSH:")
is_chebi <- !is.na(agent) & startsWith(agent, "CHEBI:")
is_hgnc <- !is.na(agent) & startsWith(agent, "HGNC:")
is_gen  <- !is.na(kind) & startsWith(kind, "genetic_")
rec_applied <- if ("agent_id_recovered" %in% names(cl)) sum(cl$agent_id_recovered, na.rm = TRUE) else NA_integer_
kind_rec    <- if ("kind_recovered" %in% names(cl)) sum(cl$kind_recovered, na.rm = TRUE) else NA_integer_

cli::cli_h1("SANITY v10")
cli::cli_alert_info("run_id={run_id}  (NB: deterministico da input+config; il token v10 nella dir lo distingue da v3..v9)")
cli::cli_alert_info("n_clusters    = {nrow(cl)}")
cli::cli_alert_info("n_assignments = {nrow(asg)}")
cli::cli_alert_info("copertura: sum(n_total) cluster = {sum(cl$n_total, na.rm=TRUE)} ; record assegnati = {length(unique(asg$record_id))}")
cli::cli_alert_info("agent_id_resolved: UNK(residuo U1)={sum(is_unk)} | STR:(framm)={sum(is_str)} | MeSH:={sum(is_mesh)} | CHEBI:={sum(is_chebi)} | HGNC:={sum(is_hgnc)}")
cli::cli_alert_info("kind genetic_* (K2)={sum(is_gen)} | agent recuperati (flag)={rec_applied} | kind recuperati (flag)={kind_rec}")
if ("recovery_source" %in% names(cl)) {
  rs <- table(cl$recovery_source, useNA = "no")
  cli::cli_inform("recovery_source (cluster): {paste(sprintf('%s=%d', names(rs), as.integer(rs)), collapse=', ')}")
}

# Focus disease_vs_normal: quanti cluster UNK residui vs identita' distinte recuperate
dis <- !is.na(kind) & kind == "disease_vs_normal"
cli::cli_inform("disease_vs_normal: {sum(dis)} cluster | UNK residui={sum(dis & is_unk)} | con agent recuperato (MeSH/STR)={sum(dis & !is_unk)} | identita' distinte={length(unique(agent[dis & !is_unk]))}")
sm <- !is.na(kind) & kind == "small_molecule"
cli::cli_inform("small_molecule: {sum(sm)} cluster | UNK residui={sum(sm & is_unk)} | recuperati={sum(sm & !is_unk)}")

# Confronto rapido vs v3 (disease UNK prima/dopo) -- se la dir v3 e' disponibile
if (dir.exists(v3_dir)) {
  cl_v3 <- readRDS(file.path(v3_dir, "clusters.rds"))
  v3_dis_unk <- sum(!is.na(cl_v3$kind_effective_resolved) &
                      cl_v3$kind_effective_resolved == "disease_vs_normal" &
                      !is.na(cl_v3$agent_id_resolved) & cl_v3$agent_id_resolved == "UNK")
  scope <- if (SMOKE) "(v3 GLOBALE vs v10 SUBSET: non confrontabili 1:1, solo ordine di grandezza)" else "(v3 GLOBALE vs v10 GLOBALE)"
  cli::cli_inform("CONFRONTO disease_vs_normal|UNK cluster: v3={v3_dis_unk} -> v10={sum(dis & is_unk)} {scope}")
}

# [v10] Sanity dei DUE overlay + de-frammentazione bandiera --------------------
cli::cli_h2("SANITY v10 (overlay + bandiera)")
cli::cli_alert_info("overlay applicati: v9(k>=2)={n_overlay_v9} GSM | fallback(STR/UNK)={n_overlay_fb} GSM")
if ("recovery_source" %in% names(cl)) {
  n_llm <- sum(cl$recovery_source == "LLM_NAME_CLEANUP", na.rm = TRUE)
  cli::cli_alert_info("cluster con recovery_source=LLM_NAME_CLEANUP: {n_llm} (v9-final full era 42.773; qui {if (SMOKE) 'SUBSET smoke' else 'FULL'})")
}
flag_v10 <- c("MeSH:D001943"="breast", "MeSH:D015179"="colorectal", "MeSH:D006528"="hepatocell")
for (id in names(flag_v10)) {
  sel <- !is.na(agent) & agent == id
  if (any(sel)) cli::cli_inform("  {flag_v10[id]} ({id}): {sum(sel)} cluster | max studi (k) = {max(cl$k[sel], na.rm=TRUE)}")
  else cli::cli_inform("  {flag_v10[id]} ({id}): assente nel subset")
}

cli::cli_alert_success("FINE. Wall totale: {round(as.numeric(difftime(Sys.time(), t_start, units='mins')),1)} min. Output: {out_dir}")
