# analysis/audit/2026-07-20-v9-fallback-poolable-gain.R
# ---------------------------------------------------------------------------
# Passo 4-bis (opzione C) — GUADAGNO POOLABILE REALE dell'LLM-fallback, SENZA
# re-pool. Riproduce ESATTAMENTE il gate rem_group (ADR-0022,
# `.build_group_rem_dispatch_from_stage3`): per ogni record group
# `series__group_id`, cerca la comparison in-study dove group_id e' treated_group
# -> control_group nello stesso studio, >= n_min per braccio. k_eff = studi
# DISTINTI con contrasto valido; gate poolabile k_eff >= 3.
#
# Per ogni bucket group post-overlay che raggiunge k>=3 studi-MEMBRI, calcola:
#   - k_eff_pre  = gate sui soli cluster ESISTENTI (non-override) del bucket
#   - k_eff_post = gate su ESISTENTI + override che si fondono allo stesso anchor
# -> il guadagno poolabile = k_eff_post - k_eff_pre. Distingue NUOVE poolabili
# (pre<3 -> post>=3) da ESISTENTI rafforzate.
#
# CAVEAT: salta il pre-filtro H5 del re-pool (samples non in H5 non contano) ->
# k_eff e' un UPPER BOUND. VALIDAZIONE: k_eff_pre di breast deve ~ combaciare col
# k_eff=22 noto dal re-gate v9 (analysis/audit/2026-07-19-stage4-v9-remgroup-processed.csv).
#
# Read-only. Uso: Rscript analysis/audit/2026-07-20-v9-fallback-poolable-gain.R
# ---------------------------------------------------------------------------
suppressMessages({devtools::load_all(".", quiet = TRUE); library(arrow); library(dplyr)})

STAGE3 <- "analysis/p4-output/20260717T171550Z-stage3-v9-364547a7"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
SIDE   <- "analysis/p4-output/name-cleanup-fallback-side-table.rds"

cl   <- readRDS(file.path(STAGE3, "clusters.rds"))
asg  <- arrow::read_parquet(file.path(STAGE3, "assignments.parquet"))
side <- readRDS(SIDE)
ov   <- side[side$action == "override" & !is.na(side$new_id), ]
cat(sprintf("cluster %d | assignments %d | override %d\n", nrow(cl), nrow(asg), nrow(ov)))
cat("Loading stage2 master...\n")
stage2_master <- simulomicsr:::.load_stage2_master(STAGE2)
cat(sprintf("stage2 studies: %d\n\n", length(stage2_master)))

# ---- post-overlay anchor (come nella sim) ---------------------------------
new_id_by   <- setNames(ov$new_id, ov$cluster_id)
new_kind_by <- setNames(vapply(ov$new_kind, simulomicsr:::.canonicalize_overlay_kind, character(1)), ov$cluster_id)
is_ov  <- cl$cluster_id %in% ov$cluster_id
ov_idx <- which(is_ov)
branch_b <- c(simulomicsr:::.OVERLAY_ANCHOR_GENETIC_KINDS, "cytokine_stim", "pathogen_or_aggregate_exposure")
segs <- strsplit(cl$anchor_key, "|", fixed = TRUE)
post <- cl$anchor_key
for (i in ov_idx) { s <- segs[[i]]; cid <- cl$cluster_id[i]; s[2] <- new_id_by[[cid]]
  nk <- new_kind_by[[cid]]; if (!is.na(nk) && nk %in% branch_b) s[1] <- nk; post[i] <- paste(s, collapse = "|") }

# ---- seleziona bucket GROUP, >=2 cluster, che toccano override, k_post>=3 --
is_group <- cl$mode == "group"
studies_of_idx <- function(idx) unique(unlist(cl$studies_in_cluster[idx], use.names = FALSE))
grp <- split(seq_len(nrow(cl)), post)
sel <- Filter(function(idx) length(idx) >= 2L && any(idx %in% ov_idx) &&
                all(cl$mode[idx] == "group") &&
                length(studies_of_idx(idx)) >= 3L, grp)
cat(sprintf("bucket GROUP post-overlay (>=2 cluster, con override, k_membri>=3): %d\n", length(sel)))

# ---- batch: assignments sintetici <Bi_pre> / <Bi_all> per il dispatch -----
asg_by_clid <- split(asg$record_id, asg$cluster_id)
recs_of <- function(cids) unlist(asg_by_clid[cids], use.names = FALSE)
rows <- list(); meta <- list()
for (bi in seq_along(sel)) {
  idx <- sel[[bi]]
  members    <- cl$cluster_id[idx]
  pre_members<- cl$cluster_id[setdiff(idx, ov_idx)]
  r_all <- recs_of(members); r_pre <- recs_of(pre_members)
  if (length(r_all)) rows[[length(rows)+1L]] <- data.frame(record_id = r_all, cluster_id = sprintf("B%05d_all", bi), stringsAsFactors = FALSE)
  if (length(r_pre)) rows[[length(rows)+1L]] <- data.frame(record_id = r_pre, cluster_id = sprintf("B%05d_pre", bi), stringsAsFactors = FALSE)
  meta[[bi]] <- list(bi = bi, entity = strsplit(post[idx[1]], "|", fixed = TRUE)[[1]][2],
                     kind = strsplit(post[idx[1]], "|", fixed = TRUE)[[1]][1],
                     level = cl$level[idx[1]], n_members = length(members),
                     n_override = sum(idx %in% ov_idx), k_membri = length(studies_of_idx(idx)))
}
synth_asg <- do.call(rbind, rows)
synth_asg$mode <- "group"; synth_asg$level <- 4L; synth_asg$anchor_key <- NA_character_
eligible <- data.frame(cluster_id = unique(synth_asg$cluster_id), mode = "group",
                       method = "rem_group", stringsAsFactors = FALSE)
cat(sprintf("record sintetici: %d | cluster-variant: %d | dispatch...\n", nrow(synth_asg), nrow(eligible)))

disp <- simulomicsr:::.build_group_rem_dispatch_from_stage3(eligible, synth_asg, stage2_master, n_min = 2L)
keff <- function(clid) { d <- disp[[clid]]; if (is.null(d)) return(0L); length(unique(vapply(d, function(x) x$study_id, character(1)))) }

# ---- compila risultati ----------------------------------------------------
out <- do.call(rbind, lapply(meta, function(m) {
  kp <- keff(sprintf("B%05d_pre", m$bi)); ka <- keff(sprintf("B%05d_all", m$bi))
  data.frame(entity = m$entity, kind = m$kind, level = m$level, n_members = m$n_members,
             n_override = m$n_override, k_membri = m$k_membri,
             k_eff_pre = kp, k_eff_post = ka, gain = ka - kp, stringsAsFactors = FALSE)
}))
out <- out[order(-out$gain, -out$k_eff_post), ]

cat("\n=== VALIDAZIONE: k_eff_pre breast (MeSH:D001943) vs v9 re-gate (k_eff=22) ===\n")
br <- out[out$entity == "MeSH:D001943", ]
print(as.data.frame(br[, c("entity","level","k_membri","k_eff_pre","k_eff_post","gain")]), row.names = FALSE)

cat("\n=== SINTESI GUADAGNO POOLABILE ===\n")
newly <- out[out$k_eff_pre < 3L & out$k_eff_post >= 3L, ]
stron <- out[out$k_eff_pre >= 3L & out$gain > 0L, ]
cat(sprintf("bucket group candidati (k_membri>=3): %d\n", nrow(out)))
cat(sprintf("  NUOVE poolabili (k_eff_pre<3 -> k_eff_post>=3): %d (somma k_eff_post %d)\n", nrow(newly), sum(newly$k_eff_post)))
cat(sprintf("  ESISTENTI poolabili rafforzate (k_eff_pre>=3, gain>0): %d\n", nrow(stron)))
cat(sprintf("  guadagno k_eff TOTALE (somma gain su bucket che restano/diventano poolabili): %d\n",
            sum(out$gain[out$k_eff_post >= 3L])))
cat(sprintf("  bucket con gain=0 (override non aggiungono contrasto interno): %d\n", sum(out$gain == 0L)))

cat("\n=== top 20 per guadagno k_eff poolabile ===\n")
print(head(as.data.frame(out[, c("entity","kind","level","k_membri","k_eff_pre","k_eff_post","gain")]), 20), row.names = FALSE)

write.csv(out, "analysis/audit/2026-07-20-v9-fallback-poolable-gain.csv", row.names = FALSE)
cat("\nCSV: analysis/audit/2026-07-20-v9-fallback-poolable-gain.csv\n== FINE ==\n")
