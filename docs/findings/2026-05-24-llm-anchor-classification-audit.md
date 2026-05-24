# LLM anchor classification audit — Stage 1/3 cross-validation contro ontologie esterne

**Date**: 2026-05-24
**Author**: audit eseguito durante sessione `p5-llm-anchor-classification-audit`
**Branch**: `p5-llm-anchor-classification-audit` (NON mergiato)
**Modello LLM auditato**: `mistralai/Mistral-Small-3.2-24B-Instruct-2506` (Stage 1 sample classification + Stage 2 study classification)
**Vocabolari ground-truth**: ChEBI release 2026-05-01 (205.310 compounds), HGNC complete set 2026, MeSH 2025 (30.956 descriptors)

## Domanda

Il LLM emette `agent_normalized.id_database` ∈ {CHEBI, HGNC, MeSH, ...} + `id` + `preferred_name` (Stage 1 v3 schema). NON c'è alcun lookup esterno: i numeri arrivano dalla memoria di training. Sono affidabili come ground-truth per il clustering Stage 3?

## Sintesi (3 numeri chiave)

| Metrica | Valore | Cosa dice |
|---|---:|---|
| **Field-swap rate** `<DB>:<num>` (ID numerico nel campo `preferred_name` invece che `id`) | **23.87%** (63.738 / 267.056 cluster Stage 3) | Bug di field-assignment LLM. ID **recuperabile** post-hoc via lookup. |
| **Pure hallucination rate** (numero numerico inesistente in alcun vocabolario controllato) | **0.97%** (2.587 / 267.056) | Bassissimo. Il LLM raramente "inventa" numeri inesistenti. |
| **`kind_effective` accuracy** cross-checked contro ChEBI `has_role` | **`cytokine_stim` 0.7% match, `pathogen_or_aggregate_exposure` 2.4% match, `vehicle_only` 93.5% match** | Disastroso per cytokine/pathogen. OK per vehicle. |

## Impatto sul lavoro fatto

1. **Pooling DE Layer A è ALGORITMICAMENTE VALIDO** — la chiave testuale dell'anchor v3 è deterministica per composto (lo stesso composto produce la stessa stringa di anchor cross-studio, anche se field-swap), quindi il matching cross-studio funziona. Gli 622 cluster Stage 4 hanno pooled studi correttamente.
2. **L'interpretazione BIOLOGICA dei cluster è in molti casi INVALIDA** — la `kind_effective` "cytokine_stim" o "pathogen_or_aggregate_exposure" assegnata dal LLM è quasi sempre wrong se l'agente è un metabolita o solvent. I cluster esistono ma la loro etichetta semantica è sbagliata.
3. **Cluster fragmentation reale**: a livello coarse (L0, group-mode), 44.9% dei composti appaiono in >1 cluster, e a `(canonical_compound, kind_effective)` fissati il 34.4% resta fragmentato — quindi non tutti gli studi sullo stesso composto sono pooled insieme.

## Dettaglio risultati

### Pattern detection (267.056 cluster Stage 3)

| Pattern | Count | % |
|---|---:|---:|
| PATH 1: numerico puro (es. `"17126"`) | 37.160 | 13.91% |
| **PATH 2: `<DB>:<number>` field-swap (es. `"CHEBI:17126"`)** | **63.738** | **23.87%** |
| PATH 3: `<DB>:<word>` (raro/normale) | 255 | 0.10% |
| PATH 4: MeSH naked `Dxxxxxx` | 7.688 | 2.88% |
| PATH 4: ChEMBL naked | 3.617 | 1.35% |
| PATH 4: stringa nome libero | 89.799 | 33.62% |
| PATH 5: unknown/empty | 64.799 | 24.26% |

### Validità ID emessi nel campo wrong (PATH 2)

| DB dichiarato | VALID_PRIMARY | NOT_VALID | Recovery (su NOT_VALID) |
|---|---:|---:|---|
| CHEBI | 51.979 (95.7%) | 2.330 (4.3%) | 721 → in realtà HGNC, 198 → Entrez, 1.411 → hallucinated |
| HGNC | 7.209 (78.9%) | 1.925 (21.1%) | 1.742 → in realtà CHEBI, 163 → hallucinated, 20 → Entrez |
| MGI | 0 (0%) | 285 (100%) | 47 → CHEBI, 238 → hallucinated |
| NCBITaxonomy | 0 | 10 (100%) | 10 → hallucinated |

**Conclusione PATH 2**: il LLM emette in `preferred_name` il numero corretto (validato come ID esistente in ChEBI/HGNC) nell'**85-96% dei casi**. Field-swap è un bug di assignment, non di knowledge.

### Validità PATH 1 (numerico puro)

37.160 numeri puri (campo `id` correttamente valorizzato, ma `id_database` non sappiamo cosa contenesse):
- **34.959 (94%) → ChEBI primary/secondary**
- 1.778 → HGNC
- 150 → Entrez (via HGNC entrez_id column)
- **273 (0.7%) → no match → hallucinated**

### Validità MeSH naked (`Dxxxxxx`)

7.688 cluster con agent_id formato `D` + 6 cifre:
- 7.196 (93.6%) **PRIMARY in MeSH 2025**
- 492 (6.4%) **NOT_FOUND in MeSH** → hallucinated

**Esempio paper-grade di hallucination MeSH**: il LLM ha emesso `D011279` per un cluster con `tissue=prostate, kind_effective=disease_vs_normal`, suggerendo "Prostatic Neoplasms". Lookup MeSH 2025: **D011279 = Pregnanetriol** (uno steroide, branch D04.210 = sterols). "Prostatic Neoplasms" è D011471. Il LLM ha allucinato l'UI MeSH.

### `kind_effective` validation contro ChEBI `has_role`

Su 18.117 cluster con canonical CHEBI risolto e roles disponibili:

| `kind_effective` LLM | n | MATCH | MISMATCH | mismatch_rate |
|---|---:|---:|---:|---:|
| `cytokine_stim` | 3.018 | 20 | 2.998 | **99.3%** |
| `pathogen_or_aggregate_exposure` | 1.705 | 41 | 1.664 | **97.6%** |
| `vehicle_only` | 4.878 | 4.562 | 316 | 6.5% |
| `small_molecule` | (accept_any) | — | — | — |

**Esempi MISMATCH paper-grade** (top 5 per cluster numerosi):
1. **CHEBI:16236 (ethanol) classificato `cytokine_stim`**: 755 cluster. ChEBI roles: antiseptic drug, polar solvent, neurotoxin, CNS depressant.
2. **CHEBI:16635 (Met-tRNA) classificato `cytokine_stim`**: 744 cluster. ChEBI roles: S. cerevisiae metabolite, E. coli metabolite. Una tRNA carrier, NON un signaling molecule.
3. **CHEBI:17126 (carnitine) classificato `pathogen_or_aggregate_exposure`**: 462 cluster. ChEBI roles: human metabolite, mouse metabolite.
4. **CHEBI:17120 (hexanoate, acido grasso) classificato `pathogen`**: 327 cluster. ChEBI roles: human metabolite, plant metabolite.
5. **CHEBI:16991 (DNA) classificato `cytokine_stim`**: 280 cluster.

**Caveat sulla validation**: il mio keyword-mapping è restrittivo. Esempi legittimi che potrebbero comparire come MISMATCH:
- **poly(I:C) classificato pathogen** (275 cluster) — ChEBI role: "immunological adjuvant" → semanticamente OK come pathogen-mimic ma il mio mapping non ha "adjuvant" → conta come WRONG (false positive del check). Ho corretto nel audit 15 aggiungendo "adjuvant|TLR".
- Imiquimod come `cytokine_stim` — ChEBI role: "interferon inducer" → semanticamente OK (matcha "interferon" keyword) → MATCH legittimo.

Anche allargando, **migliaia di cluster** rimangono REAL errors (Ethanol≠cytokine, Carnitine≠pathogen).

### Cluster fragmentation

| Slice | Compounds | % fragmentati (>1 cluster) | max cluster per compound |
|---|---:|---:|---:|
| Tutti i compounds Stage 3 (legit canonical) | 33.495 | 100%* | 1.214 (DMSO) |
| Con ≥2 studi unique (meaningful per pooling) | 3.036 | 100% | — |
| A level=0 mode=group (anchor coarse) | 8.187 | **44.9%** | 1.214 |
| A (canonical, level=0, mode=group, kind_eff) fissato | 10.411 | **34.4%** | — |

\* 100% perché la gerarchia anchor v3 ha 5 livelli × 2 modi = 10 instanze minimum per compound se gli studi coprono multipli livelli; non è bug per sé. La metrica meaningful è la riga 3-4.

**Interpretazione**: a livello aggregato e con stesso kind, **un terzo dei composti popolari resta fragmentato in più cluster**. Le cause possibili (da investigare separatamente):
- Studi su stesso composto ma `tissue`/`cell_context`/`engineering` diversi → fragmentation BIOLOGICAMENTE LEGITTIMA (anchor è hierarchical refinement).
- Studi su stesso composto rappresentato in modo INCONSISTENTE dal LLM (es. alcuni con `id=17126`, altri con `preferred_name=17126`) → fragmentation INDOTTA DA BUG.

Per misurare quale frazione del 34.4% è bug-induced servirebbe scan sample-level (per ogni GSE, contare le rappresentazioni alternative dello stesso composto emesse dal LLM). Non fatto in questo audit per costo, ma fattibile in follow-up.

## Audit 15 case study Layer B (selection corrente)

| # | Cluster | Label originale (mia) | Compound reale (post-lookup) | LLM ID | Kind | Decisione |
|---|---|---|---|---|---|:-:|
| 1 | `pair_L4_17e4a563` | polyIC_TLR3_agonist_blood | **poly(I:C) (CHEBI:84491)** — adjuvant | STRING_ALIAS | pathogen | ✅ MANTIENI |
| 2 | `pair_L3_d8550b3f` | Resiquimod_TLR7_8_agonist_blood | **resiquimod (CHEBI:36706)** — TLR7/8 agonist | NAME_MATCH | small_molecule | ✅ MANTIENI |
| 3 | `pair_L4_06cee1fa` | Interferon_beta_kidney | **Interferon-beta (MeSH:D016899)** | CORRECT_FIELD | cytokine_stim | ✅ MANTIENI |
| 4 | `pair_L4_0d451fc0` | Hypoxia_HIF1a | hypoxia (string) | STRING_ONLY | environmental | ✅ MANTIENI |
| 5 | `pair_L4_605808b4` | miR_9_9star_124_neural_reprog_skin | mir-9/9*-124 (string) | STRING_ONLY | genetic_overexpression | ✅ MANTIENI |
| 6 | `pair_L4_8dacf4ca` | Contact_inhibition_lung | contact inhibition (string) | STRING_ONLY | environmental | ✅ MANTIENI |
| 7 | `pair_L4_b5c447d0` | Mesendoderm_hESC | mesendoderm (string) | STRING_ONLY | differentiation | ✅ MANTIENI |
| 8 | `group_L0_a6f8c0e9` (smoke big) | Smoke_big_transversal_blood | UNRESOLVED (agent=unknown, transversal blood) | UNKNOWN | none | ⚠️ TRANSVERSAL (no agent) — semanticamente equivoco |
| 9 | `group_L0_1a0673ae` (smoke small) | Smoke_small_transversal_skin | UNRESOLVED (agent=unknown, transversal skin) | UNKNOWN | none | ⚠️ TRANSVERSAL (no agent) |
| 10 | `pair_L2_3ce85e50` (smoke aug) | Smoke_aug_CHEBI17236 | **2-hydroxy-6-oxohexa-2,4-dienoic acid (CHEBI:17236)** — intermediate aromatic-degradation pathway | FIELD_SWAP | small_molecule | ⚠️ COMPOUND OSCURO: probabile hallucination consistente del LLM (compound super-specifico ripetuto su 200 cluster L0G, biologicamente improbabile come "lung treatment") |
| 11 | `pair_L4_e89dff76` | Small_molecule_CHEBI17236_lung | come #10 | FIELD_SWAP | small_molecule | ⚠️ STESSO PROBLEMA di #10 |
| 12 | `pair_L4_25ee1af1` | Pathogen_exposure_blood_CHEBI17126 | **carnitine (CHEBI:17126)** — human/mouse metabolite | FIELD_SWAP | pathogen | ❌ **DROP**: kind_effective WRONG (carnitine NON è pathogen). Label paper completamente errata. |
| 13 | `pair_L4_875da822` | Pathogen_exposure_blood_CHEBI17199 | **4,5-dihydroxyphthalic acid (CHEBI:17199)** | FIELD_SWAP | pathogen | ❌ **DROP probabile**: dihydroxyphthalic acid è una bronsted acid, NON pathogen (no roles in ChEBI). |
| 14 | `pair_L4_8feddd0d` | Cytokine_CHEBI16236_skin | **ethanol (CHEBI:16236)** | FIELD_SWAP | cytokine | ❌ **DROP**: kind_effective WRONG (ethanol NON è cytokine, è solvent/CNS depressant). |
| 15 | `pair_L4_6a3ba59f` | Prostate_neoplasm_MeSH_D011279 | **Pregnanetriol (MeSH:D011279)** — non Prostatic Neoplasms | CORRECT_FIELD | disease_vs_normal | ❌ **DROP**: agent_id è uno steroide, NON una disease term. Kind "disease_vs_normal" wrong. |

**Riepilogo Layer B**:
- ✅ **7 case study scientificamente validi** (poly(I:C), Resiquimod, IFN-β, Hypoxia, miR-9, contact inhibition, Mesendoderm) — label da arricchire con lookup
- ⚠️ **2 transversal blood/skin** (group_L0 smoke) — agent generico, da decidere se mantenere come case study "pattern trasversale" o droppare per ambiguità
- ⚠️ **2 oscure compound** (`pair_L2_3ce85e50` smoke aug + `pair_L4_e89dff76`) — probabile hallucination LLM consistente di CHEBI:17236; il bundle DE è valido (pooling DE Stage 4 corretto), ma il "treatment" semantico è sospetto
- ❌ **4 critically wrong** (Carnitine-as-pathogen, dihydroxyphthalic-as-pathogen, Ethanol-as-cytokine, Pregnanetriol-as-disease) — da rimpiazzare nella selection

## Implicazioni paper-wide

### L2 limitation (memoria `project_paper_known_limitations`) — ESPANSIONE

Era: "L2 ceiling Mistral-3.2".
Diventa:
- **L2a**: schema mono-axis (già documentato)
- **L2b**: LLM field-assignment bug per id_database+id+preferred_name → 23.87% field-swap rate (recuperabile post-hoc)
- **L2c**: LLM `kind_effective` accuracy bassa per cytokine_stim (0.7% match) e pathogen_or_aggregate_exposure (2.4% match); accettabile per vehicle_only (93.5%). Causa probabile: il LLM associa "stimulation" generica al `kind=cytokine_stim` indipendentemente dall'agente.
- **L2d**: LLM hallucination MeSH UI sporadica (6.4% dei `Dxxxxxx` non esistono); ChEBI hallucination 0.97% pure.

### Mitigation strategy proposta (decisione a domani)

**OPZIONE 1 — Layer B only, low-cost (1-2h wall)**:
- Rimpiazzo i 4 critically wrong (#12-#15) con altri cluster dalla shortlist 31 che hanno coerenza ontology
- Patch label dei restanti con nomi ChEBI/MeSH risolti
- Rilancio batch Layer B parziale (~5 min)
- Documenta L2b-c-d in `project_paper_known_limitations` + paper Discussion

**OPZIONE 2 — Post-hoc ChEBI override at Layer B (medium, 4-6h)**:
- Aggiungo a `R/anchors.R::.resolve_agent_id` un resolver downstream che normalizza `<DB>:<num>` → canonical ID + nome
- Aggiungo a `R/anchors.R` un `kind_effective_resolved` che usa ChEBI `has_role` come ground-truth quando disponibile
- Re-build Stage 3 dal master Stage 2 (anchor_key nuovi)
- Re-build Stage 4 Layer A (28h wall, già fatto una volta)
- Re-build Layer B (15 case study, ~10 min)
- L'opzione 2 produce un dataset **più affidabile** ma costa 28h di compute (laptop) o 4-6h (DGX 2TB RAM).

**OPZIONE 3 — Stage 2 re-prompt mirato (long-term, ore-giorni)**:
- Re-prompt LLM Mistral su ~5000 cluster con `kind_effective` mismatch confermato, con istruzione esplicita "valida agent vs kind"
- Re-run Stage 3 + Stage 4 + Layer B
- Costo: stage 2 chunked rerun parziale (~3-6h DGX H100) + 28h Layer A.

**OPZIONE 4 — Stage 1 prompt fix + re-run completo (drastica, giorni)**:
- Aggiungo al system prompt Stage 1 "If id_database is set, put the numeric ID in field `id`, NOT in `preferred_name`. `preferred_name` MUST be the human-readable name (e.g., 'Carnitine'), never the database ID number."
- Re-run Stage 1 full su 879k record (wall ~18h DGX)
- Re-run Stage 2 (~42h DGX)
- Re-run Stage 3 + Stage 4 (~28h)
- Costo totale: ~4-5 giorni wall. Risolve field-swap radicalmente. **Non risolve kind_effective accuracy** (richiederebbe redesign del prompt Stage 2 separato).

### Mia raccomandazione (per discussione domani mattina)

**OPZIONE 2** è la scelta razionale paper-grade:
- Risolve il field-swap **deterministicamente** via ChEBI lookup (no LLM dependency)
- Risolve la maggior parte dei kind_effective error per gli agenti con ChEBI role
- Il costo 28h Layer A è già rodato (sappiamo come farlo, è automatic)
- Compatible con i dati gi% fatti (Stage 1/2 master NON cambiano, solo Stage 3 build downstream)
- Limita L2d (MeSH hallucination, ChEBI hallucination pure) come paper caveat residuo
- Genera un dataset/cluster ID stabile cross-vocabolario, prerequisito per il benchmark vs RummaGEO P3.5 eval

**Non raccomandazione OPZIONE 4**: 4-5 giorni di re-run completo per un fix che ChEBI ontology fa downstream in pochi minuti. Il prompt fix è comunque utile come "consolidation" per futuri run su dataset diversi (mouse ARCHS4 γ), ma NON è bloccante per il paper attuale.

## File deliverable di questo audit

| File | Contenuto |
|---|---|
| `analysis/p5-audit-chebi-build-dict.R` | Build ChEBI dictionary |
| `analysis/p5-audit-hgnc-mesh-build-dict.R` | Build HGNC + MeSH dictionary |
| `analysis/p5-audit-stage3-scan.R` | Scan validazione 267k cluster |
| `analysis/p5-audit-fragmentation.R` | Fragmentation analysis |
| `analysis/p5-audit-kind-validation.R` | kind_effective vs ChEBI roles |
| `analysis/p5-audit-15-layer-b.R` | Audit 15 case study Layer B |
| `analysis/p4-output/p5-audit-agent-id-validation.rds` | Scan output |
| `analysis/p4-output/p5-audit-fragmentation.rds` | Fragmentation output |
| `analysis/p4-output/p5-audit-kind-validation.rds` | Kind validation output |
| `analysis/p4-output/p5-audit-15-layer-b.csv` + `.rds` | Audit 15 case study (decisione-ready) |
| `~/.cache/R/simulomicsr/chebi/chebi-lookup.rds` | ChEBI dictionary (16 MB) |
| `~/.cache/R/simulomicsr/hgnc-lookup.rds` | HGNC dictionary |
| `~/.cache/R/simulomicsr/mesh-lookup.rds` | MeSH dictionary |

## Riproducibilità

```bash
# Re-download ontologies (cache se gia presenti)
Rscript analysis/p5-audit-chebi-build-dict.R
Rscript analysis/p5-audit-hgnc-mesh-build-dict.R

# Scan + fragmentation + validation
Rscript analysis/p5-audit-stage3-scan.R
Rscript analysis/p5-audit-fragmentation.R
Rscript analysis/p5-audit-kind-validation.R
Rscript analysis/p5-audit-15-layer-b.R
```

Wall totale: ~5-10 min su laptop (escluso download iniziale 1-2 min).
