# PROVA DA BUTTARE
# 27-tollera.R — S12r2: la sensibilita' sulla forma delle voci, DICHIARATA DOPO I NUMERI (2026-11-10, dopo la
# misura di M, M0 e G1). Non cambia la misura principale, ne' l'adattatore v1 (22-adattatore-v1.R), ne' l'esito
# di una previsione o della regola di esito. Serve alla lettura dei disaccordi: dice che cosa resta, studio per
# studio, quando si toglie la sola forma delle voci.
#
# `tollera(raw, v, modo)` riscrive l'uscita del modello prima dell'adattatore v1, senza aggiungere informazione:
#   T1  a `source_columns` di un fattore si aggiunge ogni colonna nota della vista che una voce del fattore nomina
#       in `when` (il caso: un fattore annidato che da' `not applicable` con la colonna del fattore padre);
#   T2  una voce con due o piu' condizioni sulla stessa colonna diventa una voce per valore, con lo stesso livello
#       (il caso: la forma delle voci del lettore v0);
#   T3  (solo modo `forma_na`) in una colonna di soggetto la stringa «NA» vale «non scritto», anche se il modello
#       non l'ha messa in `missing_values`.
# Modi: `forma` = T1 + T2; `forma_na` = T1 + T2 + T3. Si usa da 24-misura.R con S12R2_SENSIBILITA=<modo>: le
# tabelle escono col prefisso 27-<modo>-<modello>- e lo script si ferma prima delle previsioni.
tollera <- function(raw, v, modo) {
  stopifnot(modo %in% c("forma", "forma_na"))
  if (is.na(raw) || !nzchar(raw)) return(raw)
  u <- tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE), error = function(e) NULL)
  if (is.null(u) || !length(u$factors)) return(raw)
  note_col <- c("gsm", names(v$tabella), names(v$costanti))
  for (i in seq_along(u$factors)) {
    f <- u$factors[[i]]
    nuove <- list()
    for (a in f$assignment) {
      cc <- vapply(a$when, function(k) k$column, ""); vv <- vapply(a$when, function(k) k$value, "")
      if (!anyDuplicated(cc)) { nuove <- c(nuove, list(a)); next }
      col <- unique(cc)
      gr <- expand.grid(lapply(col, function(k) unique(vv[cc == k])), stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
      for (r in seq_len(nrow(gr))) {
        a2 <- a
        a2$when <- lapply(seq_along(col), function(j) list(column = col[j], value = gr[[j]][r]))
        nuove <- c(nuove, list(a2))
      }
    }
    f$assignment <- nuove
    fonti <- as.character(unlist(f$source_columns))
    usate <- unique(unlist(lapply(nuove, function(a) vapply(a$when, function(k) k$column, ""))))
    f$source_columns <- as.list(c(fonti, setdiff(intersect(usate, note_col), fonti)))
    u$factors[[i]] <- f
  }
  if (modo == "forma_na") for (i in seq_along(u$other_columns)) {
    k <- u$other_columns[[i]]
    if (identical(k$role, "subject") && k$column %in% names(v$tabella) && any(unlist(v$tabella[[k$column]]) == "NA"))
      u$other_columns[[i]]$missing_values <- as.list(union(as.character(unlist(k$missing_values)), "NA"))
  }
  as.character(jsonlite::toJSON(u, auto_unbox = TRUE, null = "null"))
}
