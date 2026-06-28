# analysis/p5-audit-chembl-build-dict.R
# Build dizionario ChEMBL nome->ID (clone di p5-audit-chebi-build-dict.R).
# Input:  dump SQLite ChEMBL estratto (env CHEMBL_SQLITE = path al .db).
# Output: cache/chembl/chembl-lookup.rds (by_id + aliases + meta).
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({ library(DBI); library(dplyr); library(cli) })

db_path <- Sys.getenv("CHEMBL_SQLITE", "")
stopifnot("env CHEMBL_SQLITE non impostata" = nzchar(db_path), file.exists(db_path))
out_dir <- file.path(tools::R_user_dir("simulomicsr","cache"), "chembl")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

cli_h1("ChEMBL lookup dictionary build")
con <- DBI::dbConnect(RSQLite::SQLite(), db_path)
on.exit(DBI::dbDisconnect(con), add = TRUE)

cli_alert_info("molecule_dictionary ...")
md <- DBI::dbGetQuery(con,
  "SELECT molregno, chembl_id, pref_name FROM molecule_dictionary WHERE pref_name IS NOT NULL")
cli_alert_success(sprintf("molecole con pref_name: %d", nrow(md)))

cli_alert_info("molecule_synonyms ...")
syn <- DBI::dbGetQuery(con,
  "SELECT molregno, synonyms, syn_type FROM molecule_synonyms WHERE synonyms IS NOT NULL")
cli_alert_success(sprintf("sinonimi grezzi: %d", nrow(syn)))

by_id <- md |>
  transmute(chembl_id = chembl_id, pref_name = pref_name) |>
  filter(!is.na(chembl_id), !is.na(pref_name)) |>
  distinct(chembl_id, .keep_all = TRUE)

mol2chembl <- md |> select(molregno, chembl_id)
# aliases = sinonimi + pref_name, lowercased, joinati su chembl_id
syn_al <- syn |>
  inner_join(mol2chembl, by = "molregno") |>
  transmute(alias_lower = tolower(trimws(synonyms)), chembl_id, type = syn_type)
pref_al <- by_id |>
  transmute(alias_lower = tolower(trimws(pref_name)), chembl_id, type = "PREF_NAME")
aliases <- bind_rows(pref_al, syn_al) |>
  filter(nzchar(alias_lower), !is.na(chembl_id)) |>
  distinct(alias_lower, chembl_id, .keep_all = TRUE)

meta <- list(
  chembl_release = basename(db_path),
  built_at = Sys.time(),
  n_molecules = nrow(by_id),
  n_synonyms = nrow(aliases),
  fixture_subset = FALSE
)
out <- file.path(out_dir, "chembl-lookup.rds")
saveRDS(list(by_id = by_id, aliases = aliases, meta = meta), out)
cli_alert_success(sprintf("scritto %s (by_id=%d, aliases=%d)", out, nrow(by_id), nrow(aliases)))
