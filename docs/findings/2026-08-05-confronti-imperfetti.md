# I confronti imperfetti: come li abbiamo trovati e quanti sono

**Data:** 2026-08-05 · **Deliverable:** v15, 214 meta-analisi
(`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v15/20260805T004943Z-stage4-v15-d29545c7`)
**Stato:** finding destinato all'articolo (Methods + Results + Limitations).
**Decisione dell'utente (2026-08-05):** i confronti imperfetti **non sono un gate**: si
**quantificano** e si dichiarano.

---

## 1. Di che cosa si tratta

Una meta-analisi di questo lavoro mette insieme confronti *trattato contro controllo*
provenienti da studi diversi, appaiati automaticamente a partire dai metadati testuali di
GEO. Un **confronto imperfetto** è un confronto che entra nel pool pur non isolando
esattamente la perturbazione dichiarata dal gruppo: per esempio il braccio trattato porta
un secondo agente che il controllo non ha, oppure i due bracci differiscono per materiale,
sede anatomica, linea cellulare o passaggio di coltura.

Non è la stessa cosa di un gruppo incoerente. Un gruppo è incoerente quando **mette insieme
contrasti diversi** (il "minestrone" del RED ALERT 2026-07-24). Un confronto imperfetto è
un **singolo membro difettoso** dentro un gruppo per il resto omogeneo. La differenza è
quantitativa e va misurata, non decisa a occhio: in un gruppo da 150 confronti, tre
imperfetti e settantacinque imperfetti sono due situazioni completamente diverse, e fino a
questa misura la pipeline le trattava allo stesso modo.

---

## 2. Il metodo, in ordine

### 2.1 Il materiale: le etichette intere degli studi *poolati*

Fonte: `analysis/audit/2026-08-05-rilettura-214/00-materiale.R`.

Per ognuna delle 214 meta-analisi si estraggono i confronti **effettivamente poolati**
(da `per_study_de.parquet`, non i membri censiti dallo Stadio 3: il gate dei controlli
interni ne scarta 541 su 1.879) e, per ciascuno, le etichette **intere** del braccio
trattato e del braccio di controllo, risolte con `.split_record_id()` / `.lookup_cmp()`
dallo Stadio 2.

**Perché "intere" è una precauzione e non un dettaglio.** Questo progetto ha già pagato tre
volte lo stesso errore: alias troppo corti (`LTA` risolto come tripeptide), lettere greche
cancellate dalla normalizzazione (`IL-1β`), e testo troncato a 58 caratteri — con un
verdetto dato su mezza frase (GSE126517: il pezzo tagliato era `and IFN-alpha for 18
hours`). Lo script quindi **misura la distribuzione delle lunghezze** e segnala i picchi
sospetti. Ne ha trovati due — 69 etichette di esattamente 40 caratteri, 11 di 58 — e sono
stati ispezionati uno per uno: sono frasi complete (*"A2780 cells treated with vehicle
control"*), non tronconi. L'etichetta più lunga misura 129 caratteri e arriva alla fine.

Il materiale è diviso in 22 blocchi da 10 gruppi
(`analysis/audit/2026-08-05-rilettura-214/blocco-NN.txt`).

### 2.2 Prima passata: 22 lettori

Un agente per blocco, con una rubrica di **nove meccanismi** ricavati dai censimenti
precedenti di questo corpus (non inventati per l'occasione): clinico contro sperimentale ·
entità che è una classe-ombrello · entità che è un reagente o un induttore · direzioni
opposte · il controllo non è un controllo · materiali incompatibili · combinazione non
catturata · entità sbagliata · bracci non appaiati per tempo, donatore, linea o passaggio.

Con un'avvertenza esplicita: **nei disegni caso-controllo di malattia i soggetti diversi
sono obbligatori**, non un difetto — è l'errore che il primo rilevatore di righe faceva nel
52% delle sue segnalazioni (2026-07-26).

### 2.3 Seconda passata: 22 contestatori

Per ogni blocco, un secondo agente riceve i verdetti del primo e **il compito di
smentirli**: attaccare i "coerente" cercando la prova contraria, e verificare che le accuse
degli "incoerente" reggano sull'etichetta citata.

### 2.4 Terza passata: 13 contatori

La seconda passata produce un verdetto binario, che per un gruppo da 150 confronti dice
poco. Per i 13 gruppi grandi (k ≥ 15) — cioè tutti quelli candidati alle figure — un terzo
agente per gruppo ha ricevuto **un compito solo: contare**. Quanti confronti ha il gruppo
in tutto, e quali esattamente sono difettosi, riportando l'etichetta com'è scritta, con
l'istruzione di **non elencare** le accuse che non reggono e di segnalarle a parte.

### 2.5 La pesatura, sui dati veri

I confronti non contano tutti uguale: nel modello a effetti casuali il peso è l'inverso
della varianza. Per ogni gruppo si calcola la quota di peso degli studi che contengono
confronti difettosi (mediana di `1/SE²` per studio, normalizzata dentro il cluster).

---

## 3. I risultati

### 3.1 Quanti gruppi hanno almeno un confronto imperfetto

Su **214 meta-analisi** rilette per intero:

| | |
|---|---:|
| nessun difetto rilevato | 101 |
| **almeno un confronto imperfetto** | **97** |
| incerti | 16 |

Il tasso **cresce con la dimensione del gruppo**, come deve: più confronti, più occasioni
di contenerne uno difettoso.

| dimensione | senza difetti | con difetti |
|---|---:|---:|
| 3-4 studi | 68 | 47 |
| 5-9 studi | 29 | 25 |
| 10-14 studi | 4 | 12 |
| **≥ 15 studi** | **0** | **13** |

**Questo è il motivo per cui non può essere un gate.** Un criterio binario "un difetto =
gruppo escluso" eliminerebbe *tutti* i gruppi grandi, cioè tutte le meta-analisi con
potenza sufficiente per una figura, per difetti che — misurati — valgono spesso meno
dell'uno per cento del segnale.

### 3.2 Quanti confronti, nei 13 gruppi grandi

> 🔴 **CORRETTO IL 2026-08-10 — QUESTA SEZIONE ERA SBAGLIATA DUE VOLTE.** I confronti censiti
> **non sono** quelli poolati (il materiale elencava i confronti di uno studio non appena lo
> *studio* compariva nel poolato, senza applicare `n_min`), e la regola del peso pesava i
> **bracci** senza collasso per studio e senza τ². Numeri corretti in
> `docs/findings/2026-08-10-sensitivity-confronti-spuri.md` §3.1 e
> `-2026-08-10-passo1-accusati-dentro-il-pooling.md`. Sotto restano i numeri **censiti**,
> con accanto quelli veri.

**85 confronti imperfetti su 843 censiti = 10,1%.** Mediana per gruppo: 8,6%.
**Sui confronti effettivamente poolati: 38 su 533 = 7,1%.**

| gruppo | confronti censiti | imperfetti | % | % del peso (pubblicata) | **% del peso (corretta)** |
|---|---:|---:|---:|---:|---:|
| SARS-CoV-2 | 98 | 3 | 3,1% | 0,7% | **2,1%** |
| ipossia | 58 | 3 | 5,2% | 1,3% | **5,0%** |
| JQ1 | 58 | 6 | 10,3% | 3,2% | **4,5%** |
| R1881 | 92 | 4 | 4,3% | 4,4% | **8,8%** |
| TGF-β1 | 145 | 29 | 20,0% | 6,7% | **9,1%** |
| cisplatino | 49 | 5 | 10,2% | 4,7% | **12,0%** |
| DHT | 44 | 3 | 6,8% | 12,0% | **9,1%** |
| **enzalutamide** | 45 | 4 | 8,9% | 12,1% | **0,0%** |
| IFN-γ | 35 | 3 | 8,6% | 13,0% | **6,0%** |
| **TNF** | 71 | 4 | 5,6% | 13,8% | **0,0%** |
| palbociclib | 39 | 11 | 28,2% | 16,1% | **15,4%** |
| LPS | 72 | 6 | 8,3% | 19,5% | **15,9%** |
| IL1B | 37 | 4 | 10,8% | 33,7% | **13,3%** |

**La colonna del peso è un limite superiore**: attribuisce a un difetto tutto il peso dello
studio coinvolto, anche quando solo uno dei suoi sette confronti è imperfetto.

⚠️ **TNF ed enzalutamide hanno peso contaminato ZERO**: tutti i loro confronti accusati stanno
sotto `n_min` e non entrano nel deliverable. E la correzione **non va in una sola direzione** —
cinque gruppi salgono, perché la regola vecchia sottostimava. Il caso peggiore non è IL1B (33,7%)
ma **LPS (15,9%)**, e l'intervallo è **0,0%–15,9%**, non 0,7%–33,7%.

~~Da notare che le due colonne non sono ordinate allo stesso modo. TGF-β1 ha il conteggio peggiore
(29 confronti su 145) ma il 6,7% del peso, perché i due studi che contribuiscono la maggior parte
dei difetti — GSE161176 e GSE210984 — pesano poco: la pesatura per varianza inversa declassa da
sola ciò che è rumoroso.~~ **RITRATTATO 2026-08-10**: il peso vero di TGF-β1 è **9,1%**, e non
c'è nessun declassamento automatico — il rapporto fra il peso degli studi accusati e la loro quota
a peso uguale è **1,07** (in 8 gruppi su 13 gli accusati pesano *più* della loro quota). Resta
vero il fenomeno inverso in IL1B, dove pochi confronti valgono molto perché appartengono a uno
studio dominante.

### 3.3 Che tipo di difetti sono

| meccanismo | confronti | quota |
|---|---:|---:|
| secondo agente presente nel solo braccio trattato | 19 | 22% |
| materiale diverso (tessuto / linea / organoide / iPSC) | 18 | 21% |
| passaggio di coltura diverso fra i bracci | 14 | 16% |
| linea cellulare diversa fra i bracci | 13 | 15% |
| sede anatomica diversa fra i bracci | 10 | 12% |
| donatore, sesso o etnia diversi in un disegno di trattamento | 8 | 9% |
| clone diverso | 2 | 2% |
| una seconda variabile cambia insieme al trattamento | 1 | 1% |
| **totale** | **85** | |

Esempi concreti, con l'etichetta come compare nel dato:

- **secondo agente**: `Hypoxia + TGF-β1` contro `PBS (Vehicle Control)` — l'ipossia non è
  isolata, e lo stesso studio contiene anche un confronto pulito TGF-β1 contro PBS;
  `DHT and ENZ` contro `EtOH_DMSO` — l'antagonista dentro il gruppo dell'agonista;
- **materiale**: `Mesenchymal Stem Cells (iPSC-derived) treated with TGF-β` contro
  `Primary Mesenchymal Stem Cells (Control)`; `human heart, SARS-CoV-2 infected person`
  contro `human ES-derived macrophage, No treatment`;
- **passaggio**: `Articular chondrocytes - TGF-B1 - 21-days - Passage 27` contro
  `Articular chondrocytes - vehicle_only - Passage 6`;
- **sede**: `DIPG primary culture pons ... JQ1` contro `DIPG primary culture brain ...
  DMSO`.

### 3.4 I difetti si concentrano in pochi studi

I difetti **non sono sparsi uniformemente**: 8 studi contribuiscono 51 degli 85 confronti
imperfetti, e in dieci casi il difetto copre l'**intero** contributo di uno studio a un
gruppo (GSE161176 e GSE210984 in TGF-β1, GSE78801 in JQ1, GSE169241 in SARS-CoV-2,
GSE99626 in DHT, GSE172205 in R1881, e altri). È un'informazione operativa: una lista di
studi da escludere è molto più corta di una lista di confronti.

---

## 4. Che cosa questo *non* dimostra

**Un difetto non implica un risultato sbagliato.** DHT ed enzalutamide contengono entrambi
confronti imperfetti (12,0% e 12,1% del peso) e producono insieme il controllo biologico
più forte del lavoro: 1.299 geni significativi in entrambi i gruppi (⚠️ CORRETTO 2026-08-10: erano «1.441», conteggio gonfiato del 10,9% da un merge su `gene_symbol` con simboli duplicati; l’asse giusto è `gene_id`), **1.266 (97,5%) di
segno opposto**, correlazione di Spearman **−0,938**, sui quattro bersagli canonici del
recettore androgenico con i segni attesi (KLK3 +2,27 contro −1,60). Sono due gruppi
costruiti separatamente, da studi diversi, e nulla nella pipeline sa che sono collegati.

---

## 5. I limiti del metodo, dichiarati

1. **Il contestatore era spinto alla severità.** Il suo prompt diceva *«il tuo compito non
   è confermarlo: è provare che ha sbagliato»*. I 24 verdetti cambiati vanno **tutti** nella
   stessa direzione (10 da coerente a incoerente, 6 a incerto, 2 da incerto a incoerente,
   **zero assoluzioni**). Parte di quella asimmetria è indotta dal disegno, non dai dati: un
   impianto migliore avrebbe avuto due critici simmetrici, uno che accusa e uno che difende.
2. **Il peso è un limite superiore** (§3.2).
3. **Tre accuse non hanno retto alla verifica**, e vanno registrate perché mostrano il tasso
   di falsi positivi del metodo:
   - **GSE178714 in TGF-β1**: era stato indicato come difetto perché quattro confronti sono
     su cellule SMAD2/SMAD3 knockout. L'etichetta smentisce: il genotipo è **identico sui
     due bracci** (`SMAD2/SMAD3 KO, TGFB, 1h` contro `SMAD2/SMAD3 KO, untreated, 1h`), quindi
     il confronto isola correttamente l'effetto del TGF-β in quel genotipo. L'obiezione era
     di plausibilità biologica (senza i trasduttori la risposta è attenuata), non un difetto
     di appaiamento. **Ritrattata.**
   - **cisplatino e palbociclib**: l'accusa "secondo agente presente nel solo trattato" non
     regge su nessuna etichetta — ogni shRNA, knockout, mutazione o fusione è appaiata
     identica sui due bracci. I difetti reali di quei gruppi sono altri e meno numerosi.
4. **Una misura tentata e scartata perché cieca**: stimare il peso dei difetti estraendo con
   una espressione regolare gli identificativi degli studi citati nelle motivazioni. Dava
   mediana 87%, perché la regola prendeva anche gli studi che le motivazioni citano come
   *puliti*, e nei gruppi da tre studi citarne due copre tutto. Non discriminava, ed è stata
   sostituita dal conteggio esplicito (§2.4).
5. **Un chiarimento che cambia una lettura precedente**: TGF-β1 ha **145 confronti**, non 59.
   Cinquantanove è il numero di **studi**. I due numeri erano stati usati come se fossero la
   stessa cosa.

---

## 6. Che cosa va nell'articolo

**Nei Methods**, la procedura del §2 come descritta, compresa la verifica che le etichette
non fossero troncate e la terza passata di conteggio.

**Nei Results**, i numeri del §3: 97 gruppi su 214 con almeno un confronto imperfetto; **38
confronti su 533 poolati nei tredici gruppi ad alta potenza (7,1%)** — non 85 su 843, che è il
censito; la tabella per gruppo con le due colonne, conteggio e peso corretto.

**Nelle Limitations**, tre affermazioni:

- il tasso di gruppi con almeno un difetto **cresce con la dimensione del gruppo**, quindi
  non è una misura di qualità comparabile fra gruppi di taglia diversa;
- la contaminazione misurata sui gruppi delle figure va da **0,0% a 15,9% del peso**,
  mediana **8,8%**, e va riportata accanto a ciascuna figura;
- ~~la pesatura per varianza inversa attenua da sola il contributo degli studi difettosi~~
  **RITRATTATA 2026-08-10**: non c'è nessuna attenuazione automatica (rapporto peso
  accusati/equipeso = 1,07). Al suo posto va la sensitivity analysis:
  **rimuovere gli studi accusati costa una mediana del 10,1% dei geni significativi e sposta il
  ranking quanto rimuovere studi puliti che tolgono altrettanti dati** — gli accusati stanno al
  79° percentile dei riferimenti appaiati, senza raggiungere la significatività (n = 17, p = 0,11).
  Finding: `docs/findings/2026-08-10-sensitivity-confronti-spuri.md`.

**Come contributo metodologico**, il punto che questo lavoro può rivendicare: in una
meta-analisi automatica su scala di database, l'appaiamento trattato-controllo va
**misurato e riportato**, non assunto. È lo stesso genere di contributo del rilevamento
degli studi mal etichettati come umani in ARCHS4 (72 studi murini,
`docs/findings/2026-05-17-llm-detected-archs4-geo-organism-mislabeling.md`): un livello di
controllo di qualità che il database a monte non fornisce.

---

## 7. Dove sono i dati

| cosa | dove |
|---|---|
| materiale letto (22 blocchi, etichette intere) | `analysis/audit/2026-08-05-rilettura-214/blocco-NN.txt` |
| script che lo genera + controllo del troncamento | `analysis/audit/2026-08-05-rilettura-214/00-materiale.R` |
| i 214 verdetti (lettore, contestatore, motivo) | `analysis/audit/2026-08-05-rilettura-214/verdetti-rilettura-214.csv` |
| verdetti + peso + metriche del deliverable | `analysis/audit/2026-08-05-rilettura-214/verdetti-con-peso.csv` |
| conteggio confronto per confronto dei 13 grandi | `analysis/audit/2026-08-05-rilettura-214/13-grandi-conteggio.json` |
| copertura della verifica (chiusura per sottoinsiemi) | `docs/findings/2026-08-05-copertura-della-verifica-v15.md` |
