# Dichiarazione di disponibilità di dati e codice — BOZZA

**Data:** 2026-08-21 (sessione S2) · **Stato:** bozza; i campi fra `[...]` sono
decisioni o DOI ancora da prendere/ottenere. Il testo per l'articolo è in inglese;
le note in italiano non vanno nell'articolo. Versione del pacchetto: 0.0.0.9028;
commit di riferimento al momento della bozza: `d4117012` (branch
`review-scientific-consistency-2026-06-10`). Il deliverable descritto è A3 v16
(194 meta-analisi); se S13/S14 lo cambiano, i numeri di questa bozza vanno rifatti.

---

## Data and code availability (draft for the manuscript)

**Code.** `simulomicsr` is an R package implementing the full pipeline (ETL from
ARCHS4, LLM-based sample and study-design classification, contrast-derived
clustering, and random-effects pooling). Source code is available at
https://github.com/UBESP-DCTV/simulomicsr under the Creative Commons Attribution-NonCommercial 4.0 International
(CC BY-NC 4.0) license [or PolyForm Noncommercial 1.0.0 for the code — see note 1]; the exact version used for the results reported
here is archived at Zenodo ([DOI **to be obtained**], package version 0.0.0.9028,
git tag [**to be created**]). The repository also includes the `renv` lockfile,
the prompts and JSON schemas used at every LLM stage, the deterministic gate and
pairing rules, the audit scripts, and the decision records (ADRs) documenting
every methodological choice.

**Input data.** Expression counts and sample metadata were taken from ARCHS4
v2.5 (human, gene-level; `human_gene_v2.5.h5`, 47.9 GB, MD5
`d61ae9b5074639d5c962c2414251c865`), publicly available at
https://maayanlab.cloud/archs4/ (Lachmann et al., 2018). GEO series-level
metadata were retrieved through NCBI E-utilities. No new sequencing data were
generated.

**Language model.** All classification stages used the openly released
`mistralai/Mistral-Small-3.2-24B-Instruct-2506` (Apache-2.0), served locally
with vLLM v0.20.2 at temperature 0.0 with structured (JSON-schema) outputs and
`VLLM_BATCH_INVARIANT=1`; no proprietary model and no external API was used at
any stage of the pipeline or its published validation.

**Intermediate and final outputs** are deposited at [Zenodo / **to be decided**,
see note 2] ([DOI **to be obtained**]) with a SHA-256 manifest of every file:

| artefact | content | size |
|---|---|---|
| Stage 1 | per-sample structured facts for 508,037 ARCHS4 human bulk samples (`sample_facts.stage1.v3`) | 1.9 GB (JSONL) |
| Stage 2 | one design record per study for 24,394 GEO series (`stage2.v2`) | 85 MB (JSONL) |
| Stage 3 | contrast-derived clusters, assignments, and `run_metadata.json` with ontology releases | 36 MB |
| Stage 4 | per-study differential expression (limma-voom), pooled random-effects estimates per cluster, QC registers (`qc_report`), and the annotated deliverable table (194 meta-analyses, with `k_eff`, `k_kish`, dominance and coherence verdicts) | 1.3 GB (Parquet/CSV) |
| gold standards | manually curated treatment/control labels for 130,784 samples (`trtctr_EP`); design-aware mini-gold of 100 samples; LLM-assisted gold of 756 samples / 72 studies | in the repository (`data-raw/`, `inst/extdata/`) |
| ontology snapshots | ChEBI (built 2026-05-24), ChEMBL 37, MeSH, HGNC, NCBI Taxonomy (2026-07-01), ImmPort, UniProt/Swiss-Prot human (2026-06-10) lookups used for name recovery | 150 MB |
| per-cluster audit | the 194 per-meta-analysis review sheets and the verdict table underlying the correctness figures | in the repository (`analysis/audit/2026-08-20-rilettura-194/`) |

The deterministic stages (ETL, Stage 3 clustering, Stage 4 pooling) can be
re-executed from the deposited Stage 1/2 outputs with the commands documented
in the repository; re-running the LLM stages reproduces a run bit-for-bit only
under the same vLLM version, hardware class and batch-invariant setting, and is
not expected to reproduce the deposited outputs exactly (see Methods, §
[Reproducibility]).

---

## Note (italiano, non vanno nell'articolo)

1. **Licenza — decisa dall'utente il 2026-08-21: CC BY-NC 4.0 «o simile».**
   `LICENSE` oggi dice ancora «Copyright 2021 UBEP. All rights reserved.» e
   `DESCRIPTION` ha `License: file LICENSE`: vanno aggiornati (`License: CC BY-NC 4.0`
   è riconosciuta da R; il testo della licenza va in `LICENSE`). Due avvertenze
   prima di farlo: (a) Creative Commons sconsiglia le proprie licenze per il
   software (nessuna clausola su brevetti e sorgente); l'equivalente non
   commerciale scritto per il codice è **PolyForm Noncommercial 1.0.0** — si può
   usare CC BY-NC 4.0 per i dati depositati e PolyForm NC per il pacchetto;
   (b) NC non è open source secondo OSI, e alcune riviste (es. PLOS, Bioinformatics)
   chiedono licenza OSI per il codice: controllare la policy della rivista.
   Atto formale di UBEP, non di una sessione.
2. **Dove depositare.** Zenodo accetta 50 GB per record (estendibili) e dà DOI
   versionato: basta per tutto tranne l'H5 (che è pubblico e non va ridepositato).
   Alternativa: figshare. Decidere anche **se depositare `per_study_de.parquet`**
   (1,1 GB, 32 milioni di righe): è ciò che rende ricalcolabile ogni pooled
   estimate senza rifare limma-voom; *preferenza: sì*.
3. **Depositare anche il riferimento v16b (211)?** È il termine di confronto di
   tutte le analisi comparative (rilettura 194, movimento Stadio 3). Se
   l'articolo riporta quei confronti, va depositato; *preferenza: sì, come
   record separato o sottocartella `reference/`*.
4. **I master Stadio 1/2 contengono testo GEO** (metadati pubblici): nessun
   problema di licenza noto, ma va citata la GEO policy.
5. **Le schede delle 194** e i verdetti dipendono da S3 (riproducibilità della
   lettura): se S3 cambia i numeri, qui cambia la riga «per-cluster audit».
6. **Controllo interno prima del deposito:** `10-manifesto-e-copia.sh verifica`
   (`analysis/audit/2026-08-21-S2-deliverable-in-salvo/`) deve dare 73/73 sul
   materiale da caricare; il manifesto stesso va incluso nel record.
7. **Riferimenti da aggiungere:** Lachmann A. et al., *Nat Commun* 2018 (ARCHS4);
   vLLM; Mistral Small 3.2 model card; `limma`/`voom`; `metafor`.
