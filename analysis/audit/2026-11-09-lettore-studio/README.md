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

## S12r — Piano 1 del lettore dello studio (dal 2026-11-10)

Da qui in poi le misure hanno cancelli e previsioni depositati prima del calcolo (`00-previsioni.md`).

| file | che cosa |
|---|---|
| `00-previsioni.md` | cancelli K1-K5 e previsioni P1-P8, depositati prima di ogni calcolo |
| `30-divisione.R`, `30-divisione.tsv` | i 129 studi divisi in 47 di sviluppo, 42 di giudizio A, 40 di giudizio B (**gli 82 di giudizio sono chiusi**) |
| `31-scarica-atlas.py`, `31-manifesto-atlas.tsv` | scarico congelato dei file di Expression Atlas (configurazione per 129 studi, SDRF solo per i 47 di sviluppo) in `analysis/input/atlas-2026-11-09/` |
| `32-scarica-ena.py`, `32-manifesto-ena.tsv` | scarico congelato dei rapporti di ENA (run → campione) in `analysis/input/ena-2026-11-09/` |
| `33-legame.R`, `33-legame.tsv`, `33-out.txt` | il legame run (SRR) → campione (GSM) da due fonti, ENA e il campo `relation` di ARCHS4: cancello K1 |
| `aiuti-misura.R` | Atlas e universo per i 47 studi di sviluppo, giudizio delle previsioni: lo usano la misura di oggi e la misura del lettore |
| `40-misura-oggi.R`, `40-out.txt` | la pipeline di oggi (master S14 dello Stadio 2) contro Atlas sui 47 studi di sviluppo: cancelli K2 e K3, previsioni P1, P2, P8 |
| `40-per-studio-oggi.csv`, `40-per-studio-oggi-secondaria.csv` | una riga per studio: variante principale (almeno 2 campioni per braccio) e secondaria (tutti i confronti) |
| `40-misure-oggi.csv` | le misure con l'intervallo al 95% (bootstrap sugli studi, B = 2.000, seme 20261109) |
| `40-confronti-atlas-oggi.csv`, `40-non-elencati-oggi.csv` | un confronto per riga: i confronti di Atlas con classe ed esito, i confronti di oggi che Atlas non elenca con il giudizio |

### La prova da buttare (Task 9 e 10): niente di questo entra nel pacchetto

| file | che cosa |
|---|---|
| `aiuti.R` | aiuti comuni alla prova: solo studi di sviluppo (cancello K5), solo `poddgx02` e variabili d'ambiente lette dal container (cancello K4) |
| `50-scarica-geo-sviluppo.py`, `50-manifesto-geo.tsv` | testi GEO congelati dei 47 studi di sviluppo in `analysis/input/geo-testi-lettore-2026-11-09/`: testo dello studio (47 da GEO, 2026-11-10) e testo dei campioni (35 da GEO, 12 riusati dallo scarico di S12 del 2026-11-08, colonna `fonte`) |
| `60-vista-v0.R`, `60-out.txt` | la vista dello studio che il modello legge: testo dello studio, colonne costanti, tabella dei campioni. 47 studi, 1.883 campioni, nessun campione cancellato, nessuna vista oltre 49.152 token stimati (massimo 37.692) |
| `60-viste-v0.jsonl` | una riga per studio: `record_id`, `testo`, `campioni`, `colonne`, `costanti`, `tabella` (per colonna, il valore di ogni campione) |
| `61-schema-v0.json` | lo schema della tabella dei fattori, prima versione |
| `62-prompt-v0.md` | il messaggio di sistema, prima versione: il file entra nel prompt byte per byte, quindi non porta il marchio «PROVA DA BUTTARE» |
