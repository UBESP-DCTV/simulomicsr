# Passo A, solo fonti: esito (2026-11-04)

Nessuno script di questo passo legge una stima del deliverable. Il risultato si committa prima del passo B.

| punto | quantità | valore | intervallo | esito |
|---|---|---:|---:|---|
| cancello 1, inizio | manifesto e metadati LINCS | tutti coincidono | | passa (`12-cancello-1-inizio.txt`) |
| integrità degli scarichi | ETag S3, oid LFS, md5 GDC | 2 + 1.026 + 1.386 file coincidono | | `10-scarica-log-lincs.txt`, `12-cancello-1-scarichi.txt` |
| cancello 2, parte sulle fonti | 19, 53, 8; 5.466 composti; 36.204 firme | uguali | | passa (`20-firme-out.txt`) |
| cancello 4 | coppie nel primo 10%; invertita più bassa | 5 su 5; 5 su 5 | servono 4 | passa (`30-out.txt`) |
| previsione `H_metà` | 80 composti, 20 divisioni | 82,5% [75,2; 88,9] | [50%; 83%] | a cavallo di 83%; non tocca la condizione sulla fonte, che è sotto 50% (`40-out.txt`) |
| previsione `H_fonti` | 142 farmaci | 37,3% [29,4; 45,8], 53 su 142 | [17%; 50%] | confermata (`51-out.txt`) |
| TCGA | 16 progetti, 693 coppie | COAD-READ 0,90; KIRC-KIRP 0,66; LUAD-LUSC 0,83 sui landmark | | `60-tcga-out.txt` |

Correzioni di strumento durante il passo: l'aggancio del nome `trichostatin A` usa `compound_aliases`; il fondo dei ligandi conta i nomi esatti (164, come il disegno, con `TGFA` e `TGFa` distinti); la lettura del file `.gctx` prende le colonne intere e poi i landmark.
