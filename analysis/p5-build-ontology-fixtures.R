#!/usr/bin/env Rscript
# p5-build-ontology-fixtures.R --- One-off: estrae mini-fixtures dalle 3
# dictionary ChEBI/HGNC/MeSH per i test TDD del resolver R/ontology-lookup.R.
#
# Output: inst/extdata/ontology-fixtures-mini/{chebi,hgnc,mesh}-mini.rds
# Ciascun RDS ha la stessa struttura dei full-dict (in modo che il loader
# .load_ontology_dicts() possa caricare indifferentemente fixtures o full).
#
# Selezione (paper-grade audit 2026-05-24):
#  - ChEBI (~13 compounds): Carnitine, Ethanol, DMSO, Resiquimod, Imiquimod,
#    poly(I:C), Doxorubicin, Heparin, Stearic acid, L-isoleucine,
#    4,5-dihydroxyphthalate, hydroxy-oxo-hexadiene (i due LLM-oscure),
#    (-)-epicatechin (target di secondary 18484->90), LPS.
#  - HGNC (~10 genes): TP53, VEGFA, EGFR, AKT3, FTO, IFNB1, IL6 (+aliases),
#    MYC, TLR3, TLR7. Include entrez_id per testare HGNC_ENTREZ_MAPPED.
#  - MeSH (~5 descriptors): Pregnanetriol (D011279, tree D chemicals),
#    Prostatic Neoplasms (D011471, tree C diseases), Interferon-beta
#    (D016899), Biomarkers (D015415), TOR Serine-Threonine Kinases (D058570).
#
# Run: Rscript --vanilla analysis/p5-build-ontology-fixtures.R
# Wall: <5 sec.

suppressMessages({
  library(dplyr)
})

# --- Setup paths -------------------------------------------------------------

cache_dir <- tools::R_user_dir("simulomicsr", which = "cache")
out_dir   <- "inst/extdata/ontology-fixtures-mini"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- Load full dictionaries ---------------------------------------------------

chebi_full <- readRDS(file.path(cache_dir, "chebi", "chebi-lookup.rds"))
hgnc_full  <- readRDS(file.path(cache_dir, "hgnc-lookup.rds"))
mesh_full  <- readRDS(file.path(cache_dir, "mesh-lookup.rds"))

# --- ChEBI mini ---------------------------------------------------------------

chebi_ids <- c(
  17126,   # carnitine (human metabolite WEAK -- contradicts pathogen LLM)
  16236,   # ethanol (polar solvent STRONG -- vehicle_only)
  28262,   # DMSO (polar aprotic solvent STRONG -- vehicle_only)
  36706,   # resiquimod (0 roles -- NONE, LLM preserved)
  36704,   # imiquimod (interferon inducer STRONG -- cytokine_stim)
  84491,   # poly(I:C) (immunological adjuvant STRONG -- pathogen)
  28748,   # doxorubicin (e. coli metabolite WEAK)
  28304,   # heparin
  28842,   # octadecanoic acid (stearic)
  17191,   # L-isoleucine (amino acid metabolite WEAK)
  17199,   # 4,5-dihydroxyphthalate (LLM-oscure, expected 0 roles)
  17236,   # 2-hydroxy-6-oxohexadiene... (LLM-oscure, expected 0 roles)
  90,      # (-)-epicatechin (primary di secondary_id 18484)
  16412    # lipopolysaccharide LPS
)

chebi_mini <- list(
  by_id     = chebi_full$by_id     |> filter(.data$chebi_id %in% chebi_ids),
  aliases   = chebi_full$aliases   |> filter(.data$chebi_id %in% chebi_ids),
  secondary = chebi_full$secondary |> filter(.data$primary_id %in% chebi_ids),
  is_a      = chebi_full$is_a      |> filter(.data$chebi_id %in% chebi_ids),
  has_role  = chebi_full$has_role  |> filter(.data$chebi_id %in% chebi_ids),
  meta      = list(
    built_at          = chebi_full$meta$built_at,
    chebi_release_dir = chebi_full$meta$chebi_release_dir,
    n_compounds       = nrow(chebi_full$by_id),
    n_aliases         = nrow(chebi_full$aliases),
    n_secondary       = nrow(chebi_full$secondary),
    n_is_a            = nrow(chebi_full$is_a),
    n_has_role        = nrow(chebi_full$has_role),
    fixture_subset    = TRUE,
    fixture_n_compounds = length(chebi_ids)
  )
)

cat(sprintf(
  "ChEBI mini: %d compounds, %d aliases, %d secondary, %d has_role rows\n",
  nrow(chebi_mini$by_id), nrow(chebi_mini$aliases),
  nrow(chebi_mini$secondary), nrow(chebi_mini$has_role)
))

# --- HGNC mini ---------------------------------------------------------------

hgnc_ids <- c(
  11998,   # TP53 (entrez 7157)
  12680,   # VEGFA (entrez 7422)
  3236,    # EGFR (entrez 1956)
  393,     # AKT3 (entrez 10000)
  24678,   # FTO (entrez 79068)
  5434,    # IFNB1 (entrez 3456)
  6018,    # IL6 (entrez 3569 + aliases: il-6, bsf2, hgf, hsf, ifnb2)
  7553,    # MYC (entrez 4609)
  11849,   # TLR3 (entrez 7098)
  15631    # TLR7 (entrez 51284)
)

hgnc_mini <- list(
  by_hgnc_int     = hgnc_full$by_hgnc_int     |> filter(.data$hgnc_int %in% hgnc_ids),
  by_symbol_lower = hgnc_full$by_symbol_lower |> filter(.data$hgnc_int %in% hgnc_ids),
  by_entrez_int   = hgnc_full$by_entrez_int   |> filter(.data$hgnc_int %in% hgnc_ids),
  aliases_long    = hgnc_full$aliases_long    |> filter(.data$hgnc_int %in% hgnc_ids)
)

cat(sprintf(
  "HGNC mini: %d genes, %d symbol_lower, %d by_entrez, %d aliases\n",
  nrow(hgnc_mini$by_hgnc_int), nrow(hgnc_mini$by_symbol_lower),
  nrow(hgnc_mini$by_entrez_int), nrow(hgnc_mini$aliases_long)
))

# --- MeSH mini ---------------------------------------------------------------

mesh_uis <- c(
  "D011279",   # Pregnanetriol (tree D chemicals)
  "D011471",   # Prostatic Neoplasms (tree C diseases)
  "D016899",   # Interferon-beta (tree D)
  "D015415",   # Biomarkers (tree D)
  "D058570"    # TOR Serine-Threonine Kinases (tree D)
)

mesh_mini <- list(
  by_ui          = mesh_full$by_ui          |> filter(.data$ui %in% mesh_uis),
  by_entry_lower = mesh_full$by_entry_lower |> filter(.data$ui %in% mesh_uis)
)

cat(sprintf(
  "MeSH mini: %d descriptors, %d entry_lower\n",
  nrow(mesh_mini$by_ui), nrow(mesh_mini$by_entry_lower)
))

# --- Save fixtures -----------------------------------------------------------

saveRDS(chebi_mini, file.path(out_dir, "chebi-mini.rds"))
saveRDS(hgnc_mini,  file.path(out_dir, "hgnc-mini.rds"))
saveRDS(mesh_mini,  file.path(out_dir, "mesh-mini.rds"))

# --- Size report --------------------------------------------------------------

for (f in c("chebi-mini.rds", "hgnc-mini.rds", "mesh-mini.rds")) {
  fpath <- file.path(out_dir, f)
  size_kb <- file.info(fpath)$size / 1024
  cat(sprintf("Wrote %s (%.1f KB)\n", fpath, size_kb))
}

invisible(NULL)
