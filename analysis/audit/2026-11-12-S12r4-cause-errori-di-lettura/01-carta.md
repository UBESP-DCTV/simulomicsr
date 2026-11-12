# S12r4 — la carta: tutte le differenze fra le due forme dell'uscita, e la variante di ognuna

Scritta **prima di ogni corsa** (2026-11-12). Le previsioni, i cancelli e la regola di diagnosi stanno in
`00-previsioni.md`, committato da solo. Il codice che realizza questa carta è `10-forme.R`; lo strumento di misura
è `aiuti-misura-r4.R`; il cancello dello strumento, passato sulle uscite congelate, è `11-cancello-strumento.R`
(`11-out.txt`).

## 1. Le due condizioni

| | condizione A (S12r2) | condizione B (S12r3) |
|---|---|---|
| schema delle uscite | `analysis/audit/2026-11-10-S12r2-prova-ripetuta/20-schema-v1.json`, uno per tutti gli studi | `schema_studio()` di `analysis/audit/2026-11-11-S12r3-elenco-chiuso/10-schema-per-studio.R`, uno per studio |
| prompt (messaggio di sistema) | `…S12r2…/21-prompt-v1.md` (5.303 byte) | `…S12r3…/21-prompt-v2.md` (5.706 byte) |
| uscite congelate | `analysis/p4-output/S12r2-lettore-v1/M-corsa1.jsonl` | `analysis/p4-output/S12r3-lettore-v2/M-corsa1.jsonl` |
| esito (riferimento a 95) | 34 chiusi, 31 identici, 50/95 | 45 chiusi, 36 identici, 68/95 |

**Uguale nelle due condizioni** (letto dai due `23-lancia.R`): la vista dello studio
(`analysis/audit/2026-11-09-lettore-studio/60-viste-v0.jsonl`, SHA-256 `2382a9ef…6d86e`), il modello
(`mistralai/Mistral-Small-3.2-24B-Instruct-2506`, revisione `95a6d26c…`), `temperature` 0, `repetition_penalty` 1,1,
`max_model_len` 65536, `max_tokens` 24576, vLLM 0.20.2, 4 lavoratori da 1 GPU su `poddgx02`,
`VLLM_BATCH_INVARIANT=1`, `HF_HUB_OFFLINE=1`. Il lavoratore (`inst/dgx/python/run_p4_vllm.py`) passa al modello
solo lo schema come vincolo (`StructuredOutputsParams(json=schema)`): descrizioni, titolo e `$id` dello schema non
entrano nel messaggio.

## 2. Le differenze, una per riga

Sigle: una reversione dal lato B porta la sigla della differenza (`A1`, `P`, …); un'aggiunta dal lato A porta la
stessa sigla con una `a` davanti (`aA1`, …). «Forma» = schema + prompt di una corsa.

### Schema

| n. | differenza | condizione A | condizione B | variante dal lato B (toglie) | variante dal lato A (mette) |
|---|---|---|---|---|---|
| 1 | **A1, ordine dei campi del fattore** | la colonna prima dei livelli: `name, type, source_columns, levels, baseline_level, baseline_evidence, assignment` | i livelli prima della colonna: `name, type, levels, baseline_level, baseline_evidence, assignment{column, values}` | `RA1`: il campo `source_column` prima di `levels`, `assignment` senza `column` | `A0A1`: `source_columns` dopo `baseline_evidence` |
| 2 | **A2, una colonna per fattore** | un fattore legge una o più colonne (`source_columns`), ogni voce ha una lista di condizioni (`when`: colonna + valore) | un fattore legge una colonna sola, ogni voce è `value` + `level` | non esprimibile da B0 (limite 1 di §6) | `A0A2`: `source_column` + `assignment.values` |
| 3 | **A3, elenchi chiusi** | nomi di colonna e valori sono stringhe libere; `series_id` libero | la colonna è una di quelle della tabella dei campioni (senza `gsm` e senza le colonne costanti), i valori sono quelli della colonna, `series_id` è fisso | `RA4A3` contro `RA4` (solo dopo A4: limite 2) | `A0A3` (da A0) e `A0A2A3` contro `A0A2` |
| 4 | **A4, la tupla dei valori** | le voci sono una lista aperta | una voce per ogni valore distinto della colonna, nell'ordine della tabella (`prefixItems`) | `RA4`: lista aperta di voci, valori a elenco chiuso | `A0A2A3A4` contro `A0A2A3` (solo dopo A2 e A3: limite 2) |
| 5 | **C, il blocco delle colonne** | `other_columns`: lista aperta, solo le colonne che non sono fonte di un fattore, ruoli `subject`, `replicate`, `uninformative` | `columns`: una voce per ogni colonna, in ordine, col ruolo `factor` in più; `subject_kind` e `missing_values` legati al ruolo | `RC` | `A0C` |
| 5b | **C3, parte di C** | `subject_kind` e `missing_values` liberi per ogni ruolo | legati al ruolo (`anyOf` di tre rami) | `RC3`: la tupla resta, il legame no | (dentro `A0C`) |
| 6 | descrizioni, `title`, `$id`, `$schema` | presenti | assenti o diversi | nessuna variante: non entrano nel messaggio. Il ponte (§4) le prova | |
| 7 | **canale dello schema** | file `schema.json` del bundle | campo `schema` di ogni record | nessuna variante: in S12r4 ogni forma, anche A0, passa lo schema nel record. `A0` contro `M-corsa1.jsonl` di S12r2 la misura | |

### Prompt (17 righe diverse su `diff`)

| n. | differenza | variante dal lato B | variante dal lato A |
|---|---|---|---|
| 8 | **P, quattro frasi sulla scelta della colonna** (solo nel prompt v2) più la clausola di `not_understood` che le accompagna. `Pa`: «Choose the column that states the factor for every sample.» `Pb`: la stessa variabile scritta in due o più colonne. `Pc`: due fattori possono leggere la stessa colonna. `Pd`: se nessuna colonna dice il fattore per tutti i campioni, il fattore non si scrive (con la clausola) | `RP` (tutte e quattro), `RPa`, `RPb`, `RPc`, `RPd` (una per volta) | nella catena: `RA1` contro `RA1P` |
| 9 | **P5, una frase**: «to the values of the samples outside it» (v2) contro «to the samples outside it» (v1) | `RP5` | nella catena: `RA1P` contro `RA1PP5` |
| 10 | testo di C: quattro passi che descrivono il blocco delle colonne | con `RC` | con `A0C` |
| 11 | testo di A1: tre passi (dove si scrive la colonna) | con `RA1` | con `A0A1` (un passo) |
| 12 | testo di A2: quattro passi (una colonna, voci `value`/`level`) | — | con `A0A2` |
| 13 | testo di A4: un passo («one entry for every distinct value …, in the order …») | (sta nel paragrafo R: limite 3) | con `A0A2A3A4` |
| 14 | **R, la stesura del paragrafo sulle voci**: stesso contenuto dopo A2 e A4, parole e ordine diversi; la frase «`gsm` and the constant columns cannot be the column of a factor» sta qui | `RR` | `A0A2A3A4R` contro `A0A2A3A4` |

Il testo che descrive un campo cambia insieme allo schema di quel campo (righe 10-13): un prompt che descrive un
campo che non esiste non è una condizione leggibile. Le eccezioni sono dichiarate nel limite 3.

**L'elenco è completo, e si prova.** Il prompt v1 con i cambi `aA2`, `aA4`, `aR` è uguale byte per byte al prompt
v2 con i cambi `A1`, `P`, `P5`, `C`; lo schema v1 con `aA2`, `aA3`, `aA4` è uguale allo schema generato con `A1` e
`C`, a meno di descrizioni, `title`, `$id` e `$schema` (47 studi su 47: `11-out.txt`, «il ponte»). Se mancasse una
differenza, le due forme non coinciderebbero.

## 3. Le due correzioni di forma (varianti a sé, dal lato B)

| sigla | che cosa cambia | per quale studio |
|---|---|---|
| `F1` | via l'elenco `levels`: i livelli di un fattore sono i nomi scritti nelle voci; ogni voce porta `entity`, `dose`, `duration`. Ordine del fattore: `name, type, baseline_level, baseline_evidence, assignment` | `GSE50499` (livello della voce non dichiarato in `levels`) |
| `F2` | i due nomi riservati (`not stated`, `not applicable`) sono valori ammessi di un campo a parte: ogni voce è `value` + `level`, oppure `value` + `special` a elenco chiuso | `GSE63816` (nome riservato scritto in una forma che lo schema non lega) |
| `F12` | F1 e F2 insieme | |

## 4. Le forme e le corse (31 forme, 34 corse)

- **Lato B, un cambio da B0 (12):** `RP`, `RPa`, `RPb`, `RPc`, `RPd`, `RP5`, `RC`, `RC3`, `RA1`, `RA4`, `RR`; e
  `RA4A3` (due cambi: A3 non si esprime senza A4).
- **Lato A, un cambio da A0 (4):** `A0C`, `A0A1`, `A0A3`, `A0A2`.
- **La catena, un cambio per volta da A0 a B0 (8 passi, 9 forme):**
  `A0` →aA2→ `A0A2` →aA3→ `A0A2A3` →aA4→ `A0A2A3A4` →aR→ `A0A2A3A4R` ≡ `RA1PP5C` →(colonne)→ `RA1PP5` →(P5)→
  `RA1P` →(P)→ `RA1` →(A1)→ `B0`. `A0A2A3A4R` e `RA1PP5C` sono **il ponte**: due forme costruite dai due lati, con lo
  stesso prompt e lo stesso schema. Si corrono tutte e due.
- **Le correzioni di forma (3):** `F1`, `F2`, `F12`.
- **I placebo (4):** `B0pl1`, `B0pl2`, `A0pl1`, `A0pl2`. Una frase del prompt riscritta senza cambiare il senso
  (`pl1`: «You receive one GEO series:» → «You are given one GEO series:»; `pl2`: «Use an empty array if there are
  none.» → «If there are none, use an empty array.»). Misurano quanto si sposta la tabella dei fattori per un
  cambio di parole che non dice niente: è il rumore contro cui si legge ogni cambio di testo.
- **Le basi:** `B0` (due corse) e `A0`.
- **La forma finale `FIN`:** decisa dalla regola di `00-previsioni.md`, scritta in `30-forma-finale.txt` prima delle
  sue corse, due corse.

Corse: 31 forme + la seconda di B0 + 2 di FIN = **34**. Ogni corsa copre i 47 studi di sviluppo. Circa 4 minuti di
generazione per corsa più il carico del modello: la stima è 2-3 ore con due job da 4 GPU alla volta, sotto il
limite di 4 ore oltre il quale decide il PI.

## 5. Perché l'ordine dei campi conta, e il controllo che lo misura

Il modello scrive l'uscita un token per volta, nell'ordine dei campi dello schema. A temperatura 0 e con
`VLLM_BATCH_INVARIANT=1`, quello che viene dopo non può cambiare quello che è già scritto. Il blocco delle colonne
si scrive dopo `factors`: lo **schema** di quel blocco non può cambiare i fattori (il **testo** del prompt sì,
perché il modello lo legge prima). Controllo: `RC3` cambia solo lo schema del blocco delle colonne, e il blocco
`factors` della sua uscita deve essere identico a quello di B0 in 47 studi su 47 (previsione 2). Se non lo è, il
vincolo dello schema agisce anche all'indietro e l'argomento non vale.

## 6. Limiti, dichiarati prima

1. **A2 non si toglie da B0.** Senza «una colonna per fattore» la tupla e gli elenchi chiusi chiedono un altro
   disegno dello schema. A2 si prova solo in una direzione (`A0` → `A0A2`).
2. **A3 e A4 sono annidati.** Da B0 l'elenco aperto dei valori (A3) esiste solo senza la tupla (A4); da A0 la tupla
   esiste solo dopo A2 e A3. Per questi due la prova «toglie» e la prova «mette» partono da forme diverse.
3. **Nelle reversioni di solo schema il testo resta.** `RA4`, `RA4A3`, `RC3` e `A0A3` cambiano lo schema e non il
   prompt: in `RA4` il prompt chiede ancora una voce per ogni valore, nell'ordine. Misurano il vincolo, non la frase.
4. **L'ordine dei passi nella catena è una scelta.** Dal lato A: A2, A3, A4, R (l'unico ordine che i limiti 1 e 2
   ammettono). Dal lato B: colonne, P5, P, A1. Un altro ordine può dare un altro passo «che mette» quando l'errore
   chiede due cambi insieme: per questo la regola di diagnosi chiede anche la prova «toglie».
5. **Ogni testo intermedio è una scelta di parole dell'agente.** I placebo ne misurano il peso.
6. **`A0A3` toglie `gsm` e le colonne costanti dalle fonti ammesse** (come lo schema generato); `series_id` fisso
   sta con l'elenco chiuso.
7. **`RA1` cambia insieme ordine e posto del nome della colonna** (`source_column` nel fattore al posto di
   `column` in `assignment`): le due cose non si separano.
8. **`F1` scrive il livello di base prima delle voci** (l'ordine degli altri campi non cambia). **`F2`** aggiunge
   il campo `special` e non vieta `"level": "not applicable"` scritto come livello normale: l'adattatore lo tratta
   come riservato, come oggi. Con `F1` un livello che è un nome riservato solo a meno di maiuscole e segni dà il
   motivo `riservato_altra_forma` e lo studio non chiude.
9. **`A0C` ha il motivo `ruolo_incoerente`** (una colonna col ruolo `factor` che nessun fattore legge, o il
   contrario), `A0` no: è la regola di S12r3, che vale dove c'è la tupla delle colonne.
10. **La firma della tabella dei fattori** (tipo, fonti, partizione, base di ogni fattore, più i soggetti) differisce
    fra A0 e B0 in 27 studi su 47 anche con gruppi identici (`11-firme-A0-B0.csv`): è sensibile per costruzione.
    Serve a scegliere che cosa leggere, non a contare errori.
11. **Quarta lettura degli stessi 47 studi.** Ogni scelta di questa carta è fatta da chi conosce già gli errori:
    la regola di diagnosi è scritta prima per questo, e la forma finale non si sceglie dal numero dei confronti.

## 7. Lo strumento di misura

Uno per tutte le forme: `adatta_forma()` valida l'uscita contro lo schema della sua forma, la traduce nella forma
v1 e chiama `adatta_v1()` di S12r2 senza cambi; le misure sono quelle di S12r3 (riferimento a 95, misura su 97
accanto). In più, per ogni studio e forma:

- i **predicati** dei 4 errori di lettura di S12r3 (`GSE57945`: `Sex` è fonte di un fattore; `GSE60340`: nessun
  fattore legge `treated with`; `GSE49155`: la cella vuota di `cell type` ha un livello non riservato; `GSE46665`:
  almeno 5 delle 9 sigle dei pazienti sono fra i livelli);
- due **conti generici**, che non nominano uno studio: `fattori_doppi` (due fattori con la stessa partizione dei
  campioni) e `soggetto_costante_nei_gruppi` (una colonna col ruolo `subject` e tipo `donor` che non cambia dentro
  nessun gruppo del lettore: ripete i gruppi, non distingue i donatori; non distingue il caso vero di un donatore
  per gruppo con repliche tecniche);
- la **firma** della tabella dei fattori e le **unità di disaccordo** di S12r2 e S12r3 (studio non chiuso,
  partizione non identica, confronto di Atlas non ritrovato, confronto del lettore giudicato errore).

Cancello dello strumento sulle uscite congelate (`11-out.txt`): con A0 ridà i numeri di S12r2 (34, 31, 50/95,
50/97, i 13 non chiusi), con B0 quelli di S12r3 (45, 36, 68/95, i 2 non chiusi, le 40 unità di disaccordo, le 13
di lettura del modello nei 4 studi); i predicati vedono i 4 errori in B0 e solo `GSE46665` in A0; il conto dei
soggetti vede `source_name_ch1` in `GSE50760` e `GSE71595`.

## 8. Decisioni tecniche dell'agente (scritte prima delle corse)

- Lo schema passa nel record per ogni forma, anche A0 (un solo canale per 34 corse).
- La base del lato A è la corsa `A0` di S12r4, non le uscite di S12r2; la base del lato B è la prima corsa di `B0`.
- Prima delle corse una prova di compilazione su `poddgx02` (`12-prova-compilazione.R`): uno studio finto con lo
  schema di ogni forma, più lo schema più grande di ogni forma. Se vLLM non compila lo schema di una forma, si
  cerca la causa. Una riscrittura equivalente dello schema (le stesse uscite ammesse) si fa prima delle corse, con
  un'aggiunta datata a questa carta. Se non esiste, la forma non si corre e il suo esito è «non valutabile». Dopo
  la prima corsa nessuno schema e nessun prompt cambia.
- Le uscite congelate stanno in `analysis/p4-output/S12r4-forme/<forma>.jsonl`, con SHA-256.
- Gli 82 studi di giudizio restano chiusi: ogni script passa da `solo_sviluppo()` e si ferma su uno studio non di
  sviluppo.
