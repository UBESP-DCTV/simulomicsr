# Spec — Recupero-nome BIOLOGICI (citochine + patogeni) → Stadio 3 v6

**Data:** 2026-06-29 · **Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Status:** Implementato + validato pre-rebuild (design finale in §13, revisione post-smoke 2026-07-01) · **Sub-skill esecuzione:** `superpowers:subagent-driven-development`
**Deep research propedeutica:** `docs/findings/2026-06-29-deep-research-biologics-db.md`
**Verifica fonti ImmPort (2026-06-29, dati reali):** API ImmPort interrogata con API key utente
(scope `browse`) + cytokine registry-file fornito. Vedi §4.1 — l'incognita ImmPort è CHIUSA.
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
- LLM-fallback finale (DECISIONE C), precision-gated, sui residui `STR:`/`UNK` — passo FINALE
  dopo tutto il deterministico.
- K3 nel verso opposto (biologico → small_molecule): non aperto (precision-first, un fronte solo).
- Doppio-record "PAMP + organismo sorgente" (es. "LPS from E. coli"): limitazione nota (§11).

## 3. Decisioni (dal brainstorming, gate utente)

| # | Decisione | Scelta |
|---|---|---|
| D1 | Scope famiglie | **Entrambe** (citochine + patogeni) in v6 |
| D2 | Fonti citochine | **HGNC** (cache, nome→ID + alias/previous) + **UniProt** (sinonimi, *misurato*) + **ImmPort cytokine registry-file** (seed sinonimi: 275 cito / 4.896 alias / 250 con HGNC ID) + **GO cytokine-activity** (whitelist CC complementare) |
| D3 | Fonte patogeni | **NCBI Taxonomy** taxdump → `NCBITaxon:<taxid>` (primario); ImmPort `lkExposureMaterial`/`lkSpecies` come cross-check vernacolo |
| D4 | Fix-tipo K3 | **In questo v6** (solo `small_molecule`→biologico, solo su match forte) |
| D5 | Confine PAMP | **Whitelist curata → ChEBI ID**, kind `pathogen`, mai mergiato con l'organismo |
| D6 | ImmPort accesso | **Verificato (non più "al build")**: registry-file statico per i sinonimi + API key (scope `browse`) per `lkProteinName`/`lkExposureMaterial` come complemento. Vedi §4.1 |
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
| ImmPort cytokine registry | seed sinonimi citochine + whitelist | `analysis/p5-audit-immport-build-dict.R` | data-use agreement | **registry-file (.xls) + API key** |
| UniProt | sinonimi-proteina → HGNC (*misurato*) | `analysis/p5-audit-uniprot-build-dict.R` | CC BY 4.0 | anonimo |

**Loader:** estendo `.load_ontology_dicts` con flag graceful `has_taxonomy`/`has_immport`/
`has_uniprot`/`has_go_cytokine` (stessa logica `has_chembl`: dump assente → `NULL` + flag `FALSE`,
retrocompat byte-identica). Nuovi `.build_taxonomy_index`/`.build_immport_index`/
`.build_uniprot_index` + whitelist citochine (set) + accessor O(1) hash-env. Gli script v6 fanno
**assert-at-run** dei flag richiesti.

### 4.1 ImmPort — verifica fonti (2026-06-29, dati reali)

Interrogata l'API ImmPort con API key utente (scope `browse`, `Authorization: Bearer`) e ispezionato
il cytokine registry-file fornito. Esito:

- **Cytokine registry-file** `CytokineRegistry.November_2015.xls` (foglio `Registry`, 275 × 30):
  preservato in `analysis/p4-output/cytokine-registry-immport-2015.xls` (gitignored;
  `sha256:dc626e4e6ff9e4e848e7547be1a76a64f0f0f24cb0859c5520e07cd36cc01bcc`). **275 citochine**,
  **250 con HGNC ID**, 247 UniProt, 255 Protein Ontology, 103 MeSH. **4.896 sinonimi** (media 18/cito,
  max 104), distribuiti su colonne `EntrezGene Aliases/Additional Names (Human)`,
  `UniProt protein (alternative) names (Human)`, `Typographical variations`, `IX Synonyms`,
  `Protein Ontology synonyms`. Es. Interferon-beta → `HGNC:5434` con ~44 grafie (IFNB1, IFN-beta,
  beta interferon, ifn{beta}, fiblaferon…). → **è il seed di sinonimi**; build via `readxl`.
- **API `lkProteinName`** (841 proteine, di cui **207 citochine/chemochine/recettori** con
  `uniprot_gene_name`=HGNC symbol + `uniprot_id`): **whitelist citochine** complementare (no alias ricchi).
- **API `lkExposureMaterial`** (102, → `NCBITaxon:`/`VO:`/`UMLS_CUI:`), `lkSpecies` (24), `lkVirusStrain`
  (59): cross-check vernacolo patogeni (SARS-CoV-2→2697049, M.tuberculosis→1773, Influenza A→11320).
- **Smentito:** l'API NON espone il registry ricco; i ~4.896 sinonimi stanno SOLO nel registry-file.
- **Conferma architetturale:** ImmPort canonicalizza su HGNC+UniProt (citochine) e NCBITaxon (patogeni)
  = i nostri ID. Endpoint reali: `/data/query/api/lookup/<lkName>?format=json` (scope `browse`).

## 5. Estrazione + risoluzione (R/stage3-name-recovery.R)

**Normalizzazione condivisa** `.normalize_biological_mention()`: riuso `.extract_compound_candidates`
(strip dose/tempo/combo: `"TNFa 600nm"→"tnfa"`) + NFKC + mappa greco `α↔alpha`, `β↔beta`, `γ↔gamma`
+ collasso trattino/spazio (`"IFN-β"="ifn beta"="ifnb"`).

**Citochine** `.normalize_cytokine_to_hgnc(term, env)` (catena precisione-decrescente):
1. gate stoplist (§6) → generico ⇒ STR
2. **ImmPort registry synonym** → `HGNC:n` *(seed sinonimi greco/storici dal registry-file)*
3. HGNC symbol / alias / previous *(già in cache)* → `HGNC:n`
4. UniProt protein-name synonym → `HGNC:n` *(misurato; droppabile)*
5. gate whitelist: hit accettato solo se il gene ∈ whitelist citochine (**registry ∪ lkProteinName ∪
   GO cytokine-activity**) ⇒ altrimenti STR
6. miss → `STR:<slug>`
- **ID canonico = `HGNC:n`** (es. IFN-β → `HGNC:5434`).

**Patogeni** `.normalize_pathogen_to_taxid(term, env)`:
1. gate stoplist → generico ⇒ STR
2. **whitelist PAMP** → `CHEBI:n` + flag `pathogen_exposure` (controllata PRIMA di taxdump)
3. vernacolo curato (+ cross-check `lkExposureMaterial`): flu→Influenza, TB/Mtb→M. tuberculosis,
   SARS-CoV-2→2697049
4. taxdump names (scientific/synonym/common/genbank-common) → taxid
5. rollup a specie via `nodes.dmp` (strain→specie salvo strain esplicito)
6. miss → `STR:<slug>`
- **ID canonico = `NCBITaxon:<taxid>`** per gli organismi, `CHEBI:n` per i PAMP.

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
  `run_metadata$ontology_releases` esteso (taxdump-date / GO-release / ImmPort-registry-version /
  UniProt-release).
- **Incidentale:** micro-fix casing `ChEMBL:`/`CHEMBL:` (20 cluster) chiuso a questo rebuild.
- **Dipendenze:** `readxl` per il registry ImmPort (verificare in DESCRIPTION); taxdump/GO/UniProt =
  parsing base R; JSON API = `jsonlite` già presente — confermato al build.

## 9. Testing

TDD bite-sized (test→fail→impl→pass→commit), subagent-driven. Mini-fixtures nuove in
`inst/extdata/ontology-fixtures-mini/`: `taxonomy-mini.rds`, `immport-mini.rds` (sottoinsieme del
registry: IFN-β/IL-6/TNF con i loro alias), `go-cytokine-mini.rds`, `uniprot-mini.rds`. **Canary
obbligatori:** stoplist (interferon/virus/cytokine nudi → STR); K3 (no flip su small-molecule
generici). Final whole-branch review (opus) prima dei run gated.

## 10. Catena di run — tutti gate utente (clone sessione 21)

| # | Step | Costo | Gate |
|---|---|---|---|
| Build | build dizionari reali: taxdump/GO/UniProt anonimi + ImmPort registry-file (`.xls` fornito) + API `lkProteinName` (key utente) | minuti | file/key già forniti |
| Smoke | copertura PRE-fullrun sui `cytokine_stim`/`pathogen` `UNK`/`STR` reali (come Task 7 farmaci): % recupero + 0 falsi canary | minuti | **punto-decisione** |
| v6.A | re-cluster Stadio 3 v6 | ~6-7h | gate |
| v6.B | re-pool Stadio 4 v6 (output `/sda`, fix df-residui già committato) | ~10h | gate |
| v6.C | re-gate omogeneità v6 + closeout | minuti | gate |

**Criterio di successo:** `cytokine_stim` scende nettamente dal 61%; `pathogen` migliora dal 33%;
gli **altri kind non peggiorano** (disease 7,7% + small_molecule L0/L1 ~8% invariati). Lo **smoke è il
gate vero**: se il guadagno biologico non si materializza lì, ci si ferma prima dei run pesanti.

## 11. Known limitations / decisioni rinviate

- **Registry ImmPort statico (Nov 2015):** 275 citochine; le citochine descritte dopo il 2015 non
  hanno gli alias-ricchi del registry → coperte comunque da HGNC (cache, corrente) + UniProt come
  fallback. Accettabile (l'universo citochine è stabile).
- **`"LPS from E. coli"`**: risolve la porzione PAMP (→ChEBI), non genera un secondo anchor per
  l'organismo. Doppio-record = estensione futura.
- **UniProt droppabile**: incluso ma misurato nello smoke; se il contributo marginale è ~0, si rimuove
  prima del re-cluster.
- **ImmPort licenza**: registry-file sotto data-use agreement (NON committato nel repo; gitignored) +
  citazione (Bhattacharya et al., Sci Data 2018). Igiene attribuzioni per-sorgente nel supplementary.
- **Virus**: classe più difficile da risolvere (benchmark SPECIES) — verifica manuale del sottoinsieme.
- **LLM-fallback (DECISIONE C)**: passo finale, dopo questo v6.

## 12. Riferimenti

- Deep research: `docs/findings/2026-06-29-deep-research-biologics-db.md`.
- Codice riusabile: `R/stage3-name-recovery.R`, `R/ontology-lookup.R`, `R/stage3-anchor-levels.R`,
  `analysis/p4-fase-f6-stage3-reclustering.R`, `analysis/audit/stage3-homogeneity-check.R`.
- Pattern precedente: Plan B ChEMBL (`docs/superpowers/plans/2026-06-28-stage3-perturbative-name-recovery-B-plan.md`).
- ImmPort: registry-file `analysis/p4-output/cytokine-registry-immport-2015.xls` (gitignored,
  sha256 dc626e4e…); API `https://www.immport.org/data/query/api/lookup/` (scope `browse`);
  Bhattacharya et al., Sci Data 2018;5:180015.
- Memoria: `[[project_stage3_minestrone_rework]]`.

## 13. Revisione post-smoke (2026-07-01) — design finale K3 + fix di precisione

La FASE codice (Task 5-13) + i dizionari reali (Task 14-18) sono stati implementati come sopra.
Lo **smoke #1** (Task 19, gate decisionale) ha bocciato il rebuild (K3 8% falsi positivi, pathogen
3%). Sono stati applicati 4 fix (A/B/I1/D), ri-validati con ri-smoke + spot-check → **GO**. Il design
del **K3 è cambiato** rispetto a §5/§7 (che restano come progetto iniziale); la forma FINALE è questa.

**K3 — ramo `small_molecule` di `recover_identity` (compound-first, Fix-A):**
1. Risolvi PRIMA come composto (`.normalize_compound_to_chebi`).
2. Se `CHEBI:` singolo (non combo) ∈ `.PAMP_WHITELIST` → flip a `pathogen`, agent_id = quel CHEBI,
   source `K3_MISTYPE_pathogen_pamp` (preserva LPS/poly(I:C)/R848…).
3. Se `CHEBI:`/`CHEMBL:` (incl. combo) non-PAMP → **resta `small_molecule`, NESSUN flip** (elimina i
   falsi positivi su farmaci veri — era il difetto dell'8% smoke #1).
4. Solo se `STR:` (composto non risolto) → K3 last-resort: citochina (`HGNC:`) → patogeno
   (`NCBITaxon:`/PAMP) → altrimenti `small_molecule` STR. Helper `.is_pamp_chebi`.

**Estrazione patogeni (Fix-B + Fix-D):** `.AGENT_KEYS` esteso con `infection|infected|virus|pathogen|
inoculation|challenge|stimulant|"treatment agent"` (Fix-B), poi **trim di `organism` + chiavi morte**
`microbe|bacteria|bacterial|viral` (Fix-D I-1: `organism: human` in 747 sample sarebbe stato flippato a
`NCBITaxon:9606` Homo-sapiens-as-pathogen). `.PATHOGEN_VERNACULAR` da 5 a 25 voci (taxid verificati vs
dict reale; RSV/HCV corretti). `.HOST_SPECIES_STOPLIST` (Fix-D I-1b): `human|homosapiens|mouse|
musmusculus|rat|rattusnorvegicus|patient|donor|subject` → STR prima del taxdump (difesa host-species).
`.AGENT_CONTROL` esteso con i controlli infection-negative (Fix-D I-2).

**Coerenza anchor (Fix-I1):** l'innesto `recovery` (passo a) adotta `recovery$agent_id` forte
(`HGNC:`/`CHEBI:`/`NCBITaxon:`/`CHEMBL:`) anche quando l'anchor aveva `STR:` (non solo `UNK`), riducendo
la frammentazione `STR:` vs ID-forte. Retrocompat: caso `UNK` invariato, ID forti esistenti non toccati.

**Esiti validazione (dati reali, dir Stadio3 v5 `364547a7`):**
| Metrica | Smoke #1 | Ri-smoke (A+B+I1) | Spot-check (post-D) |
|---|---:|---:|---:|
| Cytokine recovery → `HGNC:` | 53,2% | 53,2% | (invariato) |
| Pathogen recovery forte | 3,0% | 7,8% | 8,0% |
| K3 falsi positivi (genuini) | 8,0% | 0 genuini | 0 |
| Host-species flip (organism:human) | n/d | n/d | **0 / 747** |
| Canary generici | 0/12 | 0/12 | 8/8 |

**Known limits aggiornati:** (a) pathogen residuo alto per nomi rumorosi/abbreviazioni non nel
vernacolo (IAV/COVID-19/RV16 → espansione vernacolo, TODO); (b) `uninf` (86 sample) non ancora in
`.AGENT_CONTROL` (trascurabile); (c) M-1 PAMP short-circuit CHEBI-dependent (PAMP risolti via CHEMBL o
sale non-whitelist non ri-tipizzati — nullo per i PAMP comuni); (d) whitelist citochine larga (927)
resa innocua per `small_molecule` da Fix-A (K3 solo su STR), invariata per il dispatch diretto
`cytokine_stim`.

**Commit fix:** Fix-A `0d2e413`, Fix-B `9ec6c74`, Fix-I1 `23f8913`, Fix-D `7933503`. Report:
`docs/findings/2026-07-01-stage3-biologics-smoke.md`. Ledger: `.superpowers/sdd/progress.md`.
