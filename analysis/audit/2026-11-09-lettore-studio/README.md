# Lettore dello studio e tabella dei fattori: misure esplorative (2026-11-09)

Evidenza per `docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md`. Misure esplorative
fatte durante la discussione con il PI, **senza previsioni depositate**: servono al disegno, non sono risultati.

| file | che cosa |
|---|---|
| `00-studi-993.txt` | i 993 studi dei 1.903 confronti letti |
| `10-token-per-studio.py`, `10-out.txt` | token stimati (caratteri / 2,29) per dare al modello lo studio intero, come testo e come tabella |
| `20-atlas-studi-nostri.txt` | i 129 esperimenti di Expression Atlas (umano, RNA-seq differenziale, E-GEOD) che corrispondono a un nostro studio: accession, GSE, 1 se fra i 993, numero di assay, fattori. Costruito in sessione dall'elenco JSON degli esperimenti di Atlas con un comando non salvato: lo script che lo rigenera si scrive nella fase 0 |
| `21-atlas-conta.py`, `21-out.txt` | confronti, gruppi e campioni scritti dai curatori nei 129 file di configurazione |

Non salvati qui: i 129 file XML di Atlas (si riscaricano con `21-atlas-conta.py`), l'elenco degli esperimenti
di Atlas, i file di CREEDS (0 studi in comune con i nostri: sono microarray).
