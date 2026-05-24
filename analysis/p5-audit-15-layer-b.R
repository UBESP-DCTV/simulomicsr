# analysis/p5-audit-15-layer-b.R
#
# Audit specifico dei 15 case study Layer B selezionati:
# - Risolvi canonical agent_id (ChEBI/HGNC/MeSH lookup)
# - Identifica casi di field-swap LLM, hallucination, kind mismatch
# - Output: tabella decisione-ready paper-grade

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(dplyr); library(tibble); library(cli); library(stringr); library(readr)
  devtools::load_all(".", quiet = TRUE)
})

CACHE <- tools::R_user_dir("simulomicsr","cache")
chebi <- readRDS(file.path(CACHE, "chebi", "chebi-lookup.rds"))
hgnc  <- readRDS(file.path(CACHE, "hgnc-lookup.rds"))
mesh  <- readRDS(file.path(CACHE, "mesh-lookup.rds"))
fr    <- readRDS("analysis/p4-output/p5-audit-fragmentation.rds")

cli_h1("Audit 15 case study Layer B")

sel <- read_csv("analysis/layer-b-selection.csv", show_col_types = FALSE)
audit_tbl <- fr$fragmentation_tbl |> filter(cluster_id %in% sel$cluster_id)
audit_tbl <- sel |>
  select(cluster_id, label_paper_orig = label_paper, priority, notes) |>
  inner_join(audit_tbl, by = "cluster_id")
cli_alert_info(sprintf("Audit tbl rows: %d, cols: %s", nrow(audit_tbl),
                       paste(colnames(audit_tbl), collapse=", ")))

# Per ogni cluster, costruisci righe annotate
resolve_one <- function(row) {
  ag   <- row$agent_id
  can  <- row[["canonical"]]
  kind <- row$kind_eff

  compound_name <- NA_character_
  compound_roles <- NA_character_
  llm_id_status <- NA_character_   # CORRECT_FIELD / FIELD_SWAP / HALLUCINATED / NAME_MATCH / STRING_ONLY
  expected_db   <- NA_character_
  resolved_db   <- NA_character_

  if (grepl("^CHEBI:[0-9]+$", can)) {
    chebi_int <- as.integer(sub("^CHEBI:", "", can))
    rec <- chebi$by_id |> filter(chebi_id == chebi_int)
    if (nrow(rec) > 0L) {
      compound_name <- rec$primary_name[1L]
      roles <- chebi$has_role |> filter(chebi_id == chebi_int) |> pull(role_name) |> unique()
      compound_roles <- if (length(roles)) paste(roles, collapse = "|") else ""
      llm_id_status <- if (grepl("^CHEBI:[0-9]+$", ag)) "FIELD_SWAP_LLM" else
        if (grepl("^[0-9]+$", ag)) "CORRECT_FIELD" else
        if (ag == compound_name || tolower(ag) == tolower(compound_name)) "NAME_MATCH" else "STRING_ALIAS"
      resolved_db <- "CHEBI"
    } else {
      llm_id_status <- "HALLUCINATED"
    }
  } else if (grepl("^HGNC:[0-9]+$", can)) {
    h_int <- as.integer(sub("^HGNC:", "", can))
    rec <- hgnc$by_hgnc_int |> filter(hgnc_int == h_int)
    if (nrow(rec) > 0L) {
      compound_name <- sprintf("%s [%s]", rec$symbol[1L], rec$name[1L])
      compound_roles <- sprintf("HGNC locus_group=%s", rec$locus_group[1L])
      llm_id_status <- if (grepl("^HGNC:[0-9]+$", ag)) "FIELD_SWAP_LLM" else "CORRECT_FIELD"
      resolved_db <- "HGNC"
    }
  } else if (grepl("^MeSH:", can)) {
    ui <- sub("^MeSH:", "", can)
    rec <- mesh$by_ui |> filter(ui == !!ui)
    if (nrow(rec) > 0L) {
      compound_name <- rec$mh[1L]
      compound_roles <- sprintf("MeSH tree=%s", rec$tree_branches[1L])
      llm_id_status <- "CORRECT_FIELD"
      resolved_db <- "MeSH"
    }
  } else if (grepl("^STR:", can)) {
    compound_name <- sub("^STR:", "", can)
    llm_id_status <- "STRING_ONLY"
    resolved_db <- "STRING"
  } else if (grepl("^HALLUC", can)) {
    llm_id_status <- "HALLUCINATED"
  } else {
    llm_id_status <- "UNKNOWN"
  }

  # Kind validation (post-hoc ChEBI roles)
  kind_valid <- NA_character_
  if (!is.na(resolved_db) && resolved_db == "CHEBI" && !is.na(compound_roles) && compound_roles != "") {
    if (kind == "cytokine_stim") {
      hit <- grepl("\\bcytokine\\b|interleukin|interferon|chemokine|\\bgrowth factor\\b|signaling",
                   compound_roles, ignore.case = TRUE)
      kind_valid <- if (hit) "OK" else "WRONG"
    } else if (kind == "pathogen_or_aggregate_exposure") {
      hit <- grepl("toxin|antibiotic|lipopolysaccharide|bacterial|viral|virus|venom|pathogen|adjuvant|TLR",
                   compound_roles, ignore.case = TRUE)
      kind_valid <- if (hit) "OK" else "WRONG"
    } else if (kind == "vehicle_only") {
      hit <- grepl("solvent|\\bvehicle\\b", compound_roles, ignore.case = TRUE)
      kind_valid <- if (hit) "OK" else "WRONG"
    } else if (kind == "small_molecule") {
      kind_valid <- "ACCEPT_ANY"
    } else if (kind == "none") {
      kind_valid <- "SKIP_NONE"
    } else {
      kind_valid <- "SKIP_OTHER"
    }
  } else if (!is.na(resolved_db) && resolved_db == "CHEBI") {
    kind_valid <- "NO_ROLES_TO_VALIDATE"
  } else {
    kind_valid <- "NO_CHEBI_RESOLVED"
  }

  tibble(
    cluster_id     = row$cluster_id,
    agent_id_raw   = ag,
    canonical      = can,
    compound_name  = compound_name,
    resolved_db    = resolved_db,
    llm_id_status  = llm_id_status,
    kind_eff       = kind,
    kind_valid     = kind_valid,
    compound_roles_short = if (!is.na(compound_roles)) substr(compound_roles, 1L, 200L) else NA_character_
  )
}

audit_out <- do.call(rbind, lapply(seq_len(nrow(audit_tbl)), function(i) {
  resolve_one(audit_tbl[i, ])
}))

# Aggiungi priority + label paper proposto
audit_out <- audit_out |>
  left_join(audit_tbl |> select(cluster_id, mode, level, n_studies, priority, label_paper_orig),
            by = "cluster_id") |>
  arrange(desc(priority == 1), kind_valid != "OK", cluster_id) |>
  mutate(
    label_paper_corrected = case_when(
      resolved_db == "CHEBI" & !is.na(compound_name) ~ sprintf("%s (%s)", compound_name, canonical),
      resolved_db == "HGNC"  & !is.na(compound_name) ~ compound_name,
      resolved_db == "MeSH"  & !is.na(compound_name) ~ sprintf("%s (%s)", compound_name, canonical),
      resolved_db == "STRING"                        ~ compound_name,
      TRUE                                           ~ "UNRESOLVED"
    )
  )

cli_h2("AUDIT 15 CASE STUDY")
print(audit_out |>
        select(cluster_id, label_paper_orig, label_paper_corrected, llm_id_status,
               kind_eff, kind_valid, compound_roles_short),
      n = 30, width = Inf)

write_csv(audit_out, "analysis/p4-output/p5-audit-15-layer-b.csv")
saveRDS(audit_out, "analysis/p4-output/p5-audit-15-layer-b.rds")
cli_alert_success("Saved analysis/p4-output/p5-audit-15-layer-b.csv")

# Summary
cli_h2("Summary 15 case study")
print(audit_out |> count(llm_id_status))
print(audit_out |> count(kind_valid))
