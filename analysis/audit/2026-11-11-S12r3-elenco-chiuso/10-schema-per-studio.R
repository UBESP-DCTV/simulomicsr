# PROVA DA BUTTARE
# 10-schema-per-studio.R — il generatore dello schema delle uscite v2 (S12r3, ADR-0029): un programma scrive,
# per ogni studio, la forma JSON dell'uscita del lettore dalla tabella dei campioni della vista. Colonne e
# valori sono a elenco chiuso; ogni valore distinto della colonna scelta ha la sua voce, in ordine fisso.
# Il modello decide ancora fattori, tipi, livelli, livello di base e il livello di ogni valore.
# Non sta in inst/schemas/ e non entra nel pacchetto.
#
# Uso: `source()` (definisce `schema_studio()` e `valori_colonna()`), oppure da solo per la misura senza modello:
#   Rscript analysis/audit/2026-11-11-S12r3-elenco-chiuso/10-schema-per-studio.R
# Scrive 11-grandezza-schema.csv (una riga per studio di sviluppo). Non usa `--vanilla`.
#
# Regole di generazione (spec par. 5.2, aggiornamento 2026-11-11):
#   - colonne ammesse: le colonne NON costanti della vista (`v$colonne`), nell'ordine della vista. `gsm` e le
#     colonne costanti non sono ammesse: non dividono i campioni;
#   - valori di una colonna: i valori distinti fra i campioni dello studio, nell'ordine in cui compaiono nella
#     tabella (ordine dei campioni della vista). La cella vuota e' il valore "" e ha la sua voce;
#   - un fattore legge UNA colonna (`assignment.column`) e da' un livello a OGNI valore distinto di quella colonna
#     (`assignment.values`: una tupla a lunghezza fissa, una voce per valore, nello stesso ordine);
#   - `columns`: una tupla a lunghezza fissa, una voce per ogni colonna ammessa, nell'ordine della vista. Il ruolo
#     `factor` dice che la colonna e' la fonte di un fattore; `missing_values` ammette solo valori di quella
#     colonna, al massimo tanti quanti sono. (Prima forma, 2026-11-11: `other_columns` era una lista aperta con il
#     nome a elenco chiuso; nel controllo del vincolo il modello ha ripetuto le stesse colonne fino a max_tokens.
#     Una lista che la tabella dei campioni determina si scrive come tupla: 12-out.txt);
#   - `subject_kind` e `missing_values` sono legati al ruolo (forma 3): solo una colonna di ruolo `subject` li
#     compila; per gli altri ruoli sono "" e la lista vuota. E' la regola del prompt v1 («For every role other than
#     subject, subject_kind is the empty string»), scritta nello schema. (Forma 2: erano liberi; col messaggio
#     neutro il modello ha scritto `uninformative` + `sex` e ha riempito `missing_values` con i titoli: 12-out.txt.
#     Nelle uscite di S12r2 nessuna colonna non `subject` porta un tipo o un valore mancante: 0 su 99);
#   - nessun taglio: uno schema grande resta intero. Se ingresso + max_tokens supera il contesto, lo studio non va
#     al modello (motivo `oltre_contesto`); se l'uscita si ferma a max_tokens il motivo e' `troncata`.
TIPI_USCITA <- c("perturbation", "state", "context", "time", "technical")
RUOLI_USCITA <- c("factor", "subject", "replicate", "uninformative")
SOGGETTI_USCITA <- c("donor", "sex", "age", "passage", "batch", "pair", "")

valori_colonna <- function(v, col) {
  gsm <- as.character(unlist(v$campioni))
  x <- vapply(gsm, function(g) { y <- v$tabella[[col]][[g]]; if (is.null(y) || is.na(y)) "" else as.character(y) }, "",
              USE.NAMES = FALSE)
  unique(x)
}

schema_studio <- function(v) {
  colonne <- as.character(unlist(v$colonne))
  stopifnot(length(colonne) > 0L, !anyDuplicated(colonne), all(colonne %in% names(v$tabella)), !("gsm" %in% colonne))
  s <- function(d) list(type = "string", description = d)
  ogg <- function(req, prop) list(type = "object", additionalProperties = FALSE, required = as.list(req), properties = prop)
  voce <- function(val) ogg(c("value", "level"), list(value = list(const = val), level = list(type = "string")))
  ramo_fattore <- function(col) {
    vv <- valori_colonna(v, col)
    ogg(c("column", "values"), list(
      column = list(const = col),
      values = list(type = "array", prefixItems = lapply(vv, voce), items = FALSE,
                    minItems = length(vv), maxItems = length(vv))))
  }
  ramo_altra <- function(col) {
    vv <- valori_colonna(v, col)
    campi <- c("column", "role", "subject_kind", "missing_values")
    list(anyOf = list(
      ogg(campi, list(column = list(const = col),
                      role = list(type = "string", enum = as.list(setdiff(RUOLI_USCITA, "subject"))),
                      subject_kind = list(const = ""),
                      missing_values = list(type = "array", maxItems = 0L))),
      ogg(campi, list(column = list(const = col),
                      role = list(const = "subject"),
                      subject_kind = list(type = "string", enum = as.list(SOGGETTI_USCITA)),
                      missing_values = list(type = "array", items = list(enum = as.list(vv)), maxItems = length(vv))))))
  }
  livello <- ogg(c("level", "text_as_written", "entity", "dose", "duration"), list(
    level = s("short name of the level, unique within the factor"),
    text_as_written = s("the text that states this level, as written in the metadata"),
    entity = s("name of the agent (perturbation) or of the disease or genotype (state); empty string for the other types"),
    dose = s("dose or concentration with its unit, if written; empty string otherwise"),
    duration = s("duration of the treatment with its unit, if written; empty string otherwise")))
  fattore <- ogg(c("name", "type", "levels", "baseline_level", "baseline_evidence", "assignment"), list(
    name = s("short name of the factor"),
    type = list(type = "string", enum = as.list(TIPI_USCITA)),
    levels = list(type = "array", items = livello),
    baseline_level = s("the level that is the baseline of this factor; empty string if the factor has no baseline"),
    baseline_evidence = s("quotation from the input text that supports the baseline; empty string if baseline_level is empty"),
    assignment = list(anyOf = lapply(colonne, ramo_fattore))))
  c(list(`$schema` = "https://json-schema.org/draft/2020-12/schema",
         title = paste0("factor_table.v2 - PROVA DA BUTTARE - ", v$record_id)),
    ogg(c("series_id", "factors", "columns", "not_understood"), list(
      series_id = list(const = v$record_id),
      factors = list(type = "array", items = fattore),
      columns = list(type = "array", prefixItems = lapply(colonne, ramo_altra), items = FALSE,
                     minItems = length(colonne), maxItems = length(colonne)),
      not_understood = list(type = "array", items = ogg(c("what", "why"), list(what = list(type = "string"), why = list(type = "string")))))))
}
schema_json <- function(v) as.character(jsonlite::toJSON(schema_studio(v), auto_unbox = TRUE, null = "null"))

if (sys.nframe() == 0L) {
  AUD <- "analysis/audit/2026-11-11-S12r3-elenco-chiuso"
  VISTE <- "analysis/audit/2026-11-09-lettore-studio/60-viste-v0.jsonl"
  stopifnot(identical(unname(tools::sha256sum(VISTE)), "2382a9ef97cf41d4f487078bd45e2d4c017dda104e8eb002f36881768eb6d86e"))
  viste <- lapply(readLines(VISTE, warn = FALSE), jsonlite::fromJSON, simplifyVector = FALSE)
  stopifnot(length(viste) == 47L)
  # uscita attesa: se ogni fattore della corsa M di S12r2 legge la sua (prima) colonna di fonte, quante voci scrive
  m <- lapply(readLines("analysis/p4-output/S12r2-lettore-v1/M-corsa1.jsonl", warn = FALSE), jsonlite::fromJSON, simplifyVector = FALSE)
  m <- stats::setNames(m, vapply(m, function(x) x$record_id, ""))
  riga <- function(v) {
    cc <- as.character(unlist(v$colonne)); n <- length(v$campioni)
    nv <- vapply(cc, function(k) length(valori_colonna(v, k)), 1L)
    js <- schema_json(v)
    car_voce <- function(k) sum(nchar(valori_colonna(v, k), "chars")) + 40L * nv[[k]]   # {"value":"..","level":"<~12 car>"},
    u <- tryCatch(jsonlite::fromJSON(m[[v$record_id]]$raw, simplifyVector = FALSE), error = function(e) NULL)
    fonti <- if (is.null(u)) character(0) else vapply(u$factors, function(f) { x <- as.character(unlist(f$source_columns)); x <- intersect(x, cc); if (length(x)) x[1] else NA_character_ }, "")
    data.frame(studio = v$record_id, campioni = n, colonne = length(cc), voci_totali = sum(nv), voci_max_colonna = max(nv),
               colonna_max = cc[which.max(nv)], colonne_un_valore_per_campione = sum(nv == n & n > 1L),
               celle_vuote_colonne = sum(vapply(cc, function(k) "" %in% valori_colonna(v, k), NA)),
               schema_caratteri = nchar(js, "chars"), testo_caratteri = nchar(v$testo, "chars"),
               fattori_m = length(fonti), fattori_m_senza_colonna = sum(is.na(fonti)),
               voci_attese_m = sum(nv[fonti[!is.na(fonti)]]),
               uscita_attesa_caratteri = sum(vapply(fonti[!is.na(fonti)], car_voce, 1)),
               uscita_peggiore_caratteri = length(fonti) * max(vapply(cc, car_voce, 1)),
               stringsAsFactors = FALSE)
  }
  g <- do.call(rbind, lapply(viste, riga))
  g <- g[order(-g$schema_caratteri), ]
  utils::write.csv(g, file.path(AUD, "11-grandezza-schema.csv"), row.names = FALSE)
  cat(sprintf("studi %d | schema caratteri: mediana %d, massimo %d (%s) | voci totali: mediana %d, massimo %d\n",
              nrow(g), as.integer(stats::median(g$schema_caratteri)), max(g$schema_caratteri), g$studio[1],
              as.integer(stats::median(g$voci_totali)), max(g$voci_totali)))
  print(utils::head(g[c("studio", "campioni", "colonne", "voci_totali", "voci_max_colonna", "schema_caratteri", "testo_caratteri",
                        "voci_attese_m", "uscita_attesa_caratteri", "uscita_peggiore_caratteri")], 12), row.names = FALSE)
}
