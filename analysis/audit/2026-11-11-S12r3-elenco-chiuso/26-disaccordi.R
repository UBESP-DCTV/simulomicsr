# PROVA DA BUTTARE
# 26-disaccordi.R — S12r3: la lettura di TUTTI i disaccordi del lettore (schema delle uscite a elenco chiuso) contro
# Expression Atlas, sui 47 studi di sviluppo (00-previsioni.md, «Che cosa si legge dopo le corse» e «Come si conta lo
# studio che chiude con gruppi sbagliati»). Audit interno: le cause le ha lette un agente Claude sul materiale di
# 25-materiale-M.txt; non sono una misura dell'articolo. Gli 82 studi di giudizio non entrano in nessun file letto qui.
#
# Uso (SENZA --vanilla):
#   Rscript analysis/audit/2026-11-11-S12r3-elenco-chiuso/26-disaccordi.R > .../26-out.txt 2>&1
#
# Ingressi misurati: 24-M-* (prima corsa), 24-transizioni.csv, 25-unita-M.csv, 15-per-studio-v1.csv, e le cause lette
# in S12r2 (26-disaccordi-M-righe.csv di S12r2). Ingresso scritto a mano (separatore «|»): 26-cause-M.txt, colonne
#   studio|unita|id|causa|sotto|resto_causa|resto_sotto|anche|differenza|prova
#   unita = tutto (studio e confronti), studio, confronti, atlas (un confronto di Atlas, con id), lettore (un
#   confronto del lettore giudicato errore, con id). La riga piu' specifica vince.
#
# Che cosa fa: costruisce le unita' di disaccordo DAI FILE DELLA MISURA (misura principale: contesto fuori, 95
# confronti), da' a ognuna la causa letta e si ferma se una unita' resta senza causa, se una causa non e' fra quelle
# ammesse o se una riga a mano non serve. Poi: gli studi con gruppi sbagliati (prima causa del lettore sulla
# partizione), E12, le regressioni, che cosa e' cambiato nei 13 + 3 + 4 studi di S12r2, le attese per i 13 studi, il
# punto 4 della regola di esito. Scrive 26-disaccordi-M-righe.csv, 26-gruppi-sbagliati.csv, 26-cambiato.csv e
# 26-disaccordi.md. Se il file delle cause manca scrive 26-unita-M.csv e si ferma: serve per preparare la lettura.
R3 <- "analysis/audit/2026-11-11-S12r3-elenco-chiuso"; R2 <- "analysis/audit/2026-11-10-S12r2-prova-ripetuta"
leggi <- function(f, da = R3) utils::read.csv(file.path(da, f), stringsAsFactors = FALSE)
leggi_mano <- function(f) utils::read.delim(file.path(R3, f), sep = "|", quote = "", stringsAsFactors = FALSE,
                                           na.strings = character(0), encoding = "UTF-8", comment.char = "")
ferma <- function(ok, ...) if (!isTRUE(ok)) stop(sprintf(...), call. = FALSE)
ch <- function(a, b) paste(a, b)
ERRORI <- c("piu_fattori", "braccio_misto")
TIPI <- c("studio_non_chiuso", "partizione_non_identica", "atlas_non_ritrovato", "lettore_errore")
CAUSE <- c("vista", "schema", "modello", "curatore", "strumento")
RESTO <- c(CAUSE, "niente_letto", "non_osservato")
TREDICI <- c("GSE147507", "GSE46665", "GSE56787", "GSE57116", "GSE57945", "GSE59781", "GSE60340", "GSE63816", "GSE66207",
             "GSE69597", "GSE71595", "GSE83415", "GSE83687")
TRE <- c("GSE44379", "GSE50760", "GSE93624"); QUATTRO <- c("GSE112057", "GSE65335", "GSE75852", "GSE77598")
# Le attese per i 13 studi, da 00-previsioni.md (depositate prima delle corse): stato atteso e, dove scritto, il giudizio
# sui gruppi (sbagliati / non_errore) e i confronti (ritrovati / non_ritrovati). "" = l'attesa non lo dice.
ATTESE <- data.frame(studio = TREDICI,
  stato = c("diversa", "diversa", "diversa", "identica", "diversa", "identica", "diversa", "diversa", "identica", "diversa",
            "identica", "identica", "identica"),
  gruppi = c("sbagliati", "sbagliati", "sbagliati", "", "", "", "", "", "", "non_errore", "", "", ""),
  confronti = c("", "", "", "non_ritrovati", "", "ritrovati", "", "", "ritrovati", "", "", "", ""), stringsAsFactors = FALSE)

# Chi puo' togliere la causa (00-previsioni.md, regola di esito, punto 4: la vista o lo schema, con un rimedio
# nominato). `modello` = la causa sta nella lettura del modello: non ha chi la toglie (il modello e' deciso e la
# prova ripetuta ha misurato che il modello piu' grande non la toglie). `non_serve` = non e' un errore del lettore.
# Il rimedio nominato per ogni causa di vista o di schema sta in NOMINATO: e' una PROPOSTA non misurata.
source(file.path(R3, "26-cause-tabella.R"))   # RIMEDIO, SPIEGA, NOMINATO
ferma(setequal(names(RIMEDIO), names(SPIEGA)), "RIMEDIO e SPIEGA non hanno le stesse sottoclassi")
ferma(all(RIMEDIO %in% c("schema", "vista", "modello", "non_serve", "strumento")), "RIMEDIO: valore non ammesso")
ferma(setequal(names(NOMINATO), names(RIMEDIO)[RIMEDIO %in% c("schema", "vista")]),
      "ogni causa di vista o di schema deve avere un rimedio nominato, e solo quelle")

# ---- la misura: unita' ed esiti automatici --------------------------------------------------------------------------
pr <- function(x) x[x$misura_r3 == "principale", ]
m <- list(s = leggi("24-M-studi.csv"), p = pr(leggi("24-M-per-studio.csv")), k = pr(leggi("24-M-confronti-atlas.csv")),
          ne = pr(leggi("24-M-non-elencati.csv")), tz = leggi("24-transizioni.csv"))
v1 <- pr(leggi("15-per-studio-v1.csv")); v1 <- v1[match(m$s$studio, v1$studio), ]
oggi <- pr(leggi("15-per-studio-oggi.csv")); oggi <- oggi[match(m$s$studio, oggi$studio), ]
d2 <- leggi("26-disaccordi-M-righe.csv", R2)
ferma(nrow(m$s) == 47L && identical(m$s$studio, m$p$studio) && identical(m$s$studio, m$tz$studio), "attesi 47 studi nello stesso ordine")
ferma(sum(m$ne$giudizio %in% ERRORI) == sum(m$p$n_errori), "i giudizi contati come errore non ridanno n_errori")
unita <- function() {
  g1 <- m$s$studio[!m$s$chiuso]; g2 <- m$s$studio[m$s$chiuso & m$p$classe_gruppi != "identica"]
  us <- data.frame(tipo = rep(c("studio_non_chiuso", "partizione_non_identica"), c(length(g1), length(g2))), studio = c(g1, g2),
                   id = rep("", length(g1) + length(g2)), stringsAsFactors = FALSE)
  us$nome <- ifelse(us$tipo == "studio_non_chiuso", substr(m$s$motivi[match(us$studio, m$s$studio)], 1L, 200L),
                    paste("classe", m$p$classe_gruppi[match(us$studio, m$p$studio)]))
  kn <- m$k[m$k$in_b & m$k$ritrovato != "uguale", ]
  ua <- data.frame(tipo = rep("atlas_non_ritrovato", nrow(kn)), studio = kn$studio, id = as.character(kn$id), nome = kn$nome, stringsAsFactors = FALSE)
  ee <- m$ne[m$ne$giudizio %in% ERRORI, ]
  ue <- data.frame(tipo = rep("lettore_errore", nrow(ee)), studio = ee$studio, id = as.character(ee$id),
                   nome = sprintf("confronto del lettore %s (%d/%d), giudizio %s", ee$id, ee$n_trattato, ee$n_controllo, ee$giudizio),
                   stringsAsFactors = FALSE)
  u <- rbind(us, ua, ue)
  u$stato_v1 <- m$tz$stato_v1[match(u$studio, m$tz$studio)]; u$stato_nuovo <- m$tz$stato_nuovo[match(u$studio, m$tz$studio)]
  un <- leggi("25-unita-M.csv")
  ferma(nrow(u) == sum(un$unita) && sum(u$tipo == "atlas_non_ritrovato") == sum(un$non_ritrovati) &&
          sum(u$tipo == "lettore_errore") == sum(un$errori), "le unita' non ridanno 25-unita-M.csv")
  ferma(sum(u$tipo == "atlas_non_ritrovato") == sum(m$p$n_b_den - m$p$n_b_uguale), "i non ritrovati non ridanno la misura (b)")
  u
}

# ---- le cause lette -------------------------------------------------------------------------------------------------
cause <- function(u) {
  cs <- leggi_mano("26-cause-M.txt")
  ferma(identical(names(cs), c("studio", "unita", "id", "causa", "sotto", "resto_causa", "resto_sotto", "anche", "differenza", "prova")),
        "intestazione del file delle cause")
  ferma(all(cs$unita %in% c("tutto", "studio", "confronti", "atlas", "lettore")), "unita' non ammessa")
  ferma(!anyDuplicated(paste(cs$studio, cs$unita, cs$id)), "righe doppie nelle cause")
  ferma(all(nzchar(cs$id) == cs$unita %in% c("atlas", "lettore")), "l'id va scritto solo per le righe atlas e lettore")
  usate <- logical(nrow(cs)); campi <- c("causa", "sotto", "resto_causa", "resto_sotto", "anche", "differenza", "prova")
  for (n in campi) u[[n]] <- ""
  for (i in seq_len(nrow(u))) {
    che <- switch(u$tipo[i], atlas_non_ritrovato = c("atlas", "confronti"), lettore_errore = c("lettore", "lettore"), c("", "studio"))
    j <- which(cs$studio == u$studio[i] & cs$unita == che[1] & cs$id == u$id[i] & nzchar(che[1]))
    if (!length(j) && u$tipo[i] != "lettore_errore") j <- which(cs$studio == u$studio[i] & cs$unita %in% c("tutto", che[2]))
    ferma(length(j) == 1L, "%s %s %s: %d righe di causa (attesa 1)", u$studio[i], u$tipo[i], u$id[i], length(j))
    usate[j] <- TRUE; u[i, campi] <- cs[j, campi]
    if (!nzchar(u$prova[i])) { t <- which(cs$studio == u$studio[i] & cs$unita %in% c("tutto", "confronti", "studio") & nzchar(cs$prova)); if (length(t)) u$prova[i] <- cs$prova[t[1]] }
  }
  ferma(all(usate), "righe di causa che non servono a nessuna unita': %s", paste(ch(cs$studio, cs$unita)[!usate], collapse = ", "))
  chiave <- paste(u$causa, u$sotto, sep = "/"); ha_resto <- u$resto_causa %in% CAUSE
  chiave_r <- ifelse(ha_resto, paste(u$resto_causa, u$resto_sotto, sep = "/"), "")
  ferma(all(chiave %in% names(RIMEDIO)), "sottoclasse non nota: %s", paste(unique(chiave[!chiave %in% names(RIMEDIO)]), collapse = ", "))
  ferma(all(u$resto_causa %in% RESTO), "resto non ammesso: %s", paste(unique(u$resto_causa[!u$resto_causa %in% RESTO]), collapse = ", "))
  ferma(all(chiave_r[ha_resto] %in% names(RIMEDIO)), "sottoclasse del resto non nota: %s", paste(unique(chiave_r[ha_resto & !chiave_r %in% names(RIMEDIO)]), collapse = ", "))
  an <- unlist(strsplit(u$anche[nzchar(u$anche)], ";", fixed = TRUE))
  ferma(all(an %in% names(RIMEDIO)), "sottoclasse «anche» non nota: %s", paste(unique(an[!an %in% names(RIMEDIO)]), collapse = ", "))
  ferma(all(nzchar(u$differenza)), "unita' senza «che cosa differisce»")
  cur <- u$causa == "curatore" | u$resto_causa == "curatore"
  ferma(all(nzchar(u$prova[cur])), "causa «curatore» senza prova: %s", paste(unique(u$studio[cur & !nzchar(u$prova)]), collapse = ", "))
  s <- u$tipo == "studio_non_chiuso"
  ferma(all(u$resto_causa[!s] != "non_osservato"), "«non_osservato» vale solo per uno studio non chiuso")
  u$rimedio <- unname(RIMEDIO[chiave]); u$rimedio_resto <- ifelse(ha_resto, unname(RIMEDIO[chiave_r]), "")
  u$nominato <- ifelse(chiave %in% names(NOMINATO), unname(NOMINATO[chiave]), "")
  # esito della catena:
  #   non_errore     nella catena c'e' una scelta o un errore del curatore, o un limite della misura
  #   modello        almeno una causa della catena (prima o resto) sta nella lettura del modello
  #   vista_schema   ogni causa della catena e' di vista o di schema: PROPOSTA non misurata, col rimedio nominato
  u$esito <- vapply(seq_len(nrow(u)), function(i) {
    r <- c(u$rimedio[i], if (nzchar(u$rimedio_resto[i])) u$rimedio_resto[i])
    if (any(r %in% c("non_serve", "strumento"))) "non_errore" else if (any(r == "modello")) "modello" else "vista_schema"
  }, "")
  # una causa di lettura del modello in un punto qualsiasi: prima causa, resto o «anche» (punto 4: l'esito
  # `non_errore` non nasconde una causa del lettore)
  u$lettura_modello <- vapply(seq_len(nrow(u)), function(i) {
    k <- c(chiave[i], if (ha_resto[i]) chiave_r[i], strsplit(u$anche[i], ";", fixed = TRUE)[[1]])
    any(RIMEDIO[k] == "modello")
  }, NA)
  u$causa_lettore <- vapply(seq_len(nrow(u)), function(i) {
    k <- c(chiave[i], if (ha_resto[i]) chiave_r[i], strsplit(u$anche[i], ";", fixed = TRUE)[[1]])
    any(RIMEDIO[k] %in% c("modello", "schema", "vista"))
  }, NA)
  u
}

md <- function(...) cat(..., "\n", sep = "", file = con)
tab <- function(d) {
  if (!nrow(d)) { md("(nessuna riga)"); return(invisible()) }
  md("| ", paste(names(d), collapse = " | "), " |"); md("|", paste(rep("---", ncol(d)), collapse = "|"), "|")
  for (i in seq_len(nrow(d))) md("| ", paste(gsub("|", "/", vapply(d[i, ], as.character, ""), fixed = TRUE), collapse = " | "), " |")
}
incrocio <- function(r, c) { t <- table(r, c); d <- data.frame(x = rownames(t), unclass(t), check.names = FALSE, stringsAsFactors = FALSE); d$totale <- rowSums(t); names(d)[1] <- ""; d }

u <- unita()
cat(sprintf("unita' di disaccordo %d (%s), in %d studi su 47\n", nrow(u),
            paste(sprintf("%s %d", TIPI, vapply(TIPI, function(t) sum(u$tipo == t), 0L)), collapse = "; "), length(unique(u$studio))))
if (!file.exists(file.path(R3, "26-cause-M.txt"))) {
  utils::write.csv(u, file.path(R3, "26-unita-M.csv"), row.names = FALSE, fileEncoding = "UTF-8")
  cat("il file delle cause manca; scritto 26-unita-M.csv\n"); quit(save = "no")
}
u <- cause(u); chiave <- paste(u$causa, u$sotto, sep = "/")
utils::write.csv(u, file.path(R3, "26-disaccordi-M-righe.csv"), row.names = FALSE, fileEncoding = "UTF-8")
cat("prima causa per tipo di unita':\n"); print(table(chiave, factor(u$tipo, TIPI)))
cat("esito della catena per tipo di unita':\n"); print(table(factor(u$tipo, TIPI), u$esito))
cat(sprintf("unita' con una causa di lettura del modello in un punto qualsiasi della catena: %d (in %d studi: %s)\n",
            sum(u$lettura_modello), length(unique(u$studio[u$lettura_modello])), paste(unique(u$studio[u$lettura_modello]), collapse = ", ")))
print(table(esito = u$esito, lettura_modello = u$lettura_modello))

# ---- gli studi con gruppi sbagliati (00-previsioni.md, «Come si conta ...», punti 2 e 3) ---------------------------------
up <- u[u$tipo == "partizione_non_identica", ]
gs <- data.frame(studio = up$studio, stato_v1 = up$stato_v1, classe = sub("^classe ", "", up$nome), prima_causa = paste(up$causa, up$sotto, sep = "/"),
                 chi_la_toglie = up$rimedio, rimedio_nominato = up$nominato,
                 giudizio = ifelse(up$rimedio %in% c("non_serve", "strumento"), "gruppi diversi, non errore", "gruppi sbagliati"),
                 in_piu = up$anche, stringsAsFactors = FALSE)
i <- match(gs$studio, m$p$studio)
gs$confronti_formati <- m$s$n_confronti[match(gs$studio, m$s$studio)]; gs$giudicabili_c <- m$p$n_giudicabili[i]; gs$errori_c <- m$p$n_errori[i]
gs$b_ritrovati <- sprintf("%d/%d", m$p$n_b_uguale[i], m$p$n_b_den[i]); gs$differenza <- up$differenza
utils::write.csv(gs, file.path(R3, "26-gruppi-sbagliati.csv"), row.names = FALSE, fileEncoding = "UTF-8")
sb <- gs[gs$giudizio == "gruppi sbagliati", ]
cat(sprintf("\nstudi `diversa`: %d; gruppi sbagliati %d (per lettura del modello %d, per schema %d, per vista %d); gruppi diversi, non errore %d\n",
            nrow(gs), nrow(sb), sum(sb$chi_la_toglie == "modello"), sum(sb$chi_la_toglie == "schema"), sum(sb$chi_la_toglie == "vista"),
            sum(gs$giudizio != "gruppi sbagliati")))
cat(sprintf("confronti che il costruttore forma dagli studi con gruppi sbagliati: %d; giudicati errore dalla misura (c): %d su %d giudicabili\n",
            sum(sb$confronti_formati), sum(sb$errori_c), sum(sb$giudicabili_c)))
e12 <- sb$studio[sb$studio %in% TREDICI]
cat(sprintf("E12  dei 13, chiudono con gruppi sbagliati (causa del lettore): %d (%s); atteso 3 (GSE46665, GSE56787, GSE147507), rilevanza 0-0  ->  %s\n",
            length(e12), paste(e12, collapse = ", "), if (length(e12) == 0L) "confermata" else "smentita"))
reg <- m$tz[m$tz$regressione, ]
cat(sprintf("regressioni: %d (%s)\n", nrow(reg), paste(reg$studio, collapse = ", ")))

# ---- che cosa e' cambiato nei 13 + 3 + 4 studi di S12r2, e nelle regressioni -------------------------------------------------
una_riga <- function(g, insieme) {
  ug <- u[u$studio == g, ]; u2 <- d2[d2$studio == g, ]; i <- match(g, m$p$studio)
  data.frame(studio = g, insieme = insieme, stato_v1 = m$tz$stato_v1[i], stato_nuovo = m$tz$stato_nuovo[i],
             b_v1 = sprintf("%d/%d", v1$n_b_uguale[i], v1$n_b_den[i]), b_nuovo = sprintf("%d/%d", m$p$n_b_uguale[i], m$p$n_b_den[i]),
             b_oggi = sprintf("%d/%d", oggi$n_b_uguale[i], oggi$n_b_den[i]),
             errori_c_nuovo = sprintf("%d/%d", m$p$n_errori[i], m$p$n_giudicabili[i]),
             unita_v1 = nrow(u2), unita_nuovo = nrow(ug),
             causa_v1 = paste(unique(paste(u2$causa, u2$sotto, sep = "/")), collapse = "; "),
             causa_nuovo = paste(unique(paste(ug$causa, ug$sotto, sep = "/")), collapse = "; "),
             esito_nuovo = paste(unique(ug$esito), collapse = "; "),
             che_cosa_differisce = paste(unique(ug$differenza), collapse = " "), stringsAsFactors = FALSE)
}
altri <- setdiff(unique(c(u$studio, reg$studio)), c(TREDICI, TRE, QUATTRO))
cam <- do.call(rbind, c(lapply(TREDICI, una_riga, "13 non chiusi"), lapply(TRE, una_riga, "3 partizione non identica"),
                        lapply(QUATTRO, una_riga, "4 soli confronti non ritrovati"), lapply(altri, una_riga, "senza unita' in S12r2")))
utils::write.csv(cam, file.path(R3, "26-cambiato.csv"), row.names = FALSE, fileEncoding = "UTF-8")
cat("\nche cosa e' cambiato (stato v1 -> stato nuovo), per insieme:\n"); print(table(cam$insieme, paste(cam$stato_v1, "->", cam$stato_nuovo)))
cat(sprintf("studi con unita' in S12r2 e senza unita' adesso: %d (%s)\n", sum(cam$unita_v1 > 0L & cam$unita_nuovo == 0L),
            paste(cam$studio[cam$unita_v1 > 0L & cam$unita_nuovo == 0L], collapse = ", ")))
cat(sprintf("unita' di S12r2 %d, unita' adesso %d\n", nrow(d2), nrow(u)))

# ---- le attese per i 13 studi ---------------------------------------------------------------------------------------
at <- ATTESE; i <- match(at$studio, m$p$studio)
at$stato_osservato <- m$tz$stato_nuovo[i]
at$gruppi_osservati <- ifelse(at$studio %in% sb$studio, "sbagliati", ifelse(at$studio %in% gs$studio, "non_errore", ""))
at$confronti_osservati <- ifelse(m$p$n_b_den[i] == 0L, "", ifelse(m$p$n_b_uguale[i] == m$p$n_b_den[i], "ritrovati", "non_ritrovati"))
at$giusta <- at$stato == at$stato_osservato & (!nzchar(at$gruppi) | at$gruppi == at$gruppi_osservati) &
  (!nzchar(at$confronti) | at$confronti == at$confronti_osservati)
cat(sprintf("\nattese per i 13 studi: giuste %d su 13 (solo lo stato: %d su 13)\n", sum(at$giusta), sum(at$stato == at$stato_osservato)))
print(at, row.names = FALSE)
utils::write.csv(at, file.path(R3, "26-attese-13.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# ---- punto 4 della regola di esito ----------------------------------------------------------------------------------------
lettore <- u[u$esito != "non_errore", ]
senza <- lettore[lettore$esito == "modello", ]
p4 <- nrow(senza) == 0L && !any(sb$chi_la_toglie == "modello") && !any(u$lettura_modello)
cat(sprintf("\npunto 4: unita' con una causa %d su %d; unita' con causa del lettore %d (vista o schema con rimedio nominato %d; lettura del modello %d, in %d studi: %s); studi con gruppi sbagliati per lettura del modello %d; unita' non errore con una lettura del modello in piu' %d  ->  %s\n",
            nrow(u), nrow(u), nrow(lettore), sum(lettore$esito == "vista_schema"), nrow(senza), length(unique(senza$studio)),
            paste(unique(senza$studio), collapse = ", "), sum(sb$chi_la_toglie == "modello"),
            sum(u$esito == "non_errore" & u$lettura_modello), if (p4) "SI" else "NO"))

# ---- documento ------------------------------------------------------------------------------------------------------
con <- file(file.path(R3, "26-disaccordi.md"), "w", encoding = "UTF-8")
md("# PROVA DA BUTTARE: lettura di tutti i disaccordi del lettore con lo schema a elenco chiuso contro Expression Atlas (S12r3)\n")
md("Generato da `26-disaccordi.R` dalle tabelle della misura (`24-M-*`, prima corsa, misura principale: 95 confronti) e")
md("dalle cause lette a mano (`26-cause-M.txt`). **Audit interno:** le cause le ha lette un agente Claude sul materiale di")
md("`25-materiale-M.txt` (vista, uscita del modello, tabella di Atlas, incrocio dei gruppi, registro delle coppie). Non è")
md("una misura dell'articolo, e la lettura non è cieca. Gli 82 studi di giudizio non sono stati aperti. I 47 studi di")
md("sviluppo servono qui una terza volta.\n")
md("## Le unità di disaccordo\n")
tab(data.frame(`studi con unità` = length(unique(u$studio)), `unità` = nrow(u), `studio non chiuso` = sum(u$tipo == TIPI[1]),
               `partizione non identica` = sum(u$tipo == TIPI[2]), `confronto del riferimento non ritrovato` = sum(u$tipo == TIPI[3]),
               `confronto del lettore giudicato errore` = sum(u$tipo == TIPI[4]), `unità in S12r2 (schema v1)` = nrow(d2), check.names = FALSE))
md("\n## Le cause e chi le può togliere\n")
tutte <- { kr <- ifelse(u$resto_causa %in% CAUSE, paste(u$resto_causa, u$resto_sotto, sep = "/"), NA); an <- strsplit(u$anche, ";", fixed = TRUE)
  rbind(data.frame(studio = u$studio, c = chiave, dove = "prima", stringsAsFactors = FALSE),
        data.frame(studio = u$studio[!is.na(kr)], c = kr[!is.na(kr)], dove = rep("resto", sum(!is.na(kr))), stringsAsFactors = FALSE),
        data.frame(studio = rep(u$studio, lengths(an)), c = unlist(an), dove = rep("anche", sum(lengths(an))), stringsAsFactors = FALSE)) }
sp <- data.frame(causa = names(SPIEGA), `che cosa vuol dire` = unname(SPIEGA), `chi può toglierla` = unname(RIMEDIO[names(SPIEGA)]),
                 `rimedio nominato (non misurato)` = ifelse(names(SPIEGA) %in% names(NOMINATO), unname(NOMINATO[names(SPIEGA)]), ""),
                 check.names = FALSE, stringsAsFactors = FALSE)
sp[["unità (prima causa)"]] <- vapply(names(SPIEGA), function(x) sum(tutte$dove == "prima" & tutte$c == x), 0L)
sp[["studi (prima, resto o in più)"]] <- vapply(names(SPIEGA), function(x) length(unique(tutte$studio[tutte$c == x])), 0L)
tab(sp[sp[[5]] + sp[[6]] > 0L, ])
md("\n`chi può toglierla`: `schema` = un cambio dello schema delle uscite, del prompt o dell'adattatore; `vista` = un cambio")
md("della vista. Sono **proposte non misurate**. `modello` = la causa sta nella lettura del modello: questa prova non ha chi")
md("la toglie. `non_serve` = non è un errore del lettore. `strumento` = un limite della misura.\n")
md("### Prima causa per tipo di unità\n"); tab(incrocio(chiave, factor(u$tipo, TIPI)))
md("\n### Che cosa resta, tolta la prima causa\n")
tab(incrocio(chiave, ifelse(u$resto_causa %in% CAUSE, paste(u$resto_causa, u$resto_sotto, sep = "/"), u$resto_causa)))
md("\n### Esito della catena\n")
md("`non_errore`: nella catena c'è una scelta o un errore del curatore, o un limite della misura. `vista_schema`: ogni causa")
md("è di vista o di schema (proposta non misurata). `modello`: almeno una causa sta nella lettura del modello.\n")
tab(incrocio(factor(u$tipo, TIPI), u$esito))
md("\n## Gli studi che chiudono con una partizione non identica: gruppi sbagliati o gruppi diversi\n")
tab(gs[, c("studio", "stato_v1", "classe", "giudizio", "prima_causa", "chi_la_toglie", "rimedio_nominato", "confronti_formati", "errori_c", "giudicabili_c", "b_ritrovati", "differenza")])
md("\n## Che cosa è cambiato rispetto a S12r2 (schema v1)\n")
tab(cam)
md("\n## Le attese per i 13 studi che non chiudevano\n")
tab(at)
md("\n## Una riga per unità\n")
un <- u[, c("tipo", "studio", "id", "nome", "causa", "sotto", "resto_causa", "resto_sotto", "anche", "esito", "stato_v1", "stato_nuovo", "differenza", "prova")]
un$nome <- ifelse(nchar(un$nome) > 100L, paste0(substr(un$nome, 1L, 100L), "…"), un$nome)
tab(un)
close(con)
cat("\nscritto 26-disaccordi.md\n")
