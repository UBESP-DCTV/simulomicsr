#!/usr/bin/env Rscript
# 70-rilettura-poolati.R --- rilegge i gruppi incoerenti sui membri che sono
# EFFETTIVAMENTE entrati nel pool.
#
# Perche' solo gli incoerenti: la coerenza e' chiusa per sottoinsiemi. Se tutti i
# confronti di un gruppo misurano lo stesso contrasto, lo fa anche un qualunque
# suo sottoinsieme — quindi un gruppo giudicato coerente non puo' diventare
# incoerente perdendo studi. Il contrario si': un gruppo incoerente puo' essere
# ASSOLTO se lo studio che lo sporcava e' caduto. E' un argomento logico, non una
# misura: per questo lo si applica solo nella direzione che assolve, e i sei
# incoerenti si rileggono uno per uno sui membri veri.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE); library(arrow); library(dplyr)
})

POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
V13  <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
OUT  <- "analysis/audit/2026-07-29-etichette-v13"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

d <- readRDS(file.path(OUT, "deliverable-v13-poolato.rds"))
inc <- d[d$coherence_verdict == "incoherent", ]
cat("gruppi incoerenti nel poolato:", nrow(inc), "\n")

ps <- arrow::open_dataset(file.path(POOL, "per_study_de.parquet"))
sp <- ps %>% filter(cluster_id %in% inc$cluster_id) %>%
  distinct(cluster_id, study_id) %>% collect()
studi_pool <- split(sp$study_id, sp$cluster_id)

asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% inc$cluster_id, ]
asg$study <- sub("__.*$", "", asg$record_id)

s2 <- simulomicsr:::.load_stage2_master(STAGE2)
need <- unique(asg$record_id)
lab <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
for (study in s2) {
  sid <- study$series_id
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    rid <- sprintf("%s__%s", sid, cmp$comparison_id)
    if (!rid %in% need) next
    tg <- rgl[[cmp$treated_group]]; cg <- rgl[[cmp$control_group]]
    if (is.null(tg) || is.null(cg)) next
    assign(rid, list(tl = lab_of(tg, cmp$treated_group), cl = lab_of(cg, cmp$control_group)),
           envir = lab)
  }
}

zz <- file(file.path(OUT, "rilettura-incoerenti-poolati.txt"), open = "wt")
sink(zz)
cat("I SEI GRUPPI INCOERENTI, LETTI SUI MEMBRI CHE SONO ENTRATI NEL POOL\n")
cat("[POOLATO] = lo studio e' nel pool · [CADUTO] = scartato (nessun controllo interno)\n")
for (i in seq_len(nrow(inc))) {
  cid <- inc$cluster_id[i]
  dentro <- unique(studi_pool[[cid]])
  righe <- asg[asg$cluster_id == cid, ]
  cat("\n\n=============================================================\n")
  cat(sprintf("%s  (%s)\n", inc$contrast_entity_label[i], inc$ckey[i]))
  cat(sprintf("  k poolato = %d (censiti %d studi, poolati %d)\n",
              inc$k_effective[i], inc$n_studi_censiti[i], inc$n_studi_poolati[i]))
  cat(sprintf("  motivo del verdetto: %s\n", inc$coherence_reason[i]))
  vis <- character(0)
  for (j in seq_len(nrow(righe))) {
    e <- get0(righe$record_id[j], envir = lab, inherits = FALSE)
    if (is.null(e)) next
    key <- paste(righe$study[j], e$tl, e$cl)
    if (key %in% vis) next
    vis <- c(vis, key)
    # NIENTE TRONCAMENTO. Il bundle del censimento tagliava a 58/40 caratteri e
    # su GSE126517 il pezzo tagliato conteneva l'informazione decisiva
    # ("...and IFN-alpha for 18 hours"): un verdetto e' stato dato su meta' frase.
    cat(sprintf("   %-9s %-9s %s\n       => %s\n",
                if (righe$study[j] %in% dentro) "[POOLATO]" else "[CADUTO] ",
                righe$study[j], e$tl, e$cl))
  }
}
sink(); close(zz)
cat("scritto", file.path(OUT, "rilettura-incoerenti-poolati.txt"), "\n")
