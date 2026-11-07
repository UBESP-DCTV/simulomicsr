#!/usr/bin/env Rscript
# 20-ingressi.R — S12: costruisce l'ingresso dello Stadio 2b per i 1.903
# confronti del deliverable A3 v16 e misura che cosa il modello vedra'.
#
# CANCELLI e PREVISIONI: 00-previsioni.md (depositate prima, commit f8228f5).
#   C2  1.903 confronti su 1.903, 194 gruppi su 194, ogni GSM nell'H5, conteggi giusti;
#   C3  ogni valore non vuoto di ogni campo di ogni campione sta per intero nel testo;
#   P1  confronti oltre il limite di token (26.624 = 32.768 - 6.144; token = caratteri / 3);
#   P2  campi H5 con >= 5 stringhe alla lunghezza massima, se questa e' >= 255 byte;
#   P3  mediana e 99-esimo percentile dei token stimati.
# Esecuzione finale (stesso giorno): l'ingresso ripara la codifica UTF-8 doppia e tripla
# dell'H5; la prima uscita sta in 20-out-prima-della-codifica.txt.
#
# CECITA'. Non legge il riferimento dei 193 ne' difetti.csv. Non calcola il
# confronto tecnico dell'H5 fra i bracci (fa parte della regola: si conta in S12p).
#
# SCRIVE (solo in questa cartella):
#   20-ingressi-1903.jsonl.gz   l'ingresso congelato per la prova S12p
#   20-campi-h5-campioni.rds    i campi H5 dei campioni dei 1.903 confronti
#   20-lunghezze-campi.csv      per campo: lunghezze massime e conteggi (P2)
#   20-out.txt                  il riassunto (stdout)
# Uso (Rscript SENZA --vanilla):
#   Rscript analysis/audit/2026-11-07-S12-stadio2b-disegno/20-ingressi.R \
#     > analysis/audit/2026-11-07-S12-stadio2b-disegno/20-out.txt 2>&1
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
ns <- asNamespace("simulomicsr")
OUT <- "analysis/audit/2026-11-07-S12-stadio2b-disegno"
A3_POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
H5 <- "analysis/input/human_gene_v2.5.h5"
t0 <- Sys.time(); tempo <- function() round(as.numeric(difftime(Sys.time(), t0, units = "secs")))
cancello <- function(nome, ok, dettaglio) cat(sprintf("%-4s %s  %s\n", nome, if (isTRUE(ok)) "PASSA" else "FALLISCE", dettaglio))

# ------------------------------------------------------------ i confronti ----
A <- readRDS("analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds")$tenuti
d <- readRDS(file.path(A3_POOL, "deliverable-annotato.rds"))
stopifnot(!anyDuplicated(A$record_id))
cat("confronti:", nrow(A), " gruppi:", length(unique(A$cluster_id)),
    " gruppi nel deliverable:", nrow(d), "\n")
A$entita_proposta <- d$contrast_entity_label[match(A$cluster_id, d$cluster_id)]

# ------------------------------------------------------------- l'H5 ----------
campi <- c("geo_accession", ns$.S2B_CAMPI_INGRESSO)
M <- lapply(stats::setNames(campi, campi), function(k)
  as.character(rhdf5::h5read(H5, paste0("meta/samples/", k))))
rhdf5::h5closeAll()
M <- as.data.frame(M, stringsAsFactors = FALSE)
cat("campioni nell'H5:", nrow(M), " accession duplicati:", sum(duplicated(M$geo_accession)),
    " (lettura", tempo(), "s)\n")

# ---- P2: stringhe alla lunghezza massima, su tutto il bacino dell'H5 ----
lung <- do.call(rbind, lapply(ns$.S2B_CAMPI_INGRESSO, function(f) {
  b <- nchar(M[[f]], type = "bytes")
  mx <- max(b)
  top <- sort(as.integer(names(table(b))), decreasing = TRUE)[1:5]
  data.frame(campo = f, n_non_vuoti = sum(b > 0), max_byte = mx,
             n_alla_max = sum(b == mx),
             top5_lunghezze = paste(top, collapse = ";"),
             top5_conteggi = paste(vapply(top, function(L) sum(b == L), 1L), collapse = ";"),
             stringsAsFactors = FALSE)
}))
lung$taglio_sospetto <- lung$n_alla_max >= 5 & lung$max_byte >= 255
utils::write.csv(lung, file.path(OUT, "20-lunghezze-campi.csv"), row.names = FALSE)
cat("\nP2 - lunghezze dei campi su tutto l'H5 (byte):\n"); print(lung[, c("campo", "n_non_vuoti", "max_byte", "n_alla_max", "taglio_sospetto")], row.names = FALSE)
cat("P2 - campi con taglio sospetto:", sum(lung$taglio_sospetto), "\n")

# ------------------------------------------------- C2: i GSM dei bracci ------
pos <- stats::setNames(seq_len(nrow(M)), M$geo_accession)
pos <- pos[!duplicated(names(pos))]
spezza <- function(s) strsplit(s, ",", fixed = TRUE)[[1]]
gsm_t <- lapply(A$gsm_t, spezza); gsm_c <- lapply(A$gsm_c, spezza)
mancanti <- setdiff(unique(c(unlist(gsm_t), unlist(gsm_c))), names(pos))
conti_ok <- all(lengths(gsm_t) == A$n_gsm_t) && all(lengths(gsm_c) == A$n_gsm_c)
sovrapposti <- sum(mapply(function(a, b) length(intersect(a, b)) > 0L, gsm_t, gsm_c))
cat("\nGSM distinti nei bracci:", length(unique(c(unlist(gsm_t), unlist(gsm_c)))),
    " mancanti nell'H5:", length(mancanti), " confronti con un GSM in entrambi i bracci:", sovrapposti, "\n")

# ---- codifica UTF-8 doppia nell'H5 (verificata su GEO): stringhe riparate ----
usati0 <- unique(c(unlist(gsm_t), unlist(gsm_c)))
cat("\nstringhe riparate dalla codifica doppia, sui", length(usati0), "campioni dei 1.903:\n")
for (f in ns$.S2B_CAMPI_INGRESSO) {
  x <- M[pos[usati0], f]
  cat(sprintf("  %-22s %5d\n", f, sum(ns$.s2b_norm_testo(x) != ns$.s2b_norm_spazi(x))))
}

# --------------------------------------------- l'ingresso di ogni confronto --
sistema <- ns$.s2b_prompt_sistema("v1")
ing <- vector("list", nrow(A)); integro <- logical(nrow(A))
for (i in seq_len(nrow(A))) {
  t_df <- M[pos[gsm_t[[i]]], campi, drop = FALSE]
  c_df <- M[pos[gsm_c[[i]]], campi, drop = FALSE]
  x <- ns$.s2b_costruisci_ingresso(t_df, c_df, A$etichetta_trattato[i],
                                   A$etichetta_controllo[i], A$entita_proposta[i])
  p <- ns$build_prompt_stage2b(x)
  integro[i] <- ns$.s2b_ingresso_contiene_tutto(x$testo, t_df, c_df)
  ing[[i]] <- list(record_id = A$record_id[i], cluster_id = A$cluster_id[i],
                   study_id = A$study_id[i], etichetta_trattato = A$etichetta_trattato[i],
                   etichetta_controllo = A$etichetta_controllo[i],
                   entita_proposta = A$entita_proposta[i], n_t = length(gsm_t[[i]]),
                   n_c = length(gsm_c[[i]]), gsm_t = gsm_t[[i]], gsm_c = gsm_c[[i]],
                   n_caratteri = x$n_caratteri, token_stimati = p$token_stimati,
                   completo = p$completo, testo = x$testo)
}
cat("ingressi costruiti (", tempo(), "s)\n")

tok <- vapply(ing, `[[`, 1L, "token_stimati")
completo <- vapply(ing, `[[`, TRUE, "completo")
cat("\n---- CANCELLI ----\n")
cancello("C2", nrow(A) == 1903L && length(unique(A$cluster_id)) == 194L &&
           setequal(A$cluster_id, d$cluster_id) && length(mancanti) == 0L && conti_ok,
         sprintf("%d confronti, %d gruppi, GSM mancanti %d, conteggi per braccio %s",
                 nrow(A), length(unique(A$cluster_id)), length(mancanti), if (conti_ok) "giusti" else "SBAGLIATI"))
cancello("C3", all(integro), sprintf("%d su %d ingressi contengono ogni valore per intero", sum(integro), length(integro)))

cat("\n---- PREVISIONI ----\n")
cat(sprintf("P1  confronti oltre il limite (%d token): %d su %d\n",
            ns$.S2B_MAX_MODEL_LEN - ns$.S2B_RISERVA_RISPOSTA, sum(!completo), length(completo)))
cat(sprintf("P3  token stimati per confronto: mediana %d, 99-esimo percentile %d, massimo %d\n",
            as.integer(stats::median(tok)), as.integer(stats::quantile(tok, 0.99, type = 7)), max(tok)))
cat(sprintf("    token del prompt di sistema: %d; somma dei token stimati sui 1.903: %d\n",
            ns$.s2b_stima_token(nchar(sistema)), sum(tok)))
q <- stats::quantile(tok, c(0.5, 0.9, 0.95, 0.99, 1))
cat("    quantili:", paste(names(q), as.integer(q), collapse = "  "), "\n")
if (any(!completo)) {
  cat("    oltre il limite:\n")
  print(data.frame(record_id = A$record_id[!completo], n_t = lengths(gsm_t)[!completo],
                   n_c = lengths(gsm_c)[!completo], token = tok[!completo]), row.names = FALSE)
}

# ------------------------------------------------------------ i file ----------
gz <- gzfile(file.path(OUT, "20-ingressi-1903.jsonl.gz"), "w")
for (r in ing) writeLines(jsonlite::toJSON(r, auto_unbox = TRUE, null = "null"), gz)
close(gz)
usati <- unique(c(unlist(gsm_t), unlist(gsm_c)))
saveRDS(M[pos[usati], campi], file.path(OUT, "20-campi-h5-campioni.rds"))
cat("\nfile scritti; durata", tempo(), "s\n")
