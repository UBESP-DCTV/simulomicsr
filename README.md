
<!-- README.md is generated from README.Rmd. Please edit that file -->

# simulomicsr

<!-- badges: start -->

[![check-release](https://github.com/UBESP-DCTV/simulomicsr/actions/workflows/check-release.yaml/badge.svg)](https://github.com/UBESP-DCTV/simulomicsr/actions/workflows/check-release.yaml)
[![R-CMD-check](https://github.com/UBESP-DCTV/simulomicsr/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/UBESP-DCTV/simulomicsr/actions/workflows/R-CMD-check.yaml)
[![test-coverage](https://github.com/UBESP-DCTV/simulomicsr/actions/workflows/test-coverage.yaml/badge.svg)](https://github.com/UBESP-DCTV/simulomicsr/actions/workflows/test-coverage.yaml)
[![lint](https://github.com/UBESP-DCTV/simulomicsr/actions/workflows/lint.yaml/badge.svg)](https://github.com/UBESP-DCTV/simulomicsr/actions/workflows/lint.yaml)
[![Lifecycle:
experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
<!-- badges: end -->

## Stato

simulomicsr è una pipeline R per:

1.  scaricare metadati di sample RNAseq da repository pubblici (GEO,
    ARCHS4)
2.  classificarli via LLM in fatti strutturati a livello sample (Stadio
    1)
3.  ricostruire il design dello studio e i confronti meta-analizzabili
    (Stadio 2)
4.  produrre tabelle di confronto cross-studio per `metafor` / `DESeq2`
    / `limma`

**Plan attivo (2026-04-29):** P1 — Infrastruttura LLM (cache, validator,
client OpenAI Structured Outputs, lookup gene HGNC). Vedi
`docs/superpowers/plans/`.

## Quickstart developer

``` r
# 1) Restore environment
renv::restore()

# 2) Set OpenAI key (in .Renviron.local — gitignored)
# OPENAI_API_KEY=sk-...

# 3) Run tests
devtools::test()
```

## Installation

You can install the development version of simulomicsr from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("UBESP-DCTV/simulomicsr")
```

## Code of Conduct

Please note that the simulomicsr project is released with a [Contributor
Code of
Conduct](https://contributor-covenant.org/version/2/1/CODE_OF_CONDUCT.html).
By contributing to this project, you agree to abide by its terms.
