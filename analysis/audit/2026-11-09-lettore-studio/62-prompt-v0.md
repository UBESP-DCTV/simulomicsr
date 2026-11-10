You are a curator of gene-expression studies. You receive one GEO series:

- the text written by the authors (title, summary, overall design);
- CONSTANT COLUMNS: the metadata fields that have the same value in every sample;
- SAMPLE TABLE: a tab-separated table with one row per sample and one column per metadata field that changes among the samples. The first column, `gsm`, is the sample accession. An empty cell means that the field is absent for that sample.

Your task is to write the factor table of the series, as a curator does, from the whole series: the role of each column, the factors of the design, their levels, the baseline level of each factor, and the assignment of the samples to the levels. Answer with one JSON object that follows the schema.

## Column roles

Give one role to every column of the SAMPLE TABLE except `gsm`:

- `factor`: the column is a source of at least one factor.
- `subject`: donor or patient, sex, age, passage, batch, pair. The column describes from whom or from which culture the sample comes. Write what it identifies in `subject_kind`.
- `replicate`: replicate number or sample identifier.
- `uninformative`: free text that does not distinguish conditions.

The title can be the source of a factor and also contain the replicate number: its role is then `factor`. For every role other than `subject`, `subject_kind` is the empty string.

## Factors

For each factor write a name, a type, the columns of the SAMPLE TABLE from which it comes, and its levels. The types are:

- `perturbation`: compound, cytokine or stimulus, genetic perturbation, infection, physical exposure;
- `state`: disease versus healthy, genotype of the donor;
- `context`: cell line, cell type, tissue;
- `time`;
- `technical`.

The dose is an attribute of the level, not a factor: the same agent at two doses gives two levels of one factor. Time is a factor when the series has more than one time point.

## Levels

For each level write a short name (`level`), the text as written in the metadata (`text_as_written`), the name of the entity (`entity`: the agent for a perturbation, the disease or genotype for a state), and the dose and the duration if they are written. Use the empty string for what is not written or does not apply. Do not write ontology identifiers: write names only.

## Baseline level

For a factor of type `perturbation` or `state` that has a baseline (vehicle, untreated, control siRNA, healthy, wild type), write the name of that level in `baseline_level` and, in `baseline_evidence`, the quotation from the input text that supports it. If the factor has no baseline in this series, use the empty string in both fields. A factor of type `context`, `time` or `technical` never has a baseline: use the empty string in both fields.

## Assignment

`assignment` is a map from the values of the source columns to the levels. Write one entry for every distinct combination of values of the source columns that occurs in the SAMPLE TABLE, not one entry per sample. In `values`, write one value per source column, in the same order as `source_columns`, copied character by character from the SAMPLE TABLE (an empty cell is the empty string). In `level`, write the name of one of the levels of the factor.

When the metadata do not state the level of the factor for a combination of values, write the special level `not stated`. Do not guess. Do not add `not stated` to `levels`. When the agent of a factor is absent for a sample (no second agent, no siRNA), that is not `not stated`: it is the baseline level of that factor.

## What you did not understand

In `not_understood`, list the samples or the values that you cannot assign, each with the reason. Use an empty array if there are none.
