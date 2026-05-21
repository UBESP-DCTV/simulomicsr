# analysis/p5-stage4-debug-problemB-saturation.R
# DEBUGGING Problema B — curva di saturazione dell'augmentation.
#
# Per scegliere in modo scientificamente difendibile il cap sulla dimensione
# del baseline pool: prende cluster mega_aug grandi reali, e per cap crescenti
# del pool ({50,150,350,600} sample baseline PER ARM) esegue la DE con DUE
# motori e confronta:
#   - dream         : modello misto ~ treatment + (1|study)
#   - limma+dupcor  : limma-voom + duplicateCorrelation(block=study)
#
# Metriche per (cluster, cap, motore): n geni significativi (FDR<0.05),
# correlazione del logFC vs il cap massimo (= ha raggiunto il plateau?),
# wall time. + concordanza dream-vs-limma per cap.
#
# Geni FISSATI per cluster (filterByExpr sul set cap-max) cosi' i vettori
# logFC sono confrontabili tra cap e tra motori.
#
# SICUREZZA: watchdog esterno (lanciato a parte) + cluster cappati = piccoli.
# Usage: Rscript analysis/p5-stage4-debug-problemB-saturation.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all("."); library(cli) })
if (requireNamespace("RhpcBLASctl", quietly = TRUE)) {
  RhpcBLASctl::blas_set_num_threads(1L); RhpcBLASctl::omp_set_num_threads(1L)
}
`%||%` <- function(x, y) if (is.null(x)) y else x

cli_h1("Problema B — curva di saturazione augmentation (dream vs limma+dupcor)")

h5_path <- "analysis/input/human_gene_v2.5.h5"
ck <- readRDS("analysis/p5-stage4-debug-checkpoint.rds")
elig <- ck$elig; study_dispatch <- ck$study_dispatch
stage3_enriched <- ck$stage3_enriched; config <- ck$config
matcher <- make_anchor_matcher(policy = config$mega_aug$anchor_policy,
                                relaxed_segments = config$mega_aug$relaxed_segments)

CLUSTERS  <- c("pair_L4_25ee1af1", "pair_L3_42e11afe", "pair_L4_9349a22f")
CAPS      <- c(50L, 150L, 350L, 600L)   # max baseline sample PER ARM
DREAM_W   <- 8L
SEED      <- 42L

# H5 axis + geni letti una volta.
# ARCHS4 v2.5 meta/genes/symbol NON e' unico (4638/67186 simboli duplicati):
# rownames duplicati fanno fallire dream con "duplicate 'row.names'". make.unique
# rende i simboli distinti senza perdere righe.
h5_axis <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
genes_all <- make.unique(as.character(rhdf5::h5read(h5_path, "meta/genes/symbol")))
axis_idx <- setNames(seq_along(h5_axis), h5_axis)
rm(h5_axis)

fetch_counts <- function(sids, studies) {
  # fetch per studio (index h5 piccoli) -> cbind
  ord <- order(studies)
  sids <- sids[ord]; studies <- studies[ord]
  parts <- split(sids, studies)
  ml <- lapply(parts, function(ss) {
    idx <- axis_idx[ss]; idx <- idx[!is.na(idx)]
    if (length(idx) == 0L) return(NULL)
    m <- rhdf5::h5read(h5_path, "data/expression", index = list(unname(idx), NULL))
    m <- t(m); storage.mode(m) <- "integer"
    rownames(m) <- genes_all; colnames(m) <- names(idx)
    m
  })
  ml <- ml[!vapply(ml, is.null, logical(1L))]
  do.call(cbind, ml)
}

# --- motore dream -----------------------------------------------------------
run_dream <- function(counts, meta, workers) {
  rownames(meta) <- meta$sample_id   # silenzia warning filterInputData
  t0 <- Sys.time()
  res <- tryCatch({
    dge <- edgeR::DGEList(counts = counts)
    dge <- edgeR::normLibSizes(dge, method = "TMM")
    form <- ~ treatment + (1 | study)
    bp <- if (workers > 1L) BiocParallel::MulticoreParam(workers) else BiocParallel::SerialParam()
    vobj <- variancePartition::voomWithDreamWeights(dge, formula = form, data = meta, BPPARAM = bp)
    fit <- variancePartition::dream(vobj, formula = form, data = meta, BPPARAM = bp)
    fit <- variancePartition::eBayes(fit)
    lfc <- fit$coefficients[, "treatmenttreated"]
    se  <- sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"]
    p   <- fit$p.value[, "treatmenttreated"]
    list(logFC = lfc, SE = se, p = p, ok = TRUE, err = NA_character_)
  }, error = function(e) list(ok = FALSE, err = conditionMessage(e)))
  res$wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  res
}

# --- motore limma + duplicateCorrelation(block=study) -----------------------
run_limma_dc <- function(counts, meta) {
  rownames(meta) <- meta$sample_id
  t0 <- Sys.time()
  res <- tryCatch({
    dge <- edgeR::DGEList(counts = counts)
    dge <- edgeR::normLibSizes(dge, method = "TMM")
    design <- stats::model.matrix(~ treatment, data = meta)
    colnames(design) <- c("(Intercept)", "treatmenttreated")
    v <- limma::voom(dge, design)
    corr <- limma::duplicateCorrelation(v, design, block = meta$study)
    fit <- limma::lmFit(v, design, block = meta$study, correlation = corr$consensus)
    fit <- limma::eBayes(fit)
    lfc <- fit$coefficients[, "treatmenttreated"]
    se  <- sqrt(fit$s2.post) * fit$stdev.unscaled[, "treatmenttreated"]
    p   <- fit$p.value[, "treatmenttreated"]
    list(logFC = lfc, SE = se, p = p, ok = TRUE, err = NA_character_,
         consensus_cor = corr$consensus)
  }, error = function(e) list(ok = FALSE, err = conditionMessage(e)))
  res$wall <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  res
}

all_results <- list()

for (cid in CLUSTERS) {
  cli_h2("Cluster {cid}")
  i <- which(elig$cluster_id == cid)
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
  asm <- simulomicsr:::.assemble_mega_aug_metadata_bidir(
    pcs, gb, matcher = matcher, direction = config$mega_aug$direction,
    min_baseline_studies = config$mega_aug$min_baseline_studies)
  md <- as.data.frame(asm$metadata, stringsAsFactors = FALSE)
  md$study <- as.character(md$study); md$treatment <- as.character(md$treatment)

  # pair samples vs baseline
  pair_ids <- unique(c(unlist(lapply(de, function(d) d$treated)),
                        unlist(lapply(de, function(d) d$control))))
  md$is_pair <- md$sample_id %in% pair_ids
  n_pair_t <- sum(md$is_pair & md$treatment == "treated")
  n_pair_c <- sum(md$is_pair & md$treatment == "control")
  cli_alert_info("pair: {n_pair_t} treated + {n_pair_c} control | baseline tot: {sum(!md$is_pair)}")

  # subsample baseline per arm, ordine fissato (cap-N = primi N)
  set.seed(SEED)
  bl_c <- md$sample_id[!md$is_pair & md$treatment == "control"]
  bl_t <- md$sample_id[!md$is_pair & md$treatment == "treated"]
  bl_c <- sample(bl_c); bl_t <- sample(bl_t)
  cap_max <- max(CAPS)
  keep_bl <- c(head(bl_c, cap_max), head(bl_t, cap_max))
  md_max <- md[md$is_pair | md$sample_id %in% keep_bl, ]
  cli_alert_info("set cap-max: {nrow(md_max)} sample ({length(unique(md_max$study))} studi)")

  # fetch counts una volta per il superset cap-max
  cli_alert_info("fetch counts cap-max...")
  cnt_max <- fetch_counts(md_max$sample_id, md_max$study)
  md_max <- md_max[match(colnames(cnt_max), md_max$sample_id), ]

  # geni fissi: filterByExpr sul set cap-max
  dge0 <- edgeR::DGEList(counts = cnt_max)
  keep_g <- edgeR::filterByExpr(dge0, group = factor(md_max$treatment))
  genes_fixed <- rownames(cnt_max)[keep_g]
  cli_alert_info("geni fissati (filterByExpr cap-max): {length(genes_fixed)}")

  for (cap in CAPS) {
    sel <- md_max$is_pair |
      md_max$sample_id %in% c(head(bl_c, cap), head(bl_t, cap))
    md_s <- md_max[sel, ]
    md_s$study     <- droplevels(factor(md_s$study))
    md_s$treatment <- factor(md_s$treatment, levels = c("control", "treated"))
    cnt_s <- cnt_max[genes_fixed, md_s$sample_id, drop = FALSE]
    n_std <- nlevels(md_s$study)
    cli_alert_info("cap={cap}: {nrow(md_s)} sample, {n_std} studi -> dream + limma")

    rd <- run_dream(cnt_s, md_s, DREAM_W)
    rl <- run_limma_dc(cnt_s, md_s)
    cli_alert_info("  dream: {if(rd$ok) paste0('OK ', round(rd$wall,1),'s') else paste0('FAIL ', rd$err)} | limma: {if(rl$ok) paste0('OK ', round(rl$wall,1),'s') else paste0('FAIL ', rl$err)}")

    all_results[[length(all_results) + 1L]] <- list(
      cluster = cid, cap = cap, n_sample = nrow(md_s), n_study = n_std,
      dream = rd, limma = rl, genes = genes_fixed)
  }
  # Salvataggio incrementale: i risultati parziali sopravvivono a interruzioni.
  saveRDS(all_results, "analysis/p5-stage4-debug-problemB-saturation-result.rds")
  cli_alert_success("Cluster {cid} completato, risultati parziali salvati")
}

saveRDS(all_results, "analysis/p5-stage4-debug-problemB-saturation-result.rds")

# ---- Report ----------------------------------------------------------------
cli_h1("Risultati saturazione")
for (cid in CLUSTERS) {
  cli_h2("Cluster {cid}")
  rr <- Filter(function(x) x$cluster == cid, all_results)
  if (length(rr) == 0L) next
  # riferimento = cap massimo, per motore
  ref_dream <- rr[[length(rr)]]$dream
  ref_limma <- rr[[length(rr)]]$limma
  rows <- lapply(rr, function(r) {
    nsig_d <- if (r$dream$ok) sum(p.adjust(r$dream$p, "BH") < 0.05, na.rm = TRUE) else NA
    nsig_l <- if (r$limma$ok) sum(p.adjust(r$limma$p, "BH") < 0.05, na.rm = TRUE) else NA
    cor_d  <- if (r$dream$ok && ref_dream$ok) round(cor(r$dream$logFC, ref_dream$logFC, use = "complete.obs"), 4) else NA
    cor_l  <- if (r$limma$ok && ref_limma$ok) round(cor(r$limma$logFC, ref_limma$logFC, use = "complete.obs"), 4) else NA
    cor_dl <- if (r$dream$ok && r$limma$ok) round(cor(r$dream$logFC, r$limma$logFC, use = "complete.obs"), 4) else NA
    data.frame(cap = r$cap, n_sample = r$n_sample, n_study = r$n_study,
               nsig_dream = nsig_d, nsig_limma = nsig_l,
               cor_dream_vs_capmax = cor_d, cor_limma_vs_capmax = cor_l,
               cor_dream_vs_limma = cor_dl,
               wall_dream_s = round(r$dream$wall, 1),
               wall_limma_s = round(r$limma$wall, 1))
  })
  print(do.call(rbind, rows), row.names = FALSE)
}
cli_alert_success("Salvato analysis/p5-stage4-debug-problemB-saturation-result.rds")
cli_h1("Saturazione completata")
