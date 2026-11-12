# S12r5 - i disaccordi fra l'agente e il revisore, uno per uno (generato da 35-aggiudica.py)

Schede: 38. In disaccordo su causa, dove o etichette: 9 (causa 5, dove 6, etichette 7).

| lettura | cause | dove |
|---|---|---|
| dell'agente, prima della revisione | lettura del modello 21, forma 6, non errore 11 | in B0 4, nella lettura nuova 15, in tutte e due 2, in nessuna 17 |
| del revisore | lettura del modello 25, forma 4, non errore 9 | in B0 5, nella lettura nuova 15, in tutte e due 5, in nessuna 13 |
| dell'agente, dopo l'aggiudicazione | lettura del modello 25, forma 4, non errore 9 | in B0 5, nella lettura nuova 15, in tutte e due 5, in nessuna 13 |

Dopo l'aggiudicazione causa e dove sono diversi dal revisore in 0 schede.

## `GSE112057|76a7c486113f|05690bdd`

- **io, prima:** lettura del modello; nella lettura nuova; GSE112057:NA di gender non dichiarato mancante
- **il revisore:** lettura del modello; nella lettura nuova; GSE112057:NA di gender non dichiarato mancante;GSE112057:NA di ancestry non dichiarato mancante
- **dopo:** lettura del modello; nella lettura nuova; GSE112057:NA di gender non dichiarato mancante;GSE112057:NA di ancestry non dichiarato mancante
- **esito:** ha ragione il revisore. La mia descrizione nomina gender e ancestry, la mia etichetta solo gender: omissione mia.

## `GSE112057|d62cd9d66170|c25deea5`

- **io, prima:** non errore; in nessuna; nessuna etichetta
- **il revisore:** lettura del modello; nella lettura nuova; GSE112057:NA di ancestry non dichiarato mancante
- **dopo:** lettura del modello; nella lettura nuova; GSE112057:NA di ancestry non dichiarato mancante
- **esito:** ha ragione il revisore (criterio C1). B0 dichiara NA mancante per ancestry, la lettura nuova no: e' un errore senza effetto (5/5), e S12r4 conta errori senza effetto fra i 9 di B0. S12r4 non aveva contato questa firma.

## `GSE147507|176d2a969095|0c9f8029`

- **io, prima:** lettura del modello; nella lettura nuova; GSE147507:trattamento diviso in due fattori (infezione, IFNB);GSE147507:fattori ACE2 e ruxolitinib letti da source_name_ch1;GSE147507:tempi di 4 e 6 ore a non applicabile
- **il revisore:** lettura del modello; in tutte e due; GSE147507:fattore organism inventato da cell type;GSE147507:tempi 4 e 6 ore scritti come non applicabile;GSE147507:time point non letta
- **dopo:** lettura del modello; in tutte e due; GSE147507:trattamento diviso in due fattori (infezione, IFNB);GSE147507:tempi di 4 e 6 ore a non applicabile;GSE147507:fattore organism inventato da cell type;GSE147507:tempo letto da una sola delle due colonne
- **esito:** in parte: 3 punti al revisore, 1 a me. Al revisore: organism (descritto da me e non etichettato), il tempo letto da una colonna sola (verificato sulle uscite), ACE2 e ruxolitinib da source_name_ch1 sono fattori veri con un ruolo incoerente (forma, criterio C4: tolgo la mia etichetta). A me: in L3 la colonna treatment e' divisa in infection e interferon_beta_treatment (verificato sull'uscita), il revisore non lo etichetta.

## `GSE147507|6e8f57fbd9a5|2060fa8c`

- **io, prima:** lettura del modello; nella lettura nuova; GSE147507:trattamento diviso in due fattori (infezione, IFNB)
- **il revisore:** lettura del modello; in tutte e due; GSE147507:IFNB non applicabile sull'infezione;GSE147507:time point non letta
- **dopo:** lettura del modello; in tutte e due; GSE147507:trattamento diviso in due fattori (infezione, IFNB);GSE147507:tempo letto da una sola delle due colonne;GSE147507:ruxolitinib assegnato a 3 campioni che non lo ricevono
- **esito:** ha ragione il revisore; in piu' un errore che nessuno dei due aveva etichettato. La sua etichetta «IFNB non applicabile sull'infezione» e' la mia «trattamento diviso in due fattori». In piu' il tempo e' letto da una colonna sola, come in B0 ma dall'altra colonna (verificato). In piu', verificato sulla vista dopo la revisione: il ruxolitinib e' assegnato a 6 campioni (GSM4486160-65) e solo GSM4486163-65 lo ricevono.

## `GSE147507|9f155929b5d0|0c9f8029`

- **io, prima:** lettura del modello; nella lettura nuova; GSE147507:controlli senza livello (ruxolitinib, strain)
- **il revisore:** lettura del modello; nella lettura nuova; GSE147507:controlli senza livello (ruxolitinib, strain);GSE147507:time after treatment non letta
- **dopo:** lettura del modello; nella lettura nuova; GSE147507:controlli senza livello (ruxolitinib, strain);GSE147507:tempo letto da una sola delle due colonne;GSE147507:ruxolitinib assegnato a 3 campioni che non lo ricevono
- **esito:** ha ragione il revisore; in piu' un errore che nessuno dei due aveva etichettato. L8 ha la lettura del tempo di B0 (solo time point): l'errore e' presente anche qui e non fa la differenza da B0. In piu', verificato sulla vista dopo la revisione: il ruxolitinib e' assegnato a 6 campioni (GSM4486160-65) e solo GSM4486163-65 lo ricevono.

## `GSE147507|b738508cf3df|d937fe8f`

- **io, prima:** non errore; in nessuna; nessuna etichetta
- **il revisore:** lettura del modello; in tutte e due; GSE147507:time point non letta
- **dopo:** lettura del modello; in tutte e due; GSE147507:tempo letto da una sola delle due colonne
- **esito:** ha ragione il revisore. Verificato sulle 9 uscite: time point (20 campioni con un valore) e time after treatment (45) sono complementari e ogni lettura ne legge una sola, l'altra ha ruolo uninformative. B0 dichiara 12hrs, 4hrs e 6hrs senza campioni. E' il limite «una variabile scritta in piu' colonne» della spec (S12r3, punto 5): il modello doveva leggere una colonna intera o scrivere not_understood, e non lo fa. S12r3 e S12r4 non lo hanno contato come errore.

## `GSE60340|f88c0bb58658|0c9f8029`

- **io, prima:** forma; in nessuna; nessuna etichetta
- **il revisore:** lettura del modello; in B0; nessuna etichetta
- **dopo:** lettura del modello; in B0; nessuna etichetta
- **esito:** ha ragione il revisore (criterio C2). La lettura di L7 e' giusta e B0 non vede il trattamento: la differenza nasce dall'errore di B0, come nella scheda di L6 con la stessa firma. Che L7 non chiuda e' forma, ma non e' la causa della differenza.

## `GSE63816|17660776ac46|0c9f8029`

- **io, prima:** non errore; in nessuna; nessuna etichetta
- **il revisore:** lettura del modello; nella lettura nuova; GSE63816:age come donatore
- **dopo:** lettura del modello; nella lettura nuova; GSE63816:age come donatore
- **esito:** ha ragione il revisore (criterio C1). age come subject/donor al posto di subject/age: stesso tipo di errore di «source_name_ch1 come donatore», che S12r4 conta fra i 9 di B0. Senza effetto.

## `GSE63816|41564f163411|0c9f8029`

- **io, prima:** forma; in nessuna; nessuna etichetta
- **il revisore:** non errore; in nessuna; nessuna etichetta
- **dopo:** non errore; in nessuna; nessuna etichetta
- **esito:** ha ragione il revisore (criterio C2). Il motivo di forma (not_applicable) e' uguale in B0 e non fa la differenza. La differenza e' l'unione dei due shRNA in un livello, come fa Atlas: difendibile.

