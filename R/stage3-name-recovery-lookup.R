# stage3-name-recovery-lookup.R — Lookup precalcolato GSM -> identita' biologica
#
# Costruisce per ogni GSM un'entry (kind, agent_id, canonical_name,
# recovery_source) leggendo i metadati GEO grezzi dall'H5 ARCHS4 e
# applicando recover_identity() (FASE 2 del rework Stadio 3 minestrone).
# Spec: docs/superpowers/specs/2026-06-25-stage3-name-recovery-reclustering-design.md

# Versione schema del lookup: bumpa se cambia il contratto output di
# recover_identity() o dei campi H5 letti, per evitare hit stale su disco
# (finding "cache version-blind" audit pipeline C2/E6 2026-05-25).
.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION <- "v1"

# ---------------------------------------------------------------------------
# Helper lettura H5 (isolato per testabilita')
# ---------------------------------------------------------------------------

#' Legge i 5 campi GEO campione dal file H5 ARCHS4
#'
#' Helper interno isolato per iniettabilita' nei test: i test passano
#' un \code{read_fn} alternativo senza dipendere da un H5 reale.
#' Segue il pattern di \code{.fetch_counts_from_h5} in
#' \code{R/stage4-counts-cache.R}.
#'
#' @param h5_path character(1) path al file H5 ARCHS4.
#' @return lista con 5 vettori character nominati: \code{geo_accession},
#'   \code{series_id}, \code{source_name_ch1}, \code{characteristics_ch1},
#'   \code{title}.
#' @keywords internal
.read_h5_name_recovery_fields <- function(h5_path) {
  stopifnot(file.exists(h5_path))
  fields <- c("geo_accession", "series_id", "source_name_ch1",
               "characteristics_ch1", "title")
  res <- lapply(fields, function(f) {
    as.character(rhdf5::h5read(h5_path, paste0("meta/samples/", f)))
  })
  names(res) <- fields
  rhdf5::H5close()
  res
}

# ---------------------------------------------------------------------------
# Chiave cache
# ---------------------------------------------------------------------------

#' Calcola la chiave cache per build_name_recovery_lookup
#'
#' Ingloba: schema_version + h5_path + mtime H5 + sorted(gsms) + kind
#' per ogni gsm. Cosi' ogni modifica al set di GSM, al kind richiesto
#' o al file H5 produce una chiave distinta e invalida la cache stale.
#'
#' Finding "cache version-blind" (audit pipeline RED ALERT): la chiave
#' DEVE includere \code{.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION} per
#' invalidare automaticamente dopo un bump di schema.
#'
#' @param h5_path character(1) path al file H5.
#' @param gsms character vector di GSM.
#' @param kind_by_gsm named list/env GSM -> llm_kind.
#' @return character(1) hash xxhash32 8-hex.
#' @keywords internal
.name_recovery_lookup_cache_key <- function(h5_path, gsms, kind_by_gsm) {
  mtime <- if (file.exists(h5_path)) as.character(file.mtime(h5_path)) else "NO_FILE"
  gsms_sorted <- sort(gsms)
  kinds_str <- paste(
    vapply(gsms_sorted, function(g) {
      k <- if (!is.null(kind_by_gsm[[g]])) kind_by_gsm[[g]] else "NA"
      paste0(g, "=", k)
    }, character(1L)),
    collapse = ";"
  )
  payload <- paste0(
    .NAME_RECOVERY_LOOKUP_SCHEMA_VERSION, "::",
    h5_path, "::", mtime, "::",
    paste(gsms_sorted, collapse = "|"), "::",
    kinds_str
  )
  hash <- digest::digest(payload, algo = "xxhash32", serialize = FALSE)
  substr(hash, 1L, 8L)
}

# ---------------------------------------------------------------------------
# Entry point pubblico
# ---------------------------------------------------------------------------

#' Costruisce un lookup GSM -> identita' biologica dal file H5 ARCHS4.
#'
#' Per ogni GSM nel vettore \code{gsms}, legge i metadati GEO grezzi
#' dall'H5 (\code{source_name_ch1}, \code{characteristics_ch1},
#' \code{title}), applica \code{recover_identity()} e memorizza il
#' risultato in un environment hash (lookup O(1)). I GSM assenti
#' dall'H5 (match NA su \code{geo_accession}) non vengono assegnati:
#' restano NULL nell'env e il chiamante li tratta come "nessun recovery".
#'
#' Il parametro \code{read_fn} permette di iniettare un reader
#' alternativo nei test senza un H5 reale (pattern di
#' \code{.fetch_counts_from_h5} in \code{R/stage4-counts-cache.R}).
#'
#' @param h5_path character(1) path al file H5 ARCHS4. Richiesto se
#'   \code{read_fn} e' NULL; ignorato (ma passato a \code{read_fn}) se
#'   quest'ultima e' fornita.
#' @param gsms character vector (length >= 1) di GSM accession da
#'   processare.
#' @param kind_by_gsm named list o environment: chiave = GSM accession,
#'   valore = \code{kind_effective} LLM Stadio 2 (character(1)). Se un
#'   GSM non e' presente, viene passato \code{NA_character_} a
#'   \code{recover_identity()} (l'orchestratore gestisce kind ignoto
#'   con \code{recovery_source = "NO_RECOVERY"}).
#' @param ontology_env environment caricato da
#'   \code{.load_ontology_dicts()}, contenente i dizionari ChEBI,
#'   HGNC e MeSH.
#' @param cache_dir character(1) | NULL directory per cache su disco
#'   (salva/rilegge un RDS). Default NULL = nessuna cache. La chiave
#'   include \code{.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION} + mtime H5
#'   per evitare hit stale.
#' @param read_fn function | NULL reader iniettabile per testabilita'.
#'   Firma attesa: \code{function(h5_path) -> list(geo_accession,
#'   series_id, source_name_ch1, characteristics_ch1, title)}.
#'   Default NULL = usa \code{.read_h5_name_recovery_fields(h5_path)}.
#' @return environment hash (parent = emptyenv()). Ogni chiave e' un
#'   GSM accession; il valore e' la lista restituita da
#'   \code{recover_identity()}: \code{(kind, agent_id, canonical_name,
#'   recovery_source)}.
#' @export
build_name_recovery_lookup <- function(h5_path, gsms, kind_by_gsm,
                                        ontology_env,
                                        cache_dir = NULL,
                                        read_fn = NULL) {
  stopifnot(is.character(gsms), length(gsms) >= 1L)

  # --- Cache su disco (hit precoce) ----------------------------------------
  cache_file <- NULL
  if (!is.null(cache_dir)) {
    if (!dir.exists(cache_dir)) dir.create(cache_dir, recursive = TRUE)
    key <- .name_recovery_lookup_cache_key(h5_path, gsms, kind_by_gsm)
    cache_file <- file.path(cache_dir,
                             paste0("name-recovery-lookup-", key, ".rds"))
    if (file.exists(cache_file)) {
      return(readRDS(cache_file))
    }
  }

  # --- Lettura campi H5 (o reader iniettato) --------------------------------
  if (is.null(read_fn)) {
    h5_data <- .read_h5_name_recovery_fields(h5_path)
  } else {
    h5_data <- read_fn(h5_path)
  }

  geo_accession       <- h5_data$geo_accession
  source_name_ch1     <- h5_data$source_name_ch1
  characteristics_ch1 <- h5_data$characteristics_ch1
  title               <- h5_data$title

  # --- Costruzione lookup environment (hash per O(1)) -----------------------
  lookup <- new.env(parent = emptyenv(), hash = TRUE, size = length(gsms))

  # Match VETTORIZZATO una sola volta: `match(gsms, geo_accession)` hasha la
  # tabella geo_accession (~888k) UNA volta. La versione scalare-nel-loop
  # `match(gsm, geo_accession)` la ri-hashava ad ogni iterazione -> O(n_gsm x
  # n_h5), non scalabile al full run 10^5 GSM (review I1).
  idx_all <- match(gsms, geo_accession)

  for (j in seq_along(gsms)) {
    gsm <- gsms[[j]]
    idx <- idx_all[[j]]
    if (is.na(idx)) next   # GSM assente: non assegnato, resta NULL nell'env

    # kind mancante in kind_by_gsm -> NA_character_ (recover_identity lo gestisce)
    llm_kind <- if (!is.null(kind_by_gsm[[gsm]])) kind_by_gsm[[gsm]] else NA_character_

    res <- recover_identity(
      source          = source_name_ch1[idx],
      characteristics = characteristics_ch1[idx],
      title           = title[idx],
      llm_kind        = llm_kind,
      ontology_env    = ontology_env
    )

    assign(gsm, res, envir = lookup)
  }

  # --- Salva su disco se cache richiesta ------------------------------------
  if (!is.null(cache_file)) {
    saveRDS(lookup, cache_file, compress = "xz")
  }

  lookup
}
