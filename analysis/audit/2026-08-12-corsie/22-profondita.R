SC <- "analysis/audit/2026-08-12-corsie"
M  <- readRDS(file.path(SC, "20-metadati.rds"))
A3 <- read.delim("analysis/audit/A3-libsize-scprob-bacino.tsv", stringsAsFactors = FALSE)
i <- match(M$gsm, A3$geo)
cat("campioni con lib_size da A3:", sum(!is.na(i)), "su", nrow(M), "\n")
M$libsize <- A3$lib_size[i]
cat("\nprofondita' dei campioni poolati (milioni di reads):\n")
print(round(stats::quantile(M$libsize, c(0, .05, .1, .25, .5, .75, .95, 1), na.rm = TRUE) / 1e6, 2))
R <- readRDS(file.path(SC, "30-entry-annotate.rds")); R <- R[R$esito == "ammessa", ]
ls_ <- setNames(M$libsize, M$gsm)
mx <- function(s) suppressWarnings(max(ls_[strsplit(s, ",")[[1]]], na.rm = TRUE))
R$max_t <- vapply(R$gsm_treated, mx, numeric(1))
R$max_c <- vapply(R$gsm_control, mx, numeric(1))
R$max_tot <- pmax(R$max_t, R$max_c)
sott <- which(is.finite(R$max_tot) & R$max_tot < 1e7)
cat("\nentry in cui NESSUN campione supera 10M di reads:", length(sott), "su", nrow(R), "\n")
cat("studi coinvolti:", length(unique(R$study_id[sott])), "\n")
noti <- c("GSE173902", "GSE178340", "GSE115542", "GSE116899")
cat("i quattro noti sono dentro?", paste(noti %in% R$study_id[sott], collapse = " "), "\n")
for (s in noti) cat(sprintf("   %-11s profondita' mediana %.1fM\n", s,
    stats::median(M$libsize[M$series == s], na.rm = TRUE) / 1e6))
saveRDS(M, file.path(SC, "21-metadati-libsize.rds"))
saveRDS(unique(R$study_id[sott]), file.path(SC, "22-studi-poco-profondi.rds"))
