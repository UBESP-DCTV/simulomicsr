# Finding — Coerenza dei cluster Stadio 3: i raggruppamenti cross-studio misurano lo stesso contrasto?

**Data:** 2026-07-23
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Spec/plan:** `docs/superpowers/{specs,plans}/2026-07-23-stage3-cluster-coherence-verification-*`
**Input:** Stage 3 v10 `20260720T180625Z-stage3-v10-364547a7`; Stadio 4 v10 `20260722T210452Z-stage4-v10-a500d032`; Stadio 2 master `p4-fase-f4-stage2-master-v3.jsonl`.

---

## 0. La domanda e la risposta in una riga

**Domanda:** i cluster mettono insieme campioni di studi diversi che misurano *la stessa cosa*
(stesso trattamento vs stesso tipo di controllo), così che la meta-analisi guadagni segnale vero?

**Risposta (misurata, non asserita):** in larga parte **NO**. Dei **184 raggruppamenti che
compongono il deliverable finale** (le meta-analisi nominate `rem_group` v10), **157 (85%)
mescolano contrasti diversi** ("mele con pere"), e **solo 19 (10%) sopravvivono** come
meta-analisi difendibili (stesso contrasto **E** statisticamente consistenti **E** non-degeneri).
La **vetrina Layer B v10** ("9 case study publication-grade"): **0 su 9 sopravvivono**.

Questo è il problema CORE del RED ALERT (aperto 2026-05-25): l'audit v5→v10 ha sistemato i *nomi*
dei cluster ma la **coerenza di contrasto** non era mai stata verificata. Ora lo è.

---

## 1. Metodo (tutto riusa codice/metadati esistenti; nessuna metrica statistica inventata)

Perimetro: i **13.287 cluster k≥2** (k = serie GEO distinte). Priorità: i **714 poolati** in
Stadio 4 (mega 99, mega_aug 419, rem 12, **rem_group 184**), che sono ciò che finisce nella
meta-analisi. Il **rem_group 184** è il deliverable finale.

- **Fase 0 — Ricostruzione del contrasto.** Per ogni cluster, riuso **il dispatch reale dello
  Stadio 4** (`.lookup_cmp` pair / `.lookup_cmp_by_treated_group` group → `.lookup_rg`,
  `R/stage4-dispatch.R`) per estrarre i contrasti per-studio `treated_label ⇒ control_label
  [design_kind]`. Garantisce che verifico *ciò che è stato poolato*. (Helper testato:
  `R/stage3-coherence.R::.reconstruct_cluster_contrasts`, 16 test PASS.)
- **Fase A — Omogeneità del controllo (deterministico, tutti).** `control_type` per membro =
  `label_human` normalizzato (lowercase, strip dose/unità/numeri, sinonimi veicolo/baseline →
  una classe). Conta i tipi di controllo distinti per cluster. È un **floor conservativo**
  (corretto da D su campione).
- **Fase B — Consistenza (ADR-0021, solo poolati).** `consistency_score = 1−mediana(I² sui geni
  sig)` + `pi_frac_excl0` (prediction interval REML+HKSJ), riusando `R/stage4-consistency.R`
  INVARIATO. Validato: i 15 casi noti si riproducono entro **1e-17**. Disponibile solo per i 196
  rem/rem_group (mega/mega_aug: I² non calcolato nel pooled v10 → NA).
- **Fase C — Degenere.** Membro degenere = `treated_label == control_label` (contrasto nullo).
- **Fase D — Deep-dive LLM (184 poolati + campione).** 8 subagent hanno giudicato, per ogni
  cluster, dai contrasti REALI: (D1) tipi di controllo semantici; (D2) **l'insieme misura UN
  contrasto biologico o PIÙ?** Rubrica stretta, nessun verdetto atteso passato ai subagent.

**Verdetto (AND multi-asse, scelta utente):** `contrast_verdict` = "stesso contrasto?"
(D2 dove disponibile). `meta_analysis_valid` = coerente **E** non-degenere **E**
`consistency_score ≥ 0.5` = "cosa sopravvive come meta-analisi difendibile".

### Guardia anti-verdetto-sbagliato (mandato utente: "non fidarti dei subagent")
Il controller ha ri-giudicato a mano **24 cluster** (14 one_contrast + 10 multi_contrast) contro
le etichette reali: **accordo ~22/24 (~92%)**; i 2 borderline sono chiamate difendibili sotto la
regola conservativa. I verdetti LLM sono **verificabili sulle etichette e reggono** — NON il
problema "premesse false" del 2026-07-23. Dettaglio: `analysis/audit/2026-07-23-coherence/controller-verification-notes.md`.

### Un bug del mio strumento, trovato e corretto in corsa
Il primo `frac_degenerate` (basato su `factor_levels`) dava **falsi positivi**: due bracci diversi
(es. "Hypoxia" vs "Control") con le stesse chiavi factor_levels venivano segnati degeneri. Scoperto
verificando `group_L4_38ce0d4d` (Hypoxia, chiaramente coerente ma frac_deg=0.6). **Fix:** degenere =
uguaglianza del `label_human`. Effetto: cluster con ≥1 membro degenere **da 54 → 13 su 184** (il 54
era gonfiato). I numeri di questo finding sono POST-fix.

---

## 2. Risultato principale — il deliverable (184 rem_group, alta confidenza)

| contrast_verdict | n | % |
|---|---:|---:|
| **minestrone** (D2: contrasti diversi) | **157** | **85,3%** |
| coherent (D2: un contrasto) | 26 | 14,1% |
| uncertain | 1 | 0,5% |
| **meta_analysis_valid** (coerente + consistente + non-degenere) | **19** | **10,3%** |

- **13/184** contengono almeno un contrasto **degenere** (trattato==controllo) — errori Stadio 2
  che non andrebbero poolati (minoranza intra-cluster, nessun cluster interamente degenere).
- I **19 sopravvissuti** pendono verso **k basso** (11 su 19 hanno k<5), dove la stima di I² ha
  poca potenza → la loro consistenza (spesso I²=0) è **debole come evidenza**. Solo 8 hanno k≥5.
- **Bug di etichetta ortogonale (non è coerenza ma inquina il paper):** alcuni sopravvissuti hanno
  il `canonical_name` SBAGLIATO — `ethanol` è in realtà TNF, `Met-tRNA` è TGFB1, `anisole` è
  calcitriolo, `4-maleylacetoacetate` è DHT, e "carnitine" è ancora etichettato `pathogen`
  (mislabel noto dal 2026-05). Coerenti come contrasto, ma da rinominare prima di qualunque uso.

### Prove (le etichette reali, non asserzioni)
- **`b6a3eabd` "sars-cov-2"** (showcase, minestrone): 108 contrasti risolti, i "controlli" includono
  mock-infettato, DMSO, timepoint-post-infezione, KO/WT genetici, **e "SARS-CoV-2"/"DMSO+SARS-CoV-2"
  usati come controllo** → mescola effetto-infezione + effetto-farmaco + effetto-gene.
- **`274f387d` "Mycobacterium tuberculosis"** (showcase, minestrone): dominato da **COVID-19, sepsi
  neonatale, dengue**; la TB è minoritaria.
- **`1f404c0b` "influenza virus"** (showcase, minestrone): sotto lo stesso anchor **SARS-CoV-2, HIV-1,
  poliomavirus di Merkel, e uno xenograft mammario** senza patogeno.
- **`2bd06550` "prostate cancer" / small_molecule** (minestrone): pool­a **DHT/R1881 (agonista
  androgenico) INSIEME a Enzalutamide (antagonista, direzione OPPOSTA)** — segnali che si annullano.
- **`f20ecdaa` "acute lymphoblastic leukemia"** (minestrone): pool­a Crohn, SLA, HIV, sclerosi
  multipla, artrite psoriasica, X-ALD, uniti solo da "Healthy Control".

Pattern dominante (disease_vs_normal e "none", i kind più numerosi): l'anchor **entità+tessuto**
inghiotte **malattie diverse** che condividono solo un controllo sano generico.

---

## 3. Verdetto onesto sulla vetrina Layer B v10 (9 showcase "publication-grade")

| cluster | nome | k | contrast_verdict | consistency | meta_analysis_valid |
|---|---|---:|---|---:|:--:|
| 1f404c0b | influenza virus | 25 | **minestrone** | 0,08 | ❌ |
| 274f387d | M. tuberculosis | 59 | **minestrone** | 0,10 | ❌ |
| b6a3eabd | sars-cov-2 | 39 | **minestrone** | 0,10 | ❌ |
| c51b10c1 | hepatocellular carcinoma | 191 | **minestrone** | 0,13 | ❌ |
| b128b80d | Enzalutamide | 54 | **minestrone** | 0,03 | ❌ |
| c8600f54 | gastric cancer | 36 | **minestrone** | 0,86 | ❌ |
| eda28231 | Lung Neoplasms | 34 | **minestrone** | 0,57 | ❌ |
| 7059e6f2 | rsv | 7 | coherent | 0,16 | ❌ (I² alto) |
| 7b3e137b | Carcinoma, Renal Cell | 21 | coherent | 0,49 | ❌ (borderline) |

**0 / 9 sopravvivono.** 7 sono minestroni; 2 (RSV, RCC) hanno un contrasto coerente ma consistenza
sotto la soglia 0,5 (RCC 0,49 è borderline: con una soglia più permissiva passerebbe). La vetrina
dichiarata "publication-grade" nella sessione precedente **non lo era** — era costruita su cluster
non verificati. Questo era lo slop da eliminare.

---

## 4. Diagnosi del gate di selezione (perché i minestroni passano)

Il gate `rem_group` (ADR-0022, `.identify_layer_a_clusters`) è **puramente strutturale**:
`level∈{L2,L3,L4}` + `mode==group` + `method==rem_group` + `k_eff≥3` + dedup per entità.
**Zero check di coerenza di contrasto.** Un minestrone con un nome MeSH/ChEBI e k≥3 passa senza
ostacoli: il gate ha ammesso tutti i 184, di cui **86% non coerenti**.

**Gate di coerenza proposto** (simulato sui 184):
- porta 1 [contrasto coerente + non-degenere] → **25/184** passano;
- porta 2 [porta 1 + `consistency_score ≥ 0.5`] → **19/184** passano.

Da inserire PRIMA del pooling (o come filtro a valle sulla selezione Layer B). Se accettato → ADR
nuovo. Nota: la porta 2 penalizza i cluster a k basso (I² poco stimabile); una soglia di
consistenza va calibrata con l'utente insieme a un minimo di k.

---

## 5. Quadro a scala (13.287 cluster k≥2) — screening deterministico + copertura

| contrast_verdict | n | nota |
|---|---:|---|
| uncertain | 7437 | **copertura insufficiente** (n_resolved<2): la maggior parte NON è poolabile (treated-only senza controllo in-studio, ADR-0022) → non verificabile, ma nemmeno poolata |
| minestrone | 3036 | 157 alta-conf (deep-dive) + 2879 floor deterministico |
| coherent | 2781 | 26 alta-conf + 2755 floor deterministico (tentativo) |
| degenerate | 33 | trattato==controllo sulla maggioranza dei membri |

**Caveat di onestà:** il **40,6% (5401)** dei 13.287 non risolve alcun membro (treated-only) e il
**56% (7437)** ha verdetto "uncertain" (n_resolved<2), NON "coerente". Il floor deterministico
(coherent/minestrone a bassa confidenza) è
indicativo, non provato per-cluster come i 184. La verità solida è sul **deliverable (184)**, dove
c'è deep-dive LLM verificato + consistenza.

---

## 6. Limiti (dichiarati, non nascosti)

- **Copertura di ricostruzione**: il 59% dei cluster k≥2 ricostruisce ≥1 contrasto; la mediana della
  frazione di membri risolti è 0,25 su tutti (0,67 tra i ricostruibili, 0,69 sui 184 poolati). I
  cluster treated-only non hanno il controllo ricostruibile → verdetto uncertain (ma non erano poolati).
- **Consistenza a k basso** poco affidabile (I² non stimabile): i 19 "sopravvissuti" pendono verso
  k<5 → il loro pass di consistenza è debole.
- **Floor deterministico** del control-type sovra/sotto-stima (corretto da D solo sui 184 + campione).
- **Nomi sbagliati** ortogonali alla coerenza: alcuni cluster coerenti hanno canonical_name errato.
- **Deep-dive LLM** verificato su 24/184 (~92% accordo); non ogni verdetto è stato ri-controllato a mano.

---

## 7. Deliverable prodotti

- Tabella per-cluster (13.287): `analysis/audit/2026-07-23-coherence/cluster-verdicts.rds` (gitignored);
  summary committati: `verdict-by-kind.csv`, `verdict-by-kband.csv`, `deliverable-184-verdicts.csv`.
- Consistenza 714 poolati: `consistency-pooled.csv`. Verdetti deep-dive: `deepdive-verdicts/`.
- Verifica controller: `controller-verification-notes.md`.
- Codice: `R/stage3-coherence.R` (+ test); script `10..50-*.R`.

## 8. Prossimo passo (decisione utente)

1. **Gate di coerenza** — adottarlo (ADR nuovo) e con quali soglie (k minimo + consistenza)?
2. **Vetrina Layer B** — ricostruirla SOLO sui sopravvissuti (e sistemare i nomi sbagliati) o
   ripensare l'anchoring a monte (l'anchor entità+tessuto è troppo grezzo per disease_vs_normal:
   inghiotte malattie diverse)?
3. La causa radice (anchor troppo coarse a L3/L4) suggerisce che il vero fix è **a monte** nello
   Stadio 3, non un filtro a valle. Da decidere insieme.
