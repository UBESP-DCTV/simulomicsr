# EQUIVALENZA fra le regole dello script d'analisi (103-fase1-v10-gate.R) e quelle
# portate nel codice di pacchetto (R/stage3-contrast-gate.R, R/stage3-row-pairing.R).
#
# Non basta che i test passino: le due implementazioni devono dare la STESSA
# risposta su tutte le etichette vere, altrimenti l'innesto in produzione
# cambierebbe i risultati in silenzio.
suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
suppressPackageStartupMessages(devtools::load_all(".", quiet = TRUE))
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

## carica SOLO le definizioni dello script (tutto cio' che precede il LOOP)
src <- readLines(file.path(SC, "103-fase1-v10-gate.R"))
stop_at <- grep("^## =+ LOOP", src)[1]
tmp <- tempfile(fileext = ".R")
writeLines(src[seq_len(stop_at - 1L)], tmp)
source(tmp, local = TRUE)   # definisce is_generic_tok, verso_of, ... e carica oe

pm <- readRDS(file.path(SC, "fase1-pm2.rds"))
tl <- pm$treated_label; cl <- pm$control_label
u <- unique(c(tl, cl)); u <- u[!is.na(u)]
cat("etichette distinte:", length(u), " | coppie:", nrow(pm), "\n\n")

check <- function(nome, a, b, inputs = NULL) {
  a <- unname(a); b <- unname(b)
  d <- which(a != b | is.na(a) != is.na(b))
  cat(sprintf("%-28s %s (%d differenze su %d)\n", nome,
              ifelse(length(d) == 0, "UGUALI", "DIVERSE"), length(d), length(a)))
  if (length(d)) {
    inp <- if (is.null(inputs)) rep("", length(d)) else substr(inputs[d], 1, 60)
    print(utils::head(data.frame(input = inp, script = a[d], pacchetto = b[d]), 6), row.names = FALSE)
  }
  length(d)
}
tot <- 0L
tot <- tot + check("token generico",
                   vapply(u, is_generic_tok, logical(1)),
                   vapply(u, .cg_is_generic_token, logical(1)), u)
tot <- tot + check("induttore",
                   vapply(u, is_inducer_name, logical(1)),
                   vapply(u, .cg_is_inducer, logical(1)), u)
tot <- tot + check("verso del delta",
                   vapply(pm$dtval, verso_of, ""),
                   vapply(pm$dtval, .cg_direction, ""), pm$dtval)
tot <- tot + check("anatomia (concatenata)",
                   vapply(u, function(z) paste(sort(anatomy_of(z)), collapse = ","), ""),
                   vapply(u, function(z) paste(sort(.cg_anatomy(z)), collapse = ","), ""), u)
tot <- tot + check("materiale del braccio",
                   vapply(u, function(z) material_arm(z, ""), ""),
                   vapply(u, function(z) .cg_material_arm(z, ""), ""))
tot <- tot + check("baseline propria",
                   vapply(u, baseline_kind, ""),
                   vapply(u, .cg_baseline_kind, ""), u)
tot <- tot + check("resistenza asimmetrica",
                   mapply(resistance_mismatch, tl, cl),
                   mapply(.cg_resistance_mismatch, tl, cl))
tot <- tot + check("controllo non valido",
                   grepl(NONCONTROL_RX, tolower(cl), perl = TRUE),
                   vapply(cl, .cg_is_noncontrol, logical(1)), cl)
tot <- tot + check("delta multiclasse",
                   vapply(pm$dclasses, is_multiclass, logical(1)),
                   vapply(pm$dclasses, .cg_is_multiclass, logical(1)))
tot <- tot + check("contrasto rotto",
                   mapply(broken_contrast, tl, cl, pm$treated_fl, pm$control_fl),
                   mapply(.cg_broken_contrast, tl, cl, pm$treated_fl, pm$control_fl), paste(tl, "=>", cl))
tot <- tot + check("contesto d'infezione",
                   mapply(function(a, b) infection_ctx("infection", a, b), cl, tl),
                   mapply(function(a, b) .cg_infection_context("infection", a, b), cl, tl), paste(tl, "=>", cl))
tot <- tot + check("nome ombrello",
                   grepl(UMBRELLA_NAME_RX, tolower(u)),
                   vapply(u, .cg_is_umbrella_name, logical(1)), u)
tot <- tot + check("token distintivi",
                   vapply(pm$canonical_name, function(z) paste(sort(distinctive_toks(z)), collapse = ","), ""),
                   vapply(pm$canonical_name, function(z) paste(sort(.cg_distinctive_tokens(z)), collapse = ","), ""))
onc_s <- mapply(function(nm, tv) match_all_words(distinctive_toks(nm), tv), pm$canonical_name, pm$dtval)
onc_p <- mapply(function(nm, tv) .cg_matches_all_words(.cg_distinctive_tokens(nm), tv), pm$canonical_name, pm$dtval)
tot <- tot + check("entita' on-contrast", onc_s, onc_p)

## regole di riga: script (regole-riga.R) vs pacchetto (R/stage3-row-pairing.R)
source(file.path(SC, "regole-riga.R"), local = TRUE)
tot <- tot + check("riga: tempo",
                   mapply(rr_tempo_non_appaiato, tl, cl),
                   mapply(.rp_time_mismatch, tl, cl), paste(tl, "=>", cl))
tot <- tot + check("riga: soggetto/linea",
                   mapply(function(a, b, c) rr_soggetto_diverso(a, b, c), tl, cl, pm$ce2_cls %||% "drug"),
                   mapply(function(a, b, c) .rp_subject_mismatch(a, b, c), tl, cl, pm$ce2_cls %||% "drug"), paste(tl, "=>", cl))
tot <- tot + check("riga: genetica",
                   mapply(function(a, b) rr_genetica_asimmetrica(a, b, "drug", NA_character_), tl, cl),
                   mapply(function(a, b) .rp_genetic_asymmetry(a, b, "drug", NA_character_), tl, cl), paste(tl, "=>", cl))

cat(sprintf("\n=== TOTALE DIFFERENZE: %d ===\n", tot))
if (tot == 0L) cat("le due implementazioni sono equivalenti su tutte le etichette vere\n")
