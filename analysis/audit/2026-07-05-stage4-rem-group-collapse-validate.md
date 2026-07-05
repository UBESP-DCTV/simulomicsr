# Validazione collapse rem_group su dati veri (2026-07-05)

Script: `analysis/audit/2026-07-05-stage4-rem-group-collapse-validate.R`  
Stage 3 v7: `20260703T113045Z-stage3-v7-364547a7`  
Stage 2 master: `p4-fase-f4-stage2-master-v3.jsonl`  
Data: 2026-07-05 18:13:25.010061

## Obiettivo

Verificare che `.collapse_arms_by_study()` riduca correttamente
la pseudo-replicazione nei cluster `rem_group`: dopo il collapse,
il `k_effective` per gene deve essere ≤ al numero di studi distinti
(non al numero di bracci).

## Cluster bandiera (da smoke precedente)

Dispatch sub-campionato a max 10 entry per cluster, priorizzzando studi con bracci multipli.

| Cluster | Nome | n_entry_totale | n_studi_totale | bracci_extra |
|---|---|---|---|---|
| group_L4_b6a3eabd | SARS-CoV-2 | 25 | 12 | 13 |
| group_L4_b128b80d | enzalutamide | 18 | 12 | 6 |
| group_L4_fdd42642 | Prostatic Neoplasms | 8 | 4 | 4 |
| group_L4_b4975123 | fulvestrant | 8 | 5 | 3 |


## Risultati validazione post-collapse

Colonne: n_entry = bracci nel subset capped; n_studi = studi distinti nel subset;
k_pre = k_per_gene mediano PRIMA del collapse (= bracci);
k_post = k_per_gene mediano DOPO il collapse (deve essere ≤ n_studi);
I2 = eterogeneità mediana nel pool REM post-collapse; n_sig = geni FDR<0.05.

| Nome | n_entry | n_studi | n_righe_pre | n_righe_post | k_pre | k_post | I2_med | n_sig | Collapse |
|---|---|---|---|---|---|---|---|---|---|
| SARS-CoV-2 | 10 | 5 | 153739 | 79200 | 10.0 | 5.0 | 83.3% | 814 | OK |
| enzalutamide | 10 | 5 | 149701 | 76209 | 10.0 | 5.0 | 90.7% | 1737 | OK |
| Prostatic Neoplasms | 8 | 4 | 108844 | 52799 | 6.0 | 3.0 | 74.2% | 1485 | OK |
| fulvestrant | 8 | 5 | 116162 | 74290 | 8.0 | 5.0 | 81.6% | 518 | OK |

**STATUS: PASS (4/4 cluster con collapse OK)**

## Interpretazione

- **k_post = n_studi (check PRINCIPALE)**: il collapse ha unito i bracci multipli dello
  stesso studio in un'unica stima per gene via inverse-variance FE. Il `k_effective` nel
  pool metafor corrisponde al numero di studi distinti (non al numero di bracci) → ogni
  studio pesa una volta sola nel REM → pseudo-replicazione eliminata.

- **I2_med post-collapse (nota)**: dopo il collapse, l'I2 riflette la vera variabilità
  cross-studio. Rispetto ai valori pre-collapse dello smoke precedente (subset diverso,
  cap 6 vs 10 entry), i valori sono comparabili o leggermente superiori: questo è
  **atteso e corretto** — la pseudo-replicazione accumulava bracci concordanti dello stesso
  studio abbassando artificialmente l'I2; dopo il collapse la vera eterogeneità cross-studio
  (studi diversi che misurano il medesimo composto in condizioni biologiche diverse) emerge
  pienamente. La confrontabilità diretta con lo smoke pre-collapse è limitata dal fatto
  che i subset di studi sono diversi (diverso cap e priorità multi-arm).

## Confronto indicativo con smoke precedente (pre-collapse)

Lo smoke precedente (`2026-07-05-stage4-rem-group-smoke.R`) ha misurato il pool
SENZA `.collapse_arms_by_study()` e con subset diversi (cap 6 entry, selezione
non priorizzzata multi-arm). Il confronto è indicativo, non diretto.

| Cluster | n_geni | n_sig | I2_med (SENZA collapse, cap=6) |
|---|---|---|---|
| tamoxifen group_L4_3c38c897 | 16490 | 667 | 92.4% |
| Breast Neopl. group_L4_5d10ee81 | 17053 | 279 | 89.3% |
| enzalutamide group_L4_b128b80d | 15810 | 3747 | 84.0% |
| fulvestrant group_L4_b4975123 | 15876 | 1683 | 74.7% |
| SARS-CoV-2 group_L4_b6a3eabd | 15045 | 240 | 58.4% |

Post-collapse: enzalutamide I2=90.7% (da 84%), fulvestrant I2=81.6% (da 74.7%),
SARS-CoV-2 I2=83.3% (da 58.4%). Direzione coerente con la spiegazione sopra
(rimozione delle concordanze intra-studio → emerge la vera eterogeneità cross-studio).

