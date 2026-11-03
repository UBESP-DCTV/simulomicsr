#!/usr/bin/env Rscript
# analysis/audit/2026-11-03-S5-gate-e-insiemi/10-dispatch.R
# Replica il dispatch di produzione con il gate a 3 (cancello 2) e a 2, sul deliverable e sul
# riferimento. replica_dispatch, filtra_su_h5 e stato_produzione sono copiati da
# analysis/audit/2026-08-20-rilettura-194/00-materiale.R, che ha passato le prove A e B.
# L'unica aggiunta e' il parametro k_min, passato a config$rem_group$k_eff_min.
# Uso: Rscript analysis/audit/2026-11-03-S5-gate-e-insiemi/10-dispatch.R
source("analysis/audit/2026-11-03-S5-gate-e-insiemi/01-comune.R")
suppressPackageStartupMessages(library(cli))
N_MIN <- 2L
`%||%` <- function(a, b) if (is.null(a) || !length(a) || !nzchar(a)) b else a

# Si prendono le funzioni dal file originale, senza eseguire il resto.
src <- parse("analysis/audit/2026-08-20-rilettura-194/00-materiale.R", keep.source = FALSE)
nomi <- vapply(src, function(e) if (is.call(e) && identical(e[[1]], as.name("<-"))) as.character(e[[2]])[1] else "", "")
for (n in c("replica_dispatch", "filtra_su_h5")) eval(src[[which(nomi == n)]])

campi <- c("geo_accession", "title", "series_id", "characteristics_ch1", "source_name_ch1")
all5 <- lapply(stats::setNames(campi, campi), function(x) as.character(rhdf5::h5read(H5, paste0("meta/samples/", x))))
rhdf5::h5closeAll()

carica_base <- function(s3_dir, s2_path) {
  s3 <- load_stage3(s3_dir)
  s2 <- simulomicsr:::.load_stage2_master(s2_path)
  s2 <- filtra_su_h5(s2, all5$geo_accession)
  # indice campione -> studio: la stessa regola del ciclo originale (vince l'ultimo studio)
  gse_di <- new.env(hash = TRUE, parent = emptyenv())
  for (st in s2) for (rg in st$replicate_groups) for (g in as.character(unlist(rg$sample_ids))) assign(g, st$series_id, envir = gse_di)
  list(s3 = s3, s2 = s2, s2i = simulomicsr:::.index_stage2_master(s2), gse_di = gse_di)
}

stato <- function(base, k_min) {
  s3 <- base$s3; s2i <- base$s2i
  config <- simulomicsr:::stage4_default_config()
  config$rem_group$k_eff_min <- as.integer(k_min)
  layer_a <- simulomicsr:::.identify_layer_a_clusters(s3$clusters, config)
  cli_alert_info("k_min={k_min}: {nrow(layer_a)} candidati")
  asg <- as.data.frame(s3$assignments)
  rel <- asg[asg$cluster_id %in% layer_a$cluster_id, ]
  collect_sids <- function(rid) {
    p <- simulomicsr:::.split_record_id(rid)
    if (is.na(p$series_id) || !exists(p$series_id, envir = s2i, inherits = FALSE)) return(character(0))
    st <- get(p$series_id, envir = s2i, inherits = FALSE)
    rgl <- stats::setNames(st$replicate_groups, vapply(st$replicate_groups, `[[`, character(1L), "group_id"))
    cmp <- simulomicsr:::.lookup_cmp(st, p$suffix)
    if (!is.null(cmp)) {
      tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
      if (is.null(tg) || is.null(cg)) return(character(0))
      return(c(as.character(unlist(tg$sample_ids)), as.character(unlist(cg$sample_ids))))
    }
    rg <- rgl[[p$suffix]]
    if (!is.null(rg)) return(as.character(unlist(rg$sample_ids)))
    character(0)
  }
  sids <- unique(unlist(lapply(rel$record_id, collect_sids)))
  gse <- vapply(sids, function(g) if (exists(g, envir = base$gse_di, inherits = FALSE)) get(g, envir = base$gse_di) else "", "")
  ok <- !(gse == "" | is.na(gse)); sids <- sids[ok]; gse <- gse[ok]
  i <- match(sids, all5$geo_accession)
  cli_alert_info("campioni: {length(sids)}; titolo NA: {sum(is.na(all5$title[i]))}")
  h5m <- tibble::tibble(sample_id = sids, gsm = sids, gse = unname(gse), lib_size = 1e7L,
    geo_accession = sids, title = all5$title[i], series_id = all5$series_id[i],
    characteristics_ch1 = all5$characteristics_ch1[i], source_name_ch1 = all5$source_name_ch1[i])
  qc <- simulomicsr:::.qc_filter_samples_and_studies(s3$clusters, h5m, config)
  fus <- attr(qc$eligible_clusters, "fusioni")
  if (!is.null(fus) && nrow(fus) > 0L) asg <- simulomicsr:::.reassign_absorbed_records(asg, fus)
  lane <- simulomicsr:::build_lane_library_lookup(h5m)
  cli_alert_info("corsie: {length(lane)} campioni in {length(unique(lane))} librerie")
  list(asg = asg, s2i = s2i, lane = lane, elig = qc$eligible_clusters)
}
norm <- function(x) { x <- x[order(x$cluster_id, x$study_id, x$treated_group, x$motivo, x$n_treated, x$n_control), ]; rownames(x) <- NULL; x }
keff <- function(t) as.data.table(t)[, .(k_eff = uniqueN(study_id), bracci = .N), by = cluster_id]

esegui <- function(nome, s3, s2p, pool) {
  cli_h1(nome)
  b <- carica_base(s3, s2p)
  S3 <- stato(b, 3L); R3 <- replica_dispatch(S3$elig$cluster_id, S3$asg, S3$s2i, S3$lane)
  prod <- readRDS(file.path(pool, "qc_report.rds"))$dispatch_drops
  uguali <- isTRUE(all.equal(norm(prod), norm(R3$scarti), check.attributes = FALSE))
  cat(sprintf("[%s] scarti: produzione %d, replica %d, identici: %s\n", nome, nrow(prod), nrow(R3$scarti), uguali))
  np <- as.data.table(readRDS(file.path(pool, "non_processable.rds")))
  ke <- keff(R3$tenuti)
  cand <- data.table(cluster_id = S3$elig$cluster_id)
  cand <- merge(cand, ke, by = "cluster_id", all.x = TRUE); cand[is.na(k_eff), `:=`(k_eff = 0L, bracci = 0L)]
  d <- as.data.table(readRDS(file.path(pool, "deliverable-annotato.rds")))
  cat(sprintf("[%s] candidati %d; k_eff>=3 %d, =2 %d, =1 %d, =0 %d\n", nome, nrow(cand), sum(cand$k_eff >= 3), sum(cand$k_eff == 2), sum(cand$k_eff == 1), sum(cand$k_eff == 0)))
  m <- merge(np[, .(cluster_id, qc_final_k)], cand, by = "cluster_id", all.x = TRUE)
  cat(sprintf("[%s] non_processable %d righe, k_eff uguale in %d\n", nome, nrow(np), sum(m$qc_final_k == m$k_eff, na.rm = TRUE)))
  m2 <- merge(d[, .(cluster_id, k_effective)], cand, by = "cluster_id", all.x = TRUE)
  cat(sprintf("[%s] deliverable %d meta-analisi, k_eff uguale in %d\n", nome, nrow(d), sum(m2$k_effective == m2$k_eff, na.rm = TRUE)))
  psd <- unique(as.data.table(read_parquet(file.path(pool, "per_study_de.parquet"), col_select = c("cluster_id", "study_id"))))
  kp <- sort(paste(psd$cluster_id, psd$study_id)); km <- sort(unique(paste(R3$tenuti$cluster_id, R3$tenuti$study_id)))
  cat(sprintf("[%s] coppie nel parquet %d, nella replica %d, identiche: %s; gruppi nel parquet %d\n", nome, length(kp), length(km), identical(kp, km), uniqueN(psd$cluster_id)))
  S2 <- stato(b, 2L); R2 <- replica_dispatch(S2$elig$cluster_id, S2$asg, S2$s2i, S2$lane)
  t2 <- as.data.table(R2$tenuti); t3 <- as.data.table(R3$tenuti)
  sub <- t2[cluster_id %in% t3$cluster_id]
  cols <- c("cluster_id", "study_id", "treated_group", "control_group", "n_t", "n_c", "gsm_t", "gsm_c")
  ident <- isTRUE(all.equal(sub[order(cluster_id, study_id, treated_group), ..cols], t3[order(cluster_id, study_id, treated_group), ..cols], check.attributes = FALSE))
  cat(sprintf("[%s] sui candidati del gate a 3, la replica col gate a 2 da' gli stessi bracci: %s\n", nome, ident))
  ke2 <- keff(R2$tenuti)
  cand2 <- merge(data.table(cluster_id = S2$elig$cluster_id, k_censito = S2$elig$k), ke2, by = "cluster_id", all.x = TRUE)
  cand2[is.na(k_eff), `:=`(k_eff = 0L, bracci = 0L)]
  cat(sprintf("[%s] gate a 2: candidati %d\n", nome, nrow(cand2)))
  print(cand2[, .N, keyby = .(censito = fifelse(k_censito == 2L, "2", ">=3"), k_eff = pmin(k_eff, 3L))])
  el <- as.data.table(S2$elig)[, .(cluster_id, contrast_entity, contrast_direction, contrast_control_key, canonical_name)]
  saveRDS(list(tenuti = t2, scarti = as.data.table(R2$scarti), candidati = merge(cand2, el, by = "cluster_id"), lane = S2$lane, lane3 = S3$lane),
          file.path(PES5, paste0("dispatch-", nome, ".rds")))
}
t0 <- Sys.time()
esegui("A3", A3_S3, A3_S2, POOL)
esegui("RIF", RIF_S3, RIF_S2, RIF_POOL)
cat(sprintf("durata: %.1f min\n", as.numeric(difftime(Sys.time(), t0, units = "mins"))))
