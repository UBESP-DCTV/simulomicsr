# VERIFICA DELL'OUTPUT v16, contro le previsioni depositate PRIMA del run.
suppressMessages(devtools::load_all(".", quiet = TRUE))
V16 <- "analysis/p4-output/20260814T025911Z-stage3-v16-7f986159"
V15 <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
SC  <- "analysis/audit/2026-08-13-rerun-prep"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"

c16 <- readRDS(file.path(V16, "clusters.rds")); c15 <- readRDS(file.path(V15, "clusters.rds"))
n16 <- readRDS(file.path(V16, "non_clusterable.rds")); n15 <- readRDS(file.path(V15, "non_clusterable.rds"))
a16 <- arrow::read_parquet(file.path(V16, "assignments.parquet"))
a15 <- arrow::read_parquet(file.path(V15, "assignments.parquet"))
del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))

cat("=== 1. GLI SCARTI DEL GATE DI RIGA ===\n")
g <- function(n) { z <- n[n$reason == "contrast_gate", ]
  c(tot = nrow(n), gen = sum(z$details == "riga_genetica_asimmetrica", na.rm = TRUE)) }
cat("  v15:", g(n15), "\n  v16:", g(n16), "| delta genetica:", g(n16)["gen"] - g(n15)["gen"], "\n")
cat("  membri cgroup assegnati: v15", sum(startsWith(a15$cluster_id, "cgroup")),
    "| v16", sum(startsWith(a16$cluster_id, "cgroup")), "\n")

cat("\n=== 2. I 5 CONFRONTI PREVISTI SONO SPARITI? ===\n")
P <- read.csv(file.path(SC, "P5-d2-scartati.csv"), stringsAsFactors = FALSE)
cat("  previsti:", nrow(P), "in", length(unique(P$cluster_id)), "gruppi\n")
for (i in seq_len(nrow(P))) {
  in15 <- P$record_id[i] %in% a15$record_id; in16 <- P$record_id[i] %in% a16$record_id
  d16 <- n16$details[n16$record_id == P$record_id[i]]
  cat(sprintf("  %-46s v15=%s v16=%s | v16 motivo: %s\n", substr(P$record_id[i], 1, 46),
              in15, in16, if (length(d16)) d16[1] else "-"))
}

cat("\n=== 3. I k DEI GRUPPI DEL DELIVERABLE ===\n")
com <- intersect(c15$cluster_id[c15$mode == "cgroup"], c16$cluster_id[c16$mode == "cgroup"])
k15 <- setNames(c15$k[match(com, c15$cluster_id)], com)
k16 <- setNames(c16$k[match(com, c16$cluster_id)], com)
camb <- com[k15 != k16]
cat("  cgroup v15:", sum(c15$mode == "cgroup"), "| v16:", sum(c16$mode == "cgroup"),
    "| spariti:", length(setdiff(c15$cluster_id[c15$mode=="cgroup"], com)),
    "| nuovi:", length(setdiff(c16$cluster_id[c16$mode=="cgroup"], com)), "\n")
cat("  cluster col k cambiato:", length(camb), "\n")
for (x in camb) cat(sprintf("    %-22s %2d -> %2d  %s%s\n", x, k15[x], k16[x],
                            ifelse(x %in% del$cluster_id, "[nel 214] ", ""),
                            del$canonical_name[match(x, del$cluster_id)] %||% ""))
cat("  ATTESO: solo cgroup_L5_79ce3bd1 (bleomicina) 10 -> 9\n")

cat("\n=== 4. I CANDIDATI, COL GATE DI PRODUZIONE E LE MAPPE ACCESE ===\n")
cfg <- stage4_default_config()
A <- .identify_layer_a_clusters(c16, cfg); fus <- attr(A, "fusioni")
A <- A[A$method == "rem_group", ]
cat("  candidati rem_group:", nrow(A), "(v15: 351)\n")
if (!is.null(fus)) cat("  fusioni applicate:", nrow(fus), "(atteso 7)\n")

cat("\n=== 5. I 24 VERDETTI DI COERENZA SONO ORFANI? ===\n")
V <- read.csv("analysis/audit/2026-08-02-fix/verdetti-poolato-v15.csv", stringsAsFactors = FALSE)
ck <- paste(A$contrast_entity, A$contrast_direction, A$contrast_control_key, sep = "||")
cat("  presenti:", sum(V$ckey %in% ck), "/", nrow(V), "\n")
orf <- V$ckey[!V$ckey %in% ck]
if (length(orf)) for (o in orf) cat("   ORFANO:", o, "\n")
saveRDS(list(A = A, fusioni = fus), file.path(SC, "V16-candidati.rds"))
