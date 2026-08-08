# analysis/audit/2026-08-08-deframmentazione/10-strumento-keff.R
# ---------------------------------------------------------------------------
# STRUMENTO CALIBRATO — k_eff di un insieme arbitrario di cluster Stadio 3.
#
# A COSA SERVE. Permette di misurare, SENZA re-pool, quanti studi con contrasto
# interno valido avrebbe un gruppo ottenuto FONDENDO piu' cluster dello Stadio 3.
# La logica NON e' riscritta: si costruiscono `assignments` sintetici (tutti i
# record_id dei cluster dell'insieme sotto un unico cluster_id fittizio) e si
# chiama il dispatch DI PRODUZIONE
# `simulomicsr:::.build_group_rem_dispatch_from_stage3()`. `k_eff` = numero di
# `study_id` DISTINTI con un contrasto risolto (>= n_min campioni per braccio).
#
# CALIBRAZIONE (misurata, non asserita — vedi 00-funnel-e-calibrazione.R):
#   * i 351 candidati del gate rem_group v15 sono riprodotti esattamente;
#   * su tutti e 214 i gruppi del deliverable lo scarto
#     `k_eff_strumento - k_effective` e' 0 (214/214);
#   * i 137 non_processable tornano al k_eff dichiarato nel loro `reason`
#     (0 -> 13, 1 -> 42, 2 -> 82), 137/137;
#   * i tre controlli nominati: TGFB1 59, LPS 35, SARS-CoV-2 34.
#
# LIMITI DICHIARATI (dove lo strumento e' cieco):
#   * NON applica il pre-filtro H5 del re-pool vero (campioni assenti dall'H5,
#     lib_size < 500k). Il k_eff e' quindi un LIMITE SUPERIORE. Misurato su
#     v15: scarto ZERO su tutti e 214, cioe' il limite superiore e' STRETTO su
#     questo corpus -- ma resta un limite superiore per costruzione.
#   * NON dice nulla sulla COERENZA di contrasto del gruppo fuso: conta studi,
#     non giudica se misurano la stessa cosa.
#   * NON rifa' la deduplica per entita': l'insieme lo decide il chiamante.
#
# USO:
#   source("analysis/audit/2026-08-08-deframmentazione/10-strumento-keff.R")
#   ctx <- carica_contesto_keff()                       # ~1-2 min (master Stadio 2)
#   keff_di_gruppi(list(tgfb1 = "cgroup_L5_2e16719f",
#                       fusione = c("cgroup_L5_871ae09e", "cgroup_L5_89b5ca86")),
#                  ctx)
#
# Read-only: non scrive nulla e non dipende da variabili globali non passate.
# ---------------------------------------------------------------------------

.KEFF_STAGE3_DEFAULT <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
.KEFF_STAGE2_DEFAULT <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"

#' Carica una volta il contesto necessario a `keff_di_gruppi()`
#'
#' @param stage3_dir directory di output dello Stadio 3 (contiene
#'   `assignments.parquet`). Default: v15.
#' @param stage2_path percorso del master Stadio 2 JSONL. Default: master v3.
#' @param assignments opzionale: data.frame `assignments.parquet` gia' in
#'   memoria (evita di rileggerlo). Deve avere `record_id` e `cluster_id`.
#' @param stage2_master opzionale: lista di study record gia' caricata.
#' @return lista con `asg_by_clid` (record_id per cluster_id) e `stage2_master`.
#'   Da passare a `keff_di_gruppi()`.
carica_contesto_keff <- function(stage3_dir  = .KEFF_STAGE3_DEFAULT,
                                 stage2_path = .KEFF_STAGE2_DEFAULT,
                                 assignments = NULL,
                                 stage2_master = NULL) {
  if (!requireNamespace("simulomicsr", quietly = TRUE)) {
    stop("il pacchetto simulomicsr deve essere caricato (devtools::load_all('.'))")
  }
  if (is.null(assignments)) {
    p <- file.path(stage3_dir, "assignments.parquet")
    if (!file.exists(p)) stop("assignments.parquet non trovato: ", p)
    assignments <- arrow::read_parquet(p)
  }
  if (!all(c("record_id", "cluster_id") %in% names(assignments))) {
    stop("`assignments` deve avere le colonne record_id e cluster_id")
  }
  if (is.null(stage2_master)) {
    if (!file.exists(stage2_path)) stop("master Stadio 2 non trovato: ", stage2_path)
    stage2_master <- simulomicsr:::.load_stage2_master(stage2_path)
  }
  list(asg_by_clid   = split(assignments$record_id, assignments$cluster_id),
       stage2_master = stage2_master,
       n_assignments = nrow(assignments),
       n_studi_stage2 = length(stage2_master))
}

#' k_eff di uno o piu' insiemi di cluster Stadio 3
#'
#' @param lista_di_insiemi lista; ogni elemento e' un vettore di `cluster_id`
#'   dello Stadio 3 da trattare come UN SOLO gruppo. I nomi della lista, se
#'   presenti, finiscono nella colonna `gruppo`. Un vettore character semplice
#'   viene interpretato come un unico insieme.
#' @param ctx output di `carica_contesto_keff()`.
#' @param n_min campioni minimi per braccio (default 2L, come il re-pool).
#' @param modo `"cgroup"` (default) oppure `"group"`: sceglie come il dispatch
#'   risolve il `record_id` (per i cgroup il record_id E' la comparison).
#' @return data.frame con una riga per insieme: `gruppo`, `n_cluster`,
#'   `n_record`, `k_eff`, `passa_gate` (k_eff >= 3), `studi` (id separati da
#'   `;`), `cluster_id_mancanti` (cluster senza assignments, dichiarati).
keff_di_gruppi <- function(lista_di_insiemi, ctx, n_min = 2L, modo = "cgroup") {
  if (is.character(lista_di_insiemi)) lista_di_insiemi <- list(lista_di_insiemi)
  if (!is.list(lista_di_insiemi) || length(lista_di_insiemi) == 0L) {
    stop("`lista_di_insiemi` deve essere una lista non vuota di vettori di cluster_id")
  }
  modo <- match.arg(modo, c("cgroup", "group"))
  nomi <- names(lista_di_insiemi)
  if (is.null(nomi)) nomi <- rep("", length(lista_di_insiemi))
  nomi[!nzchar(nomi)] <- sprintf("insieme_%03d", which(!nzchar(nomi)))

  # etichette interne stabili: il chiamante non deve preoccuparsi di collisioni
  # fra i suoi nomi e i cluster_id veri.
  fittizi <- sprintf("__KEFF__%05d", seq_along(lista_di_insiemi))

  rows <- list(); mancanti <- vector("list", length(lista_di_insiemi))
  for (i in seq_along(lista_di_insiemi)) {
    cids <- unique(as.character(lista_di_insiemi[[i]]))
    presenti <- cids[cids %in% names(ctx$asg_by_clid)]
    mancanti[[i]] <- setdiff(cids, presenti)
    rid <- unlist(ctx$asg_by_clid[presenti], use.names = FALSE)
    if (length(rid)) {
      rows[[length(rows) + 1L]] <- data.frame(
        record_id = rid, cluster_id = fittizi[i], stringsAsFactors = FALSE)
    }
  }
  synth <- if (length(rows)) do.call(rbind, rows) else
    data.frame(record_id = character(0), cluster_id = character(0),
               stringsAsFactors = FALSE)

  disp <- list()
  if (nrow(synth)) {
    eligible <- data.frame(cluster_id = unique(synth$cluster_id), mode = modo,
                           method = "rem_group", stringsAsFactors = FALSE)
    disp <- simulomicsr:::.build_group_rem_dispatch_from_stage3(
      eligible, synth, ctx$stage2_master, n_min = n_min)
  }

  out <- do.call(rbind, lapply(seq_along(lista_di_insiemi), function(i) {
    d <- disp[[fittizi[i]]]
    studi <- if (is.null(d)) character(0) else
      unique(vapply(d, function(x) x$study_id, character(1)))
    data.frame(
      gruppo    = nomi[i],
      n_cluster = length(unique(as.character(lista_di_insiemi[[i]]))),
      n_record  = sum(synth$cluster_id == fittizi[i]),
      k_eff     = length(studi),
      passa_gate = length(studi) >= 3L,
      studi     = paste(sort(studi), collapse = ";"),
      cluster_id_mancanti = paste(mancanti[[i]], collapse = ";"),
      stringsAsFactors = FALSE)
  }))
  rownames(out) <- NULL
  out
}

# --- autoverifica: eseguibile direttamente ---------------------------------
# Rscript analysis/audit/2026-08-08-deframmentazione/10-strumento-keff.R
if (sys.nframe() == 0L) {
  suppressMessages({devtools::load_all(".", quiet = TRUE); library(arrow)})
  cat("== autoverifica 10-strumento-keff.R ==\n")
  ctx <- carica_contesto_keff()
  cat(sprintf("contesto: %d assignments, %d studi Stadio 2\n",
              ctx$n_assignments, ctx$n_studi_stage2))
  casi <- list(TGFB1 = "cgroup_L5_2e16719f",
               LPS   = "cgroup_L5_c548d053",
               `SARS-CoV-2` = "cgroup_L5_871ae09e")
  res <- keff_di_gruppi(casi, ctx)
  res$atteso <- c(59L, 35L, 34L)
  res$ok <- res$k_eff == res$atteso
  print(res[, c("gruppo", "n_cluster", "n_record", "k_eff", "atteso", "ok",
                "passa_gate")], row.names = FALSE)
  cat(sprintf("\n3 casi noti: %d/%d combaciano\n", sum(res$ok), nrow(res)))
  # caso di fusione: SARS vincente + SARS scartato dalla dedup
  fus <- keff_di_gruppi(
    list(`SARS solo` = "cgroup_L5_871ae09e",
         `SARS + scartato dedup` = c("cgroup_L5_871ae09e", "cgroup_L5_89b5ca86")), ctx)
  print(fus[, c("gruppo", "n_cluster", "n_record", "k_eff", "passa_gate")],
        row.names = FALSE)
  # caso limite: cluster inesistente -> dichiarato, non silenzioso
  lim <- keff_di_gruppi(list(inesistente = "cgroup_L5_NONESISTE"), ctx)
  print(lim, row.names = FALSE)
  if (!all(res$ok)) stop("AUTOVERIFICA FALLITA: k_eff non combacia")
  cat("== autoverifica OK ==\n")
}
