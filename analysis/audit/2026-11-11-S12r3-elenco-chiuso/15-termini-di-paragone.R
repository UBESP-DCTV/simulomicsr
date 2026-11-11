# 15-termini-di-paragone.R — S12r3, prima del deposito delle previsioni: i termini di paragone.
#
# (1) Riproduce i numeri di S12r2 col codice aggiornato (default `contesto_fuori = FALSE`): pipeline di oggi
#     14/47 e 13/97; lettore con lo schema v1 (Mistral-Small 3.2, prima corsa congelata di S12r2) 31/47, 50/97, 0/4.
# (2) Controllo positivo: Atlas contro Atlas nelle quattro misure di S12r3.
# (3) Il riferimento con la regola del contesto (decisione del PI del 2026-11-11): quali confronti escono.
# (4) Gli stessi due termini di paragone sul riferimento nuovo.
# Non legge nessuna uscita nuova di un modello. Legge SOLO i 47 studi di sviluppo.
#
# Uso (SENZA --vanilla):
#   Rscript analysis/audit/2026-11-11-S12r3-elenco-chiuso/15-termini-di-paragone.R \
#     > analysis/audit/2026-11-11-S12r3-elenco-chiuso/15-out.txt 2>&1
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-11-S12r3-elenco-chiuso/aiuti-misura-r3.R")
source(file.path(R2, "22-adattatore-v1.R"))
MASTER <- "analysis/p4-output/S14-stage2-master.jsonl"
USCITE_V1 <- "analysis/p4-output/S12r2-lettore-v1/M-corsa1.jsonl"
nullo <- function(x) if (is.null(x)) NA else x

sv <- studi_di_sviluppo(); rif <- atlas_di_sviluppo(sv); viste <- leggi_viste(sv)
stopifnot(identical(names(rif), sv$gse), identical(names(viste), sv$gse), length(rif) == 47L)
campi <- stats::setNames(lapply(sv$gse, function(g) campi_tempo_studio(rif[[g]], viste[[g]])), sv$gse)
per_misura <- function(mm) stats::setNames(lapply(NOMI_R3, function(m) do.call(rbind, lapply(mm, function(x) x[[m]]$riga))), NOMI_R3)

# ---- (2) Atlas contro Atlas -----------------------------------------------------------------------------------
aa <- lapply(sv$gse, function(g) { x <- rif[[g]]; misura_r3(g, x$atlas$partizione, forma_comune(x$atlas$confronti), x, campi[[g]]) })
names(aa) <- sv$gse
pa <- per_misura(aa)
cat("== Controllo positivo: Atlas contro Atlas ==\n")
for (m in NOMI_R3) {
  d <- pa[[m]]
  cat(sprintf("%s: partizione identica %d su %d; denominatore di (b) %d, ritrovati uguali %d; giudicabili fra i non elencati %d\n",
              m, sum(d$classe_gruppi %in% "identica"), nrow(d), sum(d$n_b_den), sum(d$n_b_uguale), sum(d$n_giudicabili)))
  stopifnot(nrow(d) == 47L, all(d$classe_gruppi %in% "identica"), all(d$n_b_uguale == d$n_b_den), all(d$n_giudicabili == 0L))
}

# ---- (3) Il riferimento con la regola del contesto ---------------------------------------------------------------
at <- do.call(rbind, lapply(NOMI_R3, function(m) do.call(rbind, lapply(aa, function(x) {
  k <- x[[m]]$atlas
  data.frame(misura_r3 = m, studio = k$studio, id = k$id, nome = k$nome, n_trattato = lengths(k$trattato),
             n_controllo = lengths(k$controllo), classe = k$classe, fattori_diversi = k$fattori_diversi,
             tempo_zero = k$tempo_zero, solo_contesto = k$solo_contesto, in_b = k$in_b, stringsAsFactors = FALSE)
}))))
scrivi_r3(at, "15-confronti-atlas-riferimento.csv")
cat("\n== Il riferimento: confronti di Atlas nel denominatore di (b) ==\n")
print(tapply(at$in_b, at$misura_r3, sum)[NOMI_R3])
p <- at[at$misura_r3 == "principale", ]
stopifnot(nrow(p) == 123L)
cat("\nfattori di Atlas dei 47 studi che la regola chiama contesto (studi per nome):\n")
nomi_f <- unlist(lapply(rif, function(x) x$atlas$tabella$fattori$nome))
print(table(nomi_f[tf_fattore_di_contesto(nomi_f)]))
cat("\nconfronti con la marca solo_contesto (lettura principale):", sum(p$solo_contesto), "; di questi col tempo zero:",
    sum(p$solo_contesto & p$tempo_zero %in% TRUE), "\n")
print(p[p$solo_contesto, c("studio", "id", "nome", "fattori_diversi", "tempo_zero", "in_b")], row.names = FALSE)
s <- at[at$misura_r3 == "stretta", ]
cat("lettura stretta, confronti con la marca:", sum(s$solo_contesto), "\n")
print(s[s$solo_contesto, c("studio", "id", "nome", "fattori_diversi", "tempo_zero")], row.names = FALSE)
cat("\nfattore che cambia nei confronti del denominatore, lettura principale con la regola:\n")
print(sort(table(p$fattori_diversi[p$in_b]), decreasing = TRUE))
cat("confronti `rispetta` con un fattore solo, non di contesto per la regola, il cui nome contiene cell, tissue, site, organ:\n")
print(p[p$classe == "rispetta" & !p$solo_contesto & grepl("cell|tissue|site|organ", p$fattori_diversi, ignore.case = TRUE),
        c("studio", "id", "nome", "fattori_diversi")], row.names = FALSE)

# ---- (1)+(4) La pipeline di oggi --------------------------------------------------------------------------------
righe <- readLines(MASTER)
serie <- sub('^\\{"series_id":"(GSE[0-9]+)".*$', "\\1", righe)
stopifnot(all(grepl("^GSE[0-9]+$", serie)), !anyDuplicated(serie))
oggi <- lapply(rif, function(x) {
  i <- match(x$gse, serie)
  if (is.na(i)) return(list(ha_record = FALSE, partizione = character(0), confronti = tf_da_stage2(list(series_id = x$gse))$confronti))
  rec <- jsonlite::fromJSON(righe[i], simplifyVector = FALSE); stopifnot(identical(rec$series_id, x$gse))
  c(list(ha_record = TRUE), tf_da_stage2(rec))
})
rm(righe)
mo <- lapply(sv$gse, function(g) {
  x <- rif[[g]]; o <- oggi[[g]]
  k <- o$confronti; k <- k[lengths(k$trattato) >= 2L & lengths(k$controllo) >= 2L, , drop = FALSE]
  r <- misura_r3(g, o$partizione, k, x, campi[[g]])
  for (m in NOMI_R3) if (!o$ha_record) r[[m]]$riga$classe_gruppi <- "senza_record"
  r
})
names(mo) <- sv$gse
po <- per_misura(mo); mis_o <- lapply(po, tf_riassumi_misure, B = B, seme = SEME)
scrivi_r3(impila(po), "15-per-studio-oggi.csv")
scrivi_r3(impila(mis_o), "15-misure-oggi.csv")

# ---- (1)+(4) Il lettore con lo schema v1 (prima corsa di Mistral-Small 3.2 in S12r2) -----------------------------
imp <- readLines(file.path(R2, "23-uscite-sha256.txt"))
sha <- sub("  .*$", "", imp)[sub("^[0-9a-f]+  ", "", imp) == USCITE_V1]
stopifnot(length(sha) == 1L, identical(unname(digest::digest(file = USCITE_V1, algo = "sha256")), sha))
cx <- leggi_jsonl(USCITE_V1); names(cx) <- vapply(cx, `[[`, "", "record_id")
stopifnot(setequal(names(cx), sv$gse), !anyDuplicated(names(cx))); cx <- cx[sv$gse]
e_saltato <- function(x) { s <- x$saltato; !is.null(s) && !is.na(s) && nzchar(as.character(s)) }
lett <- stats::setNames(lapply(sv$gse, function(g) adatta_v1(viste[[g]], as.character(nullo(cx[[g]]$raw)), e_saltato(cx[[g]]),
                                                               as.character(nullo(cx[[g]]$fine)))), sv$gse)
chiuso <- vapply(lett, `[[`, TRUE, "chiuso")
ml <- lapply(sv$gse, function(g) {
  x <- rif[[g]]; r <- lett[[g]]
  t <- if (r$chiuso) misura_r3(g, r$partizione, confronti_comuni(g, r$confronti), x, campi[[g]]) else
    misura_r3(g, character(0), CONFRONTI_VUOTI(g), x, campi[[g]])
  for (m in NOMI_R3) { if (!r$chiuso) t[[m]]$riga$classe_gruppi <- "non_chiuso"; t[[m]]$riga$chiuso <- r$chiuso }
  t
})
names(ml) <- sv$gse
pl <- per_misura(ml); mis_l <- lapply(pl, tf_riassumi_misure, B = B, seme = SEME)
scrivi_r3(impila(pl), "15-per-studio-v1.csv")
scrivi_r3(impila(mis_l), "15-misure-v1.csv")
meno <- lapply(stats::setNames(NOMI_R3, NOMI_R3), function(m) appaiato(pl[[m]], po[[m]], c("v1", "oggi")))
scrivi_r3(impila(meno), "15-v1-meno-oggi.csv")

cat("\n== I termini di paragone, per misura ==\n")
for (m in NOMI_R3) {
  cat(sprintf("%-13s oggi: (a) %s (b) %s (c) %s   |   lettore v1: chiusi %d, (a) %s (b) %s (c) %s\n", m,
              fraz(mis_o[[m]], "a_gruppi_identici"), fraz(mis_o[[m]], "b_confronti_ritrovati"), fraz(mis_o[[m]], "c_errori_non_elencati"),
              sum(chiuso), fraz(mis_l[[m]], "a_gruppi_identici"), fraz(mis_l[[m]], "b_confronti_ritrovati"), fraz(mis_l[[m]], "c_errori_non_elencati")))
  cat("   lettore v1 meno oggi, appaiato:\n"); print(meno[[m]], row.names = FALSE, digits = 4)
}

# ---- Riproduzione: i numeri di S12r2, studio per studio ----------------------------------------------------------
uguali <- function(nuovo, f, lettura) {
  v <- utils::read.csv(file.path(R2, f), stringsAsFactors = FALSE); v <- v[v$lettura == lettura, ]; v <- v[match(sv$gse, v$studio), ]
  cc <- intersect(c("classe_gruppi", "n_b_den", "n_b_uguale", "n_errori", "n_giudicabili", "n_rispetta", "n_atlas", "n_nostri"), names(v))
  stopifnot(!anyNA(v$studio), length(cc) >= 5L)
  all(vapply(cc, function(k) identical(as.character(nuovo[[k]]), as.character(v[[k]])), TRUE))
}
r_oggi <- c(principale97 = uguali(po$principale97, "10-per-studio-oggi.csv", "principale"),
            intera = uguali(po$intera, "10-per-studio-oggi.csv", "intera"))
r_v1 <- c(principale97 = uguali(pl$principale97, "24-M-per-studio.csv", "principale"),
          intera = uguali(pl$intera, "24-M-per-studio.csv", "intera"))
cat("\n== Riproduzione di S12r2 (studio per studio, senza la regola del contesto) ==\n")
cat("oggi, uguale a 10-per-studio-oggi.csv: principale", r_oggi[["principale97"]], "; intera", r_oggi[["intera"]], "\n")
cat("lettore v1, uguale a 24-M-per-studio.csv: principale", r_v1[["principale97"]], "; intera", r_v1[["intera"]], "\n")
stopifnot(all(r_oggi), all(r_v1), sum(chiuso) == 34L,
          fraz(mis_o$principale97, "a_gruppi_identici") == "14/47", fraz(mis_o$principale97, "b_confronti_ritrovati") == "13/97",
          fraz(mis_l$principale97, "a_gruppi_identici") == "31/47", fraz(mis_l$principale97, "b_confronti_ritrovati") == "50/97",
          fraz(mis_l$principale97, "c_errori_non_elencati") == "0/4")
cat("riproduzione passata: oggi 14/47 e 13/97; lettore v1 34 chiusi, 31/47, 50/97, 0/4\n")
cat("\nstudi dove la regola del contesto cambia il denominatore (principale meno principale97):\n")
d <- po$principale97$n_b_den - po$principale$n_b_den
print(data.frame(studio = sv$gse[d != 0], esce = d[d != 0], oggi_ritrovati_che_escono = (po$principale97$n_b_uguale - po$principale$n_b_uguale)[d != 0],
                 v1_ritrovati_che_escono = (pl$principale97$n_b_uguale - pl$principale$n_b_uguale)[d != 0]), row.names = FALSE)
cat("FINITO\n")
