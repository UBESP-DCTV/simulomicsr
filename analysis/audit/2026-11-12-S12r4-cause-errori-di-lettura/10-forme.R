# PROVA DA BUTTARE
# 10-forme.R — S12r4 (dove nasce ogni errore di lettura del lettore): le FORME dell'uscita, una per variante.
# Una forma = uno schema delle uscite per ogni studio + un prompt. Le due forme di partenza sono quelle delle due
# prove: A0 (S12r2: 20-schema-v1.json + 21-prompt-v1.md) e B0 (S12r3: schema_studio() + 21-prompt-v2.md). Ogni
# altra forma cambia UNA differenza (01-carta.md) da una delle due parti, oppure una catena dichiarata.
# Non sta in inst/ e non entra nel pacchetto. Scritto e committato PRIMA di ogni corsa di S12r4.
#
# Definisce: FORME, schema_forma(v, nome), schema_json_forma(v, nome), prompt_forma(nome), forma_finale(cambi),
# traduci(), adatta_forma(), predicati(), firma_fattori(). `source()` dopo devtools::load_all(".").
# Da solo scrive i prompt (21-prompt-<forma>.md) e passa gli autocontrolli:
#   Rscript analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/10-forme.R      (SENZA --vanilla)
#
# Lo strumento di misura e' UNO per tutte le forme: adatta_forma() valida l'uscita contro lo schema della forma,
# la traduce nella forma v1 (oggetto «canonico»: fattore con `source_columns`, voci `when`/`level`,
# `other_columns`) e chiama adatta_v1() di S12r2, senza cambi. Il traduttore aggiunge due motivi di non chiuso:
#   - `ruolo_incoerente` (regola di adatta_v2 di S12r3, uguale): nelle forme con la tupla `columns`, una colonna
#     ha il ruolo `factor` se e solo se un fattore la legge;
#   - `riservato_altra_forma` (solo forme senza l'elenco `levels`, cambio F1): un livello che non e' uno dei due
#     nomi riservati alla lettera ma lo e' senza maiuscole e segni (`not_applicable`, `Not stated`). Con l'elenco
#     `levels` quel livello non dichiarato da' `livello_assente`; senza elenco diventerebbe un livello vero.
#     Nessuna tolleranza: lo studio non chiude.
S4 <- "analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura"
if (!exists("R2")) R2 <- "analysis/audit/2026-11-10-S12r2-prova-ripetuta"
if (!exists("R3")) R3 <- "analysis/audit/2026-11-11-S12r3-elenco-chiuso"
if (!exists("schema_studio")) source(file.path(R3, "10-schema-per-studio.R"))
if (!exists("adatta_v1")) source(file.path(R2, "22-adattatore-v1.R"))      # passa il suo controllo positivo
F_SCHEMA_V1 <- file.path(R2, "20-schema-v1.json")
F_PROMPT <- c(A = file.path(R2, "21-prompt-v1.md"), B = file.path(R3, "21-prompt-v2.md"))
S1 <- jsonlite::fromJSON(F_SCHEMA_V1, simplifyVector = FALSE)
js_schema <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null"))
# lo schema v1 riletto e riscritto e' lo stesso oggetto (A0 lo passa nel record, non nel bundle)
stopifnot(identical(jsonlite::fromJSON(js_schema(S1), simplifyVector = FALSE), S1))
RISERVATI <- c("not stated", "not applicable")
norm_ris <- function(x) gsub("[^a-z0-9]", "", tolower(x))
e_riservato_altra_forma <- function(x) !(x %in% RISERVATI) & norm_ris(x) %in% norm_ris(RISERVATI)

# ============================== 1. I PROMPT ====================================================================
leggi_byte <- function(f) { x <- readChar(f, file.size(f), useBytes = TRUE); Encoding(x) <- "UTF-8"; x }
conta <- function(testo, da) { m <- gregexpr(da, testo, fixed = TRUE, useBytes = TRUE)[[1]]; if (m[1] < 0L) 0L else length(m) }
# Un passo = una lista di alternative (da, a): UNA sola alternativa deve combaciare, e una sola volta.
passo <- function(...) { x <- c(...); stopifnot(length(x) %% 2L == 0L); lapply(seq(1L, length(x), 2L), function(i) list(da = x[[i]], a = x[[i + 1L]])) }
applica_passo <- function(testo, alt, che) {
  n <- vapply(alt, function(k) conta(testo, k$da), 0L)
  if (sum(n) != 1L) stop(sprintf("prompt, cambio %s: %d corrispondenze (ne serve una)", che, sum(n)), call. = FALSE)
  k <- alt[[which(n == 1L)]]
  sub(k$da, k$a, testo, fixed = TRUE, useBytes = TRUE)
}
RIGA57_V2 <- ", and the factors that no column states for all the samples, each with the reason"
P_A <- "Choose the column that states the factor for every sample. "
P_B <- "When the same variable is written in two or more columns, each one valid for a part of the samples, choose a column that states the variable for all the samples (often the source name or the title). "
P_C <- "Two factors can read the same column, when one column states two variables. "
P_D <- "If no column states the factor for all the samples, do not write the factor: describe it in `not_understood`."
F1_LIVELLI <- "The levels of a factor are the names that you write in the entries of `assignment` (`level`). Give the same name to the values that state the same level. In each entry write also the name of the entity (`entity`: the agent for a perturbation, the disease or genotype for a state), and the dose and the duration if they are written. Use the empty string for what is not written or does not apply. Do not write ontology identifiers: write names only."
L37_V2 <- "In `level`, write the name of one of the levels of the factor, or one of two special levels. Do not add the special levels to `levels`."
L37_F1 <- "In `level`, write the name of a level of the factor, or one of two special levels."
L37_F2 <- "In `level`, write the name of one of the levels of the factor. In two special cases, write the field `special` in place of `level`, with one of the two special levels. Do not add the special levels to `levels`."
L37_F12 <- "In `level`, write the name of a level of the factor. In two special cases, write the field `special` in place of `level`, with one of the two special levels."
V1_L11 <- "a name, a type, the columns of the SAMPLE TABLE from which its levels are read (`source_columns`), and its levels."
V1_L33 <- "Each entry has a list of conditions (`when`) and a `level`. Each condition names one of the source columns of the factor (`column`) and one value of that column (`value`), copied character by character from the SAMPLE TABLE (an empty cell is the empty string). A sample has the level of an entry when it meets all the conditions of that entry."
V1_L35 <- "When the factor has one source column, write one entry, with one condition, for every distinct value of that column. Use two or more conditions in one entry only when the level depends on two or more columns together. Write entries for distinct values, not for samples. Every sample of the series must meet the conditions of the entries of exactly one level."
# Il paragrafo sulle voci: la stesura del prompt v2 (R_V2) e quella della catena dal prompt v1 (R_V1). R le scambia.
R_V2 <- "`values` has one entry for every distinct value of that column, in the order in which the values first appear in the SAMPLE TABLE. Each entry has the value (`value`), copied character by character (an empty cell is the empty string), and the level of the samples that have that value (`level`). A sample has the level of the entry of its value. `gsm` and the constant columns cannot be the column of a factor."
R_V1 <- "Each entry of `values` has one value of that column (`value`), copied character by character from the SAMPLE TABLE (an empty cell is the empty string), and the level of the samples that have that value (`level`). A sample has the level of the entry of its value.\n\n`values` has one entry for every distinct value of that column, in the order in which the values first appear in the SAMPLE TABLE. Write entries for distinct values, not for samples. Every sample of the series must have exactly one level."
# I cambi del prompt, nell'ordine fisso in cui si applicano. Lato B: sul prompt v2. Lato A: sul prompt v1.
CAMBI_PROMPT <- list(
  # ---- lato B: verso il prompt v1 (reversioni) ----
  Pa = list(passo(P_A, "")),
  Pb = list(passo(P_B, "")),
  Pc = list(passo(P_C, "")),
  Pd = list(passo(paste0(" ", P_D), ""), passo(RIGA57_V2, ", each with the reason")),
  P = list(passo(paste0("\n", P_A, P_B, P_C, P_D, "\n"), ""), passo(RIGA57_V2, ", each with the reason")),
  P5 = list(passo("to the values of the samples outside it", "to the samples outside it")),
  C = list(passo("and then the role of every column of the SAMPLE TABLE.", "and then the role of the columns that are not the source of a factor."),
           passo("\n## Columns\n", "\n## Other columns\n"),
           passo("in the order of the table, write one entry in `columns` with its role:", "that is not the `column` of a factor, write one entry in `other_columns` with its role:"),
           passo("- `factor`: the column is the `column` of a factor. Use this role for every column that a factor reads, and only for those columns.\n", "")),
  A1 = list(passo("its levels, and the column of the SAMPLE TABLE from which its levels are read (in `assignment`)",
                  "the column of the SAMPLE TABLE from which its levels are read (`source_column`), and its levels"),
            passo("A factor reads one column of the SAMPLE TABLE. Write the name of that column in `column`. `values` has",
                  "A factor reads one column of the SAMPLE TABLE: its `source_column`. `values` has"),
            passo("the `column` of a factor", "the `source_column` of a factor")),
  R = list(passo(R_V2, R_V1)),
  # ---- lato B: le due correzioni di forma ----
  F1 = list(passo("a name, a type, its levels, and the column", "a name, a type, and the column",
                  "(`source_column`), and its levels.", "(`source_column`)."),
            passo("For each level write a short name (`level`), the text as written in the metadata (`text_as_written`), the name of the entity (`entity`: the agent for a perturbation, the disease or genotype for a state), and the dose and the duration if they are written. Use the empty string for what is not written or does not apply. Do not write ontology identifiers: write names only.", F1_LIVELLI),
            passo(L37_V2, L37_F1)),
  F2 = list(passo(L37_V2, L37_F2, L37_F1, L37_F12)),
  # ---- lato A: verso il prompt v2 ----
  aC = list(passo("and then the role of the columns that are not the source of a factor.", "and then the role of every column of the SAMPLE TABLE."),
            passo("\n## Other columns\n", "\n## Columns\n"),
            passo("that is not a source column of a factor, write one entry in `other_columns` with its role:", "in the order of the table, write one entry in `columns` with its role:"),
            passo("\n- `subject`: donor or patient", "\n- `factor`: the column is a source column of a factor. Use this role for every column that a factor reads, and only for those columns.\n- `subject`: donor or patient")),
  aA1 = list(passo(V1_L11, "a name, a type, its levels, and the columns of the SAMPLE TABLE from which its levels are read (`source_columns`).")),
  aA2 = list(passo(V1_L11, "a name, a type, the column of the SAMPLE TABLE from which its levels are read (`source_column`), and its levels."),
             passo(V1_L33, "A factor reads one column of the SAMPLE TABLE: its `source_column`. Each entry of `values` has one value of that column (`value`), copied character by character from the SAMPLE TABLE (an empty cell is the empty string), and the level of the samples that have that value (`level`). A sample has the level of the entry of its value."),
             passo(V1_L35, "Write one entry for every distinct value of that column. Write entries for distinct values, not for samples. Every sample of the series must have exactly one level."),
             passo("that is not a source column of a factor", "that is not the `source_column` of a factor")),
  aA4 = list(passo("Write one entry for every distinct value of that column.", "`values` has one entry for every distinct value of that column, in the order in which the values first appear in the SAMPLE TABLE.")),
  aR = list(passo(R_V1, R_V2)),                                  # solo dopo aA2 + aA3 + aA4
  # ---- i due placebo: una frase riscritta senza cambiare il senso (valgono per i due prompt) ----
  pl1 = list(passo("You receive one GEO series:", "You are given one GEO series:")),
  pl2 = list(passo("Use an empty array if there are none.", "If there are none, use an empty array.")))
ORDINE_CAMBI <- names(CAMBI_PROMPT)

# ============================== 2. I CAMBI E LE FORME ==========================================================
# Ogni cambio: il lato, il cambio del prompt (o nessuno) e gli interruttori dello schema.
CAMBI <- list(
  Pa = list(lato = "B", prompt = "Pa"), Pb = list(lato = "B", prompt = "Pb"), Pc = list(lato = "B", prompt = "Pc"),
  Pd = list(lato = "B", prompt = "Pd"), P = list(lato = "B", prompt = "P"), P5 = list(lato = "B", prompt = "P5"),
  C = list(lato = "B", prompt = "C", schema = list(colonne_v1 = TRUE)),
  C3 = list(lato = "B", schema = list(lega = FALSE)),
  A1 = list(lato = "B", prompt = "A1", schema = list(col_prima = TRUE)),
  R = list(lato = "B", prompt = "R"),
  A4 = list(lato = "B", schema = list(tupla = FALSE)),
  A3 = list(lato = "B", schema = list(chiuso = FALSE)),                       # solo dopo A4
  F1 = list(lato = "B", prompt = "F1", schema = list(f1 = TRUE)),
  F2 = list(lato = "B", prompt = "F2", schema = list(f2 = TRUE)),
  aC = list(lato = "A", prompt = "aC", schema = list(colonne_v2 = TRUE)),
  aA1 = list(lato = "A", prompt = "aA1", schema = list(col_dopo = TRUE)),
  aA3 = list(lato = "A", schema = list(chiuso = TRUE)),
  aA2 = list(lato = "A", prompt = "aA2", schema = list(una_colonna = TRUE)),
  aA4 = list(lato = "A", prompt = "aA4", schema = list(tupla = TRUE)),        # solo dopo aA2 + aA3
  aR = list(lato = "A", prompt = "aR"),                                       # solo dopo aA4
  pl1 = list(lato = "AB", prompt = "pl1"), pl2 = list(lato = "AB", prompt = "pl2"))
forma <- function(lato, ...) list(lato = lato, cambi = c(...))
FORME <- list(
  B0 = forma("B"), RP = forma("B", "P"), RPa = forma("B", "Pa"), RPb = forma("B", "Pb"), RPc = forma("B", "Pc"),
  RPd = forma("B", "Pd"), RP5 = forma("B", "P5"), RC = forma("B", "C"), RC3 = forma("B", "C3"),
  RA1 = forma("B", "A1"), RA4 = forma("B", "A4"), RA4A3 = forma("B", "A4", "A3"), RR = forma("B", "R"),
  # la catena dal lato B: da B0 verso il fondo della catena del lato A, un cambio per volta
  RA1P = forma("B", "A1", "P"), RA1PP5 = forma("B", "A1", "P", "P5"), RA1PP5C = forma("B", "A1", "P", "P5", "C"),
  F1 = forma("B", "F1"), F2 = forma("B", "F2"), F12 = forma("B", "F1", "F2"),
  B0pl1 = forma("B", "pl1"), B0pl2 = forma("B", "pl2"),
  A0 = forma("A"), A0C = forma("A", "aC"), A0A1 = forma("A", "aA1"), A0A3 = forma("A", "aA3"),
  A0A2 = forma("A", "aA2"), A0A2A3 = forma("A", "aA2", "aA3"), A0A2A3A4 = forma("A", "aA2", "aA3", "aA4"),
  A0A2A3A4R = forma("A", "aA2", "aA3", "aA4", "aR"),             # il ponte: stesso prompt e stesso schema (a meno delle descrizioni) di RA1PP5C
  A0pl1 = forma("A", "pl1"), A0pl2 = forma("A", "pl2"))
controlla_forma <- function(f) {
  k <- f$cambi
  stopifnot(f$lato %in% c("A", "B"), all(k %in% names(CAMBI)), !anyDuplicated(k),
            all(vapply(CAMBI[k], function(x) grepl(f$lato, x$lato, fixed = TRUE), NA)),
            !("P" %in% k && any(c("Pa", "Pb", "Pc", "Pd") %in% k)), !all(c("Pa", "Pb", "Pc", "Pd") %in% k),
            !("A3" %in% k) || "A4" %in% k, !("aA4" %in% k) || all(c("aA2", "aA3") %in% k), !("aR" %in% k) || "aA4" %in% k,
            !("C3" %in% k && "C" %in% k), !(any(c("aA1", "aA2") %in% k) && all(c("aA1", "aA2") %in% k)))
  invisible(f)
}
invisible(lapply(FORME, controlla_forma))
# La forma finale (FIN): una combinazione di cambi del lato B, decisa dalla regola di diagnosi di 00-previsioni.md.
# Si registra con forma_finale() prima delle sue due corse; non e' fra le forme qui sopra.
forma_finale <- function(cambi) { f <- controlla_forma(forma("B", cambi)); stopifnot(!any(c("pl1", "pl2") %in% cambi)); FORME$FIN <<- f; invisible(f) }
F_FIN <- file.path(S4, "30-forma-finale.txt")
if (file.exists(F_FIN)) forma_finale(setdiff(trimws(strsplit(readLines(F_FIN, warn = FALSE)[1], ",", fixed = TRUE)[[1]]), ""))

prompt_forma <- function(nome) {
  f <- FORME[[nome]]; stopifnot(!is.null(f))
  t <- leggi_byte(F_PROMPT[[f$lato]])
  stopifnot(conta(t, " \n") == 0L, conta(t, "\r") == 0L)
  for (k in intersect(ORDINE_CAMBI, vapply(CAMBI[f$cambi], function(x) if (is.null(x$prompt)) "" else x$prompt, "")))
    for (i in seq_along(CAMBI_PROMPT[[k]])) t <- applica_passo(t, CAMBI_PROMPT[[k]][[i]], sprintf("%s/%d (%s)", k, i, nome))
  t <- gsub(" \n", "\n", t, fixed = TRUE, useBytes = TRUE)     # una frase tolta in fondo a una riga non lascia lo spazio
  Encoding(t) <- "UTF-8"; t
}
f_prompt_forma <- function(nome) file.path(S4, sprintf("21-prompt-%s.md", nome))
scrivi_prompt <- function(nome) { con <- file(f_prompt_forma(nome), "wb"); writeBin(charToRaw(prompt_forma(nome)), con); close(con) }

# ============================== 3. GLI SCHEMI ==================================================================
ogg <- function(req, prop) list(type = "object", additionalProperties = FALSE, required = as.list(req), properties = prop)
s_d <- function(d) list(type = "string", description = d)
D_ENT <- "name of the agent (perturbation) or of the disease or genotype (state); empty string for the other types"
D_DOSE <- "dose or concentration with its unit, if written; empty string otherwise"
D_DUR <- "duration of the treatment with its unit, if written; empty string otherwise"
S2020 <- "https://json-schema.org/draft/2020-12/schema"
# La voce di `values`. `val`: un valore (tupla: const), piu' valori (lista aperta: enum), NULL (stringa libera).
voce_forma <- function(val, tupla, f1 = FALSE, f2 = FALSE) {
  vs <- if (is.null(val)) list(type = "string") else if (tupla) list(const = val) else list(type = "string", enum = as.list(val))
  normale <- ogg(c("value", "level", if (f1) c("entity", "dose", "duration")),
                 c(list(value = vs, level = list(type = "string")),
                   if (f1) list(entity = s_d(D_ENT), dose = s_d(D_DOSE), duration = s_d(D_DUR))))
  if (!f2) return(normale)
  list(anyOf = list(normale, ogg(c("value", "special"), list(value = vs, special = list(type = "string", enum = as.list(RISERVATI))))))
}
valori_forma <- function(v, col, tupla, chiuso, f1 = FALSE, f2 = FALSE) {
  if (!chiuso) return(list(type = "array", items = voce_forma(NULL, FALSE, f1, f2)))
  vv <- valori_colonna(v, col)
  if (!tupla) return(list(type = "array", items = voce_forma(vv, FALSE, f1, f2)))
  list(type = "array", prefixItems = lapply(vv, voce_forma, tupla = TRUE, f1 = f1, f2 = f2), items = FALSE,
       minItems = length(vv), maxItems = length(vv))
}
# la tupla `columns` della forma v2: `lega` = tipo di soggetto e valori mancanti legati al ruolo (forma 3 di S12r3)
colonne_v2_forma <- function(v, lega = TRUE) {
  colonne <- as.character(unlist(v$colonne)); campi <- c("column", "role", "subject_kind", "missing_values")
  ramo <- function(col) {
    vv <- valori_colonna(v, col)
    if (!lega) return(ogg(campi, list(column = list(const = col), role = list(type = "string", enum = as.list(RUOLI_USCITA)),
                                      subject_kind = list(type = "string", enum = as.list(SOGGETTI_USCITA)),
                                      missing_values = list(type = "array", items = list(type = "string")))))
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
  list(type = "array", prefixItems = lapply(colonne, ramo), items = FALSE, minItems = length(colonne), maxItems = length(colonne))
}
# Il fattore con la colonna PRIMA dei livelli (`source_column`), una colonna per fattore.
fattore_col_prima <- function(v, comuni, tupla, chiuso, f1 = FALSE, f2 = FALSE) {
  colonne <- as.character(unlist(v$colonne))
  nomi <- c("name", "type", "source_column", if (!f1) "levels", "baseline_level", "baseline_evidence", "assignment")
  uno <- function(col) {
    p <- c(comuni, list(source_column = if (is.null(col)) list(type = "string") else list(const = col),
                        assignment = ogg("values", list(values = valori_forma(v, col, tupla, chiuso, f1, f2)))))
    ogg(nomi, p[nomi])
  }
  if (!chiuso) uno(NULL) else list(anyOf = lapply(colonne, uno))
}

# ---- lato B: da schema_studio() di S12r3; con gli interruttori di default e' lo stesso oggetto ----
schema_B <- function(v, col_prima = FALSE, tupla = TRUE, chiuso = TRUE, colonne_v1 = FALSE, lega = TRUE, f1 = FALSE, f2 = FALSE) {
  colonne <- as.character(unlist(v$colonne))
  stopifnot(length(colonne) > 0L, !anyDuplicated(colonne), all(colonne %in% names(v$tabella)), !("gsm" %in% colonne), chiuso || !tupla)
  livello <- ogg(c("level", "text_as_written", "entity", "dose", "duration"), list(
    level = s_d("short name of the level, unique within the factor"),
    text_as_written = s_d("the text that states this level, as written in the metadata"),
    entity = s_d(D_ENT), dose = s_d(D_DOSE), duration = s_d(D_DUR)))
  comuni <- list(
    name = s_d("short name of the factor"),
    type = list(type = "string", enum = as.list(TIPI_USCITA)),
    levels = list(type = "array", items = livello),
    baseline_level = s_d("the level that is the baseline of this factor; empty string if the factor has no baseline"),
    baseline_evidence = s_d("quotation from the input text that supports the baseline; empty string if baseline_level is empty"))
  fattore <- if (col_prima) fattore_col_prima(v, comuni, tupla, chiuso, f1, f2) else {
    ramo <- function(col) ogg(c("column", "values"), list(column = if (is.null(col)) list(type = "string") else list(const = col),
                                                          values = valori_forma(v, col, tupla, chiuso, f1, f2)))
    nomi <- c("name", "type", if (!f1) "levels", "baseline_level", "baseline_evidence", "assignment")
    p <- c(comuni, list(assignment = if (!chiuso) ramo(NULL) else list(anyOf = lapply(colonne, ramo))))
    ogg(nomi, p[nomi])
  }
  nome_col <- if (colonne_v1) "other_columns" else "columns"
  p <- list(series_id = if (chiuso) list(const = v$record_id) else list(type = "string"), factors = list(type = "array", items = fattore),
            colonne = if (colonne_v1) S1$properties$other_columns else colonne_v2_forma(v, lega),
            not_understood = list(type = "array", items = ogg(c("what", "why"), list(what = list(type = "string"), why = list(type = "string")))))
  names(p)[3] <- nome_col
  c(list(`$schema` = S2020, title = paste0("factor_table.v2 - PROVA DA BUTTARE - ", v$record_id)),
    ogg(c("series_id", "factors", nome_col, "not_understood"), p))
}

# ---- lato A: da 20-schema-v1.json di S12r2; senza interruttori e' lo stesso oggetto (uguale per ogni studio) ----
schema_A <- function(v, col_dopo = FALSE, chiuso = FALSE, una_colonna = FALSE, tupla = FALSE, colonne_v2 = FALSE) {
  S <- S1; colonne <- as.character(unlist(v$colonne)); fp <- S1$properties$factors$items$properties
  stopifnot(!tupla || (una_colonna && chiuso), !(col_dopo && una_colonna))
  if (col_dopo) {
    nomi <- c("name", "type", "levels", "baseline_level", "baseline_evidence", "source_columns", "assignment")
    S$properties$factors$items$required <- as.list(nomi); S$properties$factors$items$properties <- fp[nomi]
  }
  if (chiuso) S$properties$series_id <- list(const = v$record_id)
  if (chiuso && !una_colonna) {
    S$properties$factors$items$properties$source_columns$items <- list(type = "string", enum = as.list(colonne))
    S$properties$factors$items$properties$assignment$items$properties$when$items <- list(anyOf = lapply(colonne, function(col)
      ogg(c("column", "value"), list(column = list(const = col), value = list(type = "string", enum = as.list(valori_colonna(v, col)))))))
  }
  if (una_colonna) S$properties$factors$items <- fattore_col_prima(v, fp[c("name", "type", "levels", "baseline_level", "baseline_evidence")], tupla, chiuso)
  if (colonne_v2) {
    S$required <- list("series_id", "factors", "columns", "not_understood")
    S$properties <- list(series_id = S$properties$series_id, factors = S$properties$factors, columns = colonne_v2_forma(v, TRUE),
                         not_understood = S1$properties$not_understood)
  }
  if (tupla || colonne_v2) S[["$schema"]] <- S2020                 # le tuple (`prefixItems`) chiedono il draft 2020-12
  S
}
# lo schema senza le parti che non entrano nella grammatica: descrizioni, titolo, $id, $schema
spoglia <- function(x) { if (!is.list(x)) return(x); if (!is.null(names(x))) x <- x[!(names(x) %in% c("description", "title", "$id", "$schema"))]; lapply(x, spoglia) }
interruttori <- function(nome) { f <- FORME[[nome]]; stopifnot(!is.null(f)); do.call(c, c(list(list()), unname(lapply(CAMBI[f$cambi], `[[`, "schema")))) }
schema_forma <- function(v, nome) do.call(if (FORME[[nome]]$lato == "B") schema_B else schema_A, c(list(v), interruttori(nome)))
schema_json_forma <- function(v, nome) js_schema(schema_forma(v, nome))
.validatori_forma <- new.env()
validatore_forma <- function(v, nome) {
  k <- paste(nome, v$record_id)
  if (is.null(.validatori_forma[[k]])) {
    f <- tempfile(fileext = ".json"); on.exit(unlink(f))
    con <- file(f, "wb"); writeLines(enc2utf8(schema_json_forma(v, nome)), con, useBytes = TRUE); close(con)
    .validatori_forma[[k]] <- compile_schema(f)
  }
  .validatori_forma[[k]]
}

# ============================== 4. IL TRADUTTORE E LO STRUMENTO DI MISURA ======================================
# Dall'uscita di una forma all'oggetto canonico (forma v1). Non decide niente: sposta i campi.
traduci <- function(u, v) {
  extra <- character(0); note <- character(0); colonne <- as.character(unlist(v$colonne))
  fattori <- lapply(u$factors, function(f) {
    if (!is.null(f$source_columns)) return(f[c("name", "type", "source_columns", "levels", "baseline_level", "baseline_evidence", "assignment")])
    col <- if (!is.null(f$source_column)) f$source_column else f$assignment$column
    voci <- f$assignment$values
    liv_voce <- vapply(voci, function(a) if (!is.null(a$special)) a$special else a$level, "")
    speciale <- vapply(voci, function(a) !is.null(a$special), NA)
    if (is.null(f$levels)) {                                     # F1: i livelli sono i nomi scritti nelle voci
      nomi <- unique(liv_voce[!speciale & !(liv_voce %in% RISERVATI)])
      if (any(e_riservato_altra_forma(nomi))) extra <<- c(extra, sprintf("riservato_altra_forma: %s: %s", f$name, paste(nomi[e_riservato_altra_forma(nomi)], collapse = ", ")))
      levels <- lapply(nomi, function(l) { a <- voci[[which(liv_voce == l & !speciale)[1]]]
        list(level = l, text_as_written = "", entity = a$entity, dose = a$dose, duration = a$duration) })
    } else {
      levels <- f$levels
      dich <- vapply(levels, function(l) l$level, "")
      if (any(e_riservato_altra_forma(dich))) note <<- c(note, sprintf("riservato_altra_forma_dichiarato: %s: %s", f$name, paste(dich[e_riservato_altra_forma(dich)], collapse = ", ")))
    }
    list(name = f$name, type = f$type, source_columns = list(col), levels = levels, baseline_level = f$baseline_level,
         baseline_evidence = f$baseline_evidence,
         assignment = lapply(seq_along(voci), function(j) list(when = list(list(column = col, value = voci[[j]]$value)), level = liv_voce[j])))
  })
  nomi_f <- vapply(fattori, function(f) f$name, "")
  if (anyDuplicated(nomi_f)) note <- c(note, sprintf("nome_di_fattore_doppio: %s", paste(unique(nomi_f[duplicated(nomi_f)]), collapse = ", ")))
  if (is.null(u$columns)) altre <- u$other_columns else {
    ruoli <- stats::setNames(vapply(u$columns, function(k) k$role, ""), vapply(u$columns, function(k) k$column, ""))
    stopifnot(identical(names(ruoli), colonne))                 # lo schema lo fissa
    lette <- unique(unlist(lapply(fattori, function(f) as.character(unlist(f$source_columns)))))
    fuori <- setdiff(lette, colonne)                             # gsm, costante o ignota: non ha un ruolo nella tupla
    if (length(fuori)) note <- c(note, sprintf("fonte_fuori_dalla_tupla: %s", paste(fuori, collapse = ", ")))
    lette <- intersect(lette, colonne)
    senza_fattore <- setdiff(names(ruoli)[ruoli == "factor"], lette)
    senza_ruolo <- setdiff(lette, names(ruoli)[ruoli == "factor"])
    if (length(senza_fattore)) extra <- c(extra, sprintf("ruolo_incoerente: ruolo factor e nessun fattore la legge: %s", paste(senza_fattore, collapse = ", ")))
    if (length(senza_ruolo)) extra <- c(extra, sprintf("ruolo_incoerente: un fattore la legge e il ruolo e' %s", paste(sprintf("%s (%s)", senza_ruolo, ruoli[senza_ruolo]), collapse = ", ")))
    altre <- Filter(function(k) !identical(k$role, "factor"), u$columns)
  }
  list(canonico = list(series_id = u$series_id, factors = fattori, other_columns = altre, not_understood = u$not_understood),
       extra = extra, note = note)
}
# Ritorna come adatta_v1(), piu' `valida` (l'uscita passa lo schema della forma) e `canonico` (se valida).
adatta_forma <- function(v, raw, saltato, fine, nome) {
  esce <- function(m) list(chiuso = FALSE, motivi = m, note = character(0), conti = integer(0), valida = FALSE)
  if (isTRUE(saltato)) return(esce("oltre_contesto"))
  tronca <- if (identical(fine, "length")) "troncata" else character(0)
  val <- if (is.na(raw) || !nzchar(raw)) list(valid = FALSE, errors = "uscita vuota") else
    tryCatch(validate_json(raw, validatore_forma(v, nome)), error = function(e) list(valid = FALSE, errors = conditionMessage(e)))
  if (!isTRUE(val$valid)) return(esce(c(tronca, paste0("non_valida: ", unisci(utils::head(val$errors, 3L))))))
  u <- jsonlite::fromJSON(raw, simplifyVector = FALSE)
  t <- traduci(u, v)
  if (length(tronca)) return(c(esce(tronca)[c("chiuso", "motivi", "note", "conti")], list(valida = TRUE, canonico = t$canonico)))  # troncata ma valida: non si misura
  r <- adatta_v1(v, as.character(jsonlite::toJSON(t$canonico, auto_unbox = TRUE)), FALSE, fine)
  if (any(grepl("^non_valida", r$motivi))) stop("il traduttore ha scritto un oggetto che non passa lo schema v1: ", v$record_id, " ", nome, ": ", unisci(r$motivi))
  r$note <- c(r$note, t$note); r$valida <- TRUE; r$canonico <- t$canonico
  if (length(t$extra)) {
    r$motivi <- c(r$motivi, t$extra)
    if (r$chiuso) r <- c(list(chiuso = FALSE), r[c("motivi", "note", "conti", "fattori", "valida", "canonico")])
  }
  r
}
nomi_motivi <- function(r) unique(sub(":.*$", "", sub("^(tf_tabella):.*$", "\\1", r$motivi)))

# ============================== 5. I PREDICATI DEGLI ERRORI DI LETTURA E LA FIRMA ==============================
# Sul canonico (non chiede lo studio chiuso). NA = non valutabile (uscita non valida o oltre il contesto).
SIGLE_46665 <- c("DCM", "GCN", "HSD", "JDM", "NMN", "RAB", "RDR", "TCA", "TLF")
fonti_f <- function(f) as.character(unlist(f$source_columns))
predicati <- function(studio, k) {
  if (is.null(k)) return(NA)
  ff <- k$factors
  switch(studio,
    GSE57945 = any(vapply(ff, function(f) "Sex" %in% fonti_f(f), NA)),                    # il sesso scritto come fattore
    GSE60340 = !any(vapply(ff, function(f) "treated with" %in% fonti_f(f), NA)),          # nessun fattore legge il trattamento
    GSE49155 = any(vapply(ff, function(f) any(vapply(f$assignment, function(a)            # la cella vuota di `cell type` con un livello
      any(vapply(a$when, function(w) identical(w$column, "cell type") && identical(w$value, ""), NA)) &&
        !(norm_ris(a$level) %in% norm_ris(RISERVATI)), NA)), NA)),
    GSE46665 = any(vapply(ff, function(f) {                                               # le sigle dei pazienti come livelli
      liv <- c(vapply(f$levels, function(l) l$level, ""), vapply(f$assignment, function(a) a$level, ""))
      pezzi <- unique(toupper(unlist(strsplit(liv, "[^A-Za-z0-9]+"))))
      sum(SIGLE_46665 %in% pezzi) >= 5L
    }, NA)),
    NA)
}
QUATTRO <- c("GSE57945", "GSE60340", "GSE49155", "GSE46665")
# Il livello di ogni campione per un fattore del canonico (NA: nessuna voce o piu' livelli).
livelli_canonico <- function(v, f) {
  gsm <- as.character(unlist(v$campioni)); n <- length(gsm)
  val <- function(col) if (col == "gsm") gsm else if (col %in% names(v$tabella)) valori_campioni_s4(v, col) else if (col %in% names(v$costanti)) rep(as.character(v$costanti[[col]]), n) else rep(NA_character_, n)
  fonti <- fonti_f(f); out <- rep(NA_character_, n); amb <- rep(FALSE, n)
  for (a in f$assignment) {
    cc <- vapply(a$when, function(w) w$column, ""); vv <- vapply(a$when, function(w) w$value, "")
    if (!length(cc) || !all(cc %in% fonti) || anyDuplicated(cc)) next
    s <- rep(TRUE, n); for (i in seq_along(cc)) s <- s & (val(cc[i]) %in% vv[i])
    amb <- amb | (s & !is.na(out) & out != a$level); out[s & is.na(out)] <- a$level
  }
  out[amb] <- NA_character_; out
}
valori_campioni_s4 <- function(v, col) vapply(as.character(unlist(v$campioni)), function(g) { y <- v$tabella[[col]][[g]]; if (is.null(y) || is.na(y)) "" else as.character(y) }, "", USE.NAMES = FALSE)
# La firma della tabella dei fattori: per ogni fattore tipo, colonne di fonte, partizione dei campioni che induce
# e gruppo di base; piu' i soggetti (colonna, tipo, valori mancanti). Senza nomi di fattori e di livelli.
firma_fattori <- function(v, k) {
  if (is.null(k)) return(NA_character_)
  f1 <- vapply(k$factors, function(f) {
    lv <- livelli_canonico(v, f); lv[lv %in% RISERVATI[1]] <- "\001ns"; lv[lv %in% RISERVATI[2]] <- "\001na"
    ris <- lv %in% c("\001ns", "\001na"); idx <- match(lv, unique(lv[!ris & !is.na(lv)]))
    cod <- ifelse(is.na(lv), "?", ifelse(ris, sub("\001", "", lv), as.character(idx)))
    base <- if (nzchar(f$baseline_level) && f$baseline_level %in% lv) match(f$baseline_level, unique(lv[!ris & !is.na(lv)])) else 0L
    paste(f$type, paste(sort(fonti_f(f)), collapse = "+"), paste(cod, collapse = ","), base, sep = "|")
  }, "")
  sg <- vapply(Filter(function(x) identical(x$role, "subject"), k$other_columns), function(x)
    paste(x$column, x$subject_kind, paste(sort(as.character(unlist(x$missing_values))), collapse = ","), sep = "|"), "")
  digest::digest(paste(c(sort(f1), "--", sort(sg)), collapse = "\n"), algo = "sha256", serialize = FALSE)
}
# Fattore doppio: due fattori del canonico che inducono la stessa partizione dei campioni.
fattori_doppi <- function(v, k) {
  if (is.null(k) || length(k$factors) < 2L) return(0L)
  p <- vapply(k$factors, function(f) { lv <- livelli_canonico(v, f); paste(match(lv, unique(lv)), collapse = ",") }, "")
  sum(duplicated(p))
}
# Soggetto costante nei gruppi: una colonna col ruolo `subject` e tipo `donor` che ha lo stesso valore in tutti i
# campioni di ogni gruppo del lettore, con almeno due valori nello studio e almeno un gruppo di due o piu' campioni.
# Una colonna cosi' ripete i gruppi e non distingue i donatori dentro un gruppo (S12r3: `source_name_ch1` in
# GSE50760 e GSE71595). Ritorna i nomi delle colonne. Limite dichiarato: non distingue il caso vero di un solo
# donatore per gruppo con repliche tecniche. `partizione` = gruppo di ogni campione (nomi = campioni).
soggetti_costanti <- function(v, k, partizione) {
  if (is.null(k) || !length(partizione)) return(character(0))
  sg <- Filter(function(x) identical(x$role, "subject") && identical(x$subject_kind, "donor") && x$column %in% names(v$tabella), k$other_columns)
  gsm <- as.character(unlist(v$campioni)); gr <- partizione[gsm]
  out <- character(0)
  for (x in sg) {
    val <- valori_campioni_s4(v, x$column); val[val %in% c("", as.character(unlist(x$missing_values)))] <- NA
    ok <- !is.na(val) & !is.na(gr)
    if (length(unique(val[ok])) < 2L || max(table(gr[ok]), 0L) < 2L) next
    if (all(tapply(val[ok], gr[ok], function(z) length(unique(z)) == 1L))) out <- c(out, x$column)
  }
  out
}

# ============================== 6. AUTOCONTROLLI (a ogni source) ===============================================
local({
  # i prompt delle due forme di partenza sono i file congelati, byte per byte; ogni forma ha il suo prompt
  stopifnot(identical(prompt_forma("B0"), leggi_byte(F_PROMPT[["B"]])), identical(prompt_forma("A0"), leggi_byte(F_PROMPT[["A"]])))
  pp <- vapply(names(FORME), prompt_forma, "")
  # due forme hanno lo stesso prompt se e solo se hanno lo stesso lato e gli stessi cambi del prompt
  chiave <- vapply(FORME, function(f) paste(c(f$lato, sort(unlist(lapply(CAMBI[f$cambi], `[[`, "prompt")))), collapse = " "), "")
  senza <- setdiff(names(FORME), "A0A2A3A4R")                   # il ponte ha per costruzione il prompt di RA1PP5C
  stopifnot(identical(unname(match(pp[senza], unique(pp[senza]))), unname(match(chiave[senza], unique(chiave[senza])))))
  # P toglie le quattro frasi; ogni variante Pa-Pd ne toglie una sola
  quante <- function(t) vapply(c(P_A, P_B, P_C, P_D), function(x) conta(t, trimws(x)), 0L)
  stopifnot(all(quante(pp[["B0"]]) == 1L), all(quante(pp[["RP"]]) == 0L), all(quante(pp[["A0"]]) == 0L),
            all(vapply(c("RPa", "RPb", "RPc", "RPd"), function(n) sum(quante(pp[[n]])), 0L) == 3L))
  # lo studio finto GSE0 (lo stesso di S12r2 e S12r3)
  g <- sprintf("GSM%d", 1:12); col <- function(x) as.list(stats::setNames(x, g))
  v <- list(record_id = "GSE0", campioni = as.list(g), colonne = list("disease", "stage", "agent", "sex", "title"),
            tabella = list(disease = col(rep(c("healthy", "IBD", "IBD"), each = 4)), stage = col(rep(c("", "II", "III"), each = 4)),
                           agent = col(rep(c("none", "none", "Dex", "Dex"), 3)), sex = col(rep(c("F", "M", "F", "NA"), 3)),
                           title = col(sprintf("sample %d", 1:12))), costanti = list(tissue = "colon"))
  stopifnot(identical(schema_forma(v, "B0"), schema_studio(v)), identical(schema_forma(v, "A0"), S1),
            identical(schema_forma(v, "RA4A3")$properties$columns, schema_studio(v)$properties$columns))
  # il ponte fra i due lati: stesso prompt byte per byte e stesso schema, a meno di descrizioni, titolo e $id
  stopifnot(identical(pp[["A0A2A3A4R"]], pp[["RA1PP5C"]]), identical(spoglia(schema_forma(v, "A0A2A3A4R")), spoglia(schema_forma(v, "RA1PP5C"))))
  # un'uscita buona di GSE0 in ogni forma: 6 gruppi, 7 confronti; e per ogni forma un'uscita rotta apposta
  buona <- function(nome) {
    f <- FORME[[nome]]; sw <- interruttori(nome); B <- f$lato == "B"
    f1 <- isTRUE(sw$f1); f2 <- isTRUE(sw$f2)
    lv <- function(l, e = "") list(level = l, text_as_written = l, entity = e, dose = "", duration = "")
    D <- list(list("disease", "state", "disease", list(lv("healthy"), lv("IBD", "inflammatory bowel disease")), "healthy", c("healthy", "healthy", "IBD", "IBD")),
              list("stage", "state", "stage", list(lv("II"), lv("III")), "", c("", "not applicable", "II", "II", "III", "III")),
              list("compound", "perturbation", "agent", list(lv("vehicle"), lv("dex", "dexamethasone")), "vehicle", c("none", "vehicle", "Dex", "dex")))
    vecchia <- !B && !isTRUE(sw$una_colonna)                     # la forma `when` del v1
    fatt <- lapply(D, function(d) {
      x <- d[[6]]; ii <- seq(1, length(x), 2)
      voci <- lapply(ii, function(i) {
        if (vecchia) return(list(when = list(list(column = d[[3]], value = x[[i]])), level = x[[i + 1]]))
        if (f2 && x[[i + 1]] %in% RISERVATI) return(list(value = x[[i]], special = x[[i + 1]]))
        c(list(value = x[[i]], level = x[[i + 1]]), if (f1) list(entity = "", dose = "", duration = ""))
      })
      base <- list(name = d[[1]], type = d[[2]], levels = d[[4]], baseline_level = d[[5]], baseline_evidence = d[[5]])
      if (f1) base$levels <- NULL
      if (vecchia) { o <- c(base, list(source_columns = list(d[[3]]), assignment = voci))
        return(o[if (isTRUE(sw$col_dopo)) c("name", "type", "levels", "baseline_level", "baseline_evidence", "source_columns", "assignment") else c("name", "type", "source_columns", "levels", "baseline_level", "baseline_evidence", "assignment")]) }
      if (isTRUE(sw$col_prima) || !B) { o <- c(base, list(source_column = d[[3]], assignment = list(values = voci)))
        return(o[c("name", "type", "source_column", if (!f1) "levels", "baseline_level", "baseline_evidence", "assignment")]) }
      c(base, list(assignment = list(column = d[[3]], values = voci)))
    })
    ruolo <- function(colonna, role, kind = "", manc = list()) list(column = colonna, role = role, subject_kind = kind, missing_values = manc)
    altre <- list(ruolo("sex", "subject", "sex", list("NA")), ruolo("title", "replicate"))
    tutte <- c(lapply(c("disease", "stage", "agent"), ruolo, role = "factor"), altre)
    v2col <- (B && !isTRUE(sw$colonne_v1)) || isTRUE(sw$colonne_v2)
    o <- list(series_id = "GSE0", factors = fatt)
    if (v2col) o$columns <- tutte else o$other_columns <- altre
    o$not_understood <- list(); o
  }
  js <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE))
  motivo <- function(r) nomi_motivi(r)
  firme <- character(0)
  for (nome in names(FORME)) {
    sw <- interruttori(nome); b <- buona(nome)
    r <- adatta_forma(v, js(b), FALSE, "stop", nome)
    if (!isTRUE(r$chiuso)) stop("GSE0 non chiude nella forma ", nome, ": ", unisci(r$motivi))
    stopifnot(r$valida, r$n_gruppi == 6L, nrow(r$confronti) == 7L, r$n_soggetti == 1L, sum(r$confronti$fattore == "compound") == 3L,
              sum(r$tabella$livelli$stage == TF_NON_APPLICABILE) == 4L, fattori_doppi(v, r$canonico) == 0L)
    firme[nome] <- firma_fattori(v, r$canonico)
    rotta <- function(cambia) adatta_forma(v, js(cambia(b)), FALSE, "stop", nome)
    stopifnot(identical(motivo(adatta_forma(v, NA_character_, TRUE, NA_character_, nome)), "oltre_contesto"),
              identical(motivo(adatta_forma(v, substr(js(b), 1, 200), FALSE, "length", nome)), c("troncata", "non_valida")),
              identical(motivo(adatta_forma(v, js(b), FALSE, "length", nome)), "troncata"),
              identical(motivo(rotta(function(x) { x$factors[[1]]$type <- "drug"; x })), "non_valida"),
              identical(motivo(rotta(function(x) { x$factors[[1]]$baseline_level <- "control"; x })), "base_assente"),
              identical(motivo(rotta(function(x) { x$extra <- 1; x })), "non_valida"))
    if (!is.null(b$columns)) {
      stopifnot(identical(motivo(rotta(function(x) { x$columns[[5]]$role <- "factor"; x })), "ruolo_incoerente"),
                identical(motivo(rotta(function(x) { x$columns[[3]]$role <- "uninformative"; x })), "ruolo_incoerente"))
    }
    liv1 <- function(x, valore) {                                 # cambia il livello della voce 2 del fattore 1 (IBD)
      a <- if (is.null(x$factors[[1]]$assignment$values)) x$factors[[1]]$assignment[[2]] else x$factors[[1]]$assignment$values[[2]]
      a$level <- valore
      if (is.null(x$factors[[1]]$assignment$values)) x$factors[[1]]$assignment[[2]] <- a else x$factors[[1]]$assignment$values[[2]] <- a
      x
    }
    if (isTRUE(sw$f1)) {
      # senza l'elenco `levels` un nome nuovo e' un livello nuovo; un riservato in altra forma chiude lo studio
      stopifnot(rotta(function(x) liv1(x, "ibd"))$chiuso,
                identical(motivo(rotta(function(x) liv1(x, "not_applicable"))), "riservato_altra_forma"))
    } else {
      stopifnot(identical(motivo(rotta(function(x) liv1(x, "ibd"))), "livello_assente"),
                identical(motivo(rotta(function(x) liv1(x, "not_applicable"))), "livello_assente"))
    }
  }
  stopifnot(length(unique(firme)) == 1L)                         # la stessa tabella dei fattori ha la stessa firma in ogni forma
  # i predicati vedono un errore messo apposta, in una forma per lato
  k <- adatta_forma(v, js(buona("B0")), FALSE, "stop", "B0")$canonico
  k$factors[[1]]$source_columns <- list("Sex"); stopifnot(isTRUE(predicati("GSE57945", k)), isTRUE(predicati("GSE60340", k)))
  k$factors[[1]]$source_columns <- list("treated with"); stopifnot(!predicati("GSE57945", k), !predicati("GSE60340", k), !predicati("GSE49155", k), !predicati("GSE46665", k))
  k$factors[[2]]$assignment[[1]]$when[[1]]$column <- "cell type"; stopifnot(!predicati("GSE49155", k))       # cella vuota -> not applicable: non e' l'errore
  k$factors[[2]]$assignment[[1]]$level <- "II"; stopifnot(isTRUE(predicati("GSE49155", k)))
  k$factors[[1]]$levels <- lapply(c("DCM_T0", "GCN", "HSD", "JDM", "nmn"), function(l) list(level = l)); stopifnot(isTRUE(predicati("GSE46665", k)))
  k$factors[[1]]$levels <- lapply(c("DCM", "GCN", "HSD", "ICM"), function(l) list(level = l)); stopifnot(!predicati("GSE46665", k))
  stopifnot(is.na(predicati("GSE57945", NULL)))
  cat(sprintf("10-forme.R: %d forme (%d lato A, %d lato B); prompt di A0 e B0 uguali ai file congelati byte per byte; schema di B0 = schema_studio(), schema di A0 = 20-schema-v1.json; GSE0 chiude con 6 gruppi e 7 confronti in ogni forma e con la stessa firma; i motivi e i predicati vedono gli errori messi apposta\n",
              length(FORME), sum(vapply(FORME, function(f) f$lato == "A", NA)), sum(vapply(FORME, function(f) f$lato == "B", NA))))
})

if (sys.nframe() == 0L) {
  for (nome in names(FORME)) scrivi_prompt(nome)
  cat("scritti", length(FORME), "prompt in", S4, "\n")
}
