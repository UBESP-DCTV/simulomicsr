# Spezzare il re-pool in pezzi, e ricomporli.
#
# PERCHE'. Il ramo `rem_group` — l'unico che produce il deliverable — calcola un
# cluster alla volta su un core solo: il re-pool v16 ha impiegato 32,5 h su una
# macchina da 128 core, con 31,6 h dentro i cluster. I cluster sono indipendenti,
# quindi possono essere calcolati da processi separati, ognuno col suo
# `cluster_subset`, e poi ricomposti.
#
# IL MOTORE DI CALCOLO NON CAMBIA: ogni pezzo esegue lo stesso codice di sempre
# sugli stessi dati, solo su meno cluster. E' la ragione per cui questa strada e'
# stata preferita alla parallelizzazione interna: l'uguaglianza dei risultati e'
# garantita per costruzione, non per verifica. Misurata comunque, sui dati veri:
# 6 cluster, 82.375 righe poolate e 1.637.178 per-studio, tutte le colonne
# identiche.
#
# ⚠️ LA RICOMPOSIZIONE NON E' UN `rbind`. Il primo tentativo univa le due tabelle
# e basta: i dati risultavano identici ma sparivano i REGISTRI, che viaggiano
# come attributi (`role_conflicts`, `lane_collapses`, `covariate_drop_log`,
# `pooling_warnings`) e sono cio' che rende auditabile uno scarto. Un deliverable
# giusto con i registri vuoti e' esattamente il difetto che il 2026-08-11 ha
# tenuto il registro dei conflitti di ruolo fuori dal disco.

#' Registri che viaggiano come attributi delle due tabelle
#' @keywords internal
.SHARD_ATTR_PSD <- c("covariates_used", "covariates_dropped", "covariate_drop_log",
                     "role_conflicts", "lane_collapses")
.SHARD_ATTR_POOL <- c("pooling_warnings", "non_processable_in_pool",
                      "mega_aug_diagnostics")

#' Unisce i data.frame di un attributo su piu' pezzi
#' @keywords internal
.merge_attr <- function(shards, tab, nome) {
  parti <- lapply(shards, function(s) attr(s[[tab]], nome))
  parti <- parti[!vapply(parti, is.null, logical(1))]
  if (!length(parti)) return(NULL)
  df <- parti[vapply(parti, is.data.frame, logical(1))]
  if (length(df) == length(parti)) {
    df <- df[vapply(df, function(x) nrow(x) > 0L, logical(1))]
    if (!length(df)) return(parti[[1L]])
    return(do.call(rbind, df))
  }
  # attributi non tabellari (es. `covariates_used`): unione dei valori distinti
  unique(unlist(parti, use.names = FALSE))
}

#' Ricompone i pezzi di un re-pool spezzato
#'
#' @param shards list di oggetti \code{stage4_result}, uno per pezzo. I pezzi
#'   devono coprire cluster DISGIUNTI ed essere stati prodotti con la stessa
#'   configurazione.
#' @return un solo \code{stage4_result}, con le righe e i registri di tutti.
#' @export
merge_stage4_shards <- function(shards) {
  if (!is.list(shards) || length(shards) == 0L)
    stop("serve una lista non vuota di pezzi")
  if (length(shards) == 1L) return(shards[[1L]])

  # Due pezzi che calcolano lo stesso cluster ne raddoppierebbero le righe nel
  # deliverable senza che nulla lo dica.
  cids <- lapply(shards, function(s) unique(as.character(s$eligible_clusters$cluster_id)))
  dupl <- unique(unlist(cids)[duplicated(unlist(cids))])
  if (length(dupl) > 0L)
    stop("questi cluster compaiono in piu' di un pezzo: ",
         paste(utils::head(dupl, 5), collapse = ", "))

  # Una configurazione diversa fra i pezzi vuol dire che non stanno calcolando
  # la stessa cosa: il deliverable unito sarebbe un ibrido non dichiarato.
  cfg1 <- shards[[1L]]$config
  for (i in seq_along(shards)[-1L])
    if (!identical(shards[[i]]$config, cfg1))
      stop("i pezzi hanno configurazione diversa: il ", i, "-esimo non coincide col primo")

  rb <- function(nome) {
    parti <- lapply(shards, function(s) s[[nome]])
    parti <- parti[!vapply(parti, is.null, logical(1))]
    if (!length(parti)) return(NULL)
    do.call(rbind, parti)
  }
  out <- shards[[1L]]
  out$per_study_de      <- rb("per_study_de")
  out$cluster_pooled    <- rb("cluster_pooled")
  out$eligible_clusters <- rb("eligible_clusters")
  out$non_processable   <- rb("non_processable")
  for (nm in .SHARD_ATTR_PSD)
    attr(out$per_study_de, nm) <- .merge_attr(shards, "per_study_de", nm)
  for (nm in .SHARD_ATTR_POOL)
    attr(out$cluster_pooled, nm) <- .merge_attr(shards, "cluster_pooled", nm)

  # qc_report: gli slot tabellari si sommano, gli altri restano quelli del primo
  qc <- shards[[1L]]$qc_report
  for (slot in names(qc)) {
    if (!is.data.frame(qc[[slot]])) next
    parti <- lapply(shards, function(s) s$qc_report[[slot]])
    parti <- parti[vapply(parti, function(x) is.data.frame(x) && nrow(x) > 0L, logical(1))]
    if (length(parti)) qc[[slot]] <- do.call(rbind, parti)
  }
  out$qc_report <- qc
  out
}
