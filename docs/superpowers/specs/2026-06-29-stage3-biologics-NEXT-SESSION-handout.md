# Handout — Prossima sessione: recupero-nome BIOLOGICI (citochine + patogeni) → Stadio 3 v6

**Data:** 2026-06-29
**Per:** prossima sessione (sessione pulita)
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)

> Scritto in prosa semplice. Questo handout **imposta** il lavoro sui biologici; non lo
> risolve. Il primo passo è una **deep research dedicata** (che oggi NON esiste ancora).

---

## In una frase

Il rework farmaci (ChEMBL → v5) ha sciolto il minestrone delle **small molecule**, ma i
**biologici** — **citochine** (es. IFN-β, IL-6, TNF) e **patogeni/esposizioni** (virus,
batteri, LPS, TLR-agonisti) — sono ancora minestrone perché **non hanno un dizionario
nome→ID** come ChEMBL. Questa sessione apre quel filone: prima una deep research sulle
fonti, poi (se vale) il recupero-nome biologici come è stato fatto per i farmaci.

## Dove siamo (stato verificato a fine sessione 21)

Dal gate di omogeneità v5 (`analysis/audit/stage3-homogeneity-check-v5-full-out.txt`):

| kind | minestrone v5 | commento |
|---|---:|---|
| `disease_vs_normal` | 7,7% | risolto (MeSH, rework v4) |
| `small_molecule` | 36,5% globale / **~8% a L0/L1** | risolto al livello granulare (ChEMBL, rework v5) |
| **`cytokine_stim`** | **61,2%** | **NON toccato** dal rework — è il target di questa sessione |
| **`pathogen_or_aggregate_exposure`** | **33,0%** | parzialmente migliorato di rimbalzo, ma senza un suo dizionario |

I biologici erano **esplicitamente fuori scope** dal Plan B (farmaci). Vedi
`docs/findings/2026-06-29-stage3-v5-chembl-homogeneity.md` §TODO e
`[[project_stage3_minestrone_rework]]`.

## Il problema, in concreto (due sotto-problemi distinti)

1. **Mancanza di un dizionario nome→ID per i biologici.** Per i farmaci avevamo ChEBI+ChEMBL.
   Per le citochine e i patogeni serve decidere QUALE fonte usare (è ciò che la deep research
   deve stabilire). Candidati noti — **da validare, non dare per buoni**:
   - Citochine (proteine): **UniProt**, **HGNC** (i geni citochina li abbiamo già), eventuali
     vocabolari immunologici (ImmPort / Cytokine Registry / Gene Ontology immune).
   - Patogeni (organismi): **NCBI Taxonomy** (virus/batteri); alcuni PAMP/TLR-agonisti
     (poly(I:C), LPS, Resiquimod) sono già in **ChEBI** con i ruoli giusti.
2. **Mis-tipizzazione (il "fix-tipo K3").** Diversi biologici sono oggi etichettati come
   `small_molecule` dall'LLM quando dovrebbero essere `cytokine_stim`/`pathogen`: es. **LPS,
   TNF, IL-4**. Vanno ri-tipizzati. Questo è in parte ortogonale al dizionario: è una regola
   di correzione del `kind`, analoga al K2 (degron→genetic) già fatto.

## Cosa fare (sequenza proposta, tutti GATE UTENTE)

### Passo 0 — Deep research DB biologici (PRIMO task, NON esiste ancora)
Lanciare la skill `deep-research` con una domanda mirata, **sul modello di quella fatta per i
farmaci**. Riferimenti-template:
- Report farmaci: `docs/findings/2026-06-28-deep-research-small-molecule-db.md`
- Prompt usato: `docs/superpowers/specs/2026-06-28-deep-research-small-molecule-db-prompt.md`

Domande che la deep research biologici deve chiudere:
- Qual è la/le fonte/i **redistribuibile/i** (licenza!) con la miglior copertura nome→ID per
  **citochine** (sinonimi, alias, simboli) e per **patogeni** (virus/batteri/ceppi)?
- Come si normalizza una citochina a un ID canonico (UniProt? HGNC? un ID dedicato)? E un
  patogeno (NCBI Taxonomy ID)?
- I **TLR-agonisti / PAMP / adiuvanti** (poly(I:C), LPS, R848…) stanno meglio in ChEBI (ruolo)
  o in una fonte dedicata? Dove tracciamo il confine small_molecule ↔ pathogen_exposure?
- Quanto è grande il guadagno atteso? (misurabile con uno **smoke sul residuo reale**, come il
  Task 7 dei farmaci: prendere i cytokine_stim/pathogen UNK/STR e vedere quanti si recuperano.)

### Passo 1 — Brainstorming + spec/plan (gate utente)
Come per i farmaci: definire scope (citochine? patogeni? entrambi?), granularità, gating di
precisione, e se il fix-tipo K3 va in questa sessione o separato. Spec/plan/HUMANE in
`docs/superpowers/{specs,plans}/`.

### Passo 2 — Codice (TDD, subagent-driven) + smoke copertura
Clonare il pattern ChEMBL: dizionario nome→ID offline + estrazione + risoluzione con
**stoplist** anti-generici + gating precisione-prima (meglio NO_RECOVERY che merge dubbio).
Smoke copertura PRE-fullrun (validate-before-fullrun).

### Passo 3 — Run gated → Stadio 3 v6 → Stadio 4 v6 → re-gate
Stessa catena della sessione 21 (re-cluster ~6-7h → re-pool ~11h su `/sda` → gate omogeneità).
Criterio: `cytokine_stim` scende nettamente dal 61%; `pathogen` migliora; altri kind non
peggiorano. Output audit `-v6-full-out`.

## Relazione con l'LLM-fallback finale (DECISIONE C)

Dopo TUTTO il recupero deterministico (MeSH malattie + ChEMBL/ChEBI farmaci + **questo**
vocabolario biologici), i residui `STR:`/`UNK` rimasti si tentano con un **LLM precision-gated**
(propone, ma la decisione è validata contro ontologia). È il passo FINALE, brainstorming
dedicato, **dopo** i biologici. Infrastruttura eval già pronta:
`analysis/audit/name-recovery-llm-benchmark.R`.

## Riferimenti
- Stato sessione 21 + risultato v5: `CLAUDE.md` (header), `.superpowers/sdd/progress.md`,
  `docs/findings/2026-06-29-stage3-v5-chembl-homogeneity.md`.
- Template metodologico farmaci: `docs/findings/2026-06-28-deep-research-small-molecule-db.md`
  + `docs/superpowers/specs/2026-06-28-deep-research-small-molecule-db-prompt.md`.
- Memoria: `[[project_stage3_minestrone_rework]]`.
- Codice riusabile: `R/stage3-name-recovery.R` (estrazione + stoplist + gating),
  `R/ontology-lookup.R` (loader dizionari), `R/stage3-anchor-levels.R` (K2/K3-style fix-tipo),
  `analysis/p4-fase-f6-stage3-reclustering.R` (re-cluster), `analysis/audit/stage3-homogeneity-check.R` (gate).

## Nota onesta (perché questo handout esiste)
A inizio sessione si pensava esistesse già una deep research sui biologici: **non c'è**. Quella
in `findings` è sui **farmaci**. Per questo il Passo 0 è proprio fare la deep research biologici.
