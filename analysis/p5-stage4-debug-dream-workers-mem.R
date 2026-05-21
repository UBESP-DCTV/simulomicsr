# analysis/p5-stage4-debug-dream-workers-mem.R
# Curva memoria dream vs n worker su un cluster CAPPATO (max_baseline_per_arm
# = 350). Discovery 2026-05-22: il cap funziona (cluster ~510 sample) ma
# dream a 100 worker su un cluster cappato ha usato ~120 GB — la memcurve
# precedente misurava il fallback limma, non dream. Serve un cap sui worker.
#
# Misura .run_dream_mega su pair_L4_25ee1af1 cappato (~510 sample) a
# workers {16, 32}. Watchdog a 160 GB. Usa il checkpoint.
# Usage: Rscript analysis/p5-stage4-debug-dream-workers-mem.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all("."); library(cli) })
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L); RhpcBLASctl::omp_set_num_threads(1L)
}
RPID <- Sys.getpid()
cli_h1("Curva memoria dream vs worker (cluster cappato)")
cli_alert_info("R PID = {RPID}")

h5_path <- "analysis/input/human_gene_v2.5.h5"
ck <- readRDS("analysis/p5-stage4-debug-checkpoint.rds")
elig <- ck$elig; study_dispatch <- ck$study_dispatch
stage3_enriched <- ck$stage3_enriched; config <- ck$config

# --- watchdog + sampler (attivo subito) ------------------------------------
sentinel <- "analysis/p5-stage4-debug-dreamwm.run"
memfile  <- "analysis/p5-stage4-debug-dreamwm.mem"
file.create(sentinel); writeLines(character(0), memfile)
wd <- sprintf("while [ -f %s ]; do u=$(free -m|awk '/^Mem:/{print $3}'); echo \"$(date +%%s) $u\" >> %s; if [ \"$u\" -gt 160000 ]; then echo WATCHDOG_KILL >> %s; pkill -9 -P %d 2>/dev/null; kill -9 %d; break; fi; sleep 1; done",
  sentinel, memfile, memfile, RPID, RPID)
system(paste0("bash -c ", shQuote(wd)), wait = FALSE)
cli_alert_info("watchdog attivo (kill se mem > 160 GB)")
read_peak <- function() {
  ln <- readLines(memfile); ln <- ln[grepl("^[0-9]", ln)]
  if (length(ln) == 0L) return(NA_integer_)
  max(as.integer(vapply(strsplit(ln, " "), `[`, character(1L), 2L)), na.rm = TRUE)
}

# --- assembla il cluster cappato -------------------------------------------
cid <- "pair_L4_25ee1af1"
i <- which(elig$cluster_id == cid)
matcher <- make_anchor_matcher(policy = config$mega_aug$anchor_policy,
                                relaxed_segments = config$mega_aug$relaxed_segments)
pk <- simulomicsr:::.parse_pair_anchor_key(elig$anchor_key[i], level = elig$level[i])
de <- study_dispatch[[cid]]
pcs <- list(
  cluster_id = cid, level = elig$level[i], anchor_key = elig$anchor_key[i],
  treated_anchor_key = pk$treated, control_anchor_key = pk$control,
  studies_in_cluster = elig$studies_in_cluster[[i]],
  treated_samples = list(unlist(lapply(de, function(d) d$treated))),
  control_samples = list(unlist(lapply(de, function(d) d$control))),
  treated_sample_studies = list(unlist(lapply(de, function(d) rep(d$study_id, length(d$treated))))),
  control_sample_studies = list(unlist(lapply(de, function(d) rep(d$study_id, length(d$control))))))
gb <- stage3_enriched[stage3_enriched$mode == "group" &
                        stage3_enriched$level == elig$level[i], ]
asm <- simulomicsr:::.assemble_mega_aug_metadata_bidir(
  pcs, gb, matcher, direction = "both", min_baseline_studies = 2L,
  max_baseline_per_arm = 350L)
md <- as.data.frame(asm$metadata, stringsAsFactors = FALSE)
md$study <- as.character(md$study)
cli_alert_success("cluster cappato: {nrow(md)} sample / {length(unique(md$study))} studi")

# --- fetch counts per studio (axis una volta) ------------------------------
h5_axis <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
genes <- make.unique(as.character(rhdf5::h5read(h5_path, "meta/genes/symbol")))
axis_idx <- setNames(seq_along(h5_axis), h5_axis); rm(h5_axis)
parts <- split(md$sample_id, md$study)
ml <- lapply(parts, function(ss) {
  idx <- axis_idx[ss]; idx <- idx[!is.na(idx)]
  if (length(idx) == 0L) return(NULL)
  m <- rhdf5::h5read(h5_path, "data/expression", index = list(unname(idx), NULL))
  m <- t(m); storage.mode(m) <- "integer"
  rownames(m) <- genes; colnames(m) <- names(idx); m
})
ml <- ml[!vapply(ml, is.null, logical(1L))]
counts <- do.call(cbind, ml); rm(ml, axis_idx); gc(verbose = FALSE)
md <- md[match(colnames(counts), md$sample_id), ]
md$study <- as.factor(md$study)
md$treatment <- factor(as.character(md$treatment), levels = c("control", "treated"))
cli_alert_success("counts {nrow(counts)}x{ncol(counts)}")

# --- misure ----------------------------------------------------------------
measure <- function(W) {
  cli_h2("dream workers = {W}")
  gc(verbose = FALSE); Sys.sleep(3)
  t0 <- Sys.time()
  res <- tryCatch(simulomicsr:::.run_dream_mega(counts, md, cid, workers = W),
                  error = function(e) { cli_alert_danger("err: {conditionMessage(e)}"); NULL })
  wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  Sys.sleep(2)
  peak <- read_peak()
  cli_alert_info("workers={W}: wall {round(wall,1)}s | PEAK {peak} MB ({round(peak/1024,1)} GB) | ok={!is.null(res)}")
  list(workers = W, wall = wall, peak_mb = peak, ok = !is.null(res))
}
results <- lapply(c(16L, 32L), measure)
file.remove(sentinel)

cli_h2("Risultati")
for (r in results) cli_alert_info("workers={r$workers}: peak {round(r$peak_mb/1024,1)} GB, wall {round(r$wall,1)}s")
saveRDS(results, "analysis/p5-stage4-debug-dream-workers-mem-result.rds")
cli_h1("completato")
