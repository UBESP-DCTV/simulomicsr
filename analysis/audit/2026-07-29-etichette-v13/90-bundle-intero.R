#!/usr/bin/env Rscript
# 90-bundle-intero.R --- il bundle di lettura SENZA TRONCAMENTI, per i gruppi
# poolati che hanno almeno un membro la cui etichetta il bundle del censimento
# tagliava (58 caratteri sul trattato, 40 sul controllo).
#
# Perche' esiste: su GSE126517 il pezzo tagliato conteneva l'informazione
# decisiva ("...and IFN-alpha for 18 hours") e il verdetto e' stato dato su meta'
# frase. Misura del danno: 462 confronti su 5.398 (8,6%) avevano almeno un lato
# tagliato, e toccano 99 dei 191 gruppi poolati.
#
# I 92 gruppi senza alcuna etichetta tagliata NON vengono rigenerati: il loro
# verdetto poggia su testo che era gia' intero.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V13 <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
OUT <- "analysis/audit/2026-07-29-etichette-v13"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

d  <- readRDS(file.path(OUT, "deliverable-v13-poolato.rds"))
tg <- readRDS(file.path(OUT, "gruppi-testo-tagliato.rds"))
da_rileggere <- d[d$cluster_id %in% tg$cluster_id[tg$testo_tagliato], ]
cat("gruppi poolati da rileggere:", nrow(da_rileggere), "su", nrow(d), "\n")

asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% da_rileggere$cluster_id, ]
asg$study <- sub("__.*$", "", asg$record_id)

# quali studi sono davvero entrati nel pool
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
sp <- arrow::open_dataset(file.path(POOL, "per_study_de.parquet")) |>
  dplyr::filter(cluster_id %in% da_rileggere$cluster_id) |>
  dplyr::distinct(cluster_id, study_id) |> dplyr::collect()
studi_pool <- split(sp$study_id, sp$cluster_id)

s2 <- simulomicsr:::.load_stage2_master(STAGE2)
need <- unique(asg$record_id)
lab <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
for (study in s2) {
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    rid <- sprintf("%s__%s", study$series_id, cmp$comparison_id)
    if (!rid %in% need) next
    t <- rgl[[cmp$treated_group]]; c <- rgl[[cmp$control_group]]
    if (is.null(t) || is.null(c)) next
    assign(rid, list(tl = lab_of(t, cmp$treated_group), cl = lab_of(c, cmp$control_group)),
           envir = lab)
  }
}
rm(s2); gc(verbose = FALSE)

da_rileggere <- da_rileggere[order(-da_rileggere$k_effective), ]
zz <- file(file.path(OUT, "bundle-intero-99.txt"), open = "wt")
sink(zz)
cat("BUNDLE SENZA TRONCAMENTI —", nrow(da_rileggere), "gruppi poolati con almeno un'etichetta\n")
cat("che il bundle del censimento tagliava. Domanda: tutti i confronti POOLATI\n")
cat("misurano lo stesso contrasto? (i [CADUTO] non entrano nella meta-analisi)\n")
for (i in seq_len(nrow(da_rileggere))) {
  cid <- da_rileggere$cluster_id[i]
  dentro <- unique(studi_pool[[cid]])
  righe <- asg[asg$cluster_id == cid, ]
  cat("\n\n=============================================================\n")
  cat(sprintf("[%03d/%03d] %s || %s || %s\n", i, nrow(da_rileggere),
              da_rileggere$contrast_entity[i], da_rileggere$contrast_direction[i],
              da_rileggere$contrast_control_key[i]))
  cat(sprintf("  etichetta: %s | k poolato = %d | verdetto attuale: %s\n",
              da_rileggere$contrast_entity_label[i], da_rileggere$k_effective[i],
              da_rileggere$coherence_verdict[i]))
  vis <- character(0)
  for (j in seq_len(nrow(righe))) {
    e <- get0(righe$record_id[j], envir = lab, inherits = FALSE)
    if (is.null(e)) next
    if (!(righe$study[j] %in% dentro)) next   # solo cio' che entra nel pool
    key <- paste(righe$study[j], e$tl, e$cl)
    if (key %in% vis) next
    vis <- c(vis, key)
    cat(sprintf("   %-10s %s\n          => %s\n", righe$study[j], e$tl, e$cl))
  }
}
sink(); close(zz)
cat("scritto", file.path(OUT, "bundle-intero-99.txt"), "\n")
