# Stadio 2b — il disegno (spec)

**Data:** 2026-11-07 · **Sessione:** S12 · **Decisione:** ADR-0028 (`docs/decisions/0028-stadio-2b-giudice-di-confrontabilita.md`)
· **Stato:** proposta; la tabella degli esiti (§5) attende la decisione del PI · **Finding:**
`docs/findings/2026-11-07-S12-stadio2b-disegno.md` · **Evidenza:** `analysis/audit/2026-11-07-S12-stadio2b-disegno/`

## 1. Che cosa fa lo Stadio 2b

Per ogni confronto candidato (un braccio trattato e un braccio di controllo dello stesso studio, come li ha
definiti lo Stadio 2) il modello del progetto legge il testo grezzo dei campioni dei due bracci e compila una
lista di controllo strutturata. Il modello riporta fatti, con citazioni. Una regola deterministica, codice di
pacchetto con test, decide dalla lista se il confronto passa. Il modello non dà il verdetto.

| pezzo | file |
|---|---|
| schema della lista di controllo | `inst/schemas/comparison_check.stage2b.v1.json` |
| prompt di sistema | `inst/prompts/stage2b-v1.md` |
| ingresso e prompt | `R/stage2b-input.R` (`.s2b_costruisci_ingresso()`, `build_prompt_stage2b()`) |
| regola | `R/stage2b-rule.R` (`.s2b_segnali()`, `stage2b_esiti_default()`, `stage2b_decide()`) |
| test | `tests/testthat/test-stage2b-{rule,input,schema}.R`, `helper-stage2b.R` |

## 2. L'ingresso

**Fonte.** L'H5 di ARCHS4 v2.5 (`analysis/input/human_gene_v2.5.h5`, gruppo `meta/samples`), il dato fisso
della pipeline. Campi, per ogni campione dei due bracci: `title`, `source_name_ch1`, `characteristics_ch1`,
`extract_protocol_ch1`, `data_processing`, `molecule_ch1`, `library_selection`, `library_source`,
`library_strategy`, `instrument_model`, `platform_id`.

**In testa:** le etichette dei due bracci scritte dallo Stadio 2 e l'**entità proposta**, cioè il nome che la
pipeline assegna al confronto (mai un ID). Nella prova S12p è `contrast_entity_label` del gruppo nel
deliverable (non `canonical_name`, che è sbagliato in 61 gruppi su 194). In produzione (S13) è il nome
dell'entità della chiave dello Stadio 3 del record; S12c decide come si sceglie (per indice fra candidati).
Se manca, l'ingresso scrive «not given» e la regola salta i controlli sull'entità.

**Formato, senza tagli.** Un campo con lo stesso valore in tutti i campioni dei due bracci si scrive una volta
in un blocco comune. Un campo uguale dentro un braccio si scrive una volta per braccio. Un campo che cambia
dentro un braccio si scrive per campione, con la sigla T1…Tn o C1…Cm (campioni in ordine di accession; gli
accession non si scrivono). Valore vuoto in alcuni campioni: «(empty)»; vuoto in tutti: il campo non si scrive.

**Due sole trasformazioni.** (1) Riparazione della codifica: parte dei testi dell'H5 è UTF-8 codificato due o
tre volte («Î²» per «β», «Â°C» per «°C»). La riparazione riporta ogni carattere al suo byte Latin-1 e rilegge
i byte come UTF-8, finché il testo cambia (al massimo tre passi), solo se il risultato è UTF-8 valido.
Verificata contro GEO in rete (§ finding). (2) Spazi: a capo e spazi multipli diventano uno spazio. Così ogni
citazione del modello si verifica come sottostringa dell'ingresso.

**Limite di lunghezza.** Contesto 32.768 token, 6.144 riservati alla risposta: 26.624 token per prompt di
sistema e ingresso. Stima: caratteri / 3; la prova S12p misura il rapporto vero sullo smoke. Un confronto oltre
il limite **non si taglia e non si manda al modello**: la regola lo scarta con `INGRESSO_INCOMPLETO`.

**Che cosa l'ingresso non contiene.** L'H5 non ha `description`, `treatment_protocol_ch1`,
`growth_protocol_ch1`, `label_ch1` dei campioni, né titolo, riassunto e disegno della serie. Su 40 studi
scelti a caso fra i 993 dei 1.903 confronti, `description` esiste in 24 studi e cambia fra i campioni in 22
(donatori, sesso, età, trattamento, tempo); i due protocolli esistono in 25 studi e sono uguali in tutti i
campioni dello studio. Se aggiungerli è una decisione del PI (finding, decisione 1).

## 3. La lista di controllo (schema `comparison_check.stage2b.v1`)

| voce | contenuto | valori |
|---|---|---|
| `agents[]` | ogni perturbazione applicata a un campione di uno dei due bracci, veicoli e controlli negativi compresi; una voce per agente | `kind`: chemical, biologic, genetic, infection, physical, vehicle_or_mock, other · `in_treated`, `in_control`: all, some, none, not_stated · `is_proposed_entity`: yes, no, unclear, not_given · `evidence` |
| `collection_time` | per braccio: tempo dall'inizio della perturbazione alla raccolta; ore distinte; tempo zero | `hours[]`, `time_zero`: all, some, none, not_stated · `relation`: same, different, partial, not_stated |
| `axes` (11) | `material`, `cell_line`, `donor`, `genotype`, `sex`, `age_or_stage`, `anatomical_site`, `compartment`, `disease_or_condition`, `culture_conditions`, `technique` | `relation`: same (uguale), different (diverso: nessun valore in comune), partial (parziale: valori in comune ma insiemi diversi), not_stated (non detto), not_applicable (non applicabile) · valore e citazione per braccio |
| `other_differences[]` | ogni altra differenza sistematica fra i bracci (voce aperta, per la coda di casi unici) | descrizione e citazioni |
| `proposed_entity` | la differenza fra i bracci è l'entità proposta? | yes, no, unclear, not_given · citazione |
| `isolated_difference` | che cosa distingue il trattato dal controllo, per nome | nome · agent, disease_or_condition, other, none |

Le voci vengono da ADR-0028 (agenti per braccio, tempo e tempo zero, materiale, linea, donatore, genotipo,
sesso, età, compartimento, tecnica) più tre: sede anatomica, condizione d'origine (serve ai confronti malattia
contro sani) e condizioni di coltura. Le condizioni dei donatori prima del prelievo (malattia, infezione del
paziente, fumo, terapia ricevuta) non sono agenti: vanno sull'asse `disease_or_condition`.

**Compatibilità con lo structured output di vLLM.** Lo schema usa solo `type`, `enum`, `properties`,
`required`, `additionalProperties`, `items`; niente `$ref`, `pattern`, `oneOf`, limiti di lunghezza (test).

## 4. La regola, passo 1: i segnali

`.s2b_segnali()` legge la lista e accende codici. Definizioni: un agente «non veicolo» ha `kind` diverso da
`vehicle_or_mock`; «solo nel trattato» vuol dire `in_treated = all` e `in_control = none`; «solo nel trattato,
debole» ammette anche `in_control = not_stated`.

| segnale | quando |
|---|---|
| `INGRESSO_INCOMPLETO` | l'ingresso supera il limite di token |
| `LISTA_NON_VALIDA` | la lista manca o ha valori fuori schema (dopo la cascata di recupero) |
| `TEMPO_ZERO` | il controllo ha `time_zero` all o some e il trattato non ha all |
| `TEMPO_DIVERSO` | ore dei due bracci note e diverse; o `relation` different/partial; o trattato a tempo zero e controllo no |
| `TEMPO_NON_DETTO` | un braccio senza ore e con tempo zero non detto |
| `TEMPI_MULTIPLI` | più tempi per braccio, uguali nei due bracci |
| `SECONDO_AGENTE` | almeno due agenti non veicolo solo nel trattato, e almeno uno non è l'entità proposta (o entità non data) |
| `AGENTE_NON_DETTO_CONTROLLO` | un agente non veicolo, non l'entità, è nel trattato e non detto nel controllo, accanto a un altro agente del trattato |
| `AGENTE_SOLO_CONTROLLO` | un agente non veicolo è nel controllo e non nel trattato |
| `BRACCIO_MISTO` | un agente non veicolo sta solo in una parte di un braccio (`some`) |
| `NESSUNA_DIFFERENZA` | nessun agente solo nel trattato (anche debole) e condizione d'origine non diversa |
| `ENTITA_DIVERSA` / `ENTITA_INCERTA` | `proposed_entity.match` = no / unclear |
| `INCOERENZA_ENTITA` | entità confermata, ma nessun agente solo nel trattato è marcato come entità |
| `CONDIZIONE_CON_AGENTE` | la differenza è un agente e anche la condizione d'origine è diversa |
| `PARZIALE_CONDIZIONE` | condizione d'origine parziale |
| `DONATORI_DIVERSI_CONDIZIONE` | donatori diversi quando la differenza è la condizione d'origine (malattia contro sani) |
| `DIVERSO_<ASSE>` | asse `different` (per il donatore: solo quando la differenza è un agente) |
| `PARZIALE_<ASSE>` | asse `partial` |
| `NON_DETTO_<ASSE>` | asse `not_stated` |
| `TECNICA_H5_DISGIUNTA` / `TECNICA_H5_PARZIALE` | un campo tecnico strutturato dell'H5 (`instrument_model`, `platform_id`, `library_selection`, `library_source`, `library_strategy`, `molecule_ch1`) senza valori in comune fra i bracci / con valori in comune ma insiemi diversi. Calcolato dal codice, senza modello (`.s2b_tecnica_h5()`) |
| `ALTRA_DIFFERENZA` | `other_differences` non vuota |

**Che cosa distingue i bracci** (`stage2b_decide()$differenza`): «agente» se c'è almeno un agente solo nel
trattato (prima quelli con controllo `none`, poi `not_stated`); altrimenti «condizione» se la condizione
d'origine è diversa; altrimenti nessuna (`NESSUNA_DIFFERENZA`). `entita_isolata` dà il nome: l'agente o gli
agenti, o il valore della condizione nel trattato. In S13 questo nome va alla chiave dello Stadio 3 (S12c).

## 5. La regola, passo 2: errore o avviso (proposta, decide il PI)

`stage2b_esiti_default()` assegna a ogni segnale «errore» (il confronto non passa) o «avviso» (passa e si conta).
Un segnale senza esito ferma la regola (errore di classe `simulomicsr_stage2b_esito_mancante`). La decisione
del PI cambia solo questa tabella.

| esito | segnali |
|---|---|
| **errore** | `INGRESSO_INCOMPLETO`, `LISTA_NON_VALIDA`, `TEMPO_ZERO`, `TEMPO_DIVERSO`, `SECONDO_AGENTE`, `AGENTE_SOLO_CONTROLLO`, `BRACCIO_MISTO`, `NESSUNA_DIFFERENZA`, `ENTITA_DIVERSA`, `CONDIZIONE_CON_AGENTE`, `PARZIALE_CONDIZIONE`, tutti i `DIVERSO_<ASSE>`, `PARZIALE_` di materiale, linea, genotipo, sede, compartimento, coltura, tecnica, `TECNICA_H5_DISGIUNTA`, `TECNICA_H5_PARZIALE`, `ALTRA_DIFFERENZA` |
| **avviso** | tutti i `NON_DETTO_<ASSE>` e `TEMPO_NON_DETTO` (ADR-0028), `TEMPI_MULTIPLI`, `AGENTE_NON_DETTO_CONTROLLO`, `ENTITA_INCERTA`, `INCOERENZA_ENTITA`, `DONATORI_DIVERSI_CONDIZIONE`, `PARZIALE_` di donatore, sesso, età |

Da decisioni già prese: tempo zero e differenza tecnica sono sempre errore (PI, S11 §12); una differenza
tecnica in un solo campione è errore (il caso 4sU di S11), quindi anche il parziale tecnico; «non detto»
passa con avviso (ADR-0028).

## 6. Il prompt (`inst/prompts/stage2b-v1.md`)

In inglese, come i prompt degli Stadi 1 e 2. Dice al modello che etichette ed entità proposta possono essere
sbagliate e che giudica solo dal testo; definisce all/some/none/not_stated, i valori degli assi e il tempo zero
con forme generiche («0 h», «day 0», «baseline», «pre-treatment»); chiede citazioni esatte. **Nessun esempio
preso dai 193**: i termini tecnici (paired-end, single-end, kit, 4sU, poly(A)) vengono dalla decisione del PI in
S11 §12, i veicoli (DMSO, PBS, etanolo) sono generici. Il prompt non contiene accession GEO (test).

## 7. Configurazione per la prova S12p

Come l'handout S12p: temperatura 0, `repetition_penalty` 1.1, `VLLM_BATCH_INVARIANT=1`, `max_model_len` 32.768,
`max_tokens` 6.144, structured output sullo schema §3. Un'uscita che non passa `validate_json()` con lo schema
va alla cascata di recupero dello Stadio 2 (`repetition_penalty` 1.2 → 1.3 → 1.4); se resta non valida, la
regola dà `LISTA_NON_VALIDA` e il conto la riporta a parte. Ingresso congelato:
`analysis/audit/2026-11-07-S12-stadio2b-disegno/20-ingressi-1903.jsonl.gz` (SHA-256 in `90-sha256.txt`).
Per la tecnica dell'H5 la prova usa `20-campi-h5-campioni.rds`.

**Che cosa conta la prova** (previsioni P4-P6 in `00-previsioni.md`): difetti presi su 193, puliti accusati su
1.710, per modello, con intervallo di Wilson; segnali per categoria; quota di `not_stated` sui 11 × 1.903 assi;
quota di citazioni trovate per intero nell'ingresso (diagnostica, non decide).

## 8. Limiti noti del disegno

- **Cecità per esempi, non per categorie.** Le voci della lista vengono da ADR-0028, che le ha ricavate dalle
  categorie dei 193. La prova S12p è cieca sugli esempi (il prompt non ne usa) ma non sulle categorie: misura
  quanto il modello vede le classi note. La voce aperta `other_differences` e la rilettura cieca di S15 misurano
  la coda.
- **Campi GEO assenti dall'H5** (§2), salvo decisione del PI.
- **Un confronto oltre il limite** di lunghezza su 1.903 (117 campioni): scartato, non tagliato.
- **La regola si fida dei fatti del modello.** Le citazioni si verificano come sottostringhe, ma la v1 non
  scarta un confronto per una citazione non trovata: il dato serve a misurare l'affidabilità del modello.
