#!/usr/bin/env Rscript
# 24-misura.R — il secondo lettore: i cancelli K1 e K3 di 00-previsioni.md e le misure m1-m6 di ogni corsa congelata
# dei candidati (23-uscite-sha256.txt), con le funzioni della sessione con piu' letture (S12r5), senza cambi:
# misura_forma() con l'adattatore B0, riferimento a 95 confronti. In piu' la regola di scelta (punti 1-3; il punto 4
# quando c'e' la replica). Legge SOLO i 47 studi di sviluppo: gli 82 studi di giudizio restano chiusi.
#
#   Rscript analysis/audit/2026-11-15-secondo-lettore/24-misura.R > .../24-out.txt 2>&1      (SENZA --vanilla)
#
# PROVA A SECCO (prima delle corse): SECCO=<cartella fuori dal repo>. Misura come «candidato» la corsa congelata di
# Mistral-Small 3.2 con lo schema v1 (adattatore A0): il conto dell'accordo deve ridare 30 studi tenuti e 0 con un
# errore che costa (31-accordo-fra-lettori.csv della prova coi modelli Claude, riga «Mistral B0 = Mistral v1»).
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")
SEME <- 20261115L; B <- 10000L                                # depositati in 00-previsioni.md
QUI <- "analysis/audit/2026-11-15-secondo-lettore"
ESITO <- TRUE
passa <- function(che, ok, dett = "") { cat(sprintf("%s  %s%s\n", if (isTRUE(ok)) "PASSA " else "FALLISCE", che, if (nzchar(dett)) paste0(": ", dett) else "")); if (!isTRUE(ok)) ESITO <<- FALSE }
SECCO <- Sys.getenv("SECCO"); A_SECCO <- nzchar(SECCO)
if (A_SECCO) { stopifnot(dir.exists(SECCO), !startsWith(normalizePath(SECCO), normalizePath("."))); cat("PROVA A SECCO su una corsa congelata di Mistral: NON e' un risultato\n") }
DIR_OUT <- if (A_SECCO) SECCO else QUI
scrivi_qui <- function(d, f) utils::write.csv(d, file.path(DIR_OUT, f), row.names = FALSE, na = "")
sha256 <- function(f) unname(digest::digest(file = f, algo = "sha256"))
MISERR <- c("GSE46665", "GSE57945", "GSE60340", "GSE49155", "GSE147507")   # i 5 studi con un errore di Mistral B0 che costa
cat(sprintf("24-misura.R  secondo lettore\nHEAD %s; seme %d, B %d\n", system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE), SEME, B))

# ---- 1. K1: Mistral-Small 3.2 nella forma B0 (il primo lettore) ----
MIS <- misura_forma(leggi_uscite("analysis/p4-output/S12r5-letture/B0.jsonl"), "B0")
tre <- function(tab) unname(as.integer(tre_numeri(tab)[c("chiusi", "identici", "ritrovati", "den")]))
passa("K1: Mistral-Small 3.2 nella forma B0 rida' 45 chiusi, 36/47, 68/95", identical(tre(MIS$tab), c(45L, 36L, 68L, 95L)), paste(tre(MIS$tab), collapse = " "))
st_mis <- stato_errori(MIS$tab)
passa("K1: i predicati vedono i 9 errori di lettura di B0 nelle uscite di Mistral", all(st_mis %in% TRUE), sprintf("%d su 9", sum(st_mis %in% TRUE)))
KM <- chiavi_lettura(MIS); stopifnot(identical(KM$studio, sv$gse), all(MISERR %in% sv$gse))
gc_di <- function(k) paste(k$gruppi, k$confronti)             # la chiave dell'accordo: gruppi e confronti

# ---- 2. le corse congelate ----
if (A_SECCO) {
  reg <- data.frame(sha = NA_character_, file = "analysis/p4-output/S12r2-lettore-v1/M-corsa1.jsonl", nome = "MV-secco", adattatore = "A0", stringsAsFactors = FALSE)
} else {
  reg <- utils::read.table(file.path(QUI, "23-uscite-sha256.txt"), col.names = c("sha", "file"), colClasses = "character", stringsAsFactors = FALSE)
  # il registro del congelamento elenca anche i file delle cartelle dei job (uscite dei worker, log, stato): lo SHA-256
  # si controlla su TUTTI i file; le corse da misurare sono solo le uscite congelate <corsa>.jsonl
  ok <- vapply(seq_len(nrow(reg)), function(i) file.exists(reg$file[i]) && identical(sha256(reg$file[i]), reg$sha[i]), NA)
  passa(sprintf("K4: i %d file del registro hanno lo SHA-256 scritto al congelamento", nrow(reg)), all(ok), paste(reg$file[!ok], collapse = " "))
  reg <- reg[dirname(reg$file) == "analysis/p4-output/secondo-lettore-B0", ]
  reg$nome <- sub("\\.jsonl$", "", basename(reg$file)); reg$adattatore <- "B0"; stopifnot(nrow(reg) > 0L, !anyDuplicated(reg$nome))
  cat(sprintf("corse congelate da misurare: %d (%s)\n", nrow(reg), paste(reg$nome, collapse = ", ")))
}
reg$candidato <- sub("-.*$", "", reg$nome); reg$variante <- sub("^[^-]*-", "", reg$nome)
RUN <- stats::setNames(lapply(seq_len(nrow(reg)), function(i) { X <- leggi_uscite(reg$file[i])      # ferma se non sono i 47 studi di sviluppo
  M <- misura_forma(X, reg$adattatore[i]); list(X = X, M = M, kk = chiavi_lettura(M)) }), reg$nome)
passa(sprintf("K3: ogni corsa copre 47 studi di sviluppo su 47, una riga per studio (%d corse)", nrow(reg)),
      all(vapply(RUN, function(r) length(r$X) == 47L && nrow(r$M$tab) == 47L && identical(r$M$tab$studio, sv$gse), NA)))

# ---- 3. m1-m5 per corsa ----
una <- function(nome) { r <- RUN[[nome]]; n <- tre_numeri(r$M$tab); ps <- r$M$per_studio$principale; ps <- ps[match(sv$gse, ps$studio), ]
  tenuto <- r$M$tab$chiuso & MIS$tab$chiuso & gc_di(r$kk) == gc_di(KM)
  ap <- appaiato(ps, MIS$per_studio$principale, c("candidato", "mistral")); ab <- ap[ap$misura == "b_confronti_ritrovati", ]
  s <- stato_errori(r$M$tab)
  list(riga = data.frame(corsa = nome, chiusi = n[["chiusi"]], identici = n[["identici"]], ritrovati = n[["ritrovati"]], den = n[["den"]],
      b_meno_mistral = ab$differenza, b_ic_basso = ab$ic_basso, b_ic_alto = ab$ic_alto, non_valide = sum(!r$M$tab$valida),
      tenuti = sum(tenuto), tenuti_con_errore_di_mistral = sum(tenuto & sv$gse %in% MISERR), quali = paste(sv$gse[tenuto & sv$gse %in% MISERR], collapse = " "),
      tenuti_identici_ad_atlas = sum(ps$classe_gruppi[tenuto] %in% "identica"), tenuti_ritrovati = sum(ps$n_b_uguale[tenuto]), tenuti_den = sum(ps$n_b_den[tenuto]),
      confronti_atlas_fuori = sum(ps$n_b_den[!tenuto]), stessa_tabella_di_mistral = sum(chiave_tutto(r$kk) == chiave_tutto(KM)),
      errori_b0_che_costano = sum(s[ERRORI_B0$costa] %in% TRUE), errori_b0_che_non_costano = sum(s[!ERRORI_B0$costa] %in% TRUE), stringsAsFactors = FALSE),
    per_studio = data.frame(corsa = nome, studio = sv$gse, chiuso = r$M$tab$chiuso, valida = r$M$tab$valida, classe_gruppi = ps$classe_gruppi, n_b_uguale = ps$n_b_uguale,
      n_b_den = ps$n_b_den, tenuto = tenuto, errore_di_mistral_che_costa = sv$gse %in% MISERR, firma = r$kk$firma, gruppi = r$kk$gruppi, confronti = r$kk$confronti,
      fonti = r$M$tab$fonti, stringsAsFactors = FALSE),
    stati = data.frame(corsa = nome, errore = ERRORI_B0$errore, costa = ERRORI_B0$costa, presente = s, stringsAsFactors = FALSE)) }
U <- lapply(reg$nome, una); CORSE <- do.call(rbind, lapply(U, `[[`, "riga"))
scrivi_qui(CORSE, "24-corse.csv"); scrivi_qui(do.call(rbind, lapply(U, `[[`, "per_studio")), "24-per-studio.csv"); scrivi_qui(do.call(rbind, lapply(U, `[[`, "stati")), "24-stati-errori.csv")
cat("\n== Le misure di ogni corsa (riferimento a 95 confronti) ==\n")
cat(sprintf("%-10s chiusi %2d  identici %2d/47  ritrovati %2d/%d (meno Mistral %+5.1f punti, IC95 %+5.1f, %+5.1f)  non valide %d | accordo con Mistral B0: tenuti %2d, con errore di Mistral %d %s, identici ad Atlas %d, ritrovati %d/%d | errori di B0 presenti: %d che costano, %d che non costano\n",
            CORSE$corsa, CORSE$chiusi, CORSE$identici, CORSE$ritrovati, CORSE$den, 100 * CORSE$b_meno_mistral, 100 * CORSE$b_ic_basso, 100 * CORSE$b_ic_alto, CORSE$non_valide,
            CORSE$tenuti, CORSE$tenuti_con_errore_di_mistral, CORSE$quali, CORSE$tenuti_identici_ad_atlas, CORSE$tenuti_ritrovati, CORSE$tenuti_den,
            CORSE$errori_b0_che_costano, CORSE$errori_b0_che_non_costano), sep = "")
if (A_SECCO) passa("controllo positivo dell'accordo: Mistral v1 contro Mistral B0 rida' 30 studi tenuti e 0 con errore", CORSE$tenuti == 30L && CORSE$tenuti_con_errore_di_mistral == 0L,
                   sprintf("%d tenuti, %d con errore", CORSE$tenuti, CORSE$tenuti_con_errore_di_mistral))

# ---- 4. m6: le repliche (rp11r contro rp11, rp0r contro rp0) ----
RIP <- do.call(rbind, lapply(reg$nome[grepl("r$", reg$variante)], function(nr) { n0 <- sub("r$", "", nr); if (!(n0 %in% reg$nome)) return(NULL); a <- RUN[[n0]]; b <- RUN[[nr]]
  data.frame(corsa = n0, replica = nr, identiche_al_carattere = sum(uguali_al_carattere(a$X, b$X)), stessa_tabella = sum(chiave_tutto(a$kk) == chiave_tutto(b$kk)),
             stessi_gruppi_e_confronti = sum(gc_di(a$kk) == gc_di(b$kk)), studi_diversi = paste(sv$gse[gc_di(a$kk) != gc_di(b$kk)], collapse = " "), stringsAsFactors = FALSE) }))
if (!is.null(RIP)) { scrivi_qui(RIP, "24-ripetibilita.csv"); cat("\n== Repliche (studi su 47) ==\n"); print(RIP, row.names = FALSE) }

# ---- 5. la regola di scelta di 00-previsioni.md ----
# corsa giudicata: quella con piu' studi tenuti fra rp11 e rp0; a pari, rp11.
REG <- do.call(rbind, lapply(unique(reg$candidato), function(k) { c2 <- CORSE[CORSE$corsa %in% paste0(k, c("-rp11", "-rp0", "-secco")), ]; if (!nrow(c2)) return(NULL)
  g <- c2[order(-c2$tenuti, c2$corsa != paste0(k, "-rp11")), ][1, ]; rp <- if (is.null(RIP)) NULL else RIP[RIP$corsa == g$corsa, ]
  p4 <- if (is.null(rp) || !nrow(rp)) NA else rp$stessi_gruppi_e_confronti == 47L
  p <- c(g$chiusi >= 40L, g$tenuti >= 30L, g$tenuti_con_errore_di_mistral == 0L)
  data.frame(candidato = k, corsa_giudicata = g$corsa, p1_chiusi_40 = p[1], p2_tenuti_30 = p[2], p3_nessun_errore_fra_i_tenuti = p[3], p4_replica_47 = p4,
             esito = if (!all(p)) "non ammesso" else if (is.na(p4)) "passa 1-3: serve la replica" else if (p4) "ammesso" else "non ammesso",
             possibile_primo_lettore = g$chiusi >= 45L && g$b_ic_basso > 0, stringsAsFactors = FALSE) }))
scrivi_qui(REG, "24-regola.csv"); cat("\n== La regola di scelta ==\n"); print(REG, row.names = FALSE)
cat(sprintf("\nESITO DEI CANCELLI: %s\n", if (ESITO) "tutti passano" else "ALMENO UNO FALLISCE"))
if (!ESITO) quit(status = 1L)
