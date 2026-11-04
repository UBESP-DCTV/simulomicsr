# Validazione esterna, il disegno (S6)

Disegno: `docs/superpowers/specs/2026-11-04-validazione-esterna-design.md`. Finding: `docs/findings/2026-11-04-S6-validazione-disegno.md`.

Ordine di esecuzione, dalla radice del repository, con `Rscript` senza `--vanilla`:

1. `10-mappa.R`: riproduce l'aggancio sul v15 e lo applica alle 194.
2. `20-firme.R`: conta le firme LINCS dai metadati e scrive la tabella dei metadati in `/mnt/micron/simulomicsr-dati/2026-11-04-S6-validazione-disegno/si.rds`.
3. `40-copertura.R`: classi, aggancio, misurabilità, landmark.
4. `50-tahoe.R`: i composti delle 194 nell'indice di Tahoe-100M (`indici/`, SHA-256 nel finding).
5. `30-circolarita.R`, `60-soglie-e-controlli.R`, `65-lettere-greche.R`.

`05-classi.R` stampa l'elenco delle 194. `50-tcga-normali.txt` viene da una richiesta all'API del GDC, testo nel finding §4.
Nessuno script legge un dato Level 5 o un valore di `cluster_pooled`: `40-copertura.R` legge di quel file solo `cluster_id` e `gene_id`.
