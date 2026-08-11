# Un campione non puo' essere trattato E controllo dello stesso confronto.
#
# IL DIFETTO (misurato il 2026-08-09 su tutti i 2.152 confronti che entrano nel
# pooling del deliverable v15). L'orchestratore costruisce i ruoli per POSIZIONE:
#     samples   <- c(d$treated, d$control)
#     treatment <- factor(c(rep("treated", ...), rep("control", ...)))
# Un campione presente in entrambe le liste entra DUE VOLTE, una per lato: lo
# stesso profilo di espressione finisce su tutti e due i bracci del contrasto.
# La stima viene tirata verso zero e i gradi di liberta' contano repliche che non
# esistono.
#
# AMPIEZZA MISURATA: 1 confronto su 2.152. E' `GSE158765` dentro la meta-analisi
# dell'acido acetilsalicilico (`cgroup_L5_ff78d2a8`, k_effective 3, marcata
# *coerente*): 94 trattati, 61 controlli, **59 dei controlli sono anche fra i
# trattati** -- il 97% del braccio di riferimento. I metadati dicono perche': e'
# uno studio longitudinale ENTRO SOGGETTO (`subject_id`, `visit_number`,
# "81 mg Aspirin"), dove lo stesso soggetto sta prima e dopo il trattamento e i
# due bracci si sovrappongono. Il peso di quello studio nel gruppo e' al piu' il
# 9% (il gruppo e' dominato al 91% da GSE198434, k_kish 1,19).
#
# PERCHE' NON SI COPIA DAL RAMO `mega`. Una guardia equivalente esiste in
# `.build_mega_metadata_safe()`, che marca `conflict_type` e droppa il campione.
# Ma quel ramo e' fuori dal deliverable (ADR-0026) e non e' piu' sviluppato:
# prenderlo a modello legherebbe il ramo vivo a codice fermo. Questa guardia sta
# nel punto dell'orchestratore che i TRE rami per-studio (`rem`, `mega_aug`,
# `rem_group`) attraversano tutti, ed e' scritta per loro.
#
# LE TRE SCELTE, e perche':
#   - il campione ambiguo esce da ENTRAMBI i bracci. Assegnarlo a uno dei due
#     sarebbe scegliere un ruolo arbitrario su un dato che ne dichiara due;
#     tenerlo com'e' e' il difetto che si sta chiudendo.
#   - se dopo lo scarto un braccio scende sotto `n_min`, il confronto non entra:
#     un contrasto che sopravvive solo grazie ai campioni ambigui non e' un
#     contrasto.
#   - lo scarto e' sempre registrato. Questa guardia toglie campioni da una stima
#     pubblicata: una selezione silenziosa non sarebbe auditabile.
#
# NB: un campione ripetuto DENTRO lo stesso braccio non e' un conflitto di ruolo
# (il ruolo e' uno solo): si deduplica e basta.

#' Schema vuoto del registro degli scarti per conflitto di ruolo
#' @keywords internal
#' @noRd
.empty_role_conflict_log <- function() {
  data.frame(
    cluster_id       = character(0),
    study_id         = character(0),
    n_treated_before = integer(0),
    n_control_before = integer(0),
    n_dropped        = integer(0),
    dropped_samples  = character(0),
    usable           = logical(0),
    reason           = character(0),
    stringsAsFactors = FALSE
  )
}

#' Toglie dal confronto i campioni che dichiarano due ruoli
#'
#' @param treated character, identificativi dei campioni del braccio trattato.
#' @param control character, identificativi dei campioni del braccio di controllo.
#' @param n_min integer, minimo di campioni per braccio perche' il confronto sia
#'   utilizzabile (stessa soglia del pooling).
#' @param cluster_id,study_id opzionali, solo per il registro.
#' @return list con \code{treated} e \code{control} ripuliti e deduplicati,
#'   \code{dropped} (i campioni tolti, in ordine di prima comparsa nel braccio
#'   trattato), \code{usable} (entrambi i bracci hanno almeno \code{n_min}
#'   campioni) e \code{log} (una riga se c'e' stato uno scarto, zero altrimenti).
#' @keywords internal
.drop_role_conflicts <- function(treated, control, n_min = 2L,
                                 cluster_id = NA_character_,
                                 study_id = NA_character_) {
  treated <- unique(as.character(treated))
  control <- unique(as.character(control))
  n_t0 <- length(treated)
  n_c0 <- length(control)

  # ordine stabile: come compaiono nel braccio trattato, non come li ordina la
  # collazione locale (che cambia fra macchine).
  dropped <- treated[treated %in% control]

  if (length(dropped) > 0L) {
    treated <- treated[!(treated %in% dropped)]
    control <- control[!(control %in% dropped)]
  }

  usable <- length(treated) >= n_min && length(control) >= n_min

  log <- .empty_role_conflict_log()
  if (length(dropped) > 0L) {
    log <- data.frame(
      cluster_id       = as.character(cluster_id),
      study_id         = as.character(study_id),
      n_treated_before = as.integer(n_t0),
      n_control_before = as.integer(n_c0),
      n_dropped        = as.integer(length(dropped)),
      dropped_samples  = paste(dropped, collapse = ","),
      usable           = usable,
      reason           = "role_conflict_treated_and_control",
      stringsAsFactors = FALSE
    )
  }

  list(treated = treated, control = control, dropped = dropped,
       usable = usable, log = log)
}
