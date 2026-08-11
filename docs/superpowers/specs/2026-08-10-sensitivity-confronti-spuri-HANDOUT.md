# HANDOUT — Misurare l'INFLUENZA dei confronti spuri, invece di giudicarli

**Scritto:** 2026-08-10 · **Riscritto lo stesso giorno dopo una revisione ostile**
**Branch:** `review-scientific-consistency-2026-06-10` · master invariato · nessun push
**nessun re-cluster e nessun re-pool eseguiti**

> Autosufficiente. Va letto per intero prima di toccare qualsiasi cosa.
> Idea dell'utente, 2026-08-10.
>
> ⚠️ **Questa è la seconda stesura.** La prima è stata demolita da un revisore
> ostile su nove punti; le accuse decisive sono state **rimisurate da me e
> confermate**. §0 elenca che cosa è cambiato: leggerlo per primo, perché la
> prima stesura, eseguita alla lettera, avrebbe prodotto un risultato sbagliato.

---

## 0. Che cosa è cambiato rispetto alla prima stesura

| # | difetto della prima stesura | rimisurato | conseguenza |
|---|---|---|---|
| 1 | Dava per scontato che gli **843 confronti censiti** fossero quelli poolati | nel `per_study_de` dei 13 gruppi ci sono **432 bracci**, cioè il **51,2%** dei censiti; zero bracci violano `n_min` (il filtro agisce a monte) | **circa metà delle rimozioni inseguirebbe difetti che nel deliverable non esistono.** È il passo 1 del programma nuovo |
| 2 | Usava il **6,7% di peso contaminato** di TGF-β1 come giustificazione | quel numero viene da una regola scritta a mano (mediana di 1/SE² sui **bracci**, senza collasso e senza τ²); col peso vero del pooling è **9,0%** | la giustificazione va riscritta col codice di pacchetto `compute_pooling_effectiveness` |
| 3 | Affermava che «la pesatura per varianza inversa declassa da sola gli studi rumorosi» | rapporto peso-accusati/equipeso: **1,07** (mediana sui 13), e in 8/13 gruppi gli accusati pesano **≥** della loro quota | **frase falsa, rimossa** |
| 4 | Citava «1.408 geni su 1.441 di segno opposto» | verificato: quel conteggio nasce da un `merge` su `gene_symbol`; sull'asse del pooling (`gene_id`) è **1.266 su 1.299** | numero corretto qui e in 6 documenti + nello script sorgente |
| 5 | Proponeva un controllo negativo appaiato solo su «non accusato» | i 5 studi accusati di TGF-β1 portano **16 bracci su 97**, contro una mediana di **7** per 5 studi puliti | **va appaiato sulla quantità di dati rimossi**, non sul peso (che invece non differisce: p = 0,48) |
| 6 | Stimava **8–17 ore** per i 13 gruppi | il collasso dei bracci è metà del costo e nel cluster misurato era un'operazione vuota; costo vero **~34 h** con la ricetta letterale, **~12 h** collassando una volta per cluster | il preventivo va deciso esplicitamente |
| 7 | Non diceva che il disegno **non può falsificare sé stesso** | gli studi accusati **non sono più discordanti dei puliti**: Wilcoxon p = 0,17 su 344 studi, p ≈ 0,16 sui 58 misurati con la LOO vera | **il limite che decide tutto**, ora è §6.1 |

**Una cosa la prima stesura l'ha guadagnata:** il caso di accettazione regge, e regge
anche sui cluster con studi a **più bracci** (§3).

---

## 1. L'idea, in una riga

Il prezzo dell'aggregazione è che qualche confronto è spurio. **Invece di giudicare
se un gruppo è "coerente", si misura quanto quei confronti spostano il risultato**,
si sceglie una soglia sullo spostamento, e si dichiara.

Sostituisce un **verdetto** (che dipende da chi legge) con una **misura**.

## 2. Perché conviene farlo

### (a) Il verdetto non è riproducibile: dipende dal giudice, non dal dato

Sugli **stessi 213 gruppi**, con lo stesso materiale: **Mistral 24 incoerenti,
lettura umana del 5 agosto 96**. Accordo a 3 livelli **36,2%**; nucleo su cui
entrambi dicono «coerente» **55/213**.
Fonte: `docs/findings/2026-08-09-passo4-che-cosa-decide-il-verdetto.md`.

### (b) Il criterio severo distrugge esattamente ciò che serve al paper

La severità del lettore umano cresce col numero di studi (tasso di difetto per
studio implicito **0,111**, IC95% 0,091–0,134; misurato contando i difetti
**0,102** sui 12 gruppi con verdetto da entrambi i giudici).

| studi | gruppi | la lettura umana li dichiara incoerenti |
|---|---:|---:|
| 3 | 80 | 38% |
| 7–10 | 35 | 54% |
| **≥ 15** | **12** | **100%** |

⚠️ **Caveat che la prima stesura ometteva:** quella riga «100%» **non è una prova
indipendente** — i 12 gruppi con k ≥ 15 sono *tutti* i gruppi con k ≥ 15 (n = 0
altrove), quindi il 100% è la stessa cosa dell'effetto di k, non una conferma in
più. Resta il fatto operativo: **con la regola «almeno un confronto difettoso»
nessuna meta-analisi con k ≥ 15 sopravvive.**

### (c) Il rilevatore deterministico che abbiamo NON può sostituire il giudice

Misurato su tutti e **4.549** i confronti delle 213
(`analysis/audit/2026-08-09-passo4/60-rilevatore-deterministico.R`, copertura
record_id 4.549/4.549):

| | |
|---|---:|
| confronti segnalati da `.rp_row_defect` | **166/4.549 = 3,65%** |
| confronti trovati dalla lettura umana (13 gruppi) | 85/843 = **10,08%** |
| regole che si sono accese | **una sola**: `soggetto_diverso` |
| accordo col verdetto umano | **57,3%**, contro **54,9%** di chi dicesse sempre «no» |

**+2,4 punti sopra il non far nulla.** La strada «codifichiamo la regola» è chiusa.

### (d) Indizi che l'influenza sia piccola — con i numeri CORRETTI

- **TGF-β1**: 29 confronti difettosi su 145 (20% per conteggio) ma **9,0% del peso**
  del pooling (⚠️ non 6,7%: vedi §0.2). **Non c'è nessun declassamento automatico**
  (§0.3): il 9,0% va confrontato con l'8,47% che quei 5 studi varrebbero a peso
  uguale — cioè pesano *un po' di più*, non di meno.
- **Peso contaminato, mediana sui 13 gruppi grandi: 11,5%** (col peso vero; era
  12,0% con la regola vecchia — questa riga sopravvive alla rimisura). Estremi
  **4,2%–20,0%**, non 0,7%–33,7%.
- **Esperimento naturale**: DHT ed enzalutamide, gruppi costruiti separatamente,
  danno **1.266 geni su 1.299 di segno opposto (97,5%), Spearman −0,939**.

⚠️ **Nessuno di questi tre numeri è una prova che l'influenza sia piccola.** Sono
indizi che la rendono *plausibile*, ed è il motivo per cui vale la pena misurarla.
Vedi §6.1 per il motivo per cui un esito «piccolo» non proverebbe granché.

## 3. Fattibilità — il caso di accettazione, superato due volte

**Non serve nessun re-pool.** La catena di produzione è due chiamate:

```r
sub  <- simulomicsr:::.collapse_arms_by_study(per_study_de_del_cluster)
pool <- simulomicsr:::.pool_rem_cluster(sub, method_label = "rem_group")
```

### ✅ CASO DI ACCETTAZIONE n.1 — SUPERATO

Ricalcolando così il pooling e confrontandolo con `cluster_pooled.parquet`:

| cluster | k | bracci multipli? | geni | scarto massimo |
|---|---:|---|---:|---:|
| `cgroup_L5_00fd9348` | 3 | no (collasso = no-op) | 14.279 | **0,000e+00** |
| palbociclib | 15 | **sì** (29.285 coppie studio-gene con >1 braccio) | 18.225 | **0,000e+00** |

Su **tutte e otto** le quantità (`logFC_pool`, `SE_pool`, `p_value_pool`, `tau2`,
`I2`, `Q`, `k_effective`, `FDR_BH_within_cluster`), zero NA da entrambe le parti.
**La sensitivity analysis misura esattamente l'oggetto del deliverable.**

### Costo — corretto

| cluster | k | lettura | **collasso** | pooling | totale |
|---|---:|---:|---:|---:|---:|
| `cgroup_L5_00fd9348` | 3 | 0,1 s | **0,0 s** | 80,0 s | 80,2 s |
| palbociclib | 15 | 1,1 s | **80,2 s** | 106,2 s | **187,5 s** |
| IFN-γ | 20 | 1,1 s | **111,2 s** | 118,6 s | **230,9 s** |

⚠️ **Gli 81 s della prima stesura erano misurati sull'unico cluster in cui il
collasso è un'operazione vuota.** Sui cluster veri il collasso è **metà del costo**.

- Ricetta letterale (collasso dentro il ciclo LOO): **~34 h** per i 13 gruppi, di
  cui 9,4 solo per TGF-β1. **Più delle 31 h di un re-pool.**
- Collasso fatto **una volta per cluster** (ottimizzazione lecita): **~12 h**.
- Restringendo ai geni significativi: un ordine di grandezza in meno.

**Decidere quale, esplicitamente, prima di lanciare.**

## 4. Il disegno

### 4.1 PASSO ZERO, non negoziabile: riderivare la lista degli accusati

Gli 843 confronti censiti **non sono** i confronti poolati: nel `per_study_de` dei
13 gruppi ci sono **432 bracci (51,2%)**. Il filtro `n_min = 2`
(`R/stage4-dispatch.R:374`) scarta a monte i confronti con meno di 2 campioni per
braccio. Conseguenze misurate dal revisore, da riverificare come primo passo:

- circa **metà dei confronti difettosi sta fuori dal pooling**;
- **9 delle 34 coppie (studio, gruppo) accusate hanno zero difetti dentro il pooling**;
- **due gruppi interi — enzalutamide e TNF — ne hanno zero**, e il loro «peso
  contaminato» pubblicato (12,1% e 13,8%) è in realtà **0,0%**;
- il tasso di difetto sui confronti che il deliverable contiene davvero è
  **~7%**, non 10,1%.

⚠️ Il revisore conta 533 bracci, io 432: la differenza è nella definizione di
«braccio» (lui ricostruisce da Stadio 2 con `n_t≥2 & n_c≥2`, io conto le tuple
distinte `(cluster, studio, n_treated, n_control)` nel `per_study_de`, che fonde
bracci con gli stessi n). **Il primo compito della sessione è stabilire quale sia
la definizione giusta e contare una volta sola.**

### 4.2 L'unità da togliere: lo STUDIO — e ora è misurato, non argomentato

Il pooling collassa i bracci per studio, quindi togliere un confronto senza rifare
il collasso misurerebbe un oggetto che il deliverable non contiene.

E il timore che togliere l'intero studio **sovrastimi** l'influenza è **falso sul
denominatore giusto**: sui confronti *poolati*, i 25 studi con un difetto reale
portano **49 confronti di cui 38 difettosi (78%)**, con frazione mediana **1,00** e
**17 studi su 25 interamente difettosi**. Togliere lo studio sacrifica 11 confronti
puliti per eliminarne 38.

### 4.3 Le tre statistiche dell'influenza — riportarle tutte

| misura | che cosa cattura |
|---|---|
| **Spearman del ranking dei geni** pieno vs ridotto | se cambia *quali* geni si mostrano |
| **geni significativi guadagnati/persi** (FDR<0,05) | se cambia la *quantità* di risultato |
| **massimo \|Δ logFC\| fra i primi N** | se cambia la *grandezza* di un effetto dichiarato |

⚠️ Un solo numero non basta: sullo stesso gruppo si osservano Spearman ≈ 0,99 *e*
scarti di 2–3 unità di logFC sui primi 30 geni.
⚠️ `FDR_BH_within_cluster` si ricalcola su un denominatore diverso a ogni
rimozione, e il **3,5% dei geni ha `k_effective = 2`** e sparisce sotto LOO: le tre
statistiche vanno definite su un **insieme di geni fisso**, dichiarato.

### 4.4 Il controllo negativo — appaiato sui DATI RIMOSSI

Confrontare gli accusati con i non accusati **non basta**. Misura del revisore su
TGF-β1: i 5 accusati portano **16 bracci su 97**, contro una mediana di **7** per 5
studi puliti estratti a caso (95° percentile 11). Il blocco accusato toglie **il
doppio dei dati**, e Spearman(quota di peso, max|Δ| top-30) = **0,57**.

**Il nullo va costruito estraendo insiemi di studi puliti appaiati per numero di
bracci e di campioni rimossi**, non a caso.
⚠️ Il peso, invece, **non** è un confondente: quota mediana accusati 0,0373 contro
puliti 0,0367, Wilcoxon p = 0,478.

## 5. Programma della sessione

| passo | contenuto |
|---|---|
| **1** | **Riderivare la lista degli accusati sui confronti POOLATI** (§4.1), stabilendo una sola definizione di «braccio». Senza questo il resto non ha senso |
| 2 | Depositare le previsioni **dopo** aver visto §6.1, dichiarando che cosa un esito nullo licenzia e che cosa no |
| 3 | Strumento LOO per studio, codice di pacchetto con TDD. Caso di accettazione: riprodurre il pooling pieno con scarto 0 (già dimostrato fattibile, §3) |
| 4 | **Nullo appaiato** (§4.4) su tutti i gruppi con almeno uno studio accusato *dentro* il pooling |
| 5 | LOO sugli accusati + rimozione in blocco (caso peggiore), le tre statistiche di §4.3 |
| 6 | Curva a gradini e soglia — **decisione dell'utente** |

⚠️ **Potenza:** contando solo gli studi con un difetto dentro il pooling, **8 gruppi
su 13** hanno abbastanza studi perché un Wilcoxon esatto possa scendere sotto 0,05.
Due (enzalutamide, TNF) non hanno **nessuno** studio da togliere; tre (JQ1, IFN-γ,
SARS-CoV-2) ne hanno **uno solo** (p minimo 0,06–0,10). **Va dichiarato prima, non
scoperto dopo.**

## 6. I limiti — in ordine di gravità

### 6.1 ⚠️ Il disegno è cieco proprio ai difetti che deve misurare

Una leave-one-out trova gli studi **discordanti**. I difetti censiti (secondo
agente, materiale diverso, passaggio, linea, sede, donatore) producono in larga
parte uno studio che misura *comunque* il contrasto voluto, con un bias
plausibilmente **concorde**.

Misurato: concordanza di ogni studio col poolato sui geni significativi, 344 studi
dei 13 gruppi — accusati ρ mediano **0,652**, puliti **0,683**, **Wilcoxon
p = 0,168**. Sui 58 studi misurati con la LOO vera le distribuzioni **si
sovrappongono completamente** (p = 0,159 e 0,172 sulle due statistiche).

**Conseguenza: «l'influenza è piccola» è il risultato che il disegno produce
comunque, e non distingue «non ci sono difetti» da «i difetti sono concordi».**
Va scritto nel file delle previsioni, prima di misurare.

### 6.2 La lista degli accusati è un limite superiore, e viene da un giudice solo

Viene dalla lettura del 5 agosto, uno dei due giudici in disaccordo, il cui
contestatore **era spinto alla severità dal prompt** (24 verdetti cambiati, tutti
verso il peggio, zero assoluzioni — limite documentato e mai corretto).

### 6.3 Solo 13 gruppi su 214 hanno i difetti contati

Per gli altri 201 non esiste una lista di accusati: la sensitivity analysis potrà
essere solo cieca (LOO su tutti gli studi), che risponde a una domanda diversa.

### 6.4 ~~Il pre-filtro H5~~ — CHIUSO (§3), verificato anche sui cluster a bracci multipli

### 6.5 Denominatori che circolano in due versioni, da dichiarare sempre

- studi accusati: **34** su tutti e 13 i gruppi, **29** sui 12 con verdetto da
  entrambi i giudici (il 13° è TGF-β1, escluso: Mistral ha fallito lo schema su
  tutti e 5 i giri);
- gruppi con k ≥ 15: **12** nella base a due giudici, **13** nel deliverable.

## 7. Materiale

- Stime per-studio e pooling: `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7/`
- Difetti contati: `analysis/audit/2026-08-05-rilettura-214/13-grandi-conteggio.json`
- Verdetti e motivi: `analysis/audit/2026-08-05-rilettura-214/verdetti-rilettura-214.csv`
- Peso del pooling, **codice di pacchetto con 38 test**: `compute_pooling_effectiveness()` in `R/stage4-pooling-effectiveness.R` — **usare questo**, non le regole a mano negli script di audit
- Matrice dei giudici e predittori: `analysis/audit/2026-08-09-passo4/`
- Finding del PASSO 4: `docs/findings/2026-08-09-passo4-che-cosa-decide-il-verdetto.md`

## 8. Vincoli operativi

- `Rscript` **senza** `--vanilla`. Run lunghi con `setsid`.
- ⚠️ **Mai fare `merge` su `gene_symbol`**: ARCHS4 v2.5 ha 4.638 simboli duplicati e
  il merge diventa un prodotto cartesiano. È costato «1.441 invece di 1.299» in sei
  documenti, ed è il **terzo** episodio della stessa famiglia. L'asse è `gene_id`.
- ⚠️ **Il poller non deve contarsi da solo**: `pgrep -f <nome script>` aggancia anche
  il ciclo che aspetta. Filtrare sul processo R (`ps -ef | grep "[e]xec/R"`).
- ⚠️ **`.rp_row_defect` senza cache non finisce**: 4.549 confronti fermati a 7h25m
  con `cache = NULL`, minuti con un environment di memoizzazione.
- Nessun re-cluster e nessun re-pool senza decisione esplicita dell'utente.
- Ogni conclusione va sottoposta a critici avversari che la falsifichino **con i
  dati**. Su questo handout ne è bastato uno per trovare nove difetti, sette veri.
