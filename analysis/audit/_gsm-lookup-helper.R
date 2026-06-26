# Helper condiviso audit: mappa record_id -> GSM membri (lato treated/case).
#
# Questo file espone build_record_gsm_lookup(), usato da:
#   - stage3-homogeneity-check.R  (gate di omogeneita')
#   - name-recovery-llm-benchmark.R  (benchmark LLM recupero-nome)
#
# Mantieni aggiornato questo helper se la struttura del master Stadio 2
# cambia (es. integrazione member_sample_ids pianificata): i due script
# audit erediteranno automaticamente la logica corretta.
#
# MAPPA COSTRUITA (schema stage2.v2):
#   record GROUP  : chiave  = sprintf("%s__%s", series_id, group_id)
#                   valore  = sample_ids del replicate_group
#                   (braccio caratterizzante per design group: case per
#                    disease_vs_normal, treated per i perturbativi)
#
#   record PAIR   : chiave  = sprintf("%s__%s", series_id, comparison_id)
#                   valore  = sample_ids del treated_group della comparison
#                   (il braccio caratterizzante e' il treated_group; il
#                    control_group viene deliberatamente ignorato per non
#                    contaminare il conteggio delle identita' del cluster)
#
# I record sintetici *__completeness_uncovered (REGOLA 4 guard,
# R/stage2-normalize.R) NON sono nel master su disco: sono aggiunti in
# memoria da stage3-build con primary_role='unclear' e sono inerti al
# pooling treated/control. Il chiamante ricevera' NULL da get0() e
# deve saltare quei record (il guard null-safe e' gia' nei chiamanti).
#
# UTILIZZO:
#   source("analysis/audit/_gsm-lookup-helper.R")
#   rec_env <- build_record_gsm_lookup(stage2_master_path)
#   gsms <- get0("GSE123456__comparison_1", envir = rec_env)  # NULL se assente
#
build_record_gsm_lookup <- function(stage2_master_path) {
  cat("[4b] Costruzione mappa record_id -> GSM membri dal master Stadio 2...\n")
  t_map <- system.time({
    master_lines <- readLines(stage2_master_path, warn = FALSE)
    rec_env <- new.env(parent = emptyenv())
    for (ln in master_lines) {
      st  <- jsonlite::fromJSON(ln, simplifyVector = FALSE)
      sid <- st$series_id
      if (is.null(sid) || !nzchar(sid)) next
      # Lookup group_id -> sample_ids per questa serie (serve sia ai record GROUP
      # sia ai record PAIR per risalire al treated_group).
      rg_lookup <- list()
      for (rg in st$replicate_groups) {
        gid  <- rg$group_id
        sids <- as.character(unlist(rg$sample_ids, use.names = FALSE))
        rg_lookup[[gid]] <- sids
        assign(paste0(sid, "__", gid), sids, envir = rec_env)  # record GROUP
      }
      # record PAIR: il braccio caratterizzante e' il treated_group.
      if (length(st$comparisons)) {
        for (cmp in st$comparisons) {
          tg <- rg_lookup[[cmp$treated_group]]
          if (is.null(tg)) next  # comparison malformata: skip (come stage3-build)
          assign(paste0(sid, "__", cmp$comparison_id), tg, envir = rec_env)
        }
      }
    }
  })
  cat("  Mappa pronta:", length(ls(rec_env)), "record_id in", round(t_map[3], 1), "sec\n")
  rec_env
}
