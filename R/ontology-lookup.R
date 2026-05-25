# ontology-lookup.R --- Loader e accessor deterministici per le 3 dictionary
# (ChEBI, HGNC, MeSH) utilizzate dal resolver anchor v3.1.
#
# I dump pre-buildati (analysis/p5-audit-chebi-build-dict.R +
# analysis/p5-audit-hgnc-mesh-build-dict.R) vivono in
# tools::R_user_dir("simulomicsr","cache")/chebi/ + .../hgnc-lookup.rds + .../mesh-lookup.rds.
#
# Per i test viene caricato un mini-subset da inst/extdata/ontology-fixtures-mini/.
#
# Design (vedi ADR-0018 + spec 2026-05-25):
# - Singleton env .ontology_env memoizzato (refresh=FALSE riusa, refresh=TRUE reload).
# - Ogni dict e' costruita come hash environment per O(1) lookup downstream
#   (Stage 3 rebuild chiama gli accessor ~1M volte; tibble filter dplyr sarebbe O(N)).
# - Accessor restituiscono named list (NULL su miss) per uso ergonomic downstream.

#' @noRd
.ontology_env <- new.env(parent = emptyenv())

#' Carica ChEBI + HGNC + MeSH dictionary in env singleton, memoizzato
#'
#' Costruisce hash environment per ogni indice rilevante (by_id, aliases,
#' secondary, has_role per ChEBI; by_hgnc_int, by_symbol_lower, by_entrez_int,
#' aliases_long per HGNC; by_ui, by_entry_lower per MeSH).
#'
#' @param refresh logical(1): se TRUE forza reload (anche se gia' caricato).
#' @param cache_dir character(1): directory contenente i 3 RDS full (default
#'   \code{tools::R_user_dir("simulomicsr","cache")}). Usato solo se
#'   \code{fixture_dir} e' NULL.
#' @param fixture_dir character(1) | NULL: se non-NULL, carica i mini-subset
#'   \code{chebi-mini.rds}, \code{hgnc-mini.rds}, \code{mesh-mini.rds} da
#'   questa directory invece dei file full. Usato per i test.
#' @return environment con elementi \code{chebi}, \code{hgnc}, \code{mesh},
#'   \code{loaded=TRUE}, \code{source_dir}, \code{is_fixture}.
#' @keywords internal
.load_ontology_dicts <- function(refresh = FALSE,
                                 cache_dir = tools::R_user_dir("simulomicsr", which = "cache"),
                                 fixture_dir = NULL) {
  if (!refresh && isTRUE(.ontology_env$loaded)) return(.ontology_env)

  if (!is.null(fixture_dir)) {
    if (!dir.exists(fixture_dir)) {
      stop(sprintf("fixture_dir does not exist: %s", fixture_dir))
    }
    chebi_raw <- readRDS(file.path(fixture_dir, "chebi-mini.rds"))
    hgnc_raw  <- readRDS(file.path(fixture_dir, "hgnc-mini.rds"))
    mesh_raw  <- readRDS(file.path(fixture_dir, "mesh-mini.rds"))
    src_dir   <- fixture_dir
    is_fix    <- TRUE
  } else {
    chebi_path <- file.path(cache_dir, "chebi", "chebi-lookup.rds")
    hgnc_path  <- file.path(cache_dir, "hgnc-lookup.rds")
    mesh_path  <- file.path(cache_dir, "mesh-lookup.rds")
    if (!file.exists(chebi_path)) {
      stop(sprintf(
        "ChEBI dictionary missing at %s.\nRebuild via: Rscript analysis/p5-audit-chebi-build-dict.R",
        chebi_path
      ))
    }
    if (!file.exists(hgnc_path) || !file.exists(mesh_path)) {
      stop(sprintf(
        "HGNC or MeSH dictionary missing at %s / %s.\nRebuild via: Rscript analysis/p5-audit-hgnc-mesh-build-dict.R",
        hgnc_path, mesh_path
      ))
    }
    chebi_raw <- readRDS(chebi_path)
    hgnc_raw  <- readRDS(hgnc_path)
    mesh_raw  <- readRDS(mesh_path)
    src_dir   <- cache_dir
    is_fix    <- FALSE
  }

  .ontology_env$chebi      <- .build_chebi_index(chebi_raw)
  .ontology_env$hgnc       <- .build_hgnc_index(hgnc_raw)
  .ontology_env$mesh       <- .build_mesh_index(mesh_raw)
  .ontology_env$source_dir <- src_dir
  .ontology_env$is_fixture <- is_fix
  .ontology_env$loaded     <- TRUE
  .ontology_env
}

#' @noRd
.build_chebi_index <- function(chebi_raw) {
  # by_id: hash env chebi_int (as character) -> named list compound metadata
  by_id_env <- new.env(hash = TRUE, parent = emptyenv(), size = max(nrow(chebi_raw$by_id), 1L))
  for (i in seq_len(nrow(chebi_raw$by_id))) {
    row <- chebi_raw$by_id[i, ]
    assign(
      as.character(row$chebi_id),
      list(
        chebi_id     = as.integer(row$chebi_id),
        primary_name = row$primary_name,
        ascii_name   = row$ascii_name,
        stars        = as.integer(row$stars),
        definition   = row$definition,
        is_obsolete  = isTRUE(row$is_obsolete),
        parent_id    = if (is.na(row$parent_id)) NA_integer_ else as.integer(row$parent_id)
      ),
      envir = by_id_env
    )
  }

  # aliases: hash env alias_lower -> named list (chebi_id, type). Prima vittoria
  # vince (rare duplicates dove un alias mappa a piu' compound — accettiamo).
  aliases_env <- new.env(hash = TRUE, parent = emptyenv(),
                         size = max(nrow(chebi_raw$aliases), 1L))
  for (i in seq_len(nrow(chebi_raw$aliases))) {
    row <- chebi_raw$aliases[i, ]
    key <- row$alias_lower
    if (!exists(key, envir = aliases_env, inherits = FALSE)) {
      assign(key, list(chebi_id = as.integer(row$chebi_id), type = row$type),
             envir = aliases_env)
    }
  }

  # secondary: hash env secondary_id (as character) -> primary_id integer
  secondary_env <- new.env(hash = TRUE, parent = emptyenv(),
                           size = max(nrow(chebi_raw$secondary), 1L))
  for (i in seq_len(nrow(chebi_raw$secondary))) {
    row <- chebi_raw$secondary[i, ]
    assign(as.character(row$secondary_id), as.integer(row$primary_id),
           envir = secondary_env)
  }

  # has_role: hash env chebi_int (as character) -> character vector role_name.
  # Group per chebi_id vectorized (split list molto piu' veloce di for loop).
  has_role_env <- new.env(hash = TRUE, parent = emptyenv())
  if (nrow(chebi_raw$has_role) > 0L) {
    role_by_cid <- split(chebi_raw$has_role$role_name, chebi_raw$has_role$chebi_id)
    for (cid in names(role_by_cid)) {
      assign(cid, as.character(role_by_cid[[cid]]), envir = has_role_env)
    }
  }

  list(
    by_id     = by_id_env,
    aliases   = aliases_env,
    secondary = secondary_env,
    has_role  = has_role_env,
    meta      = chebi_raw$meta
  )
}

#' @noRd
.build_hgnc_index <- function(hgnc_raw) {
  # by_hgnc_int: chr(hgnc_int) -> named list gene metadata
  by_hgnc_env <- new.env(hash = TRUE, parent = emptyenv(),
                         size = max(nrow(hgnc_raw$by_hgnc_int), 1L))
  for (i in seq_len(nrow(hgnc_raw$by_hgnc_int))) {
    row <- hgnc_raw$by_hgnc_int[i, ]
    assign(
      as.character(row$hgnc_int),
      list(
        hgnc_int        = as.integer(row$hgnc_int),
        hgnc_id         = row$hgnc_id,
        symbol          = row$symbol,
        name            = row$name,
        locus_group     = row$locus_group,
        locus_type      = row$locus_type,
        status          = row$status,
        entrez_int      = if (is.na(row$entrez_int)) NA_integer_ else as.integer(row$entrez_int),
        ensembl_gene_id = row$ensembl_gene_id
      ),
      envir = by_hgnc_env
    )
  }

  # by_entrez_int: chr(entrez_int) -> named list (hgnc_int, symbol)
  by_entrez_env <- new.env(hash = TRUE, parent = emptyenv(),
                           size = max(nrow(hgnc_raw$by_entrez_int), 1L))
  for (i in seq_len(nrow(hgnc_raw$by_entrez_int))) {
    row <- hgnc_raw$by_entrez_int[i, ]
    assign(
      as.character(row$entrez_int),
      list(
        entrez_int = as.integer(row$entrez_int),
        hgnc_int   = as.integer(row$hgnc_int),
        symbol     = row$symbol,
        name       = row$name
      ),
      envir = by_entrez_env
    )
  }

  # by_symbol_lower: chr(symbol_lower) -> named list (hgnc_int, primary_symbol)
  # Include primary symbols PLUS alias_lower (per supporto alias resolution).
  by_symbol_env <- new.env(hash = TRUE, parent = emptyenv(),
                           size = max(nrow(hgnc_raw$by_symbol_lower) +
                                      nrow(hgnc_raw$aliases_long), 1L))
  for (i in seq_len(nrow(hgnc_raw$by_symbol_lower))) {
    row <- hgnc_raw$by_symbol_lower[i, ]
    assign(
      row$symbol_lower,
      list(
        hgnc_int       = as.integer(row$hgnc_int),
        primary_symbol = row$symbol,
        match_type     = "PRIMARY"
      ),
      envir = by_symbol_env
    )
  }
  # Aliases (non-conflicting: primary wins se collision)
  for (i in seq_len(nrow(hgnc_raw$aliases_long))) {
    row <- hgnc_raw$aliases_long[i, ]
    if (!exists(row$alias_lower, envir = by_symbol_env, inherits = FALSE)) {
      assign(
        row$alias_lower,
        list(
          hgnc_int       = as.integer(row$hgnc_int),
          primary_symbol = row$primary_symbol,
          match_type     = "ALIAS"
        ),
        envir = by_symbol_env
      )
    }
  }

  list(
    by_hgnc_int     = by_hgnc_env,
    by_entrez_int   = by_entrez_env,
    by_symbol_lower = by_symbol_env,
    meta            = list(n_genes = nrow(hgnc_raw$by_hgnc_int))
  )
}

#' @noRd
.build_mesh_index <- function(mesh_raw) {
  # by_ui: chr(ui) -> named list (mh, tree_top, tree_branches)
  by_ui_env <- new.env(hash = TRUE, parent = emptyenv(),
                       size = max(nrow(mesh_raw$by_ui), 1L))
  for (i in seq_len(nrow(mesh_raw$by_ui))) {
    row <- mesh_raw$by_ui[i, ]
    assign(
      row$ui,
      list(
        ui            = row$ui,
        mh            = row$mh,
        tree_top      = row$tree_top,
        tree_branches = row$tree_branches
      ),
      envir = by_ui_env
    )
  }

  # by_entry_lower: chr(entry_lower) -> named list (ui)
  by_entry_env <- new.env(hash = TRUE, parent = emptyenv(),
                          size = max(nrow(mesh_raw$by_entry_lower), 1L))
  for (i in seq_len(nrow(mesh_raw$by_entry_lower))) {
    row <- mesh_raw$by_entry_lower[i, ]
    if (!exists(row$entry_lower, envir = by_entry_env, inherits = FALSE)) {
      assign(row$entry_lower, list(ui = row$ui), envir = by_entry_env)
    }
  }

  list(
    by_ui          = by_ui_env,
    by_entry_lower = by_entry_env,
    meta           = list(n_descriptors = nrow(mesh_raw$by_ui))
  )
}

# --- ChEBI accessor ----------------------------------------------------------

#' @noRd
.chebi_lookup_id <- function(chebi_int, env = .load_ontology_dicts()) {
  key <- as.character(chebi_int)
  if (!exists(key, envir = env$chebi$by_id, inherits = FALSE)) return(NULL)
  get(key, envir = env$chebi$by_id, inherits = FALSE)
}

#' @noRd
.chebi_lookup_alias <- function(alias, env = .load_ontology_dicts()) {
  key <- tolower(alias)
  if (!exists(key, envir = env$chebi$aliases, inherits = FALSE)) return(NULL)
  get(key, envir = env$chebi$aliases, inherits = FALSE)
}

#' @noRd
.chebi_roles <- function(chebi_int, env = .load_ontology_dicts()) {
  key <- as.character(chebi_int)
  if (!exists(key, envir = env$chebi$has_role, inherits = FALSE)) return(character(0))
  get(key, envir = env$chebi$has_role, inherits = FALSE)
}

#' @noRd
.chebi_secondary_redirect <- function(chebi_int, env = .load_ontology_dicts()) {
  key <- as.character(chebi_int)
  if (!exists(key, envir = env$chebi$secondary, inherits = FALSE)) return(NULL)
  get(key, envir = env$chebi$secondary, inherits = FALSE)
}

# --- HGNC accessor -----------------------------------------------------------

#' @noRd
.hgnc_lookup_hgnc <- function(hgnc_int, env = .load_ontology_dicts()) {
  key <- as.character(hgnc_int)
  if (!exists(key, envir = env$hgnc$by_hgnc_int, inherits = FALSE)) return(NULL)
  get(key, envir = env$hgnc$by_hgnc_int, inherits = FALSE)
}

#' @noRd
.hgnc_lookup_entrez <- function(entrez_int, env = .load_ontology_dicts()) {
  key <- as.character(entrez_int)
  if (!exists(key, envir = env$hgnc$by_entrez_int, inherits = FALSE)) return(NULL)
  get(key, envir = env$hgnc$by_entrez_int, inherits = FALSE)
}

#' @noRd
.hgnc_lookup_symbol <- function(symbol, env = .load_ontology_dicts()) {
  key <- tolower(symbol)
  if (!exists(key, envir = env$hgnc$by_symbol_lower, inherits = FALSE)) return(NULL)
  get(key, envir = env$hgnc$by_symbol_lower, inherits = FALSE)
}

# --- MeSH accessor -----------------------------------------------------------

#' @noRd
.mesh_lookup_ui <- function(ui_str, env = .load_ontology_dicts()) {
  if (!exists(ui_str, envir = env$mesh$by_ui, inherits = FALSE)) return(NULL)
  get(ui_str, envir = env$mesh$by_ui, inherits = FALSE)
}

#' @noRd
.mesh_lookup_term <- function(term, env = .load_ontology_dicts()) {
  key <- tolower(term)
  if (!exists(key, envir = env$mesh$by_entry_lower, inherits = FALSE)) return(NULL)
  get(key, envir = env$mesh$by_entry_lower, inherits = FALSE)
}

# --- Release meta ------------------------------------------------------------

#' Restituisce metadata di release delle 3 dictionary correnti
#'
#' Usato da \code{build_stage3_clusters()} per registrare \code{ontology_releases}
#' nel \code{run_metadata.json}, garantendo riproducibilita' paper-grade.
#'
#' @param env environment caricato da \code{.load_ontology_dicts()}.
#' @return named list con elementi \code{chebi}, \code{hgnc}, \code{mesh}.
#' @keywords internal
.ontology_release_meta <- function(env = .load_ontology_dicts()) {
  list(
    chebi = env$chebi$meta,
    hgnc  = env$hgnc$meta,
    mesh  = env$mesh$meta,
    source_dir = env$source_dir,
    is_fixture = env$is_fixture
  )
}
