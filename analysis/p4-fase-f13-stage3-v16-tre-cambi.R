#!/usr/bin/env Rscript
# analysis/p4-fase-f13-stage3-v16-tre-cambi.R --- RE-CLUSTER Stadio 3 v16.
#
# COPIA DI p4-fase-f12-stage3-v15-defrag.R (lo script che ha prodotto v15), con
# UNA sola differenza voluta: il token di versione. Il codice nuovo NON sta qui,
# sta nel pacchetto: e' D2, il confine del marcatore genetico
# (`R/stage3-row-pairing.R`, decisione utente 2026-08-13), che il gate di riga
# chiama da solo dentro `.ca_member_contrast()`.
#
# D1 (corsie) e D3+D4 (le due mappe) NON toccano lo Stadio 3: agiscono nel
# dispatch e nella dedup dello Stadio 4. Qui cambia solo quali MEMBRI entrano
# nei cluster.
#
# ATTESE DEPOSITATE PRIMA DEL RUN
#   analysis/audit/2026-08-13-rerun-prep/PREVISIONI-PRIMA-DEL-RUN.md
#   * 5 confronti in piu' scartati con `riga_genetica_asimmetrica` fra i 351
#     candidati (v15: 0), in 3 gruppi: ATRA, Nutlin-3a, bleomicina;
#   * sul corpus: +271 confronti scartati, -77 non piu' scartati, in 132 studi;
#   * un solo `k` di Stadio 3 cambia fra i gruppi del deliverable: la bleomicina
#     `cgroup_L5_79ce3bd1`, 10 -> 9;
#   * i pavimenti bandiera NON devono scendere. Se scendono: FERMARSI e misurare.
#
# LIMITE DICHIARATO: gli effetti di secondo ordine (un `k` che cala puo' cambiare
# chi vince la dedup per entita') non sono misurabili senza questo run.
#
# --- testa dello script v15 conservata sotto ---------------------------------
# RE-CLUSTER Stadio 3 v15: MATERIALIZZA L'ANCORAGGIO DAL-CONTRASTO (ADR-0025).
#
# COPIA DI p4-fase-f8-stage3-v10-final.R (lo script che ha prodotto v10), con
# UNA sola differenza voluta: il token di versione e la dir di output. Il codice
# nuovo NON sta qui — sta nel pacchetto (`.build_contrast_group_records()` in
# R/stage3-build.R + R/stage3-contrast-anchor.R), che `build_stage3_clusters()`
# chiama da solo. Questo script resta quello di v10 perche' i DUE overlay di
# correzione dei nomi (v9 k>=2 + fallback STR/UNK, ADR-0023/0024) sono la base su
# cui sono stati misurati i 144 gruppi: senza, il recupero-nome regredisce e i
# pavimenti bandiera non tengono.
#
# NOVITA' v12 rispetto a v10 (dal pacchetto, non da qui):
#   i record di gruppo nascono dal CONTRASTO (delta trattato<->controllo) e non
#   dalla perturbazione del campione trattato. Modo nuovo `cgroup`, livello unico
#   5, chiave <entita' del delta> || <verso> || <tipo di controllo>. I modi
#   `pair` e `group` NON cambiano (test di non-regressione).
#
# NOVITA' v13 rispetto a v12 (dal pacchetto): le SEI regole derivate dal
# censimento dei 312 gruppi (finding 2026-07-28). Chiudono cinque meccanismi di
# incoerenza e la frammentazione dei controlli sinonimi.
#
# PAVIMENTI BANDIERA = i valori MISURATI su v12:
#   SARS-CoV-2 k>=38 · TGFB1 k>=61 · LPS k>=41 · enzalutamide k>=29 ·
#   vemurafenib k>=19   (stima post-regole: TGFB1 65, LPS 50, vemurafenib 20)
# Se scendono: FERMARSI e misurare, non aggiustare la regola.
#
# --- testa dello script v10 conservata sotto ---------------------------------
# RE-CLUSTER Stadio 3 col rework "recupero-nome" (name-recovery) PIU' DUE
# overlay di correzioni LLM: (1) side-table v9 (k>=2 suspects), (2) side-table
# FALLBACK finale (STR:/UNK, no filtro k, 50.246 override).
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
#       Rscript analysis/p4-fase-f13-stage3-v16-tre-cambi.R
#   FULL RUN (gate utente separato, ~8h; NON lanciare senza ok; usare setsid):
#       SMOKE=0 Rscript analysis/p4-fase-f13-stage3-v16-tre-cambi.R
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

cli::cli_h1(sprintf("Re-cluster Stadio 3 v16 (D2: il confine del marcatore genetico) -- modalita': %s",
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

    # [v15] Lo smoke DEVE esercitare la de-frammentazione: senza questo la sua
    # intersezione con i 38 studi toccati e' ZERO (misurato sul subset di v14) e
    # lo smoke passa verde senza aver provato la sola cosa nuova del run.
    dfg_dump <- "analysis/audit/2026-07-31-defrag/impatto-membri-v5.rds"
    if (file.exists(dfg_dump)) {
      dd  <- readRDS(dfg_dump)
      tok <- gsub("[^a-z0-9]", "", tolower(sub("^STR:", "", dd$ent_off)))
      dfg_series <- unique(dd$study[!is.na(dd$src_off) & dd$src_off == "STR" &
                                      tok %in% c("tgfb", "il17")])
      smoke_target_series <- unique(c(dfg_series, smoke_target_series))
      cli::cli_alert_info("[v15] +{length(dfg_series)} serie che esercitano la de-frammentazione")
    } else {
      cli::cli_alert_warning("[v15] dump della de-frammentazione assente: lo smoke NON la esercita")
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
suffix  <- if (SMOKE) sprintf("v16smoke-%s", run_id) else sprintf("v16-%s", run_id)
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

cli::cli_h1("SANITY v16")
cli::cli_alert_info("run_id={run_id}  (NB: deterministico da input+config; il token v13 nella dir lo distingue da v3..v12)")
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
  scope <- if (SMOKE) "(v3 GLOBALE vs v13 SUBSET: non confrontabili 1:1, solo ordine di grandezza)" else "(v3 GLOBALE vs v13 GLOBALE)"
  cli::cli_inform("CONFRONTO disease_vs_normal|UNK cluster: v3={v3_dis_unk} -> v10={sum(dis & is_unk)} {scope}")
}

# [v10] Sanity dei DUE overlay + de-frammentazione bandiera --------------------
cli::cli_h2("SANITY v16 (overlay + bandiera)")
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

# [v12] Sanity del ramo DAL-CONTRASTO (ADR-0025) ------------------------------
# Questi controlli sono il gate del run: se il ramo cgroup non c'e', il run non
# ha materializzato niente di nuovo e va fermato, non interpretato.
cli::cli_h2("SANITY v16 (ancoraggio dal-contrasto)")
is_cg <- !is.na(cl$mode) & cl$mode == "cgroup"
cli::cli_alert_info("cluster mode=cgroup: {sum(is_cg)} su {nrow(cl)} totali")
if (sum(is_cg) == 0L) {
  cli::cli_alert_danger("NESSUN cluster cgroup: il ramo ADR-0025 non ha prodotto niente. FERMARSI.")
} else {
  lv <- unique(cl$level[is_cg])
  cli::cli_alert_info("level dei cgroup: {paste(lv, collapse=',')} (atteso: 5)")
  n_id_ok <- sum(startsWith(cl$cluster_id[is_cg], "cgroup_L5_"))
  cli::cli_alert_info("cluster_id con prefisso cgroup_L5_: {n_id_ok}/{sum(is_cg)}")
  for (col in c("contrast_entity", "contrast_direction", "contrast_control_key")) {
    if (!col %in% names(cl)) {
      cli::cli_alert_danger("  colonna {col} ASSENTE")
    } else {
      cli::cli_alert_info("  {col}: {sum(!is.na(cl[[col]][is_cg]))}/{sum(is_cg)} popolate")
    }
  }
  # Poolabili k>=3 (soglia ADR-0022/0025, non ancora ri-aperta)
  k_cg <- cl$k[is_cg]
  cli::cli_alert_info("cgroup poolabili k>=3: {sum(k_cg >= 3L, na.rm=TRUE)} | k>=5: {sum(k_cg >= 5L, na.rm=TRUE)} | k max: {max(k_cg, na.rm=TRUE)}")
}

# --- GATE DELLA DE-FRAMMENTAZIONE -------------------------------------------
# Senza questo, un run in cui la regola non fa NULLA passa verde: il pavimento
# di TGFB1 e' 61 e v13 ne da' gia' 65. Misurato il 2026-08-02.
if ("contrast_entity_source" %in% names(cl)) {
  n_dfg <- sum(cl$contrast_entity_source == "defrag", na.rm = TRUE)
  cli::cli_alert_info("cluster con entita' dalla de-frammentazione: {n_dfg}")
  if (!SMOKE && n_dfg == 0L)
    stop("La de-frammentazione non ha prodotto NULLA: 0 cluster con ",
         "contrast_entity_source=='defrag'. FERMARSI e capire perche'.")
} else {
  stop("colonna contrast_entity_source assente: impossibile verificare la ",
       "de-frammentazione. FERMARSI.")
}
# Post-condizioni falsificabili, misurate su v13 (dove valgono 65 e 8).
if (!SMOKE) {
  k_of <- function(id) {
    s <- is_cg & !is.na(cl$contrast_entity) & cl$contrast_entity == id
    if (any(s)) max(cl$k[s], na.rm = TRUE) else 0L
  }
  for (chk in list(list(id = "HGNC:11766", min = 66L, nome = "TGFB1"),
                   list(id = "HGNC:5981",  min = 9L,  nome = "IL17A"))) {
    kk <- k_of(chk$id)
    if (kk < chk$min)
      stop(sprintf("%s (%s): k=%d, atteso > %d. La fusione non e' avvenuta.",
                   chk$nome, chk$id, kk, chk$min - 1L))
    cli::cli_alert_success("{chk$nome}: k={kk} (atteso > {chk$min - 1L}) OK")
  }
  # Le forme STR: delle entita' fuse non devono sopravvivere.
  residui <- unique(cl$contrast_entity[is_cg & !is.na(cl$contrast_entity) &
    gsub("[^a-z0-9]", "", tolower(sub("^STR:", "", cl$contrast_entity))) %in%
      c("tgfb", "il17") & startsWith(cl$contrast_entity, "STR:")])
  if (length(residui) > 0L)
    stop("residui STR: delle entita' fuse: ", paste(residui, collapse = ", "))
}

# Pavimenti bandiera: censimento 2026-07-27 DOPO le tre correzioni del 2026-07-26.
# (smoke-bandiera.csv e' anteriore e riporta TGFB1 27 / enza 21: STALE.)
if (sum(is_cg) > 0L && "contrast_entity" %in% names(cl)) {
  # Pavimenti = i valori MISURATI su v12 (non le stime): le sei regole non devono
  # far scendere nessuna bandiera. La stima dice TGFB1 65, LPS 50, vemurafenib 20:
  # se crescono e' un guadagno, se scendono ci si ferma e si misura.
  pav <- c("NCBITaxon:2697049" = 38L, "HGNC:11766" = 61L, "CHEBI:16412" = 41L,
           "CHEBI:68534" = 29L, "CHEBI:63637" = 19L)
  nomi <- c("NCBITaxon:2697049" = "SARS-CoV-2", "HGNC:11766" = "TGFB1",
            "CHEBI:16412" = "LPS", "CHEBI:68534" = "enzalutamide",
            "CHEBI:63637" = "vemurafenib")
  cli::cli_h3(sprintf("Bandiera (%s)", if (SMOKE) "SUBSET smoke: NON confrontabile coi pavimenti" else "FULL: confronto vero"))
  for (id in names(pav)) {
    sel <- is_cg & !is.na(cl$contrast_entity) & cl$contrast_entity == id
    kmax <- if (any(sel)) max(cl$k[sel], na.rm = TRUE) else 0L
    esito <- if (SMOKE) "(smoke)" else if (kmax >= pav[[id]]) "OK" else "SOTTO IL PAVIMENTO -- FERMARSI E MISURARE"
    cli::cli_inform("  {nomi[id]} ({id}): k={kmax} (pavimento {pav[[id]]}) {esito}")
  }
}

cli::cli_alert_success("FINE. Wall totale: {round(as.numeric(difftime(Sys.time(), t_start, units='mins')),1)} min. Output: {out_dir}")
