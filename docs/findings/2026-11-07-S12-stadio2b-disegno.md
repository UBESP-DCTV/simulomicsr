---
type: Finding
title: "Stadio 2b, il disegno: la lista di controllo, la regola, l'ingresso e le previsioni per la prova cieca"
description: "S12: schema della lista di controllo, regola deterministica con test, prompt e ingresso senza tagli per il nuovo giudice di confrontabilita' (ADR-0028); misura dell'ingresso sui 1.903 confronti del deliverable; previsioni per S12p. Nessun run del modello. Quattro decisioni del PI in attesa."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-07T23:40:00+01:00'}
sources:
- {id: prev, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/00-previsioni.md", title: "Cancelli e previsioni, depositati prima del calcolo (commit f8228f5)"}
- {id: spec, resource: "docs/superpowers/specs/2026-11-07-stadio-2b-design.md", title: "Spec dello Stadio 2b"}
- {id: adr, resource: "docs/decisions/0028-stadio-2b-giudice-di-confrontabilita.md", title: "ADR-0028"}
- {id: ingr, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/20-out.txt", title: "Ingresso dei 1.903 confronti: cancelli C2-C3, previsioni P1-P3"}
- {id: lung, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/20-lunghezze-campi.csv", title: "Lunghezze dei campi dell'H5 (P2)"}
- {id: taglio, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/21-out.txt", title: "Stringhe alla lunghezza massima e picchi"}
- {id: geo, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/22-out.txt", title: "Confronto con GEO in rete, 13 campioni"}
- {id: codifica, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/23-out.txt", title: "Codifica UTF-8 doppia: prima e dopo la riparazione"}
- {id: assenti, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/24-out.txt", title: "Campi GEO che l'H5 non contiene, 40 studi"}
- {id: tipi, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/25-out.txt", title: "Meta-analisi e confronti per tipo di entita'"}
- {id: sha, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/90-sha256.txt", title: "Impronte dei file congelati per S12p"}
- {id: val, resource: "docs/findings/2026-11-07-valutazione-autonoma-del-progetto.md", title: "Valutazione autonoma (85 categorie, 55 con un caso)"}
---

# In breve

## In breve: come deve giudicare il nuovo passo se un trattato e il suo controllo sono confrontabili?

**A cosa serviva.** Il nuovo passo della pipeline fa leggere al modello il testo grezzo dei campioni di un
trattato e del suo controllo. Il modello compila una lista di controllo, e una regola fissa decide se il
confronto entra nella meta-analisi. Questa sessione ha scritto la lista, la regola con i suoi test, le istruzioni
per il modello e il testo d'ingresso. Ha anche depositato le previsioni per la prova cieca sui 1.903 confronti
del deliverable.

**Cosa abbiamo trovato.**

1. **La lista di controllo e la regola sono pronte, e ogni segnale della regola ha un test.** La lista chiede al modello gli
   agenti di ciascun braccio, il tempo di raccolta, undici caratteristiche dei campioni e ogni altra differenza,
   sempre con la citazione del testo. La regola prima accende dei segnali, poi una tabella dice se ogni segnale
   è un errore o un avviso. La tua decisione cambia solo la tabella.
2. **Il modello leggerà per intero il testo di 1.902 confronti su 1.903.** Il testo di un confronto occupa in
   mediana circa 3.600 token. L'unico confronto fuori dal limite ha 117 campioni: la regola lo scarta e non
   taglia il testo. La pipeline legge i metadati da una copia di GEO, il file di ARCHS4. Su 13 campioni
   confrontati con GEO in rete, il testo della copia coincide con quello di GEO, a parte la codifica.
3. **Nella copia di ARCHS4 una parte dei testi ha lettere greche e simboli rovinati, e ora l'ingresso li ripara.** Il testo è
   codificato due o tre volte, per esempio «1Î¼M» al posto di «1μM». Nei campioni dei 1.903 confronti la
   riparazione cambia 194 titoli, 104 sorgenti e 384 caratteristiche. Dopo la riparazione nessun ingresso
   conserva questi segni.
4. **La copia di ARCHS4 non contiene la descrizione del campione, e la descrizione porta informazione utile.** Su 40 studi
   scelti a caso, la descrizione cambia da campione a campione in 22 studi: porta donatore, sesso, età, tempo o
   trattamento. I protocolli di trattamento e di coltura esistono in 25 studi, ma sono uguali in tutti i
   campioni dello studio.
5. **Le previsioni per la prova cieca sono depositate.** Il modello deve prendere almeno 130 dei 193 confronti
   difettosi e accusare al massimo 40 dei 1.710 confronti puliti. Meno del 30% delle voci della lista deve
   restare «non detto».

**Cosa devi decidere.**

1. **Aggiungiamo all'ingresso la descrizione del campione e i due protocolli presi da GEO? Raccomando di sì.**
   La descrizione è l'unico campo per campione che il modello oggi non vede. In più di metà degli studi
   controllati porta dati sul donatore, sul tempo o sul trattamento. Il costo è uno scaricamento per studio,
   congelato con data e impronta, perché GEO cambia nel tempo.
   - Se rispondi sì, preparo lo scaricamento per i 993 studi della prova e aggiorno le istruzioni prima di
     chiudere la sessione.
   - Se rispondi no, il modello legge gli stessi campi che hanno letto i lettori dei 193 difetti, e il limite
     va nei Methods.
2. **Nei confronti malati contro sani, i donatori diversi passano con un avviso? Raccomando di sì.** 42
   meta-analisi su 194 confrontano malati e sani, con 305 confronti, e i loro bracci vengono per forza da
   persone diverse.
   - Se i donatori diversi sono sempre un errore, queste meta-analisi perdono quasi tutti i loro confronti.
   - Il sesso o l'età senza valori in comune fra i due bracci restano un errore anche qui.
3. **I dati non detti e i casi incerti passano con un avviso? Raccomando di sì.** I casi sono quattro. Il testo
   non dice una caratteristica per un braccio. Donatori, sesso o età sono in parte diversi. Il testo del
   controllo non nomina un agente del trattato. Il modello non sa riconoscere l'entità. La decisione sul nuovo
   passo fa già passare i dati non detti.
   - Se un dato non detto è un errore, cade ogni confronto in cui il testo tace su una sola delle undici
     caratteristiche.
   - Se gli altri tre casi sono errori, cadono i disegni appaiati con un campione senza coppia e le entità
     scritte con sigle poco note.
4. **Una differenza fra i bracci che non sta nella lista è sempre un errore? Raccomando di sì.** I difetti noti
   hanno 85 forme, e 55 compaiono una volta sola: nessuna lista chiusa le copre. La voce aperta è l'unico modo
   di prenderle.
   - Se è un avviso, la coda dei difetti unici passa.
   - Il rischio del sì è che il modello segnali differenze banali, ma la prova cieca conta questi falsi allarmi.

**Comunque.** Il tempo zero e la differenza tecnica fra i bracci restano sempre errori, come hai deciso, anche
quando la differenza tecnica tocca un solo campione. Dopo le tue decisioni viene la prova cieca: tre modelli
leggono i 1.903 confronti. Il conto contro i 193 difetti si apre solo quando le uscite sono congelate. La
regola sugli studi doppi passa al ricalcolo finale. Il passo che ricostruisce il disegno di ogni studio ha
sempre lavorato senza il riassunto dello studio: va scritto nei Methods.

Appena decidi questi 4 punti, la sessione è chiusa.

---

# 1. Che cosa c'è su disco

| pezzo | file | commit |
|---|---|---|
| cancelli e previsioni | `analysis/audit/2026-11-07-S12-stadio2b-disegno/00-previsioni.md` | `f8228f5` (prima del calcolo) |
| schema della lista di controllo | `inst/schemas/comparison_check.stage2b.v1.json` | `efa44ac` |
| prompt di sistema | `inst/prompts/stage2b-v1.md` | `efa44ac` |
| ingresso e prompt | `R/stage2b-input.R` | `efa44ac` |
| regola | `R/stage2b-rule.R` | `efa44ac` |
| test | `tests/testthat/test-stage2b-{rule,input,schema}.R`, `helper-stage2b.R` | `efa44ac` |
| spec | `docs/superpowers/specs/2026-11-07-stadio-2b-design.md` | questo commit |
| ingresso congelato per S12p | `20-ingressi-1903.jsonl.gz`, `20-campi-h5-campioni.rds`, impronte in `90-sha256.txt` | `73955aa` e questo commit |

Il disegno completo (voci, segnali, tabella degli esiti, prompt, configurazione della prova) sta nella spec[^spec].
Qui stanno le misure e i dubbi.

# 2. Cancelli

| # | cancello | esito | fonte |
|---|---|---|---|
| C1 | manifesto SHA-256 del deliverable | **passa** | `10-manifesto-inizio.txt` |
| C2 | 1.903 confronti, 194 gruppi, ogni GSM nell'H5, conteggi per braccio giusti | **passa**: 15.559 GSM, 0 mancanti, 0 confronti con un GSM in entrambi i bracci | `20-out.txt`[^ingr] |
| C3 | ogni valore di ogni campo sta per intero nell'ingresso | **passa**: 1.903 su 1.903 | `20-out.txt`[^ingr] |
| C4 | test verdi, ogni segnale con il suo controllo positivo, il confronto pulito passa | **passa**: 195 asserzioni sui tre file dello Stadio 2b; 442 sui 17 file dello Stadio 2, 2b e validazione, 0 fallimenti, 1 test saltato (lo smoke con la chiave API) | `testthat` |
| C5 | nessun accession GEO in prompt, schema e test | **passa** (test nello schema) | `test-stage2b-schema.R` |

# 3. Previsioni

| # | quantità | atteso | intervallo di rilevanza | risultato | giudizio |
|---|---|---|---|---|---|
| P1 | confronti oltre il limite di 26.624 token | 0-5 | 0-19 | **1** su 1.903 (117 campioni, 39.674 token stimati) | **confermata** (conteggio su tutti i confronti, nessun intervallo di confidenza) |
| P2 | campi H5 con ≥ 5 stringhe alla lunghezza massima, se ≥ 255 byte | 0 | 0 | **2** (`extract_protocol_ch1`, `data_processing`) | **smentita** come scritta; dubbio chiuso, **spiegato** in §4: le stringhe alla massima sono lo stesso testo completo ripetuto nei campioni di uno studio |
| P3 | token stimati per confronto | mediana 2.000-6.000; 99° percentile < 20.000 | mediana > 10.000 | mediana **3.603**, 99° percentile **7.817** | **confermata** |
| P4-P6 | per la prova cieca | ≥ 130/193; ≤ 40/1.710; `not_stated` < 30% | dall'ADR e dall'handout | si giudicano in S12p | — |

Somma dei token stimati sui 1.903 confronti: 7.468.903, con il prompt di sistema di 2.811 token. Con tre modelli
la prova legge circa 22 milioni di token d'ingresso: il piano «una notte» regge (§9).

# 4. L'ingresso: niente tagli, ma una codifica rovinata

**Stringhe alla lunghezza massima (P2).** Il criterio depositato contava le stringhe alla lunghezza massima, ma
non distingueva un taglio da un testo ripetuto. Alla massima di `extract_protocol_ch1` (14.310 byte) ci sono 10
stringhe, **1 distinta**, da 1 serie, che finisce con una frase completa; lo stesso per `data_processing`
(10.605 byte: 6 stringhe, 1 distinta)[^taglio]. I picchi di stringhe *distinte* a una stessa lunghezza
(`characteristics_ch1` a 621, 847, 1.836 byte; `data_processing` a 941) vengono da modelli di testo con numeri
della stessa larghezza, con fini complete.

**Confronto con GEO in rete** (13 campioni: i due testi più lunghi, i 5 `source_name` che finiscono con «...»,
6 `data_processing` che finiscono con «...» scelti a caso con seme 20261107)[^geo]. I «...» stanno già in GEO:
nessun taglio di ARCHS4. Dopo la riparazione della codifica, 24 campi su 25 coincidono con GEO; il venticinquesimo
ha una codifica mista che la riparazione semplice dello script di confronto non tocca. I 5 `source_name` tagliati
da GEO non stanno nei campioni dei 1.903. Questa verifica è un campione, e si dichiara come tale.

**La codifica UTF-8 doppia e tripla.** L'H5 contiene testi codificati due volte («Â°C» per «°C», «1Î¼M» per «1μM»)
e alcuni tre volte («Ã\u0082Âµ» per «µ»). L'ingresso li ripara (spec §2, test con controllo positivo e con
testo corretto che non deve cambiare). Sui 15.559 campioni dei 1.903 confronti[^codifica]:

| campo | stringhe con il marcatore prima | dopo | cambiate dalla riparazione | cambiate senza marcatore |
|---|---|---|---|---|
| title | 194 | 0 | 194 | 0 |
| source_name_ch1 | 104 | 0 | 104 | 0 |
| characteristics_ch1 | 384 | 0 | 384 | 0 |
| extract_protocol_ch1 | 7.450 | 0 | 7.450 | 0 |
| data_processing | 2.928 | 0 | 2.928 | 0 |

Il marcatore è un carattere U+00C2-U+00F4 seguito da U+0080-U+00BF. Ingressi con il marcatore dopo la riparazione:
**0 su 1.903**. Due correzioni fatte in corsa, prima di scrivere: la prima riparazione faceva un solo passo e
lasciava 222 ingressi con segni residui (stringhe codificate tre volte), e il confronto fra stringhe con
codifiche marcate diverse in R dava un esito sbagliato; la prima versione del marcatore vedeva solo «Ã», «Â»,
«â» e non le lettere greche. L'uscita della prima esecuzione, prima della riparazione, sta in
`20-out-prima-della-codifica.txt`; P1 e P3 non cambiano.

Questo difetto di codifica tocca anche gli Stadi 1 e 2 di produzione, che leggono lo stesso testo: «TGF-Î²1»
arriva così al modello. Lo Stadio 2b lo ripara solo per sé. Rinvio in §8.

# 5. I campi GEO che l'H5 non contiene

L'H5 di ARCHS4 v2.5 non ha `description`, `treatment_protocol_ch1`, `growth_protocol_ch1`, `label_ch1`, né il
testo della serie. Su 40 studi scelti a caso fra i 993 dei 1.903 confronti (seme 20261107; 843 campioni dei
bracci, tutti trovati in GEO)[^assenti]:

| campo | studi in cui c'è | campioni | studi in cui cambia fra i campioni dei bracci |
|---|---|---|---|
| `treatment_protocol_ch1` | 25 | 605 | 0 |
| `growth_protocol_ch1` | 25 | 208 | 0 |
| `description` | 24 | 644 | 22 |
| `label_ch1` | 0 | 0 | 0 |

Nella `description` ci sono, per esempio, «Healthy female aged 26 years (Donor 1)», sigle con il tempo
(«O3-330-24-1»), nomi di trattamento («DMSO-1», «inhibitor-1»), ma anche nomi di file e numeri di libreria. I
protocolli sono uguali in tutto lo studio: non distinguono i bracci campione per campione, ma possono descrivere
tempi e veicoli. I lettori che hanno costruito il riferimento dei 193 hanno letto titolo, sorgente e
caratteristiche, più i campi tecnici: se il modello legge di più, può trovare difetti che il riferimento non ha,
e la prova S12p li conta come falsi allarmi da leggere (handout S12p, punto 5). **Decisione 1 del PI.**

# 6. La lista di controllo e la regola

La spec[^spec] descrive voci, segnali ed esiti. Tre scelte tecniche, prese qui:

- **Due passi.** La regola accende segnali; una tabella dà a ciascuno «errore» o «avviso». Un segnale senza esito
  ferma la regola. Così la decisione del PI cambia una tabella, non il codice, e i test controllano entrambi.
- **La tecnica dei campi strutturati la calcola il codice**, non il modello: `instrument_model`, `platform_id`,
  `library_selection`, `library_source`, `library_strategy`, `molecule_ch1` senza valori in comune fra i bracci, o
  in comune solo in parte. Il modello legge la tecnica scritta nel testo (paired-end, kit, 4sU).
- **Il veicolo non è una differenza.** Un veicolo o un controllo negativo in un solo braccio non accende segnali:
  un controllo «untreated» contro un trattato in DMSO passa.

**Che cosa vede la regola e che cosa non vede** (regola scientifica 6). Vede ogni fatto che il modello scrive
nella lista. Non vede un fatto che il modello omette o sbaglia: la regola si fida della lista. Le citazioni si
possono verificare come sottostringhe dell'ingresso; la v1 le conta ma non scarta per una citazione non trovata.

**Cecità.** In questa sessione non ho aperto `41-riferimento-dopo-S11.csv` né `difetti.csv`, e non ho letto il
codice del rilevatore di S10-S10b. Ho letto i finding S11 e la valutazione, che citano alcuni studi difettosi
per numero: il prompt e i test non usano nessun esempio preso da lì (test C5 sugli accession; i nomi nei test
sono inventati). Le voci della lista vengono dalle categorie dei 193 attraverso ADR-0028: la prova è cieca
sugli esempi, non sulle categorie (spec §8).

# 7. Dubbi ricevuti (riquadro della S12 nell'handout del 2026-08-21)

| dubbio | da | come si chiude |
|---|---|---|
| 18 errori del rilevatore, sette cause | S11 | **spiegato**: il rilevatore non va in produzione (ADR-0028). Lo Stadio 2b non legge i fatti dello Stadio 1, quindi spariscono per costruzione quattro cause (condizione scritta solo sul trattato, campo del passaggio usato per altro, perturbazione vuota contata, mutazione come knockout). Le altre tre hanno una voce: agente comune marcato «controllo negativo» → `vehicle_or_mock` e presenza nei due bracci; stesso tempo in due modi → ore convertite (test «1 giorno = 24 h»); nome dell'entità non riconosciuto → `is_proposed_entity` accetta sinonimi e sigle. La prova S12p misura se funziona. |
| 112 errori noti non visti dal rilevatore | S11 | **spiegato**: tempo zero solo nei titoli → lo Stadio 2b legge i titoli e il prompt definisce il tempo zero; differenze tecniche → campi strutturati nel codice e asse `technique`; i 6 casi in cui la regola di S10b non scattava riguardano un codice che non va in produzione. La prova S12p conta quanti ne prende. |
| idee per la regola sui fatti (plus, materiale incoerente, linea vuota, normoxia come agente, sinonimi della sede) | S10b | **spiegato**: riguardano la regola sui fatti dello Stadio 1, superata da ADR-0028. «Normoxia» e gli altri stati di assenza non sono agenti (prompt); la sede è un asse letto dal modello. |
| regola sugli studi doppi, con test | S5 | **rinviato** a S13, come il rinvio stesso prevedeva; scritto nel riquadro di S13 dell'handout del 2026-11-07. |

# 8. Dubbi aperti in questa sessione

| dubbio | come si chiude |
|---|---|
| P2 smentita come scritta | **spiegato** (§4): testo ripetuto, non tagliato; confronto con GEO |
| codifica UTF-8 doppia e tripla nell'ingresso | **corretto** nello Stadio 2b (§4, test) |
| la stessa codifica arriva agli Stadi 1 e 2 di produzione | **rinviato** a S13 (vedi sotto) e a S17 |
| un confronto oltre il limite di lunghezza | **spiegato**: dentro l'intervallo di P1; la regola lo scarta. S12p misura i token veri nello smoke e, se il rapporto vero lo fa stare nel limite, lo manda al modello |
| campi GEO assenti dall'H5 | **decisione del PI** (decisione 1) |
| lo Stadio 2 di produzione riceve il riassunto dello studio vuoto (24.983 record su 24.983 dell'ingresso S14; lo script d'ingresso v3 lo scrive vuoto, senza un motivo scritto) | **rinviato** a S17: va nei Methods. Non cambia nulla nello Stadio 2b, che non usa lo Stadio 2 per il giudizio |
| tabella degli esiti | **decisione del PI** (decisioni 2, 3, 4) |

**Rinvio a S13: la codifica negli Stadi 1 e 2.** Che cosa: gli Stadi 1 e 2 di produzione ricevono il testo con
la codifica rovinata. Perché conta: i nomi con lettere greche arrivano al modello come «Î²»; S9 ha già misurato
nomi d'anchor rovinati dalla codifica. Che cosa serve: decidere se S13 usa la stessa riparazione
(`.s2b_norm_testo()`) dove la pipeline costruisce nomi e chiavi; il re-run dei due passi col modello è fuori
discussione senza una decisione del PI.

# 9. La prova S12p: che cosa le serve da qui

- Ingresso congelato e impronte (`90-sha256.txt`)[^sha]; schema, prompt e regola alle versioni dei commit di S12.
- Il limite di 26.624 token usa la stima prudente di 3 caratteri per token; lo smoke misura il conteggio vero.
- 22 milioni di token d'ingresso per tre modelli (stima). Su una H100 la lettura dell'ingresso è veloce; la
  risposta (fino a 6.144 token, attesa intorno ai 1.500) domina il tempo. La stima di durata la fa S12p dallo smoke.
- Se il PI sceglie sì alla decisione 1, l'ingresso cambia prima della prova: scaricamento congelato, nuovo
  `20-ingressi-1903.jsonl.gz`, nuove impronte, e P1-P3 rimisurate.

# Da dove vengono i numeri del riassunto

| frase del riassunto | file | valore letto |
|---|---|---|
| 1.903 confronti del deliverable | `20-out.txt`, cancello C2 | «1903 confronti, 194 gruppi» |
| il testo di 1.902 confronti su 1.903 sta nel limite | `20-out.txt`, riga P1 | «1 su 1903» |
| mediana circa 3.600 token | `20-out.txt`, riga P3 | «mediana 3603» |
| l'unico fuori dal limite ha 117 campioni | `20-out.txt`, tabella «oltre il limite» | n_t 68, n_c 49 |
| 13 campioni confrontati con GEO | `21-out.txt` / `22-out.txt` | «campioni scelti per il confronto con GEO: 13» |
| 194 titoli, 104 sorgenti, 384 caratteristiche riparate | `23-out.txt` | «cambiate dalla riparazione 194 / 104 / 384» |
| nessun ingresso conserva questi segni | `23-out.txt`, prima riga | «0 su 1903» |
| 40 studi; descrizione che cambia in 22 | `24-out.txt`, ultime righe | «description presente in 24 studi ... cambia ... in 22 studi» |
| protocolli in 25 studi, uguali in tutto lo studio | `24-out.txt` | «presente in 25 studi ... cambia ... in 0 studi» |
| almeno 130 dei 193, al massimo 40 dei 1.710, meno del 30% | `00-previsioni.md`, P4-P6 | 130, 40, 30% |
| 42 meta-analisi su 194, 305 confronti | `25-out.txt`, riga `disease_vs_normal` | 42, 305 |
| 85 forme, 55 una volta sola | `docs/findings/2026-11-07-valutazione-autonoma-del-progetto.md` §2, riga «Coda lunga» | «85 categorie distinte di difetto; 55 con un solo caso» |
| 993 studi della prova | `24-scelta-out.txt` | «studi nei 1.903: 993» |

[^spec]: `docs/superpowers/specs/2026-11-07-stadio-2b-design.md`
[^ingr]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/20-out.txt`
[^taglio]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/21-out.txt`
[^geo]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/22-out.txt`
[^codifica]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/23-out.txt`
[^assenti]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/24-out.txt`
[^sha]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/90-sha256.txt`
