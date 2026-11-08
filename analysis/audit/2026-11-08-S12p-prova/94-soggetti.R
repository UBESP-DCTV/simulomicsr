#!/usr/bin/env Rscript
# S12p: classifica i 45 confronti confermati solo per i soggetti con le regole del PI (S12, decisioni 2 e 3):
# difetto se, nel disegno di trattamento, i donatori sono disgiunti; in ogni disegno, se sesso o eta' sono disgiunti.
# Parziale, uguale o non detto: avviso (esce dai difetti). Scrive l'elenco finale dei difetti confermati.
# Uso: Rscript analysis/audit/2026-11-08-S12p-prova/94-soggetti.R > analysis/audit/2026-11-08-S12p-prova/94-out.txt
suppressPackageStartupMessages(library(jsonlite))
DIR <- "analysis/audit/2026-11-08-S12p-prova"; LET <- "/home/user/S12p-soggetti-20261108"
k <- fromJSON(file.path(DIR, "82-chiave-verifica.json"))
attesi <- unlist(lapply(sort(list.files(LET, pattern = "^lotto-[0-9]+[.]txt$", full.names = TRUE)), readLines))
R <- do.call(rbind, lapply(sort(list.files(file.path(LET, "risposte"), pattern = "[.]jsonl$", full.names = TRUE)), function(f)
  do.call(rbind, lapply(readLines(f, encoding = "UTF-8"), function(l) { r <- fromJSON(l); as.data.frame(r[c("id", "disegno", "donatori", "sesso", "eta")], stringsAsFactors = FALSE) }))))
V <- c("disgiunti", "parziali", "uguali", "non_detto")
ok <- R$id %in% attesi & R$disegno %in% c("trattamento", "malati_contro_sani") & R$donatori %in% V & R$sesso %in% V & R$eta %in% V
cat(sprintf("letture valide: %d su %d attese (estranee %d)\n", sum(ok), length(attesi), sum(!R$id %in% attesi)))
R <- R[ok, ]; R$record_id <- k$record_id[match(R$id, k$id)]
R$difetto <- (R$disegno == "trattamento" & R$donatori == "disgiunti") | R$sesso == "disgiunti" | R$eta == "disgiunti"
cat("disegno:\n"); print(table(R$disegno)); cat("donatori per disegno:\n"); print(table(R$disegno, R$donatori))
cat(sprintf("difetti (disgiunti secondo le regole del PI): %d; avvisi (parziali, uguali o non detti): %d\n", sum(R$difetto), sum(!R$difetto)))
ctrl <- R[grepl("^GSE219065__|^GSE185051__", R$record_id), c("record_id", "disegno", "donatori", "sesso", "eta", "difetto")]
cat("controlli (devono essere difetti):\n"); print(ctrl, row.names = FALSE)
conf <- read.csv(file.path(DIR, "90-difetti-confermati.csv"), stringsAsFactors = FALSE)
fuori <- R$record_id[!R$difetto]
fin <- conf[!conf$record_id %in% fuori, ]
write.csv(R, file.path(DIR, "94-soggetti.csv"), row.names = FALSE); write.csv(fin, file.path(DIR, "94-difetti-finali.csv"), row.names = FALSE)
cat(sprintf("\ndifetti confermati dopo le regole sui soggetti: %d (tolti %d avvisi), in %d studi\n", nrow(fin), length(fuori), length(unique(sub("__.*$", "", fin$record_id)))))
