# analysis/p5-audit-hgnc-mesh-build-dict.R
#
# Build HGNC + MeSH lookup dictionaries.
# Output:
#   - cache/hgnc-lookup.rds   {by_hgnc_int, by_symbol_lower, by_entrez_int}
#   - cache/mesh-lookup.rds   {by_ui, by_term_lower, tree_branches}

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tibble); library(cli); library(stringr)
})

CACHE <- tools::R_user_dir("simulomicsr","cache")
HGNC_PATH <- file.path(CACHE, "hgnc_complete_set.tsv")
MESH_PATH <- file.path(CACHE, "mesh", "d2025.bin")

cli_h1("HGNC + MeSH lookup build")

# ----------------- HGNC -----------------
cli_alert_info("Loading HGNC complete set...")
hgnc <- read_tsv(
  HGNC_PATH,
  col_types = cols(.default = col_character()),
  na = c("", "NA"),
  guess_max = 50000
)
cli_alert_info(sprintf("HGNC rows: %d, cols: %d", nrow(hgnc), ncol(hgnc)))

# Estrai hgnc_id integer da "HGNC:NNNN"
hgnc$hgnc_int <- as.integer(sub("^HGNC:", "", hgnc$hgnc_id))
hgnc$entrez_int <- suppressWarnings(as.integer(hgnc$entrez_id))

by_hgnc_int <- hgnc |>
  filter(!is.na(hgnc_int)) |>
  transmute(
    hgnc_int, hgnc_id, symbol, name,
    locus_group, locus_type, status,
    entrez_int, ensembl_gene_id
  )
cli_alert_success(sprintf("by_hgnc_int rows: %d", nrow(by_hgnc_int)))

by_symbol_lower <- hgnc |>
  filter(!is.na(symbol)) |>
  transmute(symbol_lower = tolower(symbol), hgnc_int, symbol, name) |>
  distinct(symbol_lower, .keep_all = TRUE)

# Alias + previous symbols (delimited by "|")
aliases_long <- hgnc |>
  filter(!is.na(alias_symbol) | !is.na(prev_symbol)) |>
  transmute(
    hgnc_int,
    symbol,
    alias_blob = paste(coalesce(alias_symbol, ""), coalesce(prev_symbol, ""), sep = "|")
  ) |>
  tidyr::separate_longer_delim(alias_blob, delim = "|") |>
  filter(alias_blob != "") |>
  transmute(alias_lower = tolower(alias_blob), hgnc_int, primary_symbol = symbol) |>
  distinct(alias_lower, hgnc_int, .keep_all = TRUE)
cli_alert_info(sprintf("aliases_long rows: %d", nrow(aliases_long)))

by_entrez_int <- hgnc |>
  filter(!is.na(entrez_int)) |>
  transmute(entrez_int, hgnc_int, symbol, name)
cli_alert_info(sprintf("by_entrez_int rows: %d", nrow(by_entrez_int)))

hgnc_out <- list(
  by_hgnc_int     = by_hgnc_int,
  by_symbol_lower = by_symbol_lower,
  by_entrez_int   = by_entrez_int,
  aliases_long    = aliases_long
)
saveRDS(hgnc_out, file.path(CACHE, "hgnc-lookup.rds"))
cli_alert_success("Saved hgnc-lookup.rds")

# ----------------- MeSH ASCII parser -----------------
cli_alert_info("Parsing MeSH ASCII d2025.bin...")
lines <- readLines(MESH_PATH, warn = FALSE, encoding = "UTF-8")
cli_alert_info(sprintf("MeSH lines: %d", length(lines)))

# Trovo i record. Ogni record inizia con "*NEWRECORD" e contiene linee "KEY = VALUE"
record_starts <- which(lines == "*NEWRECORD")
cli_alert_info(sprintf("MeSH records detected: %d", length(record_starts)))

# Parsa fields: MH (MeSH heading), UI (Unique Identifier), MN (TreeNumber, multi)
parse_record <- function(blk) {
  # blk: vector di linee
  ui <- NA_character_; mh <- NA_character_; mn <- character(0)
  entries <- character(0)
  for (ln in blk) {
    if (startsWith(ln, "UI = ")) ui <- sub("^UI = ", "", ln)
    else if (startsWith(ln, "MH = ")) mh <- sub("^MH = ", "", ln)
    else if (startsWith(ln, "MN = ")) mn <- c(mn, sub("^MN = ", "", ln))
    else if (startsWith(ln, "ENTRY = ")) entries <- c(entries, sub("^ENTRY = ", "", ln))
    else if (startsWith(ln, "PRINT ENTRY = ")) entries <- c(entries, sub("^PRINT ENTRY = ", "", ln))
  }
  list(ui = ui, mh = mh, mn = mn, entries = entries)
}

# Costruisci blocchi
record_ends <- c(record_starts[-1] - 1L, length(lines))
records <- vector("list", length(record_starts))
for (i in seq_along(record_starts)) {
  records[[i]] <- parse_record(lines[record_starts[i]:record_ends[i]])
}

by_ui <- tibble(
  ui = vapply(records, function(r) r$ui %||% NA_character_, character(1L)),
  mh = vapply(records, function(r) r$mh %||% NA_character_, character(1L)),
  tree_top = vapply(records, function(r) {
    if (length(r$mn) == 0L) NA_character_ else substr(r$mn[1L], 1L, 1L)
  }, character(1L)),
  tree_branches = vapply(records, function(r) {
    if (length(r$mn) == 0L) NA_character_ else paste(r$mn, collapse = ";")
  }, character(1L))
) |> filter(!is.na(ui))

cli_alert_info(sprintf("by_ui rows: %d", nrow(by_ui)))

# Entry terms (synonyms)
entry_long <- do.call(rbind, lapply(records, function(r) {
  if (is.null(r$entries) || length(r$entries) == 0L) return(NULL)
  data.frame(ui = r$ui, entry = r$entries, stringsAsFactors = FALSE)
}))
by_entry_lower <- as_tibble(entry_long) |>
  mutate(
    # remove "|...|" qualifiers appended after the term
    term = sub("\\|.*$", "", entry),
    entry_lower = tolower(term)
  ) |>
  distinct(entry_lower, ui, .keep_all = FALSE)
cli_alert_info(sprintf("by_entry_lower rows: %d", nrow(by_entry_lower)))

mesh_out <- list(
  by_ui          = by_ui,
  by_entry_lower = by_entry_lower
)
saveRDS(mesh_out, file.path(CACHE, "mesh-lookup.rds"))
cli_alert_success("Saved mesh-lookup.rds")

# Sanity check: D011279 (Prostatic Neoplasms) e D001943 (visto nel scan top-30)
cli_h2("Sanity check MeSH descriptors")
for (id in c("D011279", "D001943", "D000123", "D012345")) {
  rec <- by_ui |> filter(ui == id)
  if (nrow(rec) == 0L) {
    cat(sprintf("  %s -> NOT FOUND in MeSH 2025\n", id))
  } else {
    cat(sprintf("  %s -> '%s' (tree_top=%s, branches=%s)\n",
                id, rec$mh[1L], rec$tree_top[1L], rec$tree_branches[1L]))
  }
}
