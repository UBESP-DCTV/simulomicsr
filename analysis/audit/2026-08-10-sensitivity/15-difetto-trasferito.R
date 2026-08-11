#!/usr/bin/env Rscript
# analysis/audit/2026-08-10-sensitivity/15-difetto-trasferito.R
#
# LA MINACCIA PRINCIPALE al risultato del PASSO 1. Dire che TNF ed enzalutamide
# hanno peso contaminato 0,0% vale solo se il difetto NON sopravvive cambiando
# etichetta: se un confronto accusato cade sotto `n_min` ma un ALTRO confronto
# dello stesso studio — non accusato, con etichette diverse — porta lo stesso
# difetto, allora la contaminazione c'e' e questa misura la nasconde.
#
# Non e' decidibile con una regola. Questo script prepara il materiale per
# deciderlo leggendo: per ognuna delle 9 coppie (studio, gruppo) accusate a vuoto,
# mette accanto il confronto ACCUSATO (col meccanismo) e i confronti PULITI dello
# stesso studio che invece sono nel pooling. Etichette INTERE.
#
# Uso: Rscript analysis/audit/2026-08-10-sensitivity/15-difetto-trasferito.R
suppressPackageStartupMessages({ library(cli) })

OUT <- "analysis/audit/2026-08-10-sensitivity"
acc <- utils::read.csv(file.path(OUT, "10-accuse-sui-bracci.csv"), stringsAsFactors = FALSE)
R   <- readRDS(file.path(OUT, "10-record-esito.rds"))

dentro <- unique(acc[acc$stato == "dentro il pooling", c("cluster_id", "study_id")])
tutte  <- unique(acc[, c("cluster_id", "study_id")])
vuote  <- tutte[!paste(tutte$cluster_id, tutte$study_id) %in%
                  paste(dentro$cluster_id, dentro$study_id), ]
cli_alert_info("coppie (studio, gruppo) accusate senza NESSUN difetto dentro il pooling: {nrow(vuote)}")

con <- file(file.path(OUT, "15-difetto-trasferito.txt"), open = "wt")
writeLines(c(
  "MATERIALE PER UNA DECISIONE UMANA — il difetto sopravvive cambiando etichetta?",
  "",
  "Per ognuna delle coppie (studio, gruppo) i cui confronti accusati sono TUTTI",
  "fuori dal pooling (scartati da n_min), qui sotto ci sono:",
  "  [ACCUSATO, FUORI]  il confronto giudicato difettoso e il meccanismo;",
  "  [PULITO, DENTRO]   i confronti dello stesso studio che sono nel deliverable.",
  "",
  "La domanda per ciascuno: il meccanismo dell'accusa vale anche per il confronto",
  "che e' rimasto dentro? Se si', il peso contaminato di quel gruppo NON e' zero.",
  "Etichette intere, mai troncate.", ""), con)

for (i in seq_len(nrow(vuote))) {
  cid <- vuote$cluster_id[i]; sid <- vuote$study_id[i]
  a <- acc[acc$cluster_id == cid & acc$study_id == sid, ]
  b <- R[R$cluster_id == cid & R$study_id == sid & R$esito == "braccio", ]
  writeLines(sprintf("\n================ [%d/%d] %s in %s  (%s)",
                     i, nrow(vuote), sid, cid, a$stato[1]), con)
  for (k in seq_len(nrow(a))) {
    writeLines(sprintf("  [ACCUSATO, FUORI]  meccanismo: %s", a$meccanismo[k]), con)
    writeLines(sprintf("     TRATTATO : %s", a$etichetta_trattato[k]), con)
    writeLines(sprintf("     CONTROLLO: %s", a$etichetta_controllo[k]), con)
  }
  if (nrow(b) == 0L) writeLines("  (nessun braccio di questo studio nel pooling)", con)
  for (k in seq_len(nrow(b))) {
    writeLines(sprintf("  [PULITO, DENTRO]   n=%d vs %d", b$n_t[k], b$n_c[k]), con)
    writeLines(sprintf("     TRATTATO : %s", b$etichetta_trattato[k]), con)
    writeLines(sprintf("     CONTROLLO: %s", b$etichetta_controllo[k]), con)
  }
}
close(con)

# controllo del troncamento, come sempre nel progetto
lab <- c(acc$etichetta_trattato, acc$etichetta_controllo,
         R$etichetta_trattato[R$esito == "braccio"], R$etichetta_controllo[R$esito == "braccio"])
lab <- lab[!is.na(lab)]
n <- nchar(lab)
cli_alert_info("etichette: {length(n)} | max {max(n)} | mediana {stats::median(n)}")
for (s in c(40, 58, 64, 80)) {
  cnt <- sum(n == s)
  if (cnt > 5) cli_alert_warning("{cnt} etichette misurano esattamente {s} caratteri: possibile troncamento a monte")
}
cli_alert_success("scritto {file.path(OUT, '15-difetto-trasferito.txt')}")
