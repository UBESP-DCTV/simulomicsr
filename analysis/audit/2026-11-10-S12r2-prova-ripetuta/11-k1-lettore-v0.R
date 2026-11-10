# 11-k1-lettore-v0.R — cancello K1, parte del lettore v0 (S12r2).
# Con la lettura intera il codice aggiornato deve ridare i numeri di S12r sulle uscite v0 congelate:
# (a) 14/47, (b) 10/93, (c) 1/5. Lo script di S12r (`64-adatta-e-misura.R`) non si modifica: da quel file si
# valutano solo le definizioni dell'adattatore v0 (costanti, `adatta()`, `confronti_comuni()`), una per nome.
# In piu': le uscite v0 misurate nelle tre letture (termine di paragone per la v1; nessuna previsione le riguarda).
#
# Uso (SENZA --vanilla):
#   Rscript analysis/audit/2026-11-10-S12r2-prova-ripetuta/11-k1-lettore-v0.R \
#     > analysis/audit/2026-11-10-S12r2-prova-ripetuta/11-out.txt 2>&1
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-10-S12r2-prova-ripetuta/aiuti-misura-r2.R")
Sys.setenv(S12R_SENSIBILITA = "")
VOLUTE <- c("SENS", "DIR_USCITE", "NON_STATED", "TIPI", "SOGG", "MOTIVI_PIANO", "SEP", "validatore", "unisci",
            "car", "adatta", "confronti_comuni", "CONFRONTI_VUOTI")
espr <- parse(file.path(A, "64-adatta-e-misura.R"))
nome_di <- function(e) if (is.call(e) && identical(e[[1L]], as.name("<-")) && is.name(e[[2L]])) as.character(e[[2L]]) else ""
nomi <- vapply(espr, nome_di, "")
stopifnot(all(VOLUTE %in% nomi), !anyDuplicated(nomi[nomi %in% VOLUTE]))
for (e in espr[nomi %in% VOLUTE]) eval(e, globalenv())
cat("definizioni prese da 64-adatta-e-misura.R:", paste(VOLUTE, collapse = ", "), "\n")

# le uscite v0 sono quelle congelate in S12r
imp <- readLines(file.path(A, "63-uscite-sha256.txt"))
imp <- data.frame(sha = sub("  .*$", "", imp), file = sub("^[0-9a-f]+  ", "", imp), stringsAsFactors = FALSE)
stopifnot(all(vapply(imp$file, function(f) unname(digest::digest(file = f, algo = "sha256")), "") == imp$sha),
          file.path(DIR_USCITE, "corsa1.jsonl") %in% imp$file)
cat("uscite v0: impronte uguali a 63-uscite-sha256.txt\n")

sv <- studi_di_sviluppo(); rif <- atlas_di_sviluppo(sv); viste <- leggi_viste(sv)
campi <- stats::setNames(lapply(sv$gse, function(g) campi_tempo_studio(rif[[g]], viste[[g]])), sv$gse)
c1 <- leggi_jsonl(file.path(DIR_USCITE, "corsa1.jsonl")); names(c1) <- vapply(c1, `[[`, "", "record_id")
stopifnot(setequal(names(c1), sv$gse), !anyDuplicated(names(c1))); c1 <- c1[sv$gse]
nullo <- function(x) if (is.null(x)) NA else x
lett <- lapply(sv$gse, function(g) adatta(viste[[g]], as.character(nullo(c1[[g]]$raw)), isTRUE(c1[[g]]$saltato),
                                          as.character(nullo(c1[[g]]$fine))))
names(lett) <- sv$gse
chiuso <- vapply(lett, `[[`, TRUE, "chiuso")
cat("studi chiusi dal lettore v0:", sum(chiuso), "su 47 [S12r: 23]\n")

mm <- lapply(sv$gse, function(g) {
  x <- rif[[g]]; r <- lett[[g]]
  tre <- if (r$chiuso) misura_tre(g, r$partizione, confronti_comuni(g, r$confronti), x, campi[[g]]) else
    misura_tre(g, character(0), CONFRONTI_VUOTI(g), x, campi[[g]])
  for (l in LETTURE) {
    if (!r$chiuso) tre[[l]]$riga$classe_gruppi <- "non_chiuso"
    tre[[l]]$riga$chiuso <- r$chiuso
  }
  tre
})
names(mm) <- sv$gse
per_studio <- stats::setNames(lapply(LETTURE, function(l) do.call(rbind, lapply(mm, function(m) m[[l]]$riga))), LETTURE)
misure <- lapply(per_studio, tf_riassumi_misure, B = B, seme = SEME)
oggi <- utils::read.csv(file.path(R2, "10-per-studio-oggi.csv"), stringsAsFactors = FALSE)
for (l in LETTURE) {
  cat(sprintf("\n-- lettore v0, lettura %s --\n", l))
  print(table(per_studio[[l]]$classe_gruppi, useNA = "ifany"))
  print(misure[[l]][1:3, ], row.names = FALSE, digits = 4)
  o <- oggi[oggi$lettura == l, ]; o <- o[match(sv$gse, o$studio), ]
  cat("lettore v0 meno oggi, appaiato:\n")
  print(appaiato(per_studio[[l]], o), row.names = FALSE, digits = 4)
}
scrivi_r2(do.call(rbind, per_studio), "11-per-studio-lettore-v0.csv")
scrivi_r2(do.call(rbind, lapply(LETTURE, function(l) cbind(lettura = l, misure[[l]]))), "11-misure-lettore-v0.csv")

mi <- misure$intera; v <- function(nome, campo) mi[[campo]][mi$misura == nome]
k1 <- c(v("a_gruppi_identici", "numeratore"), v("a_gruppi_identici", "denominatore"),
        v("b_confronti_ritrovati", "numeratore"), v("b_confronti_ritrovati", "denominatore"),
        v("c_errori_non_elencati", "numeratore"), v("c_errori_non_elencati", "denominatore"))
cat(sprintf("\n== K1, il lettore v0 con la lettura intera ==\n(a) %d/%d  (b) %d/%d  (c) %d/%d   [S12r: 14/47, 10/93, 1/5]\n",
            k1[1], k1[2], k1[3], k1[4], k1[5], k1[6]))
s12r <- utils::read.csv(file.path(A, "64-per-studio-lettore.csv"), stringsAsFactors = FALSE)
s12r <- s12r[match(sv$gse, s12r$studio), ]; p <- per_studio$intera
stessi <- identical(s12r$classe_gruppi, p$classe_gruppi) && all(s12r$n_rispetta == p$n_b_den) &&
  all(s12r$n_rispetta_uguale == p$n_b_uguale) && all(s12r$n_errori == p$n_errori) &&
  all(s12r$n_giudicabili == p$n_giudicabili) && all(s12r$n_nostri == p$n_nostri)
cat("studio per studio uguale a 64-per-studio-lettore.csv di S12r:", stessi, "\n")
stopifnot(all(k1 == c(14, 47, 10, 93, 1, 5)), stessi)
cat("K1 (lettore v0) passato\nFINITO\n")
