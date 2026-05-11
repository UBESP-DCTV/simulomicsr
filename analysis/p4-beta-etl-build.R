# analysis/p4-beta-etl-build.R
# Pipeline ETL completa P4 β: ARCHS4 H5 -> resolver -> JSONL stage1-input.

library(simulomicsr)
library(jsonlite)
library(fs)

stopifnot(nzchar(Sys.getenv("NCBI_API_KEY")))

# Path ARCHS4 H5 download (utente lo posiziona qui prima del run)
H5_PATH <- "analysis/input/archs4-human-gene-v2.5.h5"
STAGE1_INPUT_RAW <- "analysis/input/archs4-human-stage1-input-raw.jsonl"
STAGE1_INPUT_FINAL <- "analysis/input/archs4-human-stage1-input.jsonl"
ENTREZ_CACHE <- tools::R_user_dir("simulomicsr", "cache") |>
  file.path("geo-series-resolver-cache.rds")
PROVENANCE_PATH <- "analysis/p4-output/p4-beta-archs4-source.json"
SKIPPED_PATH <- "analysis/p4-output/p4-beta-etl-skipped.tsv"
MULTISERIES_LOG <- "analysis/p4-output/p4-beta-etl-multiseries.tsv"
TIEBREAK_LOG <- "analysis/p4-output/series-id-resolver-tiebreak.tsv"
FALLBACK_LOG <- "analysis/p4-output/series-id-resolver-fallback.tsv"

dir_create(dirname(c(STAGE1_INPUT_RAW, PROVENANCE_PATH, ENTREZ_CACHE)))

# ---- 1. Provenance record ----
stopifnot(file.exists(H5_PATH))
sha256 <- tools::md5sum(H5_PATH)  # quick check; SHA256 vero via openssl in step seguente
writeLines(jsonlite::toJSON(list(
  file = H5_PATH,
  size_bytes = as.integer(file.info(H5_PATH)$size),
  md5 = unname(sha256),
  fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
  source_url = "https://maayanlab.cloud/archs4/download.html",
  version_label = "human_gene_v2.5.h5"
), pretty = TRUE, auto_unbox = TRUE), PROVENANCE_PATH)
cat("Provenance saved:", PROVENANCE_PATH, "\n")

# ---- 2. ETL H5 -> JSONL raw (filtri organism/library_strategy/string-length) ----
cat("Reading H5...\n")
res_etl <- simulomicsr:::archs4_to_stage1_jsonl(
  h5_path = H5_PATH,
  out_jsonl_path = STAGE1_INPUT_RAW,
  skip_log_path = SKIPPED_PATH
)
cat(sprintf("ETL done. Included %d / Skipped %d (Total %d)\n",
            res_etl$included, res_etl$skipped, res_etl$total))

# ---- 3. Series-id-resolver: fetch metadata per i GSE unici nel JSONL raw ----
recs <- jsonlite::stream_in(file(STAGE1_INPUT_RAW), verbose = FALSE)
all_gses <- unique(trimws(unlist(strsplit(recs$series_id, ","))))
all_gses <- all_gses[nzchar(all_gses)]
cat(sprintf("Unique GSE da fetchare: %d\n", length(all_gses)))

entrez_cache <- if (file.exists(ENTREZ_CACHE)) readRDS(ENTREZ_CACHE) else list()
todo <- setdiff(all_gses, names(entrez_cache))
cat(sprintf("GSE non in cache: %d (stima %.1f min)\n",
            length(todo), length(todo) / 80 / 60))

t0 <- Sys.time()
for (i in seq_along(todo)) {
  entrez_cache[[todo[i]]] <- simulomicsr:::entrez_lookup_gse_metadata(todo[i])
  if (i %% 200 == 0) {
    saveRDS(entrez_cache, ENTREZ_CACHE)
    cat(sprintf("  [%d/%d] cache saved\n", i, length(todo)))
  }
}
saveRDS(entrez_cache, ENTREZ_CACHE)
cat(sprintf("Entrez done in %.1f min\n",
            as.numeric(difftime(Sys.time(), t0, units = "mins"))))

# ---- 4. Apply resolver per sample, write final JSONL ----
tiebreak_rows <- list()
fallback_rows <- list()
multi_rows <- list()
recs$series_id_resolved <- NA_character_
recs$resolver_branch <- NA_character_

for (i in seq_len(nrow(recs))) {
  out <- simulomicsr:::resolve_series_id(recs$series_id[i], entrez_cache)
  recs$series_id_resolved[i] <- out$decision
  recs$resolver_branch[i] <- out$branch
  if (out$branch == "tiebreak_both_srp") {
    tiebreak_rows[[length(tiebreak_rows) + 1L]] <-
      data.frame(geo_accession = recs$geo_accession[i],
                 series_id_input = recs$series_id[i],
                 series_id_resolved = out$decision,
                 stringsAsFactors = FALSE)
  } else if (out$branch == "fallback_no_srp" || out$branch == "all_super_pathological") {
    fallback_rows[[length(fallback_rows) + 1L]] <-
      data.frame(geo_accession = recs$geo_accession[i],
                 series_id_input = recs$series_id[i],
                 series_id_resolved = out$decision,
                 branch = out$branch,
                 stringsAsFactors = FALSE)
  }
  if (grepl(",", recs$series_id[i])) {
    multi_rows[[length(multi_rows) + 1L]] <-
      data.frame(geo_accession = recs$geo_accession[i],
                 series_id_input = recs$series_id[i],
                 series_id_resolved = out$decision,
                 resolver_branch = out$branch,
                 stringsAsFactors = FALSE)
  }
}

write_jsonl <- function(df, path) {
  lines <- vapply(seq_len(nrow(df)),
                  function(i) jsonlite::toJSON(as.list(df[i, ]), auto_unbox = TRUE),
                  character(1L))
  writeLines(lines, path)
}
write_jsonl(recs[, c("geo_accession", "series_id_resolved", "string",
                     "library_strategy", "organism")], STAGE1_INPUT_FINAL)

if (length(tiebreak_rows) > 0) write.table(do.call(rbind, tiebreak_rows), TIEBREAK_LOG,
                                            sep = "\t", row.names = FALSE, quote = FALSE)
if (length(fallback_rows) > 0) write.table(do.call(rbind, fallback_rows), FALLBACK_LOG,
                                            sep = "\t", row.names = FALSE, quote = FALSE)
if (length(multi_rows) > 0) write.table(do.call(rbind, multi_rows), MULTISERIES_LOG,
                                         sep = "\t", row.names = FALSE, quote = FALSE)

cat("\n=== ETL complete ===\n")
cat(sprintf("Final JSONL: %s\n", STAGE1_INPUT_FINAL))
cat(sprintf("N records included: %d\n", nrow(recs)))
cat(sprintf("Multi-series tracked: %d\n", length(multi_rows)))
cat(sprintf("Tiebreak log: %d\n", length(tiebreak_rows)))
cat(sprintf("Fallback log: %d\n", length(fallback_rows)))
cat("\nBranch distribution:\n")
print(table(recs$resolver_branch))
