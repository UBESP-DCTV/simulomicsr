# =============================================================================
# LA REGOLA, A PAROLE (leggere prima del codice)
# =============================================================================
#
# PROBLEMA MISURATO. Nel deliverable la stessa entita' biologica compare sotto
# CODICI ONTOLOGICI DIVERSI, e ogni copia si porta via una parte degli studi:
# `HGNC:11892` (TNF, k=41) accanto a `CHEMBL:CHEMBL265582` (TNF-ALPHA, k=7);
# `HGNC:2434` (CSF2, k=3) accanto a `CHEMBL:CHEMBL2107881` (REGRAMOSTIM, k=4).
# Questo asse NON e' quello del 2026-08-01 (`R/stage3-defrag-alias.R`), che
# lavora sugli slug `STR:` e agisce SOLO sul ramo di ripiego: se il resolver ha
# gia' prodotto un ID, quella regola non viene nemmeno interrogata. La
# frammentazione codice-contro-codice non e' mai stata toccata da nessuno.
#
# LA REGOLA, IN CINQUE RIGHE.
#   Due identificatori di REGISTRI DIVERSI designano la stessa entita' quando
#   condividono un NOME NORMALIZZATO che, dentro ciascuno dei due registri,
#   appartiene a UNA SOLA entita'. La forza della fusione e' il rango del nome
#   che la sostiene: nome canonico contro nome canonico (T1) > nome canonico
#   contro alias (T2) > alias contro alias (T3). Prima di tutto si applica il
#   redirect UFFICIALE di ChEBI (secondary -> primary), che non e' un'inferenza.
#   Se il nome condiviso e' corto, generico, un'unita' di misura, un nome
#   ombrello o una collisione gia' accertata, la regola si arrende.
#
# COSA LA REGOLA NON FA, E PERCHE'.
#  (a) NON fonde due ID dello STESSO registro. Un registro che tiene due nodi
#      distinti sta facendo un'affermazione: `CHEBI:4167` (D-glucopiranosio) e
#      `CHEBI:17234` (glucosio) sono legati da `is_a`, non sono sinonimi. Fonderli
#      e' un giudizio chimico che questa regola non sa fare. Le coppie
#      intra-registro che condividono un alias si CONTANO e si ELENCANO (uscita
#      `23-intra-registro.csv`), annotate con la relazione `is_a` quando c'e',
#      e si lasciano alla decisione dell'utente.
#  (b) NON risolve gli slug `STR:`. E' terra gia' battuta e non ha pagato
#      (v14: 305 -> 304 gruppi, -22 studi poolati netti). Lo slug si tocca solo
#      nella misura di precisione storica (`80-...R`), che riusa le 241 coppie
#      giudicate a mano il 2026-08-01 come insieme etichettato.
#  (c) NON fonde mai due versi diversi: la chiave di fusione porta sempre
#      `contrast_direction` (decisione utente). La chiave di CONTROLLO invece
#      non entra nella chiave di fusione, e questo va detto: una fusione che
#      attraversa due chiavi di controllo NON e' poolabile da sola. Le due
#      grandezze si riportano separate.
#
# GUARDIE (tutte gia' in produzione, richiamate non riscritte):
#   .CA_DEFRAG_MIN_CHARS (>=4 caratteri alfanumerici sulla chiave che fa da
#   ponte), .is_unreliable_candidate (unita' di misura e parole funzionali),
#   .is_alias_collision (le 76 coppie alias->ID accertate false),
#   .cg_is_umbrella_name (nomi di classe), .GENERIC_COMPOUND_STOPLIST.
#
# RAPPRESENTANTE della componente fusa: l'ID col k TOTALE piu' alto nel corpus;
#   a pari k, priorita' di registro dichiarata (ChEBI > HGNC > MeSH > NCBITaxon
#   > CHEMBL); a pari registro, ordine lessicografico. Scelto cosi' perche' una
#   priorita' di registro secca sposterebbe l'identita' dei gruppi grossi
#   (TGF-beta1 e' `HGNC:11766` in tutto il progetto).
#
# LETTURA READ-ONLY. Nessuna modifica a `R/`, nessun re-cluster, nessun commit.
# =============================================================================

suppressWarnings(suppressMessages(devtools::load_all(".", quiet = TRUE)))

OUT <- "analysis/audit/2026-08-08-deframmentazione"
DICT <- "/home/user/.cache/R/simulomicsr"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
say <- function(...) cat(sprintf(...), "\n", sep = "")

# --------------------------------------------------------------------------
# 0. Normalizzazione della chiave-nome
# --------------------------------------------------------------------------
# `.ca_defrag_norm` (produzione) e' scalare: qui serve vettorizzata su 3,3 M di
# nomi. La forma vettoriale viene VERIFICATA identica a quella di produzione su
# un campione, perche' uno strumento che vede meno del dato e' l'errore che
# questo progetto ha gia' pagato tre volte.
#
# ⚠️ AGGIUNTA NECESSARIA, trovata guardando i dati: i nomi ChEBI contengono
# MARCATURA HTML (`<small>D</small>-glucopyranose`, `<i>trans</i>-...`). Senza
# togliere i tag, `.ca_defrag_norm` produce "smalldsmallglucopyranose" e nessun
# ponte puo' agganciare. La rimozione dei tag e' quindi PARTE della regola, e va
# dichiarata: e' una differenza dal comportamento di produzione.
.strip_markup <- function(x) gsub("<[^>]*>", "", x)
norm_vec <- function(x) {
  x[is.na(x)] <- ""
  gsub("[^a-z0-9]", "", tolower(.strip_markup(x)))
}

# --------------------------------------------------------------------------
# 1. Corpus: le entita' dei cluster `cgroup`
# --------------------------------------------------------------------------
cl <- readRDS("analysis/p4-output/20260803T164558Z-stage3-v15-7f986159/clusters.rds")
cg <- cl[cl$mode == "cgroup", c("cluster_id", "anchor_key", "k", "n_total",
                                "studies_in_cluster", "canonical_name",
                                "contrast_entity", "contrast_direction",
                                "contrast_control_key", "contrast_entity_source")]
stopifnot(nrow(cg) == 11536L, all(cl$level[cl$mode == "cgroup"] == 5L))
say("cgroup: %d cluster, %d entita' distinte", nrow(cg), length(unique(cg$contrast_entity)))

# Prefissi: si leggono senza assumere il caso. Se esistessero due grafie dello
# stesso prefisso (`CHEMBL:` e `ChEMBL:`) sarebbe frammentazione da bug di
# scrittura, e va vista qui, non piu' avanti.
pref_raw <- sub(":.*$", "", cg$contrast_entity)
say("--- prefissi (grafia LETTERALE, non normalizzata) ---")
print(sort(table(pref_raw), decreasing = TRUE))
if (length(unique(tolower(pref_raw))) != length(unique(pref_raw)))
  say("⚠️ ATTENZIONE: due grafie dello stesso prefisso -> frammentazione da casing")

# Parti degli ID: un COMBO e' una lista di ID e va canonicalizzato pezzo per pezzo
combo_parts <- function(e) strsplit(sub("^COMBO:", "", e), "+", fixed = TRUE)[[1L]]
is_combo <- startsWith(cg$contrast_entity, "COMBO:")
ids_corpus <- unique(c(cg$contrast_entity[!is_combo],
                       unlist(lapply(cg$contrast_entity[is_combo], combo_parts))))
reg_of <- function(id) {
  p <- tolower(sub(":.*$", "", id))
  ifelse(p %in% c("chebi", "chembl", "hgnc", "mesh", "ncbitaxon"), p, "altro")
}
ids_onto <- ids_corpus[reg_of(ids_corpus) != "altro"]
say("ID distinti nel corpus: %d, di cui ontologici: %d", length(ids_corpus), length(ids_onto))
say("per registro: %s", paste(sprintf("%s=%d", names(table(reg_of(ids_onto))),
                                      as.integer(table(reg_of(ids_onto)))), collapse = " "))

# --------------------------------------------------------------------------
# 2. Tabelle nome->ID per registro, con il rango del nome
# --------------------------------------------------------------------------
# rango 1 = nome CANONICO (quello che il registro presenta come nome
# dell'entita'), rango 2 = alias. La distinzione decide il tier della fusione.
leggi_registro <- function(reg) {
  if (reg == "chebi") {
    d <- readRDS(file.path(DICT, "chebi", "chebi-lookup.rds"))
    canon <- rbind(
      data.frame(id = paste0("CHEBI:", d$by_id$chebi_id), nome = d$by_id$primary_name),
      data.frame(id = paste0("CHEBI:", d$by_id$chebi_id), nome = d$by_id$ascii_name))
    alias <- data.frame(id = paste0("CHEBI:", d$aliases$chebi_id), nome = d$aliases$alias_lower)
    extra <- list(secondary = d$secondary, is_a = d$is_a)
  } else if (reg == "hgnc") {
    d <- readRDS(file.path(DICT, "hgnc-lookup.rds"))
    canon <- rbind(
      data.frame(id = paste0("HGNC:", d$by_hgnc_int$hgnc_int), nome = d$by_hgnc_int$symbol),
      data.frame(id = paste0("HGNC:", d$by_hgnc_int$hgnc_int), nome = d$by_hgnc_int$name))
    alias <- data.frame(id = paste0("HGNC:", d$aliases_long$hgnc_int),
                        nome = d$aliases_long$alias_lower)
    extra <- list()
  } else if (reg == "mesh") {
    d <- readRDS(file.path(DICT, "mesh-lookup.rds"))
    canon <- data.frame(id = paste0("MeSH:", d$by_ui$ui), nome = d$by_ui$mh)
    alias <- data.frame(id = paste0("MeSH:", d$by_entry_lower$ui),
                        nome = d$by_entry_lower$entry_lower)
    extra <- list()
  } else if (reg == "chembl") {
    d <- readRDS(file.path(DICT, "chembl", "chembl-lookup.rds"))
    canon <- data.frame(id = paste0("CHEMBL:", d$by_id$chembl_id), nome = d$by_id$pref_name)
    alias <- data.frame(id = paste0("CHEMBL:", d$aliases$chembl_id), nome = d$aliases$alias_lower)
    extra <- list()
  } else if (reg == "ncbitaxon") {
    d <- readRDS(file.path(DICT, "taxonomy", "taxonomy-lookup.rds"))
    sci <- d$names$name_class == "scientific name"
    canon <- data.frame(id = paste0("NCBITaxon:", d$names$taxid[sci]),
                        nome = d$names$name_norm[sci])
    alias <- data.frame(id = paste0("NCBITaxon:", d$names$taxid[!sci]),
                        nome = d$names$name_norm[!sci])
    extra <- list()
  } else stop("registro ignoto: ", reg)
  canon$key <- norm_vec(canon$nome); canon$rango <- 1L
  alias$key <- norm_vec(alias$nome); alias$rango <- 2L
  tab <- rbind(canon, alias)
  tab <- tab[nzchar(tab$key) & !is.na(tab$id), ]
  # una chiave che compare come canonica E come alias della STESSA entita'
  # resta canonica (il rango migliore vince)
  tab <- tab[order(tab$key, tab$rango), ]
  tab <- tab[!duplicated(paste0(tab$key, "\r", tab$id)), ]
  list(tab = tab, extra = extra)
}

REG <- c("chebi", "hgnc", "mesh", "chembl", "ncbitaxon")
say("--- lettura dizionari ---")
DB <- list()
for (r in REG) {
  t0 <- Sys.time()
  DB[[r]] <- leggi_registro(r)
  say("%-10s %8d righe nome->ID  (%.0fs)", r, nrow(DB[[r]]$tab),
      as.numeric(difftime(Sys.time(), t0, units = "secs")))
}

# equivalenza della normalizzazione vettoriale con quella di produzione
set.seed(20260808)
camp <- sample(DB$chebi$tab$nome, 3000)
eq <- identical(unname(norm_vec(camp)),
                unname(vapply(.strip_markup(camp), simulomicsr:::.ca_defrag_norm, character(1L))))
say("normalizzazione vettoriale == .ca_defrag_norm su 3000 nomi (post-strip markup): %s", eq)
stopifnot(eq)

# --------------------------------------------------------------------------
# 3. Chiavi UNIVOCHE per registro
# --------------------------------------------------------------------------
# Una chiave che dentro il suo registro appartiene a piu' entita' non prova
# niente: si butta. Non e' una scelta di comodo — e' il meccanismo con cui
# `ifna` non si fonde (alias sia di IFNA1 sia di IFNA2).
indice_univoco <- function(tab) {
  t <- tab[nchar(tab$key) >= simulomicsr:::.CA_DEFRAG_MIN_CHARS, ]
  n <- tapply(t$id, t$key, function(z) length(unique(z)))
  ok <- names(n)[n == 1L]
  u <- t[t$key %in% ok, ]
  u <- u[!duplicated(u$key), c("key", "id", "rango")]
  u
}
UNI <- lapply(DB, function(x) indice_univoco(x$tab))
for (r in REG) say("%-10s chiavi univoche >=%d char: %d (su %d chiavi distinte)",
                   r, simulomicsr:::.CA_DEFRAG_MIN_CHARS, nrow(UNI[[r]]),
                   length(unique(DB[[r]]$tab$key)))

# --------------------------------------------------------------------------
# 4. La regola: ponti fra registri
# --------------------------------------------------------------------------
# Le guardie si applicano alla CHIAVE che fa da ponte, in entrambe le direzioni.
guardia_ok <- function(key, id_a, id_b) {
  if (nchar(key) < simulomicsr:::.CA_DEFRAG_MIN_CHARS) return(FALSE)
  if (simulomicsr:::.is_unreliable_candidate(key)) return(FALSE)
  if (key %in% simulomicsr:::.GENERIC_COMPOUND_STOPLIST) return(FALSE)
  if (simulomicsr:::.cg_is_umbrella_name(key)) return(FALSE)
  if (simulomicsr:::.is_alias_collision(key, id_a)) return(FALSE)
  if (simulomicsr:::.is_alias_collision(key, id_b)) return(FALSE)
  TRUE
}

# chiavi univoche degli ID DEL CORPUS (il ponte parte sempre da un'entita' che
# esiste nel deliverable: la regola misura la frammentazione, non ri-annota il
# mondo)
chiavi_corpus <- do.call(rbind, lapply(REG, function(r) {
  u <- UNI[[r]]; u <- u[u$id %in% ids_onto, ]; if (!nrow(u)) return(NULL)
  data.frame(reg = r, key = u$key, id = u$id, rango = u$rango, stringsAsFactors = FALSE)
}))
say("chiavi univoche appartenenti a ID del corpus: %d", nrow(chiavi_corpus))

kc <- unique(chiavi_corpus$key)
ponti <- list()
for (rb in REG) {
  ub <- UNI[[rb]][UNI[[rb]]$key %in% kc, ]
  if (!nrow(ub)) next
  m <- merge(chiavi_corpus, ub, by = "key", suffixes = c("_a", "_b"))
  m <- m[m$reg != rb, ]
  if (!nrow(m)) next
  m$reg_b <- rb
  ok <- vapply(seq_len(nrow(m)),
               function(i) guardia_ok(m$key[i], m$id_a[i], m$id_b[i]), logical(1L))
  m <- m[ok, , drop = FALSE]
  if (!nrow(m)) next
  ponti[[length(ponti) + 1L]] <- data.frame(
    id_a = m$id_a, id_b = m$id_b, reg_a = m$reg, reg_b = m$reg_b, chiave = m$key,
    tier = ifelse(m$rango_a == 1L & m$rango_b == 1L, "T1_canonico_canonico",
           ifelse(m$rango_a == 1L | m$rango_b == 1L, "T2_canonico_alias",
                  "T3_alias_alias")),
    stringsAsFactors = FALSE)
}
ponti <- if (length(ponti)) unique(do.call(rbind, ponti)) else
  data.frame(id_a = character(0), id_b = character(0), reg_a = character(0),
             reg_b = character(0), chiave = character(0), tier = character(0))
# la coppia non e' orientata: si tiene una sola riga per coppia, col tier migliore
ponti$coppia <- apply(cbind(ponti$id_a, ponti$id_b), 1L,
                      function(z) paste(sort(z), collapse = "\r"))
ponti <- ponti[order(ponti$coppia, ponti$tier), ]
ponti_u <- ponti[!duplicated(ponti$coppia), ]
say("--- equivalenze fra registri trovate: %d coppie distinte ---", nrow(ponti_u))
print(table(ponti_u$tier))
print(table(paste(pmin(ponti_u$reg_a, ponti_u$reg_b), pmax(ponti_u$reg_a, ponti_u$reg_b), sep = "-")))
# Una coppia produce FRAMMENTAZIONE solo se ENTRAMBI gli ID stanno nel corpus:
# se il gemello non e' nel deliverable non c'e' nessun gruppo da fondere.
ponti_u$entrambi_nel_corpus <- ponti_u$id_a %in% ids_onto & ponti_u$id_b %in% ids_onto
say("di cui con ENTRAMBI gli ID nel corpus (= frammentazione vera): %d",
    sum(ponti_u$entrambi_nel_corpus))
print(table(ponti_u$tier[ponti_u$entrambi_nel_corpus]))

# redirect UFFICIALE ChEBI: secondary -> primary (non e' inferenza)
sec <- DB$chebi$extra$secondary
red <- data.frame(id_a = paste0("CHEBI:", sec$secondary_id),
                  id_b = paste0("CHEBI:", sec$primary_id),
                  reg_a = "chebi", reg_b = "chebi",
                  chiave = "<redirect_ufficiale>", tier = "T0_redirect_chebi",
                  stringsAsFactors = FALSE)
red <- red[red$id_a %in% ids_onto | red$id_b %in% ids_onto, ]
red <- red[red$id_a %in% ids_onto & red$id_b %in% ids_onto, ]
say("redirect ChEBI con ENTRAMBI gli ID nel corpus: %d", nrow(red))
if (nrow(red)) red$coppia <- apply(cbind(red$id_a, red$id_b), 1L,
                                   function(z) paste(sort(z), collapse = "\r"))

FUS <- rbind(ponti_u[, c("id_a","id_b","reg_a","reg_b","chiave","tier","coppia")],
             if (nrow(red)) red[, c("id_a","id_b","reg_a","reg_b","chiave","tier","coppia")])

# --------------------------------------------------------------------------
# 5. Chiusura transitiva (union-find) e rappresentante
# --------------------------------------------------------------------------
parent <- setNames(ids_onto, ids_onto)
find <- function(x) { while (parent[[x]] != x) x <- parent[[x]]; x }
for (i in seq_len(nrow(FUS))) {
  a <- FUS$id_a[i]; b <- FUS$id_b[i]
  if (!(a %in% names(parent)) || !(b %in% names(parent))) next
  ra <- find(a); rb <- find(b)
  if (ra != rb) parent[[rb]] <- ra
}
comp <- vapply(ids_onto, find, character(1L))

# k totale per ID nel corpus (un COMBO conta il suo k su ogni parte)
k_per_id <- local({
  e <- character(0); kk <- integer(0)
  for (i in seq_len(nrow(cg))) {
    parti <- if (is_combo[i]) combo_parts(cg$contrast_entity[i]) else cg$contrast_entity[i]
    e <- c(e, parti); kk <- c(kk, rep(cg$k[i], length(parti)))
  }
  tapply(kk, e, sum)
})
PRIO <- c(chebi = 1L, hgnc = 2L, mesh = 3L, ncbitaxon = 4L, chembl = 5L)
rappresentante <- function(ids) {
  kv <- unname(k_per_id[ids]); kv[is.na(kv)] <- 0L
  o <- order(-kv, PRIO[reg_of(ids)], ids)
  ids[o[1L]]
}
canon_id <- setNames(rep(NA_character_, length(ids_onto)), ids_onto)
for (cp in unique(comp)) {
  membri <- names(comp)[comp == cp]
  canon_id[membri] <- rappresentante(membri)
}

# --------------------------------------------------------------------------
# 6. entita_canonica(): la funzione richiesta
# --------------------------------------------------------------------------
#' Entita' canonica di un `contrast_entity`
#'
#' @param contrast_entity vettore di entita' cosi' come stanno in clusters.rds
#' @param contrast_entity_source opzionale, solo per la tracciatura
#' @return data.frame con `entita_canonica`, `fonte_risoluzione`, `fiducia`
entita_canonica <- function(contrast_entity, contrast_entity_source = NULL,
                            mappa = canon_id, ponti = FUS) {
  tier_di <- setNames(ponti$tier, ponti$coppia)
  risolvi_uno <- function(id) {
    if (is.na(id) || !nzchar(id)) return(c(NA_character_, "NA", "nessuna"))
    if (startsWith(id, "STR:")) return(c(id, "STR_NON_TOCCATO", "nessuna"))
    if (!(id %in% names(mappa))) return(c(id, "FUORI_CORPUS", "nessuna"))
    cn <- mappa[[id]]
    if (identical(cn, id)) return(c(id, "GIA_CANONICO", "nessuna"))
    tt <- tier_di[[paste(sort(c(id, cn)), collapse = "\r")]]
    c(cn, if (is.null(tt)) "FUSIONE_TRANSITIVA" else tt,
      if (is.null(tt)) "media" else switch(sub("_.*$", "", tt),
        T0 = "alta", T1 = "alta", T2 = "media", T3 = "bassa", "media"))
  }
  out <- vapply(contrast_entity, function(e) {
    if (is.na(e)) return(c(NA_character_, "NA", "nessuna"))
    if (startsWith(e, "COMBO:")) {
      p <- strsplit(sub("^COMBO:", "", e), "+", fixed = TRUE)[[1L]]
      r <- lapply(p, risolvi_uno)
      nuovi <- sort(vapply(r, `[`, character(1L), 1L))
      fonti <- vapply(r, `[`, character(1L), 2L)
      fid   <- vapply(r, `[`, character(1L), 3L)
      cambiato <- any(fonti %in% c("T0_redirect_chebi", "T1_canonico_canonico",
                                   "T2_canonico_alias", "T3_alias_alias",
                                   "FUSIONE_TRANSITIVA"))
      return(c(paste0("COMBO:", paste(nuovi, collapse = "+")),
               if (cambiato) paste0("COMBO_PARTE(", paste(unique(fonti[fonti != "GIA_CANONICO"]),
                                                          collapse = ","), ")") else "GIA_CANONICO",
               if (cambiato) fid[which(fid != "nessuna")[1L]] else "nessuna"))
    }
    risolvi_uno(e)
  }, character(3L), USE.NAMES = FALSE)
  data.frame(contrast_entity = contrast_entity,
             entita_canonica = out[1, ], fonte_risoluzione = out[2, ],
             fiducia = out[3, ], stringsAsFactors = FALSE)
}

# --------------------------------------------------------------------------
# 7. Applicazione a tutti gli 11.536
# --------------------------------------------------------------------------
res <- entita_canonica(cg$contrast_entity, cg$contrast_entity_source)
cg$entita_canonica   <- res$entita_canonica
cg$fonte_risoluzione <- res$fonte_risoluzione
cg$fiducia           <- res$fiducia
say("--- esito su 11.536 cgroup ---")
print(table(cg$fonte_risoluzione))
say("cluster con entita' RISCRITTA: %d", sum(cg$entita_canonica != cg$contrast_entity))

say("--- componenti con >1 ID ---")
cs <- table(canon_id)
say("componenti di dimensione 2: %d, 3: %d, >=4: %d",
    sum(cs == 2), sum(cs == 3), sum(cs >= 4))
say("--- LE FUSIONI, una per una (ID, k nel corpus, nome canonico dal registro) ---")
nome_di <- function(id) {
  r <- reg_of(id); if (r == "altro") return(NA_character_)
  t <- DB[[r]]$tab; t <- t[t$id == id & t$rango == 1L, ]
  if (!nrow(t)) return(NA_character_); .strip_markup(t$nome[1L])
}
for (r in names(cs)[cs >= 2]) {
  membri <- names(canon_id)[canon_id == r]
  say("  %s", paste(sprintf("%s(k=%s,\"%s\")", membri,
                            ifelse(is.na(k_per_id[membri]), 0L, k_per_id[membri]),
                            vapply(membri, nome_di, character(1L))), collapse = "  ==  "))
  pr <- FUS[FUS$coppia %in% apply(utils::combn(sort(membri), 2L), 2L,
                                  function(z) paste(z, collapse = "\r")), ]
  if (nrow(pr)) say("      ponte: %s", paste(sprintf("%s via '%s'", pr$tier, pr$chiave), collapse = "; "))
}

# --------------------------------------------------------------------------
# 8. Coppie INTRA-registro che condividono un alias: contate, NON fuse
# --------------------------------------------------------------------------
intra <- list()
for (r in REG) {
  t <- DB[[r]]$tab
  t <- t[t$id %in% ids_onto & nchar(t$key) >= simulomicsr:::.CA_DEFRAG_MIN_CHARS, ]
  amb <- t[t$key %in% names(which(tapply(t$id, t$key, function(z) length(unique(z))) > 1L)), ]
  if (!nrow(amb)) next
  for (kk in unique(amb$key)) {
    ii <- sort(unique(amb$id[amb$key == kk]))
    if (length(ii) < 2L) next
    for (a in seq_len(length(ii) - 1L)) for (b in (a + 1L):length(ii)) {
      intra[[length(intra) + 1L]] <- data.frame(
        registro = r, id_a = ii[a], id_b = ii[b], chiave = kk,
        rango = min(amb$rango[amb$key == kk]), stringsAsFactors = FALSE)
    }
  }
}
intra <- if (length(intra)) unique(do.call(rbind, intra)) else
  data.frame(registro = character(0), id_a = character(0), id_b = character(0),
             chiave = character(0), rango = integer(0))
# annota is_a (ChEBI): se uno e' antenato dell'altro non e' un doppione, e' una
# CLASSE che contiene l'altro
isa <- DB$chebi$extra$is_a
isa_pair <- paste0("CHEBI:", isa$chebi_id, "\r", "CHEBI:", isa$parent_id)
intra$is_a <- ifelse(paste0(intra$id_a, "\r", intra$id_b) %in% isa_pair, "a_is_a_b",
              ifelse(paste0(intra$id_b, "\r", intra$id_a) %in% isa_pair, "b_is_a_a", ""))
say("--- coppie INTRA-registro con alias condiviso (NON fuse): %d ---", nrow(intra))
if (nrow(intra)) {
  print(table(intra$registro)); print(table(intra$is_a))
  intra$k_a <- ifelse(is.na(k_per_id[intra$id_a]), 0L, k_per_id[intra$id_a])
  intra$k_b <- ifelse(is.na(k_per_id[intra$id_b]), 0L, k_per_id[intra$id_b])
  intra$nome_a <- vapply(intra$id_a, nome_di, character(1L))
  intra$nome_b <- vapply(intra$id_b, nome_di, character(1L))
  o <- order(-(pmin(intra$k_a, intra$k_b)))
  say("  le prime 15 per k del ramo piu' piccolo:")
  for (i in head(o, 15L)) say("   %-14s(k=%2d,\"%s\")  ~ %-14s(k=%2d,\"%s\")  alias '%s' %s",
      intra$id_a[i], intra$k_a[i], intra$nome_a[i], intra$id_b[i], intra$k_b[i],
      intra$nome_b[i], intra$chiave[i], intra$is_a[i])
}

# --------------------------------------------------------------------------
# 9. Uscite
# --------------------------------------------------------------------------
saveRDS(list(cg = cg, fusioni = FUS, canon_id = canon_id, intra = intra,
             k_per_id = k_per_id, DB_meta = vapply(DB, function(x) nrow(x$tab), integer(1))),
        file.path(OUT, "21-regola-esito.rds"))
cg_csv <- cg
cg_csv$studies_in_cluster <- vapply(cg$studies_in_cluster,
                                    function(z) paste(unlist(z), collapse = ";"), character(1L))
utils::write.csv(cg_csv, file.path(OUT, "21-canonico-per-cluster.csv"), row.names = FALSE)
utils::write.csv(ponti_u[, c("id_a","id_b","reg_a","reg_b","chiave","tier","entrambi_nel_corpus")],
                 file.path(OUT, "22-ponti-fra-registri.csv"), row.names = FALSE)
utils::write.csv(intra, file.path(OUT, "23-intra-registro.csv"), row.names = FALSE)
say("scritti: 21-regola-esito.rds, 21-canonico-per-cluster.csv, 22-ponti-fra-registri.csv, 23-intra-registro.csv")
