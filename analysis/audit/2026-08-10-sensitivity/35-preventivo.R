#!/usr/bin/env Rscript
# analysis/audit/2026-08-10-sensitivity/35-preventivo.R
#
# Il preventivo del programma, con un modello di costo MISURATO invece che
# stimato. Serve alla decisione di §3 dell'handout, che va presa esplicitamente
# prima di lanciare.
#
# Il modello: dai tre cluster di 30-accettazione-e-costo.R il costo di un pooling
# e' proporzionale a (numero di geni x numero di studi):
#   TGF-beta1   785,3 s / (19.687 x 59) = 6,76e-4 s
#   palbociclib 182,4 s / (18.225 x 15) = 6,67e-4 s
#   k=3          81,2 s / (14.279 x  3) = 1,90e-3 s   <- dominato dall'overhead
# Si usa 6,7e-4 con un pavimento di 60 s per pooling (l'overhead visto sul k=3).
#
# ⚠️ Il preventivo dell'handout (§3: ~34 h letterale, ~12 h ottimizzato) contava
# solo le rimozioni degli accusati. Il nullo appaiato e la leave-one-out sugli
# studi PULITI — che e' il riferimento con cui gli accusati vanno confrontati —
# non erano contati, e sono la parte grossa.
#
# Uso: Rscript analysis/audit/2026-08-10-sensitivity/35-preventivo.R
suppressPackageStartupMessages({ library(cli) })

POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
OUT  <- "analysis/audit/2026-08-10-sensitivity"
COSTO_PER_GENE_STUDIO <- 6.7e-4
PAVIMENTO <- 60

acc <- utils::read.csv(file.path(OUT, "10-accuse-sui-bracci.csv"), stringsAsFactors = FALSE)
deliv <- readRDS(file.path(POOL, "deliverable-annotato.rds"))
dentro <- unique(acc[acc$stato == "dentro il pooling", c("cluster_id", "study_id")])
gruppi <- unique(dentro$cluster_id)

G <- data.frame(
  cluster_id = gruppi,
  entita = deliv$contrast_entity_label[match(gruppi, deliv$cluster_id)],
  k = deliv$k_effective[match(gruppi, deliv$cluster_id)],
  n_sig = deliv$n_sig[match(gruppi, deliv$cluster_id)],
  accusati = vapply(gruppi, function(c) sum(dentro$cluster_id == c), integer(1)),
  stringsAsFactors = FALSE)
# geni totali del cluster: stimati dal rapporto misurato sui tre di prova
# (n_sig / n_geni fra 0,10 e 0,40) -> si usa il caso peggiore n_geni = n_sig / 0,15
G$n_geni_tutti <- ceiling(G$n_sig / 0.15)
G <- G[order(-G$k), ]

costo <- function(n_geni, k, n_pool) pmax(PAVIMENTO, COSTO_PER_GENE_STUDIO * n_geni * k) * n_pool

scenari <- list(
  "A. solo accusati (LOO + blocco), niente nullo" =
    function(g) g$accusati + ifelse(g$accusati > 1, 1, 0),
  "B. A + leave-one-out su OGNI studio (riferimento per-studio)" =
    function(g) g$k + ifelse(g$accusati > 1, 1, 0),
  "C. B + 20 estrazioni del nullo appaiato" =
    function(g) g$k + ifelse(g$accusati > 1, 1, 0) + 20,
  "D. C con 50 estrazioni" =
    function(g) g$k + ifelse(g$accusati > 1, 1, 0) + 50)

cli_h2("Preventivo per scenario, sui {nrow(G)} gruppi con almeno uno studio accusato dentro")
R <- list()
for (nome in names(scenari)) {
  np <- scenari[[nome]](G)
  for (modo in c("tutti", "sig")) {
    ng <- if (modo == "tutti") G$n_geni_tutti else G$n_sig
    sec <- sum(costo(ng, G$k, np))
    R[[length(R) + 1L]] <- data.frame(scenario = nome, geni = modo,
      n_pooling = sum(np), ore_1_core = sec / 3600,
      ore_32_worker = sec / 3600 / 32, stringsAsFactors = FALSE)
  }
}
R <- do.call(rbind, R)
print(R, row.names = FALSE, digits = 3)
utils::write.csv(R, file.path(OUT, "35-preventivo.csv"), row.names = FALSE)

cli_h2("Dove va il costo")
np <- scenari[[3]](G)
G$ore_scenario_C_tutti <- costo(G$n_geni_tutti, G$k, np) / 3600
print(G[, c("entita", "k", "n_sig", "accusati", "ore_scenario_C_tutti")],
      row.names = FALSE, digits = 3)
cli_alert_info("i due gruppi piu' grandi valgono il {round(100*sum(utils::head(G$ore_scenario_C_tutti,2))/sum(G$ore_scenario_C_tutti))}% del costo")
cli_alert_warning("Il modello e' una proiezione da 3 cluster misurati, non una misura su tutti e 11.")
cli_alert_success("scritto 35-preventivo.csv")
