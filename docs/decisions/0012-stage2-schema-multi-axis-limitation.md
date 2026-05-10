# ADR-0012: Limitazione schema stage2.v2 — `primary_role` mono-axis vs design multi-axis

- **Status:** Accepted (limitazione conosciuta da documentare nel paper)
- **Date:** 2026-05-10
- **Deciders:** Luca Vedovelli
- **Supersedes:** —
- **Superseded by:** schema futuro v3 (potenziale, da plan separato)
- **Relates to:** ADR-0009 (safe-mode), ADR-0011 (tier strategy), spec classificatore v5

## Context and Problem Statement

Durante l'eval di α stage2 contro mini-gold v5 (2026-05-10) è emersa una limitazione **strutturale** dello schema `study_design.stage2.v2`: il campo `primary_role` è uno scalare di 5 valori (`treated/control/bystander/excluded/unclear`) assegnato per ogni `replicate_group`. Per i design **monodimensionali** (treatment_vs_vehicle, knockdown_panel, time_course con un asse) questo è adeguato. Ma per i design **multi-asse** (factorial, multi_arm con assi indipendenti) un singolo sample/gruppo può legittimamente essere `treated` su un asse e `control` su un altro asse — lo schema obbliga a una sola scelta.

### Esempi concreti dal eval mini-gold v5

1. **GSE169241** (factorial: virus × drug):
   - Sample con `SARS-CoV-2 + DMSO`: gold dice `control` (perché DMSO è il control dell'asse drug). Modello dice `treated` (perché il sample È virus-infected, control dell'asse drug ma treated dell'asse virus).
   - Entrambe le interpretazioni sono **internamente consistenti**; il gold ha scelto l'asse drug come "primario" ma lo schema non distingue assi primari/secondari.

2. **GSE178702** (factorial: VDR × treatment):
   - Sample `untreated + VDR.KO`: gold dice `control` (control dell'asse treatment). Modello dice `treated` (treated dell'asse genotype).

3. **GSE189186** (multi-arm con DMSO):
   - Sample `LNCaP + DMSO`: gold dice `control` (vehicle del confronto principale). Modello dice `treated` (uno dei "molti arm" del multi-arm). Ambiguità su quale arm è il "main".

Il modello (Mistral-Small-3.2-24B, post prompt iter 2026-05-10 con regole esplicite vehicle/baseline/time-zero/factorial) **non sbaglia il fatto** ma **sbaglia la scelta dell'asse**. Comparison-level `control_type` (campo separato in schema v2) gestisce parzialmente questo problema, ma il `primary_role` sample-level resta forzato.

## Decision Drivers

- **Lo schema v2 è frutto del brainstorming P3.5-C (2026-05-04)** che ha esplicitamente scelto la "philosophy v2": control è proprietà relazionale, esiste solo IN RELAZIONE al treated. Questo è documentato bene nel system prompt (`R/llm-stage2.R::.stage2_system_prompt`). Ma rimane il `primary_role` come simplification operazionale a livello sample/gruppo, e qui la mono-axis-ness è il limit.
- **Cambiare lo schema** (es. v3 con `roles_per_axis`) è settimane di design + reschemi + retest mini-gold + retest pipeline downstream. Out-of-scope per α P4.
- **Per la meta-analisi RNAseq downstream** (P5: DESeq2/limma + metafor), il sample-level binary control/treated è quello che serve come input. Il fattore "altro asse" (es. virus) può andare in `fixed_factors` o essere modellato come covariata di blocking. Quindi l'**utility a valle non richiede multi-role**: serve solo che la scelta dell'asse "primario" sia coerente.
- **Empiricamente, 93% binary accuracy con specificità 80% sui factorial mono-axis** è in banda investigativo plan Task 22 [80, 95). Plan accetta questo come "PASS investigativo" non TARGET (≥95%).

## Considered Options

1. **A — Accept la limitazione e documentala** (questa scelta): lo schema v2 resta. Documenta come known issue per il paper. Il prompt fix 2026-05-10 ha esaurito i guadagni "facili" (recovered 7/16 problematici, restanti sono multi-axis ambiguity).

2. **B — Schema v3 con `roles_per_axis`**: ogni gruppo riceve un array di {axis, role}. Aggiunge expressive power, costa settimane di redesign + ripetizione P3.5-C/D/A, retest pipeline P4 build/eval, riallineamento mini-gold. Out-of-scope α; potenziale per P5 plan se l'analisi a valle ne avesse bisogno (NON OGGI).

3. **C — Modello più grande**: gpt-5.5 (closed-source) o Claude Sonnet potrebbero scegliere l'asse "primario" più spesso in linea col gold umano. Ma esce da setup DGX self-host (ADR-0007), introduce dipendenza API closed, costa +. Inoltre P3.5-A su gpt-5.5 ha mostrato 83.7% sull'altro mini-gold (n=1500), non drammaticamente meglio.

4. **D — Convertire in unsupervised cross-study clustering**: skipping the explicit primary_role assignment e usare canonical anchors per il pooling. Cambia tutta la pipeline. Non rilevante per α.

## Decision Outcome

Scelta: **Opzione A — Accept e documenta**.

Motivazione: il problema è un trade-off design ben capito (sample-level scalar primary_role era una semplificazione consapevole P3.5-C); il guadagno di B/C non vale il costo per α; l'utility a valle (meta-analisi) non richiede multi-role. La limitazione si riflette in ~5-7 sample su 100 di mini-gold v5 (~5-7% specificità persa) — ben dentro la banda investigativo del plan.

### Consequences

- **Positive:**
  - α stage2 chiuso a 99.84% schema validity + 93.3% binary accuracy (o 93.0% post prompt iter, comparable).
  - Nessun re-run α massivo richiesto. La pipeline P4 resta com'è.
  - Documentazione paper-grade della limitazione, onesta.

- **Negative:**
  - I sample factorial multi-axis avranno una "scelta" del primary_role che può divergere dal manual gold in ~5-7% dei casi.
  - Per studi factorial-heavy nel β massivo (ARCHS4) ci si aspetta un drop di accuracy proporzionato. Documentato come known.

- **Neutral:**
  - Schema v3 multi-axis resta opzione futura per P5 se necessario.

## Note operative per il paper / metodi

Per il paper "simulomicsr: design-aware cross-study RNAseq meta-analysis":

> ### Stage 2 schema and known limitation
>
> Stage 2 produces a `study_design.stage2.v2` JSON object per study with
> `replicate_groups`, each tagged with a single `primary_role` ∈ {treated,
> control, bystander, excluded, unclear}. This sample-level scalar is a
> deliberate simplification: in factorial designs (e.g., genotype × drug)
> a single sample can legitimately play different roles on different
> axes (e.g., `WT-untreated` is control of the drug axis but baseline of
> the genotype axis). The schema forces selection of a single "main"
> axis for `primary_role`, which the LLM occasionally mis-aligns with
> the human reviewer's choice. On mini-gold v5 (n=100, 16 GSE), this
> accounts for ~5-7% of binary classification disagreement.
> Comparison-level `control_type` (separate field) can express the
> multi-axis nuance per-comparison (vehicle, untreated, genetic_negative,
> inducer_off, disease_normal, time_zero, secondary_arm), and is the
> canonical signal used for downstream meta-analysis pooling. A future
> schema v3 with `roles_per_axis` is a possible direction if the
> single-role limitation becomes load-bearing for the analysis goals.

## Pros and Cons of the Options

### A — Accept

- **Pro:** zero costo, onestà scientifica, paper-grade limitation note.
- **Contro:** ceiling ~93% binary su factorial-heavy datasets (accettabile per α).

### B — Schema v3 multi-axis

- **Pro:** risolve l'ambiguità strutturale.
- **Contro:** settimane di redesign; out-of-scope α; potenziale rabbit hole.

### C — Modello più grande

- **Pro:** ceiling potenzialmente più alto.
- **Contro:** dipendenza API closed; costo $; tradisce ADR-0007 (DGX self-host).

### D — Pipeline diversa

- **Pro:** —
- **Contro:** out-of-scope.

## Links

- Eval bench: `analysis/p4-output/alpha-stage2-cs25-eval.rds`
- Rerun benchmark: `analysis/p4-output/rerun-minigold-tiered-result.rds`
- ADR-0011: tier strategy (la rerun mini-gold del 2026-05-10 ha usato sia tier che prompt iter).
- Spec classificatore v5: `docs/superpowers/specs/2026-04-29-classificatore-llm-design.md`.
- Plan Task 22: `docs/superpowers/plans/2026-05-06-p4-dgx-integration-plan.md`.
- Memory: `project_paper_known_limitations.md` (paper-prep checklist).
