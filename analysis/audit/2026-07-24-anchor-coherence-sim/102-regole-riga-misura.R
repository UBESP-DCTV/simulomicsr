# Applica le REGOLE DI RIGA raffinate alle stesse 1.851 righe gia' verificate a
# mano (i 143 gruppi coerenti) e stampa OGNI segnalazione per la verifica.
# Confronto col rilevatore grezzo di 100-difetti-riga.R: quante segnalazioni in
# meno, e quali righe cambiano verdetto.
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
source(file.path(SC, "regole-riga.R"))
oe <- .load_ontology_dicts()
r <- readRDS(file.path(SC, "fase1-v9-results.rds")); pm <- r$pm
ver <- read.csv(file.path(SC, "v10-census-verdicts-FINAL.csv"), stringsAsFactors = FALSE)
coh <- ver$ckey[ver$verdetto == "COERENTE"]
m <- pm[pm$elig & pm$ckey %in% coh, ]
u <- m |> group_by(ckey, study_id, treated_label, control_label) |>
  summarise(n = n(), cls = dom_cls[1], entity = entity[1],
            nome = canonical_name[1], ce2 = ce2_name[1], cand = ce2_cand[1], .groups = "drop")
cat("righe da controllare:", nrow(u), "in", n_distinct(u$ckey), "gruppi\n")

## i token del nome dell'entita' non sono identificatori di linea ("R1881",
## "AD169" appartengono al nome del composto/ceppo, non alla linea cellulare)
tok_entita <- function(...) {
  s <- tolower(paste(stats::na.omit(c(...)), collapse = " "))
  s <- gsub("[^a-z0-9 -]+", " ", s)
  t <- strsplit(s, " +")[[1]]
  unique(t[nzchar(t)])
}
cache <- new.env(parent = emptyenv())
res <- character(nrow(u))
for (i in seq_len(nrow(u))) {
  es <- tok_entita(u$nome[i], u$ce2[i], sub("^[A-Z]+:", "", u$entity[i]))
  res[i] <- rr_difetto_riga(u$treated_label[i], u$control_label[i], u$cls[i], u$entity[i],
                            oe, cache, extra_stop = es)
  if (i %% 400 == 0) cat("  ", i, "/", nrow(u), "\n")
}
u$regola <- res; u$difetto <- nzchar(res)
cat("\n=== SEGNALAZIONI DELLE REGOLE RAFFINATE ===\n")
cat(sprintf("righe: %d | segnalate: %d (%.1f%%)\n", nrow(u), sum(u$difetto), 100 * mean(u$difetto)))
print(table(u$regola[u$difetto]))
cat("\nper classe:\n"); print(table(u$cls[u$difetto]))

old <- read.csv(file.path(SC, "difetti-riga.csv"), stringsAsFactors = FALSE)
u2 <- left_join(u, old |> select(ckey, study_id, treated_label, control_label, grezzo = difetto),
                by = c("ckey", "study_id", "treated_label", "control_label"))
cat("\n=== CONFRONTO COL RILEVATORE GREZZO ===\n")
print(table(grezzo = u2$grezzo, raffinato = u2$difetto))

con <- file(file.path(SC, "regole-riga-segnalate.txt"), "w")
writeLines(sprintf("# SEGNALAZIONI DELLE REGOLE RAFFINATE — %d righe su %d",
                   sum(u$difetto), nrow(u)), con)
s <- u2[u2$difetto, ] |> arrange(regola, ckey, study_id)
for (v in unique(s$regola)) {
  ss <- s[s$regola == v, ]
  writeLines(sprintf("\n\n######## %s — %d righe ########", v, nrow(ss)), con)
  for (i in seq_len(nrow(ss))) {
    writeLines(sprintf("[%s|%s|%s] %s\n    T: %s\n    C: %s",
                       ss$cls[i], ss$study_id[i], ifelse(ss$grezzo[i], "gia-noto", "NUOVO"),
                       ss$ckey[i], ss$treated_label[i], ss$control_label[i]), con)
  }
}
## righe che il rilevatore grezzo segnalava e le regole NON segnalano piu'
n <- u2[!u2$difetto & u2$grezzo, ] |> arrange(cls, ckey)
writeLines(sprintf("\n\n######## NON PIU' SEGNALATE (grezzo si', regole no) — %d righe ########", nrow(n)), con)
for (i in seq_len(nrow(n))) {
  writeLines(sprintf("[%s|%s] %s\n    T: %s\n    C: %s", n$cls[i], n$study_id[i], n$ckey[i],
                     n$treated_label[i], n$control_label[i]), con)
}
close(con)
write.csv(u, file.path(SC, "regole-riga-esito.csv"), row.names = FALSE)
cat("\nscritto regole-riga-segnalate.txt + regole-riga-esito.csv\n")
