# FASE 1.3 — I metadati dei campioni delle 2.152 entry ammesse.
#
# NOTA DI MONOTONIA (la ragione per cui bastano le ammesse): contare i campioni
# BIOLOGICI invece dei campioni non puo' mai far RISALIRE un'entry sopra n_min —
# il conteggio biologico e' <= al conteggio grezzo. Le 2.525 gia' cadute restano
# cadute. Si guardano quindi solo le ammesse.
suppressMessages(library(rhdf5))
SC <- "analysis/audit/2026-08-12-corsie"
D  <- readRDS(file.path(SC, "10-dispatch.rds"))
R  <- D$R[D$R$esito == "ammessa", ]
cat("entry ammesse:", nrow(R), "\n")

gsm <- unique(c(unlist(strsplit(R$gsm_treated, ",")),
                unlist(strsplit(R$gsm_control, ","))))
cat("campioni distinti coinvolti:", length(gsm), "\n")

h5  <- "analysis/input/human_gene_v2.5.h5"
acc <- as.character(h5read(h5, "meta/samples/geo_accession"))
idx <- match(gsm, acc)
cat("agganciati all'H5:", sum(!is.na(idx)), "su", length(gsm), "\n")
rd <- function(f) { v <- as.character(h5read(h5, paste0("meta/samples/", f))); v[idx] }
M <- data.frame(gsm = gsm,
                title       = rd("title"),
                source      = rd("source_name_ch1"),
                charact     = rd("characteristics_ch1"),
                relation    = rd("relation"),
                series      = rd("series_id"),
                descr_type  = rd("type"),
                libsel      = rd("library_selection"),
                instrument  = rd("instrument_model"),
                submission  = rd("submission_date"),
                stringsAsFactors = FALSE)
h5closeAll()

# BioSample: il campo relation contiene "BioSample: https://...SAMNxxxxx"
M$samn <- ifelse(grepl("SAMN[0-9]+", M$relation),
                 sub(".*(SAMN[0-9]+).*", "\\1", M$relation), NA_character_)
# SRA experiment (SRX/ERX/DRX): un altro asse, piu' fine del BioSample
M$srx <- ifelse(grepl("(SRX|ERX|DRX)[0-9]+", M$relation),
                sub(".*((SRX|ERX|DRX)[0-9]+).*", "\\1", M$relation), NA_character_)

cat("\n=== COPERTURA DEGLI IDENTIFICATORI ===\n")
cat("con BioSample SAMN:", sum(!is.na(M$samn)), sprintf("(%.1f%%)\n", 100*mean(!is.na(M$samn))))
cat("con SRX/ERX/DRX:   ", sum(!is.na(M$srx)),  sprintf("(%.1f%%)\n", 100*mean(!is.na(M$srx))))
cat("titolo vuoto:      ", sum(is.na(M$title) | !nzchar(trimws(M$title))), "\n")
cat("\nesempio di relation:\n"); print(utils::head(M$relation[!is.na(M$samn)], 2))
cat("\nSAMN usati da piu' di un campione (in TUTTO l'insieme):\n")
tb <- table(M$samn[!is.na(M$samn)])
cat("  SAMN distinti:", length(tb), "| con >1 campione:", sum(tb > 1),
    "| campioni coinvolti:", sum(tb[tb > 1]), "\n")

saveRDS(M, file.path(SC, "20-metadati.rds"))
write.csv(M[, c("gsm","series","title","source","samn","srx")],
          file.path(SC, "20-metadati.csv"), row.names = FALSE)
cat("\nscritto.\n")
