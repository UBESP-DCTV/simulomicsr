# 47-membri.R — i confronti dei gruppi con piu' nomi, per 47-nome-del-modello.py
r <- readRDS("analysis/audit/2026-11-07-S9-greche-e-corsie/30-due-regimi.rds")
key <- paste(r$entity_off, r$direction_off, r$control_key_off, sep = "||")
el <- r$eleggibile & r$scarto_off == ""
g <- c("STR:irradiation", "STR:radiation", "STR:ifna", "HGNC:5417", "CHEBI:17823",
       "STR:1_25_oh_2d3", "STR:1_25d3", "STR:1alpha_25_oh_2d3")
x <- r[el & key %in% paste0(g, "||gain||vehicle_untreated"), c("record_id", "study", "entity_off")]
write.csv(x, "analysis/audit/2026-11-07-S9-greche-e-corsie/47-membri.csv", row.names = FALSE)
