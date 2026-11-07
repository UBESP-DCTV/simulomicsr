---

editor_options: 
  markdown: 
    wrap: 72
---

# HANDOUT — I difetti aperti, divisi in sessioni

**Scritto:** 2026-08-21 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato **Deliverable corrente:** A3 v16 `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d` (194 meta-analisi)

> **Come si usa.** Ogni sessione ha un obiettivo solo, dice che cosa fare e che cosa NON fare, dice come si capisce che è finita, e quasi tutte finiscono con **una decisione che spetta a te**. In fondo a ciascuna c'è il **prompt da incollare**.
>
> **Regola d'oro: una sessione, un obiettivo.** Se salta fuori altro, si scrive e si rimanda.
>
> **Nessuna fretta.** Il deliverable è scientifico. Meglio una sessione in più che un numero non verificato.

## ⚠️ Due cose da sapere PRIMA di aprire qualunque sessione

**1. `CLAUDE.md` punta al deliverable sbagliato.** Dichiara `20260815T193851Z-stage4-v16-3e31e59d` **(211 meta-analisi)**. Il deliverable corrente è `20260819T185517Z-stage4-v16-3e31e59d` **(194)**. Esistono entrambi, hanno la stessa forma, e il vecchio è usato come *riferimento* da `10-blocchi.R`: una sessione che si fida delle istruzioni permanenti **lavora sull'oggetto sbagliato** — che è il difetto tipico di questo progetto. **S1 lo corregge. Fino ad allora, aggiungi questa riga in testa a ogni prompt che tocca i dati:**

```         
Il deliverable e'
/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d
(194 meta-analisi), NON quello che dice CLAUDE.md.
```

Serve a **tutti i prompt tranne S3, S1, S8 e S4**, che ce l'hanno già dentro o non toccano i dati.

**2. Il comando R giusto è `Rscript` SENZA `--vanilla`.** `CLAUDE.md` dice il contrario per il laptop, e si sbaglia: con `--vanilla` mancano `devtools` e `arrow`. Tutti gli script di audit lo dicono già in testata. **S1 deve correggere anche questo**, altrimenti la riscrittura porta avanti l'errore.

------------------------------------------------------------------------

## Il quadro, in parole semplici

Abbiamo 194 meta-analisi. Le abbiamo lette tutte. I verdetti sono **116 corrette, 62 difettose, 16 incerte**; i gruppi che contengono almeno un difetto sono **66** (le 62 difettose più 4 delle incerte) — due conteggi diversi che non vanno confusi.

Abbiamo misurato quanto pesano quegli errori: poco nei gruppi grandi (8,8% del peso), tanto nei piccoli (38,4%).

**Ma la misura che dice se i difetti contano davvero è una terza, e va letta insieme alle prime due:** confrontando la rimozione degli studi accusati con 20 rimozioni casuali di studi *puliti* della stessa taglia, in media sono **indistinguibili** (percentile 0,50 / 0,33 / 0,50; Wilcoxon p = 0,59 / 0,46 / 0,39). Cioè l'influenza misurata è in gran parte quella del **togliere dati**, non del difetto. **Però la coda supera il caso**: 12 gruppi su 45 stanno sopra il 90° percentile contro 4,5 attesi (binomiale **p = 0,0012**; ⚠️ è il migliore dei tre test — gli altri due danno 0,032 e **0,159**, quest'ultimo non significativo, e la molteplicità non è corretta), e **tre li superano su tutte e tre le statistiche — `IL22`, `obese`, `sals`**.

E il vero collo di bottiglia **non sono gli errori**: è che in gran parte dei gruppi un solo studio porta più della metà del peso. Filtrando tutto si arriva a un **nocciolo di 37 meta-analisi senza asterischi**, che è **contenuto** nelle **173 che restano in piedi togliendo i difetti** — non sono due gruppi separati: 37 + 173 farebbe 210, e le meta-analisi sono 194.

> ⚠️ **I 173 non sono 173 puliti**, e questo cambia la decisione di S5: sono **128 senza difetti più 45 che i difetti li contengono ancora** («sopravvivono» significa solo che toglierli non li ucciderebbe). Quei 45 hanno peso contaminato mediano **14,7%**, massimo **47,7%**, sette sopra il 25%. E dei 128 «puliti», **87 su 128 sono dominati** da un solo studio e **53 valgono meno di due studi efficaci** (68% e 41%; le percentuali pubblicate altrove dicono 69% e 42% perché il denominatore lì è 126, i due con la misura mancante). **`IL22`, `obese` e `sals` — i tre casi in cui l'evidenza dice che il difetto sposta davvero il risultato — stanno nei 173 e non nei 37.**

## Le tredici cose aperte

**Le sessioni sono numerate nell'ordine in cui vanno fatte.**

| # | | si chiude in |
|---|---|---|
| 1 | `CLAUDE.md` è 2.364 righe e nessuno lo pota | S1 |
| 2 | Il deliverable esiste in una copia sola, fuori dal repository, fra quattro cartelle omonime | S2 |
| 3 | ~~Non sappiamo se la lettura delle 194 sia riproducibile~~ **riproducibile: kappa 0,78 su 194; con l'umano 18/19 (S3)** | S3 |
| 4 | ~~I bracci che **condividono il controllo** gonfiano il peso~~ **misurato: taglio 113→41; il PI corregge varianza e ruoli in S13 (S4)** | S4 |
| 5 | ~~Non è deciso se l'articolo è 37 o 173, né se il gate resta a k≥3~~ **deciso: gate a 3 studi, le 40 come insieme principale, le altre 132 in supplementare (S5)** | S5 |
| 6 | ~~Nessuna verifica usa dati esterni al corpus~~ **eseguita sul deliverable di oggi: 14 su 19 e 39 su 53 contro LINCS, 11 su 32 contro Tahoe (S7). Il numero dell'articolo viene dalla seconda esecuzione, in S13** | S6 → S7 → S13 |
| 7 | ~~Non è deciso se rifare il run completo~~ **Il PI ha scelto il re-run completo dopo la prova (S8b, 2026-11-05): 24.394 studi da zero, in un solo run** | S8 → S8b ✅ → S14 |
| 8 | ~~Le lettere greche sbagliano in 45 prove su 90~~ **misurato su tutto lo Stadio 3 (S9): 7 meta-analisi su 194 cambiano; la sola traduzione toglie 15 studi a TNF. Il PI fa scrivere la correzione in S12b** | S9 ✅ → S12b → S13 |
| 9 | ~~`.lane_index()` va in crash su un **titolo NA**, e con lei `build_lane_library_lookup()`~~ **corretto con due test (S9, `6996f73`)** | S9 ✅ |
| 10 | ~~Il rilevatore di difetti in produzione ne segnala 2 su 1.903~~ **misurato (S10, 2026-11-07): la regola corretta sulle etichette prende 10 confronti difettosi su 129 con 51 falsi allarmi su 1.704; i difetti sono asimmetrici. Sui fatti dei campioni (S10b, 2026-11-07) la combinazione proposta prende 43 su 129 con 40 falsi allarmi; il PI la manda alla lettura (S11). Letta (S11, 2026-11-07): 37 allarmi su 56 sono errori veri, 18 errori della regola; il riferimento sale da 129 a 193 e il rilevatore ne vede 81. Il PI: nessuna soglia di errore, ogni causa si corregge in S12** | S10 → S10b → S11 → S12 → S13 |
| 16 | **Tabelle dei nomi agganciate per numero d'ordine** (S10, 2026-11-07): negli studi rigenerati il nome cade su altri campioni; nel deliverable 283 confronti su 1.903 hanno un nome diverso sul primo campione trattato, nel master da zero il 70% dei record agganciati cambia o manca. **Il PI fa correggere l'aggancio in S12d** | S10 → S12d → S13, S14 |
| 11 | Se si rifà il run, la rilettura a mano delle 194 va in parte rifatta | S15 |
| 12 | Le figure dell'articolo descrivono un deliverable che non esiste più | S16 |
| 13 | I limiti misurati non sono scritti da nessuna parte | S17 |
| 14 | **Studi doppi** (2026-11-03): due o tre numeri GEO con gli stessi dati, in 13 gruppi. **Il PI li toglie (2026-11-04)** con una regola sulle conte | S5 → S12 → S13 |
| 15 | **Una entità con più nomi** (2026-11-07): il calcitriolo sta in quattro gruppi (14 studi, due meta-analisi del deliverable); altre candidate dal nome (irradiation/radiation, asthma/asthmatic, ifna/IFNA1, nash/NAFLD). Il modello scrive il nome giusto con un ID ChEBI sbagliato, e il codice si fida dell'ID. **Il PI apre una sessione (2026-11-07)** | S9 → S12c → S13 |
| 17 | **Validazione con meta-analisi pubblicate** (proposta del PI, 2026-11-07): cercare meta-analisi pubblicate che usano gli stessi studi GEO e vedere se il nostro metodo le ritrova | S7b |

**Tre cose non si chiudono, si dichiarano** — sono materiale per S17, non sessioni: il **bias concorde** (invisibile a qualunque leave-one-out), il **16,5% di verdetti che l'etichetta non chiude** — 32 su 194, che sono un insieme **diverso** dai 16 con verdetto «incerta»: 16 incerte + 13 difettose + 3 corrette (il metadato GEO non dice abbastanza) — i **1.993 campioni persi dallo Stadio 2** (5,3%: potenza buttata, non risultati sbagliati).

## La mappa

**Le sessioni sono numerate nell'ordine in cui vanno fatte.** S1 per prima, S17
per ultima. Non è obbligatorio seguirlo — la colonna «serve prima» dice quali
sono i veri vincoli — ma se lo segui non sbagli.

| # | sessione | tipo | durata | serve prima |
|---|---|---|---|---|
| **S1** | Pulizia di `CLAUDE.md` | igiene | ~3 h | — |
| **S2** | Mettere in salvo il deliverable | igiene | ~2 h | — |
| **S3** | Il metro concorda con se stesso? ✅ | misura | ~4 h | — |
| **S4** | Il controllo condiviso, e il peso che gonfia ✅ | misura | ~3 h | — |
| **S5** | Le due decisioni: il gate, e «37 o 173» ✅ | **decisione** | ~4 h | *meglio S3 e S4* |
| **S6** | Validazione esterna: il disegno ✅ | disegno | ~3 h | S5 ✅ |
| **S7** | Validazione esterna: l'esecuzione ✅ | misura | ~6 h | **S6** ✅ |
| **S7b** | Validazione con meta-analisi pubblicate sugli stessi studi (proposta del PI, 2026-11-07) | disegno + misura | *da stimare in apertura* | **S14** (deliverable dopo il re-run); *meglio dopo S15* |
| **S8** | La decisione sul re-run completo: prima una prova ✅ | **decisione** | ~2 h | — |
| **S8b** | La prova: 6.000 studi a caso e 300 già rigenerati, poi sì o no: **sì** ✅ | misura | ~17 h | **S8** ✅ |
| **S9** | Le lettere greche, e il crash delle corsie ✅ | misura + 1 fix | ~4 h | — |
| **S10** | Il rilevatore: costruirlo e misurarlo ✅ | misura | ~4 h | *meglio S3* |
| **S10b** | Il rilevatore sui metadati dei campioni (decisione del PI, 2026-11-07) ✅ | misura | ~4-6 h | **S10** ✅ |
| **S11** | Il rilevatore: leggere i falsi allarmi (56 righe, elenco di S10b) ✅ | lettura | una sessione | **S10b** ✅ |
| **S12** | Il rilevatore: portarlo in produzione, senza errori accettati (decisione del PI in S11) | piano + codice (TDD) + misura | *da stimare in apertura: il piano lo decide il PI* | **S11** |
| **S12b** | La chiave d'entità: greche, citochine in lettere latine, negazione | codice (TDD) + misura | ~4-6 h | **S9** ✅ |
| **S12c** | Una entità con più nomi: il nome scritto dal modello, regola generale | ADR + codice (TDD) + misura + lettura | *da stimare in apertura; più di una sessione S12b* | **S9**, **S12b** |
| **S12d** | Le tabelle dei nomi agganciate ai campioni (decisione del PI, 2026-11-07) | codice (TDD) + misura | ~4 h | **S10** ✅; *meglio prima di S12c, che misura le chiavi con gli anchor* |
| **S13** | Applicare le correzioni (re-cluster + re-pool locali) | calcolo | ~6 h | **S12, S12b, S12c, S12d** *(+ S4)* |
| **S14** | Il re-run completo degli stadi LLM (i due passi col modello ✅ 2026-11-07; restano raggruppamento, pooling e annotazione) | campagna | **~44 h di macchina** (misurate 33 h per i due passi) | **S8b** (sì) ✅ **+ S12** per raggruppamento e pooling; i due passi col modello possono andare prima, se lo sceglie il PI |
| **S15** | Riverificare le meta-analisi cambiate | lettura | *dipende da S14* | **S14** |
| **S16** | Rifare le figure sul deliverable vero | produzione | ~4 h | **S5**, e dopo S13/S14 |
| **S17** | Scrivere i Methods e le limitazioni | scrittura | ~4 h | **S5, S8, S9, S4** |

> **Le prime quattro non dipendono da nulla** e si possono fare in qualunque
> ordine. «Meglio» non è un blocco: avverte che il numero su cui decidi può
> muoversi.
>
> ⚠️ **S9 (2026-11-07) aggiunge due cancelli: S13←S12b e S13←S12c.** S12b e S12c non dipendono da S10-S12.
>
> ⚠️ **I veri cancelli sono sei**, quelli in grassetto: S7←S6, S11←S10, S12←S11,
> S13←S12, S14←S8+S12, S15←S14. Tutto il resto è consiglio.
>
> **Se S8 dice «no» al re-run**, S14 e S15 si saltano e si va da S13 a S16. **S8b ha detto sì (2026-11-05):** S14 e S15 si fanno.

### Se hai tempo per poche sessioni

**Falle in ordine: S1, S2, S3, S4, S5.** Sono le prime cinque, costano fra le due
e le quattro ore ciascuna, e nessuna dipende dalle altre.

Il senso della sequenza, in una riga: **si mette in ordine (S1) e in salvo (S2)
quello che c'è, poi ci si assicura che i numeri siano ripetibili (S3) e giusti
(S4), e solo allora si decide che cos'è l'articolo (S5).**

Se ne fai **una sola, fai S3**: tutti i numeri del progetto vengono da una sola
lettura fatta da un modello che nessuno ha mai controllato. Se non è ripetibile,
il resto è sabbia.

# S1 — Pulizia di `CLAUDE.md`

### Perché

Il file che ogni sessione legge per intero prima di agire è di **2.364 righe e 198 KB**. Le righe 11-1766 — il **74%** — sono il preambolo RED ALERT più **44 blocchi di "Stato"** accumulati da maggio (il primo a riga 38), mai potati.

Il danno non è estetico: in mezzo a quella cronologia ci sono blocchi **già ritrattati** che una sessione nuova può prendere per veri.

### Che cosa si fa

1.  **Prima di spostare qualunque cosa**, si scrive una lista breve — dieci o quindici voci — di **quello che deve restare**: come è fatta la pipeline, le convenzioni, dove stanno i dati, le trappole già pagate. **Quattro voci sono obbligatorie**, perché S13 e S14 senza queste non partono: il comando R che funziona davvero (`Rscript` **senza** `--vanilla`), `setsid` per i run lunghi (`run_in_background` ha già ucciso un run di ore), l'aggiornamento orario durante i run pesanti, e **il percorso del deliverable corrente** — che oggi in `CLAUDE.md` è sbagliato.
2.  Si spostano i 44 blocchi di Stato in `docs/STORIA.md`, in ordine, senza perdere niente, marcando come **ritrattato** quello che lo è.
3.  Si riscrive `CLAUDE.md`: stato attuale in una pagina, convenzioni, trappole, puntatori ai findings.
4.  Si verifica **la lista del punto 1**, voce per voce.

### Che cosa NON si fa

Non si tocca codice né dati. Non si "aggiorna" nessun numero: si sposta. Se un numero sembra sbagliato, si annota e si rimanda.

### Come si sa che è finita

`CLAUDE.md` sotto le **300 righe**, e **ogni voce della lista del punto 1 è ancora dentro `CLAUDE.md`** — non «da qualche parte». Un controllo che verifica solo se i numeri esistono ancora da qualche parte **passerebbe sempre**, perché la storia li contiene tutti: il rischio vero non è perdere un numero, è retrocedere a cronologia qualcosa che serviva sempre.

### La decisione che spetta a te

Ti verranno proposte due o tre versioni della prima pagina. Scegli quella che dice il necessario e nient'altro.

### Prompt

```         
Leggi CLAUDE.md per intero, poi apri
docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la SESSIONE S1,
solo quella.

CLAUDE.md e' 2.364 righe e 198 KB; le righe 11-1766 sono il preambolo RED ALERT
piu' 44 blocchi di "Stato" accumulati da maggio (il primo a riga 38).

PRIMA di spostare qualunque cosa scrivimi la lista di 10-15 voci di quello che
DEVE restare in CLAUDE.md, e fammela approvare. Quattro voci sono obbligatorie:
il comando R che funziona (Rscript SENZA --vanilla: CLAUDE.md oggi dice il
contrario e sbaglia), setsid per i run lunghi, l'aggiornamento orario, e il
percorso del deliverable corrente - che in CLAUDE.md e' quello VECCHIO
(20260815T193851Z, 211 meta-analisi) invece di 20260819T185517Z (194). Correggi
entrambi. Poi sposta i 44 blocchi in
docs/STORIA.md senza perdere niente, marcando come RITRATTATO quello che lo e'.
Poi riscrivi CLAUDE.md sotto le 300 righe.

Alla fine verifica la lista voce per voce: non "il numero esiste ancora da
qualche parte" (passerebbe sempre), ma "questa voce e' ancora dentro CLAUDE.md".

Non toccare codice, non toccare dati, non aggiornare numeri: sposta e basta.
Proponimi due o tre versioni della prima pagina e fammi scegliere.
```

------------------------------------------------------------------------

---

# S2 — Mettere in salvo il deliverable

### Perché

**Il deliverable esiste in una copia sola, su un disco esterno, fuori dal repository.** Sta in `/mnt/wwn-0x5000039d58caca35/`, e ricostruirlo costa 40-60 ore di macchina — sempre che ci siano ancora gli ingressi, che stanno in `analysis/p4-output/` (gitignored, copia unica). Accanto ci sono **quattro cartelle con nomi quasi identici** — e questo handout si apre dicendo che una sessione ha già lavorato su quella sbagliata.

Per un articolo, dati e codice disponibili sono materiale obbligatorio. Qui sono anche **l'unico esemplare**.

### Che cosa si fa

1.  Checksum di tutti i file del deliverable, scritti in un file versionato in git.
2.  Una copia su un supporto diverso.
3.  Un `README` nella cartella che dica **quale delle quattro** è il deliverable, da quale Stadio 3 viene, e con quale master Stadio 2. ⚠️ **Le informazioni stanno in due file, non in uno**: il `run_metadata.json` dello *Stadio 4* ha `stage3$dir` e `clusters_sha256`, ma **il master Stadio 2 è registrato nel `run_metadata.json` dello Stadio 3**.
4.  **E si salva anche quello che serve a ricostruirlo**, che è il pezzo che il piano rischia di mancare: lo Stadio 3 `analysis/p4-output/20260818T110906Z-stage3-v16-7f986159` e i due master `A3-stage1-master-innestato.jsonl` / `A3-stage2-master-innestato.jsonl` stanno sotto `analysis/p4-output/`, che **è gitignored e in copia unica**. Senza quelli, il deliverable non si rifà.
5.  La bozza della dichiarazione di disponibilità di dati e codice.

### Che cosa NON si fa

Non si cancella nessuna delle quattro cartelle finché non è chiaro quale serve.

### Come si sa che è finita

I checksum sono in git, la copia esiste ed è verificata, e aprendo la cartella si capisce in dieci secondi che cos'è.

### La decisione che spetta a te

Dove va la copia, e se le tre cartelle vecchie si tengono o si archiviano.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S2, solo quella.

Il deliverable esiste in UNA copia sola, su un disco esterno, fuori dal
repository, e ricostruirlo costa 40-60 ore. Accanto ci sono quattro cartelle con
nomi quasi identici, e CLAUDE.md punta a quella sbagliata - quindi una sessione
che si fida delle istruzioni permanenti ci lavorerebbe.

Fai: checksum di tutti i file, scritti in un file versionato in GIT; una copia su
un supporto diverso; un README nella cartella che dica QUALE delle quattro e' il
deliverable, da quale Stadio 3 viene e con quale master Stadio 2 (attenzione: il
master Stadio 2 e' registrato nel run_metadata.json dello STADIO 3, non in quello
dello Stadio 4); e la bozza della dichiarazione di disponibilita' di dati e
codice.

E salva anche cio' che serve a RICOSTRUIRLO, che e' il pezzo che rischio di
mancare: lo Stadio 3 analysis/p4-output/20260818T110906Z-stage3-v16-7f986159 e i
due master A3-stage1/stage2-master-innestato.jsonl stanno sotto
analysis/p4-output/, che e' gitignored e in copia unica.

Non cancellare niente. Dimmi dove mettere la copia.
```

---

# S3 — Il metro concorda con se stesso?

> **Va fatta presto, e costa mezzo pomeriggio.** Non dipende da nulla.

> ✅ **Punto 1 fatto il 2026-08-22** (`docs/findings/2026-08-21-S3-il-metro-concorda.md`):
> test-retest su **tutti e 15 i blocchi** (194), stesso modello (Opus 5), prompt
> verificati byte-identici, **ambiente congelato al 19/08**. Accordo **88,1%**
> [83,5; 92,8], **kappa 0,78** [0,70; 0,86], binario 93,3% → **alto** secondo la
> soglia depositata prima del run. Solo 5/194 saltano fra *corretta* e *difettosa*;
> 18 dei 23 disaccordi hanno «incerta» da un lato. `IL22`/`obese`/`sals` confermati.
> Totali 116/62/16 → 113/55/26. **Il primo retest era contaminato** (11/60 agenti
> avevano letto le stringhe grezze e i verdetti originali, scritti dopo il run):
> con agenti dotati di strumenti si congela l'ambiente, non solo il prompt.
> ✅ **Punto 2 fatto il 2026-11-02**: lettura umana su 19 schede su 20 (`08-sals` esclusa,
> non più cieca). Accordo con l'originale **18/19** (94,7%, IC95 esatto 74,0–99,9), kappa 0,91.
>
> ✅ **Inversioni cercate su tutte le 194 il 2026-11-02**
> (`docs/findings/2026-11-02-inversioni-bracci-194.md`): una confermata, `GSE144269` in
> `Carcinoma, Hepatocellular`, che porta il gruppo da **6.590 a 105 geni significativi**;
> 4 studi con un braccio sbagliato. Lo strumento avrebbe visto un'inversione nel 52% degli
> studi. **Vale per S5, S10 e S13**: i 173 contengono errori che il setaccio non vede, e tutti
> questi errori si leggono nelle stringhe grezze, non nell'etichetta. Prossima: **S4**.

### Perché

Tutto quello che sta in questo handout — i **116/62/16**, i 66 gruppi, i 97 difetti, i 128, i 173, i 37, il peso contaminato, i nulli, il denominatore di S10, il setaccio di S5, la selezione di S16 — esce da **una sola lettura**, fatta da un modello, che **nessun umano ha mai controllato**.

Il precedente del progetto è pesante: sugli stessi 213 gruppi, con lo stesso materiale, un modello ne dichiarò incoerenti **24** e la lettura umana **96** — accordo **36,2%**.

**Non sappiamo se i 116/62/16 siano riproducibili o siano un'estrazione fra le tante.** È l'unico numero che manca, ed è quello da cui dipende tutto il resto.

### Che cosa si fa

Si prendono **venti** delle 194 — scelte a caso, col seme scritto prima — e si rilegge ciascuna **due volte**:

1.  **una seconda volta con lo stesso metodo** (lettore, due critici, arbitro), partendo dallo stesso materiale, per misurare **quanto il metodo concorda con se stesso**;
2.  **a mano da te**, per misurare **quanto il metodo concorda con un umano** — che è la cosa che il precedente del progetto accusa (accordo 36,2%), quindi il campione grosso va **qui**, non al confronto del metodo con sé stesso. Dividile come preferisci fra le venti; se ne leggi solo cinque, con cinque non si distingue un accordo del 36% da uno del 90%, e va scritto.

⚠️ **Quattro cose che rendono il punto 1 meno banale di come suona, e vanno risolte prima di lanciare:**

- **`10-blocchi.R` non sa selezionare venti gruppi.** L'unica manopola è `PER_BLOCCO`; lo script ordina tutte e 194 e le distribuisce a giro. Serve un modo di costruire il blocco dei venti estratti.
- **Il workflow è cablato su 194.** In `analysis/audit/2026-08-20-rilettura-194/C1-workflow-rilettura.js` c'è `BLOCCHI = Array.from({length: 15}, …)` e il prompt del lettore dice «Sono 13 gruppi»: falso per un giro da venti.
- **Cambiando la composizione del blocco si cambia il metodo**, perché i critici ricevono i verdetti del lettore *di tutto il blocco* e l'arbitro rilegge il blocco intero. Per un test-retest onesto conviene **rifare un blocco intero già letto** invece di comporne uno nuovo coi venti estratti: si perde la casualità della selezione e si guadagna che il metodo resta identico. **Scegli quale delle due e dichiara perché.**
- ⚠️ **E c'è un limite che va detto:** i prompt in `C1-workflow-rilettura.js` sono stati **recuperati** il 2026-08-21 dopo essere andati persi. Sono lo script vero del workflow eseguito, ma se per qualunque ragione non fossero verbatim, S3 misurerebbe una *ricostruzione* contro l'originale — che non è un test-retest. Verificalo prima.

Poi si confrontano i verdetti e si conta l'accordo.

### Che cosa NON si fa

Non si cambia nessun verdetto delle 194. Questa sessione **misura**, non corregge.

### Come si sa che è finita

Ci sono **due numeri, ciascuno con scritto su quanti gruppi è calcolato** — e la ripartizione la scegli tu al punto 2, non è fissata qui. ⚠️ Se scegli di rifare un **blocco intero già letto** (l'opzione che tiene il metodo identico), i gruppi sono **13**, non 20: va bene, basta dichiararlo.

### La decisione che spetta a te

Dipende dal risultato, ed è per questo che va fatta presto:

- **accordo alto** → ogni numero dell'handout acquista una barra d'errore e si va avanti tranquilli;
- **accordo basso** → S5 sta per decidere «37 o 173» su un'estrazione, e S10 sta per misurare la sensibilità contro un metro instabile. **Allora la rilettura va rifatta prima di tutto il resto**, e questo handout va riscritto.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S3, solo quella. Il deliverable e'
/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d
(194) - NON quello che dice CLAUDE.md.

I 116/62/16 e tutto quello che ne discende vengono da UNA sola lettura fatta da un
modello, mai controllata da un umano. Precedente: sugli stessi 213 gruppi, modello
24 incoerenti contro 96 della lettura umana, accordo 36,2%.

PRIMA di lanciare, risolvi tre cose e dimmi come:
- 10-blocchi.R non sa selezionare venti gruppi (l'unica manopola e' PER_BLOCCO, e
  distribuisce tutte e 194 a giro);
- il workflow in analysis/audit/2026-08-20-rilettura-194/C1-workflow-rilettura.js
  e' cablato su 194 (BLOCCHI = 15, e il prompt del lettore dice "sono 13 gruppi");
- cambiando la composizione del blocco CAMBIA IL METODO, perche' i critici
  ricevono i verdetti del lettore di tutto il blocco. Valuta se convenga rifare un
  BLOCCO INTERO gia' letto invece di comporne uno coi venti estratti, e dichiara
  la scelta.
E verifica che i prompt in quel file siano verbatim: sono stati recuperati dopo
essere andati persi, e se non lo fossero misureresti una ricostruzione.

Poi rileggi con lo stesso metodo e dammi le schede da leggere a mano IO - il
campione grosso va sul confronto con l'umano, che e' quello che il precedente
accusa (36,2%), non su quello del metodo con se stesso.

Alla fine due numeri, con scritto su quanti gruppi ciascuno.
Non cambiare nessun verdetto: qui si misura, non si corregge.
```

------------------------------------------------------------------------

---

# S4 — Il controllo condiviso, e il peso che gonfia

> ✅ **Misurata il 2026-11-02, chiusa il 2026-11-03** (`docs/findings/2026-11-02-S4-controllo-condiviso.md`).
> **492 bracci su 1.118** condividono il controllo (171 coppie, 109 gruppi). `SE` corretta/attuale:
> **mediana 1,20**, massimo 2,73. **Taglio 113 → 41** con tutti e tre i trattamenti (varianza
> corretta, GLS, fusione): entrano `psoriasis`, `Parkinson Disease`, `ykl 5 124`, `bipolar disorder`,
> non esce nessuno. Geni significativi −3,1% nel totale, ma 20 gruppi su 108 ne perdono oltre il 20%
> (`multiple sclerosis` 1.082 → 53, `Arthritis, Rheumatoid` 2.833 → 932).
> ⚠️ **Il cancello di riproduzione ha trovato un difetto di produzione: 3 bracci con i ruoli sbagliati**
> (`GSE222992`, `GSE208347`, `GSE135485`): la cache rende le colonne in un altro ordine e la pipeline
> assegna i ruoli per posizione. **Due cancelli sono falliti come depositati**, spiegati nel finding.
> **Decisioni del PI (2026-11-03):** (1) si corregge solo la varianza (T1), nel calcolo di S13;
> (2) i ruoli si assegnano per nome del campione, prima di ogni nuovo calcolo, e i tre bracci si
> correggono in S13; (3) la misura vale, con i due cancelli falliti e spiegati. Prossima: **S5**.
> I numeri qui sotto sono quelli di prima della misura, e `59 dei 113` conta tutti gli
> studi multi-braccio: quelli col dominante che condivide il controllo sono **23**.

### Perché

**Ventisei verdetti su 194 nominano lo stesso fenomeno, e nessuna sessione lo raccoglie.** L'arbitro l'ha escluso da `difetti.csv` per una regola corretta *per il suo compito*: «raddoppia il peso dello studio, ma **non rompe il contrasto**». Quindi è fuori dal setaccio, dalla leave-one-out, dai nulli, da S10-S11-S12.

> ⚠️ **Attenzione: l'arbitro l'ha chiamato «duplicazione», e non lo è.** Lui guardava la scheda — etichette e numeri identici — non i campioni. Misurato sui **121 entry / 56 chiavi** che hanno etichetta identica nello stesso (gruppo, studio):
>
> |                                                        |              |
> |--------------------------------------------------------|-------------:|
> | chiavi in cui i **trattati** sono gli stessi campioni  |  **0 su 56** |
> | chiavi in cui i **controlli** sono gli stessi campioni | **46 su 56** |
>
> Non è la stessa cosa contata due volte: sono **due bracci trattati diversi che condividono lo stesso pool di controllo**. La differenza è operativa, non terminologica: **deduplicare butterebbe via campioni veri e toglierebbe informazione.**

**Il problema resta, ma è un altro**, ed è già dichiarato nel codice e in nessun documento (`R/stage4-orchestrator.R:209-211`): i bracci condividono il controllo, **la correlazione non è modellata**, e la SE combinata è «lievemente ottimistica». `.collapse_arms_by_study()` (riga 218) li combina a varianza inversa **come se fossero indipendenti**, e non lo sono.

E tocca il numero che decide tutto: **`quota_top1` — il criterio che taglia da 113 a 37 — si calcola su quei pesi.** Misurato: dei 41 gruppi coinvolti, **20 sono dentro i 113**, e **quattro stanno sul confine** (quota 0,50 / 0,50 / 0,51 / 0,51). Più in largo: **59 dei 113 hanno lo studio dominante con più di un braccio.**

### Che cosa si fa

1.  Si contano i bracci che condividono il controllo: quanti, in quanti studi, in quanti gruppi, e quanti di quei gruppi stanno nei 113 e vicino al confine di `quota_top1`.
2.  Si misura di quanto cambia `quota_top1` con un trattamento **corretto**, e le opzioni sono due — **non la deduplicazione**:
    - fondere i bracci che condividono il controllo in **un confronto solo**;
    - applicare una correzione per baseline condivisa. ⚠️ **Non è una spunta da accendere**: `franchini_correction` sta in `config$mega_aug` — il ramo che non è nel deliverable — e `.has_shared_baseline()` / `.build_franchini_V_matrix()` **non hanno chiamanti** fuori dai propri test. È codice scritto e mai chiamato: usarlo è implementazione nuova.
3.  Si dice **quante delle 113 entrerebbero o uscirebbero dai 37.**

### Che cosa NON si fa

**Non si deduplica**: i trattati sono diversi in 56 casi su 56. E non si tocca niente prima di aver misurato.

⚠️ **La funzione da guardare per `quota_top1` è `.collapse_arm_se_by_study()`** (`R/stage4-pooling-effectiveness.R:30`), chiamata da `compute_pooling_effectiveness()`. `.collapse_arms_by_study()` (`R/stage4-orchestrator.R:218`) serve alle **stime poolate**, non a `quota_top1`: sono due catene diverse e vanno guardate tutte e due.

### Come si sa che è finita

C'è il numero: **N bracci a controllo condiviso, e il setaccio 113→37 diventa 113→M** con il trattamento scelto.

**Lo script che produce questi numeri esiste**: `analysis/audit/2026-08-20-rilettura-194/C2-controllo-condiviso.R`. Riproduce 121 entry / 56 chiavi / 0 su 56 trattati identici / 46 su 56 controlli identici / 41 gruppi / 20 nei 113 / 59 dei 113, e ricalcola il setaccio 113→37 da zero. Parti da lì.

### La decisione che spetta a te

Se correggere (e allora rientra in S13) o dichiararlo nei Methods.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S4, solo quella. Il deliverable e'
/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d
(194 meta-analisi) - NON quello che dice CLAUDE.md.

26 verdetti su 194 nominano lo stesso fenomeno e l'arbitro l'ha chiamato
"duplicazione". NON LO E': su 56 chiavi con etichetta identica, i TRATTATI sono
campioni diversi in 56 casi su 56, e i CONTROLLI sono gli stessi in 46 su 56.
Sono due bracci diversi che condividono il pool di controllo. Quindi NON
deduplicare: butteresti via campioni veri.

Il problema vero e' che .collapse_arms_by_study() (R/stage4-orchestrator.R:218) li
combina a varianza inversa COME SE FOSSERO INDIPENDENTI, e il codice lo dichiara
gia' alle righe 209-211 ("la SE combinata e' lievemente ottimistica"). E
quota_top1 - il criterio che taglia da 113 a 37 - si calcola su quei pesi: dei 41
gruppi coinvolti, 20 sono nei 113 e sei stanno vicino al confine (0,50 0,50 0,51
0,51 0,57 0,57). Lo script C2-controllo-condiviso.R riproduce tutti questi numeri:
parti da li'.

Contali, poi misura di quanto cambia quota_top1 con un trattamento CORRETTO - o
fondendo i bracci a controllo condiviso in un confronto solo, o con la correzione
per baseline condivisa - e dimmi quante delle 113 entrano o escono dai 37.

ATTENZIONE alle funzioni: quota_top1 lo calcola .collapse_arm_se_by_study()
(R/stage4-pooling-effectiveness.R:30) via compute_pooling_effectiveness();
.collapse_arms_by_study() (R/stage4-orchestrator.R:218) serve alle STIME poolate.
Sono due catene diverse, guardale entrambe.

E la "correzione di Franchini" NON e' una spunta: franchini_correction sta in
config$mega_aug, il ramo che non e' nel deliverable, e .has_shared_baseline() /
.build_franchini_V_matrix() non hanno chiamanti fuori dai test. E' codice mai
chiamato: usarlo e' implementazione nuova.

Non toccare niente prima di avere il numero.
```

------------------------------------------------------------------------

---

# S5 — Le due decisioni: il gate, e «37 o 173»

> ✅ **Misurata il 2026-11-03, chiusa il 2026-11-04** (`docs/findings/2026-11-03-S5-gate-e-insiemi.md`,
> opzioni e scelta in `analysis/audit/2026-08-21-decisioni/S5-opzioni.md`).
> **Decisioni del PI (2026-11-04):** (1) la misura vale, con il cancello 5(a) fallito e spiegato; (2) il gate
> resta a 3 studi, con il limite nei Methods; (3) le 40 nelle figure principali, le altre 132 in supplementare
> con gli avvisi; (4) gli studi doppi si tolgono in S13, con una regola sulle conte, quindi 41 → 40, 173 → 172,
> 194 → 193; (5) la dominanza si dichiara con una colonna, due livelli e il confronto con studi non collegati.
> **La scelta decade** se S11 sposta più di 5 verdetti fra corretta e difettosa, o anche uno solo dentro le 40,
> oppure se si esegue S14. S13 rigenera le liste con la stessa regola, e non fa decadere la scelta. Prossima: **S6**.
> ⚠️ **Decaduta in S11 (2026-11-07):** 13 verdetti passano da corretta a difettosa, 6 dentro le 40 (calcium atom,
> TNF, 5-aza-2'-deoxycytidine, EGF, IL2, IL13). Nessuna sessione prima del re-run usa le 40: la scelta si rifà una
> volta sola in S15, come già deciso in S8b.
> Il testo qui sotto è quello di prima
> della misura, e tre cose vanno lette corrette. **(1)** I gruppi a due studi sono **282, non 88**: il
> gate agisce anche sul numero di studi del censimento, e `non_processable.rds` non registra quei 194. Dopo
> gli studi doppi sono **273**. **(2)** Fit e pooling non sono «tempo macchina da decidere a parte»: 35
> minuti. **(3)** «Un intervallo di predizione che non esclude nulla» è vero solo con τ̂² > 0: a k=2 esclude 0
> nel 27,3% dei geni significativi. Il numero per la scelta è **40**: 41 meno `sirna pool against igf2bp1`,
> che è un solo studio con tre numeri GEO: il PI ha scelto di togliere gli studi doppi.
> Confronto con studi non collegati, stessa precisione: **3,04 volte nelle 41, 1,19 nelle 96 dominate.**

> **Ricevuto dalla misura del controllo condiviso (S4), da leggere per primo.** Il taglio dei 113 con
> l'errore standard corretto è **41**, non 37: la clausola «la scelta decade se S4 sposta il confine»
> è scattata. Dieci meta-analisi dei 113 perdono oltre il 20% dei geni significativi, fra cui
> `multiple sclerosis` (1.082 → 53) e `Arthritis, Rheumatoid` (2.833 → 932). Il PI ha scelto la
> correzione della varianza: **il numero per questa scelta è 41**. Tre delle quattro nuove stanno
> vicine al limite (`Parkinson Disease` 0,486, `bipolar disorder` 0,491, `ykl 5 124` 0,497). Il
> deliverable su disco resta a T0 fino a S13: la lista delle 41 sta in
> `analysis/audit/2026-11-02-S4-controllo-condiviso/50-per-gruppo.csv`, colonna `in37_1`.
> Finding: `docs/findings/2026-11-02-S4-controllo-condiviso.md`.

### Perché

Sono le decisioni che stabiliscono **che cosa è l'articolo**. Tutto il resto ne discende: quali figure si fanno, che cosa si valida, con che gate si rilancia, e persino quale soglia ha senso in S11.

**Il gate `k ≥ 3`.** Un gruppo diventa meta-analisi solo con almeno tre studi. È la causa del **62,4%** del movimento fra due esecuzioni della stessa catena, e il motivo per cui **21 gruppi su 66** muoiono se togli i loro difetti — non perché il difetto fosse decisivo, ma perché toglierlo lascia due studi.

**«37 o 173».** Applicando i filtri uno sopra l'altro: 194 → 128 (nessun difetto) → 116 («corretta») → **113** (l'etichetta chiude il verdetto) → **37** (nessuno studio oltre metà del peso). I filtri sui difetti portano a 113. È la **dominanza** a portare a 37.

### Che cosa si fa

1.  Si contano — non si stimano — le meta-analisi che **nascerebbero a k=2**: quante e con che k. ⚠️ **E si dice quanto costa, ma con l'argomento giusto.** A k=2 il ramo `rem_group` un I² lo produce — provato: `k=2 REML → I² = 71,5, τ² = 0,129` — quindi **non** è vero che si rinuncia alla misura di eterogeneità. Il costo è un altro: con due studi quella stima ha un'incertezza enorme e un intervallo di predizione che non esclude nulla. **Questa sessione deve misurarlo**, non affermarlo: quanto valgono I² e τ² sui gruppi che nascerebbero a k=2, e con che intervallo. *(Nota: ADR-0026 riguarda il ramo `mega` e la sua specificazione del modello — niente pendenza casuale sul trattamento — non il valore di k. E vive solo sul branch `mega-recovery-2026-07-27`: qui non c'è.)* **La risposta è già su disco**: `non_processable.rds` nella cartella del deliverable ha 122 righe col motivo dello scarto, e **88 sono a `k_eff=2`** (27 a 1, 7 a 0). Il gate è `config$rem_group$k_eff_min` in `run_metadata.json`. ⚠️ **Potenza e dominanza di quei gruppi non esistono finché non sono poolati** (`k_kish`, `quota_top1`, `n_sig` sono output dello Stadio 4). O si accetta la risposta parziale — quante e con che k — **scrivendo che è parziale**, oppure si mette in conto il pooling dei gruppi nuovi, che è tempo macchina e va deciso a parte.
2.  Si mostra che aspetto hanno i due insiemi: entità, k, geni significativi, e che cosa andrebbe dichiarato accanto a ciascuno.
3.  Si scrivono tre o quattro modi di dichiarare il limite della dominanza.

### Che cosa NON si fa

Non si cambia il gate. Non si sceglie al posto tuo.

### Come si sa che è finita

Esiste `analysis/audit/2026-08-21-decisioni/S5-opzioni.md` con le opzioni, i numeri, e **la tua scelta scritta dentro**. Se non scegli in seduta, la sessione **non** è finita: resta aperta finché la scelta non è depositata.

### La decisione che spetta a te

⚠️ **Due cose che questa sessione non sa e che la riguardano:** il numero `quota_top1`, che è il criterio del taglio 113→37, **è gonfiato dal controllo condiviso** e S4 misura di quanto (quattro gruppi stanno sul confine 0,50-0,51); e S11 può spostare righe di `difetti.csv`, da cui escono 128, 66, 173 e 37. Se puoi, fai **S3 e S4 prima**; se non puoi, **scrivi che la scelta decade** se **S4** sposta il confine di `quota_top1`, se S11 sposta più di N verdetti, o se S14 viene eseguita.

- **il gate resta a 3, scende a 2 dichiarando la fragilità, o resta a 3 e la fragilità si dichiara nei Methods?**
- **l'articolo è 37, 173, o entrambi con ruoli diversi** (per esempio 37 in figura, 173 in supplementare)?

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S5, solo quella.

Devo prendere due decisioni e mi servono i materiali, non le tue preferenze.

1) Il gate k>=3: causa del 62,4% del movimento fra le due esecuzioni e del fatto
   che 21 gruppi su 66 muoiono se tolgo i difetti. Contami quante meta-analisi
   nascono a k=2 e con che k. La risposta e' gia' su disco: non_processable.rds
   nella cartella del deliverable ha 122 righe col motivo, di cui 88 a k_eff=2.
   Il gate e' config$rem_group$k_eff_min in run_metadata.json. Se per dire potenza e dominanza serve poolarle,
   DIMMELO e dammi la risposta parziale dichiarandola parziale: non stimare.

2) 37 o 173: fammi vedere i due insiemi - entita', k, geni significativi, e cosa
   andrebbe dichiarato accanto a ciascuno.

E dimmi anche quanto valgono I2 e tau2 sui gruppi che nascerebbero a k=2, con che
intervallo: MISURALO, non affermarlo. A k=2 un I2 esce (provato: REML da' I2=71,5,
tau2=0,129), quindi non e' vero che si rinuncia all'eterogeneita': e' che quella
stima ha un'incertezza enorme, e voglio vederla.

Poi scrivimi tre o quattro modi di dichiarare il limite della dominanza.

DUE COSE CHE DEVI DIRMI PRIMA CHE IO SCELGA, altrimenti scelgo al buio:
- quota_top1, il criterio che taglia da 113 a 37, e' GONFIATO dai bracci che
  condividono il controllo, e S4 misura di quanto: quattro gruppi stanno sul
  confine (0,50 0,50 0,51 0,51). Se S4 non e' ancora stata fatta, dimmelo;
- S11 puo' spostare righe di difetti.csv, da cui escono 128, 66, 173 e 37.
Se possibile facciamo S3 e S4 PRIMA. Se non e' possibile, scrivi nel file che la
mia scelta DECADE se S4 sposta il confine, se S11 sposta piu' di N verdetti, o se
S14 viene eseguita.

Scrivi tutto in analysis/audit/2026-08-21-decisioni/S5-opzioni.md e mettici
dentro la mia scelta. La sessione finisce
quando la scelta e' scritta, non prima. Non scegliere al posto mio.
```

------------------------------------------------------------------------

---

# S6 — Validazione esterna: il disegno

> **Chiusa il 2026-11-04.** Il PI ha scelto: LINCS per il verdetto, Tahoe-100M e TCGA con un ruolo limitato; almeno 8 composti su 19 nel primo 10%; se la causa è il
> metodo, l'articolo dichiara il fallimento e tiene le stime come ipotesi; test adesso e di nuovo dopo le correzioni; 99 estrazioni.
> Disegno: `docs/superpowers/specs/2026-11-04-validazione-esterna-design.md`. Finding: `docs/findings/2026-11-04-S6-validazione-disegno.md`.
> **I numeri di questa sezione sono superati:** i «111» erano candidati (90 agganciati, 77 dei quali nelle 194). Le classi corrette sono 109
> piccole molecole, 45 malattie, 20 ligandi, 8 patogeni, 5 ambientali, 5 biologici, 2 genetiche. La misura vale per 96 meta-analisi su 194 e 24 su 40.
>
> **Ricevuto dalla sessione sul gate e i due insiemi (S5), da leggere per primo.** Il controllo negativo con
> studi non collegati di precisione simile è una validazione interna che costa minuti, e separa gli insiemi:
> 3,04 volte nelle 41, 1,19 nelle 96 dominate (`74-out.txt`). È stato fatto con **una sola estrazione per
> gruppo**, quindi non dà un verdetto per singola meta-analisi, e non ha misurato le 36 non dominate fuori dalle
> 41. **Che cosa serve per chiuderlo:** ripeterlo con molte estrazioni, dopo le correzioni, su tutti i gruppi.
> Da decidere qui se entra nel disegno della validazione. Una risposta generica condivisa alza il nullo: va
> dichiarato. Script: `analysis/audit/2026-11-03-S5-gate-e-insiemi/74-nullo-appaiato.R`.
> **Il PI ha scelto (2026-11-04):** il disegno riguarda le 40 come insieme principale e le altre 132 in
> supplementare, e il confronto con studi non collegati entra nell'articolo. Il punto 4 qui sotto non dipende
> più da «37 o 173».

### Perché

**È il buco più grande che resta, e non è un difetto del codice: è un pezzo di scienza che manca.** Tutto quello che abbiamo verificato usa *lo stesso corpus che ha prodotto il risultato*. Nessuno ha mai chiesto a una fonte **indipendente** se queste stime siano giuste.

> ⚠️ **Il 70% di questa sessione è già stato fatto il 2026-08-07, e va riusato, non rifatto.** In `analysis/audit/2026-08-08-validazione-esterna/` ci sono 26 file, fra cui `copertura-lincs-per-entita.csv` con **111 entità già mappate** (numero di firme, linee, dosi; match per InChIKey via UniChem→ChEMBL), e in `/mnt/wwn-0x5000039d58caca35/lincs-meta/` ci sono **491 MB di metadati LINCS già scaricati**, con SHA256 e URL di provenienza. Una sessione che riscarica tutto rischia di ottenere un numero *diverso* da quello su disco, e poi deve riconciliarli.
>
> ⚠️ **E l'handout dell'8 agosto è scritto su v15 / 214 meta-analisi**: il suo script `10-mappa-entita-lincs.R` contiene `stopifnot(nrow(d) == 214)`. Va usato **per il metodo, non per i numeri**. In più il suo §6 chiede «una misura pilota su un sottoinsieme», che è esattamente ciò che questa sessione vieta: i due documenti danno ordini opposti, e vince questo.

Materiale: `analysis/audit/2026-08-08-validazione-esterna/` e `docs/superpowers/specs/2026-08-08-validazione-esterna-HANDOUT.md`.

### Che cosa si fa

1.  Si **riporta sulle 194** la copertura già misurata sulle 214 (111 entità), e si dichiara quante delle 111 sopravvivono. ⚠️ **E si dichiara il soffitto, che è basso e strutturale.** LINCS mappa solo piccole molecole. Delle 194 entità: 107 sono `small_molecule`, ma **42 sono malattie, 15 citochine, 9 patogeni, 11 ambientali, 9 genetiche e 1 differenziamento** — fuori **per costruzione**. Misurato: 91 delle 111 entità LINCS sono nelle 194, e **dei 37 del nocciolo ne copre 21**. Cioè al meglio si valida **il 47% del deliverable e il 57% del nocciolo**. La domanda «quale fonte» va posta sapendo questo, e accanto va chiesto **che cosa valida l'altra metà** — o si dichiara che resta non validata.
2.  ⚠️ **Si misura la circolarità, e lo strumento esiste già.** `analysis/audit/2026-08-08-validazione-esterna/30-geni-e-circolarita.R` conta gli **studi GEO in comune** fra il nostro corpus e LINCS. Una fonte «esterna» che condivide studi col corpus non è esterna: è la cosa che questa sessione esiste per evitare, e il conto non è mai entrato nel disegno.
3.  Solo se si vuole valutare una fonte **diversa** da LINCS si misura una copertura nuova, e allora serve almeno l'indice: scaricare un indice è permesso, dati pesanti no.
4.  Si scrive il disegno: quali meta-analisi si confrontano, che cosa si misura, **quale risultato conterebbe come fallimento**, quali limiti ha la fonte. ⚠️ Quali? **Dipende da S5** (37 o 173): il disegno va scritto robusto a entrambi gli insiemi, o si aspetta la decisione.
5.  **Si deposita l'ancoraggio della soglia** — è la parte che rende la decisione possibile a chi non è statistico: qual è il valore che si otterrebbe **per puro caso**, e due o tre soglie candidate con scritto accanto, in parole semplici, che cosa significherebbe ciascuna.
6.  **Si pre-impegna la spiegazione del fallimento**, e le spiegazioni sono **tre**, non due: «è il metodo», «è la fonte», e — la più probabile — **«è l'identità»**. L'aggancio a LINCS passa da InChIKey→UniChem→ChEMBL sugli stessi identificativi che S9 dichiara fragili (`IL-1β` → IL1A): se un gruppo è etichettato male si confronta con la firma della molecola sbagliata e fallisce **per forza**. Va deciso adesso quale prova distingue le tre, perché dopo un fallimento «era la fonte» è sempre disponibile.
7.  **Si deposita anche la via d'uscita**: se S7 fallisce e la prova dice «è il metodo», che cosa resta dell'articolo? Chi lo decide? Una validazione senza conseguenza dichiarata in caso di fallimento non è una validazione.

### Che cosa NON si fa

Non si guarda nessun risultato. Non si scaricano dati pesanti.

### Come si sa che è finita

C'è un documento che un estraneo potrebbe eseguire, che dice in anticipo che cosa lo farebbe fallire, e che contiene **la stima di durata di S7**.

### La decisione che spetta a te

**Quale fonte**, e **quale soglia** fra quelle candidate — scegliendo fra opzioni già tradotte in parole, non fissando un numero a freddo.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S6, solo quella. Leggi anche
docs/superpowers/specs/2026-08-08-validazione-esterna-HANDOUT.md.

Tutto quello che abbiamo verificato usa lo stesso corpus che ha prodotto il
risultato. Voglio una validazione ESTERNA, e voglio il DISEGNO prima dei
risultati.

ATTENZIONE, il 70% e' gia' fatto: analysis/audit/2026-08-08-validazione-esterna/
ha 111 entita' gia' mappate su LINCS (copertura-lincs-per-entita.csv) e
/mnt/wwn-0x5000039d58caca35/lincs-meta/ ha 491 MB gia' scaricati. RIPORTA quella
copertura sulle 194 invece di rifarla, e dimmi quante delle 111 sopravvivono.
L'handout dell'8 agosto e' scritto su 214/v15 (il suo script ha
stopifnot(nrow(d)==214)): usalo per il METODO, non per i numeri, e ignora il suo
§6 punto 3 (misura pilota) perche' qui non si guardano risultati.

Se vuoi proporre una fonte DIVERSA da LINCS, allora misurane la copertura
(scarica pure un indice; non dati pesanti).

Poi il disegno: cosa si confronta, cosa si misura, e quale risultato conterebbe
come FALLIMENTO.

Dichiarami il SOFFITTO: LINCS mappa solo piccole molecole, e delle 194 entita'
107 sono small_molecule mentre 42 sono malattie, 15 citochine, 9 patogeni, 11
ambientali, 9 genetiche e 1 differenziamento. Dei 37 del nocciolo ne copre 21. Dimmi
che cosa valida l'altra meta', o dichiara che resta non validata.

E misura la CIRCOLARITA': lo strumento c'e' gia',
analysis/audit/2026-08-08-validazione-esterna/30-geni-e-circolarita.R conta gli
studi GEO in comune fra il nostro corpus e LINCS. Una fonte "esterna" che
condivide studi col corpus non e' esterna.

Tre cose che mi servono per decidere: (a) quanto verrebbe per PURO CASO, e due o
tre soglie candidate tradotte in parole; (b) se non passa, quale prova distingue
le TRE spiegazioni - "e' il metodo", "e' la fonte", e "E' L'IDENTITA'" (l'aggancio
passa dagli stessi ID che S9 dice fragili, IL-1β -> IL1A: un gruppo mal
etichettato fallisce per forza) - deciso ADESSO; (c) che cosa resta dell'articolo
se S7 fallisce e la colpa e' del metodo.

Dammi anche la stima di durata dell'esecuzione. Non guardare nessun risultato.
```

------------------------------------------------------------------------

---

# S7 — Validazione esterna: l'esecuzione

> **Chiusa il 2026-11-04.** Il test passa: 14 su 19 (soglia effettiva 23,9%) e 39 su 53 (26,4%).
> Contro Tahoe: 11 su 32. Finding: `docs/findings/2026-11-04-S7-validazione-esecuzione.md`. Evidenza: `analysis/audit/2026-11-04-S7-validazione-esecuzione/`.
> Il numero dell'articolo viene dalla seconda esecuzione, dopo le correzioni (S13). **Il PI ha scelto:** l'articolo riporta insieme il numero di LINCS e quello di Tahoe-100M, che non ha un verdetto.
>
> **Ricevuto dal disegno (S6), da leggere per primo.** Il disegno è `docs/superpowers/specs/2026-11-04-validazione-esterna-design.md`.
> È congelato con le scelte del PI: la soglia è T = 17%, cioè almeno 8 composti su 19 e 16 su 53. Il passo A usa solo le fonti e si committa prima del passo B. Il PI ha approvato il
> calcolo, stimato in circa 6 ore. Copia le previsioni di §8 nel tuo `00-previsioni.md` senza cambiarle.

### Perché

Si esegue il disegno di S6 e si guarda l'esito, qualunque sia.

### Che cosa si fa

Esattamente quello che dice il disegno, senza cambiarlo in corsa. Se ci si accorge che il disegno era sbagliato: **si ferma, si scrive perché, si rifà S6.**

### Che cosa NON si fa

Non si cambia la soglia depositata. Mai. Non si inventa a posteriori la spiegazione di un fallimento: quella è già scritta in S6.

### Come si sa che è finita

C'è un numero, la soglia depositata, e un verdetto: passa o non passa.

### La decisione che spetta a te

Che cosa farne. Se passa: come si scrive. Se non passa: si esegue la prova discriminante già decisa in S6.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S7. Leggi il disegno di S6 ed eseguilo esattamente com'e' scritto.

Prima di eseguire verifica che il disegno di S6 sia scritto sulle 194 e non
ereditato dalle 214 di v15.

Non cambiare la soglia depositata, per nessun motivo. Se il disegno era
sbagliato, FERMATI e dimmelo: non aggiustare mentre guardi i dati.

Alla fine: il numero, la soglia, il verdetto. Se non passa, esegui la prova
discriminante gia' decisa in S6.
```

------------------------------------------------------------------------

---

# S7b — Validazione con meta-analisi pubblicate

> **Aperta dal PI il 2026-11-07, durante la S11:** «cercare in letteratura se qualcuno ha mai fatto una o più
> meta-analisi con gli stessi campioni che usiamo noi e vedere se noi riusciamo a beccarle con il nostro metodo».

### Perché

LINCS e Tahoe-100M (S6, S7) controllano le firme dei composti. Una meta-analisi pubblicata sugli stessi studi GEO
controlla tutta la catena: quali studi entrano, come si appaiano i bracci, che cosa esce dal pooling.

### Che cosa si fa

1. Si cercano meta-analisi pubblicate (PubMed, Europe PMC) che citano almeno tre studi `GSE` presenti nel corpus, e
   si conta quante usano RNA-seq e non microarray.
2. Per ognuna si confronta: gli studi che noi mettiamo nella stessa meta-analisi; i bracci che usiamo; i geni
   significativi pubblicati contro i nostri.
3. Il disegno (che cosa conta come «ritrovata», le soglie, le previsioni) si deposita prima di guardare i risultati,
   come in S6.

### Che cosa NON si fa

Non si tratta una meta-analisi pubblicata come verità: l'accordo misura la concordanza, non la correttezza. Non si usa
questa misura per cambiare una regola della pipeline su una singola meta-analisi.

### Come si sa che è finita

Il numero di meta-analisi pubblicate trovate, quante sono confrontabili, e per ognuna l'accordo su studi, bracci e geni.

### La decisione che spetta a te

Il disegno, in apertura: quali fonti, che cosa vuol dire «ritrovata», e la soglia.

### Prompt

```
sessione simulomicsr S7b, leggi prima la skill di progetto.

Cerca meta-analisi pubblicate che usano gli stessi studi GEO del deliverable dopo il
re-run, e misura se il nostro metodo le ritrova (studi, bracci, geni). Deposita il
disegno prima di guardare i risultati. Una meta-analisi pubblicata non e' la verita'.
```

------------------------------------------------------------------------

---

# S8 — La decisione sul re-run completo

> **Ricevuto dall'esecuzione della validazione esterna (S7), da leggere per primo.** Il test esterno passa sul deliverable di oggi. Se il PI sceglie il re-run completo, il numero
> dell'articolo deve venire dal deliverable finale, quindi la seconda esecuzione del test va dopo S14 e non dopo S13. **Che cosa serve per chiuderlo:** scrivere nella decisione di S8 quando si riesegue il test.

> **Esito della sessione (2026-11-04), da leggere per primo.** Il PI ha scelto una prova prima del sì o no: 2.000 studi a caso fra i 21.828 e 300 già rigenerati
> (`analysis/audit/2026-11-04-S8b-prova/`). Regola: sotto 50 studi stimati no, sopra 250 sì, in mezzo decide il PI. **Correzioni al testo qui sotto** (finding `2026-11-04-S8-re-run-decisione`):
> i 21.828 **non** sono tutti in gruppi da uno studio solo (4.994 hanno un gruppo, 11.175 hanno confronti fermati dalle regole, 5.659 non hanno confronti); i 141 studi entrati stanno tutti dentro i 2.566;
> il netto di -130 dipende dal disegno del run parziale; il costo è da 38 a 70 ore, centrale 63. **Da verificare se la risposta è sì:** le tabelle di correzione dei nomi si agganciano ai `record_id` del run vecchio, e S14 non ne prevede la rigenerazione.

> **Esito della prova (S8b, 2026-11-05), da leggere per primo.** Il PI ha scelto il re-run completo: «Si rifa tutto, siamo scienziati». Su 6.000 studi a caso ne entrano 19, circa 69 [42; 108] sul corpus.
> I 300 studi già rigenerati sono identici ad agosto. Finding `2026-11-05-S8b-prova-re-run`, sezione «Decisioni del PI». Il paragrafo dei Methods per il «no» non si usa.

### Perché

Il mandato del 13 agosto diceva «re-run completo di **tutti** gli stadi». Quello che è stato fatto (A3) copre **2.566 studi su 24.394 — il 10,5% degli studi**.

> ⚠️ Un numero circola sbagliato: il **17,1%** che si trova in `A3-definizione.json` è la frazione dei **record di Stadio 1** (86.898 campioni su 508.037), non degli studi. Sono due denominatori diversi e non vanno fusi.

Per la domanda a cui A3 doveva rispondere è completo: tutti gli studi del deliverable sono dentro. Per «come sarebbe il deliverable dopo un re-run vero» no: restano **21.828 studi mai ri-processati**, oggi tutti in gruppi da uno studio solo. Uno di quelli, rigenerato, potrebbe far nascere una meta-analisi che oggi non esiste.

### Il conto completo, che va guardato tutto

| a favore | contro |
|------------------------------------|------------------------------------|
| **141 studi sono entrati** venendo da fuori: il meccanismo funziona | …ma nello stesso confronto **271 sono usciti**: il netto è **−130 studi**, non +141 |
| Chiude una domanda aperta | Il re-run parziale ha fatto **perdere 17 meta-analisi su 211** |
| Chiude il mandato del 13 agosto | Costa **40-60 ore** su più giorni, a cancelli (non 10: gli stadi LLM sono il grosso) |
| Un run solo porta dentro anche le correzioni di S12 | **Manda in parte in scadenza la rilettura a mano delle 194** e obbliga a S15 |

### Che cosa si fa

Si mettono i due conti sul tavolo, si stima il costo di S15, si decide. Nessun calcolo pesante.

### Come si sa che è finita

La decisione è scritta, con la data e il motivo.

### La decisione che spetta a te

**Rifare il run completo, sì o no.** Il «no» è legittimo: si scrive nei Methods che il re-run ha coperto il 10,5% degli studi e che studi oggi isolati potrebbero, dopo un re-run completo, formare gruppi nuovi.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S8, solo quella. Serve una decisione, niente calcoli pesanti.

Il re-run completo non e' mai stato fatto: A3 copre 2.566 studi su 24.394, cioe'
il 10,5% DEGLI STUDI (il 17,1% di A3-definizione.json e' la frazione dei RECORD
di Stadio 1, un altro denominatore).

Mettimi sul tavolo il conto COMPLETO, non solo l'argomento a favore: da una parte
i 141 studi entrati da fuori - ma nello stesso confronto ne sono USCITI 271, netto
-130, e questo va detto; dall'altra le 17 meta-analisi perse su 211 dal re-run
parziale, le 40-60 ore di macchina, e il fatto che rifarlo manda in scadenza la
rilettura a mano delle 194, le figure di S16 e i Methods di S17.

Stimami quanto costerebbe riverificare quello che cambia (S15).

Poi ti dico si' o no. Se e' no, scrivimi il paragrafo dei Methods che dichiara la
limitazione.
```

------------------------------------------------------------------------

---

# S9 — Le lettere greche, e il crash delle corsie

> **Chiusa il 2026-11-07** (`docs/findings/2026-11-07-S9-greche-e-corsie.md`). La chiave d'entità ricalcolata su tutti gli
> 86.745 confronti dello Stadio 3, senza e con traduzione delle greche: cambiano 364 confronti e 7 meta-analisi su 194, fra le
> 40 solo TNF (42 → 27 studi, per un difetto della forma ASCII `TNF-alpha`, che già oggi lascia fuori 12 studi). Cinque cambi
> tolgono confronti già segnati difettosi. Crash di `.lane_index()` corretto (`6996f73`); 45 su 90 confermato.
> **Decisioni del PI:** la correzione si scrive in **S12b** (traduzione, citochine in lettere latine, negazione); il problema
> nuovo «una entità con più nomi» va in **S12c**, che lo risolve con un comportamento generale (il nome scritto dal modello).
> Entrambe prima di S13, S12c dopo S12b. Il calcitriolo va in S12c (finding §12).

> **Ricevuto dal disegno della validazione esterna (S6), da leggere per primo.** Nessuna correzione può scegliere che cosa correggere guardando
> l'esito della validazione esterna per una meta-analisi. Vale anche per il rilevatore e per il calcolo delle correzioni. Fra i composti misurabili in
> LINCS, uno solo ha una lettera greca nel nome: `17β-estradiol`, nell'insieme principale. Controllalo qui.

### Perché

Nove punti della pipeline traducono un testo (`"TGF-β1"`) in un identificativo (`HGNC:11766`), e **uno solo se la cava su tutte e dieci** le coppie di prova. Le due funzioni che *traducono* le greche (`.normalize_greek_stereo`, `.ca_latinize_greek`) **non sono fra i nove**: stanno altrove nella catena, ed è per questo che i nove restano scoperti.

| esito, su 90 prove         |        |
|----------------------------|-------:|
| stessa risposta            |     26 |
| **identità diversa**       | **45** |
| la greca non risolve nulla |     11 |
| entrambe vuote             |      8 |

Il caso peggiore non è il silenzio: `IL-1β` restituisce **IL1A**, un gene diverso da IL1B. E non sbaglia sempre la greca: in **2 casi su 45** sbaglia la forma latina (`TNF-alpha` finisce su un identificativo ChEMBL mentre `TNF-α` dà correttamente `HGNC:11892`). Tre citochine distinte — `IFN-γ`, `IFN-α`, `IFN-β` — collassano tutte nella stessa stringa `STR:ifn`.

**Ma il deliverable regge**, perché il fix del 26 luglio è applicato proprio nel punto che decide l'entità del gruppo: nessuna delle 194 entità è una delle **sette** forme collassate provate finora. Sette, non tutte quelle possibili.

### Che cosa si fa

1.  **Si estende il controllo del collasso oltre le sette forme provate**: si cercano tutte le entità del deliverable che una traduzione delle greche potrebbe cambiare, con un **criterio dichiarato di esaustività**.

2.  Si contano le etichette vere con lettere greche e si vede in quali gruppi stanno.

3.  Si simula il fix **senza applicarlo** e si conta: quante entità cambierebbero, quanti gruppi si fonderebbero, quanti si spezzerebbero. ⚠️ **Le fusioni non si vedono guardando le 194 righe**: un gruppo si fonde tirandosi dentro gruppi che oggi stanno *sotto* k=3, cioè fuori dal deliverable. Va ri-derivata la chiave d'entità su **tutto lo Stadio 3**.

4.  Si corregge **una cosa sola**, che è una riga. **La riproduzione è questa, in quattro righe** — non si passa da `00-materiale.R`, che il crash lo *aggira* (usa un match esatto apposta perché `GSM6849338` non entri) e costa un'ora di caricamenti:

    ``` r
    simulomicsr:::.lane_index(c("a_L001", "a_L002", NA))
    #> Error: NAs are not allowed in subscripted assignments
    ```

    Il difetto è in `.lane_index()`, `R/stage4-technical-lanes.R:79-84`: `regexpr` su `NA` dà `NA`, quindi `k <- m > 0L & is.na(out)` contiene `NA` e `out[k] <- ...` esplode. `build_lane_library_lookup()` ci arriva **solo se almeno un altro gruppo è candidato corsia** — per questo un test scritto con la sola riga NA passerebbe senza esercitare nulla.

    ⚠️ **Il grilletto è il titolo NA, non l'assenza dall'H5** (l'assenza produce l'NA attraverso `match()`): un test scritto letteralmente su «campione assente dall'H5» si tirerebbe dietro tutto l'H5 per niente.

### Che cosa NON si fa

Non si tocca nessuno dei nove resolver. Nessun re-cluster.

### Come si sa che è finita

Tre cose: **(a)** il criterio di esaustività del punto 1 è scritto e applicato; **(b)** c'è la tabella «N entità cambierebbero, M gruppi si fonderebbero, P si spezzerebbero», derivata da **tutto lo Stadio 3**, non dalle 194; **(c)** `98-greche-tutti-i-resolver.R` dà ancora 45 su 90 (nulla corretto per sbaglio) e il crash delle corsie non c'è più.

### La decisione che spetta a te

**Se vale la pena correggerli**, e il costo dipende da S8:

⚠️ **Attenzione, il costo è quasi sempre zero.** S13 — re-cluster + re-pool in locale — **gira comunque**, perché dipende da S12 e non da S8: serve ad applicare le correzioni del rilevatore. Quindi il fix delle greche entra in una macchina che sta già girando, in **entrambi** i rami:

- se il re-run completo si fa (S14), si paga con quello;
- se non si fa, si paga con S13, che si fa lo stesso.

Il costo marginale del **calcolo** è **\~0**, non 6 ore, purché S12 non venga abbandonata (la via d'uscita di S10 può chiuderla, e con lei S13).

⚠️ **Ma il costo del calcolo non è tutto il costo, e l'handout finora lo taceva: nessuna sessione implementa il fix delle greche.** S9 lo *simula* e vieta di toccare i resolver; S12 è il rilevatore; S13 applica «le correzioni del rilevatore». Se la risposta è «sì, vale la pena», **questa sessione deve anche dire chi lo scrive e quanto costa** — nove funzioni in TDD non sono gratis — e quel lavoro va aggiunto alla mappa prima di S13.

La domanda resta: **quante meta-analisi cambierebbero?** — ma la risposta va pesata contro il costo di scrivere il fix, non solo di girarlo.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S9, solo quella.

Dei 9 punti che risolvono un nome in un ID, UNO SOLO se la cava su tutte e dieci
le coppie di prova: 45 su 90 danno identita' diverse, e IL-1β restituisce IL1A
invece di IL1B. Nessuna delle 194 entita' e' una delle SETTE forme collassate che
ho provato - sette, non tutte quelle possibili.

1. Estendi il controllo del collasso oltre le sette forme, con un criterio di
   esaustivita' dichiarato.
2. Conta le etichette vere che contengono lettere greche e dimmi in quali gruppi
   stanno.
3. Simula il fix SENZA applicarlo: quante entita' cambiano, quanti gruppi si
   fondono, quanti si spezzano. ATTENZIONE: le fusioni NON si vedono sulle 194
   righe, perche' un gruppo si fonde tirandosi dentro roba che oggi sta sotto
   k=3. Ri-deriva la chiave d'entita' su TUTTO lo Stadio 3.
4. Correggi UNA cosa sola, che e' una riga. LA RIPRODUZIONE E' QUESTA:
     simulomicsr:::.lane_index(c("a_L001","a_L002", NA))
     -> Error: NAs are not allowed in subscripted assignments
   Il difetto e' in .lane_index(), R/stage4-technical-lanes.R:79-84. NON passare
   da 00-materiale.R: quello il crash lo AGGIRA, e costa un'ora di caricamenti.
   Il grilletto e' il TITOLO NA, non l'assenza dall'H5. E build_lane_library_lookup()
   ci arriva solo se c'e' almeno un altro gruppo candidato corsia: il test deve
   esercitare quel caso, non la sola riga NA.

Non toccare i resolver, non lanciare re-cluster. E alla fine RILANCIA
98-greche-tutti-i-resolver.R: deve dare ancora 45 su 90. Se da' un numero diverso
hai corretto qualcosa per sbaglio, ed e' proprio quello che non devi fare qui.
Alla fine dimmi se vale la pena, e pesa DUE costi, non uno:
- il CALCOLO costa ~0, perche' S13 (re-cluster + re-pool locale) gira comunque -
  dipende da S12, non da S8. Costa davvero solo se abbandoniamo anche S12;
- ma SCRIVERE il fix non e' gratis, e nessuna sessione lo implementa: S9 lo simula
  e basta, S12 e' il rilevatore, S13 applica le correzioni del rilevatore. Se la
  risposta e' "si' vale la pena", dimmi anche CHI lo scrive e quanto costa - nove
  funzioni in TDD - e aggiungiamo quel lavoro alla mappa prima di S13.
```

------------------------------------------------------------------------

---

# S10 — Il rilevatore di difetti: costruirlo e misurarlo

> **Chiusa il 2026-11-07.** **Decisioni del PI** («sì alle tue proposte»): (1) il rilevatore si rifà sui metadati dei campioni
> in **S10b**, con lo stesso riferimento e N = 85, e S11 aspetta S10b; (2) l'aggancio delle tabelle dei nomi si corregge in
> **S12d**, prima di S13.
>
> **Misurata il 2026-11-07** (`docs/findings/2026-11-07-S10-rilevatore.md`,
> evidenza `analysis/audit/2026-11-07-S10-rilevatore/`). Il PI ha fissato prima della misura N = 85 e la lettura a blocchi
> di 150. Il riferimento è di **129 confronti difettosi**, non 97 (97 righe su 97 agganciate, 23 confronti a mano). La regola
> corretta (V3: greche, soglia a un agente tolta l'entità, regola sul materiale) prende **10 su 129** (7,8%, tre per caso) con
> **51 falsi allarmi su 1.704**: recuperabile per la soglia, ma vede meno di un difetto su dieci, perché i difetti sono
> asimmetrici (l'informazione sta su un braccio solo). 32 dei 51 falsi allarmi vengono da TNF e calcitriolo (S12b, S12c).
> Il dubbio sulle tabelle dei nomi qui sotto è misurato (§7 del finding) e chiuso dalla decisione (2) del PI: S12d.

> **Ricevuto dalla prova del re-run (S8b), da leggere per primo. Rinvio.** Le tabelle che correggono i nomi si agganciano al `record_id` del run vecchio. Se lo Stadio 2 rigenerato cambia il
> significato di un gruppo, la correzione può cadere su altri campioni. Il dubbio tocca già il deliverable di agosto, non solo il re-run. **Che cosa serve per chiuderlo:** contare, su tutte le righe
> delle tabelle dei nomi, quante puntano a un gruppo con un contenuto diverso nel run nuovo. Il dubbio riguarda S10, S11 e S12, e la misura può ripetersi quando esiste il master del re-run.

### Perché

Esiste già in produzione una funzione che dovrebbe accorgersi dei confronti mal appaiati: `.rp_row_defect()`, con 29 blocchi di test e 101 asserzioni, chiamata da `R/stage3-contrast-anchor.R` in **due** punti (righe 684 e 787). Sui 1.903 confronti veri del deliverable ne segnala **due**.

Tace su tutti i casi da manuale: `Hypoxia + TGF-β1` contro `PBS (Vehicle Control)`, `Circulating macrophage + IFN-γ and LPS` contro `untreated`.

Tre cause misurate: **(1)** le lettere greche — il secondo agente non viene riconosciuto; **(2)** la soglia chiede «due agenti in più nel trattato» perché uno è l'entità del gruppo, ma se il secondo non è riconosciuto il conto si ferma a uno e la regola tace; **(3)** la seconda famiglia più frequente — **materiale diverso fra i bracci**, il 22,4% — non ha **nessuna** regola.

### Che cosa si fa

Si costruisce una versione corretta **in un ambiente separato, non in produzione**, e si misura su tutti e 1.903 i confronti.

> ⚠️ **Il denominatore giusto è 97, non 199.** `difetti.csv` ha 97 righe e ognuna porta l'etichetta del confronto colpevole: la verità di riferimento è **già al livello del confronto**. Misurare contro i 199 confronti *degli studi accusati* pretenderebbe che la regola segnali anche i confronti **puliti** di quegli studi: una regola perfetta — che prende tutti e 97 i difettosi e nessun altro — uscirebbe con una sensibilità del **49%** e verrebbe scartata a torto. I 199 si riportano come misura secondaria.

> ⚠️ **Ma quel denominatore non esiste come dato: va costruito, ed è il lavoro vero di questa sessione.** `difetti.csv` è indicizzato per **(cluster, studio)**, non per confronto: 97 righe, 94 coppie distinte, e **solo 40 delle 94 portano un confronto solo** — per le altre 54 il difetto va attribuito a mano fra i 159 confronti che quelle coppie portano (fino a 8 per una).
>
> L'aggancio è possibile — tutte e 97 le righe citano entrambe le etichette — ma in **cinque formati diversi**: `'…'`, `«…»`, `"…"`, backtick, e righe che nominano **più confronti insieme**. Un parser a formato singolo ne aggancia **69 su 97**, ne lascia 3 ambigui, 24 non parsati, e **ne perde uno su una lettera greca**: `GSE97744 · Circulating macrophage + IFN-gamma and LPS`, dove l'arbitro aveva traslitterato `IFN-γ`. È la trappola di casa che ricompare dentro la sessione fatta per evitarne un'altra.
>
> **Quindi: parser multi-formato, normalizzazione delle greche, e le righe multi-confronto risolte a mano. Il conto (agganciati / ambigui / a mano) si pubblica PRIMA di calcolare qualunque sensibilità.**
>
> Il punto di partenza è `95-regole-esistenti.R`, che però oggi usa il denominatore 199 — quello vietato qui.

Si produce l'**elenco dei falsi allarmi**, che verranno letti in S11.

### Che cosa NON si fa

Non si modifica `R/stage3-row-pairing.R`. **Non si leggono i falsi allarmi**: quello è S11, perché sono di numero ignoto a priori e il tetto è 1.704.

### Come si sa che è finita

C'è la tabella a due entrate sui **97** confronti, i 199 come misura secondaria, e un file con l'elenco dei falsi allarmi e il loro **numero**.

### La via d'uscita, se la regola non è recuperabile

**Va depositata adesso, prima di misurare.** Se la regola corretta produce più di **N falsi allarmi su 1.704** — il valore di N lo fissi tu qui, prima di vedere il risultato — S10 si chiude con «non è recuperabile», S11 e S12 **non si aprono**, e il difetto va nei Methods come limite dichiarato. Senza questa soglia depositata, una regola che ne fa 800 verrà comunque «aggiustata» finché non sembra buona.

### La decisione che spetta a te

Due: **il valore di N** qui sopra, e **se l'elenco è leggibile in una sessione sola** o va spezzato (regola proposta: oltre 150, si spezza).

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S10, solo quella.

.rp_row_defect() e' in produzione e sui 1.903 confronti veri ne segnala DUE.

Costruisci una versione corretta IN UN AMBIENTE SEPARATO (non toccare
R/stage3-row-pairing.R) che sistemi le tre cause: lettere greche; la soglia
">=2 agenti in piu'" da cambiare in ">=1 dopo aver tolto l'entita' del gruppo";
la famiglia "materiale diverso fra i bracci" che non ha regola.

Misurala su tutti e 1.903 i confronti. IL DENOMINATORE E' 97 - NON 199: misurare
sui 199 confronti degli studi accusati pretenderebbe che la regola segnali anche i
confronti PULITI di quegli studi, e bocciarebbe una regola perfetta (uscirebbe al
49%). Riporta i 199 come misura secondaria.

MA QUEL DENOMINATORE VA COSTRUITO, ed e' il lavoro vero: difetti.csv e' indicizzato
per (cluster, studio), non per confronto - 97 righe, 94 coppie, e solo 40 delle 94
portano UN confronto solo; per le altre 54 il difetto va attribuito a mano fra i
159 confronti che portano. Le etichette ci sono tutte ma in CINQUE formati
('...', «...», "...", backtick, e righe con piu' confronti insieme): un parser a
formato singolo ne aggancia 69 su 97 e ne perde uno sulla lettera greca
(GSE97744, IFN-γ traslitterato in IFN-gamma).

Scrivi il parser multi-formato, normalizza le greche, risolvi a mano le righe
multi-confronto, e PUBBLICA IL CONTO (agganciati / ambigui / a mano) prima di
calcolare qualunque sensibilita'. Parti da 95-regole-esistenti.R, che pero' oggi
usa il denominatore 199.

PRIMA DI MISURARE, chiedimi due numeri e scrivili: (a) N, il numero di falsi
allarmi su 1.704 oltre il quale dichiariamo la regola NON RECUPERABILE e chiudiamo
qui - senza aprire S11 ne' S12, e il difetto va nei Methods; (b) se l'elenco lo
leggiamo in una sessione sola. Depositali PRIMA di vedere il risultato: senza
quella soglia, una regola che ne fa 800 verra' comunque aggiustata finche' non
sembra buona.

NON leggere i falsi allarmi: producine l'elenco e dimmi quanti sono.
```

------------------------------------------------------------------------

---

# S10b — Il rilevatore sui metadati dei campioni

> **Chiusa il 2026-11-07.** **Decisione del PI** («ok va bene la combinazione scelta»): va alla lettura (S11) la combinazione
> proposta dal criterio, con l'elenco `analysis/audit/2026-11-07-S10b-metadati-campioni/40-falsi-allarmi.csv` (56 righe).
> La regola sul materiale resta fuori.
>
> **Misurata il 2026-11-07** (`docs/findings/2026-11-07-S10b-rilevatore-metadati.md`, evidenza
> `analysis/audit/2026-11-07-S10b-metadati-campioni/`, deposito `3defd61`). Cinque cancelli superati. La regola sui fatti
> dello Stadio 1 (12 sotto-regole) prende **56 difettosi su 129** con **184 falsi allarmi su 1.704**: sopra N = 85. Il
> criterio depositato propone **R1 + R2a + R2b + R6 + la parte di V3 senza la soglia a un agente**: **43 su 129** (33,3%,
> ottimistica perché la scelta usa il riferimento) con **40 falsi allarmi** e 16 altri negativi, 56 righe da leggere. La
> regola sul materiale (R4a) resta fuori per 2 falsi allarmi (87 con lei). I fatti dei campioni vedono il secondo agente
> (29 su 41) e il tempo (10 su 19); non vedono materiale, soggetto e sede (bracci misti, `context_kind` troppo grossolano,
> linea vuota).

> **Aperta dal PI il 2026-11-07, alla chiusura di S10** («sì alle tue proposte»). Fonte: `docs/findings/2026-11-07-S10-rilevatore.md`
> §5. Evidenza riusabile in `analysis/audit/2026-11-07-S10-rilevatore/`: `20-ingressi-regola.rds` (gli ingressi veri della
> regola di produzione sui 1.903 confronti), `30-riferimento.csv` (i 129 confronti difettosi), `40-esiti.csv` (gli esiti di
> V0-V3), `45-perche-non-visti.csv` (per ogni difetto, che cosa le etichette dicono).

### Perché

La regola sulle etichette corretta in S10 prende 10 confronti difettosi su 129, tre per caso. I difetti sono asimmetrici:
l'informazione che rompe il confronto sta su un braccio solo (il tempo sul solo trattato, il secondo agente con un codice di
ricerca, l'etnia e il sesso in parole), e una regola che confronta le due etichette non ha niente da confrontare. Lo Stadio 1
scrive per ogni campione i campi dove l'asimmetria si legge: `perturbations` (agenti uno per uno, `duration.value_hours`,
`is_zero_timepoint`), `patient_metadata` (`donor_id`, `sex`, `ancestry_or_population`, `age`), `cell_context` (`context_kind`,
`tissue`, `cell_line_cellosaurus_candidate`, `passage_or_state`).

### Che cosa si fa

1. Si scrive una regola deterministica, **fuori dal pacchetto**, che confronta i fatti dello Stadio 1 dei campioni trattati con
   quelli dei campioni di controllo di ogni confronto (`gsm_t`, `gsm_c` di `dispatch-A3.rds`; master
   `analysis/p4-output/A3-stage1-master-innestato.jsonl`). Le famiglie da coprire sono quelle della rilettura: secondo agente,
   tempo, donatore/sesso/etnia, materiale, sede, passaggio. L'entità del gruppo si toglie come in V2 di S10.
2. **La regola si congela e si committa con le previsioni, prima di misurare**: come si aggrega un braccio con più campioni,
   che cosa conta come differenza, quali classi esenta (per esempio il caso-controllo per donatore nelle malattie).
3. Si misura come in S10: sensibilità sui **129**, falsi allarmi sui **1.704**, altri negativi sui 70, bootstrap degli studi
   (B = 2000, seme della data), una variante per sotto-regola, e il confronto con V3 di S10. Si produce l'elenco dei falsi
   allarmi e il loro numero.
4. Si dichiara che cosa la regola non vede: un campo vuoto nello Stadio 1 non è una prova di assenza.

### Che cosa NON si fa

Non si modifica `R/`. Non si leggono i falsi allarmi: è S11. Non si cambia la regola dopo il commit delle previsioni. Non si usa
la validazione esterna per scegliere.

### Come si sa che è finita

La tabella a due entrate sui 129 e sui 1.704, la scala delle sotto-regole, l'elenco dei falsi allarmi e il loro numero.
**Controlli positivi** da depositare prima, fra i casi che le etichette non vedono: `GSE139963` «Hypoxia + TGF-β1», un controllo
a tempo zero di `GSE126409`, l'etnia di `GSE97358`. Se lo Stadio 1 non scrive l'informazione, il caso si dichiara invisibile
prima della misura.

### La decisione che spetta a te

La stessa di S10, già presa: **N = 85** falsi allarmi su 1.704, oltre i quali la regola non è recuperabile; lettura a blocchi di
150. Alla fine: quale regola, o quale combinazione con V3 di S10, va alla lettura in S11.

### Prompt

```
sessione simulomicsr S10b, leggi prima la skill di progetto.

Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S10b, solo quella. Leggi prima docs/findings/2026-11-07-S10-rilevatore.md
§2-§5.

La regola sulle etichette vede 10 difetti su 129 perche' i difetti sono
asimmetrici. Costruisci, fuori dal pacchetto, una regola che confronta i fatti
dello Stadio 1 dei campioni trattati e di controllo (agenti, durata, tempo zero,
donatore, sesso, etnia, materiale, tessuto, linea, passaggio). Congela la regola
e le previsioni PRIMA di misurare. Misura sullo stesso riferimento di S10
(129 difettosi, 1.704 puliti) con la stessa N = 85. Non leggere i falsi allarmi.
```

------------------------------------------------------------------------

---

# S11 — Il rilevatore: leggere i falsi allarmi

> **Chiusa il 2026-11-07.** **Decisione del PI dopo il riassunto** («si»): una differenza solo tecnica fra i bracci
> (strumento, kit, paired-end contro single-end, RNA marcato) è un errore, per tutti i confronti. Applicata: 8 candidati
> in 7 studi, 5 errori nuovi. **Numeri finali:** 37 errori veri, 18 errori della regola, 1 incerto; riferimento 129 → 193;
> il rilevatore ne vede 81; 15 meta-analisi cambiano verdetto (13 da corretta a difettosa), 6 nelle 40.
>
> **Misurata il 2026-11-07** (`docs/findings/2026-11-07-S11-lettura-falsi-allarmi.md`,
> evidenza `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/`, deposito `c50228a`). **Decisioni del PI prese in
> apertura:** (1) un controllo raccolto a tempo zero è sempre un errore, se il tempo zero si legge nell'etichetta o nei
> metadati GEO; (2) un errore leggibile solo nei metadati GEO entra nel riferimento con la fonte marcata; (3) nessuna
> soglia di errore: la tabella delle soglie non si calcola, ogni errore della regola si corregge. **Risultato:** dei 56
> allarmi, 36 errori veri, 19 errori della regola, 1 incerto. Il tempo zero tocca 50 confronti in 17 studi. Il
> riferimento passa da 129 a 188 confronti (`41-riferimento-dopo-S11.csv`, `42-difetti-dopo-S11.csv`); la sensibilità
> della combinazione da 43/129 a 80/188 (ottimistica). 14 meta-analisi cambiano verdetto, 6 nelle 40: la scelta della
> S5 decade. Il rilevatore vede 80 dei 188 errori noti (prima della decisione tecnica). Rinvii scritti in S12 e S15.

> **Ricevuto dal rilevatore sui fatti dei campioni (S10b), da leggere per primo.** Il PI ha scelto la combinazione
> proposta (2026-11-07): l'elenco da leggere è `analysis/audit/2026-11-07-S10b-metadati-campioni/40-falsi-allarmi.csv`,
> 56 righe (40 puliti, 16 altri negativi), una sessione. Sostituisce l'elenco della S10 citato qui sotto e nel prompt.
> Le colonne `det_*` dicono quali valori dello Stadio 1 fanno scattare la regola. La sensibilità della combinazione (43 su 129) è ottimistica: va ricalcolata sul
> riferimento corretto a fine lettura. **Rinvio, anomalia del riferimento:** i controlli a tempo zero sono giudicati in
> modo diverso nello stesso studio. In `GSE126409` gli 11 confronti hanno lo stesso controllo «vehicle control (time
> zero)» e la rilettura ne accusa 5 (3 su 3 per IL-21, 1 su 4 per IL-15, 1 su 4 per IFN-β); in `GSE221804` 10 confronti
> con controllo «unstimulated» a 0 h sono 7 altri negativi e 3 puliti. 13 dei 16 altri negativi dell'elenco hanno un
> controllo a tempo zero. **Che cosa serve per chiuderlo:** decidere una volta se un controllo a tempo zero è un difetto,
> applicarlo a tutti i confronti con un controllo a tempo zero, e registrare ogni riga di `difetti.csv` che cambia.
> Alcuni falsi allarmi di R1 sembrano secondi agenti veri (bortezomib con shPSMD2, 5-fluorouracile con clorochina,
> CB-839 con radiazione): §6 del finding S10b.

> **Ricevuto dalla misura del rilevatore (S10), da leggere per primo.** L'elenco è
> `analysis/audit/2026-11-07-S10-rilevatore/40-falsi-allarmi.csv`: 54 allarmi (51 sui confronti puliti, 3 sugli altri
> negativi), una sessione sola per la regola dei 150. Il denominatore della sensibilità è **129** confronti
> (`30-riferimento.csv`), non 97. 25 allarmi su TNF e 7 sul calcitriolo vengono da difetti della chiave che S12b e S12c
> cambiano. **Il PI ha deciso (2026-11-07): questa sessione aspetta S10b**, e legge gli allarmi della regola che S10b sceglie.

### Perché

Un numero di falsi allarmi non dice niente finché non si guarda **che cosa sono**. Il precedente del progetto: il primo rilevatore segnalava 186 casi di cui 96 veri — poco più della metà.

### Che cosa si fa

Si apre ogni falso allarme e si dice se è **davvero** un falso allarme o se è la rilettura ad aver sbagliato. Uno per uno, citando l'etichetta.

### Che cosa NON si fa

Non si aggiusta la regola mentre si legge. Se emerge come migliorarla, **si scrive e si rimanda a S12**.

### Come si sa che è finita

Ogni falso allarme dell'elenco ha un verdetto scritto accanto. Se l'elenco era più lungo di quanto si legge in una sessione, si chiude qui e se ne apre un'altra: **meglio due sessioni che una lettura frettolosa**.

### La decisione che spetta a te

**Quanti falsi allarmi accetti** — e questa volta con la conseguenza tradotta: per ogni soglia candidata, **quante delle 194 meta-analisi morirebbero** (un membro che cade può portare il gruppo sotto k=3: è successo a 21 gruppi su 66) e **quanti geni significativi si perderebbero**. Senza quella colonna la domanda si risponde a sensazione.

⚠️ Quella colonna **non si conta sulle 194 righe**: va ri-derivato `k_eff` col dispatch replicato di `00-materiale.R` (Layer A sui 316 candidati, `n_min` dopo il collasso delle corsie, dedup, fusioni). Contarla sul deliverable dà il numero sbagliato.

⚠️ **E c'è un problema di metodo che va guardato in faccia, non nascosto.** Questa è l'unica soglia del progetto che si sceglie **dopo** aver visto l'effetto sul prodotto — mentre S6 e S7 impongono l'opposto («non si cambia la soglia depositata, mai»). Il rischio è ovvio: si sceglie la soglia che uccide meno meta-analisi. **Difesa minima:** si scrive *prima* di guardare la tabella quale criterio si userà (per esempio «la precisione più alta che tiene i falsi allarmi sotto il 10%»), e poi si applica quel criterio al risultato, qualunque sia.

⚠️ **Il metro può muoversi mentre lo si usa.** S11 ha per mandato di dire «o ha sbagliato la rilettura»: cioè può cambiare `difetti.csv`, che è lo stesso file contro cui S10 ha misurato la sensibilità. **Ogni riga che si sposta va registrata**, e la sensibilità va ricalcolata alla fine sul metro corretto, dichiarando entrambi i valori. Altrimenti il numero che esce non è stimabile.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S11. Leggi l'elenco dei falsi allarmi prodotto in S10.

Aprili e leggili UNO PER UNO: per ognuno dimmi, citando l'etichetta, se e'
davvero un falso allarme o se ha sbagliato la rilettura.

Non aggiustare la regola mentre leggi: se ti viene un'idea, scrivila e rimandala
a S12. Se l'elenco e' troppo lungo, fermati e apriamo un'altra sessione: meglio
due sessioni che una lettura frettolosa.

DUE DIFESE DA APPLICARE, e sono il punto:

1. PRIMA di mostrarmi la tabella delle soglie, scrivi quale CRITERIO useremo per
   scegliere (es. "la precisione piu' alta che tiene i falsi allarmi sotto il
   10%"). Poi applica quel criterio al risultato, qualunque sia. Altrimenti
   sceglieremo la soglia che uccide meno meta-analisi - e questa e' l'unica soglia
   del progetto scelta DOPO aver visto l'effetto sul prodotto.

2. Hai per mandato di dire "o ha sbagliato la rilettura": cioe' puoi cambiare
   difetti.csv, che e' lo STESSO file contro cui S10 ha misurato la sensibilita'.
   REGISTRA ogni riga che sposti, e alla fine ricalcola la sensibilita' sul metro
   corretto, dichiarando ENTRAMBI i valori. Altrimenti il numero non e'
   stimabile.

Alla fine, per farmi decidere la soglia, dammi una tabella con: per ogni soglia
candidata, quanti difetti veri prende, quanti falsi allarmi fa, QUANTE DELLE 194
MORIREBBERO (un membro che cade puo' portare il gruppo sotto k=3), e quanti geni
significativi si perdono.

La colonna "quante muoiono" si calcola RI-DERIVANDO k_eff col dispatch replicato
di 00-materiale.R (Layer A sui 316 candidati, n_min dopo il collasso delle corsie,
dedup, fusioni): contarla sulle 194 righe da' la risposta sbagliata.
```

------------------------------------------------------------------------

---

# S12 — Il rilevatore: portarlo in produzione

> **Ricevuto dalla lettura dei falsi allarmi (S11, 2026-11-07), da leggere per primo. Rinvio, e cambia il mandato.**
> **Decisione del PI in S11: nessuna soglia di errore** («La pipeline non deve sbagliare. Sono dati fissi»). Quindi
> la regola non va in produzione con un tasso di falsi allarmi «accettabile»: ogni causa si corregge, e ogni errore
> noto non visto si spiega. Lo stato (finding `docs/findings/2026-11-07-S11-lettura-falsi-allarmi.md` §6-§7):
> (1) **18 errori del rilevatore, sette cause**: modifica genetica o condizione comune scritta dallo Stadio 1 solo sul
> trattato (6); agente comune marcato «controllo negativo» solo nel controllo, e non contato (3); stesso tempo scritto
> in due modi (3); campo del passaggio usato per altro (2); nome dell'entità non riconosciuto
> nell'agente (2); mutazione del paziente come knockout (1); perturbazione vuota contata come agente (1).
> (2) **112 dei 193 errori noti non sono visti** (tempo 28, materiale 20, donatore 14, altro 13, secondo agente 12,
> sede 6, entità 6, differenza tecnica 5, altre 8). Le differenze tecniche (decisione del PI) si leggono nei campi GEO
> `instrument_model`, `platform_id`, `extract_protocol_ch1` e nei marcatori 4sU, paired-end, single-end
> (`analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/27-differenze-tecniche.py`). In 12 confronti il tempo zero sta solo nei titoli GEO («D0», «Day0», «_0h», «T0») e lo
> Stadio 1 non lo scrive; in 6 lo Stadio 1 scrive il tempo zero ma R2a e R2b non scattano (`GSE163241`, `GSE186396`,
> `GSE207409`, `GSE223893`): da capire. (3) Il riferimento è ora
> `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv` (193 confronti, colonna `fonte`).
> **Che cosa serve per chiuderlo:** in apertura, un piano che dica come la regola vede i 112 (per molti servono i
> metadati GEO dei campioni, non solo i fatti dello Stadio 1) e come corregge le sette cause, con la stima del lavoro.
> La durata di ~4 h scritta nella mappa non vale più: decide il PI sul piano.

> **Ricevuto dal rilevatore sui fatti dei campioni (S10b), da leggere per primo. Rinvio.** La regola misurata in S10b
> legge i fatti dello Stadio 1 dei campioni: in produzione il passo che appaia i bracci (`R/stage3-row-pairing.R`) oggi
> legge solo le etichette, e deve ricevere i fatti dei campioni. Idee emerse dalla misura, **non applicate** (la regola
> era congelata), da misurare qui come correzioni separate: (1) «plus» come separatore di combinazione («XRT plus
> Metformin»); (2) `context_kind` incoerente fra «coltura primaria» e «tessuto primario» (27 dei 48 falsi allarmi di R4a);
> (3) `cell_line_cellosaurus_candidate` quasi sempre vuoto: due linee diverse sono entrambe `cell_line_in_vitro`;
> (4) condizioni di controllo scritte come agenti («normoxia», 10 falsi allarmi di R1c); (5) sinonimi della sede
> («stomach» e «gastric»). Ogni correzione si misura sullo stesso riferimento, con N = 85.

> **Ricevuto dalla sessione sul gate e i due insiemi (S5), da leggere per primo. Il PI ha scelto di togliere gli
> studi doppi (2026-11-04).** La regola serve anche se S11 dice che questa sessione non vale la pena: in quel caso
> si scrive in S13. Serve una regola sulle conte, con i test: due campioni sono lo stesso dato se la distanza L1
> relativa sta sotto 0,001 (190 coppie sotto, nessuna fra 0,001 e 0,03), due studi di un gruppo sono doppi se
> condividono almeno metà dei campioni dello studio più piccolo, resta lo studio con più campioni. L'impronta
> esatta non basta: lo stesso dato riallineato non dà conte identiche. Il `k_eff` va contato dopo questa regola.
> Da verificare: se `.build_samn_dedupe_lookups()` vede questi casi. Controllo positivo:
> `GSE154613`/`GSE159522`, `GSE108743`/`GSE89725`, `GSE156038`/`GSE156184`/`GSE222279`.
> Elenco: `analysis/audit/2026-11-03-S5-gate-e-insiemi/48-coppie-di-studi-doppie.csv`.

> Solo se S11 dice che ne vale la pena.

### Che cosa si fa

Test **prima** del codice, una correzione alla volta, coi casi presi dalle etichette vere. Poi si ri-misura che il comportamento coincida con S10 **alla cifra**. Suite intera verde.

### Che cosa NON si fa

**Non si lancia niente.** L'applicazione è S13.

⚠️ **E si dichiara per iscritto se il cambio tocca una cache su disco.** Verificato: `.rp_row_defect` è memoizzata solo in environment di processo (`caches$agent`/`caches$token`) e **non** entra nel lookup del recupero-nome, che resta `v7` — quindi nessun bump. Va scritto lo stesso: questa verifica, saltata, è già costata otto ore.

### Come si sa che è finita

I test passano, la suite è verde, la misura di S10 si riproduce esattamente, e la verifica sulla cache è scritta.

### La decisione che spetta a te

Nessuna: qui si esegue. È l'unica sessione senza decisione.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S12. Prima leggi i risultati di S10 e S11.

Porta in produzione le correzioni al rilevatore, in TDD: test prima, codice dopo,
una alla volta, coi casi presi dalle etichette vere.

Poi ri-misura sui 1.903 confronti e verifica che coincida ALLA CIFRA con S10. Se
non coincide, fermati e dimmi perche'.

Verifica e DICHIARA se il cambio tocca una cache su disco: .rp_row_defect e'
memoizzata solo in environment di processo (caches$agent/caches$token) e NON entra
nel lookup del recupero-nome, che resta v7 - quindi nessun bump. Dillo per
iscritto: questa verifica e' gia' costata 8 ore una volta.

NON lanciare niente: l'applicazione e' S13. Suite verde prima di committare.
```

------------------------------------------------------------------------

---

# S12b — La chiave d'entità: greche, citochine in lettere latine, negazione

> **Ricevuto dalla sessione sulle lettere greche (S9), da leggere per primo. Decisione del PI del 2026-11-07.** Rinvii, con
> la fonte in `analysis/audit/2026-11-07-S9-greche-e-corsie/`:
> (1) **TNF-alpha in lettere latine.** Nel ramo dei farmaci ChEBI e ChEMBL vengono prima delle citochine: `tnf-alpha` →
> `CHEMBL:CHEMBL265582`, `tnfalpha` → `CHEBI:197439` (TNF del pesce zebra, in lista nera). Oggi 12 studi restano fuori dalla
> meta-analisi su TNF, che ne ha 42 (`45-out.txt` §C). La sola traduzione delle greche porta TNF da 42 a 27 studi.
> (2) **Interferon gamma per esteso** → `CHEBI:5939+CHEMBL:CHEMBL2108494` o `CHEMBL:CHEMBL2108494`; la tabella delle citochine dà
> `HGNC:5438` (`45-out.txt` §D). Stesso difetto di (1).
> (3) **La regola `entita_costante` non legge la negazione**: 241 confronti eleggibili in 92 studi con «no», «non», «without»,
> «w/o», «minus» o «absence» nel controllo (`45-entita-costante-negata.csv`). Conto massimo: vanno letti.
> (4) **L'anchor non è ricalcolato dalla misura di S9.** 2.142 confronti in un gruppo hanno un carattere greco nell'anchor o nei
> fatti dello Stadio 1, 137 prendono l'entità dall'anchor (`40-out.txt`); 272 nomi di anchor hanno greche rovinate dalla codifica
> (`45-out.txt` §F). **Che cosa serve per chiuderlo:** dire se la correzione tocca il recupero del nome; se lo tocca, misurarlo e
> fare il bump di `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`.
> (5) **Il calcitriolo è di S12c.** Qui la traduzione non deve dividere nessun gruppo, salvo i gruppi che S12c unisce.
> (6) **Nessuna scelta guarda la validazione esterna** (regola di S6): TNF e `17β-estradiol` sono nell'insieme principale.

### Perché

S9 ha tradotto le greche in tutte le stringhe della chiave di tutti gli 86.745 confronti: cambiano 364 confronti e 7 meta-analisi.
Cinque cambi tolgono confronti già segnati difettosi in `difetti.csv`, e IL1A perde uno studio di IL-1β. Ma la sola traduzione
manda «TNF-α» sulla forma ASCII, che è risolta male, e TNF (nelle 40) perde 15 studi. Servono tre parti, misurate una alla volta.

### Che cosa si fa

1. **Riproduci prima di cambiare.** Con gli ingressi di S9 (`20-ingressi.rds`) il codice di oggi deve ridare le chiavi OFF di S9
   (`30-due-regimi.rds`): 27.395 chiavi su 27.395, 32.830 scarti su 32.830.
2. **TDD, una parte alla volta**, ognuna misurata sugli 86.745 confronti contro le chiavi OFF di S9, con la tabella dei confronti e
   delle meta-analisi che cambiano:
   a. la traduzione in **un punto**, all'ingresso di `.ca_member_contrast()`; la specifica è `01-traduzione.R` di S9 (μ e µ → `u`,
      ß → `beta`, il resto della stringa intatto);
   b. i nomi delle citochine in lettere latine risolti come citochine: una **regola** sull'ordine dei dizionari nel ramo dei
      farmaci, non una lista; misura gli effetti su tutti i confronti, non solo su TNF e sull'interferone;
   c. la negazione nella regola `entita_costante`, **dopo** la lettura dei 241 confronti.
3. Il punto (4) del riquadro: il recupero del nome, misurato o dichiarato fuori.

Gli ingressi non cambiano se cambia solo la chiave: una misura costa circa 15 minuti (dizionari + chiavi). Se cambia l'anchor, si
rifà anche `20-ingressi.R` (20 minuti).

### Che cosa NON si fa

Non si lancia il re-cluster: è S13. Non si tocca il calcitriolo né le altre entità con più nomi: è S12c. Non si aggiungono voci a
`.CA_VERIFIED_ALIASES` per far tornare un numero.

### Come si sa che è finita

Le tre parti hanno test e la suite è verde; per ogni parte c'è la tabella di che cosa cambia, letta; TNF non perde studi; la
traduzione non divide nessun gruppo, salvo quelli che S12c unisce; `98-greche-tutti-i-resolver.R` è rilanciato e il suo numero è
dichiarato; è scritto se il cambio tocca una cache su disco.

### La decisione che spetta a te

Dopo la lettura dei 241: quali negazioni contano come «entità assente». Alla fine: se la correzione entra in S13.

### Prompt

```
sessione simulomicsr S12b, leggi prima la skill di progetto.

Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S12b, solo quella. Leggi prima il riquadro dei rinvii e il finding
docs/findings/2026-11-07-S9-greche-e-corsie.md (§6, §7, §9, §12).

Riproduci prima le chiavi OFF di S9 con gli ingressi di S9. Poi, in TDD, una
parte alla volta, ognuna misurata su tutti gli 86.745 confronti: (a) traduzione
delle greche in un punto all'ingresso di .ca_member_contrast(); (b) nomi delle
citochine in lettere latine risolti come citochine, con una regola; (c) la
negazione nella regola entita_costante, dopo aver letto i 241 confronti.

TNF non deve perdere studi. La traduzione non deve dividere gruppi, salvo
quelli che S12c unisce. Non lanciare il re-cluster.
```

------------------------------------------------------------------------

# S12c — Una entità con più nomi: il nome scritto dal modello

> **Decisione del PI del 2026-11-07: S12c risolve il problema con un comportamento generale.** Non è limitata al calcitriolo e
> all'interferone alfa: quelli sono i controlli positivi della regola, non lo scopo. Nessuna lista di entità.

> **Ricevuto dalla sessione sulle lettere greche (S9), da leggere per primo.** Fonti in
> `analysis/audit/2026-11-07-S9-greche-e-corsie/` e nel finding S9 §11.
> (1) **Nota del PI: classi, non coppie.** Un'entità può avere più di due nomi: il calcitriolo ne ha quattro.
> (2) **Il modello scrive il nome giusto** (`47-out.txt`): «calcitriol» in tutti e quattro i gruppi del calcitriolo, anche per
> «1α,25(OH)2D3» e «1,25D3», ma con sei ID ChEBI diversi e nessuno è `CHEBI:17823`; «interferon-alpha» nei due gruppi di
> IFN-alfa; «Radiation» nella maggior parte dei confronti dei due gruppi delle radiazioni («irradiation» in 4).
> (3) **Il codice perde il nome giusto in due punti.** (a) Si fida dell'ID scritto dal modello anche quando l'ID è di un'altra
> molecola: `CHEBI:16579` (anisole) 117 volte, 83 con il nome «calcitriol»; `CHEBI:16635` (Met-tRNA) 996 volte, 327 «transforming
> growth factor beta-1», 241 «interferon gamma»; `CHEBI:17236` 646 volte, 105 «interferon-alpha» (`46-out.txt` §E). ADR-0018
> corregge gli ID inesistenti e i campi scambiati, non un ID valido con il nome di un'altra molecola. (b) La chiave del gruppo
> legge il testo del confronto (ADR-0025): se il testo non si risolve diventa `STR:`, e il nome del modello non entra.
> (4) **Casi noti**: calcitriolo in quattro gruppi con lo stesso verso e controllo (9 + 3 + 1 + 1 studi, 14 distinti; due
> meta-analisi del deliverable); candidate dal nome: irradiation/radiation (7 e 7), asthma/asthmatic (4 e 3), ifna/IFNA1
> (6 e 6), nash/NAFLD (7 e 5, entrambe nelle 40). Le meta-analisi `STR:` sono 44. `GSE221690` e `GSE223405` possono essere
> studi doppi.
> (5) **Domanda del PI:** «l'LLM non dovrebbe avere problemi a classificare irradiation e radiation alla stessa maniera; l'ancora
> dovrebbe essere uguale». La risposta è (2) e (3): il modello li classifica quasi sempre allo stesso modo, il codice no.

### Perché

Se una entità ha più nomi, i suoi studi si dividono fra più meta-analisi: l'articolo la conta più volte e ogni meta-analisi ha meno
studi. Il modello conosce già l'identità giusta, ma il codice la perde. La correzione deve valere per tutte le entità, per
costruzione.

### Che cosa si fa

1. **Un ADR prima del codice**, che estende ADR-0018 e ADR-0025: quando l'ID e il nome scritti dal modello non corrispondono,
   vince il nome; quando il testo del confronto non si risolve, entra il nome del modello. Il PI lo approva prima del codice.
2. **Regola 1, l'ID contro il nome, per ogni ID scritto dal modello** nello Stadio 1, in tutti i database (ChEBI, ChEMBL, HGNC,
   MeSH, NCBITaxon) e in tutti i campi che portano un ID (perturbazioni, malattia). Il codice confronta il nome dell'ID nel
   dizionario con il nome scritto dal modello, con la stessa normalizzazione e gli stessi sinonimi dei resolver. Se non
   corrispondono, risolve il nome e usa quell'ID; se il nome non si risolve, l'ID non si usa. Prima del codice: il tasso di
   disaccordo per database su tutto il master dello Stadio 1, A3 e S14.
3. **Regola 2, il nome del modello nella chiave.** Quando il testo del confronto non si risolve a un ID (oggi `STR:`), la chiave usa
   il nome che il modello ha scritto per la stessa parola nel campione trattato. Vale solo se il modello ha letto la stessa parola
   del confronto (uguaglianza normalizzata, dichiarata nell'ADR): così l'anchor non porta dentro una perturbazione diversa, che è il
   motivo di ADR-0025. Vale per tutte le classi: farmaci, citochine, patogeni, malattie, genetica, ambiente.
4. **Misura su tutto**, con gli script di S9 estesi al nome del modello (`20-ingressi.R`, `30-due-regimi.R`, `40-analisi.R`):
   tutti gli 86.745 confronti, tutti i gruppi dello Stadio 3, la tabella dei gruppi che si uniscono e dei confronti che cambiano.
5. **Le classi che restano.** Dopo le due regole: insiemi di gruppi con lo stesso verso e controllo e con nomi che i dizionari o il
   modello dichiarano sinonimi. Si leggono tutti.

### Che cosa NON si fa

Nessuna lista di entità o di sinonimi scritta a mano: la regola vale per costruzione (`CLAUDE.md` §4). Non si uniscono gruppi per
somiglianza di stringa. Non si lancia il re-cluster: è S13. Se cambia il recupero del nome, bump di
`.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`. Nessuna scelta guarda la validazione esterna.

### Come si sa che è finita

- L'ADR è approvato dal PI; le due regole non contengono nomi di entità e hanno test.
- Il disaccordo fra ID e nome è misurato su tutto lo Stadio 1, A3 e S14, per database.
- La misura copre tutti i confronti e tutti i gruppi; la tabella dei cambi è letta.
- **Controlli positivi** (devono vedersi, altrimenti la regola non funziona): il calcitriolo in un solo gruppo; l'interferone alfa
  in un solo gruppo; le radiazioni unite almeno dove il modello scrive «Radiation».
- **Controllo negativo:** nessun confronto che oggi si risolve a un ID cambia entità per la regola 2.
- Le classi rimaste sono lette, e i casi dubbi sono decisi dal PI.

### La decisione che spetta a te

Prima del codice: l'ADR. Alla fine: le classi dubbie (per esempio NASH e NAFLD, l'interferone alfa come famiglia o come gene),
e se la correzione entra in S13.

### Prompt

```
sessione simulomicsr S12c, leggi prima la skill di progetto.

Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S12c, solo quella, dopo S12b. Leggi prima i due riquadri e il finding
docs/findings/2026-11-07-S9-greche-e-corsie.md §11-§12.

Il PI vuole un comportamento GENERALE, non una correzione per il calcitriolo e
l'interferone alfa: quelli sono controlli positivi. Scrivi prima l'ADR e
aspetta l'approvazione. Poi, in TDD: (1) l'ID scritto dal modello si controlla
con il nome scritto dal modello, in tutti i database; se non corrispondono vince
il nome; (2) quando il testo del confronto non si risolve, la chiave usa il nome
del modello per la stessa parola. Misura su tutti gli 86.745 confronti con gli
script di S9. Nessuna lista di entita'. Non lanciare il re-cluster.
```

------------------------------------------------------------------------

# S12d — Le tabelle dei nomi agganciate ai campioni

> **Aperta dal PI il 2026-11-07, alla chiusura di S10** («sì alle tue proposte»). Fonte: `docs/findings/2026-11-07-S10-rilevatore.md`
> §7; evidenza `analysis/audit/2026-11-07-S10-rilevatore/50-*`, `51-*`, `52-*`.

### Perché

Le due tabelle che correggono i nomi (`name-cleanup-side-table-v1.rds`, `name-cleanup-fallback-side-table.rds`) sono state scritte
sui gruppi dei run v9. La produzione le applica passando dal `record_id` del run v9 ai campioni di quel `record_id` **nel master
corrente** (`R/stage3-name-cleanup-overlay.R:66`; nel re-cluster `analysis/p4-fase-f13-stage3-v16-tre-cambi.R:413` costruisce la
mappa da `stage2_path`). Molti `record_id` portano il numero d'ordine del gruppo (`grp_0004`, `mg29`), e uno Stadio 2 rigenerato
numera i gruppi in un altro modo. Misurato in S10: 4.583 record del deliverable non hanno più nessun campione in comune con il
run vecchio; 283 confronti su 1.903 hanno un nome diverso sul primo campione trattato; nel master S14 il 69,9% dei record
agganciati cambia o manca.

### Che cosa si fa

1. In TDD: l'overlay si costruisce con la mappa record → campioni del **master su cui le tabelle sono state scritte**
   (`analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl`, che contiene il 99,3% dei `record_id` dei run v9), non del master
   corrente. Il percorso e lo SHA-256 di quel master entrano in `run_metadata`. Una quota di `record_id` trovati sotto una soglia
   dichiarata ferma il run con un errore diagnostico.
2. Si verifica e si dichiara per iscritto se il cambio tocca una cache su disco: nel re-cluster l'overlay si applica in memoria
   dopo il lookup del recupero (`build_name_recovery_lookup(cache_dir=)`), ma va controllato sul codice. Se il lookup cambia,
   bump di `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`.
3. Si misura l'effetto con gli script di S9 (`20-ingressi.R` con l'aggancio corretto, `30-due-regimi.R`, `40-analisi.R`): confronti
   che cambiano entità, gruppi che si uniscono o si dividono, meta-analisi delle 194 e delle 40 che cambiano.

### Che cosa NON si fa

Non si rigenerano le tabelle con il modello. Non si lancia il re-cluster: è S13. Nessuna scelta guarda la validazione esterna.

### Come si sa che è finita

I test passano, la suite è verde, la tabella dei cambi su tutto lo Stadio 3 è scritta. **Controllo positivo:** in `GSE186341`
«HCC1143 cells treated with Lapatinib» il primo campione trattato riceve `CHEBI:49603`, non `CHEBI:49375`. **Controllo negativo:**
negli studi non rigenerati nessun nome cambia (S10: 84.584 record uguali, nessuno diverso).

### La decisione che spetta a te

Se l'effetto tocca le 40 meta-analisi dell'insieme principale, come dichiararlo. La correzione entra in S13 e nel raggruppamento
di S14 comunque.

### Prompt

```
sessione simulomicsr S12d, leggi prima la skill di progetto.

Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S12d, solo quella. Leggi prima docs/findings/2026-11-07-S10-rilevatore.md §7.

Le tabelle dei nomi si agganciano al record_id del run v9 e prendono i campioni dal
master CORRENTE: negli studi rigenerati il nome cade su altri campioni. In TDD,
aggancia l'overlay ai campioni del master su cui le tabelle sono state scritte
(p4-fase-f4-stage2-master-v3.jsonl). Verifica e dichiara la cache su disco. Poi
misura l'effetto su tutto lo Stadio 3 con gli script di S9. Non rigenerare le
tabelle con il modello, non lanciare il re-cluster.
```

------------------------------------------------------------------------

# S13 — Applicare le correzioni (re-cluster + re-pool locali)

> **Ricevuto dalla sessione sulle lettere greche (S9), da leggere per primo.** S12b e S12c cambiano la chiave d'entità e
> vanno fatte prima. Prima del re-cluster, misura la chiave con gli script di S9 (`20-ingressi.R`, `30-due-regimi.R`,
> `40-analisi.R`, circa 35 minuti): le chiavi devono essere quelle che S12b e S12c hanno misurato.

> **Ricevuto dalla prova del re-run (S8b), da leggere per primo.** (1) Il PI ha scelto il re-run completo, quindi il test esterno, il confronto con studi non collegati e il numero dell'articolo vengono
> dopo S14, sul deliverable finale. Qui il calcolo serve a separare l'effetto delle correzioni dall'effetto del re-run. Se il re-run del modello è già fatto, scrivi quale master usi e perché.
> (2) **Rinvio, da chiudere prima di ogni invio al DGX, quindi anche prima di S14:** `dgx_p4_status()` tratta una risposta vuota come `TERMINATED` (`R/dgx-submit.R`), e `.dgx_ssh()` restituisce una risposta vuota se la
> connessione è rifiutata. Ha già dato un falso arresto il 2026-11-04. Il rimedio è in `analysis/audit/2026-11-04-S8b-prova/50-notte.R` (`stati_sacct`). Togli anche le frasi che suggeriscono gli altri nodi in `R/dgx-config.R` e
> `analysis/p5-name-cleanup-run.R`. **Che cosa serve per chiuderlo:** il codice corretto con un test.

> **Ricevuto dall'esecuzione della validazione esterna (S7), da leggere per primo.** (1) Dopo il calcolo riesegui il passo B con `POOL_DIR` sul nuovo deliverable:
> `analysis/audit/2026-11-04-S7-validazione-esecuzione/README.md` dice come. Il passo A non si rifà. Rigenera prima l'elenco degli 80 composti con le regole del disegno §4.
> `69-cancello-5.R` legge le stime per studio di S4: puntalo alle stime nuove. (2) **Rinvio:** misura come descrizione la prova «Combinazione» del disegno §9 su tutti i composti, perché
> un successo può descrivere bene uno studio dominante e oggi non sappiamo se la combinazione aggiunge qualcosa. **Che cosa serve per chiuderlo:** `d_e` con il suo intervallo. Non cambia il verdetto.
> (3) **Regola di separazione (disegno §2):** i valori bassi di `metformin`, `nicotinamide`, `17β-estradiol`, `IFNB1`, e i due studi del carcinoma epatocellulare con correlazione vicina a 0 con TCGA
> (`GSE256235`, `GSE120663`, `69-out.txt`), non possono scegliere una correzione. Una meta-analisi corretta per questo motivo si marca `a_posteriori` ed esce dal calcolo primario. Se un'altra regola tocca quei due studi, scrivi quale.

> **Ricevuto dal disegno della validazione esterna (S6), da leggere per primo.** Dopo il calcolo: (1) rigenera con le stesse regole l'insieme misurabile in LINCS;
> (2) riesegui il test esterno con lo stesso codice e la stessa soglia: il numero dell'articolo è questo, per scelta del PI; (3) esegui il confronto con studi non collegati su tutti i
> gruppi, con 99 estrazioni scelte dal PI, al massimo 35 ore (disegno §11). **Che cosa serve per chiuderlo:** il risultato per gruppo. Lo script di partenza è
> `analysis/audit/2026-11-03-S5-gate-e-insiemi/74-nullo-appaiato.R`, che misurava una sola estrazione e 137 gruppi.

> **Ricevuto dalla sessione sul gate e i due insiemi (S5), da leggere per primo.** Il PI ha scelto di togliere gli
> studi doppi (2026-11-04): si applicano qui, con la regola sulle conte descritta in S12. Se S12 non è stata
> eseguita, la regola e i suoi test si scrivono qui. `sirna pool against igf2bp1` non è più una meta-analisi,
> quindi 41 → 40, 173 → 172, 194 → 193. Dopo il calcolo si rigenerano le liste con la stessa regola. L'assegnazione dei
> ruoli per nome corregge anche `GSE145896`, un quarto braccio con i ruoli sbagliati, fuori dalle 194.

> **Ricevuto dalla misura del controllo condiviso (S4), da leggere per primo.** (1) Prima di ogni
> re-pool: `.run_per_study_de_all()` assegna i ruoli per posizione su una matrice che la cache rende
> in un altro ordine. Va assegnato per nome, con un test, e guardati anche i rami `mega` e `mega_aug`.
> Tre bracci del deliverable sono sbagliati per questo (finding S4 §5): si correggono in questo
> calcolo, per decisione del PI. (2) Il PI ha scelto la correzione della varianza (T1, solo la
> varianza): entra in `.collapse_arms_by_study()` **e** in
> `.collapse_arm_se_by_study()`, e i dati devono portare i campioni di ogni braccio. La frase
> «lievemente ottimistica» (`R/stage4-orchestrator.R:210`) è sbagliata: va riscritta.

### Perché

Le regole agiscono nello Stadio 3: finché non si rifà il cluster e il pool, il codice corretto non cambia nulla. **Questa sessione è separata da S14 apposta**: se decidi di non rifare il run completo, le correzioni si applicano lo stesso e il lavoro di S7-S12 non resta in un cassetto.

⚠️ **E può arrivare qui anche altro lavoro**: S9 conta il fix delle greche come «entra in una macchina che sta già girando», e S4 dice che una correzione del controllo condiviso «rientra in S13». **Prima di lanciare, verifica che cosa dev'essere dentro**: girare la macchina per una correzione sola e poi riscoprire che ne mancava un'altra costa il doppio.

### Che cosa si fa

Si depositano le previsioni **per iscritto** (quante meta-analisi, quali entità, quali k), si lancia re-cluster + re-pool in locale, si verificano le previsioni una per una.

**Gli script sono questi, e vanno lanciati così** — senza queste quattro cose la sessione non parte o produce spazzatura:

|  |  |
|------------------------------------|------------------------------------|
| re-cluster | `analysis/p4-fase-f13-stage3-v16-tre-cambi.R` — variabili: `STAGE1_MASTER`, `STAGE2_MASTER`, `H5_PATH`, `SUMMARIZE_WORKERS=32`. Prima un giro con `SMOKE=1`. |
| re-pool | `analysis/p4-fase-f5-stage4-layer-a-rebuild-v16.R` — **obbligatorie** `STAGE3_DIR` e `VERDETTI_PATH` (senza, si ferma apposta), più `STAGE2_MASTER`. Prima `DRY_RUN=1`. |
| ricomposizione | `analysis/p4-fase-f5b-stage4-ricomponi-pezzi.R` — `PEZZI_DIR`, `STAGE3_DIR`, `VERDETTI_PATH` |

1.  **Il re-pool va a pezzi, altrimenti non sono 6 ore ma 32.** Seriale costò 32,5 h; con `PEZZO`/`N_PEZZI` in processi separati sono \~2,5 h — ma allora serve il terzo script per ricomporli. Chi lancia lo script e basta aspetta un giorno e non ha il deliverable.
2.  **`setsid`**, mai `run_in_background`: ha già ucciso un run di ore a metà. Si verifica con `ps -eo pid,sid,args` che SID == PID.
3.  ⚠️ **`VERDETTI_PATH` è una trappola, non un parametro.** `.annotate_coherence()` (`R/stage4-coherence-annotation.R:48-53`) è **fatale sui verdetti orfani**: se un verdetto punta a un gruppo che non esiste più, l'annotazione si ferma. E lo scopo di S13 è **proprio** cambiare quali gruppi esistono. Quindi l'esito di default è: il run finisce dopo ore e *poi* aborta. Va pre-filtrato prima, come già fatto una volta (`analysis/audit/2026-08-02-fix/verdetti-poolato-v15-applicabili.csv`).
4.  Il re-pool **verifica lo SHA256** del master Stadio 2 contro quello registrato dallo Stadio 3 e si ferma se non combaciano: è una difesa, non un intoppo. `STAGE2_MISMATCH_OK=1` esiste ma va usato solo se sai perché.

### Come si sa che è finita

Il deliverable nuovo esiste e **ogni** previsione depositata è verificata, quelle sbagliate comprese.

### La decisione che spetta a te

Dopo: se il deliverable nuovo sostituisce quello attuale.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S13. Verifica che S12 sia chiusa.

PRIMA DI TUTTO verifica che cosa deve entrare in questo giro: oltre alle
correzioni del rilevatore (S12), potrebbero doverci stare il fix delle greche (S9
lo conta come "gratis perche' la macchina gira comunque") e una correzione del
controllo condiviso (S4 dice che "rientra in S13"). Girare per una sola e poi
scoprire che ne mancava un'altra costa il doppio.

Poi deposita le previsioni per iscritto - quante meta-analisi, quali entita',
quali k.

Gli script sono: analysis/p4-fase-f13-stage3-v16-tre-cambi.R (re-cluster,
variabili STAGE1_MASTER/STAGE2_MASTER/H5_PATH/SUMMARIZE_WORKERS=32, prima
SMOKE=1) e analysis/p4-fase-f5-stage4-layer-a-rebuild-v16.R (re-pool,
OBBLIGATORIE STAGE3_DIR e VERDETTI_PATH, prima DRY_RUN=1), piu'
analysis/p4-fase-f5b-stage4-ricomponi-pezzi.R per ricomporre.

QUATTRO COSE SENZA LE QUALI NON FUNZIONA:
1. il re-pool va a PEZZI (PEZZO/N_PEZZI in processi separati) o sono 32 ore
   invece di 2,5 - e poi serve il terzo script per ricomporli;
2. setsid, mai run_in_background (ha gia' ucciso un run a meta'); verifica
   SID==PID con ps -eo pid,sid,args;
3. VERDETTI_PATH e' una TRAPPOLA: .annotate_coherence() e' fatale sui verdetti
   orfani, e lo scopo di questa sessione e' proprio cambiare quali gruppi
   esistono - quindi il run finisce dopo ore e POI aborta. Pre-filtra i verdetti
   prima, come in analysis/audit/2026-08-02-fix/verdetti-poolato-v15-applicabili.csv;
4. il re-pool controlla lo SHA256 del master Stadio 2 contro quello dello Stadio
   3 e si ferma se non torna: e' una difesa, non un intoppo.

Alla fine verifica le previsioni una per una, comprese quelle che hai sbagliato.
```

------------------------------------------------------------------------

---

# S14 — Il re-run completo degli stadi LLM

> **Fatto il 2026-11-07: i due passi col modello** (`docs/findings/2026-11-07-S14-due-passi-col-modello.md`, evidenza `analysis/audit/2026-11-05-S14-re-run-modello/`).
> Stadio 1 e Stadio 2 rifatti da zero su `poddgx02`, in un solo run di 33 h. Master nuovi: `analysis/p4-output/S14-stage1-master.jsonl` (508.037 record, 3 campioni senza record valido) e `analysis/p4-output/S14-stage2-master.jsonl` (24.393 studi: `GSE9135` dei master vecchi non esiste). Ripetibilità: 211.484 record su 211.484 e 8.565 studi su 8.566 identici al riferimento; `GSE157657` è spiegato nel finding, §4.1. Copia verificata in `/mnt/micron/simulomicsr-salvataggio/S14-master-2026-11-07/`.
> **Che cosa resta di S14**, dopo S12 e dopo l'assegnazione dei ruoli per nome (S13, punto 1): re-cluster, re-pool e annotazione su questi due master, con le tappe gated scritte e approvate prima. Poi S15.
> **Da sapere prima di un altro run del modello sul corpus:** gli outlier dello Stadio 1 (oltre 3.500 caratteri) vanno con `max_model_len` 32768, come nel run di produzione F2. Con 4096 il job 452113 è rimasto fermo 1 h senza errori (vLLM #39734). La catena di S14 lo fa; i default di `dgx_p4_build_bundle()` no.
> **Tabelle dei nomi (punto 7 qui sotto): misurate in S10 il 2026-11-07** (finding S10 §7). Le tabelle si agganciano al
> `record_id` del run v9, quasi sempre con il numero d'ordine del gruppo. Nel master da zero il 69,9% dei record agganciati
> ha altri campioni o non esiste più. **Il raggruppamento sul re-run non può usare le tabelle come sono oggi.** Il PI ha
> deciso (2026-11-07): l'aggancio si corregge in **S12d**, ai campioni del master su cui le tabelle sono state scritte, senza
> rigenerarle con il modello. Raggruppamento e pooling di S14 vengono dopo S12d.

> **Ricevuto dalla prova del re-run (S8b), da leggere per primo. Il PI ha detto sì il 2026-11-05.**
> (1) **Oggetto:** i 24.394 studi, Stadio 1 e Stadio 2, da zero, in un solo run e senza innesti (lettura della frase «Si rifa tutto», finding S8b, «Decisioni del PI»). Se il PI la corregge, vale la sua correzione.
> (2) **Costo:** 44,4 h di macchina con due job alla volta (`analysis/audit/2026-11-04-S8b-prova/84-out.txt`), più la prova di invarianza. Non contiene la rigenerazione delle tabelle dei nomi.
> (3) **Nodo:** tutte le 8 GPU di `poddgx02`, due job da 4 GPU. Non usare `poddgx01`, vietato dal PI. Non usare `nodelist = NULL`. Non usare `poddgx05` senza una risposta esplicita del PI: sta su `shared-dgx`, con altri utenti. La ripetibilità è provata su un solo nodo: dichiaralo.
> (4) **Ordine, a scelta del PI.** I due passi col modello e i loro recuperi non dipendono da S12, perché S9-S13 agiscono solo su raggruppamento e pooling. Il PI può aprire questa sessione prima di S9, scrivendo «solo i due passi col modello»: in quel caso si ferma ai master. Re-cluster, re-pool e annotazione restano dopo S12 e dopo l'assegnazione dei ruoli per nome (S13, punto 1).
> (5) **Base del codice:** `analysis/audit/2026-11-04-S8b-prova/50-notte.R` (catena riprendibile) e `45-rescue-build-s2.R`. Le tappe (gated) vanno approvate lo stesso, con gli script scritti prima.
> (6) **Prima dell'invio:** il rinvio su `dgx_p4_status()` in S13, punto (2).
> (7) **Da decidere nelle attese:** rigenerare o no le tabelle dei nomi, e con quale costo. Il dubbio è in S8b §6 e in S10.
> (8) **Controllo in più:** gli 8.566 studi già rigenerati (agosto e prova) si confrontano record per record con il run nuovo. È il controllo di ripetibilità su tutti, oltre ai 300 della prova.

> **Ricevuto dalla misura del controllo condiviso (S4), da leggere per primo.** Uno Stadio 2 nuovo
> cambia le divisioni in ruoli: con la cache delle conte già piena può creare altri bracci con i ruoli
> sbagliati. La correzione dell'assegnazione dei ruoli (S13, punto 1) è un prerequisito anche qui.

> S8b ha detto sì. **Circa 44 ore di macchina su più giorni.**

### Perché

I 21.828 studi mai ri-processati (vedi S8). **Questa non è una sessione: è una campagna.** Va spezzata in tappe con un cancello fra l'una e l'altra, come è già stato fatto per A3 — lo schema è in `analysis/audit/2026-08-16-A3/README.md`.

### Che cosa si fa

Le tappe di A3, sull'intero corpus: prova di invarianza → Stadio 1 → rescue → Stadio 2 → rescue → re-cluster → re-pool → annotazione. Previsioni depositate prima. Un cancello dopo ogni tappa.

⚠️ **Tre tappe del README di A3 — la 5, la 7 e la 8 — sono marcate `(gated)` e non nominano nessuno script.** Sono le tre più pesanti (Stadio 1 sul corpus, Stadio 2, re-cluster + re-pool interi). **Prima di aprire il cancello si scrive quali script si useranno e si fanno approvare**, altrimenti si improvvisa sul pezzo più caro del progetto.

Vale tutto quello che S13 dice su script, variabili, pezzi, `setsid` e verdetti orfani. In più c'è la DGX: `VLLM_BATCH_INVARIANT=1` passato via `dgx_p4_submit(env=)`, e la verifica che sia arrivato davvero leggendo `runs/<run_id>/container-env.txt` — la variabile una volta **non esisteva nel codice** e i job giravano senza.

### Come si sa che è finita

Il deliverable nuovo esiste, le previsioni sono verificate, e **S15 è aperta**.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S14. Verifica che S8 abbia detto si' e che S12 sia chiusa.

Questa non e' una sessione, e' una campagna da 40-60 ore. Spezzala in tappe con
un cancello fra l'una e l'altra, sullo schema di
analysis/audit/2026-08-16-A3/README.md: invarianza, Stadio 1, rescue, Stadio 2,
rescue, re-cluster, re-pool, annotazione.

ATTENZIONE: le tappe 5, 7 e 8 di quel README sono marcate (gated) e NON nominano
uno script. Prima di aprire quei cancelli scrivimi quali script userai e fammeli
approvare.

Vale tutto quello che dice S13 su script, variabili, pezzi, setsid e verdetti
orfani. In piu' la DGX: VLLM_BATCH_INVARIANT=1 va passato con dgx_p4_submit(env=)
e VERIFICATO leggendo runs/<run_id>/container-env.txt - quella variabile una volta
non esisteva nel codice e i job giravano senza.

Deposita le previsioni PRIMA. Fermati a ogni cancello e dimmi dove siamo.
Quando finisce, aprimi S15.
```

------------------------------------------------------------------------

---

# S15 — Riverificare le meta-analisi cambiate

> **Ricevuto dalla lettura dei falsi allarmi (S11, 2026-11-07), da leggere per primo. Rinvio.** (1) **Il nome dei
> gruppi scritto dallo Stadio 2 non basta**: in almeno 9 studi i metadati GEO lo smentiscono (`GSE93153` «HBV» con
> campioni Mock; `GSE221804` «Wild-type» con doppi knockout; `GSE222658` «radiation» con CB-839; `GSE247389`,
> `GSE209582`, `GSE229331`, `GSE118566` con un secondo agente non nominato; `GSE198670`, `GSE184891` con bracci
> misti). Su 36 errori veri trovati in S11, 30 si leggono solo nei metadati GEO. **Che cosa serve:** la rilettura
> deve leggere titolo, sorgente e caratteristiche GEO dei campioni, non solo le etichette (come le schede di
> `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/23-schede.py`), e applicare le decisioni del PI di S11
> (tempo zero sempre errore; differenza tecnica sempre errore; errori nei metadati con la fonte marcata). (2) **114 delle 129 accuse di agosto non sono
> state rilette sui metadati**; fra le 15 rilette, 3 hanno un motivo diverso (§9 del finding S11). (3) **La scelta
> delle 40 e delle 132 è già decaduta in S11** (6 delle 40 cambiano verdetto): si rifà qui, una volta sola. (4) Il
> riferimento da usare è `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv` (193
> confronti), non quello di agosto.

> **Ricevuto dalla prova del re-run (S8b), da leggere per primo.** La stima di circa 38 meta-analisi toccate viene dal campione, senza validazione: conta quelle vere sul deliverable nuovo. Dopo la lettura, il PI
> rifà la scelta dell'insieme principale (le 40 e le 132), che decade con S14, e la regola sugli studi doppi si applica di nuovo.

> Solo se S14 è stata fatta.

### Perché

Il re-run cambia quali meta-analisi esistono. La rilettura a mano delle 194 — 60 agenti, verdetti che citano le etichette — vale per il deliverable vecchio. Le meta-analisi nuove o cambiate non sono mai state lette.

### Che cosa si fa

Si isolano le meta-analisi **nuove o con composizione cambiata** e si rileggono **solo quelle**, con lo stesso metodo.

**Il metodo è riproducibile, e i prompt esistono**: il materiale si rifà con `00-materiale.R` → `10-blocchi.R`, e i prompt di lettore, critici e arbitro sono salvati in `analysis/audit/2026-08-20-rilettura-194/C1-workflow-rilettura.js`.

⚠️ **Ma erano andati persi e sono stati recuperati il 2026-08-21.** S3 ha per compito di verificare che siano **verbatim**: se S3 è stata fatta, usa il suo esito; se non è stata fatta, **verificalo qui prima di usarli**, altrimenti stai rileggendo con una ricostruzione del metodo, non col metodo.

⚠️ **Ma non vanno ricopiati tali e quali.** La misura dice che i due critici hanno prodotto 69 rilievi contro 183 — rapporto 0,38. Il disegno era simmetrico, l'esito no. **Chi rifà la lettura corregga quella asimmetria**, e dichiari come.

Poi si riallineano verdetti, difetti, setaccio e le tre misure d'influenza.

⚠️ **Si ripete anche il controllo di S3** sul deliverable nuovo: venti gruppi non cambiati, riletti una seconda volta. Serve a sapere se il metro è rimasto lo stesso dopo il re-run.

### Come si sa che è finita

Ogni meta-analisi del deliverable nuovo ha un verdetto, e il setaccio è rifatto.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S15. Verifica che S14 sia finita.

Isola le meta-analisi nuove o con composizione cambiata rispetto alle 194, e
rileggi SOLO quelle con lo stesso metodo: il materiale si rifa' con 00-materiale.R
e 10-blocchi.R, e i prompt di lettore/critici/arbitro sono in
analysis/audit/2026-08-20-rilettura-194/C1-workflow-rilettura.js.

NON ricopiarli tali e quali: i due critici hanno prodotto 69 rilievi contro 183
(rapporto 0,38) - il disegno era simmetrico, l'esito no. Correggi l'asimmetria e
dimmi come.

Poi riallinea verdetti, difetti, setaccio e le tre misure d'influenza.

E ripeti il controllo di S3 sul deliverable nuovo: venti gruppi non cambiati,
riletti una seconda volta, per sapere se il metro e' rimasto lo stesso.
```

------------------------------------------------------------------------

---

# S16 — Rifare le figure sul deliverable vero

> **Ricevuto dal disegno della validazione esterna (S6), da leggere per primo.** Non dividere le figure per `kind_effective_resolved`: la colonna sbaglia il tipo
> (TGFB1 è `small_molecule`, IL6 è `genetic_knockout`, `g007_lk` è `disease_vs_normal`). Le classi per identificativo stanno in
> `analysis/audit/2026-11-04-S6-validazione-disegno/40-copertura-194.csv`.

### Perché

**Le figure destinate all'articolo descrivono un deliverable che non esiste più.** L'ultimo Layer B è `analysis/p4-output/20260808T063421Z-layer-b-81f379d3`, dell'8 agosto: la scheda di TGF-β1 dice **k = 59**, mentre nel deliverable attuale TGF-β1 è a **k = 54**. In più le narrative dei bundle sono marcate «BOZZE, testo scientifico da rileggere e firmare» — lo dice `CLAUDE.md` oggi, **e S1 lo riscriverà**: se S1 è già stata fatta, la fonte è `docs/STORIA.md`, e la marcatura «bozza» si controlla direttamente nei file `narrative.qmd` dei bundle.

È il prodotto visibile dell'articolo, ed è l'unico pezzo senza padrone.

### Che cosa si fa

Si rigenera la selezione **dal deliverable attuale** — mai a mano: un CSV di selezione portava 181 numeri di una versione precedente scritti a mano, e nessuna guardia se ne accorge perché è testo libero. Si ricostruiscono i bundle, si verifica **aprendo l'artefatto** che i k dichiarati siano quelli veri, si rileggono e si firmano le narrative.

⚠️ **Lo script di build per v16 non esiste, e questa è la parte rischiosa.** Il più recente è `analysis/p5-stage4-layer-b-build-v13.R`, **coi percorsi v13 scritti dentro**; il Layer B dell'8 agosto fu costruito su *stage4-v15*. Quindi il build va copiato e ri-puntato — ed è **esattamente la manovra che questo progetto ha già sbagliato due volte** (28 ore di pooling sui cluster vecchi finite in una cartella etichettata v14). Si cambiano **ingresso e uscita**, e si verifica che concordino **prima** di lanciare.

La selezione invece uno script ce l'ha: `analysis/audit/2026-08-02-fix/70-selection-v15.R`, che legge solo `deliverable-annotato.rds` — va adattato, non riscritto.

Il controllo finale è facile e non ammette scuse: `schede/001-TGFB1-k54.txt` dice il valore vero.

⚠️ **E c'è una seconda cosa che le schede stampano e che è falsa.** `R/layer-b-summary-card.R:131` stampa `coherence verdict: coherent` leggendo la colonna `coherence_verdict` del deliverable. Ma quella colonna dice `coherent` su 190 gruppi, mentre la rilettura ne ha giudicati corretti **116**: **74 schede dichiarerebbero una coerenza che la rilettura ha smentito.** O si riallinea la colonna ai verdetti di `verdetti-194.csv`, o la scheda smette di stamparla. Non è un dettaglio grafico: è un'affermazione falsa sul prodotto visibile.

### Che cosa NON si fa

Non si sceglie quali case study prima che S5 abbia deciso «37 o 173». (S5 ha deciso il 2026-11-04: le 40 nelle
figure principali, le altre 132 in supplementare.)

### Come si sa che è finita

Ogni scheda dichiara il k del deliverable attuale — verificato aprendo l'artefatto, non il codice — e nessuna narrativa è più marcata «bozza».

### La decisione che spetta a te

**Quali case study** vanno in figura, dentro l'insieme deciso in S5.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S16. Verifica che S5 abbia deciso "37 o 173".

L'ultimo Layer B e' dell'8 agosto e la scheda di TGF-β1 dice k=59, mentre nel
deliverable attuale e' k=54: le figure descrivono un deliverable che non esiste
piu'.

Rigenera la selezione DAL DELIVERABLE, mai a mano: adatta
analysis/audit/2026-08-02-fix/70-selection-v15.R, che legge solo
deliverable-annotato.rds.

ATTENZIONE sul build: NON esiste uno script Layer B per v16. Il piu' recente e'
analysis/p5-stage4-layer-b-build-v13.R, COI PERCORSI v13 SCRITTI DENTRO, e il
Layer B dell'8 agosto fu costruito su stage4-v15. Devi copiarlo e ri-puntarlo -
ed e' la manovra che qui e' gia' andata storta due volte (28 ore di pooling sui
cluster vecchi in una cartella etichettata v14). Cambia INGRESSO E USCITA e
verifica che concordino PRIMA di lanciare.

Poi verifica APRENDO L'ARTEFATTO che i k dichiarati siano quelli veri:
schede/001-TGFB1-k54.txt dice il valore giusto.

E c'e' una seconda cosa falsa che le schede stampano: R/layer-b-summary-card.R:131
scrive "coherence verdict: coherent" dalla colonna del deliverable, che dice
coherent su 190 gruppi mentre la rilettura ne ha giudicati corretti 116 - 74
schede dichiarerebbero una coerenza smentita. O riallinei la colonna a
verdetti-194.csv, o togli quella riga dalla scheda.

Poi rileggiamo le narrative, ancora marcate "bozza", e le firmiamo.
Proponimi i case study e fammi scegliere.
```

------------------------------------------------------------------------

---

# S17 — Scrivere i Methods e le limitazioni

> **Ricevuto dalla prova del re-run (S8b), da leggere per primo.** Il PI ha scelto il re-run completo: il paragrafo «Scope of the model re-run» del finding S8b §7 e quello del finding S8 §7 non si usano. I Methods
> descrivono un solo run su 24.394 studi, con i numeri del deliverable finale.

> **Ricevuto dall'esecuzione della validazione esterna (S7), da leggere per primo.** Da dichiarare, con i numeri della seconda esecuzione: il valore contro LINCS dipende dal numero di linee (da 63% a 74%
> sulle 19) e dalla forza del composto (Spearman 0,515 con `tas`); contro Tahoe il valore è molto più basso (11 su 32); il test non separa le 40 dalle altre 132 né le corrette dalle difettose;
> 978 geni su 21.758, linee tumorali. **Il PI ha scelto la forma del testo (2026-11-04):** i successi contro LINCS con il denominatore, l'intervallo di valori secondo il trattamento delle linee, i successi contro Tahoe-100M come seconda fonte senza verdetto, e le altre 21 delle 40 come non validate.

> **Ricevuto dalla sessione sul gate e i due insiemi (S5), da leggere per primo.** Tre limiti da scrivere, con i numeri
> del finding. **(1)** L'I² è poco leggibile sotto i dieci studi: l'intervallo copre 95,6 punti a k=3 e 23,2 a k≥10.
> **(2)** La significatività sotto i dieci studi dipende dal test z: con Knapp-Hartung almeno un gene resta nel 17% dei
> gruppi a k=3 e nel 78% a k≥10. **(3)** Il segno concorde fra studi non è una prova: vale 99,2% anche con studi non
> collegati, perché il REM seleziona i geni concordi. Non si cambia il test senza una decisione del PI.
> **Il PI ha scelto (2026-11-04):** il gate resta a 3 studi e questo limite va nei Methods. L'articolo usa le 40 come
> insieme principale e le altre 132 in supplementare. La dominanza si dichiara con una colonna, due livelli e il
> confronto con studi non collegati.

> **Ricevuto dalla misura del controllo condiviso (S4), da leggere per primo.** Da dichiarare: la
> correlazione fra bracci con campioni diversi dello stesso laboratorio resta non modellata, anche
> dopo la correzione della varianza. Il PI ha scelto di correggere varianza e ruoli in S13: se S13
> non gira prima dell'articolo, vanno dichiarati l'errore standard sottostimato (rapporto mediano
> 1,20 in 171 coppie) e i ruoli sbagliati di tre bracci.

### Perché

Almeno **sette** cose misurate in questi mesi devono finire in un testo, e oggi non hanno un posto: il bias concorde, il 16,5% di verdetti che l'etichetta non chiude, i 1.993 campioni persi dallo Stadio 2, la dominanza, le lettere greche (se si decide di non correggerle), il 10,5% del re-run (se S8 dice no), il gate.

Finché restano sparse nei findings si disperdono: è lo stesso meccanismo per cui si sono accumulati 44 blocchi di Stato senza mai potarli.

### Che cosa si fa

Si scrive il testo: Methods, e una sezione di limitazioni dichiarate che le raccolga tutte, ognuna col suo numero e il puntatore all'evidenza.

### Che cosa NON si fa

Non si scrive prima che S5 abbia deciso: il testo cambia se l'articolo è 37 o 173.

### Come si sa che è finita

**Ognuna delle undici** — le sette dei titoli più le quattro del ⚠️ qui sotto — ha un paragrafo, e ogni paragrafo ha accanto il file da cui viene il numero.

⚠️ **Ne vanno aggiunte altre quattro, che non sono nei titoli e chi scrive dai numeri di testa se le perde:**

- **i critici non sono stati simmetrici** — 69 rilievi contro 183, rapporto 0,38, con 37 assoluzioni proposte da uno e 1 dall'altro (§3 del finding). Il disegno era simmetrico, l'esito no;
- **i 194 verdetti vengono da un modello e nessun umano li ha letti.** Il precedente del progetto è pesante: sugli stessi 213 gruppi, Mistral ne dichiarò incoerenti 24 e la lettura umana 96, **accordo 36,2%**. Tutto quello che sta in questo handout — 116/62/16, i 97 difetti, i 173, i 37 — poggia su un metro la cui riproducibilità **non è mai stata misurata**;
- **il peso gonfiato dai bracci che condividono il controllo** (S4), che alza `quota_top1`, cioè il criterio che taglia da 113 a 37. ⚠️ **Non chiamarlo «doppio conteggio»**: i trattati sono campioni diversi in 56 casi su 56, non è una duplicazione;
- **i 1.993 campioni persi non sono stati guardati per braccio.** La frase «potenza buttata, non risultati sbagliati» è un'**asserzione, non una misura**: se i persi di uno studio stanno tutti da un lato, il confronto è sbilanciato, non solo più piccolo. O si misura, o si scrive che non si sa.

⚠️ **E non si riparte da zero:** le limitazioni già a libro stanno nella memoria `project_paper_known_limitations` (L1 schema mono-asse, L2 tetto del modello, L3 dimensione del mini-gold, L4 campioni omessi, **L7** i 279 gruppi trattati-solo esclusi col prestito di controlli bocciato con misura). Vanno recuperate, non riscritte.

### La decisione che spetta a te

Il tono e la lunghezza: quanto spazio dare alle limitazioni.

### Prompt

```         
Apri docs/superpowers/specs/2026-08-21-HANDOUT-DIFETTI-APERTI.md e fai la
SESSIONE S17. Verifica che S5 abbia deciso.

Scrivi i Methods e la sezione delle limitazioni dichiarate. Devono starci tutte e
sette: bias concorde, 16,5% di verdetti non chiusi dall'etichetta, 1.993 campioni
persi dallo Stadio 2, dominanza, lettere greche (se non le correggiamo), 10,5%
del re-run (se non lo rifacciamo), gate k>=3.

E aggiungine altre quattro che nei titoli non ci sono:
- i critici della rilettura NON sono stati simmetrici (69 rilievi contro 183,
  rapporto 0,38 - §3 del finding);
- i 194 verdetti vengono da un MODELLO e nessun umano li ha letti. Precedente:
  sugli stessi 213 gruppi Mistral ne dichiaro' incoerenti 24 e la lettura umana
  96, accordo 36,2%. La riproducibilita' del metro non e' mai stata misurata;
- il peso gonfiato dai bracci che CONDIVIDONO IL CONTROLLO (vedi S4): alza
  quota_top1, il criterio che taglia da 113 a 37. NON chiamarlo "doppio
  conteggio": i trattati sono campioni diversi in 56 casi su 56;
- i 1.993 campioni persi non sono mai stati guardati PER BRACCIO: "potenza
  buttata, non risultati sbagliati" e' un'asserzione, non una misura. O la misuri
  o scrivi che non si sa.

E non ripartire da zero: le limitazioni gia' a libro stanno nella memoria
project_paper_known_limitations (L1, L2, L3, L4, L7). Recuperale.

Ogni paragrafo con accanto il file da cui viene il numero. Se un numero non lo
trovi nell'evidenza, non scriverlo: dimmelo.
```

------------------------------------------------------------------------

------------------------------------------------------------------------

## I file da cui viene tutto questo

|  |  |
|------------------------------------|------------------------------------|
| `analysis/audit/2026-08-20-rilettura-194/` | la rilettura, le tre misure d'influenza, gli script |
| `INFLUENZA-DEI-DIFETTI.md` | peso contaminato, influenza, nulli, il setaccio 194→37 |
| `COME-SI-FORMA-UNA-META-ANALISI.md` | la catena passo per passo |
| `schede/` | 194 schede, una per meta-analisi, campione per campione |
| `docs/findings/2026-08-20-rilettura-194-correttezza.md` | verdetti, tassonomia, lettere greche |
| `analysis/audit/2026-08-16-A3/README.md` | lo schema a cancelli del re-run parziale |
