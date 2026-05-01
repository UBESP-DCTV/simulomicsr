# P1 — Infrastruttura LLM (versione leggibile)

Companion al plan dettagliato `2026-04-29-p1-infrastruttura-llm-plan.md`.
Qui solo cosa ti riguarda: cosa otterrai, dove devi decidere, cosa NON è in P1.

## Cosa è P1 in una frase

Costruisco le **fondamenta tecniche** del classificatore LLM: client API, cache locale e validazione output. Niente classificazione vera ancora — il prompt e lo schema dei sample arrivano in P2.

## Cosa otterrai a fine P1

- Una funzione `llm_call_structured()` che prende un prompt e uno schema JSON, chiama OpenAI in modalità "Structured Outputs" (zero tolleranza per output malformato), e ritorna l'oggetto già parsato e validato.
- Una **cache locale** che evita di pagare due volte la stessa chiamata. Sopravvive a riavvii. Cambiare lo schema invalida automaticamente la cache.
- Una **utility per normalizzare nomi di geni umani** (`VEGF` → `HGNC:12680`, `c-Myc` → `HGNC:7794`...) deterministica, senza rischio di allucinazioni.
- Una **vignette di esempio** (manuale utente embrionale) che mostra come si chiama il client.
- Test automatici, smoke test reale contro OpenAI gated dietro la chiave.

A questo punto P2 può partire scrivendo prompt/schema reali sopra una base che funziona.

## Quello su cui devi decidere

### Adesso, prima di lanciare l'esecuzione

**1. OpenAI API key.** Mi serve in `.Renviron.local` (file gitignored, mai committato). Hai la chiave dell'account università? Eventuale tetto di spesa? Per P1 il consumo è pochi centesimi (1 sola chiamata smoke + qualche test di ripetizione manuale).

**2. Modello per il test E2E.** Default che ho messo: `gpt-5.4-mini`. Se non è abilitato sul tuo account, fallback a `gpt-4o-mini` (è solo un test infrastrutturale, non c'è ancora classificazione vera). Vuoi confermare uno dei due, o vuoi che provi prima e ti dico cosa risponde l'API?

**3. Dump HGNC completo.** P1 include una fixture mini (10 geni) per i test. Per usare `normalize_gene()` su input reale serve il dump completo (~10 MB) — lo scarichi tu manualmente da genenames.org una volta, oppure lo automatizziamo in un mini-plan separato (`PX-vocabolari`)? Suggerimento: aspettiamo P2, lo automatizzo lì insieme agli altri vocabolari (Cellosaurus, DrugBank, MeSH...) che dovremo aggiungere comunque.

### Più avanti, quando arriverà il momento

**4. Strategia smoke test → dry-run reali.** P1 valida solo che l'infrastruttura funzioni con una domanda finta ("capitale d'Italia"). Il primo dry-run su sample reali parte in P2. Lì rivedrai prompt e schema iterativamente come hai fatto in spec v5.

**5. Modello per Stadio 1 vs Stadio 2.** La spec dice `gpt-5.4-mini` per Stadio 1 e `gpt-5.5` per Stadio 2. La scelta finale (e il benchmark di costo/qualità) è una decisione di P2-P3, non di P1. Eventualmente apriremo un ADR-modelli dedicato.

**6. Gold "design-aware".** La spec §6.2 e §9.8 dicono che il `trtctr_EP` del xlsx misura una semantica diversa da quella che produrremo. Quando avrai visto i primi risultati in P3 ("a buon punto"), dovrai decidere se costruire il gold design-aware su 200-300 sample, o accettare il proxy `design_role → trtctr` come valutazione di non-regressione.

### Promemoria operativo: Batch API OpenAI

Tu vuoi usare il **Batch API** (sconto 50%, latenza fino a 24h). Confermato: lo aggiungerò in P3, non in P1, perché:

- in P1 c'è 1 sola chiamata vera (smoke test) — batch sarebbe overhead
- in P2 sul dev set 100-200 sample — real-time conviene per iterazione rapida sul prompt
- in P3 sul run massivo 700k sample ARCHS4 — qui il batch diventa essenziale e dentro il tuo tetto di **$500** ci sta (Stadio 1 batch: ~$300-700 stimati). Senza batch dovremmo sotto-campionare.

L'API batch è asincrona (file in upload, poll stato, scarica risultato): la implementerò come funzioni dedicate `llm_batch_submit()` + `llm_batch_collect()` in P3, separate da `llm_call_structured()` che resta solo real-time.

### Decisioni rinviate non bloccanti per P1

- **ADR-0003** — rinominare il pacchetto. "simulomicsr" non riflette la pipeline reale. Da affrontare quando vuoi (più semplice farlo prima del primo `install_github` pubblico).
- **ADR-0005?** — Docker. Non discusso finora. Vale la pena considerarlo solo se userai macchine cloud per il run massivo ARCHS4. Per il workflow locale `renv` basta. Possiamo ragionarci a P3.

## Quello che P1 NON fa (per evitare confusione)

- ❌ Non scrive il prompt del classificatore Stadio 1 (è P2)
- ❌ Non implementa il calcolo del `comparability_anchor` (è P3)
- ❌ Non scarica metadati GEO (è P3)
- ❌ Non gira sul xlsx di 130k sample (è P2 sul dev set, P3 a fine pipeline)
- ❌ Non produce confusion matrix vs gold (è P3)
- ❌ Non integra Cellosaurus / DrugBank / ChEMBL / MeSH / CAS / NCBITaxonomy / MGI (plan separato)
- ❌ Non usa Anthropic / Claude (la spec contempla la possibilità in futuro, non in P1)

## Stima di tempo

Una sessione di lavoro completa con un agente fresco per ogni task (8-9 task piccoli): probabilmente 2-3 ore di walltime. Senza interruzioni, esce in mezza giornata. Se qualcosa rompe sull'installazione binaria di pacchetti su macOS aarch64, può richiedere intervento umano (capita su `RSQLite` o `httr2` in casi rari).

## Quando ti chiamerò in causa durante l'esecuzione

Se scelgo l'esecuzione subagent-driven con review tra task, ti faccio uno status a fine di:
- **Task 0** (renv riconciliato + DESCRIPTION aggiornato): ti chiedo conferma prima di committare il lockfile, perché tocca l'ambiente.
- **Task 5** (adapter OpenAI): ti mostro un campione di richiesta/risposta finta, per essere sicuri che il formato è quello che vuoi.
- **Task 7** (smoke E2E reale): è il momento in cui consumiamo la prima chiamata API vera. Ti chiedo "lancio?" prima di farla.
- **Task 8** (vignette + R CMD check): ti faccio vedere l'output di `devtools::check()`. Se ci sono warning li discutiamo.

Per il resto fila liscio senza interrompere.
