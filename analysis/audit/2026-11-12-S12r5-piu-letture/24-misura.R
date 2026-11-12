# PROVA DA BUTTARE
# 24-misura.R — S12r5: i cancelli 1, 3, 4, 5 di 00-previsioni.md; la misura di ogni lettura (quella di S12r4,
# riferimento a 95 confronti); le chiavi di ogni lettura per studio; la regola sulla discordanza e la regola di
# esito (00-previsioni.md par. 3 e 4); l'andamento col numero di letture; il conto a 11 letture; lo stato dei 9
# errori di B0 in ogni lettura; l'esito delle previsioni che non chiedono una lettura; l'elenco di quello che si
# legge (par. 6). Legge SOLO le uscite congelate (analysis/p4-output/S12r5-letture/<corsa>.jsonl) e solo i 47 studi
# di sviluppo: gli 82 studi di giudizio restano chiusi.
#
#   [S12R5_OGGETTI=<file.rds fuori dal repo>] Rscript .../24-misura.R > .../24-out.txt 2>&1        (SENZA --vanilla)
#
# PROVA A SECCO (prima delle corse, per provare lo script): PROVA=<cartella fuori dal repo> usa le uscite
# congelate di S12r4 (B0, B0pl1, B0pl2: gia' viste) al posto delle 9 corse e scrive solo in quella cartella.
suppressMessages(devtools::load_all(".", quiet = TRUE))
source("analysis/audit/2026-11-12-S12r5-piu-letture/aiuti-misura-r5.R")
ESITO <- TRUE
passa <- function(che, ok, dett = "") { cat(sprintf("%s  %s%s\n", if (isTRUE(ok)) "PASSA " else "FALLISCE", che, if (nzchar(dett)) paste0(": ", dett) else "")); if (!isTRUE(ok)) ESITO <<- FALSE }
PROVA <- Sys.getenv("PROVA")
if (nzchar(PROVA)) {
  stopifnot(dir.exists(PROVA), !startsWith(normalizePath(PROVA), normalizePath(".")))
  NUOVE <- c("B0pl1", "B0pl2"); USCITE <- USCITE_R4; DIR_OUT <- PROVA; DIR_IMP <- file.path(S4, "23-uscite-sha256"); F_REG <- file.path(S4, "23-out.txt"); PAROLA <- "forma"
  cat("PROVA A SECCO sulle uscite congelate di S12r4: NON e' un risultato di S12r5\n")
} else { NUOVE <- LETTURE; USCITE <- USCITE_R5; DIR_OUT <- S5; DIR_IMP <- file.path(S5, "23-uscite-sha256"); F_REG <- file.path(S5, "23-out.txt"); PAROLA <- "lettura" }
CORSE <- c("B0", NUOVE); n_let <- length(CORSE)
f_corsa <- function(k) file.path(USCITE, paste0(k, ".jsonl"))
scrivi_o <- function(d, f) utils::write.csv(d, file.path(DIR_OUT, f), row.names = FALSE, na = "")
cat(sprintf("24-misura.R  PROVA DA BUTTARE\nHEAD %s; letture %d: %s\n", system2("git", c("rev-parse", "--short", "HEAD"), stdout = TRUE), n_let, unisci(CORSE, ", ")))
MANCANO <- CORSE[!file.exists(f_corsa(CORSE))]; if (length(MANCANO)) stop("mancano corse: ", paste(MANCANO, collapse = ", "), call. = FALSE)
con_err <- sv$gse %in% STUDI_CON_ERRORE; costa <- sv$gse %in% STUDI_CHE_COSTANO
n_err_studio <- as.integer(table(factor(ERRORI_B0$studio, levels = sv$gse)))

# ---- 0. le uscite congelate, le impronte, il registro del lancio (cancelli 4 e 5) --------------------------------
X <- stats::setNames(lapply(CORSE, function(k) leggi_uscite(f_corsa(k))), CORSE)      # leggi_uscite ferma se non sono i 47 di sviluppo
passa(sprintf("cancello 4: ogni corsa copre 47 studi di sviluppo su 47 e nessun altro (%d corse)", n_let), all(vapply(X, length, 0L) == 47L))
imp_ok <- vapply(CORSE, function(k) {
  f <- file.path(DIR_IMP, paste0(k, ".txt")); if (!file.exists(f)) return(FALSE)
  l <- readLines(f, warn = FALSE); r <- l[endsWith(l, f_corsa(k))]
  length(r) == 1L && identical(sub("  .*$", "", r), sha(f_corsa(k)))
}, NA)
passa("le uscite congelate hanno lo SHA-256 scritto al congelamento (23-uscite-sha256/)", all(imp_ok), paste(CORSE[!imp_ok], collapse = " "))
reg <- readLines(F_REG, warn = FALSE)
amb <- do.call(rbind, lapply(CORSE, function(k) {
  mandati <- sum(!vapply(X[[k]], e_saltato, NA))
  a <- grep(sprintf("^%s: slurm [0-9]+ COMPLETED, durata [0-9:]+, nodo poddgx02; container-env.txt: VLLM_BATCH_INVARIANT=1 e HF_HUB_OFFLINE=1$", k), reg, value = TRUE)
  s <- regmatches(reg, regexec(sprintf("^%s: schema per record ([0-9]+)/([0-9]+) ", k), reg)); s <- s[lengths(s) == 3L]
  g <- grep(sprintf("^%s: %s %s .*generation.json: ", k, PAROLA, k), reg, value = TRUE)
  gen <- if (length(g) == 1L) tryCatch(jsonlite::fromJSON(sub("^.*generation.json: ", "", g), simplifyVector = FALSE), error = function(e) NULL) else NULL
  ing <- if (length(g) == 1L) sub("^.*ingresso [^ ]+ SHA-256 ([0-9a-f]+),.*$", "\\1", g) else NA_character_
  data.frame(corsa = k, nodo_e_ambiente = length(a) == 1L, mandati = mandati,
             schema_per_record = length(s) == 1L && identical(as.integer(s[[1]][2:3]), c(mandati, mandati)),
             configurazione = !is.null(gen) && identical(gen$model_id, "mistralai/Mistral-Small-3.2-24B-Instruct-2506") &&
               identical(gen$llm_extra$revision, "95a6d26c4bfb886c58daf9d3f7332c857cb27b43") && identical(as.numeric(gen$temperature), 0) &&
               identical(as.numeric(gen$repetition_penalty), 1.1) && identical(as.integer(gen$max_model_len), 65536L) && identical(as.integer(gen$max_tokens), 24576L),
             ingresso = ing, slurm = if (length(a) == 1L) sub("^.*slurm ([0-9]+) .*$", "\\1", a) else NA_character_, stringsAsFactors = FALSE)
}))
scrivi_o(amb, "24-ambiente.csv")
passa("cancello 5: ogni job COMPLETED su poddgx02 con VLLM_BATCH_INVARIANT=1 e HF_HUB_OFFLINE=1 (23-out.txt)", all(amb$nodo_e_ambiente), paste(amb$corsa[!amb$nodo_e_ambiente], collapse = " "))
passa("cancello 5: modello, revisione, temperature 0, repetition_penalty 1,1, max_model_len 65536, max_tokens 24576", all(amb$configurazione), paste(amb$corsa[!amb$configurazione], collapse = " "))
passa("cancello 5: il lavoratore usa lo schema del record in ogni record mandato al modello", all(amb$schema_per_record), paste(amb$corsa[!amb$schema_per_record], collapse = " "))
passa("cancello 5: l'ingresso di ogni corsa (testi e schemi) e' lo stesso, quello di B0 (uno SHA-256 solo)", length(unique(amb$ingresso)) == 1L && !anyNA(amb$ingresso), unisci(unique(substr(amb$ingresso, 1L, 12L))))
cat(sprintf("studi mandati al modello: 47 in %d corse su %d\n", sum(amb$mandati == 47L), n_let))

# ---- 1. la misura di ogni corsa -----------------------------------------------------------------------------------
t0 <- Sys.time()
M <- stats::setNames(lapply(CORSE, function(k) misura_forma(X[[k]], k)), CORSE)
cat(sprintf("misura di %d corse: %.0f s\n", n_let, as.numeric(difftime(Sys.time(), t0, units = "secs"))))
TAB <- do.call(rbind, lapply(CORSE, function(k) cbind(corsa = k, M[[k]]$tab, stringsAsFactors = FALSE)))
scrivi_o(TAB, "24-per-studio.csv")

# ---- 2. cancello 1: B0 si riproduce; cancello 3: il controllo positivo ----------------------------------------------
r4 <- leggi_uscite(file.path(USCITE_R4, "B0.jsonl"))
u1 <- uguali_al_carattere(X$B0, r4)
passa("cancello 1: la corsa di B0 e' identica al carattere alle uscite congelate di S12r4, 47 studi su 47", all(u1), sprintf("%d/47; diversi: %s", sum(u1), paste(sv$gse[!u1], collapse = " ")))
nB <- tre_numeri(M$B0$tab)
passa("cancello 1: B0 rida' 45 chiusi, 36 gruppi identici, 68 confronti su 95", identical(unname(nB[1:4]), c(45L, 36L, 68L, 95L)), paste(nB[1:4], collapse = " "))
STATI <- vapply(CORSE, function(k) stato_errori(M[[k]]$tab), logical(nrow(ERRORI_B0))); rownames(STATI) <- ERRORI_B0$errore
passa("cancello 3: i 9 predicati vedono i 9 errori di lettura nella corsa di B0", all(STATI[, "B0"] %in% TRUE), sprintf("%d su 9", sum(STATI[, "B0"] %in% TRUE)))
c13 <- readLines(file.path(S5, "13-out.txt"), warn = FALSE)
passa("cancello 2: lo strumento rida' i numeri congelati di S12r4 (13-out.txt, prima delle corse)", identical(utils::tail(c13, 1L), "CANCELLO DELLO STRUMENTO: PASSA") && !any(startsWith(c13, "FALLISCE")))

# ---- 3. i numeri di ogni lettura e le chiavi ----------------------------------------------------------------------
CH <- lapply(M, chiavi_lettura)
Kd <- function(n, corse = CORSE) { z <- vapply(CH[corse], function(x) if (n == "tutto") chiave_tutto(x) else x[[n]], character(47)); rownames(z) <- sv$gse; z }
NOMI_K <- c("tutto", "firma", "gruppi", "confronti")
diversa_da_B0 <- function(n, k) Kd(n)[, k] != Kd(n)[, "B0"]
NUM <- do.call(rbind, lapply(CORSE, function(k) { t <- tre_numeri(M[[k]]$tab)
  data.frame(lettura = k, chiusi = t[["chiusi"]], gruppi_identici = t[["identici"]], ritrovati = t[["ritrovati"]], den = t[["den"]], ritrovati97 = t[["ritrovati97"]], den97 = t[["den97"]],
             errori_c = t[["errori_c"]], giudicabili_c = t[["giudicabili_c"]], identica_al_carattere_a_B0 = sum(uguali_al_carattere(X[[k]], X$B0)),
             diversa_tutto = sum(diversa_da_B0("tutto", k)), diversa_firma = sum(diversa_da_B0("firma", k)), diversa_gruppi = sum(diversa_da_B0("gruppi", k)),
             diversa_confronti = sum(diversa_da_B0("confronti", k)), errori_di_B0_presenti = sum(STATI[, k] %in% TRUE), stringsAsFactors = FALSE) }))
scrivi_o(NUM, "24-letture.csv"); print(NUM, row.names = FALSE)
CHL <- do.call(rbind, lapply(CORSE, function(k) cbind(lettura = k, CH[[k]], stato = M[[k]]$tab$stato, ritrovati = M[[k]]$tab$n_b_uguale, den = M[[k]]$tab$n_b_den,
                                                      motivi = M[[k]]$tab$motivi, stringsAsFactors = FALSE)))
scrivi_o(CHL, "24-chiavi.csv")
# firma uguale e stessa chiusura -> gruppi e confronti uguali (controllo delle chiavi: si riporta, e ferma se non vale)
local({ viol <- 0L; coppie <- 0L; chius <- character(0); F <- Kd("firma"); G <- Kd("gruppi"); C <- Kd("confronti")
  for (g in seq_len(47L)) for (i in seq_len(n_let - 1L)) for (j in (i + 1L):n_let) if (F[g, i] == F[g, j] && F[g, i] != "senza tabella") {
    coppie <- coppie + 1L; nc <- c(G[g, i], G[g, j]) == "non chiuso"
    if (xor(nc[1], nc[2])) chius <- c(chius, sv$gse[g]) else if (G[g, i] != G[g, j] || C[g, i] != C[g, j]) viol <- viol + 1L }
  passa("controllo delle chiavi: firma uguale e stessa chiusura -> gruppi e confronti uguali", viol == 0L, sprintf("%d coppie di letture con la stessa firma, %d con gruppi o confronti diversi", coppie, viol))
  cat(sprintf("  firma uguale, una lettura chiusa e una no: %d coppie, negli studi: %s\n", length(chius), unisci(unique(chius)))) })

# ---- 4. la regola sulla discordanza (00-previsioni.md par. 3) ------------------------------------------------------
b0 <- M$B0$tab; stopifnot(identical(b0$studio, sv$gse))
SEGN <- vapply(NOMI_K, function(n) segnalato(Kd(n)), logical(47)); segn <- SEGN[, "tutto"]
ST <- data.frame(studio = sv$gse, segnalato = segn, chiavi_distinte = n_distinte(Kd("tutto")), firme_distinte = n_distinte(Kd("firma")),
                 gruppi_distinti = n_distinte(Kd("gruppi")), confronti_distinti = n_distinte(Kd("confronti")),
                 segnalato_firma = SEGN[, "firma"], segnalato_gruppi = SEGN[, "gruppi"], segnalato_confronti = SEGN[, "confronti"],
                 letture_diverse_da_B0 = vapply(sv$gse, function(g) unisci(NUOVE[Kd("tutto")[g, NUOVE] != Kd("tutto")[g, "B0"]], " "), ""),
                 n_letture_diverse_da_B0 = rowSums(Kd("tutto")[, NUOVE, drop = FALSE] != Kd("tutto")[, "B0"]),
                 stato_B0 = b0$stato, ritrovati_B0 = b0$n_b_uguale, den = b0$n_b_den, errori_di_B0 = n_err_studio, errore_che_costa = costa,
                 stati_nelle_letture = vapply(sv$gse, function(g) unisci(vapply(CORSE, function(k) substr(M[[k]]$tab$stato[match(g, sv$gse)], 1L, 1L), ""), ""), ""),
                 ritrovati_nelle_letture = vapply(sv$gse, function(g) unisci(vapply(CORSE, function(k) as.character(M[[k]]$tab$n_b_uguale[match(g, sv$gse)]), ""), " "), ""),
                 stringsAsFactors = FALSE, row.names = NULL)
scrivi_o(ST, "24-segnalati.csv")
ic_quota <- function(x, dove = rep(TRUE, 47L)) { set.seed(SEME); b <- vapply(seq_len(B), function(k) { i <- sample.int(47L, replace = TRUE); mean(x[i][dove[i]]) }, 0)
  unname(stats::quantile(b, c(0.025, 0.975), na.rm = TRUE)) }
conti <- function(s) c(segnalati = sum(s), studi_con_errore = sum(s & con_err), studi_che_costano = sum(s & costa), errori = sum(n_err_studio[s]),
                       errori_che_costano = sum(ERRORI_B0$costa & ERRORI_B0$studio %in% sv$gse[s]),
                       identici_in_B0 = sum(s & b0$stato == "identica"), diversi_in_B0 = sum(s & b0$stato == "diversa"), non_chiusi_in_B0 = sum(s & b0$stato == "non chiuso"),
                       senza_errore = sum(s & !con_err))
cat(sprintf("\n==== LA REGOLA SULLA DISCORDANZA, %d letture (%s), chiave firma + gruppi + confronti ====\n", n_let, unisci(CORSE, ", ")))
cn <- conti(segn); ic <- ic_quota(segn)
cat(sprintf("studi segnalati: %d su 47 (IC95 della quota per ricampionamento degli studi: %.3f, %.3f)\n  %s\n", cn[["segnalati"]], ic[1], ic[2], unisci(sv$gse[segn])))
cat(sprintf("studi con un errore di B0 segnalati: %d su %d; non segnalati: %s\n", cn[["studi_con_errore"]], sum(con_err), unisci(sv$gse[con_err & !segn])))
cat(sprintf("studi con un errore che costa segnalati: %d su %d; non segnalati: %s\n", cn[["studi_che_costano"]], sum(costa), unisci(sv$gse[costa & !segn])))
cat(sprintf("errori di B0 in studi segnalati: %d su %d; di quelli che costano: %d su %d\n", cn[["errori"]], nrow(ERRORI_B0), cn[["errori_che_costano"]], sum(ERRORI_B0$costa)))
cat(sprintf("studi segnalati per stato in B0: gruppi identici ai curatori %d (su %d), gruppi diversi %d (su %d), non chiusi %d (su %d)\n", cn[["identici_in_B0"]], sum(b0$stato == "identica"),
            cn[["diversi_in_B0"]], sum(b0$stato == "diversa"), cn[["non_chiusi_in_B0"]], sum(b0$stato == "non chiuso")))
cat(sprintf("studi segnalati senza un errore di B0: %d su %d\n", cn[["senza_errore"]], sum(!con_err)))
print(table(errore_di_B0 = ifelse(con_err, ifelse(costa, "errore che costa", "errore che non costa"), "nessun errore"), segnalato = segn))
print(table(stato_B0 = b0$stato, segnalato = segn))
ES <- esito_regola(segn)
cat(sprintf("\nREGOLA DI ESITO: quota di segnalati fra gli studi con errore %d/%d = %.3f, fra gli altri %d/%d = %.3f; differenza %+.3f, IC95 %+.3f, %+.3f (B %d, seme %d; ricampionamenti senza un gruppo %d)\n",
            ES$q$con, ES$q$n_con, ES$q$con / ES$q$n_con, ES$q$senza, ES$q$n_senza, ES$q$senza / ES$q$n_senza, ES$q$diff, ES$q$ic[1], ES$q$ic[2], B, SEME, ES$q$vuoti))
cat(sprintf("  condizione (a), l'intervallo sta tutto sopra zero: %s; condizione (b), almeno 3 dei 4 studi con un errore che costa sono segnalati: %s (%d su 4)\n  ESITO DELLA REGOLA: %s\n",
            if (ES$a) "si'" else "no", if (ES$b) "si'" else "no", ES$costano, toupper(ES$esito)))
ACC <- do.call(rbind, lapply(NOMI_K, function(n) { e <- esito_regola(SEGN[, n]); cc <- conti(SEGN[, n])
  data.frame(letture = n_let, chiave = n, t(cc), quota_con_errore = e$q$con / e$q$n_con, quota_senza = e$q$senza / e$q$n_senza, differenza = e$q$diff, ic_inf = e$q$ic[1], ic_sup = e$q$ic[2],
             a = e$a, b = e$b, esito = e$esito, stringsAsFactors = FALSE) }))

# ---- 5. lo stato dei 9 errori di B0 in ogni lettura (il conto a livello di errore, accanto) ----------------------
parola <- function(z) ifelse(is.na(z), "senza tabella", ifelse(z, "presente", "assente"))
SE <- data.frame(errore = ERRORI_B0$errore, studio = ERRORI_B0$studio, costa = ERRORI_B0$costa, studio_segnalato = ERRORI_B0$studio %in% sv$gse[segn], stringsAsFactors = FALSE)
SE$presente_in <- as.integer(rowSums(matrix(STATI %in% TRUE, nrow = nrow(STATI)))); SE$assente_in <- as.integer(rowSums(matrix(STATI %in% FALSE, nrow = nrow(STATI))))
SE$senza_tabella_in <- as.integer(rowSums(is.na(STATI))); SE$stato_cambia <- SE$presente_in < n_let
SE$letture_senza_errore <- vapply(seq_len(nrow(STATI)), function(i) unisci(CORSE[!(STATI[i, ] %in% TRUE)], " "), "")
SE <- cbind(SE, as.data.frame(matrix(parola(STATI), nrow = nrow(STATI), dimnames = list(NULL, CORSE)), stringsAsFactors = FALSE))
scrivi_o(SE, "24-stati-errori.csv")
cat(sprintf("\n==== I 9 ERRORI DI B0 NELLE %d LETTURE (conto a livello di errore) ====\n", n_let)); print(SE[c("errore", "costa", "studio_segnalato", "presente_in", "assente_in", "senza_tabella_in", "stato_cambia")], row.names = FALSE)
cat(sprintf("errori il cui stato cambia fra le letture: %d su 9; di quelli che costano: %d su 4; errori in uno studio segnalato con lo stato che NON cambia: %s\n",
            sum(SE$stato_cambia), sum(SE$stato_cambia & SE$costa), unisci(SE$errore[SE$studio_segnalato & !SE$stato_cambia])))
stopifnot(all(SE$studio_segnalato[SE$stato_cambia]))            # uno stato che cambia vuol dire una tabella dei fattori diversa: lo studio e' segnalato per costruzione

# ---- 6. l'andamento col numero di letture: B0 piu' k letture nuove, tutti i sottoinsiemi --------------------------
AND <- do.call(rbind, lapply(0:length(NUOVE), function(k) {
  S <- if (k == 0L) list(character(0)) else utils::combn(NUOVE, k, simplify = FALSE)
  r <- vapply(S, function(s) conti(segnalato(Kd("tutto", c("B0", s))))[c("segnalati", "studi_con_errore", "studi_che_costano", "errori", "identici_in_B0")], numeric(5))
  ord <- conti(segnalato(Kd("tutto", c("B0", utils::head(NUOVE, k)))))
  data.frame(letture = k + 1L, sottoinsiemi = length(S),
             segnalati_media = mean(r[1, ]), segnalati_min = min(r[1, ]), segnalati_max = max(r[1, ]),
             studi_con_errore_media = mean(r[2, ]), studi_con_errore_min = min(r[2, ]), studi_con_errore_max = max(r[2, ]),
             studi_che_costano_media = mean(r[3, ]), studi_che_costano_min = min(r[3, ]), studi_che_costano_max = max(r[3, ]),
             errori_media = mean(r[4, ]), identici_in_B0_media = mean(r[5, ]), identici_in_B0_min = min(r[5, ]), identici_in_B0_max = max(r[5, ]),
             ordine_fisso_segnalati = ord[["segnalati"]], ordine_fisso_studi_con_errore = ord[["studi_con_errore"]], ordine_fisso_studi_che_costano = ord[["studi_che_costano"]],
             stringsAsFactors = FALSE) }))
scrivi_o(AND, "24-andamento.csv")
cat("\n==== ANDAMENTO COL NUMERO DI LETTURE (B0 + k letture nuove; media, minimo e massimo su tutti i sottoinsiemi) ====\n"); print(format(AND, digits = 3), row.names = FALSE)

# ---- 7. il conto a 11 letture: le 9 piu' i due placebo di S12r4 (gia' visti: accanto, non entra nell'esito) ------
if (!nzchar(PROVA)) {
  PL <- c("B0pl1", "B0pl2"); XP <- stats::setNames(lapply(PL, function(k) leggi_uscite(file.path(USCITE_R4, paste0(k, ".jsonl")))), PL)
  for (k in PL) { M[[k]] <- misura_forma(XP[[k]], k); CH[[k]] <- chiavi_lettura(M[[k]]) }
  for (n in NOMI_K) { s11 <- segnalato(Kd(n, c(CORSE, PL))); e <- esito_regola(s11); cc <- conti(s11)
    ACC <- rbind(ACC, data.frame(letture = n_let + 2L, chiave = n, t(cc), quota_con_errore = e$q$con / e$q$n_con, quota_senza = e$q$senza / e$q$n_senza, differenza = e$q$diff,
                                 ic_inf = e$q$ic[1], ic_sup = e$q$ic[2], a = e$a, b = e$b, esito = e$esito, stringsAsFactors = FALSE)) }
  s11 <- segnalato(Kd("tutto", c(CORSE, PL)))
  cat(sprintf("\n11 letture (le 9 piu' B0pl1 e B0pl2 di S12r4, gia' visti): segnalati %d; in piu' delle 9 letture: %s\n", sum(s11), unisci(sv$gse[s11 & !segn])))
}
scrivi_o(ACC, "24-regola-per-chiave.csv")
cat("\n==== LA REGOLA CON LE ALTRE CHIAVI E A 11 LETTURE (accanto: l'esito e' quello della chiave `tutto` a 9 letture) ====\n"); print(format(ACC, digits = 3), row.names = FALSE)

# ---- 8. quello che si legge (00-previsioni.md par. 6): ogni coppia (studio, lettura nuova) con la chiave diversa da B0
KT <- Kd("tutto"); KF <- Kd("firma"); KG <- Kd("gruppi"); KC <- Kd("confronti")
L <- do.call(rbind, lapply(NUOVE, function(k) { i <- which(KT[, k] != KT[, "B0"]); if (!length(i)) return(NULL); t <- M[[k]]$tab[i, ]
  data.frame(scheda = sprintf("%s|%s|%s", sv$gse[i], substr(KF[i, k], 1L, 12L), substr(vapply(paste(KG[i, k], KC[i, k]), imp, ""), 1L, 8L)),
             studio = sv$gse[i], lettura = k, firma = substr(KF[i, k], 1L, 12L), firma_diversa = KF[i, k] != KF[i, "B0"], gruppi_diversi = KG[i, k] != KG[i, "B0"],
             confronti_diversi = KC[i, k] != KC[i, "B0"], stato = t$stato, stato_B0 = b0$stato[i], ritrovati = t$n_b_uguale, ritrovati_B0 = b0$n_b_uguale[i], den = t$n_b_den,
             errori_c = t$n_errori, errori_c_B0 = b0$n_errori[i], fonti = t$fonti, fonti_B0 = b0$fonti[i], soggetti = t$soggetti, soggetti_B0 = b0$soggetti[i],
             motivi = t$motivi_estesi, errori_di_B0 = n_err_studio[i], stringsAsFactors = FALSE) }))
if (is.null(L)) L <- data.frame(scheda = character(0), studio = character(0), lettura = character(0), firma = character(0))
# l'eredita' da S12r4: la stessa firma, nello stesso studio, gia' letta (punto di partenza: la scheda si rilegge comunque)
ered <- local({
  a <- utils::read.csv(file.path(S4, "26-letture.csv"), stringsAsFactors = FALSE, encoding = "UTF-8"); b <- utils::read.csv(file.path(S4, "26-letture-senza-unita.csv"), stringsAsFactors = FALSE, encoding = "UTF-8")
  p4 <- utils::read.csv(file.path(S4, "24-per-studio.csv"), stringsAsFactors = FALSE, encoding = "UTF-8")
  function(g, f) { ia <- a$studio == g & a$firma == f; ib <- b$studio == g & b$firma == f; ip <- p4$studio == g & substr(p4$firma, 1L, 12L) %in% f
    c(corse = unisci(unique(p4$corsa[ip]), " "), causa = unisci(unique(a$causa[ia])), errore = unisci(unique(c(a$errore[ia], b$errore[ib])[nzchar(c(a$errore[ia], b$errore[ib]))])),
      descrizione = substr(unisci(unique(c(a$descrizione[ia], b$descrizione[ib])), " // "), 1L, 500L)) }
})
SCH <- if (nrow(L)) do.call(rbind, lapply(split(L, L$scheda), function(d) { e <- ered(d$studio[1], d$firma[1])
  data.frame(scheda = d$scheda[1], studio = d$studio[1], firma = d$firma[1], n_letture = nrow(d), letture = unisci(d$lettura, " "), prima_lettura = d$lettura[1],
             stato = d$stato[1], stato_B0 = d$stato_B0[1], ritrovati = d$ritrovati[1], ritrovati_B0 = d$ritrovati_B0[1], den = d$den[1],
             firma_diversa = d$firma_diversa[1], gruppi_diversi = d$gruppi_diversi[1], confronti_diversi = d$confronti_diversi[1], errori_di_B0 = d$errori_di_B0[1],
             firma_vista_in_S12r4 = e[["corse"]], causa_S12r4 = e[["causa"]], errore_S12r4 = e[["errore"]], descrizione_S12r4 = e[["descrizione"]], stringsAsFactors = FALSE) })) else NULL
if (!is.null(SCH)) rownames(SCH) <- NULL
scrivi_o(L, "24-da-leggere-righe.csv"); if (!is.null(SCH)) scrivi_o(SCH, "24-da-leggere-schede.csv")
cat(sprintf("\n==== DA LEGGERE ====\ncoppie (studio, lettura nuova) con la chiave diversa da B0: %d, in %d studi; schede (studio, chiave): %d; schede con una firma gia' vista in S12r4: %d\n",
            nrow(L), length(unique(L$studio)), if (is.null(SCH)) 0L else nrow(SCH), if (is.null(SCH)) 0L else sum(nzchar(SCH$firma_vista_in_S12r4))))
stopifnot(setequal(unique(L$studio), sv$gse[segn]))            # uno studio e' segnalato se e solo se una lettura nuova ha la chiave diversa da B0

# ---- 9. le previsioni che non chiedono una lettura (00-previsioni.md par. 2) -----------------------------------------
if (!nzchar(PROVA)) {
  dentro <- function(x, lo, hi) if (x >= lo && x <= hi) "dentro" else "fuori"
  icq <- function(x, dove = rep(TRUE, 47L)) { z <- ic_quota(x, dove); sprintf("quota %.3f, IC95 %.3f, %.3f", mean(x[dove]), z[1], z[2]) }
  a5 <- AND$segnalati_media[AND$letture == 9L] - AND$segnalati_media[AND$letture == 5L]
  nn <- NUM[NUM$lettura != "B0", ]
  PRE <- rbind(
    data.frame(n = 1, quantita = "studi segnalati con 9 letture", atteso = "20", intervallo = "13-23", osservato = as.character(cn[["segnalati"]]), esito = dentro(cn[["segnalati"]], 13, 23), accanto = icq(segn)),
    data.frame(n = 2, quantita = "studi con la chiave diversa da B0, per lettura: mediana fra le 8", atteso = "8", intervallo = "5-12", osservato = sprintf("%.1f (da %d a %d)", stats::median(nn$diversa_tutto), min(nn$diversa_tutto), max(nn$diversa_tutto)),
               esito = dentro(stats::median(nn$diversa_tutto), 5, 12), accanto = sprintf("sulla sola firma: mediana %.1f (da %d a %d)", stats::median(nn$diversa_firma), min(nn$diversa_firma), max(nn$diversa_firma))),
    data.frame(n = 3, quantita = "studi con un errore che costa segnalati (su 4)", atteso = "3", intervallo = "3-4", osservato = as.character(cn[["studi_che_costano"]]), esito = dentro(cn[["studi_che_costano"]], 3, 4), accanto = paste("non segnalati:", unisci(sv$gse[costa & !segn]))),
    data.frame(n = 4, quantita = "errori di B0 in studi segnalati (su 9)", atteso = "6", intervallo = "5-8", osservato = as.character(cn[["errori"]]), esito = dentro(cn[["errori"]], 5, 8), accanto = sprintf("studi con errore segnalati %d su 8", cn[["studi_con_errore"]])),
    data.frame(n = 5, quantita = "studi con gruppi identici ai curatori in B0 che sono segnalati (su 36)", atteso = "11", intervallo = "7-15", osservato = as.character(cn[["identici_in_B0"]]), esito = dentro(cn[["identici_in_B0"]], 7, 15), accanto = icq(segn, b0$stato == "identica")),
    data.frame(n = 6, quantita = "esito della regola", atteso = "no (manca la condizione a)", intervallo = "-", osservato = sprintf("%s (a %s, b %s)", ES$esito, ES$a, ES$b), esito = if (ES$esito == "no" && !ES$a && ES$b) "come previsto" else "diverso dal previsto",
               accanto = sprintf("differenza %+.3f, IC95 %+.3f, %+.3f", ES$q$diff, ES$q$ic[1], ES$q$ic[2])),
    data.frame(n = 7, quantita = "errori che costano il cui stato cambia fra le 9 letture (su 4)", atteso = "2 (GSE60340, GSE49155)", intervallo = "2-3", osservato = sprintf("%d (%s)", sum(SE$stato_cambia & SE$costa), unisci(SE$studio[SE$stato_cambia & SE$costa])),
               esito = dentro(sum(SE$stato_cambia & SE$costa), 2, 3), accanto = sprintf("dei 9: %d", sum(SE$stato_cambia))),
    data.frame(n = 8, quantita = "GSE46665, sigle dei pazienti come malattie: letture in cui e' presente (su 9)", atteso = "9", intervallo = "9", osservato = as.character(SE$presente_in[1]), esito = dentro(SE$presente_in[1], 9, 9), accanto = paste("letture senza:", SE$letture_senza_errore[1])),
    data.frame(n = 9, quantita = "studi segnalati aggiunti in media da 5 a 9 letture", atteso = "3", intervallo = "1-5", osservato = sprintf("%.2f", a5), esito = dentro(a5, 1, 5), accanto = sprintf("media a 5 letture %.2f, a 9 letture %d", AND$segnalati_media[AND$letture == 5L], cn[["segnalati"]])),
    data.frame(n = 10, quantita = "confronti ritrovati su 95, in ognuna delle 8 letture nuove", atteso = "da 64 a 74", intervallo = "64-74 per tutte", osservato = sprintf("da %d a %d", min(nn$ritrovati), max(nn$ritrovati)),
               esito = if (all(nn$ritrovati >= 64 & nn$ritrovati <= 74)) "dentro" else "fuori", accanto = sprintf("chiusi da %d a %d; gruppi identici da %d a %d", min(nn$chiusi), max(nn$chiusi), min(nn$gruppi_identici), max(nn$gruppi_identici))))
  scrivi_o(PRE, "24-previsioni.csv"); cat("\n==== PREVISIONI (la 11 e la 12 chiedono la lettura: 27-dopo-la-lettura.R) ====\n"); print(PRE, row.names = FALSE, right = FALSE)
}
f_ogg <- Sys.getenv("S12R5_OGGETTI")
if (nzchar(f_ogg)) { stopifnot(!startsWith(normalizePath(dirname(f_ogg)), normalizePath(".")))
  saveRDS(list(sv = sv, X = X, M = M, CH = CH, L = L, SCH = SCH, ST = ST, SE = SE, CORSE = CORSE, NUOVE = NUOVE), f_ogg); cat("oggetti scritti in", f_ogg, "\n") }
cat(sprintf("\n24-misura.R: %s\n", if (ESITO) "TUTTI I CANCELLI PASSANO" else "UN CANCELLO FALLISCE"))
if (!ESITO) quit(status = 1L)
