# PROVA DA BUTTARE
# 26-disaccordi.R — S12r2: la lettura di TUTTI i disaccordi di ogni modello misurato contro Expression Atlas, sui 47
# studi di sviluppo (00-previsioni.md, «Che cosa si legge dopo le corse»). Audit interno: le cause le ha lette un
# agente Claude sul materiale di 25-materiale-<modello>.txt; non sono una misura dell'articolo. Gli 82 studi di
# giudizio non entrano in nessun file letto qui.
#
# Uso (SENZA --vanilla):
#   MODELLI=M,M0,G1 Rscript analysis/audit/2026-11-10-S12r2-prova-ripetuta/26-disaccordi.R > .../26-out.txt
#
# Ingressi misurati: 24-<modello>-* (misura principale, prima corsa), 27-forma-<modello>-* e 27-forma-na-<modello>-*
# (sensibilita' dichiarate dopo i numeri, 27-tollera.R), 10-confronti-atlas-oggi.csv (la pipeline di oggi).
# Ingresso scritto a mano, uno per modello (separatore «|»): 26-cause-<modello>.txt, con le colonne
#   studio|unita|id|causa|sotto|resto_causa|resto_sotto|anche|differenza|prova
#   unita = tutto (studio e confronti), studio, confronti, atlas (un confronto di Atlas, con id), lettore (un
#   confronto del lettore giudicato errore, con id). La riga piu' specifica vince.
#
# Che cosa fa: costruisce le unita' di disaccordo DAI FILE DELLA MISURA (non da un elenco a mano), da' a ognuna la
# causa letta, e si ferma se una unita' resta senza causa, se una causa non e' fra quelle ammesse, se una riga a mano
# non serve, o se una causa contraddice la misura. Scrive 26-disaccordi-<modello>-righe.csv e 26-disaccordi.md.
# Se il file delle cause di un modello manca, scrive 26-unita-<modello>.csv (le unita' con gli esiti automatici) e
# passa oltre: serve per preparare la lettura.
#
# Unita' di disaccordo (00-previsioni.md), nella lettura principale: uno studio non chiuso; uno studio chiuso con
# partizione non identica; un confronto del riferimento (in_b) non ritrovato; un confronto del lettore giudicato
# errore (piu_fattori, braccio_misto).
A <- "analysis/audit/2026-11-10-S12r2-prova-ripetuta"
MODELLI <- strsplit(Sys.getenv("MODELLI", "M,M0,G1"), ",")[[1]]
leggi <- function(f) utils::read.csv(file.path(A, f), stringsAsFactors = FALSE)
leggi_mano <- function(f) utils::read.delim(file.path(A, f), sep = "|", quote = "", stringsAsFactors = FALSE,
                                           na.strings = character(0), encoding = "UTF-8", comment.char = "")
ferma <- function(ok, ...) if (!isTRUE(ok)) stop(sprintf(...), call. = FALSE)
ch <- function(a, b) paste(a, b)
ERRORI <- c("piu_fattori", "braccio_misto")
TIPI <- c("studio_non_chiuso", "partizione_non_identica", "atlas_non_ritrovato", "lettore_errore")
CAUSE <- c("vista", "schema", "modello", "curatore", "strumento")
RESTO <- c(CAUSE, "niente_misurato", "niente_letto", "non_osservato")

# Chi puo' togliere la causa (00-previsioni.md, regola di esito, punto 4: la vista, lo schema o, per Mistral-Small
# 3.2, un modello piu' grande). `schema` e `vista` sono PROPOSTE non misurate, salvo dove la sensibilita' (27-*) le
# misura. `modello` = la causa sta nella lettura del modello: per M la toglie un modello piu' grande solo se la
# misura di G1 o G2 lo mostra (colonna `piu_grande`); per G1 e G2 non c'e' chi la toglie in questa prova.
RIMEDIO <- c(
  "modello/forma_voci" = "schema", "schema/annidato_colonna_padre" = "schema", "modello/valore_senza_voce" = "schema",
  "modello/valore_non_letterale" = "schema", "modello/colonna_non_letterale" = "schema",
  "modello/mancante_non_dichiarato" = "vista", "schema/context_senza_base" = "schema", "vista/sotto_serie" = "vista",
  "modello/fattore_per_campione" = "modello", "modello/fattore_doppio" = "modello", "modello/fattori_uniti" = "modello",
  "modello/fattore_non_visto" = "modello", "modello/fattore_inventato" = "modello", "modello/ruolo_soggetto" = "modello",
  "modello/tipo_fattore" = "modello", "modello/base" = "modello", "modello/livello" = "modello",
  "curatore/tempo_zero" = "non_serve", "curatore/riferimento" = "non_serve", "curatore/repliche" = "non_serve",
  "curatore/errore_campione" = "non_serve", "curatore/fattore_ignorato" = "non_serve",
  "curatore/fattori_combinati" = "non_serve", "curatore/livelli_uniti" = "non_serve",
  "modello/colonna_fuori_fonti" = "schema", "strumento/fattori_ridondanti" = "strumento")
SPIEGA <- c(
  "modello/forma_voci" = "una voce di `assignment` porta più valori della stessa colonna (lo schema v1 chiede una voce per valore)",
  "schema/annidato_colonna_padre" = "il modello dà «not applicable» a un fattore annidato con una condizione sulla colonna del fattore padre, che non è fra le colonne di fonte del fattore: schema e adattatore v1 non lo ammettono",
  "modello/valore_senza_voce" = "un valore della colonna di fonte resta senza voce (variante rara, cella vuota, «NA», o un elenco incompleto); le voci scritte hanno la forma giusta",
  "modello/valore_non_letterale" = "una voce porta un valore che la colonna di fonte non contiene: maiuscole diverse, stringa vuota per «None» o «-», valori di un'altra colonna o del titolo",
  "modello/colonna_non_letterale" = "un fattore dichiara una colonna di fonte che la tabella non ha, o nessuna colonna",
  "modello/mancante_non_dichiarato" = "la stringa «NA» di una colonna di soggetto non è dichiarata in `missing_values`: il costruttore la legge come un valore scritto",
  "schema/context_senza_base" = "per schema un fattore di contesto non ha livello di base: il lettore non può scrivere il confronto fra due tipi cellulari, due tessuti o due condizioni di coltura",
  "vista/sotto_serie" = "la vista porta i campioni di più sotto-serie con colonne diverse e molte celle vuote",
  "modello/fattore_per_campione" = "un fattore letto dal titolo o da un identificativo, con un livello per campione",
  "modello/fattore_doppio" = "due fattori scritti dalla stessa informazione (una colonna ripete l'altra)",
  "modello/fattori_uniti" = "due variabili del disegno scritte come un fattore solo, o una colonna di fonte che non distingue i livelli scritti",
  "modello/fattore_non_visto" = "una colonna che distingue le condizioni è giudicata non informativa",
  "modello/fattore_inventato" = "un fattore che i metadati non scrivono",
  "modello/ruolo_soggetto" = "ruolo di soggetto sbagliato: il donatore o il sesso scritti come fattore, o una colonna di condizione letta come donatore",
  "modello/tipo_fattore" = "tipo del fattore sbagliato (una malattia scritta come contesto, un contesto come stato)",
  "modello/base" = "livello di base non scritto dove c'è, o scritto dove non c'è",
  "modello/livello" = "livello sbagliato per un gruppo di campioni",
  "curatore/tempo_zero" = "Atlas usa il tempo zero come controllo",
  "curatore/riferimento" = "Atlas usa come riferimento un gruppo che non è un controllo",
  "curatore/repliche" = "Atlas tratta come repliche campioni che differiscono in una variabile sperimentale",
  "curatore/errore_campione" = "Atlas mette un campione nel gruppo sbagliato",
  "curatore/fattore_ignorato" = "Atlas ignora una colonna di GEO che distingue i campioni",
  "curatore/fattori_combinati" = "Atlas confronta due gruppi che differiscono in due fattori veri",
  "curatore/livelli_uniti" = "Atlas unisce in un livello due valori che GEO distingue",
  "modello/colonna_fuori_fonti" = "una voce porta una condizione su una colonna vera che il fattore non dichiara fra le colonne di fonte",
  "strumento/fattori_ridondanti" = "la misura (c) conta come due fattori la stessa differenza scritta due volte da Atlas")
ferma(setequal(names(RIMEDIO), names(SPIEGA)), "RIMEDIO e SPIEGA non hanno le stesse sottoclassi")

# ---- la misura di un modello: unita' ed esiti automatici ------------------------------------------------------------
oggi <- leggi("10-confronti-atlas-oggi.csv"); oggi <- oggi[oggi$lettura == "principale", ]
carica <- function(cod, pre = "24-") {
  pr <- function(x) x[x$lettura == "principale", ]
  list(s = leggi(sprintf("%s%s-studi.csv", pre, cod)), p = pr(leggi(sprintf("%s%s-per-studio.csv", pre, cod))),
       k = pr(leggi(sprintf("%s%s-confronti-atlas.csv", pre, cod))), ne = pr(leggi(sprintf("%s%s-non-elencati.csv", pre, cod))),
       rg = leggi(sprintf("%s%s-registro-coppie.csv", pre, cod)))
}
MIS <- lapply(stats::setNames(MODELLI, MODELLI), carica)
stato_studio <- function(m, g) {
  i <- match(g, m$s$studio)
  sprintf("%s/%s", ifelse(m$s$chiuso[i], "chiuso", "non chiuso"), m$p$classe_gruppi[match(g, m$p$studio)])
}
stato_k <- function(m, g, id) m$k$ritrovato[match(ch(g, id), ch(m$k$studio, m$k$id))]
unita <- function(cod) {
  m <- MIS[[cod]]; f <- carica(cod, "27-forma-"); fn <- carica(cod, "27-forma-na-")
  ferma(nrow(m$s) == 47L && identical(m$s$studio, m$p$studio) && identical(m$s$studio, f$s$studio) && identical(m$s$studio, fn$s$studio),
        "%s: attesi 47 studi nello stesso ordine in misura e sensibilita'", cod)
  ferma(setequal(ch(m$k$studio, m$k$id), ch(oggi$studio, oggi$id)), "%s: i confronti di Atlas non sono quelli di oggi", cod)
  ferma(sum(m$ne$giudizio %in% ERRORI) == sum(m$p$n_errori), "%s: i giudizi contati come errore non ridanno n_errori", cod)
  g1 <- m$s$studio[!m$s$chiuso]; g2 <- m$s$studio[m$s$chiuso & m$p$classe_gruppi != "identica"]
  us <- data.frame(tipo = rep(c("studio_non_chiuso", "partizione_non_identica"), c(length(g1), length(g2))), studio = c(g1, g2),
                   id = "", stringsAsFactors = FALSE)
  us$nome <- ifelse(us$tipo == "studio_non_chiuso", substr(m$s$motivi[match(us$studio, m$s$studio)], 1L, 200L),
                    paste("classe", m$p$classe_gruppi[match(us$studio, m$p$studio)]))
  us$forma <- stato_studio(f, us$studio); us$forma_na <- stato_studio(fn, us$studio); us$oggi <- ""
  kn <- m$k[m$k$in_b & m$k$ritrovato != "uguale", ]
  ua <- data.frame(tipo = rep("atlas_non_ritrovato", nrow(kn)), studio = kn$studio, id = kn$id, nome = kn$nome,
                   forma = stato_k(f, kn$studio, kn$id), forma_na = stato_k(fn, kn$studio, kn$id),
                   oggi = oggi$ritrovato[match(ch(kn$studio, kn$id), ch(oggi$studio, oggi$id))], stringsAsFactors = FALSE)
  ee <- m$ne[m$ne$giudizio %in% ERRORI, ]
  ue <- data.frame(tipo = rep("lettore_errore", nrow(ee)), studio = ee$studio, id = ee$id,
                   nome = sprintf("confronto del lettore %s (%d/%d), giudizio %s", ee$id, ee$n_trattato, ee$n_controllo, ee$giudizio),
                   forma = rep("", nrow(ee)), forma_na = rep("", nrow(ee)), oggi = rep("", nrow(ee)), stringsAsFactors = FALSE)
  u <- rbind(us, ua, ue)
  # la stessa unita' negli altri modelli (prima corsa, lettura principale)
  for (o in setdiff(names(MIS), cod)) {
    mo <- MIS[[o]]
    u[[paste0("in_", o)]] <- ifelse(u$tipo == "atlas_non_ritrovato", stato_k(mo, u$studio, u$id),
                                    ifelse(u$tipo == "lettore_errore", "", stato_studio(mo, u$studio)))
  }
  un <- leggi(sprintf("25-unita-%s.csv", cod))
  ferma(nrow(u) == sum(un$unita) && sum(u$tipo == "atlas_non_ritrovato") == sum(un$non_ritrovati) &&
          sum(u$tipo == "lettore_errore") == sum(un$errori), "%s: le unita' non ridanno 25-unita-%s.csv", cod, cod)
  ferma(sum(u$tipo == "atlas_non_ritrovato") == sum(m$p$n_b_den - m$p$n_b_uguale), "%s: i non ritrovati non ridanno la misura (b)", cod)
  u
}

# ---- le cause lette -------------------------------------------------------------------------------------------------
cause <- function(cod, u) {
  cs <- leggi_mano(sprintf("26-cause-%s.txt", cod))
  ferma(identical(names(cs), c("studio", "unita", "id", "causa", "sotto", "resto_causa", "resto_sotto", "anche", "differenza", "prova")),
        "%s: intestazione del file delle cause", cod)
  ferma(all(cs$unita %in% c("tutto", "studio", "confronti", "atlas", "lettore")), "%s: unita' non ammessa", cod)
  ferma(!anyDuplicated(paste(cs$studio, cs$unita, cs$id)), "%s: righe doppie nelle cause", cod)
  ferma(all(nzchar(cs$id) == cs$unita %in% c("atlas", "lettore")), "%s: l'id va scritto solo per le righe atlas e lettore", cod)
  usate <- logical(nrow(cs)); campi <- c("causa", "sotto", "resto_causa", "resto_sotto", "anche", "differenza", "prova")
  for (n in campi) u[[n]] <- ""
  for (i in seq_len(nrow(u))) {
    che <- switch(u$tipo[i], atlas_non_ritrovato = c("atlas", "confronti"), lettore_errore = c("lettore", "lettore"), c("", "studio"))
    j <- which(cs$studio == u$studio[i] & cs$unita == che[1] & cs$id == u$id[i] & nzchar(che[1]))
    if (!length(j) && u$tipo[i] != "lettore_errore") j <- which(cs$studio == u$studio[i] & cs$unita %in% c("tutto", che[2]))
    ferma(length(j) == 1L, "%s %s %s %s: %d righe di causa (attesa 1)", cod, u$studio[i], u$tipo[i], u$id[i], length(j))
    usate[j] <- TRUE; u[i, campi] <- cs[j, campi]
    # la prova dello studio vale anche per il confronto che ha una riga sua senza prova
    if (!nzchar(u$prova[i])) { t <- which(cs$studio == u$studio[i] & cs$unita %in% c("tutto", "confronti", "studio") & nzchar(cs$prova)); if (length(t)) u$prova[i] <- cs$prova[t[1]] }
  }
  ferma(all(usate), "%s: righe di causa che non servono a nessuna unita': %s", cod, paste(ch(cs$studio, cs$unita)[!usate], collapse = ", "))
  chiave <- paste(u$causa, u$sotto, sep = "/"); ha_resto <- u$resto_causa %in% CAUSE
  chiave_r <- ifelse(ha_resto, paste(u$resto_causa, u$resto_sotto, sep = "/"), "")
  ferma(all(chiave %in% names(RIMEDIO)), "%s: sottoclasse non nota: %s", cod, paste(unique(chiave[!chiave %in% names(RIMEDIO)]), collapse = ", "))
  ferma(all(u$resto_causa %in% RESTO), "%s: resto non ammesso: %s", cod, paste(unique(u$resto_causa[!u$resto_causa %in% RESTO]), collapse = ", "))
  ferma(all(chiave_r[ha_resto] %in% names(RIMEDIO)), "%s: sottoclasse del resto non nota: %s", cod, paste(unique(chiave_r[ha_resto & !chiave_r %in% names(RIMEDIO)]), collapse = ", "))
  an <- unlist(strsplit(u$anche[nzchar(u$anche)], ";", fixed = TRUE))
  ferma(all(an %in% names(RIMEDIO)), "%s: sottoclasse «anche» non nota: %s", cod, paste(unique(an[!an %in% names(RIMEDIO)]), collapse = ", "))
  ferma(all(nzchar(u$differenza)), "%s: unita' senza «che cosa differisce»", cod)
  cur <- u$causa == "curatore" | u$resto_causa == "curatore"
  ferma(all(nzchar(u$prova[cur])), "%s: causa «curatore» senza prova: %s", cod, paste(unique(u$studio[cur & !nzchar(u$prova)]), collapse = ", "))
  # «tolta la prima causa non resta niente (misurato)» deve essere quello che la sensibilita' misura, e viceversa.
  # La sensibilita' piu' larga e' forma_na (T1 + T2 + T3).
  a <- u$tipo == "atlas_non_ritrovato"; d <- (u$resto_causa[a] == "niente_misurato") != (u$forma_na[a] == "uguale")
  ferma(!any(d), "%s: confronti: «niente_misurato» non coincide con «ritrovato nella sensibilita'»: %s", cod, paste(ch(u$studio[a], u$id[a])[d], collapse = ", "))
  s <- u$tipo == "studio_non_chiuso"; d <- (u$resto_causa[s] == "niente_misurato") != (u$forma_na[s] == "chiuso/identica")
  ferma(!any(d), "%s: studi: «niente_misurato» non coincide con «chiuso e identico nella sensibilita'»: %s", cod, paste(u$studio[s][d], collapse = ", "))
  ferma(all(!(u$resto_causa[s] == "non_osservato" & grepl("^chiuso", u$forma_na[s]))), "%s: «non_osservato» su uno studio che la sensibilita' chiude", cod)
  u$rimedio <- unname(RIMEDIO[chiave]); u$rimedio_resto <- ifelse(ha_resto, unname(RIMEDIO[chiave_r]), "")
  # esito della catena:
  #   non_errore     nella catena c'e' una scelta o un errore del curatore, o un limite della misura
  #   forma          la sensibilita' dichiarata toglie il disaccordo: MISURATO
  #   modello        almeno una causa della catena sta nella lettura del modello
  #   vista_schema   ogni causa della catena e' di vista o di schema: PROPOSTA non misurata
  u$esito <- vapply(seq_len(nrow(u)), function(i) {
    r <- c(u$rimedio[i], if (nzchar(u$rimedio_resto[i])) u$rimedio_resto[i])
    if (any(r %in% c("non_serve", "strumento"))) "non_errore"
    else if (u$resto_causa[i] == "niente_misurato") "forma"
    else if (any(r == "modello")) "modello"
    else "vista_schema"
  }, "")
  # una causa di lettura del modello (RIMEDIO = modello) in un punto qualsiasi: prima causa, resto o «anche».
  # Serve al punto 4 della regola di esito: l'esito `non_errore` non nasconde una causa del lettore.
  u$lettura_modello <- vapply(seq_len(nrow(u)), function(i) {
    k <- c(chiave[i], if (ha_resto[i]) chiave_r[i], strsplit(u$anche[i], ";", fixed = TRUE)[[1]])
    any(RIMEDIO[k] == "modello")
  }, NA)
  # un modello piu' grande toglie l'unita'? Misurato sulla stessa unita' nelle prime corse di G1 e G2.
  grandi <- intersect(setdiff(c("G1", "G2"), cod), names(MIS))
  u$piu_grande <- vapply(seq_len(nrow(u)), function(i) {
    if (!cod %in% c("M", "M0") || !length(grandi) || u$tipo[i] == "lettore_errore") return("")
    ok <- vapply(grandi, function(o) { x <- u[[paste0("in_", o)]][i]; x %in% c("uguale", "chiuso/identica") }, NA)
    if (any(ok)) paste(grandi[ok], collapse = ",") else "nessuno"
  }, "")
  u
}

# ---- conti e documento ----------------------------------------------------------------------------------------------
md <- function(...) cat(..., "\n", sep = "", file = con)
tab <- function(d) {
  if (!nrow(d)) { md("(nessuna riga)"); return(invisible()) }
  md("| ", paste(names(d), collapse = " | "), " |"); md("|", paste(rep("---", ncol(d)), collapse = "|"), "|")
  for (i in seq_len(nrow(d))) md("| ", paste(gsub("|", "/", vapply(d[i, ], as.character, ""), fixed = TRUE), collapse = " | "), " |")
}
incrocio <- function(r, c) { t <- table(r, c); d <- data.frame(x = rownames(t), unclass(t), check.names = FALSE, stringsAsFactors = FALSE); d$totale <- rowSums(t); names(d)[1] <- ""; d }
U <- list()
for (cod in MODELLI) {
  u <- unita(cod)
  cat(sprintf("\n=== %s: unita' di disaccordo %d (%s), in %d studi su 47\n", cod, nrow(u),
              paste(sprintf("%s %d", TIPI, vapply(TIPI, function(t) sum(u$tipo == t), 0L)), collapse = "; "), length(unique(u$studio))))
  if (!file.exists(file.path(A, sprintf("26-cause-%s.txt", cod)))) {
    utils::write.csv(u, file.path(A, sprintf("26-unita-%s.csv", cod)), row.names = FALSE, fileEncoding = "UTF-8")
    cat(sprintf("%s: il file delle cause manca; scritto 26-unita-%s.csv\n", cod, cod)); next
  }
  u <- cause(cod, u); u$modello <- cod; U[[cod]] <- u
  utils::write.csv(u, file.path(A, sprintf("26-disaccordi-%s-righe.csv", cod)), row.names = FALSE, fileEncoding = "UTF-8")
  chiave <- paste(u$causa, u$sotto, sep = "/")
  cat("prima causa per tipo di unita':\n"); print(table(chiave, factor(u$tipo, TIPI)))
  cat("esito della catena per tipo di unita':\n"); print(table(factor(u$tipo, TIPI), u$esito))
  if (cod %in% c("M", "M0") && any(nzchar(u$piu_grande))) {
    cat("unita' con esito «modello»: un modello piu' grande le toglie? (misurato)\n"); print(table(chiave[u$esito == "modello"], u$piu_grande[u$esito == "modello"]))
    cat("tutte le unita' di atlas e di studio: stessa unita' nei modelli piu' grandi\n"); print(table(u$esito[nzchar(u$piu_grande)], u$piu_grande[nzchar(u$piu_grande)]))
  }
  st <- unique(data.frame(studio = u$studio, c = chiave, stringsAsFactors = FALSE))
  cat("studi per prima causa (uno studio conta una volta per causa):\n"); print(sort(table(st$c), decreasing = TRUE))
  cat(sprintf("%s: unita' con una causa di lettura del modello in un punto qualsiasi della catena: %d (in %d studi)\n", cod,
              sum(u$lettura_modello), length(unique(u$studio[u$lettura_modello]))))
  print(table(esito = u$esito, lettura_modello = u$lettura_modello))
  cat(sprintf("punto 4 della regola di esito, %s: unita' con una causa %d su %d; unita' con esito «modello» %d (in %d studi)%s\n", cod, nrow(u), nrow(u),
              sum(u$esito == "modello"), length(unique(u$studio[u$esito == "modello"])),
              if (cod %in% c("M", "M0") && any(nzchar(u$piu_grande))) sprintf("; di queste, tolte da un modello piu' grande misurato: %d",
                                                                    sum(u$esito == "modello" & !u$piu_grande %in% c("nessuno", ""))) else ""))
}
if (!length(U)) quit(save = "no")

con <- file(file.path(A, "26-disaccordi.md"), "w", encoding = "UTF-8")
md("# PROVA DA BUTTARE: lettura di tutti i disaccordi del lettore v1 contro Expression Atlas (S12r2)\n")
md("Generato da `26-disaccordi.R` dalle tabelle della misura (`24-*`, prima corsa, lettura principale), dalle sensibilità")
md("dichiarate dopo i numeri (`27-forma-*`, `27-forma-na-*`) e dalle cause lette a mano (`26-cause-<modello>.txt`).")
md("**Audit interno:** le cause le ha lette un agente Claude sul materiale di `25-materiale-<modello>.txt` (vista, uscita")
md("del modello, tabella di Atlas, incrocio dei gruppi, registro delle coppie). Non è una misura dell'articolo. Gli 82")
md("studi di giudizio non sono stati aperti. I 47 studi di sviluppo servono qui una seconda volta.\n")
md("Modelli: M = Mistral-Small 3.2 (24B) con `repetition_penalty` 1,1; M0 = lo stesso senza penalità; G1 =")
md("Mistral-Small-4-119B; G2 = Qwen3.5-122B-A10B (se misurato).\n")
md("## Le unità di disaccordo\n")
tab(do.call(rbind, lapply(names(U), function(cod) { u <- U[[cod]]
  data.frame(modello = cod, `studi con unità` = length(unique(u$studio)), `unità` = nrow(u), `studio non chiuso` = sum(u$tipo == TIPI[1]),
             `partizione non identica` = sum(u$tipo == TIPI[2]), `confronto del riferimento non ritrovato` = sum(u$tipo == TIPI[3]),
             `confronto del lettore giudicato errore` = sum(u$tipo == TIPI[4]), check.names = FALSE, stringsAsFactors = FALSE) })))
md("\nOgni unità ha una **prima causa** (il primo difetto che la misura principale incontra) e un **resto** (che cosa resta")
md("quando la prima causa è tolta). Il resto è `niente_misurato` quando la sensibilità più larga (`27-forma-na-*`) toglie il")
md("disaccordo, `niente_letto` quando la lettura non vede altro, `non_osservato` quando lo studio non chiude nemmeno nella")
md("sensibilità e la lettura non può dire che cosa resta. Lo script si ferma se «niente_misurato» non coincide con la misura.\n")
md("## Le cause e chi le può togliere\n")
tutte <- do.call(rbind, lapply(names(U), function(cod) { u <- U[[cod]]; k1 <- paste(u$causa, u$sotto, sep = "/")
  kr <- ifelse(u$resto_causa %in% CAUSE, paste(u$resto_causa, u$resto_sotto, sep = "/"), NA)
  an <- strsplit(u$anche, ";", fixed = TRUE)
  rbind(data.frame(modello = cod, studio = u$studio, c = k1, dove = "prima", stringsAsFactors = FALSE),
        data.frame(modello = cod, studio = u$studio[!is.na(kr)], c = kr[!is.na(kr)], dove = rep("resto", sum(!is.na(kr))), stringsAsFactors = FALSE),
        data.frame(modello = rep(cod, sum(lengths(an))), studio = rep(u$studio, lengths(an)), c = unlist(an), dove = rep("anche", sum(lengths(an))), stringsAsFactors = FALSE)) }))
sp <- data.frame(causa = names(SPIEGA), `che cosa vuol dire` = unname(SPIEGA), `chi può toglierla` = unname(RIMEDIO[names(SPIEGA)]), check.names = FALSE, stringsAsFactors = FALSE)
for (cod in names(U)) {
  sp[[paste(cod, "unità (prima causa)")]] <- vapply(names(SPIEGA), function(x) sum(tutte$modello == cod & tutte$dove == "prima" & tutte$c == x), 0L)
  sp[[paste(cod, "studi (prima, resto o in più)")]] <- vapply(names(SPIEGA), function(x) length(unique(tutte$studio[tutte$modello == cod & tutte$c == x])), 0L)
}
tab(sp[rowSums(sp[, -(1:3), drop = FALSE]) > 0L, ])
md("\n`chi può toglierla`: `schema` = un cambio dello schema, del prompt o dell'adattatore. Per `modello/forma_voci`,")
md("`modello/colonna_fuori_fonti` e `schema/annidato_colonna_padre` l'effetto è misurato dalla sensibilità `forma`; per `modello/mancante_non_dichiarato`")
md("dalla sensibilità `forma_na`. Per `modello/valore_senza_voce`, `modello/valore_non_letterale` e")
md("`modello/colonna_non_letterale` la proposta è uno schema generato per ogni studio, in cui colonne e valori sono un")
md("elenco chiuso e ogni valore distinto ha la sua voce: **non è misurata**. `vista` = un cambio della vista, non misurato")
md("salvo `forma_na`. `modello` = la causa sta nella lettura del modello: per M la toglie un modello più grande solo dove la")
md("misura di G1 o G2 lo mostra; per G1 e G2 questa prova non ha chi la toglie. `non_serve` = non è un errore del lettore.\n")
for (cod in names(U)) {
  u <- U[[cod]]; chiave <- paste(u$causa, u$sotto, sep = "/")
  md(sprintf("\n## %s\n", cod))
  md("### Prima causa per tipo di unità\n"); tab(incrocio(chiave, factor(u$tipo, TIPI)))
  md("\n### Che cosa resta, tolta la prima causa\n")
  tab(incrocio(chiave, ifelse(u$resto_causa %in% CAUSE, paste(u$resto_causa, u$resto_sotto, sep = "/"), u$resto_causa)))
  md("\n### Esito della catena\n")
  md("`non_errore`: nella catena c'è una scelta o un errore del curatore, o un limite della misura. `forma`: la sensibilità")
  md("dichiarata toglie il disaccordo (misurato). `vista_schema`: ogni causa è di vista o di schema (proposta non misurata).")
  md("`modello`: almeno una causa sta nella lettura del modello.\n")
  tab(incrocio(factor(u$tipo, TIPI), u$esito))
  if (cod %in% c("M", "M0") && any(nzchar(u$piu_grande))) {
    md(sprintf("\n### Un modello più grande toglie l'unità? (misurato sulla stessa unità, prime corse)\n"))
    md("`nessuno` = l'unità resta in ogni modello più grande misurato. Gli errori del lettore non hanno un'unità corrispondente.\n")
    x <- nzchar(u$piu_grande); tab(incrocio(u$esito[x], u$piu_grande[x]))
    md(""); tab(incrocio(chiave[x & u$esito == "modello"], u$piu_grande[x & u$esito == "modello"]))
  }
  md(sprintf("\n### %s: una riga per studio\n", cod))
  tab(do.call(rbind, lapply(unique(u$studio), function(g) { ug <- u[u$studio == g, ]
    che <- c(if (any(ug$tipo == TIPI[1])) "non chiuso", if (any(ug$tipo == TIPI[2])) sub("classe", "partizione", ug$nome[ug$tipo == TIPI[2]]),
             if (any(ug$tipo == TIPI[3])) sprintf("%d confronti non ritrovati", sum(ug$tipo == TIPI[3])),
             if (any(ug$tipo == TIPI[4])) sprintf("%d confronti del lettore giudicati errore", sum(ug$tipo == TIPI[4])))
    rr <- unique(ifelse(ug$resto_causa %in% CAUSE, paste(ug$resto_causa, ug$resto_sotto, sep = "/"), ug$resto_causa))
    data.frame(studio = g, disaccordi = paste(che, collapse = "; "), `che cosa differisce` = paste(unique(ug$differenza), collapse = " "),
               `prima causa` = paste(unique(paste(ug$causa, ug$sotto, sep = "/")), collapse = "; "), resto = paste(rr, collapse = "; "),
               `in più` = paste(unique(ug$anche[nzchar(ug$anche)]), collapse = "; "), esito = paste(unique(ug$esito), collapse = "; "),
               `sensibilità (forma; forma_na)` = paste(unique(sprintf("%s; %s", ug$forma, ug$forma_na)[ug$tipo != TIPI[4]]), collapse = " // "),
               prova = paste(unique(ug$prova[nzchar(ug$prova)]), collapse = " "), check.names = FALSE, stringsAsFactors = FALSE) })))
  md(sprintf("\n### %s: una riga per unità\n", cod))
  md("`forma`, `forma_na` = la stessa unità nelle due sensibilità; `in_<modello>` = la stessa unità nella prima corsa di un altro modello; `oggi` = la pipeline di oggi sullo stesso confronto.\n")
  un <- u[, c("tipo", "studio", "id", "nome", "causa", "sotto", "resto_causa", "resto_sotto", "esito", "forma", "forma_na",
              grep("^in_", names(u), value = TRUE), "oggi", "piu_grande")]
  un$nome <- ifelse(nchar(un$nome) > 100L, paste0(substr(un$nome, 1L, 100L), "…"), un$nome)
  tab(un)
}
close(con)
cat(sprintf("\nscritto 26-disaccordi.md (%s)\n", paste(names(U), collapse = ", ")))
