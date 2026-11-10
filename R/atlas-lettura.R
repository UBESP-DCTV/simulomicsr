# Expression Atlas (EBI): lettura dei file dei curatori e tabella dei fattori.
#
# Per ogni studio Atlas pubblica due file:
#  - `<accession>-configuration.xml`: i gruppi di run (`assay_group`) e i
#    confronti (`contrast`), ognuno con un gruppo di riferimento e uno di test;
#  - `<accession>.condensed-sdrf.tsv`: per ogni run, le caratteristiche e i
#    fattori scelti dai curatori.
# Sono il termine di paragone del cancello di ADR-0029.

#' Legge la configurazione di uno studio di Expression Atlas
#'
#' @param path Percorso di `<accession>-configuration.xml`.
#' @param solo_id Se `TRUE` non legge le etichette dei gruppi (`label`) e i nomi
#'   dei confronti (`<name>`): le colonne `etichetta` e `nome` sono `NA`. E' la
#'   sola forma ammessa per uno studio di giudizio.
#' @return Lista con `gruppi` (`gruppo`, `etichetta`, `run`: una riga per coppia
#'   gruppo-run) e `confronti` (`id`, `nome`, `riferimento`, `test`).
#' @keywords internal
atlas_leggi_configurazione <- function(path, solo_id = FALSE) {
  rlang::check_installed("xml2")
  if (!file.exists(path)) {
    .tf_abort(sprintf("File di configurazione di Atlas non trovato: %s", path), "atlas_file_mancante")
  }
  doc <- xml2::read_xml(path)

  nodi_gruppo <- xml2::xml_find_all(doc, ".//assay_group")
  gruppi <- lapply(nodi_gruppo, function(nodo) {
    run <- trimws(xml2::xml_text(xml2::xml_find_all(nodo, "./assay")))
    data.frame(gruppo = rep(xml2::xml_attr(nodo, "id"), length(run)),
               etichetta = rep(if (solo_id) NA_character_ else xml2::xml_attr(nodo, "label"), length(run)),
               run = run, stringsAsFactors = FALSE)
  })
  gruppi <- do.call(rbind, c(list(data.frame(gruppo = character(0), etichetta = character(0),
                                             run = character(0), stringsAsFactors = FALSE)), gruppi))
  # Uno studio con piu' blocchi `analytics` ripete i gruppi: una riga per coppia.
  gruppi <- gruppi[!duplicated(gruppi[c("gruppo", "run")]), , drop = FALSE]
  rownames(gruppi) <- NULL
  if (anyNA(gruppi$gruppo) || any(!nzchar(gruppi$run))) {
    .tf_abort(sprintf("Configurazione di Atlas con un gruppo senza `id` o un run vuoto: %s", path),
              "atlas_configurazione_non_valida")
  }

  testo_figlio <- function(nodo, nome) {
    x <- xml2::xml_find_first(nodo, paste0("./", nome))
    if (inherits(x, "xml_missing")) NA_character_ else trimws(xml2::xml_text(x))
  }
  nodi_confronto <- xml2::xml_find_all(doc, ".//contrast")
  confronti <- lapply(nodi_confronto, function(nodo) {
    data.frame(id = xml2::xml_attr(nodo, "id"),
               nome = if (solo_id) NA_character_ else testo_figlio(nodo, "name"),
               riferimento = testo_figlio(nodo, "reference_assay_group"),
               test = testo_figlio(nodo, "test_assay_group"), stringsAsFactors = FALSE)
  })
  confronti <- do.call(rbind, c(list(data.frame(id = character(0), nome = character(0),
                                                riferimento = character(0), test = character(0),
                                                stringsAsFactors = FALSE)), confronti))
  confronti <- confronti[!duplicated(confronti[c("id", "riferimento", "test")]), , drop = FALSE]
  rownames(confronti) <- NULL
  if (anyNA(confronti$riferimento) || anyNA(confronti$test) || anyDuplicated(confronti$id)) {
    .tf_abort(sprintf("Configurazione di Atlas con un confronto senza gruppi o con `id` ripetuto: %s", path),
              "atlas_configurazione_non_valida")
  }
  ignoti <- setdiff(c(confronti$riferimento, confronti$test), gruppi$gruppo)
  if (length(ignoti)) {
    .tf_abort(sprintf("Configurazione di Atlas: i confronti nominano gruppi che non esistono (%s): %s",
                      .tf_elenca(ignoti), path),
              "atlas_configurazione_non_valida")
  }
  list(gruppi = gruppi, confronti = confronti)
}

#' Legge l'SDRF condensato di uno studio di Expression Atlas
#'
#' Il file e' separato da tabulazioni e non ha intestazione. Le colonne lette
#' sono la 3 (run), la 4 (ruolo), la 5 (nome) e la 6 (valore).
#'
#' @param path Percorso di `<accession>.condensed-sdrf.tsv`.
#' @return `data.frame` con `run`, `ruolo` (`characteristic` | `factor`), `nome`, `valore`.
#' @keywords internal
atlas_leggi_sdrf <- function(path) {
  if (!file.exists(path)) {
    .tf_abort(sprintf("SDRF di Atlas non trovato: %s", path), "atlas_file_mancante")
  }
  righe <- readLines(path, warn = FALSE, encoding = "UTF-8")
  righe <- righe[nzchar(trimws(righe))]
  campi <- strsplit(righe, "\t", fixed = TRUE)
  corte <- lengths(campi) < 6L
  if (any(corte)) {
    .tf_abort(sprintf("SDRF di Atlas con %d righe da meno di 6 colonne (prima: riga %d): %s",
                      sum(corte), which(corte)[1], path),
              "atlas_sdrf_non_valido")
  }
  out <- data.frame(run = vapply(campi, `[[`, "", 3L), ruolo = vapply(campi, `[[`, "", 4L),
                    nome = vapply(campi, `[[`, "", 5L), valore = vapply(campi, `[[`, "", 6L),
                    stringsAsFactors = FALSE)
  ignoti <- setdiff(unique(out$ruolo), c("characteristic", "factor"))
  if (length(ignoti)) {
    .tf_abort(sprintf("SDRF di Atlas con ruoli non previsti (%s): %s", .tf_elenca(ignoti), path),
              "atlas_sdrf_non_valido")
  }
  out
}

#' La tabella dei fattori dei curatori di Atlas, sui nostri campioni
#'
#' Porta i gruppi e i confronti di Atlas dai run (SRR) ai campioni (GSM). Piu'
#' run dello stesso campione si riducono al campione. Un campione in due gruppi
#' di Atlas ferma lo studio con un errore. Un fattore che i curatori non
#' scrivono per un run (la dose del controllo non trattato) ha il livello
#' `TF_NON_SCRITTO`. Un run senza nessun fattore ferma lo studio.
#'
#' @param config Uscita di [atlas_leggi_configurazione()].
#' @param sdrf Uscita di [atlas_leggi_sdrf()].
#' @param legame `data.frame` con `run` e `gsm`. Se ha la colonna `gse` con un
#'   solo valore, quel valore diventa la colonna `studio` dei confronti.
#' @return Lista con:
#'   - `tabella`: una `simulomicsr_tf_tabella` sui GSM dei gruppi di Atlas, un
#'     fattore per ogni `factor` dell'SDRF, tipo `"contesto"` e `base = NA`
#'     (Atlas non dichiara un livello di base: lo da' il confronto). `NULL` se
#'     nessun run ha un GSM;
#'   - `partizione`: vettore con nome, GSM -> gruppo di Atlas;
#'   - `confronti`: forma comune (`studio`, `id`, `trattato`, `controllo`), piu'
#'     `nome`, `riferimento` e `test`. Il gruppo di riferimento e' il controllo;
#'   - `esclusi`: i run dei gruppi senza GSM (`run`, `gruppo`).
#' @keywords internal
atlas_tabella <- function(config, sdrf, legame) {
  if (!is.data.frame(legame) || !all(c("run", "gsm") %in% names(legame))) {
    .tf_abort("`legame` deve essere un data.frame con le colonne `run` e `gsm`.", "ingresso_non_valido")
  }
  legame <- legame[!is.na(legame$gsm) & nzchar(legame$gsm), , drop = FALSE]
  legame <- legame[!duplicated(legame[c("run", "gsm")]), , drop = FALSE]
  doppi <- unique(legame$run[duplicated(legame$run)])
  if (length(doppi)) {
    .tf_abort(sprintf("Run legati a piu' di un GSM: %s.", .tf_elenca(doppi)), "atlas_run_con_due_gsm")
  }
  studio <- if ("gse" %in% names(legame) && length(unique(legame$gse)) == 1L) {
    as.character(legame$gse[1])
  } else {
    NA_character_
  }

  gruppi <- config$gruppi
  gruppi$gsm <- legame$gsm[match(gruppi$run, legame$run)]
  esclusi <- gruppi[is.na(gruppi$gsm), c("run", "gruppo"), drop = FALSE]
  rownames(esclusi) <- NULL
  gruppi <- gruppi[!is.na(gruppi$gsm), , drop = FALSE]

  # Un GSM in due gruppi di Atlas: lo studio si ferma (Review Focus 2).
  per_gsm <- unique(gruppi[c("gsm", "gruppo")])
  in_due <- unique(per_gsm$gsm[duplicated(per_gsm$gsm)])
  if (length(in_due)) {
    .tf_abort(sprintf("GSM in piu' di un gruppo di Atlas: %s.", .tf_elenca(in_due)),
              "atlas_gsm_in_due_gruppi")
  }
  partizione <- stats::setNames(per_gsm$gruppo, per_gsm$gsm)

  # I livelli dei fattori, run per run, poi ridotti al GSM.
  fatt <- sdrf[sdrf$ruolo == "factor", c("run", "nome", "valore"), drop = FALSE]
  fatt <- unique(fatt)
  # Un valore vuoto vale come un valore assente.
  fatt <- fatt[!is.na(fatt$valore) & nzchar(fatt$valore), , drop = FALSE]
  nomi_fattori <- sort(unique(fatt$nome[fatt$run %in% gruppi$run]), method = "radix")
  # Un run senza nessun fattore non e' un caso dei curatori: l'SDRF non lo descrive, lo studio si ferma.
  nudi <- setdiff(unique(gruppi$run), fatt$run)
  if (length(nudi) && length(nomi_fattori)) {
    .tf_abort(sprintf("Run di Atlas senza nessun fattore nell'SDRF: %s.", .tf_elenca(nudi)),
              "atlas_run_senza_fattori")
  }
  tabella <- NULL
  if (nrow(gruppi) > 0L) {
    campioni <- per_gsm$gsm
    livelli <- data.frame(row.names = campioni)
    for (nome in nomi_fattori) {
      f <- fatt[fatt$nome == nome, , drop = FALSE]
      valore_run <- f$valore[match(gruppi$run, f$run)]
      # I curatori non scrivono un fattore dove non si applica (la dose del controllo non trattato):
      # il livello e' `TF_NON_SCRITTO`, come nella tabella dei fattori del lettore.
      valore_run[is.na(valore_run)] <- TF_NON_SCRITTO
      piu_valori <- unique(f$run[duplicated(f$run)])
      piu_valori <- intersect(piu_valori, gruppi$run)
      per_campione <- tapply(valore_run, gruppi$gsm, function(v) length(unique(v)))
      if (length(piu_valori) || any(per_campione > 1L)) {
        .tf_abort(sprintf("Il fattore `%s` di Atlas ha piu' valori per lo stesso run o GSM: %s.", nome,
                          .tf_elenca(c(piu_valori, names(per_campione)[per_campione > 1L]))),
                  "atlas_gsm_livelli_diversi")
      }
      livelli[[nome]] <- valore_run[match(campioni, gruppi$gsm)]
    }
    if (length(nomi_fattori) == 0L) {
      .tf_abort(sprintf("Nessun fattore nell'SDRF di Atlas per i run dei gruppi: %s.",
                        .tf_elenca(gruppi$run)),
                "atlas_run_senza_fattori")
    }
    fattori <- data.frame(nome = nomi_fattori, tipo = rep("contesto", length(nomi_fattori)),
                          base = rep(NA_character_, length(nomi_fattori)), stringsAsFactors = FALSE)
    tabella <- tf_tabella(campioni, livelli, fattori)
  }

  membri <- function(g) sort(unname(per_gsm$gsm[per_gsm$gruppo == g]), method = "radix")
  k <- config$confronti
  confronti <- data.frame(studio = rep(studio, nrow(k)), id = k$id, nome = k$nome,
                          riferimento = k$riferimento, test = k$test, stringsAsFactors = FALSE)
  confronti$trattato <- lapply(k$test, membri)
  confronti$controllo <- lapply(k$riferimento, membri)

  list(tabella = tabella, partizione = partizione, confronti = confronti, esclusi = esclusi)
}
