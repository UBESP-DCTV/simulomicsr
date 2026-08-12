# PASSO 2, SOLA MISURA — versione ESATTA.
#
# ⚠️ LA PRIMA VERSIONE (P2-anchor-mancato.R) USAVA LO STRUMENTO SBAGLIATO, e si e'
# visto da un numero che non tornava: 173 cluster passavano la prova con il nome
# del modello pur non avendo `src == "anchor"`. Causa: in produzione
# (`R/stage3-contrast-anchor.R:701`) la prova gira su `d$treated_values`, cioe' i
# valori del DELTA trattato-controllo, non su tutti i `factor_levels` del braccio
# trattato. Il mio testo era un SOVRAINSIEME: piu' facile da far combaciare.
#
# Qui si ricostruiscono `treated_fl` e `control_fl` esattamente come fa
# `.build_contrast_group_records()` (R/stage3-build.R:575) e si chiama `.ca_delta`
# di produzione. Il caso di accettazione diventa stringente: la prova col nome del
# modello deve dare TRUE esattamente sui cluster con `src == "anchor"`.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-13-passo2"
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"

cl  <- readRDS(file.path(S3D, "clusters.rds")); cl <- cl[cl$mode == "cgroup", ]
asg <- arrow::read_parquet(file.path(S3D, "assignments.parquet"))
# La cache del master Stadio 2: si ricostruisce da solo al primo lancio.
s2_rds <- "analysis/audit/2026-08-12-corsie/s2.rds"
s2 <- if (file.exists(s2_rds)) readRDS(s2_rds) else {
  z <- jsonlite::stream_in(file("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"),
                           verbose = FALSE, simplifyVector = FALSE)
  saveRDS(z, s2_rds); z
}
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))

nome_vero <- function(id) {
  if (is.na(id) || !nzchar(id)) return(NA_character_)
  if (startsWith(id, "HGNC:")) {
    r <- simulomicsr:::.hgnc_lookup_hgnc(suppressWarnings(as.integer(sub("HGNC:", "", id))))
    return(if (is.null(r)) NA_character_ else r$symbol)
  }
  if (startsWith(id, "CHEBI:")) {
    r <- simulomicsr:::.chebi_lookup_id(sub("CHEBI:", "", id))
    return(if (is.null(r)) NA_character_ else r$primary_name)
  }
  if (startsWith(id, "MeSH:")) {
    r <- simulomicsr:::.mesh_lookup_ui(sub("MeSH:", "", id))
    return(if (is.null(r)) NA_character_ else r$mh)
  }
  NA_character_
}

s2_idx <- simulomicsr:::.index_stage2_master(s2)
asg_by <- split(asg$record_id, asg$cluster_id)
# identico a R/stage3-build.R:575
fl_of <- function(rg) {
  fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))),
        collapse = ";")
}
in_del <- cl$cluster_id %in% del$cluster_id

righe <- list()
for (i in seq_len(nrow(cl))) {
  rids <- asg_by[[cl$cluster_id[i]]]
  if (is.null(rids) || !length(rids)) next
  p <- simulomicsr:::.split_record_id(rids[1])
  if (is.na(p$series_id) || !exists(p$series_id, envir = s2_idx, inherits = FALSE)) next
  st <- get(p$series_id, envir = s2_idx, inherits = FALSE)
  cmp <- simulomicsr:::.lookup_cmp(st, p$suffix)
  if (is.null(cmp)) next
  tg <- simulomicsr:::.lookup_rg(st, cmp$treated_group)
  cg <- simulomicsr:::.lookup_rg(st, cmp$control_group)
  if (is.null(tg) || is.null(cg)) next
  d <- simulomicsr:::.ca_delta(fl_of(tg), fl_of(cg))
  if (is.na(d$dominant_class)) next
  testo <- paste(d$treated_values, collapse = " ")

  nm_llm <- cl$canonical_name[i]; id <- cl$agent_id_resolved[i]
  nm_ok  <- nome_vero(id)
  prova <- function(nm) !is.na(nm) && nzchar(nm) && !is.na(id) &&
    simulomicsr:::.cg_matches_all_words(simulomicsr:::.cg_distinctive_tokens(nm), testo)
  righe[[length(righe) + 1L]] <- data.frame(
    cluster_id = cl$cluster_id[i], agent_id = id %||% NA_character_,
    nome_llm = nm_llm %||% NA_character_, nome_vero = nm_ok,
    src = cl$contrast_entity_source[i], entity = cl$contrast_entity[i],
    scatta_llm = prova(nm_llm), scatterebbe_vero = prova(nm_ok),
    nel_deliverable = in_del[i], stringsAsFactors = FALSE)
}
D <- do.call(rbind, righe)
cat("cluster misurati:", nrow(D), "su", nrow(cl), "\n\n")

cat("=== ACCETTAZIONE STRINGENTE: la prova riproduce il ramo di produzione? ===\n")
a <- sum(D$scatta_llm & D$src == "anchor")
b <- sum(D$scatta_llm & D$src != "anchor")
c_ <- sum(!D$scatta_llm & D$src == "anchor")
cat("  TRUE e src=='anchor':", a, "| TRUE e src diverso:", b,
    "| FALSE e src=='anchor':", c_, "\n")
cat("  accordo:", sprintf("%.2f%%\n", 100 * mean(D$scatta_llm == (D$src == "anchor"))))
if (b > 0L) {
  cat("  i disaccordi (TRUE ma non anchor), primi 8 -- il ramo anchor chiede ANCHE\n")
  cat("  che l'ID non sia NA e che il nome non sia vuoto:\n")
  z <- D[D$scatta_llm & D$src != "anchor", ]
  for (i in seq_len(min(8, nrow(z))))
    cat(sprintf("     %-14s %-24s src=%-6s entity=%s\n", z$agent_id[i],
        substr(z$nome_llm[i], 1, 24), z$src[i], substr(z$entity[i], 1, 26)))
}

cat("\n=== IL COSTO DEL NOME SBAGLIATO ===\n")
k <- !D$scatta_llm & D$scatterebbe_vero
cat("cluster in cui il ramo anchor NON scatta ma scatterebbe col nome vero:", sum(k),
    sprintf("(%.2f%% di %d)\n", 100 * mean(k), nrow(D)))
cat("  nel deliverable:", sum(k & D$nel_deliverable), "\n")
if (sum(k)) print(table(D$src[k]))
cat("\ncaso OPPOSTO (scatta col nome del modello, NON col nome vero):",
    sum(D$scatta_llm & !D$scatterebbe_vero), "| nel deliverable:",
    sum(D$scatta_llm & !D$scatterebbe_vero & D$nel_deliverable), "\n")
cat("esito identico con i due nomi:", sum(D$scatta_llm == D$scatterebbe_vero),
    sprintf("(%.1f%%)\n", 100 * mean(D$scatta_llm == D$scatterebbe_vero)))

cat("\n=== I CASI DEL COSTO (tutti) ===\n")
E <- D[k, ]
if (nrow(E)) for (i in seq_len(nrow(E)))
  cat(sprintf("  %-14s modello %-30s vero %-26s -> usata %s (%s)%s\n",
      E$agent_id[i], substr(E$nome_llm[i], 1, 30), substr(E$nome_vero[i], 1, 26),
      substr(E$entity[i], 1, 24), E$src[i],
      if (E$nel_deliverable[i]) "  [DELIVERABLE]" else ""))

saveRDS(D, file.path(SC, "P2b-anchor-mancato.rds"))
write.csv(D, file.path(SC, "P2b-anchor-mancato.csv"), row.names = FALSE)
cat("\nscritto.\n")
