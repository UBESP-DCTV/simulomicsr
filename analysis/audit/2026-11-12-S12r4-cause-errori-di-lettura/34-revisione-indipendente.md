> **Nota dell'autore della sessione (non del revisore).** Questo è il rapporto del revisore, copiato senza cambi dalla cartella
> temporanea della sessione. I suoi script sono copiati in `34-revisione-script/` (il rapporto li cita col percorso
> temporaneo `…/scratchpad/rev/`). Il revisore ha lavorato sui file del commit `68c3252`, prima della correzione del
> rilievo R5: dopo la correzione alcuni numeri del rapporto cambiano (stati 1.359 assente, 433 presente, 6 non
> valutabile; «più cambi» 20, «una direzione sola» 6; peggioramenti 109 / 33 / 14). L'esito di ogni rilievo sta nel
> finding `docs/findings/2026-11-12-S12r4-cause-errori-di-lettura.md`, §13.

# Revisione indipendente della sessione sulle cause degli errori di lettura (S12r4)

Data: 2026-11-12. Revisore: subagente Claude, audit interno, in sola lettura.
Cartella di evidenza `D/` = `/home/user/simulomicsr/analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/`.
Uscite grezze: `/home/user/simulomicsr/analysis/p4-output/S12r4-forme/<forma>.jsonl`.
I miei script stanno in `/tmp/claude-1000/-home-user-simulomicsr/2676cd47-181f-464d-ad87-e31fb720e8a6/scratchpad/rev/`
(`ricalcolo.py`, `performa.py`, `leggi_grezzo.py`, `quattro.py`). Non ho scritto nel repository, non ho rilanciato
`27-diagnosi.R`, non ho aperto studi fuori dai 47 di sviluppo.

**Conclusione in tre frasi.** I numeri delle tabelle si ricalcolano tutti: non ho trovato un numero sbagliato.
La conclusione «la forma finale è `B0`, senza cambi» regge con ogni lettura della regola che ho provato. Il rilievo
nuovo più importante è sul conto degli errori nuovi: vede solo gli studi peggiorati, e per etichetta gli errori nati
sono di più (per `RA1` 8 contro 2), con una frase del finding che mescola i due conti.

Legenda: **[V]** = verificato da me sul codice, sui CSV o sull'uscita grezza. **[D]** = dedotto, non ricalcolato.
«Già dichiarato» = l'autore lo scrive nel codice o nel finding
(`/home/user/simulomicsr/docs/findings/2026-11-12-S12r4-cause-errori-di-lettura.md`); l'ho visto solo dopo i miei
conti, con una ricerca per parole, e lo riporto come conferma indipendente.

---

## 1. Rilievi, dal più grave

### R1. Il conto «studi con un errore nuovo» vede solo le righe peggiorate; una frase del finding mescola due conti [V]

- **Che cosa.** `errore_nuovo` vale solo per uno studio che ha un «peggioramento» (`00-previsioni.md` §4, criteri
  1-6) e solo se la causa della scheda è «lettura del modello». Un errore di lettura che nasce in uno studio non
  peggiorato, o migliorato, non si conta. Il codice applica §4 alla lettera. `27-stati.csv` però segna quegli
  stessi errori come «presente».
- **Prova 1** (`rev/performa.py`, da `27-stati.csv`): studi con un'etichetta di errore «presente» nella forma e non
  «presente» nella base, contro `studi_con_errore_nuovo`: `RP` 13 contro 8; `RPa` 4 contro 3; `RPb` 9 contro 7;
  `RPc` 4 contro 2; `RPd` 7 contro 4; `RP5` 5 contro 2; `RC` 5 contro 2; `RC3` 0 contro 0; `RA1` 8 contro 2;
  `RA4` 2 contro 1; `RR` 5 contro 3; `F1` 14 contro 11; `F2` 5 contro 3.
- **Prova 2, una frase che non torna.** Il finding (§5.2, righe 385-387) scrive: «`RA1` toglie 4 errori presenti in
  `B0` […] e ne fa nascere 2 (`GSE47718`, `GSE63816`); `RC` ne toglie 3 e ne fa nascere 2». La tabella dello stesso
  finding (§3.1) dà errori presenti 9 in `B0`, 13 in `RA1`, 12 in `RC`. Con 9 − 4 + 2 si arriva a 7, non a 13.
  Da `27-stati.csv`: `RA1` toglie 4 etichette e ne fa nascere 8 (in 8 studi); `RC` ne toglie 3 e ne fa nascere 6
  (in 5 studi); `RP` 3 e 14; `F1` 4 e 14; `F2` 2 e 5. I «tolti» della frase sono contati per etichetta, i «nati»
  per riga peggiorata.
- **Gli 8 nati in `RA1`:** `GSE147507:ceppo dei controlli scritto come non dichiarato`, `GSE47718:source_name_ch1
  come donatore`, `GSE50760:tessuto come contesto senza base`, `GSE57116:tempo ripetuto come secondo fattore`,
  `GSE57945:l2 type come secondo fattore di malattia`, `GSE63816:MDS scritta come non dichiarata`,
  `GSE67812:controlli scritti come DM1`, `GSE83687:sede del prelievo scritta come non dichiarata`. Sono gli stessi 8
  errori con esito «della forma (A1)».
- **Esempio letto sull'uscita grezza.** In `RC`, `GSE67812`: i tre controlli vanno al livello `dm1`. Lo stato dello
  studio resta «identica» (Atlas ha un gruppo solo) e i confronti restano 0. Quindi non è un peggioramento e non è
  un errore nuovo di `RC`. Altri nati non contati in `RC`: `GSE50760:tessuto come contesto senza base`,
  `GSE63816:genotipo ZRSR2 non letto`, `GSE63816:shRNA letto da source_name_ch1`.
- **Che cosa cambia.** Previsione 11: la mediana fra le 13 forme passa da 3 a 5 (valori ordinati 0, 2, 4, 4, 5, 5,
  5, 5, 7, 8, 9, 13, 14). Resta nell'intervallo 0-5, sull'estremo. La frase «`RC`, `RA1`, `RPc`, `RP5` non si
  distinguono da un placebo per numero di errori nuovi» (§5.2) vale solo col conto sulle righe peggiorate [D: non
  ho rifatto il conto per etichetta sui placebo]. Per la forma finale il conto più largo rafforza il «non entra».
  Le conclusioni «ogni forma che toglie un errore ne fa nascere almeno uno» e «forma finale `B0`» restano.

### R2. In `RA1` due righe hanno causa «forma» ma portano un errore di lettura [V]

- **Dove.** `27-peggioramenti.csv`, corsa `RA1`, studi `GSE147507` e `GSE57116`: `causa` = «forma»,
  `errore_nuovo` = FALSE. La colonna `errore` nomina però un errore di lettura che `27-stati.csv` segna «presente»
  e che la diagnosi tratta come errore «della forma (A1)».
- **Uscita grezza `RA1.jsonl`.** `GSE147507`: `'4 hours'->not stated; '6 hours'->not stated` (valori reali mandati a
  «non dichiarato»), livelli `day_1`, `day_3`, `day_7` che nessun campione ha, ceppo `'NA'->not stated`. C'è anche
  un difetto di forma (livello `mock` usato e non dichiarato nel fattore `ruxolitinib`). `GSE57116`: i livelli del
  trattamento contengono il tempo (`3h_drb_0min_4su`…) e c'è anche il fattore `time`; lo studio non chiude per
  `not_applicable` scritto col trattino basso (forma).
- **Mio giudizio.** Le due righe hanno tutte e due le cause. Col criterio di lettura dato, `GSE147507` in `RA1` è
  «lettura del modello».
- **Che cosa cambia.** `RA1` avrebbe 3 o 4 studi con un errore nuovo invece di 2. L'esito non cambia. È lo stesso
  effetto di R1 visto da un'altra parte: una scheda ha una causa sola.

### R3. La forma finale non controlla il verso: `30-forma-finale.txt` chiama «conflitto» anche `P` [V; in parte già dichiarato]

- **Che cosa.** `27-diagnosi.R` riga 239 mette in `cand` ogni D con un esito «della forma (D)». Non guarda se D
  mette l'errore o lo toglie. §6 delle previsioni («si toglie D se almeno un errore ha esito della forma (D)») ha
  senso solo se D mette l'errore.
- **Prova.** Dei 14 errori «della forma», 13 hanno il verso «sparisce con D»: sono assenti in `B0` e nascono quando
  D si toglie (4 con `P`, 1 con `C`, 8 con `A1`). Uno solo, `GSE57945:sesso come fattore`, ha il verso «appare con
  D» (`C`, `A1`).
- **Già dichiarato.** Il finding §4.3 lo dice con gli stessi numeri («`P` non è una candidata da togliere») e la
  tabella di §6 lo ripete.
- **Che cosa resta.** `D/30-forma-finale.txt` scrive ancora «P: la forma RP ha 8 studi con un errore nuovo → non
  entra (conflitto, va al PI)», e il finding §6 parla di «cinque conflitti» da portare al PI. I conflitti veri sono
  al più 4 (`C`, `A1`, `F1`, `F2`). Con la lettura severa dell'autore sono 2 (`F1`, `F2`), perché l'unico errore
  che motiva `C` e `A1` è instabile col placebo (R4). L'esito `B0` è uguale.

### R4. «Della forma»: 14 alla lettera, 5 con la lettura severa dell'autore, 1 con una terza lettura non dichiarata [V]

- **Confermo, con un ricalcolo a parte** (`rev/ricalcolo.py`, da `27-stati.csv`): esiti uguali a `27-diagnosi.csv`
  in 58 errori su 58; `esito_severo`: «della forma» 5, «del modello» 2, «non deciso» 51.
- **Già dichiarato** (codice righe 201-205, finding §4.4): (a) la coppia (`RA1`, `B0`) vale come prova «toglie»
  (riga 172) e come prova «mette» (righe 175-176), e 8 errori sono «della forma (A1)» per quella sola coppia;
  (b) il placebo si guarda solo nella base in cui l'errore è presente. Per `GSE57945:sesso come fattore` il placebo
  `A0pl1` fa nascere lo stesso errore (uscita grezza: fattore `sex`, tipo `context`, colonna `Sex`), quindi la
  prova «mette» di `A0C` e `A0A1` non si distingue da un placebo. Per `GSE67812:controlli scritti come DM1` il
  placebo `B0pl1` produce l'errore (`ALS11`, `ALS13`, `ALS14` al livello `dm1`), e il controllo è vuoto perché
  l'errore è assente nelle due basi. Ho verificato tutti e due i casi sull'uscita grezza.
- **Non dichiarato, terza lettura.** `00-previsioni.md` §3 definisce le due prove «per un errore che c'è in `B0` e
  non in `A0`» e per il caso inverso. Il codice le applica anche agli errori assenti in tutte e due le basi. Con il
  solo vincolo «presente in una base sola» gli esiti «della forma» sono 6. Insieme alla lettura severa resta 1
  errore su 58: `GSE112057:NA di gender non dichiarato mancante` (`C`), dove `C` protegge [V per le varianti una per
  volta, D per l'intersezione: i 4 errori di `P` sono assenti nelle due basi].
- **Ambiguità del testo depositato.** La definizione di «della forma» dice «i due placebo della base in cui E è
  presente». La sotto-etichetta di «non deciso» dice «lo stato di E cambia sotto un placebo», senza la base. Il
  codice sceglie la prima per l'esito e la seconda per `esito_severo`.
- **Che cosa cambia.** L'esito principale, `27-previsioni.csv` e `30-forma-finale.txt` usano la lettera. La
  previsione 8 è «confermata» con 1 (atteso 2, intervallo 1-3), e quell'1 è `GSE57945:sesso come fattore`: con la
  lettura severa è 0, fuori intervallo. `27-previsioni.csv` non ha il valore severo nella colonna `accanto`
  (vuota); il finding lo dice in parole in §4.4 («nessuno dei 4 errori di S12r3 ha una causa nella forma»). Le due
  previsioni 7 sono smentite con tutte e due le letture. La forma finale non cambia.

### R5. Due celle «assente» dubbie per `GSE69597:source_name_ch1 come donatore` [V sul grezzo, D sull'effetto]

- **Dove.** `RA1P` e `RA1PP5`: la colonna `source_name_ch1` (3 valori, uguali al gruppo di malattia) ha ruolo
  `subject`/`donor`, ma `27-stati.csv` dice «assente». In `RC` la stessa cosa in `GSE50760` (ruolo
  `subject`/`pair`) è segnata «presente».
- **Che cosa cambia.** L'esito di quell'errore passerebbe da «non deciso: una direzione sola (C)» a «più cambi».
  Nessun effetto sulle 13 forme a un cambio né sulla forma finale. Controllo meccanico mio su 341 celle con
  un'etichetta «…come donatore»: 3 discordi, queste.

### R6. Minori [V]

- La sotto-etichetta «non deciso: nessuna coppia a un cambio lo sposta» (7 errori) non è nel testo depositato.
  Il finding la dichiara (§8, punto 4).
- `27-per-forma.csv` conta in `migliorati` e `peggiorati` anche gli studi che sono tutte e due le cose;
  `24-forme.csv` li toglie. 16 forme differiscono esattamente per quella sovrapposizione. Sono due definizioni, non
  un errore: va scritto quale si usa.
- Il predicato di `GSE46665` (`D/10-forme.R` righe 368-375) riconosce le sigle per prefisso. In `F1` i livelli sono
  `DCM_T0`…, uno per campione: l'errore c'è nella sostanza.
- `RA4` ha 1 studio con errore nuovo ed è `GSE49155`, che è già in `B0` (`errore_nuovo_stretto` FALSE). Il finding
  lo dichiara (conto stretto).

---

## 2. Compito 1: il codice applica la regola depositata?

Sì nei conti: 58 esiti su 58 ricalcolati uguali. Le scelte di lettura, con l'alternativa e l'effetto:

| punto del testo | che cosa fa il codice | l'altra lettura | esiti che cambiano | dichiarato dall'autore |
|---|---|---|---|---|
| §3, coppie «mette» | (`RA1`, `B0`) vale anche come «mette» | la prova «mette» su una coppia diversa | 8 errori; «della forma» 14 → 6 | sì (`esito_severo`, §4.4) |
| §3, placebo | solo i placebo della base in cui E è presente | un placebo qualunque dei 4 | `GSE57945:sesso`, `GSE67812:controlli`; 14 → 12; previsione 8: 1 → 0 | sì (`esito_severo`, §4.4); non in `27-previsioni.csv` |
| §3, le due insieme | | lettura severa | 14 → 5 | sì |
| §3, campo della regola | anche errori assenti nelle due basi | solo errori presenti in una base sola | 14 → 6; con la severa 5 → 1 | no |
| §3, sotto-etichette | aggiunge «nessuna coppia a un cambio lo sposta» | non prevista | 7 errori, solo il nome | sì |
| §4, errore nuovo | solo fra le righe peggiorate, per la causa della scheda | per etichetta presente e non nella base | previsione 11: 3 → 5; `RA1` 2 → 8; forma finale uguale | no (dichiarato solo il conto stretto, che va nel verso opposto) |
| §6, forma finale | candidata ogni D con un «della forma (D)» | solo se D mette l'errore | `P` non è candidata; esito `B0` uguale | sì nel finding (§4.3), no in `30-forma-finale.txt` |

`stato_di`: tre vie di eredità (firma uguale alla base, scheda o firma letta, lettura supplementare);
«non valutabile» solo per uscita non valida (6 celle su 1.798). Stati ricalcolati: 1.361 assente, 431 presente,
6 non valutabile [V].

---

## 3. Compito 2: rilettura indipendente

Metodo: ho letto l'uscita grezza con un mio lettore (`rev/leggi_grezzo.py`) e la scheda dello studio, ho scritto il
giudizio, poi l'ho confrontato con `27-stati.csv` e `27-peggioramenti.csv`.
**Limite dell'indipendenza:** all'inizio ho guardato le prime righe dei file `26-*` per capirne la struttura. Ho
visto così le letture di `GSE147507` (`RP`, `RPc`, `B0pl1`), `GSE46665` (`RP`), `GSE103501`, `GSE112057`,
`GSE50760`, `GSE56787`, `GSE69597` prima del mio giudizio.

### 3a. I quattro errori noti nelle 31 forme (124 celle) [V sull'uscita grezza]

Accordo con `27-stati.csv`: **124 celle su 124** nella sostanza.

| errore | presente in (mio giudizio) | n | accordo |
|---|---|---|---|
| `GSE57945`, sesso come fattore | `B0 RPb RPc RPd RP5 RC3 RA4 RA4A3 B0pl1 B0pl2 A0C A0A1 A0pl1` | 13 | 31/31 |
| `GSE60340`, nessun fattore legge `treated with` | `B0 RPc RC3 RA4 RA4A3 RR F2 B0pl1` | 8 | 31/31 |
| `GSE49155`, la cella vuota di `cell type` prende un livello di patologia | `B0 RP RPa RPb RPd RP5 RC RC3 RA4 RA4A3 RR F2 B0pl2 A0A1` | 14 | 31/31 |
| `GSE46665`, sigle dei pazienti come livelli di malattia | tutte | 31 | 31/31 |

Note. `GSE57945`: in `RPc`, `RPd`, `RA4`, `RA4A3`, `A0C` la colonna ha ruolo `subject` e c'è anche un fattore `sex`.
`GSE49155`: in `A0A2` e `A0A2A3` c'è un fattore `tissue` con il livello inventato `airway`; è un altro errore, con
la sua etichetta, e il predicato lì è assente. `GSE60340` in `B0`: Adriamycin, 5-aza e H2O2 stanno tutti nel
livello `induced_senescence`.

### 3b. Le righe con `errore_nuovo` TRUE che decidono la forma finale [V sull'uscita grezza]

| forma | studio | che cosa scrive l'uscita | mio giudizio | già nella base? | file |
|---|---|---|---|---|---|
| `RC` | `GSE112057` | `gender` (NA = gli 11 controlli) senza `missing_values`; confronti 5 → 0 | lettura del modello (di confine) | no in `B0`; sì in `A0` | uguale |
| `RC` | `GSE47718` | `source_name_ch1` («…nonsmoker/smoker») come `subject`/`donor`; confronti 1 → 1 | lettura del modello, senza costo | no in `B0`; sì in `A0` | uguale |
| `RA1` | `GSE47718` | come sopra | lettura del modello | no | uguale |
| `RA1` | `GSE63816` | `'myelodysplastic syndrome (MDS)'->not stated` con livelli `mutant_mds`, `wild_type_mds` | lettura del modello | no con questa etichetta; `B0` manda tutte le MDS a `mutant` (altro errore) | uguale |
| `RP` | `GSE147507` | fattore `Ruxolitinib` da `description`, base `untreated` che non è un livello; `strain` con base `mock` | lettura del modello | no | uguale |
| `RP` | `GSE47718`, `GSE49608`, `GSE52194`, `GSE65335`, `GSE71289` | `source_name_ch1` (linea, tessuto, tipo cellulare) come `subject`/`donor` | lettura del modello (costa solo in `GSE65335`, 1 → 0) | no (in `B0` è `uninformative` o `factor`) | uguale |
| `RP` | `GSE56691` | livelli `GSKJ4`, `GSKJ4_48h`, `GSKJ4_72h` più il fattore `time` | lettura del modello | no | uguale |
| `RP` | `GSE57116` | livelli del trattamento col tempo dentro più il fattore `time` | lettura del modello | no | uguale |
| `F1` | `GSE112057` | secondo fattore `jia_subtype` letto dal titolo | lettura del modello | no | uguale |
| `F1` | `GSE41586` | 5 µM e 10 µM nello stesso livello `treated` | lettura del modello | no | uguale |
| `F1` | `GSE47718` | `source_name_ch1` come donatore | lettura del modello | no | uguale |
| `F1` | `GSE52778` | il donatore (`cell line`) scritto come fattore di contesto | lettura del modello | no | uguale |
| `F1` | `GSE56691` | `'CUTLL1-untreated'->` livello vuoto, base vuota | lettura del modello | no | uguale |
| `F1` | `GSE56787` | il fattore biopsia/miotubi/mioblasti non c'è più | lettura del modello | no | uguale |
| `F1` | `GSE57116` | come in `RP` | lettura del modello | no | uguale |
| `F1` | `GSE58365` | base `siBCL6`, che non è un livello | lettura del modello | no | uguale |
| `F1` | `GSE67812` | i tre controlli al livello `myotonic dystrophy` | lettura del modello | no | uguale |
| `F1` | `GSE69597` | `stage` letto da `subgroup`, con `reinfection` e `relapse` fra gli stadi | lettura del modello | no | uguale |
| `F1` | `GSE83415` | base non scritta (`B0`: `clinical remission`) | lettura del modello (di confine: non c'è un controllo) | no | uguale |
| `F2` | `GSE47718` | `source_name_ch1` come donatore | lettura del modello | no | uguale |
| `F2` | `GSE53280` | `'mock'->` livello vuoto, livelli `['', 'Salmonella']`, base vuota | lettura del modello (di confine con «forma») | no | uguale |
| `F2` | `GSE56691` | controllo non trattato al livello vuoto, base vuota | lettura del modello | no | uguale |
| `B0pl1` | `GSE60340` | nessun fattore legge `treated with` | lettura del modello | **sì, in `B0`** (`stretto` FALSE) | uguale |
| `B0pl1` | `GSE68919` | `'PBS'->` livello vuoto, base vuota, nota «baseline level is not clear» | lettura del modello | no | uguale |
| `B0pl2` | `GSE56691` | controllo non trattato al livello vuoto, base vuota | lettura del modello | no | uguale |
| `A0pl1` | `GSE57945` | fattore `sex` di contesto dalla colonna `Sex` | lettura del modello | no in `A0`; sì in `B0` | uguale |

Esito: **accordo sulla causa in tutte le righe lette** (30 coppie forma-studio). Tre righe sono di confine
(`RC` `GSE112057`, `F1` `GSE83415`, `F2` `GSE53280`). Se le tre passano a «forma» o «non errore», `RC` resta con 1
studio (`GSE47718`), `F1` con 10, `F2` con 2: nessuna forma arriva a zero, la forma finale non cambia.
In `RC` l'unico errore nuovo certo fra le righe contate è `GSE47718`, che non costa confronti; l'errore più grave
di `RC` è `GSE67812` (controlli scritti come DM1), che il conto non vede (R1).

Controllo in più: etichetta `GSE67812:controlli scritti come DM1` nelle 31 forme, dal grezzo: accordo 31 su 31
(in `A0A1` e `A0A2` il livello `dm1` va a un valore che nessun campione ha).

### 3c. Le altre righe con `errore_nuovo` TRUE

Non lette una per una (vedi §5). Solo il controllo meccanico sull'etichetta «…come donatore» (R5).

---

## 4. Compito 3: i numeri [V]

- `27-diagnosi.csv` da `27-stati.csv`: 58 esiti su 58 uguali.
- `27-per-forma.csv` da `24-contro-la-base.csv`, `27-peggioramenti.csv`, `27-stati.csv`: 29 righe, 0 diverse.
  `errore_nuovo` = (`causa` = «lettura del modello») in 156 righe su 156.
- `29-errori-presenti-per-forma.csv`: 31 righe, 0 diverse.
- `24-forme.csv` da `24-per-studio.csv` (chiusi, identici, ritrovati, denominatore): 32 righe, 0 diverse.
- Previsione 1: `A0` uguale al carattere a `S12r2-lettore-v1/M-corsa1.jsonl` in 47 su 47. Previsione 2: blocco
  `factors` di `RC3` uguale a `B0` al carattere in 47 su 47. Previsione 3: `A0A2A3A4R` uguale a `RA1PP5C` in 47 su 47.
- Previsione 4: firme diverse dalla base 9, 6, 8, 5 (ricalcolate). Previsione 5: 6 presenti e 2 assenti (dal grezzo,
  §3a). Previsione 9: `F12` 36 chiusi, 57/95 contro 68/95. Previsione 10: `F1` chiude `GSE50499` (identica), `F2`
  chiude `GSE63816` (diversa). Previsione 12: `RA4` 41 chiusi.
- Gli esiti scritti seguono la regola depositata (`00-previsioni.md` righe 51-55: conteggio contro intervallo per
  4, 8, 11, 12; intervallo di confidenza per 9). Le previsioni 8 e 11 dipendono dalle scelte di R4 e R1.

---

## 5. Che cosa non ho controllato

- Le righe con `errore_nuovo` TRUE delle forme `RPa`, `RPb`, `RPc`, `RPd`, `RP5`, `RA4`, `RR`, `F12`, del lato A e
  della catena: non rilette sull'uscita grezza (compito 2c).
- Gli stati delle 54 etichette nelle 1.674 celle: riletti dal grezzo solo per le etichette «…come donatore» (341
  celle, in modo meccanico) e per `GSE67812` (31 celle).
- Le righe con causa «forma» o «non errore» (49 su 156): lette solo le due di `RA1` in R2.
- Il costruttore dei confronti e le misure di `24-misura.R` e `aiuti-misura-r4.R`: letti, non ricalcolati da zero
  (ho ricalcolato solo le somme da `24-per-studio.csv`).
- Gli intervalli da ricampionamento, i cancelli, `31-stabilita.py`, `32-tabelle*`.
- Il finding `docs/findings/2026-11-12-S12r4-cause-errori-di-lettura.md`: non riletto. L'ho cercato per parole solo
  alla fine, per sapere che cosa l'autore dichiara già (§3.1, §4.3, §4.4, §5.2, §6, §8). Non ho controllato il
  riassunto «In breve» né la tabella «Da dove vengono i numeri».
- Il conto per etichetta degli errori nati nei 4 placebo e nelle forme del lato A (R1 lo dà per 13 forme da `B0`).
- Il testo completo degli studi (riassunto, disegno): ho usato la scheda. Per `GSE69597` in `F1` non ho verificato
  se il testo dello studio definisce i sottogruppi.
