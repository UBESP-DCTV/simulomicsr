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
- `30-adattatore-gemma.R` → `30-esiti.csv`, `30-out.txt`: l'adattatore dai disegni di Gemma alla tabella dei fattori
  (regole 1-7 della carta), col controllo positivo (K2), il controllo sugli studi di giudizio (K4) e un esito per
  ognuna delle 3.170 voci (K3).
- `31-curatori-contro-curatori.R` → `31-out.txt`, `31-per-studio.csv`, `31-riassunto.csv`, `31-appaiato.csv`,
  `31-schede/` (una scheda di lettura per studio): la misura della carta sui 21 studi di sviluppo, Gemma e
  Mistral `B0` contro Atlas sullo stesso universo di campioni.
- `32-sensibilita-base-di-gemma.R` → `32-out.txt`, `32-per-studio.csv`: sensibilità **dichiarata dopo i numeri**, la
  base di Gemma anche per i fattori di contesto e di tempo (`gemma_tabella(..., base_di_gemma = TRUE)`).
- `33-disaccordi-letti.csv`: i disaccordi dei 21 studi letti tutti, con la causa (scritto a mano dalle schede).
- Finding: `docs/findings/2026-11-15-gemma-curatori-contro-curatori.md`.
