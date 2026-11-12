# PROVA DA BUTTARE
# 10-letture.R — S12r5: le letture L1-L8. Ogni lettura e' la forma B0 (schema generato per ogni studio a elenco
# chiuso, prompt v2) con UNA frase del prompt riscritta senza cambiare il senso. Lo schema delle uscite e
# l'adattatore sono quelli di B0, senza cambi. Le frasi le estrae 10-frasi.R (seme 20261112); le riscritture
# stanno in 11-riscritture.csv e il loro giudizio cieco in 12-giudizio-esito-giro1.csv (01-carta.md).
# `source()` al livello piu' alto, dopo devtools::load_all("."): aggiunge L1-L8 a CAMBI_PROMPT, CAMBI e FORME di
# 10-forme.R di S12r4, cosi' prompt_forma(), schema_forma() e adatta_forma() valgono anche per le letture.
# Eseguito come script scrive i prompt 21-prompt-L<n>.md in questa cartella.
S5 <- "analysis/audit/2026-11-12-S12r5-piu-letture"
# 10-forme.R di S12r4 non si carica piu' cosi' com'e': dal commit da65625 il file 30-forma-finale.txt porta il testo
# dell'esito («FORMA FINALE: B0, senza cambi») e la riga che lo legge come elenco di cambi si ferma. I file di
# S12r4 sono evidenza chiusa e non si toccano: qui si carica 10-forme.R SENZA quella sola riga (la forma finale e'
# B0, quindi nessuna forma FIN da registrare). Lo stesso aiuto carica aiuti-misura-r4.R senza la riga che fa source
# di 10-forme.R.
sorgente_senza <- function(f, riga_fissa) {
  x <- readLines(f, warn = FALSE, encoding = "UTF-8"); i <- which(startsWith(x, riga_fissa))
  if (length(i) != 1L) stop(sprintf("%s: %d righe che cominciano con «%s» (ne serve una)", f, length(i), riga_fissa), call. = FALSE)
  eval(parse(text = x[-i], encoding = "UTF-8", keep.source = FALSE), envir = globalenv())
}
if (!exists("FORME")) sorgente_senza("analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/10-forme.R", "if (file.exists(F_FIN)) forma_finale(")
stopifnot(is.null(FORME$FIN))
RIS <- utils::read.csv(file.path(S5, "11-riscritture.csv"), stringsAsFactors = FALSE, encoding = "UTF-8", check.names = FALSE)
LETTURE <- RIS$lettura
stopifnot(identical(LETTURE, sprintf("L%d", 1:8)), !any(LETTURE %in% names(FORME)), !any(LETTURE %in% names(CAMBI)))
for (i in seq_len(nrow(RIS))) {
  CAMBI_PROMPT[[LETTURE[i]]] <- list(passo(RIS$originale[i], RIS$riscritta[i]))
  CAMBI[[LETTURE[i]]] <- list(lato = "B", prompt = LETTURE[i])
  FORME[[LETTURE[i]]] <- forma("B", LETTURE[i])
}
ORDINE_CAMBI <- names(CAMBI_PROMPT)
invisible(lapply(FORME[LETTURE], controlla_forma))
# il prompt di una corsa: per le letture sta in questa cartella, per B0 e' il file di S12r4 (uguale al prompt v2)
f_prompt_lettura <- function(nome) if (nome %in% LETTURE) file.path(S5, sprintf("21-prompt-%s.md", nome)) else f_prompt_forma(nome)
scrivi_prompt_lettura <- function(nome) { stopifnot(nome %in% LETTURE); con <- file(f_prompt_lettura(nome), "wb"); writeBin(charToRaw(prompt_forma(nome)), con); close(con) }

# ---- autocontrolli (a ogni source) ----
local({
  FR <- utils::read.csv(file.path(S5, "10-frasi.csv"), stringsAsFactors = FALSE, encoding = "UTF-8", check.names = FALSE)
  b0 <- prompt_forma("B0"); stopifnot(identical(b0, leggi_byte(F_PROMPT[["B"]])))
  tra_apici <- function(x) sort(regmatches(x, gregexpr("`[^`]*`", x))[[1]])
  pp <- vapply(LETTURE, prompt_forma, "")
  for (i in seq_len(nrow(RIS))) {
    o <- RIS$originale[i]; n <- RIS$riscritta[i]; p <- pp[[i]]
    stopifnot(identical(FR$frase[FR$n == RIS$n_frase[i]], o), identical(FR$lettura[FR$n == RIS$n_frase[i]], LETTURE[i]),   # la frase estratta col seme
              conta(b0, o) == 1L, conta(b0, n) == 0L, conta(p, n) == 1L, conta(p, o) == 0L,
              identical(sub(n, o, p, fixed = TRUE, useBytes = TRUE), enc2utf8(b0)) || identical(charToRaw(sub(n, o, p, fixed = TRUE, useBytes = TRUE)), charToRaw(b0)),   # il resto del prompt e' identico al byte
              identical(tra_apici(o), tra_apici(n)),                                                  # i nomi dei campi e i livelli speciali non cambiano
              abs(nchar(n) - nchar(o)) <= 10L,
              lengths(regmatches(n, gregexpr("[.] ", n))) == lengths(regmatches(o, gregexpr("[.] ", o))))   # una frase resta una frase
  }
  # nessuna lettura ha il prompt di un'altra lettura, di B0 o dei due placebo di S12r4
  tutti <- c(pp, B0 = b0, B0pl1 = prompt_forma("B0pl1"), B0pl2 = prompt_forma("B0pl2"))
  stopifnot(!anyDuplicated(unname(tutti)))
  # gli interruttori dello schema e dell'adattatore sono quelli di B0: una lettura cambia solo il prompt
  stopifnot(all(vapply(CAMBI[LETTURE], function(x) is.null(x$schema) && identical(x$lato, "B"), NA)))
  cat(sprintf("10-letture.R: %d letture (%s), ognuna = B0 con una frase del prompt riscritta; resto del prompt identico al byte; campi fra apici inversi uguali; nessun cambio allo schema\n",
              length(LETTURE), paste(LETTURE, collapse = ", ")))
})
if (sys.nframe() == 0L) {
  for (nome in LETTURE) scrivi_prompt_lettura(nome)
  cat("scritti", length(LETTURE), "prompt in", S5, "\n")
}
