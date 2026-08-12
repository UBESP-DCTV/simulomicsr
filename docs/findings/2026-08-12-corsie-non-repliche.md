# Le corsie di sequenziamento non sono repliche — PASSO 3, misurato

**Data:** 2026-08-12 · **Branch:** `review-scientific-consistency-2026-06-10`
**master invariato · nessun push · nessun re-cluster e nessun re-pool eseguiti**
**Il meccanismo e' in codice di pacchetto ed e' SPENTO di default.**

Chiude il PASSO 3 del programma di correttezza
(`docs/superpowers/specs/2026-08-10-correttezza-passo-passo-HANDOUT.md` §4).

---

## 0. Il risultato, in cinque righe

`n_min` ammette un confronto se ogni braccio ha **due campioni**. In quattro studi
del deliverable due campioni sono la **stessa libreria letta su corsie diverse**.
Nel caso peggiore — **GSE173902**, 36 GSM = 18 campioni biologici x 2 corsie, un
solo campione biologico per condizione — la varianza che limma-voom stima e'
rumore di sequenziamento: il suo **SE mediano e' 0,19-0,39 volte** quello dei pari
nello stesso gruppo e quello studio **pesa il 76%** in due meta-analisi su 214.

Contando le librerie invece dei campioni: **6 confronti su 2.152 cadono**, tutti di
GSE173902; **6 righe delle 214** perdono uno studio; **una esce** sotto `k>=3`
(*Staphylococcus epidermidis*, k 3 -> 2), e il deliverable passa da **214 a 213**.
**La previsione depositata prima della misura e' confermata alla lettera.**

Ma il `k` non e' la parte grave. Per *S. aureus* la correlazione di rango fra il
risultato pubblicato e quello corretto e' **−0,02**, per *S. epidermidis* **0,10**:
quelle due meta-analisi sono, in sostanza, il risultato di uno studio senza
repliche biologiche (§5bis).

**Il numero di confronti coinvolti e' un limite inferiore**, non una stima: per i
casi non dichiarati nel titolo non esiste uno strumento (§7.1).

---

## 1. Che cosa e' stato corretto PRIMA di misurare: l'unita' di analisi

Il rilevatore `v4` della sessione del 2026-08-09 raggruppava per
`(cluster, studio, braccio)`. **`n_min` non agisce li'.** Agisce dentro
`.build_group_rem_dispatch_from_stage3()` (`R/stage4-dispatch.R:374`) per **entry
del dispatch**, cioe' per `(studio, treated_group)` dopo la dedup: uno studio con
piu' bracci trattati nello stesso cluster genera **piu' entry**, e il rilevatore
le fondeva in una.

Tutta la misura e' stata rifatta sull'unita' giusta, replicando il loop di
produzione con gli scarti registrati.

> **Caso di accettazione, superato prima di ogni numero.** La replica riproduce il
> dispatch di produzione **entry per entry e campione per campione**: 214 cluster,
> **2.152 entry**, insiemi di trattati e controlli identici, ordine compreso.
> Sui 4.726 record esaminati: 2.152 ammessi, 2.525 gia' sotto `n_min`, 49 doppioni
> di chiave.
> `analysis/audit/2026-08-12-corsie/10-replica-dispatch.R`

**Monotonia, dichiarata:** il conteggio biologico e' sempre `<=` al conteggio dei
campioni, quindi le 2.525 entry gia' cadute non possono risalire. Bastano le 2.152
ammesse.

---

## 2. Tre criteri "autoritativi" provati e SCARTATI

### 2.1 Il BioSample non e' un criterio, in nessuna delle due direzioni

Copertura **100,0%** (18.371 campioni su 18.371 hanno un `SAMN` nel campo
`relation`). E' inutilizzabile lo stesso:

- in **GSE178340** le quattro corsie della stessa libreria (`ATRA1_S4_L001..L004`)
  hanno **quattro BioSample distinti** — l'identificativo eredita l'errore del
  sottomettente;
- l'**unico** SAMN condiviso di tutto il poolato (`SAMN06909706`, GSE98984) copre
  quattro campioni che stanno sui **due bracci opposti** (`treated rep1/rep2` e
  `untreated rep1/rep2`): dedurne identita' avrebbe unito trattato e controllo.

Lo stesso vale per l'identificativo SRA: quattro `SRX` per quattro corsie.

### 2.2 La profondita' non filtra

L'idea che «una corsia e' un libro sottile» e' **falsa**: le corsie di GSE173902
hanno **19,9 M di reads** l'una e quelle di GSE116899 **10,9 M**, sopra la mediana
del corpus (22,3 M, primo quartile 13,5 M). Un pre-filtro sulla profondita' avrebbe
perso due studi su quattro.

### 2.3 Il profilo di espressione genera candidati, non verdetti

Su **313.047 coppie intra-braccio** di tutto il poolato (1.115 studi, Pearson su
log-CPM dei geni espressi):

| | coppie | mediana | minimo |
|---|---:|---:|---:|
| dichiarate corsia dalla regola | 85 | 0,9832 | 0,9773 |
| tutte le altre | 312.962 | 0,9350 | — |

**AUC 0,985** — una coppia-corsia a caso correla piu' di una coppia biologica a
caso nel 98,5% dei casi. **E non serve a niente come classificatore**, ed e' il
punto: a soglia 0,990 ritrova **13 corsie su 85 (15%)** e prende **3.444 coppie
biologiche**; a 0,9963 ritrova **zero** corsie. Repliche biologiche di linee
cellulari arrivano a **0,9988**, corsie di librerie poco profonde scendono a
0,977: le due distribuzioni si attraversano.

> **⚠️ Se si cita l'AUC senza la sensibilita' si dice una cosa falsa.** Sono due
> facce dello stesso dato e vanno riportate insieme.

**Uno strumento sbagliato, corretto in corsa.** La prima versione correlava su
tutti i geni con somma > 0 (oltre 40.000, quasi tutti nella coda quasi-nulla) e
dava 0,88-0,94 ovunque, senza separazione. La coda misura rumore di campionamento,
non identita' del materiale. Rifatta sui geni espressi (CPM >= 1 in almeno meta'
dei campioni), la separazione dentro lo studio compare in **3 studi su 4**.

---

## 3. Resta il titolo — e da solo sbaglia piu' spesso di quanto indovina

Applicata a tutti gli **888.821** campioni dell'H5, la regola del solo titolo
produce **4.360 librerie** da piu' campioni (20.364 campioni, 107 studi). Ma:

> **solo il 45,3% di quelle librerie ha `characteristics_ch1` identici.**

Il controllo negativo ha trovato il falso positivo che ha cambiato il disegno: la
regola unisce i **POZZETTI di una piastra**.

- **GSE145815**: `1001703001_L1` ha `well: L1`, `1001703001_L10` ha `well: L10` — e
  hanno `moi: 0` contro `moi: 0.1`, cioe' **un controllo e un trattato**;
- **GSE124742** (patch-seq), **GSE116672**, **GSE144296**: "corsie" fino a `L23`,
  `L24`, con metadati identici perche' sono cellule dello stesso donatore.

### Le tre guardie, e da dove viene ciascuna

| | regola | da dove |
|---|---|---|
| **G1** | al piu' 8 campioni per libreria | vincolo fisico: un flowcell Illumina ha 8 corsie |
| **G2** | `characteristics_ch1` e `source_name_ch1` identici | due corsie sono lo STESSO materiale |
| **G3** | indice di corsia fra 1 e 8 | `_L24` non e' una corsia |

Effetto sul corpus intero: **4.360 -> 1.717 librerie**, **107 -> 50 studi**
(scarti: 2.150 per metadati diversi, 345 per cardinalita', 6 per indice).
**I quattro studi del deliverable superano tutte e tre le guardie al completo**
(18/18, 8/8, 6/6, 15/15 librerie).

### Una guardia proposta e SCARTATA perche' non misura nulla

L'indice di campione Illumina (`_S<n>_`) e' costante dentro la libreria su
**4.360 librerie su 4.360**: e' vero per costruzione (il token fa parte della
chiave) e non aggiunge informazione. Sarebbe entrata in produzione come prova
senza esserlo.

### Due marcatori NON implementati, e perche'

- **`run N`**: in GSE62544 `STT516_run_1` e `STT516_run_2` possono essere due
  letture della stessa libreria o due esperimenti; nessuna prova nei metadati.
  Tocca **0 entry** delle 214, e **0 librerie** in tutto il corpus sopravvivono
  solo grazie a lui. Una regola che non si sa difendere non entra.
- **il filtro sul single-cell**: 836 delle 1.717 librerie superstiti vengono da
  studi con `singlecellprobability > 0,5` (GSE267774, GSE145668, ...). Nessuna e'
  nel deliverable. Il filtro non serve qui e non e' stato scritto.

---

## 4. Il difetto, quantificato

### 4.1 Che cosa cade

| studio | entry | trattati | controlli | esito |
|---|---:|---|---|---|
| **GSE173902** | 6 | 2 -> **1** | 2 -> **1** | **cadono tutte e 6** |
| GSE115542 (digossina) | 1 | 12 -> 3 | 12 -> 3 | resta |
| GSE178340 | 1 | 12 -> 3 | 12 -> 3 | resta |
| GSE116899 | 1 | 10 -> 5 | 3 -> 2 | resta |

GSE173902 e' uno studio a **18 condizioni, un campione biologico ciascuna**
(`SE.none sam2`, `none.IL4 sam4`, ...), sequenziate su due corsie. Non ha
replicazione biologica: nessuna delle sue 6 righe puo' entrare in una
meta-analisi.

**La verifica che chiude il caso.** Lo Stadio 2 ha diviso i 36 GSM in **22 gruppi
di replica**: 14 da due campioni e 8 da uno. Dei 14 gruppi da due,
**14 su 14 sono le due corsie dello STESSO campione** (`sam19_L001` +
`sam19_L002`, `sam9_L001` + `sam9_L002`, ...). Nessuna eccezione.

E' anche il motivo per cui solo 6 dei 21 confronti dello studio sono arrivati al
pooling: dove il modello ha messo le due corsie in gruppi **separati** (grp_0003 e
grp_0004 sono entrambi «*S. aureus* + IFNg» con un campione ciascuno) il confronto
cade da solo al gate `n_min`. **Il difetto e' passato solo dove il
raggruppamento era, in se', corretto.**

### 4.2 Le sei righe delle 214 che cambiano

| entita' | k | k dopo | geni sig. | k Kish | dominato |
|---|---:|---:|---:|---:|---|
| `NCBITaxon:1282` *Staphylococcus epidermidis* | 3 | **2 -> ESCE** | 1.539 | 1,51 | si |
| `NCBITaxon:1280` *Staphylococcus aureus* | 4 | 3 | 1.356 | 1,50 | si |
| `HGNC:14900` IL22 | 6 | 5 | 1.121 | 3,24 | no |
| `HGNC:6014` IL4 | 10 | 9 | 624 | 4,91 | no |
| `HGNC:5973` IL13 | 12 | 11 | 1.805 | 8,02 | no |
| `HGNC:5438` IFNG | 20 | 19 | 3.579 | 18,16 | no |

> ⚠️ **I nomi vengono da `contrast_entity_label`, non da `canonical_name`.** Per
> due di queste righe `canonical_name` e' sbagliato — dice «IMPDH2» dove l'ID e'
> IL22 e «IL5RA» dove l'ID e' IL13 — e per una terza dice «spin probe» dove
> l'entita' e' l'acido retinoico. **Non e' un difetto nuovo**: tutte e tre sono
> gia' nell'elenco del 2026-08-08
> (`analysis/audit/2026-08-08-deframmentazione/40-canonical-name-ingannevole.csv`,
> 111 righe su 214), verificato prima di riferirlo.

> **Caso di accettazione:** il `k` ricostruito dal dispatch coincide con
> `k_effective` del deliverable su **tutte e 214 le righe, scarto massimo 0**.

### 4.3 Il peso — quello che il solo `k` non dice

Quota mediana del peso REM sui geni significativi (macchina di produzione,
`compute_pooling_weight_shares()`):

| meta-analisi | studio | quota | equipeso | rapporto | SE / SE dei pari |
|---|---|---:|---:|---:|---:|
| *S. aureus* | GSE173902 | **76,4%** | 25,0% | **3,05** | **0,19** |
| *S. epidermidis* | GSE173902 | **75,4%** | 33,3% | **2,26** | 0,24 |
| IMPDH2 | GSE173902 | 24,0% | 16,7% | 1,44 | 0,39 |
| IL5RA | GSE173902 | 11,4% | 8,3% | 1,37 | 0,28 |
| IL4 | GSE173902 | 12,4% | 10,0% | 1,24 | 0,24 |
| IFNG | GSE173902 | 5,9% | 5,0% | 1,18 | 0,38 |
| spin probe | GSE178340 | 14,5% | 20,0% | 0,73 | 0,44 |
| digossina | GSE115542 | 3,5% | 33,3% | 0,10 | 0,71 |
| artrite reumatoide | GSE116899 | 0,0% | 20,0% | 0,00 | 1,02 |

**Due meta-analisi su 214 sono guidate al 76% da uno studio senza replicazione
biologica.** Gli altri tre studi, che sopravvivono al gate, non dominano nulla.

---

## 5. L'esperimento: sommare le corsie, una variabile sola

Stessa funzione DE di produzione, stessi campioni, stessi geni; cambia **solo** se
le corsie della stessa libreria vengono sommate prima del fit.

| studio | n | n dopo | SE prima | SE dopo | **SE dopo/prima** | Spearman logFC | scarto mediano logFC |
|---|---:|---:|---:|---:|---:|---:|---:|
| GSE115542 | 12/12 | 3/3 | 0,213 | 0,454 | **2,16** | 0,996 | 0,030 |
| GSE178340 | 12/12 | 3/3 | 0,058 | 0,068 | **1,20** | 0,995 | 0,003 |
| GSE116899 | 10/3 | 5/2 | 0,285 | 0,358 | **1,31** | 0,969 | 0,044 |
| GSE173902 | 2/2 | 1/1 | — | — | **non calcolabile** | — | — |

### Una previsione depositata e FALSIFICATA, con la spiegazione misurata

Avevo previsto una crescita dell'SE di circa `sqrt(4) = 2` per gli studi a quattro
corsie. **Vero per GSE115542 (2,16), falso per GSE178340 (1,20).**

Scomponendo `SE = sd * sqrt(1/n1 + 1/n2)`:

| studio | sd dopo/prima | fattore di `n` | prodotto | osservato |
|---|---:|---:|---:|---:|
| GSE115542 | 1,07 | 2,00 | 2,13 | 2,16 |
| GSE178340 | **0,58** | 2,00 | 1,17 | 1,20 |
| GSE116899 | 0,99 | 1,27 | 1,26 | 1,31 |

In GSE178340 la dispersione **fra le corsie** era una parte consistente della
varianza fra i 12 campioni: sommarle la toglie, e i due effetti in parte si
annullano. **Contare le corsie come repliche gonfia insieme `n` e la varianza
stimata**, e quanto i due si compensino dipende dalla profondita'. La regola
`sqrt(numero di corsie)` non vale.

---

## 5bis. Che cosa cambia nel risultato poolato

Ri-pooling con la macchina di produzione (`pool_cluster_leaving_out`), influenza
misurata sull'insieme FISSO dei geni significativi del pooling pieno. Le prime tre
righe cambiano **solo** perche' le corsie sono sommate (nessuno studio esce); le
altre sei perdono GSE173902.

| entita' | k | k dopo | geni sig. | dopo | **persi** | Spearman |
|---|---:|---:|---:|---:|---:|---:|
| *S. epidermidis* | 3 | 2 | 1.539 | 483 | **68,6%** | **0,10** |
| *S. aureus* | 4 | 3 | 1.356 | 286 | **78,9%** | **−0,02** |
| IL22 | 6 | 5 | 1.121 | 702 | 37,4% | 0,52 |
| IL4 | 10 | 9 | 624 | 424 | 32,1% | 0,76 |
| IL13 | 12 | 11 | 1.805 | 1.273 | 29,5% | 0,77 |
| IFNG | 20 | 19 | 3.579 | 2.913 | 18,6% | 0,94 |
| digossina | 3 | 3 | 766 | 640 | 16,4% | 0,69 |
| acido retinoico | 5 | 5 | 983 | 863 | 12,2% | 0,84 |
| artrite reumatoide | 5 | 5 | 117 | 96 | 17,9% | 0,87 |

**Due letture, e vanno tenute separate.**

1. **Il fatto.** Per *S. aureus* la correlazione di rango fra il risultato
   pubblicato e quello corretto e' **−0,02**: il ranking dei geni non ha
   praticamente nulla in comune. Quella meta-analisi, e quella di
   *S. epidermidis*, sono in sostanza il risultato di GSE173902 — uno studio con
   **un campione biologico per condizione**.
2. **Il limite.** Togliere uno studio da un gruppo a k=3 o k=4 sposta sempre
   moltissimo: la sola grandezza dello spostamento **non prova** che il risultato
   pubblicato sia sbagliato. Cio' che lo argomenta e' il **meccanismo**, misurato a
   parte: SE 0,19-0,24 volte quello dei pari e peso 2,3-3,1 volte l'equipeso, per
   uno studio che non ha repliche biologiche. Il confronto con le rimozioni degli
   altri studi dello stesso gruppo e' in §5ter.

**Anche senza che nessuno studio esca, correggere l'SE cambia il risultato**: le
tre righe in fondo perdono dal 12% al 18% dei geni significativi con la sola somma
delle corsie. Il difetto non e' solo una questione di `k`.

## 5ter. Il nullo appaiato: in tre gruppi su sei GSE173902 non e' speciale

Qualunque rimozione sposta una meta-analisi. Per non ripetere l'errore che questo
progetto ha gia' corretto il 2026-08-10, in ognuno dei 6 gruppi si e' tolto **a
turno ogni altro studio** (55 pooling) e si e' guardato dove cade GSE173902.

| entita' | k | GSE173902: geni persi (Spearman) | le altre rimozioni | e' la piu' influente? |
|---|---:|---|---|---|
| *S. aureus* | 4 | **79%** (−0,02) | 22-33% (0,46-0,75) | **si** |
| *S. epidermidis* | 3 | **69%** (0,10) | 30-45% (0,42-0,64) | **si** |
| IFNG | 20 | 19% (0,94) | 4-18% (0,89-0,99) | si, di misura |
| IL22 | 6 | 37% (0,52) | 18-44% (0,50-0,92) | **no** |
| IL4 | 10 | 32% (0,76) | 9-40% (0,55-0,93) | **no** |
| IL13 | 12 | 29% (0,78) | 8-30% (0,72-0,94) | **no** |

**In tre gruppi su sei l'influenza di GSE173902 e' dentro il campo delle rimozioni
ordinarie.** Li' il motivo per toglierlo non e' che sposta il risultato — non piu'
degli altri — ma che **quel confronto non ha repliche biologiche**: e' un difetto
di disegno, non di influenza. Nei due gruppi di stafilococco le due cose
coincidono, ed e' il caso in cui il risultato pubblicato non sopravvive.

*(Controllo di determinismo: i pooling sono stati fatti una prima volta in serie e
una seconda in parallelo su 14 worker. Sul gruppo di* S. epidermidis *i tre valori
sono 0,102 / 0,637 / 0,416 in entrambe le esecuzioni.)*

## 6. Il codice

`R/stage4-technical-lanes.R` (nuovo, **23 casi di accettazione / 41 asserzioni**,
di cui 10 blocchi negativi contro 4 positivi — i negativi sono piu' numerosi
apposta, e' la direzione in cui uno strumento sbaglia senza dare segno), piu'
`test-stage4-technical-lanes-integration.R` (4 casi / 10 asserzioni) che si
intesta il collegamento col percorso di produzione:

- `build_lane_library_lookup(h5_metadata)` — la corrispondenza campione ->
  libreria, con le tre guardie e il registro degli scarti;
- `.n_biological(gsms, lookup)` — conta le librerie, sui campioni **distinti**;
- `.collapse_technical_lanes(counts, treatment, lookup)` — somma le corsie, rifa'
  il vettore dei ruoli, **si ferma** se una libreria sta sui due bracci.

Due consumatori, una sola corrispondenza:

- `.build_group_rem_dispatch_from_stage3(..., lane_lookup=)` — `n_min` conta le
  librerie;
- `.run_per_study_de_all(..., lane_lookup=)` — somma le conte prima del DE, e
  registra in `attr(out, "lane_collapses")`;
- `.drop_role_conflicts(..., lane_lookup=)` — dopo lo scarto dei campioni ambigui
  il braccio deve avere due **librerie**, non due campioni.

Interruttore: `stage4_default_config()$rem_group$collapse_technical_lanes`,
**FALSE** di default.

### Le accettazioni, sui dati veri

| | |
|---|---|
| corrispondenza costruita su 888.821 campioni | 5.721 campioni in 1.810 librerie, 17 s |
| entry toccate e cadute, contro la misura a mano | **9 e 6, identiche** |
| conteggi biologici per braccio | **identici** |
| dispatch con la corrispondenza accesa | 2.152 -> 2.146 entry, **6 cluster con k cambiato, gli stessi** |
| ri-pooling che riproduce il pubblicato | **scarto 0,000e+00** su logFC, SE, tau2, I2 in tutti e 9 i cluster |
| suite `stage4` | **0 FAIL, 0 ERROR** |
| suite INTERA (tutti i file di test) | **0 fallimenti** |

**Con `lane_lookup = NULL` non cambia nulla — verificato, non assunto.** Il codice
di prima contava `length(treated)`, il nuovo conta i campioni **distinti**: sono lo
stesso numero solo se nessun `replicate_group` ripete un campione. Controllati
tutti: **0 su 186.269**.

**Differenza deliberata rispetto alla misura a mano:** il pacchetto riconosce anche
la scrittura `lane N` per esteso, che l'estrattore a mano bloccava. Sono **+93
librerie, tutte e 93 con "lane" nel titolo, nessuna nel deliverable**; **zero
librerie perse.**

---

## 7. I limiti, in ordine di gravita'

1. **I falsi negativi non sono esclusi, e non esiste uno strumento per farlo.** Se
   un sottomettente ha spezzato una libreria in corsie senza dichiararlo nel
   titolo, nessuno dei tre criteri lo vede: il BioSample no (§2.1), la profondita'
   no (§2.2), il profilo no (§2.3, e **7.185 coppie non dichiarate su 313.047
   correlano almeno quanto una corsia confermata**). Il difetto misurato qui e'
   quindi un **limite inferiore**.
2. **La regola e' lessicale.** Riconosce cio' che il titolo dichiara, con tre
   guardie che ne tagliano il 61% dei casi corpus-wide. Non e' un criterio
   biologico.
3. **La correlazione conferma in 3 studi su 4.** In GSE178340 una coppia biologica
   (`Ctrl1` contro `Ctrl2`, r = 0,9850) supera la coppia-corsia piu' debole
   (0,9814): li' la prova e' la **struttura del titolo** (`ATRA1_S4_L001..L004`,
   dove `S4` e' l'indice di libreria e `L00x` la corsia nel formato bcl2fastq) e i
   metadati identici, non il profilo.
4. **La cardinalita' 8 e' un vincolo di piattaforma, non una legge.** Una libreria
   sequenziata su due flowcell da 8 corsie sarebbe bloccata da G1. Non ne esistono
   nel poolato; su un altro corpus il numero va rivisto.
5. **Il single-cell non e' filtrato** (§3).

---

## 8. Il materiale

| | |
|---|---|
| replica del dispatch e accettazione | `analysis/audit/2026-08-12-corsie/10-replica-dispatch.R` |
| metadati e BioSample | `20-metadati.R`, `22-profondita.R` |
| candidati sull'unita' giusta | `30-candidati.R` |
| correlazione mirata e v2 | `41-correlazione-mirata.R`, `42-correlazione-v2.R` |
| screening completo (313.047 coppie) | `43-screening-completo.R`, `44-discriminazione.R` |
| effetto sulle 214 | `50-effetto-sui-214.R` |
| peso e SE | `60-peso.R` |
| esperimento delle corsie sommate | `80-esperimento-corsie.R` |
| ampiezza, falsi positivi, guardie | `90-ampiezza-regola.R`, `91-falsi-positivi.R`, `92-guardie.R`, `93-g4.R` |
| validazione del pacchetto sui dati veri | `94-validazione-pacchetto.R`, `95-diff-regole.R` |
| controllo del ramo NULL | `98-controllo-nullo.R`, `98b-libreria-sui-due-bracci.R` |
| influenza sul poolato | `97-influenza.R` |
| codice | `R/stage4-technical-lanes.R`, `tests/testthat/test-stage4-technical-lanes.R` |

---

## 9. La decisione, che non e' mia

Il meccanismo e' spento. Accenderlo cambia il deliverable e richiede un re-pool.
Le opzioni sono due, e **non sono equivalenti**:

- **solo il gate** (`n_min` conta le librerie): fa cadere le 6 entry di GSE173902,
  ma lascia GSE115542, GSE178340 e GSE116899 con `n` gonfiato e SE deflazionato;
- **il collasso** (le corsie si sommano prima del DE): fa cadere le stesse 6 entry
  — dopo la somma i loro bracci hanno un campione — **e in piu'** corregge l'SE dei
  tre che restano. **Il collasso contiene il gate**; il gate da solo lascia meta'
  del difetto in piedi.
