---
type: Finding
title: "Stadio 2b, il disegno: la lista di controllo, la regola, l'ingresso e le previsioni per la prova cieca"
description: "S12: schema della lista di controllo, regola deterministica con test, prompt e ingresso senza tagli per il nuovo giudice di confrontabilita' (ADR-0028); misura dell'ingresso sui 1.903 confronti del deliverable; previsioni per S12p. Nessun run del modello. Parte 2 (2026-11-08): quattro decisioni del PI, campi GEO congelati nell'ingresso, due campioni cancellati da GEO, che il ricalcolo finale toglie (decisione del PI)."
status: draft
generated: {by: simulomicsr-agent/skill-v1, at: '2026-11-08T13:30:00+01:00'}
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
- {id: prev2, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/00-previsioni-parte2.md", title: "Parte 2: decisioni del PI, cancelli G1-G5 e previsioni P7-P10 (commit 15a157e)"}
- {id: scar, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/26-out.txt", title: "Scaricamento dei testi GEO, 993 studi (e 26-out-ripresa.txt)"}
- {id: estr, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/27-out.txt", title: "Estrazione dei campi GEO: G2, G3"}
- {id: canc, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/27-cancellati-da-geo.json", title: "Campioni cancellati da GEO"}
- {id: ingr2, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/28-out.txt", title: "Ingresso con i campi GEO: R0, G2, G4, P7-P10"}
- {id: sha2, resource: "analysis/audit/2026-11-07-S12-stadio2b-disegno/91-sha256.txt", title: "Impronte dei file congelati per S12p, parte 2"}
---

# In breve

## In breve: come deve giudicare il nuovo passo se un trattato e il suo controllo sono confrontabili?

**A cosa serviva.** Il nuovo passo della pipeline fa leggere al modello il testo grezzo dei campioni di un
trattato e del suo controllo. Il modello compila una lista di controllo, e una regola fissa decide se il
confronto entra nella meta-analisi. Ieri questa sessione ha scritto la lista, la regola con i test e le
istruzioni per il modello. Ha anche depositato le previsioni per la prova cieca sui 1.903 confronti del
deliverable. Oggi hai preso
le quattro decisioni, e il testo d'ingresso ora contiene anche la descrizione e i protocolli dei campioni presi
da GEO.

**Cosa abbiamo trovato.**

1. **Il controllo che chiedeva il testo GEO di ogni campione è fallito per 2 campioni su 15.559, perché GEO li ha
   cancellati.** Lo staff di GEO ha cancellato i due campioni il 12 ottobre 2024, e la copia di ARCHS4 li contiene
   ancora. I due campioni formano tutto il controllo di 2 confronti su 1.903, in uno studio sull'ipossia. Ora
   l'ingresso scrive per questi campioni che il testo GEO non è disponibile. Un campione senza testo e senza la
   prova della cancellazione ferma il calcolo.
2. **Le tue quattro risposte coincidono con la tabella della regola, e un test ora le fissa.** Nessun esito è
   cambiato.
3. **Il testo GEO che il modello leggerà descrive la stessa versione dei campioni che usa la pipeline.** Ho
   scaricato e congelato i testi di tutti i 993 studi, con data e impronta. Il titolo scaricato coincide con il
   titolo della copia di ARCHS4 in tutti i 15.557 campioni che GEO ha ancora.
4. **La descrizione cambia da campione a campione in 4 studi su 10, non in più di metà come diceva la stima su
   40 studi.** La descrizione esiste in 513 studi su 993 e cambia fra i campioni dei bracci in 419. Il modello
   la legge campione per campione in 729 confronti su 1.903.
5. **Il testo d'ingresso cresce poco, e 1.902 confronti su 1.903 restano nel limite di lunghezza.** La mediana
   sale da circa 3.600 a 3.920 token per confronto.

**Cosa devi decidere.** Hai deciso il 2026-11-08: i campioni cancellati da GEO si tolgono nel ricalcolo finale.

1. **I campioni che GEO ha cancellato restano nella pipeline? Raccomando di toglierli nel ricalcolo finale.**
   Un lettore dell'articolo non può ritrovare questi campioni in GEO. Lo staff di GEO li ha cancellati per un
   motivo che non conosciamo, e quel motivo può essere un errore nei dati.
   - Se rispondi sì, il ricalcolo finale toglie ogni campione cancellato. Qui i 2 confronti perdono il controllo.
     Il numero totale si conosce solo quando il ricalcolo finale scarica il testo di tutti gli studi candidati.
   - Se rispondi no, i campioni restano, e i Methods devono elencarli e dire che GEO li ha cancellati.
   - In ogni caso la prova cieca tiene i 2 confronti, perché misura il modello sui confronti del deliverable
     così come sono.

**Comunque.** Il tempo zero e la differenza tecnica fra i bracci restano sempre errori. Il prossimo passo è la
prova cieca: tre modelli leggono i 1.903 confronti con il testo nuovo. Il conto contro i 193 difetti si apre
solo quando le uscite sono congelate. Il ricalcolo finale scarica da GEO il testo di tutti gli studi candidati
con lo stesso script.

Il controllo fallito ha una causa nota, e l'ingresso ora la scrive. Hai deciso questo punto: la sessione è
chiusa.

**Sui tempi di calcolo.** Lo scaricamento dei 993 studi ha richiesto 41 minuti misurati, con un solo processo e
una pausa di 0,4 secondi fra le richieste.

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
| ingresso della prima parte, solo H5 (non va alla prova) | `20-ingressi-1903.jsonl.gz`, `20-campi-h5-campioni.rds`, impronte in `90-sha256.txt` | `73955aa`, `64527e7` |
| cancelli e previsioni, parte 2 | `00-previsioni-parte2.md` | `15a157e` (prima dello scaricamento) |
| ingresso con i campi GEO, campioni cancellati marcati, tabella degli esiti decisa | `R/stage2b-input.R`, `R/stage2b-rule.R`, test, prompt | `9ca12fe`, `6d2fe9d` |
| testi GEO congelati (993 studi, 155 MB, fuori da git) | `analysis/p4-output/S12-geo-campioni-20261108/`; copia verificata in `/mnt/micron/simulomicsr-salvataggio/S12-geo-campioni-20261108/`; impronte `26-manifesto-testi-geo.sha256` | `6c6d0ed` |
| **ingresso congelato per S12p** | `28-ingressi-1903.jsonl.gz`, `27-campi-geo-campioni.jsonl.gz`, `27-cancellati-da-geo.json`, `20-campi-h5-campioni.rds`, impronte in `91-sha256.txt` | `6c6d0ed` |

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
e la prova S12p li conta come falsi allarmi da leggere (handout S12p, punto 5). **Decisione 1 del PI: sì
(2026-11-08).** La misura su tutti i 993 studi sta in §10: la stima su 40 studi era alta.

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
| campi GEO assenti dall'H5 | **deciso** dal PI il 2026-11-08: sì; fatto in §10 |
| lo Stadio 2 di produzione riceve il riassunto dello studio vuoto (24.983 record su 24.983 dell'ingresso S14; lo script d'ingresso v3 lo scrive vuoto, senza un motivo scritto) | **rinviato** a S17: va nei Methods. Non cambia nulla nello Stadio 2b, che non usa lo Stadio 2 per il giudizio |
| tabella degli esiti | **deciso** dal PI il 2026-11-08: la tabella proposta, senza cambi; un test la fissa |

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
- Il PI ha scelto sì alla decisione 1: l'ingresso della prova è `28-ingressi-1903.jsonl.gz` (§10), con le
  impronte in `91-sha256.txt`. Il `20-ingressi-1903.jsonl.gz` della prima parte resta come evidenza.

# 10. Parte 2 (2026-11-08): le decisioni del PI e i campi GEO

**Decisioni del PI** (2026-11-08, tutte come raccomandato): (1) l'ingresso contiene `description`,
`treatment_protocol_ch1` e `growth_protocol_ch1` presi da GEO; (2) donatori diversi nei confronti malati contro
sani = avviso; (3) non detto e casi incerti = avviso; (4) `ALTRA_DIFFERENZA` = errore. Le decisioni 2-4
coincidono con la tabella proposta: dal commit `efa44ac` il codice della regola è cambiato solo nei commenti, e il
test «la tabella degli esiti riporta le decisioni del PI» la fissa. Cancelli e previsioni della parte 2 sono stati
depositati prima di scaricare qualunque testo[^prev2].

**Lo scaricamento.** Una richiesta per studio (`acc.cgi?acc=<GSE>&targ=gsm&form=text&view=brief`), testo
grezzo salvato byte per byte, manifesto con URL, data UTC, byte e SHA-256. 993 studi in 2.435 s, un solo
processo, pausa di 0,4 s; tre studi hanno fallito il primo tentativo (due letture interrotte, `IncompleteRead`,
e una rete irraggiungibile) e sono riusciti al secondo[^scar]. Una lettura interrotta solleva un errore e non
salva nulla. Testi in
`analysis/p4-output/S12-geo-campioni-20261108/` (155 MB, fuori da git), copia verificata in
`/mnt/micron/simulomicsr-salvataggio/S12-geo-campioni-20261108/`. L'estrazione unisce più righe dello stesso
campo con «,» come l'H5 e copia i valori com'erano; l'unione con l'H5 la fa `.s2b_aggiungi_campi_geo()`.

| # | cancello | esito | fonte |
|---|---|---|---|
| G1 | GEO ha risposto per 993 studi su 993 | **passa** | `26-out.txt`[^scar] |
| G2 | ogni campione dei bracci ha il suo blocco GEO | **fallisce come scritto: 15.557 su 15.559.** I 2 mancanti (GSM7061582, GSM7061583) sono stati cancellati dallo staff di GEO il 12 ottobre 2024; la pagina di GEO che lo dice è salvata. Nessun campione è senza testo e senza prova di cancellazione | `27-out.txt`[^estr], `27-cancellati-da-geo.json`[^canc] |
| G3 | controllo positivo: sui 40 studi del 2026-11-07, «presente» e «cambia» dei tre campi uguali a `24-out.txt` | **passa**: 40 studi, 0 differenze | `27-out.txt`[^estr] |
| G4 | ogni valore di ogni campo (H5 e GEO) sta per intero nell'ingresso | **passa**: 1.903 su 1.903 | `28-out.txt`[^ingr2] |
| G5 | test verdi; nessun accession in prompt, schema e test | **passa**: 242 asserzioni (58 ingresso, 169 regola, 15 schema), 0 fallimenti; `grep` vuoto | `testthat`, `grep` |
| R0 | (non depositato; regola 4 della skill) con i soli campi H5 l'ingresso si ricostruisce identico a quello della prima parte | **passa**: 1.903 su 1.903 | `28-out.txt`[^ingr2] |

| # | quantità | atteso | intervallo di rilevanza | risultato | giudizio |
|---|---|---|---|---|---|
| P7 | confronti oltre 26.624 token | 1-4 | 0-19 | **1** (lo stesso della prima parte, 117 campioni, 40.081 token stimati) | **confermata** |
| P8 | mediana dei token per confronto | 3.700-5.500 | sopra 10.000 | **3.920** (99° percentile 7.977) | **confermata** |
| P9 | studi in cui la descrizione cambia fra i campioni dei bracci | 55% | 40%-70% | **419 su 993, 42,2%** (conteggio su tutti gli studi) | **confermata**, vicino all'estremo basso; la frase del primo riassunto «in più di metà degli studi» era sbagliata ed è corretta |
| P10 | campioni con il titolo GEO uguale al titolo H5 | ≥ 99% | 98%-100% | **15.557 su 15.557** che GEO ha ancora | **confermata** |

Tutti i conteggi coprono l'intera popolazione (993 studi, 15.559 campioni, 1.903 confronti): nessun intervallo di
confidenza.

**I due campioni cancellati da GEO.** Stanno nello studio GSE226005; nell'H5 hanno titolo
«IMR90_Control2_rep1/2(RNA-seq)» e caratteristiche «treatment: None». Formano tutto il braccio di controllo di 2
confronti su 1.903 (`GSE226005__GSE226005__Hypoxia_vs_Vehicle__1`, `…Hypoxia_rep_vs_Vehicle__1`, gruppo
`cgroup_L5_83f57274`). GEO oggi elenca 12 campioni dello studio, e i due non ci sono. Non ho giudicato i due
confronti (la prova è cieca). L'ingresso scrive per i tre campi GEO di questi campioni «(not available: sample
deleted from GEO)», e il prompt dice al modello che questo valore non descrive l'esperimento. Se resta nella
pipeline un campione che GEO ha cancellato l'ha deciso il PI il 2026-11-08: **no**, il ricalcolo finale lo toglie.

**Che cosa mostra la misura**[^ingr2]. Sui 15.557 campioni che GEO ha ancora: `description` in 7.505 campioni e
513 studi; `treatment_protocol_ch1` in 8.697 campioni e 666 studi; `growth_protocol_ch1` in 8.275 campioni e 675
studi. La descrizione è assente in 882 confronti, comune ai due bracci in 202, scritta una volta per braccio in
90, scritta per campione in 729. La riparazione della codifica non cambia nessuna stringa GEO, e nessun ingresso
conserva il marcatore di codifica doppia. I token crescono in mediana di 281 per confronto; il prompt di sistema
passa da 2.811 a 2.940 token; la somma sui 1.903 è 8.120.345 (circa 24 milioni per tre modelli).

**Che cosa la misura vede e che cosa non vede.** Il titolo uguale in tutti i 15.557 campioni dice che GEO non ha
riscritto i titoli dopo la copia di ARCHS4. Non dice se la descrizione o i protocolli sono cambiati senza il
titolo: l'H5 non ha questi campi, quindi la data della versione letta è quella dello scaricamento (2026-11-08).

**Tre correzioni in corsa**, prima di scrivere: (1) la prima estrazione toglieva gli spazi ai bordi con
`str.strip()` di Python, che toglie anche lo spazio non separabile U+00A0; 23 titoli di uno studio risultavano
diversi dall'H5 per questo solo carattere. Ora l'estrattore copia il valore com'è, e l'unica normalizzazione è
quella dell'ingresso: P10 passa da 23 titoli diversi a 0. (2) I conteggi di presenza contavano il valore «not
available» dei due campioni cancellati come testo; ora li escludono. (3) Lo script di scaricamento rifiutava la
pagina di cancellazione; ora la salva come prova (`26-out-ripresa.txt`, solo i due campioni).

**Dubbi della parte 2**

| dubbio | come si chiude |
|---|---|
| G2 fallito come scritto | **spiegato** (GEO ha cancellato i 2 campioni; pagina salvata) e **corretto** nell'ingresso (valore «not available», `.s2b_aggiungi_campi_geo()` con test: un campione senza testo e senza prova ferma il calcolo) |
| un campione cancellato da GEO resta nella pipeline? | **deciso** dal PI il 2026-11-08: no, il ricalcolo finale (S13) toglie ogni campione cancellato da GEO; la prova S12p tiene i 2 confronti |
| il testo GEO per tutti gli studi candidati del ricalcolo finale | **rinviato** a S13 (sotto) |
| spazio non separabile tolto dall'estrattore | **corretto** |

**Rinvio a S13: il testo GEO di tutti i candidati.** Che cosa: scaricare e congelare il testo GEO di tutti gli
studi candidati con `26-scarica-geo.py` e `27-estrai-campi-geo.py`, unire con `.s2b_aggiungi_campi_geo()`,
elencare i campioni cancellati da GEO e toglierli (decisione del PI, 2026-11-08). Perché: lo Stadio 2b in
produzione deve leggere gli stessi campi della prova. Che cosa serve: il numero degli studi candidati, dichiarato
prima; il tempo misurato qui è 2,5 s per studio (2.435 s per 993 studi), con un solo processo. Il 2026-11-08 le
pagine HTML di GEO hanno mostrato un controllo reCAPTCHA, mentre il formato testo ha risposto: il lancio deve
poter riprendere da dove si ferma, come qui.

# Da dove vengono i numeri del riassunto

| frase del riassunto | file | valore letto |
|---|---|---|
| i 1.903 confronti del deliverable | `20-out.txt`, cancello C2 | «1903 confronti, 194 gruppi» |
| 2 campioni su 15.559 senza testo GEO | `27-out.txt`, riga G2 | «15557 campioni su 15559 con il loro blocco; cancellati da GEO 2» |
| cancellati il 12 ottobre 2024 | `27-cancellati-da-geo.json` | «Oct 12, 2024» (due voci) |
| tutto il controllo di 2 confronti su 1.903, studio sull'ipossia | `28-out.txt`, riga «confronti con un campione cancellato»; `20-ingressi-1903.jsonl.gz`, campi `gsm_c` e `n_c` | «2 GSE226005__…Hypoxia_vs_Vehicle__1 …Hypoxia_rep_vs_Vehicle__1»; `n_c` = 2, `gsm_c` = i due campioni |
| le quattro risposte coincidono con la tabella, nessun esito cambiato | `git diff efa44ac -- R/stage2b-rule.R` (solo righe di commento); `test-stage2b-rule.R`, test «la tabella degli esiti riporta le decisioni del PI» | nessuna riga di codice cambiata; test verde |
| i testi di tutti i 993 studi | `26-out.txt`, riga FINE | «studi 993» |
| titolo uguale in tutti i 15.557 campioni che GEO ha ancora | `28-out.txt`, riga P10 | «15557 su 15557» |
| la descrizione cambia in 4 studi su 10; esiste in 513, cambia in 419 | `28-out.txt`, righe P9 | «419 su 993 (42.2%)»; «description presente in 513 studi» |
| la stima su 40 studi diceva più di metà | `24-out.txt`, ultime righe | «cambia ... in 22 studi» su 40 |
| la legge campione per campione in 729 confronti | `28-out.txt`, tabella «modo» | «per campione 729» |
| 1.902 confronti su 1.903 nel limite | `28-out.txt`, riga P7 | «1 su 1903» |
| la mediana sale da circa 3.600 a 3.920 token | `20-out.txt`, riga P3; `28-out.txt`, riga P8 | «mediana 3603»; «mediana 3920» |
| i 193 difetti della prova | `00-previsioni.md`, P4 | 193 |
| 41 minuti, un processo, pausa di 0,4 secondi | `26-out.txt`, riga FINE; `26-scarica-geo.py`, `PAUSA` | «durata 2435 s»; `PAUSA = 0.4` |

[^spec]: `docs/superpowers/specs/2026-11-07-stadio-2b-design.md`
[^ingr]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/20-out.txt`
[^taglio]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/21-out.txt`
[^geo]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/22-out.txt`
[^codifica]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/23-out.txt`
[^assenti]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/24-out.txt`
[^sha]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/90-sha256.txt`
[^prev2]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/00-previsioni-parte2.md`
[^scar]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/26-out.txt`, `26-out-ripresa.txt`, `26-manifesto-testi-geo.tsv`
[^estr]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/27-out.txt`
[^canc]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/27-cancellati-da-geo.json`
[^ingr2]: `analysis/audit/2026-11-07-S12-stadio2b-disegno/28-out.txt`
