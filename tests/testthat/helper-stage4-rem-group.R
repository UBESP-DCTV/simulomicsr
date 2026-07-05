# helper-stage4-rem-group.R
# Helper condiviso tra test-stage4-rem-group.R e test-stage4-rem-group-integration.R.
# Caricato automaticamente da testthat per tutti i file di test.

.mk_cluster_row <- function(cluster_id, mode, level, k, n_total, n_studies,
                            safety_min, usable_mega_strict, kind, agent) {
  tibble::tibble(
    cluster_id = cluster_id, mode = mode, level = level, k = k,
    n_total = n_total, n_studies = n_studies, safety_min = safety_min,
    usable_rem_strict = FALSE, usable_rem_relaxed = FALSE,
    usable_mega_strict = usable_mega_strict, usable_mega_relaxed = FALSE,
    kind_effective_resolved = kind, agent_id_resolved = agent,
    studies_in_cluster = list(paste0("GSE", seq_len(n_studies))),
    direction_check = "ok"
  )
}
