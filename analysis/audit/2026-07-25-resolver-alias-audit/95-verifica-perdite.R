# Le identita' RIMOSSE dal fix: erano sbagliate (bene) o corrette (danno)?
# Si guarda il TESTO SORGENTE vero, non l'ID.
suppressPackageStartupMessages({library(dplyr)})
OUT <- "analysis/audit/2026-07-25-resolver-alias-audit"
ba <- readRDS(file.path(OUT, "before-after.rds"))
pers <- ba |> filter(cambiato)
cat(sprintf("identita' cambiate: %d\n", nrow(pers)))
cat("\n=== casi da verificare: geni plausibili spariti ===\n")
for (id in c("HGNC:17563", "HGNC:18420", "HGNC:9884", "HGNC:16400", "HGNC:644",
             "HGNC:2524", "HGNC:28323", "HGNC:13203")) {
  s <- pers |> filter(id_old == id)
  if (!nrow(s)) next
  cat(sprintf("\n-- %s (%s) : %d campioni rimossi | nuovo id: %s\n", id, s$nome_old[1], nrow(s),
              paste(unique(substr(s$id_new, 1, 26)), collapse = ", ")))
  txt <- unique(substr(gsub("\\s+", " ", s$txt %||% ""), 1, 0))
  print(head(unique(data.frame(src_old = s$src_old, src_new = s$src_new,
                               nome_new = substr(s$nome_new, 1, 30))), 4), row.names = FALSE)
}
