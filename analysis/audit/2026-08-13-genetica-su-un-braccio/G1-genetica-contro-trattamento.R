# LA DOMANDA DELL'UTENTE, generalizzata: esiste una meta-analisi che mette
# insieme una MANIPOLAZIONE GENETICA e un TRATTAMENTO con una molecola?
#
# Non e' la stessa cosa e non va nello stesso mucchio: sovraesprimere il gene del
# TNF e aggiungere proteina TNF al terreno sono due esperimenti diversi.
#
# PERCHE' IL RISCHIO ESISTE: la chiave di raggruppamento e'
# `entita' || verso || tipo-di-controllo`. Il VERSO protegge dai knockout (verso
# `block`, non si fondono mai con `gain`), ma **il tipo di intervento non e'
# nella chiave**: una SOVRAESPRESSIONE ha verso `gain` come una stimolazione.
#
# COME SI MISURA, senza inventare un rilevatore: `.ca_delta()` di produzione dice
# gia' di che CLASSE e' cio' che cambia fra i due bracci (`genetic`, `drug`,
# `infection`, `disease`, `environment`). Si guarda la classe del delta di ogni
# membro e si cercano i gruppi che ne mescolano di incompatibili. Solo cio' che
# CAMBIA conta: `genetic_background=wild-type` su tutti e due i bracci non e' una
# manipolazione, ed e' escluso per costruzione.
#
# CASI DI ACCETTAZIONE, dichiarati prima di guardare l'esito:
#   A1. il gruppo TNF `cgroup_L5_d9e23e09` deve risultare PURO senza genetica
#       (48 etichette lette a mano: tutte "proteina TNF-alpha aggiunta al terreno").
#   A2. il rilevatore non deve essere cieco: deve esistere almeno un gruppo con
#       delta `genetic` nel corpus, altrimenti sta misurando zero per un difetto
#       suo e non per una proprieta' dei dati.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC  <- "analysis/audit/2026-08-13-genetica-su-un-braccio"
S3D <- "analysis/p4-output/20260803T164558Z-stage3-v15-7f986159"
DEL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"

del <- readRDS(file.path(DEL, "deliverable-annotato.rds"))
asg <- arrow::read_parquet(file.path(S3D, "assignments.parquet"))
s2  <- readRDS(file.path("analysis/audit/2026-08-12-corsie", "s2.rds"))
idx <- simulomicsr:::.index_stage2_master(s2)
asg <- asg[asg$cluster_id %in% del$cluster_id, ]
cat("gruppi:", length(unique(asg$cluster_id)), "| membri:", nrow(asg), "\n")

fl_of <- function(rg) {
  fl <- rg$factor_levels
  if (length(fl) == 0L) return("")
  paste(sort(vapply(fl, function(z) paste0(z$key, "=", z$value), character(1L))),
        collapse = ";")
}
righe <- list()
for (i in seq_len(nrow(asg))) {
  p <- simulomicsr:::.split_record_id(asg$record_id[i])
  if (is.na(p$series_id) || !exists(p$series_id, envir = idx, inherits = FALSE)) next
  st <- get(p$series_id, envir = idx, inherits = FALSE)
  cmp <- simulomicsr:::.lookup_cmp(st, p$suffix)
  if (is.null(cmp)) next
  tg <- simulomicsr:::.lookup_rg(st, cmp$treated_group)
  cg <- simulomicsr:::.lookup_rg(st, cmp$control_group)
  if (is.null(tg) || is.null(cg)) next
  d <- simulomicsr:::.ca_delta(fl_of(tg), fl_of(cg))
  righe[[length(righe) + 1L]] <- data.frame(
    cluster_id = asg$cluster_id[i], study_id = p$series_id,
    classe = d$dominant_class %||% NA_character_,
    firma = d$classes_signature %||% "",
    ha_genetica = "genetic" %in% d$classes,
    trattato = substr(paste(d$treated_values, collapse = " | "), 1, 70),
    controllo = substr(paste(d$control_values, collapse = " | "), 1, 50),
    etichetta_t = substr(tg$label_human %||% "", 1, 45),
    stringsAsFactors = FALSE)
}
M <- do.call(rbind, righe)
cat("membri risolti:", nrow(M), "\n\n")
cat("=== CLASSE DEL DELTA, su tutti i membri ===\n"); print(table(M$classe, useNA = "ifany"))

cat("\n=== ACCETTAZIONE ===\n")
tnf <- M[M$cluster_id == "cgroup_L5_d9e23e09", ]
cat("  A1 gruppo TNF: membri", nrow(tnf), "| con genetica nel delta:", sum(tnf$ha_genetica),
    "(atteso 0)\n")
cat("  A2 membri con genetica nel delta, in tutto il deliverable:", sum(M$ha_genetica),
    "| gruppi:", length(unique(M$cluster_id[M$ha_genetica])), "(deve essere > 0)\n")

per <- lapply(split(M, M$cluster_id), function(z) data.frame(
  cluster_id = z$cluster_id[1], n = nrow(z),
  n_genetica = sum(z$ha_genetica),
  classi = paste(sort(unique(z$classe)), collapse = "+"), stringsAsFactors = FALSE))
P <- do.call(rbind, per)
P$misto_genetica <- P$n_genetica > 0L & P$n_genetica < P$n
P <- merge(P, del[, c("cluster_id", "contrast_entity_label", "contrast_direction",
                      "k_effective", "n_sig")], by = "cluster_id")

cat("\n=== L'ESITO ===\n")
cat("gruppi tutti-genetica:", sum(P$n_genetica == P$n), "\n")
cat("gruppi senza genetica:", sum(P$n_genetica == 0L), "\n")
cat("GRUPPI MISTI (genetica + trattamento):", sum(P$misto_genetica), "su", nrow(P), "\n\n")
if (any(P$misto_genetica)) {
  Q <- P[P$misto_genetica, ]
  Q <- Q[order(-Q$k_effective), ]
  print(Q[, c("cluster_id", "contrast_entity_label", "contrast_direction",
              "k_effective", "n", "n_genetica", "classi")], row.names = FALSE)
  cat("\n=== I MEMBRI CON GENETICA DENTRO QUEI GRUPPI ===\n")
  for (cc in Q$cluster_id) {
    z <- M[M$cluster_id == cc, ]
    cat(sprintf("\n-- %s (%s, verso %s, k=%d)\n", cc,
                Q$contrast_entity_label[Q$cluster_id == cc],
                Q$contrast_direction[Q$cluster_id == cc],
                Q$k_effective[Q$cluster_id == cc]))
    g <- z[z$ha_genetica, ]
    for (i in seq_len(min(6, nrow(g))))
      cat(sprintf("   GENETICA  %-11s T: %-46s C: %s\n", g$study_id[i], g$trattato[i], g$controllo[i]))
    h <- z[!z$ha_genetica, ]
    for (i in seq_len(min(4, nrow(h))))
      cat(sprintf("   altro     %-11s T: %-46s C: %s\n", h$study_id[i], h$trattato[i], h$controllo[i]))
  }
}
saveRDS(list(M = M, P = P), file.path(SC, "G1-genetica.rds"))
write.csv(P, file.path(SC, "G1-gruppi.csv"), row.names = FALSE)
write.csv(M, file.path(SC, "G1-membri.csv"), row.names = FALSE)
cat("\nscritto.\n")
