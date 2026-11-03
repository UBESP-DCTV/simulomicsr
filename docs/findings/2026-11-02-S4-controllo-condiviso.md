---
type: Finding
title: "I bracci che condividono il controllo: il taglio passa da 37 a 41, e tre bracci hanno i ruoli sbagliati"
description: "Misura del controllo condiviso sulle 194 meta-analisi con tre trattamenti corretti, più un errore di produzione trovato dal cancello di riproduzione."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-02T21:40:00+01:00'}
sources:
- {id: previsioni, resource: "analysis/audit/2026-11-02-S4-controllo-condiviso/00-previsioni.md", title: "Cancelli e previsioni, depositati prima del calcolo"}
- {id: deliverable, resource: "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d", title: "Deliverable A3 v16, 194 meta-analisi"}
- {id: inversioni, resource: "docs/findings/2026-11-02-inversioni-bracci-194.md", title: "Inversioni dei bracci sulle 194"}
---

# In breve

## In breve: i bracci che condividono il controllo cambiano le meta-analisi che possiamo usare?

**A cosa serviva.** Molti studi hanno più bracci trattati contro lo stesso controllo. La pipeline combina questi bracci come se fossero indipendenti, quindi sottostima l'errore standard dello studio e ne alza il peso. Quel peso dice se un solo studio porta più di metà della meta-analisi, e questo criterio porta le candidate per l'articolo da 113 a 37.

**Cosa abbiamo trovato.**

1. **Due controlli scritti prima del calcolo non sono passati. Li ho spiegati e il risultato sul peso regge, ma la scelta di accettarli spetta a te.**
   - Il primo controllo rifaceva ogni confronto e ha trovato un errore vero, descritto al punto 5.
   - Il secondo controllo aveva due soglie sbagliate, perché ignorava la correlazione fra i geni dei campioni veri. Ho scritto soglie nuove e le ho provate su 48 gruppi di controllo mai usati: la prova passa.
2. **Con l'errore standard corretto, le meta-analisi che passano tutti i controlli salgono da 37 a 41.** Entrano psoriasi, Parkinson, disturbo bipolare e `ykl 5 124`. Non esce nessuna meta-analisi, e tre trattamenti diversi danno le stesse quattro.
   - Tre di queste restano vicine al limite: il primo studio porta fra il 49% e il 50% del peso.
   - Parkinson contiene anche il braccio sbagliato trovato dalla ricerca delle inversioni. Quello studio porta meno dell'1% del peso.
3. **Il problema tocca 492 bracci su 1.118 e 109 meta-analisi su 194, e non è piccolo.** In mediana l'errore standard corretto è il 20% più grande di quello attuale. Su singoli geni arriva a 2,7 volte. Il codice lo descrive come «lievemente ottimistico». Gli altri 626 bracci hanno controlli separati e non cambiano.
4. **I geni significativi calano poco nel totale, ma in 20 meta-analisi su 108 ne cade più del 20%.** Sulle 194 il totale cala del 3,1%, e sulle 37 cala dello 0,7%.
   - La sclerosi multipla scende da 1.082 a 53 geni. L'artrite reumatoide scende da 2.833 a 932 geni. In entrambe lo studio che pesa di più ha molti bracci con lo stesso controllo: 10 e 5.
   - In 8 delle 20, a FDR 0,10 restano tanti geni quanti erano a FDR 0,05. In questi casi pesa la soglia.
   - Le stime dell'effetto restano quasi uguali: in quelle 20 la correlazione fra prima e dopo ha mediana 0,998.
5. **Tre bracci hanno i ruoli sbagliati nel risultato, per un errore della pipeline.** La pipeline salva le conte su disco con una chiave che ignora l'ordine dei campioni. Poi assegna trattato e controllo per posizione, quindi un ordine scritto da una richiesta precedente mette i ruoli sui campioni sbagliati.
   - `GSE222992` in R1881: il braccio è invertito per intero. Con i ruoli giusti i geni significativi passano da 7.956 a 8.027.
   - `GSE208347` in Parkinson: i due «trattati» sono controlli, e i veri trattati stanno fra i controlli. I geni passano da 838 a 839.
   - `GSE135485` in endometriosi: un trattato e un controllo hanno i ruoli scambiati. I geni passano da 62 a 89.
   - Nessuna delle tre meta-analisi attraversa il limite del 50%, neanche con l'errore standard corretto.
   - Un nuovo calcolo può creare altri errori uguali, se i ruoli cambiano rispetto alla richiesta precedente.

**Cosa devi decidere.**

1. **Correggiamo l'errore standard nel calcolo che applicherà le correzioni? Consiglio di sì, e consiglio di cambiare solo la varianza.** Le stime di ogni studio restano quelle di oggi, e le 37 diventano 41.
   - In alternativa fondiamo i bracci con lo stesso controllo in un confronto solo. Le 41 sono le stesse, ma dosi e tempi diversi finiscono in un solo braccio e la sclerosi multipla scende a 0 geni.
   - In alternativa usiamo i minimi quadrati generalizzati. Le 41 sono le stesse, ma cambiano anche le stime e un braccio può ricevere un peso negativo.
   - In alternativa lo dichiariamo solo nei Methods. Restano le 37, e l'articolo pubblica errori standard che sappiamo troppo piccoli.
2. **Correggiamo l'assegnazione dei ruoli prima di ogni nuovo calcolo? Consiglio di sì.** La modifica assegna i ruoli per nome del campione. I tre bracci si correggono nello stesso calcolo del punto 1.
   - In alternativa correggiamo subito i tre bracci con un calcolo a parte. La correzione arriva prima, ma i calcoli diventano due.
   - In alternativa dichiariamo solo l'errore. Il prossimo calcolo può creare altri bracci sbagliati.
3. **Accetti questa misura con i due controlli non passati e spiegati? Consiglio di sì.** Il primo controllo ha trovato un errore vero. Il secondo è passato su dati nuovi, con soglie scritte prima di guardarli.
   - In alternativa rifaccio la misura con un disegno nuovo. Costa una sessione in più, e non mi aspetto numeri diversi.

**Comunque:**

- non cambiamo nessun verdetto e non tocchiamo il risultato depositato;
- la scelta fra le 37 e le 173 userà il numero 41, se confermi il punto 1;
- scriveremo nei Methods che la correlazione fra bracci con campioni diversi dello stesso laboratorio resta non misurata.

Appena decidi questi 3 punti, la sessione è chiusa.

# Decisioni del PI (2026-11-03)

Il PI ha accettato le tre proposte del riassunto. Il testo qui sopra resta com'era quando il PI l'ha letto.

1. **Errore standard: si corregge solo la varianza (T1), nel calcolo che applica le correzioni (S13).** Le stime di ogni studio restano quelle di oggi. Il taglio di riferimento è 41. Fusione e GLS restano sensibilità.
2. **Ruoli: si correggono per nome del campione, prima di ogni nuovo calcolo.** I tre bracci sbagliati si correggono nello stesso calcolo di S13. Nessun calcolo a parte.
3. **La misura vale, con i cancelli 3 e 4 falliti come depositati e spiegati (§5, §6).** Il fallimento resta scritto in §1. Il cancello 4-bis non lo cancella.

Fino al calcolo di S13 il deliverable resta com'è: `SE_pool`, `quota_top1` e i geni significativi su disco sono quelli di T0, e i tre bracci restano sbagliati. La lista delle 41 sta in `50-per-gruppo.csv`, colonna `in37_1`.

# 1. I cancelli

Testo depositato in `00-previsioni.md`[^previsioni], commit `bba1c18`. Il cancello 4-bis è del commit `889be2a`.

| # | cancello | esito | fonte |
|---|---|---|---|
| 1 | manifesto SHA-256 | **passa** | `10-manifesto-e-copia.sh verifica` |
| 2 | riproduzione di T0: 3.210.306 righe di `cluster_pooled` e `quota_top1`, `k_kish` | **passa**: scarto massimo 8,4e-14 su `logFC_pool`, 3,6e-13 su `SE_pool`, 1,1e-13 su `tau2`, 7,4e-13 su FDR, 1,3e-15 su `quota_top1`, 8,0e-15 su `k_kish`; setaccio 113 → 37 | `50-out.txt` |
| 3 | fit ripetuto dei 1.118 bracci multi-braccio | **fallisce come depositato**: 1 braccio con scarto (`GSE222992`), più 2 fra i bracci unici. Vedi §5 | `20-out.txt` |
| 4 | controllo positivo sul nullo | **fallisce come depositato**: (a) scarto +0,073 in 1:1:1, +0,048 in 1:1:2, limite 0,05; (b) MAD² di T1 1,197 e 1,181, limite 1,15; (c) passa, T0 1,72 e 1,48. Vedi §6 | `30-out.txt` |
| 4-bis | la stessa prova su 48 insiemi non usati, criteri scritti prima | **passa**: (a) scarto medio −0,019 e −0,007; (b) T1/T3 1,03 e 1,03; (c) T0/T1 1,46 e 1,30 | `32-out.txt` |
| 5 | copertura e formula chiusa | **passa**: 194 gruppi su 194, 1.903 bracci su 1.903; formula chiusa con scarto < 1e-10; 0 gruppi non toccati con quota cambiata | `10-out.txt`, `50-out.txt` |

Il protocollo dice che con un cancello fallito la sessione non vale. Non ho cambiato i cancelli 3 e 4 dopo il risultato. Il PI ha accettato le spiegazioni il 2026-11-03 (decisione 3).

# 2. Le previsioni

| # | quantità | attesa | intervallo | stima (IC95) | esito |
|---|---|---:|---:|---:|---|
| P1 | bracci che condividono un campione, su 1.118 | 750 | [560; 950] | **492** (44,0%) | **smentita**, §3 |
| P2 | `SE_T1/SE_T0` mediano per coppia | 1,20 | [1,10; 1,35] | 1,199 (1,182; 1,220) | confermata |
| P3 | Δ`quota_top1` mediano, 23 gruppi dei 113 col dominante che condivide | −0,04 | [−0,08; −0,01] | −0,024 (−0,048; −0,013) | confermata |
| P4 | M con T1 | 44 | [39; 49] | **41** | confermata |
| P5 | variazione mediana di `n_sig` per gruppo | −8% | [−15%; −3%] | −2,1% (−5,6%; −0,9%) | **indeterminata**, §4 |
| P6 | uscite dai 37 | 1 | [0; 3] | 0 | confermata |
| P7 | M(T3) − M(T1) | +1 | [−3; +5] | 0 | confermata |
| P8 | `SE_T3/SE_T1` mediano | 1,10 | [1,00; 1,30] | 1,047 (1,018; 1,068) | confermata |
| P9 | \|M(T2) − M(T1)\| | 1 | [0; 3] | 0 | confermata |

# 3. Il conteggio (`10-out.txt`)

**492 bracci su 1.118** condividono almeno un campione con un altro braccio della stessa coppia (gruppo, studio): 171 coppie, 152 studi, **109 gruppi su 194**. Sono tutti controlli in comune: 0 bracci condividono trattati, 0 hanno un campione con ruoli opposti. La correlazione `rho` massima per braccio ha mediana 0,45 (IQR 0,33-0,50, massimo 0,89). Le coppie arrivano a 28 bracci. I componenti da fondere sono 191.

**P1 è smentita, e la causa è spiegata.** Gli altri 626 bracci stanno in studi multi-braccio con controlli separati, di solito uno per tempo o per linea cellulare. La mia attesa veniva dai 56 casi con etichetta identica dell'handout, dove i controlli identici sono 46 su 56: quello è un sottoinsieme favorevole. Il numero «59 dei 113 con il dominante a più bracci» conta tutti gli studi multi-braccio. Quelli con il dominante che condivide un controllo sono **23**, e 17 stanno fuori dai 37. I 48 gruppi dei 113 con almeno una coppia che condivide sostituiscono i «20» dell'handout, che contavano solo le etichette identiche.

# 4. Il taglio e le stime (`50-out.txt`, `55-out.txt`, `56-out.txt`)

**Le due catene.** `.collapse_arms_by_study()` (stime) e `.collapse_arm_se_by_study()` (`quota_top1`) usano la stessa varianza inversa. Il cancello 2 prova che tutte e due coincidono con la mia formula, e nel deliverable non ci sono `logFC` o `SE` non finiti che le separino. La correzione deve entrare in tutte e due.

**Il taglio.** 113 → **41** con tutti e tre i trattamenti, con le stesse quattro meta-analisi e nessuna uscita. Con `k_kish >= 2` il numero resta 41.

| meta-analisi | k | dominante | quota T0 | T1 | T2 | T3 | geni T0 | T1 | T3 |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|
| psoriasis | 9 | `GSE150851` | 0,504 | 0,425 | 0,421 | 0,431 | 543 | 356 | 378 |
| Parkinson Disease | 8 | `GSE181029` | 0,516 | 0,486 | 0,483 | 0,444 | 838 | 687 | 405 |
| `ykl 5 124` | 3 | `GSE172442` | 0,514 | 0,497 | 0,493 | 0,487 | 2.121 | 1.817 | 1.579 |
| bipolar disorder | 3 | `GSE80655` | 0,569 | 0,491 | 0,491 | 0,461 | 1.551 | 1.089 | 767 |

Fra le meta-analisi che restano fuori, le più vicine col dominante che condivide sono `5-azacytidine` (0,520 con T1, 0,618 con T3) e `Carcinoma, Renal Cell` (0,553). Il Δ`quota_top1` su quei 23 gruppi va da −0,133 a +0,106: la quota può salire, perché la `tau2` cala e il gruppo dei significativi cambia. **T1-pesi** (solo l'errore standard, `tau2` e geni del deliverable) dà anch'esso 41, ma con un insieme diverso: entra `multiple sclerosis` (0,482) e non entra `bipolar disorder` (0,505). Il numero coincide per caso: il taglio va letto sulla catena intera. Sulle 194 attraversano 0,5 anche `IFNA1`, `temozolomide` e `gemcitabine`, fuori dai 113. Le dominate passano da 116 a 113. Il dominante cambia in 16 gruppi con T1, in 27 con T3.

**P5 è indeterminata, e non decide la conclusione.** La mediana nasconde la coda, e la coda è il risultato: su 108 gruppi con geni significativi la variazione va da −95,1% a +13,6%, e **20 gruppi perdono più del 20%** con T1 (28 con T3). Il totale scende da 341.222 a 330.771 con T1 (−3,1%), a 329.094 con T2 (−3,6%), a 324.916 con T3 (−4,8%). Nei 37 scende da 77.632 a 77.127 (−0,65%): tre gruppi perdono più del 10% (`Non-alcoholic Fatty Liver` −26%, `sunitinib` −19%, `nash` −16%).

**Le meta-analisi che crollano sono spiegate.** Due meccanismi, che si sommano:

- lo studio dominante ha molti bracci con lo stesso controllo, e l'errore standard del pool cresce davvero. `multiple sclerosis`: 10 bracci, `SE_pool` ×1,54 sui geni significativi di T0, da 1.082 a 53 geni (0 con T3). `Arthritis, Rheumatoid`: 5 bracci, ×1,61, da 2.833 a 932 geni;
- la soglia del FDR: in 8 dei 20 gruppi, a FDR 0,10 con T1 restano tanti geni quanti erano a FDR 0,05 con T0.

Nei 20 gruppi `SE_pool` cresce di ×1,114 in mediana, negli altri 88 di ×1,006. Spearman fra i `logFC` poolati di T0 e T1 nei 20: mediana 0,998, minimo 0,961. Dieci dei 20 stanno nei 113. Uno sta nei 37 con T0: `Non-alcoholic Fatty Liver`. `multiple sclerosis` e `Arthritis, Rheumatoid` hanno verdetto «corretta»: il loro numero di geni non è citabile senza questa nota.

**Il rapporto `SE_T1/SE_T0`** per coppia: mediana 1,20, IQR 1,14-1,26, massimo per gene 2,73. Sopra 1,10 in 151 coppie su 171: la frase del codice «lievemente ottimistica» (`R/stage4-orchestrator.R:210`) è sbagliata.

# 5. Tre bracci con i ruoli sbagliati (`20-out.txt`, `25-out.txt`, `57-out.txt`)

**Il cancello 3 ha trovato un difetto di produzione.** `.fetch_counts_cached()` ha una chiave che ordina i campioni (`.cache_key_for_fetch`, `R/stage4-counts-cache.R:23`), quindi rende la matrice con le colonne nell'ordine della **prima** richiesta. `.run_per_study_de_all()` costruisce `treatment` **per posizione** (`R/stage4-orchestrator.R:88-95`). Se una richiesta precedente ha scritto un altro ordine, i ruoli cadono sui campioni sbagliati, e nessuna guardia lo vede.

**Prova.** Il fit con i ruoli per nome riproduce 1.900 bracci su 1.903. Nei 3 restanti i primi `n_t` campioni in cache non sono i trattati, e il fit con i ruoli **per posizione** riproduce il parquet con scarto 0. L'abbinamento fra bracci e campioni è quindi provato in 1.903 bracci su 1.903, e non resta nessuno scarto senza spiegazione.

| studio | meta-analisi | braccio | trattati veri fra i primi | correlazione `logFC` col fit per nome | geni significativi | I² | `quota_top1` | geni con T1 e ruoli giusti |
|---|---|---|---:|---:|---|---|---|---:|
| `GSE222992` | R1881 | 3 contro 3 | 0 su 3 | −1,000 | 7.956 → 8.027 | 94,9 → 94,9 | 0,064 → 0,064 | 8.030 |
| `GSE208347` | Parkinson Disease | 2 contro 5 | 0 su 2 | 0,611 | 838 → 839 | 53,8 → 53,7 | 0,516 → 0,519 | 696 |
| `GSE135485` | endometriosis | 54 contro 4 | 53 su 54 | 0,713 | 62 → 89 | 41,3 → 42,2 | 0,445 → 0,440 | 89 |

Con l'errore standard corretto e i ruoli giusti insieme, Parkinson ha quota 0,483 e endometriosis 0,440: il taglio resta 41. L'unico dei tre bracci in uno studio multi-braccio ha controlli separati (`rho` = 0), quindi T1, T2 e T3 non lo toccano.

**Non è l'inversione di `GSE144269`.** Quel braccio si riproduce per nome: lì l'errore sta nell'etichetta dello Stadio 2[^inversioni]. **Rimando alla ricerca delle inversioni:** `GSE222992` è uno dei 18 studi «sospetti con il metadato che concorda». Il metadato concorda perché l'etichetta è giusta: i ruoli li ha invertiti la cache. I non spiegati scendono a 17. `GSE208347` resta `braccio_sbagliato` per i suoi metadati, e in più ha i ruoli sbagliati.

**Quanto è esposto un run futuro.** Il rischio nasce quando lo stesso insieme di campioni arriva con un'altra divisione in ruoli, cosa che succede quando lo Stadio 2 cambia. Dentro le 194 nessun insieme ha due divisioni (`26-out.txt`): la richiesta precedente viene da fuori (gruppi non poolati o run vecchi). Per `GSE208347` il dispatch del riferimento ha lo stesso insieme con 3 contro 4. Per `GSE222992` il riferimento ha gli stessi ruoli, quindi non so da quale richiesta venga l'ordine. **Un re-run completo con Stadio 2 nuovo può creare altri casi.** Per questo la correzione del codice viene prima di ogni nuovo calcolo.

**La correzione proposta, non applicata.** In `.run_per_study_de_all()`, subito dopo `fetch_fn()`: riordinare le colonne con `counts[, samples, drop = FALSE]` e riattaccare `attr(counts, "gene_symbol")`, con un test che chiede la stessa matrice in due ordini. I rami `mega` e `mega_aug` chiamano `fetch_fn` altrove (`R/stage4-orchestrator.R:436`, `:617`) e sono fuori dal deliverable: vanno guardati nello stesso passo.

**Un errore del mio strumento, corretto.** La regola dei bracci della ricerca delle inversioni («un braccio finisce dove un gene si ripete») sposta righe se il braccio seguente ha gli stessi n e il suo primo gene manca da quello corrente. Il cancello 3 lo ha mostrato su `GSE237177`. Sono **9 righe su 27.504.279**, in 9 bracci di 6 coppie. La stima per studio non dipende dalla divisione in bracci, e 9 righe non cambiano una correlazione di rango su 14.000 geni: quel finding resta valido. La regola nuova usa la posizione sull'asse H5.

# 6. Il controllo positivo (`30-out.txt`, `31-out.txt`, `32-out.txt`)

Dentro un gruppo di controllo vero non c'è un effetto. Divido a caso i campioni e faccio i fit veri.

| dati | proporzione | `rho` formula | mediana empirica | media empirica | MAD² z singolo | T0 | T1 | T3 | T1/T3 |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 40 insiemi veri | 1:1:1 | 0,455 | 0,536 | 0,468 | 1,08 | 1,72 | 1,20 | 1,16 | 1,02 |
| 40 insiemi veri | 1:1:2 | 0,286 | 0,348 | 0,305 | 1,12 | 1,48 | 1,18 | 1,16 | 0,99 |
| gli stessi, permutati gene per gene | 1:1:1 | 0,455 | 0,451 | 0,454 | 1,08 | 1,58 | 1,09 | 1,06 | 1,02 |
| gli stessi, permutati gene per gene | 1:1:2 | 0,286 | 0,287 | 0,287 | 1,06 | 1,35 | 1,06 | 1,06 | 1,00 |

**La causa del fallimento sono due margini sbagliati, non la formula.** Permutando i conteggi gene per gene (distribuzioni vere, nessuna correlazione fra geni) la formula di `rho` torna con scarto ≤ 0,003. Con i campioni veri, la spiegazione coerente con questi numeri è un fattore nascosto che spinge la correlazione fra geni verso ±1 dentro una divisione: la sua mediana fra insiemi allora non stima `rho`. La media infatti sta a +0,012 e +0,020. E anche uno z valido, la fusione, ha MAD² 1,16: il riferimento giusto per T1 era T3, non 1. La correzione T1 porta l'inflazione di T0 al livello di un confronto singolo valido, entro il 3%. Questa spiegazione è arrivata dopo i dati: per questo il cancello 4-bis l'ha provata su dati nuovi, con criteri scritti prima.

# 7. Che cosa non vede questa misura

- `rho` viene dalla sovrapposizione dei campioni. Non vede la correlazione fra bracci con campioni diversi dello stesso laboratorio: il batch resta non modellato, e tocca anche i 626 bracci a controlli separati.
- Il collasso a effetti fissi ignora le differenze vere fra bracci (dose, tempo). T1 non le corregge. T3 le mette nel residuo, ed è il motivo per cui `SE_T3` supera `SE_T1` del 4,7%.
- T1 lascia le stime per studio di produzione; le stime poolate cambiano poco, perché cambiano i pesi. T2 è lo stimatore efficiente, ma cambia le stime e può dare pesi negativi: lo tengo come sensibilità.
- Il controllo positivo prova la formula su un nullo, non sui bracci veri.
- M non include il fix dei difetti letti, delle inversioni e delle lettere greche. Il numero 41 vale con il deliverable di oggi.

# 8. Che cosa passa alle sessioni seguenti

Scritto nelle sezioni dell'handout che lo ricevono.

- **La scelta fra le 37 e le 173:** il taglio con il trattamento corretto è 41, e dieci meta-analisi dei 113 perdono più del 20% dei geni. Il criterio «la scelta decade se il confine si sposta» è scattato.
- **L'applicazione delle correzioni:** correzione dell'assegnazione dei ruoli come primo passo; correzione della varianza (T1), scelta dal PI; la frase «lievemente ottimistica» va corretta.
- **Il re-run completo:** stesso prerequisito sui ruoli.
- **I Methods:** il limite del batch fra bracci, che resta anche dopo la correzione della varianza.

# 9. Evidenza e come si rifà

`analysis/audit/2026-11-02-S4-controllo-condiviso/`, in ordine: `10-bracci.R`, `20-rifit-bracci.R` (15 min a 64 processi), `22-fusione.R` (2 min), `25-effetto-dei-ruoli-sbagliati.R`, `26-da-dove-viene-l-ordine.R`, `30-controllo-positivo.R`, `31-perche-il-nullo-non-passa.R`, `32-nullo-fuori-campione.R`, `40-collassi-e-rem.R` (45 min a 64 processi), `50-efficacia-e-setaccio.R`, `55-dettagli.R`, `56-perche-alcuni-crollano.R`, `57-ruoli-giusti-con-T1.R`. I file pesanti stanno in `/mnt/micron/simulomicsr-dati/2026-11-02-S4-controllo-condiviso/`. Il deliverable e la copia verificata non sono stati toccati. La cache delle conte non ha righe nuove: la fusione compone le matrici dei singoli bracci.

# Da dove vengono i numeri del riassunto

| nel riassunto | file | valore letto |
|---|---|---|
| «da 113 a 37» | `50-out.txt`, «T0 37» | 113; 37 |
| «48 gruppi di controllo mai usati» | `32-out.txt` | 48 insiemi |
| «da 37 a 41», «tre trattamenti», «non esce nessuna» | `50-out.txt` | T1 41, T2 41, T3 41; escono 0 |
| «fra il 49% e il 50%» | `50-out.txt` | 0,486; 0,491; 0,497 |
| «meno dell'1% del peso» | `25-out.txt`; finding delle inversioni | 0,1% sui geni significativi; 0,6% |
| «492 bracci su 1.118», «109 meta-analisi su 194» | `10-out.txt` | 492; 1.118; 109 |
| «il 20% più grande» | `50-out.txt`, P2 | 1,199 |
| «2,7 volte» | `55-out.txt` | 2,73 |
| «Gli altri 626» | `10-out.txt` | 1.118 − 492 |
| «20 meta-analisi su 108» | `55-out.txt`, `56-out.txt` | 20; 108 |
| «il 3,1%», «lo 0,7%» | `55-out.txt`, `57-out.txt` | −3,1%; −0,65% |
| «da 1.082 a 53», «da 2.833 a 932», «10 e 5» | `56-out.txt` | 1.082; 53; 2.833; 932; 10; 5 |
| «In 8 delle 20» | `56-out.txt` | 8 su 20 |
| «mediana 0,998» | `56-out.txt` | 0,998 |
| «da 7.956 a 8.027», «da 838 a 839», «da 62 a 89» | `25-out.txt` | valori uguali |
| «un trattato e un controllo» | `20-out.txt` | 53 trattati veri fra i primi 54 |
| «i due trattati sono controlli» | `20-out.txt` | 0 su 2 |
| «non attraversa il limite» | `57-out.txt` | 0,483; 0,440; 0,064 |
| «scende a 0 geni» | `55-out.txt`, `multiple sclerosis` | 0 |

[^previsioni]: `analysis/audit/2026-11-02-S4-controllo-condiviso/00-previsioni.md`.
[^inversioni]: `docs/findings/2026-11-02-inversioni-bracci-194.md`.
