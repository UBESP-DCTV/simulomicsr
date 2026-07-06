# Design — Pulizia-nomi con Mistral (scope A relabel + misura B)

**Data:** 2026-07-06
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Prerequisito:** fix gate Stadio 4 COMPLETO (fullrun v8 `a500d032`, ADR-0022 Accepted).
**È la DECISIONE C** del rework (LLM-fallback finale sui residui nome), limitata alla coda mal-etichettata.
**Handout base:** `docs/superpowers/specs/2026-07-06-name-cleanup-mistral-SESSION-AFTER-handout.md`.
**Finding base:** `docs/findings/2026-07-05-stage4-selection-gate-excludes-named-metaanalyses.md` §3.

## In una frase

Una minoranza di cluster omogenei è **mal etichettata** (LPS→"carnitine", NSCLC→"Netherlands Antilles",
AML→"Antistreptolysin", HCC→"Pemphigoid Gestationis"). Li facciamo ripulire da **Mistral** (lo stesso LLM
self-hosted della pipeline) sui metadati grezzi dei campioni membri, con **risoluzione ontologica
deterministica** e **override precision-gated**. Scope **A** (relabel post-hoc del pooled v8, nessun
re-run); come sottoprodotto misuriamo la frammentazione per decidere **B** (re-cluster) con il dato in mano.

## Problema e contesto

Il pooling DE dei cluster mal-nominati è **valido** (raggruppa per struttura dell'anchor, non per il nome):
il difetto è di **interpretazione**, non di clustering (finding §3, coerenza a livello GSM ~95% omogenea).
Il recupero-nome deterministico (ChEBI/MeSH/HGNC/taxonomy) ha una coda irriducibile di abbreviazioni/sinonimi
("IL-4", "LPS", "5-FU") che il match esatto non risolve; un LLM che legge il **contesto** dei metadati la
chiude. Usare lo **stesso Mistral-Small-3.2 self-hosted** (config identica) mantiene l'uniformità
metodologica (memoria `feedback_pipeline_config_uniformity`): nessun confounder da modello diverso.

## Decisioni prese (brainstorming, gate utente 2026-07-06)

- **D1 — Scope: IBRIDO.** Scope A (relabel post-hoc del pooled output v8, nessun re-run) come deliverable;
  l'output di Mistral misura la frammentazione (entità distinte con ≥2 cluster_id) → scope B (fix identità
  Stadio 3 → re-cluster → re-pool, ~18h) deciso **data-driven** solo se il guadagno di k è materiale.
- **D2 — Precision gate: Mistral propone il NOME, l'ontologia è l'autorità sull'ID.** Mistral emette
  `canonical_name`; noi risolviamo `nome → ID` in modo deterministico con gli accessor pipeline; STRONG
  match obbligatorio. Mistral **mai** autorità sull'ID (spirito ADR-0018; evita il 23,87% di field-swap ID
  dell'audit originale).

## Componenti (unità isolate, testabili)

### 1. Candidate set + pre-clean markup (deterministico)
- **Input set → Mistral (125)**: 119 `OMOGENEO+MAL_nominato` + 6 `ETEROGENEO(sospetto)` (doppio-check
  anti-minestrone). Fonte: `analysis/audit/2026-07-05-stage4-popB-coherence-triage.csv` (colonna `cls`).
- **Canary (68)**: `OMOGENEO+ben_nominato` — passati a Mistral solo per verificare 0 cambi spuri.
- **Esclusi (4)**: `vehicle/none`.
- **Pre-clean markup**: strip di markup HTML dai nomi ChEBI (`<i>`,`<em>`,`<sub>`,`<sup>`,`<small>`,
  entità `&…;`) — igiene deterministica, applicata a monte e indipendente da Mistral. Helper puro TDD.

### 2. Builder input Mistral (per cluster)
- Aggrega i metadati **grezzi** dei GSM membri (treated/case) dello studio: `title`, `source_name_ch1`,
  `characteristics_ch1`, deduplicati e raggruppati per studio, con **budget char** (tiering come la pipeline).
- Riusa il pattern di lookup membri già in `analysis/audit/_gsm-lookup-helper.R` +
  `2026-07-05-stage4-popB-coherence-check.R` (record_id → stage2 master → GSM; H5 per geo_accession).
- **`top_theme` NON entra nel prompt**: resta oracolo indipendente per il diff/validazione (no leak
  circolare LLM↔oracolo).
- Prompt: label corrente (sospetta) + kind atteso + metadati membri. Riusa l'infra prompt esistente
  (`prompts.py`, client vLLM DGX).

### 3. Schema output + risoluzione deterministica
- Structured output: `{canonical_name: str, kind: str, confidence: enum(high|medium|low), evidence: str}`.
  (`ontology_id_hint` opzionale ma **ignorato** come autorità.)
- Risoluzione `canonical_name → ID`: accessor nome→id già in pacchetto — `.chebi_lookup_alias`,
  `.mesh_lookup_term`, `.hgnc_lookup_symbol`, taxonomy (per pathogen) — dispatchati per `kind`.
- Esito risoluzione: `{resolved_id | NA, match_strength ∈ {STRONG, WEAK, NONE}}`.

### 4. Policy override (precision-gated)
| Condizione | Azione |
|---|---|
| STRONG + `resolved_id` valido + kind compatibile | **override** label → `canonical_name` + `resolved_id`, `name_recovery_source="mistral_fallback"` |
| WEAK / NONE / kind incompatibile / `confidence=low` | **NO override**, si tiene la label vecchia, flag `name_llm_unvalidatable=TRUE` |
| Canary (ben-nominato) risolve a ID **diverso** dall'attuale | **flag per review**, NO override silenzioso |
| Canary risolve allo **stesso** ID | no-op (conferma) |

Compatibilità `kind`: riusa la logica `infer_kind_with_override` / accessor `has_role` già in
`R/ontology-lookup.R` (stesso spirito ADR-0018, override conservativo).

### 5. Applicazione scope A + misura B
- **Stabilità cluster_id**: il triage popB è costruito sui cluster **Stadio 3 v7**, e v8 ha ri-poolato lo
  **stesso** Stadio 3 v7 (nessun re-cluster) → i `cluster_id` del triage sono validi e stabili in v8. Il
  relabel si applica ai `cluster_id` candidati presenti in `clusters.rds` v7: i pooled in v8 (rem_group/mega)
  ottengono il beneficio di **interpretazione**; i non-processable ottengono l'identità pulita per la
  **misura B** e la futura re-curation.
- **Side-table relabel**: `cluster_id → {old_anchor_key, old_label, new_canonical, new_id, new_kind,
  match_strength, name_recovery_source, name_llm_unvalidatable, confidence, evidence}`. Applicata come
  join sul pooled v8 (`cluster_pooled.parquet` è keyed su `cluster_id`; la label vive nello Stadio 3
  `clusters.rds` via `anchor_key`). **NON ri-poola.** Pensata per essere consumata dalla futura Layer B
  re-curation.
- **Misura B (sottoprodotto)**: raggruppa i cluster (processati + i loro `new_id`) per entità risolta →
  conta le entità distinte con ≥2 `cluster_id` (frammenti) e stima il `k` merged. Report numerico →
  input per la decisione B.

### 6. Riproducibilità + gate (validate-before-fullrun)
- Config Mistral identica alla pipeline: `temperature=0`, `repetition_penalty=1.1`, structured output,
  **cache keyed** con `name_cleanup_cache_version` (bump-aware, memoria `feedback_bump_lookup_cache_version`).
- **Gold ~20 mislabel noti** (carnitine→LPS, Antistreptolysin→AML, Netherlands→NSCLC, Pemphigoid→HCC,
  Genes-Viral→GBM, …) → **smoke precision/recall PRIMA** del run sui 125.
- **Canary 68** → 0 cambi spuri attesi (se >0, indagare prima di procedere).
- **Diff report before/after + review umana** (no-fretta paper-grade) prima del closeout.

## Cosa NON è (limiti espliciti)

- **NON** ri-etichetta tutto: tocca solo la coda mal-nominata; i 68 ben-nominati restano (canary).
- **NON** è libera interpretazione: Mistral propone, il **validatore deterministico** conferma; incerto/
  invalido → **flag**, non sovrascrittura.
- **NON** cambia il pooling DE in scope A: un cluster omogeneo mal-nominato produce già una meta-analisi
  valida; qui si corregge l'**etichetta**. La ri-fusione dei frammenti è scope B (gated, data-driven).
- **NON** decide B alla cieca: B parte solo se la misura di frammentazione mostra un guadagno di k materiale.

## Edge case

- **Nome ChEBI corretto ma IUPAC/brutto** (es. `17β-estradiol`, `17β-hydroxy-5α-androstan-3-one`=DHT):
  Mistral può proporre lo stesso ID → no-op (confermato), nessun cambio. Atteso per buona parte dei 119.
- **kind mislabel a monte** (LPS etichettato `small_molecule`): l'override può correggere anche il kind se
  l'ontologia lo impone (STRONG), coerente con ADR-0018.
- **6 sospetti eterogenei**: Mistral come doppio-check → probabile split-da-sinonimo (non minestrone);
  se conferma eterogeneità reale, flag per ispezione manuale (NON si fondono).
- **char budget superato** dai metadati membri: troncamento deterministico per studio (tiering), come pipeline.

## Deliverable

- Side-table relabel+flag (RDS/parquet) · report misura-B · script riproducibili + suite TDD ·
  finding `docs/findings/2026-07-06-...` · CLAUDE.md + memoria `project_stage3_minestrone_rework` + ledger.
- **Nessun re-run in scope A.** Scope B eventuale = handout/plan separato deciso sui numeri.

## Riferimenti

- Handout: `…/2026-07-06-name-cleanup-mistral-SESSION-AFTER-handout.md`
- Finding-causa §3: `docs/findings/2026-07-05-stage4-selection-gate-excludes-named-metaanalyses.md`
- Finding-risultati v8: `docs/findings/2026-07-06-stage4-rem-group-results.md`
- ADR-0018 (override ontologico conservativo), ADR-0022 (ramo rem_group)
- Triage: `analysis/audit/2026-07-05-stage4-popB-coherence-triage.csv`
- Memorie: `feedback_pipeline_config_uniformity`, `feedback_validate_before_fullrun`,
  `feedback_no_fretta_paper_grade`, `feedback_bump_lookup_cache_version`, `project_stage3_minestrone_rework`.
