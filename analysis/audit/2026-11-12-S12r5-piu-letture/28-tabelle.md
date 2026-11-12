# S12r5 - tabelle del finding (generate da 28-tabelle.py)

## 1. I 24 studi segnalati

| studio | stato in `B0` | errori di `B0` | letture diverse da `B0` | classe | etichette nuove |
|---|---|---|---|---|---|
| `GSE103501` | identica | 0 | 1 (L5) | non errore | - |
| `GSE112057` | identica | 0 | 6 (L1 L2 L4 L5 L7 L8) | tocca un errore di lettura | NA di ancestry non dichiarato mancante; NA di gender non dichiarato mancante |
| `GSE147507` | identica | 0 | 4 (L2 L3 L4 L8) | tocca un errore di lettura | controlli senza livello (ruxolitinib, strain); fattore organism inventato da cell type; ruxolitinib assegnato a 3 campioni che non lo ricevono; tempi di 4 e 6 ore a non applicabile; trattamento diviso in due fattori (infezione, IFNB) |
| `GSE46665` | diversa | 2 (costa) | 1 (L3) | tocca un errore di lettura | - |
| `GSE49155` | identica | 1 (costa) | 1 (L4) | tocca un errore di lettura | - |
| `GSE49608` | identica | 0 | 2 (L3 L6) | forma | - |
| `GSE50499` | non chiuso | 0 | 3 (L3 L5 L8) | forma | - |
| `GSE50760` | diversa | 1 | 3 (L1 L4 L5) | tocca un errore di lettura | tessuto come contesto senza base |
| `GSE53280` | identica | 0 | 1 (L3) | tocca un errore di lettura | controllo mock senza livello |
| `GSE56235` | identica | 0 | 1 (L6) | non errore | - |
| `GSE56691` | identica | 0 | 3 (L4 L5 L7) | tocca un errore di lettura | controllo non trattato senza livello |
| `GSE56787` | diversa | 0 | 6 (L1 L2 L4 L6 L7 L8) | non errore | - |
| `GSE57116` | identica | 0 | 1 (L3) | tocca un errore di lettura | tempo ripetuto come secondo fattore |
| `GSE57945` | diversa | 1 (costa) | 1 (L2) | tocca un errore di lettura | eta' come fattore di contesto |
| `GSE60340` | diversa | 1 (costa) | 5 (L2 L3 L5 L6 L7) | tocca un errore di lettura | base non scritta; nessun trattamento diviso in tre livelli; passaggio come fattore |
| `GSE60585` | identica | 0 | 3 (L4 L5 L7) | non errore | - |
| `GSE63816` | non chiuso | 0 | 5 (L2 L3 L5 L6 L7) | tocca un errore di lettura | age come donatore; genotipo ZRSR2 non letto; shRNA letto da source_name_ch1 |
| `GSE65335` | identica | 0 | 5 (L2 L3 L4 L6 L7) | non errore | - |
| `GSE66573` | identica | 1 | 7 (L1 L2 L3 L5 L6 L7 L8) | tocca un errore di lettura | - |
| `GSE67812` | identica | 0 | 4 (L3 L4 L5 L8) | tocca un errore di lettura | controlli scritti come DM1 |
| `GSE68919` | identica | 0 | 5 (L1 L2 L5 L6 L7) | tocca un errore di lettura | controllo PBS senza livello |
| `GSE69597` | diversa | 0 | 2 (L5 L8) | tocca un errore di lettura | paese come fattore |
| `GSE71289` | identica | 0 | 1 (L3) | non errore | - |
| `GSE83687` | diversa | 0 | 6 (L1 L2 L4 L6 L7 L8) | tocca un errore di lettura | ileo come non applicabile |

La colonna «errori di `B0`» conta i 9 errori depositati. La revisione indipendente ha trovato in `B0` un errore in piu', fuori dai 9 e non contato qui: `GSE147507:tempo letto da una sola delle due colonne`. Non e' fra le etichette nuove.

## 2. Gli studi non segnalati, per stato in `B0`

- stato diversa, errori di `B0` 0: 2 studi
- stato identica, errori di `B0` 0: 19 studi
- stato identica, errori di `B0` 1: 2 studi
- non segnalati con gruppi diversi dai curatori in `B0`: `GSE44379`, `GSE93624`

## 3. Confronti ritrovati: gli studi in cui una lettura nuova cambia il conto di `B0` (dichiarata dopo i numeri)

| lettura | ritrovati su 95 | differenza da `B0` | studi che cambiano |
|---|---|---|---|
| `L1` | 62 | -6 | `GSE112057` 5→0 (identica); `GSE68919` 1→0 (non chiuso) |
| `L2` | 68 | +0 | `GSE65335` 1→2 (identica); `GSE68919` 1→0 (non chiuso) |
| `L3` | 67 | -1 | `GSE147507` 2→0 (non chiuso); `GSE50499` 0→1 (identica); `GSE53280` 1→0 (non chiuso); `GSE65335` 1→2 (identica) |
| `L4` | 71 | +3 | `GSE49155` 0→2 (identica); `GSE65335` 1→2 (identica) |
| `L5` | 58 | -10 | `GSE112057` 5→0 (identica); `GSE50499` 0→1 (identica); `GSE68919` 1→0 (non chiuso); `GSE69597` 5→0 (diversa) |
| `L6` | 70 | +2 | `GSE60340` 0→2 (identica); `GSE65335` 1→2 (identica); `GSE68919` 1→0 (non chiuso) |
| `L7` | 63 | -5 | `GSE112057` 5→0 (identica); `GSE65335` 1→2 (identica); `GSE68919` 1→0 (non chiuso) |
| `L8` | 67 | -1 | `GSE147507` 2→0 (non chiuso); `GSE50499` 0→1 (identica) |

Somma delle differenze sulle 8 letture, per studio: `GSE112057` -15; `GSE68919` -5; `GSE69597` -5; `GSE147507` -4; `GSE53280` -1; `GSE49155` +2; `GSE60340` +2; `GSE50499` +3; `GSE65335` +5

## 4. Errori di lettura per lettura (dichiarata dopo i numeri)

| lettura | errori di `B0` presenti (su 9) | studi con un errore nuovo | etichette nuove | quali studi |
|---|---|---|---|---|
| `L1` | 8 | 3 | 4 | `GSE112057`, `GSE50760`, `GSE68919` |
| `L2` | 8 | 5 | 6 | `GSE112057`, `GSE57945`, `GSE60340`, `GSE63816`, `GSE68919` |
| `L3` | 7 | 5 | 8 | `GSE147507`, `GSE53280`, `GSE57116`, `GSE63816`, `GSE67812` |
| `L4` | 8 | 6 | 7 | `GSE112057`, `GSE147507`, `GSE50760`, `GSE56691`, `GSE67812`, `GSE83687` |
| `L5` | 7 | 8 | 12 | `GSE112057`, `GSE50760`, `GSE56691`, `GSE60340`, `GSE63816`, `GSE67812`, `GSE68919`, `GSE69597` |
| `L6` | 7 | 2 | 2 | `GSE63816`, `GSE68919` |
| `L7` | 7 | 3 | 4 | `GSE112057`, `GSE56691`, `GSE68919` |
| `L8` | 8 | 4 | 5 | `GSE112057`, `GSE147507`, `GSE67812`, `GSE83687` |

Etichette nuove distinte: 22, in 13 studi. Unione con i 9 errori di `B0`: 31 etichette in 18 studi.
Errori per lettura (i 9 depositati presenti piu' le etichette nuove; `B0` 9): L1 12, L2 14, L3 15, L4 15, L5 19, L6 9, L7 11, L8 13. L'errore aggiunto dalla revisione e' presente in tutte le 9 letture: con quello ogni conto cresce di 1.
Etichette nuove distinte, cumulate nell'ordine `L1`…`L8`: L1 4 (3 studi); L2 8 (6 studi); L3 14 (10 studi); L4 17 (12 studi); L5 20 (13 studi); L6 21 (13 studi); L7 21 (13 studi); L8 22 (13 studi).

## 5. Le 38 schede

| scheda | causa | dove | etichette nella lettura nuova |
|---|---|---|---|
| `GSE103501|3d36c1a7730a|da51d3ac` | non errore | in nessuna | - |
| `GSE112057|76a7c486113f|05690bdd` | lettura del modello | nella lettura nuova | GSE112057:NA di gender non dichiarato mancante; GSE112057:NA di ancestry non dichiarato mancante |
| `GSE112057|d62cd9d66170|c25deea5` | lettura del modello | nella lettura nuova | GSE112057:NA di ancestry non dichiarato mancante |
| `GSE147507|176d2a969095|0c9f8029` | lettura del modello | in tutte e due | GSE147507:trattamento diviso in due fattori (infezione, IFNB); GSE147507:tempi di 4 e 6 ore a non applicabile; GSE147507:fattore organism inventato da cell type; GSE147507:tempo letto da una sola delle due colonne |
| `GSE147507|6e8f57fbd9a5|2060fa8c` | lettura del modello | in tutte e due | GSE147507:trattamento diviso in due fattori (infezione, IFNB); GSE147507:tempo letto da una sola delle due colonne; GSE147507:ruxolitinib assegnato a 3 campioni che non lo ricevono |
| `GSE147507|9f155929b5d0|0c9f8029` | lettura del modello | nella lettura nuova | GSE147507:controlli senza livello (ruxolitinib, strain); GSE147507:tempo letto da una sola delle due colonne; GSE147507:ruxolitinib assegnato a 3 campioni che non lo ricevono |
| `GSE147507|b738508cf3df|d937fe8f` | lettura del modello | in tutte e due | GSE147507:tempo letto da una sola delle due colonne |
| `GSE46665|9582349882d5|c3219da1` | lettura del modello | in B0 | GSE46665:sigle dei pazienti come malattie |
| `GSE49155|66212ce60896|84545a0e` | lettura del modello | in B0 | - |
| `GSE49608|5c490d073b98|0c9f8029` | forma | in nessuna | - |
| `GSE49608|5c490d073b98|2aac5829` | non errore | in nessuna | - |
| `GSE50499|da98547423d3|6298f733` | forma | in nessuna | - |
| `GSE50499|fcba6c09e0a4|6298f733` | forma | in nessuna | - |
| `GSE50760|a6dd321f4dc0|29992090` | lettura del modello | nella lettura nuova | GSE50760:tessuto come contesto senza base; GSE50760:source_name_ch1 come donatore |
| `GSE53280|0b6239a2e318|0c9f8029` | lettura del modello | nella lettura nuova | GSE53280:controllo mock senza livello |
| `GSE56235|2a0f070d3da2|4a82d6cd` | non errore | in nessuna | - |
| `GSE56691|111d229309ad|0c9f8029` | lettura del modello | nella lettura nuova | GSE56691:controllo non trattato senza livello |
| `GSE56787|12ad9182f3ba|73a391bf` | non errore | in nessuna | - |
| `GSE57116|c37409409645|96ec7e0c` | lettura del modello | nella lettura nuova | GSE57116:tempo ripetuto come secondo fattore |
| `GSE57945|6c079af72d99|0c9f8029` | lettura del modello | nella lettura nuova | GSE57945:sesso come fattore; GSE57945:eta' come fattore di contesto |
| `GSE60340|5ec302b13e8b|75c46680` | lettura del modello | in tutte e due | GSE60340:colonna del trattamento non vista |
| `GSE60340|f307254c2df8|00111868` | lettura del modello | nella lettura nuova | GSE60340:colonna del trattamento non vista; GSE60340:passaggio come fattore |
| `GSE60340|f88c0bb58658|0c9f8029` | lettura del modello | in B0 | - |
| `GSE60340|f88c0bb58658|514f21a8` | lettura del modello | in B0 | - |
| `GSE60340|f9a717c76e3d|4ffd8489` | lettura del modello | in tutte e due | GSE60340:base non scritta; GSE60340:nessun trattamento diviso in tre livelli; GSE60340:passaggio come fattore |
| `GSE60585|fdabeb4309e2|73e24377` | non errore | in nessuna | - |
| `GSE63816|17660776ac46|0c9f8029` | lettura del modello | nella lettura nuova | GSE63816:age come donatore |
| `GSE63816|41564f163411|0c9f8029` | non errore | in nessuna | - |
| `GSE63816|48b16d2d48cc|0c9f8029` | lettura del modello | nella lettura nuova | GSE63816:genotipo ZRSR2 non letto; GSE63816:shRNA letto da source_name_ch1 |
| `GSE65335|69079952891b|d1fc7ae6` | non errore | in nessuna | - |
| `GSE66573|633fc3373743|34fd6a3b` | lettura del modello | in B0 | - |
| `GSE67812|0fa6d852d97e|7f5a8b72` | lettura del modello | nella lettura nuova | GSE67812:controlli scritti come DM1 |
| `GSE68919|77e51d4c9b22|0c9f8029` | lettura del modello | nella lettura nuova | GSE68919:controllo PBS senza livello |
| `GSE69597|5d94015d9663|dfae353f` | lettura del modello | nella lettura nuova | GSE69597:paese come fattore |
| `GSE69597|9e2a6d6e69a7|4db9efdf` | non errore | in nessuna | - |
| `GSE71289|11e3bc8e3f80|a299e5b1` | non errore | in nessuna | - |
| `GSE83687|709dd1724b3e|f424c1c9` | lettura del modello | nella lettura nuova | GSE83687:ileo come non applicabile |
| `GSE83687|8b4f154a1d3d|0c9f8029` | forma | in nessuna | - |

## 6. Le coppie (studio, lettura) con un errore nuovo, per stato della lettura (dichiarata dopo i numeri)

Coppie con un errore nuovo: 36. Per stato della lettura: diversa 7; identica 13; non chiuso 16.
- diversa: `GSE50760` L1 (0/0), `GSE50760` L4 (0/0), `GSE50760` L5 (0/0), `GSE60340` L2 (0/0), `GSE69597` L5 (0/5), `GSE83687` L4 (0/0), `GSE83687` L8 (0/0)
- identica: `GSE112057` L1 (0/5), `GSE112057` L2 (5/5), `GSE112057` L4 (5/5), `GSE112057` L5 (0/5), `GSE112057` L7 (0/5), `GSE112057` L8 (5/5), `GSE147507` L4 (2/2), `GSE57116` L3 (2/2), `GSE60340` L5 (0/0), `GSE67812` L3 (0/0), `GSE67812` L4 (0/0), `GSE67812` L5 (0/0), `GSE67812` L8 (0/0)
- non chiuso: `GSE147507` L3 (0/2), `GSE147507` L8 (0/2), `GSE53280` L3 (0/1), `GSE56691` L4 (0/0), `GSE56691` L5 (0/0), `GSE56691` L7 (0/0), `GSE57945` L2 (0/0), `GSE63816` L2 (0/0), `GSE63816` L3 (0/0), `GSE63816` L5 (0/0), `GSE63816` L6 (0/0), `GSE68919` L1 (0/1), `GSE68919` L2 (0/1), `GSE68919` L5 (0/1), `GSE68919` L6 (0/1), `GSE68919` L7 (0/1)

Fra parentesi: confronti ritrovati nella lettura nuova / in `B0`.
