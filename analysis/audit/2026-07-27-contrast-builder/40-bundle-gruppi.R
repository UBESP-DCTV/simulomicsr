# Bundle di lettura per TUTTI i gruppi poolabili prodotti dal codice di pacchetto.
#
# Il 97,9% della simulazione NON si trasferisce: la composizione dei gruppi e'
# cambiata (150 chiavi invece di 144, e non sono le stesse). Va riletto tutto,
# uno per uno, come nelle sessioni precedenti — mai a campione.
#
# Un bundle per gruppo: identita' del contrasto + tutti i confronti tenuti
# (studio, trattato -> controllo), piu' i confronti SCARTATI della stessa entita'
# (servono a giudicare se lo scarto era giusto).
suppressPackageStartupMessages(library(dplyr))
OUT <- "analysis/audit/2026-07-27-contrast-builder"
r <- readRDS(file.path(OUT, "equivalenza-builder.rds"))
pm <- r$pm; agg <- r$agg

el <- pm[pm$new_dr == "ok" & !is.na(pm$new_entity), ]
el$ckey <- paste(el$new_entity, el$new_verso, el$new_ct, sep = "||")
sel <- el[el$ckey %in% agg$ckey, ]

# nome leggibile: il primo nome risolto non vuoto fra i membri
nome_di <- function(x) {
  n <- c(x$ce2_name, x$canonical_name)
  n <- n[!is.na(n) & nzchar(n)]
  if (length(n)) n[1] else NA_character_
}

ord <- agg |> arrange(desc(k))
sink(file.path(OUT, "bundle-gruppi.txt"))
cat("BUNDLE DEI GRUPPI POOLABILI k>=3 —", nrow(agg), "gruppi\n")
cat("prodotti dal codice di pacchetto (.ca_member_contrast) sui 38.440 contrasti\n")
cat("Ogni gruppo: identita' del contrasto, confronti TENUTI, confronti SCARTATI della stessa entita'.\n")
for (i in seq_len(nrow(ord))) {
  ck <- ord$ckey[i]
  x <- sel[sel$ckey == ck, ]
  scartati <- pm[pm$new_dr != "ok" & !is.na(pm$new_entity) & pm$new_entity == ord$entita[i], ]
  cat("\n\n===============================================================\n")
  cat(sprintf("[%03d/%03d] %s\n", i, nrow(ord), ck))
  cat(sprintf("  nome: %s | k=%d studi | n=%d confronti\n", nome_di(x), ord$k[i], nrow(x)))
  cat("  --- CONFRONTI TENUTI ---\n")
  u <- unique(x[, c("study_id", "treated_label", "control_label")])
  for (j in seq_len(nrow(u))) {
    cat(sprintf("   %-12s %s  =>  %s\n", u$study_id[j],
                substr(u$treated_label[j], 1, 78), substr(u$control_label[j], 1, 58)))
  }
  if (nrow(scartati) > 0L) {
    us <- unique(scartati[, c("study_id", "treated_label", "control_label", "new_dr")])
    cat("  --- SCARTATI (stessa entita') ---\n")
    for (j in seq_len(min(12L, nrow(us)))) {
      cat(sprintf("   %-12s [%s] %s => %s\n", us$study_id[j], us$new_dr[j],
                  substr(us$treated_label[j], 1, 60), substr(us$control_label[j], 1, 45)))
    }
    if (nrow(us) > 12L) cat("   ... e altri", nrow(us) - 12L, "\n")
  }
}
sink()

# indice compatto per il verdetto
idx <- ord |> mutate(nome = vapply(ckey, function(k) {
  nm <- nome_di(sel[sel$ckey == k, ]); if (is.na(nm)) "" else nm }, character(1))) |>
  select(ckey, entita, verso, k, n, nome)
write.csv(idx, file.path(OUT, "gruppi-indice.csv"), row.names = FALSE)
cat("scritti bundle-gruppi.txt e gruppi-indice.csv (", nrow(ord), "gruppi )\n")
