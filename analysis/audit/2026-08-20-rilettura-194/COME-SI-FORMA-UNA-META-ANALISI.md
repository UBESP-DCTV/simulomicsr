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

## La catena in un colpo d'occhio

```
ARCHS4 H5            888.821 campioni
   │  STADIO 0 — 7 filtri deterministici
   ▼
bacino               508.037 campioni          (24.394 studi)
   │  STADIO 1 — LLM, un campione alla volta
   ▼
fatti per campione   508.037 record
   │  STADIO 2 — LLM, uno studio alla volta
   ▼
gruppi + confronti   24.394 studi
   │  STADIO 3 — deterministico, chiave del contrasto
   ▼
cluster              325.059 cluster / 571.680 assegnazioni
   │  GATE — n_min, dedup, k>=3
   ▼
194 meta-analisi     1.903 confronti · 1.178 coppie studio-gruppo · 15.559 campioni
```

---

## La catena, passo per passo

### Passo 0 — lo Stadio 0 decide chi entra

Filtro **deterministico**, nessun modello. `R/etl-archs4-utils.R::is_sample_classifiable()`.

**Entra:** i 888.821 campioni umani dell'H5 ARCHS4 v2.5, coi loro campi GEO.
**Esce:** 508.037 campioni, ognuno con una `string` unica costruita da titolo +
sorgente + caratteristiche.

Sette motivi di esclusione, in quest'ordine, e il primo che scatta vince:
`not_human` · `not_bulk_rnaseq` · `library_source_not_transcriptomic` ·
`string_too_short` (<20 caratteri) · `single_cell_protocol_match` ·
`lib_size_too_small` (<500.000) · `single_cell_probability_high` (≥0.9).

> **Questo passo spiega quasi tutti i «campioni mancanti».** GSE200186 ha 1.179
> campioni in GEO e ne manda 27: gli altri 1.152 escono per
> `single_cell_protocol_match`. Non sono persi, sono esclusi con un motivo.
> Per sapere il motivo di un campione qualsiasi: `A2-filtro-stadio0.R`.

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

Modello Mistral-Small-3.2 self-hosted, `temperature = 0`, output vincolato allo
schema `sample_facts.stage1.v3`.

**Entra:** un campione alla volta — `geo_accession`, `series_id`, la `string`,
`organism`, `library_strategy`, `molecule_ch1`. Nient'altro: **non vede gli altri
campioni dello studio**, quindi non puo' ancora sapere chi e' trattato e chi
controllo.

**Esce:** un record per campione, coi blocchi
- `cell_context` — tipo cellulare, tessuto, `context_kind`, stato, modifiche ingegnerizzate, co-colture;
- `disease_state` — termine grezzo, candidato MeSH, stato;
- `perturbations[]` — `kind`, `agent_raw`, `agent_normalized`, dose, durata;
- `patient_metadata` — donatore, eta', sesso, etnia, visita;
- `extraction` — versione dello schema, confidenza, `ambiguity_flags`.

**Dove si sbaglia:** l'agente normalizzato. E' qui che `IL-1β` puo' diventare
un altro gene (vedi `98-greche-tutti-i-resolver.R`).

### Passo 3 — lo Stadio 2 guarda lo STUDIO intero e forma i confronti

**Entra:** un record per studio, con **tutti** i suoi campioni e i fatti che lo
Stadio 1 ha estratto per ciascuno (`record_id`, `series_id`, `samples[]` con
`geo_accession` + `sample_facts`).

**Esce:** un record per studio con sette campi:
`series_id` · `design_summary` · `design_kind` · `factors[]` ·
**`replicate_groups[]`** · **`comparisons[]`** · `extraction`.

I due che contano:

```
replicate_group: {group_id, label_human, sample_ids[], primary_role, factor_levels[]}
comparison     : {comparison_id, treated_group, control_group, control_type,
                  design_kind, varying_factor, fixed_factors[], study_internal_score}
```

`label_human` e' l'etichetta che leggi nelle schede; `factor_levels` e' cio' su
cui lo Stadio 3 calcolera' la differenza fra i bracci.

> **Qui si perde qualcosa senza motivo dichiarato.** Un campione ricevuto puo'
> non finire in nessun `replicate_group`, e allora sparisce: **1.993 su 37.800
> (5,3%)**, in 97 studi su 993. Non c'e' un campo che lo registri — si vede solo
> confrontando entrata e uscita (`A1-campioni-persi.R`).

Nelle schede: il `replicate_group` e' la riga `gruppo Stadio 2:`, la `comparison`
e' il blocco `CONFRONTO`.

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

**Deterministico**, nessun modello: l'unica cosa che serve dall'esterno sono le
ontologie (ChEBI 205k composti, HGNC 45k geni, MeSH 31k, ChEMBL, NCBI Taxonomy).

**Entra:** i 24.394 record dello Stadio 2.
**Esce:** due file —
- `clusters.rds` (325.059 righe): `cluster_id`, `mode`, `level`, `anchor_key`,
  `k`, `n_total`, **`contrast_entity`**, **`contrast_direction`**,
  **`contrast_control_key`**;
- `assignments.parquet` (571.680 righe): `record_id`, `cluster_id`, `mode`,
  `level`, `anchor_key` — cioe' **quale confronto sta in quale cluster**.

Il `record_id` e' `<serie>__<comparison_id>__<indice>`: e' il confronto, non il
campione. L'entita' si ricava dalla **differenza** fra i `factor_levels` dei due
bracci, non dal solo braccio trattato.

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

Prima di poolare, tre porte scartano materiale. **E' il motivo per cui i campioni
nelle schede sono meno di quelli che lo Stadio 2 ha collocato:**

1. **`n_min = 2`** — un braccio serve almeno due repliche *biologiche*. Due
   letture della stessa libreria su corsie diverse **non** sono due repliche e
   vengono collassate prima di contare.
2. **dedup `studio || braccio-trattato`** — se lo stesso braccio trattato compare
   in due confronti dello stesso studio dentro lo stesso gruppo, ne sopravvive
   uno solo: altrimenti quello studio peserebbe il doppio.
3. **`k >= 3`** — un gruppo diventa meta-analisi solo con almeno tre studi
   distinti. Sotto tre, non nasce.

Quello che passa tutte e tre le porte e' esattamente quello che vedi nelle
schede: **1.903 confronti**, da 316 cluster candidati a **194 meta-analisi**.

**Entra nel gate:** `assignments.parquet` + i `replicate_groups` dello Stadio 2.
**Esce dal gate:** il *dispatch*, cioe' una lista di tuple
`{cluster_id, study_id, campioni_trattati[], campioni_controllo[]}`, piu' il
registro di TUTTO cio' che e' caduto (`qc_report$dispatch_drops`: 3.319 righe con
`cluster_id`, `study_id`, `treated_group`, `motivo`, i quattro conteggi).

**Poi il calcolo**, in due tempi:

| | entra | esce |
|---|---|---|
| **DE per studio** (limma-voom) | conte grezze dall'H5 dei campioni del dispatch, piu' le covariate `instrument_model` e `aligner_class` | `per_study_de.parquet` — `cluster_id`, `study_id`, `gene_id`, `gene_symbol`, `logFC`, `SE`, `p_value`, `n_treated`, `n_control` |
| **combinazione** (REM, REML) | le stime per studio | `cluster_pooled.parquet` — `logFC_pool`, `SE_pool`, `p_value_pool`, **`tau2`**, **`I2`**, `Q`, `k_effective`, `FDR_BH_within_cluster` |

Fra i due c'e' un passaggio che vale la pena sapere: i bracci multipli dello
stesso studio vengono **collassati in una stima sola per studio** (varianza
inversa, effetti fissi) prima della combinazione, altrimenti uno studio con
cinque confronti peserebbe cinque volte.

---

## Il conto, per non perdersi

| | |
|---:|---|
| **194** | meta-analisi |
| **1.178** | coppie (meta-analisi, studio) — la somma dei `k` |
| **1.903** | confronti poolati (uno studio puo' portarne piu' di uno) |
| **993** | studi distinti |
| **15.559** | campioni distinti (20.713 righe nelle schede: un controllo serve piu' confronti) |

I campioni nelle schede sono quelli **effettivamente entrati nel calcolo**, non
quelli censiti: l'insieme e' stato ricostruito replicando il dispatch di
produzione e verificato due volte contro l'output vero (registro degli scarti
3.319 = 3.319, coppie 1.178 = 1.178). Se trovi un campione che secondo te
dovrebbe esserci e non c'e', quasi sempre e' caduto per `n_min`: il registro
completo degli scarti sta nel `qc_report.rds` del deliverable.

---

## Quanto pesano i difetti

Qualche confronto è difettoso: è un dato di fatto, non un gate. Nessuna
meta-analisi viene esclusa per questo — la regola «almeno un difetto ⇒ fuori»
azzererebbe **tutte** quelle con k ≥ 15, cioè quelle con potenza. Al posto del
verdetto, tre misure.

**Metodo.** (1) *Peso contaminato*: la quota di peso random-effects
`1/(SE²+τ²)` degli studi difettosi, mediana sui geni, coi bracci collassati per
studio. (2) *Influenza*: si tolgono in blocco e si rifà il pooling; si guardano
Spearman del ranking, geni significativi persi, max |Δ logFC| fra i primi 30, su
un insieme di geni fissato sul pooling pieno. (3) *Nulli*: la stessa rimozione
contro 20 rimozioni casuali di studi **puliti**, con lo stesso numero di studi e
di bracci; si riporta il percentile.
Prova di accettazione: il ri-pooling pieno riproduce `cluster_pooled.parquet` —
**66 gruppi su 66, scarto esattamente 0**.

**Risultati.** 128 delle 194 (66%) non hanno alcun difetto letto. Sulle 66 che ne
hanno, il peso e l'influenza **calano in modo monotono col crescere di k**:

| | k=3-4 | k=5-9 | k=10-14 | k≥15 |
|---|---:|---:|---:|---:|
| gruppi accusati | 29 | 23 | 2 | 12 |
| di cui **muoiono** (scendono sotto k=3) | 21 | 0 | 0 | 0 |
| peso contaminato | 38,4% | 18,1% | 7,3% | **8,8%** |
| geni significativi persi | 58,0% | 40,7% | 17,3% | **13,1%** |
| Spearman del ranking | 0,473 | 0,632 | 0,840 | **0,864** |

I gruppi grandi **contengono** quasi sempre un difetto — è aritmetica, a tasso
costante dell'8,2% per studio — ma quel difetto **pesa poco**. I piccoli
raramente ne contengono, ma quando capita domina, e in 21 casi su 29 toglierlo
uccide la meta-analisi: quello però è un fatto sul **gate** `k ≥ 3`, non sul
difetto. **Togliendo tutti i difetti, 173 meta-analisi su 194 restano in piedi.**

**E il difetto conta più del semplice togliere dati?** In media no: il percentile
della rimozione accusata fra 20 rimozioni pulite equivalenti è 0,50 / 0,33 / 0,50
sulle tre statistiche (Wilcoxon p = 0,59 / 0,46 / 0,39). Ma la coda supera il
caso: **12 gruppi su 45 stanno sopra il 90° percentile** sullo Spearman contro 4,5
attesi (binomiale p = 0,0012). Non «non contano», e non «sono tutti gravi».

> **Limite che vale per tutte e tre.** Una leave-one-out vede solo gli studi
> **discordanti**. Un difetto che sposta il risultato *nella stessa direzione*
> degli altri è invisibile a questo disegno. «Influenza piccola» non assolve il
> difetto. Il dettaglio, coi limiti, sta in `INFLUENZA-DEI-DIFETTI.md`.

---

## Dove ogni errore possibile si vede

| se sbaglia... | lo vedi confrontando... | e la colpa e' del... |
|---|---|---|
| la stringa non dice abbastanza | `grezzo` con i campi `H5` | dato GEO di partenza |
| manca un campione dello studio | il motivo in `A2-filtro-stadio0.R` | Stadio 0 — **e allora non e' un difetto** |
| un campione ricevuto non sta in nessun gruppo | `ricevuti` con `collocati`, in fondo alla scheda | Stadio 2 (LLM) — 5,3% |
| l'etichetta non corrisponde ai campioni | `etichetta Stadio 2` con i `grezzo` sotto | Stadio 2 (LLM) |
| i due bracci non sono appaiati | `TRATTATO` con `CONTROLLO` | Stadio 2 (LLM) |
| il gruppo mette insieme cose diverse | i vari `CONFRONTO` fra loro | Stadio 3 (chiave) |
| l'entita' del gruppo e' il composto sbagliato | `entita (ID)` con le etichette | Stadio 3 (resolver/ontologie) |
| manca uno studio che ti aspettavi | `k studi` con `qc_report$dispatch_drops` | il gate (`n_min`, `k>=3`) |
| il numero di campioni non torna | `n=` del braccio coi GSM elencati | il collasso delle corsie (due letture di una libreria valgono uno) |

Il verdetto che la rilettura automatica ha dato a ciascuna e' in testa alla
scheda (`verdetto della rilettura`), cosi' puoi confrontare il tuo giudizio col
suo. Dove non sei d'accordo, ha ragione la scheda: le etichette sono quelle vere.
