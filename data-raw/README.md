# `data-raw/` — dati di reference

Questa cartella contiene dati piccoli e canonici che servono al progetto come
input fisso o gold standard. NON contiene dati grezzi pesanti scaricati dalla
pipeline: quelli vivono in `analysis/input/` (gitignored).

## Contenuto

### `relevant_sample_classified.xlsx`

Foglio Excel etichettato a mano dall'autore EP, usato come gold standard per
la valutazione del classificatore LLM treated/control.

- **Foglio:** `relevant_sample` — 130.784 righe, 8 colonne
- **Origine:** filtraggio precedente di sample RNAseq da GEO; il codice originale
  che lo ha prodotto è andato perso

| Colonna | Descrizione |
|---|---|
| `Column1` | Indice di riga progressivo (artefatto export) |
| `string` | **Input.** Stringa metadati testuale concatenata da campi GEO sample (es. `"treatment: siBCL6,cell line: OCI-LY1"`) |
| `trtctr_EP` | **Gold manuale.** Etichetta `treated` / `control` assegnata a mano dall'autore EP |
| `geo_accession` | GSM ID del sample |
| `series_id` | GSE ID dello studio di provenienza |
| `treat` | Label di trattamento estratto (es. `"siNT"`, `"VEGF"`) |
| `trtctr` | **Baseline shallow.** Classificazione automatica precedente basata su keyword (control / dmso / water / ...) |
| `gold` | **(Da chiarire con l'autore)** Probabile colonna di consenso/decisione finale |

## Politica

- Aggiungi qui solo dati piccoli (< qualche MB), versionabili, e che servono come
  riferimento stabile (gold standard, esempi documentazione, mapping)
- I dataset pesanti (HDF5 ARCHS4, matrici espressione raw) NON vanno qui: vivono
  in `analysis/input/` e sono scaricati on-demand dalla pipeline
- Ogni file in questa cartella deve essere documentato in questo README
