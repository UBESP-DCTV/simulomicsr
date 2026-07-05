# Smoke gate rem_group — Stage 4 v7 (2026-07-05)

Script: `analysis/audit/2026-07-05-stage4-rem-group-smoke.R`  
Stage 3: `20260703T113045Z-stage3-v7-364547a7`  
Stage 2 master: `p4-fase-f4-stage2-master-v3.jsonl`  

## (a) Copertura globale

Layer A totale: **885** cluster (mega=175, mega_aug=353, rem=8, rem_group=349)

rem_group post-dedup: **349** cluster
- Ammessi (k_eff >= 3): **70**
- Non-ammessi (k_eff < 3): **279** (di cui 131 con dispatch vuoto)

Principali cause di non-ammissione: mancanza di comparison in stage2 con
il group come treated_group (il controllo non è nello stesso studio). Questo
è atteso per cluster 'both_roles' dove il controllo è nel cluster stesso
ma non compare in una comparison separata, o per studi senza design aperto.

## (b) Tabella bandiera

| Bandiera | cluster_id | k_raw | k_eff | ammesso | n_bracci_extra |
|---|---|---|---|---|---|
| SARS-CoV-2                | group_L4_b6a3eabd | 25 | 12 | TRUE | 13 |
| SARS-CoV-2                | group_L4_2ec66bb3 | 3 | 2 | FALSE | 1 |
| enzalutamide              | group_L4_b128b80d | 25 | 12 | TRUE | 6 |
| Breast Neoplasms          | group_L4_5d10ee81 | 88 | 6 | TRUE | 1 |
| Breast Neoplasms          | group_L4_ef94a846 | 7 | 0 | FALSE | 0 |
| Prostatic Neoplasms       | group_L4_fdd42642 | 17 | 4 | TRUE | 4 |
| Alzheimer Disease         | NON in rem_group | NA | NA | NA | - |
| fulvestrant               | group_L4_b4975123 | 12 | 5 | TRUE | 3 |
| tamoxifen                 | group_L4_3c38c897 | 9 | 5 | TRUE | 2 |
| vemurafenib               | group_L4_fbaef709 | 10 | 4 | TRUE | 3 |

## (c) Misura I1 — bracci multipli intra-studio

Cluster ammessi con n_bracci_extra > 0: **49 / 70 (70.0%)**

Distribuzione n_bracci_extra (ammessi con bracci > 0): max=97, mediana=2.0, Q75=4.0, Q95=28.8

I bracci multipli intra-studio derivano da farmaci testati a dosi/tempi diversi
nello stesso studio (es. enzalutamide 1nM vs 10nM). Entrano tutti nel per-study
DE come entry separate e poi vengono aggregati nel REM. Questo introduce
pseudo-replicazione a livello di studio. La decisione di aggregazione
(media bracci o selezione) è aperta e richiede gate utente.

## (d) Risultati pool campione

| cluster_id | n_geni_pooled | n_FDR<0.05 | mediana_I2 | mediana_tau2 |
|---|---|---|---|---|
| group_L4_3c38c897 | 16490 | 667 | 92.39 | 0.3785 |
| group_L4_5d10ee81 | 17053 | 279 | 89.32 | 0.1945 |
| group_L4_b128b80d | 15810 | 3747 | 84.04 | 0.0522 |
| group_L4_b4975123 | 15876 | 1683 | 74.73 | 0.0564 |
| group_L4_b6a3eabd | 15045 | 240 | 58.42 | 0.0062 |

**Pool campione NON vuoto: SI**

## Conclusione — SMOKE GATE PASS

**Ramo rem_group validato sul campione leggero (5/5 cluster, exit=0):**

- Pool NON vuoto: **SI** (tutti 5 cluster)
- n_FDR<0.05 > 0: **SI** (667 tamoxifen, 3747 enzalutamide, 1683 fulvestrant, 279 Breast Neopl., 240 SARS-CoV-2)
- Crash per-study DE: **0**
- I2 mediana: 58–92% (alta eterogeneità cross-studio attesa: campioni diversi, condizioni diverse)

**Decisione aperta per utente (misura I1):** 70% dei cluster ammessi ha bracci multipli
intra-studio (n_bracci_extra mediana 2.0, max 97). Enzalutamide: 6 bracci extra;
SARS-CoV-2: 13 bracci extra. Il comportamento corrente tratta ogni braccio come studio
indipendente nel REM → pseudo-replicazione. Servono istruzioni su aggregazione bracci
prima del fullrun.

**Bandiera Alzheimer Disease non in rem_group:** Cluster `group_L3_2adb994a`
(k_raw=14) presente in Stage 3 ma non raggiunge k_eff>=3 nel dispatch: nessuna
comparison in stage2_master con quel group come treated_group. Esito atteso per
disease cluster where controls live in-cluster (both_roles) senza comparison esplicita.

