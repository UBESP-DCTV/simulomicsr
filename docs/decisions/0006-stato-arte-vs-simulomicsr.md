# ADR-0006: Stato dell'arte 2026 e unique value di simulomicsr

- **Status:** Accepted
- **Date:** 2026-05-02
- **Deciders:** Luca Vedovelli
- **Supersedes:** —
- **Superseded by:** —

## Context and Problem Statement

A inizio P3 (Stadio 2 — study_design + comparability_anchor), prima di investire 2-3 mesi su un'altra fase importante, è emerso il dubbio: ARCHS4 e i tool affini negli ultimi anni si sono molto evoluti — il progetto ha ancora senso? E se sì, dove sta esattamente il suo unique value rispetto allo stato dell'arte 2024-2026?

La spec v5 (`2026-04-29-classificatore-llm-design.md`) e gli ADR precedenti trattano ARCHS4 solo come **fonte dati** (HDF5 dei conteggi, ~700k+ sample) e non come potenziale competitor metodologico. Manca un'analisi del delta annotativo. Senza chiarire il positioning ora, c'è il rischio reale di:
- duplicare lavoro già fatto da altri (annotazione per-sample);
- non saper rispondere a "perché non usare RummaGEO/MetaHQ direttamente?" né nei README, né nei paper futuri;
- accorgersi a fine P3 che il prodotto finale è ridondante.

## Decision Drivers

- **Originalità verificata.** Prima di scrivere il plan P3, voglio sapere quali parti della pipeline simulomicsr sono uniche e quali sono già coperte da tool esistenti (free o commerciali).
- **Framing del prodotto.** README, vignette future, paper devono presentare simulomicsr per quello che è davvero, non per come lo abbiamo descritto in passato.
- **Riutilizzo intelligente.** Se esistono tool che fanno parte del lavoro a monte (es. tissue/disease mapping), simulomicsr dovrebbe consumarli invece di rifarli.
- **Tracciabilità.** L'analisi serve come riferimento citabile nei paper meta-analitici e come capitolo "stato dell'arte" del manuale utente.

## Considered Options

1. **Procedere con scope P3-B come previsto, con framing sharpenato** — confermare che simulomicsr ha valore unico, aggiornare README/spec con il positioning corretto, citare i competitor, eventualmente integrare alcuni come upstream.
2. **Pivot a "consumer pipeline"** — abbandonare Stadio 1+2 LLM-based; consumare RummaGEO/MetaHQ come fonte di sample annotations + comparison signatures, e implementare solo Stadio 4-5 (DE per-studio + meta-analisi REM). Il pacchetto diventa un "metaforR per RNAseq con anchor pooling".
3. **Sospendere il progetto** — se i competitor coprono già end-to-end, non vale la pena continuare.

## Decision Outcome

Scelta: **Opzione 1 — procedere con scope P3-B come previsto, con framing sharpenato.**

Motivazione: la due-diligence (vedi §"Findings") mostra che **nessun tool 2024-2026 produce un canonical comparability_anchor cross-studio per pooling effect-size meta-analitico via REM**. RummaGEO è il competitor più vicino ma resta a livello di gene-set per-studio, senza anchor canonico né effect size. Il valore unico di simulomicsr è specificamente nel passaggio da "sample/study annotati" a "comparisons appaiate cross-studio raggruppabili per pooling random-effects" — un anello mancante che non vediamo coperto altrove. L'Opzione 2 perderebbe proprio la parte differenziante (anchor LLM-driven + design inference); l'Opzione 3 abbandonerebbe lavoro originale per un timore non confermato dai fatti.

### Consequences

- **Positive:**
  - Il positioning del progetto è documentato e citabile.
  - Si confermano i tool da citare come prior art / comparator nei paper futuri (RummaGEO, MetaHQ, Mondal et al. 2025, Ardigen) — niente più "che ne so dello stato dell'arte" generico.
  - Si apre l'opzione di **consumare** MetaHQ come upstream per tissue/disease/sex/age normalization in Stadio 2/3, risparmiando lavoro lato `R/lookup.R`.
  - README e CLAUDE.md possono dichiarare esplicitamente il differenziatore.
- **Negative:**
  - Costo della due-diligence: ~1-2 ore di Claude + WebSearch/WebFetch (assorbito).
  - Una volta committato il framing, va mantenuto coerente: README, vignette, eventuale paper devono riflettere che simulomicsr non è "un altro annotatore" ma "un meta-analizzatore con anchor canonico".
- **Neutral:**
  - Il benchmark testa-a-testa contro RummaGEO entra come **deliverable integrale** del progetto (vedi §"Deliverable integrale: benchmark vs RummaGEO"), non più come prospettiva opzionale.
  - L'integrazione MetaHQ è opzionale e va valutata quando arriverà a Stadio 2 il bisogno di tissue normalization "robusto" — vedi §"Aperto".

## Findings — competitive landscape 2024-2026

### Riepilogo per dimensione

| Tool | Sample annotations | Treated/control inference | Comparison pairs | Cross-study anchor | Effect-size meta-analysis |
|---|---|---|---|---|---|
| **ARCHS4 v9 / v2.x** (Maayan Lab, 2025) | Raw GEO metadata + functional gene predictions | ❌ | ❌ | ❌ | ❌ |
| **archs4r** R package | Raw GEO metadata strings (`title`, `characteristics_ch1`, `source_name_ch1`, ecc.) | ❌ | ❌ | ❌ | ❌ |
| **MetaSRA** (Bernstein 2017, dormant) | Sample type + ontology terms (Cell Ontology, Uberon, EFO, Cellosaurus, DO) | ❌ | ❌ | ❌ | ❌ |
| **MetaHQ** (Hicks et al., arxiv 2602.07805, marzo 2026) | Tissue + disease + sex + age (4 attributi) — aggregato di 13 fonti | ❌ | ❌ | ❌ | ❌ |
| **Multi-agent metadata curation** (Mondal et al., bioRxiv 658658, giugno 2025) | 23 campi inclusi tissue, disease, treatment, donor info — recall medio 93% | Parziale (estrae il campo `treatment` ma non risolve treated/control role) | ❌ (non dichiarato) | ❌ | ❌ |
| **RummaGEO** (Maayan Lab, *Patterns* 2024) | Usa espressione ARCHS4 + metadata clustering | K-means su metadata + keyword matching ("ctrl", "wildtype", "DMSO") | ❌ — solo gene set UP/DOWN per-studio | ❌ | ❌ — solo overlap di gene set |
| **Ardigen LLM pipeline** (commerciale, closed) | tissue, condition, drug, intervention — >80% strict accuracy | ❌ | ❌ | ❌ | ❌ |
| **metaRNASeq / metaseqR2 / DESeq2** (R/Bioconductor) | n/a (consumano comparisons già appaiate) | ❌ (l'utente fornisce il design) | User-supplied | ❌ | ✅ (p-value combination, no anchor) |
| **simulomicsr (planned)** | Stadio 1 LLM: sample_facts ricco — perturbations (kind, agent normalized, dose, duration, vehicle), cell_context, mediated_effect, phase, ambiguity flags | ✅ Stadio 2 LLM: design_role per sample | ✅ Stadio 2: `comparisons_table` cross-GSE | ✅ `comparability_anchor` v3 canonical | ✅ Stadio 5: metafor REM by anchor |

### Note di dettaglio

**ARCHS4** (`maayanlab.cloud/archs4`, `archs4r`, `archs4py`) — fornisce conteggi allineati Kallisto, embeddings, predizioni funzionali a livello di gene set, e metadati GEO grezzi. Non risolve treated/control entro lo studio, non produce comparison pairs, non normalizza dose/time/vehicle. Per simulomicsr resta la fonte dati primaria (HDF5) ma non sovrappone metodologicamente.

**MetaSRA** (Bernstein et al. 2017, ultimo update 2020) — first-mover su metadata harmonization SRA. Pipeline Python ancora reperibile su GitHub (`deweylab/MetaSRA-pipeline`) ma non più attivamente mantenuta. Output: ontology terms per-sample, sample type. Mai esteso a treated/control né a comparisons.

**MetaHQ** (Hicks et al., U. Colorado / Michigan State, marzo 2026) — più recente, 188.223 sample × 11.718 studi GEO, 4 attributi (tissue, disease, sex, age). Aggregatore + harmonizer di 13 fonti curate (Gemma, ALE, Bgee, CellO, CREEDS, DiSignAtlas, URSA, ecc.) con CLI Python (`pip install metahq-cli`). Espone propagazione gerarchica via Cell Ontology / UBERON / MONDO. **Ortogonale a simulomicsr**: copre i campi descrittivi base con qualità expert-level, ma non perturbations/dose/time/design_role. Buon candidato come **upstream** per il lookup tissue/disease al posto di reinventare normalize_tissue() in casa.

**Multi-agent metadata curation** (Mondal et al., bioRxiv 2025.06.10.658658) — il più vicino a Stadio 1 di simulomicsr per ambizione di copertura (23 campi, treatment context). 93% recall medio su 23 campi. **Architettura agentic** con orchestratore + sub-agenti specializzati (retrieval, parsing pubblicazioni, ontology mapping, context inference). Differenze rilevanti per simulomicsr:
- non risolve **design_role** (treated/control entro lo studio);
- non specifica estrazione granulare di dose/duration/vehicle/mediated_effect;
- non produce anchor canonico cross-studio;
- non sembra avere dataset pubblico né tool installabile (preprint single, no codebase pubblico citato).

Va citato come prior art più rilevante per Stadio 1 nei paper futuri.

**RummaGEO** (Maayan Lab, *Patterns* 2024, `rummageo.com`) — **il competitor più vicino end-to-end**. Pipeline:
1. Per ogni studio ARCHS4 RNA-seq, esegue **K-means clustering** sui metadati testuali concatenati (`title` + `characteristics_ch1` + `source_name_ch1`) per identificare gruppi.
2. Cerca termini di controllo (`wildtype`, `ctrl`, `DMSO`, `vehicle`) per assegnare il control group.
3. Computa DEG (limma-voom) tra control e ogni altro gruppo, soglia p-adj < 0.05.
4. Pubblica il risultato come **gene set UP/DOWN per-studio** (non effect-size; non logFC; non SE).
5. Permette signature search (gene set overlap) cross-studio.

Limiti per la meta-analisi proper:
- K-means + keyword matching è fragile su design factoriali, time courses, mediated_effect, phase non-default.
- L'output è gene-set membership, non effect size — non si può fare random-effects pooling proper (`metafor` REM richiede `yi`+`vi`).
- Nessun **anchor canonico**: due studi che misurano "VEGFA cytokine stim 1h HUVEC" non sono raggruppati esplicitamente, vengono ritrovati solo via signature similarity (rumore alto su signature corte).
- Non distingue tra ruoli (es. case vs comparison nei design `disease_vs_normal`).

Per simulomicsr, RummaGEO è il paragone obbligato in qualunque paper futuro. Beneficio per simulomicsr: dimostrare che (a) LLM design inference batte K-means+keyword su factorial, (b) effect-size REM batte gene-set overlap per pooling pulito.

**Ardigen LLM pipeline** — commerciale, closed-source, target enterprise. Estrae 4 campi base (tissue, condition, drug, intervention) con >80% strict accuracy in 5 min/studio. Nessun benchmark pubblico, nessun output scaricabile. Niente comparisons, niente anchor. Citabile come prior art "industry" ma non utilizzabile.

### Posizionamento di simulomicsr — il delta

L'unico contributo che la due-diligence non trova in nessun altro tool è la combinazione di:

1. **LLM-based design_role inference** (Stadio 2): chi è treated, chi è control, dentro studi factoriali / time-course / mediated_effect — più ricco di K-means+keyword (RummaGEO) e di "treatment field extraction" (Mondal et al.).
2. **Canonical comparability_anchor v3** (R puro, post-LLM): chiave deterministica `kind|agent_id|dose|time|cell_context|tissue` che permette pooling esatto cross-studio. Versionata. Auditabile.
3. **Effect-size meta-analysis** (Stadio 5): consumo dell'anchor da parte di `metafor` REM. Output finale = effect size pooled per anchor (con I², τ², CI). Non gene-set overlap.
4. **Sample-level granularity** che alimenta l'anchor: dose, duration, vehicle, mediated_effect, phase. Nessun competitor estrae questi al livello che la spec §3 prescrive.

Il framing corretto per simulomicsr non è "un altro annotatore di GEO" — quel campo è saturo e dominato da MetaHQ + ARCHS4 + Mondal. È: **"meta-analizzatore design-aware con canonical anchor cross-studio per pooling effect-size REM su RNAseq pubblico"**.

## Deliverable integrale: benchmark vs RummaGEO

Il benchmark testa-a-testa contro RummaGEO è **parte integrante** del progetto (non un'aggiunta opzionale post-hoc). Razionale: RummaGEO è il competitor end-to-end più vicino e l'unico modo di sostenere oggettivamente la tesi "LLM design inference + canonical anchor batte K-means+keyword + gene-set overlap" è misurarlo su un subset rappresentativo. Senza questo benchmark, qualunque paper o vignette sarà debole nelle conclusioni.

**Specifiche del benchmark (da implementare in P3.5 eval):**

- **Scope:** subset di 50-100 GSE estratti dallo xlsx 130k, stratificati per `design_kind` (treatment_vs_vehicle, knockout_vs_wt, time_course, factorial, disease_vs_normal).
- **Output 1 — accordo design_role:** matrice di confusione fra `design_role` di simulomicsr (collassato a treated/control via §6.2) e label `control` vs altri di RummaGEO. Metrica: accuracy, precision, recall, F1 per classe; breakdown per `design_kind` per evidenziare dove l'LLM batte K-means.
- **Output 2 — comparability anchor coverage:** quanti dei comparisons RummaGEO trovano un equivalente con stesso `comparability_anchor` simulomicsr cross-studio (intra-subset). Misura quanto l'anchor canonico aggiunge raggruppabilità.
- **Output 3 — pooling effect-size proper vs gene-set overlap:** su un anchor con ≥3 studi nel subset, confrontare (a) effect size pooled metafor REM da simulomicsr (`yi`+`vi`) vs (b) overlap di gene set RummaGEO. Mostrare se la stima REM è più informativa (CI stretti, I² interpretabile).
- **Codice:** `R/eval-rummageo.R` + target `eval_rummageo_benchmark` in `analysis/_targets.R` + report Quarto in `analysis/eval/rummageo-benchmark.Rmd`.
- **Timing:** dopo che `study_designs` e `comparisons_table` sono popolati nel subset di P3. Diventa un Task del plan P3.5 eval (insieme al gold design-aware su 200-300 sample).
- **Vincolo dati:** RummaGEO espone gene sets via API o bulk download. Verificare disponibilità di un dump strutturato (database SQLite o JSONL) ai primi target di P3.5.

## Aperto / da decidere quando matureranno

- **Integrare MetaHQ come upstream per tissue/disease normalization in Stadio 2.** Vantaggio: 188k sample annotati expert-level, propagazione ontologica via UBERON/MONDO. Costo: dipendenza Python esterna (`pip install metahq-cli`) o richiede caching di un dump TSV. Decisione: rimandata al primo punto di P3 in cui serve `normalize_tissue()`.

## Azioni immediate post-decisione

1. Aggiornare `README.md` con il positioning corretto ("design-aware meta-analyzer ... canonical comparability anchor ... not just another GEO annotator").
2. Citare ADR-0006 in `CLAUDE.md` § "Visione del progetto", § "Riferimenti chiave", § "Next step".
3. Aggiornare `docs/superpowers/specs/2026-04-29-classificatore-llm-design.md` aggiungendo §13 References con i paper citati nell'ADR.
4. Inserire benchmark vs RummaGEO come Task esplicito di P3.5 eval (insieme al gold design-aware su 200-300 sample).
5. Procedere con plan P3-B come previsto (schema + prompt + GEO fetch + classify_study + make_anchor + comparisons_table).

## Links

- [docs/superpowers/specs/2026-04-29-classificatore-llm-design.md](../superpowers/specs/2026-04-29-classificatore-llm-design.md) — spec classificatore v5.
- [docs/decisions/0005-server-migration-trigger.md](0005-server-migration-trigger.md) — trigger migrazione server (post-P3).
- [RummaGEO paper, Patterns 2024 (PMC11030343)](https://pmc.ncbi.nlm.nih.gov/articles/PMC11030343/).
- [MetaHQ preprint, arXiv 2602.07805 (marzo 2026)](https://arxiv.org/abs/2602.07805).
- [Multi-agent metadata curation, Mondal et al., bioRxiv 2025.06.10.658658](https://www.biorxiv.org/content/10.1101/2025.06.10.658658v1).
- [MetaSRA, Bernstein et al. 2017 (Bioinformatics)](https://academic.oup.com/bioinformatics/article/33/18/2914/3848915).
- [ARCHS4 help](https://maayanlab.cloud/archs4/help.html).
- [Ardigen LLM annotation pipeline (commercial blog)](https://ardigen.com/harnessing-large-language-models-llms-for-metadata-annotation-to-accelerate-biotech-and-pharma-research/).
