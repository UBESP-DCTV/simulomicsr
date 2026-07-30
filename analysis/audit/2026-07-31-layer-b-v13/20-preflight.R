# analysis/audit/2026-07-31-layer-b-v13/20-preflight.R
# PRE-FLIGHT del Layer B v13: verifica, PRIMA di lanciare il build, che ogni
# cluster della selezione si risolva in campioni veri e che il numero di studi
# risolti coincida con il k_effective del pool.
#
# Il bug del 2026-07-23 era esattamente questo: la macchina Layer B non
# conosceva il ramo del deliverable, il dispatch tornava vuoto e il build
# crashava a meta'. Qui si misura prima, senza leggere l'H5.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/20-preflight.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
  library(cli)
})

stage4_dir    <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
stage3_dir    <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
stage2_path   <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
selection_csv <- "analysis/layer-b-selection-v13.csv"

stopifnot(dir.exists(stage4_dir), dir.exists(stage3_dir),
          file.exists(stage2_path), file.exists(selection_csv))

cli_h1("Pre-flight Layer B v13")

sel <- simulomicsr:::.load_layer_b_selection(selection_csv)
cli_alert_info("Selezione: {nrow(sel)} cluster.")

# --- 1. i cluster esistono nel Layer A v13? ---------------------------------
val <- layer_b_validate_selection(selection_csv, stage4_dir)
if (any(!val$exists_in_stage4)) {
  cli_abort("Assenti dal Layer A: {val$cluster_id[!val$exists_in_stage4]}")
}
cli_alert_success("1/5 tutti i {nrow(val)} cluster esistono nel Layer A v13.")

# --- 2. method e' quello atteso? -------------------------------------------
#
# ⚠️ `k_effective` in cluster_pooled e' PER-GENE, non per-cluster: un gene
# assente in alcuni studi ha meno studi che contribuiscono. Confrontare il
# dispatch con un k_effective pescato a caso (match()) e' un metro cieco — mio
# errore, visto e corretto qui: 12 cluster danno 219 combinazioni distinte.
# Il k del deliverable e' il MASSIMO per cluster: quello e' il termine di
# confronto giusto per il numero di studi risolti.
cp_raw <- arrow::open_dataset(file.path(stage4_dir, "cluster_pooled.parquet")) |>
  dplyr::filter(cluster_id %in% sel$cluster_id) |>
  dplyr::select(cluster_id, method, k_effective) |>
  dplyr::collect()
methods <- unique(cp_raw$method)
if (!identical(methods, "rem_group")) {
  cli_abort("Method inatteso nella selezione: {methods}")
}
cp_meta <- cp_raw |>
  dplyr::group_by(cluster_id) |>
  dplyr::summarise(
    method       = unique(method),
    k_eff_max    = max(k_effective, na.rm = TRUE),
    k_eff_min    = min(k_effective, na.rm = TRUE),
    k_eff_median = stats::median(k_effective, na.rm = TRUE),
    .groups = "drop"
  )
cli_alert_success("2/5 method = rem_group su tutte le {nrow(cp_raw)} righe dei {nrow(cp_meta)} cluster.")

# --- 3. il dispatch li risolve? --------------------------------------------
s3 <- load_stage3(stage3_dir)
assignments <- s3$assignments
stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)

meta <- s3$clusters[s3$clusters$cluster_id %in% sel$cluster_id, ]
meta$method <- cp_meta$method[match(meta$cluster_id, cp_meta$cluster_id)]
deliv <- readRDS("analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds")
cli_alert_info("mode dei cluster selezionati: {paste(names(table(meta$mode)), table(meta$mode), sep='=', collapse=' ')}")

study_dispatch <- simulomicsr:::.build_study_dispatch_from_stage3(
  meta, assignments, stage2_master)
group_rem_dispatch <- simulomicsr:::.build_group_rem_dispatch_from_stage3(
  meta, assignments, stage2_master, n_min = 2L)
group_dispatch <- simulomicsr:::.build_group_dispatch_from_stage3(
  meta, assignments, stage2_master)

cli_alert_info(paste0(
  "dispatch: study(pair)=", length(study_dispatch),
  " group_rem=", length(group_rem_dispatch),
  " group(mega)=", length(group_dispatch)))

resolved <- union(names(study_dispatch), names(group_rem_dispatch))
unresolved <- setdiff(sel$cluster_id, resolved)
if (length(unresolved) > 0L) {
  cli_abort("NON risolti dal dispatch: {unresolved}")
}
cli_alert_success("3/5 tutti e {length(sel$cluster_id)} risolti dal dispatch.")

# --- 4. il numero di studi risolti coincide col k_effective del pool? -------
disp <- c(study_dispatch, group_rem_dispatch)
chk <- do.call(rbind, lapply(sel$cluster_id, function(cid) {
  items <- disp[[cid]]
  studi <- unique(vapply(items, function(x) x$study_id, character(1L)))
  n_samp <- sum(vapply(items, function(x) length(x$treated) + length(x$control), integer(1L)))
  j <- match(cid, cp_meta$cluster_id)
  data.frame(
    cluster_id   = cid,
    n_bracci     = length(items),
    n_studi      = length(studi),
    k_deliv      = deliv$k_effective[match(cid, deliv$cluster_id)],
    k_pool_max   = cp_meta$k_eff_max[j],
    k_pool_med   = cp_meta$k_eff_median[j],
    k_pool_min   = cp_meta$k_eff_min[j],
    n_campioni   = n_samp,
    stringsAsFactors = FALSE
  )
}))
chk$ok <- chk$n_studi == chk$k_deliv & chk$n_studi == chk$k_pool_max
print(chk, row.names = FALSE)

if (!all(chk$ok)) {
  cli_alert_danger("DISALLINEAMENTO su: {chk$cluster_id[!chk$ok]}")
} else {
  cli_alert_success("4/5 n_studi risolti == k del deliverable == max k_effective del pool, su tutti e {nrow(chk)}.")
}
cli_alert_info(paste0(
  "NB: k_effective e' per-gene. Frazione di geni al k pieno, per cluster: ",
  paste(sprintf("%s=%.0f%%", sub("cgroup_L5_", "", chk$cluster_id),
                100 * chk$k_pool_med / chk$k_pool_max), collapse = " ")))

# --- 5. i campioni esistono nell'asse dell'H5? ------------------------------
# Controllo di copertura: nessuna lettura di espressione, solo l'asse dei
# sample_id. Se un campione non c'e', il build casca a meta' come nel 2026-07-23.
h5_path <- "analysis/input/human_gene_v2.5.h5"
sample_axis <- simulomicsr:::.h5_sample_axis(h5_path)
tutti <- unique(unlist(lapply(sel$cluster_id, function(cid) {
  unlist(lapply(disp[[cid]], function(x) c(x$treated, x$control)))
})))
mancanti <- setdiff(tutti, sample_axis)
cli_alert_info("campioni totali nella selezione: {length(tutti)}; assenti dall'H5: {length(mancanti)}")
if (length(mancanti) > 0L) {
  cli_abort("Campioni assenti dall'asse H5: {utils::head(mancanti, 10)}")
}
cli_alert_success("5/5 tutti i {length(tutti)} campioni presenti nell'asse H5.")

saveRDS(chk, "analysis/audit/2026-07-31-layer-b-v13/preflight-dispatch.rds")
cli_alert_success("PRE-FLIGHT PASS.")
