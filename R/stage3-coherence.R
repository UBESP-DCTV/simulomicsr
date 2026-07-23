#' Normalizza un control-label (label_human) in una classe canonica cross-studio
#'
#' Serve a contare quanti TIPI di controllo semanticamente diversi convivono in un
#' cluster (segnale di minestrone). Usa label_human (comparabile cross-studio),
#' NON factor_levels (chiavi study-specific). Determinismo: lowercase, strip
#' dose/unita'/numeri, collasso di sinonimi di veicolo/baseline in un'unica classe.
#' Controlli specifici (dieta, normossia, scramble genetico) restano distinti.
#' Conservativo verso la diversita': NON collassa controlli biologicamente diversi.
#' @keywords internal
.normalize_control_type <- function(label) {
  if (length(label) == 0L || is.na(label) || !nzchar(trimws(label))) return("NA")
  x <- tolower(trimws(label))
  x <- gsub("\\b\\d+(\\.\\d+)?\\s?(nm|um|µm|mm|mg|ng|ug|µg|%|h|hr|hrs|day|days|d|week|weeks|min)\\b", " ", x)
  x <- gsub("\\b\\d+(\\.\\d+)?\\b", " ", x)              # numeri isolati
  x <- gsub("[^a-z ]+", " ", x)                            # punteggiatura
  x <- trimws(gsub("\\s+", " ", x))
  # classe veicolo/baseline: sinonimi comuni -> stessa classe
  veh <- c("dmso","vehicle","untreated","control","mock","pbs","saline","none",
           "no treatment","not treated","baseline","normal","healthy","naive")
  toks <- strsplit(x, " ")[[1]]
  if (any(toks %in% veh) &&
      !any(toks %in% c("diet","normoxia","normoxic","hypoxia","scramble","scrambled",
                        "wildtype","wt","sirna","shrna","sgrna","irradiated","fasting"))) {
    return("vehicle_untreated")
  }
  if (x == "") return("NA")
  x
}

#' Ricostruisce i contrasti per-studio di un cluster (stesso dispatch dello Stadio 4)
#'
#' Pair -> .lookup_cmp; group -> .lookup_cmp_by_treated_group; entrambi -> .lookup_rg.
#' Una riga per membro RISOLTO (comparison trovata + treated/control presenti).
#' @keywords internal
.reconstruct_cluster_contrasts <- function(cluster_id, mode, asg_by_clid, s2_idx) {
  fl_sig <- function(rg) {
    fl <- rg$factor_levels
    if (length(fl) == 0L) return("")
    paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), "")), collapse = ";")
  }
  lab <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid
  rids <- asg_by_clid[[cluster_id]]
  if (is.null(rids)) return(.empty_contrast_df())
  rows <- list()
  for (rid in rids) {
    p <- .split_record_id(rid)
    if (is.na(p$series_id) || !exists(p$series_id, envir = s2_idx, inherits = FALSE)) next
    st <- get(p$series_id, envir = s2_idx, inherits = FALSE)
    cmp <- if (identical(mode, "pair")) .lookup_cmp(st, p$suffix)
           else .lookup_cmp_by_treated_group(st, p$suffix)
    if (is.null(cmp)) next
    tg <- .lookup_rg(st, cmp$treated_group); cg <- .lookup_rg(st, cmp$control_group)
    if (is.null(tg) || is.null(cg)) next
    rows[[length(rows) + 1L]] <- data.frame(
      study_id      = p$series_id,
      treated_label = lab(tg, cmp$treated_group), treated_fl = fl_sig(tg),
      control_label = lab(cg, cmp$control_group), control_fl = fl_sig(cg),
      design_kind   = st$design_kind %||% "NA", stringsAsFactors = FALSE)
  }
  if (length(rows) == 0L) return(.empty_contrast_df())
  do.call(rbind, rows)
}

.empty_contrast_df <- function() data.frame(
  study_id = character(0), treated_label = character(0), treated_fl = character(0),
  control_label = character(0), control_fl = character(0), design_kind = character(0),
  stringsAsFactors = FALSE)

#' Riassume i segnali di coerenza (Fase A/C) da un data.frame di contrasti
#' @keywords internal
.cluster_coherence_signals <- function(contrast_df) {
  n <- nrow(contrast_df)
  if (n == 0L) return(list(n_resolved = 0L, n_control_types = NA_integer_,
    control_homogeneity = NA_real_, n_design_kinds = NA_integer_,
    n_treated_types = NA_integer_, n_degenerate = NA_integer_, frac_degenerate = NA_real_))
  ctrl_types <- vapply(contrast_df$control_label, .normalize_control_type, character(1))
  trt_types  <- vapply(contrast_df$treated_label, .normalize_control_type, character(1))
  # degenere: stessa firma factor_levels (stesso studio, chiavi confrontabili) o stesso label
  deg <- (nzchar(contrast_df$treated_fl) & contrast_df$treated_fl == contrast_df$control_fl) |
         (tolower(trimws(contrast_df$treated_label)) == tolower(trimws(contrast_df$control_label)))
  n_ct <- length(unique(ctrl_types))
  list(
    n_resolved = n,
    n_control_types = n_ct,
    control_homogeneity = 1 / n_ct,                 # 1 = un solo tipo; ->0 = molti tipi
    n_design_kinds = length(unique(contrast_df$design_kind)),
    n_treated_types = length(unique(trt_types)),
    n_degenerate = sum(deg),
    frac_degenerate = mean(deg))
}

#' Verdetto AND multi-asse da segnali + consistenza + deep-dive
#'
#' Soglie di DEFAULT (documentate nel finding, non nascoste):
#'   - min_resolved = 2 : sotto = uncertain (copertura insufficiente).
#'   - deg_frac_hi  = 0.5: frac_degenerate >= => degenerate.
#'   - homogeneous control = n_control_types == 1 (dopo normalizzazione).
#'   - design homogeneous  = n_design_kinds <= 1.
#'   - consistency_ok = (is.na) o >= 0.5 dove disponibile.
#'   - deepdive: se valutato, "one_contrast" richiesto per coherent; "multi_contrast" => minestrone.
#' @keywords internal
.coherence_verdict <- function(signals, consistency = NA_real_, deepdive = NA_character_,
                               min_resolved = 2L, deg_frac_hi = 0.5, cons_ok = 0.5) {
  s <- signals
  if (is.na(s$n_resolved) || s$n_resolved < min_resolved) return("uncertain")
  if (!is.na(s$frac_degenerate) && s$frac_degenerate >= deg_frac_hi) return("degenerate")
  if (!is.na(deepdive) && identical(deepdive, "multi_contrast")) return("minestrone")
  control_homog <- !is.na(s$n_control_types) && s$n_control_types == 1L
  design_homog  <- !is.na(s$n_design_kinds)  && s$n_design_kinds  <= 1L
  if (!control_homog || !design_homog) return("minestrone")
  # qui: control-omogeneo E design-omogeneo E non-degenere
  cons_pass <- is.na(consistency) || consistency >= cons_ok
  dd_pass   <- is.na(deepdive) || identical(deepdive, "one_contrast")
  if (cons_pass && dd_pass) return("coherent")
  "uncertain"
}
