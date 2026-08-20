# Come si forma una meta-analisi, e come controllarla a mano

Questo file spiega la catena che porta da un campione GEO a una delle 194
meta-analisi, e dice esattamente **dove guardare** per controllare ogni passo.

Tutto quello che serve sta in tre file, in questa cartella:

| file | che cos'e' |
|---|---|
| `INDICE-194.csv` | l'elenco delle 194, una riga ciascuna |
| `schede/NNN-<nome>-kNN.txt` | **una scheda leggibile per ogni meta-analisi**: ogni confronto, ogni braccio, ogni campione, con la stringa grezza accanto |
| `campioni-per-meta-analisi.csv` | la stessa cosa in tabella, una riga per campione, per chi vuole filtrare e ordinare |

---

## La catena, in cinque passi

### Passo 1 — il campione grezzo

Il punto di partenza e' un campione GEO (un `GSM`) con i suoi metadati testuali.
Nelle schede lo trovi cosi':

```
      GSM4581234
        grezzo (Stadio 1): title: HUVEC hypoxia 24h rep1,source: endothelial cells,treatment: 1% O2
        H5 titolo        : HUVEC hypoxia 24h rep1
        H5 caratteristiche: treatment: 1% O2
        H5 sorgente      : endothelial cells
```

- **`grezzo (Stadio 1)`** e' la stringa *esatta* che il modello ha letto. Non e'
  stata riscritta da nessuno.
- Le tre righe `H5` sono i campi originali di ARCHS4, riportati a parte perche' la
  stringa dello Stadio 1 li fonde in una riga sola: se sospetti che la fusione
  abbia perso qualcosa, le confronti.

**Che cosa controllare qui:** che la stringa dica davvero quello che serve. Se la
stringa non distingue trattato e controllo, nessun passo a valle puo' farlo.

### Passo 2 — lo Stadio 1 legge il singolo campione

Un modello (Mistral, self-hosted) legge quella stringa e ne estrae i fatti del
singolo campione: che cellula e', che perturbazione ha subito, a che dose, per
quanto tempo. **Non decide ancora chi e' trattato e chi e' controllo**: guarda un
campione alla volta e non sa che esistono gli altri.

### Passo 3 — lo Stadio 2 guarda lo STUDIO intero e forma i confronti

Qui nasce il confronto. Il modello vede tutti i campioni di uno studio insieme e
fa due cose:

1. raggruppa i campioni che sono **repliche della stessa condizione** (i
   *replicate group*): nelle schede e' la riga `gruppo Stadio 2:`;
2. decide **quale gruppo e' il trattato e quale il controllo**, e li appaia in un
   *confronto*. Nelle schede e' il blocco `CONFRONTO`.

L'etichetta leggibile che vedi (`etichetta Stadio 2:`) e' prodotta qui.

```
CONFRONTO  GSE123456__cmp_3__1
  studio: GSE123456
  TRATTATO  (n=3)  etichetta Stadio 2: HUVEC hypoxia 24h
      gruppo Stadio 2: rg_hypoxia_24h
      ...
  CONTROLLO  (n=3)  etichetta Stadio 2: HUVEC normoxia 24h
      gruppo Stadio 2: rg_normoxia_24h
      ...
```

**Che cosa controllare qui, ed e' il controllo piu' importante:**
- l'etichetta e' giustificata dalle stringhe grezze dei campioni che ci stanno
  sotto? (se l'etichetta dice `hypoxia 24h` e una stringa dice `48h`, e' un
  errore dello Stadio 2);
- i due bracci sono **appaiati**? Cioe' differiscono per *una sola cosa*, quella
  che lo studio vuole misurare. Se il trattato e' `hypoxia 24h` e il controllo e'
  `normoxia 0h`, il confronto misura ipossia **e** tempo insieme.

### Passo 4 — lo Stadio 3 assegna a ogni confronto una CHIAVE

Ogni confronto riceve una chiave di tre pezzi, e **la chiave e' la meta-analisi**:

```
entita || verso || tipo di controllo
```

- **entita'**: che cosa il confronto isola (`STR:hypoxia`, `HGNC:11766` = TGFB1,
  `CHEBI:16412` = LPS...). Si ricava dalla *differenza* fra i due bracci, non dal
  solo braccio trattato;
- **verso**: `gain` (l'entita' viene aggiunta / attivata) oppure `block` /
  `loss` (viene tolta / inibita). Serve a non mettere insieme un agonista e un
  antagonista;
- **tipo di controllo**: contro che cosa si misura (`vehicle_untreated`,
  `unstimulated`, `ctrl`...).

Tutti i confronti con la **stessa identica chiave** finiscono nello stesso
gruppo. Nelle schede la chiave e' in testa:

```
entita (ID)     : STR:hypoxia
verso           : gain
tipo di controllo: vehicle_untreated
```

**Che cosa controllare qui:** i confronti raccolti sotto la stessa chiave
misurano davvero la stessa cosa? E' qui che nascono i «minestroni»: confronti
diversi finiti sotto lo stesso nome.

### Passo 5 — il gate, poi la meta-analisi

Prima di poolare, due porte scartano materiale. **Questo e' il motivo per cui i
campioni nelle schede sono MENO di quelli che lo studio contiene:**

1. **`n_min = 2`** — un braccio serve almeno due repliche *biologiche*. Due
   letture della stessa libreria su corsie diverse **non** sono due repliche e
   vengono collassate prima di contare.
2. **dedup `studio || braccio-trattato`** — se lo stesso braccio trattato compare
   in due confronti dello stesso studio dentro lo stesso gruppo, ne sopravvive
   uno solo: altrimenti quello studio peserebbe il doppio.
3. **`k >= 3`** — un gruppo diventa meta-analisi solo con almeno tre studi
   distinti. Sotto tre, non nasce.

Quello che passa tutte e tre le porte e' esattamente quello che vedi nelle
schede. Solo dopo si calcola la meta-analisi vera e propria (effetto per studio,
poi combinazione a effetti casuali con I² e τ²).

---

## Il conto, per non perdersi

| | |
|---:|---|
| **194** | meta-analisi |
| **1.178** | coppie (meta-analisi, studio) — la somma dei `k` |
| **1.903** | confronti poolati (uno studio puo' portarne piu' di uno) |
| **993** | studi distinti |

I campioni nelle schede sono quelli **effettivamente entrati nel calcolo**, non
quelli censiti: l'insieme e' stato ricostruito replicando il dispatch di
produzione e verificato due volte contro l'output vero (registro degli scarti
3.319 = 3.319, coppie 1.178 = 1.178). Se trovi un campione che secondo te
dovrebbe esserci e non c'e', quasi sempre e' caduto per `n_min`: il registro
completo degli scarti sta nel `qc_report.rds` del deliverable.

---

## Dove ogni errore possibile si vede

| se sbaglia... | lo vedi confrontando... | e la colpa e' del... |
|---|---|---|
| la stringa non dice abbastanza | `grezzo` con i campi `H5` | dato GEO di partenza |
| l'etichetta non corrisponde ai campioni | `etichetta Stadio 2` con i `grezzo` sotto | Stadio 2 (LLM) |
| i due bracci non sono appaiati | `TRATTATO` con `CONTROLLO` | Stadio 2 (LLM) |
| il gruppo mette insieme cose diverse | i vari `CONFRONTO` fra loro | Stadio 3 (chiave) |
| manca uno studio che ti aspettavi | `k studi` con `qc_report$dispatch_drops` | il gate (`n_min`, `k>=3`) |

Il verdetto che la rilettura automatica ha dato a ciascuna e' in testa alla
scheda (`verdetto della rilettura`), cosi' puoi confrontare il tuo giudizio col
suo. Dove non sei d'accordo, ha ragione la scheda: le etichette sono quelle vere.
