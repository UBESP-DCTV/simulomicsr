#!/usr/bin/env Rscript
# Costruisce il fixture archs4-mini.h5 usato dai test ETL.
#
# Idempotente: cancella e ricrea il file. Eseguito a mano quando lo schema
# del fixture cambia. NON in esecuzione automatica nei test.
#
# Schema (P5 audit RED_ALERT C1):
#   /meta/samples/ contiene 14 dataset (1 riga per sample, 4 sample).
#   13 STRING + 1 FLOAT (singlecellprobability).
#
# I 4 sample sono quelli storici (GSM001-GSM004) con i campi originali invariati;
# i 7 campi nuovi (ADR-0019 D1, D2, D3, D5, D8, D9) sono popolati con valori
# plausibili scelti per dare copertura ai test downstream (C2, C3, C4).

fix_path <- file.path("tests", "testthat", "fixtures", "archs4-mini.h5")

if (file.exists(fix_path)) {
  file.remove(fix_path)
}

rhdf5::h5createFile(fix_path)
rhdf5::h5createGroup(fix_path, "meta")
rhdf5::h5createGroup(fix_path, "meta/samples")

# ---- Campi storici (7) -----------------------------------------------------
samples_chr <- list(
  geo_accession       = c("GSM001", "GSM002", "GSM003", "GSM004"),
  series_id           = c("GSE100", "GSE100,GSE101", "GSE102", "GSE103"),
  title               = c("MCF7 tam 24h", "MCF7 DMSO 24h", "HEK293 baseline", ""),
  source_name_ch1     = c("MCF7", "MCF7", "HEK293", "K562"),
  characteristics_ch1 = c("cell: MCF7,trt: tam", "cell: MCF7,trt: DMSO",
                          "cell: HEK293,trt: none", "x"),
  organism_ch1        = c("Homo sapiens", "Homo sapiens", "Mus musculus",
                          "Homo sapiens"),
  library_strategy    = c("RNA-Seq", "RNA-Seq", "RNA-Seq", "scRNA-Seq")
)

# ---- Campi nuovi character (6) — ADR-0019 D1, D2, D5, D8, D9 ---------------
# GSM001: bulk human polyA standard, STAR/NovaSeq, BioSample.
# GSM002: bulk human total RNA, HISAT2/HiSeq, BioSample.
# GSM003: mouse (sara' droppato a monte da organism_ch1).
# GSM004: scRNA-Seq dichiarato (library_source single cell + 10x kit + scprob alta).
samples_chr_new <- list(
  molecule_ch1         = c("polyA RNA", "total RNA", "polyA RNA", "polyA RNA"),
  library_source       = c("transcriptomic", "transcriptomic", "transcriptomic",
                           "transcriptomic single cell"),
  extract_protocol_ch1 = c("TRIzol total RNA + TruSeq Stranded mRNA Library Prep Kit",
                           "RNeasy mini kit + TruSeq",
                           "TRIzol mouse standard",
                           "10x Genomics Chromium Single Cell 3' v3"),
  instrument_model     = c("Illumina NovaSeq 6000", "Illumina HiSeq 2500",
                           "Illumina NovaSeq 6000", "Illumina NovaSeq 6000"),
  data_processing      = c("STAR_2.7.10a alignment to GRCh38; HTSeq-count",
                           "HISAT2 alignment to GRCh38; featureCounts",
                           "STAR mm10",
                           "Cell Ranger 6.1.2 alignment + count"),
  relation             = c("BioSample: https://www.ncbi.nlm.nih.gov/biosample/SAMN12340001",
                           "BioSample: https://www.ncbi.nlm.nih.gov/biosample/SAMN12340002",
                           "BioSample: https://www.ncbi.nlm.nih.gov/biosample/SAMN12340003",
                           "BioSample: https://www.ncbi.nlm.nih.gov/biosample/SAMN12340004")
)

# ---- Campo nuovo numeric (1) — ADR-0019 D3 ---------------------------------
# Probabilita' bassa per i 3 bulk; alta per GSM004 (scRNA-Seq dichiarato).
samples_num <- list(
  singlecellprobability = c(0.02, 0.04, 0.03, 0.95)
)

# ---- Scrittura -------------------------------------------------------------
for (nm in names(samples_chr)) {
  rhdf5::h5write(samples_chr[[nm]], fix_path, paste0("meta/samples/", nm))
}
for (nm in names(samples_chr_new)) {
  rhdf5::h5write(samples_chr_new[[nm]], fix_path, paste0("meta/samples/", nm))
}
for (nm in names(samples_num)) {
  rhdf5::h5write(samples_num[[nm]], fix_path, paste0("meta/samples/", nm))
}

rhdf5::H5close()

cat(sprintf("Fixture ricostruito: %s\n", fix_path))
cat(sprintf("Size: %d bytes\n", file.info(fix_path)$size))
