# Exp D — Multi-model comparison resolver con feature arricchite.
# Estende prompt con SRP cross-link, publication date, jaccard sample lists, pubmed.
# Chiama 2 modelli (Claude Sonnet 4.6 + GPT-5.5) sui 30 ambiguous sample.
# Mistral local skippato per ora (richiede MISTRAL_API_KEY o DGX job).

suppressMessages({
  library(httr2)
  library(jsonlite)
  library(rentrez)
  library(readxl)
})

stopifnot(nzchar(Sys.getenv("ANTHROPIC_API_KEY")))
stopifnot(nzchar(Sys.getenv("OPENAI_API_KEY")))
stopifnot(nzchar(Sys.getenv("NCBI_API_KEY")))
rentrez::set_entrez_key(Sys.getenv("NCBI_API_KEY"))

# ---- 1. Load 30 ambiguous + string ----
amb30 <- read.csv("analysis/scratch/exp-a-ambiguous-30-sample.csv", stringsAsFactors = FALSE)
gold <- read_excel("data-raw/relevant_sample_classified.xlsx", sheet = "relevant_sample")
amb30$string <- gold$string[match(amb30$geo_accession, gold$geo_accession)]

# ---- 2. Identifica GSE coinvolti, fetch extended Entrez metadata ----
unique_gse <- unique(c(amb30$primary, amb30$secondary))
cat(sprintf("Fetching extended metadata per %d GSE coinvolti\n", length(unique_gse)))

ext_cache_path <- "analysis/scratch/exp-d-entrez-extended.rds"
ext_cache <- if (file.exists(ext_cache_path)) readRDS(ext_cache_path) else list()

get_gse_uid <- function(gse) {
  s <- entrez_search(db = "gds", term = paste0(gse, "[Accession]"))
  if (length(s$ids) == 0) return(NA)
  gse_uids <- s$ids[grepl("^2[0-9]+$", s$ids)]
  if (length(gse_uids) > 0) gse_uids[1] else s$ids[1]
}

lookup_extended <- function(gse) {
  if (!is.null(ext_cache[[gse]])) return(ext_cache[[gse]])
  res <- tryCatch({
    uid <- get_gse_uid(gse)
    if (is.na(uid)) return(list(uid = NA, pdat = NA, srp = NA, samples = character(0), pubmedids = character(0)))
    info <- entrez_summary(db = "gds", id = uid)
    srp <- NA
    if (length(info$extrelations) > 0 && is.data.frame(info$extrelations)) {
      sra_row <- info$extrelations[info$extrelations$relationtype == "SRA", ]
      if (nrow(sra_row) > 0) srp <- sra_row$targetobject[1]
    }
    samples <- character(0)
    if (length(info$samples) > 0) {
      samples <- if (is.data.frame(info$samples)) info$samples$accession else as.character(info$samples)
    }
    pubmedids <- if (length(info$pubmedids) > 0) as.character(unlist(info$pubmedids)) else character(0)
    list(
      uid = uid,
      pdat = info$pdat %||% NA,
      srp = srp,
      n_samples = info$n_samples %||% NA,
      samples = samples,
      pubmedids = pubmedids,
      title = info$title %||% NA,
      seriestitle = info$seriestitle %||% NA
    )
  }, error = function(e) list(uid = NA, pdat = NA, srp = NA, samples = character(0), pubmedids = character(0), error = conditionMessage(e)))
  ext_cache[[gse]] <<- res
  res
}

t0 <- Sys.time()
for (i in seq_along(unique_gse)) {
  lookup_extended(unique_gse[i])
  if (i %% 5 == 0) saveRDS(ext_cache, ext_cache_path)
}
saveRDS(ext_cache, ext_cache_path)
cat(sprintf("Fetch extended done in %.1f sec\n", as.numeric(difftime(Sys.time(), t0, units = "secs"))))

# ---- 3. Calculate per-pair derived features ----
pair_features <- function(g_a, g_b) {
  a <- ext_cache[[g_a]]
  b <- ext_cache[[g_b]]
  srp_match <- !is.na(a$srp) && !is.na(b$srp) && a$srp == b$srp
  d_a <- tryCatch(as.Date(a$pdat), error = function(e) NA)
  d_b <- tryCatch(as.Date(b$pdat), error = function(e) NA)
  days_apart <- if (!is.na(d_a) && !is.na(d_b)) as.numeric(d_b - d_a) else NA
  num_a <- as.numeric(gsub("GSE", "", g_a))
  num_b <- as.numeric(gsub("GSE", "", g_b))
  acc_order_a_first <- num_a < num_b
  sa <- a$samples
  sb <- b$samples
  jaccard <- if (length(sa) > 0 && length(sb) > 0) length(intersect(sa, sb)) / length(union(sa, sb)) else NA
  contain_a_in_b <- if (length(sa) > 0 && length(sb) > 0) length(intersect(sa, sb)) / length(sa) else NA
  contain_b_in_a <- if (length(sa) > 0 && length(sb) > 0) length(intersect(sa, sb)) / length(sb) else NA
  pubmed_overlap <- if (length(a$pubmedids) > 0 && length(b$pubmedids) > 0) length(intersect(a$pubmedids, b$pubmedids)) > 0 else NA
  list(
    srp_a = a$srp, srp_b = b$srp, srp_match = srp_match,
    pdat_a = a$pdat, pdat_b = b$pdat, days_apart = days_apart,
    n_a = a$n_samples, n_b = b$n_samples,
    acc_order_a_first = acc_order_a_first,
    jaccard = jaccard,
    contain_a_in_b = contain_a_in_b,
    contain_b_in_a = contain_b_in_a,
    pubmed_overlap = pubmed_overlap,
    pmid_a = paste(a$pubmedids, collapse = ","),
    pmid_b = paste(b$pubmedids, collapse = ",")
  )
}

amb30$features <- lapply(seq_len(nrow(amb30)), function(i) pair_features(amb30$primary[i], amb30$secondary[i]))

# ---- 4. Enriched prompt builder ----
build_prompt <- function(row, feat) {
  paste0(
    "You are deciding which of two GEO series is the primary scientific context of a biological sample.\n\n",
    "SAMPLE: ", row$geo_accession, "\n",
    "Sample metadata (characteristics_ch1): ", row$string, "\n\n",
    "Two GEO series share this sample:\n\n",
    "SERIES A (", row$primary, "):\n",
    "  Title: ", ext_cache[[row$primary]]$title %||% "NA", "\n",
    "  Summary: ", row$primary_summary, "\n",
    "  Publication date: ", feat$pdat_a, "\n",
    "  N total samples: ", feat$n_a, "\n",
    "  SRA project (SRP): ", feat$srp_a %||% "none", "\n",
    "  PubMed: ", feat$pmid_a, "\n\n",
    "SERIES B (", row$secondary, "):\n",
    "  Title: ", ext_cache[[row$secondary]]$title %||% "NA", "\n",
    "  Summary: ", row$secondary_summary, "\n",
    "  Publication date: ", feat$pdat_b, "\n",
    "  N total samples: ", feat$n_b, "\n",
    "  SRA project (SRP): ", feat$srp_b %||% "none", "\n",
    "  PubMed: ", feat$pmid_b, "\n\n",
    "DERIVED SIGNALS:\n",
    "  SRP match (same underlying experiment in SRA): ", feat$srp_match, "\n",
    "  Days between publication: ", feat$days_apart, " (negative = B before A)\n",
    "  Sample list Jaccard (|A∩B| / |A∪B|): ", round(feat$jaccard, 3), "\n",
    "  Containment A->B (|A∩B|/|A|): ", round(feat$contain_a_in_b, 3), "\n",
    "  Containment B->A (|A∩B|/|B|): ", round(feat$contain_b_in_a, 3), "\n",
    "  Accession A < B (A submitted first numerically): ", feat$acc_order_a_first, "\n",
    "  Shared PubMed: ", feat$pubmed_overlap, "\n\n",
    "Decide:\n",
    "- If SRP match=TRUE, the two series are GEO-views of one SRA experiment -> output 'merge' (same study).\n",
    "- If one is contained in the other (containment ~1.0), the smaller is likely the specific study, larger is aggregate -> choose the smaller.\n",
    "- Otherwise reason based on the signals.\n\n",
    "Output STRICT JSON (no markdown, no code fence), schema:\n",
    "{\"choice\": \"A\" | \"B\" | \"merge\" | \"unclear\", \"confidence\": <0..1>, \"reasoning\": \"<max 40 words>\"}"
  )
}

# ---- 5. Strip markdown helper ----
strip_md <- function(text) {
  text <- gsub("^\\s*```(?:json)?\\s*\\n?", "", text, perl = TRUE)
  text <- gsub("\\n?\\s*```\\s*$", "", text, perl = TRUE)
  trimws(text)
}

# ---- 6. Claude call ----
call_claude <- function(prompt, model = "claude-sonnet-4-6") {
  resp <- request("https://api.anthropic.com/v1/messages") |>
    req_headers(
      "x-api-key" = Sys.getenv("ANTHROPIC_API_KEY"),
      "anthropic-version" = "2023-06-01",
      "content-type" = "application/json"
    ) |>
    req_body_json(list(
      model = model,
      max_tokens = 300,
      messages = list(list(role = "user", content = prompt))
    )) |>
    req_timeout(30) |>
    req_perform()
  content <- resp_body_json(resp)
  text <- strip_md(content$content[[1]]$text)
  parsed <- tryCatch(fromJSON(text), error = function(e) list(choice = "PARSE_ERROR", reasoning = substr(text, 1, 120)))
  list(choice = parsed$choice %||% "NA", confidence = parsed$confidence %||% NA,
       reasoning = parsed$reasoning %||% "",
       in_tok = content$usage$input_tokens %||% NA, out_tok = content$usage$output_tokens %||% NA)
}

# ---- 7. OpenAI call ----
call_gpt <- function(prompt, model = "gpt-5.5") {
  resp <- request("https://api.openai.com/v1/chat/completions") |>
    req_headers(
      "Authorization" = paste("Bearer", Sys.getenv("OPENAI_API_KEY")),
      "content-type" = "application/json"
    ) |>
    req_body_json(list(
      model = model,
      messages = list(list(role = "user", content = prompt)),
      response_format = list(type = "json_object")
    )) |>
    req_timeout(60) |>
    req_perform()
  content <- resp_body_json(resp)
  text <- strip_md(content$choices[[1]]$message$content)
  parsed <- tryCatch(fromJSON(text), error = function(e) list(choice = "PARSE_ERROR", reasoning = substr(text, 1, 120)))
  list(choice = parsed$choice %||% "NA", confidence = parsed$confidence %||% NA,
       reasoning = parsed$reasoning %||% "",
       in_tok = content$usage$prompt_tokens %||% NA, out_tok = content$usage$completion_tokens %||% NA)
}

# ---- 8. Run both models in sequence per sample (avoid rate-limit) ----
results <- vector("list", nrow(amb30))
totals <- list(claude_in = 0, claude_out = 0, gpt_in = 0, gpt_out = 0)
t0 <- Sys.time()

for (i in seq_len(nrow(amb30))) {
  r <- amb30[i, ]
  feat <- r$features[[1]]
  prompt <- build_prompt(r, feat)

  claude_resp <- tryCatch(call_claude(prompt),
                          error = function(e) list(choice = "ERROR", reasoning = conditionMessage(e), in_tok = 0, out_tok = 0, confidence = 0))
  gpt_resp <- tryCatch(call_gpt(prompt),
                       error = function(e) list(choice = "ERROR", reasoning = conditionMessage(e), in_tok = 0, out_tok = 0, confidence = 0))

  totals$claude_in <- totals$claude_in + (claude_resp$in_tok %||% 0)
  totals$claude_out <- totals$claude_out + (claude_resp$out_tok %||% 0)
  totals$gpt_in <- totals$gpt_in + (gpt_resp$in_tok %||% 0)
  totals$gpt_out <- totals$gpt_out + (gpt_resp$out_tok %||% 0)

  results[[i]] <- list(
    i = i,
    geo = r$geo_accession,
    primary = r$primary,
    secondary = r$secondary,
    pair = paste(pmin(r$primary, r$secondary), pmax(r$primary, r$secondary), sep = "|"),
    srp_match = feat$srp_match,
    jaccard = round(feat$jaccard %||% NA, 3),
    contain_a_in_b = round(feat$contain_a_in_b %||% NA, 3),
    contain_b_in_a = round(feat$contain_b_in_a %||% NA, 3),
    days_apart = feat$days_apart,
    claude_choice = claude_resp$choice,
    claude_conf = claude_resp$confidence,
    gpt_choice = gpt_resp$choice,
    gpt_conf = gpt_resp$confidence,
    agreement = identical(claude_resp$choice, gpt_resp$choice),
    claude_reasoning = substr(claude_resp$reasoning, 1, 80),
    gpt_reasoning = substr(gpt_resp$reasoning, 1, 80)
  )

  cat(sprintf("[%d/30] %s | SRP_match=%s J=%.2f | Claude=%s(%.2f) GPT=%s(%.2f) agree=%s\n",
              i, r$geo_accession, feat$srp_match,
              feat$jaccard %||% NA,
              claude_resp$choice, claude_resp$confidence %||% NA,
              gpt_resp$choice, gpt_resp$confidence %||% NA,
              identical(claude_resp$choice, gpt_resp$choice)))
}

elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

# ---- 9. Save results ----
df <- do.call(rbind, lapply(results, function(x) {
  data.frame(t(unlist(x)), stringsAsFactors = FALSE)
}))
write.csv(df, "analysis/scratch/exp-d-llm-resolver-30.csv", row.names = FALSE)

# ---- 10. Report ----
cat(sprintf("\n=== Stats run ===\n"))
cat(sprintf("Elapsed: %.1f sec\n", elapsed))
cat(sprintf("Claude tokens: in %d / out %d\n", totals$claude_in, totals$claude_out))
cat(sprintf("GPT-5 tokens: in %d / out %d\n", totals$gpt_in, totals$gpt_out))
# Pricing
claude_cost <- (totals$claude_in / 1e6) * 3 + (totals$claude_out / 1e6) * 15
gpt_cost <- (totals$gpt_in / 1e6) * 5 + (totals$gpt_out / 1e6) * 15  # rough GPT-5.5 pricing
cat(sprintf("Cost Claude: $%.4f, GPT-5.5: $%.4f (rough)\n", claude_cost, gpt_cost))
cat(sprintf("Extrapolated 3353 ambiguous: Claude $%.2f, GPT-5.5 $%.2f\n",
            claude_cost * 3353/30, gpt_cost * 3353/30))

cat("\n=== Distribuzioni choices ===\n")
cat("Claude:\n"); print(table(df$claude_choice))
cat("\nGPT-5.5:\n"); print(table(df$gpt_choice))
cat("\n=== Inter-model agreement ===\n")
cat(sprintf("Claude == GPT: %d / 30 (%.1f%%)\n",
            sum(df$agreement == "TRUE"), 100 * sum(df$agreement == "TRUE") / 30))
cat("\nCross-tab Claude × GPT-5.5:\n")
print(table(df$claude_choice, df$gpt_choice))

cat("\n=== Feature predictiveness ===\n")
cat("Quanti pair hanno srp_match=TRUE?\n")
print(table(df$srp_match))
cat("\nDistribuzione choice per srp_match:\n")
print(table(df$claude_choice, df$srp_match))
print(table(df$gpt_choice, df$srp_match))

cat("\nDone. Output: analysis/scratch/exp-d-llm-resolver-30.csv\n")
