#!/usr/bin/env Rscript
# analysis/audit/2026-08-10-sensitivity/16-nmin-e-qualita.R
#
# L'ipotesi nata leggendo 15-difetto-trasferito.txt: in tutti e 9 i casi il
# confronto sopravvissuto al filtro `n_min` e' la versione CORRETTAMENTE APPAIATA
# dello stesso esperimento (LAPC4_ENZA vs VCaP_DMSO fuori, R1AD1_ENZA vs
# R1AD1_DMSO dentro; donatore assente fuori, donatore 1013 appaiato dentro).
#
# Se e' un caso, il tasso di difetto dev'essere lo stesso dentro e fuori. Se non
# lo e', `n_min` — messo per un motivo puramente statistico (limma-voom vuole
# replica) — sta filtrando anche la QUALITA' dell'appaiamento, e questo va detto
# perche' e' un pezzo del motivo per cui il deliverable e' piu' pulito del censimento.
#
# ⚠️ Il denominatore giusto e' quello che il LETTORE ha visto: i confronti dei
# soli studi presenti nel per_study_de del cluster (e' il filtro di
# 00-materiale.R:78). Contare tutti i record del cluster gonfierebbe il fuori con
# confronti che il lettore non ha mai letto e non poteva accusare.
#
# Uso: Rscript analysis/audit/2026-08-10-sensitivity/16-nmin-e-qualita.R
suppressPackageStartupMessages({ library(arrow); library(cli) })

POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7"
OUT  <- "analysis/audit/2026-08-10-sensitivity"

acc <- utils::read.csv(file.path(OUT, "10-accuse-sui-bracci.csv"), stringsAsFactors = FALSE)
R   <- readRDS(file.path(OUT, "10-record-esito.rds"))
ids <- unique(acc$cluster_id)

# studi poolati per cluster: la vista che il lettore aveva
psd <- unique(as.data.frame(read_parquet(file.path(POOL, "per_study_de.parquet"),
                                         col_select = c("cluster_id", "study_id"))))
psd <- psd[psd$cluster_id %in% ids, ]

V <- R[R$cluster_id %in% ids, ]
V <- V[paste(V$cluster_id, V$study_id) %in% paste(psd$cluster_id, psd$study_id), ]
V$dentro <- V$esito == "braccio"

cli_alert_info("confronti visti dal lettore: {nrow(V)} (censiti dichiarati: 843)")
cli_alert_info("di cui DENTRO il pooling {sum(V$dentro)} | FUORI {sum(!V$dentro)}")

# marca gli accusati sui record, per tripla (studio, etichetta trattato, controllo)
V$chiave   <- paste(V$study_id, V$etichetta_trattato, V$etichetta_controllo, sep = "‖")
acc$chiave <- paste(acc$study_id, acc$etichetta_trattato, acc$etichetta_controllo, sep = "‖")
V$accusato <- paste(V$cluster_id, V$chiave) %in% paste(acc$cluster_id, acc$chiave)

tab <- table(dentro = V$dentro, accusato = V$accusato)
print(tab)

p_in  <- sum(V$accusato & V$dentro)  / sum(V$dentro)
p_out <- sum(V$accusato & !V$dentro) / sum(!V$dentro)
cli_h2("Tasso di confronti accusati")
cli_alert_info("DENTRO il pooling (n>=2 su entrambi i lati): {sprintf('%.1f%%', 100*p_in)}")
cli_alert_info("FUORI (scartati da n_min): {sprintf('%.1f%%', 100*p_out)}")
cli_alert_info("rapporto: {sprintf('%.2fx', p_out/p_in)}")

ft <- stats::fisher.test(tab)
cli_alert_info("Fisher esatto: p = {format.pval(ft$p.value, digits=3)} | OR = {sprintf('%.2f', ft$estimate)} (IC95% {sprintf('%.2f-%.2f', ft$conf.int[1], ft$conf.int[2])})")

# ⚠️ il confondente ovvio: un confronto con un lato a 1 e' anche piu' "strano" di
# suo. Il test dice che i due gruppi differiscono, non PERCHE'.
cli_alert_warning("Associazione, non meccanismo: n_min e appaiamento possono avere una causa comune (studi con molte condizioni a replica singola).")

utils::write.csv(as.data.frame(tab), file.path(OUT, "16-nmin-e-qualita.csv"), row.names = FALSE)
cli_alert_success("scritto 16-nmin-e-qualita.csv")
