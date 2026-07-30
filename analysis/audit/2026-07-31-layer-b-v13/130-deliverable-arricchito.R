#!/usr/bin/env Rscript
# 130-deliverable-arricchito.R --- il deliverable dice ANCHE quanto il pooling e'
# efficace, invece di lasciarlo in un file di audit.
#
# CRITICA DELL'UTENTE (2026-07-31), giusta: "mi sembra una cacata che non
# mostriamo gli studi in cui il pooling sia davvero efficace o almeno
# quantificare quanto sia efficace". Il numero c'era — misurato su tutti e 191 —
# ma stava in una tabella di audit invece che nel deliverable, dove il lettore
# vede solo `k_effective`, cioe' QUANTI studi entrano e non quanto CONTANO.
#
# Le colonne aggiunte sono additive: nulla viene tolto o sovrascritto, e la
# versione precedente resta nella storia di git (commit 27c8810).
#
#  * k_kish, quota_top1, frazione_efficace, dominato, studio_dominante
#    -> R/stage4-pooling-effectiveness.R, 38 test
#  * materiale_misto, n_studi_model/primary/unknown, classe_studio_dominante
#    -> R/stage3-material-class.R, 49 test, accordo 19/20 col giudizio umano
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/130-deliverable-arricchito.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(cli) })

V13    <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
POOL   <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
STAGE2 <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
DEL    <- "analysis/audit/2026-07-29-etichette-v13"
NEW    <- "analysis/audit/2026-07-31-layer-b-v13"

d   <- readRDS(file.path(DEL, "deliverable-v13-poolato.rds"))
eff <- readRDS(file.path(NEW, "efficacia-pooling-191.rds"))
mat <- readRDS(file.path(NEW, "materiale-tutti-191.rds"))
stopifnot(nrow(d) == 191L)

# Le tre tabelle devono coprire ESATTAMENTE gli stessi cluster: un merge che
# perde righe in silenzio produrrebbe NA che il lettore leggerebbe come "non
# misurato" invece di "difetto della pipeline".
if (!setequal(d$cluster_id, eff$cluster_id)) cli_abort("efficacia: insiemi diversi")
if (!setequal(d$cluster_id, mat$cluster_id)) cli_abort("materiale: insiemi diversi")

d$k_kish            <- round(eff$k_kish[match(d$cluster_id, eff$cluster_id)], 2)
d$quota_top1        <- round(eff$quota_top1[match(d$cluster_id, eff$cluster_id)], 4)
d$frazione_efficace <- round(eff$frazione_efficace[match(d$cluster_id, eff$cluster_id)], 3)
d$dominato          <- eff$dominato[match(d$cluster_id, eff$cluster_id)]
d$studio_dominante  <- eff$studio_dominante[match(d$cluster_id, eff$cluster_id)]

d$materiale_misto   <- mat$materiale_misto[match(d$cluster_id, mat$cluster_id)]
d$n_studi_model     <- mat$n_studi_model[match(d$cluster_id, mat$cluster_id)]
d$n_studi_primary   <- mat$n_studi_primary[match(d$cluster_id, mat$cluster_id)]
d$n_studi_unknown   <- mat$n_studi_unknown[match(d$cluster_id, mat$cluster_id)]

# --- lo studio che DOMINA e' un sistema in vitro? ---------------------------
# E' il segnale preciso, quello che "materiale misto" da solo non da': in un
# gruppo di trattamento e' normale che il trattamento sia applicato sia a
# tessuto sia a cellule, mentre in un gruppo di MALATTIA un modello cellulare
# che porta il peso misura un'altra cosa rispetto al tessuto di paziente.
asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% d$cluster_id, ]
asg$study <- sub("__.*$", "", asg$record_id)
s2 <- simulomicsr:::.load_stage2_master(STAGE2)
need <- unique(asg$record_id)
lab <- new.env(hash = TRUE, size = length(need), parent = emptyenv())
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
for (study in s2) {
  if (length(study$comparisons) == 0L) next
  rgl <- setNames(study$replicate_groups,
                  vapply(study$replicate_groups, function(g) g$group_id, character(1L)))
  for (cmp in study$comparisons) {
    rid <- sprintf("%s__%s", study$series_id, cmp$comparison_id)
    if (!rid %in% need) next
    t <- rgl[[cmp$treated_group]]; c <- rgl[[cmp$control_group]]
    if (is.null(t) || is.null(c)) next
    assign(rid, c(lab_of(t, cmp$treated_group), lab_of(c, cmp$control_group)), envir = lab)
  }
}
rm(s2); gc(verbose = FALSE)

righe <- list()
for (i in seq_len(nrow(asg))) {
  e <- get0(asg$record_id[i], envir = lab, inherits = FALSE)
  if (is.null(e)) next
  righe[[length(righe) + 1L]] <- data.frame(
    cluster_id = asg$cluster_id[i], study_id = asg$study[i],
    label = e, stringsAsFactors = FALSE)
}
membri <- do.call(rbind, righe)
cls <- simulomicsr:::.classify_material(membri$label)
rango <- c(unknown = 0L, primary = 1L, model = 2L)
per_studio <- vapply(split(rango[cls], paste(membri$cluster_id, membri$study_id, sep = "\r")),
                     max, integer(1L))
nomi <- c("unknown", "primary", "model")
chiave_dom <- paste(d$cluster_id, d$studio_dominante, sep = "\r")
d$classe_studio_dominante <- nomi[per_studio[chiave_dom] + 1L]
d$classe_studio_dominante[is.na(d$classe_studio_dominante)] <- "unknown"

# Il segnale forte: chi porta il peso e' un modello IN UN GRUPPO DOMINATO, e nel
# gruppo c'e' anche materiale di paziente.
# La congiunzione con `dominato` non e' un dettaglio: senza, la colonna si
# accendeva anche su TGF-beta1 e LPS, dove lo studio "dominante" pesa il 2,5% e
# il 3,8% — cioe' non domina affatto. "Il primo della lista" non e' "chi
# comanda", ed e' un errore che avrei stampato nel deliverable.
d$dominato_da_modello <- d$dominato &
  d$classe_studio_dominante == "model" & d$n_studi_primary > 0L

# --- scrittura -------------------------------------------------------------
d <- d[order(-d$k_effective), ]
saveRDS(d, file.path(DEL, "deliverable-v13-poolato.rds"))
utils::write.csv(
  d[, c("cluster_id", "contrast_entity", "contrast_entity_label",
        "contrast_entity_label_source", "contrast_entity_label_note",
        "canonical_name", "contrast_direction", "contrast_control_key",
        "k_effective", "k_kish", "frazione_efficace", "quota_top1", "dominato",
        "studio_dominante", "classe_studio_dominante", "dominato_da_modello",
        "materiale_misto", "n_studi_model", "n_studi_primary", "n_studi_unknown",
        "n_sig", "I2_med", "coherence_verdict", "coherence_reason",
        "n_studi_censiti", "n_studi_poolati", "stessi_membri", "studi_caduti")],
  file.path(DEL, "deliverable-v13-poolato.csv"), row.names = FALSE)

cli_h2("Deliverable arricchito: 191 meta-analisi")
cat(sprintf("  coerenti:                          %d (%.1f%%)\n",
            sum(d$coherence_verdict == "coherent"),
            100 * mean(d$coherence_verdict == "coherent")))
cat(sprintf("  dominati da un solo studio (>=50%%): %d (%.1f%%)\n",
            sum(d$dominato), 100 * mean(d$dominato)))
# Contato sui valori NON arrotondati: `d$k_kish` e' arrotondato a due decimali
# per leggibilita', e contare su quello spostava due gruppi al confine (66 -> 64).
kk <- eff$k_kish[match(d$cluster_id, eff$cluster_id)]
cat(sprintf("  meno di 2 studi efficaci:          %d (%.1f%%)\n",
            sum(kk < 2), 100 * mean(kk < 2)))
cat(sprintf("  materiale misto:                   %d (%.1f%%)\n",
            sum(d$materiale_misto), 100 * mean(d$materiale_misto)))
cat(sprintf("  DOMINATI DA UN MODELLO in vitro:   %d (%.1f%%)\n",
            sum(d$dominato_da_modello), 100 * mean(d$dominato_da_modello)))

cli_h2("Coerenza e dominanza sono assi INDIPENDENTI")
print(table(coerente = d$coherence_verdict, dominato = d$dominato))

cli_h2("I gruppi dominati da un modello in vitro")
dm <- d[d$dominato_da_modello, c("contrast_entity_label", "k_effective", "k_kish",
                                 "quota_top1", "studio_dominante", "n_studi_primary",
                                 "n_sig", "coherence_verdict")]
dm <- dm[order(-dm$quota_top1), ]
for (i in seq_len(min(20L, nrow(dm)))) {
  cat(sprintf("  %-34s k=%2d eff=%4.1f top1=%4.1f%% %-11s prim=%d n_sig=%5d %s\n",
              substr(dm$contrast_entity_label[i], 1, 34), dm$k_effective[i],
              dm$k_kish[i], 100 * dm$quota_top1[i], dm$studio_dominante[i],
              dm$n_studi_primary[i], dm$n_sig[i], dm$coherence_verdict[i]))
}
if (nrow(dm) > 20L) cat(sprintf("  ... e altri %d\n", nrow(dm) - 20L))

cli_alert_success("Scritto {.path {file.path(DEL, 'deliverable-v13-poolato.csv')}} (+ .rds)")
