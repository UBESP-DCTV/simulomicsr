#!/usr/bin/env Rscript
# RED ALERT FASE A7 — confronto qualita' dedupe: relation (BioSample SAMN)
# vs donor_id (LLM Stage 1).
#
# Output:
#   1. Coverage breakdown SAMN ∩ donor_id (4 quadranti)
#   2. Duplicati cross-GSE per ciascun segnale
#   3. Caso ambigui per ispezione manuale

suppressMessages({ library(rhdf5) })
set.seed(42)

h5_path <- "analysis/input/human_gene_v2.5.h5"
master  <- "analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl"
out_tsv <- "analysis/audit/A7-biosample-donor-coverage.tsv"
out_dups <- "analysis/audit/A7-cross-gse-duplicates.tsv"

# ============================================================
# Step 1: SAMN da relation H5
# ============================================================
cat("[A7] reading H5 relation + geo_accession + series_id ...\n")
h5_geo    <- as.character(rhdf5::h5read(h5_path, "meta/samples/geo_accession"))
h5_ser    <- as.character(rhdf5::h5read(h5_path, "meta/samples/series_id"))
h5_rel    <- as.character(rhdf5::h5read(h5_path, "meta/samples/relation"))
rhdf5::H5close()

# Parser SAMN (regex \bSAMN\d+\b)
extract_samn <- function(x) {
  m <- regmatches(x, regexpr("SAMN\\d+", x))
  ifelse(length(m) == 0, NA_character_, m)
}
cat("[A7] parsing SAMN from relation ...\n")
samn <- vapply(h5_rel, extract_samn, character(1L), USE.NAMES = FALSE)
cat(sprintf("[A7] H5 total: %d, samn non-NA: %d (%.2f%%)\n",
            length(samn), sum(!is.na(samn)), 100*mean(!is.na(samn))))

# ============================================================
# Step 2: donor_id LLM dal master rescued
# ============================================================
cat("[A7] reading master rescued JSONL ...\n")
lines <- readLines(master, warn = FALSE)
cat(sprintf("[A7] master lines: %d\n", length(lines)))

# Parse record_id + donor_id
parse_rid <- function(line) {
  m <- regmatches(line, regexpr('"record_id"\\s*:\\s*"[^"]+"', line))
  if (length(m) == 0) return(NA_character_)
  sub('.*"record_id"\\s*:\\s*"([^"]+)".*', "\\1", m)
}
# donor_id puo' essere:
#   "donor_id":null
#   "donor_id":"patient 5"
#   \"donor_id\": null              (escaped nel raw_output)
#   \"donor_id\": \"patient 5\"     (escaped)
# Cerco anche all'interno della string escaped raw_output.
parse_donor <- function(line) {
  # Cerca prima il pattern escaped (raw_output contiene il vero parsed JSON)
  m_esc <- regmatches(line, regexpr('\\\\"donor_id\\\\"\\s*:\\s*(\\\\"[^"\\\\]*\\\\"|null)', line))
  if (length(m_esc) > 0) {
    val <- sub('.*\\\\"donor_id\\\\"\\s*:\\s*\\\\"([^"\\\\]*)\\\\".*', "\\1", m_esc)
    if (val == m_esc) return(NA_character_)  # was null
    return(val)
  }
  # Fallback unescaped
  m <- regmatches(line, regexpr('"donor_id"\\s*:\\s*("[^"]*"|null)', line))
  if (length(m) == 0) return(NA_character_)
  val <- sub('"donor_id"\\s*:\\s*"([^"]*)".*', "\\1", m)
  if (val == m) return(NA_character_)  # was null
  val
}

cat("[A7] parsing donor_id from master ...\n")
rescued_gsm <- vapply(lines, parse_rid, character(1L), USE.NAMES = FALSE)
donor_id    <- vapply(lines, parse_donor, character(1L), USE.NAMES = FALSE)
# Normalize donor_id: NA o "" -> NA, trim
donor_id_norm <- ifelse(is.na(donor_id) | trimws(donor_id) == "", NA_character_,
                         tolower(trimws(donor_id)))
rm(lines); gc(verbose = FALSE)

cat(sprintf("[A7] rescued GSM with donor_id non-NA: %d / %d (%.2f%%)\n",
            sum(!is.na(donor_id_norm)), length(donor_id_norm),
            100*mean(!is.na(donor_id_norm))))

# ============================================================
# Step 3: build dataframe bacino rescued
# ============================================================
idx <- match(rescued_gsm, h5_geo)
stopifnot(!anyNA(idx))
df <- data.frame(
  geo = rescued_gsm,
  series = h5_ser[idx],
  samn = samn[idx],
  donor_id = donor_id_norm,
  stringsAsFactors = FALSE
)
rm(h5_geo, h5_ser, h5_rel, samn, idx); gc(verbose = FALSE)

cat(sprintf("[A7] bacino rescued: %d\n", nrow(df)))

# Coverage 4-quadranti
df$has_samn  <- !is.na(df$samn)
df$has_donor <- !is.na(df$donor_id)
cat("\n[A7] === Coverage 2x2 SAMN × donor_id ===\n")
ct <- table(SAMN = df$has_samn, donor = df$has_donor)
print(ct)
cat(sprintf("\n  both           : %d (%.2f%%)\n",
            sum(df$has_samn & df$has_donor),
            100*mean(df$has_samn & df$has_donor)))
cat(sprintf("  SAMN only      : %d (%.2f%%)\n",
            sum(df$has_samn & !df$has_donor),
            100*mean(df$has_samn & !df$has_donor)))
cat(sprintf("  donor only     : %d (%.2f%%)\n",
            sum(!df$has_samn & df$has_donor),
            100*mean(!df$has_samn & df$has_donor)))
cat(sprintf("  none           : %d (%.2f%%)\n",
            sum(!df$has_samn & !df$has_donor),
            100*mean(!df$has_samn & !df$has_donor)))

# ============================================================
# Step 4: duplicati cross-GSE
# ============================================================
cat("\n[A7] === Duplicati cross-GSE ===\n")

# SAMN duplicati cross-GSE: lo stesso SAMN in piu' di 1 series_id distinto
df_samn <- df[df$has_samn, c("geo", "series", "samn")]
samn_x_series <- aggregate(series ~ samn, data = df_samn,
                            FUN = function(s) length(unique(s)))
names(samn_x_series)[2] <- "n_distinct_series"
samn_dup <- samn_x_series[samn_x_series$n_distinct_series > 1, ]
cat(sprintf("SAMN unique with non-NA: %d\n", nrow(samn_x_series)))
cat(sprintf("SAMN in >1 series (cross-GSE dup): %d (%.2f%%)\n",
            nrow(samn_dup), 100 * nrow(samn_dup) / nrow(samn_x_series)))
cat(sprintf("istogramma n_distinct_series per SAMN duplicato:\n"))
print(table(cut(samn_dup$n_distinct_series,
                breaks = c(1, 2, 3, 5, 10, Inf),
                labels = c("2", "3", "4-5", "6-10", ">10"),
                right = TRUE, include.lowest = TRUE)))

# Sample-level: quanti GSM hanno SAMN che è cross-GSE?
df$samn_is_cross <- df$samn %in% samn_dup$samn
cat(sprintf("\nGSM con SAMN cross-GSE: %d / %d (%.2f%%)\n",
            sum(df$samn_is_cross), nrow(df), 100*mean(df$samn_is_cross)))

# donor_id duplicati cross-GSE (cautela: i donor_id banali tipo "patient 1" sono frequenti
# in tanti studi diversi, ma sono coincidenze NON veri duplicati cross-studio).
# Conta cmq per benchmark.
df_donor <- df[df$has_donor, c("geo", "series", "donor_id")]
donor_x_series <- aggregate(series ~ donor_id, data = df_donor,
                             FUN = function(s) length(unique(s)))
names(donor_x_series)[2] <- "n_distinct_series"
donor_dup <- donor_x_series[donor_x_series$n_distinct_series > 1, ]
cat(sprintf("\ndonor_id unique non-NA: %d\n", nrow(donor_x_series)))
cat(sprintf("donor_id in >1 series: %d (%.2f%%)\n",
            nrow(donor_dup), 100 * nrow(donor_dup) / nrow(donor_x_series)))
cat("top 20 donor_id più frequenti cross-GSE (probabile rumore):\n")
print(head(donor_dup[order(-donor_dup$n_distinct_series), ], 20), row.names = FALSE)

# ============================================================
# Step 5: casi controversi
# ============================================================
cat("\n[A7] === Casi controversi: stesso SAMN ma donor_id diversi ===\n")
df_both <- df[df$has_samn & df$has_donor, ]
samn_donor_combos <- aggregate(donor_id ~ samn, data = df_both,
                                FUN = function(d) length(unique(d)))
names(samn_donor_combos)[2] <- "n_distinct_donor"
disc <- samn_donor_combos[samn_donor_combos$n_distinct_donor > 1, ]
cat(sprintf("SAMN with >1 distinct donor_id: %d (%.2f%% di %d SAMN con entrambi)\n",
            nrow(disc), 100 * nrow(disc) / nrow(samn_donor_combos),
            nrow(samn_donor_combos)))

# Save 30 esempi controversi
if (nrow(disc) > 0L) {
  set.seed(7)
  sel_samn <- sample(disc$samn, min(15, nrow(disc)))
  ex <- df_both[df_both$samn %in% sel_samn, ]
  ex <- ex[order(ex$samn, ex$series), ]
  write.table(ex[, c("samn", "geo", "series", "donor_id")],
              "analysis/audit/A7-discordant-samn-donor.tsv",
              sep = "\t", row.names = FALSE, quote = FALSE)
  cat(sprintf("salvati 15 SAMN controversi in analysis/audit/A7-discordant-samn-donor.tsv\n"))
}

# Coverage finale
write.table(df, out_tsv, sep = "\t", row.names = FALSE, quote = FALSE)
# Save SAMN duplicates summary
write.table(samn_dup[order(-samn_dup$n_distinct_series), ], out_dups,
            sep = "\t", row.names = FALSE, quote = FALSE)

cat("\n[A7] DONE\n")
