# `analysis/` — pipeline dello studio

Questa sotto-cartella contiene la pipeline `targets` che esegue lo studio specifico
implementato in simulomicsr: scaricare RNAseq da repository pubblico, classificare
i sample via LLM, raggruppare esperimenti comparabili, e produrre la meta-analisi
cross-studio.

A differenza di `R/` (libreria di funzioni distribuibile), `analysis/` è
*applicativo*: produce risultati specifici di QUESTO studio. Vedi
[`docs/decisions/0002-struttura-research-compendium.md`](../docs/decisions/0002-struttura-research-compendium.md)
per la motivazione.

## Esecuzione

Dalla root del repo:

```r
targets::tar_make(
  script = "analysis/_targets.R",
  store  = "analysis/_targets"
)
```

Oppure dall'interno della cartella:

```r
setwd("analysis")
targets::tar_make()
```

## Layout

```
analysis/
├── _targets.R              # definizione DAG (sorgenti in ../R/)
├── _targets.yaml           # config targets (path relativi)
├── _targets_packages.R     # pacchetti caricati nel worker targets
├── _targets/               # stato pipeline (gitignored eccetto .gitignore interno)
├── input/                  # dati grezzi (gitignored, scaricati on-demand)
└── output/                 # artefatti generati (gitignored)
```

## Note

- `input/` e `output/` non sono in git: dataset pesanti (HDF5 ARCHS4, matrici di
  espressione) e artefatti riproducibili tramite `tar_make()`
- I dati di reference piccoli e canonici (es. il gold standard per la
  classificazione) vivono in `../data-raw/`, non qui
- I pacchetti dichiarati in `_targets_packages.R` devono essere coerenti con
  quelli in `../DESCRIPTION` (Imports/Suggests della libreria)
