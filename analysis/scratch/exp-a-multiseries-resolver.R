# Exp A — Misurazione distribuzione clean/ambiguous/patologico per series-id-resolver
# Throw-away analysis, NON production code.
# Input: gold-standard 130k sample.
# Output: distribuzione + 30 casi ambiguous random per ispezione manuale (Exp B).

suppressMessages({
  library(rentrez)
  library(readxl)
  library(dplyr)
  library(stringr)
})

stopifnot(nzchar(Sys.getenv("NCBI_API_KEY")))
rentrez::set_entrez_key(Sys.getenv("NCBI_API_KEY"))

# ---- 1. Load gold + estrai GSE unici ----
x <- read_excel("data-raw/relevant_sample_classified.xlsx", sheet = "relevant_sample")
x$n_series <- str_count(x$series_id, ",") + 1L
multi <- x[x$n_series >= 2, ]
cat(sprintf("Total sample: %d | Multi-series: %d (%.1f%%)\n",
            nrow(x), nrow(multi), 100 * nrow(multi) / nrow(x)))

all_split <- str_split(x$series_id, ",")
all_gses <- sort(unique(trimws(unlist(all_split))))
all_gses <- all_gses[nzchar(all_gses)]
cat(sprintf("Unique GSE totali: %d\n", length(all_gses)))

# ---- 2. Cache on-disk ----
cache_path <- "analysis/scratch/exp-a-entrez-cache.rds"
cache <- if (file.exists(cache_path)) readRDS(cache_path) else list()
cat(sprintf("Cache hit: %d / %d (%.1f%%)\n",
            sum(all_gses %in% names(cache)), length(all_gses),
            100 * sum(all_gses %in% names(cache)) / length(all_gses)))

# ---- 3. Entrez lookup function ----
SUPER_RE <- "^This SuperSeries is composed of"

lookup_gse <- function(gse) {
  if (!is.null(cache[[gse]])) return(cache[[gse]])
  res <- tryCatch({
    s <- entrez_search(db = "gds", term = paste0(gse, "[Accession]"))
    if (length(s$ids) == 0) return(list(entrytype = "NOT_FOUND", summary = NA_character_, n_samples = NA))
    gse_uids <- s$ids[grepl("^2[0-9]+$", s$ids)]
    uid <- if (length(gse_uids) > 0) gse_uids[1] else s$ids[1]
    info <- entrez_summary(db = "gds", id = uid)
    summary_text <- as.character(info$summary %||% "")
    is_super <- grepl(SUPER_RE, summary_text)
    list(
      entrytype = if (is_super) "SuperSeries" else "NotSuper",
      summary = substr(summary_text, 1, 200),
      n_samples = info$n_samples %||% NA,
      gdstype = info$gdstype %||% NA
    )
  }, error = function(e) {
    list(entrytype = "ERROR", summary = conditionMessage(e), n_samples = NA)
  })
  cache[[gse]] <<- res
  res
}

# ---- 4. Loop su tutti i GSE (resume da cache) ----
todo <- setdiff(all_gses, names(cache))
cat(sprintf("\nGSE da fetchare: %d (stima %.1f min con API key)\n",
            length(todo), length(todo) / 10 / 60))

if (length(todo) > 0) {
  t0 <- Sys.time()
  for (i in seq_along(todo)) {
    lookup_gse(todo[i])
    if (i %% 200 == 0) {
      saveRDS(cache, cache_path)
      elapsed <- as.numeric(difftime(Sys.time(), t0, units = "mins"))
      eta_min <- elapsed / i * (length(todo) - i)
      cat(sprintf("  [%d/%d] elapsed %.1f min, ETA %.1f min\n",
                  i, length(todo), elapsed, eta_min))
    }
  }
  saveRDS(cache, cache_path)
}

# ---- 5. Apply resolver su multi-series ----
type_of <- function(g) {
  if (is.null(cache[[g]])) return("MISSING")
  cache[[g]]$entrytype
}

multi$primary   <- sapply(str_split(multi$series_id, ","), function(z) trimws(z[1]))
multi$secondary <- sapply(str_split(multi$series_id, ","), function(z) trimws(z[2]))
multi$primary_type   <- sapply(multi$primary,   type_of)
multi$secondary_type <- sapply(multi$secondary, type_of)

classify_case <- function(p, s) {
  if (p == "SuperSeries" && s == "SuperSeries") return("all_super")
  if (p == "SuperSeries" || s == "SuperSeries") return("clean")
  if (p == "NotSuper" && s == "NotSuper") return("ambiguous")
  paste0("other:", p, "|", s)
}
multi$case <- mapply(classify_case, multi$primary_type, multi$secondary_type)

# ---- 6. Report distribuzione ----
cat("\n=== Distribuzione casi multi-series ===\n")
tab <- table(multi$case)
print(tab)
cat("\nPercentuali:\n")
print(round(prop.table(tab) * 100, 2))

cat(sprintf("\n=== Stima impatto ===\n"))
cat(sprintf("Sample CLEAN     : %d (resolver picks unique NotSuper)\n", sum(multi$case == "clean")))
cat(sprintf("Sample AMBIGUOUS : %d (entrambi NotSuper - decisione policy needed)\n", sum(multi$case == "ambiguous")))
cat(sprintf("Sample ALL_SUPER : %d (caso patologico)\n", sum(multi$case == "all_super")))
other_n <- sum(!multi$case %in% c("clean", "ambiguous", "all_super"))
cat(sprintf("Sample OTHER     : %d (errori lookup / not found)\n", other_n))

# ---- 7. Sample 30 ambiguous random per Exp B ----
amb <- multi[multi$case == "ambiguous", ]
if (nrow(amb) > 0) {
  set.seed(42)
  n_pick <- min(30, nrow(amb))
  picked_idx <- sample(nrow(amb), n_pick)
  picked <- amb[picked_idx, c("geo_accession", "series_id", "primary", "secondary",
                              "primary_type", "secondary_type")]
  picked$primary_summary <- sapply(picked$primary,
                                    function(g) substr(cache[[g]]$summary %||% "", 1, 100))
  picked$secondary_summary <- sapply(picked$secondary,
                                      function(g) substr(cache[[g]]$summary %||% "", 1, 100))
  picked$primary_n_samples <- sapply(picked$primary,
                                      function(g) cache[[g]]$n_samples %||% NA)
  picked$secondary_n_samples <- sapply(picked$secondary,
                                        function(g) cache[[g]]$n_samples %||% NA)
  write.csv(picked, "analysis/scratch/exp-a-ambiguous-30-sample.csv", row.names = FALSE)
  cat(sprintf("\n30 casi ambiguous random salvati in analysis/scratch/exp-a-ambiguous-30-sample.csv\n"))
  cat("Apri il CSV e ispeziona manualmente i 30 sample per capire la natura dell'ambiguità (Exp B).\n")
}

# ---- 8. Salva tutto per future analysis ----
saveRDS(multi, "analysis/scratch/exp-a-multiseries-resolved.rds")
saveRDS(cache, cache_path)
cat("\nDone. Cache + classification table salvati.\n")
