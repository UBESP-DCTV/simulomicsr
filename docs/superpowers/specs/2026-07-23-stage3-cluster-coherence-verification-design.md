# Spec — Verifica di coerenza dei cluster Stadio 3 (ogni k≥2) + diagnosi del gate

**Data:** 2026-07-23
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Stato:** APPROVATA (dall'utente delegata a Claude: "approvatela da solo e parti con subagent mode")
**Handout di partenza:** `docs/superpowers/specs/2026-07-23-stage3-cluster-coherence-verification-HANDOUT.md`

---

## 0. La domanda (in una riga)

**I cluster mettono insieme campioni di studi diversi che misurano DAVVERO la stessa cosa —
stesso tipo di trattamento contro lo stesso tipo di controllo — così che la meta-analisi
guadagni segnale vero e non medi "mele con pere"?**

È la domanda centrale di tutto lo studio. L'audit v5→v10 ha sistemato i *nomi* dei cluster ma
non ha mai verificato la *coerenza di contrasto*. Questa spec aggiunge quella verifica, la misura
a scala su tutti i cluster cross-studio, e diagnostica perché il gate di selezione lascia passare
i minestroni.

## 1. Evidenza già misurata (2026-07-23, dati veri) — motiva lo scope

Ricostruendo i contrasti per-studio con **lo stesso dispatch che lo Stadio 4 usa per poolare**
(`.lookup_cmp` / `.lookup_cmp_by_treated_group` → `.lookup_rg`), sui **184 rem_group poolati**
(il deliverable finale v10):

| segnale | valore |
|---|---|
| cluster con controllo OMOGENEO (1 solo tipo) | **0 / 184** |
| cluster con ≥5 tipi di controllo distinti | **147 / 184 (80%)** |
| controlli distinti per cluster (mediana) | **10** (max 147) |
| cluster con ≥1 membro DEGENERE (treated==control) | **54 / 184 (29%)** |

I flagship della vetrina sono i peggiori (SARS `b6a3eabd` 48 controlli/108 membri; M.tuberc
`274f387d` 55/172; hepatocell `c51b10c1` 147/210; Enzalutamide `b128b80d` 77/138 + 12 degeneri) e
hanno anche consistenza bassa (0.03–0.13). Conferma la tesi del handout: **breast era consistente
0.98 MA minestrone → la consistenza da sola non li becca**.

Caveat onesto: il conteggio sopra usa normalizzazione grezza (lowercase) → **sovrastima** la
diversità. La direzione è inequivocabile; il conteggio esatto paper-grade richiede la
normalizzazione definita in §3 (Fase A) + calibrazione LLM (Fase D).

## 2. Scope e perimetro

- **Perimetro = 13.287 cluster k≥2** (k = serie GEO distinte). Distribuzione confermata sui dati:
  k=2:8085 · k=3:1966 · k=4-5:1486 · k=6-10:1032 · k=11-20:432 · k>20:286.
  Modalità: **12.603 group (95%) + 684 pair (5%)**. I minestroni vivono nel group mode (l'anchor
  fissa solo il *treated*; il control è libero per studio).
- **Priorità di impatto: i 714 poolati** (mega 99 · mega_aug 419 · rem 12 · **rem_group 184**),
  perché sono ciò che finisce nella meta-analisi. Verifica su TUTTI i 13.287, deep-dive prioritario
  sui poolati.
- **Vincolo di copertura (finding, non bug):** la ricostruzione del contrasto risolve in mediana
  ~12% dei membri group (32% dei cluster group risolvono 0 membri) — perché la maggior parte sono
  *treated-only senza controllo in-studio* (ADR-0022) e per questo NON poolati. La verifica piena
  (A completa) è possibile solo dove il contrasto risolve; dove non risolve si riporta il limite.

## 3. Metodo — misura a scala poi deep-dive (VIETATO inventare metriche)

Tutto riusa codice/metadati esistenti. Nessuna nuova metrica statistica.

### Fase 0 — Ricostruzione del contrasto (tutti i 13.287)
Per ogni cluster, riusare **il dispatch reale dello Stadio 4** per estrarre la lista di contrasti
per-studio: `{study_id, treated_label, treated_factor_levels, control_label,
control_factor_levels, design_kind}`. Pair → `.lookup_cmp`; group → `.lookup_cmp_by_treated_group`;
entrambi → `.lookup_rg`. Registrare `n_members`, `n_resolved`, `resolution_rate`.
**Perché riusare il dispatch:** garantisce che verifichiamo *lo stesso contrasto che è stato
poolato*, non una ricostruzione parallela divergente.

### Fase A — Omogeneità del contrasto (deterministico, tutti) — il check nuovo e decisivo
`control_type` per membro:
- identità primaria = **firma factor_levels** (coppie `key=value` ordinate) quando presente;
- fallback = `label_human` normalizzato: lowercase; strip dose/unità (`\d+ ?(nm|µm|um|mm|mg|ng|%|
  h|hr|day|d|week)`); strip numeri isolati; canonicalizza sinonimi di veicolo/controllo
  (dmso, vehicle, untreated, mock, pbs, control, normoxia, wildtype/wt, scramble/scrambled →
  classi canoniche); collassa whitespace.
Segnali per-cluster (sui membri risolti): `n_control_types`, `control_homogeneity`
(=1 se `n_control_types==1`; altrimenti gradato), `n_design_kinds`, `n_treated_types`.
Questo è il **floor conservativo** (sovrastima la diversità → corretto da Fase D su campione).

### Fase B — Consistenza (ADR-0021, solo ~714 poolati)
Estendere `analysis/p5-stage4-showcase-consistency-v10.R` da 15 a **tutti i 714 poolati**, riusando
`R/stage4-consistency.R` INVARIATO: `consistency_score`, `median_I2`, `pi_frac_excl0`. I ~12.573
non-poolati non hanno DE per-studio → nessun I²/PI (rispetta §8: no re-pool); verdetto da A+C.
**Necessaria NON sufficiente** — accoppiata sempre ad A/C/D.

### Fase C — Degenere (deterministico, tutti)
Membro degenere = `treated_factor_levels == control_factor_levels` (fallback
`treated_label == control_label`). Per-cluster: `n_degenerate`, `frac_degenerate`.

### Fase D — Deep-dive biologico (LLM/subagente, campione stratificato + tutti i flaggati)
Target: (i) tutti i **184 rem_group poolati**; (ii) i cluster flaggati da A/C; (iii) campione
stratificato per `kind × k` del resto.
- **D1 — ri-conteggio SEMANTICO dei control-type**: dato l'elenco dei control-label reali del
  cluster, raggrupparli in tipi semantici → `n_control_types_semantic` (corregge il floor
  deterministico). Eseguito su un **campione di calibrazione** (~30-40 cluster lungo tutto il range
  di diversità) per stimare il fattore di sovrastima del deterministico + su tutti i 184 poolati.
- **D2 — coerenza dell'insieme di contrasti + biologia**: l'insieme dei contrasti (treated vs
  control) misura UN contrasto biologico o più? + per i poolati, i **top geni PI-robusti**
  (`excl0` dal parquet `cluster_pi_per_gene`) matchano la biologia attesa dall'anchor?
  SOLO sui geni PI-robusti (non sul ranking |logFC|).
- **Guardia anti-verdetto-sbagliato** (avvertimento utente 2026-07-23): ogni verdetto LLM è
  accompagnato dall'evidenza grezza (i label reali / i geni reali); Claude (orchestratore) verifica
  a mano un sottoinsieme contro i dati; il finding riporta il **tasso di accordo LLM-vs-dati**.
  Nessun claim che non poggi sul dato vero. Infra: subagenti Claude batchati (non Mistral DGX; il
  deep-dive è su ~200-300 cluster, non 13k).

### Verdetto per-cluster — AND multi-asse (coerenza congiunta)
- **degenere**: `frac_degenerate` alta (contrasto invalido).
- **minestrone**: controllo eterogeneo (`n_control_types` alto — semantico dove disponibile,
  deterministico altrove) OPPURE `design_kind` mescolati OPPURE (poolati) D2 dice ≥2 contrasti.
  **La consistenza NON salva un minestrone.**
- **coerente**: SOLO se controllo-omogeneo E non-degenere E (consistenza OK dove disponibile) E
  D2 conferma (dove valutato).
- **incerto**: copertura insufficiente (`n_resolved` troppo basso) o segnali contrastanti non
  risolti da D.
Soglie numeriche calibrate sui dati nella fase di implementazione e riportate esplicitamente nel
finding (nessuna soglia nascosta).

## 4. Diagnosi del gate di selezione (richiesta esplicita utente)

Il gate rem_group (ADR-0022, `.identify_layer_a_clusters` + `.build_group_rem_dispatch_from_stage3`)
è **puramente strutturale**: `level ∈ {L2,L3,L4}` + `mode==group` + `method==rem_group` +
`k_eff ≥ 3` + dedup per entità. **Zero check di coerenza di contrasto.** Da produrre: quanti dei
184 poolati falliscono A/C; proposta di **gate di coerenza** (control-homogeneity ≥ soglia +
no-degenere + design_kind omogeneo) da inserire PRIMA del pooling o come filtro a valle Layer B;
quanti dei 184 lo passerebbero. Se accettato → ADR nuovo.

## 5. Deliverable

1. **Tabella per-cluster** (13.287): `cluster_id, kind, k, mode, level, anchor, n_resolved,
   n_control_types(_semantic), control_homogeneity, n_design_kinds, frac_degenerate,
   consistency_score, pi_frac_excl0, verdict`. Gitignored se pesante; summary + distribuzioni
   committati.
2. **Finding** `docs/findings/2026-07-23-stage3-cluster-coherence.md`: coerenti / minestroni /
   degeneri / incerti per `kind` e per fascia di `k`; impatto sui 184 poolati; esempi con prova.
3. **Diagnosi del gate** + proposta di gate di coerenza (ADR se accettato).
4. **Verdetto onesto sulla vetrina Layer B**: quali dei 9 (e dei 184) sopravvivono.

## 6. Decisioni bloccate (dall'utente, 2026-07-23)

- **Metrica (A)**: ibrido — deterministico su tutti (floor) + LLM (D) sui flaggati/campione per il
  conteggio semantico.
- **Verdetto**: AND multi-asse (la consistenza è necessaria non sufficiente; breast docet).
- **Scope (B)**: solo i ~714 poolati (riuso parquet Stadio 4 v10; nessun re-run DE — §8).
- **Infra D**: subagenti Claude batchati + verifica manuale.

## 7. Cosa NON fa (scope)

- NON ri-clusterizza, NON re-poola, NON re-runna DE (§8 handout).
- NON produce vetrina/paper finché la coerenza non è verificata.
- NON dichiara "paper-grade" senza prova sui dati.

## 8. Riferimenti (riusabili)

- Consistenza/PI: `docs/decisions/0021-*`, `R/stage4-consistency.R`,
  `analysis/p5-stage4-showcase-consistency-v10.R`.
- Gate: `docs/decisions/0022-*`, `R/stage4-dispatch.R` (`.identify_layer_a_clusters`,
  `.build_group_rem_dispatch_from_stage3`, `.lookup_cmp`, `.lookup_cmp_by_treated_group`,
  `.lookup_rg`, `.split_record_id`).
- Input: Stage 3 v10 `analysis/p4-output/20260720T180625Z-stage3-v10-364547a7/`; Stadio 2 master
  `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl`; Stadio 4 v10
  `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032/`.
