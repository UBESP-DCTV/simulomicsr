#!/usr/bin/env Rscript
# 46-nomi-e-anchor.R — S9, dopo la prima risposta del PI: il calcitriolo, le
# meta-analisi con due nomi, e perche' l'anchor non le unisce. Ogni numero del §11
# del finding viene da qui (46-out.txt).
#
#  A. Come il dizionario risolve le forme del calcitriolo.
#  B. Dove finiscono oggi i confronti che nominano il calcitriolo.
#  C. Coppie candidate di meta-analisi con lo stesso verso e controllo (dal nome).
#  D. Anchor e fonte dell'entita' nei gruppi irradiation, radiation, ifna, IFNA1,
#     calcitriol, 1 25 oh 2d3.
#  E. Nel master dello Stadio 1: il nome scritto dal modello contro l'ID scritto dal
#     modello, per gli ID degli anchor assurdi.
#
# Uso: Rscript analysis/audit/2026-11-07-S9-greche-e-corsie/46-nomi-e-anchor.R
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE) })
OUT <- "analysis/audit/2026-11-07-S9-greche-e-corsie"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
S1  <- "analysis/p4-output/A3-stage1-master-innestato.jsonl"
r   <- readRDS(file.path(OUT, "30-due-regimi.rds"))
ing <- readRDS(file.path(OUT, "20-ingressi.rds"))
d   <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
q40 <- read.csv("analysis/audit/2026-11-03-S5-gate-e-insiemi/80-insieme-40.csv", stringsAsFactors = FALSE)
onto <- simulomicsr:::.load_ontology_dicts()
L <- character(0); say <- function(...) { s <- sprintf(...); L <<- c(L, s); cat(s, "\n") }
put <- function(x) { o <- capture.output(print(x)); L <<- c(L, o); cat(o, sep = "\n") }
key <- paste(r$entity_off, r$direction_off, r$control_key_off, sep = "||")
el  <- r$eleggibile & r$scarto_off == ""

say("== A. Il dizionario e le forme del calcitriolo ==")
for (s in c("calcitriol", "1,25(oh)2d3", "1α,25(oh)2d3", "1alpha,25(oh)2d3", "1,25-dihydroxyvitamin d3",
            "1alpha,25-dihydroxyvitamin d3", "1,25d3", "25-hydroxyvitamin d3", "vitamin d3")) {
  a <- simulomicsr:::.normalize_compound_to_chebi(s, onto)
  say("   %-32s -> %s (%s)", s, a$id, a$name)
}

say("")
say("== B. I confronti che nominano il calcitriolo nel trattato ==")
rx <- "calcitriol|1[,.]? ?25[- ]?\\(?oh\\)?2|1(α|alpha|a)?[,.]? ?25[- ]?(\\(oh\\)2|dihydroxy)|1[,.]25[- ]?d3|\\bvd3\\b|vitamin ?d3"
hit <- grepl(rx, tolower(paste(ing$tl, ing$tfl)), perl = TRUE)
say("confronti: %d in %d studi", sum(hit), length(unique(r$study[hit])))
x <- data.frame(key = key[hit & el], study = r$study[hit & el])
k <- tapply(x$study, x$key, function(s) length(unique(s)))
put(sort(k, decreasing = TRUE))
quattro <- c("CHEBI:17823", "STR:1_25_oh_2d3", "STR:1_25d3", "STR:1alpha_25_oh_2d3")
qk <- paste0(quattro, "||gain||vehicle_untreated")
say("studi distinti nei quattro gruppi con verso gain e controllo vehicle_untreated: %d",
    length(unique(x$study[x$key %in% qk])))
say("meta-analisi del deliverable fra questi gruppi:")
put(d[d$anchor_key %in% names(k), c("contrast_entity_label", "anchor_key", "n_studies")])

say("")
say("== C. Coppie candidate (dal nome; non verificate) ==")
cand <- list(c("STR:irradiation", "STR:radiation"), c("STR:asthma", "STR:asthmatic"),
             c("STR:ifna", "HGNC:5417"), c("STR:nash", "MeSH:D065626"),
             c("STR:1_25_oh_2d3", "CHEBI:17823"))
for (cc in cand) {
  i <- match(cc, d$contrast_entity)
  say("   %-40s studi %s | controllo %s | nelle 40 %s",
      paste(d$contrast_entity_label[i], collapse = " + "), paste(d$n_studies[i], collapse = " e "),
      paste(unique(d$contrast_control_key[i]), collapse = "/"),
      paste(d$cluster_id[i] %in% q40$cluster_id, collapse = "/"))
}
say("meta-analisi STR: nel deliverable: %d", sum(startsWith(d$contrast_entity, "STR:")))

say("")
say("== D. Anchor e fonte dell'entita' ==")
for (e in c("STR:irradiation", "STR:radiation", "STR:ifna", "HGNC:5417", "CHEBI:17823", "STR:1_25_oh_2d3")) {
  i <- el & key == paste0(e, "||gain||vehicle_untreated")
  say("-- %s: %d confronti, %d studi; fonte: %s", e, sum(i), length(unique(r$study[i])),
      paste(names(table(r$fonte_off[i])), table(r$fonte_off[i]), sep = "=", collapse = ", "))
  put(head(sort(table(paste0(ing$anchor_name[i], " [", ing$anchor_id[i], "]")), decreasing = TRUE), 5))
}

say("")
say("== E. Nome scritto dal modello contro ID scritto dal modello (master Stadio 1 A3) ==")
ids <- c("CHEBI:16579", "CHEBI:16512", "CHEBI:17236", "CHEBI:16635", "CHEBI:16515")
for (id in ids) {
  rg <- suppressWarnings(system(sprintf("grep -o '\"id\": \"%s\", \"preferred_name\": \"[^\"]*\"' %s", id, S1), intern = TRUE))
  nm <- sub('.*"preferred_name": "([^"]*)"', "\\1", rg)
  h  <- simulomicsr:::.chebi_lookup_id(sub("^CHEBI:", "", id), onto)
  ch <- if (is.null(h)) NA_character_ else as.character(h$name %||% h$primary_name %||% h[[1L]])[1L]
  say("   %s (nome in ChEBI: %s): %d occorrenze; nomi scritti dal modello piu' frequenti: %s", id,
      ch %||% "?", length(rg),
      paste(sprintf("%s (%d)", names(head(sort(table(tolower(nm)), decreasing = TRUE), 4)),
                    head(sort(table(tolower(nm)), decreasing = TRUE), 4)), collapse = ", "))
}
writeLines(L, file.path(OUT, "46-out.txt"))
