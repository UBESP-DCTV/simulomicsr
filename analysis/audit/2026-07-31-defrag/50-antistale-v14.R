#!/usr/bin/env Rscript
# 50-antistale-v14.R --- verifica del re-cluster v14 letta DAI FILE PRODOTTI,
# non dal log. Il log dice quello che lo script ha stampato; i file dicono cosa
# c'e' davvero (modello: 50-antistale-v13.R).
#
# Fa tre cose:
#  1. le invarianti strutturali sui cgroup;
#  2. i quattro numeri della decisione, sui dati veri;
#  3. il CONFRONTO DEGLI INSIEMI dei membri con v13, gruppo per gruppo — che e'
#     cio' che dice quali verdetti di coerenza restano validi e quali gruppi
#     vanno riletti (FASE D0ter). Non si campiona: si confrontano gli insiemi.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

V14 <- "analysis/p4-output/20260801T081819Z-stage3-v14-364547a7"
V13 <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
OUT <- "analysis/audit/2026-07-31-defrag"

ck <- function(d) paste(d$contrast_entity, d$contrast_direction,
                        d$contrast_control_key, sep = "||")

cfg <- stage4_default_config()
c14 <- readRDS(file.path(V14, "clusters.rds"))
c13 <- readRDS(file.path(V13, "clusters.rds"))
g14 <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(c14, cfg))
g13 <- as.data.frame(simulomicsr:::.identify_layer_a_clusters(c13, cfg))
g14$ckey <- ck(g14); g13$ckey <- ck(g13)

cat("================ 1. INVARIANTI STRUTTURALI (dai file) ================\n")
cg14 <- c14[!is.na(c14$mode) & c14$mode == "cgroup", ]
cat(sprintf("  cluster cgroup                     : %d\n", nrow(cg14)))
cat(sprintf("  prefisso cgroup_L5_                : %d / %d\n",
            sum(startsWith(cg14$cluster_id, "cgroup_L5_")), nrow(cg14)))
cat(sprintf("  contrast_entity popolate           : %d / %d\n",
            sum(!is.na(cg14$contrast_entity) & nzchar(cg14$contrast_entity)), nrow(cg14)))
cat(sprintf("  contrast_direction popolate        : %d / %d\n",
            sum(!is.na(cg14$contrast_direction) & nzchar(cg14$contrast_direction)), nrow(cg14)))
cat(sprintf("  contrast_control_key popolate      : %d / %d\n",
            sum(!is.na(cg14$contrast_control_key) & nzchar(cg14$contrast_control_key)), nrow(cg14)))
cat(sprintf("  livelli distinti dei cgroup        : %s\n",
            paste(sort(unique(cg14$level)), collapse = ",")))
cat(sprintf("\n  gruppi selezionati (deliverable Stadio 3): v13=%d -> v14=%d\n",
            nrow(g13), nrow(g14)))

cat("\n================ 2. LE ENTITA' BANDIERA E I QUATTRO NUMERI ================\n")
kk <- function(g, ent) { r <- g$k[g$contrast_entity == ent]; if (!length(r)) 0L else max(r) }
band <- data.frame(
  entita = c("SARS-CoV-2", "TGFB1", "LPS", "enzalutamide", "vemurafenib",
             "Glioblastoma", "IL17A", "STR:ifna"),
  id = c("NCBITaxon:2697049", "HGNC:11766", "CHEBI:16412", "CHEBI:68534",
         "CHEBI:63637", "MeSH:D005909", "HGNC:5981", "STR:ifna"),
  stringsAsFactors = FALSE)
band$k_v13 <- vapply(band$id, function(e) kk(g13, e), numeric(1))
band$k_v14 <- vapply(band$id, function(e) kk(g14, e), numeric(1))
band$delta <- band$k_v14 - band$k_v13
print(band, row.names = FALSE)

cat("\n  --- STR:ifna deve essere INVARIATO (non fuso) ---\n")
i13 <- g13[g13$contrast_entity == "STR:ifna", c("cluster_id", "k")]
i14 <- g14[g14$contrast_entity == "STR:ifna", c("cluster_id", "k")]
cat(sprintf("    v13: %d gruppo/i (k=%s) · v14: %d gruppo/i (k=%s)\n",
            nrow(i13), paste(i13$k, collapse = ","), nrow(i14), paste(i14$k, collapse = ",")))
cat(sprintf("    IFNA1/IFNA2 come entita' a se': v14 HGNC:5417 k=%d · HGNC:5423 k=%d\n",
            kk(g14, "HGNC:5417"), kk(g14, "HGNC:5423")))

cat("\n================ 3. CONFRONTO DEGLI INSIEMI DEI MEMBRI (FASE D0ter) ================\n")
a14 <- arrow::read_parquet(file.path(V14, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
a13 <- arrow::read_parquet(file.path(V13, "assignments.parquet"),
                           col_select = c("record_id", "cluster_id"))
m14 <- split(a14$record_id[a14$cluster_id %in% g14$cluster_id],
             a14$cluster_id[a14$cluster_id %in% g14$cluster_id])
m13 <- split(a13$record_id[a13$cluster_id %in% g13$cluster_id],
             a13$cluster_id[a13$cluster_id %in% g13$cluster_id])
names(m14) <- g14$ckey[match(names(m14), g14$cluster_id)]
names(m13) <- g13$ckey[match(names(m13), g13$cluster_id)]

tutte <- union(names(m13), names(m14))
stato <- vapply(tutte, function(k) {
  a <- m13[[k]]; b <- m14[[k]]
  if (is.null(a)) return("NUOVO")
  if (is.null(b)) return("SPARITO")
  if (setequal(a, b)) "IDENTICO" else "CAMBIATO"
}, character(1L))
print(table(stato))
cat(sprintf("\n  -> i verdetti di coerenza restano validi sui %d gruppi IDENTICI\n",
            sum(stato == "IDENTICO")))
cat(sprintf("  -> DA RILEGGERE: %d cambiati + %d nuovi = %d\n",
            sum(stato == "CAMBIATO"), sum(stato == "NUOVO"),
            sum(stato %in% c("CAMBIATO", "NUOVO"))))

cat("\n  --- i 6 verdetti di incoerenza: la loro chiave esiste ancora? ---\n")
v <- utils::read.csv("analysis/audit/2026-07-29-etichette-v13/verdetti-poolato-v13.csv",
                     stringsAsFactors = FALSE)
v$in_v14 <- v$ckey %in% names(m14)
v$stato  <- ifelse(v$ckey %in% tutte, stato[v$ckey], "ASSENTE")
print(v[, c("ckey", "in_v14", "stato")], row.names = FALSE)
orf <- v$ckey[!v$in_v14]
if (length(orf)) {
  cat(sprintf("\n  ⚠️ VERDETTI ORFANI: %d -> l'annotazione del deliverable si FERMEREBBE.\n",
              length(orf)))
  cat("     ", paste(orf, collapse = "\n      "), "\n")
} else cat("\n  nessun verdetto orfano.\n")

d <- data.frame(ckey = tutte, stato = unname(stato), stringsAsFactors = FALSE)
d$k_v13 <- vapply(d$ckey, function(k) if (is.null(m13[[k]])) 0L else length(unique(sub("__.*$", "", m13[[k]]))), integer(1L))
d$k_v14 <- vapply(d$ckey, function(k) if (is.null(m14[[k]])) 0L else length(unique(sub("__.*$", "", m14[[k]]))), integer(1L))
write.csv(d[order(d$stato, -d$k_v14), ], file.path(OUT, "50-confronto-insiemi-v13-v14.csv"),
          row.names = FALSE)
cat("\nScritto 50-confronto-insiemi-v13-v14.csv\n")
