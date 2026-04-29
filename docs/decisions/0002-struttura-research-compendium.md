# ADR-0002: Struttura repo come research compendium

- **Status:** Accepted
- **Date:** 2026-04-29
- **Deciders:** Luca Vedovelli
- **Supersedes:** —
- **Superseded by:** —

## Context and Problem Statement

Il repo è stato inizializzato come pacchetto R con `targets`, `renv` e infrastruttura di sviluppo completa. Tuttavia il progetto reale è una pipeline che esegue uno studio specifico (RNAseq da repository pubblico → classificazione LLM → meta-analisi cross-studio). La struttura attuale mescola due ruoli:

- **Libreria**: funzioni riusabili (in `R/`, testate, documentate, distribuibili)
- **Applicazione**: pipeline `targets` che produce i risultati di QUESTO studio

I `_targets.*` vivono attualmente nella root del pacchetto, e il `_targets.yaml` punta a un path assoluto Windows che è residuo della macchina di un autore. La situazione è insostenibile prima di iniziare a scrivere codice della pipeline.

## Decision Drivers

- Il pacchetto deve restare distribuibile via `install_github()` per condividere le funzioni (es. wrapper LLM, parser ARCHS4, statistiche meta-analitiche)
- La pipeline che esegue lo studio è parte integrante del progetto e va versionata, non lasciata fuori repo
- I file di stato di `targets` (`_targets/`) e i dati grezzi non devono finire nel build del pacchetto né nella distribuzione GitHub-pesante
- La replica dello studio da parte di terzi deve essere documentata e fattibile (dipendenze, ordine, input attesi)
- La struttura deve essere riconoscibile per chi ha già visto un research compendium R (Marwick et al.)

## Considered Options

1. **Research compendium** — pacchetto + sotto-cartella `analysis/` con la pipeline targets specifica dello studio
2. **Pacchetto puro** — solo libreria; chi vuole eseguire la pipeline si organizza in un proprio progetto
3. **Solo pipeline** — rimuovere DESCRIPTION/NAMESPACE/man/, tenere solo `R/` + `_targets.R` come progetto di analisi

## Decision Outcome

Scelta: **Opzione 1 — research compendium**.

Motivazione: è l'unica opzione che soddisfa simultaneamente il bisogno di distribuire le funzioni come libreria (per riuso esterno), versionare la pipeline reale dello studio (per riproducibilità), e mantenere i benefici della struttura pacchetto (R CMD check, lint, test, vignette/pkgdown come manuale generato). Il pacchetto puro rinuncia alla riproducibilità nel repo; la pipeline pura rinuncia alla distribuibilità. Il compendium li tiene insieme con responsabilità chiare.

### Struttura adottata

```
simulomicsr/
├── R/                    # funzioni riutilizzabili (libreria)
├── tests/                # test unitari
├── man/                  # roxygen
├── vignettes/            # tutorial = manuale generato
├── analysis/             # pipeline targets per QUESTO studio
│   ├── _targets.R
│   ├── _targets.yaml      (path relativo)
│   ├── _targets_packages.R
│   ├── _targets/          (gitignored eccetto il suo .gitignore interno)
│   ├── input/             (gitignored: dati grezzi grandi, scaricati)
│   └── output/            (gitignored: artefatti)
├── data-raw/             # dati di reference piccoli (xlsx gold, ...)
├── docs/                 # ADR, spec, plan (non distribuiti)
├── DESCRIPTION
├── NAMESPACE
├── renv.lock
└── README.md
```

### Convenzioni operative

- `_targets.yaml` usa `store: _targets` (relativo, default) — niente più path assoluti
- La pipeline si esegue con `setwd("analysis")` + `targets::tar_make()`, oppure `targets::tar_make(script = "analysis/_targets.R", store = "analysis/_targets")`
- `analysis/` è in `.Rbuildignore` (non parte del pacchetto distribuito)
- `analysis/input/` e `analysis/output/` sono in `.gitignore` (file pesanti, generati o scaricati)
- I dati piccoli e canonici (gold standard, esempi) restano in `data-raw/`
- Il manuale utente del pacchetto vive in `vignettes/` e si genera via `pkgdown::build_site()`

### Consequences

- **Positive:**
  - Confine chiaro fra libreria (R/) e applicazione (analysis/)
  - Pipeline riproducibile e versionata insieme alle funzioni che la implementano
  - Distribuzione `install_github('UBESP-DCTV/simulomicsr')` continua a funzionare per chi vuole solo la libreria
  - Vignette generate come manuale ufficiale
- **Negative:**
  - Discesa di un livello per eseguire la pipeline: bisogna ricordarsi di puntare a `analysis/`
  - Doppio "luogo dei pacchetti": `DESCRIPTION` (per la libreria) e `analysis/_targets_packages.R` (per la pipeline). Vanno tenuti coerenti
  - Lievemente più complesso per chi vede solo un pacchetto R e non riconosce il pattern compendium
- **Neutral:**
  - `renv.lock` resta singolo a livello di repo, copre sia libreria sia pipeline (questa è la pratica standard nei compendium)
  - I file `dev/` di sviluppo del pacchetto restano alla root (sono workflow pacchetto, non analisi)

## Decisioni rinviate

- **Nome del pacchetto.** "simulomicsr" non riflette la visione attuale (la pipeline non simula nulla). Ridenominazione da affrontare in un ADR successivo, separatamente; non blocca la struttura
- **Contenuto di `_targets_packages.R`.** Il file attuale ha residui shiny (`bs4Dash`, `clustermq`, `shinyWidgets`...) probabilmente del template iniziale. Si ripulisce quando inizieremo a popolare la pipeline reale, non in questo ADR
- **`renv` profili.** Possibile splittare in profili `library` vs `analysis` se le dipendenze divergono; per ora un solo profilo

## Links

- Riferimento: Marwick, Boettiger, Mullen (2018) — "Packaging Data Analytical Work Reproducibly Using R (and Friends)" — *The American Statistician*
- ADR-0001 (sistema di tracking)
