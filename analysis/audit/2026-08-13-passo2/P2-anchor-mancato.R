# PASSO 2, SOLA MISURA — quante volte il ramo `anchor` non scatta per colpa di un
# `canonical_name` sbagliato.
#
# LA CATENA, letta nel codice (R/stage3-contrast-anchor.R:700-702):
#   il ramo `anchor` adotta l'ID dell'anchor SOLO SE tutti i token distintivi del
#   suo NOME CANONICO compaiono nei valori del braccio trattato
#   (`.cg_matches_all_words`). Se il nome e' sbagliato — e lo e' su 111 righe su
#   214 del deliverable — i token non combaciano e il ramo NON scatta: l'identita'
#   ripiega sul testo (`onto`, `defrag`, `STR`).
#
# E' un errore di OMISSIONE: non sostituisce un'entita' con un'altra, ne perde
# una. Questa e' la misura che il PASSO 1 aveva lasciato aperta.
#
# COME SI MISURA, senza rifare il clustering: per ogni cluster `cgroup` si prende
# il NOME VERO dell'`agent_id_resolved` risolto dai dizionari e si rifa' la sola
# prova `.cg_matches_all_words` con quel nome al posto di `canonical_name`.
# Le righe in cui il nome sbagliato fallisce e quello giusto passerebbe sono il
# costo.
#
# LIMITE DICHIARATO IN PARTENZA: la prova gira sui valori del PRIMO membro del
# cluster (e' quello che `ct_chr()` porta al cluster). Sui cluster gia' formati
# questo e' esatto — l'entita' e' nella chiave, quindi identica per tutti i membri
# — ma NON dice quanti cluster non sono mai nati per questa via.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-13-passo2"
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"

cl  <- readRDS(file.path(S3D, "clusters.rds"))
cl  <- cl[cl$mode == "cgroup", ]
asg <- arrow::read_parquet(file.path(S3D, "assignments.parquet"))
# La cache del master Stadio 2: si ricostruisce da solo al primo lancio.
s2_rds <- "analysis/audit/2026-08-12-corsie/s2.rds"
s2 <- if (file.exists(s2_rds)) readRDS(s2_rds) else {
  z <- jsonlite::stream_in(file("analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"),
                           verbose = FALSE, simplifyVector = FALSE)
  saveRDS(z, s2_rds); z
}
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
cat("cluster cgroup:", nrow(cl), "| di cui nel deliverable:", sum(cl$cluster_id %in% del$cluster_id), "\n")

# --- il nome VERO dell'ID, dai dizionari --------------------------------------
env <- simulomicsr:::.load_ontology_dicts()
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

# --- i valori del braccio trattato del primo membro ---------------------------
s2_idx <- simulomicsr:::.index_stage2_master(s2)
asg_by <- split(asg$record_id, asg$cluster_id)
lab_of <- function(study, gid) {
  rg <- simulomicsr:::.lookup_rg(study, gid)
  if (is.null(rg)) return(character(0))
  c(as.character(unlist(rg$factor_levels)), as.character(rg$label_human %||% ""))
}

righe <- list()
for (i in seq_len(nrow(cl))) {
  cid <- cl$cluster_id[i]
  rids <- asg_by[[cid]]
  if (is.null(rids) || !length(rids)) next
  p <- simulomicsr:::.split_record_id(rids[1])
  if (is.na(p$series_id) || !exists(p$series_id, envir = s2_idx, inherits = FALSE)) next
  st <- get(p$series_id, envir = s2_idx, inherits = FALSE)
  cmp <- simulomicsr:::.lookup_cmp(st, p$suffix)
  if (is.null(cmp)) next
  tval <- paste(lab_of(st, cmp$treated_group), collapse = " ")
  nm_llm <- cl$canonical_name[i]
  id     <- cl$agent_id_resolved[i]
  nm_ok  <- nome_vero(id)
  ok_llm <- !is.na(nm_llm) && nzchar(nm_llm) && !is.na(id) &&
    simulomicsr:::.cg_matches_all_words(simulomicsr:::.cg_distinctive_tokens(nm_llm), tval)
  ok_vero <- !is.na(nm_ok) && nzchar(nm_ok) && !is.na(id) &&
    simulomicsr:::.cg_matches_all_words(simulomicsr:::.cg_distinctive_tokens(nm_ok), tval)
  righe[[length(righe) + 1L]] <- data.frame(
    cluster_id = cid, agent_id = id %||% NA_character_,
    nome_llm = nm_llm %||% NA_character_, nome_vero = nm_ok,
    src = cl$contrast_entity_source[i], entity = cl$contrast_entity[i],
    scatta_llm = ok_llm, scatterebbe_vero = ok_vero,
    nel_deliverable = cid %in% del$cluster_id, stringsAsFactors = FALSE)
  if (i %% 2000L == 0L) cat("  ", i, "/", nrow(cl), "\n")
}
D <- do.call(rbind, righe)
cat("cluster misurati:", nrow(D), "\n\n")

cat("=== ACCETTAZIONE: la prova rifatta riproduce il ramo scelto in produzione? ===\n")
cat("  scatta_llm == TRUE e src == 'anchor':", sum(D$scatta_llm & D$src == "anchor"), "\n")
cat("  scatta_llm == TRUE ma src diverso:   ", sum(D$scatta_llm & D$src != "anchor"), "\n")
cat("  src == 'anchor' ma scatta_llm FALSE: ", sum(!D$scatta_llm & D$src == "anchor"), "\n")

cat("\n=== IL COSTO DEL NOME SBAGLIATO ===\n")
k <- !D$scatta_llm & D$scatterebbe_vero
cat("cluster in cui il ramo anchor NON scatta ma scatterebbe col nome vero:", sum(k),
    sprintf("(%.2f%% di %d)\n", 100 * mean(k), nrow(D)))
cat("  di questi, nel deliverable:", sum(k & D$nel_deliverable), "\n")
cat("  per ramo effettivamente usato:\n"); print(table(D$src[k]))
cat("\ncluster in cui il nome del modello e quello vero COINCIDONO nell'esito:",
    sum(D$scatta_llm == D$scatterebbe_vero), sprintf("(%.1f%%)\n", 100 * mean(D$scatta_llm == D$scatterebbe_vero)))
cat("caso opposto (scatta col nome del modello, non col vero):",
    sum(D$scatta_llm & !D$scatterebbe_vero), "\n")

cat("\n=== ESEMPI (i primi 15) ===\n")
E <- D[k, ]
for (i in seq_len(min(15, nrow(E))))
  cat(sprintf("  %-14s nome del modello %-28s nome vero %-24s -> entita' usata %s (%s)%s\n",
      E$agent_id[i], substr(E$nome_llm[i], 1, 28), substr(E$nome_vero[i], 1, 24),
      substr(E$entity[i], 1, 22), E$src[i],
      if (E$nel_deliverable[i]) "  [DELIVERABLE]" else ""))

saveRDS(D, file.path(SC, "P2-anchor-mancato.rds"))
write.csv(D, file.path(SC, "P2-anchor-mancato.csv"), row.names = FALSE)
cat("\nscritto.\n")
