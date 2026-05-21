# analysis/p5-stage4-debug-problemB-memcurve.R
# DEBUGGING Problema B (OOM) — passo 2: curva memoria di dream.
#
# Misura il picco di memoria di sistema mentre .run_dream_mega gira sul
# cluster Layer A piu' grande (pair_L4_25ee1af1, n_input=7122) a worker
# bassi e sicuri (8, 16). Due punti -> base + pendenza GB/worker ->
# estrapolazione del cap sicuro. Cross-check col dato noto del fullrun #4
# (100 worker -> >=251 GB OOM).
#
# SICUREZZA:
#  - Watchdog bash attivo PRIMA del fetch: killa R se la mem di sistema
#    supera 170 GB (su 251). A 8/16 worker il picco atteso e' <100 GB.
#  - Fetch counts PER STUDIO (come l'orchestrator reale): index h5read
#    piccoli e ~contigui. NON un singolo h5read con 7122 indici sparsi
#    (quello espande il bounding box a ~tutto il dataset -> blowup).
#
# Usage: Rscript analysis/p5-stage4-debug-problemB-memcurve.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all("."); library(cli) })
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L); RhpcBLASctl::omp_set_num_threads(1L)
}
`%||%` <- function(x, y) if (is.null(x)) y else x

cli_h1("Problema B passo 2 — curva memoria dream")
RPID <- Sys.getpid()
cli_alert_info("R PID = {RPID}")

h5_path <- "analysis/input/human_gene_v2.5.h5"
ck <- readRDS("analysis/p5-stage4-debug-checkpoint.rds")
elig <- ck$elig; study_dispatch <- ck$study_dispatch
stage3_enriched <- ck$stage3_enriched; config <- ck$config

# ---- 0. Watchdog + sampler memoria (ATTIVO SUBITO, prima del fetch) -------
sentinel <- "analysis/p5-stage4-debug-memcurve.run"
memfile  <- "analysis/p5-stage4-debug-memcurve.mem"
file.create(sentinel); writeLines(character(0), memfile)
watchdog <- sprintf(
  "while [ -f %s ]; do u=$(free -m | awk '/^Mem:/{print $3}'); echo \"$(date +%%s) $u\" >> %s; if [ \"$u\" -gt 170000 ]; then echo WATCHDOG_KILL >> %s; pkill -9 -P %d 2>/dev/null; kill -9 %d; break; fi; sleep 1; done",
  sentinel, memfile, memfile, RPID, RPID)
# wait=FALSE backgrounda gia' il comando: NON aggiungere "&" (sh -> "& &" err).
system(paste0("bash -c ", shQuote(watchdog)), wait = FALSE)
cli_alert_info("watchdog attivo (kill se mem sistema > 170 GB)")
read_peak <- function() {
  ln <- readLines(memfile); ln <- ln[grepl("^[0-9]", ln)]
  if (length(ln) == 0L) return(NA_integer_)
  max(as.integer(vapply(strsplit(ln, " "), `[`, character(1L), 2L)), na.rm = TRUE)
}

# ---- 1. Ricostruisci il cluster mega_aug piu' grande ----------------------
cid <- "pair_L4_25ee1af1"
i <- which(elig$cluster_id == cid)
cli_alert_info("Cluster target: {cid} (level {elig$level[i]})")
matcher <- make_anchor_matcher(policy = config$mega_aug$anchor_policy,
                                relaxed_segments = config$mega_aug$relaxed_segments)
parsed_key <- simulomicsr:::.parse_pair_anchor_key(elig$anchor_key[i], level = elig$level[i])
de <- study_dispatch[[cid]]
pcs <- list(
  cluster_id = cid, level = elig$level[i], anchor_key = elig$anchor_key[i],
  treated_anchor_key = parsed_key$treated, control_anchor_key = parsed_key$control,
  studies_in_cluster = elig$studies_in_cluster[[i]],
  treated_samples = list(unlist(lapply(de, function(d) d$treated))),
  control_samples = list(unlist(lapply(de, function(d) d$control))),
  treated_sample_studies = list(unlist(lapply(de, function(d) rep(d$study_id, length(d$treated))))),
  control_sample_studies = list(unlist(lapply(de, function(d) rep(d$study_id, length(d$control))))))
gb <- stage3_enriched[stage3_enriched$mode == "group" &
                        stage3_enriched$level == elig$level[i], ]
assembled <- simulomicsr:::.assemble_mega_aug_metadata_bidir(
  pcs, gb, matcher = matcher, direction = config$mega_aug$direction,
  min_baseline_studies = config$mega_aug$min_baseline_studies)
md <- as.data.frame(assembled$metadata, stringsAsFactors = FALSE)
md$study <- as.character(md$study)
cli_alert_success("metadata: {nrow(md)} sample | dup: {anyDuplicated(md$sample_id)}")

# ---- 2. Fetch counts PER STUDIO (axis letto una volta; cache su RDS) ------
counts_cache <- "analysis/p5-stage4-debug-memcurve-counts.rds"
if (file.exists(counts_cache)) {
  cli_alert_info("Counts cache trovata, carico {counts_cache}")
  cc <- readRDS(counts_cache)
  counts <- cc$counts; md <- cc$md
} else {
cli_alert_info("Fetch counts da H5 (per studio)...")
t0 <- Sys.time()
h5_axis <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
genes   <- as.character(rhdf5::h5read(h5_path, "meta/genes/symbol"))
axis_idx <- setNames(seq_along(h5_axis), h5_axis)
rm(h5_axis)
all_studies <- unique(md$study)
counts_list <- vector("list", length(all_studies))
for (k in seq_along(all_studies)) {
  ss  <- md$sample_id[md$study == all_studies[k]]
  idx <- axis_idx[ss]; idx <- idx[!is.na(idx)]
  if (length(idx) == 0L) next
  m <- rhdf5::h5read(h5_path, "data/expression", index = list(unname(idx), NULL))
  m <- t(m); storage.mode(m) <- "integer"
  rownames(m) <- genes; colnames(m) <- names(idx)
  counts_list[[k]] <- m
  if (k %% 50L == 0L) cli_alert_info("  studi fetchati: {k}/{length(all_studies)}")
}
counts_list <- counts_list[!vapply(counts_list, is.null, logical(1L))]
counts <- do.call(cbind, counts_list)
rm(counts_list, axis_idx); gc(verbose = FALSE)
md <- md[match(colnames(counts), md$sample_id), , drop = FALSE]
cli_alert_success("counts {nrow(counts)}x{ncol(counts)} in {round(as.numeric(difftime(Sys.time(),t0,units='secs')),1)}s | size {round(as.numeric(object.size(counts))/1e9,2)} GB")
saveRDS(list(counts = counts, md = md), counts_cache)
cli_alert_info("Counts cache salvata: {counts_cache}")
}

# .run_dream_mega richiede study/treatment come factor (study clobberato a
# character per il grouping del fetch). treatment resta gia' factor.
md$study <- as.factor(md$study)

# ---- 3. Misure dream a worker bassi e sicuri ------------------------------
measure <- function(W) {
  cli_h2("dream workers = {W}")
  gc(verbose = FALSE); Sys.sleep(3)
  t0 <- Sys.time()
  res <- tryCatch(
    simulomicsr:::.run_dream_mega(counts, md, cid, workers = W),
    error = function(e) { cli_alert_danger("dream error: {conditionMessage(e)}"); NULL })
  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  Sys.sleep(2)
  peak <- read_peak()
  cli_alert_info("wall {round(wall,1)}s | PEAK sistema {peak} MB ({round(peak/1024,1)} GB)")
  list(workers = W, wall = wall, mem_peak_mb = peak, ok = !is.null(res))
}
results <- list()
for (W in c(8L, 16L)) results[[as.character(W)]] <- measure(W)

file.remove(sentinel)
res_df <- do.call(rbind, lapply(results, function(r)
  data.frame(workers = r$workers, wall_s = round(r$wall, 1),
             mem_peak_gb = round(r$mem_peak_mb / 1024, 1), ok = r$ok)))
cli_h2("Risultati curva memoria")
print(res_df, row.names = FALSE)

if (nrow(res_df) >= 2L && all(res_df$ok)) {
  fit <- lm(mem_peak_gb ~ workers, data = res_df)
  base <- coef(fit)[[1L]]; slope <- coef(fit)[[2L]]
  cli_alert_info("modello: peak_GB ~ {round(base,1)} + {round(slope,2)} * workers (cluster 7122 sample)")
  cli_alert_info("cross-check: a 100 worker -> {round(base + slope*100,0)} GB (fullrun #4 osservato: >=251, OOM)")
  for (budget in c(150, 170, 200)) {
    cli_alert_info("cap per stare sotto {budget} GB su QUESTO cluster: {floor((budget-base)/slope)} worker")
  }
}
saveRDS(results, "analysis/p5-stage4-debug-problemB-memcurve-result.rds")
cli_alert_success("Salvato")
cli_h1("Problema B passo 2 completato")
