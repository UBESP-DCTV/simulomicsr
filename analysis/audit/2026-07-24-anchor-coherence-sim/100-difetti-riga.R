# Rilevatore dei difetti a livello di RIGA dentro i gruppi coerenti.
#
# Il gruppo puo' misurare la cosa giusta e contenere lo stesso righe mal appaiate.
# Cinque forme, tutte viste leggendo i dati veri:
#   A linea/tessuto diverso fra i due bracci  ("LAPC4 Enza" vs "CWR-22Rv1 Vehicle")
#   B combinazione non catturata              ("TNF-alpha IL-1alpha" vs "Control")
#   C tempo non appaiato                      ("SARS 24h" vs "Control 0h")
#   D perturbazione genetica su un solo braccio ("+ shMfn2 + TNF" vs "+ DMSO")
#   E soggetto/donatore diverso               ("LPS N35" vs "untreated N37")
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
oe <- .load_ontology_dicts()
r <- readRDS(file.path(SC, "fase1-v9-results.rds")); pm <- r$pm; agg <- r$agg
ver <- read.csv(file.path(SC, "v10-census-verdicts-FINAL.csv"), stringsAsFactors = FALSE)
coh <- ver$ckey[ver$verdetto == "COERENTE"]
m <- pm[pm$elig & pm$ckey %in% coh, ]
u <- m |> group_by(ckey, study_id, treated_label, control_label) |>
  summarise(n = n(), .groups = "drop")
cat("righe uniche da controllare:", nrow(u), "in", n_distinct(u$ckey), "gruppi\n")

## --- A: linee cellulari (token con lettere E cifre, o nomi noti) ---
LINEE_RX <- "\\b([a-z]{2,6}[-_ ]?[0-9]{2,4}[a-z]?|hela|jurkat|hek293[a-z]*|imr90|calu[- ]?3|caco[- ]?2|thp[- ]?1|lncap[a-z0-9]*|vcap|lapc[- ]?4|du145|mcf7|mcf[- ]?10a|sum159|hepg2|huh7|beas[- ]?2b|a2780|skov3|panc[- ]?1|raji|k562|u87|u251|t47d|bt[- ]?474|sk[- ]?br[- ]?3|22rv1|c4[- ]?2|pc3|h1299|h460|h358|a375)\\b"
linee <- function(x) {
  s <- tolower(gsub("[^A-Za-z0-9 ._-]", " ", x))
  unique(unlist(regmatches(s, gregexpr(LINEE_RX, s, perl = TRUE))))
}
## --- C: tempi ---
TEMPI_RX <- "\\b([0-9]+(\\.[0-9]+)?\\s?(h|hr|hrs|hour|hours|d|day|days|dpi|hpi|min|week|weeks|mo|month|months))\\b"
tempi <- function(x) unique(gsub("\\s", "", unlist(regmatches(tolower(x), gregexpr(TEMPI_RX, tolower(x), perl = TRUE)))))
## --- D: perturbazioni genetiche ---
GEN_RX <- "\\b(sh[a-z0-9]{2,}|si[a-z0-9]{2,}|sg[a-z0-9]{2,}|[a-z0-9]+[- ]?ko\\b|knockout|knockdown|transgene|transgenic|crispr|overexpress[a-z]*)\\b"
genet <- function(x) unique(unlist(regmatches(tolower(x), gregexpr(GEN_RX, tolower(x), perl = TRUE))))
## --- E: soggetti/donatori ---
SOGG_RX <- "\\b(donor[ _-]?[a-z0-9]+|patient[ _-]?[a-z0-9]+|subject[ _-]?[a-z0-9]+|[nphc][0-9]{2,3})\\b"
sogg <- function(x) unique(unlist(regmatches(tolower(x), gregexpr(SOGG_RX, tolower(x), perl = TRUE))))
## --- B: agenti (riuso il resolver di produzione, ora con le guardie) ---
.cache_ag <- new.env(parent = emptyenv())
agente <- function(tok) {
  if (exists(tok, envir = .cache_ag, inherits = FALSE)) return(get(tok, envir = .cache_ag))
  ok <- function(id) !is.na(id) && nzchar(id) && !startsWith(id, "STR:")
  res <- ""
  if (nchar(tok) >= 4) {
    x <- .normalize_compound_to_chebi(tok, oe); if (ok(x$id)) res <- x$id
    if (!nzchar(res)) { x <- .normalize_cytokine_to_hgnc(tok, oe); if (ok(x$id)) res <- x$id }
    if (!nzchar(res)) { x <- .normalize_pathogen_to_taxid(tok, oe); if (ok(x$id)) res <- x$id }
  }
  assign(tok, res, envir = .cache_ag); res
}
agenti <- function(x) {
  tk <- strsplit(tolower(gsub("[^A-Za-z0-9 -]", " ", x)), " +")[[1]]
  tk <- unique(tk[nchar(tk) >= 4])
  a <- unique(vapply(tk, agente, "")); a[nzchar(a)]
}

n <- nrow(u); A <- B <- C <- D <- E <- logical(n)
for (i in seq_len(n)) {
  t <- u$treated_label[i]; c0 <- u$control_label[i]
  lt <- linee(t); lc <- linee(c0)
  A[i] <- length(lt) > 0 && length(lc) > 0 && length(intersect(lt, lc)) == 0
  at <- agenti(t); ac <- agenti(c0)
  B[i] <- length(setdiff(at, ac)) >= 2
  tt <- tempi(t); tc <- tempi(c0)
  C[i] <- length(tt) > 0 && length(tc) > 0 && length(intersect(tt, tc)) == 0
  gt <- genet(t); gc2 <- genet(c0)
  D[i] <- (length(gt) > 0) != (length(gc2) > 0)
  st <- sogg(t); sc <- sogg(c0)
  E[i] <- length(st) > 0 && length(sc) > 0 && length(intersect(st, sc)) == 0
  if (i %% 300 == 0) cat("  ", i, "/", n, "\n")
}
u$A_linea <- A; u$B_combo <- B; u$C_tempo <- C; u$D_genetico <- D; u$E_soggetto <- E
u$difetto <- A | B | C | D | E
cat("\n=== RIGHE CON DIFETTO ===\n")
cat(sprintf("righe totali: %d | con almeno un difetto: %d (%.1f%%)\n",
            nrow(u), sum(u$difetto), 100 * mean(u$difetto)))
print(data.frame(A_linea_diversa = sum(A), B_combinazione = sum(B), C_tempo_non_appaiato = sum(C),
                 D_genetico_asimmetrico = sum(D), E_soggetto_diverso = sum(E)))
g <- u |> group_by(ckey) |> summarise(righe = n(), difettose = sum(difetto),
        studi_difettosi = n_distinct(study_id[difetto]), studi = n_distinct(study_id), .groups = "drop") |>
  mutate(quota = round(100 * difettose / righe)) |> arrange(desc(quota), desc(difettose))
cat("\n=== GRUPPI PIU' COLPITI (quota di righe difettose) ===\n")
print(as.data.frame(head(g |> filter(difettose > 0), 30)), row.names = FALSE)
cat(sprintf("\ngruppi senza alcun difetto: %d / %d\n", sum(g$difettose == 0), nrow(g)))
write.csv(u, file.path(SC, "difetti-riga.csv"), row.names = FALSE)
write.csv(g, file.path(SC, "difetti-per-gruppo.csv"), row.names = FALSE)
