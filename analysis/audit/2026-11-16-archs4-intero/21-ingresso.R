# 21-ingresso.R — lo schema delle uscite della forma B0 per ogni studio nuovo di ARCHS4 e l'ingresso del lettore.
# Nessun modello gira qui. Base: analysis/audit/2026-11-15-lettori-su-gemma/22-schemi-b0.R (stesso generatore, stessa
# scrittura del record {record_id, testo, schema}).
#
# INSIEME=prova  dalle viste dei 540 studi nuovi della prova (archs4-viste-v0-prova.jsonl) scrive due ingressi:
#                  analysis/input/archs4-b0-ingresso-prova-casuale.jsonl   i 500 studi `casuale`
#                  analysis/input/archs4-b0-ingresso-prova-coda.jsonl      i 40 studi `grandi` e i 50 di `controllo`
#                I record di `controllo` sono le righe dell'ingresso di ieri (gemma-b0-ingresso-aperta.jsonl), copiate.
#                Cancello K1: il record rigenerato adesso dalla vista di ieri e' uguale byte per byte a quella riga.
# INSIEME=nuovo  dalle viste di tutti gli studi nuovi (archs4-viste-v0-nuovo.jsonl) scrive l'ingresso della corsa
#                grande (analysis/input/archs4-b0-ingresso-nuovi.jsonl) e la tabella di copertura dei 24.393 studi
#                (cancello K3: 21-copertura.csv).
# Controllo positivo del generatore, sempre: i 47 schemi di sviluppo hanno le impronte scritte dal lancio del
# secondo lettore (analysis/audit/2026-11-15-secondo-lettore/23-schemi-sha256.csv).
#
# Uno studio senza colonne non costanti non ha uno schema e non va al modello (`nessuna_colonna_variabile`).
# I token stimati = (caratteri della vista + caratteri del prompt v2) / 2,29: qui si segnala soltanto. Il limite
# vero lo applica il lavoratore sul DGX con i token contati (ingresso oltre 40.960 token = `oltre_contesto`).
# Niente si taglia. Gli studi di giudizio, di sviluppo e chiusi di Gemma non entrano in nessun ingresso (K5).
#
#   INSIEME=prova Rscript analysis/audit/2026-11-16-archs4-intero/21-ingresso.R        (SENZA --vanilla)
# Uscite: gli ingressi, 21-per-studio-<insieme>.csv, 21-ingresso-sha256-<insieme>.txt, 21-out-<insieme>.txt.
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(jsonlite) })
DIR <- "analysis/audit/2026-11-16-archs4-intero"; R3 <- "analysis/audit/2026-11-11-S12r3-elenco-chiuso"
LG <- "analysis/audit/2026-11-15-lettori-su-gemma"; S12R <- "analysis/audit/2026-11-09-lettore-studio"
source(file.path(R3, "10-schema-per-studio.R"))     # schema_studio(), schema_json(), valori_colonna()
INSIEME <- Sys.getenv("INSIEME"); stopifnot(INSIEME %in% c("prova", "nuovo"))
F_VISTE <- sprintf("analysis/input/archs4-viste-v0-%s.jsonl", INSIEME)
F_IERI <- "analysis/input/gemma-b0-ingresso-aperta.jsonl"; SHA_IERI <- "bf323bbae970ec9123ef238db998bb7edcfb58e618bed3aa8aad89d069fbca06"
CAR_PER_TOKEN <- 2.29; MAX_MODEL_LEN <- 65536L; MAX_TOKENS <- 24576L; LIMITE_INGRESSO <- MAX_MODEL_LEN - MAX_TOKENS
sha_testo <- function(x) digest::digest(enc2utf8(x), algo = "sha256", serialize = FALSE)
sha_file <- function(f) unname(digest::digest(file = f, algo = "sha256"))
id_riga <- function(r) sub('^\\{"record_id":"(GSE[0-9]+)".*$', "\\1", r)
num <- function(g) as.numeric(sub("GSE", "", g))
prompt <- paste(readLines(file.path(R3, "21-prompt-v2.md"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
sink(file.path(DIR, sprintf("21-out-%s.txt", INSIEME)), split = TRUE)
cat("21-ingresso.R  INSIEME=", INSIEME, " ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "; caratteri del prompt v2: ", nchar(prompt), "\n", sep = "")

el <- utils::read.csv(file.path(DIR, "10-elenco.csv"), stringsAsFactors = FALSE)
stopifnot(nrow(el) == 24393L, !anyDuplicated(el$gse))
DIVISIONE <- utils::read.delim(file.path(S12R, "30-divisione.tsv"), stringsAsFactors = FALSE)
stopifnot(setequal(DIVISIONE$gse[DIVISIONE$parte != "sviluppo"], el$gse[el$classe == "giudizio"]))
classe_di <- stats::setNames(el$classe, el$gse); prova_di <- stats::setNames(el$prova, el$gse)

# il record dell'ingresso e la riga dei conti di uno studio: come in 22-schemi-b0.R
uno_studio <- function(v) {
  g <- v$record_id; colonne <- as.character(unlist(v$colonne)); n_col <- length(colonne)
  tok <- ceiling((nchar(v$testo) + nchar(prompt)) / CAR_PER_TOKEN)
  r <- data.frame(gse = g, campioni = length(unlist(v$campioni)), colonne_non_costanti = n_col,
                  valori_distinti = NA_integer_, valori_max_per_colonna = NA_integer_, schema_caratteri = NA_integer_, schema_sha256 = NA_character_,
                  token_stimati = tok, oltre_contesto_stimato = as.integer(tok > LIMITE_INGRESSO),
                  esito = if (n_col == 0L) "nessuna_colonna_variabile" else "nell_ingresso", stringsAsFactors = FALSE)
  riga <- NULL
  if (n_col > 0L) {
    nv <- vapply(colonne, function(k) length(valori_colonna(v, k)), 1L)
    s <- schema_studio(v); sj <- as.character(toJSON(s, auto_unbox = TRUE, null = "null"))
    r$valori_distinti <- sum(nv); r$valori_max_per_colonna <- max(nv); r$schema_caratteri <- nchar(sj); r$schema_sha256 <- sha_testo(sj)
    riga <- enc2utf8(as.character(toJSON(list(record_id = g, testo = v$testo, schema = s), auto_unbox = TRUE, null = "null")))
  }
  list(r = r, riga = riga)
}

# ---- controllo positivo del generatore: i 47 studi di sviluppo ----------------------------------------------
sv <- lapply(readLines(file.path(S12R, "60-viste-v0.jsonl"), warn = FALSE, encoding = "UTF-8"), fromJSON, simplifyVector = FALSE)
noti <- utils::read.csv("analysis/audit/2026-11-15-secondo-lettore/23-schemi-sha256.csv", stringsAsFactors = FALSE)
adesso <- vapply(sv, function(v) sha_testo(schema_json(v)), "")
stopifnot(identical(vapply(sv, `[[`, "", "record_id"), noti$studio), identical(unname(adesso), noti$schema_sha256))
cat("controllo positivo: 47 schemi di sviluppo su 47 con l'impronta del lancio del secondo lettore\n"); rm(sv)

# ---- le viste degli studi nuovi, una per volta ---------------------------------------------------------------
attesi <- if (INSIEME == "prova") el$gse[el$classe == "nuovo" & el$prova %in% c("casuale", "grandi")] else el$gse[el$classe == "nuovo"]
F_ING <- switch(INSIEME,
  prova = c(casuale = "analysis/input/archs4-b0-ingresso-prova-casuale.jsonl", coda = "analysis/input/archs4-b0-ingresso-prova-coda.jsonl"),
  nuovo = c(nuovi = "analysis/input/archs4-b0-ingresso-nuovi.jsonl"))
pezzo_di <- function(g) if (INSIEME == "nuovo") "nuovi" else if (prova_di[[g]] == "casuale") "casuale" else "coda"
righe <- stats::setNames(vector("list", length(F_ING)), names(F_ING))      # prova: poche righe, in memoria
con_out <- if (INSIEME == "nuovo") file(F_ING[["nuovi"]], "wb") else NULL
per <- list(); con <- file(F_VISTE, "r"); ultimo <- -1
repeat {
  l <- readLines(con, n = 200L, warn = FALSE, encoding = "UTF-8"); if (!length(l)) break
  for (x in l) {
    v <- fromJSON(x, simplifyVector = FALSE); g <- v$record_id
    stopifnot(g %in% attesi, identical(classe_di[[g]], "nuovo"), num(g) > ultimo); ultimo <- num(g)   # K5 e ordine per numero GEO
    u <- uno_studio(v); per[[length(per) + 1L]] <- u$r
    if (!is.null(u$riga)) { if (INSIEME == "nuovo") writeLines(u$riga, con_out, useBytes = TRUE) else righe[[pezzo_di(g)]][[g]] <- u$riga }
  }
}
close(con); if (!is.null(con_out)) close(con_out)
per <- do.call(rbind, per); per$classe <- unname(classe_di[per$gse]); per$prova <- unname(prova_di[per$gse])
stopifnot(!anyDuplicated(per$gse))

if (INSIEME == "prova") {
  # ---- i 50 studi di controllo: le righe dell'ingresso di ieri, e il record rigenerato adesso (K1) ----
  stopifnot(identical(sha_file(F_IERI), SHA_IERI))
  ieri <- readLines(F_IERI, warn = FALSE, encoding = "UTF-8"); names(ieri) <- id_riga(ieri)
  ctrl <- el$gse[el$prova == "controllo"]; ctrl <- ctrl[order(num(ctrl))]
  stopifnot(length(ctrl) == 50L, all(classe_di[ctrl] == "gemma_aperta"), all(ctrl %in% names(ieri)))
  vg <- readLines("analysis/input/gemma-viste-v0.jsonl", warn = FALSE, encoding = "UTF-8"); names(vg) <- id_riga(vg)
  rigenerate <- vapply(ctrl, function(g) uno_studio(fromJSON(vg[[g]], simplifyVector = FALSE))$riga, "")
  uguali <- sum(rigenerate == ieri[ctrl])
  cat(sprintf("CONTROLLO POSITIVO (K1): record di `controllo` rigenerati adesso e uguali byte per byte alla riga dell'ingresso di ieri: %d su 50\n", uguali))
  stopifnot(uguali == 50L)
  coda <- c(unlist(righe$coda), ieri[ctrl]); coda <- coda[order(num(names(coda)))]
  cas <- unlist(righe$casuale); if (is.null(cas)) cas <- character()
  scritti <- list(casuale = cas, coda = coda)
  for (k in names(F_ING)) { co <- file(F_ING[[k]], "wb"); writeLines(scritti[[k]], co, useBytes = TRUE); close(co) }
  # rilettura e K5
  for (k in names(F_ING)) {
    rl <- readLines(F_ING[[k]], warn = FALSE, encoding = "UTF-8"); idk <- id_riga(rl)
    stopifnot(identical(rl, unname(enc2utf8(scritti[[k]]))), !anyDuplicated(idk), all(classe_di[idk] %in% c("nuovo", "gemma_aperta")),
              all(prova_di[idk] == if (k == "casuale") "casuale" else c("grandi", "controllo")[1 + (classe_di[idk] == "gemma_aperta")]))
    if (k == "coda") stopifnot(identical(unname(rl[idk %in% ctrl]), unname(ieri[ctrl])))
    cat(sprintf("ingresso %s: %d studi, %.1f MB, SHA-256 %s\n", F_ING[[k]], length(rl), file.size(F_ING[[k]]) / 1e6, sha_file(F_ING[[k]])))
  }
  cat(sprintf("pezzo coda: %d studi `grandi` con uno schema, %d studi di `controllo`\n", length(righe$coda), length(ctrl)))
}
writeLines(sprintf("%s  %s", vapply(F_ING, sha_file, ""), F_ING), file.path(DIR, sprintf("21-ingresso-sha256-%s.txt", INSIEME)))
utils::write.csv(per, file.path(DIR, sprintf("21-per-studio-%s.csv", INSIEME)), row.names = FALSE, na = "")

# ---- i conti -------------------------------------------------------------------------------------------------
q <- function(x) paste(format(stats::quantile(x, c(0, .25, .5, .75, .95, .99, 1), na.rm = TRUE, names = FALSE), big.mark = ".", decimal.mark = ",", scientific = FALSE), collapse = " | ")
esc <- utils::read.csv(file.path(DIR, sprintf("20-esclusi-%s.csv", INSIEME)), stringsAsFactors = FALSE)
stopifnot(setequal(c(per$gse, esc$gse), attesi), !any(per$gse %in% esc$gse))
gruppi <- if (INSIEME == "prova") split(per, per$prova) else list(nuovo = per)
for (k in names(gruppi)) {
  d <- gruppi[[k]]; n_att <- if (INSIEME == "prova") sum(el$prova == k) else length(attesi)
  cat(sprintf("\n%s: %d studi attesi; con la vista %d; nell'ingresso %d; senza colonne non costanti %d; oltre il contesto (stima) %d\n",
              k, n_att, nrow(d), sum(d$esito == "nell_ingresso"), sum(d$esito != "nell_ingresso"), sum(d$oltre_contesto_stimato == 1L & d$esito == "nell_ingresso")))
  cat("  quantili (minimo | 25% | mediana | 75% | 95% | 99% | massimo)\n")
  cat("  token stimati dell'ingresso:   ", q(d$token_stimati), "\n")
  cat("  caratteri dello schema:        ", q(d$schema_caratteri), "\n")
  cat("  studi con lo schema oltre 222.556 caratteri (il massimo della terza prova):", sum(d$schema_caratteri > 222556L, na.rm = TRUE), "\n")
}
cat("\nesclusi dalla vista:", nrow(esc), "\n"); if (nrow(esc)) print(table(sub("GSE[0-9]+", "<GSE>", esc$motivo)))

if (INSIEME == "nuovo") {
  # ---- rilettura dell'ingresso e cancello K3: un esito per ognuno dei 24.393 studi ----
  idn <- character(); con <- file(F_ING[["nuovi"]], "r")
  repeat { l <- readLines(con, n = 500L, warn = FALSE); if (!length(l)) break; idn <- c(idn, id_riga(l)) }
  close(con)
  stopifnot(identical(idn, per$gse[per$esito == "nell_ingresso"]), all(classe_di[idn] == "nuovo"))
  cop <- data.frame(gse = el$gse, classe = el$classe, esito = NA_character_, motivo = "", stringsAsFactors = FALSE)
  fisso <- c(giudizio = "giudizio_chiuso", sviluppo = "sviluppo_gia_letto", gemma_aperta = "gemma_aperta_gia_letta", gemma_chiusa = "gemma_chiusa")
  i <- cop$classe %in% names(fisso); cop$esito[i] <- fisso[cop$classe[i]]
  i <- match(per$gse, cop$gse); cop$esito[i] <- per$esito
  i <- match(esc$gse, cop$gse); cop$esito[i] <- ifelse(esc$motivo == "senza_testi", "senza_testi", "senza_vista"); cop$motivo[i] <- esc$motivo
  f_senza <- file.path(DIR, "12-senza-testi.csv")       # il motivo per cui mancano i testi (12-verifica-testi.py)
  if (file.exists(f_senza)) { st <- utils::read.csv(f_senza, stringsAsFactors = FALSE); j <- cop$esito == "senza_testi"
    stopifnot(setequal(cop$gse[j], st$gse)); cop$motivo[j] <- st$motivo[match(cop$gse[j], st$gse)] }
  stopifnot(!anyNA(cop$esito), nrow(cop) == 24393L)
  utils::write.csv(cop, file.path(DIR, "21-copertura.csv"), row.names = FALSE)
  cat("\nCANCELLO K3, copertura: un esito per ognuno dei", nrow(cop), "studi\n"); print(table(cop$classe, cop$esito))
  cat(sprintf("\na1, studi nuovi con i due file dei testi: %d su %d\na2, studi nuovi nell'ingresso: %d su %d\n",
              sum(cop$classe == "nuovo" & cop$esito != "senza_testi"), sum(cop$classe == "nuovo"),
              sum(cop$classe == "nuovo" & cop$esito == "nell_ingresso"), sum(cop$classe == "nuovo")))
  cat(sprintf("ingresso %s: %d studi, %.1f MB, SHA-256 %s\n", F_ING[["nuovi"]], length(idn), file.size(F_ING[["nuovi"]]) / 1e6, sha_file(F_ING[["nuovi"]])))
}
sink()
