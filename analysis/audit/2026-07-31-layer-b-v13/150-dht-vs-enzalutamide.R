#!/usr/bin/env Rscript
# 150-dht-vs-enzalutamide.R --- la figura 1 del paper, misurata invece che
# raccontata.
#
# L'argomento noto era: quattro bersagli scelti dalla letteratura (KLK3,
# TMPRSS2, FKBP5, NKX3-1) salgono col DHT e scendono con l'enzalutamide. E'
# vero, ma e' un controllo su geni SCELTI PRIMA.
#
# Guardando le tabelle dei due bundle e' saltata fuori una cosa piu' forte: fra
# i primi quindici geni per |logFC| x -log10(FDR), SETTE sono gli stessi nei due
# gruppi con segno opposto (PGC, UGT2B28, CHRNA2, SLC38A4, ALPK2, NNMT,
# ST6GALNAC1) — e nessuno di quei sette era stato scelto da nessuno.
#
# Qui si misura la cosa su TUTTO il trascrittoma condiviso, non sui primi
# quindici: correlazione dei logFC, concordanza dei segni, e la probabilita' che
# venga per caso. I due gruppi sono stati costruiti indipendentemente e non
# condividono studi (verificato qui sotto, non assunto).
#
# Usage: Rscript analysis/audit/2026-07-31-layer-b-v13/150-dht-vs-enzalutamide.R

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(dplyr); library(cli) })

S   <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v13/20260729T210013Z-stage4-v13-ac125296"
OUT <- "analysis/audit/2026-07-31-layer-b-v13"
DHT  <- "cgroup_L5_930c8dcf"
ENZA <- "cgroup_L5_c0d1d837"

# --- i due gruppi condividono studi? ----------------------------------------
# Se li condividessero, la simmetria sarebbe in parte un artefatto dello stesso
# esperimento. Va provato, non dato per scontato.
st <- arrow::open_dataset(file.path(S, "per_study_de.parquet")) |>
  filter(cluster_id %in% c(DHT, ENZA)) |>
  distinct(cluster_id, study_id) |> collect()
s_dht  <- st$study_id[st$cluster_id == DHT]
s_enza <- st$study_id[st$cluster_id == ENZA]
comuni <- intersect(s_dht, s_enza)
cli_alert_info("studi DHT: {length(s_dht)} | enzalutamide: {length(s_enza)} | IN COMUNE: {length(comuni)}")
if (length(comuni)) cli_alert_warning("studi condivisi: {paste(comuni, collapse=' ')}")

cp <- arrow::open_dataset(file.path(S, "cluster_pooled.parquet")) |>
  filter(cluster_id %in% c(DHT, ENZA)) |>
  select(cluster_id, gene_id, gene_symbol, logFC_pool, FDR_BH_within_cluster,
         k_effective, I2) |> collect()

a <- cp[cp$cluster_id == DHT, ]
b <- cp[cp$cluster_id == ENZA, ]
m <- merge(a, b, by = c("gene_id", "gene_symbol"), suffixes = c("_dht", "_enza"))
cli_alert_info("geni in comune fra i due pool: {nrow(m)}")

sig_both <- m[m$FDR_BH_within_cluster_dht < 0.05 & m$FDR_BH_within_cluster_enza < 0.05, ]
cli_alert_info("significativi in ENTRAMBI: {nrow(sig_both)}")

riga <- function(x, etichetta) {
  if (nrow(x) < 3L) return(invisible(NULL))
  r  <- stats::cor(x$logFC_pool_dht, x$logFC_pool_enza)
  rs <- stats::cor(x$logFC_pool_dht, x$logFC_pool_enza, method = "spearman")
  opp <- mean(sign(x$logFC_pool_dht) != sign(x$logFC_pool_enza))
  # probabilita' di vedere almeno questa concordanza per caso, se il segno fosse
  # una monetina: test binomiale a una coda
  n_opp <- sum(sign(x$logFC_pool_dht) != sign(x$logFC_pool_enza))
  p <- stats::binom.test(n_opp, nrow(x), p = 0.5, alternative = "greater")$p.value
  cat(sprintf("  %-34s n=%5d  Pearson=%+.3f  Spearman=%+.3f  segno opposto=%5.1f%%  p=%.2g\n",
              etichetta, nrow(x), r, rs, 100 * opp, p))
  invisible(NULL)
}

cli_h2("Correlazione dei logFC fra agonista e antagonista dello stesso recettore")
riga(m, "tutti i geni in comune")
riga(sig_both, "significativi in entrambi")
riga(sig_both[abs(sig_both$logFC_pool_dht) > 1 | abs(sig_both$logFC_pool_enza) > 1, ],
     "significativi + |logFC|>1 in uno dei due")

# --- i geni scoperti, non scelti -------------------------------------------
punteggio <- function(x, lf, fdr) abs(x[[lf]]) * (-log10(pmax(x[[fdr]], 1e-300)))
kmax_dht  <- max(a$k_effective, na.rm = TRUE)
kmax_enza <- max(b$k_effective, na.rm = TRUE)
top_dht <- a |> filter(FDR_BH_within_cluster < 0.05,
                       k_effective >= ceiling(0.5 * kmax_dht)) |>
  mutate(s = punteggio(pick(everything()), "logFC_pool", "FDR_BH_within_cluster")) |>
  arrange(desc(s)) |> head(30)
top_enza <- b |> filter(FDR_BH_within_cluster < 0.05,
                        k_effective >= ceiling(0.5 * kmax_enza)) |>
  mutate(s = punteggio(pick(everything()), "logFC_pool", "FDR_BH_within_cluster")) |>
  arrange(desc(s)) |> head(30)
condivisi <- intersect(top_dht$gene_symbol, top_enza$gene_symbol)
condivisi <- condivisi[!is.na(condivisi) & nzchar(condivisi)]

cli_h2("I primi 30 di ciascun gruppo: quanti sono gli stessi, e con che segno")
cat(sprintf("  condivisi fra i due elenchi: %d su 30\n", length(condivisi)))
tab <- data.frame(gene = condivisi,
                  logFC_dht  = a$logFC_pool[match(condivisi, a$gene_symbol)],
                  logFC_enza = b$logFC_pool[match(condivisi, b$gene_symbol)],
                  stringsAsFactors = FALSE)
tab$segno_opposto <- sign(tab$logFC_dht) != sign(tab$logFC_enza)
tab <- tab[order(-abs(tab$logFC_dht)), ]
for (i in seq_len(nrow(tab))) {
  cat(sprintf("    %-12s DHT %+6.2f   enzalutamide %+6.2f   %s\n",
              tab$gene[i], tab$logFC_dht[i], tab$logFC_enza[i],
              ifelse(tab$segno_opposto[i], "OPPOSTO", "stesso segno")))
}
cat(sprintf("\n  con segno opposto: %d su %d\n", sum(tab$segno_opposto), nrow(tab)))

# --- i quattro bersagli scelti dalla letteratura ----------------------------
cli_h2("I quattro bersagli noti, per confronto")
for (g in c("KLK3", "TMPRSS2", "FKBP5", "NKX3-1")) {
  i <- match(g, m$gene_symbol)
  if (is.na(i)) { cat(sprintf("  %-9s assente\n", g)); next }
  cat(sprintf("  %-9s DHT %+6.2f (k=%2d, I2=%5.1f)   enzalutamide %+6.2f (k=%2d, I2=%5.1f)\n",
              g, m$logFC_pool_dht[i], m$k_effective_dht[i], m$I2_dht[i],
              m$logFC_pool_enza[i], m$k_effective_enza[i], m$I2_enza[i]))
}

write.csv(tab, file.path(OUT, "dht-vs-enzalutamide-condivisi.csv"), row.names = FALSE)
write.csv(sig_both[, c("gene_symbol", "gene_id", "logFC_pool_dht", "logFC_pool_enza",
                       "FDR_BH_within_cluster_dht", "FDR_BH_within_cluster_enza",
                       "k_effective_dht", "k_effective_enza")],
          file.path(OUT, "dht-vs-enzalutamide-tutti.csv"), row.names = FALSE)
cli_alert_success("Scritte dht-vs-enzalutamide-condivisi.csv e -tutti.csv")
