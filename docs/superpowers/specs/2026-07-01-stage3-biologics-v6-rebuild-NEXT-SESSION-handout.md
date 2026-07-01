# Handout — Prossima sessione: RUN GATED rebuild Stadio 3/4 v6 (biologici)

**Data:** 2026-07-01
**Per:** sessione fresh (i run pesanti si lanciano lì)
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato, pushato fino a HEAD)

> Tutto il CODICE, i DIZIONARI reali e i FIX di precisione sono implementati e **validati (GO)**.
> Manca SOLO la catena di 3 run pesanti (re-cluster → re-pool → re-gate). Lo script re-cluster v6 è
> già preparato e **smoke-validato** (SMOKE=1 PASS). Questa sessione ha deciso: "prepara ma non
> lanciare, il full in sessione fresh".

## In una frase
Lanciare il **re-cluster Stadio 3 v6** (~6-7h), poi il **re-pool Stadio 4 v6** (~10h), poi il
**re-gate omogeneità v6**, per materializzare il de-minestronamento dei biologici (citochine 61% →
atteso giù; patogeni 33% → atteso giù) — tutto già validato allo smoke.

## Stato verificato (fine sessione 2026-07-01)
- **Codice** (FASE 1-3, 13 task TDD+review + Fix A/B/I1/D): completo. Dizionari taxonomy/ImmPort/
  UniProt/GO + `.normalize_cytokine_to_hgnc`/`.normalize_pathogen_to_taxid` + K3 compound-first + anchor
  `NCBITaxon:` + cache v3. Suite verde.
- **Dizionari reali** in `~/.cache/R/simulomicsr/`: `taxonomy/taxonomy-lookup.rds` (3.35M nomi),
  `immport/immport-lookup.rds` (5046 syn / 927 whitelist, `has_go=TRUE`), `uniprot/uniprot-lookup.rds`
  (68.805 syn), + chembl/chebi/hgnc/mesh già presenti. **Tutti `has_* TRUE`.**
- **Validazione (GO)**: smoke#1 NO-GO → Fix A/B/I1 → ri-smoke GO (cytokine 53%, pathogen 3→8%, K3 0
  falsi genuini) → final review Opus (I-1/I-2) → Fix-D (chiuso Homo-sapiens-as-pathogen 0/747) →
  spot-check GO. Design finale in **spec §13**; report `docs/findings/2026-07-01-stage3-biologics-smoke.md`.
- **Script re-cluster v6 PRONTO** (`analysis/p4-fase-f6-stage3-reclustering.R`, commit `0e9bb96`): assert
  `has_taxonomy/immport/uniprot/chembl` fail-fast + token v6. Smoke SMOKE=1 PASS: HGNC:=1155, NCBITaxon:,
  K3_MISTYPE attivi.

## I 3 run (tutti GATE UTENTE)

### Run 1 — re-cluster Stadio 3 v6 (~6-7h, locale detached)
```bash
cd /home/user/simulomicsr
# pre-flight (già nello script, ma verificabile): .load_ontology_dicts()$has_taxonomy/immport/uniprot == TRUE
SMOKE=0 Rscript analysis/p4-fase-f6-stage3-reclustering.R
```
- Wall REALE atteso **~6-7h** (NON i "90-120 min" della stima: la Phase 6 `summarize_clusters` su ~317k
  cluster domina, come v4/v5). Lanciare **detached** (nohup/background) + log.
- Output: `analysis/p4-output/…-stage3-v6-<id>/` (gitignored). Verificare `run_metadata.json`: dizionari
  biologici + recovery source (CYTOKINE_IMMPORT/PAMP_WHITELIST/K3_MISTYPE_*/PATHOGEN_TAXID) + sanity
  agent_id (`HGNC:` citochine, `NCBITaxon:` patogeni).
- NB: primo **load ontologie ~5 min** (taxonomy 2.85M list objects — concern noto, assorbito dal wall).

### Run 2 — re-pool Stadio 4 v6 (~10h, output su /sda)
- **PRIMA preparare** `analysis/p4-fase-f5-stage4-layer-a-rebuild-v6.R` = copia di `-v5` con 4 cambi:
  `stage3_dir`→dir v6, `out_dir`→`/sda/simulomicsr-stage4-v6/` + token v6, 2 log. Smoke DRY_RUN, poi full
  detached. Fix df-residui **già committato** (non ri-crasha).
- Output `/sda/simulomicsr-stage4-v6/…-stage4-v6-<id>/`.

### Run 3 — re-gate omogeneità v6 + closeout
```bash
Rscript analysis/audit/stage3-homogeneity-check.R <dir-v6> analysis/input/human_gene_v2.5.h5 Inf Inf <stage2-master-v3>
```
- **Criterio**: `cytokine_stim` scende nettamente dal 61%; `pathogen` migliora dal 33%; disease (7,7%) e
  small_molecule (L0/L1 ~8%) INVARIATI. Output `-v6-full-out.{txt,csv}`. Finding
  `docs/findings/…-stage3-v6-biologics-homogeneity.md`. Aggiornare CLAUDE.md + ledger + memoria.

## Attesi (dallo smoke/spot-check su dati reali)
- Cytokine recovery ~**53%** → `HGNC:` (driver ImmPort). Pathogen recovery ~**8%** → `NCBITaxon:`/`CHEBI:`.
- **0 falsi K3 genuini**, **0 flip host-species** (organism:human), canary generici puliti.

## TODO residui (NON bloccanti per il rebuild)
- **Pathogen residuo alto** (~61% UNK): espandere `.PATHOGEN_VERNACULAR` (IAV colloquiale, COVID-19, RV16,
  ceppi) — alza ulteriormente il recupero patogeni.
- `uninf` (86 sample) non in `.AGENT_CONTROL` (trascurabile).
- M-1: PAMP risolti via CHEMBL/sale non-whitelist non ri-tipizzati (nullo per PAMP comuni).
- LLM-fallback finale (DECISIONE C) sui residui STR/UNK — passo FINALE dopo i biologici.

## Note operative
- **Dischi**: grezzi/dump su `/mnt/wwn-0x5000039d58caca35/simulomicsr-biolex-build/`; Stadio 4 output su
  `/sda` (NVMe `/` ha ~91G, non basta per stage4). Registry ImmPort xls in `analysis/p4-output/` (gitignored).
- **Ledger** completo: `.superpowers/sdd/progress.md` (tutti i task + fix + smoke).
- **Spec** design finale: `docs/superpowers/specs/2026-06-29-stage3-biologics-name-recovery-design.md` §13.
- Memoria: `[[project_stage3_minestrone_rework]]`.
