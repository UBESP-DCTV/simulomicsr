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
