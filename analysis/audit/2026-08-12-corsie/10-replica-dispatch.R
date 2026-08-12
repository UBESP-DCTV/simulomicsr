# FASE 1 — La replica del dispatch, con gli SCARTI registrati.
#
# PERCHE'. `n_min` agisce dentro .build_group_rem_dispatch_from_stage3 alla riga
# 374, per ENTRY = (studio, treated_group). Il rilevatore v4 raggruppava per
# (cluster, studio, braccio): un'altra unita'. Per sapere che cosa cade con un
# n_min biologico serve il loop vero, con la stessa dedup e lo stesso ordine.
#
# CASO DI ACCETTAZIONE (obbligatorio, prima di qualunque numero): la replica deve
# riprodurre il dispatch di PRODUZIONE entry per entry e GSM per GSM.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-12-corsie"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"

del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
cl  <- readRDS(file.path(S3D, "clusters.rds"))
asg <- arrow::read_parquet(file.path(S3D, "assignments.parquet"))

s2_rds <- file.path(SC, "s2.rds")
if (file.exists(s2_rds)) {
  s2 <- readRDS(s2_rds)
} else {
  s2 <- jsonlite::stream_in(file("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"),
                            verbose = FALSE, simplifyVector = FALSE)
  saveRDS(s2, s2_rds)
}
cat("deliverable:", nrow(del), "righe | stage2:", length(s2), "studi\n")

elig <- cl[cl$cluster_id %in% del$cluster_id, ]
elig$method <- "rem_group"
stopifnot(nrow(elig) == nrow(del))

# ---- dispatch di PRODUZIONE (il riferimento) -------------------------------
disp_prod <- simulomicsr:::.build_group_rem_dispatch_from_stage3(elig, asg, s2, n_min = 2L)
cat("dispatch di produzione: cluster", length(disp_prod),
    "| entry", sum(vapply(disp_prod, length, integer(1))), "\n")

# ---- REPLICA del loop, con gli scarti --------------------------------------
s2_idx <- simulomicsr:::.index_stage2_master(s2)
asg_by <- split(asg$record_id, asg$cluster_id)

righe <- list(); disp_mio <- list()
for (i in seq_len(nrow(elig))) {
  cid <- elig$cluster_id[i]
  is_contrast <- identical(elig$mode[i], "cgroup")
  rids <- asg_by[[cid]]
  if (is.null(rids) || length(rids) == 0L) next
  cluster_dispatch <- list(); seen <- character(0)
  for (rid in rids) {
    p <- simulomicsr:::.split_record_id(rid)
    if (is.na(p$series_id)) next
    if (!exists(p$series_id, envir = s2_idx, inherits = FALSE)) next
    study <- get(p$series_id, envir = s2_idx, inherits = FALSE)
    cmp <- if (is_contrast) simulomicsr:::.lookup_cmp(study, p$suffix)
           else simulomicsr:::.lookup_cmp_by_treated_group(study, p$suffix)
    if (is.null(cmp)) next
    tg <- simulomicsr:::.lookup_rg(study, cmp$treated_group)
    cg <- simulomicsr:::.lookup_rg(study, cmp$control_group)
    if (is.null(tg) || is.null(cg)) next
    treated <- as.character(unlist(tg$sample_ids))
    control <- as.character(unlist(cg$sample_ids))
    esito <- "ammessa"
    if (length(treated) < 2L || length(control) < 2L) esito <- "sotto_n_min"
    key <- paste0(p$series_id, "||", cmp$treated_group)
    if (esito == "ammessa" && key %in% seen) esito <- "doppione_chiave"
    if (esito == "ammessa") {
      seen <- c(seen, key)
      cluster_dispatch[[length(cluster_dispatch) + 1L]] <-
        list(study_id = p$series_id, treated = treated, control = control)
    }
    righe[[length(righe) + 1L]] <- data.frame(
      cluster_id = cid, record_id = rid, study_id = p$series_id,
      treated_group = cmp$treated_group, control_group = cmp$control_group,
      n_treated = length(treated), n_control = length(control),
      esito = esito,
      gsm_treated = paste(treated, collapse = ","),
      gsm_control = paste(control, collapse = ","),
      stringsAsFactors = FALSE)
  }
  if (length(cluster_dispatch) > 0L) disp_mio[[cid]] <- cluster_dispatch
}
R <- do.call(rbind, righe)
cat("record esaminati:", nrow(R), "| ammessi:", sum(R$esito == "ammessa"),
    "| sotto n_min:", sum(R$esito == "sotto_n_min"),
    "| doppioni:", sum(R$esito == "doppione_chiave"), "\n")

# ---- CASO DI ACCETTAZIONE ---------------------------------------------------
cat("\n=== ACCETTAZIONE: la replica riproduce la produzione? ===\n")
stopifnot(identical(sort(names(disp_prod)), sort(names(disp_mio))))
cat("  [OK] stessi cluster:", length(disp_prod), "\n")
sig <- function(dl) vapply(dl, function(e)
  paste(e$study_id, paste(sort(e$treated), collapse = ","),
        paste(sort(e$control), collapse = ","), sep = "|"), character(1))
diff_n <- 0L
for (cid in names(disp_prod)) {
  a <- sig(disp_prod[[cid]]); b <- sig(disp_mio[[cid]])
  if (!identical(a, b)) { diff_n <- diff_n + 1L; if (diff_n <= 3) {
    cat("  DIVERGE:", cid, "\n"); print(setdiff(a, b)); print(setdiff(b, a)) } }
}
if (diff_n == 0L) cat("  [OK] tutte le entry identiche (studio, trattati, controlli), ordine compreso\n") else
  stop("la replica NON riproduce la produzione su ", diff_n, " cluster: fermarsi.")

saveRDS(list(R = R, disp = disp_prod), file.path(SC, "10-dispatch.rds"))
write.csv(R[, setdiff(names(R), c("gsm_treated", "gsm_control"))],
          file.path(SC, "10-record-esito.csv"), row.names = FALSE)
cat("\nscritto.\n")
