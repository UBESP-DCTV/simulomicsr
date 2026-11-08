# S12p, quinta parte — dove nascono i 473 difetti: cancelli e previsioni

**Depositate:** 2026-11-08, prima di ogni calcolo di questa parte.
**Richiesta del PI (2026-11-08):** «fai la diagnosi». Prima: «bisogna trovare un modo per non farlo sbagliare A MONTE»;
«stai cercando di mettere una pezza stravolgendo lo studio». Questa parte è una **diagnosi**: non propone correzioni,
non cambia prompt, regole o codice della pipeline, non tocca deliverable e master.

**Domanda.** Per ogni confronto difettoso: qual è l'ultimo passo della pipeline che **aveva** l'informazione che rende
i due bracci non confrontabili? Il difetto nasce nel passo dopo, quello che l'ha persa o non l'ha usata.

## La catena (verificata nel codice prima di scrivere)

| passo | che cosa riceve | che cosa produce | dove |
|---|---|---|---|
| P0 · ingresso dello Stadio 1 | per campione: `title`, `source`, `characteristics` di ARCHS4; **non** `description`, protocolli, campi tecnici | — | `analysis/input/archs4-human-stage1-input-v2.jsonl` (campo `string`) |
| P1 · Stadio 1 (modello) | il testo di un campione | i fatti del campione (`sample_facts.stage1.v3`) | master `A3-stage1-master-innestato.jsonl` |
| P2 · codice: condizioni | i fatti di tutti i campioni dello studio | i campioni con la **stessa firma di disegno** diventano una condizione; la firma **esclude** donatore, età, sesso, ascendenza, passaggio, trattamenti tecnici, candidato Cellosaurus | `R/stage2-design-signature.R`, `.build_study_conditions()` |
| P3 · Stadio 2 (modello) | **solo** i fatti di un rappresentante per condizione (+ `n_replicates`, `condition_id`); `study_summary` vuoto in 2.728 ingressi su 2.728 | gruppi (unioni di condizioni) e confronti (coppie di gruppi) | `prompts.py::render_user_message_stage2`, ingresso `analysis/input/A3-stage2-subset.jsonl` |
| P4 · codice: fusione dei pezzi ed espansione | i disegni dei pezzi | i gruppi con tutti i campioni | `R/stage2-expand.R` |
| P5 · Stadio 3 (codice) | un confronto dello Stadio 2 = un record | cancello del contrasto, chiave dell'entità | `R/stage3-build.R::.build_contrast_group_records` |

## Oggetti

- **Confronti:** i 1.903 di `analysis/audit/2026-08-20-rilettura-194/dispatch-A3.rds` (`$tenuti`), dal deliverable
  `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`.
- **Difettosi:** 473 = i 193 di `analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv` più i
  280 di `94-difetti-finali.csv`. **Puliti:** 1.430.
- **Master e ingressi letti:** `analysis/p4-output/A3-stage1-master-innestato.jsonl`, `A3-stage2-master-innestato.jsonl`,
  `analysis/input/A3-stage2-subset.jsonl` (+ `A3-stage2-rescue.jsonl`); misura secondaria su
  `analysis/p4-output/S14-stage2-master.jsonl`.
- **Ingresso dello Stadio 1, confronto per chiavi:** le chiavi di `characteristics` e `source_name` già calcolate in
  `100-senza-modello.csv` (colonne `accuse` e `chiavi_mescolate`; le regole stanno in `00-previsioni-monte.md` §A).
  Dichiarato: quei numeri aggregati sono già noti (A1, A3 della quarta parte). Il `title` non si confronta: è diverso
  in ogni campione.
- **Tipo di entità:** `kind_effective_resolved` da `deliverable-annotato.rds` del deliverable (sbaglia in parte dei casi,
  finding S6).

## Il tipo del difetto e le famiglie di campi

**Tipo.** Per i 280: le parole di `tipi2` (seconda lettura). Per i 193: la `categoria` di S11 con queste regole, in
minuscolo; una categoria può avere più tipi; vale ogni regola che trova:

| tipo | la categoria contiene |
|---|---|
| tempo_zero | «tempo zero», «controllo a tempo zero» |
| tempo_diverso | «tempo», «durata», «fase» |
| secondo_agente | «secondo agente», «secondo intervento», «secondo fattore», «combinazione», «due agenti», «esposizione farmacologica» |
| agente_nel_controllo | «entita' nel controllo» |
| entita_diversa | «entita'» (non «entita' nel controllo») |
| materiale_o_sede | «sede», «materiale», «compartimento», «comparto», «tessuto», «frazione», «vescicole», «sferoidi», «linea», «clone», «pdx», «xenotrapianto», «modello» |
| soggetti | «donatore», «sesso», «etnia», «eta'» |
| genotipo | «genotipo», «genetic», «stato genetico» |
| coltura | «stato cellulare», «differenziamento», «coltura», «passaggio» |
| tecnica | «tecnica» |
| braccio_misto | «braccio misto» |
| altro | nessuna delle regole sopra |

**Famiglie di campi dello Stadio 1** (F = nella firma, X = escluso dalla firma):

| famiglia | tipi | campi |
|---|---|---|
| materiale | materiale_o_sede | `tissue` F, `tissue_segment` F, `cell_type_or_line_raw` F, `context_kind` F, `subcellular_fraction.kind` F, `sort_markers` F; `cell_line_cellosaurus_candidate` X, `cell_composition_estimates` X, `host_organism` X |
| coltura | coltura | `cell_state` F, `developmental_stage` F, `co_culture_partners` F, `context_kind` F; `passage_or_state` X |
| genotipo | genotipo | `engineered_modifications` F; `cell_line_cellosaurus_candidate` X |
| soggetti | soggetti | `disease_state.*` F, `patient_metadata.{condition, clinical_response, stage, survival_group}` F; `patient_metadata.{donor_id, age, sex, ancestry_or_population, ancestry_admixture}` X |
| tempo | tempo_zero, tempo_diverso | durata delle perturbazioni (`value_hours`, altrimenti `value_raw`) F, `is_zero_timepoint` F, `phase` F, `patient_metadata.visit_or_timepoint` F; `temporal_order` X |
| agente | secondo_agente, agente_nel_controllo | agenti attivi (`agent_raw` delle perturbazioni con `kind` diverso da `none`, `vehicle_only`, `unclear` e `is_negative_control` non vero) F; `technical_treatments` X |
| tecnica | tecnica | `technical_treatments` X (gli altri campi tecnici non entrano nello Stadio 1) |

`altro` e `braccio_misto` usano tutte le famiglie. `entita_diversa` non usa famiglie: vedi classe E.

**Chiavi dell'ingresso per famiglia** (classe C), sul nome della chiave in minuscolo: materiale = `tissue|organ|site|source_name|cell type|cell line|cell_type|material|fraction|compartment|region`;
coltura = `culture|differentiat|passage|medium|state|stage`; genotipo = `genotype|mutation|clone|knock|crispr|variant|allele`;
soggetti = `donor|patient|subject|individual|sex|gender|age|ethnic|race|disease|status|diagnosis`;
tempo = `time|day|hour|hr|week|duration|visit`; agente = `treatment|agent|compound|drug|dose|concentration|stimul|infect`;
tecnica = `batch|lane|run|library|instrument|rin|rna|well|plate|investigative|center|kit`.

**Confronto dei valori.** Valori in minuscolo, spazi compattati, «µ» e «μ» come «u», `na`, `n/a`, `null`, `nan` e vuoto =
non detto. Campo scalare: diverso fra i bracci se entrambi i bracci hanno valori detti e gli insiemi sono diversi;
diverso dentro un braccio se il braccio ha almeno 2 valori detti distinti. Campo lista: si confronta l'insieme intero
di ogni campione, la lista vuota conta come valore. **Tempo:** diverso fra i bracci se un campione del controllo ha
`is_zero_timepoint` vero e nessun campione del trattato lo ha, oppure se gli insiemi delle durate detti nei due bracci
sono diversi, oppure se `visit_or_timepoint` è diverso. **Agente:** diverso fra i bracci se il trattato ha almeno 2
agenti attivi assenti dal controllo, oppure il controllo ha almeno 1 agente attivo assente dal trattato; dentro un
braccio, se gli insiemi degli agenti attivi dei campioni sono diversi.

**Il contrasto stesso non conta** (solo fra i bracci, non dentro un braccio): tipo di entità `disease_vs_normal` → si
ignorano `disease_state.*` e `patient_metadata.{condition, clinical_response, stage, survival_group}`;
`pathogen_or_aggregate_exposure` → si ignora `disease_state.*`; `genetic_*` → si ignora `engineered_modifications`;
`differentiation` → si ignorano `cell_state` e `developmental_stage`.

## Le classi (per tipo; un difetto con più tipi prende la classe più visibile, nell'ordine A, B, C, D)

| classe | definizione | il difetto nasce |
|---|---|---|
| **A · lo Stadio 2 l'ha vista** | la famiglia è diversa fra i **rappresentanti** che lo Stadio 2 ha ricevuto: dentro un braccio (fra le condizioni unite nello stesso gruppo: **A-unione**) o fra i bracci (**A-scelta**). I rappresentanti si confrontano su tutti i loro campi, anche quelli esclusi dalla firma: lo Stadio 2 li riceve interi | nel modello dello Stadio 2, che ha costruito il gruppo o il confronto, e nel cancello dello Stadio 3, che non l'ha fermato |
| **B · lo Stadio 1 l'ha scritta, il codice l'ha nascosta** | non A, ma la famiglia è diversa fra i fatti di **tutti** i campioni (dentro un braccio o fra i bracci) | nella firma di disegno (P2): lo Stadio 2 ha visto un solo rappresentante |
| **C · lo Stadio 1 l'ha letta, non l'ha scritta** | non A né B, ma una chiave dell'ingresso della stessa famiglia è diversa fra i bracci o mescolata dentro un braccio | nel modello dello Stadio 1 |
| **D · nessun passo l'ha letta** | nessuna delle tre | prima dello Stadio 1: l'informazione sta nel titolo, nella descrizione, nei protocolli, nei campi tecnici o nel ragionamento dei lettori |
| **E · nome dell'entità** | il difetto ha solo il tipo `entita_diversa` | nella chiave dell'entità (Stadio 3, sessione S12c); assegnata dal tipo, non misurata |

**Puliti (riferimento di base).** Sui 1.430 puliti si calcolano le stesse classi con **tutte** le famiglie (non hanno un
tipo). Sui difettosi si calcola anche la classe con tutte le famiglie, per il confronto alla pari.

## Cancelli

| # | cancello | se fallisce |
|---|---|---|
| G0 | `analysis/audit/2026-08-21-S2-deliverable-in-salvo/10-manifesto-e-copia.sh verifica` passa (copre deliverable e master A3) | stop |
| G1 | per 1.903 confronti su 1.903, i campioni dei due bracci di `dispatch-A3.rds` sono uguali ai campioni dei due gruppi nel master A3 dello Stadio 2 (studio, `treated_group`, `control_group`) | stop; ogni eccezione si spiega prima di andare avanti |
| G2 | ogni campione dei bracci ha i fatti nel master A3 dello Stadio 1 e una condizione nell'ingresso dello Stadio 2; ogni braccio è un'unione di condizioni intere | stop |
| G3 | la firma ricalcolata con `design_signature()` dai fatti del master è uguale per tutti i campioni di ogni condizione toccata dai bracci | stop: il master non è quello che lo Stadio 2 ha letto |
| G4 | controllo positivo dello strumento: un confronto finto per classe (A-unione, A-scelta, B, C, D) costruito a mano esce nella classe attesa | stop |
| G5 | controllo positivo sui dati: fra i 193 con `fonte = etichetta` e tipo diverso da solo `entita_diversa`, il difetto si vede nelle etichette scritte dallo Stadio 2, che legge solo i fatti dello Stadio 1; quindi la classe con tutte le famiglie deve essere A in **almeno l'80%** | stop: il confronto dei fatti è cieco; si corregge lo strumento e si ridepositano le soglie |

## Previsioni

**Unità:** il confronto. Intervallo di Wilson al 95% per le quote; per le differenze fra difettosi e puliti, bootstrap
per **studio** (i confronti di uno studio condividono i gruppi), B = 2000, seme 20261108. Tutti gli intervalli di
rilevanza sono **giudizi motivati** (nessuna soglia del progetto si applica qui): li dico al PI.

| # | quantità | atteso | intervallo di rilevanza | motivo |
|---|---|---|---|---|
| D1 | difetti in classe A (per tipo), su 473 | 55% | da 50% a 100% | sopra metà, la maggior parte dei difetti nasce dove l'informazione c'era già (Stadio 2 e cancello dello Stadio 3): la ricerca della causa continua lì, non nello Stadio 1 |
| D2 | difetti in A-unione, su 473 | 15% | da 20% a 100% | sopra il 20% l'unione di condizioni diverse in un gruppo è una causa a sé, con un suo punto nella catena |
| D3 | difetti in classe B, su 473 | 8% | da 15% a 100% | sopra il 15% la firma che esclude donatore, età, sesso e passaggio è una causa a sé |
| D4 | difetti in classe C, su 473 | 15% | da 25% a 100% | sopra il 25% una parte grande nasce nel modello dello Stadio 1 |
| D5 | difetti in classe D, su 473 | 15% | da 25% a 100% | sopra il 25% una parte grande sta in campi che nessun passo legge |
| D6 | difetti in classe E, su 473 | 8% | — (conteggio dal tipo) | — |
| D7 | classe A con tutte le famiglie: difettosi meno puliti, in punti percentuali | +20 | da +10 a +100 | sotto +10 la differenza dei fatti si trova quasi altrettanto spesso nei puliti: la classe A non distingue i difetti e D1 non si può leggere come causa |
| D8 | confronti con almeno un braccio fatto di 2 o più condizioni: difettosi meno puliti, in punti | +10 | da +5 a +100 | sotto +5 l'unione di condizioni non distingue i difetti |
| D9 | difetti i cui due bracci (stessi campioni) sono un confronto anche nel master S14 dello Stadio 2, su 473 | 85% | da 80% a 100% | sopra l'80% il re-run S14 riporta gli stessi bracci difettosi nel ricalcolo finale: la causa sta nella catena, non nel run |

**Che cosa questa misura non vede.** La classe dice dove l'informazione **c'era**, non che il passo dopo l'avrebbe
dovuta usare. Le famiglie e le chiavi sono regole sui nomi dei campi: una differenza scritta in un campo di un'altra
famiglia non si vede (per questo la classe con tutte le famiglie). Il tipo dei 193 viene da una regola sul testo della
categoria. Le differenze dei fatti dello Stadio 1 possono essere rumore: D7 e D8 lo misurano sui puliti.
