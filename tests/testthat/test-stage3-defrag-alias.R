# De-frammentazione: un token che sarebbe finito in `STR:` si fonde nell'ID
# ontologico SOLO se aggancia, in modo UNIVOCO, un alias per esteso (>3
# caratteri) di una sola entita' fra quelle che la classe del contrasto
# interroga.
#
# Perche' esiste (decisione 2026-07-31): il gruppo HGNC:11766 contiene GIA'
# membri etichettati "TGF-beta"/"TGFbeta"/"TGF-B1"; tenere fuori "TGFb" non e'
# una distinzione scientifica, e' un incidente del resolver. Ma la fusione non
# puo' essere una lista di casi: e' una regola meccanica, e dove la stringa non
# dice l'identita' (IFNa = IFNA1 o IFNA2?) NON si fonde.
#
# Il vincolo ">3 caratteri" e' quello gia' pagato il 2026-07-29: un match su una
# SIGLA fece dare per buono CHEBI:73572 (il tripeptide Leu-Thr-Ala ha "LTA" fra
# i sinonimi, ma negli studi LTA e' acido lipoteicoico).

# ---------------------------------------------------------------- normalizza --

test_that(".ca_defrag_norm riduce le scritture diverse alla stessa chiave", {
  expect_equal(.ca_defrag_norm("TGFb"), "tgfb")
  expect_equal(.ca_defrag_norm("TGF-B"), "tgfb")
  expect_equal(.ca_defrag_norm("tgf_b"), "tgfb")
  expect_equal(.ca_defrag_norm("  TGF b  "), "tgfb")
  # le CIFRE restano: senza, TGFB1 e TGFB2 sarebbero la stessa chiave
  expect_equal(.ca_defrag_norm("TGFB2"), "tgfb2")
  expect_equal(.ca_defrag_norm(NA_character_), "")
  expect_equal(.ca_defrag_norm(""), "")
})

# ------------------------------------------------- quali ontologie, per classe --

test_that("l'ordine delle ontologie NON dipende dalla classe (niente split)", {
  # ⚠️ La prima versione sceglieva le ontologie per CLASSE. Misurato sull'output
  # vero di v14: produceva SPLIT — `STR:hypoxia` k=33 E `MeSH:D000860` k=10, la
  # stessa entita' in due gruppi, entrambi nel deliverable. Un ordine unico lo
  # elimina per costruzione, e questo test lo difende.
  for (cls in c("disease", "drug", "genetic", "infection", "other", "time",
                NA_character_)) {
    expect_identical(.ca_defrag_ontologies(cls), .CA_DEFRAG_ONTOLOGY_ORDER)
  }
  # la tassonomia e' ULTIMA: e' la fonte del problema del granchio
  expect_identical(utils::tail(.CA_DEFRAG_ONTOLOGY_ORDER, 1L), "taxon")
})

test_that("lo stesso token da' lo STESSO ID qualunque sia la classe", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # e' l'invariante che impedisce lo split, provata sui casi che lo produssero
  # ⚠️ glioblastoma rimosso il 2026-08-02: non si fonde piu' e ritornerebbe NA
  for (tk in c("hypoxia", "schizophrenia", "sepsis", "smoking", "tgfb",
               "il17")) {
    ids <- unique(vapply(c("disease", "drug", "genetic", "infection", "other"),
                         function(c) .ca_defrag_entity(tk, c, oe), character(1L)))
    expect_length(ids, 1L)
  }
})

test_that("l'omonimia nella tassonomia resta un rischio REALE, e per questo `sepsis` non si fonde", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # ⚠️ ASSERZIONE CAMBIATA il 2026-08-01 con la restrizione alle tre entita'
  # autorizzate. Prima questo test chiedeva `sepsis -> MeSH:D018805`, perche' la
  # regola generale fondeva 923 entita' e l'ordine delle ontologie serviva a far
  # vincere la malattia sull'omonimo. Ora `sepsis` non e' autorizzata e resta
  # `STR:`, come in v13.
  # Il rischio che il test documenta e' comunque VERO e va tenuto scritto:
  # NCBITaxon:137507 e' un GENERE DI MOSCHE che si chiama Sepsis, ed e' la stessa
  # famiglia di `cancer`->granchio e `mito`->una pianta.
  expect_equal(.ca_defrag_index(oe, "taxon")[["sepsis"]], "NCBITaxon:137507")
  expect_true(is.na(.ca_defrag_entity("sepsis", "disease", oe)))
  expect_true(is.na(.ca_defrag_entity("sepsis", "drug", oe)))
})

# ------------------------------------------------------------------- la regola --

test_that(".ca_defrag_entity fonde TGFb in TGFB1 (aggancio univoco)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # misurato il 2026-07-31: nessuna entita' oltre TGFB1 ha "tgfb" nudo fra gli
  # alias — TGFB2 e TGFB3 hanno "tgfb2"/"tgfb3"
  expect_equal(.ca_defrag_entity("tgfb", "drug", oe), "HGNC:11766")
  expect_equal(.ca_defrag_entity("tgf_b", "drug", oe), "HGNC:11766")
  expect_equal(.ca_defrag_entity("TGF-B", "drug", oe), "HGNC:11766")
})

test_that(".ca_defrag_entity NON fonde IFNa: la stringa non dice quale interferone", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # "ifna" e' alias sia di IFNA1 (HGNC:5417) sia di IFNA2 (HGNC:5423)
  expect_true(is.na(.ca_defrag_entity("ifna", "drug", oe)))
})

test_that(".ca_defrag_entity non fonde MAI su una sigla di 3 caratteri", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # il caso gia' pagato: "LTA" e' sinonimo del tripeptide Leu-Thr-Ala
  expect_true(is.na(.ca_defrag_entity("lta", "drug", oe)))
  # e nemmeno quando l'aggancio SAREBBE univoco: la lunghezza viene prima
  expect_true(is.na(.ca_defrag_entity("dht", "drug", oe)))
  expect_true(is.na(.ca_defrag_entity("tnf", "drug", oe)))
})

test_that(".ca_defrag_entity lascia STR quello che non aggancia nulla", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  expect_true(is.na(.ca_defrag_entity("zzzqqqwww", "drug", oe)))
  expect_true(is.na(.ca_defrag_entity("", "drug", oe)))
  expect_true(is.na(.ca_defrag_entity(NA_character_, "drug", oe)))
})

test_that(".ca_defrag_entity NON fonde glioblastoma (tolto 2026-08-02)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # ⚠️ ASSERZIONE CAPOVOLTA il 2026-08-02. Era autorizzato dalla decisione del
  # 2026-07-31, ma la misura mostra che comprava solo 1 membro su 40, con una
  # chiave di controllo non presente nel gruppo bersaglio. La fusione non
  # chiudeva lo split e avrebbe introdotto una meta-analisi a k=3 mai censita.
  # Restano due fusioni: tgfb e il17.
  expect_true(is.na(.ca_defrag_entity("glioblastoma", "disease", oe)))
})

test_that(".ca_defrag_entity fonde IL17 in IL17A ma solo dove la classe lo prevede", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # nello spazio che la classe drug interroga (ChEBI/ChEMBL/HGNC/taxonomy)
  # "il17" aggancia solo HGNC:5981
  expect_equal(.ca_defrag_entity("il17", "drug", oe), "HGNC:5981")
})

test_that("anche una classe senza resolver fonde, e allo STESSO ID", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # ⚠️ RETTIFICA 2026-08-01: prima queste classi non fondevano nulla, e sembrava
  # la scelta conservativa. Era la CAUSA dello split: un membro `hypoxia` di
  # classe `other` restava STR mentre uno di classe `disease` diventava MeSH.
  expect_equal(.ca_defrag_entity("tgfb", "other", oe), "HGNC:11766")
  expect_equal(.ca_defrag_entity("tgfb", NA_character_, oe), "HGNC:11766")
})

test_that(".ca_defrag_entity rispetta le collisioni alias gia' accertate", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # "activin" e' il caso che esercita davvero la tabella: aggancia HGNC:24029
  # (INHBE) in modo UNIVOCO e con 7 caratteri, quindi passa lunghezza e
  # univocita' — lo ferma solo `.is_alias_collision` (audit 2026-07-25).
  expect_true(.is_alias_collision("activin", "HGNC:24029"))
  expect_true(is.na(.ca_defrag_entity("activin", "drug", oe)))
  # "cancer" aggancia NCBITaxon:6754, il GENERE DEL GRANCHIO: la de-frammentazione
  # interroga la tassonomia come fa il resolver, e senza la guardia sulle parole
  # funzionali ci cascherebbe.
  expect_equal(.ca_defrag_index(oe, "taxon")[["cancer"]], "NCBITaxon:6754")
  expect_true(.is_unreliable_candidate("cancer"))
  expect_true(is.na(.ca_defrag_entity("cancer", "drug", oe)))
  expect_true(is.na(.ca_defrag_entity("donor", "drug", oe)))
  # `mito` -> NCBITaxon:262676 e' *Vasconcellea candicans*, una PIANTA: trovato
  # leggendo una per una le 7 fusioni su taxon (le altre 6 erano ceppi virali
  # corretti). Aggiunto alle collisioni accertate, decisione utente 2026-07-31.
  expect_equal(.ca_defrag_index(oe, "taxon")[["mito"]], "NCBITaxon:262676")
  expect_true(is.na(.ca_defrag_entity("mito", "drug", oe)))
  expect_true(is.na(.ca_defrag_entity("mito", "infection", oe)))
})

# ------------------------------------------------------------- nel gate vero --

test_that("il membro TGFb esce con l'ID del gene, non con STR", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_member_contrast(
    treated_label = "TGFb treated", control_label = "untreated",
    treated_fl = "treatment=TGFb", control_fl = "treatment=none",
    ontology_env = oe)
  expect_equal(r$drop_reason, "")
  expect_equal(r$entity, "HGNC:11766")
  expect_equal(r$entity_source, "defrag")
})

test_that("la de-frammentazione NON tocca i membri che gia' risolvevano", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # non-regressione: il ramo nuovo sta DOPO res$id, non puo' sovrascriverlo
  r <- .ca_member_contrast(
    treated_label = "LNCaP Enzalutamide", control_label = "LNCaP Vehicle",
    treated_fl = "cell_line=LNCaP;treatment=Enzalutamide",
    control_fl = "cell_line=LNCaP;treatment=Vehicle",
    ontology_env = oe)
  expect_equal(r$entity, "CHEBI:68534")
  expect_equal(r$entity_source, "onto")
})

test_that("la fusione non spegne la guardia 'entita' tenuta costante'", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # Per un membro `STR:tgfb` la sonda era il NOME ("tgfb") e trovava l'entita'
  # anche nel braccio di controllo. Per un membro de-frammentato l'entita' e' un
  # ID: senza il token la sonda cercherebbe "hgnc 11766" e non troverebbe mai
  # nulla — la guardia si spegnerebbe in silenzio proprio sui membri nuovi.
  #
  # ⚠️ SCENARIO SCELTO SUI DATI, non a intuito. La prima stesura di questo test
  # usava "TGFb + SB431542" contro "TGFb": misurato, quel caso non arriva qui —
  # lo intercetta prima il ramo delle COMBINAZIONI (entita' COMBO:sb431542+tgfb,
  # membro tenuto). Il test era verde/rosso per la ragione sbagliata.
  r <- .ca_member_contrast(
    treated_label = "TGFb stimulated", control_label = "TGFb withdrawal",
    treated_fl = "treatment=TGFb", control_fl = "treatment=TGFb withdrawal",
    ontology_env = oe)
  expect_equal(r$drop_reason, "entita_costante")
  # controprova: lo stesso trattato contro un controllo che NON nomina l'entita'
  # passa, e passa proprio per la de-frammentazione
  ok <- .ca_member_contrast(
    treated_label = "TGFb treated", control_label = "untreated",
    treated_fl = "treatment=TGFb", control_fl = "treatment=none",
    ontology_env = oe)
  expect_equal(ok$drop_reason, "")
  expect_equal(ok$entity_source, "defrag")
})

test_that("il nome dell'entita' fusa arriva al rilevatore di riga", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # `.ca_entity_tokens` serve a non scambiare il nome dell'entita' per un
  # identificativo di linea cellulare. Con l'ID al posto del nome i token
  # sarebbero "hgnc" e "11766".
  expect_true("tgfb" %in% .ca_entity_tokens(NA_character_, NA_character_,
                                            "HGNC:11766", "tgfb"))
  r <- .ca_member_contrast(
    treated_label = "TGFb treated", control_label = "untreated",
    treated_fl = "treatment=TGFb", control_fl = "treatment=none",
    ontology_env = oe)
  expect_equal(r$drop_reason, "")
})

test_that("il token della fusione arriva alla guardia sugli induttori", {
  # La guardia cerca il NOME. Per un membro fuso l'entita' e' un ID e `res$name`
  # e' NA: senza il token, `.cg_is_inducer` non ha piu' niente da guardare.
  expect_true(.cg_is_inducer("auxin"))
  expect_true(.cg_is_inducer("dtag 13"))
})

test_that("LIMITE PRE-ESISTENTE: la guardia sugli induttori non vede `dtag13`", {
  # ⚠️ Questo test fissa una cosa VERA e scomoda, non un comportamento voluto.
  # `.CG_INDUCERS` contiene "dtag", ma il confronto e' a confini di parola e le
  # CIFRE sono caratteri di parola: `\bdtag\b` non aggancia `dtag13`. Le
  # etichette scritte `dTAG-13` vengono prese, quelle scritte `dTAG13` sfuggono.
  #
  # Misurato sul corpus il 2026-07-31: 64 membri (`STR:dtag13`, `STR:dtag7`,
  # `STR:dtag47`) sono TENUTI, prima e dopo la de-frammentazione. Il difetto e'
  # anteriore a questa regola e non e' chiuso qui: chiuderlo cambierebbe il
  # corpus oltre a cio' che e' stato misurato e autorizzato.
  #
  # ⚠️ RETTIFICA: la prima stesura di questo test asseriva che quei membri
  # venissero SCARTATI come induttori. Falso, e dedotto da un commento invece
  # che contato.
  expect_false(.cg_is_inducer("dtag13"))
  expect_false(.cg_is_inducer("dtag47"))
})

test_that("un membro che restava STR e non aggancia nulla resta STR", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  r <- .ca_member_contrast(
    treated_label = "zzzqqqwww treated", control_label = "untreated",
    treated_fl = "treatment=zzzqqqwww", control_fl = "treatment=none",
    ontology_env = oe)
  expect_true(startsWith(r$entity, "STR:"))
  expect_equal(r$entity_source, "STR")
})

# ------------------------------------------------- le fusioni adjudicate ------

test_that("le fusioni giudicate sbagliate NON avvengono", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # Adjudicate una per una il 2026-08-01 leggendo le etichette vere: 63 coppie
  # su 241 assegnavano un'identita' sbagliata. Qui si difendono le piu' grosse e
  # le piu' istruttive.
  for (tk in c("msa_p", "copd", "pla_b", "nets", "chmi", "mid_49", "mos2",
               "boca", "cadasil", "senv", "cbp30", "blast", "mir_1", "tcells",
               "cpd1", "rela", "ifn_i", "polya", "spms", "iwr1")) {
    expect_true(is.na(.ca_defrag_entity(tk, "drug", oe)),
                info = paste("doveva essere rifiutato:", tk))
  }
})

test_that("il rifiuto NON tocca le due fusioni autorizzate che sono sigle", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # ⚠️ ASSERZIONI RIMOSSE il 2026-08-01, non perche' fossero sbagliate ma perche'
  # descrivono un comportamento che non esiste piu'. `arac`->citarabina,
  # `r837`->imiquimod, `4oht`->afimoxifene, `zikv`->Zika erano fusioni CORRETTE
  # della regola generale, e servivano a provare che nessun filtro meccanico le
  # separa dalle sbagliate (`msa_p`, `copd`, `nets`…). Quella dimostrazione resta
  # valida ed e' il motivo per cui la regola generale e' stata abbandonata: la
  # sua evidenza sta in `analysis/audit/2026-07-31-defrag/90-adjudica.txt`.
  # Con la restrizione, quei quattro token NON si fondono piu' — ed e' asserito
  # nel test "le fusioni abbandonate tornano STR:".
  expect_equal(.ca_defrag_entity("il17", "drug", oe), "HGNC:5981")
  expect_equal(.ca_defrag_entity("tgfb", "drug", oe), "HGNC:11766")
})

# =============================== RESTRIZIONE 2026-08-01 ======================
# La regola fonde SOLO le tre entita' autorizzate dalla decisione del 31/07.
# Tutto il resto torna `STR:`, cioe' esattamente come in v13.

test_that("si fondono SOLO le due entita' autorizzate (glioblastoma tolto 2026-08-02)", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  expect_equal(.ca_defrag_entity("tgfb", "drug", oe), "HGNC:11766")
  expect_equal(.ca_defrag_entity("tgf_b", "drug", oe), "HGNC:11766")
  expect_equal(.ca_defrag_entity("TGF-B", "drug", oe), "HGNC:11766")
  # ⚠️ glioblastoma non si fonde piu': dei 40 membri candidati solo 1 arrivava
  # al ripiego, con una chiave di controllo non presente nel bersaglio.
  expect_true(is.na(.ca_defrag_entity("glioblastoma", "disease", oe)))
  expect_equal(.ca_defrag_entity("il17", "drug", oe), "HGNC:5981")
  expect_length(.CA_DEFRAG_ACCEPT, 2L)
})

test_that("le fusioni abbandonate tornano STR:, non spariscono", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # Le ~918 fusioni della regola generale non avvengono piu'. Le piu' grosse
  # erano corrette (hypoxia 182 membri, covid_19 61, schizophrenia 57): restano
  # `STR:` come in v13 — etichetta ignota ma onesta, gruppo per stringa identica.
  for (tk in c("hypoxia", "covid_19", "schizophrenia", "keloid", "ifnb",
               "r5020", "4oht", "arac", "zikv", "kshv")) {
    expect_true(is.na(.ca_defrag_entity(tk, "drug", oe)), info = tk)
  }
  # e quelle SBAGLIATE a maggior ragione
  for (tk in c("msa_p", "copd", "rela", "ifn_i", "tnfa", "nets", "mos2")) {
    expect_true(is.na(.ca_defrag_entity(tk, "drug", oe)), info = tk)
  }
})

test_that("`tnfa` non aggancia piu' il TNF dello zebrafish: 17 membri salvi", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # La regola generale lo mandava su CHEBI:197439 (TNF di zebrafish), che e' in
  # `.CA_BLACKLIST_ID`: 17 confronti TNFalpha prima TENUTI venivano SCARTATI.
  expect_equal(.ca_defrag_index(oe, "chebi")[["tnfa"]], "CHEBI:197439")
  expect_true("CHEBI:197439" %in% .CA_BLACKLIST_ID)
  expect_true(is.na(.ca_defrag_entity("tnfa", "drug", oe)))
  r <- .ca_member_contrast(
    treated_label = "TNFa treated", control_label = "untreated",
    treated_fl = "treatment=TNFa", control_fl = "treatment=none",
    ontology_env = oe)
  expect_false(identical(r$drop_reason, "id_blacklist"))
})

test_that("ogni entita' autorizzata e' ancora univoca e sostenuta dal nome", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  # l'indice non serve piu' a runtime, ma qui prova che la lista non e' arbitraria
  norm <- function(x) gsub("[^a-z0-9]", "", tolower(x))
  for (k in names(.CA_DEFRAG_ACCEPT)) {
    id <- unname(.CA_DEFRAG_ACCEPT[[k]])
    ont <- if (startsWith(id, "HGNC:")) "hgnc" else if (startsWith(id, "MeSH:")) "mesh" else "chebi"
    expect_equal(.ca_defrag_index(oe, ont)[[k]], id, info = k)   # univoca
    nm <- norm(.resolve_contrast_entity_label(id, env = oe)$label)
    expect_true(grepl(k, nm, fixed = TRUE) || grepl(nm, k, fixed = TRUE), info = k)
  }
})

# ============================== TASK 1 / 2026-08-02 ===========================
# Glioblastoma esce dalle fusioni: la misura mostra che comprava un membro su 40.

test_that("la lista autorizzata contiene DUE entita': glioblastoma e' stato tolto", {
  # Decisione utente 2026-08-02. Misurato: dei 40 membri candidati, 39 hanno gia'
  # l'entita' dal ramo `anchor` (che precede la de-frammentazione) e al ripiego ne
  # arriva UNO, con una chiave di controllo che non esiste nel gruppo bersaglio.
  # La fusione non chiudeva lo split e faceva entrare una meta-analisi a k=3 esatti
  # mai censita.
  expect_length(simulomicsr:::.CA_DEFRAG_ACCEPT, 2L)
  expect_setequal(names(simulomicsr:::.CA_DEFRAG_ACCEPT), c("tgfb", "il17"))
  expect_false("glioblastoma" %in% names(simulomicsr:::.CA_DEFRAG_ACCEPT))
})

test_that("glioblastoma NON si fonde piu', in nessuna forma", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  for (tk in c("glioblastoma", "Glioblastoma", "GLIOBLASTOMA")) {
    expect_true(is.na(.ca_defrag_entity(tk, "disease", oe)),
                info = tk)
  }
})

test_that("le due fusioni tenute continuano a funzionare su tutte le grafie del corpus", {
  oe <- .load_ontology_dicts()
  skip_if(isTRUE(oe$is_fixture), "dizionari fixture: test end-to-end saltato")
  for (tk in c("tgfb", "TGFb", "TGF-B", "tgf_b", "TGF-b"))
    expect_identical(.ca_defrag_entity(tk, "drug", oe), "HGNC:11766", info = tk)
  for (tk in c("il17", "IL-17", "il_17", "IL17"))
    expect_identical(.ca_defrag_entity(tk, "drug", oe), "HGNC:5981", info = tk)
})
