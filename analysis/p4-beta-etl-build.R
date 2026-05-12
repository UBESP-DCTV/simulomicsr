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

# ---- 4. Apply resolver per sample (vectorized: unique-string + match lookup) ----
# Risolvi solo le ~32k stringhe series_id uniche invece di 888k sample-level calls.
unique_sids <- unique(recs$series_id)
cat(sprintf("Unique series_id strings da risolvere: %d (vs %d sample-level)\n",
            length(unique_sids), nrow(recs)))
t_resolve <- Sys.time()
resolved_decision <- character(length(unique_sids))
resolved_branch   <- character(length(unique_sids))
for (i in seq_along(unique_sids)) {
  out <- simulomicsr:::resolve_series_id(unique_sids[i], entrez_cache)
  resolved_decision[i] <- as.character(out$decision)
  resolved_branch[i]   <- as.character(out$branch)
}
cat(sprintf("Resolver unique done in %.1f sec\n",
            as.numeric(difftime(Sys.time(), t_resolve, units = "secs"))))

# Map back ai 888k sample via match (hash-based, O(N))
idx <- match(recs$series_id, unique_sids)
recs$series_id_resolved <- resolved_decision[idx]
recs$resolver_branch    <- resolved_branch[idx]

# ---- Vectorized log filters ----
is_multi    <- grepl(",", recs$series_id, fixed = TRUE)
is_tiebreak <- recs$resolver_branch == "tiebreak_both_srp"
is_fallback <- recs$resolver_branch %in% c("fallback_no_srp", "all_super_pathological")

if (any(is_tiebreak)) {
  write.table(
    data.frame(geo_accession      = recs$geo_accession[is_tiebreak],
               series_id_input    = recs$series_id[is_tiebreak],
               series_id_resolved = recs$series_id_resolved[is_tiebreak],
               stringsAsFactors = FALSE),
    TIEBREAK_LOG, sep = "\t", row.names = FALSE, quote = FALSE)
}
if (any(is_fallback)) {
  write.table(
    data.frame(geo_accession      = recs$geo_accession[is_fallback],
               series_id_input    = recs$series_id[is_fallback],
               series_id_resolved = recs$series_id_resolved[is_fallback],
               branch             = recs$resolver_branch[is_fallback],
               stringsAsFactors = FALSE),
    FALLBACK_LOG, sep = "\t", row.names = FALSE, quote = FALSE)
}
if (any(is_multi)) {
  write.table(
    data.frame(geo_accession      = recs$geo_accession[is_multi],
               series_id_input    = recs$series_id[is_multi],
               series_id_resolved = recs$series_id_resolved[is_multi],
               resolver_branch    = recs$resolver_branch[is_multi],
               stringsAsFactors = FALSE),
    MULTISERIES_LOG, sep = "\t", row.names = FALSE, quote = FALSE)
}

# ---- Write final JSONL via stream_out (NDJSON, batch buffer) ----
t_write <- Sys.time()
final_df <- recs[, c("geo_accession", "series_id_resolved", "string",
                     "library_strategy", "organism")]
con_out <- file(STAGE1_INPUT_FINAL, "w")
jsonlite::stream_out(final_df, con_out, verbose = FALSE)
close(con_out)
cat(sprintf("Final JSONL written in %.1f sec\n",
            as.numeric(difftime(Sys.time(), t_write, units = "secs"))))

cat("\n=== ETL complete ===\n")
cat(sprintf("Final JSONL: %s\n", STAGE1_INPUT_FINAL))
cat(sprintf("N records included: %d\n", nrow(recs)))
cat(sprintf("Multi-series tracked: %d\n", sum(is_multi)))
cat(sprintf("Tiebreak log: %d\n", sum(is_tiebreak)))
cat(sprintf("Fallback log: %d\n", sum(is_fallback)))
cat("\nBranch distribution:\n")
print(table(recs$resolver_branch))
