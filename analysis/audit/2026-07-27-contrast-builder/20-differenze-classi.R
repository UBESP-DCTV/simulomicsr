# Le differenze fra il codice di pacchetto e il gate misurato, classe per classe.
#
# Il piano dice che ogni classe deve avere una spiegazione scritta: senza, non si
# va al GO. Qui si estraggono gli esempi che servono a giudicare, con accanto i
# campi su cui la decisione si basa (delta, entita' risolta, fonte).
suppressPackageStartupMessages(library(dplyr))
OUT <- "analysis/audit/2026-07-27-contrast-builder"
r <- readRDS(file.path(OUT, "equivalenza-builder.rds")); pm <- r$pm
old <- ifelse(pm$dr %in% c("ok", "ok_combo"), "ok", pm$dr)
pm$new_dr_lab <- ifelse(pm$new_dr == "ok" & pm$new_src == "COMBO", "ok_combo", pm$new_dr)
pm$transizione <- paste(pm$dr, "->", pm$new_dr_lab)
d <- pm[(old == "ok") != (pm$new_dr == "ok") |
        (old == "ok" & pm$new_dr == "ok" & pm$entity != pm$new_entity), ]

cat("=== differenze totali:", nrow(d), "===\n\n")
tb <- sort(table(d$transizione), decreasing = TRUE)
print(tb)

campi <- c("study_id", "treated_label", "control_label", "dtval", "dcval",
           "dclasses", "canonical_name", "ce2_id", "ce2_name", "ce2_cand",
           "entity", "new_entity", "new_src", "onc", "dr", "new_dr")

sink(file.path(OUT, "differenze-classi.txt"))
for (cls in names(tb)) {
  x <- d[d$transizione == cls, ]
  cat("\n\n################################################################\n")
  cat("## CLASSE:", cls, " (", nrow(x), "membri )\n")
  cat("################################################################\n")
  # quante coppie (entita' gate, entita' pacchetto) distinte
  cat("\n-- coppie entita' distinte (gate -> pacchetto), top 15:\n")
  cp <- x |> count(entity, new_entity, new_src, sort = TRUE) |> head(15)
  print(as.data.frame(cp), row.names = FALSE)
  cat("\n-- studi coinvolti:", length(unique(x$study_id)), "\n")
  cat("\n-- esempi (fino a 8):\n")
  for (i in seq_len(min(8L, nrow(x)))) {
    cat("\n  [", i, "] studio", x$study_id[i], "\n")
    cat("      trattato : ", substr(x$treated_label[i], 1, 100), "\n")
    cat("      controllo: ", substr(x$control_label[i], 1, 100), "\n")
    cat("      delta    : [", substr(x$dtval[i], 1, 80), "] vs [",
        substr(x$dcval[i], 1, 60), "] classi:", x$dclasses[i], "\n")
    cat("      nome cluster (gate): ", x$canonical_name[i], " | on-contrast:", x$onc[i], "\n")
    cat("      ce2 (delta risolto): ", x$ce2_id[i], "=", x$ce2_name[i],
        " da candidato [", x$ce2_cand[i], "]\n")
    cat("      GATE     : ", x$dr[i], "->", x$entity[i], "\n")
    cat("      PACCHETTO: ", x$new_dr[i], "->", x$new_entity[i], " (fonte:", x$new_src[i], ")\n")
  }
}
sink()
write.csv(d[, campi], file.path(OUT, "differenze-tutte.csv"), row.names = FALSE)
cat("\nscritti differenze-classi.txt e differenze-tutte.csv\n")
