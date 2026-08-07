#!/usr/bin/env Rscript
# analysis/audit/2026-08-06-layer-b-v3/10-conteggio-e-peso.R
#
# Unifica il conteggio dei confronti imperfetti e ne ricalcola il PESO con una
# regola sola, per tutti i gruppi che un conteggio ce l'hanno.
#
# PERCHE'. Il report v2 stampava, per i tre case study fuori dai tredici gruppi
# grandi (Crohn, Parkinson, IL1A), la frase «? confronti imperfetti su ? (X% del
# peso stimato)», dove X veniva da `peso_citati`: la quota degli studi CITATI
# nelle motivazioni della rilettura, estratti con un'espressione regolare. Quella
# stima e' dichiarata cieca dal progetto stesso (finding 2026-08-05, §5.4:
# mediana 87%, perche' raccoglie anche gli studi citati come *puliti*). Su IL1A
# dava 100,0%: un numero inaffidabile pubblicato in un documento da articolo.
#
# Qui:
#   (a) i tre gruppi mancanti hanno ora un conteggio vero (workflow 2026-08-06:
#       un contatore, due critici simmetrici -- uno che sostiene che ha accusato
#       troppo, uno che sostiene troppo poco -- e un arbitro che decide
#       sull'etichetta e dichiara i disaccordi che l'etichetta non chiude);
#   (b) il PESO e' ricalcolato per TUTTI dagli studi che il CONTEGGIO identifica,
#       non da quelli citati nelle motivazioni. Regola unica, confrontabile fra
#       gruppi: mediana di 1/SE^2 per studio, normalizzata dentro il gruppo --
#       la stessa definizione del finding, §2.5.
#
# Il peso resta un LIMITE SUPERIORE: attribuisce a un difetto l'intero peso
# dello studio anche quando solo uno dei suoi confronti e' difettoso.
#
# Uso: Rscript analysis/audit/2026-08-06-layer-b-v3/10-conteggio-e-peso.R

suppressPackageStartupMessages({ library(arrow); library(cli) })

POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
OUT  <- "analysis/audit/2026-08-06-layer-b-v3"
NUOVI <- file.path(OUT, "conteggio-3-gruppi-deciso.json")  # esito del workflow + le decisioni conservative (30-*.R)
GRANDI <- "analysis/audit/2026-08-05-rilettura-214/13-grandi-conteggio.json"

# --- i conteggi: i tredici grandi (2026-08-05) + i tre nuovi (2026-08-06) -----
g13 <- jsonlite::fromJSON(GRANDI, simplifyDataFrame = FALSE)
conteggi <- lapply(g13, function(x) list(
  cluster_id = x$cluster_id,
  n_confronti_totali = x$n_confronti_totali,
  studi = sort(unique(vapply(x$confronti_difettosi, `[[`, character(1), "studio"))),
  n_difettosi = length(x$confronti_difettosi),
  fonte = "rilettura 2026-08-05 (13 gruppi con k>=15)"))

if (file.exists(NUOVI)) {
  g3 <- jsonlite::fromJSON(NUOVI, simplifyDataFrame = FALSE)
  conteggi <- c(conteggi, lapply(g3, function(x) list(
    cluster_id = x$cluster_id,
    n_confronti_totali = x$n_confronti_totali,
    studi = sort(unique(unlist(x$studi_con_difetti))),
    n_difettosi = x$n_confronti_difettosi_finale,
    fonte = "conteggio 2026-08-06 (contatore + due critici simmetrici + arbitro) + decisioni conservative 2026-08-07")))
} else {
  cli_alert_warning("Conteggio dei tre gruppi assente in {.path {NUOVI}}: restano non misurati.")
}

# --- il peso, con una regola sola --------------------------------------------
ids <- vapply(conteggi, `[[`, character(1), "cluster_id")
psd <- as.data.frame(read_parquet(file.path(POOL, "per_study_de.parquet"),
                                  col_select = c("cluster_id", "study_id", "SE")))
psd <- psd[psd$cluster_id %in% ids & is.finite(psd$SE) & psd$SE > 0, ]

peso_studi <- function(cid, studi) {
  x <- psd[psd$cluster_id == cid, ]
  if (nrow(x) == 0L) return(NA_real_)
  agg <- stats::aggregate(list(w = 1 / x$SE^2), by = list(study_id = x$study_id),
                          FUN = stats::median, na.rm = TRUE)
  agg$peso <- agg$w / sum(agg$w)
  if (length(studi) == 0L) return(0)
  mancanti <- setdiff(studi, agg$study_id)
  if (length(mancanti) > 0L) {
    cli_alert_warning("{cid}: studi del conteggio assenti dal poolato: {paste(mancanti, collapse=', ')}")
  }
  sum(agg$peso[agg$study_id %in% studi])
}

out <- lapply(conteggi, function(g) {
  list(cluster_id = g$cluster_id,
       n = g$n_difettosi,
       tot = g$n_confronti_totali,
       peso = peso_studi(g$cluster_id, g$studi),
       studi = g$studi,
       fonte = g$fonte)
})

jsonlite::write_json(out, file.path(OUT, "confronti-imperfetti-conteggio.json"),
                     auto_unbox = TRUE, pretty = TRUE, digits = 10)

# --- che cosa cambia rispetto al numero pubblicato in v2 ----------------------
vecchio <- utils::read.csv("analysis/audit/2026-08-05-rilettura-214/verdetti-con-peso.csv",
                           stringsAsFactors = FALSE)
cli_h2("Peso: regola nuova (studi del conteggio) contro il numero pubblicato in v2")
for (g in out) {
  v <- vecchio$peso_citati[vecchio$cluster_id == g$cluster_id]
  cli_alert_info(sprintf("%s  n=%2d/%3d  peso nuovo %5.1f%%  |  v2 %5.1f%%%s",
                         g$cluster_id, g$n, g$tot, 100 * g$peso,
                         if (length(v)) 100 * v[1L] else NA_real_,
                         if (length(v) && abs(100 * g$peso - 100 * v[1L]) > 1) "   <-- cambia" else ""))
}
cli_alert_success("Scritto {.path {file.path(OUT, 'confronti-imperfetti-conteggio.json')}} ({length(out)} gruppi)")
