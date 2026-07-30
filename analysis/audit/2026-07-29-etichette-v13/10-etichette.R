# 10-etichette.R --- risolve l'etichetta dei 305 gruppi del deliverable v13
# DALL'ID (`contrast_entity`), in una colonna NUOVA, e la confronta con il nome
# mostrato oggi (`canonical_name`, ereditato dall'anchor vecchio).
#
# Non tocca `canonical_name` e non tocca il pooling: `canonical_name` non
# compare in nessun file R/stage4-*.
#
# Uso: Rscript analysis/audit/2026-07-29-etichette-v13/10-etichette.R

suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })

out_dir <- "analysis/audit/2026-07-29-etichette-v13"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

d <- as.data.frame(readRDS(
  "analysis/audit/2026-07-28-censimento-v13/deliverable-v13.rds"),
  stringsAsFactors = FALSE)
stopifnot(nrow(d) == 305L)

env <- simulomicsr:::.load_ontology_dicts()
lab <- simulomicsr:::.resolve_contrast_entity_labels(d$contrast_entity, env = env)

res <- data.frame(
  cluster_id       = d$cluster_id,
  contrast_entity  = d$contrast_entity,
  label_nuova      = lab$contrast_entity_label,
  label_fonte      = lab$contrast_entity_label_source,
  canonical_name   = d$canonical_name,
  k                = d$k,
  direzione        = d$contrast_direction,
  controllo        = d$contrast_control_key,
  stringsAsFactors = FALSE
)

norm <- function(x) {
  x <- tolower(trimws(as.character(x)))
  x[is.na(x)] <- ""
  gsub("[^a-z0-9]", "", x)
}
res$divergente <- norm(res$label_nuova) != norm(res$canonical_name) &
  !is.na(res$label_nuova)

res <- res[order(-res$k), ]
utils::write.csv(res, file.path(out_dir, "etichette-v13.csv"), row.names = FALSE)

cat("=== FONTE DELL'ETICHETTA (305 gruppi) ===\n")
print(table(res$label_fonte))
cat("\nrisolte:", sum(!is.na(res$label_nuova)),
    " non risolte:", sum(is.na(res$label_nuova)), "\n")
cat("divergenti dal nome mostrato oggi:", sum(res$divergente),
    sprintf(" (%.1f%%)\n", 100 * sum(res$divergente) / nrow(res)))
cat("studi-slot nei gruppi divergenti:", sum(res$k[res$divergente]),
    "su", sum(res$k), "\n")

cat("\n=== NON RISOLTI (etichetta da tenere com'e') ===\n")
nr <- res[is.na(res$label_nuova), c("contrast_entity", "canonical_name", "k", "label_fonte")]
if (nrow(nr) > 0) print(nr, row.names = FALSE) else cat("nessuno\n")

cat("\n=== DIVERGENTI, i 40 piu' grandi ===\n")
dv <- res[res$divergente, c("contrast_entity", "canonical_name", "label_nuova", "k")]
print(utils::head(dv, 40), row.names = FALSE)
cat("\ntotale divergenti:", nrow(dv), "\n")
cat("\nTabella completa:", file.path(out_dir, "etichette-v13.csv"), "\n")
