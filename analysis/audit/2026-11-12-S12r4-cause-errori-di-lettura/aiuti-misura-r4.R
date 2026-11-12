# PROVA DA BUTTARE
# aiuti-misura-r4.R — S12r4: la misura di una corsa in una forma qualunque (10-forme.R), con le misure di S12r3
# (riferimento a 95 confronti, la misura su 97 accanto) e col conto degli errori su gruppi e fattori.
# `source()` dopo devtools::load_all("."). Legge SOLO i 47 studi di sviluppo: gli 82 di giudizio restano chiusi.
source("analysis/audit/2026-11-11-S12r3-elenco-chiuso/aiuti-misura-r3.R")   # R2, R3, misure di S12r3, viste
SEME <- 20261112L                                             # depositato in 00-previsioni.md (la data della sessione)
B <- 2000L
source(file.path(R2, "22-adattatore-v1.R"))                   # passa da solo il suo controllo positivo
source("analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/10-forme.R")
USCITE_R4 <- "analysis/p4-output/S12r4-forme"
scrivi_r4 <- function(d, f) utils::write.csv(d, file.path(S4, f), row.names = FALSE, na = "")
nullo <- function(x) if (is.null(x)) NA else x
e_saltato <- function(x) { s <- x$saltato; !is.null(s) && !is.na(s) && nzchar(as.character(s)) }
sha <- function(f) unname(digest::digest(file = f, algo = "sha256"))

sv <- studi_di_sviluppo(); rif <- atlas_di_sviluppo(sv); viste <- leggi_viste(sv)
stopifnot(nrow(sv) == 47L)
campi <- stats::setNames(lapply(sv$gse, function(g) campi_tempo_studio(rif[[g]], viste[[g]])), sv$gse)

# Le uscite congelate di una corsa: una riga per studio, tutti e soli i 47 studi di sviluppo.
leggi_uscite <- function(f) {
  stopifnot(file.exists(f))
  x <- leggi_jsonl(f); names(x) <- vapply(x, `[[`, "", "record_id")
  if (!setequal(names(x), sv$gse) || anyDuplicated(names(x)))
    stop(sprintf("CANCELLO: %s copre %d studi di sviluppo su 47 e %d righe fuori", f, length(intersect(names(x), sv$gse)),
                 length(setdiff(names(x), sv$gse))), call. = FALSE)
  x[sv$gse]
}
uguali_al_carattere <- function(a, b) vapply(sv$gse, function(g)
  identical(as.character(nullo(a[[g]]$raw)), as.character(nullo(b[[g]]$raw))) && identical(e_saltato(a[[g]]), e_saltato(b[[g]])), NA)

# La misura di una corsa nella forma `nome`. Ritorna le letture (adatta_forma), le righe per studio nelle quattro
# misure di S12r3, il riassunto e una tabella per studio con stato, predicati, firma e conti dei fattori.
misura_forma <- function(cx, nome) {
  lett <- stats::setNames(lapply(sv$gse, function(g) adatta_forma(viste[[g]], as.character(nullo(cx[[g]]$raw)), e_saltato(cx[[g]]),
                                                                  as.character(nullo(cx[[g]]$fine)), nome)), sv$gse)
  mm <- stats::setNames(lapply(sv$gse, function(g) {
    x <- rif[[g]]; r <- lett[[g]]
    t <- if (r$chiuso) misura_r3(g, r$partizione, confronti_comuni(g, r$confronti), x, campi[[g]]) else
      misura_r3(g, character(0), CONFRONTI_VUOTI(g), x, campi[[g]])
    for (m in NOMI_R3) {
      if (!r$chiuso) t[[m]]$riga$classe_gruppi <- "non_chiuso"
      t[[m]]$riga$chiuso <- r$chiuso
      t[[m]]$riga$n_gruppi_lettore <- if (r$chiuso) length(unique(r$partizione[names(r$partizione) %in% x$universo])) else 0L
      t[[m]]$riga$n_gruppi_atlas <- length(unique(x$atlas$partizione[names(x$atlas$partizione) %in% x$universo]))
    }
    t
  }), sv$gse)
  per_studio <- stats::setNames(lapply(NOMI_R3, function(m) do.call(rbind, lapply(mm, function(x) x[[m]]$riga))), NOMI_R3)
  stopifnot(all(vapply(per_studio, nrow, 0L) == 47L))         # ogni misura copre 47 studi
  misure <- lapply(per_studio, tf_riassumi_misure, B = B, seme = SEME)
  p <- per_studio$principale
  tab <- data.frame(
    forma = nome, studio = sv$gse,
    valida = vapply(lett, function(r) isTRUE(r$valida), NA),
    chiuso = vapply(lett, `[[`, TRUE, "chiuso"),
    stato = ifelse(!p$chiuso, "non chiuso", ifelse(p$classe_gruppi %in% "identica", "identica", "diversa")),
    classe_gruppi = p$classe_gruppi, n_gruppi_lettore = p$n_gruppi_lettore, n_gruppi_atlas = p$n_gruppi_atlas,
    n_b_den = p$n_b_den, n_b_uguale = p$n_b_uguale, n_giudicabili = p$n_giudicabili, n_errori = p$n_errori,
    n_b_den97 = per_studio$principale97$n_b_den, n_b_uguale97 = per_studio$principale97$n_b_uguale,
    n_fattori = vapply(lett, function(r) if (is.null(r$canonico)) NA_integer_ else length(r$canonico$factors), 0L),
    fonti = vapply(lett, function(r) if (is.null(r$canonico)) NA_character_ else
      unisci(vapply(r$canonico$factors, function(f) sprintf("%s:%s", f$type, paste(fonti_f(f), collapse = "+")), ""), " | "), ""),
    soggetti = vapply(lett, function(r) if (is.null(r$canonico)) NA_character_ else
      unisci(vapply(Filter(function(x) identical(x$role, "subject"), r$canonico$other_columns), function(x) sprintf("%s:%s", x$column, x$subject_kind), ""), " | "), ""),
    fattori_doppi = vapply(sv$gse, function(g) if (lett[[g]]$chiuso) fattori_doppi(viste[[g]], lett[[g]]$canonico) else NA_integer_, 0L),
    firma = vapply(sv$gse, function(g) firma_fattori(viste[[g]], lett[[g]]$canonico), ""),
    soggetto_costante_nei_gruppi = vapply(sv$gse, function(g) if (lett[[g]]$chiuso) unisci(soggetti_costanti(viste[[g]], lett[[g]]$canonico, lett[[g]]$partizione)) else NA_character_, ""),
    errore_di_lettura = vapply(sv$gse, function(g) if (g %in% QUATTRO) as.logical(predicati(g, lett[[g]]$canonico)) else NA, NA),
    motivi = vapply(lett, function(r) unisci(nomi_motivi(r)), ""),
    motivi_estesi = vapply(lett, function(r) substr(unisci(r$motivi, " || "), 1L, 600L), ""),
    note = vapply(lett, function(r) unisci(unique(sub(":.*$", "", r$note))), ""),
    fine = vapply(sv$gse, function(g) as.character(nullo(cx[[g]]$fine)), ""),
    n_out = vapply(sv$gse, function(g) as.numeric(nullo(cx[[g]]$n_out)), 0),
    stringsAsFactors = FALSE, row.names = NULL)
  # Le unita' di disaccordo, come in S12r2 e S12r3 (misura principale, 95 confronti): uno studio non chiuso; una
  # partizione non identica; un confronto di Atlas del denominatore non ritrovato; un confronto del lettore fra i
  # non elencati giudicato errore. `chiave` e' stabile fra le forme: l'id di Atlas, oppure i campioni dei due bracci.
  ERRORI_C <- c("piu_fattori", "braccio_misto")
  camp <- function(x) vapply(x, function(y) paste(sort(as.character(unlist(y))), collapse = ","), "")
  unita <- do.call(rbind, lapply(sv$gse, function(g) {
    i <- match(g, tab$studio); k <- mm[[g]]$principale$atlas; ne <- mm[[g]]$principale$non_elencati
    u <- list()
    if (!tab$chiuso[i]) u[[1]] <- data.frame(tipo = "studio_non_chiuso", studio = g, id = "", chiave = "", nome = substr(tab$motivi_estesi[i], 1L, 200L))
    else if (tab$stato[i] != "identica") u[[1]] <- data.frame(tipo = "partizione_non_identica", studio = g, id = "", chiave = "", nome = paste("classe", tab$classe_gruppi[i]))
    kn <- k[k$in_b & k$ritrovato != "uguale", ]
    if (nrow(kn)) u[[2]] <- data.frame(tipo = "atlas_non_ritrovato", studio = g, id = as.character(kn$id), chiave = as.character(kn$id), nome = kn$nome)
    ee <- if (is.null(ne) || !nrow(ne)) NULL else ne[ne$giudizio %in% ERRORI_C, ]
    if (!is.null(ee) && nrow(ee)) u[[3]] <- data.frame(tipo = "lettore_errore", studio = g, id = as.character(ee$id),
      chiave = vapply(seq_len(nrow(ee)), function(j) substr(digest::digest(paste(camp(ee$trattato[j]), camp(ee$controllo[j]), sep = "|"), algo = "sha256", serialize = FALSE), 1L, 12L), ""),
      nome = sprintf("confronto del lettore %s (%d/%d), giudizio %s", ee$id, lengths(ee$trattato), lengths(ee$controllo), ee$giudizio))
    if (length(u)) do.call(rbind, Filter(Negate(is.null), u)) else NULL
  }))
  if (is.null(unita)) unita <- data.frame(tipo = character(0), studio = character(0), id = character(0), chiave = character(0), nome = character(0))
  unita <- cbind(forma = rep(nome, nrow(unita)), unita, stringsAsFactors = FALSE); rownames(unita) <- NULL
  stopifnot(sum(unita$tipo == "atlas_non_ritrovato") == sum(tab$n_b_den - tab$n_b_uguale), sum(unita$tipo == "lettore_errore") == sum(tab$n_errori))
  tab$n_unita <- as.integer(table(factor(unita$studio, levels = sv$gse)))
  tab$unita <- vapply(sv$gse, function(g) unisci(sort(paste(unita$tipo[unita$studio == g], unita$chiave[unita$studio == g], sep = ":")), " "), "")
  list(lett = lett, per_studio = per_studio, misure = misure, tab = tab, unita = unita)
}
# I tre numeri di una corsa: chiusi, gruppi identici, confronti ritrovati a 95 (e a 97).
tre_numeri <- function(tab) c(chiusi = sum(tab$chiuso), identici = sum(tab$stato == "identica"), ritrovati = sum(tab$n_b_uguale),
                              den = sum(tab$n_b_den), ritrovati97 = sum(tab$n_b_uguale97), den97 = sum(tab$n_b_den97),
                              errori_c = sum(tab$n_errori), giudicabili_c = sum(tab$n_giudicabili))
