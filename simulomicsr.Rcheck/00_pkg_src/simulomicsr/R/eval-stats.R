#' Wilson 95% CI per proporzione
#'
#' Implementa la formula di Wilson (1927) per intervallo di confidenza
#' su proporzione binomiale. Preferito a normal approximation per p
#' vicino ai bordi (0 o 1) o n piccolo. Ritorna NA se n=0.
#'
#' @param successes numero di successi (intero)
#' @param n numero totale di osservazioni (intero)
#' @param conf livello di confidenza (default 0.95)
#' @return list con campi estimate, lower, upper, n
#' @export
wilson_ci <- function(successes, n, conf = 0.95) {
  stopifnot(successes >= 0L, n >= 0L, successes <= n,
            conf > 0, conf < 1)
  if (n == 0L) {
    return(list(estimate = NA_real_, lower = NA_real_,
                upper = NA_real_, n = 0L))
  }
  z <- stats::qnorm(1 - (1 - conf) / 2)
  p <- successes / n
  denom <- 1 + z^2 / n
  center <- (p + z^2 / (2 * n)) / denom
  half_width <- (z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2))) / denom
  list(
    estimate = p,
    lower = max(0, center - half_width),
    upper = min(1, center + half_width),
    n = n
  )
}

#' McNemar test paired su due classificatori
#'
#' Confronta due classificatori sulle stesse osservazioni rispetto a un
#' gold standard implicito (ognuno e' "correct" o "wrong"). Calcola b
#' (A correct, B wrong) e c (A wrong, B correct), poi statistica chi^2 =
#' (b-c)^2 / (b+c). Sample con NA in entrambi i predittori esclusi.
#'
#' Equivalente a mcnemar.test(table(pred_a, pred_b), correct = continuity).
#'
#' @param pred_a character vector con valori "correct"/"wrong" del primo classificatore
#' @param pred_b character vector con valori "correct"/"wrong" del secondo classificatore
#' @param continuity applica correzione di continuita' (Yates), default FALSE
#' @return list con statistic, p_value, b, c, n
#' @export
mcnemar_paired <- function(pred_a, pred_b, continuity = FALSE) {
  stopifnot(length(pred_a) == length(pred_b))
  keep <- !is.na(pred_a) & !is.na(pred_b)
  a <- pred_a[keep]
  b_vec <- pred_b[keep]
  n <- length(a)
  b <- sum(a == "correct" & b_vec == "wrong")
  c <- sum(a == "wrong" & b_vec == "correct")
  if (b + c == 0L) {
    return(list(statistic = NA_real_, p_value = NA_real_,
                b = b, c = c, n = n))
  }
  chi2 <- if (continuity) {
    (abs(b - c) - 1)^2 / (b + c)
  } else {
    (b - c)^2 / (b + c)
  }
  p_value <- stats::pchisq(chi2, df = 1, lower.tail = FALSE)
  list(statistic = chi2, p_value = p_value, b = b, c = c, n = n)
}

#' Bootstrap CI sul delta accuracy tra due classificatori
#'
#' Resampling sample-level (non bootstrap pairs separati). A ogni iterazione
#' rifa il calcolo accuracy_a - accuracy_b sui sample resampled. Ritorna CI
#' percentile classico.
#'
#' @param pred_a character vector "correct"/"wrong"
#' @param pred_b character vector "correct"/"wrong"
#' @param n_iter numero di iterazioni bootstrap (default 1000)
#' @param seed seed per riproducibilita' (default 1812)
#' @param conf livello di confidenza (default 0.95)
#' @return list con delta, lower, upper, n_iter
#' @export
bootstrap_delta_ci <- function(pred_a, pred_b, n_iter = 1000L,
                                seed = 1812L, conf = 0.95) {
  stopifnot(length(pred_a) == length(pred_b),
            n_iter >= 100L, conf > 0, conf < 1)
  keep <- !is.na(pred_a) & !is.na(pred_b)
  a <- pred_a[keep]
  b <- pred_b[keep]
  n <- length(a)
  if (n == 0L) {
    return(list(delta = NA_real_, lower = NA_real_,
                upper = NA_real_, n_iter = n_iter))
  }
  delta_obs <- mean(a == "correct") - mean(b == "correct")
  set.seed(seed)
  deltas <- numeric(n_iter)
  for (i in seq_len(n_iter)) {
    idx <- sample.int(n, replace = TRUE)
    deltas[i] <- mean(a[idx] == "correct") - mean(b[idx] == "correct")
  }
  alpha <- 1 - conf
  ci <- stats::quantile(deltas, probs = c(alpha / 2, 1 - alpha / 2),
                        names = FALSE)
  list(delta = delta_obs, lower = ci[1], upper = ci[2], n_iter = n_iter)
}

#' Holm correction per p-values multipli
#'
#' Wrapper su p.adjust(method = "holm") per consistenza nel report.
#' Holm e' uniformly more powerful di Bonferroni a parita' di FWER.
#'
#' @param p_values numeric vector di p-values
#' @return numeric vector di p-values corretti
#' @export
holm_adjust <- function(p_values) {
  stats::p.adjust(p_values, method = "holm")
}
