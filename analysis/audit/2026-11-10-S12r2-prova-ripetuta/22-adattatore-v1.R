# PROVA DA BUTTARE
# 22-adattatore-v1.R — l'adattatore del lettore v1 (S12r2): dall'uscita del modello (schema v1) e dalla vista
# dello studio alla tabella dei fattori del pacchetto, poi `tf_confronti()`. Scritto e committato PRIMA di ogni
# corsa col prompt v1: nessuna regola qui sotto ha visto un'uscita v1.
#
# Uso: `source()` da uno script di misura (definisce `adatta_v1()` e passa il controllo positivo), oppure da solo:
#   Rscript analysis/audit/2026-11-10-S12r2-prova-ripetuta/22-adattatore-v1.R
# Chiede `devtools::load_all(".")` gia' fatto e `aiuti-misura-r2.R` gia' letto (per `R2`).
#
# Regole, uguali a quelle dell'adattatore v0 di S12r dove lo schema non cambia (una sola cosa cambia: lo schema):
#   - chiudono lo studio senza misura: oltre_contesto, troncata, non_valida, non_coperta, mappa_ambigua (i cinque
#     nominati in 00-previsioni.md) e, come in S12r, livello_assente, base_assente, base_non_ammessa,
#     colonna_ignota, livello_riservato, tf_tabella:<classe>. Si contano per motivo;
#   - una voce di `assignment` ha la FORMA SBAGLIATA (previsione L2) quando una condizione nomina una colonna che
#     non e' una colonna di fonte del fattore, oppure due condizioni della stessa voce nominano la stessa colonna.
#     La voce non si usa e si conta (nota `voci_malformate`);
#   - un campione prende il livello di una voce quando soddisfa tutte le condizioni; se soddisfa voci con due
#     livelli diversi la mappa e' ambigua; se non ne soddisfa nessuna il campione non e' coperto;
#   - una voce che nessun campione soddisfa (valore che la tabella non contiene) si conta (nota `voci_in_piu`);
#   - `not stated` -> TF_NON_SCRITTO, `not applicable` -> TF_NON_APPLICABILE; i due nomi riservati scritti fra i
#     `levels` sono una nota, non un errore;
#   - una base scritta fra i `levels` ma senza campioni: il fattore entra senza base (nota `base_senza_campioni`,
#     previsione L4);
#   - una colonna di fonte puo' essere `gsm` o una colonna costante della vista (note `fonte_gsm`, `fonte_costante`);
#   - soggetti: le voci di `other_columns` con ruolo `subject`; i valori in `missing_values` e le celle vuote
#     valgono «non scritto» (NA). Una colonna di soggetto che e' anche fonte di un fattore resta soggetto (nota);
#   - fattore con un livello per campione (previsione L3): la definizione di 05-diagnosi-v0.py, senza cambi:
#     piu' di 2 campioni e (livelli scritti >= campioni, oppure una fonte con un valore per campione e livelli
#     scritti > meta' dei campioni). Si conta, non si scarta (spec par. 5.2, aggiornamento, punto 2).
NON_STATED_V1 <- "not stated"
NON_APPLICABLE_V1 <- "not applicable"
TIPI_V1 <- c(perturbation = "perturbazione", state = "stato", context = "contesto", time = "tempo", technical = "tecnico")
SOGG_V1 <- c(donor = "donatore", sex = "sesso", age = "eta", passage = "passaggio", batch = "lotto", pair = "coppia")
MOTIVI_DEPOSITATI <- c("oltre_contesto", "troncata", "non_valida", "non_coperta", "mappa_ambigua")
MOTIVI_S12R <- c("livello_assente", "base_assente", "base_non_ammessa", "colonna_ignota", "livello_riservato")
stopifnot(setequal(unname(TIPI_V1), TF_TIPI), setequal(unname(SOGG_V1), TF_SOGGETTI))
SCHEMA_V1 <- file.path(R2, "20-schema-v1.json")
validatore_v1 <- compile_schema(SCHEMA_V1)
unisci <- function(x, sep = " | ") paste(x, collapse = sep)
car <- function(x) if (is.null(x)) character(0) else as.character(unlist(x))

# Ritorna: chiuso, motivi (nome: dettaglio), note, conti (voci, voci_malformate, fattori_per_campione,
# basi_senza_campioni) e, se chiuso, tabella, confronti, registro, partizione, fattori.
adatta_v1 <- function(v, raw, saltato, fine) {
  motivi <- character(0); note <- character(0)
  conti <- c(voci = 0L, voci_malformate = 0L, fattori_per_campione = 0L, basi_senza_campioni = 0L,
             livelli_non_applicabile = 0L, livelli_non_scritto = 0L)
  agg <- function(m, d = "") motivi <<- c(motivi, if (nzchar(d)) paste0(m, ": ", d) else m)
  nt <- function(m, d = "") note <<- c(note, if (nzchar(d)) paste0(m, ": ", d) else m)
  esce <- function() list(chiuso = FALSE, motivi = motivi, note = note, conti = conti)
  if (isTRUE(saltato)) { agg("oltre_contesto"); return(esce()) }
  if (identical(fine, "length")) agg("troncata")
  val <- if (is.na(raw) || !nzchar(raw)) list(valid = FALSE, errors = "uscita vuota") else
    tryCatch(validate_json(raw, validatore_v1), error = function(e) list(valid = FALSE, errors = conditionMessage(e)))
  if (!isTRUE(val$valid)) { agg("non_valida", unisci(utils::head(val$errors, 3L))); return(esce()) }
  u <- jsonlite::fromJSON(raw, simplifyVector = FALSE)
  gsm <- car(v$campioni); n <- length(gsm)
  if (!identical(u$series_id, v$record_id)) nt("series_id_diverso", u$series_id)
  valori <- function(col) {
    if (col == "gsm") return(gsm)
    if (col %in% names(v$tabella)) return(vapply(gsm, function(g) v$tabella[[col]][[g]], "", USE.NAMES = FALSE))
    rep(v$costanti[[col]], n)
  }
  colonne_note <- c("gsm", names(v$tabella), names(v$costanti))
  uniche <- Filter(function(k) n > 1L && length(unique(valori(k))) == n, names(v$tabella))

  nf <- length(u$factors)
  livelli <- data.frame(row.names = gsm)
  fattori <- data.frame(nome = character(nf), tipo = character(nf), base = rep(NA_character_, nf),
                        fonti = character(nf), livelli_scritti = character(nf), n_livelli_scritti = integer(nf),
                        n_livelli_assegnati = integer(nf), per_campione = logical(nf), stringsAsFactors = FALSE)
  for (i in seq_len(nf)) {
    f <- u$factors[[i]]
    nome <- f$name; fonti <- unique(car(f$source_columns))
    liv <- unique(vapply(f$levels, function(l) l$level, ""))
    fattori$nome[i] <- nome; fattori$tipo[i] <- TIPI_V1[[f$type]]
    fattori$fonti[i] <- unisci(fonti); fattori$livelli_scritti[i] <- unisci(liv); fattori$n_livelli_scritti[i] <- length(liv)
    fattori$per_campione[i] <- n > 2L && (length(liv) >= n || (any(fonti %in% c(uniche, "gsm")) && length(liv) > n / 2))
    if (fattori$per_campione[i]) conti[["fattori_per_campione"]] <- conti[["fattori_per_campione"]] + 1L
    if (any(c(TF_NON_SCRITTO, TF_NON_APPLICABILE) %in% liv)) agg("livello_riservato", nome)
    if (any(c(NON_STATED_V1, NON_APPLICABLE_V1) %in% liv)) nt("riservato_fra_i_livelli", nome)
    ignote <- setdiff(fonti, colonne_note)
    if (length(ignote)) { agg("colonna_ignota", sprintf("%s <- %s", nome, unisci(ignote, ", "))); next }
    if ("gsm" %in% fonti) nt("fonte_gsm", nome)
    if (any(fonti %in% names(v$costanti))) nt("fonte_costante", sprintf("%s <- %s", nome, unisci(intersect(fonti, names(v$costanti)), ", ")))
    m <- stats::setNames(lapply(fonti, valori), fonti)
    nv <- length(f$assignment); conti[["voci"]] <- conti[["voci"]] + nv
    l_voce <- vapply(f$assignment, function(a) a$level, "")
    # quali campioni soddisfano ogni voce (matrice campioni x voci); NA = voce di forma sbagliata
    buona <- logical(nv); sodd <- matrix(FALSE, nrow = n, ncol = nv)
    for (j in seq_len(nv)) {
      cc <- vapply(f$assignment[[j]]$when, function(k) k$column, "")
      vv <- vapply(f$assignment[[j]]$when, function(k) k$value, "")
      buona[j] <- length(cc) > 0L && all(cc %in% fonti) && !anyDuplicated(cc)
      if (!buona[j]) next
      s <- rep(TRUE, n)
      for (k in seq_along(cc)) s <- s & (m[[cc[k]]] == vv[k])
      sodd[, j] <- s
    }
    if (any(!buona)) {
      conti[["voci_malformate"]] <- conti[["voci_malformate"]] + sum(!buona)
      nt("voci_malformate", sprintf("%s: %d", nome, sum(!buona)))
    }
    assenti <- setdiff(l_voce, c(liv, NON_STATED_V1, NON_APPLICABLE_V1))
    if (length(assenti)) agg("livello_assente", sprintf("%s: %s", nome, unisci(assenti, ", ")))
    in_piu <- sum(buona & colSums(sodd) == 0L)
    if (in_piu) nt("voci_in_piu", sprintf("%s: %d", nome, in_piu))
    lv <- rep(NA_character_, n); ambigui <- 0L
    for (r in seq_len(n)) {
      x <- unique(l_voce[sodd[r, ]])
      if (length(x) == 1L) lv[r] <- x else if (length(x) > 1L) ambigui <- ambigui + 1L
    }
    scoperti <- rowSums(sodd) == 0L
    if (ambigui) agg("mappa_ambigua", sprintf("%s: %d campioni", nome, ambigui))
    if (any(scoperti)) agg("non_coperta", sprintf("%s: %d campioni, per esempio %s", nome, sum(scoperti), gsm[scoperti][1]))
    b <- f$baseline_level
    if (nzchar(b)) {
      if (!(f$type %in% c("perturbation", "state"))) agg("base_non_ammessa", sprintf("%s (%s): %s", nome, f$type, b))
      if (!(b %in% liv)) agg("base_assente", sprintf("%s: %s", nome, b))
    }
    conti[["livelli_non_scritto"]] <- conti[["livelli_non_scritto"]] + as.integer(any(lv %in% NON_STATED_V1))
    conti[["livelli_non_applicabile"]] <- conti[["livelli_non_applicabile"]] + as.integer(any(lv %in% NON_APPLICABLE_V1))
    lv[lv %in% NON_STATED_V1] <- TF_NON_SCRITTO
    lv[lv %in% NON_APPLICABLE_V1] <- TF_NON_APPLICABILE
    fattori$n_livelli_assegnati[i] <- length(unique(lv[!is.na(lv)]))
    if (nzchar(b) && (b %in% liv)) {
      if (b %in% lv) fattori$base[i] <- b else {
        conti[["basi_senza_campioni"]] <- conti[["basi_senza_campioni"]] + 1L
        nt("base_senza_campioni", sprintf("%s: %s", nome, b))
      }
    }
    if (!length(motivi)) livelli[[nome]] <- lv
  }
  if (length(motivi)) return(c(esce(), list(fattori = fattori)))

  # soggetti: le voci di `other_columns` con ruolo `subject`
  tutte_fonti <- unique(unlist(lapply(u$factors, function(f) car(f$source_columns))))
  scritte <- vapply(u$other_columns, function(k) k$column, "")
  senza <- setdiff(names(v$tabella), c(scritte, tutte_fonti))
  if (length(senza)) nt("colonne_senza_ruolo", unisci(senza, ", "))
  if (length(setdiff(scritte, names(v$tabella)))) nt("ruolo_a_colonna_ignota", unisci(setdiff(scritte, names(v$tabella)), ", "))
  if (length(intersect(scritte, tutte_fonti))) nt("ruolo_a_colonna_di_fonte", unisci(intersect(scritte, tutte_fonti), ", "))
  soggetti <- NULL; tipo_soggetto <- NULL
  for (k in Filter(function(k) identical(k$role, "subject"), u$other_columns)) {
    col <- k$column
    if (!(col %in% names(v$tabella))) { nt("soggetto_colonna_ignota", col); next }
    x <- valori(col); manc <- car(k$missing_values)
    if (length(manc)) nt("soggetto_valori_mancanti", sprintf("%s: %s (%d campioni)", col, unisci(manc, ", "), sum(x %in% manc)))
    x[!nzchar(x) | x %in% manc] <- NA_character_
    nome_col <- col
    if (nome_col %in% c(fattori$nome, names(soggetti))) { nome_col <- paste0(col, " (soggetto)"); nt("soggetto_rinominato", col) }
    if (is.null(soggetti)) soggetti <- data.frame(row.names = gsm)
    soggetti[[nome_col]] <- x
    if (nzchar(k$subject_kind)) tipo_soggetto[nome_col] <- SOGG_V1[[k$subject_kind]] else nt("soggetto_senza_tipo", col)
  }
  tab <- tryCatch(tf_tabella(gsm, livelli, fattori[c("nome", "tipo", "base")], soggetti, tipo_soggetto),
                  error = function(e) e)
  if (inherits(tab, "error")) {
    agg(paste0("tf_tabella:", sub("^simulomicsr_tf_", "", class(tab)[1])), conditionMessage(tab))
    return(c(esce(), list(fattori = fattori)))
  }
  kk <- tf_confronti(tab, n_min = 2L)
  gr <- tf_gruppi(tab)
  partizione <- stats::setNames(rep(gr$gruppo, lengths(gr$campioni)), unlist(gr$campioni))
  stopifnot(setequal(names(partizione), gsm))
  list(chiuso = TRUE, motivi = motivi, note = note, conti = conti, tabella = tab, confronti = kk$confronti,
       registro = kk$registro, partizione = partizione, fattori = fattori, n_soggetti = length(tipo_soggetto),
       n_gruppi = nrow(gr))
}

confronti_comuni <- function(studio, k) {
  out <- data.frame(studio = rep(studio, nrow(k)), id = as.character(k$id), stringsAsFactors = FALSE)
  out$trattato <- unname(k$trattato); out$controllo <- unname(k$controllo)
  out
}
CONFRONTI_VUOTI <- function(studio) tf_da_stage2(list(series_id = studio))$confronti

# ---- Controllo positivo dell'adattatore: uno studio finto --------------------------------------------------
# 12 campioni: malattia (sano/malato) x farmaco (veicolo/dex, scritto in due colonne insieme) e lo stadio,
# annidato nella malattia. Attesi: 6 gruppi; farmaco contro veicolo dentro sano, stadio II, stadio III (3);
# malato contro sano con l'avviso `annidato:stage`, per ogni stadio e ogni livello del farmaco (4).
local({
  g <- sprintf("GSM%d", 1:12)
  col <- function(x) as.list(stats::setNames(x, g))
  v <- list(record_id = "GSE0", campioni = as.list(g),
            tabella = list(disease = col(rep(c("healthy", "IBD", "IBD"), each = 4)),
                           stage = col(rep(c("", "II", "III"), each = 4)),
                           agent = col(rep(c("none", "none", "Dex", "Dex"), 3)),
                           dose = col(rep(c("", "", "1 uM", "1 uM"), 3)),
                           sex = col(rep(c("F", "M", "F", "NA"), 3)),
                           title = col(sprintf("sample %d", 1:12))),
            costanti = list(tissue = "colon"))
  lv <- function(l, e = "") list(level = l, text_as_written = l, entity = e, dose = "", duration = "")
  w <- function(...) { x <- list(...); lapply(seq(1, length(x), 2), function(i) list(column = x[[i]], value = x[[i + 1]])) }
  buona <- list(series_id = "GSE0",
    factors = list(
      list(name = "disease", type = "state", source_columns = list("disease"),
           levels = list(lv("healthy"), lv("IBD", "inflammatory bowel disease")),
           baseline_level = "healthy", baseline_evidence = "healthy",
           assignment = list(list(when = w("disease", "healthy"), level = "healthy"),
                             list(when = w("disease", "IBD"), level = "IBD"))),
      list(name = "stage", type = "state", source_columns = list("stage"),
           levels = list(lv("II"), lv("III")), baseline_level = "", baseline_evidence = "",
           assignment = list(list(when = w("stage", ""), level = "not applicable"),
                             list(when = w("stage", "II"), level = "II"),
                             list(when = w("stage", "III"), level = "III"))),
      list(name = "compound", type = "perturbation", source_columns = list("agent", "dose"),
           levels = list(lv("vehicle"), lv("dex 1 uM", "dexamethasone")),
           baseline_level = "vehicle", baseline_evidence = "none",
           assignment = list(list(when = w("agent", "none"), level = "vehicle"),
                             list(when = w("agent", "Dex", "dose", "1 uM"), level = "dex 1 uM")))),
    other_columns = list(list(column = "sex", role = "subject", subject_kind = "sex", missing_values = list("NA")),
                         list(column = "title", role = "replicate", subject_kind = "", missing_values = list())),
    not_understood = list())
  js <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
  r <- adatta_v1(v, js(buona), FALSE, "stop")
  stopifnot(r$chiuso, r$n_gruppi == 6L, r$n_soggetti == 1L, sum(is.na(r$tabella$soggetti$sex)) == 3L,
            r$conti[["voci"]] == 7L, r$conti[["voci_malformate"]] == 0L, r$conti[["fattori_per_campione"]] == 0L,
            r$conti[["livelli_non_applicabile"]] == 1L, sum(r$tabella$livelli$stage == TF_NON_APPLICABILE) == 4L)
  k <- r$confronti
  stopifnot(nrow(k) == 7L, sum(k$fattore == "compound") == 3L, sum(k$fattore == "disease") == 4L,
            all(grepl("annidato:stage", vapply(k$avvisi[k$fattore == "disease"], unisci, ""), fixed = TRUE)))
  rotta <- function(cambia) { x <- buona; x <- cambia(x); adatta_v1(v, js(x), FALSE, "stop") }
  motivo <- function(r) sub(":.*$", "", r$motivi)
  stopifnot(identical(motivo(adatta_v1(v, NA_character_, TRUE, NA_character_)), "oltre_contesto"))
  stopifnot(identical(motivo(adatta_v1(v, substr(js(buona), 1, 200), FALSE, "length")), c("troncata", "non_valida")))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$type <- "drug"; x })), "non_valida"))
  # la forma v0 (lista per posizione) non passa lo schema v1
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$assignment[[1]] <- list(values = list("healthy"), level = "healthy"); x })), "non_valida"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$assignment[[1]]$when <- list(); x })), "non_valida"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$assignment[[2]] <- NULL; x })), "non_coperta"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$assignment[[2]]$when <- w("disease", "ibd"); x })), "non_coperta"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[3]]$assignment[[3]] <- list(when = w("dose", ""), level = "dex 1 uM"); x })), "mappa_ambigua"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$assignment[[2]]$level <- "ibd"; x })), "livello_assente"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$baseline_level <- "control"; x })), "base_assente"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[2]]$type <- "context"; x$factors[[2]]$baseline_level <- "II"; x })), "base_non_ammessa"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$source_columns <- list("diagnosis"); x })), "colonna_ignota"))
  # voce di forma sbagliata: una colonna che non e' fonte del fattore. La voce non si usa: i campioni restano scoperti.
  r <- rotta(function(x) { x$factors[[1]]$assignment[[2]]$when <- w("stage", "II"); x })
  stopifnot(!r$chiuso, r$conti[["voci_malformate"]] == 1L, identical(motivo(r), "non_coperta"))
  # due voci sugli stessi campioni con lo stesso livello non sono una mappa ambigua
  r <- rotta(function(x) { x$factors[[3]]$assignment[[3]] <- list(when = w("dose", ""), level = "vehicle"); x })
  stopifnot(r$chiuso, nrow(r$confronti) == 7L)
  # `not stated` diventa TF_NON_SCRITTO; la base senza campioni si conta e il fattore resta senza base
  r <- rotta(function(x) { x$factors[[3]]$assignment[[1]]$level <- "not stated"; x })
  stopifnot(r$chiuso, TF_NON_SCRITTO %in% r$tabella$livelli$compound, r$conti[["basi_senza_campioni"]] == 1L,
            is.na(r$fattori$base[3]), sum(r$confronti$fattore == "compound") == 0L)
  # il fattore con un livello per campione si conta e non si scarta
  r <- rotta(function(x) {
    x$factors[[4]] <- list(name = "sample", type = "technical", source_columns = list("title"),
                           levels = lapply(sprintf("s%d", 1:12), lv), baseline_level = "", baseline_evidence = "",
                           assignment = lapply(1:12, function(i) list(when = w("title", sprintf("sample %d", i)), level = sprintf("s%d", i))))
    x$other_columns[[2]] <- NULL; x })
  stopifnot(r$chiuso, r$conti[["fattori_per_campione"]] == 1L, r$n_gruppi == 12L, nrow(r$confronti) == 0L)
  r <- rotta(function(x) { x$factors <- list(); x })
  stopifnot(r$chiuso, r$n_gruppi == 1L, nrow(r$confronti) == 0L)
  cat("controllo positivo dell'adattatore v1: passato (studio finto: 6 gruppi, 7 confronti, fattore annidato,",
      "voce con due condizioni, valore di soggetto mancante; 11 esiti che chiudono visti)\n")
})
