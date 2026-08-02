# Passo 5 del Task 5 (2026-08-02): misura l'effetto della dedup corretta sui
# dati veri di v13, PRIMA di committare. Il gate e' il conteggio: se non torna
# a 354 tenuti / 4 scartati, la chiave non e' quella giusta e ci si ferma.
#
# Confronto "prima" (chiave anchor-del-primo-membro) vs "dopo" (chiave
# contrast_entity||contrast_direction, gia' innestata in produzione da questa
# sessione). ENTRAMBI i regimi passano dal gate vero di produzione
# `simulomicsr:::.identify_layer_a_clusters` -- niente riscrittura locale del
# filtro di selezione. Per ottenere il regime "prima" si sostituisce SOLO
# `.dedup_rem_group_by_entity` (via testthat::with_mocked_bindings, mock nel
# namespace del pacchetto) con una copia della funzione ANTE-fix; il gate, i
# filtri a monte e ogni altra condizione restano il codice vero, identico in
# entrambe le chiamate. La sola differenza tra "prima" e "dopo" e' la chiave
# di dedup -- esattamente cio' che si sta misurando. (Round 1 di revisione:
# la versione precedente di questo script riscriveva a mano il filtro di
# selezione per isolare il "prima" -- lo stesso numero, ma misurato con uno
# strumento che non era quello vero. Corretto qui.)

devtools::load_all(".", quiet = TRUE)

stage3_dir <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
cl <- readRDS(file.path(stage3_dir, "clusters.rds"))

cfg <- simulomicsr::stage4_default_config()
cfg$deliverable_methods <- "rem_group"

# --- "DOPO": codice di produzione attuale, senza alcun mock (fix gia'
# innestato in R/stage4-qc.R). ---
after <- simulomicsr:::.identify_layer_a_clusters(cl, cfg)

# --- "PRIMA": stesso gate di produzione, con la SOLA .dedup_rem_group_by_entity
# sostituita dalla copia ante-fix (chiave = kind||agent_id_resolved||direction,
# l'anchor del primo membro, niente contrast_entity, niente attributo scartati).
.dedup_old_key <- function(rem_group_clusters) {
  if (nrow(rem_group_clusters) == 0L) return(rem_group_clusters)
  direction <- simulomicsr:::.col_or_default(rem_group_clusters, "contrast_direction", NA_character_)
  direction[is.na(direction)] <- ""
  entity <- paste0(rem_group_clusters$kind_effective_resolved, "||",
                   rem_group_clusters$agent_id_resolved, "||", direction)
  ord <- order(entity,
               -rem_group_clusters$k,
               -rem_group_clusters$n_total,
               -rem_group_clusters$level,
               rem_group_clusters$cluster_id)
  rg  <- rem_group_clusters[ord, , drop = FALSE]
  ent <- entity[ord]
  rg[!duplicated(ent), , drop = FALSE]
}

before <- testthat::with_mocked_bindings(
  .dedup_rem_group_by_entity = .dedup_old_key,
  .package = "simulomicsr",
  simulomicsr:::.identify_layer_a_clusters(cl, cfg)
)

# --- Pool "cgroup" pre-dedup (per il denominatore "scartati"): stesso gate
# vero, dedup mockata a funzione IDENTITA' (nessun collasso) cosi' il conteggio
# viene anch'esso dal filtro di selezione di produzione, non da un ricalcolo
# locale. ---
pre_dedup <- testthat::with_mocked_bindings(
  .dedup_rem_group_by_entity = function(rem_group_clusters) rem_group_clusters,
  .package = "simulomicsr",
  simulomicsr:::.identify_layer_a_clusters(cl, cfg)
)
n_pre_dedup <- nrow(pre_dedup)

cat("=== Passo 5: effetto della dedup su v13 (rem_group / cgroup) ===\n")
cat("Entrambi i regimi passano da simulomicsr:::.identify_layer_a_clusters();\n")
cat("l'unica differenza e' la funzione di dedup mockata (testthat::with_mocked_bindings).\n\n")

cat("Pool cgroup pre-dedup (gate vero, dedup mockata a identita'):", n_pre_dedup, "\n\n")

cat("--- PRIMA (chiave vecchia: kind||agent_id_resolved||direction, gate vero + dedup mockata) ---\n")
cat("Tenuti :", nrow(before), "\n")
cat("Scartati:", n_pre_dedup - nrow(before), "\n\n")

cat("--- DOPO (chiave nuova: contrast_entity||contrast_direction, codice di produzione, nessun mock) ---\n")
cat("Tenuti :", nrow(after), "\n")
scartati_dopo <- attr(after, "scartati")
if (is.null(scartati_dopo)) {
  # do.call(rbind, ...) su piu' branch in .identify_layer_a_clusters puo'
  # far cadere gli attributi custom; se successo, ricalcola l'attributo
  # richiamando la dedup vera sullo stesso pool rem_group gia' filtrato da
  # .identify_layer_a_clusters (nessuna riscrittura del filtro: e' lo stesso
  # identify_layer_a_clusters, isolato solo per recuperare l'attributo perso
  # nel rbind).
  rem_group_after <- after[after$method == "rem_group", , drop = FALSE]
  scartati_dopo <- attr(simulomicsr:::.dedup_rem_group_by_entity(rem_group_after), "scartati")
}
cat("Scartati:", if (is.null(scartati_dopo)) NA else nrow(scartati_dopo), "\n\n")

cat("Dettaglio scartati DOPO (i 4 duplicati veri attesi):\n")
print(scartati_dopo)

cat("\n--- Verifica di fedelta' del regime PRIMA ---\n")
cat("Atteso dal round 1 di revisione (misurato in precedenza con una riscrittura locale del filtro,\n")
cat("da ri-confermare qui col gate vero): 305 tenuti / 53 scartati.\n")
cat("Ottenuto col gate vero (nessuna riscrittura) + dedup mockata:", nrow(before), "tenuti /",
    n_pre_dedup - nrow(before), "scartati.\n")

# --- Entita' che PRIMA venivano buttate e DOPO rientrano ---
before_entities <- unique(before$contrast_entity)
after_entities  <- unique(after$contrast_entity)
rientrate <- setdiff(after_entities, before_entities)
cat("\nEntita' (contrast_entity) presenti DOPO ma non PRIMA:", length(rientrate), "\n")

check_ids <- c("CHEBI:41774", "CHEBI:17347", "NCBITaxon:1773")
cat("\nControllo puntuale attese dal protocollo:\n")
for (id in check_ids) {
  cat(sprintf("  %-16s rientrata: %s\n", id, id %in% rientrate))
}

cat("\nElenco completo delle entita' rientrate:\n")
print(sort(rientrate))
