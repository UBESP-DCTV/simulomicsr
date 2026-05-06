# Internal chunking helpers -------------------------------------------------

# Heuristic fallback used before binding to a model-specific tokenizer.
.estimate_text_tokens <- function(text, chars_per_token = 4) {
  text <- as.character(text %||% "")
  text[is.na(text)] <- ""
  text <- enc2utf8(text)
  bytes <- nchar(text, type = "bytes", allowNA = FALSE, keepNA = FALSE)
  pmax(1L, ceiling(bytes / chars_per_token))
}

.plan_chunks_greedy <- function(
  text,
  max_context_tokens,
  prompt_overhead_tokens,
  output_reserve_per_record,
  target_context_fraction = 0.70,
  max_records_per_chunk = Inf,
  chars_per_token = 4
) {
  text <- as.character(text)
  n <- length(text)

  if (n < 1L) {
    return(data.frame(
      chunk_id = integer(),
      start_index = integer(),
      end_index = integer(),
      record_count = integer(),
      estimated_tokens = integer(),
      oversize = logical()
    ))
  }

  budget <- floor(as.numeric(max_context_tokens) * as.numeric(target_context_fraction))
  input_tokens <- .estimate_text_tokens(text, chars_per_token = chars_per_token)
  record_cost <- input_tokens + as.integer(output_reserve_per_record)

  chunk_id <- integer(0)
  start_index <- integer(0)
  end_index <- integer(0)
  record_count <- integer(0)
  estimated_tokens <- integer(0)
  oversize <- logical(0)

  i <- 1L
  current_chunk <- 0L

  while (i <= n) {
    current_chunk <- current_chunk + 1L
    start <- i
    current_cost <- as.integer(prompt_overhead_tokens)
    count <- 0L
    this_oversize <- FALSE

    repeat {
      next_cost <- current_cost + record_cost[[i]]
      next_count <- count + 1L
      can_fit_tokens <- next_cost <= budget
      can_fit_count <- next_count <= max_records_per_chunk

      if (count == 0L && !can_fit_tokens) {
        current_cost <- next_cost
        count <- 1L
        this_oversize <- TRUE
        break
      }

      if (!can_fit_tokens || !can_fit_count) {
        break
      }

      current_cost <- next_cost
      count <- next_count

      if (i == n) {
        break
      }

      i <- i + 1L
    }

    finish <- start + count - 1L

    chunk_id <- c(chunk_id, current_chunk)
    start_index <- c(start_index, start)
    end_index <- c(end_index, finish)
    record_count <- c(record_count, count)
    estimated_tokens <- c(estimated_tokens, current_cost)
    oversize <- c(oversize, this_oversize)

    i <- finish + 1L
  }

  data.frame(
    chunk_id = chunk_id,
    start_index = start_index,
    end_index = end_index,
    record_count = record_count,
    estimated_tokens = estimated_tokens,
    oversize = oversize
  )
}
