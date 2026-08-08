#' Helper: legge colonna dal dataframe o restituisce un vettore di default
#'
#' Rende i rami di filtraggio robusti a fixture legacy che non contengono
#' le colonne introdotte in FASE F6 (kind_effective_resolved,
#' agent_id_resolved, usable_mega_strict). In produzione i cluster.rds emessi
#' da .summarize_clusters hanno sempre quelle colonne; nei test pre-F6 mancano.
#'
#' @param df data.frame o tibble
#' @param name nome colonna (character(1))
#' @param default valore scalare da replicare nrow(df) volte se la colonna
#'   e' assente
#' @return vettore di lunghezza nrow(df)
#' @keywords internal
.col_or_default <- function(df, name, default) {
  if (name %in% names(df)) df[[name]] else rep(default, nrow(df))
}

#' Dedup rem_group: una meta-analisi per entita' (kind, agent, verso) al k massimo
#'
#' Le stesse entita' nominate compaiono a piu' livelli L2/L3/L4. Si tiene un
#' solo cluster per entita' \code{(kind_effective_resolved, agent_id_resolved)}:
#' quello a \code{k} massimo (tie-break \code{n_total} desc, \code{level} desc,
#' \code{cluster_id} asc). Decisione utente 2026-07-05: massimizza potenza;
#' l'eterogeneita' di contesto residua e' catturata dall'I2/tau2 del REM.
#'
#' ADR-0025: per i cluster derivati dal contrasto la chiave include il
#' \code{contrast_direction}. Agonista e antagonista della stessa entita' sono
#' contrasti OPPOSTI e non vanno dedotti l'uno contro l'altro (decisione utente
#' 2026-07-25: la direzione opposta non si fonde). Quando la colonna non c'e'
#' (cluster legacy) il comportamento e' identico a prima.
#'
#' @keywords internal
.dedup_rem_group_by_entity <- function(rem_group_clusters,
                                       entity_canonical = NULL,
                                       control_canonical = NULL) {
  if (nrow(rem_group_clusters) == 0L) return(rem_group_clusters)
  direction <- .col_or_default(rem_group_clusters, "contrast_direction", NA_character_)
  direction[is.na(direction)] <- ""
  # ATTENZIONE 2026-08-02: per i cgroup l'identita' e' `contrast_entity`, NON
  # l'anchor. `agent_id_resolved` e `kind_effective_resolved` vengono dal
  # PRIMO MEMBRO (R/stage3-build.R:861-866) e per i cgroup l'invariante che
  # li giustifica e' falsa, perche' li' l'anchor_key nasce dal contrasto e
  # non dall'anchor: misurato, differiscono in 188 cluster su 358. La chiave
  # vecchia buttava 53 gruppi, 49 dei quali ORFANI (entita' che non ricompare
  # da nessuna parte), e tutte e 53 le coppie perdente/vincente avevano ZERO
  # record in comune -- tamoxifene ucciso da afimoxifene, testosterone dal suo
  # antagonista, due gruppi di tubercolosi da un gruppo che si chiama
  # tubercolosi ed e' COVID.
  #
  # Il `contrast_control_key` resta FUORI dalla chiave: con lui dentro la
  # chiave coinciderebbe con l'anchor_key, unica per costruzione, e la dedup
  # sarebbe un no-op che riapre la frammentazione per tipo di controllo
  # (l'intento di ADR-0022 e' proprio fondere hypoxia-vs-vehicle e
  # hypoxia-vs-normoxia al k maggiore).
  ce <- .col_or_default(rem_group_clusters, "contrast_entity", NA_character_)

  # ENTITA' CANONICA (2026-08-08). `entity_canonical` rimappa le SCRITTURE
  # diverse della stessa entita' sul loro codice canonico: il TNF arriva come
  # `HGNC:11892` (il gene) e come `CHEMBL:CHEMBL265582` (la proteina
  # ricombinante), sono la stessa cosa e nel deliverable occupano DUE righe.
  # Chi non e' nella mappa resta com'e': la mappa non e' un dizionario di
  # tutte le entita', solo delle equivalenze accertate.
  ce_can <- ce
  if (length(entity_canonical) > 0L) {
    hit <- !is.na(ce) & ce %in% names(entity_canonical)
    if (any(hit)) ce_can[hit] <- unname(entity_canonical[ce[hit]])
  }
  entity <- ifelse(
    !is.na(ce_can) & nzchar(ce_can),
    paste0(ce_can, "||", direction),
    paste0(rem_group_clusters$kind_effective_resolved, "||",
           rem_group_clusters$agent_id_resolved, "||", direction))
  ord <- order(entity,
               -rem_group_clusters$k,
               -rem_group_clusters$n_total,
               -rem_group_clusters$level,
               rem_group_clusters$cluster_id)
  rg  <- rem_group_clusters[ord, , drop = FALSE]
  ent <- entity[ord]
  ce_ord     <- ce[ord]         # scrittura GREZZA dell'entita'
  ce_can_ord <- ce_can[ord]     # entita' canonica
  ck_raw <- .col_or_default(rg, "contrast_control_key", NA_character_)
  ck_raw[is.na(ck_raw)] <- ""

  # CHIAVE DI CONTROLLO CANONICA (2026-08-08). Simmetrica a quella dell'entita'.
  # `.normalize_control_type()` (R/stage3-coherence.R) ha una lista di sinonimi
  # che diventano `vehicle_untreated` e una di controlli tenuti distinti. Due
  # tagli misurati sono DIMENTICANZE di quel vocabolario, non distinzioni:
  # `mock` sta fra i sinonimi ma `uninfected` non sta in nessuna delle due liste
  # (SARS-CoV-2 finiva in due cluster, 34 e 2 studi), e `normal`/`healthy`/
  # `control`/`normal_weight` ci sono ma `lean` no. Un terzo -- `normoxia` -- e'
  # distinto DI PROPOSITO, ma la misura mostra che il confine non tiene: il
  # cluster vincente dell'ipossia pool­a gia' controlli scritti `Untreated` e
  # `Control`, e lo scartato ne ha tre che nominano la normossia. Decisione
  # utente 2026-08-08: si ribalta. Evidenza: 33-materiale-dedup.txt (237
  # confronti con le etichette intere), 36-verdetti-4-fusioni-dedup.csv.
  #
  # Si applica QUI e non nello Stadio 3 perche' cambiare il vocabolario a monte
  # imporrebbe un re-cluster (~9 h) per un effetto che si ottiene senza.
  ck <- ck_raw
  if (length(control_canonical) > 0L) {
    hitc <- ck_raw %in% names(control_canonical)
    if (any(hitc)) ck[hitc] <- unname(control_canonical[ck_raw[hitc]])
  }

  # ---- PASSO 1: FUSIONE, non scarto -----------------------------------------
  # Stessa entita' canonica, stesso verso e stessa chiave di controllo CANONICA
  # sono la stessa cosa scritta in due modi: i record del perdente vanno poolati
  # COL vincente, non buttati. Canonicalizzare senza fondere peggiorerebbe le
  # cose -- il TNF diventerebbe una riga da 32 studi buttandone 6 -- quindi le
  # due cose vanno insieme.
  #
  # Condizione STRETTA, per non toccare nulla di quanto gia' validato: il gruppo
  # si fonde solo se contiene almeno DUE coppie distinte
  # (`contrast_entity` GREZZO, `contrast_control_key` GREZZA) e `contrast_entity`
  # e' popolato su tutti i membri. Con le due mappe assenti (il default) la
  # condizione NON PUO' accendersi: due coppie grezze distinte danno per
  # costruzione due chiavi distinte, perche' il `cluster_id` di un cgroup e'
  # l'hash di (entita' || verso || controllo). Il comportamento resta quindi
  # identico a prima, e le fixture legacy prive di `contrast_entity` cadono nel
  # ramo `anyNA` e non vengono nemmeno considerate.
  key1 <- paste0(ent, "||", ck)
  grezza <- paste0(ce_ord, "\r", ck_raw)
  assorbiti <- integer(0L)
  vincenti  <- integer(0L)
  for (g in split(seq_len(nrow(rg)), key1)) {
    if (length(g) < 2L) next
    scr <- ce_ord[g]
    if (anyNA(scr) || !all(nzchar(scr))) next
    if (length(unique(grezza[g])) < 2L) next
    # rg e' ordinato per forza decrescente entro la chiave: g[1] e' il vincente
    assorbiti <- c(assorbiti, g[-1L])
    vincenti  <- c(vincenti,  rep(g[1L], length(g) - 1L))
  }
  fusioni <- data.frame(cluster_id_assorbito = character(0),
                        cluster_id_vincente  = character(0),
                        chiave               = character(0),
                        k_vincente_prima     = integer(0),
                        k_dopo_fusione       = integer(0),
                        entity_vincente_prima      = character(0),
                        control_key_vincente_prima = character(0),
                        stringsAsFactors = FALSE)
  if (length(assorbiti) > 0L) {
    # IL k DEL VINCENTE DIVENTA QUELLO DELL'UNIONE. Il gate del deliverable
    # filtra su `k`; lasciandogli il k del solo vincente giudicherebbe un gruppo
    # che non esiste piu'. Si contano gli studi DISTINTI (misurato: per i cgroup
    # `k` e' esattamente il numero di studi distinti in `studies_in_cluster`,
    # verificato su tutti e 11.536), quindi uno studio presente in entrambe le
    # scritture non viene contato due volte.
    k_prima <- rg$k[vincenti]
    ha_studi <- "studies_in_cluster" %in% names(rg)
    if (ha_studi) {
      for (w in unique(vincenti)) {
        assorbiti_di_w <- assorbiti[vincenti == w]
        unione <- unique(unlist(rg$studies_in_cluster[c(w, assorbiti_di_w)],
                                use.names = FALSE))
        rg$studies_in_cluster[[w]] <- unione
        rg$k[w] <- length(unione)
      }
    }
    # IL VINCENTE PORTA LE CHIAVI CANONICHE. Il gruppo fuso pool­a entrambe le
    # scritture e entrambi i controlli: se restasse etichettato con la chiave del
    # solo vincente, la scheda del case study direbbe una cosa piu' stretta di
    # quella che il gruppo misura (per l'ipossia direbbe «contro normossia»
    # mentre pool­a anche i controlli non trattati). Le chiavi di partenza
    # restano scritte in `fusioni`, per l'audit.
    ent_prima <- rg$contrast_entity[vincenti]
    ck_prima  <- ck_raw[vincenti]
    if ("contrast_entity" %in% names(rg)) {
      rg$contrast_entity[unique(vincenti)] <- ce_can_ord[unique(vincenti)]
    }
    if ("contrast_control_key" %in% names(rg)) {
      rg$contrast_control_key[unique(vincenti)] <- ck[unique(vincenti)]
    }
    fusioni <- data.frame(cluster_id_assorbito = rg$cluster_id[assorbiti],
                          cluster_id_vincente  = rg$cluster_id[vincenti],
                          chiave               = key1[assorbiti],
                          k_vincente_prima     = as.integer(k_prima),
                          k_dopo_fusione       = as.integer(rg$k[vincenti]),
                          entity_vincente_prima      = ent_prima,
                          control_key_vincente_prima = ck_prima,
                          stringsAsFactors = FALSE)
    tieni1 <- rep(TRUE, nrow(rg)); tieni1[assorbiti] <- FALSE
    rg  <- rg[tieni1, , drop = FALSE]
    ent <- ent[tieni1]
  }

  # ---- PASSO 2: lo SCARTO di sempre -----------------------------------------
  # Stessa entita' e stesso verso ma chiave di controllo DIVERSA: si tiene il k
  # maggiore e gli altri si perdono. Fondere due CONTROLLI diversi e' un'altra
  # decisione (ipossia contro normossia non e' ipossia contro veicolo) e alla
  # data di questo codice non e' stata presa.
  keep <- !duplicated(ent)
  out <- rg[keep, , drop = FALSE]
  # Una selezione silenziosa non e' auditabile: chi viene tolto lo si scrive,
  # con il gruppo che l'ha assorbito.
  sc <- rg[!keep, , drop = FALSE]
  attr(out, "scartati") <- if (nrow(sc) == 0L) {
    data.frame(cluster_id = character(0), reason = character(0),
               details = character(0), stringsAsFactors = FALSE)
  } else {
    data.frame(
      cluster_id = sc$cluster_id,
      reason     = "dedup_entita_duplicata",
      details    = paste0("assorbito da ", out$cluster_id[match(ent[!keep], ent[keep])],
                          " (chiave ", ent[!keep], ")"),
      stringsAsFactors = FALSE)
  }
  attr(out, "fusioni") <- fusioni
  out
}

#' Identifica cluster Layer A (REM proper + MEGA strict + MEGA-aug)
#'
#' Layer A = i ~412 cluster publishable definiti nel finding scope decision
#' 2026-05-19. Aggiunge colonna \code{method} con il path da seguire.
#'
#' @param stage3_clusters tibble di \code{clusters.rds} Stage 3.
#' @param stage4_config output di \code{stage4_default_config}.
#' @return tibble con colonne originali + \code{method} (\code{rem} \code{mega}
#'   \code{mega_aug}).
#' @keywords internal
.identify_layer_a_clusters <- function(stage3_clusters, stage4_config) {
  # Colonne F6 opzionali: usable_mega_strict/kind_effective_resolved/agent_id_resolved
  # sono assenti nelle fixture legacy pre-F6. .col_or_default garantisce
  # retrocompatibilita' senza crash: colonna mancante -> valore scalare di default
  # replicato nrow(df) volte. In produzione (clusters.rds da .summarize_clusters)
  # le colonne sono sempre presenti e il comportamento e' identico all'accesso diretto.
  mega_strict_col <- .col_or_default(stage3_clusters, "usable_mega_strict", FALSE)
  kind_col        <- .col_or_default(stage3_clusters, "kind_effective_resolved", NA_character_)
  agent_col       <- .col_or_default(stage3_clusters, "agent_id_resolved",       NA_character_)

  rem <- stage3_clusters[
    stage3_clusters$usable_rem_strict &
    stage3_clusters$k >= 3L & stage3_clusters$k <= 9L &
    stage3_clusters$mode == "pair",
  ]
  if (nrow(rem) > 0L) rem$method <- "rem"

  # Usa mega_strict_col (via .col_or_default) per proteggere il filtro dalle
  # fixture legacy prive di usable_mega_strict.
  mega <- stage3_clusters[
    mega_strict_col &
    stage3_clusters$n_studies >= 5L &
    stage3_clusters$mode == "group",
  ]
  if (nrow(mega) > 0L) mega$method <- "mega"

  # MEGA-AUG: pair k=2 con baseline pool (vedi mega_aug_pair_with_baseline_pool
  # nello spec; v1 identifica come pair k==2 + usable_rem_relaxed + esiste un
  # group cluster con stesso control_anchor allo stesso L).
  # Implementazione semplificata: derivata dal cluster STAGE3 (s3 ha gia' i
  # candidate); per ora marca tutti i pair k=2 mode=pair usable_rem_relaxed
  # con method=mega_aug e flag baseline_pool_check da verificare a build time.
  mega_aug <- stage3_clusters[
    stage3_clusters$mode == "pair" &
    stage3_clusters$k == 2L &
    stage3_clusters$usable_rem_relaxed,
  ]
  if (nrow(mega_aug) > 0L) mega_aug$method <- "mega_aug"

  # rem_group (FASE F6 2026-07-05): group nominati L2-L4 (safety_min basso per
  # design) -> REM per-studio. Mutua esclusivita' col ramo mega garantita da
  # !usable_mega_strict (i L2-L4 non sono mai usable_mega_strict per il vincolo
  # di livello {0,1}; se un cluster soddisfa entrambi vince mega). Nessun gate
  # safety_min: il REM modella l'eterogeneita', non la filtra.
  # Con colonne assenti: usable_mega_strict=FALSE -> !FALSE=TRUE (escluso
  # dal gate mega ma non dal rem_group); kind/agent=NA -> !is.na(NA)=FALSE -> 0
  # righe rem_group (degradazione graceful, nessun crash).
  rg_cfg      <- stage4_config$rem_group
  excl_kinds  <- rg_cfg$excluded_kinds %||% c("vehicle_only", "none", "")
  min_k_raw   <- rg_cfg$k_eff_min %||% 3L
  # ADR-0025: il deliverable nasce dal CONTRASTO. Il ramo rem_group consuma i
  # cluster "cgroup" (un record per comparison, chiave = entita'-delta || verso
  # || tipo di controllo) e non piu' i "group", che restavano comparison-blind e
  # producevano l'85% di minestroni (finding 2026-07-23). Il vincolo
  # !usable_mega_strict e' ridondante per i cgroup (level 5) ma resta come difesa
  # e per non cambiare il comportamento su input legacy.
  # ⚠️ IL FILTRO SU `k` STA DOPO LA FUSIONE, NON PRIMA (2026-08-08). Prima era
  # dentro questa selezione, e il risultato era che le scritture PICCOLE della
  # stessa entita' cadevano al gate senza che la dedup le vedesse mai: misurato,
  # IL6 (una scrittura a k=10 e una a k=1) e IL15 (k=4 e k=2) non si fondevano
  # per questo. Filtrare i pezzi prima di ricomporli e' lo stesso errore della
  # frammentazione, in un'altra forma. Il gate ora giudica il gruppo FUSO, il cui
  # `k` e' il numero di studi distinti dell'unione.
  #
  # Con `entity_canonical` assente l'ordine e' indifferente e la selezione resta
  # la stessa: la dedup tiene il k massimo, e il massimo di un sovrainsieme che
  # contiene il massimo globale e' lo stesso. Verificato sui dati veri: 351
  # candidati, insieme dei cluster_id identico. Cambia solo `scartati`, che
  # diventa piu' completo (registra anche i cluster sotto soglia).
  rem_group <- stage3_clusters[
    stage3_clusters$mode == "cgroup" &
    !mega_strict_col &
    !(kind_col %in% excl_kinds) &
    !is.na(agent_col) &
    nzchar(agent_col, keepNA = FALSE),
  ]
  if (nrow(rem_group) > 0L) {
    rem_group$method <- "rem_group"
    rem_group <- .dedup_rem_group_by_entity(
      rem_group,
      entity_canonical  = rg_cfg$entity_canonical,
      control_canonical = rg_cfg$control_canonical)
    .fus <- attr(rem_group, "fusioni")
    .sca <- attr(rem_group, "scartati")
    rem_group <- rem_group[rem_group$k >= min_k_raw, , drop = FALSE]
    attr(rem_group, "fusioni")  <- .fus
    attr(rem_group, "scartati") <- .sca
  }

  # ADR-0026: il deliverable e' selezionato, non cablato. Di default resta il
  # solo ramo derivato dal contrasto; gli altri restano calcolati e raggiungibili
  # (config$deliverable_methods), cosi' la loro logica non muore silenziosamente.
  branches <- list(rem = rem, mega = mega, mega_aug = mega_aug,
                   rem_group = rem_group)
  keep <- stage4_config$deliverable_methods %||%
    c("rem", "mega", "mega_aug", "rem_group")
  branches <- branches[names(branches) %in% keep]
  # deliverable_methods senza nessun nome valido: risultato vuoto, non NULL
  # (un NULL a valle diventerebbe un errore lontano dalla causa).
  if (length(branches) == 0L) return(stage3_clusters[0L, , drop = FALSE])

  do.call(rbind, branches)
}

#' Filtra sample, studi e cluster per QC sample-level
#'
#' Applica filtro \code{lib_size_min} sui sample del metadata H5 e propaga i
#' drop a livello studio: per ogni (cluster, study) appartenente a Layer A,
#' conta i sample remaining post drop sample-level; se uno studio resta con
#' zero sample, viene registrato in \code{qc_drops_study}. La decisione finale
#' sul cluster (qc_drops_cluster) e' demandata all'orchestratore quando avra'
#' i counts veri.
#'
#' @param stage3_clusters tibble Stage 3 clusters.
#' @param h5_metadata tibble con (sample_id, gsm, gse, lib_size).
#' @param config stage4 config.
#' @return list con \code{eligible_clusters}, \code{qc_drops_sample},
#'   \code{qc_drops_study}, \code{qc_drops_cluster}.
#' @keywords internal
.qc_filter_samples_and_studies <- function(stage3_clusters, h5_metadata, config) {
  layer_a <- .identify_layer_a_clusters(stage3_clusters, config)

  # Sample drops: lib_size sotto soglia
  qc_drops_sample <- h5_metadata[h5_metadata$lib_size < config$qc$lib_size_min, ]
  qc_drops_sample$reason <- "lib_size_below_500k"

  # Studio per cluster: identificato dai studies_in_cluster
  # Per ogni (cluster_id, study_id), conta sample remaining post lib_size
  dropped_samples <- qc_drops_sample$sample_id
  remaining_meta <- h5_metadata[!(h5_metadata$sample_id %in% dropped_samples), ]

  # Pre-popola qc_drops_study iterando sui cluster Layer A: per ogni studio nel
  # cluster, se non resta alcun sample, segnalalo con reason="all_samples_dropped".
  drops_study_rows <- list()
  if (nrow(layer_a) > 0L) {
    for (i in seq_len(nrow(layer_a))) {
      cid <- layer_a$cluster_id[[i]]
      sids <- layer_a$studies_in_cluster[[i]]
      if (is.null(sids) || length(sids) == 0L) next
      for (sid in sids) {
        n_rem <- sum(remaining_meta$gse == sid)
        if (n_rem == 0L) {
          drops_study_rows[[length(drops_study_rows) + 1L]] <- tibble::tibble(
            cluster_id = cid,
            study_id = sid,
            n_treated_remaining = NA_integer_,
            n_control_remaining = NA_integer_,
            reason = "all_samples_dropped"
          )
        }
      }
    }
  }

  if (length(drops_study_rows) > 0L) {
    qc_drops_study <- do.call(rbind, drops_study_rows)
  } else {
    qc_drops_study <- tibble::tibble(
      cluster_id = character(),
      study_id = character(),
      n_treated_remaining = integer(),
      n_control_remaining = integer(),
      reason = character()
    )
  }

  # Cluster eligible post-QC: stessa tibble layer_a, eventualmente con
  # k_post_qc < k (logica future-prooming; v1 conserva i cluster originali +
  # passa i dropped per filtraggio downstream).
  eligible_clusters <- layer_a

  # qc_drops_cluster: cluster non-processable post QC. v1 empty perche'
  # la decisione finale e' presa in orchestratore con counts veri; flag
  # placeholder per output schema.
  qc_drops_cluster <- tibble::tibble(
    cluster_id = character(),
    original_k = integer(),
    qc_final_k = integer(),
    original_n_studies = integer(),
    qc_final_n_studies = integer(),
    reason = character()
  )

  list(
    eligible_clusters = eligible_clusters,
    qc_drops_sample   = qc_drops_sample,
    qc_drops_study    = qc_drops_study,
    qc_drops_cluster  = qc_drops_cluster
  )
}
