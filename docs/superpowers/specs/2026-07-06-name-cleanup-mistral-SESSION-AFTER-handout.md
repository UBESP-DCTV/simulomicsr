# Handout — Sessione DOPO il fix Stadio 4: PULIZIA-NOMI con Mistral

**Data:** 2026-07-05 (per la sessione **successiva** al fix Stadio 4)
**Prerequisito:** fix gate Stadio 4 COMPLETATO (handout
`2026-07-05-stage4-selection-gate-fix-NEXT-SESSION-handout.md`). **Non iniziare prima.**
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Finding base:** `docs/findings/2026-07-05-stage4-selection-gate-excludes-named-metaanalyses.md` §3
**È la DECISIONE C** già nei TODO del progetto (LLM-fallback finale sui residui nome).

## In una frase

Una minoranza di cluster (~50–70 su 197 entità Pop B) è **omogenea ma mal etichettata** (LPS→"carnitine",
NSCLC→"Netherlands Antilles", AML→"Antistreptolysin", HCC→"Pemphigoid Gestationis"). Farla ripulire da
**Mistral** (lo stesso LLM self-hosted della pipeline) sui metadati grezzi dei campioni membri, con
validazione ontologica deterministica e override precision-gated — **per coerenza e riproducibilità**
con il resto della pipeline.

## Perché Mistral (non un altro metodo)

Decisione dell'utente: **coerenza + riproducibilità** con la pipeline. Il recupero-nome deterministico
(ChEBI/MeSH/HGNC/taxonomy) ha una coda irriducibile di casi ambigui/abbreviati; un check lessicale
nome↔testo ha falsi negativi (abbreviazioni: "IL-4", "LPS", "5-FU"). L'LLM legge il contesto e risolve
dove il match esatto fallisce. Usare **lo stesso Mistral-Small-3.2 self-hosted** (config identica:
`temperature=0`, `repetition_penalty=1.1`, structured output, cache) mantiene l'uniformità metodologica
(memoria `feedback_pipeline_config_uniformity`) — nessun confounder da modello diverso.

## Cosa NON è (limiti)

- **NON** ri-etichetta tutto: si tocca SOLO la coda mal-nominata (i 68 ben-nominati restano).
- **NON** è libera interpretazione: Mistral propone, un **validatore deterministico** contro ontologia
  conferma (stesso spirito ADR-0018, override conservativo precision-gated). Se Mistral è incerto o la
  proposta non valida → si **flagga**, non si sovrascrive.
- **NON** cambia il pooling DE: un cluster omogeneo mal-nominato produce già una meta-analisi valida; qui
  si corregge l'**interpretazione** (e, con scope B sotto, si ri-fondono i frammenti).

## Materiale già pronto (da questa sessione)

- **Triage 197 entità**: `analysis/audit/2026-07-05-stage4-popB-coherence-triage.csv` con colonne
  `name, kind, k, homog, top_theme, name_ok, cls`. Buckets:
  - `OMOGENEO+ben_nominato` (68) → **lasciare stare**.
  - `OMOGENEO+MAL_nominato` (119) → **candidati Mistral** (di cui ~50–70 veri mislabel; il resto è nome
    corretto in forma IUPAC/abbreviata, es. R1881, osimertinib — il validatore li conferma senza cambio).
  - `ETEROGENEO(sospetto)` (6, k=3–4) → **far ispezionare a Mistral come doppio-check anti-minestrone**.
  - `vehicle/none` (4) → escludere.
- Il `top_theme` estratto dai metadati membri **già indica la biologia vera** (hepatocellular, aml, lps…):
  ottimo input di contesto per Mistral + oracolo per validare la sua risposta.
- Script riproducibili: `analysis/audit/2026-07-05-stage4-popB-{coherence-check,nametail}.R`.

## Design da decidere (BRAINSTORMING, gate utente)

1. **Scope — due livelli, scelta esplicita:**
   - **(A) Relabel post-hoc del pooled output**: aggiorna solo l'etichetta dei cluster già poolati dallo
     Stadio 4. Economico, **nessun re-run**, sistema l'interpretazione. NON ri-fonde i frammenti (LPS
     resta spezzato in più cluster, k reale sottostimato).
   - **(B) Fix identità in Stadio 3 → re-cluster → re-pool**: corregge `agent_id_resolved` alla sorgente,
     ri-clusterizza (i frammenti LPS→"carnitine"+"hexanoate" si **fondono** → k più alto e meta-analisi
     più potente), ri-poola. Costo: catena di run pesanti (re-cluster ~7h + re-pool ~11h).
   - Raccomandazione da discutere: B ha valore scientifico reale (k più alto), ma A è un ritocco rapido;
     eventualmente A subito + B come passo successivo mirato solo sui frammenti veri.
2. **Prompt/schema Mistral**: input = label corrente (sospetta) + metadati grezzi dei campioni membri
   (aggregati per studio, budget char) + kind atteso. Output structured = `{canonical_name, ontology_id,
   confidence, evidence}`. Riusare l'infra prompt esistente (`prompts.py`, client vLLM DGX).
3. **Validatore + policy override**: ontology lookup su `ontology_id` proposto (accessor `by_id` in
   `R/ontology-lookup.R`); override solo se STRONG+valido; altrimenti flag `name_llm_unvalidatable`.
   Registrare `name_recovery_source = "mistral_fallback"` + versioning cache.
4. **Gate riproducibilità**: `temperature=0` + structured output + cache keyed (deterministico); diff
   report before/after + **review umana** dei cambi (no-fretta paper-grade, memoria
   `feedback_no_fretta_paper_grade`). Benchmark su un gold di ~20 mislabel noti (carnitine→LPS,
   Antistreptolysin→AML, Netherlands→NSCLC, Pemphigoid→HCC…) prima del fullrun.

## Workflow suggerito

1. `superpowers:brainstorming` sulle 4 decisioni → spec + HUMANE (+ eventuale ADR se scope B).
2. Costruire gold ~20 mislabel + template Mistral + validatore (TDD).
3. **Smoke gate**: Mistral sul gold → precision/recall del relabel; canary sui 68 ben-nominati (0 cambi
   spuri attesi).
4. `superpowers:writing-plans` → plan; poi run (scope A = leggero; scope B = catena gated).
5. Re-gate coerenza (ri-girare `2026-07-05-stage4-popB-coherence-check.R`) + finding + CLAUDE.md + memoria.

## Attesi

- Coda mal-nominata ~50–70 → corretta/flaggata; 0 cambi spuri sui ben-nominati.
- Con scope B: alcuni frammenti si fondono (LPS k reale ↑), poche entità.
- I 6 sospetti-eterogenei: chiariti (probabile split-da-sinonimo, non minestrone — confermare).

## Note operative

- Config Mistral/DGX invariata (`.sif` vLLM, self-host FP16). Cache `~/.cache/R/simulomicsr/`.
- Memorie: `[[project_stage3_minestrone_rework]]`, `[[feedback_pipeline_config_uniformity]]`,
  `[[feedback_validate_before_fullrun]]`, `[[feedback_no_fretta_paper_grade]]`,
  `[[feedback_explain_then_decide]]`. Ledger: `.superpowers/sdd/progress.md`.
