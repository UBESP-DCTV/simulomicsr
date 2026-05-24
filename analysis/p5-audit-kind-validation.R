# analysis/p5-audit-kind-validation.R
#
# Cross-check kind_effective (LLM-classified) vs ChEBI ontology (has_role) per
# i cluster con agent_id risolto a ChEBI ID valido.
#
# Mapping ground-truth (ChEBI role keyword presence in role_name):
#   - cytokine_stim                  -> {cytokine, interleukin, interferon, chemokine, "growth factor"}
#   - small_molecule                 -> [accept any ChEBI compound]
#   - pathogen_or_aggregate_exposure -> {toxin, antibiotic, "lipopolysaccharide", bacterial, viral, virus, venom, "pathogen"}
#   - vehicle_only                   -> {solvent, vehicle, "polar solvent", "aprotic solvent"}
#   - environmental                  -> [hard to validate]
#   - differentiation                -> [hard to validate]
#   - genetic_knockdown/overexpression/knockout/crispra/crispri -> ChEBI NON usato (gene-level, salta)
#   - disease_vs_normal              -> ChEBI NON usato (disease term, salta)
#   - none / vehicle_only            -> validabile via solvent role

Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(dplyr); library(tibble); library(cli); library(stringr)
})

CACHE <- tools::R_user_dir("simulomicsr","cache")
chebi <- readRDS(file.path(CACHE, "chebi", "chebi-lookup.rds"))
fr    <- readRDS("analysis/p4-output/p5-audit-fragmentation.rds")

cli_h1("kind_effective vs ChEBI ontology cross-check")

ft <- fr$fragmentation_tbl

# Mantieni solo cluster con canonical CHEBI:NNN risolto
chebi_clusters <- ft |>
  filter(grepl("^CHEBI:[0-9]+$", canonical)) |>
  mutate(chebi_int = as.integer(sub("^CHEBI:", "", canonical)))

cli_alert_info(sprintf("Cluster con CHEBI canonical risolto: %d", nrow(chebi_clusters)))

# Estrai roles per ogni CHEBI ID univoco
roles_agg <- chebi$has_role |>
  group_by(chebi_id) |>
  summarise(roles_blob = paste(unique(role_name), collapse = " | "), .groups = "drop")

chebi_clusters <- chebi_clusters |>
  left_join(roles_agg, by = c("chebi_int" = "chebi_id")) |>
  left_join(chebi$by_id |> select(chebi_int = chebi_id, compound_name = primary_name),
            by = "chebi_int")

cli_alert_info(sprintf("Cluster con role disponibile: %d (%.1f%%)",
                       sum(!is.na(chebi_clusters$roles_blob)),
                       100*mean(!is.na(chebi_clusters$roles_blob))))

# Detect kind_effective vs role keyword
detect_role_keyword <- function(roles_blob, keywords) {
  if (is.na(roles_blob)) return(NA)
  any(sapply(keywords, function(kw) grepl(kw, roles_blob, ignore.case = TRUE)))
}

KEYWORDS <- list(
  cytokine_stim    = c("\\bcytokine\\b","interleukin","interferon","chemokine","\\bgrowth factor\\b"),
  pathogen_or_aggregate_exposure = c("toxin","antibiotic","lipopolysaccharide","\\bbacterial\\b","\\bviral\\b","\\bvirus\\b","\\bvenom\\b","\\bpathogen\\b"),
  vehicle_only     = c("solvent","\\bvehicle\\b")
)

chebi_clusters <- chebi_clusters |>
  mutate(
    role_cytokine = mapply(detect_role_keyword, roles_blob, MoreArgs = list(KEYWORDS$cytokine_stim)),
    role_pathogen = mapply(detect_role_keyword, roles_blob, MoreArgs = list(KEYWORDS$pathogen_or_aggregate_exposure)),
    role_solvent  = mapply(detect_role_keyword, roles_blob, MoreArgs = list(KEYWORDS$vehicle_only))
  )

cli_h2("Distribution kind_effective per CHEBI cluster")
print(chebi_clusters |> count(kind_eff, sort = TRUE) |> head(10))

# Validation rules:
#  - kind_eff=cytokine_stim  -> role_cytokine must be TRUE (else MISMATCH)
#  - kind_eff=pathogen       -> role_pathogen must be TRUE
#  - kind_eff=vehicle_only   -> role_solvent must be TRUE
#  - kind_eff=small_molecule -> always OK (accept)
#  - kind_eff=other          -> skip (no ground-truth via ChEBI role)
validate_kind <- function(kind, role_cytokine, role_pathogen, role_solvent, roles_avail) {
  if (!roles_avail) return("NO_ROLES_TO_VALIDATE")
  if (kind == "cytokine_stim")    return(if (isTRUE(role_cytokine)) "MATCH" else "MISMATCH")
  if (kind == "pathogen_or_aggregate_exposure") return(if (isTRUE(role_pathogen)) "MATCH" else "MISMATCH")
  if (kind == "vehicle_only")     return(if (isTRUE(role_solvent))  "MATCH" else "MISMATCH")
  if (kind == "small_molecule")   return("ACCEPT_ANY")
  if (kind == "none")             return("SKIP_NONE")
  return("SKIP_NO_RULE")
}
chebi_clusters$kind_validation <- mapply(
  validate_kind,
  chebi_clusters$kind_eff,
  chebi_clusters$role_cytokine,
  chebi_clusters$role_pathogen,
  chebi_clusters$role_solvent,
  !is.na(chebi_clusters$roles_blob)
)

cli_h2("Kind validation summary")
print(chebi_clusters |> count(kind_validation, sort = TRUE))

cli_h2("Mismatch rate per kind validable (cytokine/pathogen/vehicle)")
validable <- chebi_clusters |> filter(kind_validation %in% c("MATCH", "MISMATCH"))
print(validable |> group_by(kind_eff) |>
        summarise(n = n(), n_match = sum(kind_validation == "MATCH"),
                  n_mismatch = sum(kind_validation == "MISMATCH"),
                  mismatch_rate_pct = round(100*n_mismatch/n, 1), .groups = "drop"))

cli_h2("Esempi MISMATCH (top 15 per cluster numerosi)")
mismatch_examples <- chebi_clusters |>
  filter(kind_validation == "MISMATCH") |>
  group_by(canonical, compound_name, kind_eff, roles_blob) |>
  summarise(n_clusters = n(), .groups = "drop") |>
  arrange(desc(n_clusters)) |> head(15)
print(mismatch_examples |> select(canonical, compound_name, kind_eff, n_clusters, roles_blob), width = Inf)

cli_h2("MATCH esempi (validation OK)")
match_examples <- chebi_clusters |>
  filter(kind_validation == "MATCH") |>
  group_by(canonical, compound_name, kind_eff) |>
  summarise(n_clusters = n(), .groups = "drop") |>
  arrange(desc(n_clusters)) |> head(10)
print(match_examples, width = Inf)

saveRDS(list(
  chebi_clusters = chebi_clusters,
  validable_summary = validable |> group_by(kind_eff) |>
    summarise(n = n(), n_match = sum(kind_validation == "MATCH"),
              n_mismatch = sum(kind_validation == "MISMATCH"),
              mismatch_rate_pct = round(100*n_mismatch/n, 1), .groups = "drop"),
  mismatch_examples = mismatch_examples
), "analysis/p4-output/p5-audit-kind-validation.rds")
cli_alert_success("Saved analysis/p4-output/p5-audit-kind-validation.rds")
