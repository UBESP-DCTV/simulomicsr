#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/80-usciti.R
#
# DOVE FINISCONO I 271 STUDI CHE ESCONO DAL DELIVERABLE.
#
# La misura precedente (70-leva.R) guarda solo dentro il deliverable, e li' il
# movimento risulta quasi tutto «lo studio esce» / «lo studio entra». Ma quella
# e' una porta, non una causa: uno studio esce dal deliverable anche quando la
# sua chiave di contrasto cambia e la chiave NUOVA non arriva a k>=3, cioe' non
# diventa una meta-analisi. Per sapere che cosa correggere a monte bisogna
# guardare dove va a finire nello STADIO 3, dove ci sono tutti i cluster e non
# solo quelli poolabili.
#
# E' anche la verifica della sola aspettativa concreta del handout: «13 studi
# delle cinque entita' bandiera si sono spostati perche' il tipo di controllo e'
# stato normalizzato diversamente — da vehicle_untreated a unknown, ctrl, nt, nc,
# sicontrol, undiff, pre treatment».
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/80-usciti.R

suppressPackageStartupMessages({ library(arrow); library(cli); devtools::load_all(".", quiet = TRUE) })
OUT    <- "analysis/audit/2026-08-20-rilettura-194"
S3_A3  <- "analysis/p4-output/20260818T110906Z-stage3-v16-7f986159"
S3_RIF <- "analysis/p4-output/20260814T025911Z-stage3-v16-7f986159"

carica <- function(d) {
  cl <- readRDS(file.path(d, "clusters.rds"))
  a  <- as.data.frame(read_parquet(file.path(d, "assignments.parquet"),
                                   col_select = c("record_id", "cluster_id")))
  a$study_id <- vapply(strsplit(a$record_id, "__", fixed = TRUE), `[`, character(1), 1L)
  cl <- cl[!is.na(cl$mode) & cl$mode == "cgroup", ]
  a  <- a[a$cluster_id %in% cl$cluster_id, ]
  i  <- match(a$cluster_id, cl$cluster_id)
  a$entita    <- cl$contrast_entity[i]
  a$verso     <- cl$contrast_direction[i]
  a$controllo <- cl$contrast_control_key[i]
  a
}
cli_alert_info("carico i due Stadio 3...")
A <- carica(S3_A3); R <- carica(S3_RIF)

lev <- read.csv(file.path(OUT, "leva-chiave-contrasto.csv"), stringsAsFactors = FALSE)
usciti <- lev$study_id[lev$esito == "esce del tutto dal deliverable"]
cli_alert_info("studi usciti dal deliverable: {length(usciti)}")

sa <- split(A[, c("entita", "verso", "controllo")], A$study_id)
sr <- split(R[, c("entita", "verso", "controllo")], R$study_id)

esito <- character(0)
for (s in usciti) {
  a <- sa[[s]]; r <- sr[[s]]
  if (is.null(a)) { esito[s] <- "sparisce dai cluster del contrasto"; next }
  if (is.null(r)) { esito[s] <- "non c'era nemmeno prima"; next }
  ea <- unique(a$entita); er <- unique(r$entita)
  comuni <- intersect(ea, er)
  if (length(comuni) == 0L) { esito[s] <- "cambia l'ENTITA' anche in Stadio 3"; next }
  # per le entita' in comune: cambia il verso o il tipo di controllo?
  vr <- unique(r$verso[r$entita %in% comuni]);  va <- unique(a$verso[a$entita %in% comuni])
  cr <- unique(r$controllo[r$entita %in% comuni]); ca <- unique(a$controllo[a$entita %in% comuni])
  esito[s] <- if (!identical(sort(vr), sort(va))) "stessa entita', cambia il VERSO"
              else if (!identical(sort(cr), sort(ca))) "stessa entita', cambia il TIPO DI CONTROLLO"
              else "stessa chiave in Stadio 3: esce per il gate (k o n_min)"
}
cli_h2("Dove finiscono, guardati nello Stadio 3")
tb <- sort(table(esito), decreasing = TRUE)
for (i in seq_along(tb))
  cat(sprintf("  %4d  (%5.1f%%)  %s\n", tb[i], 100*tb[i]/length(usciti), names(tb)[i]))

cli_h2("Il tipo di controllo, quando cambia: da che cosa a che cosa")
dett <- list()
for (s in names(esito)[esito == "stessa entita', cambia il TIPO DI CONTROLLO"]) {
  a <- sa[[s]]; r <- sr[[s]]
  comuni <- intersect(unique(a$entita), unique(r$entita))
  for (e in comuni) {
    cr <- sort(unique(r$controllo[r$entita == e])); ca <- sort(unique(a$controllo[a$entita == e]))
    if (!identical(cr, ca)) dett[[length(dett)+1L]] <- data.frame(
      study_id = s, entita = e, da = paste(cr, collapse=";"), a = paste(ca, collapse=";"),
      stringsAsFactors = FALSE)
  }
}
if (length(dett)) {
  dd <- do.call(rbind, dett)
  print(utils::head(sort(table(paste(dd$da, "->", dd$a)), decreasing = TRUE), 15))
  utils::write.csv(dd, file.path(OUT, "usciti-controllo.csv"), row.names = FALSE)
}

cli_h2("Le cinque bandiera: la verifica dell'aspettativa del handout")
PAV <- c("NCBITaxon:2697049"="SARS-CoV-2","HGNC:11766"="TGFB1","CHEBI:16412"="LPS",
         "CHEBI:68534"="enzalutamide","CHEBI:63637"="vemurafenib")
for (id in names(PAV)) {
  sr_id <- unique(R$study_id[R$entita == id]); sa_id <- unique(A$study_id[A$entita == id])
  fuori <- setdiff(sr_id, sa_id)
  motivi <- esito[intersect(fuori, names(esito))]
  cli_alert(sprintf("%-13s studi in Stadio 3: %3d -> %3d  (usciti %2d, di cui nel deliverable %d)",
                    PAV[[id]], length(sr_id), length(sa_id), length(fuori), length(motivi)))
  if (length(motivi)) print(table(motivi))
}

utils::write.csv(data.frame(study_id = names(esito), esito = unname(esito)),
                 file.path(OUT, "usciti-dove-finiscono.csv"), row.names = FALSE)
cli_alert_success("Scritto usciti-dove-finiscono.csv")
