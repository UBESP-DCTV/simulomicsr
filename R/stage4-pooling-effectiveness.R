# R/stage4-pooling-effectiveness.R --- quanto conta davvero ogni studio in una
# meta-analisi poolata.
#
# Il deliverable riporta `k_effective`: quanti studi entrano. Non dice quanto
# quegli studi PESANO. In un random-effects il peso di uno studio su un gene e'
# 1/(SE^2 + tau^2): con SE molto diversi e tau^2 piccolo un solo studio puo'
# portare quasi tutto, e la meta-analisi non aggiunge nulla a quello che quello
# studio diceva gia'. Misurato su v13 (2026-07-31): 105 gruppi su 191 hanno uno
# studio sopra il 50% del peso e 66 valgono meno di due studi efficaci — tutti
# marcati "coerenti", perche' coerenza e dominanza sono assi indipendenti.
#
# Non e' un difetto della pesatura: l'inverso della varianza DEVE dare piu' peso
# a chi misura meglio. E' un'informazione che mancava al lettore.

#' Collassa i bracci di uno studio in una sola stima per studio
#'
#' `per_study_de` tiene una riga per BRACCIO (uno studio con quattro condizioni
#' trattate contro lo stesso controllo produce quattro righe). Il ramo
#' `rem_group` collassa i bracci dentro lo studio a effetti fissi
#' (inverso della varianza) PRIMA del random-effects, cosi' uno studio vale uno
#' studio (vedi `.collapse_arms_by_study`). Pesare i bracci invece degli studi
#' misura un'altra cosa: TGF-beta1 ha 83 bracci per 49 studi.
#'
#' Le righe con `SE` mancante, nulla o negativa vengono scartate: non sono
#' informative e propagherebbero `NA` o infiniti nei pesi.
#'
#' @param per_arm data.frame con `cluster_id`, `gene_id`, `study_id`, `SE`.
#' @return data.frame con `cluster_id`, `gene_id`, `study_id`, `SE_study`.
#' @keywords internal
.collapse_arm_se_by_study <- function(per_arm) {
  ok <- !is.na(per_arm$SE) & per_arm$SE > 0
  x <- per_arm[ok, , drop = FALSE]
  if (nrow(x) == 0L) {
    return(data.frame(cluster_id = character(), gene_id = character(),
                      study_id = character(), SE_study = numeric(),
                      stringsAsFactors = FALSE))
  }
  chiave <- paste(x$cluster_id, x$gene_id, x$study_id, sep = "\r")
  prec <- stats::aggregate(list(prec = 1 / x$SE^2), by = list(chiave = chiave),
                           FUN = sum)
  parti <- do.call(rbind, strsplit(prec$chiave, "\r", fixed = TRUE))
  data.frame(
    cluster_id = parti[, 1L],
    gene_id    = parti[, 2L],
    study_id   = parti[, 3L],
    SE_study   = sqrt(1 / prec$prec),
    stringsAsFactors = FALSE
  )
}

#' Efficacia del pooling per cluster: quanti studi contano davvero
#'
#' Per ogni gene si calcolano i pesi del random-effects `w = 1/(SE_studio^2 +
#' tau^2)` e da questi il **numero efficace di studi** di Kish
#' \eqn{(\sum w)^2 / \sum w^2}: vale `k` se tutti pesano uguale, tende a 1 se
#' uno domina. Si aggrega per cluster con la MEDIANA sui geni (robusta alle
#' code), non con la media.
#'
#' Un gene presente nei pesi ma privo di `tau2` viene **escluso**, non trattato
#' come `tau2 = 0`: assumere zero abbasserebbe artificialmente il numero
#' efficace, cioe' spingerebbe verso la conclusione piu' allarmante. Le esclusioni
#' si leggono in `n_geni`.
#'
#' @param per_arm data.frame con `cluster_id`, `gene_id`, `study_id`, `SE`
#'   (una riga per braccio: il collasso per studio lo fa questa funzione).
#' @param tau2 data.frame con `cluster_id`, `gene_id`, `tau2`. Passare qui il
#'   sottoinsieme dei geni su cui si vuole la misura (di norma i significativi).
#' @param soglia_dominanza quota di peso del primo studio oltre la quale il
#'   cluster e' marcato `dominato` (default 0,5).
#' @return data.frame, una riga per cluster: `cluster_id`, `k_studies` (studi
#'   distinti, mediana sui geni), `k_kish`, `quota_top1`, `frazione_efficace`
#'   (`k_kish / k_studies`), `dominato`, `studio_dominante` (lo studio con la
#'   quota mediana piu' alta), `n_geni`.
#' @export
compute_pooling_effectiveness <- function(per_arm, tau2, soglia_dominanza = 0.5) {
  vuoto <- data.frame(
    cluster_id = character(), k_studies = integer(), k_kish = numeric(),
    quota_top1 = numeric(), frazione_efficace = numeric(),
    dominato = logical(), studio_dominante = character(),
    n_geni = integer(), stringsAsFactors = FALSE
  )
  if (nrow(per_arm) == 0L) return(vuoto)

  per_studio <- .collapse_arm_se_by_study(per_arm)
  if (nrow(per_studio) == 0L) return(vuoto)

  t2 <- tau2[!is.na(tau2$tau2), c("cluster_id", "gene_id", "tau2"), drop = FALSE]
  chiave_ps <- paste(per_studio$cluster_id, per_studio$gene_id, sep = "\r")
  chiave_t2 <- paste(t2$cluster_id, t2$gene_id, sep = "\r")
  j <- match(chiave_ps, chiave_t2)
  tieni <- !is.na(j)
  if (!any(tieni)) return(vuoto)

  per_studio <- per_studio[tieni, , drop = FALSE]
  per_studio$tau2 <- t2$tau2[j[tieni]]
  per_studio$w <- 1 / (per_studio$SE_study^2 + per_studio$tau2)

  # per gene: Kish + quota del primo
  gk <- paste(per_studio$cluster_id, per_studio$gene_id, sep = "\r")
  agg <- function(f) vapply(split(per_studio$w, gk), f, numeric(1L))
  sw   <- agg(sum)
  sw2  <- agg(function(w) sum(w^2))
  maxw <- agg(max)
  n_st <- vapply(split(per_studio$w, gk), length, integer(1L))

  # quale studio domina: quello con la quota MEDIANA piu' alta sui geni del
  # cluster, non quello che vince su un gene solo. Senza il nome non si puo'
  # chiedere se chi porta il peso sia un modello in vitro.
  per_studio$quota <- per_studio$w / sw[gk]
  sk <- paste(per_studio$cluster_id, per_studio$study_id, sep = "\r")
  q_med <- vapply(split(per_studio$quota, sk), stats::median, numeric(1L))
  q_cl <- sub("\r.*$", "", names(q_med))
  q_st <- sub("^.*\r", "", names(q_med))
  dominante <- vapply(split(seq_along(q_med), q_cl),
                      function(idx) q_st[idx][which.max(q_med[idx])],
                      character(1L))

  per_gene <- data.frame(
    gk = names(sw),
    k_studies = as.integer(n_st),
    k_kish = as.numeric(sw^2 / sw2),
    quota_top1 = as.numeric(maxw / sw),
    stringsAsFactors = FALSE
  )
  per_gene$cluster_id <- sub("\r.*$", "", per_gene$gk)

  med <- function(col) {
    vapply(split(per_gene[[col]], per_gene$cluster_id), stats::median, numeric(1L))
  }
  k_studies <- med("k_studies")
  out <- data.frame(
    cluster_id = names(k_studies),
    k_studies  = as.integer(round(k_studies)),
    k_kish     = as.numeric(med("k_kish")),
    quota_top1 = as.numeric(med("quota_top1")),
    n_geni     = as.integer(table(per_gene$cluster_id)[names(k_studies)]),
    stringsAsFactors = FALSE
  )
  out$frazione_efficace <- out$k_kish / out$k_studies
  out$dominato <- out$quota_top1 >= soglia_dominanza
  out$studio_dominante <- unname(dominante[out$cluster_id])
  rownames(out) <- NULL
  out[, c("cluster_id", "k_studies", "k_kish", "quota_top1",
          "frazione_efficace", "dominato", "studio_dominante", "n_geni")]
}
