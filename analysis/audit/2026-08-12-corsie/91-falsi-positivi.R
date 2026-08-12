# FASE 2d — IL CONTROLLO NEGATIVO DELLA REGOLA, sui dati e non sulle stringhe.
#
# Se due campioni sono davvero due corsie della STESSA libreria, allora sono lo
# stesso materiale biologico e i loro METADATI DESCRITTIVI devono coincidere.
# Se invece la regola ha unito due campioni diversi (una "L" che non era una
# corsia: L2 come vertebra lombare, L come linea, ...), i metadati divergono.
#
# Il controllo gira su TUTTE le 4.431 librerie che collassano in tutto l'H5, non
# sui casi comodi.
SC <- "analysis/audit/2026-08-12-corsie"
h5 <- "analysis/input/human_gene_v2.5.h5"
A  <- readRDS(file.path(SC, "90-ampiezza.rds"))
A  <- A[A$in_multi & !A$gia_uguali, ]
cat("campioni in librerie collassanti:", nrow(A), "| librerie:", length(unique(A$lib)), "\n")

acc <- as.character(rhdf5::h5read(h5, "meta/samples/geo_accession"))
ch  <- as.character(rhdf5::h5read(h5, "meta/samples/characteristics_ch1"))
so  <- as.character(rhdf5::h5read(h5, "meta/samples/source_name_ch1"))
rhdf5::h5closeAll()
i <- match(A$gsm, acc)
A$charact <- ch[i]; A$source <- so[i]

sp <- split(seq_len(nrow(A)), A$lib)
res <- data.frame(lib = names(sp),
  n = vapply(sp, length, integer(1)),
  ch_uguali = vapply(sp, function(j) length(unique(A$charact[j])) == 1L, logical(1)),
  so_uguali = vapply(sp, function(j) length(unique(A$source[j])) == 1L, logical(1)),
  stringsAsFactors = FALSE)
cat("\n=== LIBRERIE COLLASSATE: i metadati descrittivi coincidono? ===\n")
cat("  characteristics identici:", sum(res$ch_uguali), "su", nrow(res),
    sprintf("(%.1f%%)\n", 100 * mean(res$ch_uguali)))
cat("  source_name identici:    ", sum(res$so_uguali), "su", nrow(res),
    sprintf("(%.1f%%)\n", 100 * mean(res$so_uguali)))

cat("\n=== I CASI IN CUI NON COINCIDONO = candidati FALSI POSITIVI ===\n")
bad <- res[!res$ch_uguali, ]
cat("librerie sospette:", nrow(bad), "| studi:",
    length(unique(sub("\r.*", "", bad$lib))), "\n\n")
for (l in utils::head(bad$lib[order(-bad$n)], 20)) {
  j <- sp[[l]]
  cat(sprintf("%-42s n=%d\n", substr(gsub("\r", " | ", l), 1, 42), length(j)))
  for (x in utils::head(j, 3))
    cat(sprintf("    %s  %-38s  %s\n", A$gsm[x], substr(A$title[x], 1, 38),
                substr(A$charact[x], 1, 70)))
}
cat("\n=== STUDI SOSPETTI, per numero di librerie ===\n")
print(utils::head(sort(table(sub("\r.*", "", bad$lib)), decreasing = TRUE), 15))
write.csv(res, file.path(SC, "91-librerie-coerenza.csv"), row.names = FALSE)
cat("\nscritto.\n")
