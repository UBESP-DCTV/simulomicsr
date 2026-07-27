#!/usr/bin/env Rscript
# MISURA (metro simmetrico): l'entita' del gruppo si risolve anche dal braccio
# di CONTROLLO?
#
# Il tentativo precedente (30-) ri-tokenizzava il controllo a mano e NON trovava
# nemmeno il caso da cui era partito ("TGF-β1 + 3C" vs "TGF-β1 + DMSO"): la beta
# greca sparisce nella tokenizzazione e "tgf" non risolve. Quello 0,2% era un
# limite inferiore prodotto da uno strumento cieco, non una misura.
#
# Qui si usa ESATTAMENTE la catena che ha prodotto l'entita' (.ca_delta ->
# .ca_candidates -> .ca_resolve_entity), applicata al lato controllo invece che
# al lato trattato. Se i due lati risolvono alla STESSA entita', quel confronto
# tiene l'entita' costante e misura altro: non appartiene a quella meta-analisi.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V12 <- "analysis/p4-output/20260727T204316Z-stage3-v12-364547a7"
OUT <- "analysis/audit/2026-07-28-censimento-v12"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

cl  <- readRDS(file.path(V12, "clusters.rds"))
sel <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(cl, stage4_default_config()))
sel$ckey <- paste0(sel$contrast_entity, "||", sel$contrast_direction, "||", sel$contrast_control_key)
asg <- arrow::read_parquet(file.path(V12, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% sel$cluster_id, ]
asg$entita <- sel$contrast_entity[match(asg$cluster_id, sel$cluster_id)]
asg$ckey   <- sel$ckey[match(asg$cluster_id, sel$cluster_id)]

cat("carico Stadio 2...\n")
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
need <- unique(asg$record_id)
lab <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
fl_of <- function(rg) {
  fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";")
}
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
for (study in s2) {
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    rid <- sprintf("%s__%s", study$series_id, cmp$comparison_id)
    if (!rid %in% need) next
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    assign(rid, list(study = study$series_id, tl = lab_of(tg, cmp$treated_group),
                     cl = lab_of(cg, cmp$control_group),
                     tfl = fl_of(tg), cfl = fl_of(cg)), envir = lab)
  }
}
rm(s2); gc()

oe <- simulomicsr:::.load_ontology_dicts()

cat("misuro su", nrow(asg), "confronti (metro simmetrico)...\n")
res <- vector("list", nrow(asg)); t0 <- Sys.time()
for (i in seq_len(nrow(asg))) {
  if (i %% 500 == 0) cat("  ", i, "/", nrow(asg), " (",
                         round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min )\n")
  e <- get0(asg$record_id[i], envir = lab, inherits = FALSE)
  if (is.null(e)) next
  ent <- asg$entita[i]
  if (is.na(ent) || startsWith(ent, "COMBO:")) next

  d <- simulomicsr:::.ca_delta(e$tfl, e$cfl)
  if (is.na(d$dominant_class)) next
  cls <- d$dominant_class
  tv <- d$treated_values[d$classes == cls]; if (!length(tv)) tv <- d$treated_values
  cv <- d$control_values[d$classes == cls]; if (!length(cv)) cv <- d$control_values
  cv <- cv[nzchar(trimws(cv))]
  if (!length(cv)) next                                  # controllo vuoto: nulla da risolvere

  # STESSA catena del gate, lato controllo
  rc <- simulomicsr:::.ca_resolve_entity(cls, cv,
          simulomicsr:::.ca_candidates(cv, e$cl, cls), oe)
  rt <- simulomicsr:::.ca_resolve_entity(cls, tv,
          simulomicsr:::.ca_candidates(tv, e$tl, cls), oe)

  res[[i]] <- data.frame(
    record_id = asg$record_id[i], ckey = asg$ckey[i], entita = ent, study = e$study,
    id_trattato  = rt$id %||% NA_character_,
    id_controllo = rc$id %||% NA_character_,
    stessa_entita = identical(rc$id, ent),
    tl = e$tl, cl = e$cl, tval = paste(tv, collapse = "|"),
    cval = paste(cv, collapse = "|"), stringsAsFactors = FALSE)
}
r <- do.call(rbind, res)
saveRDS(r, file.path(OUT, "entita-simmetrica.rds"))

cat("\n=== ESITO (metro simmetrico) ===\n")
cat("confronti misurati:", nrow(r), "\n")
bad <- r[!is.na(r$stessa_entita) & r$stessa_entita, ]
cat("confronti in cui il CONTROLLO risolve alla stessa entita' del gruppo:",
    nrow(bad), sprintf("(%.1f%%)\n", 100 * nrow(bad) / nrow(r)))
cat("gruppi toccati:", length(unique(bad$ckey)), "su", length(unique(r$ckey)), "\n")
if (nrow(bad)) {
  tb <- sort(table(bad$ckey), decreasing = TRUE)
  cat("\n--- gruppi piu' colpiti ---\n")
  for (i in seq_len(min(20L, length(tb)))) {
    ck <- names(tb)[i]; tot <- sum(r$ckey == ck)
    cat(sprintf("  %-50s %d/%d confronti\n", substr(ck, 1, 50), tb[[i]], tot))
  }
  cat("\n--- esempi (primi 25) ---\n")
  for (i in seq_len(min(25L, nrow(bad))))
    cat(sprintf("  %-11s %-15s T[%s] => C[%s]\n", bad$study[i], substr(bad$entita[i],1,15),
                substr(bad$tval[i], 1, 34), substr(bad$cval[i], 1, 30)))
  write.csv(bad, file.path(OUT, "entita-simmetrica.csv"), row.names = FALSE)
}
cat("\nfatto.\n")
