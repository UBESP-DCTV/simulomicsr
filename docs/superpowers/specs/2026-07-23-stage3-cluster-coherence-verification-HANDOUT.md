# HANDOUT — Verifica di COERENZA dei cluster Stadio 3 (ogni k≥2) + diagnosi del gate di selezione

**Data prep:** 2026-07-23
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato)
**Stato:** 🔴 problema CORE del RED ALERT ancora APERTO. Da affrontare in sessione dedicata.

---

## 0. Perché siamo qui — lettura onesta (leggere prima di tutto)

Il RED ALERT (apertura 2026-05-25) nasceva per un difetto **paper-grade**: i cluster
Stadio 3 sono **minestroni** — raggruppano biologie/contrasti diversi. L'audit v5→v10 ha
lavorato per mesi ma ha risolto **solo i NOMI** (recupero-nome deterministico, de-frammentazione
LLM, fallback): far sì che la stessa entità prenda un'etichetta e i frammenti si fondano. **NON
ha mai verificato la COERENZA DI CONTRASTO dei cluster** — cioè che gli studi messi insieme
misurino davvero *la stessa cosa*.

**Scoperta 2026-07-23** (durante il redesign della vetrina Layer B), usando la metrica di
consistenza canonica del progetto (ADR-0021, prediction interval REML+HKSJ) + estrazione dei
contrasti per-studio:

- Cluster "flagship" come **breast** (`environmental|MeSH:D001943|breast`), **prostate**
  (`environmental|MeSH:D011471|prostate`), **LPS** (`environmental|CHEBI:16412|Blood`) sono
  **minestroni tematici**: pool­ano decine di contrasti SCOLLEGATI uniti solo dal tessuto —
  ipossia, dieta con noci, chemio, deprivazione ormonale, mutazioni, radiazione, stimolazioni
  immunitarie diverse (molte nemmeno LPS). Il `kind` è spesso mislabellato "environmental"
  (calderone).
- **La consistenza da sola NON li cattura**: breast è il cluster PIÙ consistente di tutti
  (consistency 0.98, I²≈1.6). Servono consistenza **E** coerenza di contrasto/biologia insieme.
- Un caso degenere trovato: prostate GSE173246 ha `treated` e `control` con la **stessa etichetta**.
- I deliverable a valle (Layer B v10, "18/9 case study **publication-grade**") sono costruiti su
  cluster **non verificati** → **NON sono paper-grade** finché la coerenza non è verificata.
  (Nella sessione precedente questi erano stati dichiarati paper-grade senza verifica: è lo slop
  da eliminare.)

**Conclusione onesta:** per la parte "coerenza dei cluster", il problema del RED ALERT è **ancora
aperto**. Il metodo di AGGREGAZIONE (Stadio 4 REM/PI) è corretto; ciò che non è garantito né
verificato è che gli studi aggregati condividano lo stesso contrasto.

---

## 1. Obiettivo della prossima sessione

**Controllare OGNI cluster k≥2 formato in Stadio 3** e stabilire, per ciascuno, se è coerente o
no. Poi diagnosticare **cosa è fallito nel passaggio alla selezione degli studi** (perché i
minestroni sono stati ammessi al pooling).

Non "rifare l'audit": **aggiungere la verifica di coerenza che non è mai stata fatta**, misurare
l'impatto, e proporre un gate.

---

## 2. Scala e perimetro (numeri REALI, Stage 3 v10 `20260720T180625Z-stage3-v10-364547a7`)

- Cluster totali: **310.738**. Di questi **297.451 sono k=1** (mono-studio, non cross-study →
  fuori scope per il minestrone cross-studio; possono comunque essere mislabellati, ma non è
  questo il focus).
- **Perimetro da verificare = 13.287 cluster k≥2** (k = n° serie GEO distinte nel cluster):
  - k=2: 8085 · k=3: 1966 · k=4-5: 1486 · k=6-10: 1032 · k=11-20: 432 · k>20: 286.
- Distribuzione per `kind` (primo segmento anchor_key) tra i k≥2:
  `disease_vs_normal 3264 · none 2333 · vehicle_only 2215 · small_molecule 1775 ·
   environmental 1172 · genetic_knockdown 801 · pathogen_or_aggregate_exposure 753 ·
   cytokine_stim 344 · genetic_overexpression 291 · genetic_knockout 191 · differentiation 103 ·
   mechanical 40 · crispra_activation 5`.
- **NON pre-giudicare quali kind sono minestroni**: il difetto è emerso su "environmental" ma i
  sospetti sono diffusi (disease_vs_normal e "none" sono i più numerosi). Verificare TUTTI.
- I **184 rem_group** effettivamente pooled (v10) sono un SOTTOINSIEME dei 13.287 (quelli passati
  al gate ADR-0022). Il controllo è su TUTTI i 13.287, ma con priorità di impatto sui 184 pooled.

---

## 3. Metodo di verifica — SCALABILE e ANCORATO AL PROGETTO (vietato inventare)

Calcolare per tutti i 13.287 cluster un insieme di segnali, poi combinarli in un verdetto.
NIENTE metriche ad-hoc: usare gli assi canonici già a libro + i metadati Stadio 2 esistenti.

- **(A) Omogeneità del CONTRASTO — il check nuovo e decisivo.** Gli studi membri misurano lo
  STESSO tipo di contrasto? Segnali dai record Stadio 2 (`p4-fase-f4-stage2-master-v3.jsonl`,
  ha `design_kind`, `factors`, e per ogni `replicate_group` `label_human`+`factor_levels`+
  `primary_role`):
  - i gruppi CONTROL degli studi membri sono lo stesso tipo semantico? (fulvestrant: "DMSO/vehicle"
    ovunque = coerente; breast: 20%O2 / full-media / starvation / walnut-control / pre-surgery =
    guazzabuglio → minestrone).
  - i `design_kind` degli studi membri sono omogenei o mescolati (dose-response + timecourse +
    genetic_KD + environmental nello stesso cluster = minestrone)?
  - l'`agent`/perturbazione reale è lo stesso, o l'anchor (entità+tessuto) ha inghiottito
    perturbazioni diverse?
- **(B) Consistenza / Prediction Interval (ADR-0021).** Già stabilita e verificata. Riusare
  `R/stage4-consistency.R` (`.rem_prediction_interval` REML+HKSJ, `.rem_consistency_from_i2`) e
  il pattern `analysis/p5-stage4-showcase-consistency-v10.R`. Riportare `consistency_score`,
  `median_I2`, `pi_frac_excl0`. **Necessaria NON sufficiente** (un minestrone può essere
  consistente) → va SEMPRE accoppiata ad (A)/(D).
- **(C) Degenere.** `treated` e `control` con la stessa `label_human` / stessi factor_levels →
  contrasto invalido (già visto: prostate GSE173246). Flag automatico.
- **(D) Coerenza biologica (deep-dive).** Su un campione stratificato + i cluster flaggati da
  (A)/(C): i top geni ROBUSTI (PI-excl0 dal parquet `cluster_pi_per_gene`) matchano la biologia
  attesa dall'anchor? (LLM/subagent con verifica su letteratura, come i 3 revisori del 2026-07-23,
  ma SOLO sui geni PI-robusti, non sul ranking |logFC|).

**Verdetto per-cluster** = combinazione A-D → {coerente | minestrone | degenere | incerto}.
La scala (13.287) impone: A/B/C automatici su TUTTI; D (LLM) su campione + flagged.

---

## 4. Diagnosi del gate di selezione (perché i minestroni passano) — richiesta esplicita utente

Il gate rem_group (ADR-0022, `.identify_layer_a_clusters` + `.build_group_rem_dispatch_from_stage3`)
è **puramente STRUTTURALE/STATISTICO**: `level ∈ {L2,L3,L4}` + `mode==group` + `method==rem_group`
+ `k_eff ≥ 3` (studi distinti post-collapse) + dedup per entità al k massimo. **Zero check di
coerenza di contrasto.** Un minestrone con un nome MeSH/ChEBI e k≥3 passa senza ostacoli.

Da produrre: quanti dei **184 pooled** falliscono (A)/(C); quale gate di coerenza andrebbe
inserito PRIMA del pooling (o come filtro a valle sulla selezione Layer B).

---

## 5. Deliverable attesi

1. **Tabella per-cluster** (tutti i 13.287): `cluster_id, kind, k, anchor, control_homogeneity,
   design_kind_homogeneity, consistency_score, pi_frac_excl0, degenerate_flag, verdict`.
   (gitignored se pesante; summary + distribuzioni committate.)
2. **Finding** `docs/findings/2026-07-<gg>-stage3-cluster-coherence.md`: quanti coerenti /
   minestroni / degeneri, per kind e per fascia di k; impatto sui 184 pooled; esempi.
3. **Diagnosi del gate** + proposta di gate di coerenza (ADR nuovo se accettato).
4. **Verdetto onesto sulla vetrina Layer B**: quali dei 9 (e dei 184) sopravvivono alla verifica.

---

## 6. Regole (HARD) per la prossima sessione

- **VIETATO dichiarare "paper-grade"/"publication-grade"/"validato" senza prova sui dati.** Ogni
  affermazione di coerenza va dimostrata, non asserita.
- **VIETATO inventare metriche.** Usare ADR-0021 (consistenza/PI) + i check di omogeneità sui
  metadati Stadio 2 già esistenti. Se serve un metodo nuovo → brainstorming + spec PRIMA, con
  fondamento bibliografico (come fu per ADR-0021).
- **Prima MISURARE a scala (A/B/C su tutti i 13.287), poi deep-dive (D) su campione + flagged.**
  No cherry-picking, no conclusioni da 3 esempi.
- **Non fidarsi dei verdetti dei subagent senza controllo** (i revisori del 2026-07-23 avevano dato
  premesse sbagliate — es. "rank per significatività ed emergono i canonici", smentito dai dati).
- **Fail onesto**: se la maggioranza dei 13.287 è minestrone, dirlo con il numero. È un finding, non
  una vergogna.

---

## 7. Artefatti / riferimenti (già prodotti, riusabili)

- Metrica consistenza/PI (metodo canonico): `docs/decisions/0021-reproducibility-consistency-metric.md`
  + spec `docs/superpowers/specs/2026-06-15-f6-reproducibility-consistency-metric-design.md` +
  codice `R/stage4-consistency.R` + orchestratore `analysis/p4-fase-f6-consistency.R`.
- Consistenza/PI già calcolata sui 15 cluster vetrina+drop v10:
  `analysis/audit/2026-07-23-showcase-consistency-summary.csv` +
  `cluster_pi_per_gene_showcase.parquet` (nel dir del run Stadio 4 v10) +
  script `analysis/p5-stage4-showcase-consistency-v10.R` (pattern riusabile).
- Estrazione contrasti per-studio (evidenza dei minestroni): pattern nello scratchpad di sessione
  (drop-contrast-extract.R) — ricostruisce treated/control `label_human` per cluster dai dispatch.
- Gate di selezione: `docs/decisions/0022-stage4-rem-group-named-metaanalyses.md` +
  `R/stage4-dispatch.R` (`.identify_layer_a_clusters`, `.build_group_rem_dispatch_from_stage3`).
- Input: Stage 3 v10 `analysis/p4-output/20260720T180625Z-stage3-v10-364547a7/`; Stadio 2 master
  `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl`; re-pool v10
  `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032/`.
- Contesto pipeline: `CLAUDE.md`, `docs/RED_ALERT.md`.

---

## 8. Cosa NON fa questa sessione (scope)

- NON rifà Stadio 1/2/3/4 da zero. Verifica + diagnosi + proposta di gate.
- NON ri-clusterizza (a meno che il finding non provi che serve — decisione utente separata).
- NON produce vetrina/paper finché la coerenza non è verificata.
