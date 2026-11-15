# 30-adattatore-gemma.R — dai disegni curati di Gemma (UBC) alla tabella dei fattori.
# Regole fissate in 00-previsioni.md («L'adattatore», punti 1-7), prima di formare gruppi e confronti.
# `source()` dopo devtools::load_all("."). Uso da riga di comando (Rscript, SENZA --vanilla):
#   Rscript analysis/audit/2026-11-15-gemma-riferimento/30-adattatore-gemma.R
# fa il controllo positivo (cancello K2) e scrive l'esito dell'adattatore per ogni voce scaricata (cancello K3)
# in 30-esiti.csv. Non legge Atlas e non legge nessuna uscita di un modello.
G <- "analysis/audit/2026-11-15-gemma-riferimento"
GEMMA_DIR <- "analysis/p4-output/gemma-disegni-2026-11-15"

gemma_leggi <- function(nome, dir = GEMMA_DIR) {
  f <- function(che) {
    p <- file.path(dir, sprintf("%s.%s.json.gz", nome, che))
    if (!file.exists(p)) stop("file di Gemma non trovato: ", p, call. = FALSE)
    h <- gzfile(p, "rb"); on.exit(close(h))
    jsonlite::fromJSON(paste(readLines(h, warn = FALSE, encoding = "UTF-8"), collapse = "\n"), simplifyVector = FALSE)$data
  }
  list(campioni = f("samples"), analisi = f("analyses"))
}

.gm_testo <- function(x) if (is.null(x) || !length(x) || is.na(x)) NA_character_ else as.character(x)
.gm_blocco <- function(fv) {
  cat_f <- .gm_testo(fv$experimentalFactorCategory$category)
  cat_c <- vapply(fv$characteristics %||% list(), function(c) .gm_testo(c$category), "")
  any(c(cat_f, cat_c) %in% "block")
}
`%||%` <- function(a, b) if (is.null(a)) b else a

# La tabella dei fattori di una voce di Gemma. Ritorna sempre una lista con `esito`: "tabella" oppure un motivo
# con codice (K3). `note`: codici senza effetto sull'esito (fattori tolti, basi diverse, ...).
gemma_tabella <- function(campioni, analisi, studio) {
  note <- character(0); nota <- function(codice, che = "") note <<- c(note, if (nzchar(che)) paste0(codice, ":", che) else codice)
  esce <- function(esito, ...) c(list(esito = esito, chiuso = FALSE, note = note, studio = studio), list(...))

  # 1. campioni
  gsm <- vapply(campioni, function(x) .gm_testo(x$accession$accession), "")
  if (!length(gsm)) return(esce("senza_campioni"))
  if (anyNA(gsm) || any(!grepl("^GSM[0-9]+$", gsm))) return(esce("campione_senza_gsm"))
  if (anyDuplicated(gsm)) return(esce("gsm_doppi"))
  n_outlier <- sum(vapply(campioni, function(x) isTRUE(x$outlier) || isTRUE(x$userFlaggedOutlier), NA))
  if (n_outlier) nota("outlier_di_gemma", as.character(n_outlier))        # restano nella tabella: la regola 1 prende tutti i campioni

  # 2. valori dei fattori scritti sui campioni: una riga per campione e valore
  fv <- do.call(rbind, lapply(seq_along(campioni), function(i) {
    v <- campioni[[i]]$sample$fvbasicVOs %||% list()
    if (!length(v)) return(NULL)
    data.frame(gsm = gsm[i], fattore = vapply(v, function(z) as.character(z$experimentalFactorId), ""),
               valore = vapply(v, function(z) as.character(z$id), ""),
               tipo = vapply(v, function(z) .gm_testo(z$experimentalFactorType), ""),
               categoria = vapply(v, function(z) .gm_testo(z$experimentalFactorCategory$category), ""),
               testo = vapply(v, function(z) .gm_testo(z$summary), ""),
               blocco = vapply(v, .gm_blocco, NA), stringsAsFactors = FALSE)
  }))
  if (is.null(fv)) return(esce("senza_fattori", gsm = gsm))
  fatt <- unique(fv[c("fattore", "tipo", "categoria", "blocco")])
  if (anyDuplicated(fatt$fattore)) return(esce("fattore_incoerente", gsm = gsm))   # lo stesso fattore con due tipi o categorie
  fatt$motivo_uscita <- ifelse(fatt$blocco, "blocco", ifelse(fatt$tipo %in% "continuous", "continuo", NA))
  for (i in which(!is.na(fatt$motivo_uscita))) nota(paste0("fattore_tolto_", fatt$motivo_uscita[i]), fatt$categoria[i])
  tenuti <- fatt[is.na(fatt$motivo_uscita), , drop = FALSE]
  if (!nrow(tenuti)) return(esce("senza_fattori", gsm = gsm, fattori_gemma = fatt))
  tenuti <- tenuti[order(tenuti$categoria, as.numeric(tenuti$fattore)), , drop = FALSE]
  tenuti$nome <- sprintf("%s [%s]", ifelse(is.na(tenuti$categoria), "senza categoria", tenuti$categoria), tenuti$fattore)

  # 3. livelli
  livelli <- data.frame(row.names = gsm)
  nome_livello <- list()
  for (j in seq_len(nrow(tenuti))) {
    f <- fv[fv$fattore == tenuti$fattore[j], , drop = FALSE]
    if (anyDuplicated(f$gsm)) return(esce("campione_con_due_valori", gsm = gsm, fattore = tenuti$nome[j]))
    u <- unique(f[c("valore", "testo")])
    u$testo[is.na(u$testo) | !nzchar(trimws(u$testo))] <- "valore senza testo"
    u$testo <- trimws(u$testo)
    doppio <- u$testo %in% u$testo[duplicated(u$testo)] | u$testo %in% c(TF_NON_SCRITTO, TF_NON_APPLICABILE)
    if (any(doppio)) nota("testo_del_livello_ripetuto", tenuti$nome[j])
    u$livello <- ifelse(doppio, sprintf("%s [%s]", u$testo, u$valore), u$testo)
    nome_livello[[tenuti$fattore[j]]] <- stats::setNames(u$livello, u$valore)
    x <- u$livello[match(f$valore[match(gsm, f$gsm)], u$valore)]
    if (anyNA(x)) nota("campioni_senza_valore", sprintf("%s=%d", tenuti$nome[j], sum(is.na(x))))
    x[is.na(x)] <- TF_NON_SCRITTO
    livelli[[tenuti$nome[j]]] <- x
  }

  # 4. base: il baselineGroup degli insiemi di risultati a un solo fattore
  basi <- list(); n_inter <- 0L
  for (an in analisi) for (rs in an$resultSets %||% list()) {
    ef <- rs$experimentalFactors %||% list()
    if (length(ef) > 1L) { n_inter <- n_inter + 1L; next }
    if (length(ef) == 1L && !is.null(rs$baselineGroup) && !is.null(rs$baselineGroup$id)) {
      k <- as.character(ef[[1]]$id); basi[[k]] <- union(basi[[k]], as.character(rs$baselineGroup$id))
    }
  }
  if (n_inter) nota("interazioni_ignorate", as.character(n_inter))
  if (!length(analisi)) nota("senza_analisi")
  tenuti$base <- NA_character_
  for (j in seq_len(nrow(tenuti))) {
    b <- basi[[tenuti$fattore[j]]]
    if (is.null(b)) next
    if (length(b) > 1L) { nota("basi_diverse", tenuti$nome[j]); next }
    liv <- nome_livello[[tenuti$fattore[j]]][b]
    if (is.na(liv)) { nota("base_fuori_dai_campioni", tenuti$nome[j]); next }
    tenuti$base[j] <- unname(liv)
  }

  # 5. tipo
  contesto <- tf_fattore_di_contesto(tenuti$categoria)
  tempo <- tolower(trimws(tenuti$categoria)) %in% "timepoint"
  for (j in which((contesto | tempo) & !is.na(tenuti$base)))
    nota(if (contesto[j]) "base_di_contesto_non_usata" else "base_di_tempo_non_usata", tenuti$nome[j])
  tenuti$tipo <- ifelse(contesto, "contesto", ifelse(tempo, "tempo", ifelse(is.na(tenuti$base), "contesto", "perturbazione")))
  tenuti$base_gemma <- tenuti$base
  tenuti$base[tenuti$tipo != "perturbazione"] <- NA_character_

  tab <- tryCatch(tf_tabella(gsm, livelli, tenuti[c("nome", "tipo", "base")]), error = function(e) e)
  if (inherits(tab, "error")) {
    nota("tf_tabella", conditionMessage(tab))
    return(esce(paste0("tf_tabella:", sub("^simulomicsr_tf_", "", class(tab)[1])), gsm = gsm, fattori = tenuti))
  }
  # 6. gruppi e confronti del costruttore
  gr <- tf_gruppi(tab); kk <- tf_confronti(tab, n_min = 2L)
  partizione <- stats::setNames(rep(gr$gruppo, lengths(gr$campioni)), unlist(gr$campioni))
  stopifnot(setequal(names(partizione), gsm))
  list(esito = "tabella", chiuso = TRUE, note = note, studio = studio, gsm = gsm, tabella = tab, fattori = tenuti,
       fattori_gemma = fatt, partizione = partizione, confronti = kk$confronti, registro = kk$registro, n_gruppi = nrow(gr))
}

# ---- Controllo positivo (cancello K2): due studi finti nel formato di Gemma ---------------------------------
finto_fv <- function(id, fattore, categoria, testo, tipo = "categorical", blocco = FALSE)
  list(id = id, experimentalFactorId = fattore, experimentalFactorType = tipo,
       experimentalFactorCategory = list(category = categoria), summary = testo,
       characteristics = list(list(category = if (blocco) "block" else categoria, value = testo)))
finto_campione <- function(i, ...) list(accession = list(accession = sprintf("GSM%d", i)), outlier = FALSE,
                                        sample = list(fvbasicVOs = list(...)))
finto_insieme <- function(fattori, base = NULL)
  list(experimentalFactors = lapply(fattori, function(f) list(id = f)), baselineGroup = if (is.null(base)) NULL else list(id = base))
controllo_positivo <- function() {
  # Finto 1: trattamento (veicolo = base, farmaco) x linea cellulare (A, B), un blocco tecnico, un'interazione.
  veh <- finto_fv(11, 1, "treatment", "reference substance role"); dex <- finto_fv(12, 1, "treatment", "dexamethasone")
  la <- finto_fv(21, 2, "cell line", "A549"); lb <- finto_fv(22, 2, "cell line", "HeLa")
  b1 <- finto_fv(31, 3, "block", "Batch_01", blocco = TRUE); b2 <- finto_fv(32, 3, "block", "Batch_02", blocco = TRUE)
  cc <- list(finto_campione(1, veh, la, b1), finto_campione(2, veh, la, b2), finto_campione(3, dex, la, b1), finto_campione(4, dex, la, b2),
             finto_campione(5, veh, lb, b1), finto_campione(6, veh, lb, b2), finto_campione(7, dex, lb, b1), finto_campione(8, dex, lb, b2))
  an <- list(list(isSubset = FALSE, resultSets = list(finto_insieme(1, 11), finto_insieme(2, 21), finto_insieme(c(1, 2)))))
  r <- gemma_tabella(cc, an, "FINTO1")
  k <- r$confronti
  chiave <- function(k) sort(sprintf("%s>%s", vapply(k$trattato, paste, "", collapse = ","), vapply(k$controllo, paste, "", collapse = ",")))
  stopifnot(r$esito == "tabella", r$n_gruppi == 4L,
            identical(r$fattori$tipo, c("contesto", "perturbazione")), identical(r$fattori$base, c(NA, "reference substance role")),
            nrow(k) == 2L, identical(chiave(k), c("GSM3,GSM4>GSM1,GSM2", "GSM7,GSM8>GSM5,GSM6")),
            any(grepl("^fattore_tolto_blocco", r$note)), any(grepl("^interazioni_ignorate:1$", r$note)),
            any(grepl("^base_di_contesto_non_usata", r$note)))
  # Finto 2: lo stesso disegno, ma le analisi su sottoinsiemi dichiarano basi diverse per il trattamento.
  an2 <- list(list(isSubset = TRUE, resultSets = list(finto_insieme(1, 11))), list(isSubset = TRUE, resultSets = list(finto_insieme(1, 12))))
  r2 <- gemma_tabella(cc, an2, "FINTO2")
  stopifnot(r2$esito == "tabella", any(grepl("^basi_diverse", r2$note)), all(is.na(r2$fattori$base)), nrow(r2$confronti) == 0L,
            r2$n_gruppi == 4L)
  # Finto 3: un campione senza GSM ferma lo studio; uno studio senza fattori ha il suo codice.
  cc3 <- cc; cc3[[1]]$accession$accession <- NULL
  stopifnot(gemma_tabella(cc3, an, "FINTO3")$esito == "campione_senza_gsm",
            gemma_tabella(lapply(1:4, finto_campione), list(), "FINTO4")$esito == "senza_fattori")
  cat("K2 controllo positivo dell'adattatore: passato (tabella, base, 2 confronti, blocco tolto, basi diverse, codici di uscita)\n")
  invisible(TRUE)
}

# ---- Da riga di comando: K2 e K3 ----------------------------------------------------------------------------
if (sys.nframe() == 0L) {
  suppressMessages(devtools::load_all(".", quiet = TRUE))
  controllo_positivo()
  el <- utils::read.csv(file.path(G, "11-da-scaricare.csv"), stringsAsFactors = FALSE)
  nomi <- sort(sub("\\.samples\\.json\\.gz$", "", list.files(GEMMA_DIR, pattern = "\\.samples\\.json\\.gz$")), method = "radix")
  # K4: nessun file di uno studio di giudizio
  div <- utils::read.delim("analysis/audit/2026-11-09-lettore-studio/30-divisione.tsv", stringsAsFactors = FALSE)
  giudizio <- div$gse[div$parte != "sviluppo"]
  stopifnot(length(giudizio) == 82L, !any(sub("\\..*$", "", nomi) %in% giudizio),
            !any(nomi %in% el$shortName[grepl("^giudizio", el$parte)]))
  cat(sprintf("K4: 0 file di studi di giudizio fra le %d voci scaricate\n", length(nomi)))
  esiti <- do.call(rbind, lapply(nomi, function(n) {
    r <- tryCatch({ x <- gemma_leggi(n); gemma_tabella(x$campioni, x$analisi, n) },
                  error = function(e) list(esito = "errore_non_previsto", chiuso = FALSE, note = conditionMessage(e)))
    data.frame(shortName = n, parte = el$parte[match(n, el$shortName)], esito = r$esito,
               campioni = length(r$gsm %||% character(0)),
               fattori = if (is.null(r$fattori)) NA_integer_ else nrow(r$fattori),
               fattori_con_base = if (is.null(r$fattori)) NA_integer_ else sum(!is.na(r$fattori$base)),
               gruppi = r$n_gruppi %||% NA_integer_, gruppi_da_uno = if (r$chiuso) sum(table(r$partizione) == 1L) else NA_integer_,
               confronti = if (r$chiuso) nrow(r$confronti) else NA_integer_,
               note = paste(unique(sub(":.*$", "", r$note)), collapse = " | "), stringsAsFactors = FALSE)
  }))
  utils::write.csv(esiti, file.path(G, "30-esiti.csv"), row.names = FALSE, na = "")
  stopifnot(nrow(esiti) == length(nomi), !anyNA(esiti$esito), !any(esiti$esito == "errore_non_previsto"), !anyNA(esiti$parte))
  cat(sprintf("K3: %d voci, %d esiti\n", length(nomi), nrow(esiti)))
  print(table(esiti$esito, esiti$parte))
  t <- esiti[esiti$esito == "tabella", ]
  cat(sprintf("con tabella: %d; con almeno un confronto: %d; confronti in tutto: %d; gruppi mediana %g; studi con tutti i gruppi da un campione: %d\n",
              nrow(t), sum(t$confronti > 0), sum(t$confronti), stats::median(t$gruppi), sum(t$gruppi_da_uno == t$gruppi)))
  nn <- table(unlist(strsplit(esiti$note[nzchar(esiti$note)], " | ", fixed = TRUE)))
  cat("note (voci con la nota):\n"); print(sort(nn, decreasing = TRUE))
}
