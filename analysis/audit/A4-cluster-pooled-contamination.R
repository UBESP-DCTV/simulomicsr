#!/usr/bin/env Rscript
# RED ALERT FASE A4 — quantificazione contaminazione single-cell nel run
# Stadio 4 baseline (cluster_pooled.parquet, run 96c43acb).
#
# Per ognuno dei 487 cluster Layer A:
#   1. Recupera lista GSM membri (via assignments + stage2_master).
#   2. Calcola n_total, n_drop_a1, n_drop_a2, n_drop_a3, n_drop_union.
#   3. frac_sc = n_drop_union / n_total.
#   4. Tabella distribuzione bucket frac_sc.
# Output:
#   - analysis/audit/A4-cluster-contamination.tsv (487 cluster × stats)
#   - log + summary

suppressMessages({
  library(arrow); library(simulomicsr)
})

t_start <- Sys.time()

stage3_dir <- "analysis/p4-output/20260519T055547Z-stage3-2153addc"
stage4_dir <- "analysis/p4-output/20260523T032601Z-stage4-96c43acb"
stage2_collect <- "analysis/p4-output/20260515T175712Z-beta-stage2-fullrun-a275b0/collect.rds"

a1_tsv  <- "analysis/audit/A1-single-cell-by-library-source.tsv"
a2_tsv  <- "analysis/audit/A2-sc-by-extract-protocol.tsv"
a3_tsv  <- "analysis/audit/A3-libsize-scprob-bacino.tsv"
out_tsv <- "analysis/audit/A4-cluster-contamination.tsv"

# ============================================================
# Step 1: union drop list A1 + A2 + A3 (scprob >= 0.9)
# ============================================================
cat("[A4] load drop lists ...\n")
a1 <- read.delim(a1_tsv, sep = "\t", header = TRUE, stringsAsFactors = FALSE,
                 quote = "", fill = TRUE, comment.char = "")
a2 <- read.delim(a2_tsv, sep = "\t", header = TRUE, stringsAsFactors = FALSE,
                 quote = "", fill = TRUE, comment.char = "")
a3 <- read.delim(a3_tsv, sep = "\t", header = TRUE, stringsAsFactors = FALSE,
                 quote = "", fill = TRUE, comment.char = "")

drop_a1 <- unique(a1$geo_accession)
drop_a2 <- unique(a2$geo)
drop_a3_scprob <- unique(a3$geo[a3$passed_libsize_500k == "TRUE" &
                                 a3$singlecellprobability >= 0.9])
drop_a3_libsize <- unique(a3$geo[a3$passed_libsize_500k == "FALSE"])

drop_union_sc <- unique(c(drop_a1, drop_a2, drop_a3_scprob))
drop_union_all <- unique(c(drop_union_sc, drop_a3_libsize))

cat(sprintf("[A4] drop A1: %d, A2: %d, A3-scprob: %d, A3-libsize: %d\n",
            length(drop_a1), length(drop_a2),
            length(drop_a3_scprob), length(drop_a3_libsize)))
cat(sprintf("[A4] union SC-only (A1+A2+A3-scprob): %d\n", length(drop_union_sc)))
cat(sprintf("[A4] union ALL (incl. A3-libsize):    %d\n", length(drop_union_all)))

drop_a1_set       <- new.env(parent = emptyenv(), hash = TRUE, size = length(drop_a1))
drop_a2_set       <- new.env(parent = emptyenv(), hash = TRUE, size = length(drop_a2))
drop_a3_sc_set    <- new.env(parent = emptyenv(), hash = TRUE, size = length(drop_a3_scprob))
drop_a3_lib_set   <- new.env(parent = emptyenv(), hash = TRUE, size = length(drop_a3_libsize))
for (g in drop_a1)         drop_a1_set[[g]]     <- TRUE
for (g in drop_a2)         drop_a2_set[[g]]     <- TRUE
for (g in drop_a3_scprob)  drop_a3_sc_set[[g]]  <- TRUE
for (g in drop_a3_libsize) drop_a3_lib_set[[g]] <- TRUE

# ============================================================
# Step 2: carica cluster_pooled, assignments, stage2_master
# ============================================================
cat("[A4] load cluster_pooled cluster_ids ...\n")
cp_clu <- arrow::read_parquet(file.path(stage4_dir, "cluster_pooled.parquet"),
                              col_select = c("cluster_id", "method"),
                              as_data_frame = TRUE)
ucm <- unique(cp_clu[, c("cluster_id", "method")])
cat(sprintf("[A4] unique (cluster_id, method): %d (%d group_mega + %d pair_mega_aug)\n",
            nrow(ucm),
            sum(startsWith(ucm$cluster_id, "group_")),
            sum(startsWith(ucm$cluster_id, "pair_"))))

cat("[A4] load stage3 assignments ...\n")
asg <- arrow::read_parquet(file.path(stage3_dir, "assignments.parquet"),
                           as_data_frame = TRUE)
asg_by_clid <- split(asg$record_id, asg$cluster_id)
cat(sprintf("[A4] assignments: %d rows, %d unique cluster_id\n",
            nrow(asg), length(asg_by_clid)))

cat("[A4] load stage2_master (predictions list) ...\n")
collect <- readRDS(stage2_collect)
stage2_master <- collect$predictions
rm(collect); gc(verbose = FALSE)
cat(sprintf("[A4] stage2 predictions: %d records\n", nrow(stage2_master)))

# Stage2 master come list di studi indexed da series_id, formato compatibile
# con .index_stage2_master() (richiede list di study records con $series_id).
cat("[A4] build stage2_master list-of-studies ...\n")
s2_records <- vector("list", nrow(stage2_master))
for (i in seq_len(nrow(stage2_master))) {
  pj <- stage2_master$parsed_json[[i]]
  if (is.null(pj) || is.null(pj$series_id)) next
  s2_records[[i]] <- pj
}
s2_records <- s2_records[!vapply(s2_records, is.null, logical(1L))]
cat(sprintf("[A4] non-null stage2 records: %d\n", length(s2_records)))

# Indice via funzione interna
s2_idx <- simulomicsr:::.index_stage2_master(s2_records)
cat(sprintf("[A4] s2_idx environment built\n"))

# ============================================================
# Step 3: per ogni cluster, espandi sample_ids
# ============================================================
cat("\n[A4] step 3: expand cluster -> samples ...\n")
n_cl <- nrow(ucm)
results <- vector("list", n_cl)

for (i in seq_len(n_cl)) {
  cid    <- ucm$cluster_id[i]
  method <- ucm$method[i]
  is_pair  <- startsWith(cid, "pair_")
  is_group <- startsWith(cid, "group_")

  record_ids <- asg_by_clid[[cid]]
  if (is.null(record_ids)) {
    results[[i]] <- tibble::tibble(cluster_id = cid, method = method,
                                    n_total = 0L)
    next
  }

  all_sids <- character(0L)
  for (rid in record_ids) {
    parsed <- simulomicsr:::.split_record_id(rid)
    if (is.na(parsed$series_id)) next
    if (!exists(parsed$series_id, envir = s2_idx, inherits = FALSE)) next
    study <- get(parsed$series_id, envir = s2_idx, inherits = FALSE)

    if (is_pair) {
      cmp <- simulomicsr:::.lookup_cmp(study, parsed$suffix)
      if (is.null(cmp)) next
      tg <- simulomicsr:::.lookup_rg(study, cmp$treated_group)
      cg <- simulomicsr:::.lookup_rg(study, cmp$control_group)
      sids_t <- if (!is.null(tg)) as.character(unlist(tg$sample_ids)) else character(0)
      sids_c <- if (!is.null(cg)) as.character(unlist(cg$sample_ids)) else character(0)
      all_sids <- c(all_sids, sids_t, sids_c)
    } else if (is_group) {
      rg <- simulomicsr:::.lookup_rg(study, parsed$suffix)
      if (is.null(rg)) next
      role <- rg$primary_role %||% NA_character_
      if (is.na(role) || !role %in% c("treated", "control")) next
      sids <- as.character(unlist(rg$sample_ids))
      all_sids <- c(all_sids, sids)
    }
  }

  all_sids <- unique(all_sids)
  if (length(all_sids) == 0L) {
    results[[i]] <- tibble::tibble(cluster_id = cid, method = method,
                                    n_total = 0L)
    next
  }

  # Conta drop per categoria
  n_a1     <- sum(vapply(all_sids, function(s) exists(s, envir = drop_a1_set, inherits = FALSE), logical(1L)))
  n_a2     <- sum(vapply(all_sids, function(s) exists(s, envir = drop_a2_set, inherits = FALSE), logical(1L)))
  n_a3sc   <- sum(vapply(all_sids, function(s) exists(s, envir = drop_a3_sc_set, inherits = FALSE), logical(1L)))
  n_a3lib  <- sum(vapply(all_sids, function(s) exists(s, envir = drop_a3_lib_set, inherits = FALSE), logical(1L)))
  n_unionSC <- sum(vapply(all_sids, function(s) {
    exists(s, envir = drop_a1_set, inherits = FALSE) ||
    exists(s, envir = drop_a2_set, inherits = FALSE) ||
    exists(s, envir = drop_a3_sc_set, inherits = FALSE)
  }, logical(1L)))

  results[[i]] <- tibble::tibble(
    cluster_id = cid, method = method,
    n_total = length(all_sids),
    n_drop_a1 = n_a1,
    n_drop_a2 = n_a2,
    n_drop_a3_scprob = n_a3sc,
    n_drop_a3_libsize = n_a3lib,
    n_drop_union_sc = n_unionSC,
    frac_sc = n_unionSC / length(all_sids)
  )

  if (i %% 50L == 0L || i == n_cl) {
    el <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
    cat(sprintf("  [A4] %d / %d cluster done (%.1f min wall)\n",
                i, n_cl, el/60))
  }
}

df <- do.call(rbind, results)
write.table(df, out_tsv, sep = "\t", row.names = FALSE, quote = FALSE)

# ============================================================
# Step 4: tabelle distribuzione
# ============================================================
cat("\n[A4] === Distribuzione frac_sc per i 487 cluster ===\n")
df_valid <- df[df$n_total > 0L, ]
cat(sprintf("cluster con n_total > 0: %d / %d\n", nrow(df_valid), nrow(df)))

if (nrow(df_valid) > 0L) {
  bucket <- cut(df_valid$frac_sc,
                breaks = c(-Inf, 0, 0.01, 0.10, 0.50, 0.99, 1.0001),
                labels = c("0%", "0-1%", "1-10%", "10-50%", "50-99%", "100%"),
                right = TRUE, include.lowest = TRUE)
  cat("\ntabella frac_sc (A1+A2+A3-scprob union, NO libsize):\n")
  print(table(bucket, method = df_valid$method))

  cat("\nstat n_total cluster size:\n")
  print(summary(df_valid$n_total))

  cat(sprintf("\nfrac cluster con frac_sc > 0: %.2f%% (%d/%d)\n",
              100 * mean(df_valid$frac_sc > 0), sum(df_valid$frac_sc > 0), nrow(df_valid)))
  cat(sprintf("frac cluster con frac_sc >= 0.5: %.2f%% (%d/%d)\n",
              100 * mean(df_valid$frac_sc >= 0.5), sum(df_valid$frac_sc >= 0.5), nrow(df_valid)))
  cat(sprintf("frac cluster con frac_sc = 1.0: %.2f%% (%d/%d)\n",
              100 * mean(df_valid$frac_sc >= 0.999), sum(df_valid$frac_sc >= 0.999), nrow(df_valid)))

  # Quanti sample SC sono attualmente nel pool aggregato (somma su cluster)
  cat(sprintf("\nTotale sample SC nei pool: %d (somma)\n",
              sum(df_valid$n_drop_union_sc)))
  cat(sprintf("Totale sample nei pool   : %d (somma)\n",
              sum(df_valid$n_total)))
  cat(sprintf("Frac sample SC su totale : %.2f%%\n",
              100 * sum(df_valid$n_drop_union_sc) / sum(df_valid$n_total)))
}

cat(sprintf("\n[A4] TSV: %s (%d righe)\n", out_tsv, nrow(df)))
cat(sprintf("[A4] Wall totale: %.1f min\n",
            as.numeric(difftime(Sys.time(), t_start, units = "mins"))))
cat("[A4] DONE\n")
