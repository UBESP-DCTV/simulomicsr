#' Normalizza un valore di dose nella forma canonica dell'anchor
#'
#' Rimuove spazi, normalizza simboli micro, mappa null/NA/"" -> "nodose".
#' Preserva il valore "standard" come placeholder per dosaggi non specificati
#' ma noti dal protocollo.
#'
#' @param dose stringa o NULL/NA
#' @return stringa canonica (es. "10nM", "100ng/ml", "nodose", "standard")
#' @keywords internal
.normalize_dose <- function(dose) {
  if (is.null(dose) || length(dose) == 0L) return("nodose")
  if (is.na(dose) || !nzchar(dose)) return("nodose")
  d <- gsub("\\s+", "", dose)
  d <- gsub("µ", "u", d)  # micro symbol -> u
  d
}

#' Normalizza una durata nella forma canonica dell'anchor (ore/giorni)
#'
#' Converte minuti -> ore (1.5h per 90 min), days -> ore (48h per 2 days)
#' tranne per durate >= 6 giorni dove preserva "Nd" (es. 6d, 14d).
#' Mappa null/NA/"" -> "na".
#'
#' @param duration stringa o NULL/NA
#' @return stringa canonica
#' @keywords internal
.normalize_duration <- function(duration) {
  if (is.null(duration) || length(duration) == 0L) return("na")
  if (is.na(duration) || !nzchar(duration)) return("na")
  s <- tolower(gsub("\\s+", "", duration))

  # Pattern: <num><unit>
  m <- regmatches(s, regexec("^([0-9.]+)([a-z]+)$", s))[[1L]]
  if (length(m) != 3L) return(s)
  num <- as.numeric(m[2L])
  unit <- m[3L]

  if (unit %in% c("min", "minute", "minutes", "m")) {
    return(paste0(format(num / 60, drop0trailing = TRUE), "h"))
  }
  if (unit %in% c("h", "hr", "hour", "hours")) {
    return(paste0(format(num, drop0trailing = TRUE), "h"))
  }
  if (unit %in% c("d", "day", "days")) {
    if (num >= 6) {
      return(paste0(format(num, drop0trailing = TRUE), "d"))
    }
    return(paste0(format(num * 24, drop0trailing = TRUE), "h"))
  }
  s  # fallback
}

#' Normalizza un cell identifier per l'anchor
#'
#' Preferenza: Cellosaurus ID. Fallback: label_raw. Default: "unclear".
#'
#' @param cellosaurus_id stringa o NULL/NA
#' @param label_raw stringa o NULL/NA
#' @return stringa canonica
#' @keywords internal
.normalize_cell_id <- function(cellosaurus_id, label_raw) {
  if (.nzchar_safe(cellosaurus_id)) return(cellosaurus_id)
  if (.nzchar_safe(label_raw)) return(label_raw)
  "unclear"
}

#' @noRd
.nzchar_safe <- function(x) {
  !is.null(x) && length(x) > 0L && !is.na(x) && nzchar(x)
}
