#!/usr/bin/env Rscript
# 110-materiale-tutti-191.R --- il rilevatore di materiale su TUTTI e 191, e il
# suo accordo con la lettura a mano.
#
# Un rilevatore che passa i test su fixture ma non e' mai stato confrontato col
# giudizio umano sui dati veri non vale niente: e' esattamente il modo in cui in
# questo progetto tre strumenti sono stati ciechi. I 20 gruppi di malattia sono
# stati letti uno per uno il 2026-07-31 (malattie-membri.txt): quello e' il
# metro, e qui si misura l'accordo, disaccordi compresi.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/110-materiale-tutti-191.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(cli) })

V13    <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
POOL   <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
OUT    <- "analysis/audit/2026-07-31-layer-b-v13"

d <- readRDS("analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds")

asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% d$cluster_id, ]
asg$study <- sub("__.*$", "", asg$record_id)

sp <- arrow::open_dataset(file.path(POOL, "per_study_de.parquet")) |>
  dplyr::filter(cluster_id %in% d$cluster_id) |>
  dplyr::distinct(cluster_id, study_id) |> dplyr::collect()
dentro <- paste(sp$cluster_id, sp$study_id, sep = "\r")

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
    assign(rid, c(lab_of(t, cmp$treated_group), lab_of(c, cmp$control_group)), envir = lab)
  }
}
rm(s2); gc(verbose = FALSE)

# una riga per (cluster, studio, etichetta) — entrambi i bracci
righe <- list()
for (i in seq_len(nrow(asg))) {
  e <- get0(asg$record_id[i], envir = lab, inherits = FALSE)
  if (is.null(e)) next
  if (!(paste(asg$cluster_id[i], asg$study[i], sep = "\r") %in% dentro)) next
  righe[[length(righe) + 1L]] <- data.frame(
    cluster_id = asg$cluster_id[i], study_id = asg$study[i],
    label = e, stringsAsFactors = FALSE)
}
membri <- do.call(rbind, righe)
cli_alert_info("etichette raccolte: {nrow(membri)} su {length(unique(membri$cluster_id))} cluster")
cli_alert_info("lunghezza max: {max(nchar(membri$label))} caratteri — nessun troncamento")

mat <- detect_mixed_material(membri)
cli_alert_success("classificati {nrow(mat)} cluster")

cli_h2("Riepilogo sui 191")
cat(sprintf("  gruppi con materiale MISTO (in vitro + primario): %d (%.1f%%)\n",
            sum(mat$materiale_misto), 100 * mean(mat$materiale_misto)))
cat(sprintf("  solo in vitro: %d | solo primario: %d | tutto ignoto: %d\n",
            sum(mat$n_studi_model > 0 & mat$n_studi_primary == 0),
            sum(mat$n_studi_primary > 0 & mat$n_studi_model == 0),
            sum(mat$n_studi_model == 0 & mat$n_studi_primary == 0)))

# --- accordo con la lettura a mano dei 20 gruppi di malattia ---------------
# Giudizio umano dato leggendo malattie-membri.txt il 2026-07-31, PRIMA di
# guardare l'output del rilevatore.
umano_misto <- c("MeSH:D010300",   # Parkinson: iPSC 73%
                 "MeSH:D015179",   # Colorettale: sferoidi 47%
                 "MeSH:D002292",   # Carcinoma renale: colture 31%
                 "MeSH:D006816",   # Huntington: progenitori gliali 57%
                 "MeSH:D013167",   # Spondilite: differenziamento adipogenico 80%
                 "MeSH:D016640")   # Diabete gestazionale: progenitori endoteliali
mal <- d[grepl("^MeSH:", d$contrast_entity), ]
mal$rilevato <- mat$materiale_misto[match(mal$cluster_id, mat$cluster_id)]
mal$umano <- mal$contrast_entity %in% umano_misto

cli_h2("Accordo col giudizio umano sui 20 gruppi di malattia")
tab <- table(rilevato = mal$rilevato, umano = mal$umano)
print(tab)
cat(sprintf("\n  accordo: %d su %d (%.0f%%)\n",
            sum(mal$rilevato == mal$umano), nrow(mal),
            100 * mean(mal$rilevato == mal$umano)))
disc <- mal[mal$rilevato != mal$umano, ]
if (nrow(disc) > 0L) {
  cat("\n  DISACCORDI (vanno detti, non nascosti):\n")
  for (i in seq_len(nrow(disc))) {
    cat(sprintf("    %-38s rilevatore=%-5s umano=%-5s (model=%d primary=%d unknown=%d)\n",
                disc$contrast_entity_label[i], disc$rilevato[i], disc$umano[i],
                mat$n_studi_model[match(disc$cluster_id[i], mat$cluster_id)],
                mat$n_studi_primary[match(disc$cluster_id[i], mat$cluster_id)],
                mat$n_studi_unknown[match(disc$cluster_id[i], mat$cluster_id)]))
  }
}

saveRDS(mat, file.path(OUT, "materiale-tutti-191.rds"))
write.csv(mat, file.path(OUT, "materiale-tutti-191.csv"), row.names = FALSE)
cli_alert_success("Scritta materiale-tutti-191.rds e .csv")
