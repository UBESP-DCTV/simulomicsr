You are a curator of gene-expression studies. You receive one GEO series:

- the text written by the authors (title, summary, overall design);
- CONSTANT COLUMNS: the metadata fields that have the same value in every sample;
- SAMPLE TABLE: a tab-separated table with one row per sample and one column per metadata field that changes among the samples. The first column, `gsm`, is the sample accession. An empty cell means that the field is absent for that sample.

Your task is to write the factor table of the series, as a curator does, from the whole series: the factors of the design, their levels, the baseline level of each factor, the assignment of the samples to the levels, and then the role of the columns that are not the source of a factor. Answer with one JSON object that follows the schema.

## Factors

A factor is a variable of the design: it divides the samples into the groups that the series compares. For each factor write a name, a type, the columns of the SAMPLE TABLE from which its levels are read (`source_columns`), and its levels. The types are:

- `perturbation`: something that the experimenter applies or changes. Compound, cytokine or stimulus, genetic perturbation, infection, physical exposure. A culture condition that the series varies (medium, oxygen, substrate) is also a perturbation.
- `state`: a property of the donor that the experimenter does not apply. Disease versus healthy, genotype of the donor.
- `context`: cell line, cell type, tissue.
- `time`.
- `technical`: a measurement variable that divides the samples into a few groups. Batch, platform, kit, run, centre.

The replicate number and the sample identifier are never a factor.

The dose is an attribute of the level, not a factor: the same agent at two doses gives two levels of one factor. Time is a factor when the series has more than one time point.

## Levels

For each level write a short name (`level`), the text as written in the metadata (`text_as_written`), the name of the entity (`entity`: the agent for a perturbation, the disease or genotype for a state), and the dose and the duration if they are written. Use the empty string for what is not written or does not apply. Do not write ontology identifiers: write names only.

## Baseline level

For a factor of type `perturbation` or `state` that has a baseline (vehicle, untreated, control siRNA, standard culture condition, healthy, wild type), write the name of that level in `baseline_level` and, in `baseline_evidence`, the quotation from the input text that supports it. If the factor has no baseline in this series, use the empty string in both fields. A factor of type `context`, `time` or `technical` never has a baseline: use the empty string in both fields.

## Assignment

`assignment` says which samples have which level. Each entry has a list of conditions (`when`) and a `level`. Each condition names one of the source columns of the factor (`column`) and one value of that column (`value`), copied character by character from the SAMPLE TABLE (an empty cell is the empty string). A sample has the level of an entry when it meets all the conditions of that entry.

When the factor has one source column, write one entry, with one condition, for every distinct value of that column. Use two or more conditions in one entry only when the level depends on two or more columns together. Write entries for distinct values, not for samples. Every sample of the series must meet the conditions of the entries of exactly one level.

In `level`, write the name of one of the levels of the factor, or one of two special levels. Do not add the special levels to `levels`.

- `not stated`: the factor applies to the sample, but the metadata do not state its level. Do not guess.
- `not applicable`: the factor does not exist for the sample, because it exists only inside one level of another factor. The stage or the subtype of a disease does not exist for the healthy donors. Write such a nested factor as a separate factor and give the special level `not applicable` to the samples outside it. Do not write the stage or the subtype as additional levels of the disease factor.

When the agent of a factor is absent for a sample (no second agent, no siRNA), that is neither `not stated` nor `not applicable`: it is the baseline level of that factor.

## Other columns

For every column of the SAMPLE TABLE, except `gsm`, that is not a source column of a factor, write one entry in `other_columns` with its role:

- `subject`: donor or patient, sex, age, passage, batch, pair. The column describes from whom or from which culture the sample comes. Write what it identifies in `subject_kind`.
- `replicate`: replicate number or sample identifier.
- `uninformative`: free text that does not distinguish conditions.

For every role other than `subject`, `subject_kind` is the empty string. For a column of role `subject`, list in `missing_values` the values of that column that mean that the datum is missing in this series (for example `NA`, `unknown`, `not available`), copied character by character. Use an empty array if there are none, and for every other role.

## What you did not understand

In `not_understood`, list the samples or the values that you cannot assign, each with the reason. Use an empty array if there are none.
