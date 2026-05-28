#!/usr/bin/env Rscript
# p4-fase-f2-eval-build-pool.R --- costruisce il pool candidato per il gold
# design-aware scalato (FASE F2, eval autonomo notturno).
#
# Strategia: studi REALI dal bacino v2 (cio' che la pipeline processa) che
# hanno almeno qualche sample con etichetta umana nel gold autore
# (relevant_sample_classified.xlsx: trtctr_EP + gold). Studi COMPLETI
# (tutti i sample del GSE presenti nel bacino) di taglia gestibile, cosi'
# che Stadio 2 veda il design intero e io possa etichettare design_role_v3
# raffinando il prior umano.
#
# Output: analysis/p4-output/f2-eval-pool.rds con
#   - samples: data.frame(geo, series, string, molecule, trtctr_EP, gold)
#     per TUTTI i sample degli studi candidati
#   - study_stats: una riga per studio candidato

suppressPackageStartupMessages({ library(jsonlite) })

V2   <- "analysis/input/archs4-human-stage1-input-v2.jsonl"
XLSX <- "data-raw/relevant_sample_classified.xlsx"
OUT  <- "analysis/p4-output/f2-eval-pool.rds"

cat("Carico bacino v2 (508k)...\n")
recs <- jsonlite::stream_in(file(V2), verbose = FALSE, simplifyVector = TRUE)
v2 <- data.frame(
  geo      = as.character(recs$geo_accession),
  series   = as.character(recs$series_id),
  string   = as.character(recs$string),
  molecule = as.character(recs$molecule_ch1),
  stringsAsFactors = FALSE
)
cat(sprintf("  v2: %d sample, %d studi unici\n", nrow(v2), length(unique(v2$series))))

cat("Carico gold autore (XLSX)...\n")
suppressPackageStartupMessages(library(readxl))
gold <- readxl::read_excel(XLSX, sheet = "relevant_sample")
gold <- data.frame(
  geo       = as.character(gold$geo_accession),
  trtctr_EP = gold$trtctr_EP,
  gold      = gold$gold,
  stringsAsFactors = FALSE
)
gold <- gold[!is.na(gold$geo) & nzchar(gold$geo), ]
gold <- gold[!duplicated(gold$geo), ]
cat(sprintf("  gold autore: %d GSM etichettati\n", nrow(gold)))

# Overlap GSM
v2$in_gold <- v2$geo %in% gold$geo
cat(sprintf("Overlap: %d / %d sample v2 hanno etichetta umana (%.1f%%)\n",
            sum(v2$in_gold), nrow(v2), 100 * mean(v2$in_gold)))

# Stat per studio (su TUTTI i sample del bacino, studi completi)
agg <- aggregate(cbind(n_samples = rep(1L, nrow(v2)), n_labeled = as.integer(v2$in_gold)),
                 by = list(series = v2$series), FUN = sum)
cat(sprintf("Studi nel bacino: %d\n", nrow(agg)))

# Hint design: keyword nelle stringhe per stratificare diversita'
study_hint <- function(s_series) {
  ss <- tolower(paste(v2$string[v2$series == s_series], collapse = " || "))
  c(
    sirna   = grepl("sirna|shrna|knock|sictrl|sint|scramble|sh-", ss),
    drug    = grepl("treat|drug|compound|dmso|vehicle|dose|µm|uM|nm |ng/ml|inhibitor|agonist|stimul", ss),
    time    = grepl("time|hour|hr |day | h$|t0|timepoint|0h|24h|48h", ss),
    geno    = grepl("wt |wild.?type|ko |knockout|mutant|overexpress|\\boe\\b|transgen|crispr", ss),
    disease = grepl("tumor|tumour|cancer|carcinoma|patient|disease|healthy|normal|control subject", ss)
  )
}

# Candidati: taglia 4..24, almeno 2 sample etichettati a mano
cand <- agg[agg$n_samples >= 4 & agg$n_samples <= 24 & agg$n_labeled >= 2, ]
cat(sprintf("Studi candidati (4<=n<=24, >=2 labeled): %d\n", nrow(cand)))

saveRDS(list(v2 = v2, gold = gold, agg = agg, cand = cand),
        "analysis/p4-output/f2-eval-pool-raw.rds")
cat("Salvato raw pool. Distribuzione taglia candidati:\n")
print(table(cut(cand$n_samples, c(3,6,10,16,24))))
cat("\nDone build-pool (raw).\n")
