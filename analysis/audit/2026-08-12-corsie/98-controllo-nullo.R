# CONTROLLO: con lane_lookup = NULL il gate e' DAVVERO identico a prima?
# `.n_biological(x, NULL)` conta i campioni DISTINTI; il codice di prima contava
# `length(treated)`. Se un replicate_group ripete un campione, i due numeri
# divergono e il "non cambia nulla" sarebbe falso.
suppressMessages(devtools::load_all(".", quiet = TRUE))
SC <- "analysis/audit/2026-08-12-corsie"
s2 <- readRDS(file.path(SC, "s2.rds"))
n_rg <- 0L; n_dup <- 0L; casi <- character(0)
for (st in s2) {
  for (rg in st$replicate_groups) {
    v <- as.character(unlist(rg$sample_ids))
    n_rg <- n_rg + 1L
    if (length(v) != length(unique(v))) {
      n_dup <- n_dup + 1L
      if (length(casi) < 5L) casi <- c(casi, paste(st$series_id, rg$group_id,
        length(v), length(unique(v)), sep = "/"))
    }
  }
}
cat("replicate_group esaminati:", n_rg, "| con campioni ripetuti:", n_dup, "\n")
if (n_dup) { cat("esempi (serie/gruppo/n/n_distinti):\n"); print(casi) }
