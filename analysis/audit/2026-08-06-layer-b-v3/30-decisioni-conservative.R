#!/usr/bin/env Rscript
# analysis/audit/2026-08-06-layer-b-v3/30-decisioni-conservative.R
#
# CHIUDE I DISACCORDI DEL CONTEGGIO CON UNA REGOLA DICHIARATA.
#
# L'arbitrato del 2026-08-06 ha lasciato aperti dieci confronti in cui
# l'etichetta ammette DUE letture, una che vede un difetto e una che non lo
# vede, senza che il testo decida. Decisione (utente, 2026-08-07): non si
# rimandano, si decidono, e **nel dubbio si sceglie la lettura che NON
# sovrastima la qualita' del dato** — cioe' il confronto si conta come
# difettoso.
#
# E' coerente con la natura della misura, gia' dichiarata un LIMITE SUPERIORE:
# attribuisce a un difetto l'intero peso dello studio coinvolto anche quando
# un solo confronto su molti e' imperfetto. Un limite superiore che escludesse
# i casi dubbi non sarebbe piu' un limite superiore.
#
# La regola vale in tutte e due le direzioni: dove l'etichetta DECIDE che il
# confronto e' pulito, resta pulito (vedi le due esclusioni motivate in fondo).
#
# Uso: Rscript analysis/audit/2026-08-06-layer-b-v3/30-decisioni-conservative.R

suppressPackageStartupMessages({ library(cli) })

OUT <- "analysis/audit/2026-08-06-layer-b-v3"
IN  <- file.path(OUT, "conteggio-3-gruppi.json")
g <- jsonlite::fromJSON(IN, simplifyDataFrame = FALSE)
names(g) <- vapply(g, `[[`, character(1), "cluster_id")

# --- le decisioni, una per una ------------------------------------------------
# Ogni voce: quanti confronti si aggiungono al conteggio, quali studi entrano
# fra i contaminati, e PERCHE'.
DECISIONI <- list(
  list(cluster = "cgroup_L5_c3ae78cd", confronti = 1L, studi = "GSE164871",
       questione = "GSE164871 'Crohn's Disease CD4' contro 'Healthy Control Colon Tissue'",
       decisione = "CONTATO come difettoso",
       motivo = paste0(
         "L'etichetta ammette due letture: 'CD4' come popolazione linfocitaria ",
         "isolata (materiale incompatibile col tessuto colico intero del ",
         "controllo) o come codice di soggetto. Il braccio gemello dello stesso ",
         "studio, 'Crohn's Disease Colon Tissue', mette un MATERIALE in quello ",
         "slot. La lettura prudente e' quella che vede il difetto.")),

  list(cluster = "cgroup_L5_c3ae78cd", confronti = 4L, studi = "GSE261086",
       questione = "GSE261086, i quattro confronti 'Inflamed ...' contro 'Normal ...'",
       decisione = "CONTATI come difettosi",
       motivo = paste0(
         "L'etichetta non nomina l'entita' del gruppo (Crohn), e lo studio ",
         "tiene bracci 'Crohn's disease X' e 'Inflamed X' come DISTINTI in tutte ",
         "e tre le granularita': nel vocabolario dello studio stesso 'Inflamed' ",
         "non e' 'Crohn's disease'. Che sia il segmento infiammato della stessa ",
         "coorte e' plausibile ma non scritto.")),

  list(cluster = "cgroup_L5_c3ae78cd", confronti = 2L, studi = character(0),
       questione = "GSE139179, i due confronti su sigmoideo con codice temporale (T26, T106)",
       decisione = "CONTATI come difettosi",
       motivo = paste0(
         "Qui la sede coincide, quindi il difetto di sede non si applica; resta ",
         "il tempo. Che T## sia un tempo e' provato dalle etichette vicine ",
         "('Baseline' nello stesso slot). Se il campione a T106 sia sotto terapia ",
         "non e' scritto: la lettura prudente lo conta. Lo studio era gia' fra i ",
         "contaminati, quindi cambia il conteggio e non il peso.")),

  list(cluster = "cgroup_L5_85083e38", confronti = 2L, studi = character(0),
       questione = "Eta' del donatore discordante (GSE106608 88 contro 66 anni; GSE128177 71 contro 65)",
       decisione = "CONTATI come difettosi",
       motivo = paste0(
         "La tassonomia dei difetti del progetto nomina 'donatore, sesso o etnia' ",
         "e non l'eta'. Ma l'eta' e' un attributo del donatore come il sesso, e' ",
         "scritta sulle stesse etichette, e in tessuto cerebrale post-mortem e' il ",
         "confondente principale per una malattia guidata dall'eta'. Contare il ",
         "sesso e non l'eta' sarebbe incoerente. Entrambi gli studi erano gia' fra ",
         "i contaminati: cambia il conteggio e non il peso.")),

  list(cluster = "cgroup_L5_85083e38", confronti = 3L, studi = "GSE181029",
       questione = "GSE181029, 'terminally differentiated' presente sul solo braccio di controllo",
       decisione = "CONTATI come difettosi",
       motivo = paste0(
         "Lo studio tiene due pool di controllo distinti proprio con quella ",
         "dicitura, quindi la parola discrimina; e il braccio trattato puo' ",
         "portarla, quindi la sua assenza non e' una collisione di slot ",
         "obbligata. In un differenziamento da iPSC lo stadio pesa. ",
         "CONSEGUENZA GRAVE E VOLUTA: GSE181029 porta il 73% del peso del ",
         "gruppo, quindi il peso contaminato di Parkinson diventa la quasi ",
         "totalita'. E' esattamente cio' che un limite superiore deve fare in un ",
         "gruppo gia' dichiarato dominato da un solo studio e a materiale misto.")),

  list(cluster = "cgroup_L5_85083e38", confronti = 1L, studi = "GSE168496",
       questione = "GSE168496 'Parkinson's disease' contro 'Non-demented control'",
       decisione = "CONTATO come difettoso",
       motivo = paste0(
         "Il riferimento e' definito su un asse diverso da quello della malattia ",
         "in studio: assenza di demenza, non assenza di parkinsonismo. E' l'unico ",
         "dei dieci studi a cambiare asse. Che 'non-demented' sia la dicitura ",
         "standard di una banca cervelli per un controllo neurologicamente ",
         "normale e' conoscenza esterna, non testo dell'etichetta: la lettura ",
         "prudente conta il confronto."))
)

# --- due esclusioni, per mostrare che la regola NON e' "conta tutto" ----------
ESCLUSIONI <- list(
  list(questione = "IFN-gamma / GSE215771 'A549 IRF1KO IFN-g' contro 'A549 IRF1KO Vehicle'",
       decisione = "NON contato",
       motivo = paste0(
         "Il genotipo knockout e' IDENTICO sui due bracci, quindi il confronto ",
         "isola correttamente l'effetto dell'IFN-gamma in quel genotipo. ",
         "L'obiezione (che IRF1 non possa salire dove IRF1 e' spento) e' di ",
         "plausibilita' biologica, non di appaiamento: e' letteralmente il caso ",
         "GSE178714/SMAD2-SMAD3 KO in TGF-beta1, gia' accusato e poi RITRATTATO ",
         "dal progetto. Va dichiarato nella narrativa, non contato qui.")),
  list(questione = "IL1A / GSE155141, i due confronti su cute non lesionale",
       decisione = "NON contati",
       motivo = paste0(
         "L'appaiamento interno e' impeccabile e identico sui due bracci. Che lo ",
         "studio somministri IL-1beta invece di IL-1alfa e' un difetto di ",
         "COMPOSIZIONE del gruppo, gia' contato una volta nel verdetto di ",
         "incoerenza: contarlo di nuovo qui lo metterebbe in due bilanci."))
)

# --- applica ------------------------------------------------------------------
cli_h2("Decisioni conservative sui confronti che l'etichetta non decide")
for (d in DECISIONI) {
  x <- g[[d$cluster]]
  prima_n <- length(x$confronti_difettosi_finali)
  prima_s <- unlist(x$studi_con_difetti)
  x$n_difettosi_decisi <- (x$n_difettosi_decisi %||% prima_n) + d$confronti
  x$studi_con_difetti <- sort(unique(c(prima_s, d$studi)))
  x$decisioni <- c(x$decisioni, list(d))
  g[[d$cluster]] <- x
  cli_alert_info("{sub('cgroup_L5_','',d$cluster)}: +{d$confronti} confronti{if (length(d$studi)) paste0(', +studio ', d$studi) else ''} — {d$questione}")
}
cli_h3("Esclusioni motivate (la regola vale in tutte e due le direzioni)")
for (e in ESCLUSIONI) cli_alert_info("{e$decisione}: {e$questione}")

out <- lapply(g, function(x) {
  x$n_confronti_difettosi_finale <- x$n_difettosi_decisi %||% length(x$confronti_difettosi_finali)
  x
})
jsonlite::write_json(unname(out), file.path(OUT, "conteggio-3-gruppi-deciso.json"),
                     auto_unbox = TRUE, pretty = TRUE)
jsonlite::write_json(list(decisioni = DECISIONI, esclusioni = ESCLUSIONI),
                     file.path(OUT, "decisioni-conservative.json"),
                     auto_unbox = TRUE, pretty = TRUE)

cli_h2("Conteggio finale")
for (x in out) {
  cli_alert_success("{sub('cgroup_L5_','',x$cluster_id)}: {x$n_confronti_difettosi_finale} su {x$n_confronti_totali} confronti; studi contaminati: {paste(unlist(x$studi_con_difetti), collapse=', ')}")
}
