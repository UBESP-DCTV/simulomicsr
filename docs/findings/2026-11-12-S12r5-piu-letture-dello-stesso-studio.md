---
type: Finding
title: "Più letture dello stesso studio con una frase del prompt riscritta: la discordanza fra le letture segnala gli errori di lettura? 9 letture, Mistral-Small 3.2, forma B0, gli stessi 47 studi"
description: "Con 9 letture per studio la discordanza segnala 24 studi su 47: 6 degli 8 studi con un errore di lettura di B0 e 18 dei 39 altri. La regola di esito depositata dà no. Cinque dei 9 errori di B0 sono uguali in tutte le 9 letture, e le 8 letture nuove portano 22 errori che B0 non ha, in 13 studi. La revisione indipendente ha trovato in B0 un errore fuori dai 9, presente in tutte le letture."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: 2026-11-12T23:20:00+01:00}
sources:
- {id: carta, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/01-carta.md", title: "La carta: le 9 letture, le 8 frasi riscritte, il criterio «non cambia il senso», i limiti detti prima (commit 17f09df)"}
- {id: previsioni, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/00-previsioni.md", title: "Cancelli 1-5, previsioni 1-12, regola sulla discordanza, regola di esito e regole della lettura, depositati prima di ogni corsa (commit 17f09df)"}
- {id: riscritture, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/11-riscritture.csv", title: "Le 8 frasi riscritte: originale, riscritta, operazione"}
- {id: giudizio, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/12-giudizio-esito-giro1.csv", title: "Il giudizio di due agenti sulle 8 riscritture e sulle 3 esche (audit interno, prima delle corse)"}
- {id: strumento, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/13-out.txt", title: "Cancello dello strumento sulle uscite congelate di S12r4 (cancello 2)"}
- {id: potenza, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/14-out.txt", title: "La forza della regola di esito, calcolata senza uscite del modello"}
- {id: corse, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/23-out.txt", title: "Registro delle 9 corse su poddgx02"}
- {id: misura, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/24-out.txt", title: "La misura: cancelli 1, 3, 4, 5, regola sulla discordanza, regola di esito, andamento, previsioni 1-10"}
- {id: letturecsv, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/24-letture.csv", title: "Una riga per lettura: chiusi, identici, ritrovati, studi con la chiave diversa da B0"}
- {id: segnalati, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/24-segnalati.csv", title: "Una riga per studio: segnalato o no, chiavi distinte, letture diverse da B0, stato in B0"}
- {id: stati, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/24-stati-errori.csv", title: "I 9 errori di B0: stato in ognuna delle 9 letture"}
- {id: andamento, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/24-andamento.csv", title: "Studi segnalati per numero di letture, su tutti i sottoinsiemi"}
- {id: schede, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/26-letture.csv", title: "La lettura delle 38 schede dopo l'aggiudicazione dei 9 disaccordi col revisore: causa, dove, etichette, descrizione (audit interno)"}
- {id: dopo, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/27-out.txt", title: "I conti dopo la lettura: cause, errori nuovi, classi degli studi segnalati, previsioni 11 e 12"}
- {id: tabelle, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/28-tabelle.md", title: "Le tabelle di questo finding, generate dai CSV (28-tabelle.py)"}
- {id: revisione, resource: "analysis/audit/2026-11-12-S12r5-piu-letture/34-revisione-indipendente/", title: "La revisione indipendente delle 38 schede (subagente Claude, audit interno): lettura del revisore, lettura di prima, aggiudicazione dei 9 disaccordi"}
- {id: s12r4, resource: "docs/findings/2026-11-12-S12r4-cause-errori-di-lettura.md", title: "La sessione sulle cause (S12r4): i 9 errori di lettura di B0 e i due placebo"}
- {id: spec, resource: "docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md", title: "Il disegno del lettore dello studio: §5.5, il cancello"}
- {id: adr29, resource: "docs/decisions/0029-lettore-dello-studio-tabella-dei-fattori.md", title: "ADR-0029 e aggiornamenti del 2026-11-12"}
---

# In breve

## In breve: se il modello legge lo stesso studio nove volte, le differenze fra le letture segnalano gli errori di lettura?

**A cosa serviva.** Il modello legge uno studio e scrive la tabella dei fattori, e in alcuni studi sbaglia. La sessione precedente ha trovato che la lettura cambia quando una frase delle istruzioni è riscritta con lo stesso senso. Qui abbiamo misurato se questo fatto è utile: il modello ha letto ogni studio 9 volte, una con le istruzioni decise e 8 con una frase riscritta. Uno studio è «segnalato» se le 9 letture non sono tutte uguali. Conta per l'articolo, perché nessun errore di lettura si accetta e negli altri studi nessun curatore li trova.

**Cosa abbiamo trovato.**

1. **La regola scritta prima delle corse dà «no». Le differenze fra le letture segnalano 24 studi su 47, e non separano gli studi con errore dagli altri.** La lettura con le istruzioni decise ha errori noti in 8 studi. Le differenze segnalano 6 di questi 8 studi e 18 degli altri 39. Con soli 8 studi con errore la prova ha poca forza: il «no» non dimostra che le differenze sono inutili.
2. **Cinque dei 9 errori noti sono uguali in tutte le 9 letture, e nessun confronto fra letture li può vedere.** Fra questi ci sono 2 dei 4 errori che cambiano i gruppi o i confronti. Nello studio GSE46665 il modello legge le sigle dei pazienti come malattie. Nello studio GSE57945 il modello scrive il sesso come fattore. I due studi sono segnalati, ma per un'altra differenza fra le letture.
3. **Un secondo lettore indipendente ha trovato un errore in più, in uno studio che contavamo senza errori.** Nello studio GSE147507 il tempo sta in due colonne, e ogni lettura ne legge una sola. Anche questo errore è presente in tutte le 9 letture. Quindi i 39 studi «senza errori noti» non sono provati senza errori.
4. **Ogni lettura in più porta errori suoi.** Le 8 letture nuove hanno 22 errori che la lettura con le istruzioni decise non ha, in 13 studi. Una frase riscritta porta errori nuovi in un numero di studi fra 2 e 8. Dei 24 studi segnalati, 16 hanno un errore in almeno una lettura e 8 no. Quindi più letture non danno una lettura migliore, e la regola non dice quale lettura è giusta.
5. **Una frase riscritta con lo stesso senso sposta il risultato quanto un cambio nella forma della risposta.** I confronti dei curatori che il lettore ritrova vanno da 58 a 71 su 95 secondo la frase, contro 68 con le istruzioni decise. Due corse con le stesse parole danno invece risposte uguali al carattere.

**Cosa devi decidere.**

1. **Che cosa facciamo degli studi segnalati? Raccomando di non usare le differenze fra le letture come filtro: restano uno strumento di misura.** La regola dà «no», segnala metà degli studi e non vede 5 errori noti su 9. Il disegno approvato chiede di correggere la causa di un errore, non di aggiungere una regola dopo il modello.
   - In alternativa togliamo gli studi segnalati. Sui 47 restano 23 studi: 21 hanno i gruppi dei curatori e nessuno ha un errore noto che cambia i gruppi o i confronti. Perdiamo metà degli studi, il calcolo del modello cresce di 9 volte, e questo conto è nato dopo i numeri, su studi già letti. Nessuno ha riletto quei 23 studi in questa sessione.
   - In alternativa teniamo gli studi segnalati con una nota. Gli errori restano nei risultati, e la nota cade su metà degli studi.
2. **Scriviamo adesso il piano che mette il lettore nel pacchetto? Raccomando di no: prima una sessione sugli errori uguali in tutte le letture.** Questi errori non dipendono dalle parole delle istruzioni. La sessione cambia il testo dello studio che il modello riceve, che è il solo pezzo prima del modello non ancora variato. Limiti: è la sesta prova sugli stessi 47 studi, e gli errori uguali in tutte le letture sono 6.
   - In alternativa scriviamo il piano adesso, con una lettura sola. Il primo gruppo di studi chiusi mostrerà errori del lettore, e oggi non abbiamo una correzione da applicare.
   - In alternativa scriviamo il piano adesso, con più letture per studio. Il calcolo cresce, gli errori uguali in tutte le letture restano, e la regola non sceglie fra le letture.
   - In alternativa proviamo un altro modello. Dei due modelli più grandi già provati, uno ha fatto peggio e non è ripetibile, e l'altro non è partito.
   - In alternativa apriamo una parte degli 82 studi chiusi per contare gli errori. Quegli studi servono una volta sola.
   - In alternativa fermiamo il lettore e teniamo il metodo di oggi, che ritrova 13 confronti su 95 contro 68.
   - Dichiarare gli errori di lettura come limite va contro la tua regola: nessun errore si accetta.

**Comunque:**

- gli 82 studi chiusi per il giudizio finale restano chiusi;
- le istruzioni e la forma della risposta decise non cambiano;
- le 9 letture restano come misura di quanto la lettura cambia da sola: ogni prova seguente si confronta con questa misura;
- i risultati su disco restano quelli di oggi.

Appena decidi questi 2 punti, la sessione è chiusa.

# 1. Che cosa è stato fatto

La sessione S12r5 misura se la discordanza fra più letture dello stesso studio segnala gli errori di lettura del
lettore dello studio (ADR-0029[^adr29]). La sessione sulle cause (S12r4[^s12r4]) aveva trovato che la lettura
cambia con una frase del prompt riscritta senza cambiare il senso, e un calcolo fatto dopo i numeri su tre letture
diceva che la discordanza segnala gli errori «in parte».

- **Carta, prima di ogni corsa**[^carta]: 9 letture per studio. `B0` è la forma dell'uscita decisa dal PI (schema
  generato per ogni studio a elenco chiuso, prompt v2). `L1`-`L8` sono `B0` con **una** frase del prompt di sistema
  riscritta. Un programma estrae le 8 frasi (una per sezione del prompt, due dalla sezione con più candidate;
  seme 20261112); le riscritture[^riscritture] sono di sola sintassi (ordine dei complementi in `L3`, `L5`, `L6`,
  `L8`; ordine di principale e subordinata in `L4`, `L7`; da attiva a passiva in `L2`; relativa equivalente in
  `L1`). Due agenti indipendenti hanno giudicato uguali le 8 riscritture e diverse le 3 esche messe apposta[^giudizio].
  I due placebo di S12r4 non entrano nel conto principale.
- **Deposito, prima di ogni corsa**[^previsioni] (commit `17f09df`): 5 cancelli, 12 previsioni, la regola sulla
  discordanza, la regola di esito, le regole della lettura dei disaccordi.
- **Corse**[^corse]: 9 job su `poddgx02`, due processi in parallelo, 31 minuti di attesa in tutto (durata dei job
  da 4 min 3 s a 6 min 39 s). Mistral-Small 3.2, configurazione di produzione, `VLLM_BATCH_INVARIANT=1`.
- **Misura**[^misura] e **lettura di tutti i disaccordi**[^schede]: 77 coppie (studio, lettura nuova) con la chiave
  diversa da `B0`, in 24 studi, riunite in 38 schede. Le ha lette tutte l'agente. Poi le ha rilette tutte un agente
  indipendente dal materiale congelato fuori dal repository (§12).

**La regola sulla discordanza** (depositata). Per ogni studio e lettura si calcola una chiave di tre parti: la
firma della tabella dei fattori, i gruppi che il costruttore forma, i confronti che il costruttore forma. Uno
studio è **segnalato** se le 9 letture hanno due o più chiavi distinte. La regola segnala soltanto: non sceglie
una lettura, non vota e non corregge.

**La regola di esito** (depositata). «Sì» se valgono tutte e due: (a) la quota di studi segnalati fra gli 8 studi
con un errore di lettura di `B0` è più alta della quota fra gli altri 39, e l'intervallo al 95% della differenza
(ricampionamento degli studi, B = 2.000, seme 20261112) sta tutto sopra zero; (b) almeno 3 dei 4 studi con un
errore che costa gruppi o confronti sono segnalati.

Le 8 frasi riscritte:

| lettura | sezione del prompt | operazione | frase originale → frase riscritta |
|---|---|---|---|
| `L1` | apertura | relativa equivalente | «the metadata fields that have the same value in every sample» → «the metadata fields whose value is the same in every sample» |
| `L2` | Factors | da attiva a passiva | «it divides the samples into the groups that the series compares» → «the samples are divided by it into the groups that the series compares» |
| `L3` | Levels | ordine dei complementi | «For each level write a short name (…)» → «Write for each level a short name (…)»; «and the dose and the duration if they are written» → «and, if they are written, the dose and the duration» |
| `L4` | Baseline level | principale e subordinata | «If the factor has no baseline in this series, use the empty string in both fields.» → «Use the empty string in both fields if the factor has no baseline in this series.» |
| `L5` | Assignment | ordine dei complementi | «The stage or the subtype of a disease does not exist for the healthy donors.» → «For the healthy donors, the stage or the subtype of a disease does not exist.» |
| `L6` | Assignment | ordine dei complementi | «…and give the special level `not applicable` to the values of the samples outside it.» → «…and, to the values of the samples outside it, give the special level `not applicable`.» |
| `L7` | Columns | principale e subordinata | «Use an empty array if there are none, and for every other role.» → «If there are none, and for every other role, use an empty array.» |
| `L8` | What you did not understand | ordine dei complementi | «In `not_understood`, list the samples or the values…» → «List in `not_understood` the samples or the values…» |

# 2. Cancelli

Tutti e cinque passano[^misura][^strumento].

| n. | cancello | esito |
|---|---|---|
| 1 | la corsa nuova di `B0` è identica al carattere all'uscita congelata di S12r4 | 47 studi su 47; 45 chiusi, 36 con gruppi identici, 68 confronti su 95 |
| 2 | lo strumento ridà i numeri congelati di S12r4 (prima delle corse) | i 9 predicati 279 casi su 279; i 12 studi dell'handout sulla sola firma |
| 3 | i 9 predicati vedono i 9 errori di lettura nella corsa nuova di `B0` | 9 su 9 |
| 4 | ogni corsa copre i 47 studi di sviluppo e nessuno degli 82 di giudizio | 9 corse su 9 |
| 5 | ambiente: `poddgx02`, le due variabili, modello e parametri, un solo ingresso, schema per record | 9 job `COMPLETED` su `poddgx02`; ingresso con uno SHA-256 solo |

# 3. La misura

## 3.1 Le 9 letture, una per una

Ogni lettura è misurata come in S12r4, sul riferimento a 95 confronti[^letturecsv].

| lettura | studi chiusi | gruppi identici ai curatori | confronti ritrovati su 95 | studi identici al carattere a `B0` | studi con la chiave diversa da `B0` | di cui: firma / gruppi / confronti | errori di `B0` presenti (su 9) |
|---|---|---|---|---|---|---|---|
| `B0` | 45 | 36 | 68 | 47 | 0 | 0 / 0 / 0 | 9 |
| `L1` | 43 | 35 | 62 | 25 | 6 | 5 / 2 / 4 | 8 |
| `L2` | 42 | 35 | 68 | 23 | 10 | 9 / 4 / 5 | 8 |
| `L3` | 43 | 34 | 67 | 7 | 12 | 12 / 4 / 6 | 7 |
| `L4` | 44 | 35 | 71 | 22 | 10 | 10 / 3 / 6 | 8 |
| `L5` | 44 | 36 | 58 | 19 | 12 | 11 / 5 / 6 | 7 |
| `L6` | 43 | 36 | 70 | 21 | 9 | 8 / 3 / 4 | 7 |
| `L7` | 41 | 34 | 63 | 20 | 10 | 9 / 4 / 6 | 7 |
| `L8` | 45 | 36 | 67 | 27 | 8 | 8 / 3 / 3 | 8 |

Con una frase riscritta la chiave cambia in un numero di studi fra 6 e 12 (mediana 10). Il testo dell'uscita
cambia in più studi (da 20 a 40 su 47): la maggior parte dei cambi di testo non tocca la tabella dei fattori.
`L3` cambia il testo in 40 studi: la sua frase dice in quale ordine scrivere i campi di un livello.

## 3.2 La regola sulla discordanza e la regola di esito

**Studi segnalati: 24 su 47** (quota 0,511; IC95 per ricampionamento degli studi 0,383-0,660)[^misura][^segnalati].

| | segnalati | non segnalati | totale |
|---|---|---|---|
| studi con un errore di `B0` che costa | 4 | 0 | 4 |
| studi con un errore di `B0` che non costa | 2 | 2 | 4 |
| studi senza un errore letto in `B0` | 18 | 21 | 39 |
| **totale** | **24** | **23** | **47** |

| stato in `B0` | segnalati | non segnalati |
|---|---|---|
| gruppi identici ai curatori (36) | 15 | 21 |
| gruppi diversi (9) | 7 | 2 |
| non chiuso (2) | 2 | 0 |

**Regola di esito: NO.** Quota di segnalati fra gli studi con errore 6/8 = 0,750; fra gli altri 18/39 = 0,462;
differenza +0,288, IC95 −0,091, +0,610. La condizione (a) non vale: l'intervallo comprende lo zero. La condizione
(b) vale: 4 studi su 4 con un errore che costa sono segnalati. La carta lo aveva detto prima (§6 punto 4)[^potenza]:
con 6 studi con errore segnalati su 8 la condizione (a) vale solo se gli studi senza errore segnalati sono al
massimo 13 su 39; sono 18. Un «no» di questa regola vuol dire: su 47 studi la discordanza non separa gli studi con
errore dagli altri oltre il caso. Non vuol dire che non li separa.

**Gli errori non segnalati, uno per uno** (li chiede la regola di esito): `GSE71595:source_name_ch1 come donatore`
e `GSE75852:tempo che ripete il tipo cellulare`. Tutti e due sono presenti in 9 letture su 9 e nessuno dei due
costa gruppi o confronti.

## 3.3 I 9 errori di `B0` nelle 9 letture

| errore | costa | presente in (su 9) | lo stato cambia | studio segnalato |
|---|---|---|---|---|
| `GSE46665`: sigle dei pazienti come malattie | sì | 9 | no | sì |
| `GSE57945`: sesso come fattore | sì | 9 | no | sì |
| `GSE60340`: colonna del trattamento non vista | sì | 6 | sì | sì |
| `GSE49155`: fattore doppio | sì | 8 | sì | sì |
| `GSE46665`: tempo ripetuto come secondo fattore | no | 8 | sì | sì |
| `GSE50760`: `source_name_ch1` come donatore | no | 9 | no | sì |
| `GSE66573`: `source_name_ch1` come donatore | no | 2 | sì | sì |
| `GSE71595`: `source_name_ch1` come donatore | no | 9 | no | no |
| `GSE75852`: tempo che ripete il tipo cellulare | no | 9 | no | no |

Lo stato cambia per 4 errori su 9, e per 2 dei 4 che costano[^stati]. **Cinque errori su 9 sono uguali in tutte le
9 letture**: la discordanza non li vede per costruzione. Tre di questi cinque stanno comunque in uno studio
segnalato, perché una lettura cambia in un altro punto dello stesso studio:

- `GSE46665` è segnalato per la sola lettura `L3`, che non scrive il tempo ripetuto come secondo fattore. L'errore
  delle sigle è in tutte le letture.
- `GSE57945` è segnalato per la sola lettura `L2`, che aggiunge l'età come fattore di contesto (un errore nuovo) e
  non chiude lo studio. Il sesso come fattore è in tutte le letture.
- `GSE50760` è segnalato per le letture `L1`, `L4`, `L5`, che scrivono il tessuto come contesto senza base (un
  errore nuovo). `source_name_ch1` come donatore è in tutte le letture.

Quindi il conto «4 studi su 4 con un errore che costa sono segnalati» vale per lo studio, non per l'errore: in 2
dei 4 studi la discordanza non riguarda l'errore che costa.

**Un errore di `B0` fuori dai 9, trovato dalla revisione indipendente (§12).** In `GSE147507` il tempo è scritto in
due colonne complementari: `time point` (20 campioni con un valore) e `time after treatment` (45 campioni). Ogni
lettura ne legge una sola e dà all'altra il ruolo `uninformative`: `B0`, `L1`, `L5`, `L6`, `L7`, `L8` leggono
`time point` e dichiarano i livelli di 4, 6 e 12 ore senza campioni; `L2`, `L3`, `L4` leggono `time after
treatment`. Verificato sulle 9 uscite. È il limite «una variabile scritta in più colonne» del disegno (spec §5.2,
punto 5[^spec]): il modello deve leggere la variabile da una colonna che la porta intera, o dichiarare il fattore
in `not_understood`. Non lo fa in nessuna delle 9 letture. S12r3 lo aveva annotato senza contarlo («in questa prova
non ha fatto danno»), perché i 2 confronti di Atlas sono ritrovati 2 su 2; S12r4 non lo ha contato fra i 9. Il danno
sta nei confronti fuori dall'universo di Atlas: in `B0` il confronto fra IFNB e mock unisce campioni di tre tempi.

Questo errore **non entra nei 9 depositati né nella regola di esito** (§12 riporta il conto accanto). Lo studio era
contato fra i 39 «senza errore» ed è segnalato. Qui la discordanza vede il cambio di colonna (`L2`), ma le due
letture discordi sono sbagliate tutte e due. Con questo errore, gli errori presenti in tutte le 9 letture sono 6 su
10.

## 3.4 L'andamento col numero di letture

Media, minimo e massimo su tutti i sottoinsiemi di letture nuove aggiunte a `B0`[^andamento].

| letture | studi segnalati: media (min-max) | studi con errore segnalati, su 8 | studi con un errore che costa segnalati, su 4 | studi con gruppi identici in `B0` segnalati, su 36 |
|---|---|---|---|---|
| 2 | 9,62 (6-12) | 2,25 | 1,00 | 5,62 |
| 3 | 14,54 (10-19) | 3,29 | 1,64 | 8,57 |
| 4 | 17,36 (13-22) | 3,93 | 2,11 | 10,36 |
| 5 | 19,26 (15-23) | 4,43 | 2,50 | 11,61 |
| 6 | 20,71 (17-24) | 4,86 | 2,88 | 12,61 |
| 7 | 21,93 (18-24) | 5,25 | 3,25 | 13,46 |
| 8 | 23,00 (20-24) | 5,62 | 3,62 | 14,25 |
| 9 | 24 | 6 | 4 | 15 |

Gli studi segnalati crescono a ogni lettura in più, sempre più piano: da 8 a 9 letture in media 1 studio. Con 11
letture (le 9 più i due placebo di S12r4, già visti) gli studi segnalati restano 24. Il numero della sessione è
quello a 9 letture: nessun numero di letture è stato scelto.

**La regola con le parti della chiave da sole** (accanto, senza peso nell'esito): sola firma 24 studi (gli stessi);
soli gruppi 10 (2 studi con errore su 8); soli confronti 14 (4 su 8). L'esito è «no» con ogni chiave.

# 4. Le previsioni

## 4.1 Le previsioni con l'esito

| n. | quantità | atteso | intervallo | misurato | esito |
|---|---|---|---|---|---|
| 1 | studi segnalati con 9 letture | 20 | 13-23 | 24 | **smentita** (fuori di 1; IC95 della quota 0,383-0,660) |
| 2 | studi con la chiave diversa da `B0` per lettura, mediana | 8 | 5-12 | 10 (da 6 a 12) | confermata |
| 3 | studi con un errore che costa segnalati (su 4) | 3 | 3-4 | 4 | confermata |
| 4 | errori di `B0` in studi segnalati (su 9) | 6 | 5-8 | 7 | confermata |
| 5 | studi con gruppi identici in `B0` segnalati (su 36) | 11 | 7-15 | 15 | confermata, sull'estremo |
| 6 | esito della regola | no: manca (a), vale (b) | - | no: manca (a), vale (b) | come previsto |
| 7 | errori che costano il cui stato cambia (su 4) | 2 (`GSE60340`, `GSE49155`) | 2-3 | 2 (gli stessi) | confermata |
| 8 | `GSE46665`, sigle: letture in cui è presente (su 9) | 9 | 9 | 9 | confermata |
| 9 | studi segnalati aggiunti in media da 5 a 9 letture | 3 | 1-5 | 4,74 | confermata |
| 10 | confronti ritrovati su 95 in ognuna delle 8 letture nuove | 64-74 | tutte fra 64 e 74 | da 58 a 71 | **smentita** (`L5` 58, `L1` 62, `L7` 63) |
| 11 | studi con un errore di lettura nuovo per lettura, mediana | 2 | 0-4 | 4,5 (da 2 a 8) | **smentita** dopo la revisione indipendente (prima: 3,5, confermata; §4.2 e §12) |
| 12 | studi segnalati in cui la discordanza tocca un errore di lettura | 65% | 50%-85% | 16/24 = 66,7% | confermata |

Le previsioni 1, 2, 5, 9, 10 e 12 hanno un margine di giudizio dell'agente, dichiarato nel deposito. Le previsioni
11 e 12 dipendono dalla lettura delle schede, che è un giudizio (§5 e §12): l'esito della 11 cambia con un criterio
della lettura, l'esito della 12 no (16 su 24 nei tre conti).

## 4.2 I dubbi aperti dalle previsioni, e come sono chiusi

**Previsione 1, smentita: 24 studi segnalati contro al massimo 23.** La conseguenza era scritta prima: sopra 23 la
regola segnala più di metà degli studi, e una segnalazione dice poco. È così: 24 su 47, e la lettura dice che cosa
c'è dentro (§5.3): in 16 studi la discordanza tocca un errore di lettura, in 2 è solo forma, in 6 la differenza
fra le letture non è un errore. La smentita è di uno studio e non cambia l'esito della regola, che era «no» anche con 23. **Chiuso:
spiegato; il fatto entra nel primo punto del riassunto.**

**Previsione 10, smentita: tre letture ritrovano meno di 64 confronti.** La conseguenza scritta prima: la
riscrittura si rilegge. Le ho rilette (`L1`, `L5`, `L7`, §1): il senso è lo stesso. La perdita viene da due studi
con 5 confronti ciascuno (`28-tabelle.md` §3)[^tabelle]:

- `GSE112057` perde 5 confronti su 5 in `L1`, `L5`, `L7`: il modello non dichiara mancante il valore `NA` di
  `gender`, e il costruttore vede soggetti diversi nelle coppie. I gruppi restano identici ai curatori.
- `GSE69597` perde 5 confronti in `L5`: il modello scrive `country` come fattore.
- `GSE68919` perde 1 confronto in `L1`, `L5`, `L7`: il controllo PBS resta senza livello e lo studio non chiude.

Nelle tre letture questi due studi fanno 20 dei 23 confronti persi. La frase riscritta in `L7` è quella che segue
l'istruzione sui valori mancanti (`missing_values`), e l'errore di `GSE112057` è sui valori mancanti. Ma lo stesso
errore c'è in `L1` e in `L5`, le cui frasi parlano d'altro (le colonne costanti; lo stadio di una malattia nei
donatori sani). Quindi la riscrittura di `L7` non è la causa. **Chiuso: spiegato.** Il fatto resta un risultato:
una frase riscritta senza cambiare il senso sposta il conto dei confronti da −10 a +3 rispetto a `B0`, cioè quanto
un cambio di forma di S12r4, e un solo studio con molti confronti basta.

**Previsione 11, smentita dopo la revisione indipendente: mediana 4,5 studi con un errore nuovo per lettura, contro
al massimo 4.** Con la mia lettura di prima della revisione la mediana era 3,5 e la previsione era confermata. La
differenza viene da un criterio solo (C1, §12): un errore di lettura si conta anche quando non cambia gruppi e
confronti. Con questo criterio entrano due errori che non avevo contato: il valore `NA` di `ancestry` non dichiarato
mancante in `GSE112057` (`L2`, `L4`, `L8`) e `age` scritta come donatore in `GSE63816` (`L6`). Il conto per lettura
passa da 3, 4, 5, 5, 8, 1, 3, 3 a 3, 5, 5, 6, 8, 2, 3, 4. Tengo il criterio severo perché è quello di S12r4, che
conta fra i 9 errori di `B0` cinque errori che non costano; il mio criterio di prima non era scritto nel deposito.
La conseguenza scritta prima per «sopra 4» è: ogni lettura in più porta errori suoi, e l'insieme degli errori cresce
col numero di letture. Vale con tutti e due i conti: le etichette nuove distinte crescono da 4 con una lettura a 22
con otto (19 col conto di prima), e nessuna lettura nuova è senza errori nuovi. **Chiuso: spiegato; l'esito dipende
dal criterio, e i due conti sono riportati.**

**Previsione 5, sull'estremo: 15 studi con gruppi identici segnalati su 36.** Dentro l'intervallo. La conseguenza
scritta per «sopra 15» (il costo di rileggere gli studi giusti è alto) vale già a 15: il 42% degli studi giusti è
segnalato. Va al PI nel conto (§8).

# 5. La lettura dei disaccordi

## 5.1 Che cosa è stato letto e con quali criteri

Tutte le 77 coppie (studio, lettura nuova) con la chiave diversa da `B0`, in 38 schede (una scheda per chiave
distinta nello studio). Ogni scheda riceve causa, dove sta l'errore, etichette degli errori di lettura presenti
nella lettura nuova, descrizione[^schede]. In 31 schede su 38 la stessa firma era già stata letta in S12r4, e la
scheda mostrava l'etichetta di allora come punto di partenza.

Le tabelle di questa sezione sono **la lettura dopo l'aggiudicazione** dei 9 disaccordi col revisore indipendente
(§12, che riporta anche la lettura di prima e quella del revisore). Criteri della lettura, oltre a quelli
depositati (decisioni tecniche, §7):

- «dove» si riferisce all'errore che causa la differenza fra la lettura nuova e `B0`; la causa di una scheda è la
  causa di quella differenza (C2);
- «forma» è una lettura giusta o uguale a `B0`, in uno studio che non chiude solo per come è scritta l'uscita; un
  fattore vero letto da una colonna col ruolo sbagliato è forma (C4);
- un errore di lettura si conta anche se non cambia gruppi e confronti, come S12r4 ha fatto per i 9 errori di `B0`
  (C1). Prima della revisione non contavo due casi di questo tipo: era un criterio mio, non scritto, ed è caduto;
- una colonna equivalente come fonte, o una scelta su cui i curatori stessi non sono costanti, è «non errore»;
- un errore speculare (una delle due colonne del tempo di `GSE147507`) ha una etichetta sola (C3).

## 5.2 Le cause

| causa | schede | coppie coperte |
|---|---|---|
| lettura del modello | 25 | vedi `28-tabelle.md` §5 |
| forma | 4 | |
| non errore | 9 | |
| **totale** | **38** | **77** |

Dove sta l'errore, nelle 25 schede con causa «lettura del modello»: nella lettura nuova 15; in `B0` 5; in tutte e
due 5[^dopo]. Le 5 schede «in `B0`» sono letture nuove **migliori** di `B0`: `GSE46665` `L3` (senza il tempo
ripetuto), `GSE49155` `L4` (senza il fattore doppio: 2 confronti su 2 contro 0), `GSE60340` `L6` (il trattamento è
letto: 2 su 2 contro 0) e `L7` (il trattamento è letto, ma lo studio non chiude per forma), `GSE66573` in 7 letture
(senza `source_name_ch1` come donatore). Prima della revisione il conto era 21, 6 e 11 schede, con 15, 4 e 2 (§12).

## 5.3 Le classi dei 24 studi segnalati

| classe | studi | quali |
|---|---|---|
| tocca un errore di lettura | 16 | `GSE112057`, `GSE147507`, `GSE46665`, `GSE49155`, `GSE50760`, `GSE53280`, `GSE56691`, `GSE57116`, `GSE57945`, `GSE60340`, `GSE63816`, `GSE66573`, `GSE67812`, `GSE68919`, `GSE69597`, `GSE83687` |
| forma | 2 | `GSE49608`, `GSE50499` |
| non errore | 6 | `GSE103501`, `GSE56235`, `GSE56787`, `GSE60585`, `GSE65335`, `GSE71289` |

Le classi sono uguali nei tre conti (mio di prima, del revisore, dopo l'aggiudicazione). Fra i 16: 6 hanno uno dei
9 errori depositati di `B0`; **10 non hanno nessuno dei 9**, e 9 hanno in `B0` gruppi identici ai curatori[^dopo].
Con l'errore di `B0` trovato dalla revisione in `GSE147507` i due numeri sono 7 e 9: in 9 studi l'errore sta solo
in una o più letture nuove. La tabella intera, studio per studio, sta in `28-tabelle.md` §1.

## 5.4 Gli errori di lettura nuovi

Un errore è nuovo se `B0` non ha quell'etichetta in quello studio (conto per etichetta, dichiarato prima).

| lettura | studi con un errore nuovo | etichette nuove | errori in tutto (dei 9 di `B0` presenti più le nuove) | quali studi |
|---|---|---|---|---|
| `B0` | - | - | 9 | - |
| `L1` | 3 | 4 | 12 | `GSE112057`, `GSE50760`, `GSE68919` |
| `L2` | 5 | 6 | 14 | `GSE112057`, `GSE57945`, `GSE60340`, `GSE63816`, `GSE68919` |
| `L3` | 5 | 8 | 15 | `GSE147507`, `GSE53280`, `GSE57116`, `GSE63816`, `GSE67812` |
| `L4` | 6 | 7 | 15 | `GSE112057`, `GSE147507`, `GSE50760`, `GSE56691`, `GSE67812`, `GSE83687` |
| `L5` | 8 | 12 | 19 | `GSE112057`, `GSE50760`, `GSE56691`, `GSE60340`, `GSE63816`, `GSE67812`, `GSE68919`, `GSE69597` |
| `L6` | 2 | 2 | 9 | `GSE63816`, `GSE68919` |
| `L7` | 3 | 4 | 11 | `GSE112057`, `GSE56691`, `GSE68919` |
| `L8` | 4 | 5 | 13 | `GSE112057`, `GSE147507`, `GSE67812`, `GSE83687` |

Mediana 4,5 studi per lettura (da 2 a 8)[^dopo][^tabelle]. **Le etichette nuove distinte sono 22, in 13 studi.**
Insieme ai 9 errori di `B0` fanno 31 etichette in 18 studi su 47 (32 con l'errore di `B0` trovato dalla revisione,
che è presente in tutte le 9 letture e alza di 1 ogni conto della quarta colonna). Ogni lettura nuova ha 7 o 8 dei
9 errori di `B0` e in più errori suoi. In tutto sette letture nuove su 8 hanno più errori di `B0` (da 11 a 19
contro 9) e `L6` ne ha 9 come `B0`. Nessuna lettura nuova ha meno errori di `B0`. `L6` ritrova 70 confronti contro
68: non è un motivo per cambiare quella frase, perché la differenza sta dentro lo spostamento che una frase
riscritta dà da sola (§3.1), e scegliere una frase per il suo conto sui 47 studi è quello che la carta esclude.
Prima della revisione le etichette nuove erano 19 e la mediana 3,5 (§12). Una delle 22 l'ho aggiunta io dopo la
revisione, da una osservazione che il revisore dà come non verificabile e che ho verificato sulla vista (§12): il
ruxolitinib di `GSE147507` in `L4` e `L8`. Le 22 etichette:

- un controllo senza livello, che non fa chiudere lo studio: `GSE53280` (mock), `GSE56691` (non trattato),
  `GSE68919` (PBS), `GSE147507` (ruxolitinib e ceppo);
- un fattore di troppo, diviso o inventato: `GSE57945` (età), `GSE69597` (paese), `GSE60340` (passaggio; «nessun
  trattamento» diviso in tre livelli), `GSE57116` (tempo ripetuto), `GSE147507` (trattamento diviso in infezione e
  IFNB; fattore `organism` inventato da `cell type`);
- un fattore letto dalla colonna sbagliata o non letto: `GSE63816` (shRNA da `source_name_ch1`; genotipo ZRSR2 non
  letto);
- un livello o una base sbagliati: `GSE67812` (controlli scritti come DM1), `GSE83687` (ileo come non applicabile),
  `GSE147507` (tempi di 4 e 6 ore a non applicabile; ruxolitinib assegnato a 6 campioni, mentre lo ricevono 3),
  `GSE50760` (tessuto come contesto senza base), `GSE60340` (base non scritta);
- un valore mancante non dichiarato: `GSE112057` (`NA` di `gender`, che costa 5 confronti su 5; `NA` di `ancestry`,
  che non costa);
- un ruolo del soggetto sbagliato: `GSE63816` (`age` come donatore, che non costa).

# 6. Conti dichiarati dopo i numeri

Questi conti non erano nel deposito. Non entrano nell'esito.

**6.1 Errori stabili ed errori che si muovono.** Un errore che è presente in alcune letture e assente in altre dà
letture discordi: la discordanza lo vede **per costruzione**. Un errore uguale in tutte le letture non si vede mai.
Dei 9 errori di `B0`, 4 si muovono e 5 sono stabili (§3.3). L'errore trovato dalla revisione in `GSE147507` è
presente in tutte le letture in due forme speculari: la discordanza vede il cambio di forma e non l'errore. Dei 4 che costano, 2 sono stabili: le sigle dei
pazienti come malattie in `GSE46665` (anche in 31 forme su 31 in S12r4) e il sesso come fattore in `GSE57945`
(stabile sotto le 8 frasi riscritte, ma presente in 13 forme su 31 in S12r4: si muove con la forma e non con
queste frasi). Tutti i 22 errori nuovi sono in studi segnalati, per costruzione.

**6.2 Gli studi non segnalati.** Sono 23. In `B0` 21 hanno gruppi identici ai curatori e 2 no (`GSE44379`,
`GSE93624`: differenze dai curatori già lette come «non errore» in S12r3). Hanno 36 confronti ritrovati su 41. Hanno
2 errori di lettura noti, che non costano (`GSE71595`, `GSE75852`), e nessun errore noto che costa. I 24 studi
segnalati hanno in `B0` 32 confronti ritrovati su 54. Limite: «noto» vuol dire letto in S12r4 su `B0`; un errore
uguale in tutte le letture e senza disaccordo con i curatori non è mai stato letto (carta §6 punto 5). La revisione
indipendente ne ha trovato uno di questo tipo in uno studio segnalato (`GSE147507`, §3.3): i 23 studi non segnalati
non sono stati riletti da un revisore, perché non hanno schede.

**6.3 Un errore nuovo si vede da solo?** Le coppie (studio, lettura) con un errore nuovo sono 36 (`28-tabelle.md`
§6)[^tabelle]. In 16 la lettura non chiude lo studio: il costruttore si ferma e l'errore si vede senza altre
letture. In 20 la lettura chiude lo studio: in 13 con gruppi identici ai curatori (di cui `GSE112057` sei volte: tre
con 0 confronti su 5 e tre con 5 su 5), in 7 con gruppi diversi. Prima della revisione le coppie erano 32 (15, 10 e
7).

# 7. Decisioni tecniche dell'agente

1. **La chiave della regola ha tre parti**, non la sola firma dell'handout (carta §7, prima delle corse). Sulle 9
   letture le due regole segnalano gli stessi 24 studi. Il motivo resta valido: in 20 coppie di letture la firma è
   uguale e una lettura chiude lo studio e l'altra no (`GSE49608`, `GSE50499`, `GSE60340`, `GSE83687`).
2. **Il conto degli errori nuovi è per etichetta** (carta §7).
3. **Due processi in parallelo** su `poddgx02`, 4 GPU ciascuno, col lanciatore di S12r4 adattato.
4. **Il file di S12r4 che definisce le forme si carica senza una riga** che oggi legge un file cambiato dopo la
   chiusura di S12r4 (carta §7). Il cancello 2 prova che la misura ridà i numeri congelati.
5. **`27-dopo-la-lettura.R` è stato scritto dopo il deposito e prima della lettura.** Applica le definizioni
   depositate (errore nuovo per etichetta, classi dello studio). Non aggiunge regole.
6. **I criteri della lettura** (§5.1) precisano le tre cause depositate. Li ho fissati leggendo, non prima. Il
   revisore indipendente **non** li ha ricevuti: le sue istruzioni portano solo le definizioni depositate. Dove i
   due criteri erano diversi ho aggiudicato con quattro criteri scritti (C1-C4, §12), dichiarati dopo la revisione.
7. **L'errore di `B0` trovato dalla revisione non entra nei 9 depositati.** Un'etichetta di `B0` non conta come
   nuova: per questo `27-dopo-la-lettura.R` legge `26-errori-di-B0-aggiunti.csv`. Lo stesso script riporta accanto
   la regola di esito con l'insieme allargato, dopo aver ridato i numeri depositati.
8. **Le etichette possono comparire anche con «dove» = «in `B0`» o «in nessuna»**: la colonna delle etichette dice
   quali errori sono presenti nella lettura nuova, non la causa della differenza.
9. **`28-tabelle.py`** genera le tabelle di questo finding dai CSV. I conti di §5.4 e di §6 sono suoi.

# 8. Che cosa va al PI

L'handout assegna al PI due decisioni: se si scrive il Piano 2 (il lettore nel pacchetto, S12s), e che cosa si fa
degli studi segnalati e degli errori non segnalati. Il conto:

- la regola di esito dà **no**;
- la discordanza segnala 24 studi su 47; 15 hanno in `B0` gruppi identici ai curatori; in 8 dei 24 la differenza fra
  le letture non è un errore di lettura (2 forma, 6 non errore), e non hanno errori noti;
- non vede 5 dei 9 errori di `B0`, fra cui 2 dei 4 che costano; i loro studi sono segnalati solo perché una lettura
  cambia in un altro punto;
- la revisione indipendente ha trovato in `B0` un errore fuori dai 9, presente in tutte le 9 letture, in uno studio
  contato «senza errore» (`GSE147507`, §3.3): i 39 studi «senza errore» non sono provati senza errore;
- ogni lettura in più porta errori suoi (22 etichette nuove in 13 studi), e la regola non dice quale lettura è
  giusta;
- il disegno approvato (spec §5.5[^spec]) chiede che un errore del lettore trovato al cancello si corregga in
  «vista, schema o modello, non una regola a valle». Lo schema e il prompt sono stati variati in S12r4 senza
  trovare una correzione. La vista e il modello no.

**Decisione 1: che cosa si fa degli studi segnalati.**

| opzione | conseguenza |
|---|---|
| A. La discordanza non entra nella pipeline come filtro; resta uno strumento di misura (**raccomandata**) | gli errori che si muovono restano senza rimedio a valle; il rimedio si cerca a monte (decisione 2) |
| B. Gli studi segnalati escono dal deliverable | sui 47 restano 23 studi, con 21 gruppi identici, 2 errori noti che non costano e nessuno che costa (conto dopo i numeri, §6.2, su studi già letti); si perde circa metà degli studi; il calcolo del modello cresce di 9 volte; è una regola a valle, che la spec esclude |
| C. Gli studi segnalati restano, con una nota | gli errori restano nel deliverable; la nota cade su metà degli studi e non dice quale lettura è giusta |

**Decisione 2: si scrive il Piano 2 adesso?**

| opzione | conseguenza |
|---|---|
| A. No: prima una sessione sugli errori stabili, che cambia la vista (il testo dello studio e la tabella dei campioni che il modello riceve), con ogni variante letta più volte (**raccomandata**) | è il solo pezzo a monte non ancora variato; gli errori stabili non dipendono dalle parole del prompt, quindi la causa sta nella vista o nel modello; le 9 letture danno la misura del rumore, che in S12r4 mancava. Limiti: sesta lettura degli stessi 47 studi; gli errori stabili sono 5 in 5 studi (6 in 6 con quello di `GSE147507`), e una vista scritta dopo averli visti rischia di coprire quegli studi |
| B. Sì, con una lettura sola (`B0`) | il giudizio A (42 studi) mostrerà errori del lettore: sui 47 sono in 8 studi. La spec chiede allora una correzione a monte, che oggi non ha un nome; il giudizio A si consuma per una misura il cui esito è prevedibile |
| C. Sì, con più letture e la discordanza | vedi decisione 1, opzioni B e C |
| D. Un altro modello | serve una decisione nuova del PI: Mistral-Small 3.2 è il modello scelto; Mistral-Small-4-119B ha fatto peggio e non è ripetibile (S12r2); Qwen3.5-122B non è partito |
| E. Aprire una parte degli 82 studi solo per contare gli errori | si consumano studi che servono una volta sola |
| F. Dichiarare gli errori di lettura come limite | va contro la regola del PI: nessun errore si accetta |
| G. Fermare il lettore e tenere la pipeline di oggi | restano 13 confronti ritrovati su 95, contro 68 |

La raccomandazione è dell'agente e non è una misura. Se la sessione sulla vista non trova una causa, le strade che
restano sono D, B della decisione 1, F e G.

# 9. Le consegne ricevute, e che cosa passa al passo seguente

Ricevute da S12r4 (handout, sezione S12r5), tutte lette prima del lavoro. Passano **senza cambi** al Piano 2
(S12s), come dice l'handout:

- la regola del riferimento per i fattori di contesto (`growth condition`, `GSE65335`). In questa sessione 5
  letture nuove scrivono la condizione di crescita come perturbazione con base e ritrovano 2 confronti su 2 contro
  1 su 2 di `B0`: la scheda è «non errore», e la regola resta da scrivere;
- `GSE147507`: 10 confronti fuori dall'universo di Atlas; qui non chiude in `L3` e `L8`. **Nota nuova per S12s:**
  in quei confronti la lettura di `B0` ha almeno un difetto (il tempo letto da una sola delle due colonne, §3.3), e
  `B0` non legge ACE2 e ruxolitinib come fattori (ruxolitinib sta in `not_understood`). Il limite «una variabile
  scritta in più colonne» non è più «senza danno»;
- la misura dei confronti non elencati sugli 82 studi col suo intervallo.

Nuovo, da questa sessione: i 22 errori nuovi, le 31 etichette in 18 studi e l'errore di `B0` aggiunto
(`26-letture.csv`, `27-errori-nuovi.csv`, `26-errori-di-B0-aggiunti.csv`) sono il materiale di partenza di ogni
sessione seguente sugli errori di lettura.

Note nuove per il Piano 2, dalle osservazioni del revisore (§12.6), non contate come errori:

- lo schema dei ruoli non ha un ruolo per un attributo del soggetto che non è donatore, sesso, età o passaggio
  (`country` in `GSE69597`, `ancestry` in `GSE112057`): il modello li scrive come donatore;
- `GSE63816`: il livello della malattia coi 12 campioni MDS ha il nome «mutant» in tutte le 9 letture. La
  partizione è giusta, ma il nome entrerebbe nell'etichetta del confronto;
- le schede per la lettura dei disaccordi si fanno senza tagli (§12.5).

# 10. Limiti

1. **47 studi, letti per la quinta volta.** Le frasi, le regole e le previsioni sono state scritte prima, ma i 9
   errori di riferimento sono stati trovati su questi stessi studi. Il risultato non dice quanto vale la regola su
   studi nuovi.
2. **La regola di esito ha poca forza** (carta §6 punto 4): 8 studi con errore. Il «no» non prova che la
   discordanza non separa.
3. **I 39 studi «senza errore» non sono provati senza errore.** La revisione ha trovato un errore di `B0` in uno di
   questi (`GSE147507`). In 10 di questi una lettura nuova ha un errore: questo non dice che `B0` è giusto in ogni
   punto di quegli studi. I 23 studi non segnalati non hanno schede e nessun revisore li ha riletti.
4. **La lettura delle schede è un giudizio.** L'ha fatta un agente e l'ha rifatta un agente indipendente (§12): i
   due sono diversi in 9 schede su 38, e l'esito della previsione 11 cambia con un criterio. È un audit interno con
   un modello Claude: nessuna etichetta entra nella pipeline né nella validazione pubblicata. Il revisore ha letto
   schede con le voci troncate a 14 (19 file di schede su 24 hanno almeno una riga tagliata) e non ha letto il
   testo intero degli studi. Un errore di assegnazione è passato per questo a tutti e due (§12.5). Non ho fatto
   un controllo di tutte le assegnazioni campione per campione: fuori dai fattori dei curatori manca un riferimento.
5. **Il criterio «non cambia il senso» è un giudizio di due agenti**, non una prova.
6. **Otto frasi su 40 candidate.** Altre frasi possono muovere altri studi: l'andamento (§3.4) cresce ancora a 9
   letture, di 1 studio in media per lettura.
7. **La vista non è stata variata. Un solo modello.**
8. **Un errore uguale in tutte le letture e senza disaccordo con i curatori non è letto** (limite ereditato da
   S12r4: `country` in `GSE69597` in `B0`).

# 11. Anomalie viste durante il lavoro

- **Gli SHA-256 dei file `B0.jsonl` di S12r5 e di S12r4 sono diversi**: i file portano metadati della corsa (ora,
  job). Il testo dell'uscita per studio è identico in 47 studi su 47: è il confronto del cancello 1.
- **`GSE60340` `L7`**: il trattamento è letto (l'errore di `B0` è assente), ma lo studio non chiude perché due
  livelli mancano dall'elenco dichiarato. Dopo la revisione la scheda è «lettura del modello, in `B0`» (prima:
  «forma», come S12r4 per la stessa firma): la differenza da `B0` nasce dall'errore di `B0`, e la mancata chiusura
  è forma. Il predicato conta l'errore come assente: per questo lo stato cambia in 3 letture e i confronti ritrovati
  salgono in una sola (`L6`).
- **`GSE147507`**: la revisione ha trovato un errore di `B0` che S12r3 e S12r4 non avevano contato (§3.3, §12).
  In `L4` e `L8` il modello legge il ruxolitinib dalla `description` e lo assegna a 6 campioni (`GSM4486160`-`65`);
  la vista lo scrive solo nel `source_name_ch1` di `GSM4486163`-`65`. I 6 valori della `description` non nominano
  il ruxolitinib: il modello ha assegnato il livello a tutti i campioni infetti di quella serie.
- **`GSE112057`**: gruppi identici ai curatori e 0 confronti su 5 in tre letture. La misura dei gruppi non vede un
  valore mancante non dichiarato; la vede la misura dei confronti.

# 12. La revisione indipendente

## 12.1 Chi ha riletto, e da che cosa

Un agente indipendente (un subagente Claude: audit interno) ha riletto **tutte le 38 schede** senza vedere le mie
etichette[^revisione]. Il materiale stava in una cartella congelata fuori dal repository: le istruzioni, l'elenco
delle 38 schede, le etichette di S12r4 per questi studi e 24 file di schede, uno per studio. Le istruzioni portano
solo le definizioni depositate (causa, dove, etichette). **Non portano i miei criteri di lettura né il limite della
spec sulla variabile scritta in più colonne.**

Che cosa ha letto l'ho contato sul suo transcript dopo la revisione (`36-cosa-ha-letto.txt`): 34 comandi e una
lettura di file, tutti nella cartella congelata; nessun percorso fuori dalla cartella, niente rete, nessun altro
agente. Il revisore dichiara 27 file letti (le istruzioni, l'elenco, le etichette di S12r4, le 24 schede).

## 12.2 Le 38 schede: 29 uguali, 9 diverse

In 29 schede su 38 causa, dove ed etichette sono uguali alle mie. In 9 sono diverse: la causa in 5, il «dove» in 6,
le etichette in 7 (`35-aggiudicazione.md`, una scheda per volta, con il motivo). **Il revisore ha ragione in 8
schede e in parte in una.**

| scheda (letture) | io, prima | il revisore | dopo | chi ha ragione |
|---|---|---|---|---|
| `GSE112057` (`L1`, `L5`, `L7`) | lettura del modello; `NA` di `gender` | in più `NA` di `ancestry` | come il revisore | il revisore: la mia descrizione nominava `ancestry`, la mia etichetta no |
| `GSE112057` (`L2`, `L4`, `L8`) | non errore | lettura del modello, nella lettura nuova; `NA` di `ancestry` | come il revisore | il revisore (C1): errore senza effetto, 5 confronti su 5 |
| `GSE147507` (`L3`) | lettura del modello, nella lettura nuova | in tutte e due; in più `organism` e il tempo; senza «trattamento diviso» | in tutte e due; `organism`, tempo, «trattamento diviso» resta; tolta la mia etichetta su ACE2 e ruxolitinib da `source_name_ch1` (C4) | 3 punti al revisore, 1 a me |
| `GSE147507` (`L4`) | lettura del modello, nella lettura nuova | in tutte e due; in più il tempo | come il revisore, più il ruxolitinib (§12.5) | il revisore |
| `GSE147507` (`L8`) | lettura del modello, nella lettura nuova | in più il tempo | come il revisore, più il ruxolitinib (§12.5) | il revisore |
| `GSE147507` (`L2`) | non errore | lettura del modello, in tutte e due; il tempo | come il revisore | il revisore: è l'errore di `B0` fuori dai 9 (§3.3) |
| `GSE60340` (`L7`) | forma | lettura del modello, in `B0` | come il revisore | il revisore (C2) |
| `GSE63816` (`L6`) | non errore | lettura del modello, nella lettura nuova; `age` come donatore | come il revisore | il revisore (C1): errore senza effetto |
| `GSE63816` (`L7`) | forma | non errore | come il revisore | il revisore (C2) |

## 12.3 I quattro criteri dell'aggiudicazione, dichiarati dopo la revisione

I 9 disaccordi nascono quasi tutti da criteri che il deposito non scrive. Li ho scritti dopo la revisione, in
`35-aggiudica.py`, e li ho applicati a tutte le schede in disaccordo:

- **C1.** Un errore di lettura si conta anche se non cambia gruppi e confronti. S12r4 ha fatto così per i 9 errori
  di `B0`: 5 non costano. Prima non contavo due casi di questo tipo, con un criterio mio non scritto.
- **C2.** La causa di una scheda è la causa della differenza da `B0`, non di ogni difetto della lettura nuova.
- **C3.** Un errore che `B0` e la lettura nuova hanno in forma speculare ha una etichetta sola ed è un errore di
  `B0`: non è nuovo. Il revisore usa due etichette (una per colonna del tempo non letta).
- **C4.** Un fattore vero letto da una colonna col ruolo sbagliato è forma, non lettura.

C1 e C2 danno ragione al revisore. C3 e C4 sono scelte mie: C3 toglie un'etichetta nuova a `L2`, `L3` e `L4`
rispetto al conto del revisore.

## 12.4 I tre conti

| conto | cause (lettura, forma, non errore) | dove (`B0`, nuova, tutte e due, nessuna) | studi con un errore nuovo, `L1`…`L8` | mediana | etichette nuove | previsione 11 |
|---|---|---|---|---|---|---|
| io, prima della revisione (commit `ca32886`) | 21, 6, 11 | 4, 15, 2, 17 | 3, 4, 5, 5, 8, 1, 3, 3 | 3,5 | 19 in 13 studi | confermata |
| il revisore | 25, 4, 9 | 5, 15, 5, 13 | 3, 6, 5, 6, 8, 2, 3, 4 | 4,5 | 22 in 13 studi | smentita |
| io, dopo l'aggiudicazione | 25, 4, 9 | 5, 15, 5, 13 | 3, 5, 5, 6, 8, 2, 3, 4 | 4,5 | 22 in 13 studi | smentita |

Dopo l'aggiudicazione causa e dove sono uguali al revisore in 38 schede su 38. Le etichette restano diverse in tre
punti, e le due somme uguali (22) sono un caso:

1. il revisore ha due etichette per il tempo di `GSE147507` e io una (C3): per questo `L2` ha 6 studi nel suo conto
   e 5 nel mio;
2. in `L3` io tengo «trattamento diviso in due fattori», che il revisore non mette;
3. io ho l'etichetta del ruxolitinib in `L4` e `L8`, che il revisore non ha potuto verificare (§12.5).

**Che cosa non cambia:** i cancelli, la regola sulla discordanza, la regola di esito (no), le previsioni da 1 a 10,
le classi dei 24 studi segnalati (16, 2, 6 nei tre conti) e la previsione 12 (16 su 24). **Che cosa cambia:** la
previsione 11 passa da confermata a smentita (§4.2); le etichette nuove passano da 19 a 22; `B0` ha un errore
fuori dai 9 depositati.

**La regola di esito accanto, con l'errore di `B0` aggiunto** (dichiarata dopo i numeri, non sostituisce l'esito):
7 studi segnalati su 9 con errore contro 17 su 38, differenza +0,330, IC95 da −0,040 a +0,626. La condizione
sull'intervallo resta «no»[^dopo].

## 12.5 Un errore in più, da una osservazione del revisore

Il revisore scrive fra i dubbi: in `GSE147507` le letture `L4` e `L8` danno il ruxolitinib a 6 campioni dalla
`description`, la lettura `L3` a 3 campioni da `source_name_ch1`; «non posso verificare quale conto è giusto (voci
troncate)». L'ho verificato sulla vista intera e sulle uscite. I 6 valori della `description` sono i campioni
`GSM4486160`-`65`; il ruxolitinib è scritto solo nel `source_name_ch1` di `GSM4486163`-`65`. **`L4` e `L8` assegnano
il ruxolitinib a 3 campioni che non lo ricevono.** È un errore di lettura nuovo, che né io né il revisore avevamo
etichettato. L'ho aggiunto alle due schede. Il conto degli studi per lettura non cambia, perché `GSE147507` aveva già
un errore nuovo in `L4` e `L8`.

Il motivo per cui nessuno dei due lo aveva visto è un limite del materiale che ho preparato io: le schede mostrano
al massimo 14 voci per fattore, tagliano l'elenco dei valori distinti di una colonna e accorciano i valori
lunghi. 19 file di schede su 24 hanno almeno una riga tagliata. Il conto «campioni per livello» resta intero, ed è da quello che il revisore ha visto il 6 contro 3. Un
livello assegnato ai campioni sbagliati, dentro un fattore che i curatori non hanno e senza un conto che non torna,
può restare non visto in altre schede. Per le sessioni seguenti le schede si fanno senza tagli.

## 12.6 Le osservazioni del revisore senza etichetta

- `country` (`GSE69597`) e `ancestry` (`GSE112057`) hanno il ruolo di donatore, in `B0` e nelle letture nuove. Sono
  attributi del soggetto e non il donatore. Lo schema non ha un ruolo migliore: non è un errore del modello. Passa
  al Piano 2 come nota sullo schema dei ruoli.
- `GSE63816`: il livello della malattia coi 12 campioni MDS si chiama «mutant», in tutte le letture. La partizione
  dei campioni è giusta. Il nome sbagliato di un livello non cambia gruppi e confronti, ma entrerebbe nell'etichetta
  del confronto: l'ho aggiunto alle note per il Piano 2 e non l'ho contato, perché è uguale in `B0` e in tutte le
  letture e nessuna scheda lo mostra come differenza.
- Il revisore dissente da S12r4 in altri tre punti (`GSE49608` `L6`, `GSE60340` `L6`, `GSE60585`): ha giudicato le
  letture chiuse sui loro fatti, e le sue etichette sono uguali alle mie.

## 12.7 Limiti della revisione

- Il revisore ha letto le schede, non il testo intero degli studi né le uscite intere del modello.
- Il revisore è un modello Claude, come chi ha fatto la prima lettura: i due non sono indipendenti quanto due
  persone. L'accordo di 29 schede su 38 non è una misura di correttezza.
- I 23 studi non segnalati non hanno schede e non sono stati riletti. La revisione ha trovato un errore di `B0`
  stabile in uno studio segnalato: non dice quanti ce ne sono fra i non segnalati.
- L'aggiudicazione l'ho fatta io, che sono una delle due parti. Per questo i criteri sono scritti, i tre conti sono
  riportati tutti e i file del revisore sono nell'evidenza senza cambi.

# 13. Da dove vengono i numeri del riassunto

| Nel riassunto | Fonte | Valore letto |
|---|---|---|
| «9 volte: una con le istruzioni decise e 8 con una frase riscritta» | `01-carta.md` §2; `23-out.txt` | `B0` e `L1`-`L8`; 9 job `COMPLETED` |
| «24 studi su 47» | `24-out.txt`, regola sulla discordanza | segnalati 24 su 47 |
| «errori noti in 8 studi» | `24-stati-errori.csv` | 9 errori in 8 studi (`GSE46665` ne ha 2) |
| «6 di questi 8 studi e 18 degli altri 39» | `24-out.txt`, regola di esito | 6/8 = 0,750; 18/39 = 0,462; differenza +0,288, IC95 −0,091, +0,610 |
| «la regola dà no» | `24-out.txt`, regola di esito | (a) no, (b) sì: esito no |
| «la prova ha poca forza» | `14-out.txt`; `01-carta.md` §6 punto 4 | con 6 su 8 la condizione vale solo con al massimo 13 su 39 |
| «cinque dei 9 errori noti sono uguali in tutte le 9 letture» | `24-stati-errori.csv` | presenti 9 su 9: `GSE46665` sigle, `GSE57945`, `GSE50760`, `GSE71595`, `GSE75852` |
| «2 dei 4 errori che cambiano i gruppi o i confronti» | `24-stati-errori.csv`; `24-out.txt` previsione 7 | costano e presenti 9 su 9: `GSE46665` sigle, `GSE57945` sesso |
| «i due studi sono segnalati, ma per un'altra differenza» | `26-letture.csv`, schede di `GSE46665` (`L3`) e `GSE57945` (`L2`) | tempo ripetuto assente in `L3`; età come fattore di contesto in `L2` |
| «un secondo lettore indipendente ha trovato un errore in più, in uno studio che contavamo senza errori» | `34-revisione-indipendente/35-aggiudicazione.md`, scheda `GSE147507` (`L2`); `26-errori-di-B0-aggiunti.csv`; `24-stati-errori.csv` | `GSE147507:tempo letto da una sola delle due colonne`; lo studio non è fra gli 8 con errori di `B0` |
| «il tempo sta in due colonne, e ogni lettura ne legge una sola … in tutte le 9 letture» | uscite `analysis/p4-output/S12r5-letture/*.jsonl`, studio `GSE147507` | `time point` in `B0`, `L1`, `L5`-`L8`; `time after treatment` in `L2`-`L4`; l'altra colonna ha ruolo `uninformative` in 9 letture su 9 |
| «22 errori … in 13 studi» | `27-out.txt` | etichette nuove distinte 22, in 13 studi |
| «un numero di studi fra 2 e 8» | `27-out.txt` | `L1` 3, `L2` 5, `L3` 5, `L4` 6, `L5` 8, `L6` 2, `L7` 3, `L8` 4 |
| «16 hanno un errore in almeno una lettura e 8 no» | `27-out.txt`, classi | tocca un errore di lettura 16; forma 2; non errore 6 |
| «da 58 a 71 su 95 … contro 68» | `24-letture.csv` | `L5` 58, `L4` 71, `B0` 68 |
| «due corse con le stesse parole … uguali al carattere» | `24-out.txt`, cancello 1 | 47 studi su 47 |
| «restano 23 studi: 21 hanno i gruppi dei curatori e nessuno ha un errore noto che cambia i gruppi o i confronti» | `28-tabelle.md` §2 | 23 non segnalati; 21 identici; 2 errori noti che non costano |
| «non vede 5 errori noti su 9» | `24-stati-errori.csv` | 5 errori presenti in 9 letture su 9 |
| «nessuno ha riletto quei 23 studi» | `24-da-leggere-schede.csv` | schede solo per i 24 studi segnalati |
| «è la sesta prova sugli stessi 47 studi» | `CLAUDE.md` §1 | cinque prove fatte: S12r, S12r2, S12r3, S12r4, S12r5 |
| «il calcolo del modello cresce di 9 volte» | `01-carta.md` §2 | 9 letture per studio |
| «gli errori uguali in tutte le letture sono 6» | `24-stati-errori.csv`; `26-errori-di-B0-aggiunti.csv` | 5 dei 9 depositati, più l'errore di `B0` trovato dalla revisione |
| «uno ha fatto peggio e non è ripetibile, e l'altro non è partito» | `CLAUDE.md` §1, riga della prova ripetuta (S12r2) | Mistral-Small-4-119B 32/97 e 25/97; Qwen3.5-122B non misurato |
| «13 confronti su 95 contro 68» | `CLAUDE.md` §1, riga della terza prova (S12r3); `24-letture.csv` | oggi 13, lettore 68 |
| «82 studi chiusi» | ADR-0029 | 42 giudizio A + 40 giudizio B |

[^carta]: `analysis/audit/2026-11-12-S12r5-piu-letture/01-carta.md`.
[^previsioni]: `analysis/audit/2026-11-12-S12r5-piu-letture/00-previsioni.md`.
[^riscritture]: `analysis/audit/2026-11-12-S12r5-piu-letture/11-riscritture.csv`.
[^giudizio]: `analysis/audit/2026-11-12-S12r5-piu-letture/12-giudizio-esito-giro1.csv`.
[^strumento]: `analysis/audit/2026-11-12-S12r5-piu-letture/13-out.txt`.
[^potenza]: `analysis/audit/2026-11-12-S12r5-piu-letture/14-out.txt`.
[^corse]: `analysis/audit/2026-11-12-S12r5-piu-letture/23-out.txt`.
[^misura]: `analysis/audit/2026-11-12-S12r5-piu-letture/24-out.txt`.
[^letturecsv]: `analysis/audit/2026-11-12-S12r5-piu-letture/24-letture.csv`.
[^segnalati]: `analysis/audit/2026-11-12-S12r5-piu-letture/24-segnalati.csv`.
[^stati]: `analysis/audit/2026-11-12-S12r5-piu-letture/24-stati-errori.csv`.
[^andamento]: `analysis/audit/2026-11-12-S12r5-piu-letture/24-andamento.csv`.
[^schede]: `analysis/audit/2026-11-12-S12r5-piu-letture/26-letture.csv`.
[^dopo]: `analysis/audit/2026-11-12-S12r5-piu-letture/27-out.txt`.
[^tabelle]: `analysis/audit/2026-11-12-S12r5-piu-letture/28-tabelle.md`.
[^revisione]: `analysis/audit/2026-11-12-S12r5-piu-letture/34-revisione-indipendente/`.
[^s12r4]: `docs/findings/2026-11-12-S12r4-cause-errori-di-lettura.md`.
[^spec]: `docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md` §5.2 punto 5 (una variabile scritta in più colonne) e §5.5 (il cancello).
[^adr29]: `docs/decisions/0029-lettore-dello-studio-tabella-dei-fattori.md`.
