# P5 coherence Task 3: segnali A/C (Fase 0+A+C) su TUTTI i 13.287 cluster Stadio 3 k>=2.
#
# Ricostruisce, per ogni cluster k>=2, i contrasti per-membro (studio/treated/control/design_kind)
# via .reconstruct_cluster_contrasts (stesso dispatch dello Stadio 4) e riassume i segnali di
# coerenza (n_control_types, control_homogeneity, n_design_kinds, frac_degenerate, ...) via
# .cluster_coherence_signals. Output = 2 file (pesanti, gitignored):
#   - per-member-contrasts.parquet : una riga per membro RISOLTO, con cluster_id
#   - per-cluster-signals.rds      : 13.287 righe, una per cluster k>=2, con i 7 segnali +
#                                     cluster_id/kind/k/mode/level/anchor_key/canonical_name
#
# Verifica (Step 3 del brief): copertura, distribuzione n_control_types sui group, e confronto
# esplicito con la misura di calibrazione dei 184 rem_group poolati (pooled-184-res.rds, scratchpad,
# conteggio GREZZO pre-normalizzazione: 0/184 con control omogeneo, 147/184 con >=5 tipi).

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

suppressPackageStartupMessages({
  library(arrow)
  devtools::load_all(".", quiet = TRUE)
})

OUT_DIR <- "analysis/audit/2026-07-23-coherence"
dir.create(OUT_DIR, showWarnings = FALSE, recursive = TRUE)

S3_DIR <- "analysis/p4-output/20260720T180625Z-stage3-v10-364547a7"
S2_PATH <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
S4_DIR <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032"

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

cat("=== Task 3: segnali A/C su tutti i cluster k>=2 ===\n")
cat(format(Sys.time()), "- carico clusters.rds ...\n")
cl <- readRDS(file.path(S3_DIR, "clusters.rds"))
cl <- cl[!is.na(cl$k) & cl$k >= 2, , drop = FALSE]
stopifnot(nrow(cl) == 13287L)
cat("cluster k>=2:", nrow(cl), "\n")

cat(format(Sys.time()), "- carico assignments.parquet ...\n")
asg <- read_parquet(file.path(S3_DIR, "assignments.parquet"))
asg_by_clid <- split(asg$record_id, asg$cluster_id)

cat(format(Sys.time()), "- carico Stage 2 master ...\n")
s2 <- .load_stage2_master(S2_PATH)
s2_idx <- .index_stage2_master(s2)
cat(format(Sys.time()), "- Stage 2 master indicizzato (", length(ls(s2_idx)), "series).\n")

n_cl <- nrow(cl)
cluster_ids <- cl$cluster_id
modes <- cl$mode

member_rows <- vector("list", n_cl)
signal_rows <- vector("list", n_cl)

cat(format(Sys.time()), "- ricostruzione contrasti su", n_cl, "cluster ...\n")
t0 <- Sys.time()
for (i in seq_len(n_cl)) {
  cid <- cluster_ids[[i]]
  mode <- modes[[i]]
  df <- .reconstruct_cluster_contrasts(cid, mode, asg_by_clid, s2_idx)
  if (nrow(df) > 0L) {
    df$cluster_id <- cid
    member_rows[[i]] <- df
  }
  s <- .cluster_coherence_signals(df)
  signal_rows[[i]] <- data.frame(
    cluster_id = cid,
    kind = cl$kind_effective_resolved[[i]],
    k = cl$k[[i]],
    mode = mode,
    level = cl$level[[i]],
    anchor_key = cl$anchor_key[[i]],
    canonical_name = cl$canonical_name[[i]],
    n_resolved = s$n_resolved,
    n_control_types = s$n_control_types,
    control_homogeneity = s$control_homogeneity,
    n_design_kinds = s$n_design_kinds,
    n_treated_types = s$n_treated_types,
    n_degenerate = s$n_degenerate,
    frac_degenerate = s$frac_degenerate,
    stringsAsFactors = FALSE
  )
  if (i %% 2000 == 0 || i == n_cl) {
    el <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    cat(sprintf("%s - %d/%d cluster (%.1f%%), %.1fs trascorsi\n",
                format(Sys.time()), i, n_cl, 100 * i / n_cl, el))
  }
}

cat(format(Sys.time()), "- assemblo output ...\n")
per_member <- do.call(rbind, member_rows[!vapply(member_rows, is.null, logical(1))])
per_cluster <- do.call(rbind, signal_rows)
rownames(per_cluster) <- NULL

stopifnot(nrow(per_cluster) == 13287L)

out_member <- file.path(OUT_DIR, "per-member-contrasts.parquet")
out_signals <- file.path(OUT_DIR, "per-cluster-signals.rds")
write_parquet(per_member, out_member)
saveRDS(per_cluster, out_signals)
cat("Salvato:", out_member, "(", nrow(per_member), "righe )\n")
cat("Salvato:", out_signals, "(", nrow(per_cluster), "righe )\n")

## ---------------------------------------------------------------------------
## VERIFICA (Step 3 del brief) — leggere dai dati, non inventare.
## ---------------------------------------------------------------------------

cat("\n=== VERIFICA (a): copertura n_resolved/n_members ===\n")
n_members <- lengths(asg_by_clid[per_cluster$cluster_id])
cov_ratio <- per_cluster$n_resolved / pmax(n_members, 1)
cat("n_members mediana:", median(n_members), "\n")
cat("n_resolved mediana:", median(per_cluster$n_resolved), "\n")
cat("copertura (n_resolved/n_members) mediana:", median(cov_ratio), "\n")
cat("n. cluster con n_resolved==0:", sum(per_cluster$n_resolved == 0L), "\n")
print(summary(cov_ratio))

cat("\n=== VERIFICA (b): mode=='group' & k>=2 -> distribuzione n_control_types ===\n")
grp <- per_cluster[per_cluster$mode == "group" & per_cluster$k >= 2, , drop = FALSE]
cat("n cluster group k>=2:", nrow(grp), "\n")
print(summary(grp$n_control_types))
cat("n. group con n_control_types==1 (control omogeneo):",
    sum(grp$n_control_types == 1L, na.rm = TRUE), "\n")
cat("n. group con n_control_types>=5:",
    sum(grp$n_control_types >= 5L, na.rm = TRUE), "\n")
cat("n. group con n_control_types NA (0 risolti):",
    sum(is.na(grp$n_control_types)), "\n")

cat("\n=== VERIFICA (c): i 184 rem_group poolati (cluster_pooled.parquet v10) ===\n")
cp_meta <- open_dataset(file.path(S4_DIR, "cluster_pooled.parquet")) |>
  dplyr::select(cluster_id, method) |> dplyr::distinct() |> dplyr::collect()
remgroup_ids <- unique(cp_meta$cluster_id[cp_meta$method == "rem_group"])
cat("rem_group poolati (v10 cluster_pooled.parquet):", length(remgroup_ids), "\n")

rg <- per_cluster[per_cluster$cluster_id %in% remgroup_ids, , drop = FALSE]
cat("rem_group trovati nella tabella segnali (k>=2, atteso ==184):", nrow(rg), "\n")

cat("\nsummary n_control_types (dopo normalizzazione, sui 184 rem_group):\n")
print(summary(rg$n_control_types))
cat("summary frac_degenerate (sui 184 rem_group):\n")
print(summary(rg$frac_degenerate))
n_ctrl_eq1 <- sum(rg$n_control_types == 1L, na.rm = TRUE)
n_ctrl_ge5 <- sum(rg$n_control_types >= 5L, na.rm = TRUE)
cat("\nn. rem_group con n_control_types==1 (control OMOGENEO dopo normalizzazione):",
    n_ctrl_eq1, "/", nrow(rg), "\n")
cat("n. rem_group con n_control_types>=5:", n_ctrl_ge5, "/", nrow(rg), "\n")

# Confronto esplicito con la misura di calibrazione GREZZA (pre-normalizzazione),
# salvata nello scratchpad da 09-calibrate-on-184.R / pooled-184.R.
calib_path <- "/tmp/claude-1000/-home-user-simulomicsr/48a08c90-610f-4a7c-8eaa-a251d3cda71d/scratchpad/pooled-184-res.rds"
if (file.exists(calib_path)) {
  calib <- readRDS(calib_path)
  cat("\n--- confronto con calibrazione GREZZA (pooled-184-res.rds) ---\n")
  cat("calibrazione grezza: n cluster =", nrow(calib), "\n")
  cat("calibrazione grezza: ctrl_d==1 (omogeneo) =", sum(calib$ctrl_d == 1L), "\n")
  cat("calibrazione grezza: ctrl_d>=5              =", sum(calib$ctrl_d >= 5L), "\n")
  merged <- merge(
    calib[, c("cluster_id", "ctrl_d")],
    rg[, c("cluster_id", "n_control_types")],
    by = "cluster_id", all = TRUE
  )
  merged$moved_to_1 <- !is.na(merged$ctrl_d) & merged$ctrl_d > 1L &
    !is.na(merged$n_control_types) & merged$n_control_types == 1L
  cat("n. cluster che passano da ctrl_d>1 (grezzo) a n_control_types==1 (normalizzato):",
      sum(merged$moved_to_1), "\n")
  cat("delta ctrl==1: grezzo", sum(calib$ctrl_d == 1L, na.rm = TRUE),
      "-> normalizzato", n_ctrl_eq1, "\n")
} else {
  cat("\n(ATTENZIONE) file di calibrazione", calib_path, "non trovato: confronto saltato.\n")
}

## ---------------------------------------------------------------------------
## Sanity ancora (Step 5): group_L4_b6a3eabd deve avere n_resolved=108, n_control_types=9.
## ---------------------------------------------------------------------------
cat("\n=== SANITY ANCORA: group_L4_b6a3eabd ===\n")
sanity_row <- per_cluster[per_cluster$cluster_id == "group_L4_b6a3eabd", , drop = FALSE]
if (nrow(sanity_row) == 1L) {
  cat("n_resolved:", sanity_row$n_resolved, "(atteso 108)\n")
  cat("n_control_types:", sanity_row$n_control_types, "(atteso 9)\n")
  if (!identical(sanity_row$n_resolved, 108L) || !identical(sanity_row$n_control_types, 9L)) {
    cat("!!! SANITY FALLITA: valori divergono dall'atteso. FERMARSI E INDAGARE. !!!\n")
  } else {
    cat("SANITY PASS.\n")
  }
} else {
  cat("!!! SANITY: group_L4_b6a3eabd non trovato (o duplicato) in per_cluster. !!!\n")
}

cat("\n=== FINE Task 3 ===\n")
