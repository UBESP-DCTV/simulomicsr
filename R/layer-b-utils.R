#' Genera run_id deterministico per Layer B
#'
#' Hash a 8-hex di canonical-form(stage4_run_id + selection_csv_sha256 +
#' config + schema_versions). Idempotenza: stesso input -> stesso run_id.
#' Ordina i campi `config` e `schema_versions` per stabilita cross-platform
#' (insensibile a ordine di insert).
#'
#' @param stage4_run_id character (1).
#' @param selection_sha256 character (1).
#' @param config list (vedi `layer_b_default_config()`).
#' @param schema_versions list (es. `list(layer_b_algorithm = "v1", stage4_algorithm = "v1")`).
#'
#' @return character 8-hex.
#' @keywords internal
.run_id_for_layer_b <- function(stage4_run_id, selection_sha256, config, schema_versions) {
  payload <- list(
    stage4_run_id = stage4_run_id,
    selection_sha256 = selection_sha256,
    config = config[order(names(config))],
    schema_versions = schema_versions[order(names(schema_versions))]
  )
  substr(digest::digest(payload, algo = "sha256"), 1L, 8L)
}

#' SHA-256 di un file (helper per selection_sha256)
#'
#' Wrapper attorno a `digest::digest(file = path, algo = "sha256")`.
#'
#' @param path character path-to-file esistente.
#'
#' @return character SHA-256 hex.
#' @keywords internal
.sha256_of_file <- function(path) {
  digest::digest(file = path, algo = "sha256")
}

#' Ordina i geni per significativita e deduplica per simbolo genico
#'
#' Revisione scientifica (showcase Layer B): ordinare per `|logFC_pool|`
#' pesca geni ad alta varianza e bassa robustezza (es. recettori olfattivi,
#' cheratine, geni con `k_effective` basso) e seppellisce i marcatori
#' canonici veri (logFC modesto ma alta significativita e alto k). Criterio
#' corretto: `FDR_BH_within_cluster` ASCENDENTE (piu significativo prima),
#' tie-break `abs(logFC_pool)` DISCENDENTE.
#'
#' Dedup: ARCHS4 mappa piu Ensembl gene_id sullo stesso simbolo HGNC
#' (artefatto multi-Ensembl, es. RDH13 x7, AGER x4) gonfiando le
#' tabelle/heatmap con righe ridondanti dello stesso gene biologico.
#' Collassa le righe che condividono lo stesso `gene_symbol` NON vuoto alla
#' singola riga PIU significativa (la prima dopo l'ordinamento, quindi
#' `FDR_BH_within_cluster` minimo). Righe con `gene_symbol` NA o `""`
#' (nessuna annotazione HGNC) NON vengono deduplicate tra loro: restano
#' righe distinte (sono gia' univoche per `gene_id`).
#'
#' @param sig data.frame/tibble gia' filtrato (es. per `FDR<thr`), con
#'   colonne `gene_symbol`, `logFC_pool`, `FDR_BH_within_cluster`.
#'
#' @return data.frame ordinato e deduplicato, stesso schema colonne di `sig`.
#' @keywords internal
.rank_and_dedup_genes <- function(sig) {
  if (nrow(sig) == 0L) {
    return(sig)
  }

  ord <- order(sig$FDR_BH_within_cluster, -abs(sig$logFC_pool))
  sig <- sig[ord, , drop = FALSE]

  has_symbol <- !is.na(sig$gene_symbol) & sig$gene_symbol != ""
  keep <- !has_symbol
  # Fra le righe con simbolo, tiene la prima occorrenza per simbolo: dato
  # l'ordinamento sopra e' gia' la riga piu significativa per quel simbolo.
  keep[has_symbol] <- !duplicated(sig$gene_symbol[has_symbol])

  sig[keep, , drop = FALSE]
}

# --- filtro di copertura sui geni mostrati nelle figure -----------------------
#
# Misurato il 2026-07-31 sui bundle veri: la tabella dei top geni e la heatmap,
# ordinate per FDR, sono guidate da geni misurati in POCHI studi. Il meccanismo
# e' verificato: con k basso il random-effects non riesce a stimare tau^2, lo
# pone a ZERO, l'errore standard collassa e l'FDR precipita. Quegli stessi geni
# sono a conteggio zero nella maggior parte dei campioni (Spearman fra k e
# frazione di zeri: -0,813) e ComBat li salta, quindi nella heatmap restano
# segnale di studio invece che di trattamento.
#
# Il filtro non giudica la stima poolata — quella resta quella che e'. Decide
# solo QUALI geni si mostrano in una figura.

#' Tiene i geni misurati in una frazione minima degli studi del cluster
#'
#' @param sig data.frame dei geni candidati (tipicamente i significativi), con
#'   colonna `k_effective`. Se la colonna manca, l'input passa indenne.
#' @param min_k_frac numeric(1) frazione minima del `k` del cluster. 0 disattiva.
#' @param k_max integer(1) opzionale: il `k` del cluster. Va passato quando `sig`
#'   e' gia' un sottoinsieme, perche' dedurlo dai geni presenti abbasserebbe la
#'   soglia proprio nei cluster in cui serve di piu'.
#' @return list con `genes` (il data.frame filtrato), `n_dropped`, `k_max`,
#'   `k_min_richiesto`, `fallback` (TRUE se il filtro avrebbe svuotato la figura
#'   e si e' tornati all'insieme intero).
#' @keywords internal
.filter_genes_by_coverage <- function(sig, min_k_frac, k_max = NULL) {
  vuoto <- list(genes = sig, n_dropped = 0L, k_max = NA_integer_,
                k_min_richiesto = NA_integer_, fallback = FALSE)
  if (nrow(sig) == 0L) return(vuoto)
  if (is.null(sig$k_effective)) return(vuoto)
  if (is.null(min_k_frac) || is.na(min_k_frac) || min_k_frac <= 0) {
    vuoto$k_max <- as.integer(max(sig$k_effective, na.rm = TRUE))
    return(vuoto)
  }

  kmax <- if (!is.null(k_max)) as.integer(k_max) else {
    as.integer(max(sig$k_effective, na.rm = TRUE))
  }
  if (!is.finite(kmax) || kmax <= 0L) return(vuoto)

  kmin <- as.integer(ceiling(min_k_frac * kmax))
  # NA non passa di nascosto: un k ignoto non e' un k alto.
  tieni <- !is.na(sig$k_effective) & sig$k_effective >= kmin

  if (!any(tieni)) {
    # Mai svuotare una figura in silenzio: il lettore leggerebbe "nessun
    # risultato" invece di "filtro troppo severo per questo cluster".
    return(list(genes = sig, n_dropped = 0L, k_max = kmax,
                k_min_richiesto = kmin, fallback = TRUE))
  }
  list(genes = sig[tieni, , drop = FALSE],
       n_dropped = as.integer(sum(!tieni)),
       k_max = kmax, k_min_richiesto = kmin, fallback = FALSE)
}

#' Frase per la caption che dichiara il filtro applicato
#'
#' Un taglio di copertura non dichiarato si legge come "questi sono i geni piu'
#' forti", che e' falso. Se non e' stato tolto nulla la frase e' vuota, cosi' la
#' caption non si sporca senza motivo.
#'
#' @param filtro output di `.filter_genes_by_coverage()`.
#' @return character(1), eventualmente `""`.
#' @keywords internal
.coverage_filter_note <- function(filtro) {
  if (isTRUE(filtro$fallback)) {
    return(sprintf(
      paste0(" Coverage filter (>= %d of %d studies) not applied: no gene met ",
             "it in this cluster, so all significant genes are shown."),
      filtro$k_min_richiesto, filtro$k_max))
  }
  if (is.null(filtro$n_dropped) || filtro$n_dropped == 0L) return("")
  sprintf(
    paste0(" Genes measured in fewer than %d of %d studies were excluded from ",
           "ranking (%d genes): with few studies the random-effects model ",
           "estimates tau^2 as zero, which collapses the standard error and ",
           "inflates significance."),
    filtro$k_min_richiesto, filtro$k_max, filtro$n_dropped)
}

#' Il `k` del CLUSTER, non quello di un gene a caso
#'
#' `k_effective` in `cluster_pooled` ha un valore **per gene**: un gene assente
#' in alcuni studi ha meno studi che contribuiscono. Prendere `unique(...)[1L]`
#' o `dplyr::first()` restituisce il k di qualunque gene capiti per primo nel
#' parquet — misurato il 2026-07-31, **quattro schede di case study su nove
#' riportavano un k sbagliato** (IL1A 3 invece di 4, Parkinson 9 invece di 10,
#' SARS-CoV-2 32 invece di 33, JQ1 22 invece di 24).
#'
#' Il k del cluster e' il **massimo**: e' il criterio gia' usato dal deliverable
#' e dal filtro di copertura, e corrisponde al numero di studi che il dispatch
#' risolve (verificato su tutti e 191 il 2026-07-31, `20-preflight.R`).
#'
#' @param cp data.frame/tibble delle righe poolate di UN cluster.
#' @return integer(1), oppure `NA_integer_` se la colonna manca, e' tutta `NA`
#'   o non ci sono righe.
#' @keywords internal
.cluster_k_effective <- function(cp) {
  if (is.null(cp) || nrow(cp) == 0L) return(NA_integer_)
  # `%in% names()` e non `cp$k_effective`: su un tibble l'accesso a una colonna
  # assente emette un warning, e un warning in una funzione chiamata su ogni
  # cluster e' rumore che finisce per nascondere quelli veri.
  if (!"k_effective" %in% names(cp)) return(NA_integer_)
  k <- cp[["k_effective"]]
  k <- k[!is.na(k)]
  if (length(k) == 0L) return(NA_integer_)
  as.integer(max(k))
}
