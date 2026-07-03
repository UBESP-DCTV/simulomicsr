# Finding — Stadio 3 v7: fix estrazione pathogen (dose/tempo/verbo) + materializzazione

**Data:** 2026-07-03/04
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato, no push)
**Commit codice:** `1fb1520` (fix estrazione) + `409aa0a` (bump cache lookup v3→v4)
**Deliverable v7:** Stadio 3 `analysis/p4-output/20260703T113045Z-stage3-v7-364547a7/` +
Stadio 4 `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v7/20260703T230632Z-stage4-v7-4f7ea215/`

## Sintesi

Il re-gate omogeneità v6 (post-recupero biologici) aveva mostrato **pathogen in
regressione** (v5 33% → v6 43,9% minestroni), unico kind peggiorato. Indagine
data-driven → il residuo pathogen **non era un buco di vocabolario ma di
estrazione**. Il fix (candidate-extraction sul path pathogen) porta **pathogen
43,9% → 11,2%** nei cluster v7 reali — ribaltando la regressione in un netto
miglioramento (vicino a disease 7,7%, meglio di v5 33%).

## Root cause (data-driven, "misura prima di patchare")

Analisi dei 68 minestroni pathogen v6 (`stage3-homogeneity-check-out.csv`): i
token `STR:` erano **patogeni GIÀ noti** ma catturati come stringa intera rumorosa:

| pattern | esempi `STR:` | già in dizionario? |
|---|---|---|
| LPS (dominante) | `lps_exposed_for_24_hours`, `stimulated_with_lps_for_8h`, `intravenous_lps` | ✅ PAMP → CHEBI:16412 |
| SARS-CoV-2 | `sars_cov_2_infection_at_moi_1_during_24_h`, `sars_cov_2_infected`, `sars_cov_2_wt` | ✅ vernacolo `sarscov2` → 2697049 |
| poly(I:C) | `tlr3_agonist_poly_i_c_10_g_ml`, `polyic_induced_for_24hr` | ✅ PAMP whitelist |

**Prova del mescolamento:** nei minestroni pathogen c'erano token `CHEBI:16412`
(LPS risolto) **mescolati** con `STR:lps_exposed_for_24_hours` (LPS non estratto)
nello stesso cluster → stessa entità, due rappresentazioni.

**Asimmetria di implementazione:** `.normalize_pathogen_to_taxid` faceva **solo
match esatto** del termine collassato (`gsub("[^a-z0-9]+","")`) contro le chiavi
PAMP/vernacolo → `"lps_exposed_for_24_hours"` → `"lpsexposedfor24hours"` ≠ `"lps"`.
Invece `.normalize_cytokine_to_hgnc` **già** usava `.extract_compound_candidates`
(spoglia dose/tempo). Per questo lo smoke Task 19 misurava **cytokine 53% vs
pathogen 8%** di recupero.

## Fix (`1fb1520`, TDD, precision-gated)

`.normalize_pathogen_to_taxid` ora itera i candidati da `.extract_compound_candidates`
(come il path citochina) e li matcha contro PAMP → vernacolo → taxdump:
- `"LPS exposed for 24 hours"` → cand `"lps"` → CHEBI:16412 (PAMP)
- `"poly(I:C) 10 ug/ml"` → cand `"poly(i:c)"` → CHEBI:84491 (PAMP)
- `"SARS-CoV-2 infected"` → cand `"sars-cov-2"` → NCBITaxon:2697049 (vernacolo)
- \+ vernacolo `mtuberculosis` → 1773

**Guardie di precisione** (la lezione dell'audit): host-species per-candidato (un
token `human`/`mouse` viene saltato → mai NCBITaxon:9606); taxdump SOLO su
candidati multi-parola (frasi), mai su token singoli. TDD: 6 test risoluzione
rumorosa (RED→GREEN) + 4 canary. Smoke precision-gated: **K3 falsi 0/200,
canary generici 0/12 PASS**.

## Misura pre-materializzazione (evita un re-cluster inutile)

Prima di impegnare ~18h, ri-eseguito il gate omogeneità **su v6 con il codice
fixato** (ri-deriva le identità membri): **pathogen 43,9% → 16,8%** — confermato
che il fix sposta il metrico senza toccare gli altri kind. GO per il ciclo v7.

## Episodio cache-miss (lezione operativa)

Il **1° re-cluster v7 ha prodotto output byte-identico a v6** (fix non
materializzato): il name-recovery lookup è **disk-cached version-aware**, ma il
fix a `recover_identity` non aveva bumpato `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`
→ chiave cache invariata (`v3`) → servito il lookup stale di v6 (build in **0.1
min** = cache hit, non ~1 min). Catturato dalla **sanity** (recovery_source
identici a v6). Fix: bump `v3→v4` (`409aa0a`, il contratto documentato del
cache-key lo richiedeva) → re-run: lookup ricalcolato 2.9 min + nuovo file cache,
n_assignments 547020→547010 (anchor cambiati). Vedi memoria
`feedback_bump_lookup_cache_version`. Costo: ~8h di re-cluster sprecate.

## Risultato v7 (materializzato)

**Stadio 3 v7** (`...stage3-v7-364547a7`): n_clusters 317687→**317304**;
`NCBITaxon:` cluster **1149→2245** (53 taxa); recovery_source cluster
PATHOGEN_VERNACULAR **521→1561** (×3), PAMP_WHITELIST **371→872** (×2,3),
STR_FALLBACK 68008→66003; **0 host-species** (9606/10090/10116).

**Stadio 4 v7** (`...stage4-v7-4f7ea215`): **7.468.582 righe pooled**, **998.695
sig** (FDR<0,05), 433 processed + 103 non-processable, **0 crash df-residui**.
Wall v7-1 re-cluster 475 min + v7-2 re-pool 668 min.

**Re-gate omogeneità v7** (test finale):

| kind | v5 | v6 | **v7** |
|---|---:|---:|---:|
| pathogen | 33,0% | 43,9% | **11,2%** |
| cytokine_stim | 61,2% | 35,9% | 35,9% |
| small_molecule | 36,5% | 35,9% | 35,9% |
| disease_vs_normal | 7,7% | 7,7% | 7,7% |
| **totale** | 22,7% | 22,0% | **20,1%** |

pathogen **11,2%** batte anche la previsione (16,8%): v7 ha ri-poolato
coerentemente, non solo ri-etichettato. Pathogen ora ≈ disease (7,7%).

## TODO residui (non-bloccanti)

- **cytokine / small_molecule ~36%** invariati: NON è estrazione (già coperta) ma
  **copertura ChEBI/HGNC** dei composti/citochine specifici + granularità
  per-membro. Richiede più copertura ontologica o cambio granularità.
- **LLM-fallback finale** (DECISIONE C, precision-gated) sui residui STR/UNK — il
  passo finale generale dopo tutti i recuperi deterministici.
- La pipeline è **end-to-end su v7** (Stadio 1→2→3 v7→Stadio 4 v7).
