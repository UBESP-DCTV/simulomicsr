# ADR-0016: Stadio 4 — fix crash MEGA-AUG bidirezionale + cap dimensione baseline pool

- **Status:** Accepted
- **Date:** 2026-05-22
- **Deciders:** lucavd
- **Supersedes:** —
- **Superseded by:** —
- **Correlato a:** ADR-0015 (dream default) — vedi sez. "Sub-finding".

## Context and Problem Statement

Il fullrun Layer A di Stadio 4 (Task 21, MEGA-AUG bidirezionale) e' fallito
**4 volte** (2026-05-20/21): due crash `duplicate 'row.names'` e due OOM
(exit 137). La sessione di debugging 2026-05-21/22 ha isolato i guasti in
modo sistematico — riproduzione su dati reali, NON ri-lanci reattivi — e ha
trovato **tre** bug distinti + una scoperta metodologica.

## Decisione 1 — Problema A: crash `duplicate 'row.names'`

### Diagnosi (riproduzione: scan 310 cluster mega_aug)

`.run_dream_mega` crasha a `rownames(metadata) <- metadata$sample_id` quando
`metadata$sample_id` ha duplicati. Tre sorgenti distinte di duplicati nel
dispatch bidirezionale (`.assemble_mega_aug_metadata_bidir`):

1. **Stesso baseline pool su entrambi i bracci** (13/310 cluster). Quando il
   `treated_anchor` e il `control_anchor` del pair sono indistinguibili
   (identici ai level >= 2 dove i tier C/D sono droppati; o differenti solo
   nei `relaxed_segments` a L0/L1), un solo group baseline pool matcha
   entrambi i bracci. Aggiunto a control E treated → ogni suo sample
   duplicato.
2. **Pool distinti che condividono GSM** (7/310). `control` pool e `treated`
   pool sono cluster diversi ma contengono lo stesso GSM (duplicazione
   ARCHS4 super-series: identico GSM in piu' GSE → replicate_group in group
   cluster diversi). `build_baseline_rows` deduplica ogni blocco
   internamente ma non i due blocchi tra loro.
3. **Cluster `mega_aug` senza `study_dispatch`** (5/310). Record di
   comparison non risolvibili in `stage2_master` → nessun pair reale.

### Decisione

- **Caso 1 → mono-fallback (Opzione 1, scelta utente 2026-05-21).** Se
  `top_control` e `top_treated` collassano sullo stesso pool, si augmenta
  SOLO il braccio control (= comportamento legacy monodirezionale, gia'
  validato). Razionale scientifico: mettere gli stessi sample su entrambi
  i lati di un contrasto e' privo di senso (si annullano); l'alternativa
  "skip augmentation" perderebbe il cluster, "dedup difensivo" mentirebbe
  nei diagnostics. Il bias eventuale (pool ambiguo usato come solo control)
  e' conservativo verso il nulla. Flag `bidir_collapsed_to_mono` in
  `mega_aug_diagnostics`.
- **Caso 2 → drop role-conflict.** Il GSM condiviso ha ruolo ambiguo →
  rimosso da ENTRAMBI i blocchi baseline, coerente con la convenzione
  gia' presente in `.build_mega_metadata_safe` (`role_conflict_dropped`,
  paper-grade: non assumere un ruolo arbitrario).
- **Caso 3 → skip-guard.** Cluster `mega_aug` senza dispatch → registrato
  in `non_processable` (`mega_aug_no_study_dispatch`), non processato.
- **Defense-in-depth:** guardia `anyDuplicated(metadata$sample_id)` in
  `.run_dream_mega` → errore esplicito cluster-named invece del criptico
  `.rowNamesDF<-` per qualunque sorgente di duplicati futura.

Verifica: scan post-fix **0/310 cluster con sample_id duplicati**.

## Decisione 2 — simboli gene ARCHS4 non unici (+ sub-finding ADR-0015)

### Diagnosi

ARCHS4 v2.5 `meta/genes/symbol` **non e' unico**: 4638/67186 simboli HGNC
sono duplicati (es. `KIR3DL2` x43 — piu' gene Ensembl mappati sullo stesso
simbolo). `.fetch_counts_from_h5` li metteva come `rownames` della count
matrix. `dream`/`variancePartition` crashano con `duplicate 'row.names'`
su rownames duplicati; `limma` invece li tollera.

### Sub-finding metodologico (impatta ADR-0015)

`.run_dream_mega` ha un `tryCatch` che, su errore di `dream`, ripiega
**silenziosamente** su `limma-voom + duplicateCorrelation`. Conseguenza:
poiche' OGNI count matrix reale aveva rownames duplicati, `dream` falliva
sempre e la pipeline ha **sempre girato il fallback limma**, mai `dream`.
ADR-0015 ha scelto `dream` come default proprio per la sua calibrazione
FDR superiore (e nota che limma+dupcor NON e' validato per FDR sotto
violazioni) — ma di fatto `dream` non e' mai stato eseguito sui dati reali.
Anche le misure di memoria/tempo del debugging Problema B erano del
fallback limma.

### Decisione

`make.unique()` sui simboli in `.fetch_counts_from_h5` (deterministico:
ogni fetch produce gli stessi rownames → concat cross-study coerente).
Guardia difensiva `make.unique` anche in `.run_dream_mega`. Cache
`stage4-counts` purgata (le matrici cacheate avevano i vecchi rownames).
**Questo fix RIPRISTINA l'intento di ADR-0015**: dopo il fix `dream` gira
davvero. La sessione di debugging ha quindi anche eseguito un confronto
diretto dream-vs-limma sui dati reali (vedi sez. Decisione 3).

## Decisione 3 — Problema B: OOM da cluster augmentati giganti

### Diagnosi

I 4 fullrun OOM non erano causati da un cluster MEGA puro (max 548 sample)
come ipotizzato dal handoff, ma dai cluster **`mega_aug` augmentati**: fino
a **7122 sample / 945 studi** (28 cluster oltre 3000 sample). Misura diretta
sul cluster piu' grande: picco memoria **125 GB**, wall **> 1h** — bomba di
memoria E di tempo. Il COW creep dei worker forkati e' proporzionale al
tempo di esecuzione, quindi i cluster grandi (run lunghi) strisciano di piu'.

### Decisione: cap sulla dimensione del baseline pool per braccio

Razionale scientifico — **rendimenti decrescenti dell'augmentation**. La
varianza del contrasto e' `~ 1/n_pair + 1/n_aug`: il contrasto e' limitato
dal braccio del pair, e con `n_aug >> n_pair` il secondo termine e'
trascurabile. La frazione del beneficio massimo catturata con un braccio
augmentato `k` volte il braccio del pair e' `1 - 1/k`: k=5 → 80%, k=20 →
95%, k=1400 (= 7000 baseline su un pair da 5) → 99.93%. L'ultimo 0.07% di
beneficio costa 125 GB e un'ora.

Quindi: cap il numero di sample baseline aggiunti per braccio a `N`. Oltre
`N` si sotto-campiona (deterministico, seed dal cluster_id). Questo bound-a
la dimensione di OGNI cluster Layer A a poche centinaia di sample.

### Decisione 3b: cap statico sui dream worker

Il solo pool cap NON basta. Misura empirica 2026-05-22
(`analysis/p5-stage4-debug-dream-workers-mem.R`) su un cluster cappato
(~510 sample): `dream` consuma **~1 GB di RAM per worker** —
16 worker -> 27 GB, 32 worker -> 43 GB, ~100 worker -> ~115 GB. La
memcurve citata da ADR-0015 ("~10-15 GB con 100 worker") misurava di fatto
il **fallback limma**, non `dream` (vedi Decisione 2: `dream` non girava).
`dream` reale a 100 worker e' molto piu' pesante.

Poiche' il pool cap rende tutti i cluster ~uniformi (≤ ~550 sample), un
cap **statico** sui worker basta (niente cap dinamico). Scelto
`dream_workers_cap = 32` (ADR-0015 era 100): picco ~43 GB per cluster,
margine ampio sotto i 251 GB del laptop anche con overlap di worker
orfani tra cluster consecutivi. Wall ~100s/cluster sul cluster cappato
piu' grande. Revisione di ADR-0015 limitatamente a `dream_workers_cap`.

### Calibrazione del valore N — curva di saturazione

Il valore di `N` e' stato scelto empiricamente con
`analysis/p5-stage4-debug-problemB-saturation.R`: 3 cluster grandi reali,
cap del pool a {50, 150, 350, 600} sample/braccio, DE con entrambi i motori
(dream e limma+dupcor), confronto del risultato DE (n geni significativi,
correlazione logFC vs cap massimo) e del costo (wall, memoria).

Curva di saturazione sul cluster `pair_L4_25ee1af1` (pair = 2 treated + 3
control, baseline pool pieno 7117 sample). Geni fissati (`filterByExpr` sul
set cap-max): 27452. Correlazione logFC calcolata vs il cap massimo (600).

| cap/arm | n_sample | n_studi | n_sig dream | n_sig limma | cor logFC dream vs cap600 | cor dream-vs-limma | wall dream | wall limma |
|---|---|---|---|---|---|---|---|---|
| 50  | 105 | 72  | 8819  | 6741  | 0.955 | 0.976 | 229s | 55s  |
| 150 | 305 | 160 | 12574 | 11535 | 0.986 | 0.977 | 235s | 221s |
| 350 | 510 | 276 | 13123 | 12058 | 0.997 | 0.988 | 271s | 630s |
| 600 | 760 | 389 | 12567 | 11562 | 1.000 | 0.992 | 321s | 1448s |

Lettura:

- Il risultato DE **satura a cap = 350**: correlazione logFC col pool piu'
  ampio gia' 0.997, e il numero di geni significativi al **picco** (13123).
- Oltre 350 il risultato **non migliora**: a cap 600 `n_sig` cala (12567 <
  13123) — i sample baseline aggiunti oltre la saturazione introducono
  rumore/diluizione, non segnale.
- cap 50 e' sotto-saturo (cor 0.955, n_sig 8819).
- Costo `dream` ~costante col cap (229→321s: dream e' dominato dal numero
  di geni, non dai sample). Costo `limma+dupcor` esplode (55→1448s:
  `duplicateCorrelation` e' super-lineare nei sample).
- `dream` e `limma` concordano bene sui logFC (cor 0.98-0.99) — il fallback
  storico (limma) non era catastrofico, ma `dream` resta il default
  ADR-0015 e ora gira davvero.

Nota: clusters 2-3 della batteria non completati per il costo `limma` ai
cap alti; la curva di `pair_L4_25ee1af1` (4 punti, monotona, plateau netto)
+ l'argomento teorico dei rendimenti decrescenti sono ritenuti sufficienti.

Valore scelto: **`max_baseline_per_arm = 350L`** (config
`stage4_default_config()$mega_aug`). E' il punto di saturazione empirico;
con `dream` (costo ~piatto col cap) non e' penalizzante; a 510 sample il
footprint memoria e' largamente sotto i limiti del laptop.

## Implementation

- `R/stage4-mega-aug.R`: collision guard mono-fallback (sez. 3b) + drop
  cross-pool (sez. 3c) + cap baseline pool in `build_baseline_rows` +
  helper `.seeded_subsample`.
- `R/stage4-orchestrator.R`: skip-guard `mega_aug_no_study_dispatch` +
  propagazione `bidir_collapsed_to_mono` in `mega_aug_diagnostics` +
  progress logging per-cluster (`.proc_rss_gb`).
- `R/stage4-dream-mega.R`: guardie difensive `anyDuplicated` (sample) +
  `make.unique` (gene).
- `R/stage4-counts-cache.R`: `make.unique` sui simboli gene.
- `R/stage4-config.R`: `mega_aug$max_baseline_per_arm = 350` +
  `compute$dream_workers_cap` 100 -> 32.
- Commit: `25c158d` (Problema A), `f3ce3af` (gene symbols), `d5f6040`
  (Problema B).

## Risks / Reversibility

- Il cap e' overridabile da config (`max_baseline_per_arm <- NA` = nessun
  cap, comportamento pre-fix).
- Il sotto-campionamento e' deterministico → riproducibile.
- Il mono-fallback (caso 1) e il drop role-conflict (caso 2) riducono la
  copertura dell'augmentation di pochi cluster/sample: tracciati nei
  diagnostics, quantificati nella sez. Results del findings.

## References

- `docs/superpowers/specs/2026-05-21-p5-stadio4-debugging-handoff.md`
- `analysis/p5-stage4-debug-*.R` — script di riproduzione + scan + curva.
- ADR-0015 (`stage4-dream-default-parallel`) — il fix gene-symbol ne
  ripristina l'intento (dream effettivamente eseguito).
- Memoria utente `user_de_methods_benchmark` (FDR calibration).
