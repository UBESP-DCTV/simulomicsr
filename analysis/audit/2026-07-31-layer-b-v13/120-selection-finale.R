#!/usr/bin/env Rscript
# 120-selection-finale.R --- la selezione dei case study del paper, decisa sulle
# misure invece che sul k.
#
# ADR-0027 fissava 2 figure / 3 gruppi nel main e 5-6 supplementari, lasciando
# aperte due scelte. Il Layer B del 2026-07-31 le ha chiuse coi numeri:
#
#  * alto k: TGF-beta1 CONTRO LPS. Vince TGF-beta1 su ogni asse — k 49 contro 35,
#    studi efficaci 45,1 contro 31,8, geni significativi 7.233 contro 6.883, e
#    soprattutto tutti e sei i bersagli attesi (SERPINE1, CCN2, SMAD7, JUNB,
#    TGFBI, COL1A1) misurati a k=48-49 su 49, cioe' al k pieno.
#
#  * malattia: Parkinson e carcinoma epatocellulare NON reggono. Parkinson ha
#    1,8 studi efficaci su 10 e il 73% del peso su uno studio che non e' cervello
#    di paziente ma neuroni da iPSC; l'epatocellulare ha il 67% del peso su due
#    studi problematici e 72 geni significativi in tutto. CROHN, misurato nella
#    stessa tabella, ha 10 studi, 6,9 efficaci, nessuno sopra il 21%, 3.515 geni
#    significativi, e tutti i membri sono tessuto o campione di paziente.
#
# Parkinson resta, come SUPPLEMENTARE DICHIARATO: un gruppo che sul k sembra
# solido e che le due misure nuove — dominanza e materiale misto — smontano. Un
# paper che mostra solo successi e' meno credibile.
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/120-selection-finale.R

suppressPackageStartupMessages({ library(cli) })

D   <- readRDS("analysis/audit/2026-07-29-etichette-v13/deliverable-v13-poolato.rds")
EFF <- readRDS("analysis/audit/2026-07-31-layer-b-v13/efficacia-pooling-191.rds")
MAT <- readRDS("analysis/audit/2026-07-31-layer-b-v13/materiale-tutti-191.rds")
OUT <- "analysis/layer-b-selection-v13-finale.csv"

sel <- rbind(
  data.frame(entity = "CHEBI:16330", label = "DHT (dihydrotestosterone) -- AR agonist",
             priority = 1L, ruolo = "MAIN fig.1 - agonista",
             perche = "controllo positivo: KLK3 +2,27, TMPRSS2 +1,78, FKBP5 +2,32, NKX3-1 +1,37"),
  data.frame(entity = "CHEBI:68534", label = "Enzalutamide -- AR antagonist",
             priority = 1L, ruolo = "MAIN fig.1 - antagonista",
             perche = "controllo negativo: gli STESSI quattro geni di segno opposto, da studi diversi in un gruppo costruito separatamente"),
  data.frame(entity = "HGNC:11766", label = "TGF-beta1",
             priority = 1L, ruolo = "MAIN fig.2 - alto k",
             perche = "k=49, 45,1 studi efficaci, studio piu' pesante 2,6%; i 6 bersagli attesi tutti al k pieno"),
  data.frame(entity = "NCBITaxon:2697049", label = "SARS-CoV-2 infection",
             priority = 2L, ruolo = "SUPP - patogeno",
             perche = "k=33, 29,2 efficaci; risposta interferone attesa (IFIT1, ISG15, MX1) tutta presente"),
  data.frame(entity = "HGNC:5438", label = "IFN-gamma",
             priority = 2L, ruolo = "SUPP - citochina",
             perche = "GO indipendente: 'response to type II interferon' come primo termine specifico"),
  data.frame(entity = "CHEBI:137113", label = "JQ1 (BET bromodomain inhibitor)",
             priority = 2L, ruolo = "SUPP - piccola molecola",
             perche = "k=24, 22,8 efficaci, 9.501 geni significativi"),
  data.frame(entity = "MeSH:D003424", label = "Crohn disease vs healthy",
             priority = 2L, ruolo = "SUPP - malattia",
             perche = "k=10, 6,9 efficaci, nessuno studio sopra il 21%, 3.515 geni sig, tutti i membri tessuto di paziente"),
  data.frame(entity = "MeSH:D010300", label = "Parkinson disease -- DECLARED: dominated + mixed material",
             priority = 3L, ruolo = "SUPP - limite dichiarato",
             perche = "k=10 ma 1,8 studi efficaci e 73% del peso su GSE181029, neuroni da iPSC in un gruppo di cervelli post-mortem"),
  data.frame(entity = "HGNC:5991", label = "IL1A -- DECLARED INCOHERENT",
             priority = 3L, ruolo = "SUPP - incoerente dichiarato",
             perche = "2 dei 4 studi poolati misurano IL-1beta, non IL-1alfa: il pooling ha fatto cadere quelli giusti")
)

missing <- setdiff(sel$entity, D$contrast_entity)
if (length(missing)) cli_abort("Entita' assenti dal deliverable: {missing}")
dupes <- sel$entity[sel$entity %in% names(which(table(D$contrast_entity) > 1L))]
if (length(dupes)) cli_abort("Entita' ambigue (piu' cluster): {dupes}")

row <- D[match(sel$entity, D$contrast_entity), ]
eff <- EFF[match(row$cluster_id, EFF$cluster_id), ]
mat <- MAT[match(row$cluster_id, MAT$cluster_id), ]

notes <- sprintf(
  "%s | %s | entita=%s | etichetta dall'ID=%s | canonical_name vecchio=%s | k=%d | studi efficaci=%.1f (%.0f%% del k) | studio dominante=%s (%.1f%% del peso) | materiale: %d in vitro / %d paziente / %d ignoto%s | n_sig=%d | I2=%.1f | coerenza=%s%s | studi censiti=%d -> poolati=%d",
  sel$ruolo, sel$perche, row$contrast_entity, row$contrast_entity_label,
  row$canonical_name, row$k_effective,
  eff$k_kish, 100 * eff$frazione_efficace,
  eff$studio_dominante, 100 * eff$quota_top1,
  mat$n_studi_model, mat$n_studi_primary, mat$n_studi_unknown,
  ifelse(mat$materiale_misto, " -> MISTO", ""),
  row$n_sig, row$I2_med, row$coherence_verdict,
  ifelse(is.na(row$coherence_reason) | !nzchar(row$coherence_reason), "",
         paste0(" (", row$coherence_reason, ")")),
  row$n_studi_censiti, row$n_studi_poolati
)

out <- data.frame(cluster_id = row$cluster_id, label_paper = sel$label,
                  priority = sel$priority, notes = notes, stringsAsFactors = FALSE)
cli_alert_info("note: min={min(nchar(out$notes))} max={max(nchar(out$notes))} caratteri, nessun troncamento")
write.csv(out, OUT, row.names = FALSE)
cli_alert_success("Scritta {.path {OUT}} — {nrow(out)} case study (3 main + 6 supplementari).")

for (i in seq_len(nrow(out))) {
  cat(sprintf("  [p%d] %-34s k=%2d eff=%4.1f top1=%4.1f%% n_sig=%5d %s\n",
              out$priority[i], substr(sel$label[i], 1, 34), row$k_effective[i],
              eff$k_kish[i], 100 * eff$quota_top1[i], row$n_sig[i],
              row$coherence_verdict[i]))
}
