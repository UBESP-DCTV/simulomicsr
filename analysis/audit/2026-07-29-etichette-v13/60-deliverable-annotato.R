#!/usr/bin/env Rscript
# 60-deliverable-annotato.R --- il deliverable finale: 191 meta-analisi poolate,
# con l'etichetta risolta dall'ID, la marcatura di coerenza, e il confronto fra
# i membri EFFETTIVAMENTE poolati e quelli che erano stati letti nel censimento.
#
# Il censimento (2026-07-28) ha giudicato i RAGGRUPPAMENTI. Il pooling scarta gli
# studi senza controllo interno: se un gruppo entra nel pool con meno studi di
# quelli letti, il verdetto va riguardato — non e' piu' lo stesso insieme.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE); library(arrow); library(dplyr)
})

POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
V13  <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
OUT  <- "analysis/audit/2026-07-29-etichette-v13"

# --- 1. i 191 cluster poolati, con le loro metriche --------------------------
cp <- arrow::open_dataset(file.path(POOL, "cluster_pooled.parquet"))
met <- cp %>% group_by(cluster_id) %>%
  summarise(k_effective = max(k_effective, na.rm = TRUE),
            n_geni      = n(),
            n_sig       = sum(FDR_BH_within_cluster < 0.05, na.rm = TRUE),
            I2_med      = median(I2, na.rm = TRUE),
            tau2_med    = median(tau2, na.rm = TRUE)) %>% collect()
cat("cluster poolati:", nrow(met), "\n")

# --- 2. identita' del contrasto + etichetta risolta dall'ID ------------------
cl  <- readRDS(file.path(V13, "clusters.rds"))
sel <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(cl, stage4_default_config()))
sel$ckey <- paste0(sel$contrast_entity, "||", sel$contrast_direction, "||",
                   sel$contrast_control_key)
env <- simulomicsr:::.load_ontology_dicts()
# Etichetta LEGGIBILE: la risoluzione dall'ID piu' le scelte umane curate in
# inst/extdata/entity-label-overrides.csv (i patogeni escono dal dizionario
# senza spazi, ChEBI usa i nomi sistematici).
lab <- simulomicsr:::.display_entity_labels(sel$contrast_entity, env = env)
sel$contrast_entity_label        <- lab$contrast_entity_label
sel$contrast_entity_label_source <- lab$contrast_entity_label_source
sel$contrast_entity_label_note   <- lab$contrast_entity_label_note

d <- merge(met, sel[, c("cluster_id", "ckey", "contrast_entity", "contrast_direction",
                        "contrast_control_key", "canonical_name", "k",
                        "contrast_entity_label", "contrast_entity_label_source",
                        "contrast_entity_label_note")],
           by = "cluster_id")
stopifnot(nrow(d) == nrow(met))

# --- 3. marcatura di coerenza ------------------------------------------------
# I motivi sono quelli RILETTI sui membri effettivamente poolati (70-rilettura-
# poolati.R), non quelli del censimento: dopo il pooling la composizione dei
# gruppi e' cambiata e i numeri del censimento non descrivono piu' cio' che c'e'
# dentro. Tre gruppi sono PEGGIORATI (sono caduti gli studi corretti).
v <- read.csv(file.path(OUT, "verdetti-poolato-v13.csv"), stringsAsFactors = FALSE)
# Tre dei nove gruppi incoerenti non sono nel poolato (li ha scartati il gate
# k_eff<3): i loro verdetti non hanno un gruppo a cui attaccarsi. Si tolgono
# ESPLICITAMENTE e si dichiara quali, invece di allentare il controllo che
# ferma la marcatura quando un verdetto resta orfano.
fuori <- setdiff(v$ckey, d$ckey)
cat("\nverdetti senza gruppo nel poolato (scartati dal gate):", length(fuori), "\n")
if (length(fuori)) for (f in fuori) cat("   -", f, "\n")
v_in <- v[v$ckey %in% d$ckey, ]
d <- simulomicsr:::.annotate_coherence(d, v_in, source = "rilettura-sui-poolati-2026-07-30")
cat("marcati incoerenti:", sum(d$coherence_verdict == "incoherent"), "\n")

# --- 4. i membri poolati sono quelli letti? ---------------------------------
ps <- arrow::open_dataset(file.path(POOL, "per_study_de.parquet"))
studi_pool <- ps %>% distinct(cluster_id, study_id) %>% collect()
studi_pool <- split(studi_pool$study_id, studi_pool$cluster_id)

asg <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
asg <- asg[asg$cluster_id %in% d$cluster_id, ]
asg$study <- sub("__.*$", "", asg$record_id)
studi_cens <- split(asg$study, asg$cluster_id)

d$n_studi_censiti <- vapply(d$cluster_id, function(c) length(unique(studi_cens[[c]])), integer(1L))
d$n_studi_poolati <- vapply(d$cluster_id, function(c) length(unique(studi_pool[[c]])), integer(1L))
d$stessi_membri   <- vapply(d$cluster_id, function(c)
  setequal(unique(studi_cens[[c]]), unique(studi_pool[[c]])), logical(1L))
d$studi_caduti <- vapply(d$cluster_id, function(c)
  paste(sort(setdiff(unique(studi_cens[[c]]), unique(studi_pool[[c]]))), collapse = " "),
  character(1L))

d <- d[order(-d$k_effective), ]
saveRDS(d, file.path(OUT, "deliverable-v13-poolato.rds"))
utils::write.csv(
  d[, c("cluster_id", "contrast_entity", "contrast_entity_label",
        "contrast_entity_label_source", "contrast_entity_label_note", "canonical_name", "contrast_direction",
        "contrast_control_key", "k_effective", "n_sig", "I2_med",
        "coherence_verdict", "coherence_reason", "n_studi_censiti",
        "n_studi_poolati", "stessi_membri", "studi_caduti")],
  file.path(OUT, "deliverable-v13-poolato.csv"), row.names = FALSE)

cat("\n=== IL DELIVERABLE POOLATO ===\n")
cat("meta-analisi:", nrow(d), "\n")
cat("coerenti:", sum(d$coherence_verdict == "coherent"),
    sprintf("(%.1f%%)", 100 * mean(d$coherence_verdict == "coherent")), "\n")
cat("geni significativi:", sum(d$n_sig), "\n")
cat("I2 mediano:", round(median(d$I2_med, na.rm = TRUE), 1), "\n")

cat("\n=== I MEMBRI POOLATI SONO QUELLI LETTI? ===\n")
cat("gruppi con lo STESSO insieme di studi:", sum(d$stessi_membri),
    sprintf("(%.1f%%)", 100 * mean(d$stessi_membri)), "\n")
cat("gruppi che hanno perso studi         :", sum(!d$stessi_membri), "\n")
cat("studi persi in totale                :",
    sum(d$n_studi_censiti - d$n_studi_poolati), "\n")
cat("gruppi con studi poolati NON censiti :",
    sum(d$n_studi_poolati > d$n_studi_censiti), "\n")

cat("\n--- i gruppi da riguardare (composizione cambiata), i 30 piu' grandi ---\n")
ch <- d[!d$stessi_membri, c("contrast_entity_label", "k_effective", "n_studi_censiti",
                            "n_studi_poolati", "coherence_verdict")]
print(utils::head(ch, 30), row.names = FALSE)
cat("\ntabella:", file.path(OUT, "deliverable-v13-poolato.csv"), "\n")
