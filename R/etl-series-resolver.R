#' Lookup metadata di un GSE da NCBI Entrez database `gds`.
#'
#' Estrae i campi necessari per il resolver SRP-driven (Op D revised, spec P4 beta):
#' - `srp`: SRA project ID se linkato (indica sub-series specifica).
#' - `is_super_series`: TRUE se il summary matcha il pattern GEO
#'   `"^This SuperSeries is composed of"`.
#'
#' @param gse Accession GEO (es. "GSE177616").
#' @param max_retries Tentativi su errori HTTP transient (default 5).
#' @param base_delay Delay base in secondi per backoff esponenziale (default 2 -> 2,4,8,16,32s).
#' @return Lista con campi `uid, srp, is_super_series, title, pdat, n_samples, summary`.
#' @keywords internal
entrez_lookup_gse_metadata <- function(gse, max_retries = 5L, base_delay = 2) {
  if (nzchar(Sys.getenv("NCBI_API_KEY"))) {
    rentrez::set_entrez_key(Sys.getenv("NCBI_API_KEY"))
  }
  attempt <- 1L
  repeat {
    res <- tryCatch({
      s <- rentrez::entrez_search(db = "gds", term = paste0(gse, "[Accession]"))
      if (length(s$ids) == 0L) {
        return(list(uid = NA, srp = NA, is_super_series = FALSE,
                    title = NA, pdat = NA, n_samples = NA, summary = NA))
      }
      # Preferisce UID che inizia con "2" (tipo GEO DataSet = GSE)
      gse_uids <- s$ids[grepl("^2[0-9]+$", s$ids)]
      uid <- if (length(gse_uids) > 0L) gse_uids[1L] else s$ids[1L]
      info <- rentrez::entrez_summary(db = "gds", id = uid)
      srp <- NA
      if (length(info$extrelations) > 0L && is.data.frame(info$extrelations)) {
        sra_row <- info$extrelations[info$extrelations$relationtype == "SRA", ]
        if (nrow(sra_row) > 0L) srp <- sra_row$targetobject[1L]
      }
      summary_text <- as.character(info$summary %||% "")
      is_super <- grepl("^This SuperSeries is composed of", summary_text)
      list(
        uid         = uid,
        srp         = srp,
        is_super_series = is_super,
        title       = info$title %||% NA,
        pdat        = info$pdat %||% NA,
        n_samples   = info$n_samples %||% NA,
        summary     = substr(summary_text, 1L, 300L)
      )
    }, error = function(e) e)
    if (!inherits(res, "error")) return(res)
    # Retry su errori HTTP transient (502 bad gateway, 503, timeout, connection)
    msg <- conditionMessage(res)
    is_transient <- grepl("HTTP failure: 5|timeout|gateway|connection|temporary|reset",
                          msg, ignore.case = TRUE)
    if (!is_transient || attempt >= max_retries) stop(res)
    Sys.sleep(base_delay * (2^(attempt - 1L)))
    attempt <- attempt + 1L
  }
}

#' Resolver SRP-driven per series_id multipli (Op D revised, spec P4 beta sez. 4.2).
#'
#' Albero decisionale:
#' 1. Un solo GSE -> ritorna invariato (branch `single_gse`).
#' 2. Misto SuperSeries + NotSuper -> scarta SuperSeries, se rimane 1 NotSuper vince
#'    (branch `clean_super_scarted`).
#' 3. Due candidati NotSuper: SRP-driven decision:
#'    - Solo A ha SRP: branch `srp_a_only`.
#'    - Solo B ha SRP: branch `srp_b_only`.
#'    - Entrambi SRP: tiebreak accession minore (branch `tiebreak_both_srp`).
#'    - Nessuno SRP: fallback accession minore (branch `fallback_no_srp`).
#' 4. Tre o piu' candidati NotSuper: regola SRP applicata al sottoinsieme;
#'    se indeterminato, accession minore (branch `multi_gse_multi_branch`).
#'
#' @param series_id_raw Stringa `"GSE_a,GSE_b[,GSE_c...]"`.
#' @param cache Lista di liste indicizzata per GSE, ciascuna con campi `srp` e
#'   `is_super_series`. Tipicamente popolata via `entrez_lookup_gse_metadata`.
#' @return Lista `list(decision = "GSE_X", branch = "<branch_name>")`.
#'   Valori di `branch`: `single_gse`, `clean_super_scarted`, `srp_a_only`,
#'   `srp_b_only`, `tiebreak_both_srp`, `fallback_no_srp`,
#'   `srp_one_of_many`, `multi_gse_multi_branch`, `all_super_pathological`.
#' @keywords internal
resolve_series_id <- function(series_id_raw, cache) {
  gses <- trimws(strsplit(series_id_raw, ",")[[1L]])
  gses <- gses[nzchar(gses)]

  # Caso 1: singolo GSE
  if (length(gses) == 1L) {
    return(list(decision = gses, branch = "single_gse"))
  }

  # Identifica NotSuper (is_super_series == FALSE o campo assente)
  not_super <- vapply(gses, function(g) {
    !(cache[[g]]$is_super_series %||% FALSE)
  }, logical(1L))

  candidates <- gses[not_super]

  # Caso 2a: un solo NotSuper -> SuperSeries scartate
  if (length(candidates) == 1L) {
    return(list(decision = candidates, branch = "clean_super_scarted"))
  }

  # Caso patologico: tutti SuperSeries
  if (length(candidates) == 0L) {
    return(list(decision = gses[1L], branch = "all_super_pathological"))
  }

  # Candidati >= 2 NotSuper: SRP-driven
  has_srp <- vapply(candidates, function(g) {
    v <- cache[[g]]$srp %||% NA_character_
    !is.na(v) && nzchar(v)
  }, logical(1L))

  if (length(candidates) == 2L) {
    a <- candidates[1L]
    b <- candidates[2L]
    if (has_srp[1L] && !has_srp[2L]) return(list(decision = a, branch = "srp_a_only"))
    if (!has_srp[1L] && has_srp[2L]) return(list(decision = b, branch = "srp_b_only"))
    # Entrambi SRP o nessuno: tiebreak accession minore
    nums  <- as.numeric(gsub("GSE", "", candidates))
    pick  <- candidates[which.min(nums)]
    branch <- if (all(has_srp)) "tiebreak_both_srp" else "fallback_no_srp"
    return(list(decision = pick, branch = branch))
  }

  # Candidati >= 3
  if (sum(has_srp) == 1L) {
    return(list(decision = candidates[has_srp], branch = "srp_one_of_many"))
  }
  nums <- as.numeric(gsub("GSE", "", candidates))
  list(decision = candidates[which.min(nums)], branch = "multi_gse_multi_branch")
}
