#' Legge i metadata sample da un dump ARCHS4 H5.
#'
#' Estrae i campi sotto \code{/meta/samples/} necessari per la classificazione
#' P4 beta + i campi addizionali introdotti da ADR-0019 (P5 audit RED_ALERT
#' Stadio 0): filtri pre-LLM single-cell (\code{library_source},
#' \code{extract_protocol_ch1}, \code{singlecellprobability}), hint LLM
#' (\code{molecule_ch1}), covariate batch DE (\code{instrument_model},
#' \code{data_processing}), dedupe BioSample (\code{relation}).
#'
#' Schema v2: 13 colonne character + 1 colonna numeric
#' (\code{singlecellprobability}).
#'
#' @param h5_path Path al file \code{human_gene_v2.5.h5} ARCHS4.
#' @return Data frame con una riga per sample. Le colonne character sono
#'   coerce-ate con \code{as.character}; \code{singlecellprobability} e'
#'   numeric (\code{NA_real_} dove mancante).
#' @keywords internal
read_archs4_metadata <- function(h5_path) {
  stopifnot(file.exists(h5_path))
  # Campi character (storici + ADR-0019 D1/D2/D5/D8/D9).
  fields_chr <- c("geo_accession", "series_id", "title", "source_name_ch1",
                  "characteristics_ch1", "organism_ch1", "library_strategy",
                  "molecule_ch1", "library_source", "extract_protocol_ch1",
                  "instrument_model", "data_processing", "relation")
  # Campi numeric (ADR-0019 D3: predizione ARCHS4 0-1).
  fields_num <- c("singlecellprobability")
  cols_chr <- lapply(fields_chr, function(f) {
    as.character(rhdf5::h5read(h5_path, paste0("meta/samples/", f)))
  })
  names(cols_chr) <- fields_chr
  cols_num <- lapply(fields_num, function(f) {
    as.numeric(rhdf5::h5read(h5_path, paste0("meta/samples/", f)))
  })
  names(cols_num) <- fields_num
  rhdf5::H5close()
  data.frame(c(cols_chr, cols_num), stringsAsFactors = FALSE)
}

#' Trasforma ARCHS4 H5 in JSONL raw input per stage1 (formato B, filtri applicati).
#'
#' Applica i filtri di inclusione (human, bulk RNA-Seq, stringa >= 20 caratteri)
#' e serializza ogni sample accettato come riga JSONL pronta per la pipeline stage1.
#'
#' @param h5_path Path ARCHS4 H5.
#' @param out_jsonl_path Path di output JSONL (una riga per sample).
#' @param skip_log_path Path di output TSV con sample skippati e ragione (default NULL).
#' @return Lista con \code{included} (int), \code{skipped} (int), \code{total} (int).
#' @keywords internal
archs4_to_stage1_jsonl <- function(h5_path, out_jsonl_path, skip_log_path = NULL) {
  meta <- read_archs4_metadata(h5_path)
  meta$string <- mapply(
    build_sample_string_format_B,
    meta$title, meta$source_name_ch1, meta$characteristics_ch1
  )
  meta$keep <- mapply(
    is_sample_classifiable,
    meta$organism_ch1, meta$library_strategy, meta$string
  )
  meta$skip_reason <- ifelse(
    meta$keep, NA_character_,
    ifelse(meta$organism_ch1 != "Homo sapiens", "not_human",
    ifelse(meta$library_strategy != "RNA-Seq", "not_bulk_rnaseq",
    ifelse(nchar(meta$string) < 20, "string_too_short", "unknown")))
  )
  if (!is.null(skip_log_path)) {
    skipped <- meta[!meta$keep, c("geo_accession", "series_id", "skip_reason")]
    write.table(skipped, skip_log_path, sep = "\t", row.names = FALSE, quote = FALSE)
  }
  kept <- meta[meta$keep, ]
  recs <- lapply(seq_len(nrow(kept)), function(i) {
    list(
      geo_accession = kept$geo_accession[i],
      series_id = kept$series_id[i],
      string = kept$string[i],
      library_strategy = kept$library_strategy[i],
      organism = kept$organism_ch1[i]
    )
  })
  out_lines <- vapply(recs, jsonlite::toJSON, character(1L), auto_unbox = TRUE)
  writeLines(out_lines, out_jsonl_path)
  structure(
    list(included = nrow(kept), skipped = nrow(meta) - nrow(kept), total = nrow(meta)),
    class = "list"
  )
}
