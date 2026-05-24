# analysis/p5-audit-chebi-build-dict.R
#
# Build ChEBI lookup dictionary per validare gli agent_id LLM-emitted.
# Input:  cache/chebi/{compounds,names,relation,secondary_ids}.tsv.gz
# Output: cache/chebi/chebi-lookup.rds — lista con
#   - $by_id   tibble (id_int, primary_name, ascii_name, stars, definition)
#   - $aliases tibble (alias_lower, chebi_id)  # names.tsv tutti i synonyms+IUPAC
#   - $secondary tibble (secondary_id, primary_id)  # ID merged
#   - $is_a    tibble (id, parent_id)
#   - $has_role tibble (id, role_id, role_name)
#
# Razionale: ChEBI flat files richiedono parsing e join multipli; tenere tutto
# in RDS pre-parsed accelera lo scan (millisec lookup).

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(tibble); library(cli)
})

CHEBI_DIR <- file.path(tools::R_user_dir("simulomicsr","cache"), "chebi")
stopifnot(dir.exists(CHEBI_DIR))

cli_h1("ChEBI lookup dictionary build")

# ----------------- compounds.tsv (primary names + status) -----------------
cli_alert_info("Loading compounds.tsv.gz...")
compounds <- read_tsv(
  file.path(CHEBI_DIR, "compounds.tsv.gz"),
  col_types = cols(
    id = col_integer(),
    name = col_character(),
    status_id = col_integer(),
    source = col_character(),
    parent_id = col_integer(),
    merge_type = col_character(),
    chebi_accession = col_character(),
    definition = col_character(),
    ascii_name = col_character(),
    stars = col_integer(),
    modified_on = col_character(),
    release_date = col_character()
  ),
  quote = "", na = c("", "null")
)
cli_alert_success(sprintf("compounds rows: %d", nrow(compounds)))

# status_id 1=submitted, 2=preliminary, 3=checked. Tenere tutti.
# parent_id valorizzato = secondary ID che e' stato mergiato in parent_id
by_id <- compounds |>
  filter(!is.na(name) | !is.na(ascii_name)) |>
  transmute(
    chebi_id     = id,
    primary_name = coalesce(name, ascii_name),
    ascii_name,
    stars,
    definition,
    is_obsolete  = !is.na(parent_id),
    parent_id
  )
cli_alert_info(sprintf("by_id rows: %d (obsolete merged-in: %d)",
                       nrow(by_id), sum(by_id$is_obsolete, na.rm = TRUE)))

# ----------------- names.tsv (synonyms + IUPAC) -----------------
cli_alert_info("Loading names.tsv.gz...")
names_tbl <- read_tsv(
  file.path(CHEBI_DIR, "names.tsv.gz"),
  col_types = cols(
    id = col_integer(),
    compound_id = col_integer(),
    name = col_character(),
    type = col_character(),
    status_id = col_integer(),
    adapted = col_logical(),
    language_code = col_character(),
    ascii_name = col_character()
  ),
  quote = "", na = c("", "null")
)
cli_alert_info(sprintf("names rows: %d", nrow(names_tbl)))

aliases <- names_tbl |>
  filter(!is.na(name), nchar(name) > 0) |>
  transmute(
    alias_lower = tolower(name),
    chebi_id    = compound_id,
    type
  ) |>
  bind_rows(
    by_id |> transmute(alias_lower = tolower(primary_name), chebi_id, type = "PRIMARY")
  ) |>
  distinct(alias_lower, chebi_id, .keep_all = TRUE)
cli_alert_success(sprintf("aliases rows (unique alias_lower x chebi_id): %d", nrow(aliases)))

# ----------------- secondary_ids.tsv -----------------
cli_alert_info("Loading secondary_ids.tsv.gz...")
sec_tbl <- read_tsv(
  file.path(CHEBI_DIR, "secondary_ids.tsv.gz"),
  col_types = cols(compound_id = col_integer(), secondary_id = col_integer()),
  na = c("", "null")
)
secondary <- sec_tbl |>
  transmute(secondary_id, primary_id = compound_id)
cli_alert_success(sprintf("secondary rows: %d", nrow(secondary)))

# ----------------- relation.tsv (is_a + has_role) -----------------
cli_alert_info("Loading relation.tsv.gz...")
rel <- read_tsv(
  file.path(CHEBI_DIR, "relation.tsv.gz"),
  col_types = cols(
    id = col_integer(),
    relation_type_id = col_integer(),
    init_id = col_integer(),
    final_id = col_integer(),
    status_id = col_integer(),
    evidence_accession = col_character(),
    evidence_source_id = col_integer()
  )
)
# relation_type: 4=has_role, 5=is_a
is_a <- rel |>
  filter(relation_type_id == 5) |>
  transmute(chebi_id = init_id, parent_id = final_id)
has_role_rel <- rel |>
  filter(relation_type_id == 4) |>
  transmute(chebi_id = init_id, role_id = final_id)

# Annotare has_role con primary_name (role label legibile)
has_role <- has_role_rel |>
  left_join(by_id |> select(chebi_id, role_name = primary_name), by = c("role_id" = "chebi_id"))
cli_alert_success(sprintf("is_a rows: %d, has_role rows: %d (with name: %d)",
                          nrow(is_a), nrow(has_role), sum(!is.na(has_role$role_name))))

# ----------------- Salva dictionary -----------------
out <- list(
  by_id     = by_id,
  aliases   = aliases,
  secondary = secondary,
  is_a      = is_a,
  has_role  = has_role,
  meta = list(
    built_at = Sys.time(),
    chebi_release_dir = CHEBI_DIR,
    n_compounds = nrow(by_id),
    n_aliases   = nrow(aliases),
    n_secondary = nrow(secondary),
    n_is_a      = nrow(is_a),
    n_has_role  = nrow(has_role)
  )
)
out_path <- file.path(CHEBI_DIR, "chebi-lookup.rds")
saveRDS(out, out_path)
cli_alert_success(sprintf("Saved: %s (%.1f MB)", out_path, file.size(out_path)/1e6))

# Quick sanity check sui 5 ChEBI ID nei case study Layer B
cli_h2("Sanity check sui 5 ChEBI ID nei case study Layer B")
ids_to_check <- c(17126, 17199, 17236, 16236, 16236)
for (id in ids_to_check) {
  rec <- by_id |> filter(chebi_id == id)
  if (nrow(rec) == 0L) {
    cat(sprintf("  CHEBI:%d -> NOT FOUND\n", id)); next
  }
  cat(sprintf("  CHEBI:%d -> %s (stars=%s, obsolete=%s)\n",
              id, rec$primary_name[1L], rec$stars[1L], rec$is_obsolete[1L]))
  # roles
  roles <- has_role |> filter(chebi_id == id) |> pull(role_name) |> unique() |> head(8)
  if (length(roles) > 0L) {
    cat(sprintf("    roles: %s\n", paste(roles, collapse = " | ")))
  }
}
