# LLM anchor ontology override — versione leggibile

Companion al plan dettagliato `2026-05-25-p5-llm-anchor-ontology-override-plan.md`.
Qui solo cosa ti riguarda: cosa otterrai, dove ti devo aspettare per decidere, dove la sessione si fermerà.

## Cosa è in una frase

L'audit di ieri ha trovato che il LLM Mistral classifica male il **kind biologico** (cytokine vs pathogen vs vehicle) e mette spesso l'**ID ChEBI nel campo sbagliato**. Invece di rifare girare il LLM (4-5 giorni di compute), aggiungo un **traduttore downstream** che usa ChEBI/HGNC/MeSH come dizionario per (1) recuperare il nome reale degli agenti e (2) correggere il kind biologico quando ChEBI dice una cosa diversa dal LLM. Ricostruisco Stage 3 → Stage 4 → Layer B sulla base dei dati LLM esistenti (non li ri-genero), e abbiamo un dataset più affidabile per il paper.

## Cosa otterrai a fine

- **Stage 3 v3.1** — un nuovo `clusters.rds` con cluster_id ricalcolati su anchor canonicalizzato. Ogni cluster avrà 6 colonne nuove: `agent_id_llm_original`, `agent_id_resolved`, `resolution_source`, `kind_effective_llm_original`, `kind_effective_resolved`, `kind_overridden`. **Tracciabilità completa**: per ogni override sappiamo cosa diceva il LLM e perché abbiamo deciso di sovrascrivere.
- **Stage 4 v3.1** — Layer A ri-pooled sul nuovo Stage 3. Stessa logica di pooling (dream-based, REML, FDR BH within-cluster). Solo i cluster_id sono diversi (perché l'anchor è cambiato).
- **Layer B v3.1** — nuova shortlist 30-50 candidati + selection 15 case study ri-curata. Le label saranno nomi reali ("Carnitine", "Ethanol", "DMSO") con kind corretto. **I 4 critically wrong** del Layer B precedente (Carnitine-as-pathogen, Ethanol-as-cytokine, dihydroxyphthalic-as-pathogen, Pregnanetriol-as-disease) saranno **risolti automaticamente** o droppati.
- **ADR-0018 Accepted** — la decisione architetturale formalizzata + validation results (numeri reali post-rebuild).
- **L2 paper limitation** quantificata e mitigata. Sappiamo quanto residuo è recuperabile vs non (CHEBI senza roles, MeSH hallucinated puro, stringhe libere) → diventa una sezione paper-grade del Methods/Discussion, non un red flag reviewer.
- **Codice riusabile**: `R/ontology-lookup.R` + le nuove funzioni `R/anchors.R` saranno utili per qualunque downstream LLM-output usage futuro (γ ARCHS4 mouse, modelli diversi).

## Quello su cui dovrai decidere

### Tutto già deciso prima di iniziare

1. **OPZIONE 2 dell'ADR-0018** — decisione presa ieri sera. Continuiamo su questa.
2. **Branch policy** — restiamo su `p5-llm-anchor-classification-audit` (non aprire branch nuovo). Master resta su `p5-stadio4-layer-b-batch-15` finché chiudiamo S5 con merge esplicito.
3. **Approccio TDD** — test-first per ogni nuova funzione (R/ontology-lookup, resolve_agent_canonical, infer_kind_from_ontology). Niente shortcut "lo testo dopo".
4. **Conservativismo override** — preserviamo il LLM original in ogni cluster. Override solo quando ChEBI roles dimostra STRONG evidence OR LLM ha fatto un'asserzione che CONTRADICE le roles disponibili. Vedi spec §4.3 per la decision table esatta.

### Quando dovrò svegliarti per decidere (gate utente)

**Gate S1 → S2** (fine sessione 1, post-smoke):
- Ti mostro l'output del smoke 3-cluster. Vedi se l'override funziona per Ethanol/Carnitine/Pregnanetriol (i casi paradigmatici).
- **Decisione tua**: avanzare al Stage 3 rebuild full o fix qualcosa nel resolver prima.

**Gate S2 → S3** (fine sessione 2, post-Stage 3 rebuild + diff):
- Ti mostro `docs/findings/2026-05-XX-stage3-v31-diff.md` con le stats before/after.
- Numeri chiave da guardare:
  - Quanti cluster sono cambiati cluster_id?
  - Quanti `kind_overridden=TRUE` (=quanti errori LLM correggiamo)?
  - I 4 critically wrong del Layer B come sono ora classificati?
  - Residual unvalidatable rate (target <5-10%)
- **Decisione tua**:
  - Avanzare a Stage 4 full rebuild (costoso: 28h laptop o 4-6h DGX)
  - Oppure aggiustare la decision table del resolver e rilanciare Stage 3
  - **Scelta laptop vs DGX** (questa è importante — vedi sezione tempi sotto)

**Gate S3 → S4** (fine sessione 3, post-Stage 4 rebuild):
- Ti mostro counts pooled + smoke render.
- **Decisione tua**: avanzare a Layer B re-curation.

**Gate S4 → S5** (fine sessione 4, post-Layer B batch):
- Ti mando il nuovo `layer_b_report.html` (33-50 MB).
- **Decisione tua**: review visiva — sono biologicamente sensati i 15 case study? Sostituiamo ancora qualcuno?

**Gate S5** (chiusura):
- Quando dici "OK chiudi", faccio merge in master + tag `p5-anchor-ontology-override-complete`.

### Decisioni rinviate non bloccanti

1. **OPZIONE 4 (Stage 1 prompt fix + full rerun)** — sempre disponibile come miglioramento futuro per dataset diversi (γ mouse) o cleanup post-paper. ADR separato quando/se serve. **NON in scope** di questo lavoro.
2. **Hardcoded mapping stringhe libere** — "Hypoxia" / "siRNA" / "transplantation" non vengono normalizzate (resta `STR:lowercase`). Se Layer B post-rebuild dimostra che è necessario, lo aggiungeremo in iterazione. Vedi spec §9 OQ2.
3. **ChEMBL dictionary** — ~3.617 cluster con ChEMBL ID naked. Senza lookup ChEMBL non possiamo validarli; restano fallback. Possiamo aggiungere ChEMBL lookup in futuro, non bloccante.
4. **Cellosaurus** — cell line IDs (CVCL_*) restano stringhe. Non scaliamo a vocabolario.
5. **Stage 5 meta-analisi (Stadio 5)** — dopo Layer B v3.1 chiuso. Spec separato.
6. **ADR-0003 (rinome pacchetto)** — sempre rinviato, indipendente.

## Cosa il fix NON fa (per evitare confusione)

- **Non re-runna il LLM** (Stage 1 e Stage 2 master restano intatti)
- **Non scaricia automaticamente le ontologie a runtime** — il refresh è esplicito, manuale. Le 3 RDS dictionary sono già pronte sul tuo disco (commit `7a0e20c`)
- **Non aggiunge segmenti nuovi all'anchor v3.1** — restano 13. Cambia solo il *contenuto* del segmento `agent_id` (canonicalizzato) e del segmento `kind_effective` (override quando appropriato)
- **Non risolve i compound LLM-oscuri senza ChEBI roles** (es. CHEBI:17199, CHEBI:17236). Restano flagged "unvalidatable" → paper caveat residuo
- **Non normalizza stringhe libere** (Hypoxia, contact inhibition, ...) → preservate as-is
- **Non cambia Stage 4 logic** (legge cluster_id + anchor_key opaco)
- **Non rebuild Stage 1 o Stage 2 chunked input** (sono master artefatti, immutati)
- **Non tocca il branch master** finché non hai approvato la merge a S5

## Stima di tempo + dove ti aspetto

Wall stimato totale: **1-2 giorni** di lavoro paper-grade, distribuiti su 5 sessioni con gate utente tra le sessioni.

| Sessione | Cosa faccio | Wall | Mi fermo aspettandoti |
|---|---|---:|---|
| **S1** | Resolver + tests + smoke isolato | 4-6h | Sì, gate "smoke OK?" |
| **S2** | Stage 3 rebuild full + diff comparison | 1-3h | Sì, gate "review diff stats" + "DGX o laptop?" |
| **S3** | Stage 4 rebuild full | **4-6h DGX o 28h laptop** | Sì, gate "Stage 4 OK?" |
| **S4** | Layer B re-shortlist + batch rebuild | 30 min | Sì, gate "review HTML report" |
| **S5** | Close (ADR + memorie + merge) | 1-2h | Sì, gate "merge in master?" |

### Sul gate "DGX o laptop" (S2 → S3)

**Laptop** (251 GB RAM): wall **~28h**. Layer A precedente ha già girato 28h sul laptop (run_id `96c43acb`). Sappiamo che funziona. Background con cron-orchestrator opzionale.

**DGX** (2 TB RAM, 100 cores): wall **~4-6h**. Setup via `dgx_p4_submit()`. Bundle + slurm. Memoria `user_dgx_backup_2tb` lista i criteri (wall>24h è uno dei trigger).

**Mia raccomandazione**: **DGX** se disponibile. Wall ~5x più veloce + RAM headroom. Per laptop avrebbe senso solo se DGX è inaccessibile per qualche motivo.

## Cose che vale la pena guardare DOPO il rebuild

Una volta finito (post-S5), questi sono i numeri che andranno nel paper Methods/Discussion:

| Metrica | Valore atteso |
|---|---|
| Field-swap recovery rate | 95-100% (CHEBI) + 75-80% (HGNC) + 93% (MeSH) |
| Kind override rate | ~5.000-7.000 cluster (~3% del totale, ma ~80% dei mismatch cytokine/pathogen) |
| Residual unvalidatable | <5% (compound senza ChEBI roles + stringhe libere) |
| MeSH hallucinated residuo | ~492 cluster (preserved + flagged) |
| Layer B 15 case study misclassification post-rebuild | <5% target gate |

Questi sono i numeri che il paper L2 limitation citerà come "mitigation rate".

## Riepilogo: cosa devi fare TU domani

1. Aprire `docs/decisions/0018-llm-anchor-ontology-override.md` per review
2. Aprire questo file (HUMANE) per orientarti su gate decision points
3. Aprire `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-plan.md` se vuoi i dettagli task-by-task (è dove l'agente esegue)
4. Iniziare la sessione S1 dicendo "ok partiamo con S1" o equivalente. L'agente (Claude o subagent) sa che il plan è in `2026-05-25-p5-llm-anchor-ontology-override-plan.md` e il sub-skill richiesto è `superpowers:executing-plans` o `superpowers:subagent-driven-development`.

Buon lavoro.
