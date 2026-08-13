# §5 — LE PREVISIONI, DEPOSITATE PRIMA DEL RUN.
#
# Si calcolano sui 351 candidati veri (v15) applicando i tre cambi UNO SOPRA
# L'ALTRO, col codice di produzione:
#   D1 corsie accese  -> `.n_biological` dentro il dispatch
#   D2 confine        -> i membri con la genetica su un braccio solo non entrano
#   D3+D4 mappe       -> i cluster fusi contano come un gruppo solo
#
# LIMITE DICHIARATO: il `k_eff` da dispatch non applica il pre-filtro H5 del
# re-pool (campioni assenti, lib_size < 500k) ed e' quindi un LIMITE SUPERIORE.
# Su v15 lo scarto misurato era 0 su tutti e 214.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-13-rerun-prep"
OLD <- "analysis/audit/2026-08-12-corsie"
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"

cl  <- readRDS(file.path(S3D, "clusters.rds"))
asg <- arrow::read_parquet(file.path(S3D, "assignments.parquet"))
s2  <- readRDS(file.path(OLD, "s2.rds")); idx <- simulomicsr:::.index_stage2_master(s2)
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
lk  <- readRDS(file.path(SC, "D1-lookup.rds"))
cfg <- stage4_default_config()

A <- .identify_layer_a_clusters(cl, cfg)
A <- A[A$method == "rem_group", , drop = FALSE]
fus <- attr(.identify_layer_a_clusters(cl, cfg), "fusioni")
cat("candidati:", nrow(A), "| fusioni:", nrow(fus), "\n")

# insieme dei cluster_id che compongono ogni candidato (vincente + assorbiti)
comp <- setNames(as.list(A$cluster_id), A$cluster_id)
if (nrow(fus)) for (w in unique(fus$cluster_id_vincente))
  if (w %in% names(comp))
    comp[[w]] <- c(w, fus$cluster_id_assorbito[fus$cluster_id_vincente == w])

asg_by <- split(asg$record_id, asg$cluster_id)
lab <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
flj <- function(rg) { fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";") }

# --- D2: i record_id da togliere, gruppo per gruppo -------------------------
ent_of <- setNames(A$contrast_entity, A$cluster_id)
tolti <- character(0); righe_d2 <- list()
for (cid in names(comp)) {
  rids <- unlist(asg_by[intersect(comp[[cid]], names(asg_by))], use.names = FALSE)
  if (!length(rids)) next
  for (rid in rids) {
    p <- simulomicsr:::.split_record_id(rid)
    if (is.na(p$series_id) || !exists(p$series_id, envir = idx, inherits = FALSE)) next
    st <- get(p$series_id, envir = idx, inherits = FALSE)
    cmp <- simulomicsr:::.lookup_cmp(st, p$suffix); if (is.null(cmp)) next
    tg <- simulomicsr:::.lookup_rg(st, cmp$treated_group)
    cg <- simulomicsr:::.lookup_rg(st, cmp$control_group)
    if (is.null(tg) || is.null(cg)) next
    tl <- lab(tg, cmp$treated_group); cl_ <- lab(cg, cmp$control_group)
    d <- simulomicsr:::.ca_delta(flj(tg), flj(cg))
    if (simulomicsr:::.rp_genetic_asymmetry(tl, cl_, d$dominant_class, unname(ent_of[cid]))) {
      tolti <- c(tolti, rid)
      righe_d2[[length(righe_d2) + 1L]] <- data.frame(
        cluster_id = cid, record_id = rid, study = p$series_id,
        trattato = substr(tl, 1, 80), controllo = substr(cl_, 1, 80),
        stringsAsFactors = FALSE)
    }
  }
}
R2 <- if (length(righe_d2)) do.call(rbind, righe_d2) else data.frame()
cat("D2: membri scartati sui 351 candidati:", length(tolti), "in",
    length(unique(R2$cluster_id)), "gruppi\n")
if (nrow(R2)) write.csv(R2, file.path(SC, "P5-d2-scartati.csv"), row.names = FALSE)

# --- k_eff con tutto acceso -------------------------------------------------
keff <- function(rids, lane) {
  if (!length(rids)) return(0L)
  synth <- data.frame(record_id = rids, cluster_id = "__X__", stringsAsFactors = FALSE)
  el <- data.frame(cluster_id = "__X__", mode = "cgroup", method = "rem_group",
                   stringsAsFactors = FALSE)
  d <- .build_group_rem_dispatch_from_stage3(el, synth, s2, n_min = 2L, lane_lookup = lane)
  if (!length(d)) return(0L)
  length(unique(vapply(d[["__X__"]], function(x) x$study_id, character(1))))
}
out <- do.call(rbind, lapply(names(comp), function(cid) {
  rids <- unlist(asg_by[intersect(comp[[cid]], names(asg_by))], use.names = FALSE)
  r_d2 <- setdiff(rids, tolti)
  data.frame(cluster_id = cid,
             entita = unname(ent_of[cid]),
             nome = del$canonical_name[match(cid, del$cluster_id)],
             nel_214 = cid %in% del$cluster_id,
             k_s3 = A$k[match(cid, A$cluster_id)],
             keff_v15   = keff(rids, NULL),
             keff_tutto = keff(r_d2, lk),
             stringsAsFactors = FALSE)
}))
out$passa_v15   <- out$keff_v15   >= 3L
out$passa_dopo  <- out$keff_tutto >= 3L
cat("\n=== PREVISIONE ===\n")
cat("candidati:", nrow(out), "| passano il gate k_eff>=3 oggi:", sum(out$passa_v15),
    "| dopo i tre cambi:", sum(out$passa_dopo), "\n")
cat("escono:", paste(out$cluster_id[out$passa_v15 & !out$passa_dopo], collapse = " "), "\n")
cat("  nomi:", paste(out$nome[out$passa_v15 & !out$passa_dopo], collapse = " | "), "\n")
cat("entrano:", paste(out$cluster_id[!out$passa_v15 & out$passa_dopo], collapse = " "), "\n")
cat("  entita:", paste(out$entita[!out$passa_v15 & out$passa_dopo], collapse = " | "), "\n")
cat("righe del 214 assorbite da una fusione:",
    sum(fus$cluster_id_assorbito %in% del$cluster_id), "\n")
sposta <- out[out$keff_v15 != out$keff_tutto, ]
cat("\ngruppi col k_eff cambiato:", nrow(sposta), "\n")
print(sposta[order(-abs(sposta$keff_tutto - sposta$keff_v15)),
             c("cluster_id", "nome", "entita", "keff_v15", "keff_tutto", "nel_214")], row.names = FALSE)
saveRDS(out, file.path(SC, "P5-previsioni.rds"))
write.csv(out, file.path(SC, "P5-previsioni.csv"), row.names = FALSE)
