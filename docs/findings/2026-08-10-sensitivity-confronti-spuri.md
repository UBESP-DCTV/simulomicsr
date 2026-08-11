# I confronti spuri, misurati invece che giudicati

**Data:** 2026-08-10 · Branch `review-scientific-consistency-2026-06-10` · master invariato ·
**nessun re-cluster, nessun re-pool, nessun gruppo escluso.**
**Decisione dell'utente (2026-08-10):** opzione A — nessuna esclusione; l'influenza dei confronti
difettosi diventa un risultato misurato dell'articolo.
**Evidenza:** `analysis/audit/2026-08-10-sensitivity/` · **Previsioni depositate prima di
misurare:** `00-previsioni.md` · **Passo preparatorio:**
`docs/findings/2026-08-10-passo1-accusati-dentro-il-pooling.md`.

---

## 1. Perché una misura al posto di un verdetto

Aggregare studi diversi ha un prezzo: qualche confronto misura qualcosa di leggermente diverso da
quello che il gruppo dichiara. Per mesi il progetto ha provato a decidere **se** un gruppo fosse
«coerente». Quel verdetto si è rivelato non riproducibile: sugli **stessi 213 gruppi**, con lo
stesso materiale, un giudice automatico ne dichiara incoerenti **24** e la lettura umana **96**,
con accordo a tre livelli del **36,2%** (`2026-08-09-passo4-che-cosa-decide-il-verdetto.md`).

Peggio: il criterio severo distrugge esattamente ciò che serve. La severità del lettore cresce col
numero di studi, e con la regola «almeno un confronto difettoso rende il gruppo inutilizzabile»
**nessuna meta-analisi con k ≥ 15 sopravvive** (12 su 12). E il rilevatore deterministico non può
sostituire il giudice: segnala il 3,65% dei confronti contro il 10% trovato leggendo, con una sola
regola che si accende, e sta **2,4 punti** sopra chi rispondesse sempre «no».

La domanda si sposta quindi da **«questo gruppo è coerente?»** a **«quanto quei confronti spostano
il risultato?»**. La prima dipende da chi legge; la seconda si misura.

## 2. Metodo

### 2.1 Che cos'è un braccio (e perché la definizione andava fissata)

Il pooling non consuma «confronti»: consuma **bracci**. Un braccio è una entry del dispatch di
produzione — la tupla (cluster, studio, campioni trattati, campioni di controllo) che ha superato,
in quest'ordine: comparison risolta, replicate group risolti, **`n_min = 2` su entrambi i lati**,
dedup su `series_id || treated_group`.

Fissarla ha cambiato i numeri pubblicati, perché il materiale su cui la rilettura era stata fatta
elencava i confronti di uno studio non appena lo **studio** compariva nel poolato, senza applicare
né `n_min` né la dedup.

| | censito | **nel deliverable** |
|---|---:|---:|
| confronti nei 13 gruppi grandi | 843 | **533** |
| confronti giudicati difettosi | 85 | **38** |
| tasso di difetto | 10,08% | **7,13%** |
| coppie (studio, gruppo) accusate | 34 | **25** |

**Tre casi di accettazione**, tutti superati: la replica strumentata riproduce il dispatch di
produzione su tutti i 214 cluster; i bracci coincidono con quelli leggibili nel `per_study_de` su
tutte le **1.338** coppie (cluster, studio); e la ricostruzione della vista che il lettore aveva
restituisce **843** confronti, cioè esattamente il denominatore pubblicato.

I 47 confronti accusati che escono hanno **tutti** un lato con un solo campione, e **nessuno** dei
2.152 bracci del deliverable ha un lato sotto 2.

### 2.2 Lo strumento

Il ri-pooling è la stessa catena della produzione — collasso dei bracci per studio con l'inverso
della varianza, poi random-effects — esposta in due funzioni di pacchetto
(`pool_cluster_leaving_out()`, `compute_pooling_influence()`, 28 test).

**Caso di accettazione sui dati veri:** ricalcolando il pooling pieno si deve riottenere
`cluster_pooled.parquet`. Verificato su tre cluster scelti per stressare punti diversi della catena
— **scarto 0 su tutte e otto le quantità** (`logFC_pool`, `SE_pool`, `p_value_pool`, `tau2`, `I2`,
`Q`, `k_effective`, `FDR_BH_within_cluster`), zero NA in posizioni diverse:

| cluster | k | coppie studio-gene a più bracci | geni | scarto |
|---|---:|---:|---:|---:|
| `cgroup_L5_00fd9348` | 3 | 0 (collasso = operazione vuota) | 14.279 | **0** |
| palbociclib | 15 | 29.285 | 18.225 | **0** |
| TGF-β1 | 59 | 532.109 | 19.687 | **0** |

**Non serve nessun re-pool** per una sensitivity analysis: la catena è due chiamate.

### 2.3 Le tre statistiche, e l'insieme di geni fisso

Un solo numero non basta, quindi se ne riportano tre: **Spearman del ranking** (cambiano i geni che
si mostrano?), **geni significativi persi** (cambia la quantità di risultato?), **massimo
|Δ logFC| fra i primi 30** (cambia la grandezza di un effetto dichiarato?).

Due vincoli, fissati **prima** di misurare:

- **L'insieme dei geni è fisso**: i significativi (FDR < 0,05) del pooling pieno, dichiarati per
  gruppo (da 835 a 9.678). Il 3,5% dei geni ha `k_effective = 2` e sparisce sotto rimozione;
  misurato, ne spariscono **mediana 5, massimo 107** per rimozione, e sono esclusi dal confronto,
  non ignorati in silenzio.
- **Il ranking usa `p_value_pool`, non l'FDR.** BH è monotona in p, quindi l'ordine è lo stesso, ma
  l'FDR si ricalcola su un denominatore diverso a ogni rimozione e ne farebbe una misura del
  denominatore. Il conteggio dei significativi, che l'FDR lo usa davvero, resta sull'FDR — ed è il
  motivo per cui il pooling è stato rifatto su **tutti** i geni e non sui soli significativi.

### 2.4 I due nulli

Confrontare gli accusati con i puliti non basta: gli accusati **tolgono più dati** (mediana 2
bracci contro 1, Wilcoxon p = 0,036). Senza appaiare non si distingue «lo studio è difettoso» da
«lo studio è grande». Sono stati costruiti due riferimenti:

- **nullo di blocco**: 20 insiemi di studi puliti per gruppo, estratti finché non pareggiano i
  **bracci** rimossi dall'insieme accusato (seme fissato, estrazioni generate prima e in modo
  deterministico, non dentro i worker);
- **nullo per studio**: per ogni studio accusato, i soli studi puliti dello stesso gruppo che
  rimuovono **lo stesso numero di bracci** (minimo 3 riferimenti, altrimenti l'accusato esce dal
  test ed è dichiarato).

**521 pooling, 6,3 h di calcolo** su 32 worker.

## 3. Risultati

### 3.1 Il peso contaminato era sbagliato, in entrambe le direzioni

Il «peso contaminato» pubblicato usava una regola scritta a mano — mediana di `1/SE²` per studio,
normalizzata dentro il gruppo — che pesa i **bracci**: senza collasso inverse-variance per studio e
senza τ². Il peso del random-effects è `1/(SE_studio² + τ²)`. Ricalcolato col codice di pacchetto e
con la lista degli accusati riderivata sul pooling (**caso di accettazione**: la regola vecchia con
la lista vecchia riproduce il numero pubblicato a **3,9e-12**, quindi la correzione è attribuibile):

| entità | k | studi accusati (censiti → veri) | pubblicato | **corretto** |
|---|---:|---:|---:|---:|
| TGF-β1 | 59 | 5 → 5 | 6,7% | **9,1%** |
| LPS | 35 | 5 → 5 | 19,5% | **15,9%** |
| SARS-CoV-2 | 34 | 2 → 1 | 0,7% | **2,1%** |
| **TNF** | 32 | 3 → **0** | 13,8% | **0,0%** |
| ipossia | 25 | 2 → 2 | 1,3% | **5,0%** |
| JQ1 | 25 | 1 → 1 | 3,2% | **4,5%** |
| DHT | 23 | 3 → 2 | 12,0% | **9,1%** |
| R1881 | 22 | 3 → 2 | 4,4% | **8,8%** |
| IFN-γ | 20 | 2 → 1 | 13,0% | **6,0%** |
| **enzalutamide** | 19 | 1 → **0** | 12,1% | **0,0%** |
| IL1B | 18 | 2 → 2 | 33,7% | **13,3%** |
| cisplatino | 17 | 2 → 2 | 4,7% | **12,0%** |
| palbociclib | 15 | 3 → 2 | 16,1% | **15,4%** |

**Mediana 12,0% → 8,8%**, estremi **0,0%–15,9%** (non 0,7%–33,7%).

⚠️ **La correzione non va in una sola direzione**: cinque gruppi salgono, perché la regola vecchia
sottostimava ignorando collasso e τ². Il gruppo peggiore non è più IL1B (33,7%) ma **LPS (15,9%)**.

**TNF ed enzalutamide hanno peso contaminato zero**: tutti i loro confronti accusati stanno sotto
`n_min`. Le 9 coppie (studio, gruppo) accusate a vuoto contribuiscono comunque al deliverable, ma
solo coi loro confronti puliti, e la lettura mostra che **in 9 casi su 9 il confronto sopravvissuto
è la versione correttamente appaiata dello stesso esperimento** (GSE225481: fuori `LAPC4_ENZA` vs
`VCaP_DMSO`, dentro `R1AD1_ENZA` vs `R1AD1_DMSO`; GSE113922: fuori «donatore 226 vs vehicle
control», dentro «donatore 1013 vs **donatore 1013** vehicle»).

Ne segue un fatto misurabile: **`n_min` filtra anche la qualità dell'appaiamento**. Tasso di
confronti accusati **7,1% dentro** contro **15,2% fuori** — rapporto 2,13×, Fisher esatto
**p = 0,00032**, OR 0,43 (IC95% 0,27–0,69). È un'associazione, non un meccanismo dimostrato: la
spiegazione plausibile è una causa comune (negli studi con molte condizioni a replica singola lo
Stadio 2 deve appaiare gruppi mal corrispondenti, mentre l'esperimento centrale ben replicato è
appaiato bene), e non è stata verificata.

### 3.2 Togliere gli studi accusati sposta il risultato — ma quanto?

Rimozione **in blocco** di tutti gli studi accusati, per gruppo:

| entità | k | Spearman | max \|Δ logFC\| | geni sig. | persi | % |
|---|---:|---:|---:|---:|---:|---:|
| TGF-β1 | 59 | 0,902 | 0,203 | 7.909 | 594 | 7,5% |
| SARS-CoV-2 | 34 | 0,886 | 0,003 | 1.933 | 85 | 4,4% |
| LPS | 35 | 0,917 | 0,464 | 6.883 | 1.062 | 15,4% |
| JQ1 | 25 | 0,985 | 0,047 | 9.678 | 252 | 2,6% |
| ipossia | 25 | 0,954 | 0,696 | 4.068 | 425 | 10,5% |
| DHT | 23 | 0,896 | 0,254 | 4.875 | 492 | 10,1% |
| R1881 | 22 | 0,914 | 0,270 | 8.427 | 560 | 6,7% |
| IFN-γ | 20 | 0,924 | 0,241 | 3.579 | 431 | 12,0% |
| cisplatino | 17 | 0,720 | 0,072 | 835 | 172 | 20,6% |
| IL1B | 18 | 0,732 | 0,691 | 1.681 | 266 | 15,8% |
| palbociclib | 15 | 0,716 | 0,145 | 2.833 | 251 | 8,9% |

**Spearman mediana 0,902** (minimo 0,716) · **max |Δ logFC| mediana 0,241** · **geni significativi
persi mediana 10,1%**, massimo 20,6%.

Non è trascurabile — ed è il primo risultato che smentisce una previsione depositata (P1 prevedeva
Spearman ≥ 0,95 in almeno 9 gruppi su 11: sono **2**).

### 3.3 Ma è l'effetto del difetto, o del togliere dati?

È la domanda che decide, e la risposta va data a tre livelli, perché non dicono la stessa cosa.

| livello | confronto | esito |
|---|---|---|
| **blocco**, appaiato sui bracci | 11 gruppi, accusati vs 20 estrazioni pulite ciascuno | percentile mediano **0,45** (0,50 = indistinguibile), Wilcoxon **p = 0,765** |
| **singolo studio**, NON appaiato | 25 accusati vs 268 puliti, stratificato per gruppo | percentile mediano **0,667**, **p = 0,016** |
| **singolo studio**, appaiato sui bracci | 17 accusati con ≥3 riferimenti a pari bracci | percentile mediano **0,786**, **p = 0,109** |

⚠️ **Il test sul blocco è sbilanciato, e va detto**: il suo nullo pareggia i **bracci** ma finisce
per togliere **più studi** dell'insieme accusato — mediana 1,35×, fino a **2,3×** su TGF-β1 (11,5
studi contro 5). Togliere più studi abbassa di più il `k` e perturba di più: quel test è quindi
conservativo **nella direzione sbagliata**, cioè fa apparire gli accusati più innocui di quanto
siano. Il suo `p = 0,765` non va letto come una prova di indistinguibilità.

Il confronto per singolo studio appaiato sui bracci è il più pulito, e dice: **gli studi accusati
stanno in mediana al 79° percentile dei puliti equivalenti** — cioè spostano il risultato più di
tre quarti degli studi puliti che rimuovono altrettanti dati — ma con n = 17 il test **non
raggiunge la significatività** (p = 0,109; sullo Spearman p = 0,062). E **6 su 17 superano il 90°
percentile del proprio riferimento, contro 1,7 attesi per caso.**

**Robustezza alla soglia dei riferimenti** (fissata a 3 nello script *prima* di vedere i risultati).
Il punto di stima è stabile, il p-value **no**:

| minimo di riferimenti a pari bracci | n | percentile mediano | p | oltre il 90° |
|---:|---:|---:|---:|---:|
| 2 | 19 | 0,786 | **0,035** | 8/19 |
| **3** (dichiarato) | 17 | 0,786 | 0,109 | 6/17 |
| 5 | 17 | 0,786 | 0,109 | 6/17 |
| 8 | 16 | 0,768 | 0,144 | 6/16 |

Il p attraversa lo 0,05 al variare di una scelta arbitraria: **scegliere la soglia guardando il p
sarebbe p-hacking**, e per questo si riporta il valore della soglia dichiarata insieme a tutta la
curva.

**Conclusione onesta: i dati sono coerenti con studi accusati un po' più influenti dei puliti
equivalenti, ma non lo stabiliscono.** Il punto di stima è dalla parte dell'accusa (79° percentile
contro il 50 atteso, stabile su ogni soglia), la significatività no.

### 3.4 I sei studi che si distinguono davvero

Superano il 90° percentile dei puliti del proprio gruppo che rimuovono altrettanti bracci:

| gruppo | studio | riferimenti | percentile |
|---|---|---:|---:|
| ipossia | GSE269699 | 14 | 1,00 |
| IL1B | GSE162691 | 13 | 1,00 |
| LPS | GSE97744 | 19 | 1,00 |
| LPS | GSE180693 | 8 | 1,00 |
| LPS | GSE181851 | 8 | 1,00 |
| palbociclib | GSE133567 | 12 | 0,92 |

**Tre dei sei sono in LPS**, il gruppo col peso contaminato più alto (15,9%): è la sola convergenza
fra la misura del peso e la misura dell'influenza. Non sono stati esclusi (decisione A): sono sei
studi, e una lista di sei è la forma di errore che questo progetto ha già pagato più volte.

## 4. Il conto delle previsioni, depositate prima di misurare

| # | previsione | esito |
|---|---|---|
| P1 | Spearman ≥ 0,95 in ≥ 9 gruppi su 11 | **FALSIFICATA** (2/11) |
| P2 | almeno un gruppo con Spearman ≥ 0,99 e max\|Δ\| > 1 | **FALSIFICATA** (0) |
| P3 | correlazione positiva peso contaminato ~ influenza | **centrata** (ρ = 0,33) |
| P4 | il nullo appaiato è indistinguibile dagli accusati | **centrata sul blocco, incerta per studio** |
| P5 | si perdono significativi (segno negativo) in ≥ 9 gruppi | **centrata** (11/11) |

**Due su cinque falsificate, e nella stessa direzione: avevo sottostimato quanto una rimozione
sposta il risultato.** È lo stesso verso dell'errore del passo precedente, dove quattro previsioni
su otto erano cadute perché avevo sottostimato quanto il deliverable ri-risolve le cose da sé.

## 5. Che cosa questo autorizza a dire — e che cosa no

Scritto **prima** di misurare (`00-previsioni.md` §0), e va riportato accanto al risultato.

Una leave-one-out trova gli studi **discordanti**. I difetti censiti (secondo agente, materiale
diverso, passaggio di coltura, linea cellulare, sede anatomica, donatore) producono in larga parte
uno studio che misura *comunque* il contrasto voluto, con un bias plausibilmente **concorde**.
Misurato prima di partire: la concordanza col poolato degli studi accusati (ρ mediano 0,652) non è
distinguibile da quella dei puliti (0,683), Wilcoxon p = 0,168 su 344 studi.

| si può dire | non si può dire |
|---|---|
| togliere gli studi accusati sposta il risultato quanto togliere altri studi comparabili | i confronti accusati non sono difettosi |
| la conclusione non poggia su quegli studi in modo particolare | i difetti non hanno introdotto bias |
| il peso contaminato mediano è 8,8%, e in due gruppi è zero | il gruppo è «coerente» |

**Un bias concorde è invisibile a questo disegno.**

## 6. Limiti

1. **Il disegno è cieco proprio ai difetti che deve misurare** (§5). È il limite principale.
2. **Il nullo di blocco toglie più studi dell'insieme accusato** (mediana 1,35×): quel test
   sottostima l'influenza degli accusati. Il nullo per studio appaiato sui bracci non ha questo
   problema, ma copre **17 accusati su 25** — gli altri 8 non hanno abbastanza studi puliti che
   rimuovano altrettanti bracci, e sono dichiarati invece che fatti entrare rilassando il criterio.
3. **La lista degli accusati è un limite superiore e viene da un giudice solo**, il cui
   contestatore era spinto alla severità dal prompt (24 verdetti cambiati, tutti verso il peggio,
   zero assoluzioni). La lettura dei casi ne ha anche trovato **uno che il censimento non aveva
   accusato** (GSE186396 in TNF: «Primary Melanoma BLM cells» su un braccio solo): la lista non è
   esaustiva.
4. **Un difetto può sopravvivere cambiando etichetta.** Le 9 coppie a zero difetti dentro il
   pooling sono state lette una per una e in 9 casi su 9 il confronto rimasto è quello appaiato
   correttamente — ma è una lettura, non una regola.
5. **Solo 13 gruppi su 214 hanno i difetti contati**, e la sensitivity riguarda gli 11 che hanno
   almeno uno studio accusato dentro il pooling. Per gli altri 201 non esiste una lista di
   accusati.
6. **La potenza è dichiarata, non scoperta dopo**: 8 gruppi su 13 hanno ≥ 2 studi accusati dentro
   il pooling, 3 ne hanno uno solo (SARS-CoV-2, JQ1, IFN-γ), 2 nessuno (TNF, enzalutamide).

## 7. Per i Methods

> **Sensitivity analysis for imperfect comparisons.** Ogni meta-analisi aggrega bracci
> trattato-controllo appaiati dentro lo stesso studio; un braccio entra nel pooling solo se ha
> almeno due campioni per lato. Tredici gruppi (k ≥ 15) sono stati riletti confronto per confronto
> da un lettore indipendente, che ha giudicato difettosi 85 dei 843 confronti censiti; riportando
> quel giudizio sui soli bracci effettivamente poolati restano **38 confronti difettosi su 533
> (7,1%)**, distribuiti su **25 coppie (studio, gruppo)** in 11 gruppi.
>
> Per ciascuno di questi gruppi la meta-analisi è stata rifatta con la stessa catena di produzione
> (collasso dei bracci per studio con l'inverso della varianza, poi random-effects REML)
> rimuovendo (i) ogni singolo studio, uno alla volta, e (ii) l'intero insieme degli studi accusati.
> Il ri-pooling riproduce il risultato pubblicato con scarto numerico nullo su tutte le quantità
> stimate. L'influenza è misurata su un insieme di geni fisso — i significativi (FDR < 0,05) del
> pooling completo — con tre statistiche: correlazione di rango del ranking dei geni, numero di
> geni significativi perduti, e massimo scarto di logFC fra i primi trenta.
>
> Poiché rimuovere dati sposta comunque una meta-analisi, ogni rimozione è stata confrontata con
> rimozioni di studi **non** accusati dello stesso gruppo che eliminano lo **stesso numero di
> bracci**. Rimuovere tutti gli studi accusati fa perdere una mediana del **10,1%** dei geni
> significativi (massimo 20,6%) con correlazione di rango mediana **0,90**; gli studi accusati si
> collocano al **79° percentile** delle rimozioni pulite equivalenti (n = 17, p = 0,11), e sei di
> essi superano il 90° percentile del proprio riferimento contro 1,7 attesi. Gli studi che
> contengono confronti difettosi portano una mediana dell'**8,8%** del peso del pooling (estremi
> 0,0%–15,9%).
>
> Nessun gruppo è stato escluso. Il disegno rileva gli studi **discordanti**: un difetto che
> introduca un bias concorde con gli altri studi non è rilevabile per questa via, e infatti la
> concordanza col risultato poolato non distingue gli studi accusati dagli altri (p = 0,17).

## 8. Materiale

| | |
|---|---|
| lista degli accusati riportata sui bracci | `analysis/audit/2026-08-10-sensitivity/10-accuse-sui-bracci.csv` |
| esito di ogni record delle 214 meta-analisi | `10-record-esito.csv` |
| lettura dei 9 casi a difetto non trasferito | `15-difetto-trasferito.txt` |
| `n_min` e qualità dell'appaiamento | `16-nmin-e-qualita.csv` |
| peso contaminato, 2×2 regola × lista | `20-peso-contaminato.csv` |
| accettazione dello strumento + costo | `30-costo.csv` |
| **influenza, 521 pooling** | `40-influenza-tutti.csv` |
| sintesi per gruppo e curva a gradini | `50-esito.csv` |
| percentili per singolo studio | `60-per-studio-percentili.csv`, `65-appaiato-sui-bracci.csv` |
| codice | `R/stage4-loo-influence.R`, `compute_pooling_weight_shares()` in `R/stage4-pooling-effectiveness.R` |

## 9. Numeri pubblicati da correggere

Il peso contaminato compare in sei documenti con i valori della regola vecchia. Vanno sostituiti
con quelli di §3.1; in particolare **non sono più vere** queste tre affermazioni:

- «la contaminazione va da **0,7% a 33,7%** del peso» → **0,0%–15,9%**;
- «**IL1B 33,7%**» (il caso peggiore citato) → 13,3%, e il peggiore è **LPS 15,9%**;
- «TGF-β1 ha il conteggio peggiore ma il **6,7%** del peso» → **9,1%**, e la frase che ne seguiva
  («la pesatura per varianza inversa declassa da sola gli studi rumorosi») era già stata ritrattata:
  il rapporto fra il peso degli accusati e la loro quota a peso uguale è **1,07**.
