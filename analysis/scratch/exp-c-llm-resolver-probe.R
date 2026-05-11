# Exp C — Proof-of-concept: usa LLM commerciale (Claude Sonnet 4.6) come resolver
# informed per i casi ambiguous (Op3-variant).
# Su 30 sample ambiguous random dal CSV di Exp A.

suppressMessages({
  library(httr2)
  library(jsonlite)
  library(readxl)
  library(dplyr)
})

stopifnot(nzchar(Sys.getenv("ANTHROPIC_API_KEY")))

# ---- 1. Load 30 ambiguous sample ----
amb30 <- read.csv("analysis/scratch/exp-a-ambiguous-30-sample.csv",
                  stringsAsFactors = FALSE)
cat("Loaded", nrow(amb30), "ambiguous sample\n")

# Need sample 'string' (characteristics_ch1) from gold
gold <- read_excel("data-raw/relevant_sample_classified.xlsx", sheet = "relevant_sample")
amb30$string <- gold$string[match(amb30$geo_accession, gold$geo_accession)]

# ---- 2. Prompt builder ----
build_prompt <- function(row) {
  paste0(
    "You are classifying a GEO biological sample to its true study of origin.\n\n",
    "SAMPLE METADATA (characteristics_ch1 from GEO):\n", row$string, "\n\n",
    "The sample (", row$geo_accession, ") is registered under TWO GEO series accessions. ",
    "Decide which one is the primary scientific context: the experimental study the sample was generated FOR. ",
    "If the sample legitimately serves as a node (e.g., shared control) in BOTH experiments, output 'both'. ",
    "If the descriptions are too similar to distinguish, output 'unclear'.\n\n",
    "SERIES A: ", row$primary, " (n_samples=", row$primary_n_samples, ")\n",
    "Summary A: ", row$primary_summary, "\n\n",
    "SERIES B: ", row$secondary, " (n_samples=", row$secondary_n_samples, ")\n",
    "Summary B: ", row$secondary_summary, "\n\n",
    "Output STRICT JSON only (no other text), with fields:\n",
    "  choice: 'A' | 'B' | 'both' | 'unclear'\n",
    "  confidence: 0.0-1.0\n",
    "  reasoning: brief (max 30 words)"
  )
}

# ---- 3. API call ----
call_claude <- function(prompt, model = "claude-sonnet-4-6") {
  resp <- request("https://api.anthropic.com/v1/messages") |>
    req_headers(
      "x-api-key" = Sys.getenv("ANTHROPIC_API_KEY"),
      "anthropic-version" = "2023-06-01",
      "content-type" = "application/json"
    ) |>
    req_body_json(list(
      model = model,
      max_tokens = 250,
      messages = list(list(role = "user", content = prompt))
    )) |>
    req_timeout(30) |>
    req_perform()
  content <- resp_body_json(resp)
  text <- content$content[[1]]$text
  # Strip markdown code fences (```json ... ``` or ``` ... ```)
  text_clean <- gsub("^\\s*```(?:json)?\\s*\\n?", "", text, perl = TRUE)
  text_clean <- gsub("\\n?\\s*```\\s*$", "", text_clean, perl = TRUE)
  text_clean <- trimws(text_clean)
  parsed <- tryCatch(fromJSON(text_clean), error = function(e) {
    list(choice = "PARSE_ERROR", confidence = 0, reasoning = paste("PARSE:", substr(text, 1, 100)))
  })
  list(
    choice = parsed$choice %||% "NA",
    confidence = parsed$confidence %||% NA,
    reasoning = parsed$reasoning %||% "",
    input_tokens = content$usage$input_tokens %||% NA,
    output_tokens = content$usage$output_tokens %||% NA
  )
}

# ---- 4. Run on 30 samples ----
results <- vector("list", nrow(amb30))
total_in <- 0
total_out <- 0
t0 <- Sys.time()

for (i in seq_len(nrow(amb30))) {
  r <- amb30[i, ]
  prompt <- build_prompt(r)
  resp <- tryCatch(call_claude(prompt),
                   error = function(e) list(choice = "ERROR",
                                            confidence = 0,
                                            reasoning = conditionMessage(e),
                                            input_tokens = NA,
                                            output_tokens = NA))
  results[[i]] <- list(
    i = i,
    geo_accession = r$geo_accession,
    primary = r$primary,
    secondary = r$secondary,
    pair_key = paste(pmin(r$primary, r$secondary), pmax(r$primary, r$secondary), sep = "|"),
    string = substr(r$string %||% "", 1, 80),
    choice = resp$choice,
    confidence = resp$confidence,
    reasoning = resp$reasoning,
    input_tokens = resp$input_tokens,
    output_tokens = resp$output_tokens
  )
  total_in <- total_in + (resp$input_tokens %||% 0)
  total_out <- total_out + (resp$output_tokens %||% 0)
  cat(sprintf("[%d/30] %s -> %s (conf %.2f): %s\n",
              i, r$geo_accession, resp$choice,
              resp$confidence %||% NA,
              substr(resp$reasoning, 1, 80)))
}

elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

# ---- 5. Save results ----
df <- do.call(rbind, lapply(results, function(x) {
  data.frame(t(unlist(x[c("i", "geo_accession", "primary", "secondary", "pair_key",
                           "string", "choice", "confidence", "reasoning",
                           "input_tokens", "output_tokens")])),
             stringsAsFactors = FALSE)
}))
write.csv(df, "analysis/scratch/exp-c-llm-resolver-30.csv", row.names = FALSE)

# ---- 6. Report ----
cat(sprintf("\n=== Stats run ===\n"))
cat(sprintf("Elapsed: %.1f sec\n", elapsed))
cat(sprintf("Total input tokens: %d | output tokens: %d\n", total_in, total_out))
# Pricing Claude Sonnet 4.6: $3/M input + $15/M output
cost <- (total_in / 1e6) * 3 + (total_out / 1e6) * 15
cat(sprintf("Cost: $%.4f (sonnet-4-6 @ $3/$15 per 1M tok)\n", cost))
# Stima cost full ambiguous run
ratio <- 3353 / 30
cat(sprintf("Cost extrapolato 3353 ambiguous: $%.2f\n", cost * ratio))

cat("\n=== Distribuzione choices ===\n")
print(table(df$choice))

cat("\n=== Distribuzione choices per pair (top pair) ===\n")
top_pair <- names(sort(table(df$pair_key), decreasing = TRUE))[1]
cat(sprintf("Top pair: %s\n", top_pair))
print(table(df$choice[df$pair_key == top_pair]))

cat("\nDone. Output: analysis/scratch/exp-c-llm-resolver-30.csv\n")
