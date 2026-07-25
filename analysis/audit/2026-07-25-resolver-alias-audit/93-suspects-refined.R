# AUDIT DEL RESOLVER — passo 3: classi di sospetto RIFATTE + lista da giudicare.
#
# La prima classificazione era inaffidabile e va corretta: "D4 ambiguo" contava
# come collisione anche `cisplatin` presente in ChEBI E ChEMBL, cioe' la stessa
# sostanza in due dizionari. Percio' il 51% misurato NON e' un tasso di errore.
#
# Classi rifatte, ortogonali e verificabili:
#   C1 UNITA'      alias che e' un'unita' di misura ("ml", "mg")
#   C2 COLLISIONE  l'alias mappa a >=2 entita' con NOMI DIVERSI (ambiguita' vera)
#   C3 NON ATTESTATA  il nome dell'entita' assegnata non compare MAI nel corpus,
#                  mentre l'alias e' frequentissimo: il match non e' corroborato
#   C4 SIGLA CORTA <=4 caratteri e non e' il nome primario dell'entita'
#
# Output: la lista dei sospetti ordinata per impatto reale (campioni), da
# giudicare uno per uno. Nessun verdetto automatico: la classificazione e' uno
# SCREENING, il verdetto lo da' l'adjudicazione (passo 4).
suppressPackageStartupMessages({library(dplyr)})
OUT <- "analysis/audit/2026-07-25-resolver-alias-audit"
A <- readRDS(file.path(OUT, "alias-catalog.rds"))
fire <- readRDS(file.path(OUT, "production-firing.rds"))
freq <- readRDS(file.path(OUT, "corpus-token-freq.rds"))

norm <- function(x) gsub("[^a-z0-9]", "", tolower(x %||% ""))
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

## C2 — ambiguita' SEMANTICA: nomi primari diversi sotto lo stesso alias
amb <- A |> filter(!is.na(name), nzchar(name)) |>
  group_by(alias) |> summarise(n_nomi = n_distinct(norm(name)), .groups = "drop")
## C3 — il NOME dell'entita' e' attestato nel corpus? (token del nome primario)
corpus_tok <- unique(freq$tok[freq$n_studi >= 1])
name_attested <- function(nm) {
  if (is.na(nm) || !nzchar(nm)) return(NA)
  w <- strsplit(gsub("[^a-z0-9]+", " ", tolower(nm)), " +")[[1]]
  w <- w[nchar(w) >= 4]
  if (!length(w)) return(NA)
  any(w %in% corpus_tok)
}

S <- fire |> filter(!is.na(alias_innesco)) |>
  group_by(alias = alias_innesco, agent_id, name, dict) |>
  summarise(n_gsm = n(), .groups = "drop")
S <- left_join(S, amb, by = "alias")
S <- left_join(S, freq |> select(tok, n_studi_alias = n_studi), by = c("alias" = "tok"))
S$n_studi_alias[is.na(S$n_studi_alias)] <- 0L
UNITS <- c("ml","ul","dl","l","ug","mg","ng","pg","kg","g","nm","um","mm","pm","cm","mol","mmol",
           "umol","nmol","moi","pfu","ffu","tcid","iu","hr","hrs","min","sec","h","d","rpm","ph")
S$C1_unita <- S$alias %in% UNITS
S$C2_collisione <- !is.na(S$n_nomi) & S$n_nomi >= 2
S$attestata <- vapply(S$name, name_attested, logical(1))
S$C3_non_attestata <- (S$attestata %in% FALSE) & S$n_studi_alias >= 20
S$C4_sigla <- nchar(gsub("[^a-z0-9]", "", S$alias)) <= 4 & norm(S$alias) != norm(S$name)
S$sospetto <- S$C1_unita | S$C2_collisione | S$C3_non_attestata | S$C4_sigla

cat("=== SCREENING RIFATTO (risoluzioni di produzione con alias identificato) ===\n")
cat(sprintf("risoluzioni (campioni)        : %d\n", sum(S$n_gsm)))
cat(sprintf("alias distinti che innescano  : %d\n", nrow(S)))
cat(sprintf("alias SOSPETTI                : %d (campioni coinvolti: %d = %.1f%%)\n",
            sum(S$sospetto), sum(S$n_gsm[S$sospetto]), 100 * sum(S$n_gsm[S$sospetto]) / sum(S$n_gsm)))
cat("\n-- campioni per classe (un alias puo' appartenere a piu' classi) --\n")
print(data.frame(
  C1_unita = sum(S$n_gsm[S$C1_unita]), C2_collisione = sum(S$n_gsm[S$C2_collisione]),
  C3_non_attestata = sum(S$n_gsm[S$C3_non_attestata]), C4_sigla = sum(S$n_gsm[S$C4_sigla])))
cat("\n-- confronto con la classificazione SBAGLIATA di prima --\n")
cat(sprintf("  vecchio 'D4 ambiguo' (dizionari diversi, stessa sostanza): %d campioni -> scartato\n",
            sum(fire$D4_ambiguo %in% TRUE)))

sus <- S |> filter(sospetto) |> arrange(desc(n_gsm)) |>
  select(alias, agent_id, name, dict, n_gsm, n_studi_alias, C1_unita, C2_collisione,
         C3_non_attestata, C4_sigla)
write.csv(sus, file.path(OUT, "sospetti-da-giudicare.csv"), row.names = FALSE)
saveRDS(S, file.path(OUT, "screening.rds"))
cat("\n=== I 60 SOSPETTI PIU' IMPATTANTI (da giudicare uno per uno) ===\n")
print(head(as.data.frame(sus), 60), row.names = FALSE)
cat(sprintf("\nscritto sospetti-da-giudicare.csv (%d righe)\n", nrow(sus)))
