# HANDOUT — La validazione esterna: come si prova che queste 214 meta-analisi dicono il vero

**Scritto:** 2026-08-07 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Stato:** il deliverable esiste ed è completo; **nessuna verifica usa dati esterni al corpus**.

> **Questo file è autosufficiente.** Non serve leggere le conversazioni precedenti.

---

## 0. Il problema, in una frase

Le 214 meta-analisi sono state verificate **solo con se stesse**. Ogni controllo fatto finora
guarda dentro lo stesso pool di dati che ha prodotto il risultato: nessuno ha mai chiesto a
una fonte indipendente se quelle stime siano giuste. Finché non lo si fa, la domanda «e come
fai a sapere che funziona?» non ha una risposta misurata.

---

## 1. Che cosa esiste già, e perché non basta

| verifica | esito | perché non è validazione esterna |
|---|---|---|
| **Bersagli fissati prima del run** (31 geni su 7 entità) | 29/31 col segno atteso e significativi | i bersagli li ha scelti chi conosce la biologia attesa: prova che il metodo non è rotto, non che sia accurato. E copre 7 entità su 214 |
| **Agonista contro antagonista** (DHT contro enzalutamide, gruppi costruiti separatamente) | 1.441 geni significativi in entrambi, **1.408 (97,7%) di segno opposto**, Spearman −0,938 | è il controllo più forte che c'è, ma resta interno: sono due sottoinsiemi dello stesso corpus |
| **Arricchimento GO** | termini attesi in cima (es. «response to type II interferon» per IFN-γ) | usa gli stessi geni della stima: misura la coerenza interna del risultato, non la sua verità |
| **Concordanza di segno per studio** (misurata 2026-08-07) | IFN-γ 91/91, TGF-β1 90,7%, DHT 89,9%, SARS 84,4%, enzalutamide 81,7% | dice che gli studi poolati concordano fra loro — cioè che il pool è coerente, non che abbia ragione |

**Il buco:** nessuna di queste tocca un dato che non sia già dentro il pool.

---

## 2. Il materiale che c'è

**Il deliverable** (`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7/`):

- `deliverable-annotato.rds` — 214 righe, una per meta-analisi, con `contrast_entity`,
  `k_effective`, `k_kish`, `I2_med`, `n_sig`, dominanza, materiale, verdetto di coerenza;
- `cluster_pooled.parquet` — la stima per gene (logFC, SE, FDR, τ², I², k);
- `per_study_de.parquet` — la stima **per studio** per gene: è quello che permette
  leave-one-study-out e qualunque confronto per singolo studio.

**Composizione delle 214, per tipo di entità** (contata, non stimata):

| tipo | quante |
|---|---:|
| piccole molecole (`CHEBI:`) | **104** |
| identificativi non risolti a un'ontologia (`STR:`) | 47 |
| malattie e condizioni (`MeSH:`) | 23 |
| geni e prodotti genici (`HGNC:`) | 20 |
| patogeni (`NCBITaxon:`) | 10 |
| composti ChEMBL | 7 |
| combinazioni | 3 |

Potenza: **29 meta-analisi con almeno 10 studi poolati**, 91 con almeno 5.
Complessivamente 344.996 geni significativi (FDR < 0,05), I² mediano 72,1, 11 dichiarate
incoerenti.

**Un set di dati mai entrato nel pool.** Il gate dei controlli interni ha scartato **137
gruppi candidati**: 42 con un solo studio utilizzabile, 82 con due, il resto sotto soglia
(`non_processable.rds`). Sono studi **reali, sulla stessa entità, esclusi per un criterio
tecnico e non biologico**. Non sono materiale da meta-analisi, ma potrebbero essere
materiale da *verifica*.

**Dizionari già in cache locale** (`~/.cache/R/simulomicsr/`): ChEBI, ChEMBL, MeSH, HGNC,
ImmPort, tassonomia NCBI. La mappatura verso una risorsa esterna non parte da zero.

**Spazio disco:** 2,2 TB liberi sul volume del deliverable.

---

## 3. Le direzioni possibili — da discutere, NON già decise

Elencate perché il brainstorming parta da qualcosa, non perché siano la risposta. Ognuna ha
un problema aperto scritto accanto: quello è il lavoro.

1. **Firme di perturbazione da una risorsa esterna** (LINCS L1000 o simili). Copre le
   piccole molecole, che sono la metà del deliverable. *Problema:* piattaforma diversa
   (~978 geni misurati e il resto inferito), linee cellulari e dosi loro, e va deciso che
   cosa si confronta — direzione dei geni condivisi? correlazione di rango? posizione della
   nostra stima nella distribuzione nulla di quella risorsa?
2. **Firme di malattia da risorse curate** (per le 23 MeSH). *Problema:* le risorse curate
   sono spesso costruite *dagli stessi studi GEO* che stanno nel nostro pool — circolarità
   da misurare, non da assumere assente.
3. **Replicazione sugli studi esclusi dal gate** (i 137). Dati veri, stessa entità, mai
   entrati nel pooling. *Problema:* non hanno controlli interni — è esattamente perché sono
   stati esclusi — quindi serve un modo difendibile di calcolarci sopra un effetto, e il
   prestito di controlli cross-studio in questo progetto è già stato misurato e **bocciato**
   (recupero 1-7% dei geni veri).
4. **Leave-one-study-out predittivo.** Interno ai dati ma esterno alla singola stima: si
   toglie uno studio, si ri-pool, si guarda quanto la stima residua predice quello tolto.
   *Problema:* costo computazionale, e va deciso cosa conta come «predizione riuscita».
5. **Coerenza farmacologica fra entità** (l'estensione di DHT/enzalutamide): coppie
   agonista/antagonista, inibitore/substrato, ligando/knockout della stessa via, cercate
   sistematicamente fra le 214. *Problema:* quante coppie esistono davvero nel corpus? Va
   contato prima di progettarci sopra.

---

## 4. I vincoli del progetto (non negoziabili)

1. **Deterministico e pubblicabile.** La validazione che finisce nell'articolo non può
   dipendere da un giudizio LLM a runtime. Gli agenti servono a progettare e a misurare,
   non a decidere il risultato.
2. **Niente re-pool a cuor leggero.** Un re-pool completo costa ~31 ore, un re-cluster
   ~9. Se un disegno lo richiede, va dichiarato come costo e messo dietro una decisione
   esplicita.
3. **Prima si misura la copertura, poi si progetta.** Una risorsa esterna che aggancia 12
   delle 214 entità non è una validazione: è un aneddoto. **La copertura va contata sui
   dati veri prima di scrivere qualunque piano.**
4. **La circolarità va misurata, non esclusa a parole.** Se la risorsa esterna contiene gli
   stessi GSE del nostro pool, il confronto è viziato: l'intersezione degli studi va
   quantificata e riportata.
5. **Mai dichiarare «validato» senza la misura accanto.** Questo progetto ha già ritrattato
   due volte dichiarazioni di vittoria premature (RED_ALERT). Il criterio di successo va
   scritto **prima** di guardare il risultato.
6. **Verifica sull'artefatto, non sul sorgente.** E quando c'è una figura, si apre e si
   guarda.

---

## 5. Che cosa NON è questo lavoro

- Non è ri-fare il clustering o il pooling: il deliverable è quello, e si valida quello.
- Non è la de-frammentazione delle entità (potenza persa, questione separata, ~9h + ~28h).
- Non è il benchmark contro RummaGEO: quello è un confronto **competitivo** con un altro
  metodo, ed è un lavoro a sé. Se il disegno della validazione lo rende gratuito, tanto
  meglio, ma non è l'obiettivo.
- Non è la scrittura dell'articolo.

---

## 6. Il criterio di riuscita di questa sessione

Non «la pipeline è validata». La sessione riesce se produce:

1. una **decisione motivata** su quale forma di validazione esterna è praticabile su questo
   corpus, con la **copertura contata sui dati veri** accanto a ciascuna opzione scartata;
2. un **criterio di successo scritto prima** di eseguire la misura (che cosa conterebbe come
   conferma, che cosa come smentita);
3. una **misura pilota** su un sottoinsieme, abbastanza per sapere se il disegno regge
   prima di lanciarlo su tutte e 214;
4. la dichiarazione onesta di che cosa quella validazione **non** dimostrerebbe.

---

## 7. Riferimenti utili

- Stato del progetto e lezioni: `CLAUDE.md`, `docs/RED_ALERT.md`
- Il controllo biologico attuale: `analysis/audit/2026-08-02-fix/90-controllo-biologico-v15.R`
- La concordanza di segno (misura 2026-08-07): `analysis/audit/2026-08-06-layer-b-v3/20-concordanza-di-segno.R`
- Perché il prestito di controlli è stato bocciato: `docs/findings/2026-07-09-stage4-augmentation-passo3-measurement.md`
- I confronti imperfetti (metodo e numeri): `docs/findings/2026-08-05-confronti-imperfetti.md`
- Il documento del Layer B: `analysis/p4-output/20260807T103637Z-layer-b-81f379d3/layer_b_report.html`
