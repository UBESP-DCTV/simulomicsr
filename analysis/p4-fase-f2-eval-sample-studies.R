#!/usr/bin/env Rscript
# Campiona studi candidati (stratificato per taglia, seed=42) e genera il
# worksheet di etichettatura design_role_v3 (FASE F2 eval autonomo).

set.seed(42)
pool <- readRDS("analysis/p4-output/f2-eval-pool-raw.rds")
v2 <- pool$v2; gold <- pool$gold; cand <- pool$cand

cand$bin <- cut(cand$n_samples, c(3,6,10,16,24), labels = c("s","m","l","xl"))
take <- c(s = 26L, m = 18L, l = 16L, xl = 12L)   # ~700 sample attesi
sel <- do.call(rbind, lapply(names(take), function(b) {
  poolb <- cand[cand$bin == b, ]
  poolb[sample(nrow(poolb), min(take[[b]], nrow(poolb))), ]
}))
cat(sprintf("Studi selezionati: %d | sample totali attesi: %d\n",
            nrow(sel), sum(sel$n_samples)))

# Pull TUTTI i sample dei series selezionati (studi completi)
ev <- v2[v2$series %in% sel$series, c("geo","series","string","molecule")]
ev <- merge(ev, gold[, c("geo","trtctr_EP","gold")], by = "geo", all.x = TRUE)
ev <- ev[order(ev$series, ev$geo), ]
cat(sprintf("Sample totali nel worksheet: %d (studi: %d)\n",
            nrow(ev), length(unique(ev$series))))
cat("Sample con prior umano (trtctr_EP non-NA):", sum(!is.na(ev$trtctr_EP)), "\n")

saveRDS(list(sel = sel, ev = ev), "analysis/p4-output/f2-eval-worksheet.rds")

# Dump testuale leggibile, raggruppato per studio, per l'etichettatura
con <- file("analysis/p4-output/f2-eval-worksheet.txt", "w")
for (s in unique(ev$series)) {
  rows <- ev[ev$series == s, ]
  writeLines(sprintf("\n===== %s  (n=%d) =====", s, nrow(rows)), con)
  for (i in seq_len(nrow(rows))) {
    writeLines(sprintf("  %s | EP=%s | gold=%s | %s",
                       rows$geo[i],
                       ifelse(is.na(rows$trtctr_EP[i]), "-", as.character(rows$trtctr_EP[i])),
                       ifelse(is.na(rows$gold[i]), "-", as.character(rows$gold[i])),
                       substr(gsub("[\r\n]+", " ", rows$string[i]), 1, 300)), con)
  }
}
close(con)
cat("Worksheet scritto: analysis/p4-output/f2-eval-worksheet.txt\n")
