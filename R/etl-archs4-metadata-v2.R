#' Costruisce il metadata sample esteso ARCHS4 v2 (ADR-0019 Stage 0 v2).
#'
#' Carica i 14 campi sample da H5 (read_archs4_metadata), applica il filtro
#' Stadio 0 v2 (is_sample_classifiable D1+D2+D3+D4), sui sopravvissuti
#' parsa le covariate tecniche aligner_class (B2 spec) + biosample_id per
#' dedupe SAMN (D9), e materializza un RDS singolo che Stadio 4 + Stadio 3
#' possono caricare in secondi senza ri-leggere H5.
#'
#' @param h5_path Path al file H5 ARCHS4 (es. \code{human_gene_v2.5.h5}).
#' @param lib_size_vec Vettore numeric lib_size per sample (length = nrow
#'   meta H5). Default NULL = D4 saltato. In produzione passato da
#'   \code{A3-libsize-scprob-bacino.tsv} (precalcolato in FASE A3 audit).
#' @param out_rds_path Path RDS output. Default NULL = no salvataggio,
#'   ritorna solo la struttura in-memory.
#' @return Lista con:
#'   - \code{metadata}: data.frame riga per sample sopravvissuto. Colonne:
#'     geo_accession, series_id, library_source, molecule_ch1,
#'     instrument_model, data_processing, aligner_class (factor),
#'     relation, biosample_id, lib_size, singlecellprobability.
#'   - \code{n_total}, \code{n_kept}, \code{n_skipped}: conteggi.
#'   - \code{skip_reasons}: table dei reason code drop.
#'   - \code{aligner_distribution}: table aligner_class sui sopravvissuti.
#' @keywords internal
build_archs4_metadata_v2 <- function(h5_path,
                                      lib_size_vec = NULL,
                                      out_rds_path = NULL) {
  meta <- read_archs4_metadata(h5_path)
  n_total <- nrow(meta)

  if (is.null(lib_size_vec)) {
    lib_size_vec <- rep(NA_real_, n_total)
  } else {
    stopifnot(length(lib_size_vec) == n_total)
  }

  # Format B string per ogni sample (input prompt LLM Stadio 1).
  meta$string <- mapply(
    build_sample_string_format_B,
    meta$title, meta$source_name_ch1, meta$characteristics_ch1
  )

  # Applica filtro Stage 0 v2 (firma B3).
  results <- Map(is_sample_classifiable,
                  organism_ch1          = meta$organism_ch1,
                  library_strategy      = meta$library_strategy,
                  library_source        = meta$library_source,
                  extract_protocol_ch1  = meta$extract_protocol_ch1,
                  title                 = meta$title,
                  source_name_ch1       = meta$source_name_ch1,
                  string                = meta$string,
                  singlecellprobability = meta$singlecellprobability,
                  lib_size              = lib_size_vec)
  meta$keep        <- vapply(results, function(r) r$keep,   logical(1L))
  meta$skip_reason <- vapply(results, function(r) r$reason, character(1L))
  meta$lib_size    <- lib_size_vec

  # Sui sopravvissuti, parsa covariate tecniche.
  kept <- meta[meta$keep, , drop = FALSE]
  kept$aligner_class <- parse_aligner_class(kept$data_processing)
  kept$biosample_id  <- parse_biosample_id(kept$relation)

  # Schema RDS finale: colonne richieste da Stadio 3 (E0 dedupe) + Stadio 4
  # (E3 covariate batch).
  out <- data.frame(
    geo_accession         = kept$geo_accession,
    series_id             = kept$series_id,
    library_source        = kept$library_source,
    molecule_ch1          = kept$molecule_ch1,
    instrument_model      = kept$instrument_model,
    data_processing       = kept$data_processing,
    aligner_class         = kept$aligner_class,
    relation              = kept$relation,
    biosample_id          = kept$biosample_id,
    lib_size              = kept$lib_size,
    singlecellprobability = kept$singlecellprobability,
    stringsAsFactors      = FALSE
  )

  if (!is.null(out_rds_path)) {
    saveRDS(out, out_rds_path)
  }

  list(
    metadata             = out,
    n_total              = n_total,
    n_kept               = nrow(out),
    n_skipped            = n_total - nrow(out),
    skip_reasons         = table(meta$skip_reason[!meta$keep], useNA = "ifany"),
    aligner_distribution = table(out$aligner_class, useNA = "ifany")
  )
}
