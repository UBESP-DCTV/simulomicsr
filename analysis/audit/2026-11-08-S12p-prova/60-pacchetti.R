#!/usr/bin/env Rscript
# S12p, lettura dei falsi allarmi (decisione del PI, 2026-11-08: Gemma e Mistral). Costruisce i pacchetti di lettura,
# ciechi: identificativo opaco, ordine mescolato, nessun accession del confronto, fonti delle affermazioni anonime
# («Fonte 1», «Fonte 2», assegnate a caso per pacchetto). Insieme letto: falsi allarmi di Mistral o di Gemma, difetti
# presi da almeno uno dei due (controllo positivo), 60 puliti non accusati da nessun modello (misura della severita'
# dei lettori). La chiave (identificativo -> confronto, fonte -> modello) sta fuori dalla cartella dei lettori.
# Uso: Rscript analysis/audit/2026-11-08-S12p-prova/60-pacchetti.R <cartella-lettori> <file-chiave>
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-08-S12p-prova/aiuti.R")
a <- commandArgs(TRUE); OUT <- a[1]; CHIAVE <- a[2]; N_LOTTO <- 30L
if (dir.exists(OUT)) ferma("la cartella dei lettori esiste gia': %s", OUT)
dir.create(file.path(OUT, "pacchetti"), recursive = TRUE); dir.create(file.path(OUT, "risposte"))
df <- ingressi(); h5 <- H5_CAMPI(); ten <- TENUTI()
x <- readRDS("analysis/p4-output/S12p-uscite/40-conto.rds")
MOD <- c("mistral", "gemma")
fin <- lapply(setNames(MOD, MOD), function(k) { l <- readLines(file.path("analysis/p4-output/S12p-uscite", paste0(k, ".jsonl")), encoding = "UTF-8"); r <- lapply(l, fromJSON, simplifyVector = FALSE); setNames(r, vapply(r, `[[`, "", "record_id")) })
E <- lapply(setNames(MOD, MOD), function(k) { e <- x$esiti[[k]]; e[match(ten$record_id, e$record_id), ] })
rid <- ten$record_id; dif <- E$mistral$difettoso
acc <- sapply(MOD, function(k) E[[k]]$accusato); leggibile <- function(k) !(E[[k]]$motivi %in% c("INGRESSO_INCOMPLETO", "LISTA_NON_VALIDA"))
falsi <- (acc[, "mistral"] | acc[, "gemma"]) & !dif; presi <- (acc[, "mistral"] | acc[, "gemma"]) & dif
con_affermazioni <- (acc[, "mistral"] & leggibile("mistral")) | (acc[, "gemma"] & leggibile("gemma"))
acc_mag <- x$esiti$magistral$accusato[match(rid, x$esiti$magistral$record_id)]
set.seed(SEME); nessuno <- sample(which(!acc[, "mistral"] & !acc[, "gemma"] & !acc_mag & !dif), 60L)  # puliti che nessuno dei tre accusa
gruppo <- ifelse(falsi & con_affermazioni, "falso_allarme", ifelse(presi & con_affermazioni, "preso", NA_character_)); gruppo[nessuno] <- "non_accusato"
sel <- which(!is.na(gruppo)); cat(sprintf("pacchetti: %d (falsi allarmi %d, presi %d, non accusati %d)\n", length(sel), sum(gruppo == "falso_allarme", na.rm = TRUE), sum(gruppo == "preso", na.rm = TRUE), sum(gruppo == "non_accusato", na.rm = TRUE)))

ASSE_TXT <- c(material = "type of biological material", cell_line = "cell line", donor = "donor or subject", genotype = "genotype or genetic background",
              sex = "sex", age_or_stage = "age, developmental or differentiation stage", anatomical_site = "anatomical site", compartment = "cell population or fraction profiled",
              disease_or_condition = "disease or condition of the samples or donors", culture_conditions = "culture conditions", technique = "library or sequencing technique")
v <- function(z) if (is.null(z) || length(z) == 0L) "-" else paste(unlist(z), collapse = ", ")
q <- function(z) if (is.null(z)) "-" else sprintf("\"%s\"", z)
tempo <- function(ck) { ct <- ck$collection_time; b <- function(s) sprintf("   %s arm: time \"%s\"; hours [%s]; time zero: %s; quote %s", s, v(ct[[s]]$value_raw), v(ct[[s]]$hours), v(ct[[s]]$time_zero), q(ct[[s]]$evidence))
  c(b("treated"), b("control"), sprintf("   relation between arms: %s", v(ct$relation))) }
agenti <- function(ck, filtro = function(a) TRUE) { ag <- Filter(filtro, ck$agents); if (!length(ag)) return("   (no agent listed)")
  vapply(ag, function(a) sprintf("   agent \"%s\" (%s): in treated arm %s, in control arm %s; is the proposed entity: %s; quote %s", v(a$name), v(a$kind), v(a$in_treated), v(a$in_control), v(a$is_proposed_entity), q(a$evidence)), "") }
asse <- function(ck, n) { z <- ck$axes[[n]]; sprintf("   %s: relation %s; treated \"%s\" (quote %s); control \"%s\" (quote %s)", ASSE_TXT[[n]], v(z$relation), v(z$treated), q(z$evidence_treated), v(z$control), q(z$evidence_control)) }
nv <- function(a) .s2b_chr(a$kind) != "vehicle_or_mock"
COD <- setNames(names(.S2B_ASSI), unname(.S2B_ASSI))
afferma <- function(s, ck, tec) {
  if (s == "TEMPO_ZERO") return(c("The control arm was harvested at time zero (before or at the start of the perturbation) and the treated arm was not.", tempo(ck)))
  if (s == "TEMPO_DIVERSO") return(c("The two arms were harvested at different times after the start of the perturbation.", tempo(ck)))
  if (s == "SECONDO_AGENTE") return(c("The treated arm received at least two agents that the control arm did not receive, and at least one of them is not the proposed entity.", agenti(ck, nv)))
  if (s == "AGENTE_SOLO_CONTROLLO") return(c("An agent (not a vehicle) was applied to the control arm and not to the treated arm.", agenti(ck, nv)))
  if (s == "BRACCIO_MISTO") return(c("An agent (not a vehicle) was applied to only some samples of one arm.", agenti(ck, nv)))
  if (s == "NESSUNA_DIFFERENZA") return(c("Nothing distinguishes the two arms: no agent only in the treated arm and no different disease or condition.", agenti(ck), asse(ck, "disease_or_condition")))
  if (s == "ENTITA_DIVERSA") return(c("What distinguishes the treated arm from the control arm is NOT the proposed entity.", sprintf("   quote: %s; what distinguishes the arms: \"%s\" (%s)", q(ck$proposed_entity$evidence), v(ck$isolated_difference$name), v(ck$isolated_difference$kind))))
  if (s == "CONDIZIONE_CON_AGENTE") return(c("The arms differ both by an agent applied only to the treated arm AND by the disease or condition of the samples or donors.", agenti(ck, nv), asse(ck, "disease_or_condition")))
  if (s == "PARZIALE_CONDIZIONE") return(c("The arms share some values of disease or condition but not all.", asse(ck, "disease_or_condition")))
  if (startsWith(s, "DIVERSO_")) { n <- COD[[sub("^DIVERSO_", "", s)]]; return(c(sprintf("The arms differ in %s: no value in common.", ASSE_TXT[[n]]), asse(ck, n))) }
  if (startsWith(s, "PARZIALE_")) { n <- COD[[sub("^PARZIALE_", "", s)]]; return(c(sprintf("The arms share some values of %s but not all.", ASSE_TXT[[n]]), asse(ck, n))) }
  if (startsWith(s, "TECNICA_H5_")) return(c("(Computed by code from structured GEO fields, not by a reader.) A technical field has different values in the two arms.", tec))
  if (s == "ALTRA_DIFFERENZA") return(c("Other systematic difference(s) between the arms:", vapply(ck$other_differences, function(o) sprintf("   - %s (treated quote %s; control quote %s)", v(o$description), q(o$evidence_treated), q(o$evidence_control)), "")))
  ferma("segnale senza affermazione: %s", s)
}
tecnica_txt <- function(i) { t <- ten[i, ]; gt <- strsplit(t$gsm_t, ",")[[1]]; gc <- strsplit(t$gsm_c, ",")[[1]]
  vapply(.S2B_CAMPI_TECNICI_H5, function(f) sprintf("   %s: treated [%s]; control [%s]", f, paste(unique(h5[[f]][match(gt, h5$geo_accession)]), collapse = " | "), paste(unique(h5[[f]][match(gc, h5$geo_accession)]), collapse = " | ")), "") }

set.seed(SEME + 1L); ordine <- sample(sel); ids <- sprintf("L%04d", seq_along(ordine))
chiave <- list(); dimensioni <- integer()
for (j in seq_along(ordine)) {
  i <- ordine[j]; r <- rid[i]; fonti <- sample(MOD); righe <- character(); nfonte <- 0L; naff <- 0L; mappa <- list()
  for (k in fonti) {
    if (!acc[i, k] || !leggibile(k)[i]) next
    ck <- fromJSON(fin[[k]][[r]]$raw, simplifyVector = FALSE); mot <- strsplit(E[[k]]$motivi[i], " ")[[1]]; mot <- mot[nzchar(mot) & !mot %in% c("INGRESSO_INCOMPLETO", "LISTA_NON_VALIDA")]
    nfonte <- nfonte + 1L; righe <- c(righe, "", sprintf("## Source %d", nfonte))
    for (s in mot) { naff <- naff + 1L; righe <- c(righe, sprintf("[claim %d] %s", naff, afferma(s, ck, tecnica_txt(i))[1]), afferma(s, ck, tecnica_txt(i))[-1]); mappa[[length(mappa) + 1L]] <- list(claim = naff, fonte = nfonte, modello = k, segnale = s) }
  }
  testo <- df$testo[match(r, df$record_id)]
  corpo <- c(sprintf("# Packet %s", ids[j]), "", testo, "", "# Claims to check",
             if (naff == 0L) "(no claim: judge only whether the comparison is comparable)" else righe)
  con <- file(file.path(OUT, "pacchetti", paste0(ids[j], ".txt")), open = "w", encoding = "UTF-8"); writeLines(corpo, con, useBytes = TRUE); close(con)
  dimensioni[ids[j]] <- sum(nchar(corpo))
  chiave[[j]] <- list(id = ids[j], record_id = r, gruppo = gruppo[i], difettoso = dif[i], accusato_mistral = acc[i, "mistral"], accusato_gemma = acc[i, "gemma"], affermazioni = mappa)
}
# Lotti bilanciati per lunghezza: i pacchetti in ordine di lunghezza decrescente, assegnati a turno.
nl <- ceiling(length(ids) / N_LOTTO); o <- names(sort(dimensioni, decreasing = TRUE)); lotto <- setNames(((seq_along(o) - 1L) %% nl) + 1L, o)
for (b in seq_len(nl)) writeLines(sort(names(lotto)[lotto == b]), file.path(OUT, sprintf("lotto-%02d.txt", b)))
write_json(chiave, CHIAVE, auto_unbox = TRUE, pretty = TRUE)
cat(sprintf("lotti: %d; caratteri per lotto: da %d a %d\n", nl, min(tapply(dimensioni[names(lotto)], lotto, sum)), max(tapply(dimensioni[names(lotto)], lotto, sum))))
cat(sprintf("pacchetto piu' lungo: %d caratteri; mediana %d\n", max(dimensioni), as.integer(median(dimensioni))))
