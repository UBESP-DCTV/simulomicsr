# Script idempotente: estrae 8 sample stratificati dal xlsx come fixture
# stabili. Eseguito una sola volta (alla prima creazione del file); rieseguire
# solo se cambiano i criteri di selezione e si vuole riallineare.
#
# Selezione (8 sample):
#   - 2 EASY treated  (trtctr_EP=="treated"  & trtctr=="treated")
#   - 2 EASY control  (trtctr_EP=="control"  & trtctr=="control")
#   - 2 DISAGREE      (trtctr_EP != trtctr)  — qui sta il valore del classificatore LLM
#   - 2 SHORT/AMBIG   (nchar(string) <= 60)  — eval qualitativa di robustezza
#
# Seed = 20260502 (data del plan).

set.seed(20260502)
library(dplyr)
xlsx <- "data-raw/relevant_sample_classified.xlsx"
all <- readxl::read_excel(xlsx) |>
  dplyr::transmute(
    geo_accession = as.character(geo_accession),
    series_id     = as.character(series_id),
    string        = as.character(string),
    trtctr_EP     = as.character(trtctr_EP),
    trtctr        = as.character(trtctr),
    treat         = as.character(treat),
    gold          = as.character(gold)
  )

pick <- function(df, n) df[sample.int(nrow(df), n, replace = FALSE), , drop = FALSE]

easy_t  <- all |> filter(trtctr_EP == "treated", trtctr == "treated") |> pick(2)
easy_c  <- all |> filter(trtctr_EP == "control", trtctr == "control") |> pick(2)
disagr  <- all |> filter(trtctr_EP != trtctr) |> pick(2)
short_a <- all |> filter(nchar(string) <= 60) |> pick(2)

fix <- bind_rows(
  easy_t  |> mutate(stratum = "easy_treated"),
  easy_c  |> mutate(stratum = "easy_control"),
  disagr  |> mutate(stratum = "disagree_ep_vs_shallow"),
  short_a |> mutate(stratum = "short_ambiguous")
)

stopifnot(nrow(fix) == 8L, !any(duplicated(fix$geo_accession)))

readr::write_tsv(fix, "inst/extdata/sample-fixtures-mini.tsv")
