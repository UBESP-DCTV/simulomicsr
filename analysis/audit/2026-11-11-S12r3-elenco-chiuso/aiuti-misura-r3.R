# aiuti-misura-r3.R — aiuti comuni alle misure di S12r3 (la terza prova piccola del lettore dello studio).
# Riusa il riferimento di S12r (`aiuti-misura.R`: Atlas e universo dei 47 studi di sviluppo) senza cambiarlo.
# Aggiunge alle tre letture di S12r2 la regola di S12r3 (spec par. 5.5, decisione del PI del 2026-11-11): i
# confronti di Atlas di solo contesto escono dal denominatore di (b) nelle letture principale e stretta.
# Legge SOLO gli studi di sviluppo (cancello K5): gli 82 studi di giudizio restano chiusi.
source("analysis/audit/2026-11-09-lettore-studio/aiuti-misura.R")   # A = cartella di S12r (ingressi)
R2 <- "analysis/audit/2026-11-10-S12r2-prova-ripetuta"               # termini di paragone
R3 <- "analysis/audit/2026-11-11-S12r3-elenco-chiuso"                # uscite di S12r3
SEME <- 20261111L                                                    # depositato in 00-previsioni.md
B <- 2000L
# Le quattro misure di S12r3. `principale` decide; `principale97` e' la lettura principale di S12r2 (senza la
# regola del contesto), accanto; `intera` e `stretta` accanto.
MISURE_R3 <- list(principale = list(lettura = "principale", contesto_fuori = TRUE),
                  principale97 = list(lettura = "principale", contesto_fuori = FALSE),
                  intera = list(lettura = "intera", contesto_fuori = FALSE),
                  stretta = list(lettura = "stretta", contesto_fuori = TRUE))
NOMI_R3 <- names(MISURE_R3)
VISTE <- file.path(A, "60-viste-v0.jsonl")
VISTE_SHA <- "2382a9ef97cf41d4f487078bd45e2d4c017dda104e8eb002f36881768eb6d86e"

leggi_jsonl <- function(f) lapply(readLines(f, encoding = "UTF-8"), jsonlite::fromJSON, simplifyVector = FALSE)
leggi_viste <- function(sv) {
  stopifnot(identical(unname(digest::digest(file = VISTE, algo = "sha256")), VISTE_SHA))
  v <- leggi_jsonl(VISTE); names(v) <- vapply(v, `[[`, "", "record_id")
  stopifnot(setequal(names(v), sv$gse), !anyDuplicated(names(v)))
  v[sv$gse]
}
campi_tempo_studio <- function(x, vista) {
  geo <- lapply(vista$tabella, function(col) {
    stats::setNames(vapply(col, function(e) as.character(e), ""), names(col))
  })
  tf_campi_di_tempo(x$atlas, if (length(geo)) geo else NULL)
}
# Una misura nelle quattro forme di S12r3. Ritorna una lista per nome (l'uscita di `tf_misura_studio()`).
misura_r3 <- function(g, partizione, confronti, x, campi) {
  stats::setNames(lapply(MISURE_R3, function(m) {
    r <- tf_misura_studio(g, partizione, confronti, x$atlas, x$universo, lettura = m$lettura, campi_tempo = campi,
                          contesto_fuori = m$contesto_fuori)
    r$riga$contesto_fuori <- m$contesto_fuori
    r
  }), NOMI_R3)
}
# Differenza appaiata sugli studi fra due metodi (L meno O): stesse estrazioni per i due metodi.
appaiato <- function(L, O, nomi = c("lettore", "oggi")) {
  n <- nrow(L); stopifnot(identical(L$studio, O$studio), identical(unique(L$lettura), unique(O$lettura)),
                          identical(unique(L$contesto_fuori), unique(O$contesto_fuori)))
  set.seed(SEME); estr <- matrix(sample.int(n, n * B, replace = TRUE), nrow = B)
  q <- function(num, den, idx) if (sum(den[idx]) > 0) sum(num[idx]) / sum(den[idx]) else NA_real_
  una <- function(nome, numL, denL, numO, denO) {
    v <- apply(estr, 1L, function(idx) q(numL, denL, idx) - q(numO, denO, idx))
    ic <- unname(stats::quantile(v, c(0.025, 0.975), na.rm = TRUE, names = FALSE))
    tutti <- seq_len(n)
    d <- data.frame(misura = nome, a = q(numL, denL, tutti), b = q(numO, denO, tutti),
                    differenza = q(numL, denL, tutti) - q(numO, denO, tutti), ic_basso = ic[1], ic_alto = ic[2],
                    ricampioni_senza_valore = sum(is.na(v)), stringsAsFactors = FALSE)
    names(d)[2:3] <- nomi
    d
  }
  id <- function(d) as.numeric(d$classe_gruppi %in% "identica")
  rbind(una("a_gruppi_identici", id(L), rep(1, n), id(O), rep(1, n)),
        una("b_confronti_ritrovati", L$n_b_uguale, L$n_b_den, O$n_b_uguale, O$n_b_den),
        una("c_errori_non_elencati", L$n_errori, L$n_giudicabili, O$n_errori, O$n_giudicabili))
}
conto <- function(codice, che, valore, atteso, basso, alto) {
  cat(sprintf("%s  %s: %s; atteso %s, rilevanza %s-%s  ->  %s\n", codice, che, valore, atteso, basso, alto,
              if (valore >= basso && valore <= alto) "confermata" else "smentita"))
}
scrivi_r3 <- function(d, f) utils::write.csv(d, file.path(R3, f), row.names = FALSE, na = "")
impila <- function(per) do.call(rbind, lapply(names(per), function(m) cbind(misura_r3 = m, per[[m]])))
fraz <- function(m, nome) { r <- m[m$misura == nome, ]; sprintf("%d/%d", as.integer(r$numeratore), as.integer(r$denominatore)) }
