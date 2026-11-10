# aiuti-misura.R — il riferimento di Expression Atlas per i 47 studi di sviluppo, e il giudizio delle previsioni.
# Lo usano `40-misura-oggi.R` (la pipeline di oggi) e `64-adatta-e-misura.R` (il lettore): stesso Atlas, stesso
# universo. Legge SOLO gli studi di sviluppo (cancello K5): gli studi di giudizio restano chiusi.
A <- "analysis/audit/2026-11-09-lettore-studio"
ATLAS_DIR <- "analysis/input/atlas-2026-11-09"
SEME <- 20261109L
B <- 2000L

studi_di_sviluppo <- function() {
  div <- read.delim(file.path(A, "30-divisione.tsv"), stringsAsFactors = FALSE)
  sv <- div[div$parte == "sviluppo", , drop = FALSE]
  stopifnot(nrow(sv) == 47L, !anyDuplicated(sv$gse), !anyDuplicated(sv$accession))
  sv[order(sv$gse, method = "radix"), ]
}

# Per ogni studio di sviluppo: la tabella di Atlas sui nostri GSM e l'universo
# (GSM dei gruppi di Atlas che stanno nel bacino sotto quello studio).
atlas_di_sviluppo <- function(sv) {
  stopifnot(all(sv$parte == "sviluppo"))
  leg <- read.delim(file.path(A, "33-legame.tsv"), stringsAsFactors = FALSE)
  out <- lapply(seq_len(nrow(sv)), function(i) {
    acc <- sv$accession[i]
    l <- leg[leg$accession == acc, , drop = FALSE]
    stopifnot(nrow(l) > 0L, all(l$gse == sv$gse[i]))
    cfg <- atlas_leggi_configurazione(file.path(ATLAS_DIR, paste0(acc, "-configuration.xml")))
    sdrf <- atlas_leggi_sdrf(file.path(ATLAS_DIR, paste0(acc, ".condensed-sdrf.tsv")))
    a <- atlas_tabella(cfg, sdrf, l[c("run", "gsm", "gse")])
    universo <- sort(intersect(names(a$partizione), l$gsm[l$nel_bacino == 1]), method = "radix")
    list(accession = acc, gse = sv$gse[i], atlas = a, universo = universo,
         n_gsm_atlas = length(a$partizione), n_run_esclusi = nrow(a$esclusi))
  })
  stats::setNames(out, sv$gse)
}

# Il giudizio di una previsione: la stima con il suo intervallo al 95% contro l'intervallo di rilevanza.
giudica <- function(ic_basso, ic_alto, basso, alto) {
  if (is.na(ic_basso) || is.na(ic_alto)) return("non giudicabile")
  if (ic_basso >= basso && ic_alto <= alto) return("confermata")
  if (ic_alto < basso || ic_basso > alto) return("smentita")
  "indeterminata"
}

# Una riga di testo per una misura di `tf_riassumi_misure()`.
riga_misura <- function(m, nome) {
  r <- m[m$misura == nome, ]
  sprintf("%s: %s/%s = %.1f%% (IC95 %.1f-%.1f%%)", nome, r$numeratore, r$denominatore,
          100 * r$quota, 100 * r$ic_basso, 100 * r$ic_alto)
}

forma_comune <- function(k) k[c("studio", "id", "trattato", "controllo")]
