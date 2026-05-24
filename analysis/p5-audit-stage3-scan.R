# analysis/p5-audit-stage3-scan.R
#
# Scan completo dei 267k cluster Stage 3 per validare gli agent_id LLM-emitted
# contro i vocabolari controllati ChEBI, HGNC, MeSH.
#
# Classificazione per ogni agent_id:
#   - PATH 1 numerico puro (es. "17126", "10000")     -> id e' nel campo id
#                                                        ma id_database ignoto:
#                                                        ambiguous, prova ChEBI+HGNC+MeSH lookup
#   - PATH 2 <DB>:<number> field-swap                  -> preferred_name = number
#                                                        DB esplicito, lookup ChEBI/HGNC/MeSH
#   - PATH 3 <DB>:<word>                               -> raro (normale), lookup nome
#   - PATH 4 stringa nome libero (es. "Resiquimod")    -> lookup alias ChEBI/HGNC
#   - PATH 5 unknown                                   -> skip
#
# Esito per ogni ID:
#   - VALID_PRIMARY      ID esiste come primary in vocabolario corretto
#   - VALID_SECONDARY    ID esiste ma e' secondary (mergiato in un altro)
#   - VALID_WRONG_DB     ID esiste ma in vocabolario diverso da quello dichiarato
#                        (es. "MeSH:17126" dove 17126 esiste come ChEBI ID)
#   - HALLUCINATED       ID non trovato in nessun vocabolario
#   - SKIP_STRING        agent e' stringa, gestito via alias_lower
#
# Output: analysis/p4-output/p5-audit-agent-id-validation.rds + .csv summary

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(dplyr); library(tibble); library(cli); library(stringr)
  devtools::load_all(".", quiet = TRUE)
})

CACHE <- tools::R_user_dir("simulomicsr","cache")
chebi <- readRDS(file.path(CACHE, "chebi", "chebi-lookup.rds"))
hgnc  <- readRDS(file.path(CACHE, "hgnc-lookup.rds"))
mesh  <- readRDS(file.path(CACHE, "mesh-lookup.rds"))

cli_h1("Stage 3 agent_id LLM validation scan")

s3 <- load_stage3("analysis/p4-output/20260519T055547Z-stage3-2153addc")
parsed <- Map(extract_anchor_summary, s3$clusters$anchor_key, s3$clusters$level, s3$clusters$mode)
agent_ids <- vapply(parsed, function(x) x$agent_id, character(1L))
kind_effs <- vapply(parsed, function(x) x$kind_effective, character(1L))

cli_alert_info(sprintf("Total Stage 3 cluster: %d", length(agent_ids)))

# ----------------- Pattern classification -----------------
DB_LIST <- c("CHEBI","HGNC","MGI","UniProt","DrugBank","ChEMBL","MeSH",
             "CAS","Cellosaurus","Ensembl","NCBITaxonomy")
DB_RE_NUM  <- sprintf("^(%s):([0-9]+)$",  paste(DB_LIST, collapse="|"))
DB_RE_WORD <- sprintf("^(%s):([A-Za-z][A-Za-z0-9 -]*)$", paste(DB_LIST, collapse="|"))

m_num   <- str_match(agent_ids, DB_RE_NUM)
m_word  <- str_match(agent_ids, DB_RE_WORD)
is_num  <- !is.na(m_num[, 1L])
is_word <- !is.na(m_word[, 1L])
is_pure_num <- grepl("^[0-9]+$", agent_ids)
is_unknown <- agent_ids == "unknown" | nchar(agent_ids) == 0L
# Special: "D" + numbers (MeSH style sans-prefix)
is_mesh_naked <- grepl("^[CD][0-9]{6}$", agent_ids)

# Anche "CHEMBLNNNN" (no colon)
is_chembl_naked <- grepl("^CHEMBL[0-9]+$", agent_ids)

# Tutto il resto = stringa nome
is_string <- !is_num & !is_word & !is_pure_num & !is_unknown & !is_mesh_naked & !is_chembl_naked

cli_alert_info(sprintf("PATH 2 <DB>:<num> field-swap:   %d", sum(is_num)))
cli_alert_info(sprintf("PATH 3 <DB>:<word>:             %d", sum(is_word)))
cli_alert_info(sprintf("PATH 1 numerico puro:           %d", sum(is_pure_num)))
cli_alert_info(sprintf("PATH 4 MeSH naked Dxxxxxx:      %d", sum(is_mesh_naked)))
cli_alert_info(sprintf("PATH 4 ChEMBL naked:            %d", sum(is_chembl_naked)))
cli_alert_info(sprintf("PATH 4 stringa nome:            %d", sum(is_string)))
cli_alert_info(sprintf("PATH 5 unknown/empty:           %d", sum(is_unknown)))

# ----------------- Validation per pattern -----------------

# Helper: cerca numero in ChEBI/HGNC/MeSH/Entrez
lookup_chebi_by_int <- function(ids) {
  primary  <- chebi$by_id$chebi_id
  sec      <- chebi$secondary$secondary_id
  is_p <- ids %in% primary
  is_s <- ids %in% sec
  case_when(is_p ~ "PRIMARY", is_s ~ "SECONDARY", TRUE ~ "NOT_FOUND")
}
lookup_hgnc_by_int <- function(ids) {
  ifelse(ids %in% hgnc$by_hgnc_int$hgnc_int, "PRIMARY", "NOT_FOUND")
}
lookup_entrez_by_int <- function(ids) {
  ifelse(ids %in% hgnc$by_entrez_int$entrez_int, "PRIMARY_ENTREZ", "NOT_FOUND")
}
lookup_mesh_by_ui <- function(uis) {
  ifelse(uis %in% mesh$by_ui$ui, "PRIMARY", "NOT_FOUND")
}

# ----- PATH 2: <DB>:<num> -----
df_num <- tibble(
  idx = which(is_num),
  agent_id = agent_ids[is_num],
  db = m_num[is_num, 2L],
  num_str = m_num[is_num, 3L]
) |>
  mutate(num_int = suppressWarnings(as.integer(num_str)))

# Per ogni DB, valida con vocabolario corretto + cross-check
df_num <- df_num |>
  mutate(
    ck_chebi_primary   = lookup_chebi_by_int(num_int),
    ck_hgnc_primary    = lookup_hgnc_by_int(num_int),
    ck_entrez_primary  = lookup_entrez_by_int(num_int),
    ck_mesh_naked      = lookup_mesh_by_ui(paste0("D", num_str))
  )

resolve_validation <- function(db, ck_chebi, ck_hgnc, ck_entrez, ck_mesh) {
  # Validity vs declared DB
  declared_valid <- dplyr::case_when(
    db == "CHEBI"       & ck_chebi   %in% c("PRIMARY","SECONDARY") ~ "VALID_PRIMARY",
    db == "HGNC"        & ck_hgnc    == "PRIMARY"                  ~ "VALID_PRIMARY",
    db == "MeSH"        & ck_mesh    == "PRIMARY"                  ~ "VALID_PRIMARY",
    TRUE                                                            ~ "NOT_VALID"
  )
  # Recovery se il vero DB e' un altro
  recovered <- dplyr::case_when(
    declared_valid != "NOT_VALID"                ~ NA_character_,
    ck_chebi  %in% c("PRIMARY","SECONDARY")      ~ "CHEBI",
    ck_hgnc   == "PRIMARY"                       ~ "HGNC",
    ck_entrez == "PRIMARY_ENTREZ"                ~ "ENTREZ_via_HGNC",
    ck_mesh   == "PRIMARY"                       ~ "MeSH",
    TRUE                                          ~ NA_character_
  )
  tibble(validation = declared_valid, recovered_db = recovered)
}
df_num <- bind_cols(
  df_num,
  resolve_validation(df_num$db, df_num$ck_chebi_primary, df_num$ck_hgnc_primary,
                     df_num$ck_entrez_primary, df_num$ck_mesh_naked)
)

# Resolve to canonical name when valid
chebi_name_by_int <- chebi$by_id |> select(chebi_id, primary_name)
hgnc_name_by_int  <- hgnc$by_hgnc_int |> select(hgnc_int, symbol, name)
mesh_name_by_ui   <- mesh$by_ui |> select(ui, mh)
entrez_name_by_int <- hgnc$by_entrez_int |> select(entrez_int, symbol, name)

df_num <- df_num |>
  left_join(chebi_name_by_int |> rename(chebi_name = primary_name), by = c("num_int" = "chebi_id")) |>
  left_join(hgnc_name_by_int  |> rename(hgnc_sym = symbol, hgnc_name = name), by = c("num_int" = "hgnc_int")) |>
  left_join(entrez_name_by_int |> rename(entrez_sym = symbol, entrez_name = name), by = c("num_int" = "entrez_int")) |>
  left_join(mesh_name_by_ui  |> rename(mesh_name = mh), by = c("ck_mesh_naked" = "ui"))

# ----- PATH 1: numerico puro -----
df_purenum <- tibble(
  idx = which(is_pure_num),
  agent_id = agent_ids[is_pure_num]
) |>
  mutate(
    num_int = suppressWarnings(as.integer(agent_id)),
    ck_chebi  = lookup_chebi_by_int(num_int),
    ck_hgnc   = lookup_hgnc_by_int(num_int),
    ck_entrez = lookup_entrez_by_int(num_int),
    ck_mesh   = lookup_mesh_by_ui(paste0("D", agent_id))
  ) |>
  left_join(chebi_name_by_int |> rename(chebi_name = primary_name), by = c("num_int" = "chebi_id")) |>
  left_join(hgnc_name_by_int  |> rename(hgnc_sym = symbol, hgnc_name = name), by = c("num_int" = "hgnc_int")) |>
  left_join(entrez_name_by_int |> rename(entrez_sym = symbol, entrez_name = name), by = c("num_int" = "entrez_int")) |>
  mutate(
    resolved_db = dplyr::case_when(
      ck_chebi  %in% c("PRIMARY","SECONDARY") ~ "CHEBI",
      ck_hgnc   == "PRIMARY"                  ~ "HGNC",
      ck_entrez == "PRIMARY_ENTREZ"           ~ "ENTREZ_via_HGNC",
      ck_mesh   == "PRIMARY"                  ~ "MeSH",
      TRUE                                     ~ NA_character_
    )
  )

# ----- PATH 4: MeSH naked Dxxxxxx -----
df_mesh_naked <- tibble(
  idx = which(is_mesh_naked),
  agent_id = agent_ids[is_mesh_naked]
) |>
  mutate(
    ck = lookup_mesh_by_ui(agent_id)
  ) |>
  left_join(mesh_name_by_ui |> rename(mesh_name = mh), by = c("agent_id" = "ui"))

# ----- PATH 4: stringa nome -> lookup alias -----
# Tronchiamo a primo 30 char per perf, lookup case-insensitive
df_string <- tibble(
  idx = which(is_string),
  agent_id = agent_ids[is_string],
  agent_lower = tolower(agent_ids[is_string])
)
# Match a ChEBI aliases (prima IUPAC NAME poi PRIMARY o SYNONYM)
chebi_alias_first <- chebi$aliases |>
  group_by(alias_lower) |>
  slice_head(n = 1L) |>
  ungroup()
df_string <- df_string |>
  left_join(chebi_alias_first |> rename(chebi_match_id = chebi_id, chebi_match_type = type),
            by = c("agent_lower" = "alias_lower")) |>
  left_join(hgnc$by_symbol_lower |> select(symbol_lower, hgnc_int_match = hgnc_int, hgnc_sym_match = symbol),
            by = c("agent_lower" = "symbol_lower")) |>
  left_join(mesh$by_entry_lower |> rename(mesh_ui_match = ui),
            by = c("agent_lower" = "entry_lower"))

# ----------------- Summary tables -----------------
cli_h2("Summary PATH 2 (<DB>:<num> field-swap)")
sum_path2 <- df_num |>
  group_by(db, validation) |>
  summarise(n = n(), .groups = "drop") |>
  arrange(db, validation)
print(sum_path2, n = 50)

cli_h2("Recovery: dove sono finiti gli ID NOT_VALID?")
sum_recovery <- df_num |>
  filter(validation == "NOT_VALID") |>
  group_by(db, recovered_db) |>
  summarise(n = n(), .groups = "drop") |>
  arrange(db, desc(n))
print(sum_recovery, n = 50)

cli_h2("Summary PATH 1 (numerico puro)")
sum_path1 <- df_purenum |>
  group_by(resolved_db) |>
  summarise(n = n(), .groups = "drop") |>
  arrange(desc(n))
print(sum_path1)

cli_h2("Summary PATH 4 MeSH naked")
sum_mesh_naked <- df_mesh_naked |>
  group_by(ck) |>
  summarise(n = n(), .groups = "drop") |>
  arrange(desc(n))
print(sum_mesh_naked)

cli_h2("Summary PATH 4 stringa nome (ChEBI/HGNC/MeSH alias hit)")
sum_string <- df_string |>
  summarise(
    n_total                = n(),
    n_chebi_alias_hit      = sum(!is.na(chebi_match_id)),
    n_hgnc_symbol_hit      = sum(!is.na(hgnc_int_match)),
    n_mesh_entry_hit       = sum(!is.na(mesh_ui_match)),
    n_no_match             = sum(is.na(chebi_match_id) & is.na(hgnc_int_match) & is.na(mesh_ui_match))
  )
print(sum_string, width = Inf)

# ----------------- Persist tutto -----------------
out <- list(
  meta = list(
    built_at = Sys.time(),
    n_total_stage3 = length(agent_ids),
    counts = list(
      path1_numeric = sum(is_pure_num),
      path2_db_num  = sum(is_num),
      path3_db_word = sum(is_word),
      path4_mesh_naked  = sum(is_mesh_naked),
      path4_chembl_naked = sum(is_chembl_naked),
      path4_string  = sum(is_string),
      path5_unknown = sum(is_unknown)
    )
  ),
  df_num         = df_num,
  df_purenum     = df_purenum,
  df_mesh_naked  = df_mesh_naked,
  df_string      = df_string,
  agent_ids      = agent_ids,
  kind_effs      = kind_effs,
  cluster_meta   = s3$clusters |> select(cluster_id, mode, level, n_studies, anchor_key)
)
saveRDS(out, "analysis/p4-output/p5-audit-agent-id-validation.rds")
cli_alert_success("Saved analysis/p4-output/p5-audit-agent-id-validation.rds")
