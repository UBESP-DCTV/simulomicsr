#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/70-leva.R
#
# QUAL E' LA LEVA, misurata sui dati e non sulla prosa dei giudizi.
#
# Il giudizio comparativo dice che il meccanismo dominante e' «lo studio entra o
# esce dal pooling» (71% dei casi A, 69% dei B). Ma «entra o esce» descrive
# l'effetto, non la causa: uno studio esce da un gruppo perche' la sua CHIAVE DI
# CONTRASTO e' cambiata, e la chiave ha tre pezzi:
#     entita || verso || tipo di controllo.
# Qui si guarda QUALE dei tre si muove: e' la differenza fra «va corretto il
# riconoscimento dell'entita'» e «va corretta la normalizzazione del controllo»,
# due interventi diversi in punti diversi della catena.
#
# ⚠️ COME NON VA FATTA. La prima versione confrontava, per ogni studio, gli
# INSIEMI di entita'/versi/controlli fra i due run. Dava «entita' cambia: 100%»,
# che non e' un risultato ma un artefatto: uno studio che sta in tre gruppi in un
# run e in due nell'altro ha per forza tutti e tre gli insiemi diversi. La
# domanda giusta si pone CHIAVE PER CHIAVE: presa una chiave che lo studio aveva
# nel riferimento e non ha piu', esiste nel run nuovo una chiave dello stesso
# studio che le somiglia, e in che cosa differisce?
#
# L'unita' e' lo STUDIO. Uno studio che si sposta in trenta gruppi vale UNO.
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/70-leva.R

suppressPackageStartupMessages({ library(cli) })
OUT      <- "analysis/audit/2026-08-20-rilettura-194"
A3_POOL  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
RIF_POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260815T193851Z-stage4-v16-3e31e59d"

dA <- readRDS(file.path(A3_POOL,  "deliverable-annotato.rds"))
dR <- readRDS(file.path(RIF_POOL, "deliverable-annotato.rds"))
A  <- readRDS(file.path(OUT, "dispatch-A3.rds"))$tenuti
R  <- readRDS(file.path(OUT, "dispatch-RIF.rds"))$tenuti
col <- c("cluster_id", "contrast_entity", "contrast_direction", "contrast_control_key")
A <- merge(A, dA[, col], by = "cluster_id"); R <- merge(R, dR[, col], by = "cluster_id")
A$key <- paste(A$contrast_entity, A$contrast_direction, A$contrast_control_key, sep = "||")
R$key <- paste(R$contrast_entity, R$contrast_direction, R$contrast_control_key, sep = "||")

ua <- unique(A[, c("study_id", "key", "contrast_entity", "contrast_direction", "contrast_control_key")])
ur <- unique(R[, c("study_id", "key", "contrast_entity", "contrast_direction", "contrast_control_key")])
la <- split(ua, ua$study_id); lr <- split(ur, ur$study_id)

studi <- union(names(la), names(lr))
esito <- character(0); dettaglio <- list()

for (s in studi) {
  a <- la[[s]]; r <- lr[[s]]
  if (is.null(a)) { esito[s] <- "esce del tutto dal deliverable"; next }
  if (is.null(r)) { esito[s] <- "entra da fuori nel deliverable"; next }
  perse  <- setdiff(r$key, a$key)
  nuove  <- setdiff(a$key, r$key)
  if (length(perse) == 0L && length(nuove) == 0L) { esito[s] <- "chiavi identiche"; next }
  # per ogni chiave persa, la chiave nuova piu' vicina dello stesso studio
  cause <- character(0)
  for (k in perse) {
    rk <- r[r$key == k, ][1, ]
    cand <- a[a$key %in% nuove, , drop = FALSE]
    if (nrow(cand) == 0L) { cause <- c(cause, "la chiave sparisce senza sostituta"); next }
    stessa_ent <- cand[cand$contrast_entity == rk$contrast_entity, , drop = FALSE]
    if (nrow(stessa_ent) == 0L) { cause <- c(cause, "cambia l'ENTITA'"); next }
    stesso_verso <- stessa_ent[stessa_ent$contrast_direction == rk$contrast_direction, , drop = FALSE]
    if (nrow(stesso_verso) == 0L) { cause <- c(cause, "cambia il VERSO"); next }
    cause <- c(cause, "cambia il TIPO DI CONTROLLO")
    dettaglio[[length(dettaglio) + 1L]] <- data.frame(
      study_id = s, da = rk$contrast_control_key,
      a = paste(unique(stesso_verso$contrast_control_key), collapse = ";"),
      entita = rk$contrast_entity, stringsAsFactors = FALSE)
  }
  # un solo esito per studio: si tiene la causa piu' "a monte" che si e' vista
  ord <- c("cambia l'ENTITA'", "cambia il VERSO", "cambia il TIPO DI CONTROLLO",
           "la chiave sparisce senza sostituta")
  esito[s] <- if (length(cause)) ord[min(match(cause, ord))] else "solo chiavi nuove, nessuna persa"
}

cli_h1("Quale pezzo della chiave di contrasto si muove")
cli_alert_info("studi che compaiono in almeno uno dei due deliverable: {length(studi)}")
tb <- sort(table(esito), decreasing = TRUE)
for (i in seq_along(tb))
  cat(sprintf("  %4d  (%5.1f%%)  %s\n", tb[i], 100*tb[i]/length(studi), names(tb)[i]))

cli_h2("Solo fra gli studi che restano nel deliverable e cambiano chiave")
mossi <- esito[!esito %in% c("chiavi identiche", "esce del tutto dal deliverable",
                             "entra da fuori nel deliverable")]
tb2 <- sort(table(mossi), decreasing = TRUE)
for (i in seq_along(tb2))
  cat(sprintf("  %4d  (%5.1f%%)  %s\n", tb2[i], 100*tb2[i]/length(mossi), names(tb2)[i]))

if (length(dettaglio)) {
  cli_h2("Quando si muove il tipo di controllo: da che cosa, a che cosa")
  dd <- do.call(rbind, dettaglio)
  print(utils::head(sort(table(paste(dd$da, "->", dd$a)), decreasing = TRUE), 12))
  utils::write.csv(dd, file.path(OUT, "leva-controllo-dettaglio.csv"), row.names = FALSE)
}

utils::write.csv(data.frame(study_id = names(esito), esito = unname(esito)),
                 file.path(OUT, "leva-chiave-contrasto.csv"), row.names = FALSE)
cli_alert_success("Scritto leva-chiave-contrasto.csv")
