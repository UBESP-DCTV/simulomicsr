suppressPackageStartupMessages({library(dplyr)})
SC <- "analysis/audit/2026-07-24-anchor-coherence-sim"
r <- readRDS(file.path(SC, "fase1-v7-results.rds")); pm <- r$pm
ANATOMY <- c("lung","lungs","liver","hepatic","kidney","renal","heart","cardiac","myocardium","brain",
  "cerebral","neural","colon","colorectal","rectum","intestine","ileum","gastric","stomach","breast",
  "mammary","prostate","ovary","ovarian","uterus","uterine","testis","testicular","pancreas",
  "pancreatic","spleen","thymus","thyroid","skin","cutaneous","dermal","epidermis","blood","plasma",
  "serum","bone","marrow","muscle","skeletal","placenta","retina","cornea","bladder","esophagus",
  "esophageal","oral","nasal","airway","bronchial","alveolar","synovial","adipose","aorta","artery",
  "vein","lymph","node","nodes","cervix","cervical","head","neck","tongue","salivary","pituitary",
  "adrenal","gallbladder","bile","duodenum","jejunum","tonsil","gingival","periodontal")
anatomy_of <- function(x) {
  w <- strsplit(tolower(gsub("[^a-z ]+", " ", x)), "\\s+")[[1]]
  unique(w[w %in% ANATOMY])
}
cat("=== (1) perche' 'AML (Blood) => Normal (Lung)' non e' stato droppato? ===\n")
x <- pm[grepl("Acute Myeloid Leukemia \\(Blood\\)", pm$treated_label), ]
cat("membri:", nrow(x), "\n")
if (nrow(x)) {
  cat("treated:", x$treated_label[1], "\ncontrol:", x$control_label[1], "\n")
  cat("anatomy treated:", paste(anatomy_of(x$treated_label[1]), collapse = ","), "\n")
  cat("anatomy control:", paste(anatomy_of(x$control_label[1]), collapse = ","), "\n")
  cat("dr:", paste(unique(x$dr), collapse = ","), " | entity:", paste(unique(x$entity), collapse = ","), "\n")
}
cat("\n=== (2) 'Gastric cancer PT017 => Normal liver PTN001' ===\n")
y <- pm[grepl("^Gastric cancer PT017", pm$treated_label), ]
if (nrow(y)) {
  cat("t:", y$treated_label[1], "| c:", y$control_label[1], "\n")
  cat("anat t:", paste(anatomy_of(y$treated_label[1]), collapse = ","),
      "| anat c:", paste(anatomy_of(y$control_label[1]), collapse = ","), "| dr:", y$dr[1], "\n")
}
cat("\n=== (3) entita' sbagliate: TGFB2 (poly I:C) e IL6 (HGF) ===\n")
for (E in c("HGNC:11768", "HGNC:6018")) {
  m <- pm[!is.na(pm$entity) & pm$entity == E, ]
  cat(sprintf("\n-- %s | membri=%d | onc=%d\n", E, nrow(m), sum(m$onc)))
  print(head(unique(data.frame(onc = m$onc, cand = m$ce2_cand, dtval = substr(m$dtval, 1, 40),
                               lab = substr(m$treated_label, 1, 40))), 8), row.names = FALSE)
}
cat("\n=== (4) quante classi cambiano nel delta (multi-classe)? ===\n")
print(head(sort(table(pm$dclasses[pm$elig]), decreasing = TRUE), 12))
cat("\nmembri eleggibili con >=2 classi:",
    sum(grepl("+", pm$dclasses[pm$elig], fixed = TRUE)), "/", sum(pm$elig), "\n")
cat("\n=== (5) controllo mock/uninfected (sperimentale) vs healthy/donor (clinico) ===\n")
ctl <- tolower(pm$control_label[pm$elig])
cat("mock/uninfected:", sum(grepl("mock|uninfected|non-infected|noninfected", ctl)), "\n")
cat("healthy/donor  :", sum(grepl("healthy|normal donor|control subject|volunteer", ctl)), "\n")
sars <- pm[pm$elig & !is.na(pm$entity) & pm$entity == "NCBITaxon:2697049", ]
cat("SARS: mock-controllati", sum(grepl("mock|uninfected", tolower(sars$control_label))),
    "su", nrow(sars), "membri;", n_distinct(sars$study_id), "studi\n")
