# ontology-lookup.R --- Loader e accessor deterministici per le 4 dictionary
# (ChEBI, HGNC, MeSH, ChEMBL) utilizzate dal resolver anchor v3.1.
#
# I dump pre-buildati (analysis/p5-audit-chebi-build-dict.R +
# analysis/p5-audit-hgnc-mesh-build-dict.R +
# analysis/p5-audit-chembl-build-dict.R) vivono in
# tools::R_user_dir("simulomicsr","cache")/chebi/ + .../hgnc-lookup.rds +
# .../mesh-lookup.rds + .../chembl/chembl-lookup.rds.
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

#' Carica ChEBI + HGNC + MeSH + ChEMBL dictionary in env singleton, memoizzato
#'
#' Costruisce hash environment per ogni indice rilevante (by_id, aliases,
#' secondary, has_role per ChEBI; by_hgnc_int, by_symbol_lower, by_entrez_int,
#' aliases_long per HGNC; by_ui, by_entry_lower per MeSH; by_id, aliases per
#' ChEMBL).
#'
#' @param refresh logical(1): se TRUE forza reload (anche se gia' caricato).
#' @param cache_dir character(1): directory contenente i RDS full (default
#'   \code{tools::R_user_dir("simulomicsr","cache")}). chebi/hgnc/mesh sono
#'   OBBLIGATORI (stop se mancano); chembl e' OPZIONALE (se manca, chembl=NULL
#'   + has_chembl=FALSE, comportamento retrocompat). Usato solo se
#'   \code{fixture_dir} e' NULL.
#' @param fixture_dir character(1) | NULL: se non-NULL, carica i mini-subset
#'   \code{chebi-mini.rds}, \code{hgnc-mini.rds}, \code{mesh-mini.rds},
#'   \code{chembl-mini.rds} da questa directory invece dei file full. Usato
#'   per i test.
#' @return environment con elementi \code{chebi}, \code{hgnc}, \code{mesh},
#'   \code{chembl} (NULL se assente nel ramo reale), \code{has_chembl} (logical),
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
    chebi_raw  <- readRDS(file.path(fixture_dir, "chebi-mini.rds"))
    hgnc_raw   <- readRDS(file.path(fixture_dir, "hgnc-mini.rds"))
    mesh_raw   <- readRDS(file.path(fixture_dir, "mesh-mini.rds"))
    chembl_raw <- readRDS(file.path(fixture_dir, "chembl-mini.rds"))
    has_chembl <- TRUE
    src_dir    <- fixture_dir
    is_fix     <- TRUE
  } else {
    chebi_path  <- file.path(cache_dir, "chebi", "chebi-lookup.rds")
    hgnc_path   <- file.path(cache_dir, "hgnc-lookup.rds")
    mesh_path   <- file.path(cache_dir, "mesh-lookup.rds")
    chembl_path <- file.path(cache_dir, "chembl", "chembl-lookup.rds")
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
    # ChEMBL e' opzionale: se non disponibile il loader continua senza errori.
    # Lo assert runtime e' rinviato agli script v5 che richiedono ChEMBL.
    if (file.exists(chembl_path)) {
      chembl_raw <- readRDS(chembl_path)
      has_chembl <- TRUE
    } else {
      chembl_raw <- NULL
      has_chembl <- FALSE
    }
    chebi_raw  <- readRDS(chebi_path)
    hgnc_raw   <- readRDS(hgnc_path)
    mesh_raw   <- readRDS(mesh_path)
    src_dir    <- cache_dir
    is_fix     <- FALSE
  }

  .ontology_env$chebi      <- .build_chebi_index(chebi_raw)
  .ontology_env$hgnc       <- .build_hgnc_index(hgnc_raw)
  .ontology_env$mesh       <- .build_mesh_index(mesh_raw)
  if (has_chembl) {
    .ontology_env$chembl   <- .build_chembl_index(chembl_raw)
  } else {
    .ontology_env$chembl   <- NULL
  }
  .ontology_env$has_chembl <- has_chembl
  .ontology_env$source_dir <- src_dir
  .ontology_env$is_fixture <- is_fix
  .ontology_env$loaded     <- TRUE
  .ontology_env
}

#' @noRd
.build_chebi_index <- function(chebi_raw) {
  # by_id: hash env chebi_int (as character) -> named list compound metadata.
  # PERF: pre-estraggo vettori una volta (la per-row tibble subset e' ~10-20x
  # piu' lenta su 205k rows).
  by_id_env <- new.env(hash = TRUE, parent = emptyenv(),
                       size = max(nrow(chebi_raw$by_id), 1L))
  if (nrow(chebi_raw$by_id) > 0L) {
    bi <- chebi_raw$by_id
    ids <- as.integer(bi$chebi_id)
    pn  <- bi$primary_name
    an  <- bi$ascii_name
    st  <- as.integer(bi$stars)
    de  <- bi$definition
    ob  <- bi$is_obsolete
    pa  <- bi$parent_id
    ns  <- length(ids)
    for (i in seq_len(ns)) {
      assign(
        as.character(ids[i]),
        list(
          chebi_id     = ids[i],
          primary_name = pn[i],
          ascii_name   = an[i],
          stars        = st[i],
          definition   = de[i],
          is_obsolete  = isTRUE(ob[i]),
          parent_id    = if (is.na(pa[i])) NA_integer_ else as.integer(pa[i])
        ),
        envir = by_id_env
      )
    }
  }

  # aliases: hash env alias_lower -> named list (chebi_id, type). Prima vittoria
  # vince (rare duplicates dove un alias mappa a piu' compound -- accettiamo).
  aliases_env <- new.env(hash = TRUE, parent = emptyenv(),
                         size = max(nrow(chebi_raw$aliases), 1L))
  if (nrow(chebi_raw$aliases) > 0L) {
    al <- chebi_raw$aliases
    keys <- al$alias_lower
    cids <- as.integer(al$chebi_id)
    types <- al$type
    for (i in seq_along(keys)) {
      k <- keys[i]
      if (!exists(k, envir = aliases_env, inherits = FALSE)) {
        assign(k, list(chebi_id = cids[i], type = types[i]),
               envir = aliases_env)
      }
    }
  }

  # secondary: hash env secondary_id (as character) -> primary_id integer
  secondary_env <- new.env(hash = TRUE, parent = emptyenv(),
                           size = max(nrow(chebi_raw$secondary), 1L))
  if (nrow(chebi_raw$secondary) > 0L) {
    se <- chebi_raw$secondary
    sids <- as.character(se$secondary_id)
    pids <- as.integer(se$primary_id)
    for (i in seq_along(sids)) {
      assign(sids[i], pids[i], envir = secondary_env)
    }
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
  # by_hgnc_int: chr(hgnc_int) -> named list gene metadata. Pre-extract vectors.
  by_hgnc_env <- new.env(hash = TRUE, parent = emptyenv(),
                         size = max(nrow(hgnc_raw$by_hgnc_int), 1L))
  if (nrow(hgnc_raw$by_hgnc_int) > 0L) {
    bh <- hgnc_raw$by_hgnc_int
    h_int  <- as.integer(bh$hgnc_int)
    h_id   <- bh$hgnc_id
    h_sym  <- bh$symbol
    h_nm   <- bh$name
    h_lg   <- bh$locus_group
    h_lt   <- bh$locus_type
    h_st   <- bh$status
    h_ent  <- bh$entrez_int
    h_ens  <- bh$ensembl_gene_id
    ns <- length(h_int)
    for (i in seq_len(ns)) {
      assign(
        as.character(h_int[i]),
        list(
          hgnc_int        = h_int[i],
          hgnc_id         = h_id[i],
          symbol          = h_sym[i],
          name            = h_nm[i],
          locus_group     = h_lg[i],
          locus_type      = h_lt[i],
          status          = h_st[i],
          entrez_int      = if (is.na(h_ent[i])) NA_integer_ else as.integer(h_ent[i]),
          ensembl_gene_id = h_ens[i]
        ),
        envir = by_hgnc_env
      )
    }
  }

  # by_entrez_int: chr(entrez_int) -> named list (hgnc_int, symbol)
  by_entrez_env <- new.env(hash = TRUE, parent = emptyenv(),
                           size = max(nrow(hgnc_raw$by_entrez_int), 1L))
  if (nrow(hgnc_raw$by_entrez_int) > 0L) {
    be <- hgnc_raw$by_entrez_int
    e_int <- as.integer(be$entrez_int)
    e_h   <- as.integer(be$hgnc_int)
    e_sym <- be$symbol
    e_nm  <- be$name
    for (i in seq_along(e_int)) {
      assign(
        as.character(e_int[i]),
        list(
          entrez_int = e_int[i],
          hgnc_int   = e_h[i],
          symbol     = e_sym[i],
          name       = e_nm[i]
        ),
        envir = by_entrez_env
      )
    }
  }

  # by_symbol_lower: chr(symbol_lower) -> named list (hgnc_int, primary_symbol)
  # Include primary symbols PLUS alias_lower (per supporto alias resolution).
  by_symbol_env <- new.env(hash = TRUE, parent = emptyenv(),
                           size = max(nrow(hgnc_raw$by_symbol_lower) +
                                      nrow(hgnc_raw$aliases_long), 1L))
  if (nrow(hgnc_raw$by_symbol_lower) > 0L) {
    bs <- hgnc_raw$by_symbol_lower
    s_low <- bs$symbol_lower
    s_h   <- as.integer(bs$hgnc_int)
    s_sym <- bs$symbol
    for (i in seq_along(s_low)) {
      assign(
        s_low[i],
        list(hgnc_int = s_h[i], primary_symbol = s_sym[i], match_type = "PRIMARY"),
        envir = by_symbol_env
      )
    }
  }
  # Aliases (non-conflicting: primary wins se collision)
  if (nrow(hgnc_raw$aliases_long) > 0L) {
    al <- hgnc_raw$aliases_long
    a_low <- al$alias_lower
    a_h   <- as.integer(al$hgnc_int)
    a_sym <- al$primary_symbol
    for (i in seq_along(a_low)) {
      k <- a_low[i]
      if (!exists(k, envir = by_symbol_env, inherits = FALSE)) {
        assign(
          k,
          list(hgnc_int = a_h[i], primary_symbol = a_sym[i], match_type = "ALIAS"),
          envir = by_symbol_env
        )
      }
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
  # by_ui: chr(ui) -> named list (mh, tree_top, tree_branches). Pre-extract.
  by_ui_env <- new.env(hash = TRUE, parent = emptyenv(),
                       size = max(nrow(mesh_raw$by_ui), 1L))
  if (nrow(mesh_raw$by_ui) > 0L) {
    bu <- mesh_raw$by_ui
    u_ui <- bu$ui
    u_mh <- bu$mh
    u_tt <- bu$tree_top
    u_tb <- bu$tree_branches
    for (i in seq_along(u_ui)) {
      assign(
        u_ui[i],
        list(ui = u_ui[i], mh = u_mh[i], tree_top = u_tt[i],
             tree_branches = u_tb[i]),
        envir = by_ui_env
      )
    }
  }

  # by_entry_lower: chr(entry_lower) -> named list (ui)
  by_entry_env <- new.env(hash = TRUE, parent = emptyenv(),
                          size = max(nrow(mesh_raw$by_entry_lower), 1L))
  if (nrow(mesh_raw$by_entry_lower) > 0L) {
    be <- mesh_raw$by_entry_lower
    e_low <- be$entry_lower
    e_ui  <- be$ui
    for (i in seq_along(e_low)) {
      k <- e_low[i]
      if (!exists(k, envir = by_entry_env, inherits = FALSE)) {
        assign(k, list(ui = e_ui[i]), envir = by_entry_env)
      }
    }
  }

  list(
    by_ui          = by_ui_env,
    by_entry_lower = by_entry_env,
    meta           = list(n_descriptors = nrow(mesh_raw$by_ui))
  )
}

#' @noRd
.build_chembl_index <- function(chembl_raw) {
  # by_id: hash env chembl_id (character) -> named list (chembl_id, pref_name).
  # Pre-estraggo vettori una volta per evitare per-row tibble subset (O(1) finale).
  by_id_env <- new.env(hash = TRUE, parent = emptyenv(),
                       size = max(nrow(chembl_raw$by_id), 1L))
  if (nrow(chembl_raw$by_id) > 0L) {
    bi  <- chembl_raw$by_id
    cid <- as.character(bi$chembl_id)
    pn  <- bi$pref_name
    for (i in seq_along(cid)) {
      assign(cid[i], list(chembl_id = cid[i], pref_name = pn[i]),
             envir = by_id_env)
    }
  }

  # aliases: hash env alias_lower -> named list (chembl_id, type).
  # Prima vittoria vince (rare duplicates dove un alias mappa a piu' molecole).
  aliases_env <- new.env(hash = TRUE, parent = emptyenv(),
                         size = max(nrow(chembl_raw$aliases), 1L))
  if (nrow(chembl_raw$aliases) > 0L) {
    al   <- chembl_raw$aliases
    keys <- al$alias_lower
    cids <- as.character(al$chembl_id)
    types <- al$type
    for (i in seq_along(keys)) {
      k <- keys[i]
      if (!exists(k, envir = aliases_env, inherits = FALSE)) {
        assign(k, list(chembl_id = cids[i], type = types[i]),
               envir = aliases_env)
      }
    }
  }

  list(by_id = by_id_env, aliases = aliases_env, meta = chembl_raw$meta)
}

# --- ImmPort -----------------------------------------------------------------
#
# Indice e accessor per il registro ImmPort (citochine, sinonimi -> HGNC).
# Raw atteso: lista con elementi:
#   $synonyms:         data.frame con colonne syn_norm (stringa gia' normalizzata),
#                      hgnc_int (integer), primary_symbol (character),
#                      reference_name (character)
#   $cytokine_hgnc_int: integer vector = whitelist HGNC ID riconosciuti come
#                       citochine (unione registry + lkProteinName + GO)
#   $meta:             lista metadati di release (as-is)
#
# .normalize_biological_mention (da stage3-name-recovery.R) viene applicata
# ai termini di lookup per collassare grafie diverse (es. "IFN-beta" -> "ifnbeta").
# Le chiavi syn_norm nel fixture DEVONO essere gia' pre-normalizzate con la
# stessa funzione al momento della build del dizionario full.

#' @noRd
.build_immport_index <- function(immport_raw) {
  # by_synonym: hash env syn_norm (stringa pre-normalizzata) ->
  #   named list (hgnc_int, primary_symbol, reference_name).
  # Prima voce per ogni chiave vince (sinonimi multipli per stesso gene ok).
  syn <- immport_raw$synonyms
  by_syn <- new.env(hash = TRUE, parent = emptyenv(),
                    size = max(nrow(syn), 1L))
  if (nrow(syn) > 0L) {
    keys <- syn$syn_norm
    h    <- as.integer(syn$hgnc_int)
    sym  <- syn$primary_symbol
    ref  <- syn$reference_name
    for (i in seq_along(keys)) {
      k <- keys[i]
      if (!is.na(k) && nzchar(k) &&
          !exists(k, envir = by_syn, inherits = FALSE)) {
        assign(k,
               list(hgnc_int      = h[i],
                    primary_symbol = sym[i],
                    reference_name = ref[i]),
               envir = by_syn)
      }
    }
  }

  # cytokine_symbols: hash env-SET as.character(hgnc_int) -> TRUE.
  # Lookup O(1) via exists(as.character(hgnc_int), envir=cytokine_symbols).
  wl  <- as.integer(immport_raw$cytokine_hgnc_int)
  cyt <- new.env(hash = TRUE, parent = emptyenv(), size = max(length(wl), 1L))
  for (id in wl[!is.na(wl)]) {
    assign(as.character(id), TRUE, envir = cyt)
  }

  list(by_synonym      = by_syn,
       cytokine_symbols = cyt,
       meta            = immport_raw$meta)
}

#' Cerca un termine biologico nell'indice ImmPort (sinonimi citochine).
#'
#' Normalizza il termine con \code{.normalize_biological_mention} prima del
#' lookup, cosi' grafie diverse della stessa citochina collassano sulla stessa
#' chiave (es. "IFN-beta", "IFN-B", "interferonbeta" -> "ifnbeta").
#'
#' @param term character(1) termine da cercare (forma originale o sinonimo).
#' @param env environment con elemento \code{$immport} (output di
#'   \code{.build_immport_index}). Default: \code{.load_ontology_dicts()}.
#' @return named list con elementi \code{hgnc_int} (integer),
#'   \code{primary_symbol} (character), \code{reference_name} (character);
#'   oppure \code{NULL} su miss o env privo di immport.
#' @noRd
.immport_lookup_synonym <- function(term, env = .load_ontology_dicts()) {
  imp <- env$immport
  if (is.null(imp)) return(NULL)
  k <- .normalize_biological_mention(term)   # "" su NA/vuoto/lunghezza!=1
  if (!nzchar(k)) return(NULL)
  if (!exists(k, envir = imp$by_synonym, inherits = FALSE)) return(NULL)
  get(k, envir = imp$by_synonym, inherits = FALSE)
}

#' Verifica se un HGNC ID e' nella whitelist citochine ImmPort.
#'
#' @param hgnc_int integer(1) HGNC ID numerico (senza prefisso "HGNC:").
#' @param env environment con elemento \code{$immport}. Default:
#'   \code{.load_ontology_dicts()}.
#' @return logical(1): TRUE se hgnc_int e' nella whitelist, FALSE altrimenti
#'   (incluso env privo di immport o hgnc_int NA/NULL).
#' @noRd
.is_cytokine_symbol <- function(hgnc_int, env = .load_ontology_dicts()) {
  imp <- env$immport
  if (is.null(imp)) return(FALSE)
  if (length(hgnc_int) != 1L) return(FALSE)
  if (is.na(hgnc_int)) return(FALSE)
  exists(as.character(as.integer(hgnc_int)), envir = imp$cytokine_symbols,
         inherits = FALSE)
}

# --- NCBI Taxonomy -----------------------------------------------------------
#
# Indice e accessor per dizionario patogeni nome->taxid.
# Raw atteso: lista con elementi:
#   $names: data.frame con colonne name_norm, taxid (integer), name_class
#   $nodes: data.frame con colonne taxid (integer), parent_taxid (integer), rank
#   $meta:  lista con metadati di release (as-is)
#
# .normalize_biological_mention (definita in stage3-name-recovery.R) viene
# applicata alle chiavi di lookup per collassare grafie diverse dello stesso
# patogeno (es. "SARS-CoV-2" -> "sarscov2").

#' @noRd
.build_taxonomy_index <- function(taxonomy_raw) {
  # by_name: hash env name_norm (stringa canonica) -> list(taxid, name_class)
  # Prima voce per ogni chiave vince (sinonimi multipli per stesso taxid ok).
  by_name <- new.env(hash = TRUE, parent = emptyenv(),
                     size = max(nrow(taxonomy_raw$names), 1L))
  nm <- taxonomy_raw$names
  if (nrow(nm) > 0L) {
    for (i in seq_len(nrow(nm))) {
      k <- nm$name_norm[i]
      if (!is.na(k) && nzchar(k) &&
          !exists(k, envir = by_name, inherits = FALSE)) {
        assign(k, list(taxid      = as.integer(nm$taxid[i]),
                       name_class = nm$name_class[i]),
               envir = by_name)
      }
    }
  }

  # by_taxid: hash env as.character(taxid) -> list(parent_taxid, rank, scientific_name)
  # scientific_name estratto da by_name (righe "scientific name") per taxid.
  nd <- taxonomy_raw$nodes
  sci_idx <- which(nm$name_class == "scientific name")
  sci_by  <- stats::setNames(nm$name_norm[sci_idx], as.character(nm$taxid[sci_idx]))

  by_taxid <- new.env(hash = TRUE, parent = emptyenv(),
                      size = max(nrow(nd), 1L))
  if (nrow(nd) > 0L) {
    for (i in seq_len(nrow(nd))) {
      tid_key <- as.character(nd$taxid[i])
      assign(tid_key,
             list(parent_taxid   = as.integer(nd$parent_taxid[i]),
                  rank           = nd$rank[i],
                  scientific_name = unname(sci_by[tid_key])),
             envir = by_taxid)
    }
  }

  list(by_name = by_name, by_taxid = by_taxid, meta = taxonomy_raw$meta)
}

#' Cerca un termine biologico nell'indice NCBI Taxonomy.
#'
#' Normalizza il termine con \code{.normalize_biological_mention} prima del
#' lookup, cosi' grafie diverse dello stesso patogeno collassano sulla stessa
#' chiave.
#'
#' @param term character(1) nome del patogeno (forma originale, tolower, sinonimo).
#' @param env environment con elemento \code{$taxonomy} (output di
#'   \code{.build_taxonomy_index}). Default: \code{.load_ontology_dicts()}.
#' @return named list con elementi \code{taxid} (integer), \code{scientific_name}
#'   (character), \code{name_class} (character); oppure \code{NULL} su miss.
#' @noRd
.taxonomy_lookup_name <- function(term, env = .load_ontology_dicts()) {
  tax <- env$taxonomy
  if (is.null(tax)) return(NULL)
  k <- .normalize_biological_mention(term)   # "" su NA/vuoto/lunghezza!=1
  if (!nzchar(k)) return(NULL)
  if (!exists(k, envir = tax$by_name, inherits = FALSE)) return(NULL)
  hit  <- get(k, envir = tax$by_name, inherits = FALSE)
  tid  <- as.character(hit$taxid)
  node <- if (exists(tid, envir = tax$by_taxid, inherits = FALSE))
            get(tid, envir = tax$by_taxid, inherits = FALSE) else NULL
  list(taxid          = hit$taxid,
       scientific_name = if (!is.null(node)) node$scientific_name else NA_character_,
       name_class     = hit$name_class)
}

#' Risale l'albero tassonomico fino al rango "species".
#'
#' Se il taxid di partenza e' gia' a livello specie, ritorna se stesso.
#' Se non esiste nell'indice o non si raggiunge alcuna specie entro 50 passi,
#' ritorna il taxid originale (comportamento difensivo: non crasha).
#'
#' @param taxid integer(1) taxid di partenza.
#' @param env environment con elemento \code{$taxonomy}. Default:
#'   \code{.load_ontology_dicts()}.
#' @return integer(1) taxid a livello specie (o taxid originale se non trovato).
#' @noRd
.taxonomy_rollup_to_species <- function(taxid, env = .load_ontology_dicts()) {
  tax <- env$taxonomy
  if (is.null(tax)) return(as.integer(taxid))
  cur   <- as.integer(taxid)
  guard <- 0L
  while (guard < 50L) {
    tid_key <- as.character(cur)
    if (!exists(tid_key, envir = tax$by_taxid, inherits = FALSE)) break
    node <- get(tid_key, envir = tax$by_taxid, inherits = FALSE)
    if (identical(node$rank, "species")) return(cur)
    pt <- as.integer(node$parent_taxid)
    if (is.na(pt) || pt == cur) break
    cur   <- pt
    guard <- guard + 1L
  }
  as.integer(taxid)  # nessuna specie raggiunta: ritorna taxid originale
}

# --- ChEBI accessor ----------------------------------------------------------
#
# Tutti gli accessor sono defensive: gestiscono input NULL, NA, character(0),
# vettori multi-elem, tipi non-character. Real-world LLM JSON puo' produrre
# ognuno di questi; il safe-path e' tornare NULL/character(0) invece di
# propagare un errore dentro un loop di clustering.

#' @noRd
.normalize_key_chr <- function(x) {
  if (is.null(x)) return(NA_character_)
  if (length(x) == 0L) return(NA_character_)
  if (length(x) > 1L) x <- x[[1L]]
  if (is.null(x) || length(x) == 0L) return(NA_character_)
  if (is.na(x)) return(NA_character_)
  if (!is.character(x)) x <- tryCatch(as.character(x), error = function(e) NA_character_)
  if (length(x) != 1L) return(NA_character_)
  if (is.na(x) || !nzchar(x)) return(NA_character_)
  x
}

#' @noRd
.chebi_lookup_id <- function(chebi_int, env = .load_ontology_dicts()) {
  key <- .normalize_key_chr(chebi_int)
  if (is.na(key)) return(NULL)
  if (!exists(key, envir = env$chebi$by_id, inherits = FALSE)) return(NULL)
  get(key, envir = env$chebi$by_id, inherits = FALSE)
}

#' @noRd
.chebi_lookup_alias <- function(alias, env = .load_ontology_dicts()) {
  raw <- .normalize_key_chr(alias)
  if (is.na(raw)) return(NULL)
  key <- tolower(raw)
  if (!exists(key, envir = env$chebi$aliases, inherits = FALSE)) return(NULL)
  get(key, envir = env$chebi$aliases, inherits = FALSE)
}

#' @noRd
.chebi_roles <- function(chebi_int, env = .load_ontology_dicts()) {
  key <- .normalize_key_chr(chebi_int)
  if (is.na(key)) return(character(0))
  if (!exists(key, envir = env$chebi$has_role, inherits = FALSE)) return(character(0))
  get(key, envir = env$chebi$has_role, inherits = FALSE)
}

#' @noRd
.chebi_secondary_redirect <- function(chebi_int, env = .load_ontology_dicts()) {
  key <- .normalize_key_chr(chebi_int)
  if (is.na(key)) return(NULL)
  if (!exists(key, envir = env$chebi$secondary, inherits = FALSE)) return(NULL)
  get(key, envir = env$chebi$secondary, inherits = FALSE)
}

# --- HGNC accessor -----------------------------------------------------------

#' @noRd
.hgnc_lookup_hgnc <- function(hgnc_int, env = .load_ontology_dicts()) {
  key <- .normalize_key_chr(hgnc_int)
  if (is.na(key)) return(NULL)
  if (!exists(key, envir = env$hgnc$by_hgnc_int, inherits = FALSE)) return(NULL)
  get(key, envir = env$hgnc$by_hgnc_int, inherits = FALSE)
}

#' @noRd
.hgnc_lookup_entrez <- function(entrez_int, env = .load_ontology_dicts()) {
  key <- .normalize_key_chr(entrez_int)
  if (is.na(key)) return(NULL)
  if (!exists(key, envir = env$hgnc$by_entrez_int, inherits = FALSE)) return(NULL)
  get(key, envir = env$hgnc$by_entrez_int, inherits = FALSE)
}

#' @noRd
.hgnc_lookup_symbol <- function(symbol, env = .load_ontology_dicts()) {
  raw <- .normalize_key_chr(symbol)
  if (is.na(raw)) return(NULL)
  key <- tolower(raw)
  if (!exists(key, envir = env$hgnc$by_symbol_lower, inherits = FALSE)) return(NULL)
  get(key, envir = env$hgnc$by_symbol_lower, inherits = FALSE)
}

# --- MeSH accessor -----------------------------------------------------------

#' @noRd
.mesh_lookup_ui <- function(ui_str, env = .load_ontology_dicts()) {
  key <- .normalize_key_chr(ui_str)
  if (is.na(key)) return(NULL)
  if (!exists(key, envir = env$mesh$by_ui, inherits = FALSE)) return(NULL)
  get(key, envir = env$mesh$by_ui, inherits = FALSE)
}

#' @noRd
.mesh_lookup_term <- function(term, env = .load_ontology_dicts()) {
  raw <- .normalize_key_chr(term)
  if (is.na(raw)) return(NULL)
  key <- tolower(raw)
  if (!exists(key, envir = env$mesh$by_entry_lower, inherits = FALSE)) return(NULL)
  get(key, envir = env$mesh$by_entry_lower, inherits = FALSE)
}

# --- ChEMBL accessor ---------------------------------------------------------

#' @noRd
.chembl_lookup_alias <- function(alias, env = .load_ontology_dicts()) {
  if (is.null(env$chembl)) return(NULL)
  raw <- .normalize_key_chr(alias)
  if (is.na(raw)) return(NULL)
  key <- tolower(raw)
  if (!exists(key, envir = env$chembl$aliases, inherits = FALSE)) return(NULL)
  get(key, envir = env$chembl$aliases, inherits = FALSE)
}

#' @noRd
.chembl_lookup_id <- function(chembl_id, env = .load_ontology_dicts()) {
  if (is.null(env$chembl)) return(NULL)
  key <- .normalize_key_chr(chembl_id)
  if (is.na(key)) return(NULL)
  if (!exists(key, envir = env$chembl$by_id, inherits = FALSE)) return(NULL)
  get(key, envir = env$chembl$by_id, inherits = FALSE)
}

# --- UniProt -----------------------------------------------------------------
#
# Indice e accessor per il dizionario UniProt (sinonimi proteina -> HGNC).
# Raw atteso: lista con elementi:
#   $names: data.frame con colonne name_norm (stringa gia' normalizzata),
#           accession (character), hgnc_int (integer)
#   $meta:  lista con metadati di release (as-is)
#
# .normalize_biological_mention (da stage3-name-recovery.R) viene applicata
# ai termini di lookup per collassare grafie diverse (es. "IFN-beta" -> "ifnbeta").
# Le chiavi name_norm nel fixture DEVONO essere gia' pre-normalizzate con la
# stessa funzione al momento della build del dizionario full.

#' @noRd
.build_uniprot_index <- function(uniprot_raw) {
  # by_name: hash env name_norm (stringa pre-normalizzata) ->
  #   named list (accession, hgnc_int).
  # Prima voce per ogni chiave vince (sinonimi multipli per stessa proteina ok).
  nm <- uniprot_raw$names
  by_name <- new.env(hash = TRUE, parent = emptyenv(),
                     size = max(nrow(nm), 1L))
  if (nrow(nm) > 0L) {
    keys <- nm$name_norm
    acc  <- nm$accession
    hid  <- as.integer(nm$hgnc_int)
    for (i in seq_along(keys)) {
      k <- keys[i]
      if (!is.na(k) && nzchar(k) &&
          !exists(k, envir = by_name, inherits = FALSE)) {
        assign(k,
               list(accession = acc[i],
                    hgnc_int  = hid[i]),
               envir = by_name)
      }
    }
  }

  list(by_name = by_name,
       meta    = uniprot_raw$meta)
}

#' Cerca un termine biologico nell'indice UniProt (sinonimi proteina).
#'
#' Normalizza il termine con \code{.normalize_biological_mention} prima del
#' lookup, cosi' grafie diverse della stessa proteina collassano sulla stessa
#' chiave (es. "IFN-beta", "interferonbeta" -> "ifnbeta").
#'
#' @param term character(1) termine da cercare (forma originale o sinonimo).
#' @param env environment con elemento \code{$uniprot} (output di
#'   \code{.build_uniprot_index}). Default: \code{.load_ontology_dicts()}.
#' @return named list con elementi \code{accession} (character),
#'   \code{hgnc_int} (integer); oppure \code{NULL} su miss o env privo di uniprot.
#' @noRd
.uniprot_lookup_name <- function(term, env = .load_ontology_dicts()) {
  uni <- env$uniprot
  if (is.null(uni)) return(NULL)
  k <- .normalize_biological_mention(term)   # "" su NA/vuoto/lunghezza!=1
  if (!nzchar(k)) return(NULL)
  if (!exists(k, envir = uni$by_name, inherits = FALSE)) return(NULL)
  get(k, envir = uni$by_name, inherits = FALSE)
}

# --- Release meta ------------------------------------------------------------

#' Restituisce metadata di release delle 4 dictionary correnti
#'
#' Usato da \code{build_stage3_clusters()} per registrare \code{ontology_releases}
#' nel \code{run_metadata.json}, garantendo riproducibilita' paper-grade.
#'
#' @param env environment caricato da \code{.load_ontology_dicts()}.
#' @return named list con elementi \code{chebi}, \code{hgnc}, \code{mesh},
#'   \code{chembl}.
#' @keywords internal
.ontology_release_meta <- function(env = .load_ontology_dicts()) {
  list(
    chebi      = env$chebi$meta,
    hgnc       = env$hgnc$meta,
    mesh       = env$mesh$meta,
    chembl     = if (!is.null(env$chembl)) env$chembl$meta else NULL,
    source_dir = env$source_dir,
    is_fixture = env$is_fixture
  )
}
