# 07-valori-speciali-atlas.R — sonda di disegno, PRIMA delle previsioni: come i curatori di Expression Atlas
# scrivono «non applicabile» e «non disponibile» nei fattori dei 47 studi di sviluppo, e in quali coppie di
# fattori uno e' annidato nell'altro. Legge solo il riferimento: nessuna uscita di pipeline, nessuna misura.
# Uso (SENZA --vanilla): Rscript analysis/audit/2026-11-10-S12r2-prova-ripetuta/07-valori-speciali-atlas.R \
#   > analysis/audit/2026-11-10-S12r2-prova-ripetuta/07-out.txt 2>&1
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-09-lettore-studio/aiuti-misura.R")
sv <- studi_di_sviluppo(); rif <- atlas_di_sviluppo(sv)
str(rif[[1]]$atlas$tabella, max.level = 2, vec.len = 3)
spec <- "^(not applicable|not available|n/?a|none|unknown|undetermined|not specified|not stated)$"
cat("\n== valori speciali nei fattori di Atlas (studio, fattore, valore, campioni nell'universo) ==\n")
for (g in names(rif)) {
  L <- rif[[g]]$atlas$tabella$livelli
  if (is.null(L)) next
  u <- rif[[g]]$universo
  for (f in setdiff(colnames(L), c("gsm", "campione"))) {
    v <- as.character(L[[f]]); names(v) <- if ("gsm" %in% colnames(L)) L$gsm else rownames(L)
    v <- v[names(v) %in% u]
    t <- table(v[grepl(spec, v, ignore.case = TRUE) | v == TF_NON_SCRITTO])
    if (length(t)) cat(g, "|", f, "|", paste(sprintf("%s=%d", names(t), t), collapse = "; "), "| n", length(v), "\n")
  }
}

# Annidamento: il fattore B e' annidato in A quando l'insieme dei campioni con B = valore speciale e' l'unione di
# uno o piu' livelli interi di A, e almeno un livello di A non ha il valore speciale.
cat("\n== annidamento (studio | B | valore | A | livelli di A tutti dentro | livelli di A a cavallo) ==\n")
for (g in names(rif)) {
  tab <- rif[[g]]$atlas$tabella; L <- tab$livelli; if (is.null(L) || ncol(L) < 1L) next
  ok <- tab$campioni %in% rif[[g]]$universo
  for (b in colnames(L)) for (val in c("not applicable", "not available", TF_NON_SCRITTO)) {
    dentro <- ok & L[[b]] == val
    if (!any(dentro)) next
    altri <- setdiff(colnames(L), b)
    if (!length(altri)) { cat(g, "|", b, "|", val, "| nessun altro fattore\n"); next }
    for (a in altri) {
      q <- tapply(dentro[ok], L[[a]][ok], mean)
      cat(g, "|", b, "|", val, "|", a, "| tutti:", paste(names(q)[q == 1], collapse = ", "),
          "| a cavallo:", paste(sprintf("%s (%.0f%%)", names(q)[q > 0 & q < 1], 100 * q[q > 0 & q < 1]), collapse = ", "),
          "| livelli senza:", sum(q == 0), "\n")
    }
  }
}
