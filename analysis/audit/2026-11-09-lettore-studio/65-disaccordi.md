# PROVA DA BUTTARE: lettura di tutti i disaccordi del lettore v0 contro Expression Atlas

Generato da `65-disaccordi.R` dalle tabelle della misura (`64-*`, `66-forma-*`) e dalle cause lette a mano
(`65-cause-studi.txt`, `65-cause-confronti.txt`). **Audit interno:** le cause le ha lette un agente Claude sul
materiale di `65-materiale.txt` (vista, uscita del modello, tabella di Atlas, incrocio dei gruppi, registro delle
coppie, per ognuno dei 47 studi di sviluppo). Non è una misura dell'articolo. Gli 82 studi di giudizio non sono stati aperti.

## Che cosa è stato letto

Le unità di disaccordo sono **145**, in 41 studi su 47. Lo script le prende dalle tabelle della misura e si ferma
se una resta senza causa.

| unità | numero |
|---|---|
| studio che il lettore non chiude | 24 |
| studio chiuso con partizione non identica | 9 |
| confronto di Atlas non ritrovato | 111 |
|   di cui nel denominatore della misura (b), classe `rispetta` | 83 |
|   di cui fuori (`piu_fattori`, `non_formabile`) | 28 |
| confronto del lettore giudicato errore, misura (c) | 1 |

Senza disaccordi: GSE53280, GSE54846, GSE56235, GSE58326, GSE59781, GSE71421.

Ogni unità ha una **prima causa** (il primo difetto che la misura principale incontra) e un **resto** (che cosa
resta quando la prima causa è tolta). Il resto è `niente_misurato` quando la sensibilità sulla forma delle voci
(`66-forma-*`) ritrova il confronto, `niente_letto` quando la lettura non vede altro, `non_osservato` quando lo
studio non chiude nemmeno nella sensibilità e la lettura non può dire che cosa resta.

## Le cause

Cause ammesse dal piano: `vista`, `schema`, `modello`, `curatore` (con la prova), `strumento`.

| causa | che cosa vuol dire | chi può toglierla | unità (prima causa) | unità (resto) | studi (prima, resto o in più) |
|---|---|---|---|---|---|
| modello/forma_voci | una voce di `assignment` porta più valori di quante sono le colonne di fonte | schema | 68 | 0 | 18 |
| modello/non_coperta | una combinazione di valori della tabella resta senza voce (le voci hanno la forma giusta) | modello | 15 | 0 | 4 |
| modello/mappa_ambigua | la stessa combinazione di valori ha due livelli | modello | 3 | 0 | 1 |
| modello/fattore_dal_titolo | un fattore tecnico o di replica letto dal titolo o da un identificativo: un livello per campione | modello | 27 | 18 | 13 |
| modello/fattore_doppio | due fattori scritti dalla stessa informazione | modello | 1 | 11 | 5 |
| modello/ruolo_soggetto | ruolo di soggetto sbagliato (una colonna di condizione letta come donatore, o il passaggio scritto come fattore) | modello | 1 | 0 | 3 |
| modello/base | livello di base non scritto dove c'è | modello | 1 | 0 | 1 |
| modello/livello | livello sbagliato per un gruppo (controlli a «not stated», o un livello dove serviva «not stated») | modello | 4 | 3 | 2 |
| schema/context_senza_base | per schema un fattore di contesto non ha livello di base: il lettore non può scrivere il confronto fra due condizioni di coltura o due tipi cellulari | schema | 1 | 2 | 2 |
| schema/soggetto_NA | lo schema non dice quali valori di una colonna di soggetto valgono «non scritto» (la stringa «NA») | schema | 0 | 5 | 1 |
| schema/fattore_annidato | un fattore che esiste solo dentro un livello di un altro (sottotipo, stadio): schema e prompt non dicono come scriverlo | schema | 0 | 16 | 4 |
| curatore/tempo_zero | Atlas usa il tempo zero come controllo | non_serve | 10 | 4 | 3 |
| curatore/riferimento | Atlas usa come riferimento un gruppo che non è un controllo | non_serve | 7 | 0 | 1 |
| curatore/repliche | Atlas tratta come repliche campioni che differiscono in una variabile sperimentale | non_serve | 0 | 2 | 1 |
| curatore/errore_campione | Atlas mette un campione nel gruppo sbagliato | non_serve | 2 | 3 | 2 |
| curatore/fattore_ignorato | Atlas ignora una colonna di GEO che distingue i campioni | non_serve | 2 | 2 | 2 |
| curatore/fattori_combinati | Atlas confronta due gruppi che differiscono in due fattori veri | non_serve | 1 | 0 | 1 |
| strumento/universo | il confronto di Atlas non ha campioni di un braccio nell'universo della misura | non_serve | 1 | 0 | 1 |
| strumento/fattori_ridondanti | la misura (c) conta come due fattori la stessa differenza scritta due volte da Atlas | strumento | 1 | 0 | 1 |

`chi può toglierla`: `schema` = un cambio dello schema o del prompt la può togliere. Per la forma delle voci l'effetto è
misurato dalla sensibilità (`66-forma-*`). Per le altre tre è una proposta: questa prova non l'ha misurata. `modello` = serve un
modello che legge meglio, ed è una **ipotesi non misurata** (questa prova ha un modello solo). `non_serve` = non è un
errore del lettore. `strumento` = è un limite della misura. La causa `vista` non è la prima causa di nessuna unità:
compare come nota in uno studio (GSE147507).

### Prima causa per tipo di unità

|  | vista | schema | modello | curatore | strumento | totale |
|---|---|---|---|---|---|---|
| studio_non_chiuso | 0 | 0 | 24 | 0 | 0 | 24 |
| partizione_non_identica | 0 | 0 | 7 | 2 | 0 | 9 |
| atlas_non_ritrovato | 0 | 1 | 89 | 20 | 1 | 111 |
| lettore_errore | 0 | 0 | 0 | 0 | 1 | 1 |

### Che cosa resta, tolta la prima causa

|  | curatore/errore_campione | curatore/fattore_ignorato | curatore/repliche | curatore/tempo_zero | modello/fattore_dal_titolo | modello/fattore_doppio | modello/livello | niente_letto | niente_misurato | non_osservato | schema/context_senza_base | schema/fattore_annidato | schema/soggetto_NA | totale |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| curatore/errore_campione | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | 0 | 0 | 2 |
| curatore/fattore_ignorato | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | 0 | 0 | 2 |
| curatore/fattori_combinati | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| curatore/riferimento | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 7 | 0 | 0 | 0 | 0 | 0 | 7 |
| curatore/tempo_zero | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 10 | 0 | 0 | 0 | 0 | 0 | 10 |
| modello/base | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| modello/fattore_dal_titolo | 0 | 2 | 0 | 0 | 0 | 11 | 0 | 5 | 0 | 7 | 2 | 0 | 0 | 27 |
| modello/fattore_doppio | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| modello/forma_voci | 3 | 0 | 2 | 4 | 15 | 0 | 3 | 0 | 14 | 15 | 0 | 7 | 5 | 68 |
| modello/livello | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 4 | 0 | 4 |
| modello/mappa_ambigua | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 3 | 0 | 0 | 0 | 3 |
| modello/non_coperta | 0 | 0 | 0 | 0 | 3 | 0 | 0 | 0 | 0 | 7 | 0 | 5 | 0 | 15 |
| modello/ruolo_soggetto | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| schema/context_senza_base | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| strumento/fattori_ridondanti | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| strumento/universo | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |

### Esito della catena

`non_errore`: nella catena c'è una scelta o un errore del curatore, o un limite della misura. `forma`: basta leggere
le voci malformate (misurato). `schema`: ogni causa è di schema. `modello`: almeno una causa chiede un modello che
legge meglio (non misurato). `ignoto`: lo studio non chiude nemmeno nella sensibilità.

|  | forma | ignoto | modello | non_errore | schema | totale |
|---|---|---|---|---|---|---|
| studio_non_chiuso | 6 | 4 | 10 | 3 | 1 | 24 |
| partizione_non_identica | 0 | 0 | 6 | 3 | 0 | 9 |
| atlas_non_ritrovato | 8 | 11 | 52 | 28 | 12 | 111 |
| lettore_errore | 0 | 0 | 0 | 1 | 0 | 1 |

Dei 93 confronti di Atlas nel denominatore della misura (b), il lettore ne ritrova 10. Dei 83 non ritrovati, 17 hanno
nella catena una scelta o un errore del curatore: un lettore senza difetti non li ritrova. La pipeline di oggi ne ritrova 6,
tutti con il tempo zero come controllo (GSE49608). Questo è un risultato di lettura, non una misura: le misure
depositate restano quelle di `64-out.txt`.

## La classe «livello combinato»

Il piano chiede di contare a parte i casi in cui i curatori scrivono due agenti come un livello solo e il lettore
come due fattori. **Disaccordi di questa classe: 0.** Nei 47 studi c'è un solo livello di Atlas con due agenti
(GSE52778, «albuterol and dexamethasone»): il lettore lo scrive come un livello solo, come Atlas, e con la forma
tollerata ritrova il confronto. Negli studi che non chiudono nemmeno nella sensibilità la classe non è giudicabile.

La classe vicina è più frequente: Atlas confronta due gruppi che differiscono in più di uno dei **suoi** fattori (classe `piu_fattori`): 29 confronti in 8 studi,
fuori dal denominatore della misura (b). Il lettore ne ritrova 2 nella misura principale e 5 nella sensibilità. Per sottoclasse dei 27 non ritrovati:

|  | GSE52194 | GSE56691 | GSE56787 | GSE57945 | GSE60340 | GSE65335 | GSE66207 | GSE69597 | totale |
|---|---|---|---|---|---|---|---|---|---|
| curatore/errore_campione (resto niente_letto) | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| curatore/fattori_combinati (resto niente_letto) | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 1 |
| curatore/riferimento (resto niente_letto) | 0 | 0 | 0 | 0 | 5 | 0 | 0 | 0 | 5 |
| curatore/tempo_zero | 0 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 3 |
| modello/forma_voci (resto niente_misurato) | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 3 |
| schema/fattore_annidato | 0 | 0 | 0 | 5 | 0 | 0 | 3 | 6 | 14 |

## Una riga per studio

| studio | disaccordi | che cosa differisce | prima causa | resto | in più | prova |
|---|---|---|---|---|---|---|
| GSE103170 | partizione piu_fine; 1 confronti di Atlas non ritrovati | Il modello scrive un fattore tecnico `sample` dal titolo, con un livello per campione: 6 gruppi di 1 campione contro i 2 gruppi di 3 di Atlas. Nessun confronto ha 2 campioni per braccio. | modello/fattore_dal_titolo | niente_letto |  | Uscita del modello: fattore `sample` (technical), 6 livelli; la colonna `disease` basta a dare i 2 gruppi. |
| GSE103501 | 4 confronti di Atlas non ritrovati | Atlas confronta le cellule stimolate in vitro per 6 ore con le cellule ex vivo a 0 ore («none»). Il lettore tiene `group` (ex vivo, in vitro) e `timepoint` come fattori distinti e non forma il confronto: registro `piu_di_un_fattore` 10. Il lettore forma LPS contro medium, che Atlas non elenca (2 confronti, giudizio «coerente»). | curatore/tempo_zero | niente_letto |  | Vista: il gruppo «none» di Atlas ha `treatment=exvivo`, `group=exvivo`, `timepoint=00h`; gli stimolati hanno `group=invitro`, `timepoint=06h`. |
| GSE112057 | non chiuso; 5 confronti di Atlas non ritrovati | Le 6 voci di `disease_state` portano 5 valori ciascuna invece di 1: l'adattatore non le usa e nessuna combinazione è coperta. Con la forma tollerata la partizione è identica ma il costruttore non forma i 5 confronti: i controlli hanno la stringa «NA» nelle colonne di soggetto (`gender`, `age at diagnosis`, `ancestry`), il costruttore la legge come valore scritto e trova insiemi disgiunti. | modello/forma_voci | niente_misurato; schema/soggetto_NA |  | Note della misura: `voci_malformate: disease_state: 6`; con la forma tollerata lo studio chiude e la partizione è identica. Registro della sensibilità: `soggetti_disgiunti` 5. Lo schema v0 non ha un campo per dire quali valori di una colonna di soggetto valgono «non scritto». |
| GSE147507 | non chiuso; 2 confronti di Atlas non ritrovati | Il modello non scrive la voce per la cella vuota in `cell_type`, `time_after_treatment`, `tissue`, e lascia senza voce 6 combinazioni di `agent`. Lo studio non chiude nemmeno con la forma tollerata. | modello/non_coperta | non_osservato | vista | Motivi: `non_coperta` su 4 fattori. Nota sulla vista: 77 campioni di più sotto-serie con campi diversi, universo di Atlas 14 campioni. |
| GSE41586 | partizione piu_fine; 2 confronti di Atlas non ritrovati | Il modello scrive un fattore `replicate` dal titolo: gruppi di 1 campione. Scrive anche due fattori (`agent`, `treatment`) dalla stessa informazione. | modello/fattore_dal_titolo | modello/fattore_doppio |  | Uscita del modello: `replicate` (technical) con un livello per campione; `agent` e `treatment` hanno la stessa partizione. |
| GSE44379 | non chiuso; 1 confronti di Atlas non ritrovati | Le voci di `treatment` e di `fraction` portano 2 valori invece di 1. Con la forma tollerata resta una scelta del curatore: Atlas tratta come repliche le 8 frazioni del gradiente di saccarosio; il lettore fa di `fraction` un fattore e ha 16 gruppi di 1 campione. | modello/forma_voci | curatore/repliche |  | Titoli dei campioni: `RNAseq_Sucrose_Gradient_[no]arsenite_fraction1..8`, una frazione per campione, nessuna replica dentro la frazione. |
| GSE46665 | non chiuso; 2 confronti di Atlas non ritrovati | Il modello mette più valori della stessa colonna in una voce e usa le sigle dei pazienti come valori di `disease`: 25 combinazioni senza voce. Lo studio non chiude nemmeno con la forma tollerata. | modello/forma_voci | non_osservato |  | Motivi: `non_coperta: disease: 25 combinazioni`; note: `voci_malformate: disease: 9`. |
| GSE47718 | 1 confronti di Atlas non ritrovati | Il modello dà a `source_name_ch1` il ruolo di soggetto (donatore), ma la colonna porta la condizione (fumatore, non fumatore). Il costruttore trova i soggetti dei due bracci disgiunti e non forma il confronto. | modello/ruolo_soggetto | niente_letto |  | Registro: `soggetti_disgiunti`; la partizione è identica a quella di Atlas. |
| GSE49155 | non chiuso; 2 confronti di Atlas non ritrovati | Il modello scrive due voci per la cella vuota di `cell type`, con due livelli diversi. | modello/mappa_ambigua | non_osservato |  | Motivi: `mappa_ambigua: cell_type: 1 combinazioni`, anche con la forma tollerata. |
| GSE49608 | 6 confronti di Atlas non ritrovati | I 6 confronti di Atlas sono tempo contro tempo zero (2, 4, 7 ore contro 0 ore, in due linee). Nello schema il tempo non ha livello di base, e il costruttore non forma confronti fra tempi. Per le regole del progetto il tempo zero come controllo è sempre un errore. | curatore/tempo_zero | niente_letto |  | Nomi dei confronti di Atlas: «'2 hour' vs '0 hour' in 'MDA-LM2'» e simili. La pipeline di oggi li ritrova tutti e 6. |
| GSE50499 | 1 confronti di Atlas non ritrovati | Il modello scrive due fattori (`treatment`, `expression`) dalla stessa informazione: i due gruppi differiscono in due fattori e il costruttore non forma il confronto. | modello/fattore_doppio | niente_letto |  | Registro: `piu_di_un_fattore`; la partizione è identica a quella di Atlas. |
| GSE50760 | non chiuso; 2 confronti di Atlas non ritrovati | Le 3 voci di `disease_state` portano 3 valori invece di 1. Con la forma tollerata resta un errore del curatore: Atlas mette fra i normali un campione che GEO scrive come metastasi (Atlas 19 normali e 17 metastasi, lettore 18 e 18). I due confronti del lettore differiscono da quelli di Atlas per quel campione. | modello/forma_voci | curatore/errore_campione |  | GEO: `source_name_ch1` e `tissue` danno 18/18/18 e il titolo del campione dice «metastasized cancer». Il modello dà a `source_name_ch1` il ruolo di donatore: è un secondo difetto, che qui dà solo un avviso. |
| GSE51261 | partizione piu_fine; 2 confronti di Atlas non ritrovati | Il modello scrive un fattore `replicate` dal titolo: gruppi di 1 campione, nessun confronto. | modello/fattore_dal_titolo | niente_letto |  | Uscita del modello: `replicate` (technical), un livello per campione. |
| GSE52194 | non chiuso; 3 confronti di Atlas non ritrovati | Le 4 voci di `breast_cancer_subtype` portano 3 valori invece di 1. Con la forma tollerata lo studio chiude, la partizione è identica e il lettore ritrova i 3 confronti di Atlas. | modello/forma_voci | niente_misurato |  | Note: `voci_malformate: breast_cancer_subtype: 4`. |
| GSE52778 | non chiuso; 3 confronti di Atlas non ritrovati | Le 14 voci di `agent` portano 4 valori invece di 1. Con la forma tollerata il lettore ritrova i 3 confronti. Il livello con due agenti («albuterol and dexamethasone») è scritto come un livello solo, come in Atlas. | modello/forma_voci | niente_misurato |  | Note: `voci_malformate: agent: 14`. |
| GSE52946 | non chiuso; 1 confronti di Atlas non ritrovati | Le 3 voci di `disease_state` portano più valori di quante sono le colonne di fonte. Con la forma tollerata il lettore ritrova il confronto. | modello/forma_voci | niente_misurato |  | Note: `voci_malformate: disease_state: 3`. |
| GSE56691 | non chiuso; 3 confronti di Atlas non ritrovati | Le voci di `time` portano 3 titoli ciascuna. Lo studio non chiude nemmeno con la forma tollerata. I 3 confronti di Atlas sono composto e dose a 24, 48, 72 ore contro il tempo zero senza composto. | modello/forma_voci | curatore/tempo_zero |  | Nomi dei confronti di Atlas («'GSKJ4; 2 micromole per liter' vs 'none' at '24 hour'») e classe `piu_fattori`. La pipeline di oggi li ritrova tutti e 3. |
| GSE56787 | partizione piu_fine; 1 confronti di Atlas non ritrovati; 1 confronto del lettore giudicato errore | Atlas mette un mioblasto di controllo nel gruppo dei miotubi di controllo (Atlas 3 e 3, lettore 3 e 2 più 1 mioblasto). La partizione del lettore è più fine per questo campione, e il confronto FSHD2 contro controllo nei miotubi non coincide. | curatore/errore_campione; strumento/fattori_ridondanti | niente_letto |  | Vista: `tissue` = «Control myoblasts», titolo `C21_blasts`; in Atlas `organism part` = myotube. |
| GSE57027 | non chiuso; 2 confronti di Atlas non ritrovati | Le 3 voci di `construct` portano 2 valori per una colonna di fonte. Lo studio non chiude nemmeno con la forma tollerata. | modello/forma_voci | non_osservato |  | Note: `voci_malformate: construct: 3`. La pipeline di oggi ritrova i 2 confronti. |
| GSE57116 | non chiuso; 2 confronti di Atlas non ritrovati | Le 14 voci di `replicate`, `time` e `treatment` portano 3 valori. Con la forma tollerata resta il fattore `replicate` dal titolo (gruppi di 1) e un fattore `time` che ripete `treatment`. | modello/forma_voci | modello/fattore_dal_titolo | modello/fattore_doppio | Note: `voci_malformate` su 3 fattori; classe con la forma tollerata: più fine. |
| GSE57945 | non chiuso; 6 confronti di Atlas non ritrovati | Il modello lascia senza voce 3 varianti rare («not IBD» 1 campione in due fattori, «no» 2 campioni). Lo studio non chiude nemmeno con la forma tollerata. | modello/non_coperta | non_osservato; schema/fattore_annidato |  | Motivi: `non_coperta` su `disease`, `inflammation_type`, `deep_ulcer_presence`; le voci hanno la forma giusta. |
| GSE58365 | 1 confronti di Atlas non ritrovati | Il modello non scrive il livello di base del fattore `genotype` (wild type): il costruttore non ha un controllo. | modello/base | niente_letto |  | Registro: `fattore_senza_base`; la partizione è identica. |
| GSE60340 | 7 confronti di Atlas non ritrovati | Atlas confronta ogni gruppo con le cellule immortalizzate spontaneamente (passaggi oltre 200). Il lettore mette la base nelle cellule giovani e non forma confronti contro le immortali. Il lettore non forma nemmeno i suoi confronti, perché scrive `passage` come fattore tecnico: registro `piu_di_un_fattore` 25. | curatore/riferimento | niente_letto | modello/ruolo_soggetto | Nomi dei confronti di Atlas («... vs 'spontaneously immortal cells; control'») e colonna `passages` (oltre 200 contro 10-12, 17-19, 28-30). |
| GSE60585 | partizione piu_fine; 4 confronti di Atlas non ritrovati | Il modello scrive un fattore `replicate` dal titolo (gruppi di 1) e due fattori (`target`, `transfection`) dalla stessa informazione. Mette `molecule subtype` fra le colonne non informative, mentre Atlas ne fa un fattore. | modello/fattore_dal_titolo | modello/fattore_doppio |  | Uscita del modello; classe: più fine. |
| GSE63015 | non chiuso; 1 confronti di Atlas non ritrovati | Le 6 voci di `time` portano più valori di quante sono le colonne di fonte. Con la forma tollerata il lettore ritrova il confronto. | modello/forma_voci | niente_misurato |  | Note: `voci_malformate: time: 6`. |
| GSE63816 | non chiuso; 3 confronti di Atlas non ritrovati | Le voci di `genotype` (22) e di `disease_state` (3) portano 5 valori. Con la forma tollerata lo studio chiude e la partizione è identica. Con la forma tollerata il costruttore non forma i 3 confronti: il modello dà ai normali il livello `control` di `genotype` invece di «not stated», e i gruppi differiscono in due fattori. | modello/forma_voci | niente_misurato; modello/livello | schema/fattore_annidato | Note: `voci_malformate` su 2 fattori. Registro della sensibilità: `piu_di_un_fattore` 8. Il genotipo di ZRSR2 esiste solo dentro la malattia. |
| GSE65335 | 2 confronti di Atlas non ritrovati | Atlas confronta due condizioni di coltura (interfaccia aria-liquido al giorno 14 contro sommerso al giorno 8). Il lettore scrive la condizione di coltura come fattore di contesto, e per schema un contesto non ha livello di base. | curatore/fattori_combinati; schema/context_senza_base | niente_letto |  | Nome del confronto di Atlas; regola del prompt: «A factor of type context, time or technical never has a baseline». |
| GSE66207 | partizione piu_fine; 3 confronti di Atlas non ritrovati | Il modello dà «not stated» ai controlli scritti «Normal, X» (hanno un'altra diagnosi) e scrive la classificazione di Montreal come fattore di stato con 20 voci e base «not applicable». Atlas confronta ogni stadio della malattia con i controlli: per il costruttore i due gruppi differiscono in due fattori. | modello/livello | schema/fattore_annidato |  | Uscita del modello; i 3 confronti di Atlas sono di classe `piu_fattori` (malattia e stadio). |
| GSE66573 | non chiuso; 1 confronti di Atlas non ritrovati | Le 2 voci di `disease_state` hanno la forma sbagliata. Con la forma tollerata resta il fattore `replicate` dal titolo: 14 combinazioni senza voce. | modello/forma_voci | modello/fattore_dal_titolo |  | Motivi con la forma tollerata: `non_coperta: replicate: 14 combinazioni`. |
| GSE67196 | non chiuso; 4 confronti di Atlas non ritrovati | Le voci di `disease`, `tissue` e `sample` hanno la forma sbagliata. Con la forma tollerata resta il fattore `sample` dal titolo, con 53 livelli: gruppi di 1 campione. | modello/forma_voci | modello/fattore_dal_titolo |  | Note: `voci_malformate` su 3 fattori; classe con la forma tollerata: più fine. |
| GSE67812 | 1 confronti di Atlas non ritrovati | Il confronto di Atlas non ha campioni trattati nell'universo della misura: il bacino ha solo i 3 campioni normali. Il confronto è fuori dalle misure per costruzione. | strumento/universo | niente_letto |  | Confronto di Atlas: 0 trattati e 3 controlli nell'universo, classe `non_formabile`. |
| GSE68919 | non chiuso; 1 confronti di Atlas non ritrovati | Le voci di `exosome` portano 2 o 3 titoli ciascuna. Lo studio non chiude nemmeno con la forma tollerata (6 combinazioni senza voce). | modello/forma_voci | non_osservato |  | Note: `voci_malformate: exosome: 3`. |
| GSE69597 | non chiuso; 6 confronti di Atlas non ritrovati | Le voci di `stage` portano più valori di `subgroup`. Lo studio non chiude nemmeno con la forma tollerata. I 6 confronti di Atlas uniscono tre fattori (malattia, fase, esito) contro i normali. | modello/forma_voci | schema/fattore_annidato |  | Note: `voci_malformate: stage: 3`; classe dei confronti di Atlas: `piu_fattori`. |
| GSE71289 | non chiuso; 6 confronti di Atlas non ritrovati | Il modello scrive un fattore tecnico `replicate` dal titolo e non scrive nessuna voce: 42 combinazioni senza voce. | modello/fattore_dal_titolo | non_osservato |  | Motivi: `non_coperta: replicate: 42 combinazioni`, anche con la forma tollerata. |
| GSE71595 | non chiuso; 4 confronti di Atlas non ritrovati | Il modello scrive un fattore `replicate` dal titolo con 4 titoli per voce. La lettera A-D del titolo è il donatore: doveva essere una colonna di soggetto. Il modello dà a `source_name_ch1` il ruolo di donatore, ma la colonna porta il tessuto. | modello/forma_voci | modello/fattore_dal_titolo | modello/ruolo_soggetto | Motivi: `non_coperta: replicate: 14 combinazioni`, anche con la forma tollerata. |
| GSE75852 | partizione piu_fine; 4 confronti di Atlas non ritrovati | Il modello scrive un fattore `replicate` da `description` (12 livelli, gruppi di 1) e un fattore `cell_line` che ripete in modo sbagliato la malattia (iPSC come controllo, progenitore neurale come atassia). | modello/fattore_dal_titolo | modello/fattore_doppio; schema/context_senza_base |  | Uscita del modello; classe: più fine. |
| GSE77598 | partizione piu_fine; 1 confronti di Atlas non ritrovati | Il modello scrive un fattore `sample` dal titolo: gruppi di 1. Senza quel fattore resta l'aplotipo di MERTK, che coincide con la malattia in tutti i campioni: per il costruttore i due gruppi differiscono in due fattori. Atlas ignora l'aplotipo. | modello/fattore_dal_titolo | curatore/fattore_ignorato |  | Vista: `disease` 5 e 3, `mertk haplotype` 5 (rischio) e 3 (non rischio), stessi campioni. |
| GSE78936 | non chiuso; 6 confronti di Atlas non ritrovati | Le voci di `disease` e di `region` portano 3 valori, uno per colonna della tabella, e il valore della malattia non è nella prima posizione. Con la forma tollerata una combinazione ha due livelli. | modello/forma_voci | non_osservato |  | Motivi con la forma tollerata: `mappa_ambigua: disease: 1 combinazioni`. |
| GSE83415 | non chiuso; 1 confronti di Atlas non ritrovati | Il modello dichiara come fonte la colonna `disease stage` ma scrive nelle voci valori presi dal titolo («active_disease», «clinical_remission»): 2 combinazioni senza voce. Scrive anche un fattore tecnico `patient` dal titolo. | modello/non_coperta | non_osservato | modello/fattore_dal_titolo | Note: `voci_in_piu: disease stage: 2`. |
| GSE83687 | non chiuso; 2 confronti di Atlas non ritrovati | Il modello lascia senza voce 1 valore di `tissue` su 14 (`rightcolon_inflamed`, 1 campione). Scrive anche un fattore `sample` dal titolo con 134 livelli. | modello/non_coperta | modello/fattore_dal_titolo |  | Motivi: `non_coperta: tissue: 1 combinazioni, 1 campioni`. |
| GSE93624 | partizione piu_fine; 1 confronti di Atlas non ritrovati | Atlas ignora la colonna `progression to complication` (27 «yes»). Il lettore ne fa un fattore: confronta 182 malati senza complicazione con i 35 controlli (giudizio «coerente»), dove Atlas confronta 209 malati con 35 controlli. | curatore/fattore_ignorato | niente_letto |  | Vista: `progression to complication` «yes» 27, «-» 218. |

## Una riga per unità di disaccordo

`forma` = esito nella sensibilità sulla forma delle voci; `oggi` = esito della pipeline di oggi sullo stesso confronto di Atlas.

| tipo | studio | id | nome | classe | causa | sotto | resto_causa | resto_sotto | esito | forma | oggi |
|---|---|---|---|---|---|---|---|---|---|---|---|
| studio_non_chiuso | GSE112057 |  | non_coperta: disease_state: 6 combinazioni, 182 campioni, per esempio «Crohn's Disease» |  | modello | forma_voci | niente_misurato |  | forma | chiuso/identica |  |
| studio_non_chiuso | GSE147507 |  | non_coperta: cell_type: 1 combinazioni, 57 campioni, per esempio «» // non_coperta: agent: 6 combinazioni, 41 … |  | modello | non_coperta | non_osservato |  | modello | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE44379 |  | non_coperta: treatment: 2 combinazioni, 16 campioni, per esempio «no treatment (control)» // non_coperta: frac… |  | modello | forma_voci | curatore | repliche | non_errore | chiuso/piu_fine |  |
| studio_non_chiuso | GSE46665 |  | non_coperta: disease: 25 combinazioni, 25 campioni, per esempio «DCM_T0» |  | modello | forma_voci | non_osservato |  | ignoto | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE49155 |  | mappa_ambigua: cell_type: 1 combinazioni |  | modello | mappa_ambigua | non_osservato |  | modello | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE50760 |  | non_coperta: disease_state: 3 combinazioni, 54 campioni, per esempio «primary colorectal cancer» |  | modello | forma_voci | curatore | errore_campione | non_errore | chiuso/incrociata |  |
| studio_non_chiuso | GSE52194 |  | non_coperta: breast_cancer_subtype: 4 combinazioni, 20 campioni, per esempio «TNBC Breast Tumor» |  | modello | forma_voci | niente_misurato |  | forma | chiuso/identica |  |
| studio_non_chiuso | GSE52778 |  | non_coperta: agent: 4 combinazioni, 14 campioni, per esempio «Untreated» |  | modello | forma_voci | niente_misurato |  | forma | chiuso/identica |  |
| studio_non_chiuso | GSE52946 |  | non_coperta: disease_state: 3 combinazioni, 19 campioni, per esempio «sALS» |  | modello | forma_voci | niente_misurato |  | forma | chiuso/identica |  |
| studio_non_chiuso | GSE56691 |  | non_coperta: time: 12 combinazioni, 12 campioni, per esempio «RNASEQ_CUTLL1-GSKJ4_24h-replicate1» |  | modello | forma_voci | curatore | tempo_zero | non_errore | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE57027 |  | non_coperta: construct: 3 combinazioni, 9 campioni, per esempio «Halo» |  | modello | forma_voci | non_osservato |  | ignoto | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE57116 |  | non_coperta: replicate: 14 combinazioni, 14 campioni, per esempio «NT-1» // non_coperta: time: 4 combinazioni,… |  | modello | forma_voci | modello | fattore_dal_titolo | modello | chiuso/piu_fine |  |
| studio_non_chiuso | GSE57945 |  | non_coperta: disease: 1 combinazioni, 1 campioni, per esempio «not IBD» // non_coperta: inflammation_type: 1 c… |  | modello | non_coperta | non_osservato |  | modello | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE63015 |  | non_coperta: time: 6 combinazioni, 6 campioni, per esempio «Day 14 Control Neural Progenitior Cells, Replicate… |  | modello | forma_voci | niente_misurato |  | forma | chiuso/identica |  |
| studio_non_chiuso | GSE63816 |  | non_coperta: genotype: 22 combinazioni, 22 campioni, per esempio «ZRSR2 mutant MDS 1» // non_coperta: disease_… |  | modello | forma_voci | niente_misurato |  | forma | chiuso/identica |  |
| studio_non_chiuso | GSE66573 |  | non_coperta: disease_state: 2 combinazioni, 14 campioni, per esempio «healthy» // non_coperta: replicate: 14 c… |  | modello | forma_voci | modello | fattore_dal_titolo | modello | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE67196 |  | non_coperta: disease: 3 combinazioni, 53 campioni, per esempio «c9ALS» // non_coperta: tissue: 2 combinazioni,… |  | modello | forma_voci | modello | fattore_dal_titolo | modello | chiuso/piu_fine |  |
| studio_non_chiuso | GSE68919 |  | non_coperta: exosome: 8 combinazioni, 8 campioni, per esempio «BxPc3 Beta5 integrin KD exo 1» |  | modello | forma_voci | non_osservato |  | ignoto | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE69597 |  | non_coperta: stage: 6 combinazioni, 104 campioni, per esempio «Group 1» |  | modello | forma_voci | schema | fattore_annidato | schema | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE71289 |  | non_coperta: replicate: 42 combinazioni, 42 campioni, per esempio «WT_d17_1» |  | modello | fattore_dal_titolo | non_osservato |  | modello | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE71595 |  | non_coperta: replicate: 14 combinazioni, 14 campioni, per esempio «HC_A_min» |  | modello | forma_voci | modello | fattore_dal_titolo | modello | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE78936 |  | non_coperta: disease: 3 combinazioni, 82 campioni, per esempio «Bipolar Disorder» // non_coperta: region: 3 co… |  | modello | forma_voci | non_osservato |  | ignoto | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE83415 |  | non_coperta: disease stage: 2 combinazioni, 21 campioni, per esempio «JIA patient with active, untreated disea… |  | modello | non_coperta | non_osservato |  | modello | non chiuso/non_chiuso |  |
| studio_non_chiuso | GSE83687 |  | non_coperta: tissue: 1 combinazioni, 1 campioni, per esempio «rightcolon_inflamed» |  | modello | non_coperta | modello | fattore_dal_titolo | modello | non chiuso/non_chiuso |  |
| partizione_non_identica | GSE103170 |  | classe piu_fine |  | modello | fattore_dal_titolo | niente_letto |  | modello | chiuso/piu_fine |  |
| partizione_non_identica | GSE41586 |  | classe piu_fine |  | modello | fattore_dal_titolo | modello | fattore_doppio | modello | chiuso/piu_fine |  |
| partizione_non_identica | GSE51261 |  | classe piu_fine |  | modello | fattore_dal_titolo | niente_letto |  | modello | chiuso/piu_fine |  |
| partizione_non_identica | GSE56787 |  | classe piu_fine |  | curatore | errore_campione | niente_letto |  | non_errore | chiuso/piu_fine |  |
| partizione_non_identica | GSE60585 |  | classe piu_fine |  | modello | fattore_dal_titolo | modello | fattore_doppio | modello | chiuso/piu_fine |  |
| partizione_non_identica | GSE66207 |  | classe piu_fine |  | modello | livello | schema | fattore_annidato | modello | chiuso/piu_fine |  |
| partizione_non_identica | GSE75852 |  | classe piu_fine |  | modello | fattore_dal_titolo | modello | fattore_doppio | modello | chiuso/piu_fine |  |
| partizione_non_identica | GSE77598 |  | classe piu_fine |  | modello | fattore_dal_titolo | curatore | fattore_ignorato | non_errore | chiuso/piu_fine |  |
| partizione_non_identica | GSE93624 |  | classe piu_fine |  | curatore | fattore_ignorato | niente_letto |  | non_errore | chiuso/piu_fine |  |
| atlas_non_ritrovato | GSE103170 | g1_g2 | 'systemic-onset juvenile idiopathic arthritis' vs 'normal' | rispetta | modello | fattore_dal_titolo | niente_letto |  | modello | no | uguale |
| atlas_non_ritrovato | GSE103501 | g3_g1 | 'Growth Medium' vs 'none' in 'normal' | rispetta | curatore | tempo_zero | niente_letto |  | non_errore | no | no |
| atlas_non_ritrovato | GSE103501 | g3_g2 | 'lipopolysaccharide' vs 'none' in 'normal' | rispetta | curatore | tempo_zero | niente_letto |  | non_errore | no | no |
| atlas_non_ritrovato | GSE103501 | g6_g4 | 'Growth Medium' vs 'none' in 'systemic-onset juvenile idiopathic arthritis' | rispetta | curatore | tempo_zero | niente_letto |  | non_errore | no | no |
| atlas_non_ritrovato | GSE103501 | g6_g5 | 'lipopolysaccharide' vs 'none' in 'systemic-onset juvenile idiopathic arthritis' | rispetta | curatore | tempo_zero | niente_letto |  | non_errore | no | no |
| atlas_non_ritrovato | GSE112057 | g2_g1 | 'Crohn disease' vs 'normal' | rispetta | modello | forma_voci | schema | soggetto_NA | schema | no | uguale |
| atlas_non_ritrovato | GSE112057 | g2_g3 | 'oligoarticular juvenile idiopathic arthritis' vs 'normal' | rispetta | modello | forma_voci | schema | soggetto_NA | schema | no | no |
| atlas_non_ritrovato | GSE112057 | g2_g4 | 'polyarticular juvenile idiopathic arthritis' vs 'normal' | rispetta | modello | forma_voci | schema | soggetto_NA | schema | no | no |
| atlas_non_ritrovato | GSE112057 | g2_g5 | 'systemic-onset juvenile idiopathic arthritis' vs 'normal' | rispetta | modello | forma_voci | schema | soggetto_NA | schema | no | no |
| atlas_non_ritrovato | GSE112057 | g2_g6 | 'ulcerative colitis (disease)' vs 'normal' | rispetta | modello | forma_voci | schema | soggetto_NA | schema | no | no |
| atlas_non_ritrovato | GSE147507 | g2_g1 | 'Severe acute respiratory syndrome coronavirus 2 (USA-WA1/2020)' vs 'mock' in 'A549' at '24 hour' | rispetta | modello | non_coperta | non_osservato |  | modello | no | no |
| atlas_non_ritrovato | GSE147507 | g4_g3 | 'Severe acute respiratory syndrome coronavirus 2 (USA-WA1/2020)' vs 'mock' in 'NHBE' at '24 hour' | rispetta | modello | non_coperta | non_osservato |  | modello | no | uguale |
| atlas_non_ritrovato | GSE41586 | g3_g2 | '5-aza-deoxy-cytidine; 5 micromolar' vs 'none' | rispetta | modello | fattore_dal_titolo | modello | fattore_doppio | modello | no | no |
| atlas_non_ritrovato | GSE41586 | g3_g1 | '5-aza-deoxy-cytidine; 10 micromolar' vs 'none' | rispetta | modello | fattore_dal_titolo | modello | fattore_doppio | modello | no | no |
| atlas_non_ritrovato | GSE44379 | g2_g1 | 'arsenite' vs 'control' | rispetta | modello | forma_voci | curatore | repliche | non_errore | no | no |
| atlas_non_ritrovato | GSE46665 | g3_g1 | '180 days after left ventricular assist device placement' vs 'control' | rispetta | modello | forma_voci | non_osservato |  | ignoto | no | no |
| atlas_non_ritrovato | GSE46665 | g3_g2 | '7 days after left ventricular assist device placement' vs 'control' | rispetta | modello | forma_voci | non_osservato |  | ignoto | no | no |
| atlas_non_ritrovato | GSE47718 | g1_g2 | 'smoker' vs 'non-smoker' | rispetta | modello | ruolo_soggetto | niente_letto |  | modello | no | no |
| atlas_non_ritrovato | GSE49155 | g1_g2 | 'premalignant lesion' vs 'normal' | rispetta | modello | mappa_ambigua | non_osservato |  | modello | no | no |
| atlas_non_ritrovato | GSE49155 | g1_g3 | 'squamous cell carcinoma' vs 'normal' | rispetta | modello | mappa_ambigua | non_osservato |  | modello | no | no |
| atlas_non_ritrovato | GSE49608 | g1_g2 | '2 hour' vs '0 hour' in 'MDA-LM2' | rispetta | curatore | tempo_zero | niente_letto |  | non_errore | no | uguale |
| atlas_non_ritrovato | GSE49608 | g1_g3 | '4 hour' vs '0 hour' in 'MDA-LM2' | rispetta | curatore | tempo_zero | niente_letto |  | non_errore | no | uguale |
| atlas_non_ritrovato | GSE49608 | g1_g4 | '7 hour' vs '0 hour' in 'MDA-LM2' | rispetta | curatore | tempo_zero | niente_letto |  | non_errore | no | uguale |
| atlas_non_ritrovato | GSE49608 | g5_g6 | '2 hour' vs '0 hour' in 'MDA-MB-231' | rispetta | curatore | tempo_zero | niente_letto |  | non_errore | no | uguale |
| atlas_non_ritrovato | GSE49608 | g5_g7 | '4 hour' vs '0 hour' in 'MDA-MB-231' | rispetta | curatore | tempo_zero | niente_letto |  | non_errore | no | uguale |
| atlas_non_ritrovato | GSE49608 | g5_g8 | '7 hour' vs '0 hour' in 'MDA-MB-231' | rispetta | curatore | tempo_zero | niente_letto |  | non_errore | no | uguale |
| atlas_non_ritrovato | GSE50499 | g2_g1 | 'MOV10 overexpression' vs 'control' | rispetta | modello | fattore_doppio | niente_letto |  | modello | no | uguale |
| atlas_non_ritrovato | GSE50760 | g2_g1 | 'colorectal cancer metastatic in the liver' vs 'normal' | rispetta | modello | forma_voci | curatore | errore_campione | non_errore | no | no |
| atlas_non_ritrovato | GSE50760 | g2_g3 | 'primary tumor' vs 'normal' | rispetta | modello | forma_voci | curatore | errore_campione | non_errore | no | no |
| atlas_non_ritrovato | GSE51261 | g3_g1 | 'BS69-1 knockdown' vs 'control' | rispetta | modello | fattore_dal_titolo | niente_letto |  | modello | no | no |
| atlas_non_ritrovato | GSE51261 | g3_g2 | 'BS69-2 knockdown' vs 'control' | rispetta | modello | fattore_dal_titolo | niente_letto |  | modello | no | no |
| atlas_non_ritrovato | GSE52194 | g3_g1 | 'HER2 Positive Breast Carcinoma; breast carcinoma' vs 'normal' | piu_fattori | modello | forma_voci | niente_misurato |  | forma | uguale | no |
| atlas_non_ritrovato | GSE52194 | g3_g4 | 'triple-negative breast cancer; breast carcinoma' vs 'normal' | piu_fattori | modello | forma_voci | niente_misurato |  | forma | uguale | no |
| atlas_non_ritrovato | GSE52194 | g3_g2 | 'non-triple-negative breast cancer; breast carcinoma' vs 'normal' | piu_fattori | modello | forma_voci | niente_misurato |  | forma | uguale | no |
| atlas_non_ritrovato | GSE52778 | g4_g1 | 'albuterol' vs 'untreated' | rispetta | modello | forma_voci | niente_misurato |  | forma | uguale | no |
| atlas_non_ritrovato | GSE52778 | g4_g3 | 'dexamethasone' vs 'untreated' | rispetta | modello | forma_voci | niente_misurato |  | forma | uguale | no |
| atlas_non_ritrovato | GSE52778 | g4_g2 | 'albuterol and dexamethasone' vs 'untreated' | rispetta | modello | forma_voci | niente_misurato |  | forma | uguale | no |
| atlas_non_ritrovato | GSE52946 | g1_g2 | 'sporadic ALS' vs 'normal' | rispetta | modello | forma_voci | niente_misurato |  | forma | uguale | no |
| atlas_non_ritrovato | GSE56691 | g4_g1 | 'GSKJ4; 2 micromole per liter' vs 'none' at '24 hour' | piu_fattori | modello | forma_voci | curatore | tempo_zero | non_errore | no | uguale |
| atlas_non_ritrovato | GSE56691 | g4_g2 | 'GSKJ4; 2 micromole per liter' vs 'none' at '48 hour' | piu_fattori | modello | forma_voci | curatore | tempo_zero | non_errore | no | uguale |
| atlas_non_ritrovato | GSE56691 | g4_g3 | 'GSKJ4; 2 micromole per liter' vs 'none' at '72 hour' | piu_fattori | modello | forma_voci | curatore | tempo_zero | non_errore | no | uguale |
| atlas_non_ritrovato | GSE56787 | g5_g3 | 'facioscapulohumeral dystrophy; FSDH2 mutation' vs 'normal' in 'myotube' | piu_fattori | curatore | errore_campione | niente_letto |  | non_errore | no | no |
| atlas_non_ritrovato | GSE57027 | g1_g3 | 'overexpression of Halo-RelA' vs 'control' | rispetta | modello | forma_voci | non_osservato |  | ignoto | no | uguale |
| atlas_non_ritrovato | GSE57027 | g1_g2 | 'overexpression of Halo-NfkB1' vs 'control' | rispetta | modello | forma_voci | non_osservato |  | ignoto | no | uguale |
| atlas_non_ritrovato | GSE57116 | g3_g1 | '3 h DRB 0 min 4sU' vs 'untreated' | rispetta | modello | forma_voci | modello | fattore_dal_titolo | modello | no | no |
| atlas_non_ritrovato | GSE57116 | g3_g2 | '3 h DRB 8 min 4sU' vs 'untreated' | rispetta | modello | forma_voci | modello | fattore_dal_titolo | modello | no | no |
| atlas_non_ritrovato | GSE57945 | g6_g1 | 'Crohn's disease, macroscopic ileal inflammation with deep ulcer' vs 'non inflammatory bowel disease control' | piu_fattori | modello | non_coperta | schema | fattore_annidato | modello | no | no |
| atlas_non_ritrovato | GSE57945 | g6_g2 | 'Crohn's disease, macroscopic ileal inflammation without deep ulcer' vs 'non inflammatory bowel disease contro… | piu_fattori | modello | non_coperta | schema | fattore_annidato | modello | no | no |
| atlas_non_ritrovato | GSE57945 | g6_g3 | 'Crohn's disease, microscopic ileal inflammation without deep ulcer' vs 'non inflammatory bowel disease contro… | piu_fattori | modello | non_coperta | schema | fattore_annidato | modello | no | no |
| atlas_non_ritrovato | GSE57945 | g6_g4 | 'Crohn's disease, normal' vs 'non inflammatory bowel disease control' | piu_fattori | modello | non_coperta | schema | fattore_annidato | modello | no | no |
| atlas_non_ritrovato | GSE57945 | g6_g5 | 'Crohn's disease, undetermined' vs 'non inflammatory bowel disease control' | piu_fattori | modello | non_coperta | schema | fattore_annidato | modello | no | no |
| atlas_non_ritrovato | GSE57945 | g6_g7 | 'ulcerative colitis' vs 'non inflammatory bowel disease control' | rispetta | modello | non_coperta | non_osservato |  | modello | no | no |
| atlas_non_ritrovato | GSE58365 | g2_g1 | 'BCL6 RD2 mutant' vs 'wild type' | rispetta | modello | base | niente_letto |  | modello | no | no |
| atlas_non_ritrovato | GSE60340 | g7_g6 | 'replicatively senescent; grown until growth arrest' vs 'spontaneously immortal cells; control' | piu_fattori | curatore | riferimento | niente_letto |  | non_errore | no | uguale |
| atlas_non_ritrovato | GSE60340 | g7_g1 | 'aging cells' vs 'spontaneously immortal cells; control' | rispetta | curatore | riferimento | niente_letto |  | non_errore | no | no |
| atlas_non_ritrovato | GSE60340 | g7_g8 | 'young cells' vs 'spontaneously immortal cells; control' | rispetta | curatore | riferimento | niente_letto |  | non_errore | no | no |
| atlas_non_ritrovato | GSE60340 | g7_g2 | 'induced into quiescence; serum starved' vs 'spontaneously immortal cells; control' | piu_fattori | curatore | riferimento | niente_letto |  | non_errore | no | uguale |
| atlas_non_ritrovato | GSE60340 | g7_g3 | 'induced into senescence; 5-aza-2-deoxycytidine' vs 'spontaneously immortal cells; control' | piu_fattori | curatore | riferimento | niente_letto |  | non_errore | no | uguale |
| atlas_non_ritrovato | GSE60340 | g7_g4 | 'induced into senescence; adriamycin' vs 'spontaneously immortal cells; control' | piu_fattori | curatore | riferimento | niente_letto |  | non_errore | no | no |
| atlas_non_ritrovato | GSE60340 | g7_g5 | 'induced into senescence; hydrogen peroxide' vs 'spontaneously immortal cells; control' | piu_fattori | curatore | riferimento | niente_letto |  | non_errore | no | uguale |
| atlas_non_ritrovato | GSE60585 | g1_g2 | 'siRNAs against Integrator 11' vs 'control' in 'ribosomal RNA depleted whole cell RNA' | rispetta | modello | fattore_dal_titolo | modello | fattore_doppio | modello | no | no |
| atlas_non_ritrovato | GSE60585 | g1_g3 | 'siRNAs against NELF' vs 'control' in 'ribosomal RNA depleted whole cell RNA' | rispetta | modello | fattore_dal_titolo | modello | fattore_doppio | modello | no | no |
| atlas_non_ritrovato | GSE60585 | g4_g5 | 'siRNAs against Integrator 11' vs 'control' in 'whole-cell RNA' | rispetta | modello | fattore_dal_titolo | modello | fattore_doppio | modello | no | no |
| atlas_non_ritrovato | GSE60585 | g4_g6 | 'siRNAs against NELF' vs 'control' in 'whole-cell RNA' | rispetta | modello | fattore_dal_titolo | modello | fattore_doppio | modello | no | no |
| atlas_non_ritrovato | GSE63015 | g1_g2 | 'fibroblast growth factor 2' vs 'control' | rispetta | modello | forma_voci | niente_misurato |  | forma | uguale | no |
| atlas_non_ritrovato | GSE63816 | g4_g1 | 'erythroleukemia; ZRSR2 shRNA' vs 'normal' | rispetta | modello | forma_voci | modello | livello | modello | no | no |
| atlas_non_ritrovato | GSE63816 | g4_g2 | 'myelodysplastic syndrome; ZRSR2 mutant' vs 'normal' | rispetta | modello | forma_voci | modello | livello | modello | no | no |
| atlas_non_ritrovato | GSE63816 | g4_g3 | 'myelodysplastic syndrome; ZRSR2 wild type' vs 'normal' | rispetta | modello | forma_voci | modello | livello | modello | no | no |
| atlas_non_ritrovato | GSE65335 | g3_g1 | 'interleukin 13; 100 nanogram per milliliter; air-liquid interface (day 14)' vs 'untreated; submerged (day 8)' | piu_fattori | curatore | fattori_combinati | niente_letto |  | non_errore | no | no |
| atlas_non_ritrovato | GSE65335 | g3_g2 | 'untreated; air-liquid interface (day 14)' vs 'untreated; submerged (day 8)' | rispetta | schema | context_senza_base | niente_letto |  | schema | no | no |
| atlas_non_ritrovato | GSE66207 | g4_g3 | 'Crohn's disease; B3, penetrating' vs 'non inflammatory bowel disease control' | piu_fattori | modello | livello | schema | fattore_annidato | modello | no | no |
| atlas_non_ritrovato | GSE66207 | g4_g2 | 'Crohn's disease; B2, stricturing' vs 'non inflammatory bowel disease control' | piu_fattori | modello | livello | schema | fattore_annidato | modello | no | no |
| atlas_non_ritrovato | GSE66207 | g4_g1 | 'Crohn's disease; B1, non-strictuing, non-penetrating' vs 'non inflammatory bowel disease control' | piu_fattori | modello | livello | schema | fattore_annidato | modello | no | no |
| atlas_non_ritrovato | GSE66573 | g1_g2 | 'relapsing-remitting multiple sclerosis' vs 'normal' | rispetta | modello | forma_voci | modello | fattore_dal_titolo | modello | no | no |
| atlas_non_ritrovato | GSE67196 | g5_g1 | 'amyotrophic lateral sclerosis with C9orf72 repeat expansion' vs 'normal' in 'cerebellum' | rispetta | modello | forma_voci | modello | fattore_dal_titolo | modello | no | no |
| atlas_non_ritrovato | GSE67196 | g6_g2 | 'amyotrophic lateral sclerosis with C9orf72 repeat expansion' vs 'normal' in 'frontal cortex' | rispetta | modello | forma_voci | modello | fattore_dal_titolo | modello | no | no |
| atlas_non_ritrovato | GSE67196 | g5_g3 | 'amyotrophic lateral sclerosis without C9orf72 repeat expansion' vs 'normal' in 'cerebellum' | rispetta | modello | forma_voci | modello | fattore_dal_titolo | modello | no | no |
| atlas_non_ritrovato | GSE67196 | g6_g4 | 'amyotrophic lateral sclerosis without C9orf72 repeat expansion' vs 'normal' in 'frontal cortex' | rispetta | modello | forma_voci | modello | fattore_dal_titolo | modello | no | no |
| atlas_non_ritrovato | GSE67812 | g2_g1 | 'Myotonic dystrophy' vs 'normal' | non_formabile | strumento | universo | niente_letto |  | non_errore | no | no |
| atlas_non_ritrovato | GSE68919 | g2_g1 | 'BxPC-3 exosomes' vs 'control' | rispetta | modello | forma_voci | non_osservato |  | ignoto | no | no |
| atlas_non_ritrovato | GSE69597 | g4_g2 | 'brucellosis; acute brucellosis; complete remission' vs 'normal' | piu_fattori | modello | forma_voci | schema | fattore_annidato | schema | no | no |
| atlas_non_ritrovato | GSE69597 | g4_g5 | 'brucellosis; acute brucellosis; reinfection' vs 'normal' | piu_fattori | modello | forma_voci | schema | fattore_annidato | schema | no | no |
| atlas_non_ritrovato | GSE69597 | g4_g6 | 'brucellosis; acute brucellosis; relapse' vs 'normal' | piu_fattori | modello | forma_voci | schema | fattore_annidato | schema | no | no |
| atlas_non_ritrovato | GSE69597 | g4_g3 | 'brucellosis; chronic brucellosis; complete remission' vs 'normal' | piu_fattori | modello | forma_voci | schema | fattore_annidato | schema | no | no |
| atlas_non_ritrovato | GSE69597 | g4_g7 | 'brucellosis; chronic brucellosis; relapse' vs 'normal' | piu_fattori | modello | forma_voci | schema | fattore_annidato | schema | no | no |
| atlas_non_ritrovato | GSE69597 | g4_g1 | 'Leishmaniasis' vs 'normal' | piu_fattori | modello | forma_voci | schema | fattore_annidato | schema | no | no |
| atlas_non_ritrovato | GSE71289 | g4_g1 | 'DISC1 exon 2 mut/mut' vs 'wild type' in 'neural progenitor cell' at 'embryoid body, day 17' | rispetta | modello | fattore_dal_titolo | non_osservato |  | modello | no | no |
| atlas_non_ritrovato | GSE71289 | g4_g2 | 'DISC1 exon 8 mut/mut' vs 'wild type' in 'neural progenitor cell' at 'embryoid body, day 17' | rispetta | modello | fattore_dal_titolo | non_osservato |  | modello | no | no |
| atlas_non_ritrovato | GSE71289 | g4_g3 | 'DISC1 exon 8 wt/mut' vs 'wild type' in 'neural progenitor cell' at 'embryoid body, day 17' | rispetta | modello | fattore_dal_titolo | non_osservato |  | modello | no | no |
| atlas_non_ritrovato | GSE71289 | g8_g5 | 'DISC1 exon 2 mut/mut' vs 'wild type' in 'neuron' at 'embryoid body, day 50' | rispetta | modello | fattore_dal_titolo | non_osservato |  | modello | no | no |
| atlas_non_ritrovato | GSE71289 | g8_g6 | 'DISC1 exon 8 mut/mut' vs 'wild type' in 'neuron' at 'embryoid body, day 50' | rispetta | modello | fattore_dal_titolo | non_osservato |  | modello | no | no |
| atlas_non_ritrovato | GSE71289 | g8_g7 | 'DISC1 exon 8 wt/mut' vs 'wild type' in 'neuron' at 'embryoid body, day 50' | rispetta | modello | fattore_dal_titolo | non_osservato |  | modello | no | no |
| atlas_non_ritrovato | GSE71595 | g2_g1 | 'juvenile idiopathic arthritis' vs 'normal' in 'JQ1; 300 nanomolar' | rispetta | modello | forma_voci | modello | fattore_dal_titolo | modello | no | no |
| atlas_non_ritrovato | GSE71595 | g3_g1 | 'JQ1; 300 nanomolar' vs 'none' in 'juvenile idiopathic arthritis' | rispetta | modello | forma_voci | modello | fattore_dal_titolo | modello | no | uguale |
| atlas_non_ritrovato | GSE71595 | g4_g2 | 'JQ1; 300 nanomolar' vs 'none' in 'normal' | rispetta | modello | forma_voci | modello | fattore_dal_titolo | modello | no | no |
| atlas_non_ritrovato | GSE71595 | g5_g3 | 'juvenile idiopathic arthritis' vs 'normal' in 'none' | rispetta | modello | forma_voci | modello | fattore_dal_titolo | modello | no | no |
| atlas_non_ritrovato | GSE75852 | g2_g1 | 'Ataxia-telangiectasia' vs 'normal' in 'induced pluripotent stem cell' | rispetta | modello | fattore_dal_titolo | modello | fattore_doppio | modello | no | uguale |
| atlas_non_ritrovato | GSE75852 | g4_g3 | 'Ataxia-telangiectasia' vs 'normal' in 'neural stem cell' | rispetta | modello | fattore_dal_titolo | modello | fattore_doppio | modello | no | no |
| atlas_non_ritrovato | GSE75852 | g2_g4 | ' neural stem cell' vs 'induced pluripotent stem cell' in 'normal' | rispetta | modello | fattore_dal_titolo | schema | context_senza_base | modello | no | no |
| atlas_non_ritrovato | GSE75852 | g1_g3 | ' neural stem cell' vs 'induced pluripotent stem cell' in 'Ataxia-telangiectasia' | rispetta | modello | fattore_dal_titolo | schema | context_senza_base | modello | no | no |
| atlas_non_ritrovato | GSE77598 | g2_g1 | 'multiple sclerosis' vs 'normal' | rispetta | modello | fattore_dal_titolo | curatore | fattore_ignorato | non_errore | no | no |
| atlas_non_ritrovato | GSE78936 | g4_g1 | 'bipolar disorder' vs 'normal' in 'Brodmann (1909) area 11' | rispetta | modello | forma_voci | non_osservato |  | ignoto | no | no |
| atlas_non_ritrovato | GSE78936 | g5_g2 | 'bipolar disorder' vs 'normal' in 'Brodmann (1909) area 24' | rispetta | modello | forma_voci | non_osservato |  | ignoto | no | no |
| atlas_non_ritrovato | GSE78936 | g6_g3 | 'bipolar disorder' vs 'normal' in 'Brodmann (1909) area 9' | rispetta | modello | forma_voci | non_osservato |  | ignoto | no | no |
| atlas_non_ritrovato | GSE78936 | g4_g7 | 'schizophrenia' vs 'normal' in 'Brodmann (1909) area 11' | rispetta | modello | forma_voci | non_osservato |  | ignoto | no | no |
| atlas_non_ritrovato | GSE78936 | g5_g8 | 'schizophrenia' vs 'normal' in 'Brodmann (1909) area 24' | rispetta | modello | forma_voci | non_osservato |  | ignoto | no | no |
| atlas_non_ritrovato | GSE78936 | g6_g9 | 'schizophrenia' vs 'normal' in 'Brodmann (1909) area 9' | rispetta | modello | forma_voci | non_osservato |  | ignoto | no | no |
| atlas_non_ritrovato | GSE83415 | g2_g1 | 'active, on treatment' vs 'remission, on treatment' | rispetta | modello | non_coperta | non_osservato |  | modello | no | verso_opposto |
| atlas_non_ritrovato | GSE83687 | g2_g1 | 'Crohn's disease' vs 'normal' | rispetta | modello | non_coperta | modello | fattore_dal_titolo | modello | no | no |
| atlas_non_ritrovato | GSE83687 | g2_g3 | 'ulcerative colitis' vs 'normal' | rispetta | modello | non_coperta | modello | fattore_dal_titolo | modello | no | no |
| atlas_non_ritrovato | GSE93624 | g2_g1 | 'Crohn's disease' vs 'non inflammatory bowel disease control' | rispetta | curatore | fattore_ignorato | niente_letto |  | non_errore | no | no |
| lettore_errore | GSE56787 | g6_g9 | disease: «FSHD2» contro «control» (3/2), giudizio piu_fattori |  | strumento | fattori_ridondanti | niente_letto |  | non_errore |  |  |

## Fuori dalle unità: gli errori del lettore nella sola sensibilità

| studio | id | causa | sotto | differenza |
|---|---|---|---|---|
| GSE50760 | g2_g1 | curatore | errore_campione | Solo nella sensibilità: il braccio «metastasis» del lettore (18 campioni) contiene il campione che Atlas mette fra i normali, e la misura lo giudica `braccio_misto`. È l'errore del curatore già scritto per lo studio. |

Le differenze e le prove dei singoli confronti con una causa diversa da quella del loro studio:

| studio | tipo | id | causa | sotto | resto_causa | resto_sotto | differenza |
|---|---|---|---|---|---|---|---|
| GSE57945 | atlas | g6_g1 | modello | non_coperta | schema | fattore_annidato | Atlas unisce malattia e istologia in un confronto (classe `piu_fattori`). |
| GSE57945 | atlas | g6_g2 | modello | non_coperta | schema | fattore_annidato | Atlas unisce malattia e istologia in un confronto (classe `piu_fattori`). |
| GSE57945 | atlas | g6_g3 | modello | non_coperta | schema | fattore_annidato | Atlas unisce malattia e istologia in un confronto (classe `piu_fattori`). |
| GSE57945 | atlas | g6_g4 | modello | non_coperta | schema | fattore_annidato | Atlas unisce malattia e istologia in un confronto (classe `piu_fattori`). |
| GSE57945 | atlas | g6_g5 | modello | non_coperta | schema | fattore_annidato | Atlas unisce malattia e istologia in un confronto (classe `piu_fattori`). |
| GSE65335 | atlas | g3_g1 | curatore | fattori_combinati | niente_letto |  | Atlas confronta interleuchina 13 all'interfaccia aria-liquido (giorno 14) con il non trattato sommerso (giorno 8): due fattori diversi. La definizione del progetto non ammette questo confronto. |
| GSE75852 | atlas | g2_g4 | modello | fattore_dal_titolo | schema | context_senza_base | Atlas confronta due tipi cellulari (staminale neurale contro iPSC): per schema un contesto non ha livello di base. |
| GSE75852 | atlas | g1_g3 | modello | fattore_dal_titolo | schema | context_senza_base | Atlas confronta due tipi cellulari (staminale neurale contro iPSC): per schema un contesto non ha livello di base. |
| GSE56787 | lettore | g6_g9 | strumento | fattori_ridondanti | niente_letto |  | Confronto del lettore FSHD2 contro controllo nei miotubi (3 contro 2). Non coincide con quello di Atlas per l'errore del curatore sul campione. La misura lo giudica `piu_fattori` perché Atlas scrive la stessa differenza in due fattori (`disease` e `genotype`). |
