# PASSO 1 — Quali confronti accusati sono davvero dentro il deliverable

**Data:** 2026-08-10 · Branch `review-scientific-consistency-2026-06-10` · master invariato ·
nessun re-cluster, nessun re-pool.
**Handout:** `docs/superpowers/specs/2026-08-10-sensitivity-confronti-spuri-HANDOUT.md` §4.1, §5 passo 1.
**Evidenza:** `analysis/audit/2026-08-10-sensitivity/`.

> Il passo era dichiarato **non negoziabile**: «senza questo il resto non ha senso».
> È chiuso, e il sospetto del revisore era fondato.

---

## 1. La domanda

La rilettura del 5 agosto ha contato **85 confronti difettosi su 843** nei 13 gruppi grandi
(10,1%), e da lì è stato pubblicato un «peso contaminato» per ciascuno. Ma il materiale su
cui quella lettura è stata fatta (`analysis/audit/2026-08-05-rilettura-214/00-materiale.R:78`)
elencava i confronti di uno studio non appena lo **studio** compariva nel `per_study_de`: non
applicava né il filtro `n_min` né la dedup che il dispatch di produzione applica.

Domanda: **quanti di quei confronti sono dentro il deliverable?**

## 2. La definizione di braccio, fissata una volta sola

Era la contraddizione aperta di §4.1 (io contavo 432 bracci, il revisore 533). **Nessuno dei
due numeri veniva da una definizione difendibile.** Quella giusta è operativa:

> Un **braccio** è una entry di `.build_group_rem_dispatch_from_stage3()`: la tupla
> (cluster, studio, campioni trattati, campioni di controllo) che ha superato, in quest'ordine,
> (1) comparison risolta, (2) replicate group trattato e controllo risolti, (3) `n_min = 2` su
> **entrambi** i lati, (4) dedup su `series_id || treated_group` (vince il primo).

È l'oggetto che il pooling consuma. Le due misure sbagliate lo erano per ragioni opposte:
contare le tuple distinte `(cluster, studio, n_t, n_c)` nel `per_study_de` **fonde** i bracci
con gli stessi `n` (il mio 432); ricostruire dallo Stadio 2 con `n_t≥2 & n_c≥2` **salta la
dedup** (il 533 del revisore, che però risulta il numero giusto — la dedup tocca solo 49
record su tutte e 214 le meta-analisi).

### Due casi di accettazione, entrambi superati

| | esito |
|---|---|
| **A.** la replica strumentata riproduce il dispatch di produzione (stessi bracci, stessi insiemi di campioni) | **PASSA** su tutti i 214 cluster |
| **B.** i bracci contati nel dispatch coincidono con quelli leggibili nel `per_study_de` del re-pool v15 | **PASSA** su tutte le **1.338** coppie (cluster, studio) |

Il caso B è quello che conta: nel `per_study_de` non esiste un identificativo di braccio — ogni
braccio contribuisce una riga per gene — quindi il numero di bracci di (cluster, studio) è il
massimo, sui geni, delle righe con quel (cluster, studio, gene). Coincide ovunque.

## 3. Il risultato

**Caso di accettazione del denominatore:** ricostruendo la vista che il lettore aveva (i
confronti dei soli studi presenti nel `per_study_de` del cluster — il filtro di
`00-materiale.R:78`) si ottengono **843 confronti**, cioè esattamente il numero pubblicato.
Numeratore e denominatore sono quindi ricostruiti entrambi, non solo il primo.

| | censito (5 agosto) | **vero (dentro il pooling)** |
|---|---:|---:|
| confronti nei 13 gruppi | 843 | **533** |
| confronti difettosi | 85 | **38** |
| tasso di difetto | 10,08% | **7,13%** |
| coppie (studio, gruppo) accusate | 34 | **25** |

**Il 36,8% dei confronti letti non è nel deliverable**, e con essi **47 confronti difettosi
su 85**.

⚠️ **Due livelli di conteggio, dichiarati per non confonderli.** Il lettore ha elencato 85
confronti difettosi che corrispondono a **78 triple distinte** (studio, etichetta trattato,
etichetta controllo): 7 triple compaiono due volte, ed è quello che il lettore stesso segnalava
come «duplicato». Per **record** (il denominatore 843): 85 confronti accusati → **38 dentro,
47 fuori**. Per **tripla** (una tripla è «dentro» se almeno un suo record lo è): 41 dentro, 44
fuori. **La lista degli studi accusati è identica ai due livelli — 25 coppie (studio, gruppo)
— quindi i pesi della §4 non ne dipendono.**

### Perché escono: una ragione sola

| motivo | confronti accusati (livello record) |
|---|---:|
| **scartati da `n_min`** (un lato con un solo campione) | **47** |
| collassati dalla dedup | 0 |

Verificato in modo avversario: **tutti e 47** hanno un lato a `n = 1`, e **nessuno** dei 2.152
bracci del deliverable ha un lato sotto 2. Non è una zona grigia — è il filtro che limma-voom
impone per avere replica, applicato a monte.

### I due gruppi il cui peso contaminato è un artefatto

**TNF ed enzalutamide non hanno NESSUNA accusa dentro il pooling** (4 e 4 accuse censite, tutte
sotto `n_min`). Le 9 coppie (studio, gruppo) accusate a vuoto — su 34 — contribuiscono comunque
al deliverable, ma **solo con i loro confronti puliti**: GSE151803, GSE236122, GSE186396,
GSE231460, GSE227511, GSE230741, GSE158814, GSE225481, GSE113922.

## 4. Il peso contaminato, ricalcolato

Il numero pubblicato è sbagliato per **due motivi indipendenti**, e lo script li separa
(`20-peso-contaminato.R`, quattro celle: {regola vecchia, regola di pacchetto} × {lista vecchia,
lista corretta}).

- **La regola.** «Mediana di `1/SE²` per studio, normalizzata dentro il gruppo» (finding
  2026-08-05 §2.5) misura i **bracci**: niente collasso inverse-variance per studio, niente τ².
  Il peso del random-effects è `1/(SE_studio² + τ²)`.
- **La lista.** Gli studi accusati venivano dal censimento, non dal pooling.

**Caso di accettazione:** la cella (regola vecchia, lista vecchia) riproduce il numero
pubblicato con scarto massimo **3,9e-12** su tutti e 13 i gruppi. La correzione è quindi
attribuibile, non un numero diverso ottenuto per altra strada.

| entità | k | studi accusati (censiti → veri) | peso pubblicato | **peso corretto** |
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

**Mediana: 12,0% pubblicato → 8,8% corretto.** Estremi **0,0%–15,9%**, non 0,7%–33,7%.

⚠️ **La correzione non va in una direzione sola.** Cinque gruppi salgono (cisplatino 4,7→12,0;
R1881 4,4→8,8; ipossia 1,3→5,0; TGF-β1 6,7→9,1; SARS-CoV-2 0,7→2,1), perché la regola vecchia
**sottostimava** il peso ignorando il collasso dei bracci e τ². Il titolo «i difetti pesano meno
di quanto detto» sarebbe falso: pesano **diversamente**, e il gruppo peggiore non è più IL1B
(33,7%) ma LPS (15,9%).

## 5. Conseguenze per il resto del programma

1. **La potenza è quella che il revisore aveva calcolato**, ora misurata sulla lista corretta:
   **8 gruppi su 13** hanno ≥2 studi accusati dentro il pooling (un Wilcoxon esatto può scendere
   sotto 0,05); **3 ne hanno uno solo** (SARS-CoV-2, JQ1, IFN-γ → p minimo 0,06–0,10);
   **2 non ne hanno nessuno** (TNF, enzalutamide → niente da togliere). Va dichiarato prima.
2. **La leave-one-out riguarda 25 coppie (studio, gruppo) su 11 gruppi**, non 34 su 13.
3. **Una frase pubblicata va corretta** ovunque compaia: «IL1B 33,7%» e «SARS-CoV-2 0,7%» come
   estremi della contaminazione, e il «6,7%» di TGF-β1 usato per dire che la pesatura declassa
   da sola gli studi rumorosi (che era già stato ritrattato in §0.3 dell'handout: il rapporto
   peso-accusati/equipeso è 1,07).

## 6. Codice nuovo

- `.compute_study_gene_weights()` — nucleo estratto: collasso dei bracci per studio, `+τ²`,
  normalizzazione dentro il gene. Era già dentro `compute_pooling_effectiveness()` (che lo usa
  per trovare lo studio dominante) ma non era richiamabile: da lì la regola scritta a mano.
- `compute_pooling_weight_shares()` — quota di peso di un insieme di studi marcati, per cluster.
  Uno studio marcato che non porta peso dà **0, non NA** (è il caso di TNF ed enzalutamide).
- `R/stage4-pooling-effectiveness.R` rifattorizzato per usare il nucleo estratto: **i 38 test
  preesistenti passano invariati**, suite del file a **57 PASS / 0 FAIL**.
- `pool_cluster_leaving_out()` e `compute_pooling_influence()` (`R/stage4-loo-influence.R`,
  **28 test**): lo strumento del passo 3. Suite `stage4` intera: **1038 PASS / 0 FAIL / 1 SKIP**.

### Il caso di accettazione dello strumento, sui dati veri

`pool_cluster_leaving_out(psd, nessuna esclusione)` deve riprodurre
`cluster_pooled.parquet`. Verificato su tre cluster scelti per rompere la catena in modi
diversi — **scarto 0 su tutte e otto le quantità** (`logFC_pool`, `SE_pool`, `p_value_pool`,
`tau2`, `I2`, `Q`, `k_effective`, `FDR_BH_within_cluster`), zero NA in posizioni diverse:

| cluster | k | coppie studio-gene a più bracci | geni | scarto |
|---|---:|---:|---:|---:|
| `cgroup_L5_00fd9348` | 3 | 0 (collasso = operazione vuota) | 14.279 | **0** |
| palbociclib | 15 | 29.285 | 18.225 | **0** |
| **TGF-β1** | **59** | **532.109** | 19.687 | **0** |

L'handout ne aveva verificati due; il terzo è la figura 2 del paper, ed è il caso in cui il
collasso dei bracci lavora di più. **Non serve nessun re-pool.**

### Il costo, misurato — e il preventivo dell'handout era su un'altra macchina

Costo di **un** pooling: 81 s (k=3) · 182 s (k=15) · **785 s (k=59)**, cioè ≈ 6,7e-4 s per
(gene × studio). Sui soli geni significativi il risparmio è **~2×**, non «un ordine di
grandezza» come l'handout ipotizzava (i significativi sono il 40% dei geni, non il 4%).

Ma il preventivo dell'handout (§3: 34 h letterali, 12 h ottimizzate) contava **solo** le
rimozioni degli accusati, non la leave-one-out sugli studi puliti — che è il riferimento con
cui gli accusati vanno confrontati — né il nullo appaiato. Contandoli, e sfruttando che i
pooling sono indipendenti fra loro (**la macchina ha 128 core**):

| scenario | pooling | 1 core | **32 worker** |
|---|---:|---:|---:|
| A. solo accusati (LOO + blocco) | 33 | 7,6 h | **14 min** |
| B. A + leave-one-out su **ogni** studio | 301 | 71 h | **2,2 h** |
| C. B + 20 estrazioni del nullo appaiato | 521 | 110 h | **3,4 h** |
| D. C con 50 estrazioni | 851 | 169 h | **5,3 h** |

**La domanda di budget dell'handout si scioglie**: lo scenario più completo, su *tutti* i geni,
costa ~5 h. E la versione economica «solo geni significativi» **non va scelta per risparmiare**,
perché costa una misura: la correzione BH si calcola sul denominatore dei geni poolati, quindi
sull'insieme dei soli significativi il conteggio «quanti geni significativi si perdono» non
misurerebbe l'influenza ma il denominatore.

## 7. `n_min` filtra anche la qualità dell'appaiamento — misurato

Il filtro `n_min = 2` esiste per una ragione puramente statistica: limma-voom richiede replica.
Ma il tasso di confronti accusati **non è lo stesso** ai due lati del filtro:

| | confronti | accusati | tasso |
|---|---:|---:|---:|
| **dentro** il pooling (n ≥ 2 su entrambi i lati) | 533 | 38 | **7,1%** |
| **fuori** (scartati da `n_min`) | 310 | 47 | **15,2%** |

**Rapporto 2,13×**, Fisher esatto **p = 0,00032**, OR 0,43 (IC95% 0,27–0,69).

E la lettura dei 9 casi (`15-difetto-trasferito.txt`) mostra il meccanismo: **in 9 casi su 9 il
confronto sopravvissuto è la versione correttamente appaiata dello stesso esperimento.**

| studio | accusato (fuori) | rimasto dentro |
|---|---|---|
| GSE225481 | `LAPC4_ENZA` vs `VCaP_DMSO` (linea diversa) | `R1AD1_ENZA` vs `R1AD1_DMSO` |
| GSE113922 | donatore 226 palbociclib vs «vehicle control» | donatore 1013 vs **donatore 1013** vehicle |
| GSE227511 | MDaPCa2a DHT+**rivestimento ACP** vs plastica | LNCaP DHT+ACP vs **controllo ACP** |
| GSE158814 | *C. trachomatis* + IFN-γ vs untreated | **IFN-γ isolato** vs untreated |
| GSE236122 | TNF **dito** vs non stimolato **ginocchio** | TNF dito vs non stimolato **dito** |

⚠️ **È un'associazione, non un meccanismo dimostrato.** La spiegazione plausibile è una causa
comune: negli studi con molte condizioni a replica singola lo Stadio 2 deve appaiare gruppi
mal corrispondenti, mentre l'esperimento centrale ben replicato è appaiato bene. Non è stato
verificato che sia questa.

⚠️ **La lettura ha trovato un candidato che il censimento non aveva accusato**: in GSE186396
(TNF) un confronto *dentro* il pooling è `Primary Melanoma BLM cells … TNF 6h` contro
`Melanoma BLM cells, Untreated` — «Primary» su un braccio solo. Non è un difetto trasferito:
è un difetto **nuovo**, e ricorda che la lista degli accusati non è esaustiva.

## 8. Limiti di questo passo

- **La lista degli accusati resta quella del 5 agosto**, con i limiti già dichiarati (un solo
  giudice, contestatore spinto alla severità dal prompt, zero assoluzioni su 24 verdetti
  cambiati). Questo passo ne corregge la **proiezione sul deliverable**, non il merito.
- **Un difetto può sopravvivere cambiando etichetta.** Se un confronto accusato cade per `n_min`
  ma un altro confronto dello stesso studio, con etichette diverse e non accusato, porta lo
  stesso difetto, qui risulta «fuori». Non è misurabile senza una nuova lettura: le 9 coppie
  a zero difetti andrebbero rilette **sui soli confronti poolati** prima di dichiararle pulite.
- **Solo 13 gruppi su 214** hanno i difetti contati; per gli altri 201 non esiste una lista.
