OUT <- "analysis/audit/2026-08-20-rilettura-194"
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
d <- readRDS(file.path(POOL,"deliverable-annotato.rds"))
M <- read.csv(file.path(OUT,"B4-quadro-influenza.csv"), stringsAsFactors=FALSE)
v <- read.csv(file.path(OUT,"verdetti-194.csv"), stringsAsFactors=FALSE)
M$eti <- v$etichetta_non_chiude[match(M$cluster_id, v$cluster_id)]
i <- match(M$cluster_id, d$cluster_id)
M$quota_top1 <- d$quota_top1[i]; M$k_kish <- d$k_kish[i]
M$nome <- d$contrast_entity_label[i]; M$n_sig <- d$n_sig[i]; M$I2 <- d$I2_med[i]

f <- function(x, etichetta) cat(sprintf("  %-58s %3d\n", etichetta, sum(x)))
cat("=== IL SETACCIO, un criterio alla volta (parte da 194) ===\n")
a <- rep(TRUE, nrow(M));                      f(a, "tutte")
a <- a & M$n_studi_accusati == 0;             f(a, "+ nessun difetto letto")
a <- a & M$verdetto == "corretta";            f(a, "+ verdetto 'corretta' (non 'incerta')")
a <- a & M$eti != "True";                     f(a, "+ il verdetto e' chiuso dall'etichetta")
a <- a & !is.na(M$quota_top1) & M$quota_top1 <= 0.5;                 f(a, "+ nessuno studio pesa piu' della meta'")
a <- a & !is.na(M$k_kish) & M$k_kish >= 2;                       f(a, "+ almeno 2 studi efficaci (Kish)")
cat("\n=== IL NOCCIOLO: che aspetto ha ===\n")
N <- M[a, ]
cat("  k: mediana", median(N$k), "| min", min(N$k), "| max", max(N$k), "\n")
cat("  a k>=15:", sum(N$k>=15), " | a k=3-4:", sum(N$k<=4), "\n")
cat("  geni significativi: mediana", format(median(N$n_sig), big.mark=" "), "\n\n")
cat("  le dieci piu' grandi:\n")
N <- N[order(-N$k), ]
for (j in seq_len(min(10,nrow(N)))) cat(sprintf("    k=%2d  %-34s  %6d geni sig  I2=%.0f\n",
  N$k[j], substr(N$nome[j],1,34), N$n_sig[j], N$I2[j]))
