# 01-traduzione.R — S9: la regola simulata, scritta una volta sola.
#
# L'insieme G e la traduzione sono quelli depositati in 00-previsioni.md:
#   - blocco «Greek and Coptic» U+0370-U+03FF e «Greek Extended» U+1F00-U+1FFF;
#   - due sosia: µ (U+00B5, segno di micro) e ß (U+00DF, usato per beta).
# Ogni lettera diventa il suo nome inglese (minuscola -> minuscolo, maiuscola ->
# iniziale maiuscola); forme con accento e varianti di simbolo -> lettera di base;
# eccezioni: μ (U+03BC) e µ (U+00B5) -> "u", ß -> "beta". Il resto della stringa
# NON cambia: niente tolower, niente normalizzazione Unicode dell'intera stringa
# (cambierebbe caratteri che non sono di G e confonderebbe la misura).

.G_RX <- "[µßͰ-Ͽἀ-῿]"

.G_NOMI <- c(alpha = "α", beta = "β", gamma = "γ", delta = "δ",
             epsilon = "ε", zeta = "ζ", eta = "η", theta = "θ",
             iota = "ι", kappa = "κ", lambda = "λ", mu = "μ",
             nu = "ν", xi = "ξ", omicron = "ο", pi = "π",
             rho = "ρ", sigma = "σ", tau = "τ", upsilon = "υ",
             phi = "φ", chi = "χ", psi = "ψ", omega = "ω")

.G_MAPPA <- local({
  m <- character(0)
  for (nm in names(.G_NOMI)) {
    lo <- .G_NOMI[[nm]]
    up <- toupper(lo)
    m[lo] <- nm
    if (!identical(up, lo)) m[up] <- paste0(toupper(substr(nm, 1, 1)), substr(nm, 2, nchar(nm)))
  }
  # eccezioni dichiarate
  m["μ"] <- "u"; m["µ"] <- "u"; m["ß"] <- "beta"
  # sigma finale e varianti di simbolo
  var <- c("ς" = "sigma", "ϐ" = "beta", "ϑ" = "theta", "ϒ" = "Upsilon",
           "ϕ" = "phi", "ϖ" = "pi", "ϰ" = "kappa", "ϱ" = "rho",
           "ϲ" = "sigma", "ϴ" = "Theta", "ϵ" = "epsilon", "Ϲ" = "Sigma")
  m[names(var)] <- var
  # forme con tonos/dialitika del blocco base
  ton <- c("Ά" = "Alpha", "Έ" = "Epsilon", "Ή" = "Eta", "Ί" = "Iota",
           "Ό" = "Omicron", "Ύ" = "Upsilon", "Ώ" = "Omega", "ΐ" = "iota",
           "Ϊ" = "Iota", "Ϋ" = "Upsilon", "ά" = "alpha", "έ" = "epsilon",
           "ή" = "eta", "ί" = "iota", "ΰ" = "upsilon", "ϊ" = "iota",
           "ϋ" = "upsilon", "ό" = "omicron", "ύ" = "upsilon", "ώ" = "omega")
  m[names(ton)] <- ton
  m
})

#' TRUE se la stringa contiene almeno un carattere di G
ha_G <- function(x) {
  x <- enc2utf8(as.character(x))
  !is.na(x) & grepl(.G_RX, x, perl = TRUE)
}

#' Un carattere di G -> la sua traduzione, o NA se non ha traduzione
.traduci_carattere <- function(ch) {
  t <- .G_MAPPA[ch]
  if (!is.na(t)) return(unname(t))
  cp <- utf8ToInt(ch)
  if (cp >= 0x1F00 && cp <= 0x1FFF) {          # Greek Extended: lettera di base
    base <- substr(stringi::stri_trans_nfd(ch), 1, 1)
    t <- .G_MAPPA[base]
    if (!is.na(t)) return(unname(t))
  }
  NA_character_
}

#' Traduce i caratteri di G; lascia intatto tutto il resto.
#' attr(, "non_tradotti"): i caratteri di G senza traduzione.
traduci_G <- function(x) {
  x <- enc2utf8(as.character(x))
  out <- x
  non_tradotti <- character(0)
  da_fare <- which(ha_G(x))
  for (i in da_fare) {
    ch <- strsplit(x[i], "", fixed = FALSE)[[1L]]
    j <- grepl(.G_RX, ch, perl = TRUE)
    for (k in which(j)) {
      t <- .traduci_carattere(ch[k])
      if (is.na(t)) non_tradotti <- c(non_tradotti, ch[k]) else ch[k] <- t
    }
    out[i] <- paste(ch, collapse = "")
  }
  attr(out, "non_tradotti") <- unique(non_tradotti)
  out
}

#' Categoria dei caratteri di G in una stringa: "greca" (lettere greche diverse
#' da μ), "micro" (μ o µ), "ss" (ß). Restituisce le categorie presenti, unite da "+".
categoria_G <- function(x) {
  x <- enc2utf8(as.character(x))
  vapply(x, function(s) {
    if (is.na(s) || !grepl(.G_RX, s, perl = TRUE)) return("")
    ch <- strsplit(s, "")[[1L]]
    ch <- ch[grepl(.G_RX, ch, perl = TRUE)]
    cat <- character(0)
    if (any(ch %in% c("μ", "µ"))) cat <- c(cat, "micro")
    if (any(ch == "ß")) cat <- c(cat, "ss")
    if (any(!(ch %in% c("μ", "µ", "ß")))) cat <- c(cat, "greca")
    paste(sort(cat), collapse = "+")
  }, character(1L), USE.NAMES = FALSE)
}
