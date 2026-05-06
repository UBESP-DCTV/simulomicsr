#' Legge il xlsx classificato in un tibble normalizzato
#'
#' Le colonne attese sono quelle documentate in `data-raw/README.md`.
#' Tutto viene letto come `character` (stabile), il caller converte se serve.
#'
#' @param path path al file xlsx
#' @param n_max numero massimo di righe da leggere (default `Inf`)
#' @return tibble con colonne `geo_accession`, `series_id`, `string`,
#'   `trtctr_EP`, `trtctr`, `treat`, `gold`
#' @keywords internal
read_samples_input <- function(path, n_max = Inf) {
  if (!fs::file_exists(path)) {
    rlang::abort(
      glue::glue("File non trovato: {path}"),
      class = "simulomicsr_eval_sampling_missing_file",
      path = path
    )
  }

  df <- readxl::read_excel(path, n_max = n_max)
  required <- c("geo_accession", "series_id", "string",
                "trtctr_EP", "trtctr", "treat", "gold")
  missing  <- setdiff(required, names(df))
  if (length(missing) > 0L) {
    rlang::abort(
      glue::glue("xlsx manca colonne attese: {paste(missing, collapse = ', ')}"),
      class = "simulomicsr_eval_sampling_bad_schema",
      missing = missing
    )
  }

  tibble::tibble(
    geo_accession = as.character(df$geo_accession),
    series_id     = as.character(df$series_id),
    string        = as.character(df$string),
    trtctr_EP     = as.character(df$trtctr_EP),
    trtctr        = as.character(df$trtctr),
    treat         = as.character(df$treat),
    gold          = as.character(df$gold)
  )
}

#' Costruisce un dev set stratificato per la valutazione iniziale dello Stadio 1
#'
#' Stratificazione (spec §6.1):
#' - 60% `easy_agree`: `trtctr_EP == trtctr` (baseline shallow d'accordo con
#'   gold manuale) — controlla regressioni
#' - 30% `disagree_ep_vs_shallow`: `trtctr_EP != trtctr` — qui sta il valore
#'   del classificatore LLM
#' - 10% `short_ambiguous`: `nchar(string) <= 60` — robustezza su input poveri
#'
#' Quando uno strato non ha abbastanza candidati, la funzione fallisce con
#' errore tipizzato (preferiamo failure esplicito a un dev set sbilanciato).
#'
#' @param samples tibble da `read_samples_input()`
#' @param n dimensione del dev set (default 100; ratio 60/30/10)
#' @param seed seed deterministico (default 1812)
#' @return tibble di `n` sample con colonna aggiuntiva `stratum`
#' @keywords internal
build_dev_set <- function(samples, n = 100L, seed = 1812L) {
  stopifnot(
    inherits(samples, "data.frame"),
    is.numeric(n), n > 0L,
    all(c("geo_accession", "string", "trtctr_EP", "trtctr") %in% names(samples))
  )

  n_easy  <- round(n * 0.60)
  n_disag <- round(n * 0.30)
  n_short <- n - n_easy - n_disag  # garantisce somma = n

  pool_easy  <- samples[samples$trtctr_EP == samples$trtctr, , drop = FALSE]
  pool_disag <- samples[samples$trtctr_EP != samples$trtctr, , drop = FALSE]
  pool_short <- samples[nchar(samples$string) <= 60L, , drop = FALSE]

  if (nrow(pool_easy)  < n_easy)  rlang::abort(
    glue::glue("Strato easy_agree insufficiente: {nrow(pool_easy)} < {n_easy}"),
    class = "simulomicsr_eval_sampling_thin_stratum", stratum = "easy_agree"
  )
  if (nrow(pool_disag) < n_disag) rlang::abort(
    glue::glue("Strato disagree_ep_vs_shallow insufficiente: {nrow(pool_disag)} < {n_disag}"),
    class = "simulomicsr_eval_sampling_thin_stratum", stratum = "disagree_ep_vs_shallow"
  )
  if (nrow(pool_short) < n_short) rlang::abort(
    glue::glue("Strato short_ambiguous insufficiente: {nrow(pool_short)} < {n_short}"),
    class = "simulomicsr_eval_sampling_thin_stratum", stratum = "short_ambiguous"
  )

  pick <- function(df, n, label) {
    offset <- match(label, c("easy_agree", "disagree_ep_vs_shallow", "short_ambiguous"))
    idx <- withr::with_seed(seed + offset,
                            sample.int(nrow(df), n, replace = FALSE))
    df  <- df[idx, , drop = FALSE]
    df$stratum <- label
    df
  }

  out <- dplyr::bind_rows(
    pick(pool_easy,  n_easy,  "easy_agree"),
    pick(pool_disag, n_disag, "disagree_ep_vs_shallow"),
    pick(pool_short, n_short, "short_ambiguous")
  )
  tibble::as_tibble(out)
}
