# §3.4 e §3.5 — il funnel dello Stadio 4 e le guardie che devono restare accese.
suppressMessages(devtools::load_all(".", quiet = TRUE))
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
cl  <- readRDS(file.path(S3D, "clusters.rds"))
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
np  <- readRDS(file.path(DEL, "non_processable.rds"))
cfg <- stage4_default_config()

cat("=== FUNNEL ===\n")
cat("cluster totali Stadio 3:", nrow(cl), "| mode=cgroup:", sum(cl$mode == "cgroup"), "\n")
rg <- cl[cl$mode == "cgroup" &
         !.col_or_default(cl, "usable_mega_strict", FALSE) &
         !(.col_or_default(cl, "kind_effective_resolved", NA_character_) %in%
           (cfg$rem_group$excluded_kinds %||% c("vehicle_only", "none", ""))) &
         !is.na(.col_or_default(cl, "agent_id_resolved", NA_character_)) &
         nzchar(.col_or_default(cl, "agent_id_resolved", ""), keepNA = FALSE), ]
cat("dopo il filtro di ammissibilita':", nrow(rg), "\n")
A <- .identify_layer_a_clusters(cl, cfg); A <- A[A$method == "rem_group", ]
cat("dopo dedup/fusione e k>=3:", nrow(A), "(v15: 351)\n")
cat("deliverable v15:", nrow(del), "| non_processable:", nrow(np),
    "| somma:", nrow(del) + nrow(np), "\n")
orf <- setdiff(c(del$cluster_id, np$cluster_id), A$cluster_id)
cat("cluster del v15 che oggi NON sono fra i candidati:", length(orf),
    if (length(orf)) paste(orf, collapse = " ") else "", "\n")
cat("  (atteso: 1 = il TNF assorbito dalla fusione)\n")
cat("motivi dei non_processable:\n"); print(head(sort(table(sub(":.*", "", np$reason)), decreasing = TRUE), 5))

cat("\n=== GUARDIE ===\n")
src_o <- readLines("R/stage4-orchestrator.R"); src_a <- readLines("R/stage4-coherence-annotation.R")
cat("conflitto di ruolo invocato in orchestrator:",
    any(grepl("\\.drop_role_conflicts\\(", src_o)), "\n")
cat("collasso corsie invocato in orchestrator:",
    any(grepl("\\.collapse_technical_lanes\\(", src_o)), "\n")
cat("verdetti orfani: guardia presente:",
    any(grepl("orfan|orphan", src_a, ignore.case = TRUE)), "\n")
ann <- grep("annotate_stage4_deliverable", readLines("analysis/p4-fase-f5-stage4-layer-a-rebuild-v15.R"), value = TRUE)
cat("annotazione chiamata dallo script di re-pool:", length(ann) > 0L, "\n")
cat("registro dispatch_drops collegato a qc_report:",
    any(grepl("dispatch_drops", readLines("R/stage4-build.R"))), "\n")
cat("\n=== CACHE ===\n")
cat("NAME_RECOVERY_LOOKUP_SCHEMA_VERSION:",
    simulomicsr:::.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION, "\n")
