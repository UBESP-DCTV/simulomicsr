# Architecture Decision Records (ADR)

Questa cartella raccoglie tutte le decisioni di scope, architettura, processo e tooling
prese sul progetto simulomicsr. Ogni ADR è immutabile una volta accettato: per cambiare
una decisione, si crea un nuovo ADR che la supersedes.

## Formato

Si usa il template [MADR](https://adr.github.io/madr/) leggero. Vedi [`template.md`](template.md).

Sezioni standard:

- **Status** — Proposed | Accepted | Deprecated | Superseded by ADR-NNNN
- **Context and Problem Statement** — perché serve decidere
- **Decision Drivers** — vincoli e priorità
- **Considered Options** — alternative valutate
- **Decision Outcome** — la scelta + perché
- **Consequences** — implicazioni positive/negative/neutrali
- **Pros and Cons of the Options** *(opzionale)* — analisi dettagliata se serve

## Convenzioni

- Numerazione progressiva a quattro cifre: `0001`, `0002`, …
- Slug kebab-case dopo il numero: `0001-sistema-tracking.md`
- Lingua: italiano (il progetto è scritto in italiano internamente; il manuale finale sarà tradotto se serve)
- Una decisione = un ADR. Niente decisioni multiple nello stesso file.
- Ogni ADR rilevante per un commit va citato nel messaggio di commit (es. `Refs ADR-0001`).

## Indice

| ID | Titolo | Status | Data |
|----|--------|--------|------|
| [0001](0001-sistema-tracking.md) | Sistema di tracking decisioni | Accepted | 2026-04-29 |
