# 33-legame.R — S12r, Task 6, passi 3 e 4: il legame fra i run di Atlas (SRR) e i nostri campioni (GSM).
#
# Per ognuno dei 129 studi di 30-divisione.tsv:
#   - i run vengono dalla configurazione di Atlas, letta con solo_id = TRUE (nessuna etichetta, nessun nome);
#   - fonte «ena»: il GSM di un run e' il primo fra sample_alias ed experiment_alias che rispetta ^GSM[0-9]+$
#     (risposte congelate in analysis/input/ena-2026-11-09/, manifesto 32-manifesto-ena.tsv);
#   - fonte «relation»: il campo meta/samples/relation dell'H5 di ARCHS4 contiene l'SRX del campione; si unisce
#     con experiment_accession di ENA. Il campo si legge intero (con index= rhdf5 va in segfault).
# Uscite: 33-legame.tsv (accession, gse, run, gsm, fonte, nel_bacino), 33-out.txt (conteggi per parte).
# Cancello K1 in fondo: zero disaccordi fra le due fonti, ogni studio di sviluppo ha almeno un run legato,
# controllo positivo SRR1039508 -> GSM1275862.
#
# Gli studi di giudizio sono chiusi: lo script usa solo identificativi e stampa solo conteggi.
# Uso (dalla radice del repository, SENZA --vanilla):  Rscript analysis/audit/2026-11-09-lettore-studio/33-legame.R
suppressMessages(devtools::load_all(".", quiet = TRUE))
suppressMessages(library(rhdf5))

qui <- "analysis/audit/2026-11-09-lettore-studio"
dir_atlas <- "analysis/input/atlas-2026-11-09"
dir_ena <- "analysis/input/ena-2026-11-09"
h5 <- "analysis/input/human_gene_v2.5.h5"
bacino_path <- "analysis/input/archs4-human-stage1-input-v2.jsonl"

div <- utils::read.delim(file.path(qui, "30-divisione.tsv"), stringsAsFactors = FALSE)
stopifnot(nrow(div) == 129L, !anyDuplicated(div$accession))

# --- i run di Atlas (solo identificativi) -----------------------------------------------------------------------
run_atlas <- do.call(rbind, lapply(seq_len(nrow(div)), function(i) {
  cfg <- atlas_leggi_configurazione(file.path(dir_atlas, paste0(div$accession[i], "-configuration.xml")),
                                    solo_id = TRUE)
  data.frame(accession = div$accession[i], gse = div$gse[i], parte = div$parte[i],
             run = sort(unique(cfg$gruppi$run), method = "radix"), stringsAsFactors = FALSE)
}))

# --- fonte «ena» -------------------------------------------------------------------------------------------------
file_ena <- list.files(dir_ena, pattern = "\\.studio-[A-Z]+[0-9]+\\.tsv$", full.names = TRUE)
ena <- do.call(rbind, lapply(file_ena, function(f) {
  x <- utils::read.delim(f, stringsAsFactors = FALSE, quote = "", colClasses = "character", na.strings = character())
  if (nrow(x) == 0L) return(NULL)
  x$accession <- sub("\\.studio-.*$", "", basename(f))
  x
}))
e_gsm <- function(x) grepl("^GSM[0-9]+$", x)
ena$gsm_ena <- ifelse(e_gsm(ena$sample_alias), ena$sample_alias,
                      ifelse(e_gsm(ena$experiment_alias), ena$experiment_alias, NA_character_))
ena <- ena[!duplicated(ena[, c("accession", "run_accession")]), ]
legame <- merge(run_atlas, ena[, c("accession", "run_accession", "experiment_accession", "gsm_ena")],
                by.x = c("accession", "run"), by.y = c("accession", "run_accession"), all.x = TRUE, sort = FALSE)
n_run_senza_ena <- sum(is.na(legame$experiment_accession))

# --- fonte «relation» (H5 di ARCHS4, campo intero) -----------------------------------------------------------
gsm_h5 <- as.character(h5read(h5, "meta/samples/geo_accession"))
rel <- as.character(h5read(h5, "meta/samples/relation"))
stopifnot(length(gsm_h5) == length(rel))
srx_h5 <- regmatches(rel, gregexpr("[SED]RX[0-9]+", rel))
mappa <- data.frame(srx = unlist(srx_h5), gsm_rel = rep(gsm_h5, lengths(srx_h5)), stringsAsFactors = FALSE)
mappa <- unique(mappa)
srx_ambigui <- unique(mappa$srx[duplicated(mappa$srx)])          # un SRX con due GSM nell'H5
n_ambigui_nostri <- sum(unique(legame$experiment_accession) %in% srx_ambigui)
mappa <- mappa[!mappa$srx %in% srx_ambigui, ]
legame$gsm_rel <- mappa$gsm_rel[match(legame$experiment_accession, mappa$srx)]

# --- unione delle due fonti ---------------------------------------------------------------------------------------
ha_e <- !is.na(legame$gsm_ena); ha_r <- !is.na(legame$gsm_rel)
legame$disaccordo <- ha_e & ha_r & legame$gsm_ena != legame$gsm_rel
legame$gsm <- ifelse(ha_e, legame$gsm_ena, legame$gsm_rel)
legame$fonte <- ifelse(ha_e & ha_r, "entrambe", ifelse(ha_e, "ena", ifelse(ha_r, "relation", NA_character_)))

# --- il bacino: i GSM dell'ingresso dello Stadio 1 ------------------------------------------------------------
righe <- readLines(bacino_path, warn = FALSE)
gsm_bacino <- regmatches(righe, regexpr('(?<="geo_accession":")GSM[0-9]+', righe, perl = TRUE))
stopifnot(length(gsm_bacino) == length(righe), length(gsm_bacino) == 508037L)
rm(righe)
legame$nel_bacino <- as.integer(!is.na(legame$gsm) & legame$gsm %in% gsm_bacino)

legame <- legame[order(legame$accession, legame$run, method = "radix"), ]
utils::write.table(legame[, c("accession", "gse", "run", "gsm", "fonte", "nel_bacino")],
                   file.path(qui, "33-legame.tsv"), sep = "\t", quote = FALSE, row.names = FALSE, na = "")

# --- conteggi per parte ---------------------------------------------------------------------------------------------
conta <- function(x, nome) {
  per_studio <- split(x, x$accession)
  data.frame(
    parte = nome, studi = length(per_studio), run_totali = nrow(x),
    run_con_gsm = sum(!is.na(x$gsm)), run_senza_gsm = sum(is.na(x$gsm)),
    fonte_entrambe = sum(x$fonte %in% "entrambe"), fonte_ena = sum(x$fonte %in% "ena"),
    fonte_relation = sum(x$fonte %in% "relation"),
    gsm_distinti = length(unique(x$gsm[!is.na(x$gsm)])),
    gsm_nel_bacino = length(unique(x$gsm[x$nel_bacino == 1L])),
    studi_con_run_non_legati = sum(vapply(per_studio, function(s) any(is.na(s$gsm)), TRUE)),
    studi_senza_gsm_nel_bacino = sum(vapply(per_studio, function(s) !any(s$nel_bacino == 1L), TRUE)),
    studi_con_tutti_i_gsm_nel_bacino = sum(vapply(per_studio, function(s) all(s$nel_bacino == 1L), TRUE)),
    disaccordi = sum(x$disaccordo),
    stringsAsFactors = FALSE)
}
tab <- rbind(conta(legame[legame$parte == "sviluppo", ], "sviluppo"),
             conta(legame[legame$parte == "giudizio_A", ], "giudizio_A"),
             conta(legame[legame$parte == "giudizio_B", ], "giudizio_B"),
             conta(legame, "tutti"))
n_disaccordi <- sum(legame$disaccordo)
studi_sviluppo <- div$gse[div$parte == "sviluppo"]
sviluppo_legati <- unique(legame$gse[!is.na(legame$gsm)])
positivo <- legame$gsm[legame$run == "SRR1039508"]

out <- c(
  "33-legame.R — legame fra i run di Atlas (SRR) e i campioni (GSM), 129 studi",
  sprintf("run di Atlas: %d; run senza riga in ENA: %d; SRX dei nostri run con due GSM nell'H5 (fonte relation scartata): %d",
          nrow(legame), n_run_senza_ena, n_ambigui_nostri),
  "",
  utils::capture.output(print(as.data.frame(t(tab[, -1]), stringsAsFactors = FALSE) |>
                                stats::setNames(tab$parte))),
  "",
  sprintf("K1 — disaccordi fra le due fonti: %d (atteso 0)", n_disaccordi),
  sprintf("K1 — studi di sviluppo con almeno un run legato a un GSM: %d su %d",
          sum(studi_sviluppo %in% sviluppo_legati), length(studi_sviluppo)),
  sprintf("K1 — controllo positivo SRR1039508 -> %s (atteso GSM1275862)", paste(positivo, collapse = ",")))
esito <- n_disaccordi == 0L && all(studi_sviluppo %in% sviluppo_legati) && identical(positivo, "GSM1275862")
out <- c(out, if (esito) "K1 passato" else "K1 FALLITO")
writeLines(out, file.path(qui, "33-out.txt")); cat(out, sep = "\n")

stopifnot(n_disaccordi == 0L)
stopifnot(all(studi_sviluppo %in% sviluppo_legati))
stopifnot(identical(positivo, "GSM1275862"))
