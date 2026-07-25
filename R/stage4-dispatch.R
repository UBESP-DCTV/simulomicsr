#' Parsa anchor_key di cluster pair-mode in treated/control + control_type
#'
#' Stage 3 codifica i pair anchor_key come \code{"<tk>__VS__<ck>"} a L2-L4 e
#' \code{"<tk>__VS__<ck>__CT_<control_type>"} a L0-L1 (vedi
#' \code{.summarize_clusters} in \code{R/stage3-build.R}). Questa helper inverte
#' la codifica per consentire al pool MEGA-AUG di reperire i baseline group
#' cluster con stesso \code{control_anchor_key}.
#'
#' @param anchor_key stringa \code{anchor_key} di un pair-cluster.
#' @param level integer L0..L4 (necessario per sapere se cercare \code{__CT_}).
#' @return list con \code{treated} (chr), \code{control} (chr),
#'   \code{control_type} (chr, NA per L>=2 o anchor malformati).
#' @keywords internal
.parse_pair_anchor_key <- function(anchor_key, level) {
  if (is.null(anchor_key) || is.na(anchor_key) || !nzchar(anchor_key)) {
    return(list(treated = NA_character_, control = NA_character_,
                control_type = NA_character_))
  }
  ct <- NA_character_
  s  <- anchor_key
  if (isTRUE(level %in% c(0L, 1L))) {
    # Greedy strip dell'ultimo "__CT_<ctype>" suffix.
    m <- regexpr("__CT_[^_].*$", s)
    if (m > 0L) {
      ct <- sub("^__CT_", "", regmatches(s, m))
      s  <- sub("__CT_[^_].*$", "", s)
    }
  }
  parts <- strsplit(s, "__VS__", fixed = TRUE)[[1L]]
  if (length(parts) != 2L) {
    return(list(treated = NA_character_, control = NA_character_,
                control_type = NA_character_))
  }
  list(treated = parts[1L], control = parts[2L], control_type = ct)
}

#' Indice stage2_master per series_id (O(1) lookup via environment hash)
#'
#' @keywords internal
.index_stage2_master <- function(stage2_master) {
  env <- new.env(hash = TRUE,
                 size = max(1L, length(stage2_master)),
                 parent = emptyenv())
  for (s in stage2_master) {
    if (is.null(s$series_id)) next
    assign(s$series_id, s, envir = env)
  }
  env
}

#' Lookup replicate_group da study via group_id
#'
#' @keywords internal
.lookup_rg <- function(study, group_id) {
  for (rg in study$replicate_groups) {
    if (identical(rg$group_id, group_id)) return(rg)
  }
  NULL
}

#' Lookup comparison da study via comparison_id
#'
#' @keywords internal
.lookup_cmp <- function(study, comparison_id) {
  for (cmp in study$comparisons) {
    if (identical(cmp$comparison_id, comparison_id)) return(cmp)
  }
  NULL
}

#' Split record_id in (series_id, suffix) sul primo "__"
#'
#' I record_id sono \code{sprintf("\%s__\%s", series_id, comparison_id|group_id)}
#' (\code{R/stage3-build.R}). I comparison_id / group_id possono contenere
#' ulteriori \code{"__"}: l'unica garanzia e' che \code{series_id} non contiene
#' \code{"__"} (GSE seguono il pattern \code{GSE<n>}).
#'
#' @keywords internal
.split_record_id <- function(record_id) {
  parts <- regmatches(record_id, regexpr("__", record_id), invert = TRUE)[[1L]]
  if (length(parts) < 2L) return(list(series_id = NA_character_,
                                      suffix    = NA_character_))
  list(series_id = parts[1L], suffix = parts[2L])
}

#' Costruisce study_dispatch per cluster pair-mode (REM + MEGA-AUG)
#'
#' Mappa ogni cluster_id pair-mode (method \code{rem} o \code{mega_aug}) in una
#' lista di per-study record \code{{study_id, treated, control}}. Il dispatch
#' viene attaccato come \code{attr(eligible_clusters, "study_dispatch")} ed e'
#' consumato da \code{.run_per_study_de_all} e dal ramo REM di
#' \code{.pool_all_clusters}.
#'
#' I sample IDs sono risolti da \code{stage2_master} via lookup
#' \code{replicate_groups}: assignment \code{record_id =
#' "<series>__<comparison_id>"} -> study\$comparisons -> treated_group +
#' control_group -> sample_ids.
#'
#' @param eligible_clusters tibble Layer A (output di
#'   \code{.qc_filter_samples_and_studies}) con colonna \code{method}.
#' @param stage3_assignments tibble \code{assignments.parquet} Stage 3.
#' @param stage2_master list di study records (output di
#'   \code{.load_stage2_master}).
#' @return named list (cluster_id -> list di \code{{study_id, treated,
#'   control}}). Cluster senza record validi sono omessi.
#' @keywords internal
.build_study_dispatch_from_stage3 <- function(eligible_clusters,
                                                stage3_assignments,
                                                stage2_master) {
  pair_clusters <- eligible_clusters[
    eligible_clusters$mode == "pair" &
      eligible_clusters$method %in% c("rem", "mega_aug"),
  ]
  if (nrow(pair_clusters) == 0L) return(list())

  s2_idx <- .index_stage2_master(stage2_master)
  asg_by_clid <- split(stage3_assignments$record_id,
                       stage3_assignments$cluster_id)

  dispatch <- vector("list", 0L)
  for (i in seq_len(nrow(pair_clusters))) {
    cid <- pair_clusters$cluster_id[i]
    record_ids <- asg_by_clid[[cid]]
    if (is.null(record_ids) || length(record_ids) == 0L) next

    cluster_dispatch <- vector("list", 0L)
    for (rid in record_ids) {
      parsed <- .split_record_id(rid)
      if (is.na(parsed$series_id)) next
      if (!exists(parsed$series_id, envir = s2_idx, inherits = FALSE)) next
      study <- get(parsed$series_id, envir = s2_idx, inherits = FALSE)
      cmp <- .lookup_cmp(study, parsed$suffix)
      if (is.null(cmp)) next

      tg <- .lookup_rg(study, cmp$treated_group)
      cg <- .lookup_rg(study, cmp$control_group)
      if (is.null(tg) || is.null(cg)) next

      cluster_dispatch[[length(cluster_dispatch) + 1L]] <- list(
        study_id = parsed$series_id,
        treated  = as.character(unlist(tg$sample_ids)),
        control  = as.character(unlist(cg$sample_ids))
      )
    }
    if (length(cluster_dispatch) > 0L) {
      dispatch[[cid]] <- cluster_dispatch
    }
  }
  dispatch
}

#' Costruisce group_dispatch per cluster group-mode (MEGA pure)
#'
#' Mappa ogni cluster_id group-mode (method \code{mega}) in una lista di
#' per-study record \code{{study_id, sample_ids, treatment}}.
#'
#' Il dispatch e' attaccato come \code{attr(eligible_clusters, "group_dispatch")}
#' e consumato dal ramo \code{mega} di \code{.pool_all_clusters} per assemblare
#' la design matrix \code{~treatment + (1|study)} di dream. Group con
#' \code{primary_role} diverso da \code{treated} / \code{control} sono
#' silently esclusi (bystander/excluded/unclear non hanno semantica utilizzabile
#' per la contrast).
#'
#' @inheritParams .build_study_dispatch_from_stage3
#' @return named list (cluster_id -> list di \code{{study_id, sample_ids,
#'   treatment}}). \code{treatment} e' un character vector per-sample,
#'   valori in \code{c("control", "treated")}.
#' @keywords internal
.build_group_dispatch_from_stage3 <- function(eligible_clusters,
                                                stage3_assignments,
                                                stage2_master) {
  group_clusters <- eligible_clusters[
    eligible_clusters$mode == "group" &
      eligible_clusters$method == "mega",
  ]
  if (nrow(group_clusters) == 0L) return(list())

  s2_idx <- .index_stage2_master(stage2_master)
  asg_by_clid <- split(stage3_assignments$record_id,
                       stage3_assignments$cluster_id)

  dispatch <- vector("list", 0L)
  for (i in seq_len(nrow(group_clusters))) {
    cid <- group_clusters$cluster_id[i]
    record_ids <- asg_by_clid[[cid]]
    if (is.null(record_ids) || length(record_ids) == 0L) next

    cluster_dispatch <- vector("list", 0L)
    for (rid in record_ids) {
      parsed <- .split_record_id(rid)
      if (is.na(parsed$series_id)) next
      if (!exists(parsed$series_id, envir = s2_idx, inherits = FALSE)) next
      study <- get(parsed$series_id, envir = s2_idx, inherits = FALSE)
      rg <- .lookup_rg(study, parsed$suffix)
      if (is.null(rg)) next

      role <- rg$primary_role %||% NA_character_
      if (is.na(role) || !role %in% c("treated", "control")) next

      sids <- as.character(unlist(rg$sample_ids))
      if (length(sids) == 0L) next

      cluster_dispatch[[length(cluster_dispatch) + 1L]] <- list(
        study_id   = parsed$series_id,
        sample_ids = sids,
        treatment  = rep(role, length(sids))
      )
    }
    if (length(cluster_dispatch) > 0L) {
      dispatch[[cid]] <- cluster_dispatch
    }
  }
  dispatch
}

#' Arricchisce stage3_clusters con sample_ids + sample_studies list-columns
#'
#' Stage 3 clusters.rds non contiene il mapping sample -> series_id (i sample
#' IDs vivono in assignments+stage2_master). Per il pool MEGA-AUG,
#' \code{.assemble_mega_aug_metadata} necessita sia di \code{sample_ids} (per
#' costruire il baseline pool) sia di \code{sample_studies} (per assegnare ogni
#' baseline sample al suo studio reale invece di una rep ciclica su
#' \code{studies_in_cluster}). Le due list-columns sono PARALLELE per indice.
#'
#' Per pair-mode rows entrambe sono \code{character(0L)} (placeholder typed).
#'
#' @inheritParams .build_study_dispatch_from_stage3
#' @param stage3_clusters tibble \code{clusters.rds} Stage 3.
#' @return tibble identica a \code{stage3_clusters} con extra list-columns
#'   \code{sample_ids} + \code{sample_studies} (parallele).
#' @keywords internal
.enrich_group_baseline_sample_ids <- function(stage3_clusters,
                                                stage3_assignments,
                                                stage2_master) {
  s2_idx <- .index_stage2_master(stage2_master)
  asg_by_clid <- split(stage3_assignments$record_id,
                       stage3_assignments$cluster_id)

  n <- nrow(stage3_clusters)
  sample_ids_col     <- vector("list", n)
  sample_studies_col <- vector("list", n)
  for (i in seq_len(n)) {
    if (!identical(as.character(stage3_clusters$mode[i]), "group")) {
      sample_ids_col[[i]]     <- character(0L)
      sample_studies_col[[i]] <- character(0L)
      next
    }
    cid <- stage3_clusters$cluster_id[i]
    rids <- asg_by_clid[[cid]]
    if (is.null(rids)) {
      sample_ids_col[[i]]     <- character(0L)
      sample_studies_col[[i]] <- character(0L)
      next
    }
    sids_all    <- character(0L)
    studies_all <- character(0L)
    for (rid in rids) {
      parsed <- .split_record_id(rid)
      if (is.na(parsed$series_id)) next
      if (!exists(parsed$series_id, envir = s2_idx, inherits = FALSE)) next
      study <- get(parsed$series_id, envir = s2_idx, inherits = FALSE)
      rg <- .lookup_rg(study, parsed$suffix)
      if (is.null(rg)) next
      these_sids <- as.character(unlist(rg$sample_ids))
      sids_all    <- c(sids_all, these_sids)
      studies_all <- c(studies_all, rep(parsed$series_id, length(these_sids)))
    }
    # Dedup parallel: first occurrence wins per (sample_id, study_id) pair
    keep <- !duplicated(sids_all)
    sample_ids_col[[i]]     <- sids_all[keep]
    sample_studies_col[[i]] <- studies_all[keep]
  }
  stage3_clusters$sample_ids     <- sample_ids_col
  stage3_clusters$sample_studies <- sample_studies_col
  stage3_clusters
}

#' Lookup comparison da study via treated_group (prima match, deterministico)
#'
#' Per i group treated-only il control vive fuori dal cluster: si risale al
#' control_group dello stesso studio cercando la comparison in cui il group_id
#' e' il \code{treated_group}. Se un group e' treated_group di piu' comparison,
#' vince la prima (ordine deterministico dell'input stage2).
#'
#' @keywords internal
.lookup_cmp_by_treated_group <- function(study, group_id) {
  for (cmp in study$comparisons) {
    if (identical(cmp$treated_group, group_id)) return(cmp)
  }
  NULL
}

#' Costruisce study_dispatch per cluster group-mode nominati (rem_group)
#'
#' Mappa ogni cluster group con method \code{rem_group} in una lista di
#' per-study record \code{{study_id, treated, control}}, con lo STESSO schema
#' di \code{.build_study_dispatch_from_stage3} (cosi' il dispatch si fonde nello
#' stesso attr "study_dispatch" e il ramo REM per-studio lo consuma invariato).
#'
#' Per ogni record group \code{<series>__<group_id>} treated si cerca la
#' comparison dello stesso studio in cui \code{group_id} e' il treated_group ->
#' control_group -> sample_ids (stesso studio). Serve UNIFORMEMENTE both_roles
#' (control nel cluster) e treated_only (control in record fratello): la
#' relazione vive sempre in \code{study\$comparisons}. Entry con < n_min treated
#' o control scartate (limma-voom richiede replica). Dedup per
#' \code{(study_id, treated_group)}.
#'
#' @inheritParams .build_study_dispatch_from_stage3
#' @param n_min integer campioni minimi per braccio per-studio (default 2).
#' @return named list (cluster_id -> list di \code{{study_id, treated,
#'   control}}). Cluster senza entry valide sono omessi.
#' @keywords internal
.build_group_rem_dispatch_from_stage3 <- function(eligible_clusters,
                                                   stage3_assignments,
                                                   stage2_master,
                                                   n_min = 2L) {
  # ADR-0025: i cluster derivati dal contrasto ("cgroup") hanno come record_id la
  # COMPARISON, quindi si risolvono con .lookup_cmp (come il ramo pair). I group
  # legacy restano risolti per gruppo-trattato.
  group_clusters <- eligible_clusters[
    eligible_clusters$mode %in% c("group", "cgroup") &
      eligible_clusters$method == "rem_group",
  ]
  if (nrow(group_clusters) == 0L) return(list())

  s2_idx <- .index_stage2_master(stage2_master)
  asg_by_clid <- split(stage3_assignments$record_id,
                       stage3_assignments$cluster_id)

  dispatch <- vector("list", 0L)
  for (i in seq_len(nrow(group_clusters))) {
    cid <- group_clusters$cluster_id[i]
    is_contrast <- identical(group_clusters$mode[i], "cgroup")
    record_ids <- asg_by_clid[[cid]]
    if (is.null(record_ids) || length(record_ids) == 0L) next

    cluster_dispatch <- vector("list", 0L)
    seen_keys <- character(0L)
    for (rid in record_ids) {
      parsed <- .split_record_id(rid)
      if (is.na(parsed$series_id)) next
      if (!exists(parsed$series_id, envir = s2_idx, inherits = FALSE)) next
      study <- get(parsed$series_id, envir = s2_idx, inherits = FALSE)
      # cgroup: il record_id E' la comparison. group legacy: si cerca la
      # comparison in cui quel gruppo e' il braccio trattato.
      cmp <- if (is_contrast) .lookup_cmp(study, parsed$suffix)
             else .lookup_cmp_by_treated_group(study, parsed$suffix)
      if (is.null(cmp)) next

      tg <- .lookup_rg(study, cmp$treated_group)
      cg <- .lookup_rg(study, cmp$control_group)
      if (is.null(tg) || is.null(cg)) next
      treated <- as.character(unlist(tg$sample_ids))
      control <- as.character(unlist(cg$sample_ids))
      if (length(treated) < n_min || length(control) < n_min) next

      key <- paste0(parsed$series_id, "||", cmp$treated_group)
      if (key %in% seen_keys) next
      seen_keys <- c(seen_keys, key)

      cluster_dispatch[[length(cluster_dispatch) + 1L]] <- list(
        study_id = parsed$series_id,
        treated  = treated,
        control  = control
      )
    }
    if (length(cluster_dispatch) > 0L) {
      dispatch[[cid]] <- cluster_dispatch
    }
  }
  dispatch
}
