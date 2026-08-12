# FASE 2c — L'AMPIEZZA DELLA REGOLA (trappola n.10 dell'handout: una regola
# misurata su pochi casi non si applica a centinaia senza rimisurare quanto
# tocca). Qui la regola gira su TUTTI gli 888.821 campioni dell'H5, non sui 9
# candidati, e si guarda dove collassa.
h5  <- "analysis/input/human_gene_v2.5.h5"
SC  <- "analysis/audit/2026-08-12-corsie"
acc <- as.character(rhdf5::h5read(h5, "meta/samples/geo_accession"))
ti  <- as.character(rhdf5::h5read(h5, "meta/samples/title"))
se  <- as.character(rhdf5::h5read(h5, "meta/samples/series_id"))
rhdf5::h5closeAll()
cat("campioni nell'H5:", length(acc), "\n")

scar <- function(x) {
  y <- tolower(trimws(x))
  y <- gsub("[._-]l0*[0-9]{1,3}([._-]|$)", "\\1", y)
  y <- gsub("[._-]lane[ _-]?0*[0-9]{1,3}([._-]|$)", "\\1", y)
  y <- gsub("[._-]run[ _-]?0*[0-9]{1,3}([._-]|$)", "\\1", y)
  gsub("[._-]+$", "", y)
}
lib <- paste(se, scar(ti), sep = "\r")          # la libreria vive DENTRO lo studio
tocca <- scar(ti) != tolower(trimws(ti))
cat("titoli che la regola MODIFICA:", sum(tocca),
    sprintf("(%.3f%%)", 100 * mean(tocca)), "| studi:", length(unique(se[tocca])), "\n")

tb <- table(lib)
multi <- names(tb)[tb > 1]
in_multi <- lib %in% multi
cat("campioni che finiscono in una libreria da PIU' campioni:", sum(in_multi),
    sprintf("(%.3f%%)", 100 * mean(in_multi)), "\n")
cat("librerie con >1 campione:", length(multi), "| studi coinvolti:",
    length(unique(se[in_multi])), "\n")

cat("\n=== CONTROLLO CRITICO: il collasso avviene per la CORSIA o perche' i titoli\n")
cat("    erano GIA' identici? (il secondo caso non e' un difetto di corsia) ===\n")
raw <- paste(se, tolower(trimws(ti)), sep = "\r")
tb_raw <- table(raw)
gia_uguali <- raw %in% names(tb_raw)[tb_raw > 1]
cat("  titoli GIA' identici nello stesso studio:", sum(gia_uguali),
    sprintf("(%.3f%%)", 100 * mean(gia_uguali)), "\n")
cat("  collasso dovuto alla regola (non gia' identici):", sum(in_multi & !gia_uguali), "\n")

cat("\n=== I 25 STUDI PIU' TOCCATI DALLA REGOLA (collasso vero) ===\n")
k <- in_multi & !gia_uguali
tt <- sort(table(se[k]), decreasing = TRUE)
for (s in utils::head(names(tt), 25)) {
  z <- which(se == s & k)
  cat(sprintf("%-30s %4d campioni -> %4d librerie | %s\n", s, length(z),
              length(unique(lib[z])), paste(utils::head(ti[z], 2), collapse = " | ")))
}
saveRDS(data.frame(gsm = acc, series = se, title = ti, lib = lib,
                   tocca = tocca, in_multi = in_multi, gia_uguali = gia_uguali,
                   stringsAsFactors = FALSE),
        file.path(SC, "90-ampiezza.rds"))
cat("\nscritto.\n")
