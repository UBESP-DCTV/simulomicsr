# Spec — Recupero-nome BIOLOGICI (citochine + patogeni) → Stadio 3 v6

**Data:** 2026-06-29 · **Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Status:** Proposed · **Sub-skill esecuzione:** `superpowers:subagent-driven-development`
**Deep research propedeutica:** `docs/findings/2026-06-29-deep-research-biologics-db.md`
**Handout origine:** `docs/superpowers/specs/2026-06-29-stage3-biologics-NEXT-SESSION-handout.md`

---

## 1. Problema

Il rework farmaci (ChEMBL → Stadio 3 v5) ha sciolto il minestrone delle small molecule al
livello granulare (L0/L1 ~8% ≈ disease 7,7%). Restano minestrone i **biologici**, che non hanno
un dizionario nome→ID come ChEMBL/ChEBI/MeSH. Dal gate omogeneità v5
(`analysis/audit/stage3-homogeneity-check-v5-full-out.txt`):

| kind | minestrone v5 | stato |
|---|---:|---|
| `disease_vs_normal` | 7,7% | risolto (MeSH, v4) |
| `small_molecule` | 36,5% globale / ~8% L0/L1 | risolto granulare (ChEMBL, v5) |
| **`cytokine_stim`** | **61,2%** | **target v6** |
| **`pathogen_or_aggregate_exposure`** | **33,0%** | **target v6** |

Due sotto-problemi distinti:
1. **Mancanza di dizionario nome→ID** per citochine (proteine) e patogeni (organismi).
2. **Mis-tipizzazione (K3):** biologici (LPS, TNF, IL-4) oggi etichettati `small_molecule` dall'LLM.

## 2. Scope

**In scope (un solo v6):**
- Citochine **e** patogeni insieme (un re-cluster + un re-pool; infrastruttura condivisa).
- Fix-tipo **K3** (`small_molecule` → `cytokine_stim`/`pathogen` su match forte).
- Confine deterministico PAMP/adiuvante.

**Out of scope (sessioni future):**
- LLM-fallback finale (DECISIONE C), precision-gated, sui residui `STR:`/`UNK` — è il passo
  FINALE dopo tutto il deterministico.
- K3 nel verso opposto (biologico → small_molecule): non aperto (precision-first, un fronte solo).
- Doppio-record "PAMP + organismo sorgente" (es. "LPS from E. coli"): limitazione nota (§9).

## 3. Decisioni (dal brainstorming, gate utente)

| # | Decisione | Scelta |
|---|---|---|
| D1 | Scope famiglie | **Entrambe** (citochine + patogeni) in v6 |
| D2 | Fonti citochine | **HGNC** (cache, nome→ID) + **UniProt** (sinonimi, *misurato*) + **GO cytokine-activity** (whitelist CC) + **ImmPort** (seed primario sinonimi, via API key) |
| D3 | Fonte patogeni | **NCBI Taxonomy** taxdump → `NCBITaxon:<taxid>` |
| D4 | Fix-tipo K3 | **In questo v6** (solo `small_molecule`→biologico, solo su match forte) |
| D5 | Confine PAMP | **Whitelist curata → ChEBI ID**, kind `pathogen`, mai mergiato con l'organismo |
| D6 | ImmPort accesso | **Build gated**: l'utente crea API key (scope `browse`) / usa Swagger; schema verificato al build |
| D7 | Approccio architetturale | **A** — clone fedele del pattern `ontology-lookup` (una fonte = un indice = un test = un dump tracciabile) |

**ID canonici:** citochina = `HGNC:n`; organismo = `NCBITaxon:<taxid>`; PAMP = `CHEBI:n`.
Namespace `HGNC:` già emesso dal K2 → riuso con `kind=cytokine_stim`. `NCBITaxon:` è nuovo.

## 4. Architettura delle fonti (R/ontology-lookup.R)

**Riuso (zero build):** HGNC (già caricato: `by_symbol_lower` + `aliases_long`), ChEBI (PAMP ID).

**Nuove fonti (build-script gated, pattern ChEMBL Task 6):**

| Fonte | Ruolo | Build script | Licenza | Accesso |
|---|---|---|---|---|
| NCBI taxdump | patogeni nome→taxid (rank specie/sotto) | `analysis/p5-audit-taxonomy-build-dict.R` | ≈public domain | anonimo (FTP) |
| GO cytokine-activity | whitelist "è-citochina" (GAF) | `analysis/p5-audit-go-cytokine-build-dict.R` | CC BY | anonimo |
| ImmPort registry | seed primario sinonimi citochine + whitelist | `analysis/p5-audit-immport-build-dict.R` | data-use agreement | **API key (utente)** |
| UniProt | sinonimi-proteina → HGNC (*misurato*) | `analysis/p5-audit-uniprot-build-dict.R` | CC BY 4.0 | anonimo |

**Loader:** estendo `.load_ontology_dicts` con flag graceful `has_taxonomy`/`has_immport`/
`has_uniprot`/`has_go_cytokine` (stessa logica `has_chembl`: dump assente → `NULL` + flag `FALSE`,
retrocompat byte-identica). Nuovi `.build_taxonomy_index`/`.build_immport_index`/
`.build_uniprot_index` + whitelist citochine (set) + accessor O(1) hash-env. Gli script v6 fanno
**assert-at-run** dei flag richiesti.

**ImmPort (D6):** le controlled-vocabulary ImmPort sono pubbliche (`Authorization Required: No`,
pattern `/data/query/api/lookup/<nome>?format=json`); per il resto basta API key scope `browse`
(`immport.org/auth/api/keys`). Path esatto dell'endpoint registry + schema campi si fissano al
build sui dati reali (come lo schema SQL ChEMBL al Task 6). Fonte deriva da HGNC/UniProt/MeSH/PRO.

## 5. Estrazione + risoluzione (R/stage3-name-recovery.R)

**Normalizzazione condivisa** `.normalize_biological_mention()`: riuso `.extract_compound_candidates`
(strip dose/tempo/combo) + NFKC + mappa greco `α↔alpha`, `β↔beta`, `γ↔gamma` + collasso
trattino/spazio (`"IFN-β"="ifn beta"="ifnb"`).

**Citochine** `.normalize_cytokine_to_hgnc(term, env)` (catena precisione-decrescente):
1. gate stoplist (§6) → generico ⇒ STR
2. ImmPort synonym → `HGNC:n`
3. HGNC symbol / alias / previous → `HGNC:n`
4. UniProt protein-name synonym → `HGNC:n` (*misurato; droppabile*)
5. gate whitelist: hit accettato solo se il gene ∈ whitelist citochine (**ImmPort ∪ GO**) ⇒ altrimenti STR
6. miss → `STR:<slug>`

**Patogeni** `.normalize_pathogen_to_taxid(term, env)`:
1. gate stoplist → generico ⇒ STR
2. **whitelist PAMP** → `CHEBI:n` + flag `pathogen_exposure` (controllata PRIMA di taxdump)
3. vernacolo curato (flu→Influenza, TB/Mtb→M. tuberculosis, SARS-CoV-2→2697049)
4. taxdump names (scientific/synonym/common/genbank-common) → taxid
5. rollup a specie via `nodes.dmp` (strain→specie salvo strain esplicito)
6. miss → `STR:<slug>`

**Orchestrazione `recover_identity`:** ramo perturbativo per `kind` →
`cytokine_stim`:`normalize_cytokine_to_hgnc`; `pathogen`:`normalize_pathogen_to_taxid`;
`small_molecule`: resta `compound` (ChEBI/ChEMBL come v5) **+ check K3** (§7). Disease/genetico
**invariati**. Fallback `STR:` identico a oggi.

## 6. Gate di precisione — stoplist biologici

Estendo il meccanismo `.GENERIC_COMPOUND_STOPLIST` (quello che azzerò i 7 match spurî farmaci) con
una lista dedicata: `cytokine(s)`, `interferon`, `interleukin`, `chemokine`, `growth factor`,
`virus`, `viral`, `bacteria`, `bacterium`, `bacterial`, `pathogen`, `infection`, `stimulation`,
`stimulus`, `exposure`, `ligand`, `tlr`, `agonist`. Mai match da soli — serve token discriminante
(numero, lettera greca, epiteto di specie). Più la **regola alias-corti**: alias `<3 char` o alias
che è approved-symbol di un gene diverso → rifiutato (chiude "IFN"/"IL-1" ambigui).

## 7. Fix-tipo K3 + confine PAMP (R/stage3-anchor-levels.R)

**`.detect_biological_mistype(term, llm_kind, env)`** (clone del K2, dove sta il K2):
- Attiva **solo** se `llm_kind == "small_molecule"`.
- Prova `normalize_cytokine_to_hgnc` → hit forte (whitelist, non STR) ⇒ `kind="cytokine_stim"` + `HGNC:n`.
  Altrimenti PAMP-whitelist/taxdump → hit forte ⇒ `kind="pathogen"` + `CHEBI:`/`NCBITaxon:`.
  Altrimenti NULL = nessun override.
- **Override solo su match esatto di dizionario/whitelist, mai su STR** (principio K2: override solo
  su segnali inequivocabili; evita il flip spurio tipo bug C1).

**`.PAMP_WHITELIST`** (vettore curato, corto, versionato, human-readable, slug→ChEBI): lps/
lipopolysaccharide, poly(i:c), r848/resiquimod, imiquimod/r837, pam3csk4, pam2csk4, fsl-1, cpg odn,
flagellin, mpla, mdp, zymosan, beta-glucan. Membership = appartenenza alla whitelist (deterministica).
Al **build** validiamo una-tantum che ogni ChEBI ID abbia role adjuvant/immunostimulant nella
role-hierarchy (sanity, non a runtime). Identità = ChEBI ID (cache); kind = pathogen; mai mergiato
con l'organismo (whitelist PAMP prima di taxdump).

## 8. Integrazione, cache, anchor, versioning

- **Anchor:** `NCBITaxon:<taxid>` nuovo namespace accanto a `MeSH:`/`CHEBI:`/`CHEMBL:`/`HGNC:`/`STR:`.
  Aggiorno round-trip `make_anchor`/`.extract_anchor_segments` + `test-anchor-parse.R`.
- **Cache lookup `v2 → v3`**, con `has_taxonomy`/`has_immport`/`has_uniprot`/`has_go_cytokine` **nella
  chiave** (difensivo come `has_chembl`: mai servire cache costruita con meno fonti).
- **Versioning:** resolver `v1.1.0 → v1.2.0`; anchor `v3.1.1 → v3.2` (nuovo namespace).
  `run_metadata$ontology_releases` esteso (taxdump-date / GO-release / ImmPort-version / UniProt-release).
- **Incidentale:** micro-fix casing `ChEMBL:`/`CHEMBL:` (20 cluster) chiuso a questo rebuild.
- **Dipendenze:** verosimilmente nessuna nuova (taxdump/GO/UniProt = parsing base R; JSON ImmPort =
  `jsonlite` già presente) — confermato al build.

## 9. Testing

TDD bite-sized (test→fail→impl→pass→commit), subagent-driven. Mini-fixtures nuove in
`inst/extdata/ontology-fixtures-mini/`: `taxonomy-mini.rds`, `immport-mini.rds`, `go-cytokine-mini.rds`,
`uniprot-mini.rds` (IFN-β/IL-6/TNF + LPS/poly(I:C) + SARS-CoV-2/M.tuberculosis + canary generici).
**Canary obbligatori:** stoplist (interferon/virus/cytokine nudi → STR); K3 (no flip su small-molecule
generici). Final whole-branch review (opus) prima dei run gated.

## 10. Catena di run — tutti gate utente (clone sessione 21)

| # | Step | Costo | Gate |
|---|---|---|---|
| Build | download+build dizionari reali (taxdump/GO/UniProt anonimi; ImmPort via API key utente) + verifica schema | minuti | utente fornisce key ImmPort |
| Smoke | copertura PRE-fullrun sui `cytokine_stim`/`pathogen` `UNK`/`STR` reali (come Task 7 farmaci): % recupero + 0 falsi canary | minuti | **punto-decisione** |
| v6.A | re-cluster Stadio 3 v6 | ~6-7h | gate |
| v6.B | re-pool Stadio 4 v6 (output `/sda`, fix df-residui già committato) | ~10h | gate |
| v6.C | re-gate omogeneità v6 + closeout | minuti | gate |

**Criterio di successo:** `cytokine_stim` scende nettamente dal 61%; `pathogen` migliora dal 33%;
gli **altri kind non peggiorano** (disease 7,7% + small_molecule L0/L1 ~8% invariati). Lo **smoke è il
gate vero**: se il guadagno biologico non si materializza lì, ci si ferma prima dei run pesanti.

## 11. Known limitations / decisioni rinviate

- **`"LPS from E. coli"`**: risolve la porzione PAMP (→ChEBI), non genera un secondo anchor per
  l'organismo. Doppio-record = estensione futura.
- **UniProt droppabile**: incluso ma misurato nello smoke; se il contributo marginale è ~0, si rimuove
  prima del re-cluster.
- **ImmPort licenza**: derivato redistribuibile sotto "commensurate terms" + citazione (Bhattacharya
  et al., Sci Data 2018); igiene attribuzioni per-sorgente nel supplementary.
- **Virus**: classe più difficile da risolvere (benchmark SPECIES) — verifica manuale del sottoinsieme.
- **LLM-fallback (DECISIONE C)**: passo finale, dopo questo v6.

## 12. Riferimenti

- Deep research: `docs/findings/2026-06-29-deep-research-biologics-db.md`.
- Codice riusabile: `R/stage3-name-recovery.R`, `R/ontology-lookup.R`, `R/stage3-anchor-levels.R`,
  `analysis/p4-fase-f6-stage3-reclustering.R`, `analysis/audit/stage3-homogeneity-check.R`.
- Pattern precedente: Plan B ChEMBL (`docs/superpowers/plans/2026-06-28-stage3-perturbative-name-recovery-B-plan.md`).
- Memoria: `[[project_stage3_minestrone_rework]]`.
