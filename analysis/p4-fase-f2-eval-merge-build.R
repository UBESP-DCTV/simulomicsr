#!/usr/bin/env Rscript
# Merge etichette design_role_v3 (3 batch) + validazione + calibrazione vs
# prior umano + build input Stadio 1 per il benchmark scalato (FASE F2).

suppressPackageStartupMessages({ devtools::load_all(quiet = TRUE); library(jsonlite) })

ws <- readRDS("analysis/p4-output/f2-eval-worksheet.rds")
ev <- ws$ev   # 756 sample: geo, series, string, molecule, trtctr_EP, gold

lab <- do.call(rbind, lapply(1:3, function(i)
  read.csv(sprintf("analysis/p4-output/f2-eval-labels-batch%d.csv", i), stringsAsFactors = FALSE)))
lab <- lab[!duplicated(lab$geo), ]
cat(sprintf("Etichette totali: %d (sample worksheet: %d)\n", nrow(lab), nrow(ev)))

# Enum valido?
valid_roles <- c("perturbed","case","secondary_arm","vehicle_control","untreated_control",
                 "negative_genetic_control","negative_inducer_control","baseline_t0",
                 "comparison","positive_control","bystander","excluded","unclear")
bad <- setdiff(unique(lab$design_role_v3), valid_roles)
stopifnot(length(bad) == 0)

# Coverage completo?
miss <- setdiff(ev$geo, lab$geo); extra <- setdiff(lab$geo, ev$geo)
cat(sprintf("Mancanti (no label): %d | extra (label senza sample): %d\n", length(miss), length(extra)))
if (length(miss)) cat("  primi mancanti:", paste(head(miss,10), collapse=", "), "\n")

g <- merge(ev, lab, by = "geo", all.x = TRUE)
g$gold_binary <- design_role_to_binary(g$design_role_v3)

# Calibrazione vs prior umano trtctr_EP (normalizza case)
ep <- tolower(as.character(g$trtctr_EP))
g$ep_binary <- ifelse(ep %in% c("treated"), "treated",
                ifelse(ep %in% c("control"), "control", NA_character_))
both <- !is.na(g$gold_binary) & !is.na(g$ep_binary)
agree <- sum(g$gold_binary[both] == g$ep_binary[both])
cat(sprintf("\nCalibrazione vs trtctr_EP umano (su %d sample con entrambi):\n", sum(both)))
cat(sprintf("  agreement binario: %.1f%% (%d/%d)\n", 100*agree/sum(both), agree, sum(both)))
cat("  (disaccordi attesi = correzioni design-aware: vehicle/NT-siRNA/multi-arm)\n")

cat("\nDistribuzione design_role_v3 (mio gold):\n")
print(sort(table(g$design_role_v3), decreasing = TRUE))
cat("\nDistribuzione binaria:\n"); print(table(g$gold_binary, useNA="ifany"))

# Salva gold + build stage1 input
saveRDS(g, "analysis/p4-output/f2-eval-gold.rds")
write.csv(g[, c("geo","series","design_role_v3","gold_binary","trtctr_EP")],
          "analysis/p4-output/f2-eval-gold.csv", row.names = FALSE)

input_s1 <- "analysis/input/p4-f2-eval-stage1-input.jsonl"
df1 <- data.frame(
  record_id        = g$geo,
  geo_accession    = g$geo,
  series_id        = g$series,
  string           = g$string,
  library_strategy = "RNA-Seq",
  organism         = "Homo sapiens",
  molecule_ch1     = g$molecule,
  stringsAsFactors = FALSE
)
# molecule_ch1 NA -> ometti campo per quel record (parita' con bacino)
con <- file(input_s1, "w")
for (i in seq_len(nrow(df1))) {
  rec <- as.list(df1[i, ])
  if (is.na(rec$molecule_ch1) || !nzchar(rec$molecule_ch1)) rec$molecule_ch1 <- NULL
  writeLines(jsonlite::toJSON(rec, auto_unbox = TRUE), con)
}
close(con)
cat(sprintf("\nStage1 input scritto: %s (%d record)\n", input_s1, nrow(df1)))
cat("Done merge-build.\n")
