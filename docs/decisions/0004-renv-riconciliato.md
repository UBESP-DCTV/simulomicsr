# ADR-0004: Riconciliazione renv per R 4.5 e dipendenze runtime LLM

- **Status:** Accepted
- **Date:** 2026-04-29
- **Deciders:** Luca Vedovelli
- **Supersedes:** —

## Context

Il `renv.lock` precedente era generato con R 4.2.2 mentre il sistema usa R 4.5.2.
La libreria locale del progetto era praticamente vuota (`installed.packages()`
nella libreria attiva ritornava `named character(0)`). Inoltre il `DESCRIPTION`
precedente aveva un set di dipendenze (`fs`, `purrr`, `readr`, `stringr`)
allineato a un template, non ai bisogni reali della pipeline LLM definita
nella spec del classificatore (v5).

## Decision

Procediamo con un singolo profilo renv allineato a R 4.5.x, con il set di
dipendenze runtime richieste da P1 dichiarate in `Imports:` del `DESCRIPTION`.
Il lockfile viene rigenerato con `renv::snapshot(type = "implicit")`.

Imports runtime aggiunti per P1:
`cli`, `DBI`, `digest`, `fs`, `glue`, `httr2`, `jsonlite`, `jsonvalidate`,
`purrr`, `readr`, `rlang`, `RSQLite`, `stringr`, `tibble`.

Suggests aggiunti per test/dev:
`httptest2` (mock httr2), `withr` (env vars in test), oltre al pre-esistente
testthat/devtools/knitr/rmarkdown.

`Depends: R (>= 4.4)` — compromesso fra modernità (httr2 e jsonvalidate
recenti funzionano bene su 4.4+) e portabilità.

## Consequences

- **Positive:** la pipeline è installabile/eseguibile localmente; CI può
  ricostruire un ambiente coerente da `renv.lock`.
- **Negative:** chi clona oggi deve eseguire `renv::restore()` (dipendenze
  binarie consistenti).
- **Neutral:** non sono introdotti profili `library` vs `analysis`; lockfile
  unico al livello di repo come da ADR-0002.

## Links

- ADR-0002 (struttura research compendium)
- Spec classificatore LLM v5 §5 (pipeline tecnica)
