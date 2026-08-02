# Passo 5 del Task 5 (2026-08-02): misura l'effetto della dedup corretta sui
# dati veri di v13, PRIMA di committare. Il gate e' il conteggio: se non torna
# a 354 tenuti / 4 scartati, la chiave non e' quella giusta e ci si ferma.
#
# Confronto "prima" (chiave anchor-del-primo-membro) vs "dopo" (chiave
# contrast_entity||contrast_direction, gia' innestata in produzione da questa
# sessione) usando SEMPRE il gate vero di produzione
# `simulomicsr:::.identify_layer_a_clusters`, non una riscrittura locale.

devtools::load_all(".", quiet = TRUE)

stage3_dir <- "analysis/p4-output/20260728T151529Z-stage3-v13-364547a7"
cl <- readRDS(file.path(stage3_dir, "clusters.rds"))

cfg <- simulomicsr::stage4_default_config()
cfg$deliverable_methods <- "rem_group"

# --- "DOPO": codice di produzione attuale (fix gia' applicato in R/stage4-qc.R) ---
after <- simulomicsr:::.identify_layer_a_clusters(cl, cfg)

# --- "PRIMA": stessa selezione a monte del gate, ma con la vecchia chiave di
# dedup (anchor del primo membro). Replica LOCALE della sola funzione di dedup
# per il confronto "prima/dopo" (non e' il gate misurato: il gate misurato e'
# sempre `after`, prodotto dal codice vero). Per isolare l'effetto della SOLA
# dedup, ricostruiamo qui il pool "rem_group" pre-dedup allo stesso modo del
# codice di produzione e applichiamo le due chiavi.
rg_cfg     <- cfg$rem_group
excl_kinds <- rg_cfg$excluded_kinds %||% c("vehicle_only", "none", "")
min_k_raw  <- rg_cfg$k_eff_min %||% 3L
mega_strict_col <- simulomicsr:::.col_or_default(cl, "usable_mega_strict", FALSE)
kind_col        <- simulomicsr:::.col_or_default(cl, "kind_effective_resolved", NA_character_)
agent_col       <- simulomicsr:::.col_or_default(cl, "agent_id_resolved", NA_character_)

rem_group_pre_dedup <- cl[
  cl$mode == "cgroup" &
  !mega_strict_col &
  !(kind_col %in% excl_kinds) &
  !is.na(agent_col) &
  nzchar(agent_col, keepNA = FALSE) &
  cl$k >= min_k_raw,
]

.dedup_old_key <- function(rem_group_clusters) {
  # Copia della funzione ANTE-fix: chiave = kind||agent||direction (anchor
  # del primo membro), niente contrast_entity, niente attributo scartati.
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

before <- .dedup_old_key(rem_group_pre_dedup)

cat("=== Passo 5: effetto della dedup su v13 (rem_group / cgroup) ===\n\n")
cat("Pool cgroup pre-dedup (stesso gate a monte, entrambe le chiave):", nrow(rem_group_pre_dedup), "\n\n")

cat("--- PRIMA (chiave vecchia: kind||agent_id_resolved||direction) ---\n")
cat("Tenuti :", nrow(before), "\n")
cat("Scartati:", nrow(rem_group_pre_dedup) - nrow(before), "\n\n")

cat("--- DOPO (chiave nuova: contrast_entity||contrast_direction, codice di produzione) ---\n")
cat("Tenuti :", nrow(after), "\n")
scartati_dopo <- attr(
  simulomicsr:::.dedup_rem_group_by_entity(rem_group_pre_dedup),
  "scartati"
)
cat("Scartati:", nrow(scartati_dopo), "\n\n")

cat("Dettaglio scartati DOPO (i 4 duplicati veri attesi):\n")
print(scartati_dopo)

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
