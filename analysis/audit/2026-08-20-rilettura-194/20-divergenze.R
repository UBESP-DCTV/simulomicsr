#!/usr/bin/env Rscript
# analysis/audit/2026-08-20-rilettura-194/20-divergenze.R
#
# CHE COSA CAMBIA DAVVERO FRA LE DUE ESECUZIONI, misurato sui campioni.
#
# Il conteggio grezzo dice «1.034 divergenze su 193 gruppi», e non informa su
# nulla: fra quelle ci sono studi che cambiano gruppo (il risultato cambia) e
# studi che restano dove sono con gli stessi identici campioni, e solo
# l'etichetta riscritta dall'LLM («5-FU 6h» diventa «HCT116 5-FU 6h»). Le due
# cose non si possono sommare.
#
# La distinzione si fa sui CAMPIONI, non sul testo: se l'insieme dei GSM del
# braccio trattato e di quello di controllo e' identico, il dato poolato e'
# identico e la divergenza e' COSMETICA, qualunque cosa dica l'etichetta.
#
# L'unita' di conteggio e' lo STUDIO, non la destinazione: uno studio di
# screening con duecento composti dominerebbe da solo il conteggio.
#
# Uso: Rscript analysis/audit/2026-08-20-rilettura-194/20-divergenze.R

suppressPackageStartupMessages({ library(cli) })
OUT      <- "analysis/audit/2026-08-20-rilettura-194"
A3_POOL  <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
RIF_POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260815T193851Z-stage4-v16-3e31e59d"

dA3  <- readRDS(file.path(A3_POOL,  "deliverable-annotato.rds"))
dRIF <- readRDS(file.path(RIF_POOL, "deliverable-annotato.rds"))
A <- readRDS(file.path(OUT, "dispatch-A3.rds"))$tenuti
R <- readRDS(file.path(OUT, "dispatch-RIF.rds"))$tenuti
stopifnot("gsm_t" %in% names(A), "gsm_t" %in% names(R))

kchiave <- function(d) paste(d$contrast_entity, d$contrast_direction, d$contrast_control_key, sep = "||")
dA3$ck <- kchiave(dA3); dRIF$ck <- kchiave(dRIF)
A$ck <- dA3$ck[match(A$cluster_id, dA3$cluster_id)]
R$ck <- dRIF$ck[match(R$cluster_id, dRIF$cluster_id)]

# firma di un confronto = i campioni dei due bracci. Il testo non entra.
A$firma <- paste(A$gsm_t, "|", A$gsm_c)
R$firma <- paste(R$gsm_t, "|", R$gsm_c)

sA <- split(A, paste(A$ck, A$study_id))
sR <- split(R, paste(R$ck, R$study_id))

chiavi <- union(names(sA), names(sR))
righe <- lapply(chiavi, function(k) {
  a <- sA[[k]]; r <- sR[[k]]
  ck  <- if (!is.null(a)) a$ck[1] else r$ck[1]
  sid <- if (!is.null(a)) a$study_id[1] else r$study_id[1]
  if (is.null(r)) return(data.frame(ck = ck, study_id = sid, esito = "solo_A3",
                                    n_a = nrow(a), n_r = 0L, stringsAsFactors = FALSE))
  if (is.null(a)) return(data.frame(ck = ck, study_id = sid, esito = "solo_riferimento",
                                    n_a = 0L, n_r = nrow(r), stringsAsFactors = FALSE))
  stessi_campioni <- identical(sort(a$firma), sort(r$firma))
  stesso_testo <- identical(sort(paste(a$etichetta_trattato, a$etichetta_controllo)),
                            sort(paste(r$etichetta_trattato, r$etichetta_controllo)))
  data.frame(ck = ck, study_id = sid,
             esito = if (stessi_campioni && stesso_testo) "identico"
                     else if (stessi_campioni) "solo_etichetta_riscritta"
                     else "campioni_diversi",
             n_a = nrow(a), n_r = nrow(r), stringsAsFactors = FALSE)
})
tab <- do.call(rbind, righe)

cli_h1("Le due esecuzioni, confrontate sui campioni")
cli_h2("Coppie (chiave di contrasto, studio)")
print(table(tab$esito))

cli_h2("Lo stesso conteggio, ma per STUDIO")
per_studio <- tapply(tab$esito, tab$study_id, function(x) {
  if (any(x == "campioni_diversi")) "campioni_diversi"
  else if (any(x %in% c("solo_A3", "solo_riferimento"))) "cambia_gruppo"
  else if (any(x == "solo_etichetta_riscritta")) "solo_etichetta_riscritta"
  else "identico"
})
print(table(per_studio))
cli_alert_info("studi distinti in gioco: {length(per_studio)}")

# quanti gruppi del deliverable A3 sono toccati da una divergenza VERA
veri <- unique(tab$ck[tab$esito %in% c("solo_A3", "solo_riferimento", "campioni_diversi")])
cli_h2("Gruppi del deliverable A3 toccati")
cli_alert_info("gruppi con almeno una divergenza VERA (cambiano i campioni o il gruppo): {sum(dA3$ck %in% veri)} su {nrow(dA3)}")
cosm <- unique(tab$ck[tab$esito == "solo_etichetta_riscritta"])
cli_alert_info("gruppi la cui unica divergenza e' un'etichetta riscritta: {sum(dA3$ck %in% setdiff(cosm, veri))}")

utils::write.csv(tab, file.path(OUT, "divergenze-per-studio.csv"), row.names = FALSE)
utils::write.csv(data.frame(study_id = names(per_studio), esito = unname(per_studio)),
                 file.path(OUT, "divergenze-esito-per-studio.csv"), row.names = FALSE)
cli_alert_success("Scritti divergenze-per-studio.csv e divergenze-esito-per-studio.csv")
