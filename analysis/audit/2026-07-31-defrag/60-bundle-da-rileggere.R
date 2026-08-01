#!/usr/bin/env Rscript
# 60-bundle-da-rileggere.R --- FASE D0ter: il materiale per rileggere i gruppi
# che cambiano composizione dopo la de-frammentazione.
#
# Si rileggono SOLO i gruppi che cambiano (19) o che nascono (27): quelli con
# l'insieme dei membri IDENTICO a v13 (258) tengono il verdetto, e questo e'
# provato dal confronto degli insiemi, non supposto (procedura 2026-07-28).
#
# ⚠️ IL TESTO VA INTERO. Il 2026-07-30 un verdetto fu dato su mezza frase perche'
# il bundle troncava a 58/40 caratteri. Qui non si tronca, e alla fine si CONTA
# quante stringhe toccano una lunghezza sospetta: se il conteggio non e' zero,
# lo strumento sta guardando meno del dato.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V14 <- "analysis/p4-output/20260801T081819Z-stage3-v14-364547a7"
V13 <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
OUT <- "analysis/audit/2026-07-31-defrag"

cf <- utils::read.csv(file.path(OUT, "50-confronto-insiemi-v13-v14.csv"),
                      stringsAsFactors = FALSE)
target <- cf[cf$stato %in% c("CAMBIATO", "NUOVO"), ]
target <- target[order(-target$k_v14), ]
cat("gruppi da rileggere:", nrow(target), "\n")

ck <- function(d) paste(d$contrast_entity, d$contrast_direction,
                        d$contrast_control_key, sep = "||")
cfg <- stage4_default_config()
c14 <- readRDS(file.path(V14, "clusters.rds"))
c13 <- readRDS(file.path(V13, "clusters.rds"))
g14 <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(c14, cfg)); g14$ckey <- ck(g14)
g13 <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(c13, cfg)); g13$ckey <- ck(g13)

a14 <- arrow::read_parquet(file.path(V14, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
a13 <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))

s2 <- simulomicsr:::.load_stage2_master(STAGE2)
lab <- new.env(hash = TRUE, parent = emptyenv())
lo <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
for (st in s2) {
  if (length(st$comparisons) == 0L) next
  rgl <- stats::setNames(st$replicate_groups,
    vapply(st$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in st$comparisons) {
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    assign(sprintf("%s__%s", st$series_id, cmp$comparison_id),
           list(t = lo(tg, cmp$treated_group), c = lo(cg, cmp$control_group)), envir = lab)
  }
}
rm(s2); gc(verbose = FALSE)

env <- simulomicsr:::.load_ontology_dicts()
tutte <- character(0)
con <- file(file.path(OUT, "60-da-rileggere.txt"), "w")
for (i in seq_len(nrow(target))) {
  k <- target$ckey[i]
  cid14 <- g14$cluster_id[g14$ckey == k]
  r14 <- a14$record_id[a14$cluster_id %in% cid14]
  cid13 <- g13$cluster_id[g13$ckey == k]
  r13 <- if (length(cid13)) a13$record_id[a13$cluster_id %in% cid13] else character(0)
  ent <- sub("\\|\\|.*$", "", k)
  nm <- tryCatch(simulomicsr:::.resolve_contrast_entity_label(ent, env = env)$label,
                 error = function(e) NA_character_)
  writeLines(sprintf("\n=== [%d/%d] %s\n    entita': %s (%s) · stato: %s · k %d -> %d",
    i, nrow(target), k, ent, nm %||% "?", target$stato[i],
    target$k_v13[i], target$k_v14[i]), con)
  nuovi <- setdiff(r14, r13); tolti <- setdiff(r13, r14)
  if (length(tolti)) writeLines(sprintf("    membri TOLTI: %d", length(tolti)), con)
  for (rid in sort(r14)) {
    e <- get0(rid, envir = lab, inherits = FALSE)
    if (is.null(e)) next
    mark <- if (rid %in% nuovi) " [NUOVO]" else ""
    writeLines(sprintf("  %s%s\n      TRATTATO: %s\n      CONTROLLO: %s",
                       rid, mark, e$t, e$c), con)
    tutte <- c(tutte, e$t, e$c)
  }
  for (rid in sort(tolti)) {
    e <- get0(rid, envir = lab, inherits = FALSE)
    if (is.null(e)) next
    writeLines(sprintf("  %s [TOLTO]\n      TRATTATO: %s\n      CONTROLLO: %s",
                       rid, e$t, e$c), con)
    tutte <- c(tutte, e$t, e$c)
  }
}
close(con)

# --- LO STRUMENTO VEDE IL DATO PER INTERO? ---
nc <- nchar(tutte)
cat("\n[strumento] etichette scritte:", length(tutte),
    "· max", max(nc), "· mediana", stats::median(nc), "\n")
for (lim in c(40, 58, 64, 80, 100, 128, 255)) {
  cat(sprintf("            == %3d char esatti: %d\n", lim, sum(nc == lim)))
}
cat("[strumento] nessun troncamento se esistono stringhe SOPRA ogni limite: max =", max(nc), "\n")
cat("\nScritto 60-da-rileggere.txt\n")
