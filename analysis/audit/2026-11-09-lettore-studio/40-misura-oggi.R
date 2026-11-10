# 40-misura-oggi.R — la pipeline di oggi (master S14 dello Stadio 2) contro la curazione di Expression Atlas,
# sui 47 studi di sviluppo. Task 8 del piano del lettore dello studio (S12r).
#
# Uso (SENZA --vanilla):
#   Rscript analysis/audit/2026-11-09-lettore-studio/40-misura-oggi.R \
#     > analysis/audit/2026-11-09-lettore-studio/40-out.txt 2>&1
#
# Ordine: (1) Atlas per i 47 studi; (2) cancello K2, Atlas contro Atlas; (3) la misura di oggi in due varianti;
# (4) il giudizio delle previsioni P1, P2, P8 depositate in `00-previsioni.md`.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-09-lettore-studio/aiuti-misura.R")
MASTER <- "analysis/p4-output/S14-stage2-master.jsonl"

sv <- studi_di_sviluppo()
rif <- atlas_di_sviluppo(sv)
cat("studi", length(rif), "\n")
cat("GSM nei gruppi di Atlas:", sum(vapply(rif, `[[`, 0L, "n_gsm_atlas")),
    " nell'universo (nel bacino):", sum(lengths(lapply(rif, `[[`, "universo"))),
    " run dei gruppi senza GSM:", sum(vapply(rif, `[[`, 0L, "n_run_esclusi")), "\n")

# ---- (2) Cancello K2: Atlas dato allo strumento come se fosse l'uscita del lettore -------------------------
k2 <- do.call(rbind, lapply(rif, function(x) {
  tf_misura_studio(x$gse, x$atlas$partizione, forma_comune(x$atlas$confronti), x$atlas, x$universo)$riga
}))
cat("\n== K2: Atlas contro Atlas ==\n")
cat("partizione identica:", sum(k2$classe_gruppi %in% "identica"), "su", nrow(k2), "\n")
cat("confronti che rispettano la definizione:", sum(k2$n_rispetta), " ritrovati uguali:", sum(k2$n_rispetta_uguale),
    " non elencati:", sum(k2$n_non_elencati), " di cui con un braccio fuori dall'universo:", sum(k2$n_fuori_atlas), "\n")
if (any(!(k2$classe_gruppi %in% "identica")) || any(k2$n_rispetta_uguale != k2$n_rispetta)) {
  print(k2[!(k2$classe_gruppi %in% "identica") | k2$n_rispetta_uguale != k2$n_rispetta,
           c("studio", "classe_gruppi", "n_universo", "n_comuni", "n_rispetta", "n_rispetta_uguale",
             "n_rispetta_verso_opposto")])
}
stopifnot(nrow(k2) == 47L, all(k2$classe_gruppi %in% "identica"), all(k2$n_rispetta_uguale == k2$n_rispetta),
          all(k2$n_giudicabili == 0L))   # un confronto con un braccio tutto fuori dal bacino non abbina: non e' giudicabile
cat("K2 passato\n")

# ---- (3) La pipeline di oggi -----------------------------------------------------------------------------
righe <- readLines(MASTER)
serie <- sub('^\\{"series_id":"(GSE[0-9]+)".*$', "\\1", righe)
stopifnot(all(grepl("^GSE[0-9]+$", serie)), !anyDuplicated(serie))
cat("\n== La pipeline di oggi ==\nrecord nel master S14:", length(righe), "\n")
oggi <- lapply(rif, function(x) {
  i <- match(x$gse, serie)
  if (is.na(i)) return(list(ha_record = FALSE, partizione = character(0),
                            confronti = tf_da_stage2(list(series_id = x$gse))$confronti))
  rec <- jsonlite::fromJSON(righe[i], simplifyVector = FALSE)
  stopifnot(identical(rec$series_id, x$gse))
  c(list(ha_record = TRUE), tf_da_stage2(rec))
})
rm(righe)
ha_record <- vapply(oggi, `[[`, TRUE, "ha_record")
cat("studi di sviluppo con un record:", sum(ha_record), "su", length(oggi), "\n")
if (any(!ha_record)) cat("senza record (zero gruppi e zero confronti, restano nel conto):",
                         paste(names(oggi)[!ha_record], collapse = ", "), "\n")

misura_variante <- function(variante) {
  lapply(names(rif), function(g) {
    x <- rif[[g]]; o <- oggi[[g]]
    k <- o$confronti
    # Principale: almeno 2 campioni per braccio nel record dello Stadio 2 (il gate `n_min = 2` dello Stadio 4).
    if (variante == "principale") k <- k[lengths(k$trattato) >= 2L & lengths(k$controllo) >= 2L, , drop = FALSE]
    m <- tf_misura_studio(g, o$partizione, k, x$atlas, x$universo)
    # Uno studio senza record non si toglie (K3): conta come partizione non identica.
    if (!o$ha_record) m$riga$classe_gruppi <- "senza_record"
    m$riga$accession <- x$accession; m$riga$ha_record <- o$ha_record
    m$riga$n_gruppi_oggi <- length(unique(o$partizione[names(o$partizione) %in% x$universo]))
    m$riga$n_gruppi_atlas <- length(unique(x$atlas$partizione[names(x$atlas$partizione) %in% x$universo]))
    m$riga$n_confronti_oggi_tutti <- nrow(o$confronti)
    m
  })
}
scrivi_csv <- function(d, f) utils::write.csv(d, file.path(A, f), row.names = FALSE, na = "")
n_braccio <- function(x) lengths(x)
esiti <- list()
for (variante in c("principale", "secondaria")) {
  mm <- misura_variante(variante)
  per_studio <- do.call(rbind, lapply(mm, `[[`, "riga"))
  stopifnot(nrow(per_studio) == 47L)                                       # K3: 47 studi su 47
  misure <- tf_riassumi_misure(per_studio, B = B, seme = SEME)
  esiti[[variante]] <- list(per_studio = per_studio, misure = misure)
  at <- do.call(rbind, lapply(mm, function(m) {
    k <- m$atlas
    data.frame(studio = k$studio, id = k$id, nome = k$nome, n_trattato = n_braccio(k$trattato),
               n_controllo = n_braccio(k$controllo), classe = k$classe, fattori_diversi = k$fattori_diversi,
               fattori_non_scritti = k$fattori_non_scritti, ritrovato = k$ritrovato, stringsAsFactors = FALSE)
  }))
  ne <- do.call(rbind, lapply(mm, function(m) {
    k <- m$non_elencati
    data.frame(studio = k$studio, id = k$id, n_trattato = n_braccio(k$trattato),
               n_controllo = n_braccio(k$controllo), giudizio = k$giudizio, stringsAsFactors = FALSE)
  }))
  esiti[[variante]]$atlas <- at; esiti[[variante]]$non_elencati <- ne

  cat(sprintf("\n== Variante %s (%s) ==\n", variante,
              if (variante == "principale") "almeno 2 campioni per braccio" else "tutti i confronti di oggi"))
  cat("(a) classi della partizione di oggi contro Atlas:\n"); print(table(per_studio$classe_gruppi, useNA = "ifany"))
  cat("campioni dell'universo:", sum(per_studio$n_universo), " comuni:", sum(per_studio$n_comuni),
      " solo in Atlas (oggi non li ha in un gruppo):", sum(per_studio$solo_atlas), "\n")
  cat("gruppi nell'universo: oggi", sum(per_studio$n_gruppi_oggi), " Atlas", sum(per_studio$n_gruppi_atlas), "\n")
  cat("(b) classi dei confronti di Atlas:\n"); print(table(at$classe, useNA = "ifany"))
  cat("    ritrovati, fra quelli che rispettano la definizione:\n")
  print(table(at$ritrovato[at$classe == "rispetta"], useNA = "ifany"))
  cat("    studi con almeno un confronto di Atlas ritrovato:", sum(per_studio$n_rispetta_uguale > 0L),
      "su", sum(per_studio$n_rispetta > 0L), "che ne hanno\n")
  cat("(c) confronti di oggi:", sum(per_studio$n_nostri), " non elencati da Atlas:", sum(per_studio$n_non_elencati), "\n")
  print(table(ne$giudizio, useNA = "ifany"))
  cat("misure:\n"); print(misure, row.names = FALSE, digits = 4)
}
pp <- esiti$principale$per_studio; ps <- esiti$secondaria$per_studio
scrivi_csv(pp, "40-per-studio-oggi.csv")
scrivi_csv(ps, "40-per-studio-oggi-secondaria.csv")
scrivi_csv(rbind(cbind(variante = "principale", esiti$principale$misure),
                 cbind(variante = "secondaria", esiti$secondaria$misure)), "40-misure-oggi.csv")
scrivi_csv(rbind(cbind(variante = "principale", esiti$principale$atlas),
                 cbind(variante = "secondaria", esiti$secondaria$atlas)), "40-confronti-atlas-oggi.csv")
scrivi_csv(rbind(cbind(variante = "principale", esiti$principale$non_elencati),
                 cbind(variante = "secondaria", esiti$secondaria$non_elencati)), "40-non-elencati-oggi.csv")

# ---- Quanto pesa la regola «un fattore non scritto non è una differenza» -----------------------------------
at <- esiti$principale$atlas
ns <- !is.na(at$fattori_non_scritti) & nzchar(at$fattori_non_scritti)
cat("\n== Sensibilità: fattori che i curatori non scrivono per un braccio ==\n")
cat("confronti di Atlas con almeno un fattore non scritto in un braccio:", sum(ns), "su", nrow(at), "\n")
cat("  di questi, classe con la regola usata:\n"); print(table(at$classe[ns]))
cat("  con la lettura stretta (non scritto = differenza): da `rispetta` a `piu_fattori`:",
    sum(ns & at$classe == "rispetta"), "; da `nessuna_differenza` a `rispetta`:",
    sum(ns & at$classe == "nessuna_differenza"), "\n")
cat("  ritrovati oggi fra i `rispetta` con un fattore non scritto:",
    sum(ns & at$classe == "rispetta" & at$ritrovato == "uguale"), "su", sum(ns & at$classe == "rispetta"), "\n")

# ---- Descrittiva per P8: quali fattori cambiano insieme nei confronti di Atlas con piu' fattori -------------
piu <- at[at$classe == "piu_fattori", ]
cat("\n== Confronti di Atlas con più di un fattore che cambia:", nrow(piu), "in", length(unique(piu$studio)), "studi ==\n")
print(as.data.frame(table(studio = piu$studio, fattori = piu$fattori_diversi), stringsAsFactors = FALSE) |>
        subset(Freq > 0), row.names = FALSE)

# ---- (4) Le previsioni -----------------------------------------------------------------------------------
m <- esiti$principale$misure
prev <- function(codice, misura, basso, alto, atteso) {
  r <- m[m$misura == misura, ]
  cat(sprintf("%s  %s  atteso %s, rilevanza %.0f-%.0f%%  ->  %s\n", codice, riga_misura(m, misura), atteso,
              100 * basso, 100 * alto, giudica(r$ic_basso, r$ic_alto, basso, alto)))
}
cat("\n== Previsioni (variante principale; bootstrap sugli studi, B =", B, ", seme", SEME, ") ==\n")
prev("P1", "b_confronti_ritrovati", 0.20, 0.50, "35%")
prev("P2", "a_gruppi_identici", 0.15, 0.45, "30%")
prev("P8", "atlas_piu_fattori", 0.05, 0.20, "10%")
cat("K3 passato: la misura di oggi copre", nrow(pp), "studi su 47\n")
cat("FINITO\n")
