# analysis/audit/2026-07-19-v9-fallback-impact-sim.R
# ---------------------------------------------------------------------------
# Passo 4 — SIMULAZIONE D'IMPATTO (deterministica, SENZA re-cluster) dell'
# LLM-fallback finale sugli indeterminati. Stima DOVE finirebbero i 50.246
# override se il re-cluster fosse rifatto, distinguendo l'upside REALE
# (meta-analisi nominate nuove/piu-potenti) dal rumore (k=1 che resta isolato).
#
# Metodo:
#   A. `.measure_fragmentation` (helper, come richiesto) — coarse, groups by
#      effective agent_id; ARTEFATTO UNK escluso.
#   B. Proiezione ANCHOR-AWARE: post-overlay ogni override cambia seg1(kind)/
#      seg2(agent_id) del suo anchor_key; due cluster si FONDONO solo se
#      l'anchor_key COMPLETO coincide (kind+id+background+dose+cellline+tissue+
#      role+timepoint, level-specific). Raggruppo TUTTI i cluster per anchor_key
#      post-overlay e conto studi DISTINTI (union studies_in_cluster).
#      Classifico: fusione-in-esistente-nominata / nuova-coalescenza / isolato.
#      Conto le entita' che raggiungono k>=3 studi distinti (soglia rem_group).
#      CAVEAT L7: k=studi distinti e' UPPER BOUND; il k_eff poolato reale e'
#      minore (gate controllo-interno treated-only).
#
# Read-only. Uso: Rscript analysis/audit/2026-07-19-v9-fallback-impact-sim.R
# ---------------------------------------------------------------------------
suppressMessages({devtools::load_all(".", quiet = TRUE); library(dplyr)})
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L || is.na(a)) b else a

STAGE3 <- "analysis/p4-output/20260717T171550Z-stage3-v9-364547a7"
SIDE   <- "analysis/p4-output/name-cleanup-fallback-side-table.rds"

cl   <- readRDS(file.path(STAGE3, "clusters.rds"))
side <- readRDS(SIDE)
ov   <- side[side$action == "override" & !is.na(side$new_id), , drop = FALSE]
cat(sprintf("cluster: %d | override: %d\n\n", nrow(cl), nrow(ov)))

# ---- overlay map: cluster_id -> (new_id, new_kind_canon) -------------------
new_id_by   <- setNames(ov$new_id, ov$cluster_id)
new_kind_by <- setNames(vapply(ov$new_kind, simulomicsr:::.canonicalize_overlay_kind, character(1)),
                        ov$cluster_id)
is_ov <- cl$cluster_id %in% ov$cluster_id

# =========================================================================
# A. .measure_fragmentation (helper) — UNK artefatto escluso
# =========================================================================
k_by <- setNames(cl$k, cl$cluster_id)
fr <- simulomicsr:::.measure_fragmentation(side, k_by)
fr_real <- fr[!(fr$resolved_entity_id %in% c("UNK")) & !grepl("^STR", fr$resolved_entity_id), ]
cat("=== A. .measure_fragmentation (side-table) ===\n")
cat(sprintf("entita' frammentate (>=2 cluster): %d totali | %d reali (escl. UNK/STR artefatto)\n",
            nrow(fr), nrow(fr_real)))
cat("Top 10 entita' reali (n_clusters, k_merged_est = Sigma k, UPPER BOUND):\n")
print(head(as.data.frame(fr_real[order(-fr_real$k_merged_est), c("resolved_entity_id","n_clusters","k_merged_est")]), 10), row.names = FALSE)
cat(sprintf("\n(ARTEFATTO escluso: UNK con %d cluster / k_merged %d = non-entita', non si fonde)\n\n",
            fr$n_clusters[fr$resolved_entity_id=="UNK"], fr$k_merged_est[fr$resolved_entity_id=="UNK"]))

# =========================================================================
# B. Proiezione ANCHOR-AWARE
# =========================================================================
# Kind-anchor validi per branch (b) (seg1 cambia solo per questi).
branch_b <- c(simulomicsr:::.OVERLAY_ANCHOR_GENETIC_KINDS,
              "cytokine_stim", "pathogen_or_aggregate_exposure")

# post-overlay anchor_key: sostituisci seg1/seg2 nei cluster override.
segs <- strsplit(cl$anchor_key, "|", fixed = TRUE)
post_anchor <- cl$anchor_key
ov_idx <- which(is_ov)
for (i in ov_idx) {
  s <- segs[[i]]
  cid <- cl$cluster_id[i]
  s[2] <- new_id_by[[cid]]                          # seg2 = agent_id -> new_id
  nk <- new_kind_by[[cid]]
  if (!is.na(nk) && nk %in% branch_b) s[1] <- nk     # seg1 = kind solo se branch (b)
  post_anchor[i] <- paste(s, collapse = "|")
}

# raggruppa TUTTI i cluster per anchor_key post-overlay
grp <- split(seq_len(nrow(cl)), post_anchor)
bucket_sizes <- lengths(grp)
merged_buckets <- grp[bucket_sizes >= 2L]
cat(sprintf("=== B. Proiezione anchor-aware ===\n"))
cat(sprintf("bucket post-overlay con >=2 cluster (fusioni): %d\n", length(merged_buckets)))

# studi distinti helper (union studies_in_cluster)
studies_of <- function(idx) unique(unlist(cl$studies_in_cluster[idx], use.names = FALSE))

# analizza ogni bucket fuso: contiene override? contiene un pre-esistente nominato?
analyze <- function(idx) {
  ov_members  <- intersect(idx, ov_idx)
  has_ov      <- length(ov_members) > 0L
  # pre-esistente nominato = membro NON-override con agent forte (non STR/UNK)
  non_ov      <- setdiff(idx, ov_idx)
  strong_pre  <- non_ov[!grepl("^UNK|^STR:", cl$agent_id_resolved[non_ov])]
  has_named_pre <- length(strong_pre) > 0L
  k_pre  <- if (length(strong_pre)) length(studies_of(strong_pre)) else 0L
  k_post <- length(studies_of(idx))
  data.frame(n = length(idx), n_ov = length(ov_members),
             has_ov = has_ov, has_named_pre = has_named_pre,
             k_pre = k_pre, k_post = k_post,
             mode = cl$mode[idx[1]], level = cl$level[idx[1]],
             agent = cl$agent_id_resolved[strong_pre[1]] %||% NA_character_,
             post_seg2 = strsplit(post_anchor[idx[1]], "|", fixed=TRUE)[[1]][2],
             stringsAsFactors = FALSE)
}
# solo i bucket che coinvolgono almeno un override (gli altri sono invariati)
touch <- vapply(merged_buckets, function(idx) any(idx %in% ov_idx), logical(1))
mb <- merged_buckets[touch]
cat(sprintf("di cui coinvolgono >=1 override: %d\n", length(mb)))
res <- do.call(rbind, lapply(mb, analyze))

# classificazione
res$klass <- ifelse(res$has_named_pre, "fusione_in_esistente",
              ifelse(res$n_ov >= 2L, "nuova_coalescenza_override", "override_isolato_con_altro"))
cat("\n--- classificazione bucket fusi (che toccano override) ---\n")
print(as.data.frame(res %>% group_by(klass) %>%
  summarise(n_bucket = n(),
            k_post_ge3 = sum(k_post >= 3L),
            override_coinvolti = sum(n_ov), .groups="drop")))

# override che NON entrano in nessun bucket >=2 = isolati (restano k=1, rumore)
ov_in_merged <- unique(unlist(mb, use.names = FALSE))
ov_isolated  <- setdiff(ov_idx, ov_in_merged)
cat(sprintf("\noverride ISOLATI (post-anchor unico, restano soli -> rumore): %d / %d\n",
            length(ov_isolated), length(ov_idx)))
cat(sprintf("override che si FONDONO (in bucket >=2): %d\n", length(intersect(ov_idx, ov_in_merged))))

# --- soglia poolabile k>=3 (proxy rem_group), per mode group ---------------
cat("\n--- ENTITA' che raggiungono k>=3 studi distinti (proxy rem_group poolabile) ---\n")
g_res <- res[res$mode == "group", ]
new_pool  <- g_res[g_res$klass != "fusione_in_esistente" & g_res$k_post >= 3L, ]
strong_ex <- g_res[g_res$klass == "fusione_in_esistente" & g_res$k_post >= 3L, ]
cat(sprintf("  NUOVE meta-analisi nominate (group, no pre-esistente, k_post>=3): %d\n", nrow(new_pool)))
cat(sprintf("  ESISTENTI nominate rafforzate (group, k_post>=3, guadagnano studi): %d\n", nrow(strong_ex)))
cat(sprintf("    di queste, guadagno mediano studi (k_post - k_pre): %s\n",
            if(nrow(strong_ex)) paste(round(median(strong_ex$k_post - strong_ex$k_pre)),collapse="") else "0"))
cat(sprintf("  per livello (group, k_post>=3): L2=%d L3=%d L4=%d\n",
            sum(g_res$level==2 & g_res$k_post>=3), sum(g_res$level==3 & g_res$k_post>=3),
            sum(g_res$level==4 & g_res$k_post>=3)))

# --- top entita' nominate per guadagno studi (group, fusione/nuova) --------
cat("\n--- top 15 bucket group per k_post (studi distinti post-overlay) ---\n")
top <- g_res[order(-g_res$k_post), ]
top$gain <- top$k_post - top$k_pre
print(head(as.data.frame(top[, c("post_seg2","klass","level","n_ov","k_pre","k_post","gain")]), 15), row.names = FALSE)

saveRDS(res, "analysis/audit/2026-07-19-v9-fallback-impact-buckets.rds")
write.csv(g_res[order(-g_res$k_post), c("post_seg2","klass","level","n","n_ov","k_pre","k_post")],
          "analysis/audit/2026-07-19-v9-fallback-impact-group-buckets.csv", row.names = FALSE)
cat("\nOutput: analysis/audit/2026-07-19-v9-fallback-impact-*.{rds,csv}\n== FINE ==\n")
