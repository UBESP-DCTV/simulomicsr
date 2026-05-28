# analysis/p4-fase-f-etl-build.R
# ============================================================================
# RED ALERT FASE F1 — ETL re-run Stadio 0 v2 (ADR-0019).
# ============================================================================
# Pipeline: ARCHS4 H5 -> filtro Stage 0 v2 (D1-D4) -> series-resolver ->
# filtro H2 mouse-mislabeled (A1, post-resolver) -> JSONL stage1-input-v2.
#
# Riscrittura paper-grade di analysis/p4-beta-etl-build.R (che restava
# stale pre-FASE-C). Vedi piano:
#   docs/superpowers/plans/2026-05-28-p5-fase-f1-etl-rebuild-plan.md
#
# Differenze chiave vs script beta:
#   - H5_PATH corretto (human_gene_v2.5.h5).
#   - lib_size_vec passato -> filtro D4 attivo (era saltato).
#   - molecule_ch1 PRESERVATO nel JSONL finale (era droppato in final_df).
#   - filtro H2 post-resolver (drop pulito 72 GSE mouse-mislabeled).
#   - sanity check ex-post set-equality vs oracle A3.
#   - NCBI_API_KEY richiesto solo se cache resolver incompleta.
#
# Decisione utente (piano §5): opzione (i) H2 DROP PULITO. GSM3612196
# (GSE126753, 78.6% murino) viene droppato se il resolver lo risolve a un
# GSE H2. Bacino atteso 508.037 o 508.038 (delta == solo GSM3612196).

library(simulomicsr)
suppressPackageStartupMessages({
  library(jsonlite)
  library(fs)
})

# ---- Path ----
H5_PATH            <- "analysis/input/human_gene_v2.5.h5"
A3_TSV             <- "analysis/audit/A3-libsize-scprob-bacino.tsv"
H2_SUSPECTS        <- "analysis/p4-output/p4-beta-rescue-h2-suspects.rds"
STAGE1_INPUT_RAW   <- "analysis/input/archs4-human-stage1-input-v2-raw.jsonl"
STAGE1_INPUT_FINAL <- "analysis/input/archs4-human-stage1-input-v2.jsonl"
ENTREZ_CACHE       <- file.path(tools::R_user_dir("simulomicsr", "cache"),
                                "geo-series-resolver-cache.rds")
PROVENANCE_PATH    <- "analysis/p4-output/p4-fase-f-source.json"
SKIPPED_PATH       <- "analysis/p4-output/p4-fase-f-skipped.tsv"
H2_DROP_LOG        <- "analysis/p4-output/p4-fase-f-h2-drop-gsm.tsv"

SHA256_KNOWN <- "a1063426cb51986c77574d80d344918a075804c155e9b18c2e551b1077ad5d18"

stopifnot(file.exists(H5_PATH), file.exists(A3_TSV), file.exists(H2_SUSPECTS))

# ============================================================================
# 1. Provenance (sha256 H5 + tag E5 + timestamp).
# ============================================================================
cat("== 1. Provenance ==\n")
cat("  sha256 H5 (47.86 GB, ~3-5 min)...\n")
t_sha <- Sys.time()
sha256 <- system2("sha256sum", shQuote(H5_PATH), stdout = TRUE)
sha256 <- sub("\\s.*$", "", sha256)
cat(sprintf("  sha256: %s (%.1f min)\n", sha256,
            as.numeric(Sys.time() - t_sha, units = "mins")))
if (!identical(sha256, SHA256_KNOWN)) {
  stop(sprintf("sha256 H5 (%s) != noto CLAUDE.md (%s). Integrita' dump compromessa.",
               sha256, SHA256_KNOWN))
}
cat("  sha256 == valore noto CLAUDE.md: OK\n")

git_head <- tryCatch(
  system2("git", c("rev-parse", "HEAD"), stdout = TRUE),
  error = function(e) NA_character_)
schema_v <- simulomicsr:::stage4_default_config()$schema_versions

writeLines(jsonlite::toJSON(list(
  file            = H5_PATH,
  size_bytes      = as.numeric(file.info(H5_PATH)$size),
  sha256          = sha256,
  md5             = unname(tools::md5sum(H5_PATH)),
  built_at        = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ"),
  source_url      = "https://mssm-data.s3.amazonaws.com/human_gene_v2.5.h5",
  version_label   = "human_gene_v2.5.h5",
  package_version = as.character(utils::packageVersion("simulomicsr")),
  git_head        = git_head,
  schema_versions = schema_v,            # "tag E5"
  h2_suspects_file = H2_SUSPECTS,
  h2_n_gse        = 72L,
  fase            = "F1_etl_stage0_v2"
), pretty = TRUE, auto_unbox = TRUE), PROVENANCE_PATH)
cat(sprintf("  provenance -> %s\n\n", PROVENANCE_PATH))

# ============================================================================
# 2. ETL H5 -> raw JSONL (D1+D2+D3+D4 + molecule_ch1 emesso).
# ============================================================================
cat("== 2. ETL H5 -> raw JSONL (filtro Stage 0 v2 D1-D4) ==\n")
# lib_size_vec allineato all'ordine H5 (read_archs4_metadata legge
# meta/samples/geo_accession nello stesso ordine deterministico).
t_geo <- Sys.time()
geo_order <- as.character(rhdf5::h5read(H5_PATH, "meta/samples/geo_accession"))
rhdf5::H5close()
lib_size_vec <- simulomicsr:::.build_libsize_vec(geo_order, A3_TSV)
cat(sprintf("  lib_size_vec: %d sample, %d non-NA (%.1f sec)\n",
            length(lib_size_vec), sum(!is.na(lib_size_vec)),
            as.numeric(Sys.time() - t_geo, units = "secs")))

t_etl <- Sys.time()
res_etl <- simulomicsr:::archs4_to_stage1_jsonl(
  h5_path        = H5_PATH,
  out_jsonl_path = STAGE1_INPUT_RAW,
  skip_log_path  = SKIPPED_PATH,
  lib_size_vec   = lib_size_vec
)
cat(sprintf("  ETL: included %d / skipped %d (total %d) in %.1f min\n",
            res_etl$included, res_etl$skipped, res_etl$total,
            as.numeric(Sys.time() - t_etl, units = "mins")))
cat("  skip reason breakdown:\n")
print(table(read.table(SKIPPED_PATH, sep = "\t", header = TRUE,
                        stringsAsFactors = FALSE)$skip_reason))

# ============================================================================
# 3. Series-id-resolver (da cache; NCBI key solo se cache incompleta).
# ============================================================================
cat("\n== 3. Series-id-resolver ==\n")
recs <- jsonlite::stream_in(file(STAGE1_INPUT_RAW), verbose = FALSE)
stopifnot("molecule_ch1" %in% names(recs))  # fix problema #3: molecule presente

all_gses <- unique(trimws(unlist(strsplit(recs$series_id, ","))))
all_gses <- all_gses[nzchar(all_gses)]
entrez_cache <- if (file.exists(ENTREZ_CACHE)) readRDS(ENTREZ_CACHE) else list()
todo <- setdiff(all_gses, names(entrez_cache))
cat(sprintf("  GSE unici: %d | non in cache: %d\n", length(all_gses), length(todo)))

if (length(todo) > 0L) {
  stopifnot("NCBI_API_KEY mancante ma cache incompleta" = nzchar(Sys.getenv("NCBI_API_KEY")))
  t0 <- Sys.time()
  for (i in seq_along(todo)) {
    entrez_cache[[todo[i]]] <- simulomicsr:::entrez_lookup_gse_metadata(todo[i])
    if (i %% 200 == 0) saveRDS(entrez_cache, ENTREZ_CACHE)
  }
  saveRDS(entrez_cache, ENTREZ_CACHE)
  cat(sprintf("  Entrez fetch %d GSE in %.1f min\n", length(todo),
              as.numeric(Sys.time() - t0, units = "mins")))
} else {
  cat("  cache completa: nessuna chiamata NCBI necessaria\n")
}

unique_sids <- unique(recs$series_id)
resolved_decision <- character(length(unique_sids))
resolved_branch   <- character(length(unique_sids))
for (i in seq_along(unique_sids)) {
  out <- simulomicsr:::resolve_series_id(unique_sids[i], entrez_cache)
  resolved_decision[i] <- as.character(out$decision)
  resolved_branch[i]   <- as.character(out$branch)
}
idx <- match(recs$series_id, unique_sids)
recs$series_id_resolved <- resolved_decision[idx]
recs$resolver_branch    <- resolved_branch[idx]
cat(sprintf("  risolti %d series uniche -> %d series risolte distinte\n",
            length(unique_sids), length(unique(recs$series_id_resolved))))

# ============================================================================
# 4. Filtro H2 mouse-mislabeled (A1, POST-resolver, drop pulito).
# ============================================================================
cat("\n== 4. Filtro H2 mouse-mislabeled (post-resolver) ==\n")
h2_gse <- readRDS(H2_SUSPECTS)$series_id
is_h2  <- simulomicsr:::.flag_mouse_mislabeled_h2(recs$series_id_resolved, h2_gse)
cat(sprintf("  H2 drop: %d sample (su %d GSE H2)\n", sum(is_h2), length(h2_gse)))
write.table(
  data.frame(geo_accession      = recs$geo_accession[is_h2],
             series_id_raw      = recs$series_id[is_h2],
             series_id_resolved = recs$series_id_resolved[is_h2],
             stringsAsFactors = FALSE),
  H2_DROP_LOG, sep = "\t", row.names = FALSE, quote = FALSE)
recs <- recs[!is_h2, , drop = FALSE]

# ============================================================================
# 5. JSONL finale (molecule_ch1 PRESERVATO + series risolto).
# ============================================================================
cat("\n== 5. JSONL finale ==\n")
final_df <- data.frame(
  record_id        = recs$geo_accession,
  geo_accession    = recs$geo_accession,
  series_id        = recs$series_id_resolved,
  string           = recs$string,
  library_strategy = recs$library_strategy,
  organism         = recs$organism,
  molecule_ch1     = recs$molecule_ch1,    # fix problema #3 vs script beta
  stringsAsFactors = FALSE
)
con_out <- file(STAGE1_INPUT_FINAL, "w")
jsonlite::stream_out(final_df, con_out, verbose = FALSE)
close(con_out)
cat(sprintf("  scritto %s (%d record)\n", STAGE1_INPUT_FINAL, nrow(final_df)))

# ============================================================================
# 6. Sanity check ex-post (gate F1).
# ============================================================================
cat("\n== 6. Sanity check ex-post ==\n")
a3 <- read.table(A3_TSV, sep = "\t", header = TRUE, stringsAsFactors = FALSE)
oracle <- a3$geo[a3$passed_libsize_500k & a3$singlecellprobability < 0.9]
final_geo <- final_df$geo_accession

extra   <- setdiff(final_geo, oracle)   # F1 include GSM NON nell'oracle -> bug
missing <- setdiff(oracle, final_geo)   # oracle ha GSM che F1 non ha
cat(sprintf("  oracle A3 survivors: %d | F1 finale: %d\n",
            length(oracle), length(final_geo)))
cat(sprintf("  extra (F1 not oracle): %d  [atteso 0]\n", length(extra)))
cat(sprintf("  missing (oracle not F1): %d  [atteso 0 o 1=GSM3612196]\n",
            length(missing)))
if (length(missing) > 0L) cat("    missing GSM:", paste(missing, collapse = ", "), "\n")

# molecule_ch1 smoke 20 random
set.seed(42)
smp <- final_df[sample(nrow(final_df), 20L), c("geo_accession", "molecule_ch1")]
cat(sprintf("  molecule_ch1 non-NA su 20 random: %d/20\n", sum(!is.na(smp$molecule_ch1) & nzchar(smp$molecule_ch1))))

# Gate
ok <- length(extra) == 0L &&
      length(missing) <= 1L &&
      all(missing %in% "GSM3612196") &&
      nrow(final_df) %in% c(508037L, 508038L)
cat(sprintf("\n== F1 GATE: %s ==\n", if (ok) "PASS" else "FAIL"))
if (!ok) {
  stop("Sanity F1 FAIL: delta inatteso vs oracle A3. STOP investigation (vedi sopra).")
}
cat(sprintf("Bacino finale Stage 0 v2: %d sample\n", nrow(final_df)))
cat("F1 ETL re-run COMPLETE.\n")
