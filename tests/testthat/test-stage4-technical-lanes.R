# Casi di accettazione della regola delle CORSIE.
#
# Ordine: prima i casi, poi il codice. I casi negativi sono piu' numerosi dei
# positivi apposta — e' la direzione in cui uno strumento sbaglia senza dare
# segno, ed e' cosi' che sono cadute le tre versioni precedenti del rilevatore
# (2026-08-09): la v1 non vedeva il confine su "_", la v2 leggeva "_R1/_R2" come
# corsie mentre in GEO sono repliche biologiche, la v3 contava le occorrenze
# invece dei campioni distinti.
#
# I casi 16-21 vengono da FALSI POSITIVI VERI trovati sul corpus il 2026-08-12:
# la regola del solo titolo unisce i POZZETTI di una piastra. Senza di essi la
# regola sarebbe entrata in produzione sbagliando piu' spesso di quanto indovina
# (su 4.360 librerie che collassano in tutto l'H5, solo il 45,3% ha
# `characteristics_ch1` identici).

meta <- function(gsm, title, series, charact = "x", source = "y") {
  data.frame(geo_accession = gsm, title = title, series_id = series,
             characteristics_ch1 = charact, source_name_ch1 = source,
             stringsAsFactors = FALSE)
}
n_lib <- function(m) {
  lk <- build_lane_library_lookup(m)
  length(unique(ifelse(is.na(lk[m$geo_accession]), m$geo_accession,
                       lk[m$geo_accession])))
}

test_that("POSITIVO: quattro corsie della stessa libreria fanno una libreria", {
  m <- meta(paste0("GSM", 1:12),
            c(paste0("ATRA1_S4_L00", 1:4), paste0("ATRA2_S5_L00", 1:4),
              paste0("ATRA3_S6_L00", 1:4)), "GSE178340")
  expect_equal(n_lib(m), 3L)
})

test_that("POSITIVO: due corsie con l'identificativo di campione nel titolo", {
  m <- meta(paste0("GSM", 1:4),
            c("SE.none sam2_L001", "SE.none sam2_L002",
              "none.IL4 sam4_L001", "none.IL4 sam4_L002"), "GSE173902")
  expect_equal(n_lib(m), 2L)
})

test_that("POSITIVO: flowcell + codice a barre uguali, corsia diversa", {
  m <- meta(paste0("GSM", 1:4),
            c("332b_C2CUGACXX_AGTCAA_L001", "332b_C2CUGACXX_AGTCAA_L002",
              "416b_C2CUGACXX_GTGGCC_L001", "416b_C2CUGACXX_GTGGCC_L002"),
            "GSE116899")
  expect_equal(n_lib(m), 2L)
})

test_that("POSITIVO: 'lane 1'/'lane 2' scritto per esteso", {
  m <- meta(paste0("GSM", 1:4),
            c("JH01_NHA_lane 1", "JH01_NHA_lane 2",
              "JH02_NHA_lane 1", "JH02_NHA_lane 2"), "GSE190615")
  expect_equal(n_lib(m), 2L)
})

test_that("NEGATIVO: _R1/_R2/_R3 in GEO sono repliche BIOLOGICHE", {
  m <- meta(paste0("GSM", 1:3), c("DU145_R1", "DU145_R2", "DU145_R3"), "GSEx")
  expect_equal(n_lib(m), 3L)
})

test_that("NEGATIVO: repliche numerate e Rep1/Rep2", {
  m1 <- meta(paste0("GSM", 1:3),
             c("Mock_ARPE19_1", "Mock_ARPE19_2", "Mock_ARPE19_3"), "GSEa")
  m2 <- meta(paste0("GSM", 1:2),
             c("LNCaP_AD_Ctrl_72h_Rep1", "LNCaP_AD_Ctrl_72h_Rep2"), "GSEb")
  m3 <- meta(paste0("GSM", 1:3), c("1118_Erl_r0", "1118_Erl_r1", "1118_Erl_r2"), "GSEc")
  m4 <- meta(paste0("GSM", 1:2),
             c("CTRL MSN01 Rep 1 (Conv)", "CTRL MSN01 Rep 2 (Conv)"), "GSEd")
  expect_equal(n_lib(m1), 3L)
  expect_equal(n_lib(m2), 2L)
  expect_equal(n_lib(m3), 3L)
  expect_equal(n_lib(m4), 2L)
})

test_that("NEGATIVO: numerazione senza separatore e codici brevi", {
  m1 <- meta(paste0("GSM", 1:3), c("D2A1", "D2A2", "D2A3"), "GSEe")
  m2 <- meta(paste0("GSM", 1:4), c("N1", "N3", "N4", "NB1"), "GSEf")
  m3 <- meta(paste0("GSM", 1:2), c("sample19_normal", "sample20_normal"), "GSEg")
  expect_equal(n_lib(m1), 3L)
  expect_equal(n_lib(m2), 4L)
  expect_equal(n_lib(m3), 2L)
})

test_that("NEGATIVO: repliche e tempi insieme", {
  m <- meta(paste0("GSM", 1:3),
            c("H23_JQ1_12h_R1", "H23_JQ1_12h_R2", "H23_JQ1_24h_R1"), "GSEh")
  expect_equal(n_lib(m), 3L)
})

test_that("NEGATIVO REALE: i POZZETTI di una piastra non sono corsie (GSE145815)", {
  # `well: L1` contro `well: L10`, e per giunta `moi: 0` contro `moi: 0.1`:
  # unirli metterebbe insieme un controllo e un trattato.
  m <- meta(paste0("GSM", 1:3),
            c("1001703001_L1", "1001703001_L10", "1001703001_L11"), "GSE145815",
            charact = c("moi: 0,well: L1", "moi: 0.1,well: L10", "moi: 0.1,well: L11"))
  expect_equal(n_lib(m), 3L)
})

test_that("NEGATIVO REALE: una piastra da 24 pozzetti coi metadati IDENTICI (GSE124742)", {
  # Qui `characteristics_ch1` non aiuta (stesso donatore): a bloccare e' la
  # cardinalita' — un flowcell Illumina ha al massimo 8 corsie.
  m <- meta(paste0("GSM", 1:24), paste0("1001200501_L", 1:24), "GSE124742",
            charact = "diabetes: nondiabetic,Sex: M,patched: FACS")
  expect_equal(n_lib(m), 24L)
})

test_that("NEGATIVO: indice di corsia fuori da 1..8", {
  m <- meta(paste0("GSM", 1:2), c("campione_L9", "campione_L12"), "GSEi")
  expect_equal(n_lib(m), 2L)
})

test_that("NEGATIVO: nove corsie sono troppe per un flowcell", {
  m <- meta(paste0("GSM", 1:9), paste0("campione_S1_L00", 1:9), "GSEl")
  expect_equal(n_lib(m), 9L)
})

test_that("NEGATIVO: metadati descrittivi diversi bloccano il collasso", {
  m <- meta(paste0("GSM", 1:2), c("campione_L001", "campione_L002"), "GSEm",
            charact = c("time: 0h", "time: 24h"))
  expect_equal(n_lib(m), 2L)
})

test_that("NEGATIVO: due studi diversi non condividono libreria", {
  m <- meta(paste0("GSM", 1:2), c("campione_L001", "campione_L002"),
            c("GSE1", "GSE2"))
  expect_equal(n_lib(m), 2L)
})

test_that(".n_biological conta le librerie, non i campioni", {
  m <- meta(paste0("GSM", 1:4), paste0("ATRA1_S4_L00", 1:4), "GSE178340")
  lk <- build_lane_library_lookup(m)
  expect_equal(.n_biological(paste0("GSM", 1:4), lk), 1L)
  expect_equal(.n_biological(paste0("GSM", 1:4), NULL), 4L)
  expect_equal(.n_biological(c("GSM1", "GSM1"), lk), 1L)
  expect_equal(.n_biological(c("ignoto1", "ignoto2"), lk), 2L)
})

test_that(".collapse_technical_lanes somma le corsie e rifa' il vettore dei ruoli", {
  m <- meta(paste0("GSM", 1:8),
            c(paste0("T1_S1_L00", 1:2), paste0("T2_S2_L00", 1:2),
              paste0("C1_S3_L00", 1:2), paste0("C2_S4_L00", 1:2)), "GSEz")
  lk <- build_lane_library_lookup(m)
  cnt <- matrix(1:24, nrow = 3,
                dimnames = list(paste0("g", 1:3), paste0("GSM", 1:8)))
  trt <- factor(rep(c("treated", "control"), each = 4L),
                levels = c("control", "treated"))
  r <- .collapse_technical_lanes(cnt, trt, lk)
  expect_equal(ncol(r$counts), 4L)
  expect_equal(as.integer(table(r$treatment)), c(2L, 2L))
  # la somma totale non cambia: nessun conteggio perso ne' duplicato
  expect_equal(sum(r$counts), sum(cnt))
  expect_equal(nrow(r$log), 4L)
})

test_that(".collapse_technical_lanes NON unisce una libreria che sta sui due bracci", {
  m <- meta(paste0("GSM", 1:4), paste0("X_S1_L00", 1:4), "GSEy")
  lk <- build_lane_library_lookup(m)
  cnt <- matrix(1:12, nrow = 3, dimnames = list(paste0("g", 1:3), paste0("GSM", 1:4)))
  trt <- factor(c("treated", "treated", "control", "control"),
                levels = c("control", "treated"))
  expect_error(.collapse_technical_lanes(cnt, trt, lk), "tutti e due i bracci")
})

test_that("lookup NULL: il conteggio e la matrice restano quelli di oggi", {
  cnt <- matrix(1:12, nrow = 3, dimnames = list(paste0("g", 1:3), paste0("GSM", 1:4)))
  trt <- factor(rep(c("treated", "control"), each = 2L), levels = c("control", "treated"))
  r <- .collapse_technical_lanes(cnt, trt, NULL)
  expect_identical(r$counts, cnt)
  expect_identical(r$treatment, trt)
  expect_equal(nrow(r$log), 0L)
})

test_that("build_lane_library_lookup non ritorna nulla quando non c'e' nulla da unire", {
  m <- meta(paste0("GSM", 1:3), c("a", "b", "c"), "GSE1")
  expect_length(build_lane_library_lookup(m), 0L)
})

test_that("la somma non trabocca l'intero: si resta in doppia precisione", {
  m <- meta(paste0("GSM", 1:2), c("x_S1_L001", "x_S1_L002"), "GSEov")
  lk <- build_lane_library_lookup(m)
  cnt <- matrix(c(2e9L, 1L, 2e9L, 1L), nrow = 2,
                dimnames = list(c("g1", "g2"), paste0("GSM", 1:2)))
  trt <- factor(c("treated", "treated"), levels = c("control", "treated"))
  r <- .collapse_technical_lanes(cnt, trt, lk)
  expect_false(anyNA(r$counts))
  expect_equal(unname(r$counts[1, 1]), 4e9)
})

test_that("una sola libreria e una sola riga non rompono la matrice", {
  m <- meta(paste0("GSM", 1:2), c("x_S1_L001", "x_S1_L002"), "GSE1r")
  lk <- build_lane_library_lookup(m)
  cnt <- matrix(c(3L, 4L), nrow = 1, dimnames = list("g1", paste0("GSM", 1:2)))
  trt <- factor(c("treated", "treated"), levels = c("control", "treated"))
  r <- .collapse_technical_lanes(cnt, trt, lk)
  expect_equal(dim(r$counts), c(1L, 1L))
  expect_equal(unname(r$counts[1, 1]), 7L)
})

test_that("un campione col titolo gia' identico a un altro NON rientra dalla finestra", {
  # `x` compare due volte identico (non e' un difetto di corsia: nessuna regola
  # lo ha unito) e c'e' anche `x_L001`. I due `x` restano fuori: le guardie non
  # sono mai state valutate su di loro.
  m <- meta(paste0("GSM", 1:3), c("x", "x", "x_L001"), "GSEfin",
            charact = c("time: 0h", "time: 24h", "time: 48h"))
  lk <- build_lane_library_lookup(m)
  expect_false("GSM1" %in% names(lk))
  expect_false("GSM2" %in% names(lk))
  expect_equal(n_lib(m), 3L)
})

test_that("i due registri arrivano dentro qc_report, non solo negli attributi", {
  # `arrow::write_parquet` perde gli attributi: un registro che vive solo li'
  # non arriva su disco. Era il caso del registro dei conflitti di ruolo.
  skip_if_not(exists(".empty_role_conflict_log", envir = asNamespace("simulomicsr"),
                     inherits = FALSE))
  m <- meta(paste0("GSM", 1:4), paste0("A_S1_L00", 1:2), "GSEreg")
  m$title <- c("A_S1_L001", "A_S1_L002", "B_S2_L001", "B_S2_L002")
  lk <- build_lane_library_lookup(m)
  cnt <- matrix(1:20, nrow = 5, dimnames = list(paste0("g", 1:5), paste0("GSM", 1:4)))
  trt <- factor(c("treated", "treated", "control", "control"),
                levels = c("control", "treated"))
  r <- .collapse_technical_lanes(cnt, trt, lk)
  expect_equal(names(r$log), c("libreria", "n_campioni", "campioni"))
  expect_equal(nrow(r$log), 2L)
})
