test_that(".parse_characteristics_kv: estrae coppie chiave:valore", {
  kv <- .parse_characteristics_kv("tissue: Blood, disease state: AD, cell type: PBMC")
  expect_equal(unname(kv[["disease state"]]), "ad")
  expect_equal(unname(kv[["tissue"]]), "blood")
  expect_equal(length(kv), 3L)
})

test_that(".parse_characteristics_kv: input vuoto/NA -> character(0)", {
  expect_length(.parse_characteristics_kv(NA_character_), 0L)
  expect_length(.parse_characteristics_kv(""), 0L)
})

test_that(".extract_disease_term: prende la malattia dalle characteristics", {
  d <- .extract_disease_term("Blood", "tissue: Blood, disease: Juvenile Dermatomyositis", "sample 1")
  expect_equal(d, "juvenile dermatomyositis")
})

test_that(".extract_disease_term: valori di controllo -> NA", {
  expect_true(is.na(.extract_disease_term("PBMC", "disease state: healthy", "ctrl")))
})

test_that(".extract_disease_term: fallback su source/title se niente chiave", {
  d <- .extract_disease_term("Breast Tumor", "tissue id: BRB123", "FFPE Breast Tumor sample")
  expect_equal(d, "breast tumor")
})

test_that(".extract_agent_term: prende il composto dal trattamento", {
  a <- .extract_agent_term("cells", "treatment: Bleomycin, time: 24h", "rep1")
  expect_equal(a, "bleomycin")
})

test_that(".extract_agent_term: veicolo/controllo -> NA", {
  expect_true(is.na(.extract_agent_term("cells", "treatment: DMSO", "vehicle 1")))
  expect_true(is.na(.extract_agent_term("cells", "treatment: control", "ctrl")))
})

test_that(".detect_genetic_perturbation: dTAG/degron -> genetico, non small_molecule", {
  r <- .detect_genetic_perturbation("HCT116", "cell line: HCT116", "POINT-Seq XRN2-dTAG minus dTAG rep1")
  expect_true(r$is_genetic)
  expect_match(r$genetic_kind, "genetic_")
  expect_equal(toupper(r$target), "XRN2")
})

test_that(".detect_genetic_perturbation: shRNA knockdown", {
  r <- .detect_genetic_perturbation("cells", "treatment: shTP53", "shRNA knockdown TP53")
  expect_true(r$is_genetic)
  expect_equal(r$genetic_kind, "genetic_knockdown")
})

test_that(".detect_genetic_perturbation: farmaco normale -> non genetico", {
  r <- .detect_genetic_perturbation("cells", "treatment: bleomycin", "Bleomycin 24h")
  expect_false(r$is_genetic)
})
