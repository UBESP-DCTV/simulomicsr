# Censimento di coerenza del ramo MEGA (mai verificato).
#
# Le mega poolate in v10 sono 99: 39 senza nome (agent UNK), 28 con kind "none".
# Per loro l'anchor non dice che cosa ha ricevuto il braccio trattato — lo stesso
# meccanismo del minestrone, in un altro ramo, mai misurato.
#
# Qui si misura, con lo STESSO motore del delta usato dal builder, quante entita'
# DIVERSE misurano i bracci trattati di ogni mega.
#
# COPERTURA DICHIARATA: dei 2.362 membri, 928 sono bracci trattati e di questi
# 459 (49%) sono agganciati a un confronto dello Stadio 2. Per gli altri non
# esiste un contrasto ricostruibile (stesso fenomeno del limite L7). Ogni numero
# va letto con questa copertura accanto. Come misura a copertura piena si conta
# quante ETICHETTE di trattamento distinte convivono nel cluster: e' descrittiva,
# non decide nulla, ma non ha buchi.
Sys.setenv(OPENBLAS_NUM_THREADS = "1", OMP_NUM_THREADS = "1")
suppressPackageStartupMessages({
  library(arrow); library(dplyr); devtools::load_all(".", quiet = TRUE)
})

S4  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032"
S3  <- "analysis/p4-output/20260720T180625Z-stage3-v10-364547a7"
S2  <- "analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl"
OUT <- "analysis/audit/2026-07-27-contrast-builder"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0L) b else a

cat(format(Sys.time()), "- carico gli input...\n")
cp <- open_dataset(file.path(S4, "cluster_pooled.parquet")) |>
  select(cluster_id, method) |> distinct() |> collect()
mega_ids <- cp$cluster_id[cp$method == "mega"]
cl  <- readRDS(file.path(S3, "clusters.rds"))
asg <- read_parquet(file.path(S3, "assignments.parquet"))
by  <- split(asg$record_id, asg$cluster_id)
s2  <- .load_stage2_master(S2); s2i <- .index_stage2_master(s2)
oe  <- .load_ontology_dicts()
caches <- list(agent = new.env(parent = emptyenv()), token = new.env(parent = emptyenv()))
cat(format(Sys.time()), "- input pronti;", length(mega_ids), "mega poolate\n")

fl_of <- function(rg) {
  fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))), collapse = ";")
}
lab_of <- function(rg, gid) if (!is.null(rg$label_human) && nzchar(rg$label_human)) rg$label_human else gid

rows <- list()
for (cid in mega_ids) {
  ents <- character(0); labs <- character(0); drops <- character(0)
  n_t <- 0L; n_res <- 0L
  for (rid in by[[cid]]) {
    p <- .split_record_id(rid)
    if (is.na(p$series_id) || !exists(p$series_id, envir = s2i, inherits = FALSE)) next
    st <- get(p$series_id, envir = s2i, inherits = FALSE)
    rg <- .lookup_rg(st, p$suffix); if (is.null(rg)) next
    if (!identical(rg$primary_role %||% "", "treated")) next
    n_t <- n_t + 1L; labs <- c(labs, lab_of(rg, p$suffix))
    cmp <- .lookup_cmp_by_treated_group(st, p$suffix); if (is.null(cmp)) next
    cg <- .lookup_rg(st, cmp$control_group); if (is.null(cg)) next
    n_res <- n_res + 1L
    v <- .ca_member_contrast(lab_of(rg, p$suffix), lab_of(cg, cmp$control_group),
                             fl_of(rg), fl_of(cg),
                             ontology_env = oe, caches = caches)
    if (nzchar(v$drop_reason)) drops <- c(drops, v$drop_reason)
    else if (!is.na(v$entity)) ents <- c(ents, v$entity)
  }
  rows[[length(rows) + 1L]] <- data.frame(
    cluster_id = cid, n_treated = n_t, n_ricostruiti = n_res,
    n_entita_distinte = length(unique(ents)),
    entita = paste(sort(unique(ents)), collapse = " | "),
    n_label_distinte = length(unique(tolower(labs))),
    scarti = paste(sort(unique(drops)), collapse = ","),
    stringsAsFactors = FALSE)
}
cens <- bind_rows(rows) |>
  left_join(cl[, c("cluster_id", "k", "canonical_name", "kind_effective_resolved",
                   "agent_id_resolved")], by = "cluster_id")

cat("\n=== CENSIMENTO MEGA (99 poolate in v10) ===\n")
cat("copertura: bracci trattati", sum(cens$n_treated),
    "| con contrasto ricostruibile", sum(cens$n_ricostruiti),
    sprintf("(%.0f%%)\n", 100 * sum(cens$n_ricostruiti) / max(sum(cens$n_treated), 1)))
cat("\ncluster con almeno un braccio ricostruito:", sum(cens$n_ricostruiti > 0), "/", nrow(cens), "\n")
msr <- cens[cens$n_entita_distinte > 0, ]
cat("cluster con almeno un'entita' risolta:", nrow(msr), "\n")
cat("  UNA sola entita' del delta (coerenti, per quanto misurabile):",
    sum(msr$n_entita_distinte == 1), "\n")
cat("  DUE O PIU' entita' del delta (minestrone misurato):",
    sum(msr$n_entita_distinte >= 2), "\n")
cat("\ndistribuzione entita' distinte per cluster:\n")
print(table(pmin(cens$n_entita_distinte, 6)))
cat("\netichette di trattamento distinte per cluster (copertura piena, descrittiva):\n")
print(summary(cens$n_label_distinte))
cat("\n=== i 15 con piu' entita' diverse ===\n")
print(as.data.frame(cens |> arrange(desc(n_entita_distinte)) |> head(15) |>
        mutate(entita = substr(entita, 1, 70)) |>
        select(cluster_id, k, kind_effective_resolved, canonical_name,
               n_treated, n_ricostruiti, n_entita_distinte, entita)), row.names = FALSE)
cat("\n=== per kind ===\n")
print(cens |> group_by(kind_effective_resolved) |>
        summarise(n = n(), una_entita = sum(n_entita_distinte == 1),
                  due_o_piu = sum(n_entita_distinte >= 2),
                  non_misurabili = sum(n_entita_distinte == 0), .groups = "drop"))
write.csv(cens, file.path(OUT, "censimento-mega.csv"), row.names = FALSE)
cat("\n", format(Sys.time()), "- salvato censimento-mega.csv\n")
