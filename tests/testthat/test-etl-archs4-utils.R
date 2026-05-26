test_that("build_sample_string_format_B concatena title + source + characteristics", {
  result <- build_sample_string_format_B(
    title = "RNA-seq of MCF7 tamoxifen 24h",
    source_name_ch1 = "MCF7 cell line",
    characteristics_ch1 = "cell line: MCF7,treatment: tamoxifen 1uM,timepoint: 24h"
  )
  expect_equal(
    result,
    "title: RNA-seq of MCF7 tamoxifen 24h,source: MCF7 cell line,cell line: MCF7,treatment: tamoxifen 1uM,timepoint: 24h"
  )
})

test_that("build_sample_string_format_B gestisce NA/empty graceful", {
  expect_equal(
    build_sample_string_format_B(NA, "src", "key: value"),
    "source: src,key: value"
  )
  expect_equal(
    build_sample_string_format_B("", "", "key: value"),
    "key: value"
  )
  expect_equal(
    build_sample_string_format_B(NA, NA, NA),
    ""
  )
})

test_that("is_sample_classifiable filtra organism, library_strategy, string length", {
  expect_true(is_sample_classifiable("Homo sapiens", "RNA-Seq", "title: x,key: very long enough metadata"))
  expect_false(is_sample_classifiable("Mus musculus", "RNA-Seq", "title: x,key: y val"))
  expect_false(is_sample_classifiable("Homo sapiens", "scRNA-seq", "title: x,key: very long metadata"))
  expect_false(is_sample_classifiable("Homo sapiens", "RNA-Seq", "short"))
})

# ============================================================================
# is_single_cell_protocol() — P5 audit RED_ALERT C2, spec B3
# ============================================================================
# Pattern Gruppo K (kit-specific) + Gruppo S (semantica) + title-bulk rescue.
# Fixture vincolante: docs/superpowers/specs/2026-05-26-B3-parsing-extract-protocol-sc.md
# §"Test fixture (definizione vincolante per C5 tests)".

test_that("is_single_cell_protocol gruppo K - kit/platform single-cell -> TRUE", {
  # 10x Genomics Chromium.
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "10x Genomics Chromium Single Cell 3' v3 Kit",
    title = "PBMC scRNA-seq donor1",
    source_name_ch1 = "PBMC"
  ))
  # SmartSeq2.
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "Single cells were sorted into 96-well plates and Smart-seq2 protocol was applied",
    title = "T cell SS2 plate1",
    source_name_ch1 = "T cells"
  ))
  # Fluidigm C1.
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "C1 Single-Cell Auto Prep IFC (Fluidigm) for SC capture",
    title = "Hepatocyte Fluidigm",
    source_name_ch1 = "Liver"
  ))
  # ICELL8.
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "ICELL8 single cell platform (Wafergen)",
    title = "Brain cortex",
    source_name_ch1 = "Cortex"
  ))
  # Drop-seq.
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "Drop-seq beads + microfluidic device",
    title = "Retina Drop-seq",
    source_name_ch1 = "Retina"
  ))
  # Seq-Well.
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "Seq-Well protocol on 86k cells",
    title = "PBMC Seq-Well",
    source_name_ch1 = "Blood"
  ))
  # BD Rhapsody.
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "BD Rhapsody cartridge",
    title = "Tumor BD",
    source_name_ch1 = "Tumor"
  ))
  # CellPlex multiplexing.
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "3' CellPlex Kit multiplexing",
    title = "Sample multiplexed",
    source_name_ch1 = "PBMC"
  ))
  # CellTag in title (catturato via union extract|title|src).
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "Standard RNA extraction",
    title = "celltag1_ispinesib_day3_CellTag",
    source_name_ch1 = "Fibroblast"
  ))
})

test_that("is_single_cell_protocol gruppo S - semantica single-cell -> TRUE", {
  # single_cell_literal.
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "Single cell RNAseq was performed per Picelli et al.",
    title = "Sample 1",
    source_name_ch1 = "Cells"
  ))
  # single_nucle.
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "Single nuclear capture and Dounce homogenization",
    title = "Brain nuclei",
    source_name_ch1 = "Brain"
  ))
  # snRNA.
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "snRNA-seq libraries from Drop-seq adaptation",
    title = "Sample sn",
    source_name_ch1 = "Adipose"
  ))
  # scRNA.
  expect_true(is_single_cell_protocol(
    extract_protocol_ch1 = "scRNA-seq libraries Chromium platform",
    title = "Sample sc",
    source_name_ch1 = "Liver"
  ))
})

test_that("is_single_cell_protocol negative - bulk standard -> FALSE", {
  # Empty.
  expect_false(is_single_cell_protocol("", "", ""))
  # Bulk TRIzol/TruSeq.
  expect_false(is_single_cell_protocol(
    extract_protocol_ch1 = "TRIzol total RNA + TruSeq Stranded mRNA Library Prep Kit",
    title = "Bulk sample 1",
    source_name_ch1 = "Tissue"
  ))
  # 10x false positive (10x buffer NON 10x Genomics).
  expect_false(is_single_cell_protocol(
    extract_protocol_ch1 = "10x SDS buffer + 10x SSC wash",
    title = "Bulk RNA",
    source_name_ch1 = "Tissue"
  ))
  # Smart-3SEQ esplicitamente escluso.
  expect_false(is_single_cell_protocol(
    extract_protocol_ch1 = "Smart-3SEQ Foley 2019 bulk 3'-tag RNA-seq",
    title = "S3 bulk",
    source_name_ch1 = "Tissue"
  ))
  # QuantSeq bulk-low-input.
  expect_false(is_single_cell_protocol(
    extract_protocol_ch1 = "Lexogen QuantSeq 3' mRNA-Seq Library Prep Kit",
    title = "QS sample",
    source_name_ch1 = "Tissue"
  ))
  # PAXgene bulk standard.
  expect_false(is_single_cell_protocol(
    extract_protocol_ch1 = "PAXgene Blood RNA Kit + GlobinClear + Illumina mRNA-Seq",
    title = "Blood patient 1",
    source_name_ch1 = "Whole blood"
  ))
})

test_that("is_single_cell_protocol title-bulk rescue - sample bulk in studio multi-modality -> FALSE", {
  # Rescue multi-modal: extract cita SC ma title contiene "bulk".
  expect_false(is_single_cell_protocol(
    extract_protocol_ch1 = "Single cells sorted Smart-seq2",
    title = "Sample-106 (Total Bulk RNA-seq)",
    source_name_ch1 = "Tissue"
  ))
  # Rescue bulk-low-input: extract menziona SC kit ma title dice esplicitamente bulk.
  expect_false(is_single_cell_protocol(
    extract_protocol_ch1 = "For bulk RNA-seq, 100 sorted cells using Smart-seq2 protocol",
    title = "Bulk_RNA-Seq_HSC_donor1",
    source_name_ch1 = "Bone marrow"
  ))
})

test_that("is_single_cell_protocol vettoriale - input/output stessa lunghezza", {
  out <- is_single_cell_protocol(
    extract_protocol_ch1 = c("10x Genomics Chromium", "TRIzol bulk", "scRNA-seq", ""),
    title = c("s1", "s2", "s3", "s4"),
    source_name_ch1 = c("PBMC", "Tissue", "Liver", "Blood")
  )
  expect_length(out, 4L)
  expect_true(is.logical(out))
  expect_equal(out, c(TRUE, FALSE, TRUE, FALSE))
})
