# Validazione esterna, l'esecuzione (S7)

Disegno: `docs/superpowers/specs/2026-11-04-validazione-esterna-design.md`. Finding: `docs/findings/2026-11-04-S7-validazione-esecuzione.md`.
Dalla radice del repository, con `Rscript` senza `--vanilla`.

**Passo A, solo fonti, una volta sola.** `10-scarica.sh` (`tahoe`, `tcga-elenco`, `tcga`) e `11-scarica-lincs-a-pezzi.py 24`, `12-sha-e-cancello-1.sh scarichi`, `20-firme.R`, `21-firme-ligandi.R`, `30-controllo-l1000.R`, `40-h-meta.R`, `50-tahoe-firme.R`, `51-h-fonti.R`, `60-tcga.R`. I file pesanti stanno in `/mnt/wwn-0x5000039d58caca35/lincs-meta/level5/` e `/mnt/micron/simulomicsr-dati/2026-11-04-S7-validazione-esecuzione/`.

**Passo B, sul deliverable.** `POOL_DIR=<deliverable> Rscript ...`, in quest'ordine: `69-cancello-5.R`, `70-verdetto.R`, `71-tahoe-e-descrizioni.R`, `72-ricerca-errore.R`, `73-ricerca-parte-2.R`, `74-triangolo-fonti.R`, `75-numeri-finding.R`.

**Per la seconda esecuzione, dopo le correzioni.** Usa una cartella nuova per `PES7` e per gli esiti, e copia `firme.rds`, le firme di Tahoe, TCGA e dei ligandi. L'elenco delle entità (`pm` in `firme.rds`) nasce da `50-copertura-con-tahoe.csv` di S6: va rigenerato con le regole del disegno §4. `69-cancello-5.R` e il controllo E1-E3 leggono percorsi di S4 e di questa cartella: controllali.

Le righe E5 ed E6 di `72-out.txt` non valgono: `73-out.txt` le sostituisce. Il motivo sta nel finding §8.
