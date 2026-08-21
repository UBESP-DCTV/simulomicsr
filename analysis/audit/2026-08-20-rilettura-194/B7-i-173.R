OUT <- "analysis/audit/2026-08-20-rilettura-194"
POOL <- "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d"
d <- readRDS(file.path(POOL,"deliverable-annotato.rds"))
M <- read.csv(file.path(OUT,"B4-quadro-influenza.csv"), stringsAsFactors=FALSE)
v <- read.csv(file.path(OUT,"verdetti-194.csv"), stringsAsFactors=FALSE)
M$eti_non_chiude <- v$etichetta_non_chiude[match(M$cluster_id, v$cluster_id)]
i <- match(M$cluster_id, d$cluster_id)
M$quota_top1 <- d$quota_top1[i]; M$k_kish <- d$k_kish[i]; M$I2 <- d$I2_med[i]

senza <- M[M$n_studi_accusati == 0, ]
con_viv <- M[M$n_studi_accusati > 0 & !is.na(M$k_ridotto) & M$k_ridotto >= 3, ]
cat("=== COMPOSIZIONE DEI 173 ===\n")
cat("  senza alcun difetto letto :", nrow(senza), "\n")
cat("  CON difetti ma sopravvivono:", nrow(con_viv), " <-- questi contengono ancora studi difettosi\n\n")

cat("=== I 128 SENZA DIFETTI: quanto sono solidi? ===\n")
cat("  verdetto 'corretta':", sum(senza$verdetto=="corretta"),
    " | 'incerta':", sum(senza$verdetto=="incerta"),
    " | 'difettosa':", sum(senza$verdetto=="difettosa"), "\n")
cat("  verdetto NON chiuso dall'etichetta:", sum(senza$eti_non_chiude=="True", na.rm=TRUE), "\n")
cat("  dominati da un solo studio (>50% del peso):", sum(senza$quota_top1>0.5, na.rm=TRUE),
    sprintf(" (%.0f%%)", 100*mean(senza$quota_top1>0.5, na.rm=TRUE)), "\n")
cat("  meno di 2 studi efficaci (Kish<2):", sum(senza$k_kish<2, na.rm=TRUE),
    sprintf(" (%.0f%%)", 100*mean(senza$k_kish<2, na.rm=TRUE)), "\n")
cat("  a k=3-4:", sum(senza$k<=4), sprintf(" (%.0f%%)", 100*mean(senza$k<=4)), "\n\n")

cat("=== I 45 CHE SOPRAVVIVONO: quanto difetto resta dentro? ===\n")
cat("  peso contaminato: mediana", sprintf("%.1f%%", median(con_viv$peso_contaminato)),
    "| max", sprintf("%.1f%%", max(con_viv$peso_contaminato)), "\n")
cat("  sopra il 25% del peso:", sum(con_viv$peso_contaminato>25), "su", nrow(con_viv), "\n")
cat("  k prima -> dopo aver tolto i difetti: mediana",
    median(con_viv$k), "->", median(con_viv$k_ridotto), "\n")
cat("  quanti scendono di piu' di 1 studio:", sum(con_viv$k - con_viv$k_ridotto > 1), "\n\n")

cat("=== SE SI TENESSERO I 173 GIA' RIPULITI (tolti i difetti) ===\n")
k_dopo <- c(senza$k, con_viv$k_ridotto)
cat("  k mediano:", median(k_dopo), " | a k=3:", sum(k_dopo==3), " | a k>=15:", sum(k_dopo>=15), "\n")
