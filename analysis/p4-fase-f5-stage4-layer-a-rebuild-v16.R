# analysis/p4-fase-f5-stage4-layer-a-rebuild-v16.R --- RE-POOL v16.
#
# COPIA DI p4-fase-f5-stage4-layer-a-rebuild-v15.R, con il solo token cambiato.
# Il codice nuovo sta nel pacchetto e si accende dalla CONFIG (decisioni utente
# 2026-08-13): `collapse_technical_lanes = TRUE` (D1), `entity_canonical` 5 voci
# (D3), `control_canonical` 2 voci condizionate all'entita' (D4), e il registro
# `qc_report$dispatch_drops` (D7).
#
# ATTESE DEPOSITATE PRIMA DEL RUN — analysis/audit/2026-08-13-rerun-prep/PREVISIONI-PRIMA-DEL-RUN.md
#   deliverable 214 -> 212 · dispatch 2.152 -> 2.146 entry · TNF 38 · ipossia 33 ·
#   SARS-CoV-2 36 · IL-6 11 · IL-15 5 · infigratinib NON nasce (k_eff 2).
# Layer A full run Stadio 4 v16 sullo Stadio 3 v16 (ancoraggio dal CONTRASTO,
# ADR-0025, + le sei regole del 2026-07-28) e master Stadio 2 v3.
#
# Differenze vs rebuild v10 (unica base di codice, nessun cambio di logica):
#   - INPUT: stage3_dir = la dir v13 (hardcoded come default, override via env
#     STAGE3_DIR per i test).
#   - DELIVERABLE: config$deliverable_methods resta il default "rem_group"
#     (ADR-0026 + decisione utente 2026-07-27). mega / mega_aug / rem restano
#     nel codice ma FUORI dal deliverable.
#   - GATE nel DRY_RUN: se compare un metodo diverso da rem_group lo script si
#     ferma con errore (la selezione non starebbe leggendo deliverable_methods).
#   - out_dir -> simulomicsr-stage4-<token>, con <token> derivato dal nome della
#     dir di Stadio 3 in ingresso.
#
# Config invariata (config uniformity): max_baseline_per_arm=350,
# dream_workers_cap=32, de_engine mega/mega_aug=dream. Il ramo rem_group non usa
# dream (REM per-studio con limma-voom + metafor), ma la config resta identica
# agli altri run per non introdurre confondenti.
#
# DRY_RUN=1 -> si ferma dopo identificazione Layer A + conteggio sample (no DE).
#
# Usage (full, detached):
#   setsid nohup Rscript analysis/p4-fase-f5-stage4-layer-a-rebuild-v16.R \
#     > analysis/audit/v16-repool-full.log 2>&1 < /dev/null &
#   ps -eo pid,sid,args | grep "[r]ebuild-v16"   # SID deve essere == PID

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all("."); library(cli) })
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L); RhpcBLASctl::omp_set_num_threads(1L)
}
DRY_RUN <- nzchar(Sys.getenv("DRY_RUN"))

cli_h1(paste0("Stadio 4 Layer A re-pool v16 (Stadio 3 v16, solo ramo rem_group)", if (DRY_RUN) " [DRY_RUN]" else ""))

# ⚠️ TROVATO PRIMA DEL LANCIO (audit 2026-08-01). La copia da `-v13.R` aveva
# aggiornato la dir di USCITA ma NON quella di INGRESSO, che puntava ancora allo
# Stadio 3 v13: il re-pool avrebbe poolato per 28 ORE i cluster vecchi
# scrivendoli in una cartella etichettata v14. Nessuno dei due gate lo intercetta
# (controllano `method == rem_group` e il prefisso `cgroup_L5_`, veri anche per
# v13). E' la stessa classe di errore che a questo progetto e' gia' costata un
# run intero. Ora la dir va passata ESPLICITAMENTE e il nome viene verificato.
stage3_dir <- Sys.getenv("STAGE3_DIR", "")
if (!nzchar(stage3_dir)) {
  stop("STAGE3_DIR non impostata: passare esplicitamente la dir dello Stadio 3 v16.\n",
       "  esempio: STAGE3_DIR=analysis/p4-output/<UTC>-stage3-v16-<run_id> Rscript ...")
}

# Il nome dell'uscita non puo' piu' contraddire l'ingresso: si deriva.
v_token <- sub("^.*-stage3-(v[0-9]+)-.*$", "\\1", basename(stage3_dir))
stopifnot(grepl("^v[0-9]+$", v_token))

# ---- SPEZZETTAMENTO (2026-08-15) --------------------------------------------
# I cluster sono indipendenti: si calcolano in processi separati e si
# ricompongono. Il motore di calcolo non cambia -- ogni pezzo esegue lo stesso
# codice sugli stessi dati, solo su meno cluster. Equivalenza misurata sui dati
# veri (analysis/audit/2026-08-13-rerun-prep/E2-equivalenza-completa.R): dati e
# registri identici. Con PEZZO/N_PEZZI assenti il comportamento e' quello di
# sempre.
#
# QUANTI PEZZI: 16, misurato sul run a 8 (2026-08-15). Qui i pezzi sono PROCESSI
# SEPARATI -- non `fork` come nello Stadio 3 -- quindi ognuno ricarica gli input
# e la memoria NON e' condivisa. I numeri del run a 8 pezzi:
#   * picco per pezzo 5,1-8,9 GB, somma dei picchi 47,6 GB su 251 (19%), e i
#     picchi non sono nemmeno simultanei -> a 16 pezzi si sta sui 95 GB;
#   * i pezzi hanno impiegato da 104 a 132 min: la ripartizione per `k`
#     decrescente bilancia bene (27% di scarto);
#   * il limite vero NON e' il numero di pezzi ma IL CLUSTER PIU' LENTO, che da
#     solo dura 48 minuti. Sotto quello non si scende con nessuna divisione.
# Stima: 8 pezzi 2h25m, 16 pezzi ~75 min, 32 pezzi ~55-60 min ma ~190 GB di
# memoria per guadagnare un quarto d'ora che il cluster piu' lento si riprende.
PEZZO   <- suppressWarnings(as.integer(Sys.getenv("PEZZO", "")))
N_PEZZI <- suppressWarnings(as.integer(Sys.getenv("N_PEZZI", "16")))
IS_SHARD <- !is.na(PEZZO) && !is.na(N_PEZZI) && N_PEZZI > 1L
if (IS_SHARD) {
  stopifnot(PEZZO >= 1L, PEZZO <= N_PEZZI)
  cli_alert_info("PEZZO {PEZZO} di {N_PEZZI}")
}

# I verdetti di coerenza sono un INGRESSO del run, non un dettaglio
# dell'annotazione: si controllano qui, al minuto zero, non dopo 28 ore.
# Il default puntava a un file inesistente e il ramo di ripiego marcava
# `coherent` TUTTE le righe con la provenienza di una rilettura mai avvenuta.
verdetti_path <- Sys.getenv("VERDETTI_PATH", "")
if (!nzchar(verdetti_path) && !nzchar(Sys.getenv("VERDETTI_ASSENTI_OK"))) {
  stop("VERDETTI_PATH non impostata. Passare il file dei verdetti di coerenza ",
       "(per v15: analysis/audit/2026-07-29-etichette-v13/verdetti-poolato-v13.csv, ",
       "riusabile perche' nessuna delle 6 chiavi tocca le entita' fuse), oppure ",
       "chiedere esplicitamente un deliverable senza coerenza con VERDETTI_ASSENTI_OK=1.")
}
if (nzchar(verdetti_path) && !file.exists(verdetti_path)) {
  stop("VERDETTI_PATH indica un file che non esiste: ", verdetti_path)
}
# GATE F4 (2026-08-03): lo schema del CSV va validato QUI, al minuto zero, non
# scoperto dopo 28 ore. Se il CSV non avesse la colonna `ckey` (o fosse
# tutta vuota/NA), `vv$ckey` piu' avanti restituirebbe NULL/NA: nessun
# orfano verrebbe rilevato dal controllo fatale post-run, e ogni gruppo
# uscirebbe marcato `coherent` per assenza di corrispondenza — lo stesso
# fallimento silenzioso "a favore della conclusione che fa comodo" gia'
# corretto per il pre-filtro dei verdetti (vedi commento piu' sotto).
if (nzchar(verdetti_path) && file.exists(verdetti_path)) {
  vv_schema_check <- utils::read.csv(verdetti_path, stringsAsFactors = FALSE)
  if (!"ckey" %in% names(vv_schema_check)) {
    stop("VERDETTI_PATH (", verdetti_path, ") non ha la colonna `ckey`: ",
         "colonne trovate: ", paste(names(vv_schema_check), collapse = ", "), ".\n",
         "  Senza `ckey` nessun orfano verrebbe rilevato e TUTTI i gruppi",
         " uscirebbero marcati `coherent`.")
  }
  if (all(!nzchar(trimws(vv_schema_check$ckey)) | is.na(vv_schema_check$ckey))) {
    stop("VERDETTI_PATH (", verdetti_path, ") ha la colonna `ckey` ma e' TUTTA vuota/NA: ",
         nrow(vv_schema_check), " righe, 0 chiavi utilizzabili.\n",
         "  Senza almeno una chiave non vuota nessun orfano verrebbe rilevato",
         " e TUTTI i gruppi uscirebbero marcati `coherent`.")
  }
  rm(vv_schema_check)
}

if (!grepl("-stage3-v16-", basename(stage3_dir), fixed = TRUE)) {
  stop("stage3_dir NON e' un output v16: ", stage3_dir, "\n",
       "  il re-pool girerebbe ~28 h su cluster vecchi producendo un file gia' visto.")
}
h5_path     <- "analysis/input/human_gene_v2.5.h5"
stage2_path <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
stopifnot(dir.exists(stage3_dir), file.exists(h5_path), file.exists(stage2_path))
cli_alert_info("Stadio 3: {.path {stage3_dir}}")

cli_alert_info("Loading stage3 + stage2_master...")
t0 <- Sys.time()
s3 <- load_stage3(stage3_dir)
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
cli_alert_success(
  "Loaded: {nrow(s3$clusters)} clusters / {nrow(s3$assignments)} assignments / {length(stage2_master)} stage2 studies (wall {round(as.numeric(difftime(Sys.time(), t0, units='secs')), 1)} sec)"
)

# Task 11: l'identita' di questo Stadio 3 e' l'impronta del CONTENUTO di
# clusters.rds, non una stringa di versione scritta a mano — e' esattamente
# il modo in cui questo progetto ha gia' perso otto ore con
# .NAME_RECOVERY_LOOKUP_SCHEMA_VERSION. Costa frazioni di secondo (~17 MB),
# una volta sola per run.
t_sha <- Sys.time()
stage3_clusters_sha256 <- digest::digest(
  file = file.path(stage3_dir, "clusters.rds"), algo = "sha256")
cli_alert_info(
  "Stadio 3 clusters.rds sha256: {stage3_clusters_sha256} (wall {round(as.numeric(difftime(Sys.time(), t_sha, units='secs')), 3)} sec)"
)

# ---- Pre-filter stage2_master vs ARCHS4 H5 sample axis (fix 2026-05-20) ----
cli_alert_info("Pre-filter stage2_master vs ARCHS4 H5 sample axis...")
t_filt <- Sys.time()
h5_samples_axis <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
cli_alert_info("H5 sample axis: {.val {length(h5_samples_axis)}} sample")
.filter_stage2_master_to_h5 <- function(stage2_master, h5_samples) {
  h5_set <- new.env(hash = TRUE, parent = emptyenv())
  for (s in h5_samples) assign(s, TRUE, envir = h5_set)
  n_dropped <- 0L; n_total <- 0L
  for (st_i in seq_along(stage2_master)) {
    rgs <- stage2_master[[st_i]]$replicate_groups
    for (rg_i in seq_along(rgs)) {
      sids <- as.character(unlist(rgs[[rg_i]]$sample_ids))
      n_total <- n_total + length(sids)
      valid <- sids[vapply(sids, exists, logical(1L), envir = h5_set, inherits = FALSE)]
      n_dropped <- n_dropped + (length(sids) - length(valid))
      stage2_master[[st_i]]$replicate_groups[[rg_i]]$sample_ids <- as.list(valid)
    }
  }
  attr(stage2_master, "h5_filter_stats") <- list(
    n_total = n_total, n_dropped = n_dropped,
    pct_dropped = 100 * n_dropped / max(1L, n_total))
  stage2_master
}
stage2_master <- .filter_stage2_master_to_h5(stage2_master, h5_samples_axis)
filt_stats <- attr(stage2_master, "h5_filter_stats")
cli_alert_success(
  "Pre-filter done in {round(as.numeric(difftime(Sys.time(), t_filt, units='secs')), 1)} sec: {.val {filt_stats$n_dropped}}/{.val {filt_stats$n_total}} sample droppati ({.val {sprintf('%.3f%%', filt_stats$pct_dropped)}}) — non in ARCHS4 H5 v2.5"
)
rm(h5_samples_axis); gc(verbose = FALSE)

# ---- Layer A identification + sample collection ---------------------------
config <- stage4_default_config()
config$mega_aug$legacy_monodirectional <- FALSE  # bidirezionale (= v7..v10)
config$compute$dream_workers_cap <- 32L
cli_alert_info("deliverable_methods: {paste(config$deliverable_methods, collapse=', ')}")
layer_a <- simulomicsr:::.identify_layer_a_clusters(s3$clusters, config)
cli_alert_info(
  "Layer A: {nrow(layer_a)} clusters (rem={sum(layer_a$method=='rem')}, mega={sum(layer_a$method=='mega')}, mega_aug={sum(layer_a$method=='mega_aug')}, rem_group={sum(layer_a$method=='rem_group')})"
)

# GATE ADR-0026: il deliverable e' il solo ramo dal-contrasto. Se compare un
# altro metodo, la selezione non sta leggendo deliverable_methods -> STOP prima
# di bruciare ~50 h di calcolo.
metodi_estranei <- setdiff(unique(layer_a$method), "rem_group")
if (length(metodi_estranei) > 0L) {
  stop(sprintf(
    "GATE ADR-0026 FALLITO: Layer A contiene metodi fuori dal deliverable (%s). La selezione non legge deliverable_methods.",
    paste(metodi_estranei, collapse = ", ")))
}
# Tutti i cgroup sono a livello 5 con prefisso cgroup_L5_ (ADR-0025).
non_cgroup <- sum(!startsWith(layer_a$cluster_id, "cgroup_L5_"))
if (non_cgroup > 0L) {
  stop(sprintf("GATE ADR-0025 FALLITO: %d cluster Layer A non hanno prefisso cgroup_L5_.", non_cgroup))
}
cli_alert_success("GATE: {nrow(layer_a)} cluster, tutti rem_group / cgroup_L5_")

# MEGA-AUG fuori dal deliverable: nessun baseline pool da matchare (il blocco
# resta per simmetria col codice dei run precedenti, ma su Layer A senza
# mega_aug produce l'insieme vuoto).
pair_aug <- layer_a[layer_a$method == "mega_aug", ]
parse_ck <- function(ak, lv) {
  s <- ak
  if (lv %in% c(0L, 1L)) s <- sub("__CT_[^_].*$", "", s)
  p <- strsplit(s, "__VS__", fixed = TRUE)[[1L]]
  if (length(p) != 2L) NA_character_ else p[2L]
}
baseline_cids <- character(0L)
for (i in seq_len(nrow(pair_aug))) {
  ck <- parse_ck(pair_aug$anchor_key[i], pair_aug$level[i])
  if (is.na(ck)) next
  matches <- s3$clusters$cluster_id[
    s3$clusters$mode == "group" & s3$clusters$level == pair_aug$level[i] &
    s3$clusters$anchor_key == ck]
  baseline_cids <- unique(c(baseline_cids, matches))
}
cli_alert_info("MEGA-AUG baseline cluster matchati: {length(baseline_cids)}")

relevant_cids <- unique(c(layer_a$cluster_id, baseline_cids))
relevant_asg <- s3$assignments[s3$assignments$cluster_id %in% relevant_cids, ]
cli_alert_info("Assignments rilevanti: {nrow(relevant_asg)}")

s2_idx <- new.env(hash = TRUE, parent = emptyenv())
for (st in stage2_master) if (!is.null(st$series_id)) assign(st$series_id, st, envir = s2_idx)
# ⚠️ FIX F1 (2026-08-03, revisione finale). Questa funzione aveva una copia
# PROPRIA della risoluzione record_id -> campioni: splittava sul primo "__" e
# cercava il resto come comparison_id ESATTO. Funzionava su v13/v14
# (record_id a due segmenti, <serie>__<comparison_id>) ma dallo Stadio 3 v16
# i record cgroup hanno TRE segmenti (<serie>__<comparison_id>__<indice>,
# R/stage3-build.R:626, fix del bug "stessa comparison_id due bracci"): il
# confronto esatto contro il terzo segmento non trova mai nulla e la funzione
# restituiva SEMPRE character(0). Misurato sull'output smoke v15
# (analysis/p4-output/20260803T000942Z-stage3-v15smoke-7418a9a0): 0 sample
# con la logica vecchia, 2813 con quella corretta sotto — vedi
# fix-finale-report.md per il numero rieseguito post-fix.
# Fix: niente seconda copia della stessa logica. Si riusano le funzioni di
# pacchetto gia' testate e gia' corrette per l'indice (R/stage4-dispatch.R):
# .split_record_id() fa lo split vero (solo sul PRIMO "__", series_id non ne
# contiene) e .lookup_cmp() risolve sia il comparison_id nudo (v13/v14) sia
# quello indicizzato (v15), con fallback a match esatto prima di provare
# l'indice.
collect_sids <- function(record_id) {
  parsed <- simulomicsr:::.split_record_id(record_id)
  if (is.na(parsed$series_id)) return(character(0L))
  if (!exists(parsed$series_id, envir = s2_idx, inherits = FALSE)) return(character(0L))
  st <- get(parsed$series_id, envir = s2_idx, inherits = FALSE)
  rg_lookup <- setNames(st$replicate_groups,
                        vapply(st$replicate_groups, `[[`, character(1L), "group_id"))
  cmp <- simulomicsr:::.lookup_cmp(st, parsed$suffix)
  if (!is.null(cmp)) {
    tg <- rg_lookup[[cmp$treated_group]]; cg <- rg_lookup[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) return(character(0L))
    return(c(as.character(unlist(tg$sample_ids)), as.character(unlist(cg$sample_ids))))
  }
  # ramo group-mode (record_id = <serie>__<group_id>, nessun indice): invariato.
  rg <- rg_lookup[[parsed$suffix]]
  if (!is.null(rg)) return(as.character(unlist(rg$sample_ids)))
  character(0L)
}
all_samples <- unique(unlist(lapply(relevant_asg$record_id, collect_sids)))
cli_alert_info("Sample IDs totali Layer A: {length(all_samples)}")

gse_for_sid <- character(length(all_samples)); names(gse_for_sid) <- all_samples
for (st in stage2_master) for (rg in st$replicate_groups) {
  sids <- as.character(unlist(rg$sample_ids)); hit <- intersect(sids, all_samples)
  if (length(hit) > 0L) gse_for_sid[hit] <- st$series_id
}
missing_gse <- sum(gse_for_sid == "" | is.na(gse_for_sid))
if (missing_gse > 0L) {
  cli_alert_warning("{.val {missing_gse}} sample senza GSE — dropped")
  ok <- !(gse_for_sid == "" | is.na(gse_for_sid))
  all_samples <- all_samples[ok]; gse_for_sid <- gse_for_sid[ok]
}
# I CINQUE CAMPI DELLE CORSIE (2026-08-15). Senza `title`,
# `characteristics_ch1` e `source_name_ch1` il collasso delle corsie non puo'
# riconoscere due letture della stessa libreria — ed e' esattamente quello che e'
# successo nel re-pool v16: quattro colonne, meccanismo spento, un warning
# sepolto fra cinquanta e 32 ore di calcolo senza il cambio che dovevano
# applicare. Ora il build si ferma se mancano; qui si leggono dall'H5.
.h5_fields <- c("geo_accession", "title", "series_id", "characteristics_ch1",
                "source_name_ch1")
.h5_all <- lapply(stats::setNames(.h5_fields, .h5_fields), function(f)
  as.character(rhdf5::h5read(h5_path, paste0("meta/samples/", f))))
rhdf5::h5closeAll()
.idx <- match(all_samples, .h5_all$geo_accession)
h5_metadata <- tibble::tibble(
  sample_id = all_samples, gsm = all_samples,
  gse = unname(gse_for_sid), lib_size = 1e7L,  # placeholder lib_size (vedi 96c43acb)
  geo_accession       = all_samples,
  title               = .h5_all$title[.idx],
  series_id           = .h5_all$series_id[.idx],
  characteristics_ch1 = .h5_all$characteristics_ch1[.idx],
  source_name_ch1     = .h5_all$source_name_ch1[.idx])
.n_no_h5 <- sum(is.na(.idx))
if (.n_no_h5 > 0L) cli_alert_warning("{.val {.n_no_h5}} campioni senza riga nell'H5: titolo NA")
rm(.h5_all, .idx)
cli_alert_success("h5_metadata: {nrow(h5_metadata)} sample, {length(.h5_fields)} campi per le corsie")

# GATE F1 (2026-08-03): un re-pool che parte con zero campioni non deve poter
# proseguire in silenzio fino a fine run (era esattamente il difetto appena
# corretto sopra in collect_sids() — senza questo controllo un altro bug dello
# stesso tipo tornerebbe a scoprirsi solo dopo ~28 ore).
stopifnot(
  "Nessun campione raccolto (h5_metadata ha 0 righe): collect_sids() non ha risolto nessun record_id -- il re-pool partirebbe da un Layer A vuoto senza errore visibile fino a fine run." =
    nrow(h5_metadata) > 0L
)

if (DRY_RUN) {
  est_h <- round(nrow(layer_a) * 164 / 3600, 1)
  cli_h2("DRY_RUN — stop pre-DE")
  cli_dl(list(
    "Layer A clusters" = nrow(layer_a),
    "  rem"       = sum(layer_a$method == "rem"),
    "  mega"      = sum(layer_a$method == "mega"),
    "  mega_aug"  = sum(layer_a$method == "mega_aug"),
    "  rem_group" = sum(layer_a$method == "rem_group"),
    "baseline pool clusters" = length(baseline_cids),
    "sample totali" = nrow(h5_metadata),
    "wall stimato (164s/cluster)" = sprintf("%.1f h", est_h)
  ))
  quit(save = "no")
}

# ---- Build Stage 4 results ------------------------------------------------
cli_h2("build_stage4_results")
cli_alert_info("dream_workers resolved: {simulomicsr:::.resolve_dream_workers(config)}")
t1 <- Sys.time()
# I cluster del pezzo: ordinati per `k` DECRESCENTE e assegnati a giro, cosi' i
# gruppi grandi (che dominano il wall: il piu' lento del v16 e' durato 48 min)
# finiscono uno per pezzo invece di ammucchiarsi nell'ultimo.
mio_subset <- NULL
if (IS_SHARD) {
  amm <- simulomicsr:::.qc_filter_samples_and_studies(s3$clusters, h5_metadata, config)$eligible_clusters
  amm <- amm[order(-amm$k, amm$cluster_id), ]
  mio_subset <- amm$cluster_id[seq_len(nrow(amm)) %% N_PEZZI == (PEZZO %% N_PEZZI)]
  cli_alert_info("pezzo {PEZZO}/{N_PEZZI}: {length(mio_subset)} cluster su {nrow(amm)}")
}
result <- build_stage4_results(
  stage3_clusters    = s3$clusters,
  h5_metadata        = h5_metadata,
  config             = config,
  h5_path            = h5_path,
  stage3_run_id      = s3$run_metadata$run_id,
  stage3_dir         = stage3_dir,
  stage3_clusters_sha256 = stage3_clusters_sha256,
  h5_path_for_hash   = h5_path,
  stage3_assignments = s3$assignments,
  stage2_master      = stage2_master,
  cluster_subset     = mio_subset
)
wall_sec <- as.numeric(difftime(Sys.time(), t1, units = "secs"))
cli_alert_success("Build complete in {round(wall_sec/60, 1)} min — run_id {result$run_metadata$run_id}")

# Un pezzo si ferma qui: salva il proprio `stage4_result` e basta. La
# ricomposizione (merge_stage4_shards), la scrittura dei parquet e l'annotazione
# le fa uno script a parte, una volta sola, quando tutti i pezzi hanno finito.
if (IS_SHARD) {
  pezzi_dir <- Sys.getenv("PEZZI_DIR", "")
  if (!nzchar(pezzi_dir)) stop("PEZZI_DIR non impostata: dove salvo il pezzo?")
  dir.create(pezzi_dir, recursive = TRUE, showWarnings = FALSE)
  f <- file.path(pezzi_dir, sprintf("pezzo-%02d-di-%02d.rds", PEZZO, N_PEZZI))
  saveRDS(result, f)
  cli_alert_success("PEZZO {PEZZO}/{N_PEZZI} scritto: {.path {f}} | pooled {nrow(result$cluster_pooled)} righe | {round(wall_sec/60,1)} min")
  quit(save = "no")
}

ts     <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
run_id <- result$run_metadata$run_id
out_root <- file.path("/mnt/wwn-0x5000039d58caca35", paste0("simulomicsr-stage4-", v_token))
out_dir  <- file.path(out_root, sprintf("%s-stage4-%s-%s", ts, v_token, run_id))
cli_alert_info("Writing to {.path {out_dir}}...")
write_stage4_to_dir(result, out_dir)
# Render dashboard NON-fatale: i deliverable DE sono gia' scritti sopra.
cli_alert_info("Rendering dashboard...")
tryCatch(render_stage4_dashboard(out_dir),
         error = function(e) cli_alert_warning("Dashboard render FALLITO (non-fatale): {conditionMessage(e)}"))

# -----------------------------------------------------------------------------
# VERIFICA VERDETTI DI COERENZA — FATALE. Le chiavi dei verdetti letti da
# VERDETTI_PATH devono essere un sottoinsieme delle chiavi del deliverable
# appena poolato: un verdetto "orfano" (il suo gruppo non e' nel poolato)
# vuol dire che il gruppo e' stato rinominato o fuso, e non aggiornarlo (FASE
# D0ter) rischia di marcare `coherent` un gruppo che era stato letto INCOERENTE.
#
# ⚠️ 2026-08-02: questo controllo stava DENTRO il tryCatch qui sotto, che lo
# declassava a warning — quindi «senza D0ter il re-pool si ferma davvero» era
# falso, in entrambi i punti dell'handout in cui era scritto. Qui fuori ferma
# sul serio, prima di scrivere il deliverable annotato (non prima delle 28 ore
# di pooling: il confronto usa le chiavi REALI del poolato appena prodotto,
# non solo quelle previste — non e' calcolabile prima).
# -----------------------------------------------------------------------------
meta_ann <- as.data.frame(
  simulomicsr:::.identify_layer_a_clusters(s3$clusters, config))
meta_ann <- meta_ann[meta_ann$cluster_id %in% unique(result$cluster_pooled$cluster_id), ]
meta_ann$ckey <- paste0(meta_ann$contrast_entity, "||", meta_ann$contrast_direction,
                        "||", meta_ann$contrast_control_key)

verdetti_ann <- if (file.exists(verdetti_path)) {
  vv <- utils::read.csv(verdetti_path, stringsAsFactors = FALSE)
  # ⚠️ CORRETTO 2026-08-01, e la versione precedente era PEGGIO di come l'avevo
  # descritta. Qui i verdetti orfani venivano tolti e solo segnalati: cosi'
  # `.annotate_coherence()` non li vedeva mai, e la sua difesa — scritta
  # apposta contro il "fallimento silenzioso a favore della conclusione che fa
  # comodo" — era disinnescata dal chiamante. Provato affiancando i due rami:
  # col pre-filtro l'annotazione RIUSCIVA e il gruppo `adenoma`, che ha un
  # verdetto di INCOERENZA, usciva marcato `coherent`.
  # Il piano diceva "l'annotazione si ferma": era falso, proseguiva.
  fuori <- setdiff(vv$ckey, meta_ann$ckey)
  if (length(fuori) > 0L) {
    stop("VERDETTI ORFANI (", length(fuori), "): ", paste(fuori, collapse = "; "),
         "\n  Il loro gruppo non e' nel poolato: senza aggiornarli (FASE D0ter)",
         " un gruppo INCOERENTE verrebbe marcato `coherent`.")
  }
  vv
} else {
  cli_alert_warning(paste0(
    "VERDETTI ASSENTI",
    if (nzchar(verdetti_path)) paste0(" (", verdetti_path, ")") else " (VERDETTI_ASSENTI_OK=1, nessun file richiesto)",
    ": le colonne di coerenza usciranno VUOTE (NA): nessun gruppo sara' dichiarato",
    " coerente ne' incoerente."))
  NULL
}

# -----------------------------------------------------------------------------
# DELIVERABLE ANNOTATO — una riga per meta-analisi, con etichetta risolta
# dall'ID, verdetto di coerenza, efficacia del pooling e materiale.
#
# Perche' e' QUI e non in uno script di audit a valle: fino al 2026-07-31 queste
# misure venivano cucite a mano dopo il run, quindi un re-pool produceva un
# deliverable senza `k_kish` — cioe' senza il numero che dice quanto il pooling
# e' davvero efficace. Ora esce dal run.
#
# NON-FATALE, come il render della dashboard: i parquet sono gia' scritti sopra
# e sono il deliverable primario. La VALIDAZIONE dei verdetti (sopra) e' invece
# fatale — qui dentro resta solo la costruzione delle etichette e la scrittura,
# che possono essere rifatte a freddo se falliscono.
# -----------------------------------------------------------------------------
cli_alert_info("Annotazione del deliverable...")
tryCatch({
  # meta_ann e verdetti_ann gia' calcolati e validati sopra, fuori dal tryCatch.

  # Etichette dei membri, per l'asse del materiale. La funzione scarta da sola
  # gli studi non poolati.
  asg_ann <- s3$assignments[
    s3$assignments$cluster_id %in% meta_ann$cluster_id, ]
  asg_ann$study <- sub("__.*$", "", asg_ann$record_id)
  lab_env <- new.env(hash = TRUE, parent = emptyenv())
  .lab_of <- function(rg, gid) {
    if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
  }
  need_ann <- unique(asg_ann$record_id)
  # ⚠️ FIX F2 (2026-08-03, revisione finale). Questo blocco COSTRUIVA rid IN
  # AVANTI (`sprintf("%s__%s", study$series_id, cmp$comparison_id)`, due
  # segmenti) e lo confrontava con `need_ann`, che dallo Stadio 3 v16 contiene
  # record_id a TRE segmenti (indice di occorrenza incluso, R/stage3-build.R:626).
  # Il confronto `!rid %in% need_ann` era SEMPRE vero (mai un agganciato) ->
  # lab_env restava vuoto -> membri_ann = NULL -> annotate_stage4_deliverable
  # prendeva i rami di ripiego che scrivono NA su n_studi_censiti,
  # stessi_membri, studi_caduti, materiale_misto, n_studi_model/primary/unknown,
  # classe_studio_dominante, dominato_da_modello: gli assi aggiunti apposta il
  # 2026-07-31 per misurare quanto il pooling e' efficace.
  #
  # Fix: si inverte la direzione. Invece di ricostruire rid dai comparisons e
  # sperare che combaci (fragile: richiederebbe replicare a mano il contatore
  # per-comparison_id di .build_contrast_group_records, rischiando un'altra
  # divergenza silenziosa), si parte dai record_id VERI delle assignments
  # (need_ann, che SONO le chiavi da risolvere) e si risolve ciascuno con le
  # stesse .split_record_id()/.lookup_cmp() di R/stage4-dispatch.R usate sopra
  # in collect_sids() — nessuna logica duplicata, nessun indice da rifare a mano.
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
  membri_ann <- do.call(rbind, lapply(seq_len(nrow(asg_ann)), function(i) {
    e <- get0(asg_ann$record_id[i], envir = lab_env, inherits = FALSE)
    if (is.null(e)) return(NULL)
    data.frame(cluster_id = asg_ann$cluster_id[i], study_id = asg_ann$study[i],
               label = e, stringsAsFactors = FALSE)
  }))

  deliverable <- annotate_stage4_deliverable(
    cluster_pooled = result$cluster_pooled,
    per_study_de   = result$per_study_de,
    cluster_meta   = meta_ann,
    member_labels  = membri_ann,
    coherence_verdicts = verdetti_ann,
    coherence_source   = "rilettura-sui-poolati-2026-07-30")

  # Task 11: la provenienza dello Stadio 3 nel deliverable stesso — un join
  # fra tabelle di run diversi si vede a occhio, senza dover riaprire il
  # run_metadata.json.
  deliverable$stage3_clusters_sha256 <- result$run_metadata$stage3$clusters_sha256

  saveRDS(deliverable, file.path(out_dir, "deliverable-annotato.rds"))
  utils::write.csv(deliverable, file.path(out_dir, "deliverable-annotato.csv"),
                   row.names = FALSE)
  cli_alert_success(paste0(
    "Deliverable annotato: ", nrow(deliverable), " meta-analisi | dominate da un ",
    "solo studio ", sum(deliverable$dominato, na.rm = TRUE), " | meno di 2 studi ",
    "efficaci ", sum(deliverable$k_kish < 2, na.rm = TRUE)))
}, error = function(e) {
  cli_alert_warning("Annotazione FALLITA (non-fatale): {conditionMessage(e)}")
  cli_alert_info("I parquet sono comunque in {.path {out_dir}}")
})

cli_h2("Layer A summary")
cli_dl(list(
  "Cluster processed"       = length(unique(result$cluster_pooled$cluster_id)),
  "Cluster non-processable" = nrow(result$non_processable),
  "Per-study DE rows"       = nrow(result$per_study_de),
  "Cluster pooled rows"     = nrow(result$cluster_pooled),
  "Significant (FDR<0.05)"  = sum(result$cluster_pooled$FDR_BH_within_cluster < 0.05, na.rm = TRUE),
  "Methods"                 = paste(sort(unique(result$cluster_pooled$method)), collapse = ", "),
  "  di cui rem_group"      = sum(result$cluster_pooled$method == "rem_group", na.rm = TRUE),
  "Run id"                  = result$run_metadata$run_id,
  "Wall total"              = sprintf("%.1f min", wall_sec / 60),
  "Output dir"              = out_dir
))
cli_alert_success("Layer A re-pool v16 OK")
