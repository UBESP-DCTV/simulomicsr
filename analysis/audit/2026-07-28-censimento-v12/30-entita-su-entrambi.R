#!/usr/bin/env Rscript
# MISURA: in quanti confronti del deliverable l'entita' del gruppo e' presente
# ANCHE nel braccio di controllo?
#
# Se lo e', quel confronto NON misura quell'entita': la tiene costante e misura
# altro (GSE233083: "TGF-β1 + 3C" vs "TGF-β1 + DMSO" misura 3C, non TGF-β1).
# Un membro cosi' dentro una meta-analisi ne sposta la stima verso un effetto
# che non c'entra.
#
# Il metro e' quello del codice: gli stessi resolver che il gate usa per dire
# "questo e' un agente" (.ca_agent_id), applicati al braccio di controllo.
# Non e' una regola nuova: e' la stessa che .ca_combo_from_labels gia' calcola
# e poi butta via quando gli agenti residui sono meno di due.
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
ac <- new.env(parent = emptyenv())
# stessa estrazione di .ca_combo_from_labels, applicata a un lato solo
agenti_di <- function(testo) {
  s <- simulomicsr:::.ca_drop_doses(testo)
  toks <- strsplit(gsub("[^a-z0-9 -]", " ", s), "[^a-z0-9-]+")[[1L]]
  toks <- toks[nzchar(toks) & nchar(gsub("[^a-z0-9]", "", toks)) >= 3L &
                 !(toks %in% simulomicsr:::.CG_GENERIC) &
                 !(toks %in% simulomicsr:::.CG_CONNECTORS)]
  ids <- character(0)
  for (tk in unique(toks)) {
    a <- simulomicsr:::.ca_agent_id(tk, oe, ac)
    if (nzchar(a)) ids <- c(ids, a)
  }
  unique(ids)
}

cat("misuro su", nrow(asg), "confronti...\n")
res <- vector("list", nrow(asg))
t0 <- Sys.time()
for (i in seq_len(nrow(asg))) {
  if (i %% 500 == 0) cat("  ", i, "/", nrow(asg), " (",
                         round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), "min )\n")
  e <- get0(asg$record_id[i], envir = lab, inherits = FALSE)
  if (is.null(e)) next
  ent <- asg$entita[i]
  if (is.na(ent) || startsWith(ent, "COMBO:")) next     # le combo sono entita' a se'
  a_ctrl <- agenti_di(paste(e$cl, e$cfl))
  a_trat <- agenti_di(paste(e$tl, e$tfl))
  res[[i]] <- data.frame(
    record_id = asg$record_id[i], ckey = asg$ckey[i], entita = ent, study = e$study,
    ent_nel_controllo = ent %in% a_ctrl,
    ent_nel_trattato  = ent %in% a_trat,
    n_agenti_trattato = length(a_trat), n_agenti_controllo = length(a_ctrl),
    tl = e$tl, cl = e$cl, stringsAsFactors = FALSE)
}
r <- do.call(rbind, res)
saveRDS(r, file.path(OUT, "entita-su-entrambi.rds"))

cat("\n=== ESITO ===\n")
cat("confronti misurati:", nrow(r), "\n")
bad <- r[r$ent_nel_controllo, ]
cat("confronti in cui l'entita' del gruppo e' ANCHE nel controllo:", nrow(bad),
    sprintf("(%.1f%%)\n", 100 * nrow(bad) / nrow(r)))
cat("gruppi toccati:", length(unique(bad$ckey)), "su", length(unique(r$ckey)), "\n")
if (nrow(bad)) {
  tb <- sort(table(bad$ckey), decreasing = TRUE)
  cat("\n--- gruppi piu' colpiti ---\n")
  for (i in seq_len(min(15L, length(tb)))) {
    ck <- names(tb)[i]
    tot <- sum(r$ckey == ck)
    cat(sprintf("  %-52s %d/%d confronti\n", substr(ck, 1, 52), tb[[i]], tot))
  }
  cat("\n--- esempi (primi 15) ---\n")
  for (i in seq_len(min(15L, nrow(bad))))
    cat(sprintf("  %-11s %-14s %-42s => %s\n", bad$study[i], bad$entita[i],
                substr(bad$tl[i], 1, 42), substr(bad$cl[i], 1, 34)))
  write.csv(bad, file.path(OUT, "entita-su-entrambi.csv"), row.names = FALSE)
}
cat("\nfatto.\n")
