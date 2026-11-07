#!/usr/bin/env Rscript
# 50-tabelle-nomi.R — S10, dubbio ricevuto dalla prova del re-run (S8b §6).
#
# LA DOMANDA. Le due tabelle che correggono i nomi (name-cleanup v1 e fallback)
# sono state scritte sui gruppi dei run v9pre e v9. La produzione le applica
# cosi' (20-ingressi.R della S9, passo 6b; R/stage3-name-cleanup-overlay.R:66):
#   riga override -> cluster_id del run vecchio -> record_id del run vecchio ->
#   campioni trattati di QUEL record_id letti nel master Stadio 2 CORRENTE.
# Se il master corrente da' a quel record_id altri campioni, il nome corretto
# cade su campioni che la correzione non ha mai visto.
#
# CHE COSA SI CONTA, su TUTTE le righe override delle due tabelle:
#   per ogni record_id agganciato, l'insieme dei campioni trattati nel master
#   del run vecchio (p4-fase-f4-stage2-master-v3), nel master del deliverable
#   (A3, innestato) e nel master rifatto da zero (S14). Stato: uguale, diverso,
#   assente nel nuovo.
# E per il deliverable: quanti dei 1.903 confronti poolati hanno un campione
# trattato che ha ricevuto un nome attraverso un record_id con contenuto diverso.
#
# Prima si verifica quale master ha generato i record_id dei run v9: la quota
# di record_id trovati nel master vecchio deve essere ~100%.
#
# Uso: Rscript analysis/audit/2026-11-07-S10-rilevatore/50-tabelle-nomi.R
suppressPackageStartupMessages({ library(cli); devtools::load_all(".", quiet = TRUE) })
OUT <- "analysis/audit/2026-11-07-S10-rilevatore"
source("analysis/audit/_gsm-lookup-helper.R")
t0 <- Sys.time(); tempo <- function() round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)

MASTER <- c(vecchio = "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl",
            A3      = "analysis/p4-output/A3-stage2-master-innestato.jsonl",
            S14     = "analysis/p4-output/S14-stage2-master.jsonl")
stopifnot(all(file.exists(MASTER)))
r2g <- lapply(MASTER, build_record_gsm_lookup)
cli_alert_info("mappe record -> campioni costruite ({tempo()} min)")

tab <- list(
  v1       = list(s = readRDS("analysis/p4-output/name-cleanup-side-table-v1.rds"),
                  run = "analysis/p4-output/20260710T045849Z-stage3-v9pre-364547a7"),
  fallback = list(s = readRDS("analysis/p4-output/name-cleanup-fallback-side-table.rds"),
                  run = "analysis/p4-output/20260717T171550Z-stage3-v9-364547a7"))

righe <- list()
for (nm in names(tab)) {
  s <- tab[[nm]]$s
  a <- as.data.frame(arrow::read_parquet(file.path(tab[[nm]]$run, "assignments.parquet")))
  # quale master ha generato questi record_id?
  trovati <- vapply(names(MASTER), function(k)
    mean(vapply(a$record_id, function(r) exists(r, envir = r2g[[k]], inherits = FALSE), NA)), 0)
  cli_alert_info("{nm}: record_id del run trovati nei master: {paste(names(trovati), sprintf('%.4f', trovati), collapse = ', ')}")
  keep <- s[s$action == "override" & !is.na(s$new_id), , drop = FALSE]
  asg_by <- split(a$record_id, a$cluster_id)
  for (i in seq_len(nrow(keep))) {
    rids <- asg_by[[keep$cluster_id[i]]]
    if (is.null(rids)) {
      righe[[length(righe) + 1L]] <- data.frame(tabella = nm, riga = i, cluster_id = keep$cluster_id[i],
        new_id = keep$new_id[i], record_id = NA_character_, n_vecchio = NA_integer_, n_A3 = NA_integer_,
        n_S14 = NA_integer_, stato_A3 = "cluster_assente", stato_S14 = "cluster_assente")
      next
    }
    g <- lapply(names(MASTER), function(k) lapply(rids, function(r) get0(r, envir = r2g[[k]], inherits = FALSE)))
    names(g) <- names(MASTER)
    stato <- function(old, new) {
      if (is.null(old) && is.null(new)) return("assente_entrambi")
      if (is.null(old)) return("assente_vecchio")
      if (is.null(new)) return("assente_nuovo")
      if (setequal(old, new)) "uguale" else "diverso"
    }
    righe[[length(righe) + 1L]] <- data.frame(
      tabella = nm, riga = i, cluster_id = keep$cluster_id[i], new_id = keep$new_id[i],
      record_id = rids,
      n_vecchio = vapply(g$vecchio, length, 0L), n_A3 = vapply(g$A3, length, 0L),
      n_S14 = vapply(g$S14, length, 0L),
      stato_A3  = mapply(stato, g$vecchio, g$A3),
      stato_S14 = mapply(stato, g$vecchio, g$S14),
      stringsAsFactors = FALSE)
  }
}
R <- do.call(rbind, righe)
saveRDS(R, file.path(OUT, "50-tabelle-nomi.rds"))
cli_alert_info("record agganciati: {nrow(R)} ({tempo()} min)")

sink(file.path(OUT, "50-out.txt"), split = TRUE)
cat("== record_id agganciati alle righe override, per stato ==\n")
print(table(tabella = R$tabella, stato_A3 = R$stato_A3))
print(table(tabella = R$tabella, stato_S14 = R$stato_S14))
cat("\n== righe override (una riga = un gruppo corretto), per stato peggiore dei suoi record ==\n")
peggio <- function(x) if (any(x == "diverso")) "almeno_un_diverso" else if (all(x == "uguale")) "tutti_uguali" else
  if (all(x %in% c("assente_nuovo", "assente_entrambi", "cluster_assente"))) "tutti_assenti" else "misto_uguale_assente"
for (k in c("stato_A3", "stato_S14")) {
  p <- tapply(R[[k]], paste(R$tabella, R$riga), peggio)
  tb <- sub(" .*", "", names(p))
  cat("\n", k, "\n"); print(table(tabella = tb, esito = p))
}

# ---------------------------------------------- impatto sul deliverable (A3) --
# Campioni che nel build A3 hanno ricevuto un nome attraverso un record_id con
# contenuto diverso, e che il run vecchio NON associava a quel record_id.
dv <- R[R$stato_A3 == "diverso", ]
mis <- unique(unlist(lapply(seq_len(nrow(dv)), function(i) setdiff(
  get0(dv$record_id[i], envir = r2g$A3, inherits = FALSE),
  get0(dv$record_id[i], envir = r2g$vecchio, inherits = FALSE)))))
cat(sprintf("\ncampioni con un nome arrivato da un record_id con contenuto diverso (A3): %d\n", length(mis)))
A <- readRDS("analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds")$tenuti
gt <- strsplit(A$gsm_t, ",", fixed = TRUE)
chiave <- sub("__[0-9]+$", "", A$record_id)
primo <- vapply(chiave, function(k) { v <- get0(k, envir = r2g$A3, inherits = FALSE); if (is.null(v)) NA_character_ else v[1L] }, "")
A$tocca_qualunque <- vapply(gt, function(v) any(v %in% mis), NA)
A$tocca_primo <- !is.na(primo) & primo %in% mis
cat(sprintf("confronti del deliverable (1.903) con almeno un campione trattato toccato: %d; col primo campione trattato toccato: %d\n",
            sum(A$tocca_qualunque), sum(A$tocca_primo)))
cat(sprintf("  in quante meta-analisi: %d e %d\n", length(unique(A$cluster_id[A$tocca_qualunque])),
            length(unique(A$cluster_id[A$tocca_primo]))))
cat(sprintf("chiavi dei 1.903 non trovate nel master A3: %d\n", sum(is.na(primo))))
sink()
write.csv(A[A$tocca_qualunque, c("cluster_id", "study_id", "record_id", "etichetta_trattato",
                                 "etichetta_controllo", "tocca_primo")],
          file.path(OUT, "50-deliverable-toccati.csv"), row.names = FALSE)
cli_alert_success("Scritti 50-tabelle-nomi.rds, 50-out.txt, 50-deliverable-toccati.csv ({tempo()} min)")
