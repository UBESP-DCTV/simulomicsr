#!/usr/bin/env Rscript
# analysis/audit/2026-08-16-A3/90-confronto-v16b.R
#
# LA RISPOSTA DI A3: quanto si muove il DELIVERABLE rifacendo gli stadi LLM.
#
# Lo Stadio 3 si muove (finding 2026-08-19: 35 studi usciti dalle cinque
# bandiera, 8 entrati). Qui si misura quanto di quel movimento arriva fino in
# fondo, dopo il gate dei controlli interni e il pooling: il gate potrebbe
# assorbirne una parte, o amplificarla.
#
# Uso: Rscript analysis/audit/2026-08-16-A3/90-confronto-v16b.R

suppressPackageStartupMessages({ library(cli); devtools::load_all(".", quiet = TRUE) })

RIF <- Sys.getenv("RIF_POOL", "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260815T193851Z-stage4-v16-3e31e59d")
A3  <- Sys.getenv("A3_POOL",  "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d")
OUT <- "analysis/audit/2026-08-16-A3"

r <- readRDS(file.path(RIF, "deliverable-annotato.rds"))
a <- readRDS(file.path(A3,  "deliverable-annotato.rds"))

cli_h2("Quante meta-analisi")
cli_alert_info("riferimento v16b: {nrow(r)}")
cli_alert_info("A3              : {nrow(a)}   ({sprintf('%+d', nrow(a)-nrow(r))})")

# L'identita' di una meta-analisi e' la CHIAVE DEL CONTRASTO, non il cluster_id:
# l'id e' un hash che cambia se cambia la composizione, quindi confrontare gli id
# direbbe "sono tutte diverse" senza informare su nulla.
kchiave <- function(d) paste(d$contrast_entity, d$contrast_direction, d$contrast_control_key, sep = "||")
kr <- kchiave(r); ka <- kchiave(a)
esce  <- setdiff(kr, ka); entra <- setdiff(ka, kr); resta <- intersect(kr, ka)

cli_h2("Composizione del movimento")
cli_alert_info("restano in entrambi: {length(resta)}")
cli_alert_info("escono (c'erano, non ci sono piu'): {length(esce)}")
cli_alert_info("entrano (nuove): {length(entra)}")

cli_h3("Le meta-analisi che ESCONO")
for (k in esce) {
  i <- which(kr == k)[1L]
  cli_alert(sprintf("  %-42s k=%2d  n_sig=%6d  %s", r$contrast_entity[i], r$k_effective[i],
                    r$n_sig[i], r$contrast_entity_label[i] %||% ""))
}
cli_h3("Le meta-analisi che ENTRANO")
for (k in entra) {
  i <- which(ka == k)[1L]
  cli_alert(sprintf("  %-42s k=%2d  n_sig=%6d  %s", a$contrast_entity[i], a$k_effective[i],
                    a$n_sig[i], a$contrast_entity_label[i] %||% ""))
}

cli_h2("Le cinque bandiera, nel deliverable")
PAV <- c("NCBITaxon:2697049"="SARS-CoV-2","HGNC:11766"="TGFB1","CHEBI:16412"="LPS",
         "CHEBI:68534"="enzalutamide","CHEBI:63637"="vemurafenib")
righe <- lapply(names(PAV), function(id) {
  ir <- which(r$contrast_entity == id); ia <- which(a$contrast_entity == id)
  data.frame(entita = PAV[[id]],
             k_rif  = if (length(ir)) max(r$k_effective[ir]) else NA_integer_,
             k_a3   = if (length(ia)) max(a$k_effective[ia]) else NA_integer_,
             sig_rif= if (length(ir)) r$n_sig[ir[which.max(r$k_effective[ir])]] else NA_integer_,
             sig_a3 = if (length(ia)) a$n_sig[ia[which.max(a$k_effective[ia])]] else NA_integer_,
             stringsAsFactors = FALSE)
})
tab <- do.call(rbind, righe)
tab$delta_k <- tab$k_a3 - tab$k_rif
tab$delta_sig_pct <- round(100 * (tab$sig_a3 - tab$sig_rif) / tab$sig_rif, 1)
print(tab, row.names = FALSE)

# quanto si muovono i gruppi che RESTANO: e' la misura piu' onesta, perche' non
# dipende da quali entrano o escono
comune <- data.frame(chiave = resta,
                     k_rif = r$k_effective[match(resta, kr)],
                     k_a3  = a$k_effective[match(resta, ka)],
                     sig_rif = r$n_sig[match(resta, kr)],
                     sig_a3  = a$n_sig[match(resta, ka)], stringsAsFactors = FALSE)
comune$dk <- comune$k_a3 - comune$k_rif
cli_h2("I gruppi presenti in entrambi: quanto si muovono")
cli_alert_info("k invariato: {sum(comune$dk == 0)} | k in calo: {sum(comune$dk < 0)} | k in crescita: {sum(comune$dk > 0)}")
cli_alert_info("delta k mediano: {stats::median(comune$dk)} | somma dei delta: {sum(comune$dk)}")
cli_alert_info("geni significativi, mediana del cambiamento relativo: {sprintf('%+.1f%%', stats::median(100*(comune$sig_a3-comune$sig_rif)/pmax(comune$sig_rif,1)))}")

utils::write.csv(comune, file.path(OUT, "confronto-v16b-comuni.csv"), row.names = FALSE)
utils::write.csv(tab, file.path(OUT, "confronto-v16b-bandiera.csv"), row.names = FALSE)
cli_alert_success("Scritti confronto-v16b-comuni.csv e confronto-v16b-bandiera.csv")
