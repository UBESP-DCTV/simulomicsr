# PROVA DA BUTTARE
# 64-adatta-e-misura.R — il lettore dello studio v0 (prova da buttare) contro la curazione di Expression Atlas,
# sui 47 studi di sviluppo. Task 10 del piano del lettore dello studio (S12r).
#
# Uso (SENZA --vanilla), solo DOPO il commit delle uscite congelate (63-uscite-sha256.txt):
#   Rscript analysis/audit/2026-11-09-lettore-studio/64-adatta-e-misura.R \
#     > analysis/audit/2026-11-09-lettore-studio/64-out.txt 2>&1
#
# Ordine: (0) controllo positivo dell'adattatore su uno studio finto; (1) le uscite congelate e P7; (2) per ogni
# studio: esiti che lo chiudono senza misura, adattatore, tf_confronti(); (3) le tre misure contro Atlas, come in
# 40-misura-oggi.R, stesso universo; (4) lettore meno oggi, appaiato; (5) token e tempi; (6) previsioni P3-P7.
#
# Regole fissate PRIMA di vedere le uscite (non si cambiano dopo):
#   - uno studio non chiuso conta come partizione non identica e zero confronti; si riporta anche la misura sui
#     soli studi chiusi;
#   - i sette esiti del piano che chiudono lo studio: oltre_contesto, non_valida, troncata, non_coperta,
#     livello_assente, base_assente, base_non_ammessa. In piu' (il piano non li nomina): colonna_ignota (una
#     colonna fonte che la vista non ha), mappa_ambigua (la stessa combinazione di valori con due livelli),
#     tf_tabella:<classe> (la tabella non passa la validazione del pacchetto). Si contano a parte;
#   - una colonna fonte puo' essere `gsm` o una colonna costante della vista: il valore e' noto, l'unione e'
#     esatta. Si conta;
#   - una base scritta fra i `levels` ma senza campioni: il fattore entra senza base (nessun confronto su quel
#     fattore in tutti e due i casi). Si conta;
#   - le voci di `assignment` con un numero di valori diverso dalle colonne fonte non si usano. Si contano.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-09-lettore-studio/aiuti-misura.R")
DIR_USCITE <- "analysis/p4-output/S12r-lettore-v0"
NON_STATED <- "not stated"
TIPI <- c(perturbation = "perturbazione", state = "stato", context = "contesto", time = "tempo", technical = "tecnico")
SOGG <- c(donor = "donatore", sex = "sesso", age = "eta", passage = "passaggio", batch = "lotto", pair = "coppia")
MOTIVI_PIANO <- c("oltre_contesto", "non_valida", "troncata", "non_coperta", "livello_assente", "base_assente",
                  "base_non_ammessa")
SEP <- "\x1f"
stopifnot(setequal(unname(TIPI), TF_TIPI), setequal(unname(SOGG), TF_SOGGETTI))
validatore <- compile_schema(file.path(A, "61-schema-v0.json"))
scrivi_csv <- function(d, f) utils::write.csv(d, file.path(A, f), row.names = FALSE, na = "")
unisci <- function(x, sep = " | ") paste(x, collapse = sep)
car <- function(x) if (is.null(x)) character(0) else as.character(unlist(x))

# ---- L'adattatore: dall'uscita del modello e dalla vista alla tabella dei fattori del pacchetto ------------
# Ritorna: chiuso, motivi (nome: dettaglio), note, e se chiuso tabella, confronti, registro, fattori.
adatta <- function(v, raw, saltato, fine) {
  motivi <- character(0); note <- character(0)
  agg <- function(m, d = "") motivi <<- c(motivi, if (nzchar(d)) paste0(m, ": ", d) else m)
  nt <- function(m, d = "") note <<- c(note, if (nzchar(d)) paste0(m, ": ", d) else m)
  esce <- function() list(chiuso = FALSE, motivi = motivi, note = note)
  if (isTRUE(saltato)) { agg("oltre_contesto"); return(esce()) }
  if (identical(fine, "length")) agg("troncata")
  val <- if (is.na(raw) || !nzchar(raw)) list(valid = FALSE, errors = "uscita vuota") else
    tryCatch(validate_json(raw, validatore), error = function(e) list(valid = FALSE, errors = conditionMessage(e)))
  if (!isTRUE(val$valid)) { agg("non_valida", unisci(utils::head(val$errors, 3L))); return(esce()) }
  u <- jsonlite::fromJSON(raw, simplifyVector = FALSE)
  gsm <- car(v$campioni)
  if (!identical(u$series_id, v$record_id)) nt("series_id_diverso", u$series_id)
  valori <- function(col) {
    if (col == "gsm") return(gsm)
    if (col %in% names(v$tabella)) return(vapply(gsm, function(g) v$tabella[[col]][[g]], "", USE.NAMES = FALSE))
    rep(v$costanti[[col]], length(gsm))
  }
  colonne_note <- c("gsm", names(v$tabella), names(v$costanti))

  nf <- length(u$factors)
  livelli <- data.frame(row.names = gsm)
  fattori <- data.frame(nome = character(nf), tipo = character(nf), base = rep(NA_character_, nf),
                        fonti = character(nf), livelli_scritti = character(nf), stringsAsFactors = FALSE)
  for (i in seq_len(nf)) {
    f <- u$factors[[i]]
    nome <- f$name; fonti <- car(f$source_columns)
    liv <- unique(vapply(f$levels, function(l) l$level, ""))
    fattori$nome[i] <- nome; fattori$tipo[i] <- TIPI[[f$type]]
    fattori$fonti[i] <- unisci(fonti); fattori$livelli_scritti[i] <- unisci(liv)
    if (TF_NON_SCRITTO %in% liv) agg("livello_riservato", nome)
    ignote <- setdiff(fonti, colonne_note)
    if (length(ignote)) { agg("colonna_ignota", sprintf("%s <- %s", nome, unisci(ignote, ", "))); next }
    if ("gsm" %in% fonti) nt("fonte_gsm", nome)
    if (any(fonti %in% names(v$costanti))) nt("fonte_costante", sprintf("%s <- %s", nome, unisci(intersect(fonti, names(v$costanti)), ", ")))
    m <- lapply(fonti, valori)
    stopifnot(!any(grepl(SEP, unlist(m), fixed = TRUE)))
    k_camp <- if (length(m)) do.call(paste, c(m, sep = SEP)) else rep("", length(gsm))
    k_voce <- vapply(f$assignment, function(a) {
      x <- car(a$values); if (length(x) != length(fonti)) NA_character_ else paste(x, collapse = SEP)
    }, "")
    l_voce <- vapply(f$assignment, function(a) a$level, "")
    if (anyNA(k_voce)) nt("voci_malformate", sprintf("%s: %d", nome, sum(is.na(k_voce))))
    buone <- !is.na(k_voce)
    assenti <- setdiff(l_voce, c(liv, NON_STATED))
    if (length(assenti)) agg("livello_assente", sprintf("%s: %s", nome, unisci(assenti, ", ")))
    doppie <- tapply(l_voce[buone], k_voce[buone], function(x) length(unique(x)))
    if (any(doppie > 1L)) agg("mappa_ambigua", sprintf("%s: %d combinazioni", nome, sum(doppie > 1L)))
    scoperte <- !(k_camp %in% k_voce[buone])
    if (any(scoperte)) agg("non_coperta", sprintf("%s: %d combinazioni, %d campioni, per esempio «%s»", nome,
                                                   length(unique(k_camp[scoperte])), sum(scoperte),
                                                   gsub(SEP, " + ", k_camp[scoperte][1], fixed = TRUE)))
    in_piu <- sum(!(unique(k_voce[buone]) %in% k_camp))
    if (in_piu) nt("voci_in_piu", sprintf("%s: %d", nome, in_piu))
    b <- f$baseline_level
    if (nzchar(b)) {
      if (!(f$type %in% c("perturbation", "state"))) agg("base_non_ammessa", sprintf("%s (%s): %s", nome, f$type, b))
      if (!(b %in% liv)) agg("base_assente", sprintf("%s: %s", nome, b))
    }
    lv <- l_voce[buone][match(k_camp, k_voce[buone])]
    lv[lv %in% NON_STATED] <- TF_NON_SCRITTO
    if (nzchar(b) && (b %in% liv)) {
      if (b %in% lv) fattori$base[i] <- b else nt("base_senza_campioni", sprintf("%s: %s", nome, b))
    }
    if (!length(motivi)) livelli[[nome]] <- lv
  }
  if (length(motivi)) return(esce())

  # soggetti: le colonne di ruolo `subject`
  sog <- Filter(function(k) identical(k$role, "subject"), u$columns)
  soggetti <- NULL; tipo_soggetto <- NULL
  tutte_fonti <- unique(unlist(lapply(u$factors, function(f) car(f$source_columns))))
  scritte <- vapply(u$columns, function(k) k$column, "")
  if (length(setdiff(names(v$tabella), scritte))) nt("colonne_senza_ruolo", unisci(setdiff(names(v$tabella), scritte), ", "))
  if (length(setdiff(scritte, names(v$tabella)))) nt("ruolo_a_colonna_ignota", unisci(setdiff(scritte, names(v$tabella)), ", "))
  for (k in sog) {
    col <- k$column
    if (!(col %in% names(v$tabella))) { nt("soggetto_colonna_ignota", col); next }
    if (col %in% tutte_fonti) nt("colonna_soggetto_e_fonte", col)
    x <- valori(col); x[!nzchar(x)] <- NA_character_
    nome_col <- col
    if (nome_col %in% c(fattori$nome, names(soggetti))) { nome_col <- paste0(col, " (soggetto)"); nt("soggetto_rinominato", col) }
    if (is.null(soggetti)) soggetti <- data.frame(row.names = gsm)
    soggetti[[nome_col]] <- x
    if (nzchar(k$subject_kind)) tipo_soggetto[nome_col] <- SOGG[[k$subject_kind]]
  }
  tab <- tryCatch(tf_tabella(gsm, livelli, fattori[c("nome", "tipo", "base")], soggetti, tipo_soggetto),
                  error = function(e) e)
  if (inherits(tab, "error")) {
    agg(paste0("tf_tabella:", sub("^simulomicsr_tf_", "", class(tab)[1])), conditionMessage(tab)); return(esce())
  }
  kk <- tf_confronti(tab, n_min = 2L)
  gr <- tf_gruppi(tab)
  partizione <- stats::setNames(rep(gr$gruppo, lengths(gr$campioni)), unlist(gr$campioni))
  stopifnot(setequal(names(partizione), gsm))
  list(chiuso = TRUE, motivi = motivi, note = note, tabella = tab, confronti = kk$confronti, registro = kk$registro,
       partizione = partizione, fattori = fattori, n_soggetti = length(tipo_soggetto), n_gruppi = nrow(gr))
}

confronti_comuni <- function(studio, k) {
  out <- data.frame(studio = rep(studio, nrow(k)), id = as.character(k$id), stringsAsFactors = FALSE)
  out$trattato <- unname(k$trattato); out$controllo <- unname(k$controllo)
  out
}
CONFRONTI_VUOTI <- function(studio) tf_da_stage2(list(series_id = studio))$confronti

# ---- (0) Controllo positivo dell'adattatore: uno studio finto ----------------------------------------------
local({
  g <- sprintf("GSM%d", 1:8)
  v <- list(record_id = "GSE0", campioni = as.list(g),
            tabella = list(treatment = as.list(stats::setNames(rep(c("Untreated", "Dex"), 4), g)),
                           `cell line` = as.list(stats::setNames(rep(c("A", "B"), each = 4), g)),
                           donor = as.list(stats::setNames(rep(c("d1", "d1", "d2", "d2"), 2), g))),
            costanti = list(tissue = "airway"))
  buona <- list(series_id = "GSE0",
    columns = list(list(column = "treatment", role = "factor", subject_kind = ""),
                   list(column = "cell line", role = "factor", subject_kind = ""),
                   list(column = "donor", role = "subject", subject_kind = "donor")),
    factors = list(
      list(name = "compound", type = "perturbation", source_columns = list("treatment"),
           levels = list(list(level = "dex", text_as_written = "Dex", entity = "dexamethasone", dose = "", duration = ""),
                         list(level = "none", text_as_written = "Untreated", entity = "", dose = "", duration = "")),
           baseline_level = "none", baseline_evidence = "Untreated",
           assignment = list(list(values = list("Untreated"), level = "none"), list(values = list("Dex"), level = "dex"))),
      list(name = "line", type = "context", source_columns = list("cell line"),
           levels = list(list(level = "A", text_as_written = "A", entity = "", dose = "", duration = ""),
                         list(level = "B", text_as_written = "B", entity = "", dose = "", duration = "")),
           baseline_level = "", baseline_evidence = "",
           assignment = list(list(values = list("A"), level = "A"), list(values = list("B"), level = "B")))),
    not_understood = list())
  js <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
  r <- adatta(v, js(buona), FALSE, "stop")
  stopifnot(r$chiuso, r$n_gruppi == 4L, nrow(r$confronti) == 2L, all(r$confronti$fattore == "compound"),
            all(r$confronti$livello_base == "none"), r$n_soggetti == 1L)
  # i sette esiti del piano, uno per volta
  rotta <- function(cambia) { x <- buona; x <- cambia(x); adatta(v, js(x), FALSE, "stop") }
  motivo <- function(r) sub(":.*$", "", r$motivi)
  stopifnot(identical(motivo(adatta(v, NA_character_, TRUE, NA_character_)), "oltre_contesto"))
  stopifnot(identical(motivo(adatta(v, substr(js(buona), 1, 200), FALSE, "length")), c("troncata", "non_valida")))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$type <- "drug"; x })), "non_valida"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$assignment[[2]] <- NULL; x })), "non_coperta"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$assignment[[2]]$values <- list("dex"); x })), "non_coperta"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$assignment[[2]]$level <- "DEX"; x })), "livello_assente"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$baseline_level <- "vehicle"; x })), "base_assente"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[2]]$baseline_level <- "A"; x })), "base_non_ammessa"))
  stopifnot(identical(motivo(rotta(function(x) { x$factors[[1]]$source_columns <- list("drug"); x })), "colonna_ignota"))
  # `not stated` diventa TF_NON_SCRITTO e non chiude lo studio; fonte costante e nessun fattore non chiudono
  r <- rotta(function(x) { x$factors[[1]]$assignment[[2]]$level <- NON_STATED; x })
  stopifnot(r$chiuso, TF_NON_SCRITTO %in% r$tabella$livelli$compound)
  r <- rotta(function(x) { x$factors <- list(); x })
  stopifnot(r$chiuso, r$n_gruppi == 1L, nrow(r$confronti) == 0L)
  cat("controllo positivo dell'adattatore: passato (studio finto: 4 gruppi, 2 confronti; 8 esiti che chiudono visti)\n")
})

# ---- (1) Le uscite congelate ------------------------------------------------------------------------------
imp <- readLines(file.path(A, "63-uscite-sha256.txt"))
imp <- data.frame(sha = sub("  .*$", "", imp), file = sub("^[0-9a-f]+  ", "", imp), stringsAsFactors = FALSE)
ora <- vapply(imp$file, function(f) unname(digest::digest(file = f, algo = "sha256")), "")
stopifnot(all(ora == imp$sha), all(file.path(DIR_USCITE, c("corsa1.jsonl", "corsa2.jsonl")) %in% imp$file))
cat("uscite congelate:", nrow(imp), "file, impronte uguali a 63-uscite-sha256.txt\n")
committato <- system2("git", c("ls-files", "--error-unmatch", file.path(A, "63-uscite-sha256.txt")), stdout = TRUE, stderr = TRUE)
stopifnot(is.null(attr(committato, "status")))
cat("63-uscite-sha256.txt e' tracciato da git (le uscite sono congelate prima della misura)\n")

sv <- studi_di_sviluppo()
leggi_jsonl <- function(f) lapply(readLines(f, encoding = "UTF-8"), jsonlite::fromJSON, simplifyVector = FALSE)
viste <- leggi_jsonl(file.path(A, "60-viste-v0.jsonl"))
names(viste) <- vapply(viste, `[[`, "", "record_id")
stopifnot(setequal(names(viste), sv$gse))
corsa <- function(n) {
  x <- leggi_jsonl(file.path(DIR_USCITE, sprintf("corsa%d.jsonl", n)))
  names(x) <- vapply(x, `[[`, "", "record_id"); stopifnot(setequal(names(x), sv$gse), !anyDuplicated(names(x)))
  x[sv$gse]
}
c1 <- corsa(1L); c2 <- corsa(2L)
nullo <- function(x) if (is.null(x)) NA else x
raw1 <- vapply(c1, function(x) as.character(nullo(x$raw)), ""); raw2 <- vapply(c2, function(x) as.character(nullo(x$raw)), "")
salt1 <- vapply(c1, function(x) isTRUE(x$saltato), TRUE); salt2 <- vapply(c2, function(x) isTRUE(x$saltato), TRUE)
uguali <- (salt1 == salt2) & ((is.na(raw1) & is.na(raw2)) | (!is.na(raw1) & !is.na(raw2) & raw1 == raw2))
cat("\n== P7: uscite identiche al carattere fra le due corse ==\n")
cat("identiche:", sum(uguali), "su", length(uguali), "\n")
if (any(!uguali)) cat("diverse:", unisci(names(uguali)[!uguali], ", "), "\n")

# ---- (2) Adattatore e costruttore, studio per studio ---------------------------------------------------------
rif <- atlas_di_sviluppo(sv)
stopifnot(identical(names(rif), sv$gse))
lett <- lapply(sv$gse, function(g) adatta(viste[[g]], raw1[[g]], salt1[[g]], nullo(c1[[g]]$fine)))
names(lett) <- sv$gse
chiuso <- vapply(lett, `[[`, TRUE, "chiuso")
nomi_motivi <- lapply(lett, function(r) unique(sub(":.*$", "", r$motivi)))
cat("\n== Esiti che chiudono lo studio senza misura ==\n")
cat("studi chiusi dal lettore:", sum(chiuso), "su", length(chiuso), "; non chiusi:", sum(!chiuso), "\n")
cat("studi per esito (uno studio puo' avere piu' esiti):\n")
print(table(factor(unlist(nomi_motivi), levels = union(MOTIVI_PIANO, unique(unlist(nomi_motivi))))))
solo_piano <- vapply(nomi_motivi, function(m) any(m %in% MOTIVI_PIANO), TRUE)
cat("non chiusi per uno dei sette esiti del piano:", sum(solo_piano), "; solo per un altro esito:", sum(!chiuso & !solo_piano), "\n")
for (g in names(lett)[!chiuso]) cat(sprintf("  %s: %s\n", g, substr(unisci(lett[[g]]$motivi, " || "), 1L, 600L)))
cat("note dell'adattatore (studi per nota):\n")
print(table(unlist(lapply(lett, function(r) unique(sub(":.*$", "", r$note))))))
# lo studio e' nell'universo di Atlas solo con i suoi campioni: la vista deve coprirli
fuori_vista <- vapply(sv$gse, function(g) sum(!(rif[[g]]$universo %in% car(viste[[g]]$campioni))), 0L)
cat("campioni dell'universo di Atlas assenti dalla vista:", sum(fuori_vista), "in", sum(fuori_vista > 0L), "studi\n")

registro <- do.call(rbind, lapply(names(lett)[chiuso], function(g) {
  r <- lett[[g]]$registro; if (!nrow(r)) return(NULL)
  data.frame(studio = g, gruppo_a = r$gruppo_a, gruppo_b = r$gruppo_b, motivo = r$motivo, dettaglio = r$dettaglio,
             stringsAsFactors = FALSE)
}))
scrivi_csv(registro, "64-registro-coppie.csv")
cat("\n== Il costruttore: coppie di gruppi che non diventano un confronto (64-registro-coppie.csv) ==\n")
print(table(registro$motivo))

piatto <- function(x) vapply(x, function(e) {
  if (!length(e)) return("")
  if (!is.null(names(e))) unisci(sprintf("%s=%s", names(e), unlist(e)), "; ") else unisci(unlist(e), "; ")
}, "")
conf_lett <- do.call(rbind, lapply(names(lett)[chiuso], function(g) {
  k <- lett[[g]]$confronti; if (!nrow(k)) return(NULL)
  data.frame(studio = g, id = k$id, fattore = k$fattore, tipo_fattore = k$tipo_fattore,
             livello_trattato = k$livello_trattato, livello_base = k$livello_base,
             n_trattato = lengths(k$trattato), n_controllo = lengths(k$controllo), esito = k$esito,
             avvisi = piatto(k$avvisi), contesto = piatto(k$contesto), stringsAsFactors = FALSE)
}))
scrivi_csv(conf_lett, "64-confronti-lettore.csv")
fatt_lett <- do.call(rbind, lapply(names(lett)[chiuso], function(g) {
  f <- lett[[g]]$fattori; if (!nrow(f)) return(NULL)
  cbind(studio = g, f, livelli_nei_campioni = vapply(f$nome, function(n) unisci(sort(unique(lett[[g]]$tabella$livelli[[n]]))), ""),
        stringsAsFactors = FALSE)
}))
scrivi_csv(fatt_lett, "64-fattori-lettore.csv")
cat("\n== Confronti del lettore (n_min = 2) ==\n")
cat("confronti:", nrow(conf_lett), "in", length(unique(conf_lett$studio)), "studi; studi chiusi senza confronti:",
    sum(chiuso) - length(unique(conf_lett$studio)), "\n")
print(table(esito = conf_lett$esito))
cat("avvisi per tipo (un confronto puo' averne piu' di uno):\n")
print(table(sub(":.*$", "", unlist(strsplit(conf_lett$avvisi[nzchar(conf_lett$avvisi)], "; ", fixed = TRUE)))))
cat("tipo del fattore che cambia:\n"); print(table(conf_lett$tipo_fattore))

# ---- (3) Le tre misure contro Atlas ------------------------------------------------------------------------
mm <- lapply(sv$gse, function(g) {
  x <- rif[[g]]; r <- lett[[g]]
  if (r$chiuso) {
    m <- tf_misura_studio(g, r$partizione, confronti_comuni(g, r$confronti), x$atlas, x$universo)
    m$riga$n_gruppi_lettore <- length(unique(r$partizione[names(r$partizione) %in% x$universo]))
  } else {
    m <- tf_misura_studio(g, character(0), CONFRONTI_VUOTI(g), x$atlas, x$universo)
    m$riga$classe_gruppi <- "non_chiuso"; m$riga$n_gruppi_lettore <- 0L
  }
  m$riga$accession <- x$accession; m$riga$chiuso <- r$chiuso
  m$riga$n_gruppi_atlas <- length(unique(x$atlas$partizione[names(x$atlas$partizione) %in% x$universo]))
  m
})
names(mm) <- sv$gse
per_studio <- do.call(rbind, lapply(mm, `[[`, "riga"))
stopifnot(nrow(per_studio) == 47L, identical(per_studio$studio, sv$gse))
at <- do.call(rbind, lapply(mm, function(m) {
  k <- m$atlas
  data.frame(studio = k$studio, id = k$id, nome = k$nome, n_trattato = lengths(k$trattato),
             n_controllo = lengths(k$controllo), classe = k$classe, fattori_diversi = k$fattori_diversi,
             fattori_non_scritti = k$fattori_non_scritti, ritrovato = k$ritrovato, stringsAsFactors = FALSE)
}))
ne <- do.call(rbind, lapply(mm, function(m) {
  k <- m$non_elencati
  data.frame(studio = k$studio, id = k$id, n_trattato = lengths(k$trattato), n_controllo = lengths(k$controllo),
             giudizio = k$giudizio, stringsAsFactors = FALSE)
}))
ne <- merge(ne, conf_lett[c("studio", "id", "fattore", "tipo_fattore", "livello_trattato", "livello_base", "esito", "avvisi")],
            by = c("studio", "id"), all.x = TRUE, sort = FALSE)
stopifnot(!anyNA(ne$fattore))
misure <- tf_riassumi_misure(per_studio, B = B, seme = SEME)
misure_chiusi <- tf_riassumi_misure(per_studio[per_studio$chiuso, ], B = B, seme = SEME)

oggi <- utils::read.csv(file.path(A, "40-per-studio-oggi.csv"), stringsAsFactors = FALSE)
oggi <- oggi[match(sv$gse, oggi$studio), ]
stopifnot(identical(oggi$studio, per_studio$studio), all(oggi$n_universo == per_studio$n_universo),
          all(oggi$n_atlas == per_studio$n_atlas), all(oggi$n_rispetta == per_studio$n_rispetta),
          all(oggi$n_piu_fattori == per_studio$n_piu_fattori))
misure_oggi <- tf_riassumi_misure(oggi, B = B, seme = SEME)
misure_oggi_chiusi <- tf_riassumi_misure(oggi[per_studio$chiuso, ], B = B, seme = SEME)
m40 <- utils::read.csv(file.path(A, "40-misure-oggi.csv"), stringsAsFactors = FALSE)
m40 <- m40[m40$variante == "principale", ]
stopifnot(isTRUE(all.equal(m40$quota, misure_oggi$quota)), isTRUE(all.equal(m40$ic_basso, misure_oggi$ic_basso)))
cat("\nla misura di oggi riletta da 40-per-studio-oggi.csv ridà i numeri di 40-misure-oggi.csv\n")

cat("\n== Lettore v0 contro Atlas, 47 studi (uno studio non chiuso: partizione non identica, zero confronti) ==\n")
cat("(a) classi della partizione del lettore contro Atlas:\n"); print(table(per_studio$classe_gruppi, useNA = "ifany"))
cat("    oggi sugli stessi studi:\n"); print(table(lettore = per_studio$classe_gruppi, oggi = oggi$classe_gruppi, useNA = "ifany"))
cat("campioni dell'universo:", sum(per_studio$n_universo), " comuni:", sum(per_studio$n_comuni),
    " solo in Atlas:", sum(per_studio$solo_atlas), "\n")
cat("gruppi nell'universo: lettore", sum(per_studio$n_gruppi_lettore), " Atlas", sum(per_studio$n_gruppi_atlas), "\n")
cat("(b) classi dei confronti di Atlas:\n"); print(table(at$classe, useNA = "ifany"))
cat("    ritrovati, fra quelli che rispettano la definizione:\n")
print(table(at$ritrovato[at$classe == "rispetta"], useNA = "ifany"))
cat("    studi con almeno un confronto di Atlas ritrovato:", sum(per_studio$n_rispetta_uguale > 0L), "su",
    sum(per_studio$n_rispetta > 0L), "che ne hanno\n")
cat("    confronti di Atlas con piu' fattori formati anche dal lettore:", sum(per_studio$n_piu_fattori_formati), "su",
    sum(per_studio$n_piu_fattori), "\n")
cat("(c) confronti del lettore:", sum(per_studio$n_nostri), " non elencati da Atlas:", sum(per_studio$n_non_elencati), "\n")
print(table(ne$giudizio, useNA = "ifany"))
cat("    non elencati per giudizio e avviso:\n"); print(table(giudizio = ne$giudizio, esito = ne$esito))
cat("misure del lettore, 47 studi:\n"); print(misure, row.names = FALSE, digits = 4)
cat("misure di oggi, 47 studi (dal Task 8):\n"); print(misure_oggi, row.names = FALSE, digits = 4)
cat(sprintf("\n== Soli studi chiusi dal lettore (%d) ==\n", sum(chiuso)))
cat("lettore:\n"); print(misure_chiusi, row.names = FALSE, digits = 4)
cat("oggi, sugli stessi studi:\n"); print(misure_oggi_chiusi, row.names = FALSE, digits = 4)

# ---- (4) Lettore meno oggi, appaiato: bootstrap sugli studi, stesse estrazioni per i due metodi -----------
appaiato <- function(L, O) {
  n <- nrow(L); stopifnot(identical(L$studio, O$studio))
  set.seed(SEME); estr <- matrix(sample.int(n, n * B, replace = TRUE), nrow = B)
  q <- function(num, den, idx) if (sum(den[idx]) > 0) sum(num[idx]) / sum(den[idx]) else NA_real_
  una <- function(nome, numL, denL, numO, denO) {
    v <- apply(estr, 1L, function(idx) q(numL, denL, idx) - q(numO, denO, idx))
    ic <- unname(stats::quantile(v, c(0.025, 0.975), na.rm = TRUE, names = FALSE))
    data.frame(misura = nome, lettore = q(numL, denL, seq_len(n)), oggi = q(numO, denO, seq_len(n)),
               differenza = q(numL, denL, seq_len(n)) - q(numO, denO, seq_len(n)), ic_basso = ic[1], ic_alto = ic[2],
               ricampioni_senza_valore = sum(is.na(v)), stringsAsFactors = FALSE)
  }
  id <- function(d) as.numeric(d$classe_gruppi %in% "identica")
  rbind(una("a_gruppi_identici", id(L), rep(1, n), id(O), rep(1, n)),
        una("b_confronti_ritrovati", L$n_rispetta_uguale, L$n_rispetta, O$n_rispetta_uguale, O$n_rispetta),
        una("c_errori_non_elencati", L$n_errori, L$n_giudicabili, O$n_errori, O$n_giudicabili))
}
diff47 <- appaiato(per_studio, oggi)
diff_chiusi <- appaiato(per_studio[per_studio$chiuso, ], oggi[per_studio$chiuso, ])
cat("\n== Lettore meno oggi, appaiato sugli studi (B =", B, ", seme", SEME, ") ==\n47 studi:\n")
print(diff47, row.names = FALSE, digits = 4)
cat("soli studi chiusi:\n"); print(diff_chiusi, row.names = FALSE, digits = 4)
cat("studi dove (b) migliora / resta / peggiora (numero di confronti ritrovati):",
    sum(per_studio$n_rispetta_uguale > oggi$n_rispetta_uguale), "/",
    sum(per_studio$n_rispetta_uguale == oggi$n_rispetta_uguale), "/",
    sum(per_studio$n_rispetta_uguale < oggi$n_rispetta_uguale), "\n")

# ---- (5) Token e tempi --------------------------------------------------------------------------------------
num <- function(x, campo) vapply(x, function(r) as.numeric(nullo(r[[campo]])), 0)
tok <- data.frame(studio = sv$gse, n_prompt = num(c1, "n_prompt"), n_prompt_vllm = num(c1, "n_prompt_vllm"),
                  n_out = num(c1, "n_out"), fine = vapply(c1, function(r) as.character(nullo(r$fine)), ""),
                  stringsAsFactors = FALSE)
cat("\n== Token veri (corsa 1) ==\n")
cat("prompt, contati da vLLM: "); print(summary(tok$n_prompt_vllm))
cat("uscita: "); print(summary(tok$n_out))
cat("totale prompt", sum(tok$n_prompt_vllm, na.rm = TRUE), " totale uscita", sum(tok$n_out, na.rm = TRUE), "\n")
cat("fine della generazione:\n"); print(table(tok$fine, useNA = "ifany"))
log63 <- readLines(file.path(A, "63-out.txt"))
gen <- grep("generazione completata", log63, value = TRUE)
sec <- as.numeric(sub("^.*completata in ([0-9.]+) ?s.*$", "\\1", gen)); nrec <- as.numeric(sub("^.*\\(([0-9]+) record\\).*$", "\\1", gen))
di_corsa <- sub("^.*(corsa[12]).*$", "\\1", gen)
cat("\n== Tempo di generazione (dal log del job; il runner non registra il tempo per studio) ==\n")
for (k in unique(di_corsa)) {
  i <- di_corsa == k
  cat(sprintf("%s: %d worker, %d studi, secondi per worker %s; il piu' lento %.0f s; secondi-GPU per studio %.1f\n", k, sum(i),
              sum(nrec[i]), unisci(sprintf("%.0f", sec[i]), ", "), max(sec[i]), sum(sec[i]) / sum(nrec[i])))
}

# ---- Tabelle ------------------------------------------------------------------------------------------------
per_studio$motivi <- vapply(lett, function(r) unisci(r$motivi, " || "), "")
per_studio$note <- vapply(lett, function(r) unisci(r$note, " || "), "")
per_studio$n_confronti_con_avviso <- vapply(sv$gse, function(g) sum(conf_lett$studio == g & conf_lett$esito == "confronto con avviso"), 0L)
per_studio$n_fattori <- vapply(lett, function(r) if (r$chiuso) nrow(r$fattori) else NA_integer_, 0L)
per_studio$n_soggetti <- vapply(lett, function(r) if (r$chiuso) as.integer(r$n_soggetti) else NA_integer_, 0L)
per_studio <- cbind(per_studio, tok[c("n_prompt_vllm", "n_out", "fine")], uguale_fra_le_corse = unname(uguali))
scrivi_csv(per_studio, "64-per-studio-lettore.csv")
scrivi_csv(rbind(cbind(insieme = "47 studi", metodo = "lettore", misure), cbind(insieme = "47 studi", metodo = "oggi", misure_oggi),
                 cbind(insieme = "studi chiusi", metodo = "lettore", misure_chiusi),
                 cbind(insieme = "studi chiusi", metodo = "oggi", misure_oggi_chiusi)), "64-misure-lettore.csv")
scrivi_csv(rbind(cbind(insieme = "47 studi", diff47), cbind(insieme = "studi chiusi", diff_chiusi)), "64-lettore-meno-oggi.csv")
scrivi_csv(at, "64-confronti-atlas-lettore.csv")
scrivi_csv(ne, "64-non-elencati-lettore.csv")

# ---- (6) Le previsioni ---------------------------------------------------------------------------------------
cat("\n== Previsioni (47 studi; bootstrap sugli studi, B =", B, ", seme", SEME, ") ==\n")
d <- diff47[diff47$misura == "b_confronti_ritrovati", ]
cat(sprintf("P3  lettore meno oggi su (b): %+.1f punti (IC95 %+.1f, %+.1f); atteso +30, rilevanza: IC95 sopra 0  ->  %s\n",
            100 * d$differenza, 100 * d$ic_basso, 100 * d$ic_alto,
            if (d$ic_basso > 0) "confermata" else if (d$ic_alto <= 0) "smentita" else "indeterminata"))
prev <- function(codice, m, misura, basso, alto, atteso) {
  r <- m[m$misura == misura, ]
  cat(sprintf("%s  %s  atteso %s, rilevanza %.0f-%.0f%%  ->  %s\n", codice, riga_misura(m, misura), atteso,
              100 * basso, 100 * alto, giudica(r$ic_basso, r$ic_alto, basso, alto)))
}
prev("P4", misure, "a_gruppi_identici", 0.50, 0.80, "65%")
prev("P5 lettore", misure, "c_errori_non_elencati", 0.00, 0.10, "5%")
prev("P5 oggi   ", misure_oggi, "c_errori_non_elencati", 0.15, 0.35, "25%")
cat(sprintf("P6  studi non chiusi: %d su 47 (per i sette esiti del piano: %d); atteso 4, rilevanza 0-7  ->  %s\n",
            sum(!chiuso), sum(solo_piano), if (sum(!chiuso) <= 7L) "confermata" else "smentita"))
cat(sprintf("P7  uscite identiche fra le due corse: %d su 47; atteso 47, rilevanza 47  ->  %s\n", sum(uguali),
            if (sum(uguali) == 47L) "confermata" else "smentita"))
cat("\nRegola di esito, le tre condizioni misurabili:\n")
for (i in seq_len(nrow(diff47))) cat(sprintf("  %s: lettore %.1f%%, oggi %.1f%%, differenza %+.1f punti (IC95 %+.1f, %+.1f)\n",
                                             diff47$misura[i], 100 * diff47$lettore[i], 100 * diff47$oggi[i],
                                             100 * diff47$differenza[i], 100 * diff47$ic_basso[i], 100 * diff47$ic_alto[i]))
cat("FINITO\n")
