#!/usr/bin/env Rscript
# analysis/audit/2026-08-02-fix/70-selection-v15.R
#
# Rigenera la selezione dei case study del Layer B DAL DELIVERABLE v15.
#
# Perche' esiste (handout §5.4 e §7): il CSV in uso,
# `analysis/layer-b-selection-v13-finale.csv`, porta nella colonna `notes` 181
# numeri di v13 (k, studi efficaci, n_sig, I2, quota del dominante...). Sono
# TESTO LIBERO: nessuna guardia della pipeline puo' accorgersi che sono vecchi,
# perche' per il codice sono una stringa qualsiasi. Se il Layer B v15 girasse
# con quel CSV, le didascalie del paper riporterebbero i numeri di un altro run.
#
# Rispetto a `analysis/audit/2026-07-31-layer-b-v13/120-selection-finale.R`
# (che faceva la stessa cosa per v13) cambia UNA cosa: quello leggeva tre file
# (deliverable + efficacia + materiale), questo ne legge UNO SOLO. Da FASE B2/B3
# (2026-07-31) l'annotazione e' codice di pacchetto chiamato dal re-pool stesso,
# quindi `deliverable-annotato.rds` porta gia' k_kish, quota_top1,
# frazione_efficace, studio_dominante e le colonne del materiale. Una seconda
# fonte per le stesse grandezze sarebbe un modo per farle divergere in silenzio.
#
# ⚠️ QUESTO SCRIPT NON DECIDE, RIGENERA. Le nove scelte qui sotto sono state
# prese sui numeri di v13 (ADR-0027 + decisioni del 2026-07-31). In v15 quei
# numeri CAMBIANO: TGF-beta1 passa da 65 a 78 studi censiti, sette gruppi
# cambiano k per il `record_id` univoco, e i verdetti di incoerenza passano da 6
# a 24. Per questo lo script stampa il confronto v13 -> v15 riga per riga: le
# scelte vanno RILETTE su quei numeri prima di costruire le figure, non
# ereditate. Un gruppo che diventa incoerente, o che perde studi efficaci, non
# puo' restare una figura del main paper solo perche' lo era in v13.
#
# Uso:
#   POOL_DIR=<dir del re-pool v15> \
#     Rscript analysis/audit/2026-08-02-fix/70-selection-v15.R

suppressPackageStartupMessages({ library(cli) })

pool_dir <- Sys.getenv("POOL_DIR", "")
out_csv  <- Sys.getenv("OUT_CSV", "analysis/layer-b-selection-v15.csv")
v13_rds  <- "analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds"

if (!nzchar(pool_dir) || !dir.exists(pool_dir))
  cli_abort("POOL_DIR mancante o inesistente. Uso: POOL_DIR=<dir re-pool v15> Rscript ...")

d_path <- file.path(pool_dir, "deliverable-annotato.rds")
if (!file.exists(d_path))
  cli_abort("Deliverable annotato assente: {.path {d_path}}. Il re-pool e' finito davvero?")

D <- readRDS(d_path)
cli_alert_info("Deliverable v15: {nrow(D)} meta-analisi, {ncol(D)} colonne.")

# --- le nove scelte, come da ADR-0027 + decisioni del 2026-07-31 ---------------
sel <- rbind(
  data.frame(entity = "CHEBI:16330", label = "DHT (dihydrotestosterone) -- AR agonist",
             priority = 1L, ruolo = "MAIN fig.1 - agonista",
             perche = "controllo positivo: KLK3, TMPRSS2, FKBP5, NKX3-1 tutti su"),
  data.frame(entity = "CHEBI:68534", label = "Enzalutamide -- AR antagonist",
             priority = 1L, ruolo = "MAIN fig.1 - antagonista",
             perche = "controllo negativo: gli STESSI geni di segno opposto, da studi diversi in un gruppo costruito separatamente"),
  data.frame(entity = "HGNC:11766", label = "TGF-beta1",
             priority = 1L, ruolo = "MAIN fig.2 - alto k",
             perche = "il gruppo de-frammentato in v15: le scritture tgfb/TGF-B/tgf_b ora stanno insieme"),
  data.frame(entity = "NCBITaxon:2697049", label = "SARS-CoV-2 infection",
             priority = 2L, ruolo = "SUPP - patogeno",
             perche = "risposta interferone attesa (IFIT1, ISG15, MX1)"),
  data.frame(entity = "HGNC:5438", label = "IFN-gamma",
             priority = 2L, ruolo = "SUPP - citochina",
             perche = "GO indipendente: 'response to type II interferon' primo termine specifico"),
  data.frame(entity = "CHEBI:137113", label = "JQ1 (BET bromodomain inhibitor)",
             priority = 2L, ruolo = "SUPP - piccola molecola",
             perche = "alto k con molti geni significativi"),
  data.frame(entity = "MeSH:D003424", label = "Crohn disease vs healthy",
             priority = 2L, ruolo = "SUPP - malattia",
             perche = "nessuno studio dominante, tutti i membri tessuto di paziente"),
  data.frame(entity = "MeSH:D010300", label = "Parkinson disease -- DECLARED: dominated + mixed material",
             priority = 3L, ruolo = "SUPP - limite dichiarato",
             perche = "k alto ma pochi studi efficaci e peso concentrato su neuroni da iPSC in un gruppo di cervelli post-mortem"),
  data.frame(entity = "HGNC:5991", label = "IL1A -- DECLARED INCOHERENT",
             priority = 3L, ruolo = "SUPP - incoerente dichiarato",
             perche = "parte degli studi poolati misura IL-1beta, non IL-1alfa")
)

# --- le due guardie: assente o ambigua = ci si ferma ---------------------------
missing <- setdiff(sel$entity, D$contrast_entity)
if (length(missing)) {
  cli_alert_danger("Entita' ASSENTI dal deliverable v15: {missing}")
  cli_abort(paste("Una scelta del paper non esiste piu' nel run nuovo. Non e' un",
                  "errore da aggirare: va deciso con quale gruppo sostituirla,",
                  "sui numeri di v15."))
}
dupes <- sel$entity[sel$entity %in% names(which(table(D$contrast_entity) > 1L))]
if (length(dupes)) cli_abort("Entita' ambigue (piu' di un cluster in v15): {dupes}")

row <- D[match(sel$entity, D$contrast_entity), ]

notes <- sprintf(
  paste0("%s | %s | entita=%s | etichetta dall'ID=%s | canonical_name vecchio=%s | ",
         "k=%d | studi efficaci=%.1f (%.0f%% del k) | studio dominante=%s (%.1f%% del peso) | ",
         "materiale: %d in vitro / %d paziente / %d ignoto%s | n_sig=%d | I2=%.1f | ",
         "coerenza=%s%s | studi censiti=%d -> poolati=%d | run=v15"),
  sel$ruolo, sel$perche, row$contrast_entity, row$contrast_entity_label,
  row$canonical_name, row$k_effective,
  row$k_kish, 100 * row$frazione_efficace,
  row$studio_dominante, 100 * row$quota_top1,
  row$n_studi_model, row$n_studi_primary, row$n_studi_unknown,
  ifelse(isTRUE(row$materiale_misto), " -> MISTO", ""),
  row$n_sig, row$I2_med, row$coherence_verdict,
  ifelse(is.na(row$coherence_reason) | !nzchar(row$coherence_reason), "",
         paste0(" (", row$coherence_reason, ")")),
  row$n_studi_censiti, row$n_studi_poolati
)

out <- data.frame(cluster_id = row$cluster_id, label_paper = sel$label,
                  priority = sel$priority, notes = notes, stringsAsFactors = FALSE)
write.csv(out, out_csv, row.names = FALSE)
cli_alert_success("Scritta {.path {out_csv}} -- {nrow(out)} case study.")

# --- il confronto v13 -> v15, perche' le scelte si rileggano sui numeri --------
cli_h2("Confronto v13 -> v15 (le scelte vanno RILETTE, non ereditate)")
V <- if (file.exists(v13_rds)) readRDS(v13_rds) else NULL
cat(sprintf("%-32s %-9s %-9s %-11s %-9s %s\n",
            "gruppo", "k v13", "k v15", "efficaci", "n_sig v15", "coerenza v15"))
for (i in seq_len(nrow(sel))) {
  v13row <- if (!is.null(V)) V[match(sel$entity[i], V$contrast_entity), ] else NULL
  k13 <- if (!is.null(v13row) && nrow(v13row) && !is.na(v13row$k_effective)) v13row$k_effective else NA
  cat(sprintf("%-32s %-9s %-9d %4.1f->%4.1f  %-9d %s\n",
              substr(sel$label[i], 1, 32),
              ifelse(is.na(k13), "assente", as.character(k13)),
              row$k_effective[i],
              ifelse(is.null(v13row) || !nrow(v13row), NA_real_, v13row$k_kish),
              row$k_kish[i], row$n_sig[i], row$coherence_verdict[i]))
}

# I gruppi che cambiano stato meritano una riga esplicita: sono quelli su cui la
# decisione del paper puo' non reggere piu'.
cambiati <- which(!is.na(row$coherence_verdict) & row$coherence_verdict != "coherent")
if (length(cambiati)) {
  cli_alert_warning(paste0("Gruppi NON coerenti fra i selezionati: ",
                           paste(sel$label[cambiati], collapse = "; "),
                           " -- verificare che siano quelli DICHIARATI apposta, non nuovi."))
}
