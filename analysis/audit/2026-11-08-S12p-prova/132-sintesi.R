#!/usr/bin/env Rscript
# S12p, quinta parte, analisi DESCRITTIVA dopo il calcolo (non nelle previsioni).
# (1) Il tipo di controllo scritto dallo Stadio 2 nel confronto (control_type), nei difettosi e nei puliti: il prompt
#     dello Stadio 2 dice di usare il tempo zero come controllo (RULE 2, control_type = time_zero).
# (2) La tabella finale «dove nasce il difetto», che unisce le classi dello strumento (130) e il campo in cui sta la
#     prova del lettore (131). Regole dell'unione, scritte prima di calcolarla:
#     - classe A                                                   -> lo Stadio 2 aveva l'informazione nei fatti
#     - fra i 193, fonte «etichetta» e classe B, C o D            -> lo Stadio 2 aveva l'informazione (l'ha scritta nell'etichetta)
#     - classe B (restanti)                                        -> lo Stadio 1 l'ha scritta in un campo che la firma esclude
#     - classe C (restanti)                                        -> lo Stadio 1 l'ha letta (chiave di characteristics) e non l'ha scritta
#     - classe D, fra i 280 con prova in un campo letto, fra i 193 con fonte «metadato» -> lo Stadio 1 l'ha letta e non l'ha scritta
#     - classe D, fra i 280 con prova solo in campi non letti     -> nessun passo legge il campo
#     - classe D, fra i 280 con prova non trovata                 -> non attribuito
#     - classe E                                                   -> nome dell'entita'
# Uso: Rscript analysis/audit/2026-11-08-S12p-prova/132-sintesi.R > analysis/audit/2026-11-08-S12p-prova/132-out.txt 2>&1
suppressPackageStartupMessages(library(jsonlite))
DIR <- "analysis/audit/2026-11-08-S12p-prova"
`%||%` <- function(a, b) if (is.null(a)) b else a
wilson <- function(x, n) { z <- qnorm(0.975); p <- x / n; c0 <- p + z^2 / (2 * n); r <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)); (c(c0 - r, c0 + r)) / (1 + z^2 / n) }
fmt <- function(x, n) { ci <- wilson(x, n); sprintf("%d su %d = %.1f%% [%.1f; %.1f]", x, n, 100 * x / n, 100 * ci[1], 100 * ci[2]) }
R <- read.csv(file.path(DIR, "130-diagnosi.csv"), stringsAsFactors = FALSE)
Q <- read.csv(file.path(DIR, "131-dove-sta-la-prova.csv"), stringsAsFactors = FALSE)
rif <- read.csv("analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv", stringsAsFactors = FALSE)
ten <- readRDS("analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds")$tenuti

# (1) control_type dal master A3 dello Stadio 2
studi <- unique(ten$study_id); l2 <- readLines("analysis/p4-output/A3-stage2-master-innestato.jsonl")
l2 <- l2[sub('^.*?"series_id": ?"([^"]+)".*$', "\\1", l2, perl = TRUE) %in% studi]
M2 <- lapply(l2, fromJSON, simplifyVector = FALSE); names(M2) <- vapply(M2, function(x) as.character(x$series_id), "")
ct <- vapply(seq_len(nrow(ten)), function(i) {
  v <- character(); for (cp in M2[[ten$study_id[i]]]$comparisons)
    if (identical(as.character(cp$treated_group), ten$treated_group[i]) && identical(as.character(cp$control_group), ten$control_group[i])) v <- c(v, as.character(cp$control_type %||% NA))
  paste(sort(unique(v)), collapse = "+") }, "")
R$control_type <- ct[match(R$record_id, ten$record_id)]
cat("== tipo di controllo scritto dallo Stadio 2: difettosi e puliti ==\n"); print(table(R$control_type, ifelse(R$difettoso, "difettosi", "puliti")))
tz <- R$control_type == "time_zero"
cat(sprintf("\ncontrollo time_zero: %d confronti, di cui difettosi %d (%s)\n", sum(tz), sum(tz & R$difettoso), fmt(sum(tz & R$difettoso), sum(tz))))
d <- R[R$difettoso, ]; z <- grepl("tempo_zero", d$tipi)
cat(sprintf("difetti di tipo tempo_zero: %d; con control_type time_zero %d; con altri tipi di controllo: %s\n", sum(z), sum(z & d$control_type == "time_zero"),
            paste(names(table(d$control_type[z & d$control_type != "time_zero"])), table(d$control_type[z & d$control_type != "time_zero"]), collapse = ", ")))

# (2) la tabella finale
d$fonte <- rif$fonte[match(d$record_id, rif$record_id)]; d$prova <- Q$prova[match(d$record_id, Q$record_id)]
d$nasce <- with(d, ifelse(classe == "A", "S2 aveva l'informazione nei fatti",
              ifelse(!is.na(fonte) & fonte == "etichetta" & classe %in% c("B", "C", "D"), "S2 aveva l'informazione (etichetta)",
              ifelse(classe == "B", "S1 l'ha scritta, la firma la esclude",
              ifelse(classe == "C", "S1 l'ha letta, non l'ha scritta",
              ifelse(classe == "D" & ((!is.na(prova) & prova == "in un campo letto dallo Stadio 1") | (!is.na(fonte) & fonte == "metadato")), "S1 l'ha letta, non l'ha scritta",
              ifelse(classe == "D" & !is.na(prova) & prova == "solo in campi non letti", "nessun passo legge il campo",
              ifelse(classe == "E", "nome dell'entita'", "non attribuito"))))))))
if (any(is.na(d$nasce))) stop("classi non attribuite")
cat("\n== dove nasce il difetto (473) ==\n")
tb <- sort(table(d$nasce), decreasing = TRUE); for (k in names(tb)) cat(sprintf("  %-40s %s\n", k, fmt(tb[[k]], nrow(d))))
s2 <- grepl("^S2", d$nasce); cat(sprintf("  totale «lo Stadio 2 aveva l'informazione»: %s\n", fmt(sum(s2), nrow(d))))
cat("\n== dove nasce, per tipo (un difetto con piu' tipi conta in ogni tipo) ==\n")
tt <- do.call(rbind, lapply(seq_len(nrow(d)), function(i) data.frame(tipo = strsplit(d$tipi[i], " ")[[1]], nasce = d$nasce[i])))
print(table(tt$tipo, tt$nasce))
cat("\n== fra i difetti dove lo Stadio 2 aveva l'informazione nei fatti: tipo di controllo ==\n"); print(sort(table(d$control_type[d$classe == "A"]), decreasing = TRUE))
write.csv(d[, c("record_id", "tipi", "classe", "sotto", "fonte", "prova", "control_type", "nasce")], file.path(DIR, "132-dove-nasce.csv"), row.names = FALSE)
cat("FINITO\n")
