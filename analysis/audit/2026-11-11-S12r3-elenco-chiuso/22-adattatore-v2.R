# PROVA DA BUTTARE
# 22-adattatore-v2.R — l'adattatore del lettore v2 (S12r3): dall'uscita del modello (schema a elenco chiuso,
# generato per ogni studio da 10-schema-per-studio.R, forma 3) e dalla vista dello studio alla tabella dei
# fattori del pacchetto, poi `tf_confronti()`. Scritto e committato PRIMA di ogni corsa col prompt v2: nessuna
# regola qui sotto ha visto un'uscita v2 su un testo di studio.
#
# Uso: `source()` da uno script di misura (definisce `adatta_v2()` e passa il controllo positivo, cancello K2 ii),
# oppure da solo:
#   Rscript analysis/audit/2026-11-11-S12r3-elenco-chiuso/22-adattatore-v2.R
# Chiede `devtools::load_all(".")` gia' fatto. Legge da solo 10-schema-per-studio.R. Non usa `--vanilla`.
#
# Regole (00-previsioni.md, «Studio non chiuso»; spec par. 5.2, aggiornamento 2026-11-11):
#   - chiudono lo studio senza misura: oltre_contesto, troncata, non_valida (contro lo schema DELLO STUDIO),
#     livello_assente, base_assente, base_non_ammessa, livello_riservato, ruolo_incoerente, tf_tabella:<classe>.
#     Si contano per motivo. Nessuna tolleranza di forma;
#   - un fattore legge UNA colonna (`assignment$column`) e ogni valore distinto della colonna ha la sua voce
#     (`assignment$values`): lo garantisce lo schema, e l'adattatore lo ricontrolla (stopifnot). Un campione
#     prende il livello della voce del suo valore. I motivi non_coperta, mappa_ambigua e colonna_ignota di
#     S12r2 non possono piu' nascere e non esistono qui;
#   - `not stated` -> TF_NON_SCRITTO, `not applicable` -> TF_NON_APPLICABILE; i due nomi riservati scritti fra i
#     `levels` sono una nota, non un errore; i due nomi interni del pacchetto fra i `levels` sono
#     `livello_riservato`;
#   - il livello di una voce che il fattore non dichiara: `livello_assente`;
#   - una base in un fattore non perturbation/state: `base_non_ammessa`; una base non fra i `levels`:
#     `base_assente`; una base scritta fra i `levels` ma senza campioni: il fattore entra senza base (nota
#     `base_senza_campioni`, previsione E15);
#   - `columns`: una colonna ha il ruolo `factor` se e solo se un fattore la legge; altrimenti
#     `ruolo_incoerente` (nuovo), con il verso scritto nel dettaglio;
#   - soggetti: le voci di `columns` con ruolo `subject`; i valori in `missing_values` e le celle vuote valgono
#     «non scritto» (NA);
#   - fattore con un livello per campione (previsione E14): la definizione di S12r2, senza cambi: piu' di 2
#     campioni e (livelli scritti >= campioni, oppure la colonna ha un valore per campione e livelli scritti >
#     meta' dei campioni). Si conta, non si scarta.
if (!exists("schema_studio")) source("analysis/audit/2026-11-11-S12r3-elenco-chiuso/10-schema-per-studio.R")
NON_STATED_V2 <- "not stated"
NON_APPLICABLE_V2 <- "not applicable"
TIPI_V2 <- c(perturbation = "perturbazione", state = "stato", context = "contesto", time = "tempo", technical = "tecnico")
SOGG_V2 <- c(donor = "donatore", sex = "sesso", age = "eta", passage = "passaggio", batch = "lotto", pair = "coppia")
MOTIVI_V2 <- c("oltre_contesto", "troncata", "non_valida", "livello_assente", "base_assente", "base_non_ammessa",
               "livello_riservato", "ruolo_incoerente")   # piu' tf_tabella:<classe>
stopifnot(setequal(unname(TIPI_V2), TF_TIPI), setequal(unname(SOGG_V2), TF_SOGGETTI),
          setequal(names(TIPI_V2), TIPI_USCITA), setequal(c(names(SOGG_V2), ""), SOGGETTI_USCITA))
unisci <- function(x, sep = " | ") paste(x, collapse = sep)
car <- function(x) if (is.null(x)) character(0) else as.character(unlist(x))

# il valore di ogni campione in una colonna, con la stessa regola del generatore (cella assente = "")
valori_campioni <- function(v, col) {
  gsm <- car(v$campioni)
  vapply(gsm, function(g) { y <- v$tabella[[col]][[g]]; if (is.null(y) || is.na(y)) "" else as.character(y) }, "", USE.NAMES = FALSE)
}
# il validatore dello schema dello studio (ajv legge il draft 2020-12 con le tuple: provato prima, e nel
# controllo positivo qui sotto). Uno per studio, in memoria.
.validatori_v2 <- new.env()
validatore_v2 <- function(v) {
  k <- v$record_id
  if (is.null(.validatori_v2[[k]])) {
    f <- tempfile(fileext = ".json"); on.exit(unlink(f))
    con <- file(f, "wb"); writeLines(enc2utf8(schema_json(v)), con, useBytes = TRUE); close(con)
    .validatori_v2[[k]] <- compile_schema(f)
  }
  .validatori_v2[[k]]
}

# Ritorna: chiuso, motivi (nome: dettaglio), note, conti e, se chiuso, tabella, confronti, registro, partizione,
# fattori, n_soggetti, n_gruppi.
adatta_v2 <- function(v, raw, saltato, fine) {
  motivi <- character(0); note <- character(0)
  conti <- c(voci = 0L, fattori_per_campione = 0L, basi_senza_campioni = 0L,
             livelli_non_applicabile = 0L, livelli_non_scritto = 0L)
  agg <- function(m, d = "") motivi <<- c(motivi, if (nzchar(d)) paste0(m, ": ", d) else m)
  nt <- function(m, d = "") note <<- c(note, if (nzchar(d)) paste0(m, ": ", d) else m)
  esce <- function() list(chiuso = FALSE, motivi = motivi, note = note, conti = conti)
  if (isTRUE(saltato)) { agg("oltre_contesto"); return(esce()) }
  if (identical(fine, "length")) agg("troncata")
  val <- if (is.na(raw) || !nzchar(raw)) list(valid = FALSE, errors = "uscita vuota") else
    tryCatch(validate_json(raw, validatore_v2(v)), error = function(e) list(valid = FALSE, errors = conditionMessage(e)))
  if (!isTRUE(val$valid)) { agg("non_valida", unisci(utils::head(val$errors, 3L))); return(esce()) }
  if (length(motivi)) return(esce())                       # troncata ma valida: non si misura lo stesso
  u <- jsonlite::fromJSON(raw, simplifyVector = FALSE)
  gsm <- car(v$campioni); n <- length(gsm); colonne <- car(v$colonne)
  stopifnot(identical(u$series_id, v$record_id))           # lo schema lo fissa
  uniche <- Filter(function(k) n > 1L && length(valori_colonna(v, k)) == n, colonne)

  nf <- length(u$factors)
  livelli <- data.frame(row.names = gsm)
  fattori <- data.frame(nome = character(nf), tipo = character(nf), base = rep(NA_character_, nf),
                        fonti = character(nf), livelli_scritti = character(nf), n_livelli_scritti = integer(nf),
                        n_livelli_assegnati = integer(nf), per_campione = logical(nf), stringsAsFactors = FALSE)
  for (i in seq_len(nf)) {
    f <- u$factors[[i]]
    nome <- f$name; col <- f$assignment$column
    liv <- unique(vapply(f$levels, function(l) l$level, ""))
    vals <- vapply(f$assignment$values, function(a) a$value, "")
    l_voce <- vapply(f$assignment$values, function(a) a$level, "")
    stopifnot(col %in% colonne, identical(vals, valori_colonna(v, col)))   # lo schema lo fissa
    conti[["voci"]] <- conti[["voci"]] + length(vals)
    fattori$nome[i] <- nome; fattori$tipo[i] <- TIPI_V2[[f$type]]
    fattori$fonti[i] <- col; fattori$livelli_scritti[i] <- unisci(liv); fattori$n_livelli_scritti[i] <- length(liv)
    fattori$per_campione[i] <- n > 2L && (length(liv) >= n || (col %in% uniche && length(liv) > n / 2))
    if (fattori$per_campione[i]) conti[["fattori_per_campione"]] <- conti[["fattori_per_campione"]] + 1L
    if (any(c(TF_NON_SCRITTO, TF_NON_APPLICABILE) %in% liv)) agg("livello_riservato", nome)
    if (any(c(NON_STATED_V2, NON_APPLICABLE_V2) %in% liv)) nt("riservato_fra_i_livelli", nome)
    assenti <- setdiff(l_voce, c(liv, NON_STATED_V2, NON_APPLICABLE_V2))
    if (length(assenti)) agg("livello_assente", sprintf("%s: %s", nome, unisci(assenti, ", ")))
    b <- f$baseline_level
    if (nzchar(b)) {
      if (!(f$type %in% c("perturbation", "state"))) agg("base_non_ammessa", sprintf("%s (%s): %s", nome, f$type, b))
      if (!(b %in% liv)) agg("base_assente", sprintf("%s: %s", nome, b))
    }
    lv <- l_voce[match(valori_campioni(v, col), vals)]
    stopifnot(!anyNA(lv))
    conti[["livelli_non_scritto"]] <- conti[["livelli_non_scritto"]] + as.integer(any(lv %in% NON_STATED_V2))
    conti[["livelli_non_applicabile"]] <- conti[["livelli_non_applicabile"]] + as.integer(any(lv %in% NON_APPLICABLE_V2))
    lv[lv %in% NON_STATED_V2] <- TF_NON_SCRITTO
    lv[lv %in% NON_APPLICABLE_V2] <- TF_NON_APPLICABILE
    fattori$n_livelli_assegnati[i] <- length(unique(lv))
    if (nzchar(b) && (b %in% liv)) {
      if (b %in% lv) fattori$base[i] <- b else {
        conti[["basi_senza_campioni"]] <- conti[["basi_senza_campioni"]] + 1L
        nt("base_senza_campioni", sprintf("%s: %s", nome, b))
      }
    }
    if (nome %in% names(livelli)) nt("nome_di_fattore_doppio", nome)
    if (!length(motivi)) livelli[[nome]] <- lv
  }

  # `columns`: la tupla e' completa e in ordine (lo schema lo fissa); il ruolo `factor` deve dire il vero
  scritte <- vapply(u$columns, function(k) k$column, "")
  ruoli <- stats::setNames(vapply(u$columns, function(k) k$role, ""), scritte)
  stopifnot(identical(scritte, colonne))
  lette <- unique(fattori$fonti)
  senza_fattore <- setdiff(names(ruoli)[ruoli == "factor"], lette)
  senza_ruolo <- setdiff(lette, names(ruoli)[ruoli == "factor"])
  if (length(senza_fattore)) agg("ruolo_incoerente", sprintf("ruolo factor e nessun fattore la legge: %s", unisci(senza_fattore, ", ")))
  if (length(senza_ruolo)) agg("ruolo_incoerente", sprintf("un fattore la legge e il ruolo e' %s", unisci(sprintf("%s (%s)", senza_ruolo, ruoli[senza_ruolo]), ", ")))
  if (length(motivi)) return(c(esce(), list(fattori = fattori)))

  soggetti <- NULL; tipo_soggetto <- NULL
  for (k in Filter(function(k) identical(k$role, "subject"), u$columns)) {
    col <- k$column
    x <- valori_campioni(v, col); manc <- car(k$missing_values)
    if (length(manc)) nt("soggetto_valori_mancanti", sprintf("%s: %s (%d campioni)", col, unisci(manc, ", "), sum(x %in% manc)))
    x[!nzchar(x) | x %in% manc] <- NA_character_
    nome_col <- col
    if (nome_col %in% c(fattori$nome, names(soggetti))) { nome_col <- paste0(col, " (soggetto)"); nt("soggetto_rinominato", col) }
    if (is.null(soggetti)) soggetti <- data.frame(row.names = gsm)
    soggetti[[nome_col]] <- x
    if (nzchar(k$subject_kind)) tipo_soggetto[nome_col] <- SOGG_V2[[k$subject_kind]] else nt("soggetto_senza_tipo", col)
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

# ---- Controllo positivo dell'adattatore (cancello K2 ii): lo studio finto GSE0 nella forma nuova -------------
# 12 campioni: malattia (sano/malato) x farmaco (veicolo/dex) e lo stadio, annidato nella malattia. E' lo
# studio finto della prova di compilazione (12-prova-compilazione.R). Attesi: 6 gruppi; farmaco contro veicolo
# dentro sano, stadio II, stadio III (3); malato contro sano con l'avviso `annidato:stage`, per ogni stadio e
# ogni livello del farmaco (4). Poi, per ogni motivo di «non chiuso», un'uscita rotta apposta da' quel motivo.
local({
  g <- sprintf("GSM%d", 1:12)
  col <- function(x) as.list(stats::setNames(x, g))
  v <- list(record_id = "GSE0", campioni = as.list(g), colonne = list("disease", "stage", "agent", "sex", "title"),
            tabella = list(disease = col(rep(c("healthy", "IBD", "IBD"), each = 4)),
                           stage = col(rep(c("", "II", "III"), each = 4)),
                           agent = col(rep(c("none", "none", "Dex", "Dex"), 3)),
                           sex = col(rep(c("F", "M", "F", "NA"), 3)),
                           title = col(sprintf("sample %d", 1:12))))
  lv <- function(l, e = "") list(level = l, text_as_written = l, entity = e, dose = "", duration = "")
  w <- function(colonna, ...) { x <- c(...); list(column = colonna, values = lapply(seq(1, length(x), 2), function(i) list(value = x[[i]], level = x[[i + 1]]))) }
  ruolo <- function(colonna, role, kind = "", manc = list()) list(column = colonna, role = role, subject_kind = kind, missing_values = manc)
  buona <- list(series_id = "GSE0",
    factors = list(
      list(name = "disease", type = "state", levels = list(lv("healthy"), lv("IBD", "inflammatory bowel disease")),
           baseline_level = "healthy", baseline_evidence = "healthy", assignment = w("disease", "healthy", "healthy", "IBD", "IBD")),
      list(name = "stage", type = "state", levels = list(lv("II"), lv("III")), baseline_level = "", baseline_evidence = "",
           assignment = w("stage", "", "not applicable", "II", "II", "III", "III")),
      list(name = "compound", type = "perturbation", levels = list(lv("vehicle"), lv("dex", "dexamethasone")),
           baseline_level = "vehicle", baseline_evidence = "none", assignment = w("agent", "none", "vehicle", "Dex", "dex"))),
    columns = list(ruolo("disease", "factor"), ruolo("stage", "factor"), ruolo("agent", "factor"),
                   ruolo("sex", "subject", "sex", list("NA")), ruolo("title", "replicate")),
    not_understood = list())
  js <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
  r <- adatta_v2(v, js(buona), FALSE, "stop")
  stopifnot(r$chiuso, r$n_gruppi == 6L, r$n_soggetti == 1L, sum(is.na(r$tabella$soggetti$sex)) == 3L,
            r$conti[["voci"]] == 7L, r$conti[["fattori_per_campione"]] == 0L, r$conti[["basi_senza_campioni"]] == 0L,
            r$conti[["livelli_non_applicabile"]] == 1L, sum(r$tabella$livelli$stage == TF_NON_APPLICABILE) == 4L)
  k <- r$confronti
  stopifnot(nrow(k) == 7L, sum(k$fattore == "compound") == 3L, sum(k$fattore == "disease") == 4L,
            all(grepl("annidato:stage", vapply(k$avvisi[k$fattore == "disease"], unisci, ""), fixed = TRUE)))
  rotta <- function(cambia) { x <- buona; x <- cambia(x); adatta_v2(v, js(x), FALSE, "stop") }
  motivo <- function(r) sub(":.*$", "", r$motivi)
  visti <- character(0)
  vede <- function(r, atteso) { stopifnot(!r$chiuso, identical(motivo(r), atteso)); visti <<- union(visti, atteso) }
  vede(adatta_v2(v, NA_character_, TRUE, NA_character_), "oltre_contesto")
  vede(adatta_v2(v, substr(js(buona), 1, 200), FALSE, "length"), c("troncata", "non_valida"))
  # un'uscita intera e valida con fine `length` resta troncata: non si misura
  vede(adatta_v2(v, js(buona), FALSE, "length"), "troncata")
  # non_valida: quello che lo schema a elenco chiuso non ammette (e che la grammatica non lascia scrivere)
  vede(rotta(function(x) { x$factors[[1]]$type <- "drug"; x }), "non_valida")
  vede(rotta(function(x) { x$factors[[1]]$assignment$column <- "diagnosis"; x }), "non_valida")          # colonna che non esiste
  vede(rotta(function(x) { x$factors[[1]]$assignment$column <- "gsm"; x }), "non_valida")                # gsm non e' ammessa
  vede(rotta(function(x) { x$factors[[2]]$assignment$values[[1]] <- NULL; x }), "non_valida")            # un valore senza voce
  vede(rotta(function(x) { x$factors[[1]]$assignment$values[[2]]$value <- "ibd"; x }), "non_valida")     # valore non letterale
  vede(rotta(function(x) { x$factors[[1]]$assignment$values <- rev(x$factors[[1]]$assignment$values); x }), "non_valida")   # ordine
  vede(rotta(function(x) { x$factors[[1]]$assignment$values[[3]] <- list(value = "IBD", level = "IBD"); x }), "non_valida") # voce in piu'
  vede(rotta(function(x) { x$factors[[3]]$assignment <- w("stage", "none", "vehicle", "Dex", "dex"); x }), "non_valida")    # valori di un'altra colonna
  vede(rotta(function(x) { x$factors[[1]]$source_columns <- list("disease"); x }), "non_valida")         # il campo della forma v1
  vede(rotta(function(x) { x$columns[[5]] <- NULL; x }), "non_valida")                                   # una colonna senza ruolo
  vede(rotta(function(x) { x$columns[[5]]$subject_kind <- "donor"; x }), "non_valida")                   # tipo di soggetto su un replicate
  vede(rotta(function(x) { x$columns[[4]]$missing_values <- list("unknown"); x }), "non_valida")         # valore mancante che la colonna non ha
  vede(rotta(function(x) { x$series_id <- "GSE1"; x }), "non_valida")
  # i motivi dell'adattatore
  vede(rotta(function(x) { x$factors[[1]]$assignment$values[[2]]$level <- "ibd"; x }), "livello_assente")
  vede(rotta(function(x) { x$factors[[1]]$baseline_level <- "control"; x }), "base_assente")
  vede(rotta(function(x) { x$factors[[2]]$type <- "context"; x$factors[[2]]$baseline_level <- "II"; x }), "base_non_ammessa")
  vede(rotta(function(x) { x$factors[[1]]$levels[[3]] <- lv(TF_NON_SCRITTO); x }), "livello_riservato")
  r <- rotta(function(x) { x$columns[[5]]$role <- "factor"; x })                                         # factor e nessun fattore la legge
  vede(r, "ruolo_incoerente"); stopifnot(grepl("nessun fattore la legge: title", r$motivi, fixed = TRUE))
  r <- rotta(function(x) { x$columns[[3]]$role <- "uninformative"; x })                                  # un fattore la legge, ruolo diverso
  vede(r, "ruolo_incoerente"); stopifnot(grepl("agent (uninformative)", r$motivi, fixed = TRUE))
  # errore di tf_tabella(): due fattori con lo stesso nome
  r <- rotta(function(x) { x$factors[[2]]$name <- "disease"; x })
  stopifnot(!r$chiuso, length(r$motivi) == 1L, grepl("^tf_tabella:", r$motivi)); visti <- union(visti, "tf_tabella")
  stopifnot(setequal(visti, c(MOTIVI_V2, "tf_tabella")))
  # che cosa NON chiude lo studio
  # `not stated` diventa TF_NON_SCRITTO; la base senza campioni si conta e il fattore resta senza base
  r <- rotta(function(x) { x$factors[[3]]$assignment$values[[1]]$level <- "not stated"; x })
  stopifnot(r$chiuso, TF_NON_SCRITTO %in% r$tabella$livelli$compound, r$conti[["basi_senza_campioni"]] == 1L,
            is.na(r$fattori$base[3]), sum(r$confronti$fattore == "compound") == 0L)
  # due fattori leggono la stessa colonna (ammesso: una colonna, due variabili)
  r <- rotta(function(x) {
    x$factors[[4]] <- list(name = "any stage", type = "state", levels = list(lv("staged"), lv("unstaged")), baseline_level = "",
                           baseline_evidence = "", assignment = w("stage", "", "unstaged", "II", "staged", "III", "staged")); x })
  stopifnot(r$chiuso, r$n_gruppi == 6L)
  # il fattore con un livello per campione si conta e non si scarta
  r <- rotta(function(x) {
    x$factors[[4]] <- list(name = "sample", type = "technical", levels = lapply(sprintf("s%d", 1:12), lv), baseline_level = "",
                           baseline_evidence = "", assignment = do.call(w, c(list("title"), as.list(rbind(sprintf("sample %d", 1:12), sprintf("s%d", 1:12))))))
    x$columns[[5]]$role <- "factor"; x })
  stopifnot(r$chiuso, r$conti[["fattori_per_campione"]] == 1L, r$n_gruppi == 12L, nrow(r$confronti) == 0L)
  r <- rotta(function(x) { x$factors <- list(); x$columns[1:3] <- lapply(c("disease", "stage", "agent"), ruolo, role = "uninformative"); x })
  stopifnot(r$chiuso, r$n_gruppi == 1L, nrow(r$confronti) == 0L)
  cat(sprintf("controllo positivo dell'adattatore v2 (cancello K2 ii): passato. Studio finto GSE0 nella forma nuova: 6 gruppi, 7 confronti, fattore annidato, valore di soggetto mancante. Motivi di non chiuso visti con un'uscita rotta apposta: %s\n",
              paste(visti, collapse = ", ")))
})
