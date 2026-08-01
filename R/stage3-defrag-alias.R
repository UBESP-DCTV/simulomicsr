# De-frammentazione dell'entita' del contrasto (decisione 2026-07-31).
#
# IL PROBLEMA. Il gruppo `HGNC:11766` (TGF-beta1) contiene gia' membri
# etichettati "TGF-beta", "TGFbeta", "TGF-B1", perche' quelle scritture
# risolvono all'ID del gene. Le scritture "TGFb" e "TGF-B" no: il resolver le
# aggancia (ImmPort le conosce) ma la guardia sugli acronimi `.ca_acronym_ok`
# le rifiuta, perche' un candidato di <=4 caratteri passa solo se coincide con
# il nome risolto ("tgfb" != "tgfb1"). Risultato: la stessa citochina finisce
# in tre gruppi. Nei Methods «abbiamo trattato TGF-beta e TGFb come entita'
# diverse» non si puo' scrivere: non e' un limite del dato, e' un'incoerenza
# interna del metodo.
#
# LA REGOLA. Prima di ripiegare su `STR:`, il token si prova contro l'ontologia
# pretendendo un match UNIVOCO su un alias PER ESTESO (>3 caratteri). Se
# l'alias aggancia piu' di un'entita', NON si fonde e si resta su `STR:`.
#
# Perche' non e' una lista di casi:
#   - `tgfb` si fonde perche' nessuna entita' oltre TGFB1 ha "tgfb" nudo fra gli
#     alias (TGFB2 e TGFB3 hanno "tgfb2" e "tgfb3");
#   - `ifna` NON si fonde perche' e' alias sia di IFNA1 sia di IFNA2, e la
#     stringa non dice quale: fonderla sarebbe un errore di identita', la classe
#     che questo rework ha eliminato;
#   - il vincolo ">3 caratteri" e' quello gia' pagato il 2026-07-29, quando un
#     match su una SIGLA fece dare per buono `CHEBI:73572` (il tripeptide
#     Leu-Thr-Ala ha "LTA" fra i sinonimi, ma negli studi LTA e' acido
#     lipoteicoico).
#
# DOVE AGISCE. Solo sul ramo di ripiego: se il resolver della classe ha gia'
# prodotto un ID, questo codice non viene nemmeno interrogato. Non puo' quindi
# cambiare un'entita' gia' risolta, solo recuperarne una che sarebbe andata
# perduta in `STR:`.
#
# PERCHE' SERVE UN INDICE PROPRIO. I dizionari in memoria sono ambienti hash
# chiave->valore: una chiave, una entita'. Non possono dire che "ifna" aggancia
# DUE geni — l'informazione e' persa nella costruzione. L'ambiguita' si vede
# solo nelle tabelle lunghe degli alias, che qui si rileggono una volta sola.

#' Lunghezza minima del token perche' la fusione sia ammessa
#'
#' ">3 caratteri" sulla forma normalizzata. Una sigla di tre lettere non prova
#' l'identita': e' la forma esatta delle collisioni misurate il 2026-07-25
#' (\code{ml}->THPO, \code{ifn}->IFNA1, \code{lta}->Leu-Thr-Ala).
#' @keywords internal
#' @noRd
.CA_DEFRAG_MIN_CHARS <- 4L

#' Forma normalizzata di un token per il confronto con gli alias
#'
#' Toglie ogni carattere non alfanumerico e abbassa: cosi' \code{TGFb},
#' \code{TGF-B} e \code{tgf_b} sono la stessa chiave. Le CIFRE restano, altrimenti
#' TGFB1 e TGFB2 diventerebbero la stessa entita'.
#' @keywords internal
#' @noRd
.ca_defrag_norm <- function(x) {
  if (length(x) != 1L || is.na(x)) return("")
  gsub("[^a-z0-9]", "", tolower(as.character(x)))
}

#' Ordine di interrogazione delle ontologie — UNICO, uguale per ogni classe
#'
#' ⚠️ **La prima versione dipendeva dalla CLASSE del contrasto** (`disease`→MeSH,
#' `drug`→ChEBI/ChEMBL/HGNC/taxon, le altre → niente), rispecchiando
#' `.ca_resolve_entity`. Sembrava la scelta conservativa. **Misurato sull'output
#' vero del re-cluster v14 (2026-08-01): produce SPLIT.** Lo stesso token si
#' risolve o no a seconda di come lo Stadio 2 ha classificato la chiave, quindi
#' la stessa entita' finisce in DUE gruppi — `STR:hypoxia` k=33 **e**
#' `MeSH:D000860` k=10, entrambi sopra la soglia, entrambi nel deliverable.
#' Sei entita' colpite (hypoxia 94 membri, schizophrenia 57, sepsis 18,
#' endometriosis 9, medulloblastoma 8, smoking 3).
#'
#' **E' frammentazione creata dalla regola che doveva toglierla**, cioe' l'esatto
#' opposto del suo scopo.
#'
#' Un ordine UNICO la elimina **per costruzione**: lo stesso token da' sempre lo
#' stesso ID, qualunque sia la classe. Restano validi gli altri due vincoli
#' (lunghezza > 3, univocita' DENTRO l'ontologia che vince).
#'
#' Perche' questo ordine, e non un altro:
#' - **la tassonomia e' ULTIMA** perche' e' la fonte del problema del granchio:
#'   3,3 M di nomi, molte parole comuni sono generi. Cosi' `sepsis` prende
#'   `MeSH:D018805` (la malattia) e non `NCBITaxon:137507`, che e' un genere di
#'   mosche;
#' - ChEBI/ChEMBL prima di HGNC ricalca l'ordine che `.ca_resolve_entity` usa
#'   per la classe `drug`, che e' la piu' frequente;
#' - **l'univocita' NON si misura sull'unione** delle ontologie: misurato, quella
#'   forma bloccherebbe 52 token su 664 (178 membri) e quasi tutti sono la stessa
#'   entita' descritta due volte — `zika_virus` (MeSH + NCBITaxon), `vegf`
#'   (gene + descrittore), `il17`, `bdnf`, `r5020`. Sarebbe l'errore opposto.
#' @keywords internal
#' @noRd
.CA_DEFRAG_ONTOLOGY_ORDER <- c("chebi", "chembl", "hgnc", "mesh", "taxon")

#' @rdname dot-CA_DEFRAG_ONTOLOGY_ORDER
#' @keywords internal
#' @noRd
.ca_defrag_ontologies <- function(contrast_class) .CA_DEFRAG_ONTOLOGY_ORDER

#' Legge una tabella lunga di alias dalla sorgente dei dizionari
#'
#' @return data.frame con colonne \code{key} (alias grezzo) e \code{id}, oppure
#'   NULL se il file non c'e' (fixture, dizionario opzionale assente).
#' @keywords internal
#' @noRd
.ca_defrag_read_one <- function(source_dir, ont) {
  path <- switch(ont,
                 chebi  = file.path(source_dir, "chebi", "chebi-lookup.rds"),
                 hgnc   = file.path(source_dir, "hgnc-lookup.rds"),
                 mesh   = file.path(source_dir, "mesh-lookup.rds"),
                 chembl = file.path(source_dir, "chembl", "chembl-lookup.rds"),
                 taxon  = file.path(source_dir, "taxonomy", "taxonomy-lookup.rds"),
                 NULL)
  if (is.null(path) || !file.exists(path)) return(NULL)
  d <- readRDS(path)
  # Il nome primario E' un alias: senza, "glioblastoma" non aggancerebbe
  # MeSH:D005909, che lo porta come intestazione e non fra i termini d'ingresso.
  switch(ont,
    chebi = rbind(
      data.frame(key = d$aliases$alias_lower,
                 id = paste0("CHEBI:", d$aliases$chebi_id), stringsAsFactors = FALSE),
      data.frame(key = d$by_id$primary_name,
                 id = paste0("CHEBI:", d$by_id$chebi_id), stringsAsFactors = FALSE)),
    hgnc = rbind(
      data.frame(key = d$aliases_long$alias_lower,
                 id = paste0("HGNC:", d$aliases_long$hgnc_int), stringsAsFactors = FALSE),
      data.frame(key = d$by_hgnc_int$symbol,
                 id = paste0("HGNC:", d$by_hgnc_int$hgnc_int), stringsAsFactors = FALSE),
      data.frame(key = d$by_hgnc_int$name,
                 id = paste0("HGNC:", d$by_hgnc_int$hgnc_int), stringsAsFactors = FALSE)),
    mesh = rbind(
      data.frame(key = d$by_entry_lower$entry_lower,
                 id = paste0("MeSH:", d$by_entry_lower$ui), stringsAsFactors = FALSE),
      data.frame(key = d$by_ui$mh,
                 id = paste0("MeSH:", d$by_ui$ui), stringsAsFactors = FALSE)),
    chembl = rbind(
      data.frame(key = d$aliases$alias_lower,
                 id = paste0("CHEMBL:", d$aliases$chembl_id), stringsAsFactors = FALSE),
      data.frame(key = d$by_id$pref_name,
                 id = paste0("CHEMBL:", d$by_id$chembl_id), stringsAsFactors = FALSE)),
    taxon = data.frame(key = d$names$name_norm,
                       id = paste0("NCBITaxon:", d$names$taxid), stringsAsFactors = FALSE),
    NULL)
}

#' Indice degli alias UNIVOCI, per ontologia
#'
#' Tiene solo le chiavi che, dentro quell'ontologia, appartengono a UNA sola
#' entita'. Le ambigue si buttano: un token che non e' nell'indice, o perche'
#' non esiste o perche' e' ambiguo, non si fonde — e sono lo stesso esito.
#'
#' Memoizzato dentro l'ambiente dei dizionari: si costruisce una volta per
#' sessione, non una volta per record.
#' @keywords internal
#' @noRd
.ca_defrag_index <- function(ontology_env, ont) {
  memo <- ontology_env$.defrag_index
  if (is.null(memo)) {
    memo <- new.env(parent = emptyenv())
    assign(".defrag_index", memo, envir = ontology_env)
  }
  if (!is.null(memo[[ont]])) return(memo[[ont]])

  src <- ontology_env$source_dir
  tab <- if (is.null(src)) NULL else .ca_defrag_read_one(src, ont)
  idx <- new.env(hash = TRUE, parent = emptyenv())
  if (!is.null(tab) && nrow(tab)) {
    k <- vapply(tab$key, .ca_defrag_norm, character(1L), USE.NAMES = FALSE)
    keep <- nzchar(k) & nchar(k) >= .CA_DEFRAG_MIN_CHARS & !is.na(tab$id)
    k <- k[keep]; v <- tab$id[keep]
    # una chiave puo' ripetersi per la STESSA entita' (alias + nome primario):
    # non e' ambiguita'.
    dup <- duplicated(paste0(k, "\r", v))
    k <- k[!dup]; v <- v[!dup]
    ambiguous <- unique(k[duplicated(k)])
    ok <- !(k %in% ambiguous)
    if (any(ok)) idx <- list2env(stats::setNames(as.list(v[ok]), k[ok]),
                                 envir = idx)
  }
  assign(ont, idx, envir = memo)
  idx
}

#' Fusioni RIFIUTATE, adjudicate una per una sui dati (2026-08-01)
#'
#' Delle 923 fusioni prodotte dalla regola, **682 sono sostenute dal nome
#' primario** dell'entita' (`hypoxia`->Hypoxia, `tgfb`->TGFB1) e non pongono
#' problemi. Le altre **241 stanno in piedi solo su un alias**, e sono state
#' lette una per una con le etichette vere accanto (`90-adjudica.txt`).
#' **~63 assegnano un'identita' SBAGLIATA.**
#'
#' La forma dell'errore e' sempre la stessa: una sigla di laboratorio, un codice
#' di campione, un tipo cellulare o un descrittore tecnico che collide con un
#' alias ontologico. Nessun filtro meccanico li separa da quelli giusti —
#' misurato: pretendere il sostegno del nome bloccherebbe anche `il17`->IL17A,
#' `4oht`->afimoxifene, `arac`->citarabina, `zikv`->Zika.
#'
#' Perche' una tabella SEPARATA da `.ALIAS_COLLISIONS`: quella e' usata anche
#' dai resolver principali, e toccarla obbligherebbe a invalidare la cache del
#' recupero-nome (~1 h) per un cambiamento che riguarda solo questo ramo.
#'
#' Precedente e metodo: identici all'audit 2026-07-25, che adjudico' 170 coppie
#' alias->ID e da cui nasce `.ALIAS_COLLISIONS`. Di quelle, cinque furono poi
#' RITRATTATE rileggendo il testo sorgente: il giudizio sulla coppia non basta,
#' va visto il testo che l'ha prodotta. Per questo accanto a ogni riga c'e'
#' l'etichetta che l'ha fatta giudicare.
#'
#' Formato: "token_normalizzato|ID_rifiutato".
#' @keywords internal
#' @noRd
.CA_DEFRAG_REJECT <- c(
  # --- malattie e sindromi finite su un GENE -------------------------------
  "msap|HGNC:7413",        # "MSA_P" vs "HC": atrofia multisistemica, non MTAP (27)
  "copd|HGNC:649",         # "COPD Bronchial Epithelium": la malattia, non ARCN1 (11)
  "fshd2|HGNC:29090",      # "hIPS with FSHD2": la malattia, non SMCHD1 (9)
  "cadasil|HGNC:7883",     # "CADASIL-affected": la malattia, non NOTCH3 (4)
  "sbma|HGNC:644",         # "SBMA Lateral Motor Cortex": la malattia, non AR (2)
  "opmd|HGNC:8565",        # "OPMD Case": la malattia, non PABPN1 (1)
  "spms|CHEBI:140399",     # "SPMS" vs "Healthy Control": sclerosi multipla secondaria (2)
  # --- farmaci e reagenti finiti su un GENE --------------------------------
  "plab|HGNC:30142",       # "Pla-B 41°C" vs DMSO: pladienolide B, non GDF15 (11)
  "iwr1|HGNC:25807",       # "treated with IWR1": inibitore di Wnt, non SLC7A6OS (1)
  "grb1|HGNC:9650",        # "G-Rb1-treated": ginsenoside Rb1, non PIK3R1 (1)
  "atri|CHEBI:35930",      # "ATRi 4hr" vs DMSO: inibitore di ATR, non uno zucchero (2)
  "clof|CHEBI:30127",      # "DEV_Clof" vs DMSO: clofarabina, non un ossido (2)
  "blast|CHEBI:81783",     # "Blast" vs Control: blasti leucemici, non tricyclazole (3)
  "cbp30|MeSH:D037502",    # "treated with CBP30": inibitore BET, non Galectin 3 (4+2)
  # --- nomi GENERICI da paper ("compound 1") -------------------------------
  "cpd1|CHEMBL:CHEMBL4297626",  # "CSM152_Cpd1": "compound 1", non nidufexor (8)
  "cpd10|CHEMBL:CHEMBL203665",  # "cpd10" vs vehicle: "compound 10", non relacatib (2)
  "ms40|CHEMBL:CHEMBL2059073",  # "MS40" vs DMSO: codice, non sulisobenzone (1)
  "med3|HGNC:2377",        # "BT549 + MED3" vs VEH: codice, non MED27 (1)
  "cia1|HGNC:14280",       # "CIA1 (18h)" vs DMSO: codice, non CIAO1 (1)
  "hit1|HGNC:12309",       # "Hit1" vs DMSO: hit di screening, non ZNHIT3 (1)
  "hit4|HGNC:26573",       # "Hit4" vs DMSO: hit di screening, non ZNF597 (1)
  "shap|HGNC:29215",       # "Treated (SHAP)": non SHROOM4 (1)
  "arf2|HGNC:655",         # "ARF_2 Treated": ambiguo, non ARF4 (1)
  # --- codici di campione, coorti, tempi -----------------------------------
  "boca|HGNC:13520",       # "BoCA Visit 0 Case": nome di coorte, non MESD (4)
  "mid49|HGNC:17920",      # "49 days Mid": un TEMPO, non MIEF2 (7)
  "dia2|HGNC:2877",        # "HS578T Dia2": codice di campione (3)
  "dia4|HGNC:2874",        # "HS578T Dia4": codice di campione (3)
  "sat3|HGNC:10864",       # "adipose tissues ... SAT3": campione, non ST3GAL4 (1)
  "ad24|HGNC:24034",       # "iPSCs AD24": codice di linea, non NOC3L (1)
  # --- entita' NON del contrasto: tipi cellulari, materiali, tecniche ------
  "tcells|MeSH:D013601",   # "D10 Tcells 4h": tipo cellulare, non la perturbazione (6)
  "hesc|MeSH:D000066449",  # "Schwann cells (hESC)": origine, non la perturbazione (2)
  "promyelocytes|MeSH:D042381",  # tipo cellulare (1)
  "tpc1|HGNC:18182",       # "TPC1 cells": linea di tumore tiroideo, non TPCN1 (1)
  "ucmsc|CHEMBL:CHEMBL5314881",  # "co-cultured with UC-MSC": cellule, non un farmaco (1)
  "scidmice|MeSH:D016513", # "xenograft in SCID mice": ospite, non la perturbazione (1)
  "chip|HGNC:11427",       # "Chip" vs "96-well plate": dispositivo, non STUB1 (1)
  "polya|CHEBI:8756",      # "polyA RNA": preparazione di libreria (8)
  "polyamrna|MeSH:D012333",# "polyA mRNA fractionation": tecnica (2)
  "polysome|MeSH:D011132", # "Polysome": frazionamento (1)
  "lncrna|MeSH:D062085",   # "H9 lncRNA": categoria, non un'entita' (1)
  "ch50|MeSH:D015941",     # "CH50": un saggio (1)
  "damage|HGNC:24934",     # "Colon Damage 5 Rounds": parola generica, non MAGEE1 (2)
  "cd23|HGNC:3612",        # "Day 5 CD23+" vs "Day 4": marcatore + tempo (2)
  # --- microRNA e proteine non-umane ---------------------------------------
  "mir1|HGNC:13745",       # "transfected with miR-1": microRNA, non FSD1 (3)
  "mir16|HGNC:29644",      # "miR-16" vs "Control miR": microRNA, non GDE1 (1)
  "nsp1|HGNC:16885",       # "HEK293 NSP1": proteina virale, non SH2D3A (1)
  "myr1|HGNC:7596",        # "infected with myr1 parasites": Toxoplasma, non MYO1B (1)
  "nets|HGNC:15464",       # "Healthy NETs": trappole dei neutrofili, non SPINK5 (9)
  "chmi|HGNC:17005",       # "CHMI NP V05C": infezione malarica controllata, non CNMD (7)
  "lats|MeSH:D008135",     # "A704 LATS" vs "non-targeting": la chinasi LATS1/2 (2)
  "peg10|CHEBI:46550",     # "PEG10" vs Control: il GENE, non il glicole (1)
  "rela|CHEMBL:CHEMBL1233",# "RELA-/-": il gene NF-kB p65, non il carisoprodol (1)
  "mos2|HGNC:30677",       # "MoS2 Treated": disolfuro di molibdeno, non GPKOW (5)
  # --- identita' semplicemente sbagliata ------------------------------------
  "senv|MeSH:D022783",     # "Wild-Type SenV" vs Mock: virus Sendai, non Torque teno (4)
  "ifni|MeSH:D009018",     # "Ileum IFN-I": interferone di tipo I, non il MAROCCO (2)
  "vaper|MeSH:D000074285", # "Vapers": svapatori, non "Smokers" (2)
  "papa|CHEBI:131579",     # "PAPA Human skin": la sindrome PAPA, non pApA (3)
  "vlps|CHEBI:215384",     # "VLPs 4h": particelle virus-simili (3)
  # --- troppo specifiche per la stringa (l'ID promette piu' del dato) -------
  "vitamind|CHEMBL:CHEMBL1536",  # "Vitamin D": D2 o D3? l'ID dice ergocalciferolo (4+1)
  "antiil4|CHEMBL:CHEMBL2108119",# "anti-IL-4": anticorpo generico, non pascolizumab (1)
  "anticd3|CHEMBL:CHEMBL1201608" # "anti-CD3": anticorpo generico, non muromonab (2)
)

#' Le fusioni AUTORIZZATE — l'unica cosa che questa regola fa
#'
#' ⚠️ **RESTRIZIONE DELIBERATA (2026-08-01), dopo cinque audit indipendenti.**
#' La decisione dell'utente del 2026-07-31
#' (`docs/superpowers/specs/2026-07-31-decisione-rerun.md`) autorizzava la
#' de-frammentazione di **cinque entita'**, con numeri calcolati su quelle. La
#' prima stesura di questo file generalizzava la regola a **923 fusioni**: quella
#' generalizzazione non era stata decisa da nessuno, ed e' da li' che vengono
#' tutti i difetti misurati:
#'
#' - **14,1% di identita' sbagliate** (130 su 923), adjudicate leggendo TUTTE le
#'   coppie con le etichette vere: `msa_p`->MTAP (e' l'atrofia multisistemica),
#'   `copd`->ARCN1, `rela`->carisoprodol su `RELA-/-`, `ifn_i`->**il Marocco**;
#' - **lo split NON si chiudeva**: il ramo `anchor` precede questo e puo' esso
#'   stesso produrre un'entita' `STR:`, quindi in v14 convivevano
#'   `STR:hypoxia` (k=33) e `MeSH:D000860` (k=10) — stessa entita', stesso verso,
#'   stesso controllo, due gruppi. 427 cluster interessati;
#' - **la regola CANCELLAVA dati**: `tnfa` agganciava il TNF dello *zebrafish*
#'   (ChEBI precede HGNC), ID in blacklist, e **17 confronti TNFα prima tenuti
#'   venivano scartati**;
#' - **l'asse clinico-vs-sperimentale si spegneva** sui membri fusi, perche' il
#'   tipo di controllo si calcola PRIMA dell'entita' (`ck_off == ck_on` su tutte
#'   e 87.092 le righe).
#'
#' Nessuno di questi difetti tocca le tre fusioni qui sotto: sono sostenute dal
#' nome primario, adjudicate una per una, e **nessuna e' fra le entita' colpite
#' dallo split del ramo anchor** (verificato sull'output v14).
#'
#' Il beneficio dichiarato resta intero, ed e' quello su cui la decisione fu
#' presa: il gruppo `HGNC:11766` contiene GIA' membri etichettati `TGF-beta`,
#' `TGFbeta`, `TGF-B1`; tenerne fuori `TGFb` non e' una distinzione scientifica
#' ma un incidente del resolver, e nei Methods non si puo' scrivere.
#'
#' Le ~918 fusioni abbandonate restano `STR:`, cioe' **esattamente come in v13**:
#' un'etichetta ignota ma onesta, con i gruppi formati per stringa identica.
#' @keywords internal
#' @noRd
.CA_DEFRAG_ACCEPT <- c(
  # TGF-beta1: `tgfb`, `TGF-B`, `tgf_b` normalizzano tutti a "tgfb". Misurato:
  # nessuna entita' oltre TGFB1 ha "tgfb" nudo fra gli alias (TGFB2 e TGFB3
  # hanno "tgfb2"/"tgfb3"). E' la figura 2 del main paper: k 65 -> 78.
  "tgfb"         = "HGNC:11766",
  # Glioblastoma: il resolver MeSH non lo vede (limite noto "glioblastoma MeSH
  # miss", name-cleanup 2026-07-07), l'alias lo aggancia in modo univoco.
  "glioblastoma" = "MeSH:D005909",
  # IL17A: "il17" aggancia solo HGNC:5981 fra i geni. Giudicata ammissibile
  # nella decisione del 2026-07-31 (nel corpus esiste un solo gruppo IL17).
  "il17"         = "HGNC:5981"
)

#' Entita' recuperata dalla de-frammentazione, oppure NA
#'
#' @param token character(1) il token che finirebbe in \code{STR:}.
#' @param contrast_class classe dominante del delta (decide le ontologie).
#' @param ontology_env ambiente dei dizionari.
#' @return character(1) ID ontologico, oppure \code{NA_character_} se non si
#'   fonde (token corto, nessun aggancio, aggancio ambiguo, guardia accesa).
#' @keywords internal
#' @noRd
.ca_defrag_entity <- function(token, contrast_class, ontology_env) {
  key <- .ca_defrag_norm(token)
  if (nchar(key) < .CA_DEFRAG_MIN_CHARS) return(NA_character_)
  # le guardie del resolver valgono anche qui: la de-frammentazione non e' una
  # porta di servizio per rientrare da dietro (audit collisioni 2026-07-25).
  if (.is_unreliable_candidate(key)) return(NA_character_)

  # La fusione avviene SOLO per le entita' della lista autorizzata.
  v <- unname(.CA_DEFRAG_ACCEPT[key])
  if (is.na(v)) return(NA_character_)
  # cinture e bretelle: le guardie gia' in produzione valgono comunque
  if (.is_alias_collision(key, v)) return(NA_character_)
  if (paste0(key, "|", v) %in% .CA_DEFRAG_REJECT) return(NA_character_)
  v
}
