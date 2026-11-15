# Il riferimento di Gemma (UBC)

- `10-gemma-umani.csv`: gli studi umani di Gemma (9.831), letti dall'API REST v2 (`datasets`, filtro `taxon`) il
  2026-11-15 da un agente di ricerca; il programma di quell'elenco non è stato salvato. Colonne: identificativo,
  nome breve, accesso GEO, tecnologia, numero di campioni, single-cell, «troubled», qualità (GEEQ).
- `11-elenco-da-scaricare.py` → `11-da-scaricare.csv`: gli studi RNA-seq di Gemma nel nostro bacino (3.203), con la
  parte (sviluppo, giudizio, gemma). Riprodotto byte per byte.
- `12-scarica-disegni.py` → `analysis/p4-output/gemma-disegni-2026-11-15/` (non tracciata): campioni e analisi
  differenziali di 3.170 voci; gli studi di giudizio non sono scaricati. `12-out.txt`: 0 errori.
- `20-censimento-disegni.py` → `20-censimento.csv`, `20-out.txt`: la struttura dei disegni.
- `00-previsioni.md`: carta e previsioni della misura curatori contro curatori.
