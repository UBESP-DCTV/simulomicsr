# PROVA DA BUTTARE
# 65-disaccordi.R — la lettura di TUTTI i disaccordi del lettore v0 contro Atlas (Task 10, passo 5 del piano del
# lettore dello studio, S12r). Audit interno: le cause le ha lette un agente Claude sul materiale di
# 65-materiale.txt; non sono una misura dell'articolo.
#
# Uso (SENZA --vanilla): Rscript analysis/audit/2026-11-09-lettore-studio/65-disaccordi.R > .../65-out.txt
#
# Ingressi scritti a mano (separatore «|»):
#   65-cause-studi.txt      una riga per studio con almeno un disaccordo (due se lo studio e i suoi confronti hanno
#                           una catena diversa): causa, sottoclasse, che cosa resta tolta la prima causa, prova.
#   65-cause-confronti.txt  le eccezioni: i confronti che hanno una causa diversa da quella dello studio.
# Ingressi misurati: 64-* (misura principale), 66-forma-* (sensibilita' dichiarata), 40-confronti-atlas-oggi.csv.
#
# Che cosa fa: costruisce l'elenco delle unita' di disaccordo DAI FILE DELLA MISURA (non da un elenco a mano), da'
# a ognuna la causa letta, e si ferma se una unita' resta senza causa, se una causa non e' fra le cinque ammesse,
# se una riga scritta a mano non serve a niente, o se una causa contraddice la misura (per esempio «tolta la forma
# delle voci non resta niente» dove la sensibilita' non ritrova il confronto). Scrive 65-disaccordi-righe.csv e
# 65-disaccordi.md.
#
# Unita' di disaccordo (il brief): ogni studio non chiuso; ogni studio chiuso con partizione non identica; ogni
# confronto di Atlas non ritrovato (tutte le classi: anche `piu_fattori` e `non_formabile`, che stanno fuori dal
# denominatore della misura (b)); ogni confronto del lettore giudicato errore.
A <- "analysis/audit/2026-11-09-lettore-studio"
leggi <- function(f) utils::read.csv(file.path(A, f), stringsAsFactors = FALSE)
leggi_mano <- function(f) utils::read.delim(file.path(A, f), sep = "|", quote = "", stringsAsFactors = FALSE,
                                           na.strings = character(0), encoding = "UTF-8", comment.char = "")
ferma <- function(ok, ...) if (!isTRUE(ok)) stop(sprintf(...), call. = FALSE)

CAUSE <- c("vista", "schema", "modello", "curatore", "strumento")
RESTO <- c(CAUSE, "niente_misurato", "niente_letto", "non_osservato")
# Chi puo' togliere la causa. `modello` vuol dire: serve un modello che legge meglio. E' una ipotesi: questa prova
# non ha misurato nessun altro modello.
RIMEDIO <- c("modello/forma_voci" = "schema", "modello/non_coperta" = "modello", "modello/mappa_ambigua" = "modello",
             "modello/fattore_dal_titolo" = "modello", "modello/fattore_doppio" = "modello",
             "modello/ruolo_soggetto" = "modello", "modello/base" = "modello", "modello/livello" = "modello",
             "schema/context_senza_base" = "schema", "schema/soggetto_NA" = "schema",
             "schema/fattore_annidato" = "schema", "curatore/tempo_zero" = "non_serve",
             "curatore/riferimento" = "non_serve", "curatore/repliche" = "non_serve",
             "curatore/errore_campione" = "non_serve", "curatore/fattore_ignorato" = "non_serve",
             "curatore/fattori_combinati" = "non_serve", "strumento/universo" = "non_serve",
             "strumento/fattori_ridondanti" = "strumento")
SPIEGA <- c(
  "modello/forma_voci" = "una voce di `assignment` porta più valori di quante sono le colonne di fonte",
  "modello/non_coperta" = "una combinazione di valori della tabella resta senza voce (le voci hanno la forma giusta)",
  "modello/mappa_ambigua" = "la stessa combinazione di valori ha due livelli",
  "modello/fattore_dal_titolo" = "un fattore tecnico o di replica letto dal titolo o da un identificativo: un livello per campione",
  "modello/fattore_doppio" = "due fattori scritti dalla stessa informazione",
  "modello/ruolo_soggetto" = "ruolo di soggetto sbagliato (una colonna di condizione letta come donatore, o il passaggio scritto come fattore)",
  "modello/base" = "livello di base non scritto dove c'è",
  "modello/livello" = "livello sbagliato per un gruppo (controlli a «not stated», o un livello dove serviva «not stated»)",
  "schema/context_senza_base" = "per schema un fattore di contesto non ha livello di base: il lettore non può scrivere il confronto fra due condizioni di coltura o due tipi cellulari",
  "schema/soggetto_NA" = "lo schema non dice quali valori di una colonna di soggetto valgono «non scritto» (la stringa «NA»)",
  "schema/fattore_annidato" = "un fattore che esiste solo dentro un livello di un altro (sottotipo, stadio): schema e prompt non dicono come scriverlo",
  "curatore/tempo_zero" = "Atlas usa il tempo zero come controllo",
  "curatore/riferimento" = "Atlas usa come riferimento un gruppo che non è un controllo",
  "curatore/repliche" = "Atlas tratta come repliche campioni che differiscono in una variabile sperimentale",
  "curatore/errore_campione" = "Atlas mette un campione nel gruppo sbagliato",
  "curatore/fattore_ignorato" = "Atlas ignora una colonna di GEO che distingue i campioni",
  "curatore/fattori_combinati" = "Atlas confronta due gruppi che differiscono in due fattori veri",
  "strumento/universo" = "il confronto di Atlas non ha campioni di un braccio nell'universo della misura",
  "strumento/fattori_ridondanti" = "la misura (c) conta come due fattori la stessa differenza scritta due volte da Atlas")
ferma(setequal(names(RIMEDIO), names(SPIEGA)), "RIMEDIO e SPIEGA non hanno le stesse sottoclassi")

# ---- la misura ------------------------------------------------------------------------------------------------------
p <- leggi("64-per-studio-lettore.csv"); f <- leggi("66-forma-per-studio-lettore.csv")
k <- leggi("64-confronti-atlas-lettore.csv"); kf <- leggi("66-forma-confronti-atlas-lettore.csv")
ne <- leggi("64-non-elencati-lettore.csv"); nef <- leggi("66-forma-non-elencati-lettore.csv")
rg <- leggi("64-registro-coppie.csv"); rgf <- leggi("66-forma-registro-coppie.csv")
o <- leggi("40-confronti-atlas-oggi.csv"); o <- o[o$variante == "principale", ]
ferma(nrow(p) == 47L && identical(p$studio, f$studio), "per-studio: attesi 47 studi nello stesso ordine")
ch <- function(a, b) paste(a, b)
ferma(setequal(ch(k$studio, k$id), ch(kf$studio, kf$id)) && setequal(ch(k$studio, k$id), ch(o$studio, o$id)),
      "i confronti di Atlas non sono gli stessi nelle tre tabelle")
k$forma <- kf$ritrovato[match(ch(k$studio, k$id), ch(kf$studio, kf$id))]
k$oggi <- o$ritrovato[match(ch(k$studio, k$id), ch(o$studio, o$id))]
ERRORI <- c("piu_fattori", "braccio_misto")  # i giudizi che la misura (c) conta come errore
ferma(sum(ne$giudizio %in% ERRORI) == sum(p$n_errori) && sum(nef$giudizio %in% ERRORI) == sum(f$n_errori),
      "i giudizi contati come errore non ridanno n_errori")

u_stu <- rbind(
  data.frame(tipo = "studio_non_chiuso", studio = p$studio[!p$chiuso], stringsAsFactors = FALSE),
  data.frame(tipo = "partizione_non_identica", studio = p$studio[p$chiuso & p$classe_gruppi != "identica"], stringsAsFactors = FALSE))
u_stu$id <- ""; u_stu$nome <- ifelse(u_stu$tipo == "studio_non_chiuso", substr(p$motivi[match(u_stu$studio, p$studio)], 1L, 160L),
                                     paste("classe", p$classe_gruppi[match(u_stu$studio, p$studio)]))
u_stu$classe <- ""; u_stu$forma <- sprintf("%s/%s", ifelse(f$chiuso[match(u_stu$studio, f$studio)], "chiuso", "non chiuso"),
                                           f$classe_gruppi[match(u_stu$studio, f$studio)])
u_stu$oggi <- ""
kn <- k[k$ritrovato != "uguale", ]
u_atl <- data.frame(tipo = "atlas_non_ritrovato", studio = kn$studio, id = kn$id, nome = kn$nome, classe = kn$classe,
                    forma = kn$forma, oggi = kn$oggi, stringsAsFactors = FALSE)
ee <- ne[ne$giudizio %in% ERRORI, ]
u_let <- data.frame(tipo = "lettore_errore", studio = ee$studio, id = ee$id,
                    nome = sprintf("%s: «%s» contro «%s» (%d/%d), giudizio %s", ee$fattore, ee$livello_trattato, ee$livello_base,
                                   ee$n_trattato, ee$n_controllo, ee$giudizio), classe = "", forma = "", oggi = "", stringsAsFactors = FALSE)
u <- rbind(u_stu, u_atl, u_let)
# i conti delle unita' devono ridare la tabella per studio
ferma(sum(u$tipo == "studio_non_chiuso") == sum(!p$chiuso), "non chiusi")
ferma(sum(u$tipo == "atlas_non_ritrovato" & u$classe == "rispetta") == sum(p$n_rispetta - p$n_rispetta_uguale),
      "i confronti `rispetta` non ritrovati non ridanno la misura (b)")
ferma(sum(u$tipo == "lettore_errore") == sum(p$n_errori), "errori del lettore")

# ---- le cause lette ---------------------------------------------------------------------------------------------------
cs <- leggi_mano("65-cause-studi.txt"); cc <- leggi_mano("65-cause-confronti.txt")
ferma(all(cs$unita %in% c("tutto", "studio", "confronti")), "65-cause-studi: unita' non ammessa")
ferma(!anyDuplicated(ch(cs$studio, cs$unita)) && !anyDuplicated(paste(cc$studio, cc$tipo, cc$id)), "righe doppie nelle cause")
riga_studio <- function(g, che) {
  i <- which(cs$studio == g & cs$unita %in% c("tutto", che))
  ferma(length(i) == 1L, "%s: %d righe di causa per l'unita' «%s» (attesa 1)", g, length(i), che)
  i
}
usate_s <- logical(nrow(cs)); usate_c <- logical(nrow(cc))
campi <- c("causa", "sotto", "resto_causa", "resto_sotto")
for (n in c(campi, "anche", "differenza", "prova")) u[[n]] <- ""
for (i in seq_len(nrow(u))) {
  tc <- switch(u$tipo[i], atlas_non_ritrovato = "atlas", lettore_errore = "lettore", "")
  j <- if (nzchar(tc)) which(cc$studio == u$studio[i] & cc$tipo == tc & cc$id == u$id[i]) else integer(0)
  if (u$tipo[i] == "lettore_errore") ferma(length(j) == 1L, "%s %s: un errore del lettore vuole la sua riga in 65-cause-confronti.txt", u$studio[i], u$id[i])
  s <- riga_studio(u$studio[i], if (nzchar(tc)) "confronti" else "studio")
  if (u$tipo[i] != "lettore_errore") usate_s[s] <- TRUE
  u[i, c("anche", "prova")] <- cs[s, c("anche", "prova")]
  if (length(j)) {
    usate_c[j] <- TRUE; u[i, campi] <- cc[j, campi]; u$differenza[i] <- cc$differenza[j]
  } else {
    u[i, campi] <- cs[s, campi]; u$differenza[i] <- cs$differenza[s]
  }
}
ferma(all(usate_s), "65-cause-studi: righe che non servono a nessuna unita': %s", paste(ch(cs$studio, cs$unita)[!usate_s], collapse = ", "))
cc_forma <- cc$tipo == "lettore_forma"
ferma(all(usate_c | cc_forma), "65-cause-confronti: righe che non servono a nessuna unita'")

# ---- controlli: ogni unita' ha una causa ammessa, e la causa non contraddice la misura -------------------------------
chiave <- paste(u$causa, u$sotto, sep = "/")
ferma(all(u$causa %in% CAUSE), "causa non ammessa: %s", paste(unique(u$causa[!u$causa %in% CAUSE]), collapse = ", "))
ferma(all(chiave %in% names(RIMEDIO)), "sottoclasse non nota: %s", paste(unique(chiave[!chiave %in% names(RIMEDIO)]), collapse = ", "))
ferma(all(u$resto_causa %in% RESTO), "resto non ammesso")
ha_resto <- u$resto_causa %in% CAUSE
chiave_r <- ifelse(ha_resto, paste(u$resto_causa, u$resto_sotto, sep = "/"), "")
ferma(all(chiave_r[ha_resto] %in% names(RIMEDIO)), "sottoclasse del resto non nota: %s", paste(unique(chiave_r[ha_resto & !chiave_r %in% names(RIMEDIO)]), collapse = ", "))
ferma(all(nzchar(u$differenza)), "unita' senza «che cosa differisce»")
cur <- u$causa == "curatore" | u$resto_causa == "curatore"
ferma(all(nzchar(u$prova[cur])), "causa «curatore» senza prova")
# «tolta la forma delle voci non resta niente» deve essere quello che la sensibilita' misura, e viceversa
a <- u$tipo == "atlas_non_ritrovato"
ferma(identical(u$resto_causa[a] == "niente_misurato", u$forma[a] == "uguale"),
      "confronti: «niente_misurato» non coincide con «ritrovato nella sensibilita'»: %s",
      paste(ch(u$studio[a], u$id[a])[(u$resto_causa[a] == "niente_misurato") != (u$forma[a] == "uguale")], collapse = ", "))
s <- u$tipo == "studio_non_chiuso"
ferma(identical(u$resto_causa[s] == "niente_misurato", u$forma[s] == "chiuso/identica"),
      "studi: «niente_misurato» non coincide con «chiuso e identico nella sensibilita'»: %s",
      paste(u$studio[s][(u$resto_causa[s] == "niente_misurato") != (u$forma[s] == "chiuso/identica")], collapse = ", "))
ferma(all(u$causa[s] == "modello"), "uno studio non chiuso ha una prima causa diversa da «modello»")
ferma(all(u$sotto[s & u$resto_causa != "non_osservato" & grepl("^chiuso", u$forma)] == "forma_voci"),
      "uno studio che la sensibilita' chiude non ha «forma_voci» come prima causa")
ferma(all(!(u$resto_causa[s] == "non_osservato" & grepl("^chiuso", u$forma[s]))),
      "«non_osservato» su uno studio che la sensibilita' chiude")
# i motivi del registro citati nelle righe a mano
conta_rg <- function(r, g, m) sum(r$studio == g & r$motivo == m)
ferma(conta_rg(rg, "GSE47718", "soggetti_disgiunti") == 1L && conta_rg(rg, "GSE58365", "fattore_senza_base") == 1L &&
        conta_rg(rg, "GSE50499", "piu_di_un_fattore") >= 1L && conta_rg(rg, "GSE103501", "piu_di_un_fattore") == 10L &&
        conta_rg(rg, "GSE60340", "piu_di_un_fattore") == 25L && conta_rg(rgf, "GSE112057", "soggetti_disgiunti") == 5L &&
        conta_rg(rgf, "GSE63816", "piu_di_un_fattore") == 8L, "un motivo del registro citato nelle cause non torna")

# ---- che cosa serve per togliere il disaccordo ---------------------------------------------------------------------
u$rimedio <- unname(RIMEDIO[chiave]); u$rimedio_resto <- ifelse(ha_resto, unname(RIMEDIO[chiave_r]), "")
# esito della catena: che cosa serve perche' il disaccordo sparisca
#   non_errore  nella catena c'e' una scelta o un errore del curatore, o un limite della misura: un lettore senza
#               difetti non ritrova comunque il confronto (o non da' la partizione di Atlas)
#   forma       basta leggere le voci malformate: MISURATO dalla sensibilita'
#   schema      ogni causa della catena e' di schema (o forma delle voci)
#   modello     almeno una causa della catena chiede un modello che legge meglio: ipotesi non misurata
#   ignoto      lo studio non chiude nemmeno nella sensibilita' e la lettura non dice che cosa resta
tutti <- function(i) c(u$rimedio[i], if (nzchar(u$rimedio_resto[i])) u$rimedio_resto[i])
u$esito <- vapply(seq_len(nrow(u)), function(i) {
  r <- tutti(i)
  if (any(r %in% c("non_serve", "strumento"))) "non_errore"
  else if (u$resto_causa[i] == "niente_misurato") "forma"
  else if (any(r == "modello")) "modello"
  else if (u$resto_causa[i] == "non_osservato") "ignoto"
  else "schema"
}, "")
utils::write.csv(u[, c("tipo", "studio", "id", "nome", "classe", "causa", "sotto", "resto_causa", "resto_sotto", "anche",
                       "rimedio", "rimedio_resto", "esito", "forma", "oggi", "differenza", "prova")],
                 file.path(A, "65-disaccordi-righe.csv"), row.names = FALSE, fileEncoding = "UTF-8")

# ---- conti ------------------------------------------------------------------------------------------------------------
TIPI <- c("studio_non_chiuso", "partizione_non_identica", "atlas_non_ritrovato", "lettore_errore")
cat(sprintf("unita' di disaccordo: %d (%s)\n", nrow(u), paste(sprintf("%s %d", TIPI, vapply(TIPI, function(t) sum(u$tipo == t), 0L)), collapse = "; ")))
cat(sprintf("studi con almeno un disaccordo: %d su 47; studi senza: %s\n", length(unique(u$studio)), paste(setdiff(p$studio, u$studio), collapse = ", ")))
cat("\nprima causa per tipo di unita':\n"); print(table(factor(u$tipo, TIPI), factor(u$causa, CAUSE)))
cat("\nprima causa e sottoclasse per tipo di unita':\n"); print(table(chiave, factor(u$tipo, TIPI)))
cat("\nche cosa resta tolta la prima causa (righe: prima causa; colonne: resto):\n")
print(table(chiave, ifelse(ha_resto, chiave_r, u$resto_causa)))
cat("\nesito della catena per tipo di unita':\n"); print(table(factor(u$tipo, TIPI), u$esito))
b <- a & u$classe == "rispetta"
cat(sprintf("\nconfronti di Atlas nel denominatore della misura (b), non ritrovati: %d\n", sum(b)))
print(table(chiave[b])); print(table(u$esito[b]))
cat("\nconfronti `rispetta` non ritrovati, esito della catena contro la pipeline di oggi:\n"); print(table(u$esito[b], u$oggi[b]))
cat(sprintf("\nconfronti di Atlas di classe piu_fattori o non_formabile, non ritrovati: %d\n", sum(a & !b))); print(table(chiave[a & !b], u$esito[a & !b]))
n_mai <- sum(b & u$esito == "non_errore")
cat(sprintf("\nsensibilita' di lettura, NON una misura: dei %d confronti `rispetta` di Atlas, %d hanno nella catena una scelta o un errore del curatore;\n",
            sum(p$n_rispetta), n_mai))
cat(sprintf("senza quelli il denominatore e' %d: lettore %d, oggi %d (oggi ne ritrova %d fra quelli tolti)\n", sum(p$n_rispetta) - n_mai,
            sum(p$n_rispetta_uguale), sum(k$oggi[k$classe == "rispetta"] == "uguale") - sum(b & u$esito == "non_errore" & u$oggi == "uguale"),
            sum(b & u$esito == "non_errore" & u$oggi == "uguale")))
tz <- b & u$esito == "non_errore" & u$oggi == "uguale"  # la frase del documento li dice tutti di GSE49608, tempo zero
ferma(all(u$studio[tz] == "GSE49608" & chiave[tz] == "curatore/tempo_zero"), "i confronti del curatore che oggi ritrova non sono tutti il tempo zero di GSE49608")
st <- unique(u[, c("studio", "causa", "sotto")]); cat("\nstudi per prima causa (uno studio conta una volta per causa):\n")
print(table(paste(st$causa, st$sotto, sep = "/")))
tutte <- rbind(data.frame(studio = u$studio, c = chiave, stringsAsFactors = FALSE),
               data.frame(studio = u$studio[ha_resto], c = chiave_r[ha_resto], stringsAsFactors = FALSE),
               data.frame(studio = u$studio[grepl("/", u$anche)], c = u$anche[grepl("/", u$anche)], stringsAsFactors = FALSE))
tutte <- unique(tutte); cat("\nstudi in cui la sottoclasse compare (prima causa, resto o «anche»):\n"); print(sort(table(tutte$c), decreasing = TRUE))
if (any(cc_forma)) {
  cat("\nerrori del lettore nella sola sensibilita' `forma` (fuori dalle unita'):\n")
  ef <- nef[nef$giudizio %in% ERRORI, ]
  ferma(setequal(ch(ef$studio, ef$id), c(ch(ee$studio, ee$id), ch(cc$studio[cc_forma], cc$id[cc_forma]))), "errori della sensibilita' senza causa")
  print(cc[cc_forma, c("studio", "id", "causa", "sotto")], row.names = FALSE)
}

# ---- 65-disaccordi.md -------------------------------------------------------------------------------------------------
md <- function(...) cat(..., "\n", sep = "", file = con)
tab <- function(d) {
  md("| ", paste(names(d), collapse = " | "), " |"); md("|", paste(rep("---", ncol(d)), collapse = "|"), "|")
  for (i in seq_len(nrow(d))) md("| ", paste(gsub("|", "/", vapply(d[i, ], as.character, ""), fixed = TRUE), collapse = " | "), " |")
}
incrocio <- function(r, c) { t <- table(r, c); d <- data.frame(x = rownames(t), unclass(t), check.names = FALSE, stringsAsFactors = FALSE); d$totale <- rowSums(t); names(d)[1] <- ""; d }
nt <- function(t) sum(u$tipo == t)
con <- file(file.path(A, "65-disaccordi.md"), "w", encoding = "UTF-8")
md("# PROVA DA BUTTARE: lettura di tutti i disaccordi del lettore v0 contro Expression Atlas\n")
md("Generato da `65-disaccordi.R` dalle tabelle della misura (`64-*`, `66-forma-*`) e dalle cause lette a mano")
md("(`65-cause-studi.txt`, `65-cause-confronti.txt`). **Audit interno:** le cause le ha lette un agente Claude sul")
md("materiale di `65-materiale.txt` (vista, uscita del modello, tabella di Atlas, incrocio dei gruppi, registro delle")
md("coppie, per ognuno dei 47 studi di sviluppo). Non è una misura dell'articolo. Gli 82 studi di giudizio non sono stati aperti.\n")
md("## Che cosa è stato letto\n")
md(sprintf("Le unità di disaccordo sono **%d**, in %d studi su 47. Lo script le prende dalle tabelle della misura e si ferma", nrow(u), length(unique(u$studio))))
md("se una resta senza causa.\n")
tab(data.frame(`unità` = c("studio che il lettore non chiude", "studio chiuso con partizione non identica", "confronto di Atlas non ritrovato",
                           "  di cui nel denominatore della misura (b), classe `rispetta`", "  di cui fuori (`piu_fattori`, `non_formabile`)",
                           "confronto del lettore giudicato errore, misura (c)"),
               numero = c(nt("studio_non_chiuso"), nt("partizione_non_identica"), nt("atlas_non_ritrovato"), sum(b), sum(a & !b), nt("lettore_errore")),
               check.names = FALSE, stringsAsFactors = FALSE))
md(sprintf("\nSenza disaccordi: %s.\n", paste(setdiff(p$studio, u$studio), collapse = ", ")))
md("Ogni unità ha una **prima causa** (il primo difetto che la misura principale incontra) e un **resto** (che cosa")
md("resta quando la prima causa è tolta). Il resto è `niente_misurato` quando la sensibilità sulla forma delle voci")
md("(`66-forma-*`) ritrova il confronto, `niente_letto` quando la lettura non vede altro, `non_osservato` quando lo")
md("studio non chiude nemmeno nella sensibilità e la lettura non può dire che cosa resta.\n")
md("## Le cause\n")
md("Cause ammesse dal piano: `vista`, `schema`, `modello`, `curatore` (con la prova), `strumento`.\n")
sp <- data.frame(causa = names(SPIEGA), `che cosa vuol dire` = unname(SPIEGA), `chi può toglierla` = unname(RIMEDIO[names(SPIEGA)]),
                 `unità (prima causa)` = vapply(names(SPIEGA), function(x) sum(chiave == x), 0L),
                 `unità (resto)` = vapply(names(SPIEGA), function(x) sum(chiave_r == x), 0L),
                 `studi (prima, resto o in più)` = vapply(names(SPIEGA), function(x) sum(tutte$c == x), 0L), check.names = FALSE, stringsAsFactors = FALSE)
tab(sp)
md("\n`chi può toglierla`: `schema` = un cambio dello schema o del prompt la può togliere. Per la forma delle voci l'effetto è")
md("misurato dalla sensibilità (`66-forma-*`). Per le altre tre è una proposta: questa prova non l'ha misurata. `modello` = serve un")
md("modello che legge meglio, ed è una **ipotesi non misurata** (questa prova ha un modello solo). `non_serve` = non è un")
md("errore del lettore. `strumento` = è un limite della misura. La causa `vista` non è la prima causa di nessuna unità:")
md("compare come nota in uno studio (GSE147507).\n")
md("### Prima causa per tipo di unità\n"); tab(incrocio(factor(u$tipo, TIPI), factor(u$causa, CAUSE)))
md("\n### Che cosa resta, tolta la prima causa\n"); tab(incrocio(chiave, ifelse(ha_resto, chiave_r, u$resto_causa)))
md("\n### Esito della catena\n")
md("`non_errore`: nella catena c'è una scelta o un errore del curatore, o un limite della misura. `forma`: basta leggere")
md("le voci malformate (misurato). `schema`: ogni causa è di schema. `modello`: almeno una causa chiede un modello che")
md("legge meglio (non misurato). `ignoto`: lo studio non chiude nemmeno nella sensibilità.\n")
tab(incrocio(factor(u$tipo, TIPI), u$esito))
md(sprintf("\nDei %d confronti di Atlas nel denominatore della misura (b), il lettore ne ritrova %d. Dei %d non ritrovati, %d hanno", sum(p$n_rispetta), sum(p$n_rispetta_uguale), sum(b), n_mai))
md(sprintf("nella catena una scelta o un errore del curatore: un lettore senza difetti non li ritrova. La pipeline di oggi ne ritrova %d,", sum(b & u$esito == "non_errore" & u$oggi == "uguale")))
md("tutti con il tempo zero come controllo (GSE49608). Questo è un risultato di lettura, non una misura: le misure")
md("depositate restano quelle di `64-out.txt`.\n")
md("## La classe «livello combinato»\n")
md("Il piano chiede di contare a parte i casi in cui i curatori scrivono due agenti come un livello solo e il lettore")
md("come due fattori. **Disaccordi di questa classe: 0.** Nei 47 studi c'è un solo livello di Atlas con due agenti")
md("(GSE52778, «albuterol and dexamethasone»): il lettore lo scrive come un livello solo, come Atlas, e con la forma")
md("tollerata ritrova il confronto. Negli studi che non chiudono nemmeno nella sensibilità la classe non è giudicabile.\n")
pf <- k[k$classe == "piu_fattori", ]
md(sprintf("La classe vicina è più frequente: Atlas confronta due gruppi che differiscono in più di uno dei **suoi** fattori (classe `piu_fattori`): %d confronti in %d studi,", nrow(pf), length(unique(pf$studio))))
md(sprintf("fuori dal denominatore della misura (b). Il lettore ne ritrova %d nella misura principale e %d nella sensibilità. Per sottoclasse dei %d non ritrovati:\n", sum(pf$ritrovato == "uguale"), sum(pf$forma == "uguale"), sum(a & u$classe == "piu_fattori")))
x <- a & u$classe == "piu_fattori"
tab(incrocio(ifelse(u$resto_causa[x] %in% CAUSE, chiave_r[x], paste0(chiave[x], " (resto ", u$resto_causa[x], ")")), u$studio[x]))
md("\n## Una riga per studio\n")
per <- do.call(rbind, lapply(unique(cs$studio), function(g) {
  r <- cs[cs$studio == g, ]; ug <- u[u$studio == g, ]
  che <- c(if (any(ug$tipo == "studio_non_chiuso")) "non chiuso", if (any(ug$tipo == "partizione_non_identica")) paste("partizione", p$classe_gruppi[p$studio == g]),
           if (any(ug$tipo == "atlas_non_ritrovato")) sprintf("%d confronti di Atlas non ritrovati", sum(ug$tipo == "atlas_non_ritrovato")),
           if (any(ug$tipo == "lettore_errore")) sprintf("%d confronto del lettore giudicato errore", sum(ug$tipo == "lettore_errore")))
  cat1 <- unique(paste(ug$causa, ug$sotto, sep = "/"))
  rr <- unique(ifelse(ug$resto_causa %in% CAUSE, paste(ug$resto_causa, ug$resto_sotto, sep = "/"), ug$resto_causa))
  data.frame(studio = g, `disaccordi` = paste(che, collapse = "; "), `che cosa differisce` = paste(r$differenza, collapse = " "),
             `prima causa` = paste(cat1, collapse = "; "), resto = paste(rr, collapse = "; "),
             `in più` = paste(unique(r$anche[nzchar(r$anche)]), collapse = "; "), prova = paste(r$prova, collapse = " "),
             check.names = FALSE, stringsAsFactors = FALSE)
}))
tab(per)
md("\n## Una riga per unità di disaccordo\n")
md("`forma` = esito nella sensibilità sulla forma delle voci; `oggi` = esito della pipeline di oggi sullo stesso confronto di Atlas.\n")
un <- u[, c("tipo", "studio", "id", "nome", "classe", "causa", "sotto", "resto_causa", "resto_sotto", "esito", "forma", "oggi")]
un$nome <- ifelse(nchar(un$nome) > 110L, paste0(substr(un$nome, 1L, 110L), "…"), un$nome)
tab(un)
if (any(cc_forma)) {
  md("\n## Fuori dalle unità: gli errori del lettore nella sola sensibilità\n")
  tab(cc[cc_forma, c("studio", "id", "causa", "sotto", "differenza")])
}
md("\nLe differenze e le prove dei singoli confronti con una causa diversa da quella del loro studio:\n")
tab(cc[!cc_forma, c("studio", "tipo", "id", "causa", "sotto", "resto_causa", "resto_sotto", "differenza")])
close(con)
cat(sprintf("\nscritti 65-disaccordi-righe.csv (%d righe) e 65-disaccordi.md\n", nrow(u)))
