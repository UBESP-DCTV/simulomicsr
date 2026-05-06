# Output Schema Guide

## Is a schema required?

Yes — `create_bundle()` and `extract_batch()` always require a `schema` argument.
The schema is embedded in the bundle and included verbatim in the prompt sent to the model.
It tells the model what JSON object to return.

---

## Plain text output (no structured extraction needed)

If you just want a free-text response per record, use a minimal single-field schema:

```r
schema_text <- list(
  type       = "object",
  properties = list(
    result = list(type = "string")
  ),
  required = I("result")
)
```

The model will return `{"result": "..."}`. After collection:

```r
results <- collect_results(job)
preds   <- results$parsed$predictions
preds$parsed_json$result   # character vector, one value per record
```

---

## Structured extraction

For structured output, use standard JSON Schema syntax. R lists map directly to JSON objects.

### Single field

```r
schema <- list(
  type       = "object",
  properties = list(
    summary = list(type = "string")
  ),
  required = I("summary")
)
```

### Multiple fields

```r
schema <- list(
  type       = "object",
  properties = list(
    conditions = list(type = "array", items = list(type = "string")),
    severity   = list(type = "string")
  ),
  required = I(c("conditions", "severity"))
)
```

### Enum (controlled vocabulary)

```r
schema <- list(
  type       = "object",
  properties = list(
    label = list(type = "string", enum = I(c("positive", "negative", "neutral")))
  ),
  required = I("label")
)
```

### Nested objects

```r
schema <- list(
  type       = "object",
  properties = list(
    patient = list(
      type       = "object",
      properties = list(
        age      = list(type = "integer"),
        sex      = list(type = "string"),
        diagnoses = list(type = "array", items = list(type = "string"))
      ),
      required = I(c("age", "sex", "diagnoses"))
    )
  ),
  required = I("patient")
)
```

---

## Important: use `I()` for length-1 required arrays

In R, `c("field")` is a length-1 character vector. With `jsonlite`'s default
`auto_unbox = TRUE`, it serializes as `"field"` (string) instead of `["field"]` (array),
producing invalid JSON Schema.

The package writes `schema.json` with `auto_unbox = FALSE`, so this is handled
automatically — but if you pass a schema that already went through `toJSON` yourself,
be aware of this behaviour.

Similarly, `enum` values are always arrays in JSON Schema:

```r
# correct
enum = I(c("a", "b", "c"))

# also correct for length > 1 (auto_unbox does not fire)
enum = c("a", "b", "c")

# risky for length-1 enums
enum = I("only-option")   # use I() to be safe
```

---

## Reading results

After `collect_results()`, predictions are in `results$parsed$predictions`, a data frame
where each row is one record. The `parsed_json` column contains the structured output
as a nested list (parsed from the model's JSON response).

```r
results <- collect_results(job)
preds   <- results$parsed$predictions

# Access a field from parsed_json
preds$parsed_json   # list column — each element is the parsed JSON object
sapply(preds$parsed_json, function(x) x$severity)   # extract one field
```

If the model returned invalid JSON for a record, `parsed_json` will be `NULL` for that
row and the raw text is still available in `output_text`.

---

## Current limitations

- Schema validation is best-effort: the model output is parsed as JSON but not validated
  against the schema. Records with invalid JSON land in `errors.jsonl`.
- Constrained decoding is not yet implemented. The model can deviate from the schema.
- For critical workflows, check `results$parsed$errors` after collection.
