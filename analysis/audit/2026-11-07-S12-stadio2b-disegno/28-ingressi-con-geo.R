#!/usr/bin/env Rscript
# 28-ingressi-con-geo.R — S12, seconda parte: l'ingresso dello Stadio 2b per i
# 1.903 confronti con i campi presi da GEO (decisione 1 del PI, 2026-11-08):
# description, treatment_protocol_ch1, growth_protocol_ch1.
#
# CANCELLI e PREVISIONI: 00-previsioni-parte2.md (commit 15a157e, prima dello
# scaricamento).
#   R0  (regola 4 della skill: riproduci prima di cambiare) con i soli campi
#       dell'H5 l'ingresso si ricostruisce identico al congelato della prima
#       parte, 1.903 testi su 1.903;
#   G2  ogni campione dei bracci ha i suoi campi GEO (i cancellati da GEO si
#       contano a parte: 27-cancellati-da-geo.json, campi marcati come non disponibili);
#   G4  ogni valore non vuoto di ogni campo (H5 e GEO) sta per intero nel testo;
#   P7  confronti oltre il limite di token; P8 mediana dei token;
#   P9  quota dei 993 studi in cui la descrizione cambia fra i campioni dei bracci;
#   P10 quota dei 15.559 campioni con il titolo GEO uguale al titolo dell'H5.
#
# CECITA'. Non legge il riferimento dei 193 ne' difetti.csv. Non legge l'H5 ne'
# il deliverable: usa i file congelati della prima parte (SHA-256 in 90-sha256.txt).
#
# SCRIVE (solo in questa cartella):
#   28-ingressi-1903.jsonl.gz   l'ingresso congelato per la prova S12p
#   28-titoli-diversi.csv       i campioni con titolo GEO diverso dall'H5 (P10)
#   28-out.txt                  il riassunto (stdout)
# Uso (Rscript SENZA --vanilla):
#   Rscript analysis/audit/2026-11-07-S12-stadio2b-disegno/28-ingressi-con-geo.R \
#     > analysis/audit/2026-11-07-S12-stadio2b-disegno/28-out.txt 2>&1
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
ns <- asNamespace("simulomicsr")
OUT <- "analysis/audit/2026-11-07-S12-stadio2b-disegno"
cancello <- function(nome, ok, dettaglio) cat(sprintf("%-4s %s  %s\n", nome, if (isTRUE(ok)) "PASSA" else "FALLISCE", dettaglio))
wilson <- function(x, n) { p <- stats::prop.test(x, n, correct = FALSE)$conf.int; sprintf("[%.1f%%, %.1f%%]", 100 * p[1], 100 * p[2]) }

# ------------------------------------------------ i file della prima parte ---
I0 <- jsonlite::stream_in(gzfile(file.path(OUT, "20-ingressi-1903.jsonl.gz")), verbose = FALSE)
H <- readRDS(file.path(OUT, "20-campi-h5-campioni.rds"))
CAMPI_H5 <- setdiff(ns$.S2B_CAMPI_INGRESSO, ns$.S2B_CAMPI_GEO)
stopifnot(nrow(I0) == 1903L, !anyDuplicated(H$geo_accession), all(CAMPI_H5 %in% names(H)))
cat("confronti:", nrow(I0), " studi:", length(unique(I0$study_id)), " campioni H5:", nrow(H), "\n")

# ------------------------------------------------------- i campi di GEO ------
G <- jsonlite::stream_in(gzfile(file.path(OUT, "27-campi-geo-campioni.jsonl.gz")), verbose = FALSE)
canc <- jsonlite::fromJSON(file.path(OUT, "27-cancellati-da-geo.json"))
cat("campioni con campi GEO:", nrow(G), " cancellati da GEO:", length(canc), paste(names(canc), collapse = " "), "\n")
# l'unione del pacchetto: un campione senza testo GEO e senza prova di cancellazione la ferma
M <- ns$.s2b_aggiungi_campi_geo(H, G, cancellati = names(canc))
iG <- match(M$geo_accession, G$gsm)
M$title_geo <- G$title[iG]; M$last_update_date <- G$last_update_date[iG]
senza_geo <- M$geo_accession[is.na(iG)]
pos <- stats::setNames(seq_len(nrow(M)), M$geo_accession)

# ---------------------------------------------- R0: riproduzione e ingressi --
sistema <- ns$.s2b_prompt_sistema("v1")
uguali_r0 <- logical(nrow(I0)); integro <- logical(nrow(I0)); ing <- vector("list", nrow(I0))
campi_df <- c("geo_accession", ns$.S2B_CAMPI_INGRESSO)
for (i in seq_len(nrow(I0))) {
  t_df <- M[pos[I0$gsm_t[[i]]], campi_df, drop = FALSE]
  c_df <- M[pos[I0$gsm_c[[i]]], campi_df, drop = FALSE]
  ent <- if (is.null(I0$entita_proposta[i])) NA_character_ else I0$entita_proposta[i]
  x0 <- ns$.s2b_costruisci_ingresso(t_df, c_df, I0$etichetta_trattato[i],
                                    I0$etichetta_controllo[i], ent, campi = CAMPI_H5)
  uguali_r0[i] <- identical(x0$testo, I0$testo[i])
  x <- ns$.s2b_costruisci_ingresso(t_df, c_df, I0$etichetta_trattato[i],
                                   I0$etichetta_controllo[i], ent)
  p <- ns$build_prompt_stage2b(x)
  integro[i] <- ns$.s2b_ingresso_contiene_tutto(x$testo, t_df, c_df)
  ing[[i]] <- list(record_id = I0$record_id[i], cluster_id = I0$cluster_id[i],
                   study_id = I0$study_id[i], etichetta_trattato = I0$etichetta_trattato[i],
                   etichetta_controllo = I0$etichetta_controllo[i],
                   entita_proposta = ent, n_t = I0$n_t[i], n_c = I0$n_c[i],
                   gsm_t = I0$gsm_t[[i]], gsm_c = I0$gsm_c[[i]],
                   campi = ns$.S2B_CAMPI_INGRESSO,
                   n_caratteri = x$n_caratteri, token_stimati = p$token_stimati,
                   completo = p$completo, testo = x$testo)
}
tok <- vapply(ing, `[[`, 1L, "token_stimati")
completo <- vapply(ing, `[[`, TRUE, "completo")

cat("\n---- CANCELLI ----\n")
cancello("R0", all(uguali_r0), sprintf("%d su %d testi ricostruiti con i soli campi H5 identici al congelato della prima parte",
                                      sum(uguali_r0), length(uguali_r0)))
cancello("G2", length(senza_geo) == 0L && nrow(G) == nrow(H),
         sprintf("%d campioni su %d con i campi GEO; senza: %d, tutti cancellati da GEO: %s",
                 nrow(H) - length(senza_geo), nrow(H), length(senza_geo),
                 if (setequal(senza_geo, names(canc))) "si'" else "NO"))
r_canc <- vapply(ing, function(r) any(c(r$gsm_t, r$gsm_c) %in% names(canc)), logical(1))
cat("     confronti con un campione cancellato da GEO:", sum(r_canc), paste(I0$record_id[r_canc], collapse = " "), "\n")
cancello("G4", all(integro), sprintf("%d su %d ingressi contengono ogni valore per intero", sum(integro), length(integro)))

cat("\n---- PREVISIONI ----\n")
cat(sprintf("P7  confronti oltre il limite (%d token): %d su %d\n",
            ns$.S2B_MAX_MODEL_LEN - ns$.S2B_RISERVA_RISPOSTA, sum(!completo), length(completo)))
if (any(!completo))
  print(data.frame(record_id = I0$record_id[!completo], n_t = I0$n_t[!completo],
                   n_c = I0$n_c[!completo], token = tok[!completo]), row.names = FALSE)
cat(sprintf("P8  token stimati per confronto: mediana %d (prima parte %d); 99-esimo percentile %d; massimo %d\n",
            as.integer(stats::median(tok)), as.integer(stats::median(I0$token_stimati)),
            as.integer(stats::quantile(tok, 0.99)), max(tok)))
cat(sprintf("    token del prompt di sistema: %d; somma sui 1.903: %d (prima parte %d)\n",
            ns$.s2b_stima_token(nchar(sistema)), sum(tok), sum(I0$token_stimati)))
d_tok <- tok - I0$token_stimati
cat("    aumento per confronto, quantili 0/50/90/99/100%:",
    paste(as.integer(stats::quantile(d_tok, c(0, .5, .9, .99, 1))), collapse = " / "), "\n")

# P9: per studio, la descrizione (normalizzata come nell'ingresso) sull'unione dei campioni dei bracci
# i campioni cancellati da GEO non hanno testo: esclusi da presenza e variazione
st <- split(seq_len(nrow(I0)), I0$study_id)
vivi <- function(ii) setdiff(unique(unlist(c(I0$gsm_t[ii], I0$gsm_c[ii]))), names(canc))
varia <- vapply(st, function(ii) {
  length(unique(ns$.s2b_norm_testo(M$description[pos[vivi(ii)]]))) > 1L
}, logical(1))
pres_st <- vapply(st, function(ii) {
  vapply(ns$.S2B_CAMPI_GEO, function(f) any(nzchar(M[[f]][pos[vivi(ii)]])), logical(1))
}, logical(3))
in_geo <- !M$geo_accession %in% names(canc)
cat(sprintf("P9  studi con la descrizione che cambia fra i campioni dei bracci: %d su %d (%.1f%%)\n",
            sum(varia), length(varia), 100 * mean(varia)))
for (f in ns$.S2B_CAMPI_GEO)
  cat(sprintf("    %-24s presente in %4d studi su %d e in %5d campioni su %d\n", f,
              sum(pres_st[f, ]), ncol(pres_st), sum(nzchar(M[[f]][in_geo])), sum(in_geo)))

# per confronto: la descrizione e' scritta per campione, per braccio o in comune?
modo <- vapply(ing, function(r) {
  if (grepl("\n[TC][0-9]+ \\[description\\] ", r$testo)) "per campione"
  else if (grepl("\n\\[description\\] ", r$testo)) {
    if (grepl("# Fields identical in every sample of both arms\n(\\[[^\n]*\n)*\\[description\\] ", r$testo)) "comune ai due bracci" else "per braccio"
  } else "assente"
}, character(1))
cat("    confronti per modo di scrittura della descrizione:\n"); print(table(modo))

# codifica dei campi GEO: stringhe cambiate dalla riparazione e marcatori residui
# (stesso marcatore di 23-codifica-residua.R)
marc <- "[\\x{00C2}-\\x{00F4}][\\x{0080}-\\x{00BF}]"
cat("    codifica dei campi GEO (campioni):\n")
for (f in ns$.S2B_CAMPI_GEO) {
  x <- M[[f]]
  cat(sprintf("      %-24s cambiate dalla riparazione %4d; con marcatore prima %4d, dopo %4d\n", f,
              sum(ns$.s2b_norm_testo(x) != ns$.s2b_norm_spazi(x)),
              sum(grepl(marc, ns$.s2b_norm_spazi(x), perl = TRUE)),
              sum(grepl(marc, ns$.s2b_norm_testo(x), perl = TRUE))))
}
testi <- vapply(ing, `[[`, "", "testo")
cat(sprintf("    ingressi con marcatore dopo la riparazione: %d su %d\n",
            sum(grepl(marc, testi, perl = TRUE)), length(testi)))

# P10: titoli GEO contro H5
# denominatore: i campioni che GEO ha ancora (i cancellati non hanno un titolo GEO)
con <- !is.na(M$title_geo)
tg <- ns$.s2b_norm_testo(M$title_geo); th <- ns$.s2b_norm_testo(M$title)
ug <- con & tg == th
cat(sprintf("P10 campioni con il titolo GEO uguale al titolo H5: %d su %d (%.2f%%, Wilson %s)\n",
            sum(ug), sum(con), 100 * sum(ug) / sum(con), wilson(sum(ug), sum(con))))
dif <- data.frame(gsm = M$geo_accession, title_h5 = th, title_geo = tg,
                  last_update_date = M$last_update_date, stringsAsFactors = FALSE)[con & !ug, ]
utils::write.csv(dif, file.path(OUT, "28-titoli-diversi.csv"), row.names = FALSE)
cat("    titoli diversi scritti in 28-titoli-diversi.csv:", nrow(dif), "\n")

# ------------------------------------------------------------ i file ---------
gz <- gzfile(file.path(OUT, "28-ingressi-1903.jsonl.gz"), "w")
for (r in ing) writeLines(jsonlite::toJSON(r, auto_unbox = TRUE, null = "null"), gz)
close(gz)
cat("\nfile scritti\n")
