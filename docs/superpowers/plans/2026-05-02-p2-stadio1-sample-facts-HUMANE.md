# P2 — Stadio 1 sample_facts (versione leggibile)

Companion al plan dettagliato `2026-05-02-p2-stadio1-sample-facts-plan.md`.
Qui solo cosa ti riguarda: cosa otterrai, dove devi decidere, dove la sessione si fermerà ad aspettarti.

## Cosa è P2 in una frase

P1 ha consegnato l'**infrastruttura** (client OpenAI, cache, validazione). P2 le mette sopra il **primo cervello vero**: prendere la stringa di metadati GEO di un sample e produrre un record JSON strutturato (lo `sample_facts.stage1.v3` della spec v5 §3) — tipo cellulare, perturbazione, dose, tempo, ambiguità — già validato contro lo schema strict.

## Cosa otterrai a fine P2

- `inst/schemas/sample_facts.stage1.v3.json` — lo schema completo della spec v5 §3, scritto in modo che OpenAI Structured Outputs lo accetti in modalità strict (zero risposte malformate ammesse).
- `classify_sample()` — una funzione (esportata) che dato un sample lo classifica via LLM, validato contro lo schema, con cache su disco. È il punto d'ingresso per usare lo Stadio 1 sia da R interattivo che dalla pipeline.
- Pipeline `analysis/_targets.R` con i primi target reali: lettura del xlsx → costruzione di un **dev set di 100 sample stratificati 60/30/10** → classificazione di tutti e 100 → partition validati/invalidi → metriche di eval → report HTML.
- Vignette `stage1-classify.Rmd` con esempio.
- Suite di test (~25 nuovi expectations) + smoke E2E reale gated su `OPENAI_API_KEY`.

A fine P2 sai: lo schema regge sui sample reali, il prompt non collassa, le metriche di base ti dicono se vale la pena passare a P3 (Stadio 2 + run più ampio).

## Quello su cui devi decidere

### Adesso, prima di lanciare l'esecuzione

**1. Modello di default = `gpt-5.5`.** La spec §5.3.1 dice "Sviluppo iniziale: usa il modello più capace anche per Stadio 1 nei primi 100-200 sample del dev set, per non confondere errori di schema con limiti del modello piccolo". Quindi P2 default è `gpt-5.5`. Lo switch a `gpt-5.4-mini` (più economico, per il run massivo) è una decisione di P3 quando il prompt sarà stabile. Vuoi confermare `gpt-5.5` o partiamo con un modello diverso?

**2. Costo del run su 100 sample.** Stima molto larga (system prompt ~2500 token, user ~200, output ~600, gpt-5.5 retail): **~$0.5-2.0 totale** per i 100 sample. Trascurabile rispetto al tetto $500 (resta tutto disponibile per P3). Se preferisci limitarti a 25-50 sample il primo giro, lo dimezziamo facilmente.

**3. Dove vivono i sample del dev set.** La pipeline legge da `data-raw/relevant_sample_classified.xlsx` (130k righe) e ne campiona 100 con seed deterministico **1812** (scelto dall'utente). Cambiare il seed cambia il dev set.

### Più avanti, quando arriverà il momento

**4. Soglie di accettabilità.** A fine Task 11 leggiamo `eval_stage1_metrics`. Soglie attese:
- `validity_rate > 0.95` (con Structured Outputs strict dovrebbe essere ~1.0; se scende, è un bug nello schema o un sample fuori scope);
- `recall_perturbation > 0.7` sul mix 60/30/10 (gli "easy" hanno quasi sempre una perturbazione, i "short_ambiguous" no);
- `recall_cell_type > 0.85`.

Se siamo sopra le soglie, P2 chiude e si parte con P3. Se siamo sotto, c'è un giro di iterazione sul prompt/schema (è il pattern dei 4 dry-run di v5 — replicato qui in piccolo).

**5. Gold "design-aware".** Continua a essere rinviato a P3 mid-stage. P2 misura recall/validity sui 100 sample — non `accuracy vs trtctr_EP`, perché la spec §6.2 chiarisce che Stadio 1 produce facts, non binari. La metrica `trtctr_predicted vs trtctr_EP` arriverà solo a Stadio 2 (P3).

**6. Modello per Stadio 1 nel run grande.** Se a fine P2 il dev set funziona con `gpt-5.5`, P3 valuterà il downgrade a `gpt-5.4-mini` (costo/8x circa) per i 700k+ sample ARCHS4 via Batch API. Se sul dev set dovesse essere già marginale con `gpt-5.5`, in P3 si mantiene il modello grande accettando il costo. Lo decideremo quando avrai i numeri sotto gli occhi.

### Decisioni rinviate non bloccanti per P2

- **ADR-0003** — rinome pacchetto (sempre aperto, non blocca).
- **Vocabolari extra** (Cellosaurus, DrugBank, ChEMBL, MeSH, CAS, NCBITaxonomy, MGI) — P2 li ammette nello schema (`id_database` enum), ma il `lookup` deterministico esiste solo per HGNC. P3 o plan separato.
- **Cache cross-modello** — la cache di P1 separa per modello (deviazione consapevole dalla spec §5.4); se P3 vorrà cache cross-modello, sarà ADR dedicato.
- **Batch API OpenAI** — sempre P3 (run massivo).

## Cosa P2 NON fa (per evitare confusione)

- Non scrive il prompt dello **Stadio 2** (study-level, design_role/comparisons): è P3.
- Non calcola il **`comparability_anchor`**: è P3.
- Non scarica i metadati di studio da GEO (`study_title`, `study_summary`): è P3.
- Non gira sui 130k sample completi del xlsx: P2 si limita ai 100 stratificati. Il run "tutto xlsx" è P3.
- Non produce confusion matrix `treated/control` vs gold: la spec dice esplicitamente che Stadio 1 NON produce questo binario.
- Non scarica il dump HGNC completo (`normalize_gene()` resta in fixture mini): plan separato.
- Non usa Anthropic / Claude: solo OpenAI come da P1.

## Stima di tempo

Esecuzione subagent-driven con review tra task, 13 task. Stima realistica: **2-3 ore walltime** se non emergono iterazioni sul prompt; **mezza giornata** se Task 6 (smoke E2E reale) o Task 11 (run su 100 sample) rivelano che il prompt va raffinato — è il caso "buono", perché significa che hai dati nuovi su cui ragionare.

## Dove la sessione si fermerà ad aspettarti

Tre stop espliciti pre-pianificati:

- **Dopo Task 6** (smoke E2E su 1 sample reale): se la chiamata fallisce o lo schema viene rifiutato, mi fermo e ti porto i log. Non procedo finché non capiamo il perché — questo è il primo punto in cui il prompt incontra il modello reale.
- **Dopo Task 8** (dev set costruito): ti mostro la composizione `table(samples_dev_set$stratum)` per conferma.
- **Prima di Task 11.6** (run vero sui 100 sample): ti chiedo "lancio?" — è il punto in cui consumiamo davvero token API. Senza la tua conferma, non procedo.

Per il resto la sessione fila senza interruzioni: tutti gli altri task sono offline (test mockati o validazione schema locale).

## Cosa P2 lascia pronto per P3

- Schema `sample_facts.stage1.v3` provato sui sample reali (non più solo nelle dry-run testuali della spec).
- Prompt `build_prompt_stage1()` con caching automatico OpenAI (system > 1024 token soddisfa la soglia).
- Pipeline `targets` con cache su disco: tutti i 100 sample classificati restano disponibili per la valutazione retroattiva quando aggiungeremo Stadio 2.
- Eval metrics P2 (validity/recall) → estese in P3 con metriche Stadio 2 (agreement con `trtctr_EP`, F1 sul gold design-aware).
- Tag `p2-stage1-complete` su master.
