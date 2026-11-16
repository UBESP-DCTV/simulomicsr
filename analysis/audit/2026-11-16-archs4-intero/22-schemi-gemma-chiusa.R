# 22-schemi-gemma-chiusa.R — lo schema delle uscite (forma B0) per i 991 studi CHIUSI di Gemma: generato e contato.
#
# La carta (00-previsioni.md, «Le parti chiuse») dice: la vista e lo schema si generano, perche' non contengono il
# disegno di Gemma; gli studi non entrano in nessun ingresso e nessun modello li legge. Questo programma NON scrive un
# ingresso, NON legge il disegno curato di Gemma e NON misura niente contro Gemma: dalla vista congelata ieri
# (analysis/input/gemma-viste-v0.jsonl, rigenerata oggi uguale byte per byte: 20-out-controllo.txt) forma lo schema e
# scrive solo i conti per studio (22-per-studio-gemma-chiusa.csv) e 22-out.txt.
# La funzione uno_studio() e le sue costanti si prendono con parse() da 21-ingresso.R, senza copiarle.
# Controllo positivo: sugli studi APERTI di Gemma la stessa funzione rida' lo SHA-256 dello schema scritto ieri
# (analysis/audit/2026-11-15-lettori-su-gemma/22-per-studio.csv) per ogni studio.
# Uso: Rscript analysis/audit/2026-11-16-archs4-intero/22-schemi-gemma-chiusa.R        (SENZA --vanilla)
suppressPackageStartupMessages({ devtools::load_all(".", quiet = TRUE); library(jsonlite) })
DIR <- "analysis/audit/2026-11-16-archs4-intero"; R3 <- "analysis/audit/2026-11-11-S12r3-elenco-chiuso"
LG <- "analysis/audit/2026-11-15-lettori-su-gemma"
source(file.path(R3, "10-schema-per-studio.R"))
prompt <- paste(readLines(file.path(R3, "21-prompt-v2.md"), warn = FALSE, encoding = "UTF-8"), collapse = "\n")
espr <- parse(file.path(DIR, "21-ingresso.R"), keep.source = FALSE)
nome_di <- function(e) if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]])) as.character(e[[2]]) else ""
# una riga di 21-ingresso.R puo' tenere piu' assegnazioni separate da `;`: parse() le da' una per una
voluti <- c("CAR_PER_TOKEN", "MAX_MODEL_LEN", "MAX_TOKENS", "LIMITE_INGRESSO", "sha_testo", "uno_studio")
presi <- character()
for (e in espr) if (nome_di(e) %in% voluti) { eval(e); presi <- c(presi, nome_di(e)) }
stopifnot(setequal(presi, voluti), !anyDuplicated(presi))

el <- utils::read.csv(file.path(DIR, "10-elenco.csv"), stringsAsFactors = FALSE)
classe_di <- stats::setNames(el$classe, el$gse)
F_VISTE <- "analysis/input/gemma-viste-v0.jsonl"
sink(file.path(DIR, "22-out.txt"), split = TRUE)
cat("22-schemi-gemma-chiusa.R ", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), "; caratteri del prompt v2: ", nchar(prompt), "\n", sep = "")
cat("viste congelate:", F_VISTE, " SHA-256", unname(tools::sha256sum(F_VISTE)), "\n")
per <- list(); con <- file(F_VISTE, "r")
repeat {
  l <- readLines(con, n = 200L, warn = FALSE, encoding = "UTF-8"); if (!length(l)) break
  for (x in l) {
    v <- fromJSON(x, simplifyVector = FALSE); g <- v$record_id
    stopifnot(classe_di[[g]] %in% c("gemma_aperta", "gemma_chiusa"))
    per[[length(per) + 1L]] <- uno_studio(v)$r          # la riga dell'ingresso (u$riga) si butta: nessun ingresso si scrive
  }
}
close(con)
per <- do.call(rbind, per); per$classe <- unname(classe_di[per$gse]); stopifnot(!anyDuplicated(per$gse), nrow(per) == 3014L)

# ---- controllo positivo: gli studi aperti ridanno lo schema di ieri ----
ieri <- utils::read.csv(file.path(LG, "22-per-studio.csv"), stringsAsFactors = FALSE)
ap <- per[per$classe == "gemma_aperta", ]; i <- match(ap$gse, ieri$gse)
stopifnot(!anyNA(i), all(ieri$parte[i] == "aperta"))
uguali <- sum(ap$schema_sha256 == ieri$schema_sha256[i] | (is.na(ap$schema_sha256) & (is.na(ieri$schema_sha256[i]) | ieri$schema_sha256[i] == "")))
cat(sprintf("CONTROLLO POSITIVO: studi aperti di Gemma con lo schema di ieri (SHA-256 o nessuno schema in tutti e due): %d su %d; nell'ingresso oggi %d, ieri %d\n",
            uguali, nrow(ap), sum(ap$esito == "nell_ingresso"), sum(ieri$parte == "aperta" & ieri$esito == "al_modello")))
cat("  token stimati: classe oggi", class(ap$token_stimati), ", ieri", class(ieri$token_stimati), "; studi con lo stesso valore", sum(ap$token_stimati == ieri$token_stimati[i]), "su", nrow(ap), "\n")
stopifnot(uguali == nrow(ap), all(ap$token_stimati == ieri$token_stimati[i]))

# ---- gli studi chiusi: solo i conti ----
ch <- per[per$classe == "gemma_chiusa", ]
n_chiusi <- sum(el$classe == "gemma_chiusa")
q <- function(x) paste(format(stats::quantile(x, c(0, .25, .5, .75, .95, .99, 1), na.rm = TRUE), big.mark = ".", decimal.mark = ","), collapse = " | ")
cat(sprintf("\nstudi chiusi di Gemma: %d nell'elenco; con la vista %d (senza vista: %s); con uno schema %d; senza colonne non costanti %d; oltre il contesto (stima) %d\n",
            n_chiusi, nrow(ch), paste(setdiff(el$gse[el$classe == "gemma_chiusa"], ch$gse), collapse = " "), sum(ch$esito == "nell_ingresso"),
            sum(ch$esito != "nell_ingresso"), sum(ch$oltre_contesto_stimato == 1L & ch$esito == "nell_ingresso")))
cat("  quantili (minimo | 25% | mediana | 75% | 95% | 99% | massimo)\n  campioni:", q(ch$campioni), "\n  token stimati dell'ingresso:", q(ch$token_stimati[ch$esito == "nell_ingresso"]),
    "\n  caratteri dello schema:", q(ch$schema_caratteri), "\n  studi con lo schema oltre 222.556 caratteri:", sum(ch$schema_caratteri > 222556L, na.rm = TRUE), "\n")
utils::write.csv(ch[c("gse", "campioni", "colonne_non_costanti", "valori_distinti", "valori_max_per_colonna", "schema_caratteri", "schema_sha256",
                      "token_stimati", "oltre_contesto_stimato", "esito")], file.path(DIR, "22-per-studio-gemma-chiusa.csv"), row.names = FALSE, na = "")
cat("nessun ingresso scritto, nessun modello, nessuna misura contro Gemma\nFINE 22-schemi-gemma-chiusa.R\n"); sink()
