# PROVA DA BUTTARE: lettura di tutti i disaccordi del lettore v1 contro Expression Atlas (S12r2)

Generato da `26-disaccordi.R` dalle tabelle della misura (`24-*`, prima corsa, lettura principale), dalle sensibilità
dichiarate dopo i numeri (`27-forma-*`, `27-forma-na-*`) e dalle cause lette a mano (`26-cause-<modello>.txt`).
**Audit interno:** le cause le ha lette un agente Claude sul materiale di `25-materiale-<modello>.txt` (vista, uscita
del modello, tabella di Atlas, incrocio dei gruppi, registro delle coppie). Non è una misura dell'articolo. Gli 82
studi di giudizio non sono stati aperti. I 47 studi di sviluppo servono qui una seconda volta.

Modelli: M = Mistral-Small 3.2 (24B) con `repetition_penalty` 1,1; M0 = lo stesso senza penalità; G1 =
Mistral-Small-4-119B; G2 = Qwen3.5-122B-A10B (se misurato).

## Le unità di disaccordo

| modello | studi con unità | unità | studio non chiuso | partizione non identica | confronto del riferimento non ritrovato | confronto del lettore giudicato errore |
|---|---|---|---|---|---|---|
| M | 20 | 63 | 13 | 3 | 47 | 0 |
| M0 | 21 | 64 | 14 | 3 | 47 | 0 |
| G1 | 24 | 93 | 17 | 4 | 65 | 7 |

Ogni unità ha una **prima causa** (il primo difetto che la misura principale incontra) e un **resto** (che cosa resta
quando la prima causa è tolta). Il resto è `niente_misurato` quando la sensibilità più larga (`27-forma-na-*`) toglie il
disaccordo, `niente_letto` quando la lettura non vede altro, `non_osservato` quando lo studio non chiude nemmeno nella
sensibilità e la lettura non può dire che cosa resta. Lo script si ferma se «niente_misurato» non coincide con la misura.

## Le cause e chi le può togliere

| causa | che cosa vuol dire | chi può toglierla | M unità (prima causa) | M studi (prima, resto o in più) | M0 unità (prima causa) | M0 studi (prima, resto o in più) | G1 unità (prima causa) | G1 studi (prima, resto o in più) |
|---|---|---|---|---|---|---|---|---|
| modello/forma_voci | una voce di `assignment` porta più valori della stessa colonna (lo schema v1 chiede una voce per valore) | schema | 9 | 2 | 10 | 4 | 3 | 2 |
| schema/annidato_colonna_padre | il modello dà «not applicable» a un fattore annidato con una condizione sulla colonna del fattore padre, che non è fra le colonne di fonte del fattore: schema e adattatore v1 non lo ammettono | schema | 4 | 3 | 0 | 2 | 0 | 1 |
| modello/valore_senza_voce | un valore della colonna di fonte resta senza voce (variante rara, cella vuota, «NA», o un elenco incompleto); le voci scritte hanno la forma giusta | schema | 27 | 8 | 28 | 8 | 24 | 7 |
| modello/valore_non_letterale | una voce porta un valore che la colonna di fonte non contiene: maiuscole diverse, stringa vuota per «None» o «-», valori di un'altra colonna o del titolo | schema | 2 | 2 | 7 | 3 | 19 | 7 |
| modello/colonna_non_letterale | un fattore dichiara una colonna di fonte che la tabella non ha, o nessuna colonna | schema | 5 | 1 | 0 | 0 | 7 | 1 |
| modello/mancante_non_dichiarato | la stringa «NA» di una colonna di soggetto non è dichiarata in `missing_values`: il costruttore la legge come un valore scritto | vista | 5 | 1 | 5 | 1 | 0 | 0 |
| schema/context_senza_base | per schema un fattore di contesto non ha livello di base: il lettore non può scrivere il confronto fra due tipi cellulari, due tessuti o due condizioni di coltura | schema | 3 | 2 | 3 | 2 | 0 | 1 |
| vista/sotto_serie | la vista porta i campioni di più sotto-serie con colonne diverse e molte celle vuote | vista | 0 | 1 | 0 | 1 | 0 | 1 |
| modello/fattore_doppio | due fattori scritti dalla stessa informazione (una colonna ripete l'altra) | modello | 0 | 2 | 0 | 2 | 2 | 1 |
| modello/fattori_uniti | due variabili del disegno scritte come un fattore solo, o una colonna di fonte che non distingue i livelli scritti | modello | 0 | 0 | 3 | 1 | 13 | 5 |
| modello/fattore_non_visto | una colonna che distingue le condizioni è giudicata non informativa | modello | 0 | 0 | 0 | 0 | 7 | 2 |
| modello/fattore_inventato | un fattore che i metadati non scrivono | modello | 0 | 1 | 0 | 0 | 0 | 1 |
| modello/ruolo_soggetto | ruolo di soggetto sbagliato: il donatore o il sesso scritti come fattore, o una colonna di condizione letta come donatore | modello | 0 | 3 | 0 | 2 | 5 | 5 |
| modello/tipo_fattore | tipo del fattore sbagliato (una malattia scritta come contesto, un contesto come stato) | modello | 2 | 1 | 2 | 2 | 0 | 4 |
| curatore/riferimento | Atlas usa come riferimento un gruppo che non è un controllo | non_serve | 0 | 1 | 0 | 1 | 0 | 1 |
| curatore/repliche | Atlas tratta come repliche campioni che differiscono in una variabile sperimentale | non_serve | 2 | 1 | 2 | 1 | 0 | 0 |
| curatore/errore_campione | Atlas mette un campione nel gruppo sbagliato | non_serve | 1 | 1 | 1 | 1 | 4 | 2 |
| curatore/fattore_ignorato | Atlas ignora una colonna di GEO che distingue i campioni | non_serve | 3 | 2 | 3 | 2 | 3 | 3 |
| curatore/livelli_uniti | Atlas unisce in un livello due valori che GEO distingue | non_serve | 0 | 1 | 0 | 1 | 0 | 0 |
| modello/colonna_fuori_fonti | una voce porta una condizione su una colonna vera che il fattore non dichiara fra le colonne di fonte | schema | 0 | 0 | 0 | 0 | 3 | 1 |
| strumento/fattori_ridondanti | la misura (c) conta come due fattori la stessa differenza scritta due volte da Atlas | strumento | 0 | 0 | 0 | 0 | 3 | 1 |

`chi può toglierla`: `schema` = un cambio dello schema, del prompt o dell'adattatore. Per `modello/forma_voci`,
`modello/colonna_fuori_fonti` e `schema/annidato_colonna_padre` l'effetto è misurato dalla sensibilità `forma`; per `modello/mancante_non_dichiarato`
dalla sensibilità `forma_na`. Per `modello/valore_senza_voce`, `modello/valore_non_letterale` e
`modello/colonna_non_letterale` la proposta è uno schema generato per ogni studio, in cui colonne e valori sono un
elenco chiuso e ogni valore distinto ha la sua voce: **non è misurata**. `vista` = un cambio della vista, non misurato
salvo `forma_na`. `modello` = la causa sta nella lettura del modello: per M la toglie un modello più grande solo dove la
misura di G1 o G2 lo mostra; per G1 e G2 questa prova non ha chi la toglie. `non_serve` = non è un errore del lettore.


## M

### Prima causa per tipo di unità

|  | studio_non_chiuso | partizione_non_identica | atlas_non_ritrovato | lettore_errore | totale |
|---|---|---|---|---|---|
| curatore/errore_campione | 0 | 1 | 0 | 0 | 1 |
| curatore/fattore_ignorato | 0 | 1 | 2 | 0 | 3 |
| curatore/repliche | 0 | 1 | 1 | 0 | 2 |
| modello/colonna_non_letterale | 1 | 0 | 4 | 0 | 5 |
| modello/forma_voci | 2 | 0 | 7 | 0 | 9 |
| modello/mancante_non_dichiarato | 0 | 0 | 5 | 0 | 5 |
| modello/tipo_fattore | 0 | 0 | 2 | 0 | 2 |
| modello/valore_non_letterale | 1 | 0 | 1 | 0 | 2 |
| modello/valore_senza_voce | 8 | 0 | 19 | 0 | 27 |
| schema/annidato_colonna_padre | 1 | 0 | 3 | 0 | 4 |
| schema/context_senza_base | 0 | 0 | 3 | 0 | 3 |

### Che cosa resta, tolta la prima causa

|  | curatore/errore_campione | curatore/livelli_uniti | curatore/riferimento | modello/fattore_doppio | niente_letto | niente_misurato | non_osservato | totale |
|---|---|---|---|---|---|---|---|---|
| curatore/errore_campione | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 1 |
| curatore/fattore_ignorato | 0 | 0 | 0 | 0 | 3 | 0 | 0 | 3 |
| curatore/repliche | 0 | 0 | 0 | 0 | 2 | 0 | 0 | 2 |
| modello/colonna_non_letterale | 0 | 0 | 0 | 0 | 0 | 0 | 5 | 5 |
| modello/forma_voci | 0 | 2 | 0 | 0 | 0 | 7 | 0 | 9 |
| modello/mancante_non_dichiarato | 0 | 0 | 0 | 0 | 0 | 5 | 0 | 5 |
| modello/tipo_fattore | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 2 |
| modello/valore_non_letterale | 0 | 0 | 0 | 0 | 0 | 0 | 2 | 2 |
| modello/valore_senza_voce | 0 | 0 | 2 | 3 | 0 | 0 | 22 | 27 |
| schema/annidato_colonna_padre | 0 | 0 | 0 | 0 | 0 | 4 | 0 | 4 |
| schema/context_senza_base | 0 | 0 | 0 | 2 | 1 | 0 | 0 | 3 |

### Esito della catena

`non_errore`: nella catena c'è una scelta o un errore del curatore, o un limite della misura. `forma`: la sensibilità
dichiarata toglie il disaccordo (misurato). `vista_schema`: ogni causa è di vista o di schema (proposta non misurata).
`modello`: almeno una causa sta nella lettura del modello.

|  | forma | modello | non_errore | vista_schema | totale |
|---|---|---|---|---|---|
| studio_non_chiuso | 2 | 1 | 1 | 9 | 13 |
| partizione_non_identica | 0 | 0 | 3 | 0 | 3 |
| atlas_non_ritrovato | 14 | 4 | 8 | 21 | 47 |
| lettore_errore | 0 | 0 | 0 | 0 | 0 |

### Un modello più grande toglie l'unità? (misurato sulla stessa unità, prime corse)

`nessuno` = l'unità resta in ogni modello più grande misurato. Gli errori del lettore non hanno un'unità corrispondente.

|  | G1 | nessuno | totale |
|---|---|---|---|
| forma | 7 | 9 | 16 |
| modello | 1 | 4 | 5 |
| non_errore | 2 | 10 | 12 |
| vista_schema | 3 | 27 | 30 |

|  | G1 | nessuno | totale |
|---|---|---|---|
| modello/valore_senza_voce | 1 | 2 | 3 |
| schema/context_senza_base | 0 | 2 | 2 |

### M: una riga per studio

| studio | disaccordi | che cosa differisce | prima causa | resto | in più | esito | sensibilità (forma; forma_na) | prova |
|---|---|---|---|---|---|---|---|---|
| GSE147507 | non chiuso; 2 confronti non ritrovati | La vista porta 77 campioni di più sotto-serie; l'universo di Atlas ne ha 14. Restano senza voce valori di `cell_line` (30 campioni), `treatment` (20), `ruxolitinib` (77) e `time_after_treatment` (36). Lo studio non chiude. | modello/valore_senza_voce | non_osservato | vista/sotto_serie | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE46665 | non chiuso; 2 confronti non ritrovati | Il modello scrive un fattore di stato «disease» dalla colonna `description`, con 9 voci solo per i valori `<paziente>_T0`: i livelli sono le sigle dei 9 pazienti. Restano scoperti 16 campioni. Il fattore `LVAD` da `time`, con base «pre-LVAD», è scritto bene. | modello/valore_senza_voce | non_osservato | modello/ruolo_soggetto | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE56787 | non chiuso | Il modello scrive tre fattori dalla sola colonna `tissue`. Il fattore `disease` ha voci solo per le biopsie (14 campioni scoperti). Il fattore `cell_type` ha voci solo per le colture (24 scoperti). Il fattore `dux4_transduction` dà «untreated» alle biopsie e «transduced» alle colture: i metadati non lo scrivono. | modello/valore_senza_voce | non_osservato | modello/fattore_inventato | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso |  |
| GSE57116 | non chiuso; 2 confronti non ritrovati | La colonna `time` ha il valore «control» in 4 campioni e il modello non scrive la voce: lo studio non chiude. Il fattore `time` ripete il fattore `treatment` (i valori di `treatment` contengono già i minuti): con la voce, i due confronti differiscono in due fattori. | modello/valore_senza_voce | modello/fattore_doppio |  | modello | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE57945 | non chiuso; 6 confronti non ritrovati | Restano senza voce il valore «not IBD» di `disease` (1 campione), 105 campioni del fattore `inflammation` e 106 del fattore `deep_ulcer`. Due voci hanno una forma che lo schema non ammette. Il fattore `inflammation` dichiara due colonne di fonte (`l2 type`, `histopathology`). | modello/valore_senza_voce | non_osservato | schema/annidato_colonna_padre | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE59781 | non chiuso; 1 confronti non ritrovati | Due voci di `assignment` portano 4 condizioni ciascuna sulla colonna `title`. L'adattatore le rifiuta e lo studio non chiude. Con una voce per valore lo studio chiude, la partizione è identica e il confronto si ritrova. | modello/forma_voci | niente_misurato |  | forma | chiuso/identica; chiuso/identica // uguale; uguale |  |
| GSE60340 | non chiuso; 2 confronti non ritrovati | Restano senza voce 12 campioni del fattore `senescence_type` e 9 del fattore `treatment`. Lo studio non chiude. Lo studio non chiude per le voci che mancano. In più Atlas usa come riferimento le cellule immortali spontanee, che non sono un controllo. | modello/valore_senza_voce | non_osservato; curatore/riferimento |  | vista_schema; non_errore | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no | Nomi dei confronti di Atlas («... vs 'spontaneously immortal cells; control'») e colonna `passages` (oltre 200 contro 10-12, 17-19, 28-30). |
| GSE63816 | non chiuso; 3 confronti non ritrovati | Il valore «erythroleukemia» di `disease` (6 campioni) resta senza voce. I fattori `zrsr2_status` e `shRNA_treatment` hanno voci sulla colonna `title` con il titolo senza il numero finale: nessun campione le soddisfa (22 scoperti, 6 + 6 voci in più). | modello/valore_senza_voce | non_osservato | modello/valore_non_letterale | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE66207 | non chiuso; 3 confronti non ritrovati | Il fattore `disease_behavior` vale solo per i malati. Il modello scrive «not applicable» con una condizione sulla colonna del fattore padre, che lo schema v1 non ammette: 9 voci rifiutate, 13 campioni scoperti. Con la forma tollerata lo studio chiude, la partizione è identica e i 3 confronti si ritrovano. | schema/annidato_colonna_padre | niente_misurato |  | forma | chiuso/identica; chiuso/identica // uguale; uguale |  |
| GSE69597 | non chiuso; 6 confronti non ritrovati | Le voci dei fattori `stage` e `response` portano più valori della colonna `subgroup` (4 + 2 voci rifiutate; 162 e 62 campioni scoperti). Con una voce per valore lo studio chiude e la partizione è più fine di Atlas: il lettore separa la brucellosi cronica sotto i 10 anni da quella sopra i 10 anni, Atlas le unisce. Lo studio non chiude per la forma delle voci. Con una voce per valore 5 confronti su 6 si ritrovano. Lo studio non chiude per la forma delle voci. Con una voce per valore questo confronto non si ritrova: il gruppo di Atlas unisce due livelli che il lettore separa. | modello/forma_voci | curatore/livelli_uniti; niente_misurato | schema/annidato_colonna_padre | non_errore; forma | chiuso/piu_fine; chiuso/piu_fine // uguale; uguale // no; no | GEO `history of brucellosis`: «Chronic brucellosis (<10 years)» 24, «(>10 years)» 4; Atlas ha un solo gruppo «chronic brucellosis; complete remission» di 18 = 14 + 4. |
| GSE71595 | non chiuso; 4 confronti non ritrovati | Il modello scrive un fattore «stimulus» senza colonna di fonte, con una voce senza condizione: 14 campioni scoperti, lo studio non chiude. Il modello dà a `source_name_ch1` il ruolo di donatore. | modello/colonna_non_letterale | non_osservato | modello/ruolo_soggetto | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE83415 | non chiuso; 1 confronti non ritrovati | Il fattore `disease_stage` ha 2 voci con valori che la colonna di fonte non contiene: 21 campioni scoperti, lo studio non chiude. | modello/valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE83687 | non chiuso; 2 confronti non ritrovati | Il modello scrive 13 voci sulla colonna `source_name_ch1` e ne manca una: il campione GSM2212679 resta scoperto e lo studio non chiude. | modello/valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE44379 | partizione piu_fine; 1 confronti non ritrovati | Il modello scrive un fattore tecnico `fraction` dal titolo, con 16 voci: i gruppi hanno un campione ciascuno. Atlas unisce le 8 frazioni del gradiente in un gruppo per trattamento. | curatore/repliche | niente_letto |  | non_errore | chiuso/piu_fine; chiuso/piu_fine // no; no | Titoli dei campioni: `RNAseq_Sucrose_Gradient_[no]arsenite_fraction1..8`, una frazione per campione, nessuna replica dentro la frazione. |
| GSE50760 | partizione incrociata; 2 confronti non ritrovati | Il lettore forma tre gruppi da 18 campioni, come le colonne `source_name_ch1` e `tissue` di GEO. Atlas ha 19 normali e 17 metastasi: un campione di metastasi sta fra i normali. La partizione è incrociata. Il modello scrive `tissue` (normale, tumore primario, metastasi) come fattore di contesto senza livello di base: il costruttore non forma confronti (registro: `fattore_senza_base` 3). Il modello dà a `source_name_ch1` il ruolo di donatore. Con il tipo giusto i gruppi di Atlas restano diversi per un campione. | curatore/errore_campione; modello/tipo_fattore | niente_letto; curatore/errore_campione | modello/ruolo_soggetto | non_errore | chiuso/incrociata; chiuso/incrociata // no; no | GEO: `source_name_ch1` e `tissue` danno 18/18/18 e il titolo del campione dice «metastasized cancer»; Atlas 19 normali e 17 metastasi. |
| GSE93624 | partizione piu_fine; 1 confronti non ritrovati | Il lettore scrive anche il fattore `progression to complication` («yes» 27 campioni) e separa i malati in due gruppi. Atlas confronta tutti i malati con i controlli. | curatore/fattore_ignorato | niente_letto |  | non_errore | chiuso/piu_fine; chiuso/piu_fine // no; no | Vista: `progression to complication` «yes» 27, «-» 218; Atlas confronta 209 malati con 35 controlli. |
| GSE112057 | 5 confronti non ritrovati | Le colonne di soggetto `gender` e `ancestry` hanno la stringa «NA» in 11 campioni. Il modello dichiara `missing_values` solo per `age at diagnosis`. Il costruttore legge «NA» come un valore scritto e scarta i 5 confronti per soggetti disgiunti (registro: `soggetti_disgiunti` 5). | modello/mancante_non_dichiarato | niente_misurato |  | forma | no; uguale |  |
| GSE65335 | 1 confronti non ritrovati | Atlas confronta due condizioni di coltura (interfaccia aria-liquido al giorno 14 contro sommerso al giorno 8). Il modello scrive `growth_condition` come fattore di contesto, che per schema non ha livello di base (registro: `fattore_senza_base` 1). | schema/context_senza_base | niente_letto |  | vista_schema | no; no |  |
| GSE75852 | 2 confronti non ritrovati | Atlas confronta progenitori neurali e cellule staminali pluripotenti indotte. Il modello scrive `cell_type` come fattore di contesto, senza base. In più scrive un fattore `time` dalla colonna `description` (giorno 0, giorno 34), che ripete il tipo cellulare: i due confronti differiscono in più di un fattore (registro: `piu_di_un_fattore` 4). | schema/context_senza_base | modello/fattore_doppio |  | modello | no; no |  |
| GSE77598 | 1 confronti non ritrovati | Il lettore scrive due fattori, la malattia e l'aplotipo di MERTK, che dividono i campioni allo stesso modo. Atlas tiene solo la malattia. | curatore/fattore_ignorato | niente_letto |  | non_errore | no; no | Vista: `disease` 5 e 3, `mertk haplotype` 5 (rischio) e 3 (non rischio), stessi campioni. |

### M: una riga per unità

`forma`, `forma_na` = la stessa unità nelle due sensibilità; `in_<modello>` = la stessa unità nella prima corsa di un altro modello; `oggi` = la pipeline di oggi sullo stesso confronto.

| tipo | studio | id | nome | causa | sotto | resto_causa | resto_sotto | esito | forma | forma_na | in_M0 | in_G1 | oggi | piu_grande |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| studio_non_chiuso | GSE147507 |  | non_coperta: cell_line: 30 campioni, per esempio GSM4462363 // non_coperta: treatment: 20 campioni, … | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE46665 |  | non_coperta: disease: 16 campioni, per esempio GSM1133661 | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE56787 |  | non_coperta: disease: 14 campioni, per esempio GSM1412722 // non_coperta: cell_type: 24 campioni, pe… | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/piu_fine |  | nessuno |
| studio_non_chiuso | GSE57116 |  | non_coperta: time: 4 campioni, per esempio GSM1375518 | modello | valore_senza_voce | modello | fattore_doppio | modello | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica |  | G1 |
| studio_non_chiuso | GSE57945 |  | non_coperta: disease: 1 campioni, per esempio GSM1598427 // non_coperta: inflammation: 105 campioni,… | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE59781 |  | non_coperta: siRNA: 8 campioni, per esempio GSM1446338 | modello | forma_voci | niente_misurato |  | forma | chiuso/identica | chiuso/identica | non chiuso/non_chiuso | chiuso/identica |  | G1 |
| studio_non_chiuso | GSE60340 |  | non_coperta: senescence_type: 12 campioni, per esempio GSM1473790 // non_coperta: treatment: 9 campi… | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE63816 |  | non_coperta: disease: 6 campioni, per esempio GSM1558072 // non_coperta: zrsr2_status: 22 campioni, … | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE66207 |  | non_coperta: disease_behavior: 13 campioni, per esempio GSM1616932 | schema | annidato_colonna_padre | niente_misurato |  | forma | chiuso/identica | chiuso/identica | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE69597 |  | non_coperta: stage: 162 campioni, per esempio GSM1704306 // non_coperta: response_to_treatment: 62 c… | modello | forma_voci | curatore | livelli_uniti | non_errore | chiuso/piu_fine | chiuso/piu_fine | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE71595 |  | non_coperta: stimulus: 14 campioni, per esempio GSM1841068 | modello | colonna_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica | chiuso/identica |  | G1 |
| studio_non_chiuso | GSE83415 |  | non_coperta: disease_stage: 21 campioni, per esempio GSM2202553 | modello | valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE83687 |  | non_coperta: tissue: 1 campioni, per esempio GSM2212679 | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica | non chiuso/non_chiuso |  | nessuno |
| partizione_non_identica | GSE44379 |  | classe piu_fine | curatore | repliche | niente_letto |  | non_errore | chiuso/piu_fine | chiuso/piu_fine | chiuso/piu_fine | chiuso/identica |  | G1 |
| partizione_non_identica | GSE50760 |  | classe incrociata | curatore | errore_campione | niente_letto |  | non_errore | chiuso/incrociata | chiuso/incrociata | chiuso/incrociata | chiuso/incrociata |  | nessuno |
| partizione_non_identica | GSE93624 |  | classe piu_fine | curatore | fattore_ignorato | niente_letto |  | non_errore | chiuso/piu_fine | chiuso/piu_fine | chiuso/piu_fine | non chiuso/non_chiuso |  | nessuno |
| atlas_non_ritrovato | GSE112057 | g2_g1 | 'Crohn disease' vs 'normal' | modello | mancante_non_dichiarato | niente_misurato |  | forma | no | uguale | no | uguale | uguale | G1 |
| atlas_non_ritrovato | GSE112057 | g2_g3 | 'oligoarticular juvenile idiopathic arthritis' vs 'normal' | modello | mancante_non_dichiarato | niente_misurato |  | forma | no | uguale | no | uguale | no | G1 |
| atlas_non_ritrovato | GSE112057 | g2_g4 | 'polyarticular juvenile idiopathic arthritis' vs 'normal' | modello | mancante_non_dichiarato | niente_misurato |  | forma | no | uguale | no | uguale | no | G1 |
| atlas_non_ritrovato | GSE112057 | g2_g5 | 'systemic-onset juvenile idiopathic arthritis' vs 'normal' | modello | mancante_non_dichiarato | niente_misurato |  | forma | no | uguale | no | uguale | no | G1 |
| atlas_non_ritrovato | GSE112057 | g2_g6 | 'ulcerative colitis (disease)' vs 'normal' | modello | mancante_non_dichiarato | niente_misurato |  | forma | no | uguale | no | uguale | no | G1 |
| atlas_non_ritrovato | GSE147507 | g2_g1 | 'Severe acute respiratory syndrome coronavirus 2 (USA-WA1/2020)' vs 'mock' in 'A549' at '24 hour' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE147507 | g4_g3 | 'Severe acute respiratory syndrome coronavirus 2 (USA-WA1/2020)' vs 'mock' in 'NHBE' at '24 hour' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | uguale | nessuno |
| atlas_non_ritrovato | GSE44379 | g2_g1 | 'arsenite' vs 'control' | curatore | repliche | niente_letto |  | non_errore | no | no | no | uguale | no | G1 |
| atlas_non_ritrovato | GSE46665 | g3_g1 | '180 days after left ventricular assist device placement' vs 'control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE46665 | g3_g2 | '7 days after left ventricular assist device placement' vs 'control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE50760 | g2_g1 | 'colorectal cancer metastatic in the liver' vs 'normal' | modello | tipo_fattore | curatore | errore_campione | non_errore | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE50760 | g2_g3 | 'primary tumor' vs 'normal' | modello | tipo_fattore | curatore | errore_campione | non_errore | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57116 | g3_g1 | '3 h DRB 0 min 4sU' vs 'untreated' | modello | valore_senza_voce | modello | fattore_doppio | modello | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57116 | g3_g2 | '3 h DRB 8 min 4sU' vs 'untreated' | modello | valore_senza_voce | modello | fattore_doppio | modello | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57945 | g6_g1 | 'Crohn's disease, macroscopic ileal inflammation with deep ulcer' vs 'non inflammatory bowel disease… | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57945 | g6_g2 | 'Crohn's disease, macroscopic ileal inflammation without deep ulcer' vs 'non inflammatory bowel dise… | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57945 | g6_g3 | 'Crohn's disease, microscopic ileal inflammation without deep ulcer' vs 'non inflammatory bowel dise… | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57945 | g6_g4 | 'Crohn's disease, normal' vs 'non inflammatory bowel disease control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57945 | g6_g5 | 'Crohn's disease, undetermined' vs 'non inflammatory bowel disease control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57945 | g6_g7 | 'ulcerative colitis' vs 'non inflammatory bowel disease control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE59781 | g2_g1 | 'PAX2 siRNA' vs 'control' | modello | forma_voci | niente_misurato |  | forma | uguale | uguale | no | uguale | uguale | G1 |
| atlas_non_ritrovato | GSE60340 | g7_g1 | 'aging cells' vs 'spontaneously immortal cells; control' | modello | valore_senza_voce | curatore | riferimento | non_errore | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE60340 | g7_g8 | 'young cells' vs 'spontaneously immortal cells; control' | modello | valore_senza_voce | curatore | riferimento | non_errore | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE63816 | g4_g1 | 'erythroleukemia; ZRSR2 shRNA' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE63816 | g4_g2 | 'myelodysplastic syndrome; ZRSR2 mutant' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE63816 | g4_g3 | 'myelodysplastic syndrome; ZRSR2 wild type' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE65335 | g3_g2 | 'untreated; air-liquid interface (day 14)' vs 'untreated; submerged (day 8)' | schema | context_senza_base | niente_letto |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE66207 | g4_g3 | 'Crohn's disease; B3, penetrating' vs 'non inflammatory bowel disease control' | schema | annidato_colonna_padre | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE66207 | g4_g2 | 'Crohn's disease; B2, stricturing' vs 'non inflammatory bowel disease control' | schema | annidato_colonna_padre | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE66207 | g4_g1 | 'Crohn's disease; B1, non-strictuing, non-penetrating' vs 'non inflammatory bowel disease control' | schema | annidato_colonna_padre | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE69597 | g4_g2 | 'brucellosis; acute brucellosis; complete remission' vs 'normal' | modello | forma_voci | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE69597 | g4_g5 | 'brucellosis; acute brucellosis; reinfection' vs 'normal' | modello | forma_voci | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE69597 | g4_g6 | 'brucellosis; acute brucellosis; relapse' vs 'normal' | modello | forma_voci | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE69597 | g4_g3 | 'brucellosis; chronic brucellosis; complete remission' vs 'normal' | modello | forma_voci | curatore | livelli_uniti | non_errore | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE69597 | g4_g7 | 'brucellosis; chronic brucellosis; relapse' vs 'normal' | modello | forma_voci | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE69597 | g4_g1 | 'Leishmaniasis' vs 'normal' | modello | forma_voci | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE71595 | g2_g1 | 'juvenile idiopathic arthritis' vs 'normal' in 'JQ1; 300 nanomolar' | modello | colonna_non_letterale | non_osservato |  | vista_schema | no | no | uguale | no | no | nessuno |
| atlas_non_ritrovato | GSE71595 | g3_g1 | 'JQ1; 300 nanomolar' vs 'none' in 'juvenile idiopathic arthritis' | modello | colonna_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | uguale | G1 |
| atlas_non_ritrovato | GSE71595 | g4_g2 | 'JQ1; 300 nanomolar' vs 'none' in 'normal' | modello | colonna_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no | G1 |
| atlas_non_ritrovato | GSE71595 | g5_g3 | 'juvenile idiopathic arthritis' vs 'normal' in 'none' | modello | colonna_non_letterale | non_osservato |  | vista_schema | no | no | uguale | no | no | nessuno |
| atlas_non_ritrovato | GSE75852 | g2_g4 | ' neural stem cell' vs 'induced pluripotent stem cell' in 'normal' | schema | context_senza_base | modello | fattore_doppio | modello | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE75852 | g1_g3 | ' neural stem cell' vs 'induced pluripotent stem cell' in 'Ataxia-telangiectasia' | schema | context_senza_base | modello | fattore_doppio | modello | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE77598 | g2_g1 | 'multiple sclerosis' vs 'normal' | curatore | fattore_ignorato | niente_letto |  | non_errore | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE83415 | g2_g1 | 'active, on treatment' vs 'remission, on treatment' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | no | no | verso_opposto | nessuno |
| atlas_non_ritrovato | GSE83687 | g2_g1 | 'Crohn's disease' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | uguale | no | no | nessuno |
| atlas_non_ritrovato | GSE83687 | g2_g3 | 'ulcerative colitis' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | uguale | no | no | nessuno |
| atlas_non_ritrovato | GSE93624 | g2_g1 | 'Crohn's disease' vs 'non inflammatory bowel disease control' | curatore | fattore_ignorato | niente_letto |  | non_errore | no | no | no | no | no | nessuno |

## M0

### Prima causa per tipo di unità

|  | studio_non_chiuso | partizione_non_identica | atlas_non_ritrovato | lettore_errore | totale |
|---|---|---|---|---|---|
| curatore/errore_campione | 0 | 1 | 0 | 0 | 1 |
| curatore/fattore_ignorato | 0 | 1 | 2 | 0 | 3 |
| curatore/repliche | 0 | 1 | 1 | 0 | 2 |
| modello/fattori_uniti | 1 | 0 | 2 | 0 | 3 |
| modello/forma_voci | 3 | 0 | 7 | 0 | 10 |
| modello/mancante_non_dichiarato | 0 | 0 | 5 | 0 | 5 |
| modello/tipo_fattore | 0 | 0 | 2 | 0 | 2 |
| modello/valore_non_letterale | 2 | 0 | 5 | 0 | 7 |
| modello/valore_senza_voce | 8 | 0 | 20 | 0 | 28 |
| schema/context_senza_base | 0 | 0 | 3 | 0 | 3 |

### Che cosa resta, tolta la prima causa

|  | curatore/errore_campione | curatore/livelli_uniti | curatore/riferimento | modello/fattore_doppio | niente_letto | niente_misurato | non_osservato | totale |
|---|---|---|---|---|---|---|---|---|
| curatore/errore_campione | 0 | 0 | 0 | 0 | 1 | 0 | 0 | 1 |
| curatore/fattore_ignorato | 0 | 0 | 0 | 0 | 3 | 0 | 0 | 3 |
| curatore/repliche | 0 | 0 | 0 | 0 | 2 | 0 | 0 | 2 |
| modello/fattori_uniti | 0 | 0 | 0 | 0 | 0 | 0 | 3 | 3 |
| modello/forma_voci | 0 | 2 | 0 | 0 | 0 | 8 | 0 | 10 |
| modello/mancante_non_dichiarato | 0 | 0 | 0 | 0 | 0 | 5 | 0 | 5 |
| modello/tipo_fattore | 2 | 0 | 0 | 0 | 0 | 0 | 0 | 2 |
| modello/valore_non_letterale | 0 | 0 | 0 | 0 | 0 | 0 | 7 | 7 |
| modello/valore_senza_voce | 0 | 0 | 2 | 3 | 0 | 0 | 23 | 28 |
| schema/context_senza_base | 0 | 0 | 0 | 2 | 1 | 0 | 0 | 3 |

### Esito della catena

`non_errore`: nella catena c'è una scelta o un errore del curatore, o un limite della misura. `forma`: la sensibilità
dichiarata toglie il disaccordo (misurato). `vista_schema`: ogni causa è di vista o di schema (proposta non misurata).
`modello`: almeno una causa sta nella lettura del modello.

|  | forma | modello | non_errore | vista_schema | totale |
|---|---|---|---|---|---|
| studio_non_chiuso | 2 | 2 | 1 | 9 | 14 |
| partizione_non_identica | 0 | 0 | 3 | 0 | 3 |
| atlas_non_ritrovato | 11 | 6 | 8 | 22 | 47 |
| lettore_errore | 0 | 0 | 0 | 0 | 0 |

### Un modello più grande toglie l'unità? (misurato sulla stessa unità, prime corse)

`nessuno` = l'unità resta in ogni modello più grande misurato. Gli errori del lettore non hanno un'unità corrispondente.

|  | G1 | nessuno | totale |
|---|---|---|---|
| forma | 8 | 5 | 13 |
| modello | 1 | 7 | 8 |
| non_errore | 2 | 10 | 12 |
| vista_schema | 0 | 31 | 31 |

|  | G1 | nessuno | totale |
|---|---|---|---|
| modello/fattori_uniti | 0 | 3 | 3 |
| modello/valore_senza_voce | 1 | 2 | 3 |
| schema/context_senza_base | 0 | 2 | 2 |

### M0: una riga per studio

| studio | disaccordi | che cosa differisce | prima causa | resto | in più | esito | sensibilità (forma; forma_na) | prova |
|---|---|---|---|---|---|---|---|---|
| GSE147507 | non chiuso; 2 confronti non ritrovati | La vista porta 77 campioni di più sotto-serie; l'universo di Atlas ne ha 14. Restano senza voce valori di `cell line` (30 campioni), `treatment` (3), `time after treatment` (63), `strain` (42) e `subject status` (75). Lo studio non chiude. | modello/valore_senza_voce | non_osservato | vista/sotto_serie | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE46665 | non chiuso; 2 confronti non ritrovati | Il modello scrive un fattore di stato «disease» dalla colonna `description`, con 9 voci solo per i valori `<paziente>_T0`: i livelli sono le sigle dei 9 pazienti. Restano scoperti 16 campioni. L'impianto del dispositivo (LVAD) è scritto come fattore di tipo tempo, senza livello di base. | modello/valore_senza_voce | non_osservato | modello/ruolo_soggetto;modello/tipo_fattore | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE49155 | non chiuso; 2 confronti non ritrovati | Il modello scrive un fattore `cell_type` dalla colonna `cell type`, che è vuota in 10 campioni su 13. Due voci hanno la stessa condizione (valore vuoto) e due livelli diversi: la mappa è ambigua (10 campioni) e lo studio non chiude. I due livelli stanno nella colonna `tissue`. | modello/fattori_uniti | non_osservato |  | modello | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE56787 | non chiuso | Il modello scrive due fattori dalla sola colonna `tissue`. Il fattore `disease` ha voci solo per le biopsie (14 campioni scoperti). Il fattore `cell_type` ha 2 voci con 3 condizioni ciascuna, che l'adattatore rifiuta (38 scoperti). | modello/valore_senza_voce | non_osservato | modello/forma_voci | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso |  |
| GSE57116 | non chiuso; 2 confronti non ritrovati | La colonna `time` ha il valore «control» in 4 campioni e il modello non scrive la voce: lo studio non chiude. Il fattore `time` ripete il fattore `treatment` (i valori di `treatment` contengono già i minuti): con la voce, i due confronti differiscono in due fattori. | modello/valore_senza_voce | modello/fattore_doppio |  | modello | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE57945 | non chiuso; 6 confronti non ritrovati | Restano senza voce le varianti di scrittura «not IBD» di `diagnosis` (1 campione; la voce c'è per «Not IBD») e «no» di `deep ulcer` (2 campioni; la voce c'è per «No»). Lo studio non chiude. | modello/valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE59781 | non chiuso; 1 confronti non ritrovati | Due voci di `assignment` portano 4 condizioni ciascuna sulla colonna `title`. L'adattatore le rifiuta e lo studio non chiude. Con una voce per valore lo studio chiude, la partizione è identica e il confronto si ritrova. | modello/forma_voci | niente_misurato |  | forma | chiuso/identica; chiuso/identica // uguale; uguale |  |
| GSE60340 | non chiuso; 2 confronti non ritrovati | Il valore «None (grown until growth arrest)» di `treated with` (3 campioni) resta senza voce. Lo studio non chiude. Lo studio non chiude per la voce che manca. In più Atlas usa come riferimento le cellule immortali spontanee, che non sono un controllo. | modello/valore_senza_voce | non_osservato; curatore/riferimento |  | vista_schema; non_errore | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no | Nomi dei confronti di Atlas («... vs 'spontaneously immortal cells; control'») e colonna `passages` (oltre 200 contro 10-12, 17-19, 28-30). |
| GSE60585 | non chiuso; 4 confronti non ritrovati | Il modello scrive un fattore tecnico dalla colonna `molecule subtype` con i valori «polyA RNA» e «total RNA». La colonna contiene «ribosomal RNA depleted whole cell RNA» e «whole-cell RNA»: 18 campioni scoperti, 2 voci in più, lo studio non chiude. | modello/valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE63816 | non chiuso; 3 confronti non ritrovati | Il valore «erythroleukemia» di `disease` (6 campioni) resta senza voce. I fattori letti dalla colonna `title` hanno voci con il titolo senza il numero finale: nessun campione le soddisfa (2 + 3 voci in più). | modello/valore_senza_voce | non_osservato | modello/valore_non_letterale | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE66207 | non chiuso; 3 confronti non ritrovati | La colonna `disease` ha 10 valori distinti e il modello scrive voci solo per «Crohn's Disease» e «Normal»: 12 campioni scoperti. Il fattore `disease_behavior` ha una voce «not applicable» con una condizione sulla colonna del fattore padre, che lo schema v1 non ammette (13 scoperti). Lo studio non chiude nemmeno con la forma tollerata. | modello/valore_senza_voce | non_osservato | schema/annidato_colonna_padre | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE67812 | non chiuso | Una voce di `assignment` porta 3 condizioni sulla colonna `title`. L'adattatore la rifiuta, 3 campioni restano scoperti e lo studio non chiude. Con una voce per valore lo studio chiude e la partizione è identica. | modello/forma_voci | niente_misurato |  | forma | chiuso/identica; chiuso/identica |  |
| GSE69597 | non chiuso; 6 confronti non ritrovati | Le voci dei fattori `stage` e `response` portano più valori della colonna `subgroup` (4 + 2 voci rifiutate; 162 e 62 campioni scoperti). Con una voce per valore lo studio chiude e la partizione è più fine di Atlas: il lettore separa la brucellosi cronica sotto i 10 anni da quella sopra i 10 anni, Atlas le unisce. Lo studio non chiude per la forma delle voci. Con una voce per valore 5 confronti su 6 si ritrovano. Lo studio non chiude per la forma delle voci. Con una voce per valore questo confronto non si ritrova: il gruppo di Atlas unisce due livelli che il lettore separa. | modello/forma_voci | curatore/livelli_uniti; niente_misurato | schema/annidato_colonna_padre | non_errore; forma | chiuso/piu_fine; chiuso/piu_fine // uguale; uguale // no; no | GEO `history of brucellosis`: «Chronic brucellosis (<10 years)» 24, «(>10 years)» 4; Atlas ha un solo gruppo «chronic brucellosis; complete remission» di 18 = 14 + 4. |
| GSE83415 | non chiuso; 1 confronti non ritrovati | Il fattore `disease_stage` ha 2 voci con valori che la colonna di fonte non contiene: 21 campioni scoperti, lo studio non chiude. | modello/valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE44379 | partizione piu_fine; 1 confronti non ritrovati | Il modello scrive un fattore tecnico `fraction` dal titolo, con 16 voci: i gruppi hanno un campione ciascuno. Atlas unisce le 8 frazioni del gradiente in un gruppo per trattamento. | curatore/repliche | niente_letto |  | non_errore | chiuso/piu_fine; chiuso/piu_fine // no; no | Titoli dei campioni: `RNAseq_Sucrose_Gradient_[no]arsenite_fraction1..8`, una frazione per campione, nessuna replica dentro la frazione. |
| GSE50760 | partizione incrociata; 2 confronti non ritrovati | Il lettore forma tre gruppi da 18 campioni, come le colonne `source_name_ch1` e `tissue` di GEO. Atlas ha 19 normali e 17 metastasi: un campione di metastasi sta fra i normali. La partizione è incrociata. Il modello scrive `tissue` (normale, tumore primario, metastasi) come fattore di contesto senza livello di base: il costruttore non forma confronti (registro: `fattore_senza_base` 3). Il modello dà a `source_name_ch1` il ruolo di donatore. Con il tipo giusto i gruppi di Atlas restano diversi per un campione. | curatore/errore_campione; modello/tipo_fattore | niente_letto; curatore/errore_campione | modello/ruolo_soggetto | non_errore | chiuso/incrociata; chiuso/incrociata // no; no | GEO: `source_name_ch1` e `tissue` danno 18/18/18 e il titolo del campione dice «metastasized cancer»; Atlas 19 normali e 17 metastasi. |
| GSE93624 | partizione piu_fine; 1 confronti non ritrovati | Il lettore scrive anche il fattore `progression to complication` («yes» 27 campioni) e separa i malati in due gruppi. Atlas confronta tutti i malati con i controlli. | curatore/fattore_ignorato | niente_letto |  | non_errore | chiuso/piu_fine; chiuso/piu_fine // no; no | Vista: `progression to complication` «yes» 27, «-» 218; Atlas confronta 209 malati con 35 controlli. |
| GSE112057 | 5 confronti non ritrovati | Le colonne di soggetto `gender` e `ancestry` hanno la stringa «NA» in 11 campioni. Il modello dichiara `missing_values` solo per `age at diagnosis`. Il costruttore legge «NA» come un valore scritto e scarta i 5 confronti per soggetti disgiunti (registro: `soggetti_disgiunti` 5). | modello/mancante_non_dichiarato | niente_misurato |  | forma | no; uguale |  |
| GSE65335 | 1 confronti non ritrovati | Atlas confronta due condizioni di coltura (interfaccia aria-liquido al giorno 14 contro sommerso al giorno 8). Il modello scrive `growth_condition` come fattore di contesto, che per schema non ha livello di base (registro: `fattore_senza_base` 1). | schema/context_senza_base | niente_letto |  | vista_schema | no; no |  |
| GSE75852 | 2 confronti non ritrovati | Atlas confronta progenitori neurali e cellule staminali pluripotenti indotte. Il modello scrive `cell_type` come fattore di contesto, senza base. In più scrive un fattore `time` dalla colonna `description` (giorno 0, giorno 34), che ripete il tipo cellulare: i due confronti differiscono in più di un fattore (registro: `piu_di_un_fattore` 4). | schema/context_senza_base | modello/fattore_doppio |  | modello | no; no |  |
| GSE77598 | 1 confronti non ritrovati | Il lettore scrive due fattori, la malattia e l'aplotipo di MERTK, che dividono i campioni allo stesso modo. Atlas tiene solo la malattia. | curatore/fattore_ignorato | niente_letto |  | non_errore | no; no | Vista: `disease` 5 e 3, `mertk haplotype` 5 (rischio) e 3 (non rischio), stessi campioni. |

### M0: una riga per unità

`forma`, `forma_na` = la stessa unità nelle due sensibilità; `in_<modello>` = la stessa unità nella prima corsa di un altro modello; `oggi` = la pipeline di oggi sullo stesso confronto.

| tipo | studio | id | nome | causa | sotto | resto_causa | resto_sotto | esito | forma | forma_na | in_M | in_G1 | oggi | piu_grande |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| studio_non_chiuso | GSE147507 |  | non_coperta: cell_line: 30 campioni, per esempio GSM4462363 // non_coperta: treatment: 3 campioni, p… | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE46665 |  | non_coperta: disease: 16 campioni, per esempio GSM1133661 | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE49155 |  | mappa_ambigua: cell_type: 10 campioni | modello | fattori_uniti | non_osservato |  | modello | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE56787 |  | non_coperta: disease: 14 campioni, per esempio GSM1412722 // non_coperta: cell_type: 38 campioni, pe… | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/piu_fine |  | nessuno |
| studio_non_chiuso | GSE57116 |  | non_coperta: time: 4 campioni, per esempio GSM1375518 | modello | valore_senza_voce | modello | fattore_doppio | modello | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica |  | G1 |
| studio_non_chiuso | GSE57945 |  | non_coperta: diagnosis: 1 campioni, per esempio GSM1598427 // non_coperta: deep_ulcer: 2 campioni, p… | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE59781 |  | non_coperta: perturbation: 8 campioni, per esempio GSM1446338 | modello | forma_voci | niente_misurato |  | forma | chiuso/identica | chiuso/identica | non chiuso/non_chiuso | chiuso/identica |  | G1 |
| studio_non_chiuso | GSE60340 |  | non_coperta: treatment: 3 campioni, per esempio GSM1473784 | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE60585 |  | non_coperta: molecule subtype: 18 campioni, per esempio GSM1482894 | modello | valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica | chiuso/piu_grossa |  | nessuno |
| studio_non_chiuso | GSE63816 |  | non_coperta: disease: 6 campioni, per esempio GSM1558072 // non_coperta: ZRSR2: 22 campioni, per ese… | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE66207 |  | non_coperta: disease: 12 campioni, per esempio GSM1616933 // non_coperta: disease_behavior: 13 campi… | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE67812 |  | non_coperta: disease state: 3 campioni, per esempio GSM1656433 | modello | forma_voci | niente_misurato |  | forma | chiuso/identica | chiuso/identica | chiuso/identica | chiuso/identica |  | G1 |
| studio_non_chiuso | GSE69597 |  | non_coperta: brucellosis_stage: 162 campioni, per esempio GSM1704306 // non_coperta: response_to_tre… | modello | forma_voci | curatore | livelli_uniti | non_errore | chiuso/piu_fine | chiuso/piu_fine | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| studio_non_chiuso | GSE83415 |  | non_coperta: disease stage: 21 campioni, per esempio GSM2202553 | modello | valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  | nessuno |
| partizione_non_identica | GSE44379 |  | classe piu_fine | curatore | repliche | niente_letto |  | non_errore | chiuso/piu_fine | chiuso/piu_fine | chiuso/piu_fine | chiuso/identica |  | G1 |
| partizione_non_identica | GSE50760 |  | classe incrociata | curatore | errore_campione | niente_letto |  | non_errore | chiuso/incrociata | chiuso/incrociata | chiuso/incrociata | chiuso/incrociata |  | nessuno |
| partizione_non_identica | GSE93624 |  | classe piu_fine | curatore | fattore_ignorato | niente_letto |  | non_errore | chiuso/piu_fine | chiuso/piu_fine | chiuso/piu_fine | non chiuso/non_chiuso |  | nessuno |
| atlas_non_ritrovato | GSE112057 | g2_g1 | 'Crohn disease' vs 'normal' | modello | mancante_non_dichiarato | niente_misurato |  | forma | no | uguale | no | uguale | uguale | G1 |
| atlas_non_ritrovato | GSE112057 | g2_g3 | 'oligoarticular juvenile idiopathic arthritis' vs 'normal' | modello | mancante_non_dichiarato | niente_misurato |  | forma | no | uguale | no | uguale | no | G1 |
| atlas_non_ritrovato | GSE112057 | g2_g4 | 'polyarticular juvenile idiopathic arthritis' vs 'normal' | modello | mancante_non_dichiarato | niente_misurato |  | forma | no | uguale | no | uguale | no | G1 |
| atlas_non_ritrovato | GSE112057 | g2_g5 | 'systemic-onset juvenile idiopathic arthritis' vs 'normal' | modello | mancante_non_dichiarato | niente_misurato |  | forma | no | uguale | no | uguale | no | G1 |
| atlas_non_ritrovato | GSE112057 | g2_g6 | 'ulcerative colitis (disease)' vs 'normal' | modello | mancante_non_dichiarato | niente_misurato |  | forma | no | uguale | no | uguale | no | G1 |
| atlas_non_ritrovato | GSE147507 | g2_g1 | 'Severe acute respiratory syndrome coronavirus 2 (USA-WA1/2020)' vs 'mock' in 'A549' at '24 hour' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE147507 | g4_g3 | 'Severe acute respiratory syndrome coronavirus 2 (USA-WA1/2020)' vs 'mock' in 'NHBE' at '24 hour' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | uguale | nessuno |
| atlas_non_ritrovato | GSE44379 | g2_g1 | 'arsenite' vs 'control' | curatore | repliche | niente_letto |  | non_errore | no | no | no | uguale | no | G1 |
| atlas_non_ritrovato | GSE46665 | g3_g1 | '180 days after left ventricular assist device placement' vs 'control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE46665 | g3_g2 | '7 days after left ventricular assist device placement' vs 'control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE49155 | g1_g2 | 'premalignant lesion' vs 'normal' | modello | fattori_uniti | non_osservato |  | modello | no | no | uguale | no | no | nessuno |
| atlas_non_ritrovato | GSE49155 | g1_g3 | 'squamous cell carcinoma' vs 'normal' | modello | fattori_uniti | non_osservato |  | modello | no | no | uguale | no | no | nessuno |
| atlas_non_ritrovato | GSE50760 | g2_g1 | 'colorectal cancer metastatic in the liver' vs 'normal' | modello | tipo_fattore | curatore | errore_campione | non_errore | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE50760 | g2_g3 | 'primary tumor' vs 'normal' | modello | tipo_fattore | curatore | errore_campione | non_errore | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57116 | g3_g1 | '3 h DRB 0 min 4sU' vs 'untreated' | modello | valore_senza_voce | modello | fattore_doppio | modello | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57116 | g3_g2 | '3 h DRB 8 min 4sU' vs 'untreated' | modello | valore_senza_voce | modello | fattore_doppio | modello | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57945 | g6_g1 | 'Crohn's disease, macroscopic ileal inflammation with deep ulcer' vs 'non inflammatory bowel disease… | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57945 | g6_g2 | 'Crohn's disease, macroscopic ileal inflammation without deep ulcer' vs 'non inflammatory bowel dise… | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57945 | g6_g3 | 'Crohn's disease, microscopic ileal inflammation without deep ulcer' vs 'non inflammatory bowel dise… | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57945 | g6_g4 | 'Crohn's disease, normal' vs 'non inflammatory bowel disease control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57945 | g6_g5 | 'Crohn's disease, undetermined' vs 'non inflammatory bowel disease control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE57945 | g6_g7 | 'ulcerative colitis' vs 'non inflammatory bowel disease control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE59781 | g2_g1 | 'PAX2 siRNA' vs 'control' | modello | forma_voci | niente_misurato |  | forma | uguale | uguale | no | uguale | uguale | G1 |
| atlas_non_ritrovato | GSE60340 | g7_g1 | 'aging cells' vs 'spontaneously immortal cells; control' | modello | valore_senza_voce | curatore | riferimento | non_errore | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE60340 | g7_g8 | 'young cells' vs 'spontaneously immortal cells; control' | modello | valore_senza_voce | curatore | riferimento | non_errore | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE60585 | g1_g2 | 'siRNAs against Integrator 11' vs 'control' in 'ribosomal RNA depleted whole cell RNA' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | no | no | nessuno |
| atlas_non_ritrovato | GSE60585 | g1_g3 | 'siRNAs against NELF' vs 'control' in 'ribosomal RNA depleted whole cell RNA' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | no | no | nessuno |
| atlas_non_ritrovato | GSE60585 | g4_g5 | 'siRNAs against Integrator 11' vs 'control' in 'whole-cell RNA' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | no | no | nessuno |
| atlas_non_ritrovato | GSE60585 | g4_g6 | 'siRNAs against NELF' vs 'control' in 'whole-cell RNA' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | no | no | nessuno |
| atlas_non_ritrovato | GSE63816 | g4_g1 | 'erythroleukemia; ZRSR2 shRNA' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE63816 | g4_g2 | 'myelodysplastic syndrome; ZRSR2 mutant' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE63816 | g4_g3 | 'myelodysplastic syndrome; ZRSR2 wild type' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE65335 | g3_g2 | 'untreated; air-liquid interface (day 14)' vs 'untreated; submerged (day 8)' | schema | context_senza_base | niente_letto |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE66207 | g4_g3 | 'Crohn's disease; B3, penetrating' vs 'non inflammatory bowel disease control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE66207 | g4_g2 | 'Crohn's disease; B2, stricturing' vs 'non inflammatory bowel disease control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE66207 | g4_g1 | 'Crohn's disease; B1, non-strictuing, non-penetrating' vs 'non inflammatory bowel disease control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE69597 | g4_g2 | 'brucellosis; acute brucellosis; complete remission' vs 'normal' | modello | forma_voci | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE69597 | g4_g5 | 'brucellosis; acute brucellosis; reinfection' vs 'normal' | modello | forma_voci | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE69597 | g4_g6 | 'brucellosis; acute brucellosis; relapse' vs 'normal' | modello | forma_voci | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE69597 | g4_g3 | 'brucellosis; chronic brucellosis; complete remission' vs 'normal' | modello | forma_voci | curatore | livelli_uniti | non_errore | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE69597 | g4_g7 | 'brucellosis; chronic brucellosis; relapse' vs 'normal' | modello | forma_voci | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE69597 | g4_g1 | 'Leishmaniasis' vs 'normal' | modello | forma_voci | niente_misurato |  | forma | uguale | uguale | no | no | no | nessuno |
| atlas_non_ritrovato | GSE75852 | g2_g4 | ' neural stem cell' vs 'induced pluripotent stem cell' in 'normal' | schema | context_senza_base | modello | fattore_doppio | modello | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE75852 | g1_g3 | ' neural stem cell' vs 'induced pluripotent stem cell' in 'Ataxia-telangiectasia' | schema | context_senza_base | modello | fattore_doppio | modello | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE77598 | g2_g1 | 'multiple sclerosis' vs 'normal' | curatore | fattore_ignorato | niente_letto |  | non_errore | no | no | no | no | no | nessuno |
| atlas_non_ritrovato | GSE83415 | g2_g1 | 'active, on treatment' vs 'remission, on treatment' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | no | no | verso_opposto | nessuno |
| atlas_non_ritrovato | GSE93624 | g2_g1 | 'Crohn's disease' vs 'non inflammatory bowel disease control' | curatore | fattore_ignorato | niente_letto |  | non_errore | no | no | no | no | no | nessuno |

## G1

### Prima causa per tipo di unità

|  | studio_non_chiuso | partizione_non_identica | atlas_non_ritrovato | lettore_errore | totale |
|---|---|---|---|---|---|
| curatore/errore_campione | 0 | 1 | 2 | 1 | 4 |
| curatore/fattore_ignorato | 0 | 0 | 3 | 0 | 3 |
| modello/colonna_fuori_fonti | 1 | 0 | 2 | 0 | 3 |
| modello/colonna_non_letterale | 1 | 0 | 6 | 0 | 7 |
| modello/fattore_doppio | 0 | 0 | 2 | 0 | 2 |
| modello/fattore_non_visto | 0 | 1 | 4 | 2 | 7 |
| modello/fattori_uniti | 3 | 0 | 9 | 1 | 13 |
| modello/forma_voci | 1 | 0 | 2 | 0 | 3 |
| modello/ruolo_soggetto | 0 | 2 | 3 | 0 | 5 |
| modello/valore_non_letterale | 6 | 0 | 13 | 0 | 19 |
| modello/valore_senza_voce | 5 | 0 | 19 | 0 | 24 |
| strumento/fattori_ridondanti | 0 | 0 | 0 | 3 | 3 |

### Che cosa resta, tolta la prima causa

|  | curatore/errore_campione | curatore/fattore_ignorato | curatore/riferimento | modello/fattori_uniti | modello/ruolo_soggetto | niente_letto | niente_misurato | non_osservato | schema/context_senza_base | totale |
|---|---|---|---|---|---|---|---|---|---|---|
| curatore/errore_campione | 0 | 0 | 0 | 0 | 0 | 4 | 0 | 0 | 0 | 4 |
| curatore/fattore_ignorato | 0 | 0 | 0 | 0 | 0 | 3 | 0 | 0 | 0 | 3 |
| modello/colonna_fuori_fonti | 0 | 0 | 0 | 1 | 1 | 0 | 1 | 0 | 0 | 3 |
| modello/colonna_non_letterale | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 7 | 0 | 7 |
| modello/fattore_doppio | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | 2 |
| modello/fattore_non_visto | 0 | 0 | 0 | 0 | 0 | 7 | 0 | 0 | 0 | 7 |
| modello/fattori_uniti | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 10 | 2 | 13 |
| modello/forma_voci | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 3 | 0 | 3 |
| modello/ruolo_soggetto | 1 | 0 | 0 | 0 | 0 | 4 | 0 | 0 | 0 | 5 |
| modello/valore_non_letterale | 0 | 1 | 2 | 0 | 0 | 0 | 0 | 16 | 0 | 19 |
| modello/valore_senza_voce | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 24 | 0 | 24 |
| strumento/fattori_ridondanti | 0 | 0 | 0 | 0 | 0 | 3 | 0 | 0 | 0 | 3 |

### Esito della catena

`non_errore`: nella catena c'è una scelta o un errore del curatore, o un limite della misura. `forma`: la sensibilità
dichiarata toglie il disaccordo (misurato). `vista_schema`: ogni causa è di vista o di schema (proposta non misurata).
`modello`: almeno una causa sta nella lettura del modello.

|  | forma | modello | non_errore | vista_schema | totale |
|---|---|---|---|---|---|
| studio_non_chiuso | 1 | 3 | 0 | 13 | 17 |
| partizione_non_identica | 0 | 2 | 2 | 0 | 4 |
| atlas_non_ritrovato | 0 | 20 | 8 | 37 | 65 |
| lettore_errore | 0 | 3 | 4 | 0 | 7 |

### G1: una riga per studio

| studio | disaccordi | che cosa differisce | prima causa | resto | in più | esito | sensibilità (forma; forma_na) | prova |
|---|---|---|---|---|---|---|---|---|
| GSE147507 | non chiuso; 2 confronti non ritrovati | Due voci di `assignment` portano 16 e 9 condizioni sulla stessa colonna: l'adattatore le rifiuta. Restano senza voce valori di `cell_line` (30 campioni), `treatment` (35), `time_point` (57) e `strain` (10). La vista porta 77 campioni di più sotto-serie; l'universo di Atlas ne ha 14. Lo studio non chiude nemmeno con la forma tollerata. | modello/forma_voci | non_osservato | modello/valore_senza_voce;vista/sotto_serie | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE46665 | non chiuso; 2 confronti non ritrovati | Il modello scrive un fattore di stato `donor_condition` dalla colonna `description`, con base «healthy_control» e 9 voci. La colonna porta la sigla del paziente e il tempo, e lo studio non ha controlli sani: 16 campioni restano scoperti. L'impianto del dispositivo (`LVAD_implant_time`) è scritto come fattore di tipo tempo, senza livello di base. | modello/valore_senza_voce | non_osservato | modello/fattore_inventato;modello/tipo_fattore | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE49155 | non chiuso; 2 confronti non ritrovati | Il modello scrive un fattore dalla colonna `cell type`, che è vuota in 10 campioni su 13: due voci hanno la stessa condizione e due livelli diversi (mappa ambigua, 10 campioni). In più scrive `patient` come fattore di stato e `pathology` come perturbazione. Lo studio non chiude. | modello/fattori_uniti | non_osservato | modello/ruolo_soggetto;modello/tipo_fattore | modello | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE54846 | non chiuso; 1 confronti non ritrovati | Il fattore `knockdown` (colonna `genotype/variation`) ha 2 voci con valori che la colonna non contiene: 6 campioni scoperti, lo studio non chiude. | modello/valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE57027 | non chiuso; 2 confronti non ritrovati | Il fattore `bait_expression` ha una voce con «Halo-NFkB1»; la colonna contiene «Halo-NfkB1». Restano scoperti 3 campioni e lo studio non chiude. | modello/valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE57945 | non chiuso; 6 confronti non ritrovati | Restano senza voce 1 campione di `disease_status`, 104 di `ileal_crohn_subphenotype` e 322 di `inflammation_type` e di `deep_ulcer_presence`. 6 + 4 voci hanno una forma che lo schema non ammette (condizioni sulla colonna del fattore padre). Il modello scrive come perturbazioni fattori che sono stati del paziente. Lo studio non chiude. | modello/valore_senza_voce | non_osservato | schema/annidato_colonna_padre;modello/tipo_fattore | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE60340 | non chiuso; 2 confronti non ritrovati | Il fattore `agent` ha una voce con un valore che la colonna non contiene: 12 campioni scoperti, lo studio non chiude. Lo studio non chiude per la voce non letterale. In più Atlas usa come riferimento le cellule immortali spontanee, che non sono un controllo. | modello/valore_non_letterale | non_osservato; curatore/riferimento |  | vista_schema; non_errore | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no | Nomi dei confronti di Atlas («... vs 'spontaneously immortal cells; control'») e colonna `passages` (oltre 200 contro 10-12, 17-19, 28-30). |
| GSE63816 | non chiuso; 3 confronti non ritrovati | Un valore di `disease_state` (6 campioni) resta senza voce. Il fattore `genetic_perturbation` ha voci sulla colonna `source_name_ch1` con valori che la colonna non contiene (22 voci in più). Lo studio non chiude. | modello/valore_senza_voce | non_osservato | modello/valore_non_letterale | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE65335 | non chiuso; 2 confronti non ritrovati | Una voce porta la condizione `treatment=untreated`, ma `treatment` non è fra le colonne di fonte del fattore: l'adattatore la rifiuta e lo studio non chiude. Con la colonna aggiunta alle fonti lo studio chiude e la partizione è identica. Lo studio non chiude per la voce con la colonna fuori dalle fonti. Con la forma tollerata il confronto non si ritrova: il fattore unisce la condizione di coltura e il trattamento, e nessuno dei due gruppi è al livello di base. Lo studio non chiude per la voce con la colonna fuori dalle fonti. Con la forma tollerata il confronto non si ritrova: il modello dà a `source_name_ch1` il ruolo di donatore e il costruttore scarta il confronto per soggetti disgiunti. | modello/colonna_fuori_fonti | niente_misurato; modello/fattori_uniti; modello/ruolo_soggetto | modello/fattori_uniti;modello/ruolo_soggetto | forma; modello | chiuso/identica; chiuso/identica // no; no |  |
| GSE66207 | non chiuso; 3 confronti non ritrovati | Il fattore `disease_behavior` legge la colonna `disease`, che non distingue i tre comportamenti: più voci hanno la stessa condizione e livelli diversi (mappa ambigua, 20 campioni) e 12 campioni restano senza voce. Il modello giudica non informativa la colonna `disease_stage`, che porta il comportamento della malattia. Lo studio non chiude. | modello/fattori_uniti | non_osservato | modello/valore_senza_voce;modello/fattore_non_visto | modello | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE69597 | non chiuso; 6 confronti non ritrovati | Restano senza voce 62 campioni del fattore `brucellosis_stage` e 62 del fattore `response_to_treatment`. Il modello scrive i due fattori come perturbazioni, con base «acute_brucellosis» e «complete_remission»: sono stati del paziente e valgono solo per i malati. Lo studio non chiude. | modello/valore_senza_voce | non_osservato | modello/tipo_fattore | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE71289 | non chiuso; 6 confronti non ritrovati | Il fattore `cell_type` ha 2 voci con valori che la colonna di fonte non contiene: 42 campioni scoperti, lo studio non chiude. | modello/valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE75852 | non chiuso; 4 confronti non ritrovati | Il fattore `cell_line_type` ha voci con la stessa condizione e livelli diversi (mappa ambigua, 12 campioni). Il fattore `time_point` ha 2 voci con 6 condizioni ciascuna, che l'adattatore rifiuta. Lo studio non chiude. Lo studio non chiude per la mappa ambigua. In più Atlas confronta due tipi cellulari, e per schema un fattore di contesto non ha livello di base. | modello/fattori_uniti | non_osservato; schema/context_senza_base | modello/forma_voci | modello | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE78936 | non chiuso; 6 confronti non ritrovati | Il fattore `disease_state` dichiara la colonna di fonte `disease`, che la tabella non ha (motivo: `colonna_ignota`). Lo studio non chiude. | modello/colonna_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE83415 | non chiuso; 1 confronti non ritrovati | Le voci del fattore di stadio portano valori che la colonna di fonte non contiene: 21 voci in più, 21 campioni scoperti, lo studio non chiude. | modello/valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE83687 | non chiuso; 2 confronti non ritrovati | Un campione (GSM2212638) resta senza voce e lo studio non chiude. | modello/valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no |  |
| GSE93624 | non chiuso; 1 confronti non ritrovati | Il modello scrive una voce con la stringa vuota per il valore «-» di `progression to complication`: 218 campioni restano scoperti e lo studio non chiude. Lo studio non chiude per la voce non letterale. Con la voce giusta (come in Mistral-Small 3.2) il confronto non si ritrova lo stesso: Atlas ignora il fattore `progression to complication` e confronta tutti i malati con i controlli. | modello/valore_non_letterale | non_osservato; curatore/fattore_ignorato |  | vista_schema; non_errore | non chiuso/non_chiuso; non chiuso/non_chiuso // no; no | Vista: `progression to complication` «yes» 27, «-» 218; Atlas confronta 209 malati con 35 controlli. |
| GSE50760 | partizione incrociata; 2 confronti non ritrovati; 1 confronti del lettore giudicati errore | Il lettore forma tre gruppi da 18 campioni, come le colonne `source_name_ch1` e `tissue` di GEO, e scrive i due confronti contro il tessuto normale (18 contro 18). Atlas ha 19 normali e 17 metastasi: un campione di metastasi sta fra i normali. La partizione è incrociata e i confronti di Atlas (17 contro 19, 18 contro 19) non si ritrovano. Il confronto del lettore (18 metastasi contro 18 normali) è giudicato «braccio misto» perché il gruppo dei normali di Atlas contiene un campione di metastasi. I bracci del lettore seguono GEO. | curatore/errore_campione | niente_letto | modello/ruolo_soggetto | non_errore | chiuso/incrociata; chiuso/incrociata // no; no | GEO: `source_name_ch1` e `tissue` danno 18/18/18 e il titolo del campione dice «metastasized cancer»; Atlas 19 normali e 17 metastasi. |
| GSE52778 | partizione piu_fine; 3 confronti non ritrovati | Il modello scrive il donatore (colonna `cell line`, 4 linee primarie) come fattore di stato senza livello di base. La partizione è più fine di Atlas (un gruppo per donatore e trattamento) e i 3 confronti di Atlas non si ritrovano. | modello/ruolo_soggetto | niente_letto |  | modello | chiuso/piu_fine; chiuso/piu_fine // no; no |  |
| GSE56787 | partizione piu_fine; 4 confronti del lettore giudicati errore | Il modello scrive `gender` come fattore di stato: la partizione è più fine di Atlas, perché ogni gruppo è diviso per sesso. Il fattore `disease_state` ha 9 livelli che uniscono la malattia e il tipo di campione (biopsia, mioblasti, miotubi). In più Atlas mette un campione di mioblasti di controllo nel gruppo dei miotubi. Il confronto del lettore oppone malati e controlli dello stesso tipo di campione, dentro un sesso (5 contro 4). Atlas scrive la stessa differenza due volte, in `disease` e in `genotype`: la misura la conta come due fattori. Il confronto del lettore oppone malati e controlli dello stesso tipo di campione, dentro un sesso (4 contro 5). Atlas scrive la stessa differenza due volte, in `disease` e in `genotype`: la misura la conta come due fattori. Il confronto del lettore oppone malati e controlli dello stesso tipo di campione, dentro un sesso (5 contro 5). Atlas scrive la stessa differenza due volte, in `disease` e in `genotype`: la misura la conta come due fattori. Il lettore confronta i miotubi FSHD2 con i controlli sani della biopsia (2 contro 4): i due bracci differiscono per la malattia e per il tipo di campione. Il fattore `disease_state` unisce le due variabili e il livello di base «healthy» è della sola biopsia. | modello/ruolo_soggetto; strumento/fattori_ridondanti; modello/fattori_uniti | curatore/errore_campione; niente_letto | modello/fattori_uniti; modello/ruolo_soggetto | non_errore; modello | chiuso/piu_fine; chiuso/piu_fine | Vista: `tissue` = «Control myoblasts», titolo `C21_blasts`; in Atlas `organism part` = myotube. |
| GSE60585 | partizione piu_grossa; 4 confronti non ritrovati; 2 confronti del lettore giudicati errore | Il modello giudica non informativa la colonna `molecule subtype`, che distingue l'RNA senza RNA ribosomale («ribosomal RNA depleted whole cell RNA», 9 campioni) dall'RNA totale («whole-cell RNA», 9). Il lettore forma 3 gruppi da 6 campioni; Atlas ne ha 6 da 3. La partizione è più grossa e i 4 confronti non si ritrovano. Il confronto del lettore (6 contro 6) unisce i due tipi di RNA nello stesso braccio: è giudicato «braccio misto». | modello/fattore_non_visto | niente_letto |  | modello | chiuso/piu_grossa; chiuso/piu_grossa // no; no |  |
| GSE57116 | 2 confronti non ritrovati | Il modello scrive due fattori dalla stessa informazione: `treatment` e il tempo di marcatura, che i valori di `treatment` contengono già. I due confronti di Atlas differiscono in più di un fattore (registro: `piu_di_un_fattore` 6). | modello/fattore_doppio | niente_letto |  | modello | no; no |  |
| GSE71595 | 2 confronti non ritrovati | Il lettore scrive anche il fattore `tissue`, che coincide con la diagnosi: sangue periferico nei sani, liquido sinoviale nei malati. I due confronti malati contro sani differiscono in due fattori (registro: `piu_di_un_fattore` 4). Atlas non scrive il tessuto. | curatore/fattore_ignorato | niente_letto |  | non_errore | no; no | Vista: `tissue` «Peripheral Blood» 8 = `diagnosis` «Healthy control» 8; «Synovial Fluid» 6 = «JIA patient» 6; fattori di Atlas: compound, disease, dose, non il tessuto. |
| GSE77598 | 1 confronti non ritrovati | Il lettore scrive due fattori, la malattia e l'aplotipo di MERTK, che dividono i campioni allo stesso modo. Atlas tiene solo la malattia. | curatore/fattore_ignorato | niente_letto |  | non_errore | no; no | Vista: `disease` 5 e 3, `mertk haplotype` 5 (rischio) e 3 (non rischio), stessi campioni. |

### G1: una riga per unità

`forma`, `forma_na` = la stessa unità nelle due sensibilità; `in_<modello>` = la stessa unità nella prima corsa di un altro modello; `oggi` = la pipeline di oggi sullo stesso confronto.

| tipo | studio | id | nome | causa | sotto | resto_causa | resto_sotto | esito | forma | forma_na | in_M | in_M0 | oggi | piu_grande |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| studio_non_chiuso | GSE147507 |  | non_coperta: cell_line: 30 campioni, per esempio GSM4462363 // non_coperta: treatment: 35 campioni, … | modello | forma_voci | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  |  |
| studio_non_chiuso | GSE46665 |  | non_coperta: donor_condition: 16 campioni, per esempio GSM1133661 | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  |  |
| studio_non_chiuso | GSE49155 |  | mappa_ambigua: cell_type: 10 campioni | modello | fattori_uniti | non_osservato |  | modello | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica | non chiuso/non_chiuso |  |  |
| studio_non_chiuso | GSE54846 |  | non_coperta: knockdown: 6 campioni, per esempio GSM1325074 | modello | valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica | chiuso/identica |  |  |
| studio_non_chiuso | GSE57027 |  | non_coperta: bait_expression: 3 campioni, per esempio GSM1373312 | modello | valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica | chiuso/identica |  |  |
| studio_non_chiuso | GSE57945 |  | non_coperta: disease_status: 1 campioni, per esempio GSM1598427 // non_coperta: ileal_crohn_subpheno… | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  |  |
| studio_non_chiuso | GSE60340 |  | non_coperta: agent: 12 campioni, per esempio GSM1473759 | modello | valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  |  |
| studio_non_chiuso | GSE63816 |  | non_coperta: disease_state: 6 campioni, per esempio GSM1558072 // non_coperta: genetic_perturbation:… | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  |  |
| studio_non_chiuso | GSE65335 |  | non_coperta: culture_condition: 6 campioni, per esempio GSM1592612 | modello | colonna_fuori_fonti | niente_misurato |  | forma | chiuso/identica | chiuso/identica | chiuso/identica | chiuso/identica |  |  |
| studio_non_chiuso | GSE66207 |  | mappa_ambigua: disease_behavior: 20 campioni // non_coperta: disease_behavior: 12 campioni, per esem… | modello | fattori_uniti | non_osservato |  | modello | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  |  |
| studio_non_chiuso | GSE69597 |  | non_coperta: brucellosis_stage: 62 campioni, per esempio GSM1704409 // non_coperta: response_to_trea… | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  |  |
| studio_non_chiuso | GSE71289 |  | non_coperta: cell_type: 42 campioni, per esempio GSM1833876 | modello | valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica | chiuso/identica |  |  |
| studio_non_chiuso | GSE75852 |  | mappa_ambigua: cell_line_type: 12 campioni // non_coperta: time_point: 12 campioni, per esempio GSM1… | modello | fattori_uniti | non_osservato |  | modello | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica | chiuso/identica |  |  |
| studio_non_chiuso | GSE78936 |  | colonna_ignota: disease_state <- disease | modello | colonna_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica | chiuso/identica |  |  |
| studio_non_chiuso | GSE83415 |  | non_coperta: disease_state: 21 campioni, per esempio GSM2202553 | modello | valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso |  |  |
| studio_non_chiuso | GSE83687 |  | non_coperta: tissue_type: 1 campioni, per esempio GSM2212638 | modello | valore_senza_voce | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/identica |  |  |
| studio_non_chiuso | GSE93624 |  | non_coperta: complicated_progression: 218 campioni, per esempio GSM2458832 | modello | valore_non_letterale | non_osservato |  | vista_schema | non chiuso/non_chiuso | non chiuso/non_chiuso | chiuso/piu_fine | chiuso/piu_fine |  |  |
| partizione_non_identica | GSE50760 |  | classe incrociata | curatore | errore_campione | niente_letto |  | non_errore | chiuso/incrociata | chiuso/incrociata | chiuso/incrociata | chiuso/incrociata |  |  |
| partizione_non_identica | GSE52778 |  | classe piu_fine | modello | ruolo_soggetto | niente_letto |  | modello | chiuso/piu_fine | chiuso/piu_fine | chiuso/identica | chiuso/identica |  |  |
| partizione_non_identica | GSE56787 |  | classe piu_fine | modello | ruolo_soggetto | curatore | errore_campione | non_errore | chiuso/piu_fine | chiuso/piu_fine | non chiuso/non_chiuso | non chiuso/non_chiuso |  |  |
| partizione_non_identica | GSE60585 |  | classe piu_grossa | modello | fattore_non_visto | niente_letto |  | modello | chiuso/piu_grossa | chiuso/piu_grossa | chiuso/identica | non chiuso/non_chiuso |  |  |
| atlas_non_ritrovato | GSE147507 | g2_g1 | 'Severe acute respiratory syndrome coronavirus 2 (USA-WA1/2020)' vs 'mock' in 'A549' at '24 hour' | modello | forma_voci | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE147507 | g4_g3 | 'Severe acute respiratory syndrome coronavirus 2 (USA-WA1/2020)' vs 'mock' in 'NHBE' at '24 hour' | modello | forma_voci | non_osservato |  | vista_schema | no | no | no | no | uguale |  |
| atlas_non_ritrovato | GSE46665 | g3_g1 | '180 days after left ventricular assist device placement' vs 'control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE46665 | g3_g2 | '7 days after left ventricular assist device placement' vs 'control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE49155 | g1_g2 | 'premalignant lesion' vs 'normal' | modello | fattori_uniti | non_osservato |  | modello | no | no | uguale | no | no |  |
| atlas_non_ritrovato | GSE49155 | g1_g3 | 'squamous cell carcinoma' vs 'normal' | modello | fattori_uniti | non_osservato |  | modello | no | no | uguale | no | no |  |
| atlas_non_ritrovato | GSE50760 | g2_g1 | 'colorectal cancer metastatic in the liver' vs 'normal' | curatore | errore_campione | niente_letto |  | non_errore | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE50760 | g2_g3 | 'primary tumor' vs 'normal' | curatore | errore_campione | niente_letto |  | non_errore | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE52778 | g4_g1 | 'albuterol' vs 'untreated' | modello | ruolo_soggetto | niente_letto |  | modello | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE52778 | g4_g3 | 'dexamethasone' vs 'untreated' | modello | ruolo_soggetto | niente_letto |  | modello | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE52778 | g4_g2 | 'albuterol and dexamethasone' vs 'untreated' | modello | ruolo_soggetto | niente_letto |  | modello | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE54846 | g1_g2 | 'expressing shRNA directed against macroH2A1' vs 'control' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | uguale |  |
| atlas_non_ritrovato | GSE57027 | g1_g3 | 'overexpression of Halo-RelA' vs 'control' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | uguale |  |
| atlas_non_ritrovato | GSE57027 | g1_g2 | 'overexpression of Halo-NfkB1' vs 'control' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | uguale |  |
| atlas_non_ritrovato | GSE57116 | g3_g1 | '3 h DRB 0 min 4sU' vs 'untreated' | modello | fattore_doppio | niente_letto |  | modello | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE57116 | g3_g2 | '3 h DRB 8 min 4sU' vs 'untreated' | modello | fattore_doppio | niente_letto |  | modello | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE57945 | g6_g1 | 'Crohn's disease, macroscopic ileal inflammation with deep ulcer' vs 'non inflammatory bowel disease… | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE57945 | g6_g2 | 'Crohn's disease, macroscopic ileal inflammation without deep ulcer' vs 'non inflammatory bowel dise… | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE57945 | g6_g3 | 'Crohn's disease, microscopic ileal inflammation without deep ulcer' vs 'non inflammatory bowel dise… | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE57945 | g6_g4 | 'Crohn's disease, normal' vs 'non inflammatory bowel disease control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE57945 | g6_g5 | 'Crohn's disease, undetermined' vs 'non inflammatory bowel disease control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE57945 | g6_g7 | 'ulcerative colitis' vs 'non inflammatory bowel disease control' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE60340 | g7_g1 | 'aging cells' vs 'spontaneously immortal cells; control' | modello | valore_non_letterale | curatore | riferimento | non_errore | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE60340 | g7_g8 | 'young cells' vs 'spontaneously immortal cells; control' | modello | valore_non_letterale | curatore | riferimento | non_errore | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE60585 | g1_g2 | 'siRNAs against Integrator 11' vs 'control' in 'ribosomal RNA depleted whole cell RNA' | modello | fattore_non_visto | niente_letto |  | modello | no | no | uguale | no | no |  |
| atlas_non_ritrovato | GSE60585 | g1_g3 | 'siRNAs against NELF' vs 'control' in 'ribosomal RNA depleted whole cell RNA' | modello | fattore_non_visto | niente_letto |  | modello | no | no | uguale | no | no |  |
| atlas_non_ritrovato | GSE60585 | g4_g5 | 'siRNAs against Integrator 11' vs 'control' in 'whole-cell RNA' | modello | fattore_non_visto | niente_letto |  | modello | no | no | uguale | no | no |  |
| atlas_non_ritrovato | GSE60585 | g4_g6 | 'siRNAs against NELF' vs 'control' in 'whole-cell RNA' | modello | fattore_non_visto | niente_letto |  | modello | no | no | uguale | no | no |  |
| atlas_non_ritrovato | GSE63816 | g4_g1 | 'erythroleukemia; ZRSR2 shRNA' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE63816 | g4_g2 | 'myelodysplastic syndrome; ZRSR2 mutant' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE63816 | g4_g3 | 'myelodysplastic syndrome; ZRSR2 wild type' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE65335 | g2_g1 | 'interleukin 13; 100 nanogram per milliliter' vs 'untreated' in 'air-liquid interface (day 14)' | modello | colonna_fuori_fonti | modello | fattori_uniti | modello | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE65335 | g3_g2 | 'untreated; air-liquid interface (day 14)' vs 'untreated; submerged (day 8)' | modello | colonna_fuori_fonti | modello | ruolo_soggetto | modello | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE66207 | g4_g3 | 'Crohn's disease; B3, penetrating' vs 'non inflammatory bowel disease control' | modello | fattori_uniti | non_osservato |  | modello | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE66207 | g4_g2 | 'Crohn's disease; B2, stricturing' vs 'non inflammatory bowel disease control' | modello | fattori_uniti | non_osservato |  | modello | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE66207 | g4_g1 | 'Crohn's disease; B1, non-strictuing, non-penetrating' vs 'non inflammatory bowel disease control' | modello | fattori_uniti | non_osservato |  | modello | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE69597 | g4_g2 | 'brucellosis; acute brucellosis; complete remission' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE69597 | g4_g5 | 'brucellosis; acute brucellosis; reinfection' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE69597 | g4_g6 | 'brucellosis; acute brucellosis; relapse' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE69597 | g4_g3 | 'brucellosis; chronic brucellosis; complete remission' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE69597 | g4_g7 | 'brucellosis; chronic brucellosis; relapse' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE69597 | g4_g1 | 'Leishmaniasis' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE71289 | g4_g1 | 'DISC1 exon 2 mut/mut' vs 'wild type' in 'neural progenitor cell' at 'embryoid body, day 17' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE71289 | g4_g2 | 'DISC1 exon 8 mut/mut' vs 'wild type' in 'neural progenitor cell' at 'embryoid body, day 17' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE71289 | g4_g3 | 'DISC1 exon 8 wt/mut' vs 'wild type' in 'neural progenitor cell' at 'embryoid body, day 17' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE71289 | g8_g5 | 'DISC1 exon 2 mut/mut' vs 'wild type' in 'neuron' at 'embryoid body, day 50' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE71289 | g8_g6 | 'DISC1 exon 8 mut/mut' vs 'wild type' in 'neuron' at 'embryoid body, day 50' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE71289 | g8_g7 | 'DISC1 exon 8 wt/mut' vs 'wild type' in 'neuron' at 'embryoid body, day 50' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE71595 | g2_g1 | 'juvenile idiopathic arthritis' vs 'normal' in 'JQ1; 300 nanomolar' | curatore | fattore_ignorato | niente_letto |  | non_errore | no | no | no | uguale | no |  |
| atlas_non_ritrovato | GSE71595 | g5_g3 | 'juvenile idiopathic arthritis' vs 'normal' in 'none' | curatore | fattore_ignorato | niente_letto |  | non_errore | no | no | no | uguale | no |  |
| atlas_non_ritrovato | GSE75852 | g2_g1 | 'Ataxia-telangiectasia' vs 'normal' in 'induced pluripotent stem cell' | modello | fattori_uniti | non_osservato |  | modello | no | no | uguale | uguale | uguale |  |
| atlas_non_ritrovato | GSE75852 | g4_g3 | 'Ataxia-telangiectasia' vs 'normal' in 'neural stem cell' | modello | fattori_uniti | non_osservato |  | modello | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE75852 | g2_g4 | ' neural stem cell' vs 'induced pluripotent stem cell' in 'normal' | modello | fattori_uniti | schema | context_senza_base | modello | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE75852 | g1_g3 | ' neural stem cell' vs 'induced pluripotent stem cell' in 'Ataxia-telangiectasia' | modello | fattori_uniti | schema | context_senza_base | modello | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE77598 | g2_g1 | 'multiple sclerosis' vs 'normal' | curatore | fattore_ignorato | niente_letto |  | non_errore | no | no | no | no | no |  |
| atlas_non_ritrovato | GSE78936 | g4_g1 | 'bipolar disorder' vs 'normal' in 'Brodmann (1909) area 11' | modello | colonna_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE78936 | g5_g2 | 'bipolar disorder' vs 'normal' in 'Brodmann (1909) area 24' | modello | colonna_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE78936 | g6_g3 | 'bipolar disorder' vs 'normal' in 'Brodmann (1909) area 9' | modello | colonna_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE78936 | g4_g7 | 'schizophrenia' vs 'normal' in 'Brodmann (1909) area 11' | modello | colonna_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE78936 | g5_g8 | 'schizophrenia' vs 'normal' in 'Brodmann (1909) area 24' | modello | colonna_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE78936 | g6_g9 | 'schizophrenia' vs 'normal' in 'Brodmann (1909) area 9' | modello | colonna_non_letterale | non_osservato |  | vista_schema | no | no | uguale | uguale | no |  |
| atlas_non_ritrovato | GSE83415 | g2_g1 | 'active, on treatment' vs 'remission, on treatment' | modello | valore_non_letterale | non_osservato |  | vista_schema | no | no | no | no | verso_opposto |  |
| atlas_non_ritrovato | GSE83687 | g2_g1 | 'Crohn's disease' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | uguale | no |  |
| atlas_non_ritrovato | GSE83687 | g2_g3 | 'ulcerative colitis' vs 'normal' | modello | valore_senza_voce | non_osservato |  | vista_schema | no | no | no | uguale | no |  |
| atlas_non_ritrovato | GSE93624 | g2_g1 | 'Crohn's disease' vs 'non inflammatory bowel disease control' | modello | valore_non_letterale | curatore | fattore_ignorato | non_errore | no | no | no | no | no |  |
| lettore_errore | GSE50760 | g2_g1 | confronto del lettore g2_g1 (18/18), giudizio braccio_misto | curatore | errore_campione | niente_letto |  | non_errore |  |  |  |  |  |  |
| lettore_errore | GSE56787 | g1_g5 | confronto del lettore g1_g5 (5/4), giudizio piu_fattori | strumento | fattori_ridondanti | niente_letto |  | non_errore |  |  |  |  |  |  |
| lettore_errore | GSE56787 | g2_g6 | confronto del lettore g2_g6 (3/5), giudizio piu_fattori | strumento | fattori_ridondanti | niente_letto |  | non_errore |  |  |  |  |  |  |
| lettore_errore | GSE56787 | g4_g6 | confronto del lettore g4_g6 (5/5), giudizio piu_fattori | strumento | fattori_ridondanti | niente_letto |  | non_errore |  |  |  |  |  |  |
| lettore_errore | GSE56787 | g14_g5 | confronto del lettore g14_g5 (2/4), giudizio piu_fattori | modello | fattori_uniti | niente_letto |  | modello |  |  |  |  |  |  |
| lettore_errore | GSE60585 | g1_g3 | confronto del lettore g1_g3 (6/6), giudizio braccio_misto | modello | fattore_non_visto | niente_letto |  | modello |  |  |  |  |  |  |
| lettore_errore | GSE60585 | g2_g3 | confronto del lettore g2_g3 (6/6), giudizio braccio_misto | modello | fattore_non_visto | niente_letto |  | modello |  |  |  |  |  |  |
