#!/usr/bin/env Rscript
# S12p, conto cieco: il primo script che legge il riferimento dei 193 confronti difettosi. Gira solo se le impronte
# delle uscite (40-uscite-sha256.txt, commit 5d8814f) passano. Attese: 00-previsioni.md (P4-P6 di S12, P11-P14, K5).
# Uso: Rscript analysis/audit/2026-11-08-S12p-prova/40-conto.R > analysis/audit/2026-11-08-S12p-prova/40-out.txt
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-08-S12p-prova/aiuti.R")
USCITE <- "analysis/p4-output/S12p-uscite"; SEME <- 20261108L; B <- 2000L
rc <- system2("sha256sum", c("-c", "--quiet", file.path(DIR, "40-uscite-sha256.txt")))
if (rc != 0L) ferma("CANCELLO K5: impronte delle uscite non verificate")
cat("impronte delle uscite: 9 file su 9 verificati\n")

ten <- TENUTI(); rif <- read.csv("analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv", stringsAsFactors = FALSE)
if (nrow(rif) != 193L || anyDuplicated(rif$record_id) || !all(rif$record_id %in% ten$record_id)) ferma("riferimento: attesi 193 confronti distinti fra i 1.903")
difettoso <- ten$record_id %in% rif$record_id; names(difettoso) <- ten$record_id
cat(sprintf("riferimento: %d difettosi, %d puliti, su %d confronti\n", sum(difettoso), sum(!difettoso), length(difettoso)))

wilson <- function(x, n) { if (n == 0) return(c(NA, NA)); z <- qnorm(0.975); p <- x / n; c0 <- p + z^2 / (2 * n); r <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)); (c(c0 - r, c0 + r)) / (1 + z^2 / n) }
fmt <- function(x, n) { ci <- wilson(x, n); sprintf("%d su %d = %.1f%% [%.1f; %.1f]", x, n, 100 * x / n, 100 * ci[1], 100 * ci[2]) }
# Conto: presi = accusati fra i difettosi, falsi allarmi = accusati fra i puliti.
conta <- function(accusati) c(presi = sum(difettoso[accusati]), falsi = sum(!difettoso[accusati]))

# K5, controllo positivo e negativo dello script del conto.
k5a <- conta(rif$record_id); k5b <- conta(character())
cat(sprintf("K5 controllo positivo: accusati i 193 -> presi %d, falsi allarmi %d (attesi 193 e 0)\n", k5a[["presi"]], k5a[["falsi"]]))
cat(sprintf("K5 controllo negativo: nessuno accusato -> presi %d, falsi allarmi %d (attesi 0 e 0)\n", k5b[["presi"]], k5b[["falsi"]]))
if (k5a[["presi"]] != 193L || k5a[["falsi"]] != 0L || any(k5b != 0L)) ferma("CANCELLO K5 fallito")

# Famiglie dei 193: regola su parole chiave della categoria, nell'ordine scritto (la prima che vale). Non e' una
# regola depositata: serve a leggere il conto per gruppi; il conto per categoria e' in 40-per-categoria.csv.
famiglia <- function(cat) {
  c <- tolower(cat)
  if (grepl("sospetto|non verificabile|non determinata|non stabilita|indecidib", c)) return("non provato o indecidibile")
  if (grepl("tempo zero|a tempo zero", c)) return("tempo zero")
  if (grepl("tempo|durata", c)) return("tempo o durata non appaiati")
  if (grepl("secondo agente|combinazione|due agenti|agente|co-tratt|coltura solo nel trattato", c)) return("seconda perturbazione")
  if (grepl("tecnic", c)) return("differenza tecnica")
  if (grepl("entita|contrasto", c)) return("entita' o contrasto")
  if (grepl("material|compartiment|linea|donator|genotip|sesso|etnia|sede|pdx|differenziament|stadio|eta", c)) return("asse dei campioni non appaiato")
  "altro"
}
rif$famiglia <- vapply(rif$categoria, famiglia, "")
cat("\nfamiglie dei 193:\n"); print(table(rif$famiglia))

tab <- list(); percat <- list(); segn <- list(); E <- list()
for (k in names(MODELLI)) {
  e <- read.delim(file.path(USCITE, paste0(k, "-esiti.tsv")), stringsAsFactors = FALSE, quote = "", na.strings = c("NA", ""))
  if (nrow(e) != 1903L || !setequal(e$record_id, ten$record_id)) ferma("esiti %s incompleti", k)
  e$motivi[is.na(e$motivi)] <- ""; e$avvisi[is.na(e$avvisi)] <- ""
  e$accusato <- !as.logical(e$passa); e$difettoso <- difettoso[e$record_id]; E[[k]] <- e
  cc <- conta(e$record_id[e$accusato])
  # P6 e P13: quote su assi e citazioni, intervallo bootstrap con il confronto come unita'.
  v <- e[as.logical(e$valida) & as.logical(e$completo), ]
  set.seed(SEME); bs <- replicate(B, { i <- sample.int(nrow(v), replace = TRUE); c(sum(v$assi_not_stated[i]) / (11 * length(i)), sum(v$citazioni_trovate[i]) / sum(v$n_citazioni[i])) })
  ns <- sum(v$assi_not_stated) / (11 * nrow(v)); ci_ns <- quantile(bs[1, ], c(.025, .975)); cit <- sum(v$citazioni_trovate) / sum(v$n_citazioni); ci_cit <- quantile(bs[2, ], c(.025, .975))
  tab[[k]] <- data.frame(modello = k, presi = cc[["presi"]], difettosi = sum(difettoso), falsi_allarmi = cc[["falsi"]], puliti = sum(!difettoso),
                         presi_ci = paste(sprintf("%.1f", 100 * wilson(cc[["presi"]], 193)), collapse = "-"), falsi_ci = paste(sprintf("%.1f", 100 * wilson(cc[["falsi"]], 1710)), collapse = "-"),
                         passano = sum(!e$accusato), non_valide = sum(!as.logical(e$valida) & as.logical(e$completo)), oltre_limite = sum(!as.logical(e$completo)),
                         not_stated = round(100 * ns, 1), not_stated_ci = paste(sprintf("%.1f", 100 * ci_ns), collapse = "-"),
                         citazioni = round(100 * cit, 1), citazioni_ci = paste(sprintf("%.1f", 100 * ci_cit), collapse = "-"))
  cat(sprintf("\n== %s ==\nP4 presi: %s\nP5 falsi allarmi: %s\nP6 assi not_stated: %.1f%% [%.1f; %.1f] (bootstrap sui confronti, B=%d)\nP11 oltre il limite: %d\nP12 liste non valide dopo la cascata: %d\nP13 citazioni trovate nel testo: %.1f%% [%.1f; %.1f]\n",
              k, fmt(cc[["presi"]], 193), fmt(cc[["falsi"]], 1710), 100 * ns, 100 * ci_ns[1], 100 * ci_ns[2], B, sum(!as.logical(e$completo)),
              sum(!as.logical(e$valida) & as.logical(e$completo)), 100 * cit, 100 * ci_cit[1], 100 * ci_cit[2]))
  # per famiglia e per categoria dei 193
  m <- merge(rif[, c("record_id", "categoria", "famiglia", "non_provato", "fonte")], e[, c("record_id", "accusato", "motivi")], by = "record_id")
  f <- aggregate(accusato ~ famiglia, m, function(x) c(n = length(x), presi = sum(x))); f <- data.frame(famiglia = f$famiglia, n = f$accusato[, "n"], presi = f$accusato[, "presi"])
  cat("presi per famiglia:\n"); print(f, row.names = FALSE)
  cat(sprintf("presi fra i difetti letti nei metadati (fonte = metadato): %s; nelle etichette: %s\n", fmt(sum(m$accusato[m$fonte == "metadato"]), sum(m$fonte == "metadato")), fmt(sum(m$accusato[m$fonte == "etichetta"]), sum(m$fonte == "etichetta"))))
  percat[[k]] <- setNames(aggregate(accusato ~ categoria, m, function(x) sum(x)), c("categoria", paste0("presi_", k)))
  # segnali che accusano, fra i presi e fra i falsi allarmi; segnali calcolati dal codice separati da quelli del modello
  sg <- function(x) { s <- unlist(strsplit(x, " ")); s <- s[nzchar(s)]; table(factor(s, levels = .s2b_tutti_i_segnali())) }
  segn[[k]] <- data.frame(segnale = .s2b_tutti_i_segnali(), presi = as.integer(sg(e$motivi[e$accusato & e$difettoso])), falsi = as.integer(sg(e$motivi[e$accusato & !e$difettoso])), modello = k)
  solo_h5 <- e$accusato & vapply(strsplit(e$motivi, " "), function(s) length(s) > 0 && all(startsWith(s, "TECNICA_H5")), TRUE)
  cat(sprintf("accusati dal solo segnale tecnico calcolato dal codice (TECNICA_H5_*): presi %d, falsi allarmi %d\n", sum(solo_h5 & e$difettoso), sum(solo_h5 & !e$difettoso)))
  cat(sprintf("accusati solo per lista non valida o ingresso oltre il limite: presi %d, falsi allarmi %d\n", sum(e$accusato & e$difettoso & e$motivi %in% c("LISTA_NON_VALIDA", "INGRESSO_INCOMPLETO")), sum(e$accusato & !e$difettoso & e$motivi %in% c("LISTA_NON_VALIDA", "INGRESSO_INCOMPLETO"))))
  canc <- e[grepl("^GSE226005__", e$record_id), c("record_id", "difettoso", "passa", "motivi")]
  cat("i due confronti con il controllo cancellato da GEO:\n"); print(canc, row.names = FALSE)
}
tab <- do.call(rbind, tab); write.csv(tab, file.path(DIR, "40-tabella.csv"), row.names = FALSE)
cat("\n== tabella ==\n"); print(tab, row.names = FALSE)
pc <- Reduce(function(a, b) merge(a, b, by = "categoria"), percat); pc <- merge(as.data.frame(table(categoria = rif$categoria), responseName = "n"), pc, by = "categoria")
pc$famiglia <- vapply(as.character(pc$categoria), famiglia, ""); pc <- pc[order(-pc$n, pc$categoria), ]
write.csv(pc, file.path(DIR, "40-per-categoria.csv"), row.names = FALSE)
sg <- do.call(rbind, segn); write.csv(sg[sg$presi + sg$falsi > 0, ], file.path(DIR, "40-segnali.csv"), row.names = FALSE)
cat("\n== segnali che accusano (presi / falsi allarmi), per modello ==\n")
w <- reshape(sg[, c("segnale", "modello", "presi", "falsi")], idvar = "segnale", timevar = "modello", direction = "wide"); w <- w[rowSums(w[, -1]) > 0, ]
print(w[order(-w$falsi.gemma), ], row.names = FALSE)
# Accordo fra i modelli sull'accusa (descrittivo).
acc <- sapply(E, function(e) e$accusato[match(ten$record_id, e$record_id)])
cat(sprintf("\naccusati da tutti e tre: presi %d, falsi allarmi %d; da nessuno: difettosi %d, puliti %d\n",
            sum(rowSums(acc) == 3 & difettoso), sum(rowSums(acc) == 3 & !difettoso), sum(rowSums(acc) == 0 & difettoso), sum(rowSums(acc) == 0 & !difettoso)))
saveRDS(list(tabella = tab, esiti = E, riferimento = rif), file.path(USCITE, "40-conto.rds"))
cat("CONTO FINITO\n")
