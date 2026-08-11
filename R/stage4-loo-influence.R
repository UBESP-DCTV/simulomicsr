# R/stage4-loo-influence.R --- misurare quanto uno studio sposta una meta-analisi
#
# Il prezzo dell'aggregazione e' che qualche confronto e' spurio. Il progetto ha
# provato per mesi a decidere se un gruppo fosse «coerente», e il verdetto si e'
# rivelato non riproducibile: sugli stessi 213 gruppi, con lo stesso materiale,
# Mistral ne dichiara incoerenti 24 e la lettura umana 96 (accordo a tre livelli
# 36,2%). E il criterio severo distrugge esattamente cio' che serve: con la regola
# «almeno un confronto difettoso» nessuna meta-analisi con k >= 15 sopravvive.
#
# Qui si sostituisce il verdetto con una MISURA: si toglie uno studio, si rifa' il
# pooling, si guarda di quanto il risultato si sposta.
#
# ⚠️ Che cosa questo NON misura. Una leave-one-out trova gli studi DISCORDANTI.
# I difetti censiti (secondo agente, materiale diverso, passaggio di coltura,
# linea, sede, donatore) producono in larga parte uno studio che misura comunque
# il contrasto voluto, con un bias plausibilmente CONCORDE — e un bias concorde e'
# invisibile a questo disegno. Misurato: la concordanza col poolato degli studi
# accusati (rho 0,652) non e' distinguibile da quella dei puliti (0,683),
# Wilcoxon p = 0,168 su 344 studi. Vedi
# analysis/audit/2026-08-10-sensitivity/00-previsioni.md §0.

#' Ri-pooling di un cluster lasciando fuori un insieme di studi
#'
#' Rifa' il pooling random-effects di un cluster escludendo gli studi indicati,
#' con la STESSA catena della produzione: collasso dei bracci per studio
#' (inverse-variance a effetti fissi) e poi \code{.pool_rem_cluster()}. Non serve
#' un re-pool: la catena e' due chiamate, e sul cluster `cgroup_L5_00fd9348`
#' (k=3) e su palbociclib (k=15, 29.285 coppie studio-gene con piu' di un
#' braccio) riproduce `cluster_pooled.parquet` con scarto **0** su tutte e otto
#' le quantita'.
#'
#' L'ordine e' vincolante. Poolare i BRACCI invece degli studi da' un numero
#' diverso e sbagliato — errore commesso davvero il 2026-07-31 (83 bracci per 49
#' studi in TGF-beta1) e corretto misurando.
#'
#' @param per_study_de_subset data.frame per-studio di UN cluster (una riga per
#'   braccio e gene), con `cluster_id`, `gene_id`, `study_id`, `logFC`, `SE`.
#' @param studi_esclusi character: gli `study_id` da togliere. Vuoto = pooling
#'   pieno. Uno studio assente e' ignorato senza errore.
#' @param method_label etichetta del metodo scritta nell'output (default
#'   `"rem_group"`, il ramo del deliverable).
#' @return tibble con lo schema di `cluster_pooled.parquet`. Zero righe se dopo
#'   la rimozione nessun gene ha almeno due studi.
#' @export
pool_cluster_leaving_out <- function(per_study_de_subset,
                                     studi_esclusi = character(0),
                                     method_label = "rem_group") {
  stopifnot(inherits(per_study_de_subset, "data.frame"))
  if (nrow(per_study_de_subset) == 0L) return(.empty_pooled_rem())

  # Guardia sullo schema. .collapse_arms_by_study() ricostruisce la riga collassata
  # colonna per colonna: su uno schema parziale fallisce dentro un rbind, con un
  # messaggio illeggibile, e SOLO se qualche studio ha piu' di un braccio — cioe'
  # su alcuni cluster si' e su altri no.
  serve <- c("cluster_id", "study_id", "gene_id", "gene_symbol", "logFC", "SE",
             "p_value", "t_stat", "n_treated", "n_control", "direction_applied")
  manca <- setdiff(serve, names(per_study_de_subset))
  if (length(manca) > 0L) {
    stop("per_study_de_subset non ha lo schema di per_study_de: mancano ",
         paste(manca, collapse = ", "))
  }

  x <- per_study_de_subset[!per_study_de_subset$study_id %in% studi_esclusi, ,
                           drop = FALSE]
  if (nrow(x) == 0L) return(.empty_pooled_rem())

  .pool_rem_cluster(.collapse_arms_by_study(x), method_label = method_label)
}

#' Di quanto si sposta una meta-analisi: le tre statistiche dell'influenza
#'
#' Un solo numero non basta: sullo stesso gruppo si osservano Spearman ~ 0,99 e
#' contemporaneamente scarti di 2-3 unita' di logFC sui primi geni. Si riportano
#' tutte e tre:
#' \itemize{
#'   \item **Spearman** del ranking dei geni — se cambia *quali* geni si mostrano;
#'   \item **geni significativi persi/guadagnati** — se cambia la *quantita'* di
#'     risultato;
#'   \item **massimo |delta logFC| fra i primi N** — se cambia la *grandezza* di
#'     un effetto dichiarato.
#' }
#'
#' Il ranking usa `p_value_pool` e non `FDR_BH_within_cluster`: BH e' monotona in
#' p, quindi l'ordine e' lo stesso, ma l'FDR si ricalcola su un denominatore
#' diverso a ogni rimozione e ne farebbe una misura del denominatore. Il conteggio
#' dei significativi, che l'FDR lo usa davvero, resta su `FDR_BH_within_cluster`.
#'
#' I primi N si fissano sul pooling PIENO: riordinare anche il ridotto
#' misurerebbe un insieme di geni diverso a ogni rimozione.
#'
#' @param pieno data.frame poolato completo (output di
#'   \code{pool_cluster_leaving_out} senza esclusioni).
#' @param ridotto data.frame poolato dopo la rimozione.
#' @param geni character: l'insieme di geni FISSO su cui misurare (di norma i
#'   significativi del pieno). Dichiararlo prima e' un vincolo, non un dettaglio.
#' @param top_n quanti geni, in cima al pieno, per il massimo scarto di logFC
#'   (default 30, come le tabelle del Layer B).
#' @return data.frame di una riga: `n_geni_richiesti`, `n_geni_confrontati`,
#'   `n_geni_spariti`, `spearman`, `n_sig_pieno`, `n_sig_ridotto`,
#'   `n_sig_persi`, `n_sig_guadagnati`, `max_abs_delta_logFC`, `gene_max_delta`,
#'   `k_pieno`, `k_ridotto`.
#' @export
compute_pooling_influence <- function(pieno, ridotto, geni, top_n = 30L) {
  stopifnot(inherits(pieno, "data.frame"), inherits(ridotto, "data.frame"))
  geni <- unique(as.character(geni))

  p <- pieno[pieno$gene_id %in% geni, , drop = FALSE]
  r <- ridotto[ridotto$gene_id %in% geni, , drop = FALSE]
  comuni <- intersect(p$gene_id, r$gene_id)

  ip <- match(comuni, p$gene_id)
  ir <- match(comuni, r$gene_id)

  spearman <- if (length(comuni) >= 3L) {
    suppressWarnings(stats::cor(p$p_value_pool[ip], r$p_value_pool[ir],
                                method = "spearman", use = "complete.obs"))
  } else NA_real_

  # i primi N si fissano sul PIENO, fra i geni confrontabili
  d <- data.frame(gene_id = comuni,
                  p_pieno = p$p_value_pool[ip],
                  delta = abs(p$logFC_pool[ip] - r$logFC_pool[ir]),
                  stringsAsFactors = FALSE)
  d <- d[order(d$p_pieno), , drop = FALSE]
  d_top <- utils::head(d, top_n)
  if (nrow(d_top) > 0L && any(is.finite(d_top$delta))) {
    j <- which.max(d_top$delta)
    max_delta <- d_top$delta[j]
    gene_max <- d_top$gene_id[j]
  } else {
    max_delta <- NA_real_
    gene_max <- NA_character_
  }

  .sig <- function(x) {
    if (!"FDR_BH_within_cluster" %in% names(x) || nrow(x) == 0L) return(character(0))
    x$gene_id[!is.na(x$FDR_BH_within_cluster) & x$FDR_BH_within_cluster < 0.05]
  }
  sig_p <- .sig(p); sig_r <- .sig(r)

  .k <- function(x) if (nrow(x) == 0L || !"k_effective" %in% names(x)) NA_real_ else
    stats::median(x$k_effective, na.rm = TRUE)

  data.frame(
    n_geni_richiesti   = length(geni),
    n_geni_confrontati = length(comuni),
    n_geni_spariti     = length(setdiff(p$gene_id, r$gene_id)),
    spearman           = spearman,
    n_sig_pieno        = length(sig_p),
    n_sig_ridotto      = length(sig_r),
    n_sig_persi        = length(setdiff(sig_p, sig_r)),
    n_sig_guadagnati   = length(setdiff(sig_r, sig_p)),
    max_abs_delta_logFC = max_delta,
    gene_max_delta     = gene_max,
    k_pieno            = .k(p),
    k_ridotto          = .k(r),
    stringsAsFactors = FALSE)
}
