# Sessione S5, il gate e i due insiemi: cancelli e previsioni

**Scritto il 2026-11-03, prima del calcolo.** Deliverable A3 v16, 194 meta-analisi:
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`.
Il deliverable, la copia su micron, i master e la cache delle conte non si toccano. Nessun
verdetto cambia. Il gate non cambia: questa sessione misura che cosa succederebbe.

## Che cosa ho già guardato prima di scrivere

- Manifesto SHA-256: passa.
- `non_processable.rds`: 122 righe, 88 a `k_eff=2`, 27 a 1, 7 a 0. I 309 gruppi di
  `per_study_de.parquet` sono 194 + 88 + 27: **i bracci delle 88 sono già su disco**.
- **Il gate agisce due volte.** `.identify_layer_a_clusters()` taglia su `k` censito con lo stesso
  `k_eff_min` (`R/stage4-qc.R`), poi l'orchestratore taglia su `k_eff`. Con `k_eff_min=3` i candidati
  sono 316, con `k_eff_min=2` sono 700. **I 384 candidati a `k` censito 2 non compaiono in
  `non_processable.rds`.** Il numero 88 dell'handout è quindi un minimo, non la risposta.
- Ritenzione per studio fra censimento e dispatch: 0,695 a `k` censito 3, 0,616 a 4, 0,657 su tutti.
- Riferimenti del deliverable per fascia di `k_effective` (T0, mediane per gruppo):

| k | gruppi | I² | τ² | geni significativi | `k_kish` | `quota_top1` |
|---|---:|---:|---:|---:|---:|---:|
| 3 | 81 | 57,7 | 0,031 | 1.428 | 1,93 | 0,616 |
| 4 | 33 | 73,1 | 0,064 | 1.143 | 2,37 | 0,516 |
| 5-9 | 57 | 72,0 | 0,070 | 895 | 2,92 | 0,467 |
| ≥10 | 23 | 86,9 | 0,124 | 1.939 | 13,96 | 0,086 |

- `compute_pooling_effectiveness()`: `quota_top1` è la mediana sui geni significativi del massimo
  peso. Con due studi quel massimo vale almeno 0,50 per ogni gene, e `k_kish` vale al massimo 2.
- `B4-quadro-influenza.csv`: `k_ridotto` vale 2 in 16 gruppi e manca in 5 (i 21 che escono).

**Non ho guardato:** il dispatch dei 384, nessun I², τ² o gene significativo a `k=2`, nessun numero
del movimento con il gate a 2, nessuna stima senza lo studio dominante.

## Che cosa si calcola

- **Gruppi a k=2:** dispatch di produzione su tutti i 700 candidati, poi fit limma-voom per braccio
  con i ruoli **per nome** (decisione del PI nella sessione sul controllo condiviso). Il trattamento
  primario è **T1**, la varianza corretta che il PI ha scelto, con T0 accanto.
- **Conte:** si leggono dalla cache se ci sono. Quelle che mancano stanno in una cache privata in
  `/mnt/micron/simulomicsr-dati/2026-11-03-S5-gate-e-insiemi/`. Nella cache di produzione non si
  scrive, perché un ordine nuovo dei campioni può creare i ruoli sbagliati che S13 deve correggere.
- **Incertezza di τ² e I²:** intervallo Q-profile al 95%, gene per gene, per ogni gruppo a `k=2` e
  per le 194. A `k=2`, con `d = y1 - y2`: `Q(τ²) = d²/(v1 + v2 + 2τ²)`, quindi forma chiusa.
  A `k≥3`: `uniroot` su `Q(τ²)`. I² si ottiene da τ² con la varianza tipica di metafor.
- **Significatività alternativa:** Knapp-Hartung con `t(k-1)` e BH dentro il gruppo, solo come
  misura. **Intervallo di predizione:** `.rem_prediction_interval()`, la funzione del pacchetto.
- **Senza lo studio dominante:** per ogni gruppo dei 173 con `quota_top1 > 0,50` in T1, REM senza
  quello studio. Sui geni significativi si misura il segno concorde e `p < 0,05`.
- **Movimento:** dispatch del riferimento a 211 con le stesse due soglie, poi studi che escono.

**Incertezza.** L'unità è il gruppo, tranne il movimento dove è lo studio. Bootstrap percentile
della mediana (o della quota), B = 2000, seme 20261103. I conteggi esaustivi non hanno intervallo:
si giudicano contro l'intervallo di rilevanza.

## Cancelli

1. **Manifesto.** `10-manifesto-e-copia.sh verifica` passa all'inizio e alla fine. La cache di
   produzione ha 29.290 file all'inizio e alla fine.
2. **Dispatch riprodotto.** Sui 316 candidati del deliverable la replica dà 3.319 scarti identici a
   `qc_report$dispatch_drops`, le 122 righe di `non_processable.rds` e i `k_effective` delle 194.
   Le coppie (gruppo, studio) dei 309 gruppi coincidono con `per_study_de.parquet`.
3. **Catena riprodotta.** Il mio REM con T0 riproduce `cluster_pooled.parquet` sulle 194 (scarto
   < 1e-6 su `logFC_pool`, `SE_pool`, `tau2`, FDR), e `quota_top1`, `k_kish`, `I2_med` del
   deliverable. T1 riproduce `q1`, `kish1`, `sig1` di `50-per-gruppo.csv`. I bracci del parquet
   nei gruppi a `k_eff` 1 e 2 si riproducono col fit per nome o col fit per posizione (scarto < 1e-6):
   0 bracci senza spiegazione.
4. **Copertura.** Ho calcolato tutti i gruppi a `k=2` su tutti, e 194 su 194. Ricavo dai file 194 →
   128 → 116 → 113 → 37, le 41 di `in37_1`, 173 = 128 + 45, e le 41 stanno dentro le 173.
5. **Controllo positivo dello strumento sugli intervalli.** (a) Su 2.000 geni per ciascun `k` in
   {2, 3, 4} gli estremi di τ² coincidono con `metafor::confint` (scarto relativo < 1e-3 dove
   l'estremo è positivo). (b) Su 20.000 geni simulati a `k=2`, con errori standard tratti da un gruppo
   vero e τ² noto, l'intervallo contiene il valore vero fra il 93% e il 97% delle volte.

## Previsioni

| # | quantità | attesa | intervallo | da dove viene il margine |
|---|---|---:|---:|---|
| P1 | gruppi a `k` censito 2 che arrivano a `k_eff=2` | 166 | [140; 200] | variabilità misurata: 384·p² con p fra 0,616 e 0,70 |
| P2 | gruppi a `k=2` con `quota_top1 ≤ 0,50` | 0 | [0; 0] | vincolo matematico: uno scarto indica un errore mio |
| P3 | I² mediano a `k=2` (mediana per gruppo, T1) | 45 | [30; 60] | giudizio: la fascia «moderata» del Cochrane Handbook |
| P4 | ampiezza mediana dell'intervallo di I² a `k=2`, punti | 97 | [75; 100] | giudizio: oltre 75 punti l'intervallo va da «trascurabile» a «considerevole» |
| P5 | ampiezza a `k=2` meno ampiezza a `k=3`, punti | +4 | [0; 10] | giudizio: fino a 10 punti su ~90 il gate a 3 non dà un I² più leggibile |
| P6 | geni significativi con τ̂² = 0 a `k=2` (mediana per gruppo) | 40% | [25%; 60%] | giudizio: sopra il 60% il risultato è di fatto a effetti fissi |
| P7 | geni significativi a `k=2` (mediana per gruppo, T1) | 1.200 | [600; 2.400] | giudizio: un fattore 2; il valore a `k=3` è 1.428 |
| P8 | geni significativi che restano con Knapp-Hartung, `k=2` (mediana per gruppo) | 0,5% | [0%; 5%] | giudizio: sotto il 5% la significatività dipende dall'approssimazione normale |
| P9 | la stessa quota a `k=3` | 15% | [5%; 30%] | giudizio: serve a dire se il gate a 3 risolve il problema o lo riduce |
| P10 | geni significativi con intervallo di predizione che esclude 0, `k=2` | 1% | [0%; 5%] | giudizio: è la frase dell'handout «non esclude nulla» |
| P11 | la stessa quota a `k=3` | 5% | [1%; 15%] | giudizio, come P9 |
| P12 | quota di studi usciti con gate 2 / quota con gate 3 | 0,75 | [0,60; 0,90] | giudizio: sopra 0,90 il gate a 2 non stabilizza, sotto 0,60 stabilizza molto |
| P13 | bracci con ruoli sbagliati fra i 319 fuori dalle 194 | 1 | [0; 3] | variabilità misurata: 3 su 1.903 nel deliverable |
| P14 | segno concorde senza lo studio dominante (mediana per gruppo) | 85% | [70%; 95%] | giudizio: sotto il 70% un gene su tre dipende da uno studio solo |
| P15 | `p < 0,05` senza lo studio dominante (mediana per gruppo) | 25% | [10%; 50%] | giudizio: dice che cosa si può scrivere accanto a un gruppo dominato |

I margini di P3-P12, P14 e P15 sono giudizi motivati. Li dichiaro al PI nel riassunto.

**Che cosa cambia.** P4 e P5 decidono la frase sul costo del gate a 2 nel file delle opzioni. P8-P11
dicono se il gate a 3 protegge o se lo fa solo in parte. P12 risponde al motivo per cui si discute il
gate. P14 e P15 danno il numero per il modo di dichiarare la dominanza con la rimozione dello studio.

## Limiti dichiarati prima

- **I gruppi a `k=2` non sono stati letti da nessuno.** Non hanno un verdetto, quindi non possono
  entrare in nessuno dei due insiemi senza una lettura dedicata. Questa sessione non li legge.
- La misura sul movimento usa due esecuzioni soltanto, e vale per quella coppia.
- La rimozione dello studio dominante vede gli studi discordanti. Un bias concorde resta invisibile.
- T1 corregge solo la correlazione dal controllo condiviso. Il batch fra bracci con campioni diversi
  resta non modellato.

## Aggiunta dopo il primo risultato (2026-11-03, prima di eseguire `43-spiega.R`)

Il testo sopra resta com'è. **Il cancello 5(a) fallisce come depositato:** scarto relativo massimo su
τ² fino a 0,47 contro il limite 1e-3 (`42-out.txt`). Il cancello 5(b) passa. P6, P9, P10 e P11 sono
smentite e P3 e P12 sono indeterminate, come da `40-out.txt` e `60-out.txt`.

**Cancello 5-bis, criterio scritto prima di guardare.** L'ipotesi è la tolleranza di `uniroot` dentro
`metafor::confint` (predefinita circa 1,2e-4 in valore assoluto), che pesa sugli estremi piccoli.
Sugli stessi geni, con lo stesso seme, chiamo `confint` con `tol = 1e-10`. Passa se per k in {2, 3, 4}
lo scarto relativo massimo su τ² sta sotto 1e-3 dove l'estremo supera 1e-6. Controllo in più: `Q`
valutata nel mio estremo dista dal bersaglio meno di 1e-6.

**Controlli sul test alternativo, stesso criterio di scarto.** La mia `knapp_hartung()` deve dare gli
stessi p di `metafor::rma(test = "knha")` su 2.000 geni per k in {2, 3, 4} (scarto assoluto < 1e-6).

**Spiegazioni da misurare, non previsioni:**
- quota di geni con τ̂² = 0 su tutti i geni e sui significativi, per fascia di k;
- quota di geni il cui intervallo di predizione esclude 0, separata per τ̂² = 0 e τ̂² > 0;
- gruppi con almeno un gene significativo col test Knapp-Hartung, per fascia di k.

**Anomalia non prevista: gli studi doppi** (`45`-`48`). La ricerca è nata da P2 e non ha previsioni
depositate. Si scrive come anomalia, con il suo controllo positivo sulle tre coppie a correlazione 1.

## Seconda aggiunta (2026-11-03, prima di eseguire `72-nullo-senza-dominante.R`)

P14 e P15 sono smentite verso l'alto: segno concorde 99,2% (98,9-99,4) contro [70%; 95%], `p < 0,05`
63,6% (60,7-66,5) contro [10%; 50%] (`70-out.txt`). **Non basta come prova.** Il REM penalizza con τ²
i geni discordanti, quindi i geni significativi possono essere concordi per selezione.

**Controllo negativo.** Per ciascuno dei 96 gruppi dominati tengo lo studio dominante e sostituisco gli
altri `k-1` studi con altrettanti studi estratti a caso da altre meta-analisi delle 194, con entità
diversa e assenti dal gruppo. Una estrazione per gruppo, seme 20261103, T1. Rifaccio REM e geni
significativi, tolgo lo studio dominante e misuro le stesse tre quantità.

**Regola, scritta prima di guardare.** Per ciascuna quantità (segno concorde, `p < 0,05`, geni ancora
FDR < 0,05) calcolo la differenza mediana vero meno nullo, appaiata per gruppo, con bootstrap sui gruppi
(B = 2000, seme 20261103).
- La quantità serve per dichiarare la dominanza solo se l'IC95 della differenza sta tutto sopra
  **10 punti**. Il margine è un giudizio: sotto 10 punti il numero non distingue il gruppo vero da
  studi non collegati.
- Se non passa, nel file delle opzioni la quantità non si usa come prova, e lo scrivo.

Il controllo non dice quanto valgono i geni: studi non collegati possono condividere una risposta
generica allo stress o alla coltura.
