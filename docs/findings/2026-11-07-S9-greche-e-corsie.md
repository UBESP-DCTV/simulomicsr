---
type: Finding
title: "Le lettere greche cambiano 7 meta-analisi su 194, e la sola traduzione danneggia TNF"
description: "La chiave d'entità ricalcolata su tutti gli 86.745 confronti dello Stadio 3, con e senza traduzione delle lettere greche. Cambiano 364 confronti e 7 meta-analisi; cinque cambi tolgono confronti già segnati difettosi, TNF perde 15 studi per un difetto della forma ASCII. Corretto il crash delle corsie su un titolo NA."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-07T16:40:00+01:00'}
sources:
- {id: previsioni, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/00-previsioni.md", title: "Cancelli e previsioni depositati prima del calcolo"}
- {id: traduzione, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/01-traduzione.R", title: "La regola simulata e l'insieme G"}
- {id: ingressi, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/20-ingressi.R", title: "Gli ingressi della chiave per ogni confronto, con l'anchor del run vero"}
- {id: regimi, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/30-due-regimi.R", title: "La chiave senza e con traduzione"}
- {id: positivo, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/30-controllo-positivo.txt", title: "Cancello 4(b)"}
- {id: c4a, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/31-cancello-4a.txt", title: "Cancello 4(a)"}
- {id: s14, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/35-quota-s14.txt", title: "P5: la quota nel master S14"}
- {id: analisi, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/40-out.txt", title: "Cancelli 2-3, P1-P4, gruppi e meta-analisi"}
- {id: meta, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/40-meta-analisi.csv", title: "Le meta-analisi che cambiano o contengono caratteri di G"}
- {id: cambi, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/40-confronti-che-cambiano.csv", title: "Tutti i 364 confronti che cambiano"}
- {id: gruppi, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/40-gruppi-toccati.csv", title: "Le 290 chiavi di gruppo toccate"}
- {id: anomalie, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/45-out.txt", title: "Spiegazioni e anomalie"}
- {id: nomi, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/46-out.txt", title: "Calcitriolo, meta-analisi con più nomi, ID scritti dal modello"}
- {id: modello, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/47-out.txt", title: "Il nome scritto dal modello nei gruppi con più nomi"}
- {id: suite, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/40-suite-stage4.txt", title: "Suite stage4 dopo il fix delle corsie"}
- {id: prove90, resource: "analysis/audit/2026-11-07-S9-greche-e-corsie/50-greche-90-prove.txt", title: "Le 90 prove sulle greche, rilanciate"}
- {id: rilettura, resource: "docs/findings/2026-08-20-rilettura-194-correttezza.md", title: "Rilettura delle 194, §12-§13 sulle greche"}
- {id: deliverable, resource: "/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d", title: "Deliverable A3 v16, 194 meta-analisi, non toccato"}
---

# In breve

## In breve: le lettere greche cambiano i gruppi delle meta-analisi?

**A cosa serviva.** Le etichette dei bracci scrivono spesso i nomi con lettere greche, per esempio TGF-β1 o IFN-γ. Ad agosto abbiamo visto che parte del codice cancella queste lettere, e che IL-1β diventa IL1A. Abbiamo misurato che cosa cambia in tutti i gruppi se il codice legge le lettere greche come lettere latine, per sapere se vale la pena correggere il codice. Abbiamo anche corretto un errore che fermava il collasso delle corsie di sequenziamento.

**Cosa abbiamo trovato.**

1. **La traduzione delle lettere greche cambia 7 delle 194 meta-analisi, non 3 come mi aspettavo.** Cambiano 364 confronti su 86.745, tutti con una lettera greca o con il simbolo di micro. Fra le 40 meta-analisi principali cambia solo quella su TNF. La meta-analisi sul 17β-estradiolo non cambia.
2. **In cinque meta-analisi la traduzione toglie confronti davvero sbagliati.** Sono 7 studi con due agenti nel trattato, per esempio «Hypoxia + TGF-β1» contro il veicolo. Uno di questi è uno studio di IFN-γ con IL-1β dentro la meta-analisi su IL1A. La rilettura di agosto aveva già segnato come difettosi 6 di questi 7 studi.
3. **Con la sola traduzione la meta-analisi su TNF scende da 42 a 27 studi, per un altro difetto.** Il codice risolve «TNF-alpha» scritto in lettere latine a un prodotto di ChEMBL, oppure al TNF del pesce zebra, che poi scarta. Lo stesso difetto lascia già oggi 12 studi fuori dalla meta-analisi su TNF, e dentro c'è un solo studio che scrive «TNF-alpha».
4. **La sola traduzione crea anche due errori nuovi.** Il gruppo sul calcitriolo si divide e scende sotto 3 studi, perché uno studio scrive «1α,25(OH)2D3» e gli altri «1,25(OH)2D3». «Interferon γ» tradotto risolve a un prodotto di ChEMBL, e nasce un gruppo sbagliato con 3 studi.
5. **Una regola scarta il confronto quando il controllo nomina l'entità, anche se il controllo la nega.** Per questa regola «no TGFb» vale come TGFb. Oggi ha scartato 241 confronti di questo tipo in 92 studi, e vanno letti. Con la traduzione la stessa regola toglie altri 4 confronti dalla meta-analisi su TGFB1.

**Cosa devi decidere.**

1. **Correggiamo il codice in una sessione nuova, prima del calcolo che applica le correzioni, e insieme alle lettere greche correggiamo i due difetti che la traduzione mostra? Consiglio di sì.** La sola traduzione toglie 15 studi a TNF, una delle 40 meta-analisi principali.
   - La sessione nuova traduce le lettere greche in un punto solo, prima del calcolo della chiave. Risolve come citochine i nomi delle citochine scritti in lettere latine. Fa leggere la negazione alla regola sul controllo. Misura ogni cambio da solo, con gli script di questa sessione: TNF deve guadagnare studi, non perderli.
   - In alternativa correggiamo solo le lettere greche. TNF perde 15 studi su 42, e la meta-analisi sul calcitriolo esce dalle 194.
   - In alternativa non correggiamo e scriviamo il limite nei Methods. TNF resta senza 12 studi, IL1A resta con uno studio di IL-1β, e cinque meta-analisi tengono confronti con due agenti, finché il rilevatore dei difetti non li toglie.
   - Chi la scrive: un agente come questo, con i test prima del codice. Non servono nove funzioni: per la chiave basta un punto solo, più le due regole. Il calcolo che applica le correzioni gira comunque, quindi il costo in più è il lavoro sul codice e le misure.

**Comunque:**

- l'errore delle corsie è corretto, con due test, e la suite di test passa;
- il deliverable, i master e la copia di salvataggio non sono cambiati, e nessun verdetto cambia adesso;
- nel master rifatto dal modello la quota di confronti con questi caratteri è quasi uguale, quindi la misura vale anche per la ricostruzione dei gruppi;
- la misura non ricalcola l'anchor del campione trattato, cioè il nome che il codice ricava dai metadati del campione: la sessione della correzione lo misurerà.

Appena decidi questo punto, la sessione è chiusa.

**Sui tempi di calcolo.** Le stime sono mie. Una misura completa ha richiesto circa 35 minuti su questa macchina. La raccolta degli ingressi di tutti i confronti ha richiesto 20 minuti con un processore. Il calcolo delle chiavi ha richiesto 7 minuti per caricare i dizionari e 8 minuti con 16 processori. Il lavoro sul codice è un mio giudizio di 4-6 ore, non una misura.

# 1. Che cosa è stato fatto

**Oggetto.** Stadio 3 del deliverable A3 v16, `analysis/p4-output/20260818T110906Z-stage3-v16-7f986159`, costruito da
`analysis/p4-output/A3-stage2-master-innestato.jsonl` (SHA-256 `b9947746…`, verificato contro il `run_metadata.json` dello
Stadio 3). Deliverable `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`, 194
meta-analisi; insieme principale `analysis/audit/2026-11-03-S5-gate-e-insiemi/80-insieme-40.csv`. Il codice dello Stadio 3
non è cambiato dopo il run del deliverable (`git log --since=2026-08-17 -- R/`: un solo commit, su `R/dgx-*`).

**La regola simulata** (`01-traduzione.R`, depositata in `00-previsioni.md` prima del calcolo[^previsioni]). Ogni carattere
dell'insieme G diventa il suo nome latino nelle cinque stringhe che entrano nella chiave d'entità di un confronto: etichetta
del trattato, etichetta del controllo, `factor_levels` dei due bracci, nome dell'anchor. G = blocchi Unicode «Greek and
Coptic» e «Greek Extended», più µ (U+00B5) e ß (U+00DF). μ e µ diventano `u`; ß diventa `beta`. Il resto della stringa non
cambia. Nessun carattere di G è rimasto senza traduzione (`30-due-regimi.txt`).

**La catena.**

| passo | script | che cosa fa | tempo |
|---|---|---|---|
| ingressi | `20-ingressi.R` | rifà i passi 1-6b del re-cluster (`analysis/p4-fase-f13-stage3-v16-tre-cambi.R`) e la cache degli anchor della fase 2.0, poi percorre i confronti come `.build_contrast_group_records()` e salva i sei ingressi della chiave | 20 min, un processo |
| due regimi | `30-due-regimi.R` | `.ca_member_contrast()` su tutti i confronti, senza traduzione (OFF) e con traduzione (ON); controllo positivo prima dei dati | 7 min di dizionari + 8 min con 16 processi |
| quota nel master S14 | `35-quota-s14.R` | la quota di confronti con caratteri di G nei master A3 e S14, con la stessa enumerazione | 2 min |
| analisi | `40-analisi.R` | cancelli 2-3, previsioni P1-P4, fusioni e rotture su tutto lo Stadio 3, le 194 e le 40 | 1 min |
| spiegazioni | `45-anomalie.R` | P1 scomposto, cambi contro `difetti.csv`, TNF in ASCII, interferone, negazione, codifica, IL1A | 8 min |
| corsie | `R/stage4-technical-lanes.R`, `tests/testthat/test-stage4-technical-lanes.R` | una riga e due test | suite 14 min |

`20-ingressi.R` controlla che i numeri intermedi siano quelli del log del re-cluster A3
(`analysis/audit/2026-08-16-A3/log/recluster-a3.log`): 24.394 studi, guardia di completezza 18.923 campioni su 1.448 studi,
189.966 chiavi di anchor, 187.288 GSM rappresentanti, overlay 52.437 e 41.470 GSM. Tutti uguali.

# 2. Cancelli

| # | cancello | esito | fonte |
|---|---|---|---|
| 1 | manifesto SHA-256 del deliverable all'inizio e alla fine | passato: «VERIFICA OK» due volte, 73 file | `10-manifesto-inizio.txt`, `90-manifesto-fine.txt` |
| 2 | il regime OFF riproduce lo Stadio 3 | passato: 53.915 record costruiti; 27.395 chiavi su 27.395 uguali ad `anchor_key`; 26.520 non eleggibili uguali a `tier_s_incomplete`; 32.830 scarti su 32.830 con la stessa ragione; nessun'altra ragione | `40-out.txt` |
| 3 | copertura e controllo negativo | passato: 86.745 confronti su 86.745 in entrambi i regimi; 82.879 confronti su 82.879 senza caratteri di G con esito ON uguale a OFF in tutti i sei campi | `40-out.txt` |
| 4 | controllo positivo | passato: (a) 10 forme greche su 10 tradotte esattamente nella forma ASCII; (b) `IFN-γ` contro `IFN-β` è `no_delta` in OFF e `HGNC:5438` in ON | `31-cancello-4a.txt`, `30-controllo-positivo.txt` |
| 5 | fix delle corsie e nient'altro | passato: `.lane_index(c(NA, "a_L001", "a_L002"))` dà `NA, 1, 2`; i due test nuovi passano; la suite `stage4` non ha fallimenti; `98-greche-tutti-i-resolver.R` dà ancora 45 su 90, CSV identico (`git diff` vuoto) | `40-suite-stage4.txt`, `50-greche-90-prove.txt` |

# 3. Previsioni

P2-P4 sono conteggi sull'intera popolazione: non hanno errore di campionamento e si giudica il valore. P1 e P5 hanno un IC 95%
da bootstrap per studio, B = 2.000, seme 20261107.

| # | quantità | atteso | intervallo | misura | verdetto |
|---|---|---:|---|---|---|
| P1 | quota dei confronti con almeno un carattere di G nelle cinque stringhe | 1,0% | 0,3%–3% | 3.866 su 86.745 = 4,46% [3,79; 5,24] | **smentita**, spiegata in §4 |
| P2 | meta-analisi delle 194 il cui gruppo cambia | 3 | 0–5 | 7 (5 con almeno uno studio in più o in meno) | **smentita** |
| P3 | meta-analisi delle 40 il cui gruppo cambia | 0 | 0 | 1 (TNF) | **smentita** |
| P4 | gruppi nuovi con almeno 3 studi | 1 | 0–2 | 1 | confermata, ma il gruppo è sbagliato (§6) |
| P5 | rapporto fra la quota del master S14 e quella del master A3 (quattro stringhe) | 1,0 | 0,5–2 | 0,935 [0,869; 1,003] | confermata |

Tre margini venivano da un mio giudizio (P1, P4, P5), due da una soglia del progetto (P2, P3: la clausola di decadenza della
sessione sui due insiemi).

# 4. Il criterio di esaustività e la quota di P1

**Criterio** (punto 1 dell'handout). La chiave d'entità è una funzione deterministica di cinque stringhe e dell'ID
dell'anchor. Un confronto può cambiare con la traduzione solo se una delle cinque contiene un carattere di G. Il cancello 3
lo verifica su tutti gli 82.879 confronti senza caratteri di G, e tutti i 364 confronti che cambiano hanno un carattere di G
(`40-out.txt`). Il criterio è applicato a tutto lo Stadio 3, non alle 194: un gruppo che si fonde con un gruppo sotto i 3
studi si vede.

**P1 è smentita per la definizione di G, non per le lettere greche.** La previsione guardava le lettere greche nei nomi. G
include anche il simbolo di micro delle unità e i nomi dell'anchor, che vengono dai dizionari (per esempio «17β-estradiol»
di ChEBI) e dai metadati del campione[^anomalie]:

| componente | confronti |
|---|---:|
| G nelle quattro stringhe del confronto (etichette e `factor_levels`) | 2.615 |
| di cui lettere greche diverse da μ | 858 (0,99%) |
| di cui solo il simbolo di micro | 1.757 |
| G solo nel nome dell'anchor | 1.251 |
| totale (P1) | 3.866 |

Le lettere greche nelle etichette e nei `factor_levels` sono lo 0,99% dei confronti, come previsto. La smentita non tocca una
conclusione: la quantità che decide è quanti confronti cambiano (§5), e quella è misurata direttamente. Il dubbio è chiuso
come **spiegato**.

**Che cosa il criterio non vede.**

- **L'anchor del campione trattato.** La simulazione traduce il nome dell'anchor ma non ricalcola l'anchor (recupero del
  nome, overlay, ID, completezza del tier S). 2.142 confronti in un gruppo hanno un carattere di G nel nome dell'anchor o nei
  fatti dello Stadio 1; 137 di questi prendono l'entità dall'anchor; 591 stanno in 91 meta-analisi del deliverable
  (`40-out.txt`). Una correzione del recupero del nome va misurata a parte.
- **Le greche rovinate dalla codifica** (UTF-8 letto come Latin-1, per esempio «ifn-î³»). Non stanno mai nelle quattro
  stringhe del confronto; stanno nel nome dell'anchor di 272 confronti, 72 in un gruppo, 3 con l'entità presa dall'anchor
  (`45-out.txt` §F).

# 5. Le etichette con caratteri di G e che cosa cambia

**Dove stanno** (punto 2). 3.866 confronti in 1.017 studi hanno un carattere di G; 1.547 sono in un gruppo; 501 stanno in 64
meta-analisi del deliverable (`40-out.txt`, `40-G-nelle-194.csv`). In 57 di queste 64 meta-analisi la traduzione non cambia
nulla.

**Che cosa cambia** (punto 3). 364 confronti cambiano stato nello Stadio 3:

| tipo | lettere greche | lettere greche e micro | solo micro | totale |
|---|---:|---:|---:|---:|
| cambia gruppo | 165 | 0 | 54 | 219 |
| esce dal gruppo | 39 | 1 | 2 | 42 |
| entra in un gruppo | 20 | 1 | 0 | 21 |
| cambia ragione di scarto | 78 | 0 | 4 | 82 |

I cambi dovuti al solo micro sono quasi tutti chiavi `STR:` e `COMBO:` che perdono la dose: «IN10018 3 µM» smette di lasciare
`3 m` nella chiave. Uno cambia entità: «Cd-5µM» (cadmio) passa da `HGNC:1685` a `STR:cd_5um`, ed entrambe sono sbagliate.

**I gruppi** (`40-out.txt`, `40-gruppi-toccati.csv`):

| quantità | valore |
|---|---:|
| gruppi OFF / ON | 11.551 / 11.563 |
| chiavi di gruppo toccate | 290 |
| entità OFF dei confronti che cambiano | 131 |
| gruppi che si spezzano (almeno 2 destinazioni) | 14 |
| gruppi che nascono da una fusione (almeno 2 origini) | 9 |
| chiavi nuove / chiavi che spariscono | 142 / 130 |
| gruppi che arrivano a 3 studi (P4) | 1: `CHEBI:5939+CHEMBL:CHEMBL2108494`, 2 → 3 |
| gruppi che scendono sotto 3 studi | 2: `COMBO:il1+tnf` 3 → 2; `STR:1_25_oh_2d3` 3 → 2 |

# 6. Le sette meta-analisi del deliverable

| meta-analisi | nelle 40 | confronti che escono | studi persi (poolati) | studi | dove vanno | causa |
|---|---|---:|---:|---|---|---|
| TGFB1 | no | 5 | 1 (1) | 71 → 70 | 1 `COMBO:hypoxia+tgf-beta1`; 4 scartati `entita_costante` | combinazione vista; regola che non legge «no» |
| TNF | **sì** | 31 | 15 (12) | 42 → 27 | 27 scartati `id_blacklist`; 4 `CHEMBL:CHEMBL265582` | difetto della forma ASCII |
| lipopolysaccharide | no | 1 | 1 (1) | 44 → 43 | `COMBO:ifn-gamma+lps` | combinazione vista |
| IFNG | no | 3 | 0 | 31 → 31 | `COMBO:ifn-gamma+sb-3ct`, `COMBO:c trachomatis+ifn-gamma` | combinazioni viste |
| IFNB1 | no | 1 | 0 | 8 → 8 | `COMBO:ifn-beta+wild-type t gondii` | combinazione vista |
| IL1A | no | 3 | 1 (1) | 4 → 3 | `COMBO:ifn-gamma+il-1beta` | entità sbagliata e combinazione |
| 1 25 oh 2d3 | no | 8 | 1 (1) | 3 → 2 | `STR:1alpha_25_oh_2d3` | il ripiego `STR:` si divide |

Fonte: `40-meta-analisi.csv`, `45-cambi-contro-difetti.csv`. Nessuna meta-analisi guadagna confronti. `17β-estradiol`
(nelle 40, rinvio dalla validazione esterna) non cambia.

**Cinque cambi tolgono confronti sbagliati.** Gli studi sono 7: `GSE139963`, `GSE163241` (TGFB1), `GSE97744` (LPS),
`GSE141585`, `GSE158814` (IFNG), `GSE125066` (IFNB1), `GSE205853` (IL1A). La rilettura di agosto aveva già segnato 6 di
questi 7 in `difetti.csv`, per la stessa meta-analisi; `GSE158814` («C. trachomatis infection + IFN-γ» contro «Untreated»)
non c'era. `GSE163241` esce per la ragione sbagliata: la rilettura lo accusava per il passaggio di coltura, la traduzione lo
scarta con la regola dell'entità costante (§7.3).

**IL1A contiene oggi uno studio di IL-1β.** In `GSE205853` il valore del trattato è «IFN-γ, IL-1β»: la sanitizzazione
cancella le greche, il candidato «ifn- il-1 tnf-» arriva alla tabella delle citochine prima della forma tradotta, e risolve a
`HGNC:5991`, cioè IL1A (`.ca_resolve_entity()`, ramo dei farmaci). È l'ordine voluto da `.ca_latinize_greek()` («si prova
DOPO la forma originale»). Il finding di agosto §13 diceva che il deliverable non era toccato: vero per le sette forme
collassate provate, non per questo studio, che la rilettura aveva però già segnato.

# 7. Anomalie viste durante il lavoro

## 7.1 TNF-alpha in lettere latine

| stringa | ChEBI/ChEMBL (provato per primo nel ramo dei farmaci) | citochine |
|---|---|---|
| `tnf-alpha` | `CHEMBL:CHEMBL265582` (TNF-ALPHA) | `HGNC:11892` |
| `tnfalpha` | `CHEBI:197439` (TNF alpha del pesce zebra), nella lista nera | `HGNC:11892` |
| `tnf-α`, `tnfα` | `STR:tnf` (non canonico) | `HGNC:11892` |

Fonte: `45-out.txt` §C. La forma greca oggi funziona perché ChEBI non la riconosce e il codice passa alle citochine. La
traduzione la manda sulla forma ASCII, che ChEBI e ChEMBL riconoscono male. Sul deliverable di oggi: 93 confronti eleggibili
scrivono TNF-alpha in lettere latine; 2 (1 studio) stanno nel gruppo TNF; 6 (6 studi) formano il gruppo
`CHEMBL:CHEMBL265582`, che non è una meta-analisi del deliverable; 11 (6 studi) sono scartati `id_blacklist`. **12 studi
restano fuori dalla meta-analisi su TNF, che ne ha 42.** Il numero è un massimo: altre regole possono scartarne alcuni.

## 7.2 Interferon gamma scritto per esteso

`interferon gamma` → `CHEBI:5939+CHEMBL:CHEMBL2108494`; `interferon γ` → `CHEMBL:CHEMBL2108494` (INTERFERON); la tabella delle
citochine dà `HGNC:5438` (IFNG) per entrambe (`45-out.txt` §D). Il gruppo nuovo di P4 sono 6 confronti di `GSE109720`
(«cells treated with Interferon γ») che passano da un gruppo sbagliato a un altro gruppo sbagliato. È lo stesso difetto di
§7.1: nel ramo dei farmaci ChEBI e ChEMBL vengono prima delle citochine.

## 7.3 La regola dell'entità tenuta costante non legge la negazione

`.ca_member_contrast()` scarta un confronto se il candidato dell'entità compare nell'etichetta del controllo
(`R/stage3-contrast-anchor.R`, `entita_costante`). Non controlla la negazione: «Passage 2-3, TGFb» contro «Passage 2-3, no
TGFb» viene scartato. Oggi la regola scarta 706 confronti eleggibili; 241, in 92 studi, hanno «no», «non», «without», «w/o»,
«minus» o «absence» nel controllo (`45-out.txt` §E, elenco in `45-entita-costante-negata.csv`). Il conto è un massimo: non
tutti sono scarti sbagliati. Vanno letti.

## 7.4 Il ripiego `STR:` sul calcitriolo

`GSE223405` scrive «1α,25(OH)2D3»; gli altri due studi del gruppo scrivono «1,25(OH)2D3». Oggi la cancellazione della α li
unisce in `STR:1_25_oh_2d3`. Con la traduzione `GSE223405` va in `STR:1alpha_25_oh_2d3` e il gruppo scende a 2 studi. Nessuna
delle due chiavi è l'ID del calcitriolo.

# 8. Il crash delle corsie

`.lane_index()` (`R/stage4-technical-lanes.R`) applicava `regexpr` a un titolo NA: `m` conteneva NA, `k <- m > 0L &
is.na(out)` pure, e `out[k] <- …` andava in errore. Il `cumsum(m > 0L)` avrebbe anche spostato gli indici dopo il NA. La
correzione è una riga: un titolo NA diventa una stringa vuota prima del `regexpr`, cioè non dichiara una corsia. Test:

- `.lane_index()` con il NA in testa, in coda e in mezzo a un titolo `lane 3`;
- `build_lane_library_lookup()` con un titolo NA e altre due librerie candidate, che è il caso che chiama `.lane_index()`.

Entrambi i test falliscono con l'errore dell'handout prima della correzione e passano dopo. Commit `6996f73`.

# 9. Il costo della correzione, e chi la scrive

L'handout chiedeva di pesare due costi.

- **Il calcolo**: circa zero. Il calcolo che applica le correzioni rifà raggruppamento e pooling comunque, e lo fa anche la
  seconda parte del re-run. La misura di controllo costa circa 35 minuti a ogni giro (§1).
- **Il codice**: non nove funzioni. Per la chiave d'entità basta tradurre in un punto, all'ingresso di
  `.ca_member_contrast()`: è quello che questa sessione ha simulato, e copre tutti i resolver che la chiave chiama. La sola
  traduzione però danneggia TNF (§7.1). Una correzione utile ha tre parti, da misurare una alla volta: la traduzione; i nomi
  delle citochine in lettere latine risolti come citochine (§7.1, §7.2); la negazione nella regola dell'entità costante
  (§7.3). Il recupero del nome dell'anchor va misurato a parte (§4). Stima: 4-6 ore di lavoro di un agente, test prima del
  codice; è un giudizio, non una misura.
- **Il rilevatore dei difetti** (sessioni S10-S12) ha già nel suo piano la normalizzazione delle greche nel riconoscitore di
  agenti, che è un punto diverso dalla chiave.

# 10. Dubbi e come si chiudono

| dubbio | come si chiude |
|---|---|
| P1 smentita | spiegato (§4): la quota include micro e nomi dell'anchor; le lettere greche nelle etichette sono lo 0,99% |
| P2 smentita (7 invece di al massimo 5) | spiegato (§6) e deciso dal PI (§12): la correzione si scrive in S12b |
| P3 smentita (TNF nelle 40) | spiegato (§7.1) e deciso dal PI (§12) |
| TNF-alpha in ASCII fuori dal gruppo TNF (12 studi) | deciso dal PI; rinviato a S12b |
| Interferon gamma per esteso | deciso dal PI; rinviato a S12b |
| regola dell'entità costante e negazione (241 confronti) | deciso dal PI; rinviato a S12b |
| calcitriolo diviso in quattro gruppi | rinviato a S12c (§11, §12) |
| meta-analisi con più nomi (domanda del PI) | deciso dal PI; rinviato a S12c |
| anchor con l'ID ChEBI sbagliato scritto dal modello (domanda del PI) | spiegato (§11, `47-out.txt`); deciso dal PI (§12, punto 4); rinviato a S12c |
| anchor non ricalcolato (2.142 confronti) | rinviato a S12b |
| greche rovinate dalla codifica (272 nomi di anchor) | spiegato (§4); rinviato a S12b con l'anchor |

# 11. Dopo il riassunto: il calcitriolo, le meta-analisi con più nomi e l'anchor

Fonte di tutta la sezione: `46-out.txt` (script `46-nomi-e-anchor.R`).

**Il calcitriolo.** Il dizionario risolve `calcitriol`, `1,25-dihydroxyvitamin d3` e `1alpha,25-dihydroxyvitamin d3` a
`CHEBI:17823`. Non risolve la forma abbreviata: `1,25(oh)2d3` e `1α,25(oh)2d3` danno `STR:1_25_oh_2d3`, `1alpha,25(oh)2d3`
dà `STR:1alpha_25_oh_2d3`, `1,25d3` dà `STR:1_25d3`. 170 confronti in 34 studi nominano il calcitriolo nel trattato. Con
verso `gain` e controllo `vehicle_untreated` stanno in quattro gruppi: `CHEBI:17823` (9 studi), `STR:1_25_oh_2d3` (3),
`STR:1_25d3` (1), `STR:1alpha_25_oh_2d3` (1); 14 studi distinti. Due sono meta-analisi del deliverable: «calcitriol» (9) e
«1 25 oh 2d3» (3). `GSE221690` e `GSE223405` usano le stesse quattro linee cellulari e possono essere studi doppi. Il
problema non è la α: la traduzione lo mostra, perché oggi la cancellazione della α unisce per caso due delle quattro forme.

**Altre meta-analisi con due nomi** (candidate dal nome, con lo stesso verso e lo stesso controllo; non verificate):

| nomi | studi | nelle 40 |
|---|---|---|
| irradiation, radiation | 7 e 7 | no |
| asthma, asthmatic | 4 e 3 | no |
| ifna, IFNA1 | 6 e 6 | no |
| nash, Non-alcoholic Fatty Liver Disease | 7 e 5 | sì, entrambe |
| 1 25 oh 2d3, calcitriol | 3 e 9 | no |

NASH e NAFLD possono essere due confronti diversi. Le meta-analisi con un nome non risolto (`STR:`) sono 44.

**Perché l'anchor non unisce questi nomi** (domanda del PI: «l'LLM non dovrebbe avere problemi a classificare irradiation e
radiation alla stessa maniera; l'ancora dovrebbe essere uguale»). Tre cause, misurate:

1. **La chiave del gruppo non è l'anchor.** Dopo ADR-0025 la chiave viene dal testo del fattore che cambia fra i bracci,
   scritto dallo Stadio 2 e risolto dai dizionari. L'anchor entra solo se tutte le parole distintive del suo nome stanno nel
   testo del trattato. Nel gruppo `STR:irradiation` 4 confronti su 13 prendono l'entità dall'anchor e 9 dal testo; nel gruppo
   `STR:ifna` 13 su 13 la prendono dal testo, anche se 8 hanno l'anchor «Interferon-alpha» (`MeSH:D016898`).
2. **Il modello copia la parola del metadato.** Gli anchor dei due gruppi sono «Radiation», «irradiation», «ionizing radiation»
   e «Radiotherapy»: le prime due non hanno un ID nei dizionari e restano due stringhe diverse.
3. **Il modello scrive il nome giusto e un numero ChEBI sbagliato, e il codice si fida del numero.** Nel master dello Stadio 1:

| ID scritto dal modello | nome in ChEBI | occorrenze | nomi scritti dal modello più frequenti |
|---|---|---:|---|
| `CHEBI:16579` | anisole | 117 | calcitriol (83), oleic acid (30) |
| `CHEBI:16512` | (S)-N-methylcanadine | 47 | calcitriol (46) |
| `CHEBI:16515` | 3-ADP-glyceric acid | 14 | calcitriol (14) |
| `CHEBI:17236` | 2-hydroxy-6-oxohexa-2,4-dienoic acid | 646 | interferon-alpha (105), prednisolone (58), interferon-beta (47), interferon gamma (41) |
| `CHEBI:16635` | Met-tRNA | 996 | transforming growth factor beta-1 (327), interferon gamma (241), transforming growth factor beta (225) |

Il difetto è noto dal 2026-07-23 (`docs/findings/2026-07-23-stage3-cluster-coherence.md`: «`ethanol` è in realtà TNF,
`Met-tRNA` è TGFB1, `anisole` è calcitriolo») e dal 2026-07-25 (`2026-07-25-stage3-contrast-anchor-v7-census.md` §5: «qualcuno
deve deciderlo»). ADR-0018 lo chiama «probable LLM hallucination consistente». Non è mai stato deciso. Non cambia il nome delle
meta-analisi del deliverable, che viene dalla chiave, ma rende l'anchor inutile per unire i sinonimi: il nome scritto dal
modello è giusto più spesso dell'ID. Rinviato a S12c.

# 12. Decisioni del PI (2026-11-07)

1. **Sì alla correzione in una sessione nuova (S12b), prima di S13**, con tre parti: traduzione delle lettere greche in un
   punto, nomi delle citochine in lettere latine risolti come citochine, negazione nella regola dell'entità costante.
2. **Sì al problema nuovo «una entità con più nomi», con una sessione propria (S12c), prima di S13.** Nota del PI: non
   limitarsi alle coppie, perché un'entità può avere più di due nomi (il calcitriolo ne ha quattro). Domanda del PI sull'anchor:
   risposta in §11.
3. **Il calcitriolo va in S12c** (scelta tecnica dell'agente: il PI ha detto sì alle due sessioni e non ha risposto a parte
   sul calcitriolo). È lo stesso difetto di S12c, quattro nomi per una entità. S12b deve verificare che la traduzione non
   divida nessun gruppo, salvo i gruppi che S12c unisce; S13 parte dopo entrambe.
4. **S12c risolve il problema, con un comportamento generale** (seconda domanda del PI: «rispondimi se nelle prossime sessioni
   risolviamo la cosa o no»; risposta del PI: «sì, ma non deve essere limitata a questi due, deve essere un comportamento
   generale»). Il modello scrive il nome giusto (`47-out.txt`): «calcitriol» in tutti e quattro i gruppi del calcitriolo, con sei
   ID ChEBI diversi e nessuno giusto; «interferon-alpha» nei due gruppi di IFN-alfa; «Radiation» nella maggior parte dei
   confronti delle radiazioni. S12c scrive un ADR e due regole senza nomi di entità: l'ID del modello si controlla con il nome
   del modello, in tutti i database; quando il testo del confronto non si risolve, la chiave usa il nome del modello per la
   stessa parola. Calcitriolo e interferone alfa sono controlli positivi. S12c viene dopo S12b.

# Da dove vengono i numeri del riassunto

| nel riassunto | fonte | valore letto |
|---|---|---|
| «7 delle 194» | `40-out.txt`, P2 | 7 |
| «non 3 come mi aspettavo» | `00-previsioni.md`, P2 | atteso 3 |
| «364 confronti su 86.745» | `40-out.txt` | 364; 86.745 |
| «tutti con una lettera greca o con il simbolo di micro» | `40-out.txt` | «tutti con G: TRUE» |
| «cambia solo quella su TNF» | `40-out.txt`, P3 | 1, TNF in40=TRUE |
| «17β-estradiolo non cambia» | `40-out.txt` | cambia=FALSE |
| «cinque meta-analisi», «7 studi» | `45-out.txt` §B | TGFB1, LPS, IFNG, IFNB1, IL1A; 7 studi |
| «6 di questi 7» | `45-out.txt` §B | `gia_difetto` TRUE per 6 |
| «da 42 a 27 studi» | `40-out.txt` | k 42 -> 27 |
| «12 studi fuori», «un solo studio che scrive TNF-alpha» | `45-out.txt` §C | 12; 2 confronti, 1 studio |
| «sotto 3 studi» (calcitriolo) | `40-out.txt` | `STR:1_25_oh_2d3` k 3 -> 2 |
| «gruppo sbagliato con 3 studi» | `40-out.txt`, P4 | `CHEBI:5939+CHEMBL:CHEMBL2108494` k 2 -> 3 |
| «241 confronti in 92 studi» | `45-out.txt` §E | 241; 92 |
| «altri 4 confronti dalla meta-analisi su TGFB1» | `40-confronti-che-cambiano.csv` | 4 righe `FUORI:entita_costante`, GSE163241 |
| «15 studi» | `40-out.txt` | studi persi 15 |
| «quasi uguale» (master S14) | `35-quota-s14.txt` | rapporto 0,935 |
| «circa 35 minuti», «7», «20», «8 minuti» | log di `30-due-regimi.R` e `20-ingressi.R` | 7 min dizionari; 20 min; 8 min |

[^previsioni]: `analysis/audit/2026-11-07-S9-greche-e-corsie/00-previsioni.md`, commit `cc8ec0c`.
[^anomalie]: `analysis/audit/2026-11-07-S9-greche-e-corsie/45-out.txt`.
