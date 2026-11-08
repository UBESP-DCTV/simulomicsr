#!/usr/bin/env Rscript
# S12p, seconda parte: raccoglie le letture dei 1.236 pacchetti, le unisce alla chiave e giudica cancelli L1-L2 e
# previsioni R1-R5 (00-previsioni-lettura.md). Classi del falso allarme come scritte nelle previsioni.
# Uso: Rscript analysis/audit/2026-11-08-S12p-prova/70-lettura.R <cartella-lettori> <file-chiave> > .../70-out.txt
suppressMessages(pkgload::load_all(".", quiet = TRUE))
suppressPackageStartupMessages(library(jsonlite))
a <- commandArgs(TRUE); LET <- a[1]; CHIAVE <- a[2]; DIR <- "analysis/audit/2026-11-08-S12p-prova"; SEME <- 20261108L; B <- 2000L
wilson <- function(x, n) { z <- qnorm(0.975); p <- x / n; c0 <- p + z^2 / (2 * n); r <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)); (c(c0 - r, c0 + r)) / (1 + z^2 / n) }
fmt <- function(x, n) { ci <- wilson(x, n); sprintf("%d su %d = %.1f%% [%.1f; %.1f]", x, n, 100 * x / n, 100 * ci[1], 100 * ci[2]) }
TIPI <- c("tempo_zero", "tempo_diverso", "secondo_agente", "agente_nel_controllo", "braccio_misto", "entita_diversa", "tecnica",
          "materiale_o_sede", "genotipo", "coltura", "soggetti", "altro")

# ---- letture -------------------------------------------------------------------------------------------------
ch <- fromJSON(CHIAVE, simplifyVector = FALSE); names(ch) <- vapply(ch, `[[`, "", "id")
lotti <- sort(list.files(LET, pattern = "^lotto-[0-9]+[.]txt$")); attesi <- unlist(lapply(file.path(LET, lotti), readLines))
L <- list(); difformi <- character()
for (f in sort(list.files(file.path(LET, "risposte"), pattern = "[.]jsonl$", full.names = TRUE))) {
  for (l in readLines(f, encoding = "UTF-8")) { if (!nzchar(trimws(l))) next
    r <- tryCatch(fromJSON(l, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(r) || is.null(r$id)) { difformi <- c(difformi, sprintf("%s: riga non leggibile", basename(f))); next }
    L[[r$id]] <- r }
}
valida_lettura <- function(id) {
  r <- L[[id]]; k <- ch[[id]]; n_aff <- length(k$affermazioni)
  if (is.null(r)) return("assente")
  if (!isTRUE(r$confrontabile %in% c("si", "no", "incerto"))) return("confrontabile fuori elenco")
  tipi <- vapply(r$difetti, function(d) if (is.null(d$tipo)) NA_character_ else d$tipo, "")
  if (length(tipi) && !all(tipi %in% TIPI)) return("tipo di difetto fuori elenco")
  if (r$confrontabile == "no" && !length(r$difetti)) return("no senza difetti")
  af <- r$affermazioni; if (length(af) != n_aff) return(sprintf("affermazioni %d, attese %d", length(af), n_aff))
  if (n_aff && !all(vapply(af, function(x) isTRUE(x$fatto %in% c("vero", "falso", "non_verificabile")) && isTRUE(x$conta %in% c("si", "no", "na")), TRUE))) return("valori delle affermazioni fuori elenco")
  "ok"
}
stato <- vapply(attesi, valida_lettura, ""); extra <- setdiff(names(L), attesi)
cat(sprintf("L1 copertura: pacchetti attesi %d, letture valide %d; difformi %d; letture estranee %d; righe illeggibili %d\n",
            length(attesi), sum(stato == "ok"), sum(stato != "ok"), length(extra), length(difformi)))
if (any(stato != "ok")) print(table(stato[stato != "ok"]))

# ---- tabella per pacchetto e per affermazione ------------------------------------------------------------------
rif <- read.csv("analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv", stringsAsFactors = FALSE)
P <- do.call(rbind, lapply(attesi[stato == "ok"], function(id) { k <- ch[[id]]; r <- L[[id]]
  data.frame(id = id, record_id = k$record_id, gruppo = k$gruppo, difettoso = isTRUE(k$difettoso), acc_mistral = isTRUE(k$accusato_mistral), acc_gemma = isTRUE(k$accusato_gemma),
             confrontabile = r$confrontabile, tipi = paste(vapply(r$difetti, function(d) d$tipo, ""), collapse = " "),
             citazioni = paste(vapply(r$difetti, function(d) if (is.null(d$citazione)) "" else d$citazione, ""), collapse = " || "),
             nota = if (is.null(r$nota)) "" else r$nota, stringsAsFactors = FALSE) }))
P$non_provato <- rif$non_provato[match(P$record_id, rif$record_id)] %in% c(TRUE, "True")
A <- do.call(rbind, lapply(attesi[stato == "ok"], function(id) { k <- ch[[id]]; r <- L[[id]]; if (!length(k$affermazioni)) return(NULL)
  do.call(rbind, lapply(seq_along(k$affermazioni), function(j) { m <- k$affermazioni[[j]]; x <- r$affermazioni[[j]]
    data.frame(id = id, claim = m$claim, modello = m$modello, segnale = m$segnale, fatto = x$fatto, conta = x$conta, stringsAsFactors = FALSE) })) }))
cat(sprintf("affermazioni lette: %d (Mistral %d, Gemma %d)\n", nrow(A), sum(A$modello == "mistral"), sum(A$modello == "gemma")))

# ---- L2: controllo positivo ------------------------------------------------------------------------------------
pr <- P[P$gruppo == "preso" & !P$non_provato, ]
cat(sprintf("L2 controllo positivo: difetti del riferimento (non «non provati») giudicati non confrontabili: %s; incerti %d (soglia 80%%)\n", fmt(sum(pr$confrontabile == "no"), nrow(pr)), sum(pr$confrontabile == "incerto")))
cat(sprintf("   difetti «non provati» letti: %d, giudicati non confrontabili %d\n", sum(P$gruppo == "preso" & P$non_provato), sum(P$gruppo == "preso" & P$non_provato & P$confrontabile == "no")))

# ---- classi dei falsi allarmi, per modello ---------------------------------------------------------------------
classe <- function(id, k) { p <- P[P$id == id, ]; a <- A[A$id == id & A$modello == k, ]
  if (p$confrontabile == "no") return("riferimento"); if (p$confrontabile == "incerto") return("incerto")
  if (any(a$fatto == "falso")) return("modello"); if (any(a$conta == "si")) return("incerto"); "regola" }
boot_quota <- function(ids, num) { set.seed(SEME); u <- unique(ids); qs <- replicate(B, { s <- sample(u, replace = TRUE); i <- unlist(lapply(s, function(z) which(ids == z))); mean(num[i]) }); quantile(qs, c(.025, .975)) }
C <- list()
for (k in c("gemma", "mistral")) {
  fa <- P[P$gruppo == "falso_allarme" & P[[paste0("acc_", k)]] & P$id %in% A$id[A$modello == k], ]
  fa$classe <- vapply(fa$id, classe, "", k = k); C[[k]] <- fa
  cat(sprintf("\n== falsi allarmi di %s letti: %d ==\n", k, nrow(fa)))
  for (cl in c("riferimento", "modello", "regola", "incerto")) cat(sprintf("   %-12s %s\n", cl, fmt(sum(fa$classe == cl), nrow(fa))))
  cat(sprintf("R%d difetti veri (lettore: non confrontabile): %s\n", if (k == "gemma") 1L else 2L, fmt(sum(fa$confrontabile == "no"), nrow(fa))))
  cat("   tipi dei difetti trovati dai lettori nei falsi allarmi:\n"); print(sort(table(unlist(strsplit(fa$tipi[fa$confrontabile == "no"], " "))), decreasing = TRUE))
  a <- A[A$modello == k & A$id %in% fa$id, ]
  s <- aggregate(cbind(n = 1, vero = a$fatto == "vero", falso = a$fatto == "falso", nv = a$fatto == "non_verificabile", vero_conta = a$fatto == "vero" & a$conta == "si", vero_non_conta = a$fatto == "vero" & a$conta == "no") ~ segnale, data = a, FUN = sum)
  s <- s[order(-s$n), ]; s$modello <- k; cat("   affermazioni per segnale (fatto e se conta):\n"); print(s, row.names = FALSE)
  write.csv(s, file.path(DIR, sprintf("70-segnali-%s.csv", k)), row.names = FALSE)
}
# R3 e R4, Mistral, quote sulle affermazioni con bootstrap sui confronti
am <- A[A$modello == "mistral" & A$id %in% C$mistral$id, ]
x <- am[am$segnale == "CONDIZIONE_CON_AGENTE", ]; ci <- boot_quota(x$id, x$fatto == "falso")
cat(sprintf("\nR3 CONDIZIONE_CON_AGENTE (Mistral) giudicata falsa: %d su %d = %.1f%% [%.1f; %.1f] (bootstrap sui confronti)\n", sum(x$fatto == "falso"), nrow(x), 100 * mean(x$fatto == "falso"), 100 * ci[1], 100 * ci[2]))
x <- am[am$segnale == "ALTRA_DIFFERENZA", ]; ci <- boot_quota(x$id, x$fatto == "vero" & x$conta == "no")
cat(sprintf("R4 ALTRA_DIFFERENZA (Mistral) vera ma non un difetto: %d su %d = %.1f%% [%.1f; %.1f]; falsa %d; vera e conta %d\n", sum(x$fatto == "vero" & x$conta == "no"), nrow(x), 100 * mean(x$fatto == "vero" & x$conta == "no"), 100 * ci[1], 100 * ci[2], sum(x$fatto == "falso"), sum(x$fatto == "vero" & x$conta == "si")))
na <- P[P$gruppo == "non_accusato", ]
cat(sprintf("R5 puliti non accusati giudicati non confrontabili (campione di 60): %s; incerti %d\n", fmt(sum(na$confrontabile == "no"), nrow(na)), sum(na$confrontabile == "incerto")))

# ---- citazioni dei lettori -------------------------------------------------------------------------------------
pk <- function(id) paste(readLines(file.path(LET, "pacchetti", paste0(id, ".txt")), encoding = "UTF-8"), collapse = "\n")
cit <- do.call(rbind, lapply(attesi[stato == "ok"], function(id) { r <- L[[id]]; if (!length(r$difetti)) return(NULL); t <- pk(id)
  data.frame(id = id, trovata = vapply(r$difetti, function(d) !is.null(d$citazione) && nzchar(d$citazione) && grepl(d$citazione, t, fixed = TRUE), TRUE)) }))
cat(sprintf("\ncitazioni dei difetti trovate per intero nel pacchetto: %s\n", fmt(sum(cit$trovata), nrow(cit))))

# ---- uscite ----------------------------------------------------------------------------------------------------
write.csv(P, file.path(DIR, "70-letture.csv"), row.names = FALSE); write.csv(A, file.path(DIR, "70-affermazioni.csv"), row.names = FALSE)
write.csv(rbind(transform(C$gemma, modello = "gemma"), transform(C$mistral, modello = "mistral")), file.path(DIR, "70-classi.csv"), row.names = FALSE)
nuovi <- P[P$gruppo == "falso_allarme" & P$confrontabile == "no", c("record_id", "acc_mistral", "acc_gemma", "tipi", "citazioni", "nota")]
write.csv(nuovi, file.path(DIR, "70-difetti-non-nel-riferimento.csv"), row.names = FALSE)
cat(sprintf("\nconfronti puliti nel riferimento che i lettori giudicano non confrontabili (falsi allarmi letti): %d, in %d studi\n", nrow(nuovi), length(unique(sub("__.*$", "", nuovi$record_id)))))
cat("LETTURA RACCOLTA\n")
