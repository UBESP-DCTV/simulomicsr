# 10-misura-oggi.R — il riferimento con le regole nuove e la pipeline di oggi, nelle tre letture (S12r2).
#
# Uso (SENZA --vanilla):
#   Rscript analysis/audit/2026-11-10-S12r2-prova-ripetuta/10-misura-oggi.R \
#     > analysis/audit/2026-11-10-S12r2-prova-ripetuta/10-out.txt 2>&1
#
# Ordine: (1) Atlas e campi di tempo dei 47 studi; (2) cancello K2 nelle tre letture e caso noto del tempo zero;
# (3) il riferimento: previsioni R1-R3; (4) la pipeline di oggi (master S14 dello Stadio 2, almeno 2 campioni per
# braccio) nelle tre letture; cancello K1 (lettura intera = S12r) e K3; previsioni O1-O3.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-10-S12r2-prova-ripetuta/aiuti-misura-r2.R")
MASTER <- "analysis/p4-output/S14-stage2-master.jsonl"

sv <- studi_di_sviluppo()
rif <- atlas_di_sviluppo(sv)
viste <- leggi_viste(sv)
stopifnot(identical(names(rif), sv$gse), identical(names(viste), sv$gse))
campi <- stats::setNames(lapply(sv$gse, function(g) campi_tempo_studio(rif[[g]], viste[[g]])), sv$gse)
cat("studi", length(rif), "\n")
cat("\n== Campi di tempo scelti dalla regola (nome con «time» all'inizio di una parola) ==\n")
for (g in sv$gse) for (k in names(campi[[g]])) {
  t <- table(campi[[g]][[k]]); cl <- .tf_classe_tempo(names(t))
  cat(sprintf("%s | %s | %s\n", g, k, paste(sprintf("'%s'=%d [%s]", names(t), as.integer(t), cl), collapse = "; ")))
}
cat("studi con almeno un campo di tempo:", sum(lengths(campi) > 0L), "su 47\n")

# ---- (2) K2: Atlas contro Atlas, nelle tre letture ---------------------------------------------------------
k2 <- lapply(LETTURE, function(l) do.call(rbind, lapply(sv$gse, function(g) {
  x <- rif[[g]]
  tf_misura_studio(g, x$atlas$partizione, forma_comune(x$atlas$confronti), x$atlas, x$universo, lettura = l,
                   campi_tempo = campi[[g]])$riga
})))
names(k2) <- LETTURE
cat("\n== K2: Atlas contro Atlas ==\n")
for (l in LETTURE) {
  d <- k2[[l]]
  cat(sprintf("%s: partizione identica %d su %d; denominatore di (b) %d, ritrovati uguali %d; giudicabili fra i non elencati %d\n",
              l, sum(d$classe_gruppi %in% "identica"), nrow(d), sum(d$n_b_den), sum(d$n_b_uguale), sum(d$n_giudicabili)))
  stopifnot(nrow(d) == 47L, all(d$classe_gruppi %in% "identica"), all(d$n_b_uguale == d$n_b_den),
            all(d$n_giudicabili == 0L))
}

# ---- (3) Il riferimento con le regole nuove -----------------------------------------------------------------
classi <- lapply(LETTURE, function(l) do.call(rbind, lapply(sv$gse, function(g) {
  x <- rif[[g]]
  m <- tf_misura_studio(g, x$atlas$partizione, forma_comune(x$atlas$confronti), x$atlas, x$universo, lettura = l,
                        campi_tempo = campi[[g]])$atlas
  data.frame(lettura = l, studio = m$studio, id = m$id, nome = m$nome, n_trattato = lengths(m$trattato),
             n_controllo = lengths(m$controllo), classe = m$classe, fattori_diversi = m$fattori_diversi,
             fattori_non_scritti = m$fattori_non_scritti, fattori_annidati = m$fattori_annidati,
             tempo_zero = m$tempo_zero, tempo_zero_verso = m$tempo_zero_verso, tempo_zero_campo = m$tempo_zero_campo,
             in_b = m$in_b, stringsAsFactors = FALSE)
})))
names(classi) <- LETTURE
scrivi_r2(do.call(rbind, classi), "10-confronti-atlas-tre-letture.csv")
cp <- classi$principale; ci <- classi$intera; cs <- classi$stretta
stopifnot(nrow(cp) == 123L, identical(cp$id, ci$id), identical(cp$tempo_zero, ci$tempo_zero),
          identical(cp$tempo_zero, cs$tempo_zero))
cat("\n== Il riferimento: 123 confronti di Atlas ==\n")
for (l in LETTURE) { cat(l, ": classi\n"); print(table(classi[[l]]$classe, useNA = "ifany")) }
cat("classe intera (righe) contro principale (colonne):\n"); print(table(intera = ci$classe, principale = cp$classe))
cat("classe principale (righe) contro stretta (colonne):\n"); print(table(principale = cp$classe, stretta = cs$classe))
cat("\nmarca tempo_zero, per studio e verso (non dipende dalla lettura):\n")
print(table(studio = cp$studio[cp$tempo_zero], verso = cp$tempo_zero_verso[cp$tempo_zero]))
cat("marca tempo_zero per classe (lettura principale):\n"); print(table(classe = cp$classe, tempo_zero = cp$tempo_zero))
cat("confronti con la marca:\n")
print(cp[cp$tempo_zero, c("studio", "id", "nome", "classe", "tempo_zero_verso", "tempo_zero_campo")], row.names = FALSE)
cat("confronti che la regola del fattore annidato tocca (lettura principale):\n")
print(cp[!is.na(cp$fattori_annidati) & nzchar(cp$fattori_annidati) | cp$classe == "non_applicabile",
         c("studio", "id", "nome", "classe", "fattori_diversi", "fattori_annidati")], row.names = FALSE)
cat("confronti che cambiano classe fra intera e principale:\n")
print(cbind(cp[ci$classe != cp$classe, c("studio", "id", "nome")], intera = ci$classe[ci$classe != cp$classe],
            intera_diversi = ci$fattori_diversi[ci$classe != cp$classe], principale = cp$classe[ci$classe != cp$classe]),
      row.names = FALSE)

# K2, il caso noto: i confronti di GSE49608 contro il tempo «0 hour»
noto <- cp[cp$studio == "GSE49608", ]
contro_zero <- grepl("0 hour", noto$nome, fixed = TRUE) & !grepl("[1-9]0 hour", noto$nome)
cat("\nK2, caso noto: GSE49608 ha", nrow(noto), "confronti di Atlas;", sum(noto$tempo_zero), "con la marca\n")
print(noto[c("id", "nome", "classe", "tempo_zero", "tempo_zero_verso", "tempo_zero_campo")], row.names = FALSE)
stopifnot(sum(noto$tempo_zero) > 0L)
cat("K2 passato: 47 su 47 e tutto il denominatore nelle tre letture; la marca vede GSE49608\n")

cat("\n== Previsioni sul riferimento ==\n")
conto("R1", "confronti di Atlas con la marca tempo_zero, su 123", sum(cp$tempo_zero), 13, 10, 16)
conto("R2", "denominatore di (b), lettura principale", sum(cp$in_b), 97, 83, 97)
conto("R3", "denominatore di (b), lettura stretta", sum(cs$in_b), 86, 72, 86)
cat("denominatore di (b), lettura intera:", sum(ci$in_b), "(S12r: 93)\n")
cat("tempo zero fra i `rispetta`: principale", sum(cp$tempo_zero & cp$classe == "rispetta"), "; intera",
    sum(ci$tempo_zero & ci$classe == "rispetta"), "; stretta", sum(cs$tempo_zero & cs$classe == "rispetta"), "\n")

# ---- (4) La pipeline di oggi --------------------------------------------------------------------------------
righe <- readLines(MASTER)
serie <- sub('^\\{"series_id":"(GSE[0-9]+)".*$', "\\1", righe)
stopifnot(all(grepl("^GSE[0-9]+$", serie)), !anyDuplicated(serie))
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
cat("\n== La pipeline di oggi (master S14, almeno 2 campioni per braccio) ==\n")
cat("studi di sviluppo con un record:", sum(ha_record), "su", length(oggi), "\n")
mm <- lapply(sv$gse, function(g) {
  x <- rif[[g]]; o <- oggi[[g]]
  k <- o$confronti; k <- k[lengths(k$trattato) >= 2L & lengths(k$controllo) >= 2L, , drop = FALSE]
  tre <- misura_tre(g, o$partizione, k, x, campi[[g]])
  for (l in LETTURE) {
    if (!o$ha_record) tre[[l]]$riga$classe_gruppi <- "senza_record"
    tre[[l]]$riga$n_gruppi_oggi <- length(unique(o$partizione[names(o$partizione) %in% x$universo]))
  }
  tre
})
names(mm) <- sv$gse
per_studio <- lapply(LETTURE, function(l) do.call(rbind, lapply(mm, function(m) m[[l]]$riga)))
names(per_studio) <- LETTURE
misure <- lapply(per_studio, tf_riassumi_misure, B = B, seme = SEME)
for (l in LETTURE) {
  stopifnot(nrow(per_studio[[l]]) == 47L)                                    # K3
  cat(sprintf("\n-- lettura %s --\n", l))
  cat("(a) classi della partizione:\n"); print(table(per_studio[[l]]$classe_gruppi, useNA = "ifany"))
  cat("campioni di Atlas omessi da oggi (solo_atlas):", sum(per_studio[[l]]$solo_atlas), "\n")
  print(misure[[l]], row.names = FALSE, digits = 4)
}
scrivi_r2(do.call(rbind, per_studio), "10-per-studio-oggi.csv")
scrivi_r2(do.call(rbind, lapply(LETTURE, function(l) cbind(lettura = l, misure[[l]]))), "10-misure-oggi.csv")
at <- do.call(rbind, lapply(LETTURE, function(l) do.call(rbind, lapply(mm, function(m) {
  k <- m[[l]]$atlas
  data.frame(lettura = l, studio = k$studio, id = k$id, nome = k$nome, classe = k$classe, tempo_zero = k$tempo_zero,
             in_b = k$in_b, ritrovato = k$ritrovato, stringsAsFactors = FALSE)
}))))
scrivi_r2(at, "10-confronti-atlas-oggi.csv")
ne <- do.call(rbind, lapply(LETTURE, function(l) do.call(rbind, lapply(mm, function(m) {
  k <- m[[l]]$non_elencati
  data.frame(lettura = rep(l, nrow(k)), studio = k$studio, id = k$id, n_trattato = lengths(k$trattato),
             n_controllo = lengths(k$controllo), giudizio = k$giudizio, stringsAsFactors = FALSE)
}))))
scrivi_r2(ne, "10-non-elencati-oggi.csv")
cat("\noggi ritrova, fra i confronti con la marca tempo_zero (lettura intera):\n")
print(table(ritrovato = at$ritrovato[at$lettura == "intera" & at$tempo_zero], classe = at$classe[at$lettura == "intera" & at$tempo_zero]))
cat("giudizio dei non elencati di oggi, per lettura:\n"); print(table(ne$giudizio, ne$lettura))

# K1 (parte di oggi): con la lettura intera il codice aggiornato ridà i numeri di S12r
mi <- misure$intera; v <- function(m, nome, campo) m[[campo]][m$misura == nome]
k1 <- c(a = v(mi, "a_gruppi_identici", "numeratore"), a_den = v(mi, "a_gruppi_identici", "denominatore"),
        b = v(mi, "b_confronti_ritrovati", "numeratore"), b_den = v(mi, "b_confronti_ritrovati", "denominatore"),
        c = v(mi, "c_errori_non_elencati", "numeratore"), c_den = v(mi, "c_errori_non_elencati", "denominatore"))
cat("\n== K1, la pipeline di oggi con la lettura intera ==\n")
cat(sprintf("(a) %d/%d  (b) %d/%d  (c) %d/%d   [S12r: 14/47, 19/93, 19/79]\n", k1[["a"]], k1[["a_den"]], k1[["b"]],
            k1[["b_den"]], k1[["c"]], k1[["c_den"]]))
s12r <- utils::read.csv(file.path(A, "40-per-studio-oggi.csv"), stringsAsFactors = FALSE)
s12r <- s12r[match(sv$gse, s12r$studio), ]
pi_ <- per_studio$intera
stessi <- identical(s12r$classe_gruppi, pi_$classe_gruppi) && all(s12r$n_rispetta == pi_$n_b_den) &&
  all(s12r$n_rispetta_uguale == pi_$n_b_uguale) && all(s12r$n_errori == pi_$n_errori) &&
  all(s12r$n_giudicabili == pi_$n_giudicabili)
cat("studio per studio uguale a 40-per-studio-oggi.csv di S12r (classe dei gruppi, denominatore e numeratore di (b), errori e giudicabili):",
    stessi, "\n")
stopifnot(all(k1 == c(14, 47, 19, 93, 19, 79)), stessi)
cat("K1 (oggi) passato\nK3 passato: la misura di oggi copre 47 studi su 47 in ogni lettura\n")

cat("\n== Previsioni sulla pipeline di oggi (lettura principale; bootstrap sugli studi, B =", B, ", seme", SEME, ") ==\n")
mp <- misure$principale
prev <- function(codice, misura, basso, alto, atteso) {
  r <- mp[mp$misura == misura, ]
  cat(sprintf("%s  %s  atteso %s, rilevanza %.0f-%.0f%%  ->  %s\n", codice, riga_misura(mp, misura), atteso,
              100 * basso, 100 * alto, giudica(r$ic_basso, r$ic_alto, basso, alto)))
}
prev("O1", "b_confronti_ritrovati", 0.08, 0.25, "15%")
conto("O2", "oggi, (a) lettura principale, studi con partizione identica", v(mp, "a_gruppi_identici", "numeratore"), 14, 14, 14)
prev("O3", "c_errori_non_elencati", 0.10, 0.35, "22%")
cat("partizioni identiche solo sui campioni comuni (oggi omette campioni di Atlas):",
    v(mp, "a_identici_sui_comuni", "numeratore"), "\n")
cat("FINITO\n")
