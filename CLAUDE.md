# CLAUDE.md — contesto persistente per Claude Code su `simulomicsr`

> Fonte canonica del contesto del progetto per ogni sessione Claude Code,
> indipendentemente dalla macchina (laptop o server). Sostituisce la
> memoria locale di Claude Code (`~/.claude/projects/<path>/memory/`)
> che è machine-specific e non portabile.
>
> **Quando una sessione inizia in questa directory, leggi questo file
> per intero prima di agire.**

---

> ⚠️ **RED ALERT ATTIVO** (apertura 2026-05-25) — audit completo
> pipeline a 5 stadi in corso (FASE F rebuild). **F6: pipeline END-TO-END su v5
> (malattie risolte + OPZIONE B farmaci/composti ChEMBL COMPLETA). Plan B Task 8-10
> ESEGUITI: re-cluster Stadio 3 v5 (317k cluster) → re-pool Stadio 4 v5 (7,36M righe
> pooled, 0 crash df-residui) → re-gate omogeneità. `small_molecule` minestrone
> 49→36,5% globale, ma al livello granulare L0/L1 (composto specifico) 12→8% ≈ disease
> (7,7%): il residuo è pooling gerarchico L3/L4 by-design, non name-recovery mancante.**
> Reference operativa: **`docs/RED_ALERT.md`** (leggere PRIMA di toccare codice) +
> ledger esecuzione **`.superpowers/sdd/progress.md`** + plan/spec/HUMANE
> `docs/superpowers/{plans,specs}/2026-06-28-stage3-perturbative-name-recovery-B-*`.
> Master invariato. Branch attivo: `review-scientific-consistency-2026-06-10`. Le
> regole comportamentali per Claude sono nel doc RED_ALERT, §"Come Claude si deve
> comportare con me in questo audit".
>
> **Stato 2026-07-07b (name-cleanup Mistral — FIX RESOLVER + FULL RUN T13 END-TO-END, CHIUSO)**:
> 🟢 **Il name-cleanup è completo end-to-end. Smoke PASS (13/13 recall, 0 canary false-alarm) e full run
> T13 su 193 cluster girato (83 override, 65 noop, 14 flag_review, 31 keep). Finding
> `docs/findings/2026-07-07-name-cleanup-results.md`.**
>
> 1. **Fix #1 resolver citochine** (commit `36756ac`, TDD, `R/name-cleanup.R`): lo smoke 29665 aveva Mistral
>    13/13 semantico ma il resolver mancava le citochine full-name. Cause (dati reali): Mistral emette `kind`
>    LIBERO `"cytokine"` (schema kind=string, no enum) → dispatch nel catch-all dove MeSH precede HGNC →
>    interferon/TNF → MeSH invece del gene; + full-name non sono symbol HGNC; + `"17-beta-estradiol"` non
>    matcha alias ChEBI. Fix: `.canonicalize_resolver_kind` (vocabolario→enum) + `try_cytokine` lookup
>    **WHOLE-STRING** ImmPort/HGNC/UniProt + gate whitelist + `.normalize_greek_stereo`
>    (`17-beta-estradiol`→`17β-estradiol`). **Review adversariale (subagent)** ha trovato PRECISION LEAK
>    IMPORTANT (il 1° tentativo usava `.normalize_cytokine_to_hgnc` che fa token-extraction: `"IL-6 receptor"`
>    →HGNC:IL6 spurio) → corretto a whole-string. Verifica: 45 test resolve + 19/19 sui dizionari reali.
> 2. **Fix #2 current_ids full-run** (commit `d6587c8`, `p5-name-cleanup-run.R`): lo script passava
>    `current_ids = anchor_key` completo (`kind|ID|tissue|…`) mentre la policy confronta l'ID ontologico del
>    resolver → `noop` mai raggiunto → override/flag_review gonfiati (48/62 flag + 17/100 override = noop
>    mascherati). Fix: `current_ids = extract_anchor_summary(...)$agent_id`.
> 3. **Smoke re-eval PASS** (sulle stesse predictions 29665, resolver fixato): Recall 69,2%→**100% (13/13)**,
>    Precision 81,8%→**100%**, canary false-alarm 25%→**0%**.
> 4. **Full run T13** (job 29670, 193 record = 125 candidate + 68 canary, wall 1m31s, 193/193 valid_schema):
>    **override 83** (correzioni genuine, new_id CHEBI 34/HGNC 13/MeSH 36), **noop 65** (già corretti),
>    **flag_review 14** (disaccordi → review umana; ~3 falsi da mismatch HGNC numero-vs-symbol KRAS/SF3B1/
>    TP53), **keep 31** (resolver NONE: glioblastoma MeSH miss, Infliximab anticorpo, varianti genetiche).
>    Scope B: **31 entità ≥2 cluster, max k_merged_est 91**.
> 5. **Fix #3 IDENTITÀ DEL GENE** (commit `bb802ae` resolver + `8dcd91e` sorgente): la review dei 14 flag_review
>    ha fatto emergere che **lo stesso gene aveva due ID** — `R/anchors.R` emette `HGNC:<numero>`, il
>    recupero-nome (citochine + K2) emetteva `HGNC:<simbolo>`. **Misura su anchor v7**: 39.096 cluster con
>    gene (37.160 numerici + 1.936 sigla), **61 geni in entrambi i formati**, **80 gruppi si fonderebbero**
>    (160 cluster), **3 meta-analisi oggi perse** sotto k≥3 (PF4/TGFB1/TNF) + 2 con più potenza; 5/503 cluster
>    poolati (v8) hanno un gene, 1 frammentato; **0 alias non canonici**. **Errore di OMISSIONE** (i pool
>    esistenti restano corretti) → NON giustifica un re-cluster dedicato (~20h). Fix: **ID canonico
>    `HGNC:<numero>`** (stabile; simbolo = etichetta, come `gene_id`/`gene_symbol` FASE E1) in
>    `.normalize_cytokine_to_hgnc` + K2 + resolver; `.canonicalize_gene_id` (`HGNC:KRAS`≡`HGNC:6407`); ramo
>    `genetic_perturbation` (gene prima di ChEBI, **niente MeSH**) con `try_gene` whole-string HGNC+**UniProt**
>    (`androgen receptor`→`HGNC:644`; canary 8/8 NULL); **cache lookup v4→v5** (obbligatorio). Si materializza
>    al prossimo re-cluster. Suite anchor+name-cleanup+name-recovery+stage3: **1405 PASS / 0 FAIL**.
> 6. **Full run re-eval finale**: override 83, **flag_review 14→10** (KRAS/SF3B1/TP53/APOE → noop: l'anchor era
>    giusto), noop 65→67, keep 31→33. `androgen receptor` MeSH:D011944→HGNC:644; GFP/HPV16-E7: override MeSH
>    spurio → keep. **Review dei 14**: 2 presunti *canary* erano gravemente mal-etichettati (JQ1 anchor
>    "D-cicloserina"; 4-OH-tamoxifene anchor "metil-idrossipalmitato") → il canary NON è un puro controllo di
>    non-regressione. 1 cluster è una **combo** (estradiolo+R5020) che nessuno dei due ID cattura.
> 7. **TODO** (non bloccanti): (a) `R/stage3-anchor-levels.R:154` fabbrica `HGNC:<target grezzo>` (es.
>    `HGNC:DTMYC`) per target mediated_effect ignoti a HGNC — stessa classe del fix I2, andrebbe `STR:` (5 sigle
>    in v7); (b) gap copertura resolver (glioblastoma/anticorpi/varianti/siRNA) = materia **LLM-fallback finale**
>    (DECISIONE C); (c) combo non modellate; (d) `kind` genetic_overexpression su cluster che sono *genotipi*
>    (APOE e4) = questione K2. Deliverable: `analysis/p4-output/name-cleanup-side-table-v1.rds` +
>    `-fragmentation-v1.csv`. Finding aggiornato con review dei 14 + misura frammentazione. Branch invariato,
>    master invariato, +5 commit (`36756ac`,`d6587c8`,`c66d844`,`bb802ae`,`8dcd91e`).
>    Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-07-06 (FULLRUN Stadio 4 v8 ESEGUITO + CLOSEOUT — ramo `rem_group` CHIUSO)**:
> 🟢 **Il re-pool Stadio 4 v8 col ramo `rem_group` è girato end-to-end e la verifica anti-stale è
> PASS. Le meta-analisi cross-studio NOMINATE sono finalmente poolate. ADR-0022 Accepted.**
>
> 1. **Run**: `setsid` detached (SID==PID, NON run_in_background), wall **1067 min (~17,8h)** laptop,
>    RSS picco ~14,6 GB, 0 crash. run_id `a500d032`, output
>    `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v8/20260706T112612Z-stage4-v8-a500d032/`. Dashboard
>    quarto fallita (non-fatale). Input v7 invariati (no re-cluster), cache counts riusata (no stale).
> 2. **ANTI-STALE PASS**: `Methods = mega,mega_aug,rem,rem_group`; **503 processati = 433 (v7, IDENTICO
>    su mega 72/mega_aug 353/rem 8) + 70 rem_group**. cluster_pooled 8.613.424 righe (rem_group 1.144.842),
>    per_study_de 34.026.609, sig FDR<0,05 1.121.633. Retrocompat rami esistenti byte-identica verificata.
> 3. **RE-GATE 70 rem_group** (tutti L4 group): n_sig 0–6347 (mediana ~1400), I² med 0–98%, k_eff 3–77
>    (studi distinti post-collapse). **BANDIERA 7/7 presenti**: SARS `NCBITaxon:2697049` (k12,n1813),
>    Prostatic `MeSH:D011471` (k4,n1485), enzalutamide `CHEBI:68534` (k12,n1337), fulvestrant
>    `CHEBI:31638` (k5,n518), tamoxifen `CHEBI:41774` (k5,n437), Breast `MeSH:D001943` (k6,n272),
>    vemurafenib `CHEBI:63637`. Top n_sig: tuberculosis|blood 6347.
> 4. **non_processable 382** = 279 `rem_group_insufficient_in_study_controls` (k_eff 131@0/93@1/55@2) +
>    103 `mega_rank_deficient`. I 279 = treated-only senza comparison stage2 (ibrido; augmentation = passo-3).
> 5. **Closeout**: finding `docs/findings/2026-07-06-stage4-rem-group-results.md`; **ADR-0022 Accepted**
>    `docs/decisions/0022-stage4-rem-group-named-metaanalyses.md`; ledger `.superpowers/sdd/progress.md`;
>    verifica `analysis/audit/2026-07-06-stage4-v8-antistale-regate.R` + `-remgroup-names.R` (+ CSV).
> 6. **PROSSIMO**: (a) **pulizia-nomi coda etichette** (LPS→"carnitine" ecc., handout
>    `docs/superpowers/specs/2026-07-06-name-cleanup-mistral-SESSION-AFTER-handout.md`); (b) augmentation
>    passo-3 (279 caduti); (c) Layer B re-curation con i 70 nuovi case-study. Branch invariato, master
>    invariato, no push. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-07-05 (ramo `rem_group` Stadio 4 — CODICE+VALIDAZIONE COMPLETI, FULLRUN v8 GATED)**:
> 🟢 **Fix del gate di selezione Stadio 4. Nuovo ramo di pooling `rem_group` che ammette le
> meta-analisi cross-studio NOMINATE (L2–L4, `safety_min` basso per design) che la selezione
> respingeva. Codice completo, final review Opus, validato sui dati veri. Fullrun v8 pronto (script +
> DRY_RUN PASS), GATED. Handout: `docs/superpowers/specs/2026-07-05-stage4-rem-group-fullrun-v8-NEXT-SESSION-handout.md`.**
>
> 1. **Causa** (finding `docs/findings/2026-07-05-stage4-selection-gate-excludes-named-metaanalyses.md`):
>    lo Stadio 4 v7 processava 433/317.304 cluster; la porta ammetteva group solo con `usable_mega_strict`
>    (`level∈{0,1}` + `safety_min≥0.7`) → 71/72 MEGA SENZA nome; SARS (k=25), enzalutamide (25), Breast
>    (88) esistevano ma `poolable=FALSE`. Logica MEGA applicata a target REM. Clustering v7 sano (95% omogeneo).
> 2. **Brainstorming→spec→plan** (5 decisioni utente): REM per-studio uniforme (both_roles+treated_only,
>    control in-study via `comparisons` stage2); porta strutturale senza `safety_min` + I²/τ² a valle;
>    ibrido documentato (no augmentation); soglie `k_eff≥3`/`n_min=2`, cap rimosso; dedup una meta-analisi
>    per entità al k massimo. `docs/superpowers/{specs,plans}/2026-07-05-stage4-rem-group-named-metaanalyses-*`.
> 3. **Impl subagent-driven (Task 1-7 TDD)**: config + porta `.identify_layer_a_clusters` + dedup +
>    dispatch-builder `.build_group_rem_dispatch_from_stage3` + `method_label` in `.pool_rem_cluster` +
>    orchestrator (filtro method + cutoff k_eff) + merge in build. Ogni task reviewato. `4f3a544`..`eb2a782`.
> 4. **Final review Opus**: **C1 CRITICAL** — il ramo era un **no-op silenzioso in produzione**
>    (`direction_check=NA` sui group → `if(NA)` → tryCatch skip ogni studio → pool vuoto; i test usavano
>    `"ok"`) → fix `isTRUE` coerce + difesa in profondità + test. **I1** (mismatch spec + pseudo-replicazione).
> 5. **Decisione utente I1**: gate `k_eff` su studi distinti + **collapse bracci intra-studio**
>    (`.collapse_arms_by_study`, inverse-variance FE, opzione C: sintesi per studio SENZA unire i campioni).
>    Limite noto: correlazione da control condiviso non modellata (raffinamento Franchini futuro).
> 6. **Validazione dati veri**: 70 rem_group AMMESSI (k_eff≥3) su 349; 6/7 bandiera (SARS k=12, enzalutamide
>    12, Breast 6, Prostatic 4, fulvestrant 5, tamoxifen 5, vemurafenib 4; Alzheimer cade); 279 cadono (no
>    comparison → ibrido, augmentation futura). Pool NON vuoto (enzalutamide 3747 sig, SARS 240; I² 58-92%).
>    Collapse validato (SARS 10→5 studi). Suite `stage4` 780 PASS, 2 FAIL PRE-ESISTENTI (dashboard quarto +
>    gene-axis E2, da `e8af92a`). Audit `analysis/audit/2026-07-05-stage4-rem-group-{smoke,collapse-validate}.*`.
> 7. **CACHE (lezione)**: v8 = re-pool (NON re-cluster) → il disastro v6→v7 (name-recovery Stadio 3) NON si
>    applica. Unica cache = **counts** (`stage4-counts/`, chiave `(v2_ensembl,biotype,gse,samples)`
>    method-independent): RIUSARLA (velocizza, no stale); nessuna cache del pooled → il ramo è sempre eseguito.
>    Verifica anti-stale: `Methods` include `rem_group`, ~70 pooled.
> 8. **Prossimo = FULLRUN v8 GATED** (~11-15h, `setsid`, `analysis/p4-fase-f5-stage4-layer-a-rebuild-v8.R`
>    DRY_RUN PASS: Layer A 885 = rem 8/mega 175/mega_aug 353/rem_group 349, 69238 sample). Poi closeout +
>    ADR-0022 Accepted. Branch invariato, master invariato, no push. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-07-04 (biologici v6 END-TO-END + FIX PATHOGEN v7 — CHIUSO)**:
> 🟢 **Pipeline end-to-end su v7. Fix estrazione pathogen materializzato.** Finding
> `docs/findings/2026-07-03-stage3-v7-pathogen-extraction.md`. Commit `1fb1520` (fix) + `409aa0a` (cache bump).
>
> 1. **v6 run gated (2026-07-01/02, setsid+loop)**: re-cluster Stadio 3 v6
>    (`…20260702T024122Z-stage3-v6-364547a7`, wall 8h06) → re-pool Stadio 4 v6
>    (`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v6/…-stage4-v6-4f7ea215`, 11h, 7,41M righe, 998k sig, 0 crash).
>    Re-gate v6: **cytokine 61→36% (VINTO, driver ImmPort), MA pathogen REGREDITO 33→44%** (unico kind peggiorato).
> 2. **Root cause pathogen (data-driven)**: NON vocabolario ma **ESTRAZIONE**. `.normalize_pathogen_to_taxid`
>    faceva solo match esatto del termine collassato mentre `.normalize_cytokine_to_hgnc` usava già
>    `.extract_compound_candidates` → asimmetria (cytokine 53% vs pathogen 8%). Stringhe rumorose
>    `STR:lps_exposed_for_24_hours`/`sars_cov_2_infected`/`poly_i_c_10_g_ml` non risolvevano.
> 3. **Fix `1fb1520` (TDD, precision-gated)**: `.normalize_pathogen_to_taxid` itera i candidati da
>    `.extract_compound_candidates` (LPS→CHEBI:16412; SARS-CoV-2→NCBITaxon:2697049; poly(I:C)→CHEBI:84491) +
>    vernacolo `mtuberculosis`. Guardie host-species per-candidato + taxdump solo su frasi. Smoke: K3 0/200,
>    generici 0/12. Misura pre-materializzazione (re-gate su v6 col fix): **pathogen 43,9→16,8%**.
> 4. **⚠️ CACHE-MISS (lezione)**: 1° re-cluster v7 (~8h) = output byte-identico a v6 → lookup disk-cached
>    riusato perché non bumpato `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`. Beccato dalla sanity. Fix v3→v4
>    (`409aa0a`) → re-run. Vedi memoria `feedback_bump_lookup_cache_version`.
> 5. **Ciclo v7 (2026-07-03/04)**: re-cluster v7 (`…20260703T113045Z-stage3-v7-364547a7`, 475min; NCBITaxon:
>    1149→2245, PATHOGEN_VERNACULAR cluster 521→1561, PAMP 371→872, 0 host-species) → re-pool Stadio 4 v7
>    (`/mnt/wwn-…/simulomicsr-stage4-v7/…-stage4-v7-4f7ea215`, 668min, **7.468.582 righe, 998.695 sig, 433 proc,
>    0 crash df-residui**). **RE-GATE v7: pathogen 43,9→11,2%** (meglio del previsto — v7 ha ri-poolato
>    coerentemente; ora ≈ disease 7,7%, batte v5 33%). cytokine/small_molecule 35,9% invariati, TOTALE 22,0→20,1%.
> 6. **TODO**: cytokine/small_molecule ~36% = copertura ChEBI/HGNC + granularità per-membro (NON estrazione);
>    **LLM-fallback finale** (DECISIONE C, precision-gated) sui residui STR/UNK = passo generale finale.
>    Branch invariato, master invariato, no push.
>
> **Stato 2026-07-01 (biologici v6 — codice+dizionari+fix VALIDATI (GO), rebuild PRONTO NON lanciato)**:
> 🟢 **Recupero-nome BIOLOGICI (citochine+patogeni) implementato + validato. 3 run pesanti gated da
> lanciare in sessione FRESH. Handout:
> `docs/superpowers/specs/2026-07-01-stage3-biologics-v6-rebuild-NEXT-SESSION-handout.md`.**
>
> 1. **Codice+dizionari+fix (subagent-driven TDD, tutti review/validati)**: dizionari reali in
>    `~/.cache/R/simulomicsr/` = taxonomy(3.35M nomi)/ImmPort(5046 syn, 927 whitelist, has_go)/
>    UniProt(68805)/GO(213). `.normalize_cytokine_to_hgnc`(→`HGNC:`) + `.normalize_pathogen_to_taxid`
>    (→`NCBITaxon:`/PAMP `CHEBI:`) + **K3 compound-first** + anchor `NCBITaxon:` + cache **v3**. Sanity ha
>    corretto **9 ID PAMP errati**. Design finale = **spec §13**
>    (`docs/superpowers/specs/2026-06-29-stage3-biologics-name-recovery-design.md`).
> 2. **Gate smoke (validate-before-fullrun) — HA FUNZIONATO**: smoke#1 NO-GO (K3 **8% falsi**, pathogen
>    3%) → Fix-A(K3 compound-first, elimina flip su farmaci veri; PAMP preservati via CHEBI∈whitelist) +
>    Fix-B(estrazione `.AGENT_KEYS`+vernacolo) + Fix-I1(anchor adotta ID forte su STR) → ri-smoke GO →
>    **final review Opus** trovò I-1 (`organism: human` → Homo-sapiens-as-pathogen su **747 sample**) →
>    Fix-D(trim `organism` + `.HOST_SPECIES_STOPLIST` + `.AGENT_CONTROL` infection-neg) → spot-check GO.
>    **Esiti reali**: cytokine **53%**, pathogen 3→**8%**, K3 **0 falsi genuini**, host-species **0/747
>    flip**, canary generici puliti. Report `docs/findings/2026-07-01-stage3-biologics-smoke.md`.
> 3. **Script re-cluster v6 PRONTO** (`analysis/p4-fase-f6-stage3-reclustering.R`, commit `0e9bb96`:
>    assert `has_taxonomy/immport/uniprot/chembl` fail-fast + token v6; SMOKE=1 PASS: HGNC:=1155,
>    NCBITaxon:, K3_MISTYPE attivi). **NON lanciato** (decisione utente: full in sessione fresh).
>    **Prossimo = 3 RUN GATED**: (a) re-cluster Stadio 3 v6 (~6-7h, `SMOKE=0 Rscript
>    analysis/p4-fase-f6-stage3-reclustering.R`, detached) → (b) re-pool Stadio 4 v6 (~10h su `/sda`,
>    preparare `-rebuild-v6.R` copia -v5) → (c) re-gate omogeneità v6 (attesi: cytokine 61%→giù, pathogen
>    33%→giù; disease/small_molecule invariati). Branch invariato, master invariato, **pushato**.
>    Ledger `.superpowers/sdd/progress.md`. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-06-29 fine sessione 21 (Plan B FASE 2 — run gated Task 8-10 COMPLETI)**:
> 🟢 **Pipeline end-to-end ri-girata su v5. Plan B (farmaci ChEMBL) CHIUSO.**
>
> 1. **Pre-flight**: `has_chembl=TRUE` (49099 molecole), fix df-residui `0c41848` nel
>    codice, input v4 presenti. **Task 8** (re-cluster Stadio 3 v5): 2 micro-edit allo
>    script `analysis/p4-fase-f6-stage3-reclustering.R` (assert `has_chembl` fail-loud +
>    token `v5`). Smoke PASS → full detached **400 min (~6h40)**, **317.434 cluster**,
>    `analysis/p4-output/20260629T041343Z-stage3-v5-364547a7/`. run_metadata: chembl reale
>    (`fixture_subset=false`), cache lookup `v2`. Recovery ChEMBL: 4407 cluster.
> 2. **Task 9** (re-pool Stadio 4 v5): script `analysis/p4-fase-f5-stage4-layer-a-rebuild-v5.R`
>    (copia -v4, 4 cambi: stage3_dir→v5, out_dir→`/sda`+token v5, 2 log). Smoke DRY_RUN PASS
>    (Layer A 533 cluster). Full detached **619 min (~10h19)**, **7.362.958 righe pooled**,
>    987.589 sig (FDR<0,05), 428 processed + 105 non-processable. **Zero crash df-residui**
>    sui 348 mega_aug (fix `0c41848` validato sul full). Output
>    `/sda/simulomicsr-stage4-v5/20260629T164735Z-stage4-v5-4f7ea215/`. Dashboard quarto
>    fallita (non-fatale, manca binario). Stima DRY_RUN 24h pessimistica (reale ~11h).
> 3. **Task 10** (re-gate omogeneità v5 + INDAGINE): `small_molecule` minestrone **49,0% →
>    36,5%** globale (criterio soddisfatto; altri kind non peggiorano). **Indagine del
>    residuo (gate utente)**: i 409 minestroni residui sono 97,5% anchor `CHEBI:` (NON
>    UNK/STR) → NON name-recovery insufficiente. Per livello (v4→v5): **L0 12,1→8,3%, L1
>    12,4→7,9%** (granulare = composto specifico, ora ≈ disease 7,7%), L2 23→17, L3 33→25,
>    L4 41→32 (pooling per classe ChEBI = minestrone in parte BY-DESIGN). Finding
>    `docs/findings/2026-06-29-stage3-v5-chembl-homogeneity.md`; audit
>    `analysis/audit/stage3-homogeneity-check-v5-full-out.{txt,csv}`.
> 4. **TODO (NON Plan B, sessioni future)**: biologici cytokine/pathogen (~61% residuo,
>    vocabolario dedicato + fix-tipo K3); **LLM-fallback finale** (DECISIONE C generale,
>    precision-gated) sui residui STR:/UNK; micro-fix casing `ChEMBL:`/`CHEMBL:` (20
>    cluster) al prossimo rebuild; caratterizzare 105 non-processable Stadio 4.
>    Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-06-28 fine sessione 20 (Opzione B — farmaci ChEMBL)**: 🟢 **FASE 1
> CODICE COMPLETA + final review clean + Task 6/7 gated (dict ChEMBL reale + smoke
> copertura) + stoplist precisione. Prossimo = RUN GATED re-cluster Stadio 3 v5.**
>
> 1. **Brainstorming→spec→plan** (gate utente): scope = SOLO farmaci/small-molecule
>    (biologici citochina/patogeno + fix-tipo K3 → TODO sessione futura, brainstorming
>    dedicato); DB = ChEMBL (CC BY-SA, copertura composti da ricerca); canonicalizzazione
>    ChEBI-preferred via pref_name ChEMBL (de-frammentazione); estrazione tollerante a
>    dose/tempo/combo; combo → ID-combo deterministico `+`. Spec/plan/HUMANE
>    `docs/superpowers/{specs,plans}/2026-06-28-stage3-perturbative-name-recovery-B-*`.
> 2. **FASE 1 codice (subagent-driven, Task 1-5, suite 1015 PASS/0 FAIL/0 ERROR)**:
>    dizionario ChEMBL (`R/ontology-lookup.R`: `.build_chembl_index`+accessor+loader
>    GRACEFUL con `has_chembl`); estrazione `.extract_compound_candidates` +
>    risoluzione `.resolve_one_compound`/`.normalize_compound_to_chebi` (catena
>    ChEBI→ChEMBL→de-frammentazione→combo→STR, gate precisione esatto C1); bump cache
>    lookup v1→v2 + asse `has_chembl` nella chiave; script build reale
>    `analysis/p5-audit-chembl-build-dict.R`. Commit `cd9b213`..`d4419a8`.
>    - **REGRESSIONE cross-task chiusa**: lo `stop()` su ChEMBL mancante nel loader (Task 1)
>      rompeva `test-anchor-parse.R` + ogni build di anchor → DECISIONE UTENTE: loader
>      GRACEFUL (chembl=NULL+has_chembl=FALSE) + assert-at-run negli script v5 (`83e1238`).
>    - **FINAL review (opus) Ready-to-merge + 1 Important**: chiave cache lookup non
>      distingueva has_chembl TRUE/FALSE → rischio servire lookup degradato v4 → fixato
>      (`aebfc68`, chiave include `has_chembl`+release).
> 3. **Task 6 (gated, DONE)**: download ChEMBL 37 SQLite (5.4G, SHA256 in
>    `analysis/p4-output/chembl-source-provenance.json`) → dict reale
>    `cache/chembl/chembl-lookup.rds` (49099 molecole, 128937 alias). Schema SQL VERIFICATO.
>    .db estratto (30G) scartato, tarball tenuto su `/sda`.
> 4. **Task 7 (gated, DONE — smoke copertura PRE-fullrun)**: **63,4% recupero** sui 484
>    drug-name candidates (driver dominante = ESTRAZIONE che sblocca farmaci già in ChEBI;
>    ChEMBL complementa i composti da ricerca; 46 combo). Canary precisione OK. **Finding:
>    7/362 match generici spuri** (drug/acid/inhibitor/agonist/ligand/peptide come token
>    isolati → merge spuri) → **stoplist** `.GENERIC_COMPOUND_STOPLIST` (commit `3bd8728`):
>    match generici **7→0**, recupero 63,4%, farmaci reali invariati.
> 5. **Prossimo (sessione 21, GATE UTENTE)**: Task 8 re-cluster Stadio 3 v5 (~6h, assert
>    `has_chembl` + SMOKE=1 sanity + SMOKE=0 detached) → Task 9 re-pool Stadio 4 v5 (~11h,
>    `/sda`, fix df-residui già committato) → Task 10 re-gate omogeneità v5 (small_molecule
>    atteso giù dal 49%) + closeout. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-06-26 fine sessione 18**: 🟢 **REWORK Stadio 3 — FASE CODICE COMPLETA
> (Task 1-12 + final whole-branch review fix) + smoke gate validato (Task 13). Restano
> i 3 run gated Task 14-16.**
>
> 1. **Task 8-12 (subagent-driven-development)** sul plan
>    `2026-06-25-stage3-name-recovery-reclustering-plan.md`, tutti review-Approved:
>    - T8 `build_name_recovery_lookup` (`R/stage3-name-recovery-lookup.R`): env GSM→identità
>      dall'H5, lettura iniettabile, cache version-aware (commit `831afd8`).
>    - T9 `.extract_anchor_segments(recovery=NULL)` (`R/stage3-anchor-levels.R`): UNK→agente
>      recuperato, K2 genetic→kind, 3 trace-field nel tracking_meta solo con recovery non-NULL;
>      retrocompat anchor 89 test. Fix Important: NA-guard su `recovery$kind` (crash `if(NA)`).
>      Commit `d3e9404`,`3dd52d1`.
>    - T10 thread del lookup nel build (`R/stage3-build.R`): `.precompute_anchor_cache(recovery_lookup=NULL)`
>      + `build_stage3_clusters(name_recovery_lookup=NULL)`; retrocompat byte-identica, suite stage3 490.
>      Commit `8075fae`. (NB: nel loop `parts[1L]`="sid" è il GSM RAPPRESENTANTE, non series.)
>    - T11 gate omogeneità (`analysis/audit/stage3-homogeneity-check.R`): Important di VALIDITÀ fixato
>      con scelta utente A — conta le identità solo sui GSM MEMBRI (treated/case) via
>      `record_id→stage2 master`, H5 per geo_accession diretto. Minestroni 84,8%→66,8% su v3
>      pre-rework. Commit `129052e`,`0ae2823`.
>    - T12 benchmark LLM (`analysis/audit/name-recovery-llm-benchmark.R`, eval fuori produzione):
>      det 63,4% recupero, template gold 52 righe; LLM+gold+decisione C GATED. Helper condiviso
>      `analysis/audit/_gsm-lookup-helper.R` (`build_record_gsm_lookup`). Commit `046301d`,`4cffb8e`.
> 2. **FINAL whole-branch review (opus)**: integrazione SOLIDA (retrocompat byte-identica,
>    tracking_meta 12→15 consumato safe da `.summarize_clusters`, data-flow coerente). Ma 1
>    CRITICAL + 3 Important cross-task che i per-task non vedevano → fix completo (scelta utente A,
>    4 commit atomici `368e8b3`,`f957cfd`,`1087d41`,`602c2fb`, suite 283/0):
>    - **C1**: regex K2 girava con `ignore.case=TRUE` → annullava il vincolo case-sensitive di
>      `sh[A-Z]`/`si[A-Z]` → flippava a genetic_* composti/agonisti REALI (Resiquimod case study
>      noto-buono, simvastatin, sirolimus, "single cell", "serum depletion"). Fix: pattern di forma
>      case-SENSITIVE (`_CS`) vs robusti case-insensitive (`_CI`); `depletion` ristretto; `auxin`/`iaa`
>      standalone rimossi; +`\boe\b`/`\bKO\b`/`\bAID\b` case-sensitive. 6 canary.
>    - **I1**: `match(gsm, geo_accession~888k)` vettorizzato fuori dal loop (era O(n²)).
>    - **I2**: target K2 validato vs `.hgnc_lookup_symbol` (gene reale→HGNC, token non-gene→STR/NA).
>    - **I3**: 3 colonne trace (`recovery_source`/`agent_id_recovered`/`kind_recovered`) additive a `clusters.rds`.
> 3. **Task 13 smoke gate (RUN GATED leggero) — ESITO ECCELLENTE su dati reali**:
>    breast `group_L4_f12efec4` CONCORDANTE (MeSH:D001943); blood `group_L4_cc07ca23` MINESTRONE
>    SCOMPOSTO in **19 malattie distinte** MeSH-resolved; HCT116 `group_L0_686d6360` K2 (67% flippati
>    a genetic_*, geni HGNC reali INTS11/PNUTS/WDR82/XRN2, titoli "POINT-Seq XRN2-dTAG"). Canary C1
>    REGGE sui dati reali. Regime U1 atteso (NO_RECOVERY ~53% blood, non persi).
> 4. **MINOR defer residui** (non-bloccanti per i run gated): `kind_by_gsm` come env vs list a scala
>    (O(n²) → environment al full run); `.parse_characteristics_kv` splitta su "," → slug numerici
>    degeneri (STR:1/STR:464); + ledger T5/T7/T8(M1-4)/T10(M1-2)/T11(R1-R2).
>
> **Resume sessione 19**: leggi `.superpowers/sdd/progress.md` (ledger, Task 1-13 complete) + il plan
> §Phase 6. Prossimo = **Task 14 re-cluster Stadio 3 v4** (run pesante ~ore, GATE UTENTE): script
> `analysis/p4-fase-f6-stage3-reclustering.R` (preparato + smoke-validato in sessione 18 — vedi
> `.superpowers/sdd/task-14-prep-report.md`). Costruire `kind_by_gsm` come **environment**. Poi Task 15
> (ri-pooling Stadio 4, DGX) + Task 16 (gate omogeneità v4, criterio ~0 minestroni provati). Branch
> invariato, master invariato, no push. Memorie: [[project_stage3_minestrone_rework]].
>
> **Stato 2026-06-25 fine sessione 17**: 🔴 **F6 Fase A run pieno FATTO + bug I² rem
> fixato; in Fase B scoperto difetto MINESTRONE a monte → REWORK Stadio 3 deciso e
> in esecuzione (Fase 1 modulo completa).**
>
> 1. **F6 Fase A run pieno** (`SMOKE=0 VPC_WORKERS=24`, ~3h): `cluster_reproducibility_v2.rds`
>    (776 cluster) + `cluster_vpc_per_gene.parquet` + `cluster_pi_per_gene.parquet` in
>    `…stage4-4f7ea215/`. **Bug paper-grade trovato+fixato**: l'I² in `cluster_pooled` è
>    PERCENTUALE 0-100, ma `.consistency_score` voleva una frazione 0-1 → `1−I²` con I²=40
>    dava −39→clamp 0 (16/28 rem falsamente azzerati). Lo smoke non l'aveva visto (pescava
>    i 2 rem con I²≈0). Fix: helper `.rem_consistency_from_i2` (TDD) + env `METHODS` per
>    ri-girare solo rem+mega_aug riusando i mega. Commit `8fc9d7d`,`828e4ca`. Distribuzione
>    corretta: mega cons_med 0,525 · rem 0,715 · mega_aug 0,818.
> 2. **Finding MINESTRONE (paper-grade, blocca F6)**: i cluster `disease_vs_normal`
>    raggruppano malattie DIVERSE (es. "sangue" = HIV+Alzheimer+leucemia+dermatomiosite)
>    perché l'anchor non porta il nome (`agent=UNK`, `R/stage3-anchor-levels.R:52` legge solo
>    il campo LLM `disease_state$mesh_id_candidate`, spesso "unknown" → collassa sul tessuto).
>    Misure: **37%** dei 177 disease cluster mescolano ≥2 malattie; **70%** dei 37
>    robusti-candidati. **La consistenza NON protegge** (minestroni a cons 0,91-1,00:
>    segnale generico aspecifico). `small_molecule` simile: degron mal-etichettati + theme-pooling.
> 3. **Decisione utente: REWORK Stadio 3**. Recupero deterministico nome malattia/composto
>    dai metadati GEO grezzi + ontologia (A) + benchmark LLM→eventuale ibrido (C); scope tutti
>    gli `UNK` (S3); granularità livello-malattia (G2); ignoti non-poolati (U1); correzione tipi
>    palesemente sbagliati (K2). Spec `docs/superpowers/specs/2026-06-25-stage3-name-recovery-reclustering-design.md`
>    + plan + HUMANE committati (`37beb97`,`c6a4208`).
> 4. **Esecuzione plan (subagent-driven) — Fase 1 COMPLETA**: modulo puro
>    `R/stage3-name-recovery.R` (Task 1-7: parse characteristics, estrai malattia/composto, K2
>    genetico, normalizza MeSH/ChEBI, orchestratore **`recover_identity`** esportato), **62 test
>    PASS**. La review ha pescato 1 bug vero (tolower fallback) + 3 Minor (nel ledger).
>    Commit `f88695f`..`96c8750`. **Prossimo = Task 8** (lookup `GSM→identità` dall'H5, Fase 2),
>    poi Task 9-10 (innesto in `.extract_anchor_segments`/`.precompute_anchor_cache`), 11-12 (gate
>    omogeneità + benchmark LLM), 13-16 (run gated: re-cluster Stadio 3 v4 → ri-pooling Stadio 4 →
>    collaudo omogeneità). **F6 Fase B/C/D SOSPESE** finché il rework non rende i cluster coerenti
>    (la consistenza da sola non è il gate; serve il gate di omogeneità).
>
> **Resume sessione 18**: leggi `.superpowers/sdd/progress.md` (ledger) + il plan, riparti dal
> Task 8 con la skill `superpowers:subagent-driven-development`. Branch
> `review-scientific-consistency-2026-06-10`, master invariato, no push. Memorie:
> [[project_stage3_minestrone_rework]]. Vedi `docs/RED_ALERT.md` §F6 + §Handoff sessione 18.
>
> **Stato 2026-06-16 fine sessione 16**: 🟡 **F6 Fase A — metrica di consistenza
> cross-studio implementata + verificata (run pieno da lanciare).** Deep research
> metodologica (2026-06-15) ha ribaltato la %DE/Spearman (non difendibili: winner's
> curse) → asse di consistenza [0,1] per-metodo (mega = 1−VPC(study) via
> variancePartition; rem = 1−I² + prediction interval REML+HKSJ; mega_aug k=2 =
> sign-concordance), sempre sui geni FDR-sig. **ADR-0021** + spec + piano. 4 helper
> **TDD** (`R/stage4-consistency.R`, 24 expect_*) + script
> `analysis/p4-fase-f6-consistency.R`. **Smoke SMOKE=2 PASS** (3 fix: formula VPC
> categoriche-random, `<<-`→`<-`, parallelizzazione VPC_WORKERS) + **verifica round 2
> PASS**: componenti VPC sommano a 1, allineamento geni 100%, **vpc_study
> cross-validata vs lme4 indipendente entro 0,05**, scelta geni-sig validata (separa
> segnale da rumore dei nulli: rem I² 84% su tutti i geni → ~1% sui sig). Commit
> `57c9f19`..`f342a5f`. **Prossimo (gate dato): run pieno** `SMOKE=0 VPC_WORKERS=24
> Rscript analysis/p4-fase-f6-consistency.R` (~3h sui 173 mega) →
> `cluster_reproducibility_v2.rds` (776 cluster) + parquet per-gene; poi Fase B
> shortlist (soglie con l'utente, `pi_frac_excl0` primario per i rem che saturano a
> cons≈1), Fase C validazione esterna (LINCS+pathway+LOO sui candidati), Fase D
> selezione ~15. **Finding**: covariate batch + SAMN-dedupe inerti nel fullrun F5
> (h5_metadata senza quelle colonne). Master git invariato, no push. Vedi
> `docs/RED_ALERT.md` §F6 + §Handoff sessione 17.
>
> **Stato 2026-06-14 fine sessione 15**: 🟢 **F4 (Stadio 3) + F5 (Stadio 4 Layer A)
> ricostruiti + metrica di riproducibilità per F6**. **F4 Stadio 3** (run
> `364547a7`, wall 221 min) sul master v3 + anchor v3.1.1 + completeness guard (ora
> legge `member_sample_ids`, commit `c6b9d51` TDD): **292.518 cluster, 546.905
> assignment**, guard 18.004 sample → `unclear` (≈3,5% REGOLA 4). Sanity PASS —
> regressione chunk-collision **chiusa** (0 suffissi chunk; `n_control=NA` sui group
> è per-design mega_aug). **F5 Stadio 4 Layer A** (run `4f7ea215`, wall 24h, 32
> dream worker, RSS picco 20,6 GB, FASE E default = ensembl+biotype+covariate):
> **776 cluster** (173 mega + 575 mega_aug + 28 rem) + 118 mega_rank_deficient,
> **13,28M righe pooled, 1.677.343 geni significativi (FDR<0,05)**; vs 96c43acb
> 776 vs 487 pooled (mega_aug ~raddoppiato, rem 0→28). Smoke gate pre-fullrun PASS
> (gene axis 100% Ensembl); dashboard quarto fallito (non-fatale, ri-renderizzabile).
> **Metrica riproducibilità per F6**: validazione ha mostrato che la **%DE NON è
> diagnostica** (cluster ad alta %DE sono per lo più CONCORDI = biologia reale;
> l'"artefatto" 80,7% DE aveva concordanza 1,00). Scelta utente: **concordanza
> cross-studio (B)** come gate POSITIVO di riproducibilità + **I² (A)** come asse
> complementare ortogonale (cor 0,03). Copertura B: rem k=3-8 (trusted), mega_aug
> k=2 (fragile ma dove stanno 71/75 artefatti), mega k=0 (non calcolabile,
> accettato). Script `analysis/p4-fase-f6-concordance.R` → `cluster_reproducibility.rds`;
> doc `analysis/audit/F5-concordance-metric.md`. Commit `c6b9d51`..`0defe37`.
> **Prossimo = F6 (Layer B re-selection)**: ri-girare lo shortlist sul nuovo
> `cluster_pooled.parquet` con la concordanza al posto della %DE, **soglie da
> fissare con l'utente**, ri-curare la selection, ri-girare il batch. Poi FASE G
> (doc + tag). Branch `p5-llm-anchor-classification-audit`, master git invariato,
> no push. Vedi `docs/RED_ALERT.md` §F5/§F6 + §Handoff sessione 16.
>
> **Stato 2026-06-11 fine sessione 14**: 🟢 **Stadio 2 v3 COMPLETO (opzione C) —
> fullrun + rescue + master**. Fullrun Stadio 2 v3 (slurm 24022, wall 15h20m):
> **24.953/24.972 valide (99,924%)**, 19 fail-schema su 10 studi. Audit dei fail
> (before-patch): **tre meccanismi distinti** di troncamento output — esplosione
> confronti (multi-fattoriale ~4-6 cmp/condizione), esplosione rep_groups (centinaia
> di condizioni/chunk), degenerazione/flood — + caso multi_arm a tier S. Rescue con
> config unica: nuovo parametro **`max_treated_per_chunk=12`** di `.chunk_conditions`
> (TDD, retrocompatibile, commit `e1dec27`) + **`max_tokens` 32768 piatto** +
> **`rep_pen` 1.2** (deviazione di config, NON di prompt, tracciata come β). Slurm
> 24222: **506/506 valide, 0 residui** (wall 26 min). **Master Stadio 2 v3: 24.394
> studi, 1 record/studio** (guard `.assert_stage2_one_record_per_series` PASS), studi
> re-chunkati ricomposti per series (GSE249377: 268 chunk → 1 record, 3146
> replicate_groups, 123 cmp), 490.051 campioni coperti (resto = coverage gap REGOLA 4,
> lo chiude il completeness guard a F4). Deliverable
> `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl` (gitignored, schema stage2.v2).
> Script `analysis/p4-fase-f4-stage2-rescue-build-v3.R` + `-rescue-submit-v3.R` +
> `-collect-v3.R`. Finding paper
> `docs/findings/2026-06-11-f4-stage2-v3-rescue-and-generalization.md` (il rescue è
> una **procedura data-adaptive**: stessa cassetta a tre leve su β/F3/F4, valori da
> ri-derivare per corpus). Commit `e1dec27`..`b84231b`. **Prossimo = F4 (Stadio 3
> rebuild) sul master v3 + anchor v3.1.1** (sessione 15). PRIMA: adattare il
> completeness guard a `member_sample_ids` (oggi legge geo_accession = rappresentante).
> Poi F5 (Stadio 4) → F6 (Layer B). TODO tracciati: completeness guard
> `member_sample_ids`; indagine single-cell Stadio 0 (~313 studi degeneri). Branch
> `p5-llm-anchor-classification-audit`, master git invariato, no push. Vedi
> `docs/RED_ALERT.md` §F4 + §Handoff sessione 15.
>
> **Stato 2026-06-10 fine sessione 13**: 🟢 **F4 opzione C implementata fino allo
> smoke gate PASS**. Ridisegno input Stadio 2 a condizioni di disegno deduplicate
> per firma (niente chunking per-campione). TDD (179 expect_*): `design_signature`
> (campi = sola condizione sperimentale, raffinati data-driven con tissue_segment +
> agent_raw) + `.build_study_conditions` + `.chunk_conditions`/`.is_control_condition`
> (coda D2: chunk per-condizione + broadcast controlli, cap 0.3) + espansione/fusione/
> assembly (`.expand_study_design`/`.merge_chunked_designs`/`.assemble_stage2_study`).
> Build input v3 (`analysis/input/archs4-human-stage2-input-v3.jsonl`, gitignored):
> **24.972 record** (24.149 a 1 record + 245 studi-coda chunkati, budget 80k char),
> **0 campioni persi**, ricostruzione esatta. Due fix trovati dai dati
> (audit-before-patch): encoding firma (µM/uM, NA-string) + esplosione chunk da
> broadcast. Cambio prompt Stadio 2 **gated** (A: sezione "Input format" nel system
> prompt R; B: strip `member_sample_ids` in `prompts.py`). `.reassemble_stage2_chunks`
> **sostituita** dal guard fail-loud `.assert_stage2_one_record_per_series` (stage3+4
> build). **Smoke gate 72 studi gold: schema 100%, accuracy 94,04% (= baseline F3),
> coverage 21→5 → PASS** (`analysis/audit/F4-stage2-smoke-v3-eval.md`). Decisioni a
> libro in ADR-0020. **Prossimo = fullrun Stadio 2 v3 sul DGX** (sessione 14, gate
> separato) → master v3 → F4 (Stadio 3) → F5. TODO tracciati: completeness guard su
> `member_sample_ids`; indagine single-cell Stadio 0 (~313 studi degeneri). Branch
> `p5-llm-anchor-classification-audit`, master git invariato, no push. Vedi
> `docs/RED_ALERT.md` §F4 + §Handoff sessione 14.
>
> **Stato 2026-06-04 fine sessione 12**: 🔴 **F4 bloccato da finding paper-grade
> chunk-collision → pivot a opzione C (ridisegno input Stadio 2)**. Agganciando
> il completeness guard è emerso (via code review) un difetto **pre-esistente**:
> gli studi grandi sono spezzati in chunk cs50, lo Stadio 2 classifica ogni fetta
> in modo incoerente, e a valle `record_id = series__suffix` collide +
> `.index_stage2_master` (per series, last-wins) tiene solo l'ultimo chunk →
> **35% dei campioni F3 (55% nel run β già prodotto `96c43acb`) misrisolti** nel
> pooling DE + ~435 confronti REM cross-chunk persi. Finding
> `docs/findings/2026-06-01-stage3-stage4-chunked-study-sample-resolution-bug.md`,
> repro `analysis/audit/F4-chunk-collision-repro.R`. Tentato fix a valle
> (riassemblaggio namespacing) → scartato (perde i confronti cross-chunk).
> **Decisione utente: opzione C (root cause)** — dare allo Stadio 2 le condizioni
> di design distinte (mediana 13/studio) deduplicate per firma, niente chunking,
> poi espandere. **ADR-0020 Proposed** + spec/HUMANE
> `docs/superpowers/specs/2026-06-02-stage2-design-signature-dedup-*`. **D1 decisa**
> (firma = sola condizione sperimentale, esclusa identità individuale donor/age/
> sex/ancestry). D2/D3/D4 residue (gate prossima sessione). C re-runa Stadio 2
> (rifà F3 → master v3, 1 record/studio), poi F4, F5. Stadio 1 (F2 508k) invariato.
> Codice namespacing uncommitted (superato da C, da gestire). I risultati
> `96c43acb` + Layer B `56b911e6` **non affidabili** come baseline. Master git
> invariato, no push. **Prossimo = implementare C** (vedi `docs/RED_ALERT.md`
> §Handoff sessione 13).
>
> **Stato 2026-05-31 fine sessione 11**: ✅ **F3 — Stadio 2 fullrun v2 (28.544)
> + rescue cascade → 100%**. Build input dal master Stadio 1 v2 congelato:
> **28.544 record / 24.394 studi**, guard `is_zero_timepoint` 12.967 flag corretti,
> 0 drop. Smoke Stadio 2 sui 72 studi gold (756 campioni) solo su Stadio 2 sul
> materiale congelato: schema **100%**, accuracy **94,04%** (= baseline sessione 9),
> gate PASS. Fullrun job 22948 (job unico 4-worker, config invariata, tier XL
> 25,6%): wall **~29h**, validità **99,874%** (36 fail su 28.544, sparsi, ~ β).
> Throughput oscillante (~6-19/min), dip notturno al pareggio ~6/min poi rientrato,
> monitoraggio orario, nessun intervento reattivo. Rescue: cs25 resplit 32/36 +
> cascade rep_pen=1,2 sui 4 residui (studi piccoli, JSON malformato) → 4/4. **Master
> finale 28.567 record, 100,0000% validi, 24.394 studi**
> (`analysis/p4-output/p4-fase-f3-stage2-master-rescued.jsonl`, gitignored,
> `rescue_source` ×59). Doc NEWS 9029 + RED_ALERT §F3 ✅. Commit
> `P5 audit RED_ALERT F3: *`. Branch invariato, master git invariato, no push.
> **Prossimo = F4 (Stadio 3 rebuild)**: prompt in
> `analysis/p4-fase-f3-NEXT-SESSION-PROMPT.md`. Vedi `docs/RED_ALERT.md` §F3 +
> §Handoff sessione 12.
>
> **Stato 2026-05-29 fine sessione 10**: ✅ **F2-fullrun Stadio 1 v2
> (508.037) + rescue cascade → 100%**. Fullrun sul bacino di produzione,
> config invariata, prompt v2 + guard `is_zero_timepoint` a valle: 51 chunk
> da 10k + 25 outlier, wall ~11h40m, ~13.8 min/chunk, 0 HALT. Validità
> LLM-only 99.712% (1.464 fail). Diagnosi paper-grade (audit before patch):
> fail rate 3x vs β = **fragilità prompt v2** (81.6% fail nuovi via overlap
> GSM; 22/23 residui = GSE157354 chimera human-mouse), NON infra/dati;
> accuratezza già validata 94-96%. Rescue cascade β (H1 rep_pen=1.2→1.317 /
> H1.2 rep_pen=1.3→124 / H1.3 rep_pen=1.4→21 / H1.4 manual 2) → master
> rescued **508.037/508.037 = 100%**, tag `rescue_source`. Deliverable
> `analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl`
> (gitignored). Commit `bda18f8`..`6ecd7b1` + closeout doc (RED_ALERT F2 ✅,
> NEWS 9028, finding §5). Branch ahead master 102 commit, master invariato,
> no push. **F2 chiuso; prossimo = F3 Stadio 2 fullrun** (build input v2 +
> smoke gate + fullrun). Vedi `docs/RED_ALERT.md` §Handoff sessione 11.
>
> **Stato 2026-05-28/29 fine sessione 9 (+ lavoro autonomo)**: ✅
> **F2-smoke + root-cause + fix `is_zero_timepoint` + benchmark scalato**.
> Gate F2-smoke (100 sample) → accuracy mini-gold 92.93% < 93% → STOP.
> Indagine systematic-debugging (3 run DGX): causa = **fragilità prompt
> Stadio 1** (D1b `molecule_hint` + D4 `organism_hint` destabilizzano
> `duration.is_zero_timepoint` → REGOLA 2 stage2 time-zero=control). NON il
> prompt Stadio 2 (controprova IT identica), NON drift infra (β-prompt
> recupera 98%). Fix: **guard deterministico** `R/stage1-normalize.R` (TDD 38
> expect_*) agganciato nel build input Stadio 2; mini-gold 92.93% → **97.00%**
> senza toccare il prompt. Commit `301bdc8`/`bc40793`/`03abb8b`.
> **Benchmark design-aware scalato**: gold LLM-assisted 756 sample / 72 studi
> reali bacino v2 (calibrato 88.2% vs gold umano), binary accuracy **94.14%**
> (full) / **96.02%** (raffinato). 5/717 plausibili errori pipeline; resto =
> multi-asse + coverage gap 3.5%. Finding
> `docs/findings/2026-05-28-f2-stage1-prompt-fragility.md`. **Gate
> pre-F2-fullrun PASS.** Prossimo step: **F2-fullrun** (508k, ~12-15h DGX) in
> sessione 10 con gate utente esplicito. Master invariato.
>
> **Stato 2026-05-28 fine sessione 8**: ✅ **pre-flight (5/5) + FASE F1
> chiusi**. Branch ahead master di **84 commit**. Prossimo step:
> **F2-smoke** (100-sample gate DGX) in sessione 9 separata, poi F2
> fullrun in sessione 10. Highlights sessione 8:
> - **Fix math error bacino**: 507.838 → **508.038** (oracle audit) era un
>   errore aritmetico di sessione 4 (+378 invece di +578), verificato
>   empiricamente su A3 TSV. Propagato in ADR-0019 + A3 + RED_ALERT.
> - **F1 ETL re-run** (`analysis/p4-fase-f-etl-build.R`, nuovo): bacino
>   produzione **508.037 sample** (`archs4-human-stage1-input-v2.jsonl`,
>   gitignored). Set equality vs oracle: extra=0, missing={GSM3612196}.
>   Lo script β era stale pre-FASE-C (5 problemi: H2 assente, H2-su-raw,
>   molecule droppato, D4 non applicato, H5_PATH errato) → riscritto.
> - **H2 mouse-mislabeled come filtro Stadio 0** (opzione A1 + drop pulito
>   (i) scelte utente): drop dei 72 GSE su series RISOLTO (post-resolver),
>   non raw H5. Helper `.flag_mouse_mislabeled_h2` + `.build_libsize_vec`
>   (TDD). GSM3612196 (GSE126753, 78.6% murino, residuo H2 di β) rimosso →
>   F1 è 1 sample più pulito dell'oracle.
> - **Pre-flight verificati**: smoke `is_sample_classifiable` 7/7 reali +
>   7/7 coverage TDD; `build_archs4_metadata_v2` full H5 GATE PASS
>   (n_kept 509.033 = F1 pre-H2, schema F5-compatibile, biosample SAMN
>   99.98%); config DGX live OK (.sif v0.20.2 presente, partition
>   infinite, Mistral cached).
> - **Igiene**: DESCRIPTION 9020→9026 (allineata + bump F1), man/*.Rd
>   rigenerati (42 file drift sessioni 5-7, NAMESPACE invariato),
>   dgx_p4_submit default time 12h→72h (preferenza utente), cache
>   stage4-counts purgata (−5 GB pre-E1).
> - **Nota downstream tracciata**: `build_archs4_metadata_v2` non applica
>   H2 → RDS include i 996 H2-survived-D1-D4, inerti a F5 (lookup solo su
>   GSM dei cluster post-H2). Da risolvere/documentare a F5.
>
> **Stato 2026-05-27 fine sessione 7**: ✅ **FASE A+B+C+D+E0+E0b chiuse
> (21/19 task)**. Sessione 7 ha chiuso E0b — collasso same-SAMN cross-GSE
> in pool Stadio 4 — con scelta utente (a) drop deterministico max
> `lib_size`, tie-break GSM alfabetico:
>
> **Evidence pre-implementazione: A7b** in `analysis/audit/A7b-*` —
> sui 425 GSM cross-GSE: 0% mix per `library_source` / `molecule_ch1` /
> `data_processing`, 45% mix per `instrument_model`, 95% mix per
> `extract_protocol_ch1`. Mediana `lib_size_ratio` cross-GSE 2.23×.
> Counts correlation cross-GSE Pearson(log1p) 0.41-0.75 anche con
> metadata identico (NON replicati tecnici). Upper bound 128 group
> cluster colpiti (32.4% dei 176 SAMN duplicati). Opzione (b) average
> counts scartata (statistica indifendibile cross-pipeline), opzione (c)
> sotto-noise scartata (non diluito).
>
> **Implementazione E0b in 7 commit bite-sized TDD**:
> - T1 `13d5342`: helper `.dedupe_gsm_by_samn` + `.lookup_chr/_num` +
>   `.empty_samn_dedupe_dropped` in `R/stage4-samn-dedupe.R` (nuovo file,
>   38 expect_*). Regola: max libsize, tie-break alfabetico GSM, NA SAMN
>   preservato (no collapse), `exclude_samn` per cross pair-baseline.
> - T2 `8fc6491`: integrazione MEGA pure in `.build_mega_metadata_safe`
>   (signature `biosample_lookup` + `libsize_lookup` default NULL =
>   retrocompat). `conflict_type = "cross_gse_samn_dedupe_kept_<gsm_kept>"`
>   in `pooling_warnings`. 14 expect_*.
> - T3 `5f600e1`: integrazione MEGA-AUG baseline pool in
>   `.assemble_mega_aug_metadata_bidir` + closure `build_baseline_rows`
>   con `exclude_samn = pair_samn_set` (cross pair-baseline). Return
>   list 8 -> 9 campi (`samn_dedupe_log`). 20 expect_*.
> - T4 `b386144`: `.build_samn_dedupe_lookups(h5_metadata)` helper +
>   propagazione down via `.pool_all_clusters` parametri lookup. Fallback
>   graceful (warning) se `biosample_id` o `lib_size` mancanti in
>   h5_metadata. 18 expect_*.
> - T5 `88d916c`: `stage4_default_config()$schema_versions$samn_dedupe_strategy
>   = "max_libsize_alphabetic_tiebreak"`. Registrato in run_metadata.json.
> - T6 `6ed729d`: smoke integration end-to-end MEGA pure (8 expect_*).
> - T6b `9fee42c`: **fix paper-grade self-review** — propaga
>   `assembled$samn_dedupe_log` MEGA-AUG in `pooling_warnings`
>   dell'orchestrator. Era persa silenziosamente (asimmetria con MEGA
>   pure). Schema conflicts standard (`cluster_id, sample_id, studies=NA,
>   roles=arm, conflict_type`). 5 expect_*.
>
> **Doc aggiornati**: A7b sintesi (`analysis/audit/A7b-samn-duplicate-analysis.md`),
> ADR-0019 §D9 con criterio max-libsize, RED_ALERT.md §E0b status ✅.
> Codex CLI tentato per review esterna: auth ChatGPT non supporta i
> modelli gpt-5.x-codex con quel tier (errore `400 invalid_request_error`)
> -> review affidata a Claude Opus 4.7 paper-grade. Self-review ha
> scoperto il finding T6b. Nessun whack-a-mole.
>
> Test suite E0b perimetro: **49 test_that, 202 expect_* PASS, 0 FAIL**
> (7 file: samn-dedupe, samn-lookups, mega-safe, mega-aug-samn, e0b-schema,
> e0b-smoke + delta su mega-aug-bidir). Branch ahead di master di **44
> commit** (37 pre-sessione 7 + 7 commit E0b T1..T6b). Master invariato.
>
> **Aggiornamento sessione 7 post-E0b — FASE E1 chiusa (gene axis Ensembl)**:
> ✅ FASE A+B+C+D+E0+E0b+E1 chiuse (22/19 task). E1 ha sostituito ADR-0016
> Decision 2 (workaround make.unique) con axis Ensembl ID univoco
> (67186 ID, 0 NA in H5 v2.5). Schema breaking pulito: colonna `gene`
> -> `gene_id` (Ensembl) + nuova `gene_symbol` (HGNC label, NA-aware).
> Layer B aggiornato (7 plot file): label leggibile = symbol con
> fallback gene_id. GO enrichment switch keyType SYMBOL -> ENSEMBL +
> readable=TRUE.
>
> **Implementazione E1 in 6 commit bite-sized TDD**:
> - `d9bcc00` T1: helper `.parse_gene_axis` (early-fail su NA, "", duplicati)
> - `93b8b3e` T2: `.h5_gene_axis` Ensembl + `.attach_gene_annotation` attr named
> - `13d88a1` T3: DE functions schema gene_id + gene_symbol; rimosso defensive
>   make.unique sostituito da stop() guardia
> - `3e486ec` T4: orchestrator cbind cross-study riattacca attr (catturato
>   durante self-review)
> - `5ba0786` T5: Layer B compatibility (7 file + helper fixture + 3 test)
> - `934d156` T6: cache key disk + schema_versions bump v2_ensembl_gene_axis
>
> Test perimetro E1 + Layer B: **669 expect_*, 0 fail** (38 file).
> Self-review paper-grade Opus 4.7 ha confermato integrita' algoritmica.
> Codex CLI ancora non utilizzabile (auth ChatGPT tier no gpt-5.x-codex,
> documentato in E0b). ADR-0016 Decision 2 marcato "Superseded by
> ADR-0019 §D6".
>
> **Aggiornamento sessione 7 post-E1 — FASE E2 chiusa (2026-05-28)**:
> ✅ FASE A+B+C+D+E0+E0b+E1+E2 chiuse (23/19 task). E2 ha implementato il
> filter `gene_biotype` di default 'protein_coding' (~23k geni su ~67k)
> alla sorgente Stadio 4. Parametro `build_stage4_results(gene_biotype_filter)`
> NULL = no filter, vector = union.
>
> **Implementazione E2 in 5 commit bite-sized TDD**:
> - `605ceb6` T1: `.parse_gene_axis` estende a 3-comp (ensembl + symbol +
>   biotype); `.attach_gene_annotation` setta attr gene_biotype named
> - `5f39215` T2: `.h5_gene_axis` legge meta/genes/biotype (cache key
>   `v3_with_biotype`); `.fetch_counts_from_h5` parametro filter +
>   helper `.apply_biotype_filter` NA-strict
> - `b7deb8e` T3: `.cache_key_for_fetch` stratifica per biotype filter
>   (permutazioni vector normalizzate); `.fetch_counts_cached` propaga
> - `3536dd4` T4: `build_stage4_results` parametro + closure default
>   propaga via `with_mocked_bindings`
> - `84d0ccc` T5: `schema_versions$gene_biotype_filter_strategy` +
>   `run_metadata$gene_biotype_filter` registrato; JSON pretty include
>   top-level field
>
> Test perimetro E2: 26 test_that, 61 expect_* PASS / 0 FAIL post-T7a+T7b
> (era 18/37 pre-fix). Perimetro stage4+layer-b totale: 744 expect_*.
>
> **Codex CLI finalmente eseguibile (2026-05-28 fine pomeriggio, auth
> restored)** -> review post-T6 ha sollevato 5 finding paper-grade.
> Indirizzati tutti in 2 commit:
> - `0f1dd59` T7a: 4 fix (warning fetch_fn esterno + errori distinti
>   nel .apply_biotype_filter + warning NA biotype + error H5 senza
>   biotype)
> - `054fb88` T7b: 1 fix (run_metadata\$gene_axis_summary cardinalita'
>   pre/post filter per audit paper-grade)
>
> Convenzione utente applicata: "codice robusto, non bello". Tutti i
> fix sono robustness alla sorgente (errori diagnostici, warning su
> silent drop, audit trace), no over-engineering API.
>
> **Aggiornamento sessione 7 post-E2 — FASE E3 chiusa (2026-05-28)**:
> ✅ FASE A+B+C+D+E0+E0b+E1+E2+E3 chiuse (24/19 task). E3 ha aggiunto
> covariate batch `instrument_model` + `aligner_class` al design DE
> Stadio 4 (limma-voom per-studio + dream-mega cross-study). Edge case
> gestiti: single-level drop | missing skip | NA partial -> 'unknown' |
> confound col treatment -> drop tutte covariate (pre-fit rank check).
>
> **Implementazione E3 in 7 commit bite-sized TDD**:
> - `225b015` T1: helper `.augment_de_design` (4 edge case base)
> - `e065db8` T2: `.run_limma_voom_de` integra design
> - `369b1b8` T3: `.run_dream_mega` integra design
> - `4e9ee68` T4: orchestrator + build_stage4_results propagano
> - `3fed578` T5: schema_versions + run_metadata trace
> - `02b848a` **T6a post-Codex Fix C1**: pre-fit `qr(X)$rank` check ->
>   drop covariate se design rank-deficient (confound col treatment)
> - `ff037ee` **T6b post-Codex Fix C2**: helper
>   `.join_covariates_to_metadata` con warning `join_incomplete`
>   distinto da `NA biologico`
>
> Test perimetro E3: 17 test_that, 66 expect_* PASS / 0 FAIL.
> Perimetro stage4+layer-b totale post-E3: **810 expect_*, 0 fail**.
> Self-review Opus 4.7 OK; Codex review eseguibile (auth restored) ->
> 2 finding bloccanti paper-grade (C1+C2) indirizzati prima del closing.
>
> **Aggiornamento sessione 7 post-E3 — FASE E4 + E5 chiuse (2026-05-28)**:
> ✅ FASE A+B+C+D+E0+E0b+E1+E2+E3+E4+E5 chiuse (26/19 task RED ALERT).
>
> - **E4** (`af8a80c`): test cascade integration E1+E2+E3 con mock H5
>   sintetico. 5 test_that, 23 expect_*. Verifica Ensembl axis +
>   biotype filter + covariate batch + pre-fit rank check in un flow
>   end-to-end.
> - **E5** (commit pending): Layer B compatibility check. Schema_versions
>   bumpato a v2_ensembl_gene_axis. Test 8 expect_* + script standalone
>   `analysis/audit/E5-smoke-plots.R` che materializza plot
>   (volcano/forest/heatmap/MA/top_genes/summary_card) in
>   `analysis/audit/E5-smoke-plots/` per giudizio visuale.
>
> Test perimetro post-E4+E5: **840 expect_*, 0 fail** stage4+layer-b
> totale.
>
> **FASE E del RED ALERT CHIUSA**. Prossimo step utente-driven:
> **FASE F** (rebuild pipeline F1-F6: F1 ETL re-run, F2 Stadio 1
> fullrun DGX, F3 Stadio 2 fullrun, F4 Stadio 3 rebuild, F5 Stadio 4
> Layer A rebuild, F6 Layer B re-selection). FASE F in sessione
> separata con gate utente esplicito.

---

## Visione del progetto

`simulomicsr` è una **pipeline R per meta-analisi RNAseq cross-studio
design-aware** basata su classificazione LLM dei metadati. Il nome è
legacy — il pacchetto NON simula nulla.

**Positioning (ADR-0006).** simulomicsr **non** è un altro annotatore
di GEO/SRA — quel campo è coperto da ARCHS4, MetaHQ (Hicks 2026),
MetaSRA, e dal multi-agent metadata curation di Mondal et al. 2025. Il
valore unico è la pipeline end-to-end **design-aware**: dal metadato
testuale alle comparisons appaiate (`design_role` LLM-driven entro lo
studio) → canonical `comparability_anchor` v3 cross-studio → pooling
effect-size random-effects (`metafor` REM). L'unico competitor end-to-end
vicino è RummaGEO (Maayan 2024), che però resta a livello di gene-set
per-studio senza anchor canonico né effect size. **Benchmark
testa-a-testa vs RummaGEO è deliverable integrale di P3.5 eval** (non
aggiunta opzionale post-hoc).

Pipeline complessiva (5 stadi):

1. **Acquisizione** — bulk RNAseq da ARCHS4-like (HDF5, ~700k+ sample da GEO).
2. **Stadio 1 sample-level** (P2 ✅) — classificare ogni sample dalla
   stringa di metadati GEO in un record JSON `sample_facts.stage1.v3`
   (cell context, perturbazioni, dose, tempo, ambiguity flags).
3. **Stadio 2 study-level** (P3 ✅) — interpretare il design
   sperimentale dello studio: replicate groups, design_role per sample,
   comparisons con `comparability_anchor` canonicalizzato per
   cross-studio matching.
4. **Stadio 3 raggruppamento** — cluster cross-studio sui
   `comparability_anchor`.
5. **Stadio 4 DE per-studio + Stadio 5 meta-analisi**
   (`DESeq2`/`limma` + `metafor` REM).

## Asset chiave — gold standard

`data-raw/relevant_sample_classified.xlsx` (committato nel repo, ~10 MB).

- Foglio `relevant_sample`: 130.784 righe × 8 colonne.
- Colonne: `Column1`, `string` (input metadata), `trtctr_EP` (gold
  manuale autore), `geo_accession`, `series_id`, `treat`, `trtctr`
  (baseline shallow), `gold` (ricontrollo terzo revisore).
- `trtctr_EP` riflette una semantica "qualunque intervento esplicito"
  che diverge da `design_role` — il gold "design-aware" è in
  `inst/extdata/p35c-minigold-reviewed-v5.csv` (100 sample, P3.5-C/D).

## Stato corrente (2026-05-23 — P5 Stadio 4 Layer A fullrun COMPLETE, tag `p5-stadio4-complete`)

### P5 Stadio 4 Task 21 chiusura — debugging sistematico + fullrun (branch `p5-stadio4-de-perstudio` ff-merged in master, 2026-05-22/23)

Sessione di debugging sistematico post-handoff: 5 bug distinti isolati con riproduzione minimale + fix mirati (no whack-a-mole). 8 commit + 1 commit doc. Suite Stadio 4 finale: **322 PASS / 0 FAIL / 1 SKIP** (+34 vs handoff 288).

**Bug fixati questa sessione**:

- **Problema A — `duplicate row.names` MEGA-AUG bidir** (`25c158d`): 3 sotto-cause emerse dallo scan dei 310 cluster `mega_aug`. (a) 13 cluster con stesso baseline pool su entrambi i bracci → mono-fallback (Opzione 1: augmenta solo il braccio control, marca `bidir_collapsed_to_mono=TRUE` nelle diagnostiche). (b) 7 cluster con pool distinti ma GSM condivisi (super-series ARCHS4) → drop role-conflict da entrambi i bracci. (c) 5 cluster `mega_aug` senza pair risolvibile → skip-guard esplicito `mega_aug_no_study_dispatch`. Scan post-fix: 0/310 duplicati.
- **Scoperta paper-grade: dream non aveva mai girato sui dati reali** (`f3ce3af`, ADR-0016 §Decision 2). ARCHS4 v2.5 `meta/genes/symbol` ha 4638/67186 simboli duplicati (paralogi PAR/KIR/HLA: più Ensembl ID legittimi mappano sullo stesso HGNC symbol). `dream` rifiuta rownames non unici → `.run_dream_mega` ripiegava silenziosamente sul fallback limma. Nessun risultato scientifico prodotto da questa pipeline è stato impattato (i 4 fullrun precedenti erano falliti prima del completamento; smoke test usavano fixture con simboli già unici). Fix: `make.unique()` deterministico in `.h5_gene_axis` (KIR3DL2, KIR3DL2.1, …) — cross-study coerente, niente perdita di informazione, niente aggregazione biased ante-test.
- **Problema B — OOM su cluster MEGA-AUG grandi** (`d5f6040` + `f8fab2e` + `22a5a0f` + `8c6eba9`, ADR-0016). Due fix complementari:
  - Cap dimensione baseline pool: `max_baseline_per_arm = 350` (calibrato da curva di saturazione su dati veri — `analysis/p5-stage4-debug-problemB-saturation.R`: a 350 correlazione logFC col pool pieno = 0.997, n. geni significativi al picco; oltre 350 il risultato non migliora).
  - Worker cap: `dream_workers_cap` 100 → 16 (in isolamento dream costa ~1 GB/worker, ma in contesto reale `build_stage4_results` fork-COW dello state alza il costo a ~3.4 GB/worker — a 32 worker il picco era 127 GB; a 16 worker il picco per-cluster è ~71 GB, validato end-to-end sui 3 cluster `mega_aug` più grandi).
  - Bonus: per-cluster progress logging + memoization assi H5 (`.h5_sample_axis` + `.h5_gene_axis` in env `.h5_axis_memo`).
- **Dashboard render — volcano subsample** (`858d9bb`): a 13.7M righe il chunk `volcano-overall` produceva una stringa che eccedeva R max length nel post-process knitr (`gsub`). Sub-campionamento deterministico a max 100k punti (tutti i sig + sample dei non-sig, seed=42).

### Layer A fullrun COMPLETE (run_id `96c43acb`, 2026-05-22T23:10Z → 2026-05-23T03:26Z)

- **622/622 cluster OK, 0 errori, watchdog mai triggered.** Wall 1682 min (~28h) su laptop 251 GB. **Dream-based** con il fix gene-symbol applicato.
- **Output** `analysis/p4-output/20260523T032601Z-stage4-96c43acb/` (gitignored):
  - `cluster_pooled.parquet` 375 MB — **13.691.756 righe** (mega 4.506.781 + mega_aug 9.184.975 by_method).
  - `per_study_de.parquet` 383 MB — 12.009.646 righe.
  - `stage4_dashboard.html` 77 MB.
  - `run_metadata.json` (config completa registrata) + `qc_report.rds` + `non_processable.rds`.
- **Config registrata**: `max_baseline_per_arm=350`, `dream_workers_cap=16`, `legacy_monodirectional=FALSE` (bidir on), `franchini_correction=TRUE`, `de_engine.mega=dream`, `de_engine.mega_aug=dream`.

## Stadio 4 Layer B (2026-05-24, branch `p5-stadio4-layer-b`)

Pipeline semi-automatica generator di "showcase case study" publication-grade.
Input: `analysis/layer-b-selection.csv` (10-20 cluster_id curati a mano dalla
dashboard Layer A). Output: bundle dir-per-cluster + Quarto HTML aggregate.

Decisioni chiave (vedi ADR-0017 + spec 2026-05-24):
- Workflow: semi-automatico CSV-driven (no Shiny, no dashboard button)
- 8 plot per cluster con dispatch conditional (forest = REM+MEGA-AUG,
  heterogeneity = REM only)
- Drop-into-paper polished (PNG @300 DPI + SVG, caption inglese paper-ready)
- Top-N: 10 forest / 30 heatmap / 30 table / 15 volcano labels
- HTML standalone aggregate (NO PDF)
- NO targets integration (script standalone primary)
- Smoke 3-cluster gate obbligatorio pre-batch

Test suite Layer B: 142+ PASS / 0 FAIL su filter `^layer-b` (269 cumulative
suite intera). Wall smoke 3-cluster: 2.8 min.

DESCRIPTION delta paper-grade: clusterProfiler, ComplexHeatmap, DESeq2, dplyr,
ggplot2, ggrepel, kableExtra, org.Hs.eg.db, patchwork, quarto, sva in `Imports`;
ReactomePA, ggrastr in `Suggests`.

**Status: COMPLETE 2026-05-24, tag `p5-stadio4-layer-b-complete`, ADR-0017 Accepted.**

Smoke validation (2026-05-24): 3 cluster pick (mega_big group_L0_a6f8c0e9,
mega_aug pair_L2_3ce85e50, mega_small group_L0_1a0673ae) → bundle dir-per-cluster
+ layer_b_report.html standalone 8 MB con 16/16 immagini base64-embedded +
caption english paper-ready + run_metadata.json con bioc_versions +
n_plots_generated/skipped + summary card con anchor risolto (treated side per
pair, level-aware per group L0..L4).

Cleanup paper-grade post-implementation: ggplot2 4.0 deprecations rimosse, SVG
size -66% to -90% (raster body via ggrastr + ComplexHeatmap::use_raster), HTML
embed-resources fix (era 0 base64 -> 16), parse_anchor_key gestisce mode='pair'
(treated__VS__control), ComBat guard su single-level treatment, summary_card
n_total_samples threading via per_cluster_samples (era N/A per mega-strict),
extract_anchor_summary public helper (era duplicato inline negli script).

Branch p5-stadio4-layer-b 31 commit ff-merged. Push remote rimane all'utente.

### Layer B selection + batch 15 case study (2026-05-24, branch `p5-stadio4-layer-b-selection`)

Curation paper-grade della selection.csv tramite shortlist data-driven sul
`cluster_pooled.parquet` (13.7M righe) + dedup gerarchia anchor v3 (487 cluster
Layer A → 293 unici). Script riproducibile `analysis/p5-stage4-layer-b-shortlist.R`
con criteri documentati: hard gates (k_effective≥4, n_sig_05≥50, max_logFC≥1.5,
kind_effective non-degenere; relaxed per mega coarse-anchor) + score composito
4-dim equipesi (magnitude/effect/power/precision) + stratified pick con cap
diversità biologica + smoke pin garantiti.

Shortlist 31 candidati → selection finale **15 case study** publication-grade:
- 13 mega_aug biology-driven: pathogen exposure × 3 (TLR ligands in blood,
  Resiquimod TLR7/8, polyI:C TLR3), small_molecule × 2 (ChEBI:17236 lung +
  smoke), cytokine × 2 (IFN-β kidney, ChEBI:16236 skin), environmental × 2
  (Hypoxia HUVEC, contact inhibition lung), genetic_overexpression × 1
  (miR-9/9*-124 neural reprog skin), disease_vs_normal × 1 (MeSH:D011279
  Prostatic Neoplasms), differentiation × 1 (Mesendoderm hESC)
- 2 mega smoke-validated: group_L0_a6f8c0e9 (transversal blood) +
  group_L0_1a0673ae (transversal skin)
- Coverage 11 kind_effective × 8 tessuti, mix level L0-L4.

Batch eseguito su laptop (wall **9.3 min**, run_id `56b911e6`):
- Output `analysis/p4-output/20260524T192649Z-layer-b-56b911e6/` (gitignored):
  15 bundle dir-per-cluster + `layer_b_report.html` 33 MB standalone con
  **88 plot base64-embedded** (no reference esterne) + `run_metadata.json`
  con bioc_versions + selection_sha256 + `selection_resolved.csv`.
- n_plots_generated/skipped: 88 / 17 (forest skip-graceful per i 2 mega
  non-REM; heterogeneity sempre generato).
- Warnings: 31 generici (ComBat mean.only su single-sample batch, pattern noto).

Next steps user-driven:
- Aprire `layer_b_report.html` per review visiva delle 15 case study
- Compilare `narrative.qmd` per ogni bundle (sezioni TODO: Biological context,
  Findings, Discussion) → integrazione nel paper Results
- ChEBI ID lookup per le 4 label "CHEBI:xxxxx" generiche (es. CHEBI:17126,
  CHEBI:17199, CHEBI:17236, CHEBI:16236) per arricchire le label paper
- Eventuale Stadio 5 meta-analisi (spec design da scrivere)

### ⚠️ AUDIT LLM ANCHOR CLASSIFICATION (2026-05-24, branch `p5-llm-anchor-classification-audit`, NON MERGIATO)

Durante il ChEBI lookup richiesto dall'utente per arricchire le label Layer B
è emerso un finding paper-grade gravissimo che bloccca l'integrazione Layer B
nel paper finché non si decide una mitigation. Audit cross-validation degli
`agent_id` LLM-emitted (Mistral-Small-3.2) contro ontologie controllate ChEBI
(205k compounds), HGNC (45k genes), MeSH 2025 (31k descriptors):

| Metrica | Valore | Cosa dice |
|---|---:|---|
| Field-swap rate `<DB>:<num>` | **23.87%** (63738/267056) | ID numerico nel campo `preferred_name` invece di `id`. Recuperabile post-hoc via lookup. |
| Pure hallucination rate | 0.97% (2587/267056) | Bassissimo. |
| `kind_effective` accuracy vs ChEBI has_role | cytokine_stim **0.7%** match, pathogen **2.4%** match, vehicle_only 93.5% match | **Disastroso** per cytokine/pathogen. |
| Fragmentation L0G (compound, kind, level, mode fissati) | 34.4% | 1/3 compounds split in piu' cluster. |

**Su 15 case study Layer B**:
- 7 scientificamente validi (poly(I:C), Resiquimod, IFN-β, Hypoxia, miR-9, contact inhibition, Mesendoderm)
- 2 transversal ambigui (smoke `group_L0_*`)
- 2 con compound LLM-oscuro CHEBI:17236 (probable consistent hallucination)
- **4 critically wrong**: Carnitine-as-pathogen, Ethanol-as-cytokine, dihydroxyphthalic-as-pathogen, Pregnanetriol-as-disease

**Impatto**:
- Pooling DE Stage 4 algoritmicamente VALIDO (anchor stringa deterministica)
- Interpretazione BIOLOGICA INVALIDA per migliaia di cluster (label numerica + kind wrong)
- L2 paper limitation va espansa drasticamente

**Decisione utente 2026-05-25**: OPZIONE 2 — post-hoc ontology override
+ rebuild Stage 3 + Stage 4 + Layer B. ADR-0018 Proposed.

Documentazione completa pronta su branch `p5-llm-anchor-classification-audit`:
- **ADR-0018**: `docs/decisions/0018-llm-anchor-ontology-override.md` (decisione architetturale)
- **Spec**: `docs/superpowers/specs/2026-05-25-p5-llm-anchor-ontology-override-design.md`
  (design tecnico: decision tables, edge cases, versioning, validation strategy)
- **Plan**: `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-plan.md`
  (task-by-task implementation, 5 sessioni S1-S5 con gate utente)
- **HUMANE**: `docs/superpowers/plans/2026-05-25-p5-llm-anchor-ontology-override-HUMANE.md`
  (versione leggibile + decisioni rinviate + cosa NON fa + stima tempo)
- **Audit drive**: `docs/findings/2026-05-24-llm-anchor-classification-audit.md`

Wall stimato totale: **1-2 giorni** distribuiti su 5 sessioni con gate
utente tra ogni sessione (vedi plan §SESSIONE 1..5).

### S1 COMPLETED 2026-05-25 (impl + tests + smoke isolato)

**5 commit incrementali su `p5-llm-anchor-classification-audit`** (master invariato):

- `5ea32c7` T1: `R/ontology-lookup.R` + mini fixtures + tests TDD (28 test, 56 expect_*).
  Loader singleton + 9 accessor O(1) hash-env per ~315k lookup downstream.
- `a91764d` T2: `resolve_agent_canonical()` in `R/anchors.R` + tests (28 test, 70 expect_*).
  Decision table 16+ branch spec §4.2.
- `7aad2e2` T3: `infer_kind_from_ontology` + `infer_kind_with_override` + tests
  (28 test, 51 expect_*). Override policy paper-grade conservativa: STRONG match
  registrato senza override; STRONG differ → ONTOLOGY_OVERRIDE_STRONG;
  MEDIUM/WEAK + LLM in {cytokine_stim, pathogen} kind incompatibile →
  LLM_CONTRADICTION_DETECTED; NONE → LLM preservato + kind_unvalidatable=TRUE.
- `afac917` T4: integrazione `.extract_anchor_segments` v3.1 + `make_anchor` thin
  wrapper + `.summarize_clusters` 11 tracking columns + `ontology_releases`
  in `run_metadata` + schema_versions anchor=v3.1 + resolver=v1.0.0.
  **9 nuovi test integration** (test-stage3-anchor-v31.R). Defensive
  `.coerce_chr1` + `.normalize_key_chr` per LLM real-world input
  character(0)/array/NA (critico: previene crash exists() in ~315k lookup).
- `45459f2` T5: smoke isolato `analysis/p5-ontology-override-smoke.R` 6 case
  paradigmatici, 6/6 PASS (log `analysis/p5-ontology-override-smoke.log`).

**Test result globale S1**: 1703 PASS / 0 FAIL / 3 SKIP (full suite escluso
perf-budget). Anchor-related: 443 PASS. Stage 3 (mocked): 268 PASS.
No regressioni.

**Smoke validato** sui 6 paradigmi dell'audit:
1. Carnitine field-swap LLM=pathogen → CHEBI:17126 + override LLM_CONTRADICTION_DETECTED
2. Ethanol LLM=cytokine_stim → CHEBI:16236 + override ONTOLOGY_OVERRIDE_STRONG → vehicle_only
3. DMSO type=vehicle → STR:dmso LLM_VEHICLE_LITERAL (preserva intent)
4. Resiquimod (0 ChEBI roles) LLM=pathogen → preservato + kind_unvalidatable=TRUE
5. poly(I:C) LLM=pathogen → CHEBI:84491 STRONG match (adjuvant)
6. Disease role=case D011471 → MeSH:D011471 STRONG disease_vs_normal

**Gate utente S1→S2 APPROVATO** (2026-05-25).

### S1bis + S2bis COMPLETED 2026-05-25 (anchor v3.1.1 + Stage 3 rebuild + 4/4 audit chiuso)

**Decisione utente 2026-05-25 (post-S2 v3.1 diff)**: OPZIONE B
(extend resolver per chiudere tutti i 4 audit case) + **DGX UniPD per S3**
Stage 4 rebuild.

**Output rebuild Stage 3 v3.1.1**:
`analysis/p4-output/20260525T172032Z-stage3-v31-2655ecb0/` (gitignored).
- 390.532 cluster (+13 vs v3.1 per nuova rule DISEASE_KIND_CONTRADICTED)
- 1.255.180 assignments (invariato vs v3.1)
- Wall rebuild: 78.9 min (invariato vs v3.1 79.9 min)
- schema_versions.anchor=v3.1.1 + resolver=v1.1.0 in run_metadata.json

**Score override v3 → v3.1 → v3.1.1**:

| metric | v3 | v3.1 (S2) | v3.1.1 (S1bis+S2bis) |
|---|---:|---:|---:|
| kind_overridden | 0 | 7068 (1.81%) | **7845 (2.01%)** |
| LLM_CONTRADICTION_DETECTED | 0 | 4568 | **2833 (-1735 BUG FIX)** |
| DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY | 0 | 0 | **2512 (NEW)** |
| ONTOLOGY_OVERRIDE_STRONG | 0 | 2500 | 2500 |
| kind_chebi_zero_roles flag | n/a | n/a | **34878 (8.93%) NEW** |

**Audit 4 critically wrong Layer B → 3/4 FIXED deterministic + 1/4 FLAGGED**:

| Compound | Status v3.1.1 | Override reason |
|---|---|---|
| Carnitine CHEBI:17126 | ✅ FIXED (since v3.1) | LLM_CONTRADICTION_DETECTED |
| Ethanol CHEBI:16236 | ✅ FIXED (since v3.1) | ONTOLOGY_OVERRIDE_STRONG |
| Pregnanetriol MeSH:D011279 | ✅ **FIXED (NEW v3.1.1)** | DISEASE_KIND_CONTRADICTED_BY_ONTOLOGY |
| dihydroxyphthalic CHEBI:17199 | ⚠️ FLAGGED | kind_chebi_zero_roles=TRUE (Layer B shortlist filter) |

**BUG silente paper-grade scoperto durante TDD S1bis**: la asymmetric trust
su `source = MESH_TREE_D` ha salvato **1735 cluster** che la policy v3.1
avrebbe wrongly demotato (es. Interferon-beta MeSH:D016899 LLM=cytokine_stim
→ MeSH tree D MEDIUM small_molecule incompatibile → demote erroneo). MeSH
tree D include sia chemicals che proteine immunitarie (D12), evidence troppo
coarse per smentire LLM cytokine specifico. Magnitude inattesa ~3x più grande
del caso target Pregnanetriol singolo. Regression test guard permanente.

**Commit S1bis + S2bis** (branch `p5-llm-anchor-classification-audit`):
- `d06e389` P5 audit S1bis: anchor v3.1.1 chiude 4/4 audit set
- `5a9aad1` P5 audit S2bis: Stage 3 v3.1.1 rebuild + diff + finding

**Report paper-grade**:
- `docs/findings/2026-05-25-stage3-v31-diff.md` — diff v3 vs v3.1 (intermediate)
- `docs/findings/2026-05-25-stage3-v311-diff.md` — diff v3 vs v3.1.1 (final)

### S2 COMPLETED 2026-05-25 (intermediate Stage 3 rebuild v3.1 + diff + report)

**Output rebuild Stage 3 v3.1**:
`analysis/p4-output/20260525T140219Z-stage3-v31-52357b00/` (gitignored).
- 390.519 cluster (+46.2% vs baseline v3 267.056)
- 1.255.180 assignments (+77.3% vs 707.595)
- 192.897 non_clusterable
- Wall rebuild: 79.9 min laptop 251 GB
- schema_versions.anchor=v3.1 + resolver=v1.0.0 + ontology_releases
  (ChEBI 205k compound + HGNC 45k + MeSH 31k) in run_metadata.json

**Override conservativo**: kind_overridden 7068 (1.81%):
- 64.6% LLM_CONTRADICTION_DETECTED (4568)
- 35.4% ONTOLOGY_OVERRIDE_STRONG (2500)

Override per kind_effective_resolved:
- 4558 → small_molecule (Carnitine-like, LLM diceva pathogen)
- 1670 → vehicle_only (Ethanol/DMSO-like, LLM diceva cytokine_stim)
- 440 → cytokine_stim (Resiquimod-like, LLM diceva small_molecule)
- 316 → disease_vs_normal (MeSH disease descriptors missed)
- 84 → pathogen_or_aggregate_exposure (poly(I:C)/TLR agonists)

**Audit 4 critically wrong Layer B (vedi `docs/findings/2026-05-25-stage3-v31-diff.md`)**:

| Compound | Old kind | New kind | Status |
|---|---|---|---|
| Carnitine CHEBI:17126 | pathogen | small_molecule | ✅ FIXED |
| Ethanol CHEBI:16236 | cytokine_stim | vehicle_only | ✅ FIXED |
| Pregnanetriol MeSH:D011279 | disease_vs_normal | disease_vs_normal | ⚠️ RESIDUAL |
| dihydroxyphthalic CHEBI:17199 | pathogen | pathogen | ⚠️ RESIDUAL |

2/4 risolti, 2/4 residual (policy attuale conservativa: no MeSH tree_top
check, no override per ChEBI compound con 0 roles annotation).

**Perf budget v3.1** (test aggiornato): 90 min wall + 8 GB memory delta
(cushion ~15-18% sui valori reali 76.6 min / 6.75 GB). Overhead +60 min su
Phase 6 `summarize_clusters` per resolve+infer lookup su 390k cluster
(atteso per design ADR-0018).

**Commit S2**:
- `74dcad4` P5 audit S2 Task 6: Stage 3 v3.1 rebuild + perf budget v3.1
- `f16de37` P5 audit S2 Task 7: diff Stage 3 v3 -> v3.1 + finding report

**Gate utente S2→S3 in attesa**.

### ⚠️ GATE PAUSE 2026-05-25 (utente richiede audit completo pipeline pre-S3)

A fine sessione S2bis l'utente ha espresso preoccupazione paper-grade per il
pattern emerso: **3 bug paper-grade scoperti in sequenza durante S2 + S1bis**
(Pregnanetriol mancato override, dihydroxyphthalic mancato flag, bug silente
Interferon-beta-like con 1735 cluster impatto). Conclude: "non mi fido più
di tutta la pipeline. Ripercorrila tutta. Audit completo dalla prossima
sessione".

**Decisione utente 2026-05-25 sera**:
- S3 Stage 4 rebuild su DGX → **SOSPESO**
- S4 Layer B re-shortlist + batch → **SOSPESO**
- S5 close ADR-0018 → **SOSPESO** (ADR resta `Proposed`)
- Merge `p5-llm-anchor-classification-audit` → master → **SOSPESO**

**Handoff completo audit pipeline**: vedi
`docs/superpowers/specs/2026-05-25-pipeline-trust-audit-handoff.md`.

Scope proposto (5 stadi × ~2-4h = 10-20h totali su 2-3 sessioni):
1. Stage 1 LLM sample-level (879k record)
2. Stage 2 LLM study-level (39k record)
3. Stage 3 anchor v3.1.1 + resolver v1.1.0 (390k cluster)
4. Stage 4 Layer A pooling DE (96c43acb baseline)
5. Layer B existing selection (56b911e6, 15 case study)

Workflow next session: gate utente tra ogni stadio. Output = 5 trust report
paper-grade in `docs/findings/<date>-stage<N>-trust-audit.md`.

Sub-skill da usare: `superpowers:systematic-debugging` come framework.

### Prossima sessione: AUDIT COMPLETO PIPELINE (PAUSED prima di S3)

**Pipeline freeze (in attesa audit)**:
- Stage 1 master rescued: `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` (879k record, gitignored)
- Stage 2 master rescued: `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` (39247 predictions)
- Stage 3 v3 baseline: `analysis/p4-output/20260519T055547Z-stage3-2153addc/` (267k cluster, committed)
- Stage 3 v3.1 intermediate: `analysis/p4-output/20260525T140219Z-stage3-v31-52357b00/` (gitignored, 390519 cluster)
- **Stage 3 v3.1.1 final**: `analysis/p4-output/20260525T172032Z-stage3-v31-2655ecb0/` (gitignored, 390532 cluster)
- Stage 4 Layer A baseline: `analysis/p4-output/20260523T032601Z-stage4-96c43acb/` (gitignored, 622 cluster pooled)
- Layer B existing: `analysis/p4-output/20260524T192649Z-layer-b-56b911e6/` (gitignored, 15 case study + 88 plot)

**Sub-skill da invocare next session**: `superpowers:systematic-debugging`
come framework di audit (NON `executing-plans` perché non c'è un plan ancora
scritto — il plan è il handoff stesso).

Branch invariato (`p5-llm-anchor-classification-audit`), master invariato.

Memorie correlate: [[project_llm_anchor_classification_audit]] (status PAUSED) +
[[no-whack-a-mole-debugging-sistematico-dopo-crash-ripetuti]] +
[[feedback-no-fretta-paper-grade]] + [[feedback-explain-then-decide]].

---

## Stato precedente (2026-05-17 — P4 β rescue cascade COMPLETE, tag p4-beta-rescue-complete pending)

### α (consolidato, riproducibile)

Pipeline classification stage1 + stage2 sul gold-standard XLSX 130.784 sample:

- **α stage1** (Task 21, 2026-05-07) → 130.784 / 130.784 = **100.00%** schema. Dettagli NEWS 0.0.0.9009-0.0.0.9011 + ADR-0008.
- **α stage2** original (Task 22, 2026-05-10, v0.10.0 + workaround stack) → 8.532 / 8.546 cs25 = 99.84% schema, mini-gold 93.3%.
- **α stage2 re-run cs50** (ADR-0010, 2026-05-11, v0.20.2-cu129 + clean stack) → **6.649 / 6.652 cs50 = 99.96%** schema single-pass, **mini-gold 96.7%** (+3.4pp). Default flipped cs25→cs50.

### β (stage1 + stage2 fullrun COMPLETE 2026-05-15/17, tag p4-beta-archs4-human-complete)

Pipeline scalata su ARCHS4 v2.5 human bulk RNA-seq (~10x α):

- **β ETL** (Task β-1..β-6, 2026-05-12) → **888.821 sample** human + RNA-Seq, 32.905 unique GSE pre-resolver, **193.097 multi-series** risolti. Output JSONL `analysis/input/archs4-human-stage1-input.jsonl` (262 MB, gitignored).
- **β series-id-resolver SRP-driven Op D revised** (`R/etl-series-resolver.R`, Task β-4): 99.86% resolti via signal (`clean_super_scarted` 183.041 + `srp_a_only/b_only` 9.011 + minor branches), 0.54% heuristic tiebreak/fallback (1.041 sample), 0 sample droppati. Test 23-pair gold replication PASS (Exp D2).
- **β GATE #1** mini-gold format B (Task β-8, 2026-05-12): stage1+stage2 end-to-end su 100 mini-gold → schema 100% s1 + 100% s2, **accuracy binaria 98.00%** (mappato design_role_v3 → control/treated via `R/eval-stage2.R::design_role_to_binary`). +1.3pp vs α 96.7%. Wall DGX 4 min totali.
- **β GATE #2** smoke 1000 stratificato per nchar quartile (Task β-9, 2026-05-12): schema **99.50% s1 + 100% s2**, 5 LLM fail droppati lenient (0.5%), tier S=718 M=3 L=0 XL=0 (no overflow), design_kind distribution sana (case_control 40%, treatment_vs_vehicle 18%, multi_arm 17%).
- **β Task 10 stage1 fullrun via chunked orchestrator** (2026-05-14/15): wall **17h53min** (20:07 UTC 2026-05-14 → 14:00 UTC 2026-05-15) per 888.795 record mainstream. 89 chunks da 10k, cron `*/3 * * * *` autonomous + cascade COMPLETED→submit-next. Throughput stabile ~12.1 min/chunk. **Zero stall**. State machine: `scripts/p4-beta-stage1-chunked-tick.sh` + `analysis/p4-beta-chunked-state.txt`.
- **β Task 10b stage1 outliers** (2026-05-15): 26 record con `nchar > 3500` (0.003%) processati separatamente con `max_model_len=32768` (Strategy A2). Strategy A1 (`max_model_len=8192`) aveva riprodotto stall su job 20705. Wall **2m23s** per 26/26 record. Strategia documentata in memoria `project_vllm_scheduler_deadlock`.
- **β Master output stage1**: `analysis/p4-output/p4-beta-stage1-master-predictions.jsonl` (888.821 righe, 3.23 GB, gitignored), concat di 90 run dirs DGX (89 chunks + 1 outliers).
- **β Task 11 stage2-input build** (2026-05-15): 887.250 sample validi (1.571 droppati lenient per LLM fail) / 28.479 GSE → **39.205 record stage2** (12.989 chunked in 2.263 studi multi-chunk + 26.216 unsplit). Output `analysis/input/archs4-human-stage2-input.jsonl` (1.2 GB, gitignored). Wall 18m46s local.
- **β Task 12 stage2 fullrun** (2026-05-15/17): job slurm **20710**, run_id `20260515T175712Z-beta-stage2-fullrun-a275b0`, wall reale **1d 18h 29m 42s** (~42.5h DGX), ExitCode 0:0 COMPLETED. Schema validity **99.89%** (39.162/39.205, 43 errori). Tier S=16.493 / M=5.626 / L=2.605 / **XL=14.481** (37%). Throughput steady ~12-14 rec/min aggregato (4 worker H100, microbatch 50 cs50 ADR-0010/0013). Output 4 worker file merged in `predictions.jsonl` 403 MB sul DGX, collected localmente.

### β rescue cascade (Task 1-15, 2026-05-17, branch `p4-beta-rescue`)

Post-fullrun cleanup di 1.571 stage1 fails + 43 stage2 fails + discovery
paper-grade mouse-mislabeled GSE. Cascade tre strategie:

- **Phase 1 classification** (Task 2): 1.571 stage1 fails decomposti in MODE_A_WHITESPACE (660), MODE_B_LEGIT_TRUNC (147), OTHER_DEGEN (15), ETL_LEAK_NONHUMAN (749). CSV `analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv`.
- **H2 — mouse-mislabeled GSE discovery + GSE-level drop** (Task 3+3b): 72 GSE ARCHS4 v2.5 `organism_ch1="Homo sapiens"` ma contenuti murini → 9.654 sample droppati GSE-level (8.398 LLM-non-human + 1.256 human collaterali) + 749 LLM JSON failure signal indiretto. Stage1 master cleaned: 888.821 → **879.167**. Stage2-input: 39.205 → **38.963**. Discovery doc paper-grade: `docs/findings/2026-05-17-llm-detected-archs4-geo-organism-mislabeling.md`.
- **H1 — Stage1 LLM-failure rescue** (Task 4-8): single-shot config `rep_pen=1.2 + max_tokens=4096 + max_model_len=8192` sui 822 Mode A/B/OTHER fails. Smoke20 21008 = 20/20 = 100%. Full retry 21103 = **802/822 = 97.6%** in 3m21s. Master rescued: `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` (879.167 record, colonna `rescue_source = "h1_rep12_maxtok4096"` su 802).
- **H1.2 — Stage1 strong cascade su H1 residual** (post-Task 15, 2026-05-18): single-shot strong `rep_pen=1.3 + max_tokens=8192 + max_model_len=16384` sui 20 H1 residual (18 Mode A + 2 Mode B). Full retry 21136 = **19/20 = 95%** in 4m03s. 1 residual GSM6005198. Master aggiornato in-place; colonna `rescue_source = "h12_rep13_maxtok8192"` su 19 record.
- **H1.3 — Manual curation single-record** (post-H1.2, 2026-05-18): GSM6005198 (whitespace flood profondo non cedevole a rep_pen=1.3) curato a mano leggendo i metadata input, validato contro `sample_facts.stage1.v3` schema e iniettato nel master. Colonna `rescue_source = "manual_curation_2026-05-18"` su 1 record. Script `analysis/p4-beta-rescue-h13-manual-gsm6005198.R`. Branch `p4-beta-rescue-h12` ff-merge → master, tag `p4-beta-rescue-complete` retagged su nuovo HEAD.
- **H3 — Stage2 stall rescue cs25** (Task 9-13): cs50→cs25 re-split sui 43 stage2 fails (tier XL stuck post-PR #40946) + `tiered_max_tokens=TRUE` con XL=32768. 85 cs25 chunks generati. Smoke5 21129 = 5/5 = 100% in 2m35s. Full retry 21132 = **85/85 valid, 0 residual, 43/43 original keys fully rescued** in 8min. Master rescued: `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` (39.247 predictions, 0 errors).

**Risultato finale β post-rescue**:

| Metric | Pre-rescue | Post-rescue cascade |
|---|---|---|
| Stage1 master records | 888.821 | **879.167** (H2 drop −9.654) |
| Stage1 LLM+manual validity | 99.82% | **100.000%** (878.418 / 878.418, 0 residual, 1 manual curation GSM6005198; escludi 749 ETL leak ridroppati per H2) |
| Stage2 records | 39.205 | **38.963** (post H2) → **39.247 predictions** (post H3 con cs25 splits) |
| Stage2 schema validity | 99.89% | **100.000%** (0 residual) |
| Mouse contamination upstream | 9.147 latent | **0** (72 GSE dropped + 72 candidati re-annotation GEO/ARCHS4) |

Strategie consolidate documentate per paper Methods/Results: `docs/findings/2026-05-17-p4-beta-rescue-strategies.md`. ADR-0008 Addendum 2026-05-17 con H1+H3 config. NEWS 0.0.0.9017.

**Pipeline running config (invariata da α)**:

- **Container**: `vllm/vllm-openai:v0.20.2-cu129-ubuntu2404` (cu129 per driver 535 DGX compat).
- **Modello**: `mistralai/Mistral-Small-3.2-24B-Instruct-2506` self-hosted FP16 su DGX H100. Costo $0.
- **vLLM API**: `StructuredOutputsParams` (backend auto = xgrammar→outlines fallback). `GuidedDecodingParams` rimosso in vLLM v0.12.0.
- **Sampling** (ADR-0008): `temperature=0.0, repetition_penalty=1.1` stage1+stage2. Tier-based per-record max_tokens stage2 (S/M/L/XL → 4K/8K/16K/32K, ADR-0011).
- **Concurrency restored** (post PR #40946): `max_num_seqs=6, microbatch=50` stage2. Safe-mode (ADR-0009) declassato a fallback contingency.
- **Stage2 chunking**: `chunk_size=50` (cs50 default, ADR-0010 addendum + ADR-0013).
- **Schema validation**: structured_outputs = parser-grade by construction.

**Tag/branch attivi**:

- Tag α: `p4-vllm-upgrade-v0.20.2-complete` (commit 31c676a, addendum 89ca20e per cs50 flip).
- Tag β: **`p4-beta-archs4-human-complete`** (2026-05-17, closing Task β-15). Branch `p4-beta-archs4-human` ff-merged in `master` locale. Push remote rimane all'utente.
- **Test**: 544 PASS / 0 FAIL / 3 SKIP α-level (skip pre-esistenti OPENAI_API_KEY) + 41 PASS β resolver = 585 total tests.

**File risultato α + β attualmente sul disco**:

- α stage1: `analysis/p4-output/alpha-stage1-final.rds` (130.784 × 7, colonna `rescue_source`)
- α stage2 cs50: `analysis/p4-output/20260510T215308Z-p5-alpha-cs50-final-8db4c0/predictions.jsonl` (6649/6652 valid)
- α eval mini-gold cs50: `analysis/p4-output/phase3-h1-eval-20088.rds`
- β ETL output JSONL stage1-input: `analysis/input/archs4-human-stage1-input.jsonl` (gitignored, 262 MB)
- β ETL provenance: `analysis/p4-output/p4-beta-archs4-source.json` (committato force-add)
- β H5 source: `analysis/input/human_gene_v2.5.h5` (47.86 GB, gitignored; SHA256 `a1063426cb51986c77574d80d344918a075804c155e9b18c2e551b1077ad5d18`)
- β cache Entrez resolver: `tools::R_user_dir("simulomicsr","cache")/geo-series-resolver-cache.rds` (~25 MB, 32.905 GSE)
- β GATE #1 eval: `analysis/p4-output/20260512T142323Z-p4-beta-gate1-minigold-eval.rds` (force-add committato)
- β GATE #2 eval: `analysis/p4-output/20260512T150505Z-p4-beta-gate2-smoke1000-eval.rds` (force-add committato)
- β stage1 chunked input shuffled: `analysis/input/archs4-human-stage1-input-shuffled.jsonl` (gitignored, 262 MB; seed=42 globale, output di `shuf --random-source=<(yes 42)`)
- β stage1 chunked input filtered (`nchar <= 3500`): `analysis/input/archs4-human-stage1-input-shuffled-filtered.jsonl` (gitignored, 262 MB, 888.795 record)
- β stage1 outliers (`nchar > 3500`): `analysis/input/archs4-human-stage1-outliers.jsonl` (gitignored, 26 record, ~140 KB)
- β stage1 chunks (89 file): `analysis/input/chunks/chunk-00.jsonl` .. `chunk-88.jsonl` (gitignored, ~2.9 MB ciascuno)
- β stage1 master predictions: `analysis/p4-output/p4-beta-stage1-master-predictions.jsonl` (gitignored, **888.821 righe, 3.23 GB**, concat di 89 chunks + 1 outliers)
- β stage1 state machine: `analysis/p4-beta-chunked-state.txt` (gitignored, ultimo valore `89` = orchestrator idle)
- β stage1 orchestrator log: `analysis/p4-beta-chunked-orchestrator.log` (gitignored, ~70 KB, log cron tick ogni 3min)
- β stage2 input cs50: `analysis/input/archs4-human-stage2-input.jsonl` (gitignored, **39.205 record, 1.2 GB**, output di `analysis/p4-beta-stage2-build-input.R`)
- β stage2 fullrun output (collect dir): `analysis/p4-output/20260515T175712Z-beta-stage2-fullrun-a275b0/` (gitignored, contiene `predictions.jsonl` 403 MB merged + 4 worker file + `run_summary.json` + `collect.rds`)
- β rescue stage1 fails classified: `analysis/p4-output/p4-beta-rescue-stage1-fails-classified.csv` (committato, 1.571 fails × 5 colonne)
- β rescue H2 suspects (72 GSE flagged): `analysis/p4-output/p4-beta-rescue-h2-suspects.rds` (committato, 72 × 4 colonne)
- β rescue stage1 cleaned (post H2): `analysis/p4-output/p4-beta-stage1-master-predictions-cleaned.jsonl` (gitignored, **879.167 righe, 2.97 GB**)
- β rescue stage2-input cleaned (post H2): `analysis/input/archs4-human-stage2-input-cleaned.jsonl` (gitignored, **38.963 record, 1.18 GB**)
- β rescue H1 input: `analysis/input/archs4-human-stage1-rescue.jsonl` (gitignored, 822 record, 296 KB)
- β rescue stage1 master rescued (post H1): `analysis/p4-output/p4-beta-stage1-master-predictions-rescued.jsonl` (gitignored, **879.167 righe, 2.97 GB**, colonna `rescue_source = "h1_rep12_maxtok4096"` su 802)
- β rescue H3 input cs25: `analysis/input/archs4-human-stage2-rescue-cs25.jsonl` (gitignored, **85 chunks, 3.2 MB**)
- β rescue stage2 master rescued (post H3): `analysis/p4-output/p4-beta-stage2-master-rescued-collect.rds` (gitignored, 39.247 predictions + 0 errors, colonna `rescue_source = "h3_cs25_resplit"` su 85 cs25 chunks)

## Convenzioni operative dell'utente

### Tracciabilità — ogni decisione documentata

Mai prendere una decisione architetturale senza scriverla in modo
durevole prima di committare codice che la riflette.

- **ADR** (decisioni architetturali) → `docs/decisions/NNNN-<slug>.md`. Template in `docs/decisions/template.md`.
- **Spec** (brainstorming/design) → `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`.
- **Plan** (implementazione) → `docs/superpowers/plans/YYYY-MM-DD-<topic>-plan.md` + companion HUMANE per la review umana.
- **Commit atomici** con messaggi italiani descrittivi formato `P<N> Task <M>: <azione>`. Sono il "come tecnico" complementare all'ADR.

A fine milestone: raccogliere materiale da ADR/spec per generare /
aggiornare vignette o capitoli del futuro manuale.

### Git workflow

- **Branch per fase:** `p<N>-<slug>` (es. `p2-stage1`).
- **Merge fast-forward only** su master a fine fase. Tag `p<N>-<slug>-complete`.
- **MAI fare `git push`** — l'utente lo fa lui, sempre. Master locale può essere molti commit ahead.
- **MAI usare `--no-verify` o `--no-gpg-sign`** salvo richiesta esplicita.
- Pulire `renv/settings.json` (untracked, autogenerato) e ripristinare `analysis/_targets/.gitignore` + `analysis/_targets/meta/meta` (rigenerati da `tar_make`) prima di ogni commit.

### Convenzioni codice

- **Italiano nei commenti, docstring, messaggi commit, error messages.**
  ASCII per i caratteri accentati nei file Rd generati da roxygen
  (usare `§`/`—` o equivalenti `sec.`/`--` nel roxygen `#'`).
- Funzioni interne: `@keywords internal`. Solo i veri entry point sono `@export`.
- TDD bite-sized (test → fail → impl → pass → commit) per ogni step di plan.

### Note operative tecniche ricorrenti

- **renv 0.16.0 (lockfile) vs renv 1.1.4 (installato):** `Rscript -e ...` (no vanilla) può non trovare `devtools` perché renv intercetta il libpath. Workaround: `Rscript --vanilla -e ...` bypassa renv e usa system libs (devtools/targets installati globalmente). **Sul server DGX (R 4.6.0)** è il contrario: usare `Rscript -e ...` SENZA `--vanilla` (renv lib path corretta nel project).
- **`callr_function = NULL` per `tar_make`:** indispensabile quando i target chiamano OpenAI. callr crea sub-process R che NON ereditano la API key dal parent.
- **`format = "qs"` non disponibile su CRAN per R 4.5.2** → P2 usa `format = "rds"` per `tar_option_set`.
- **`sample_facts_validator` storizza un PATH allo schema, non il validator compilato** — i contesti V8 di `jsonvalidate` non sono serializzabili in RDS. `compile_schema()` viene chiamato inline nei target di partition.
- **MAI fare `git checkout -- analysis/_targets/meta/meta` MENTRE un `tar_make` è in corso**: il meta viene aggiornato in tempo reale, un checkout lo riporta a stato pre-run e il job successivo non riconosce più gli oggetti già calcolati. La convenzione "ripristina meta prima del commit" vale solo quando NESSUN tar_make sta girando in background.
- **Hang HTTP transitorio iniziale**: la prima call OpenAI dopo network glitch può essere catturata in I/O wait su socket (CPU 0%, processo S, TCP ESTABLISHED) senza timeout effettivo del `req_timeout(120s)` di httr2 (rare edge case). Workaround: kill + retry.
- **NON re-introdurre `temperature = 0` come default** in `R/llm-client-openai.R` (gpt-5.5 reasoning models ritornano 400 `unsupported_value` su qualunque temperature esplicita). Per output deterministici su modelli storici (gpt-4o, gpt-5.4-mini), passare `temperature = 0` esplicito dal chiamante.

### Note operative DGX (P4 cluster)

- **Path `/home/u0044/` NON `/mnt/home/u0044/`** — i compute node UniPD HPC non montano `/mnt/home/`. Sintomo del bug: ExitCode `0:53` con job FAILED in 2 secondi senza log files.
- **🔴 BLOCCANTE (2026-07-06/07): poddgx02 riavviato il 2026-07-06 17:22 → dopo il reboot la rete NFS (`bond1` LACP) è morta → `/home` non si monta → ogni job FAILED ExitCode `0:53`, ZERO log.** CAUSA RADICE PROVATA (debug sistematico via `srun`, confidenza ALTA): su poddgx02 `mount | grep nfs` = SOLO `master:/cm/shared`; `/home` è dir LOCALE VUOTA; `ping 147.162.154.180` (server NFS `ps01nfs`) e il gateway = **100% packet loss**; `/proc/net/bonding/bond1` = slave `eth3` **NO-CARRIER**, LACP "churned"; l'altra rete `eth2` (147.162.155.x) va → per questo `/cm/shared` c'è ma `/home` no. slurm non crea il file `--output` sul path `/home` mancante → `RaisedSignal:53` + zero log; con `--output=/tmp` (locale) il job COMPLETA. **⚠️ `autofs` era un FALSO INDIZIO** (la mia prima diagnosi): autofs non esiste nemmeno su poddgx02 e sul login — che monta `/home` — è `inactive` UGUALE; la home è montata STATICAMENTE via `fstab` (`ps01nfs:/home /home nfs`). **NON è codice/quota/config** (identica ai job di giugno 20710/24022 che girarono su poddgx02 PRIMA del reboot e scrissero i log). **FIX (è CLUSTER): admin UniPD riparano `bond1` su poddgx02** (eth3 NO-CARRIER/LACP churned → cablaggio/porte switch/config LACP VLAN 147.162.154.0/24, o ri-provisioning Bright `cmsh`), poi `mount /home`; **nel frattempo DRAIN il nodo** (`scontrol update nodename=poddgx02 state=drain reason=...`, ora è IDLE e accetta job che falliscono in silenzio). Nessun workaround lato-utente (job serve `/home` per input+output; `/cm/shared` read-only; `/tmp` node-local; poddgx01 escluso, poddgx03 assente). Diagnostica riusabile: `ssh login 'srun -p dgx12cluster -A dctv_dgx -w poddgxNN --gres=gpu:1 -t2 --chdir=/tmp /usr/bin/bash -c "ping -c1 147.162.154.180; cat /proc/net/bonding/bond1 | grep -iE churn\|carrier; mount|grep nfs"'`. Vedi memoria `dgx_storage_projects_not_home`.
- **STORAGE (separato dal blocco sopra, lezione valida): usare `/mnt/projects/dctv/dgx/u0044/` (NFS gruppo `dctv_dgx`, multi-PB, no cap) per i dati DGX pesanti, NON `/home/u0044/`** (quota per-utente 500G; il `df -h /home/u0044` "99%/9.9G" è la QUOTA, il fs fisico è 4.9 PB). `/mnt/projects/dctv/dgx/u0044/` è scrivibile da u0044 (la root `/mnt/projects/dctv` NO). Il 2026-07-06 `sc-gpu-benchmark` (170G, progetto separato) era stato spostato lì liberando la quota da 9.9G→380G — utile ma **NON** ha risolto il 0:53 (che è il blocco poddgx02 di sopra). **TODO**: migrare il workspace `simulomicsr-dgx` (HF_HOME 101G + runs) su `/projects` + cambiare `dgx_config()$remote_root`; PRIMA verificare che `/mnt/projects` sia montato sui compute node e bindarlo in `run_p4.sh`.
- **ssh non-interattivo NON sourca `/etc/profile.d/*.sh`** → `SLURM_CONF` mancante. Fix in `R/dgx-utils.R::.dgx_ssh()`: wrap del comando remoto con `bash -lc <cmd>` per forzare login shell.
- **Esecuzione singularity diretta, NO `srun`** — `srun singularity` non è supportato/affidabile su questo cluster. Usare `singularity exec --nv ...` direttamente.
- Vignette setup completa: `vignettes/p4-dgx-setup.Rmd`.

## Decisioni rinviate

- **ADR-0003 — rinome pacchetto.** "simulomicsr" non riflette la pipeline. Da affrontare prima del primo `install_github` pubblico.
- **ADR-0010 — vLLM upgrade evaluation.** Aprire SOLO dopo chiusura α + tag p4-dgx-complete; vLLM Issue #39734 non risolto upstream nemmeno in 0.19.x.
- **Vocabolari extra** (Cellosaurus, DrugBank, ChEMBL, MeSH, CAS, NCBITaxonomy, MGI). Necessari per Stadio 2 esteso (post-α).
- **Gold "design-aware"** scaled su 200-300 sample. Mini-gold v5 attuale è 100 sample.
- **Integrazione MetaHQ** come upstream per `normalize_tissue()` / `normalize_disease()` in Stadio 2.
- **Migrazione a `ellmer`** come client LLM (multi-provider, batch API più ergonomico). ADR separato post-α.
- **Cache cross-modello.** P1 attuale partiziona per `(provider, model, messages)`. Se servisse cache cross-modello, ADR dedicato.
- **Migrazione su server con più spazio.** ADR-0005 documenta trigger e procedura.
- **Findings sotto-soglia P3.5-A** (eventuale prompt iter post-α): `treatment_vs_untreated` 77.3% (n=141), `time_course` 59.3% (n=54), `case_control_disease` 49.1% (n=57, sotto casuale).
- ~~**β retry/uniqfail infrastructure pre full run**~~ **DONE 2026-05-17 con β rescue cascade**. Risolto via Phase 1 classification + H1 single-shot rep_pen=1.2/max_tokens=4096 + H3 cs50→cs25 invece di multi-round retry. Risultato: stage1 LLM-only 99.998% + stage2 100.000%. Cascade documentato in ADR-0008 addendum 2026-05-17 + `docs/findings/2026-05-17-p4-beta-rescue-strategies.md`.
- **β gate2 throughput measurement bug** (cosmetico, gate-decision non impattata). Lo script `analysis/p4-beta-gate2-smoke.R` misura wall come `Sys.time()` pre/post `poll_until_done`, ma resume da job COMPLETED restituisce ~5 sec → "throughput 9996 rec/min" artefatto. Fix corretto: pull `sacct -j JID --format=Elapsed` e usare quello come wall reale. ETA stage1 full corretta calcolata a mano dal log poll iniziale: ~59h.

## Roadmap

### β tutti i task DONE (chiusura 2026-05-17)

1. ~~**β Task 10 stage1 full run**~~ **DONE** 2026-05-14/15. 888.795 record mainstream + 26 outliers = 888.821 totali. Wall 17h53min mainstream + 2m23s outliers. Master output: `analysis/p4-output/p4-beta-stage1-master-predictions.jsonl`.
2. ~~**β Task 10b stage1 outliers**~~ **DONE** 2026-05-15. Strategy A2 (`max_model_len=32768`) ha completato 26/26 record in 2m23s wall.
3. ~~**β Task 11 stage2-input**~~ **DONE** 2026-05-15. 39.205 record stage2 (vs ~17k stima gate2). Output `analysis/input/archs4-human-stage2-input.jsonl` (1.2 GB).
4. ~~**β Task 12 stage2 full run**~~ **DONE** 2026-05-15/17. Wall reale ~42.5h (vs stima iniziale 6-8h sbagliata per via di 37% tier XL e cold-start). Schema validity 99.89% (39.162/39.205). Job slurm 20710 ExitCode 0:0.
5. ~~**β Task 15 closing**~~ **DONE** 2026-05-17. NEWS 0.0.0.9016 esteso, tag `p4-beta-archs4-human-complete`, ff-merge → master locale. Push remote rimane all'utente.
6. ~~**β rescue cascade Task 1-15**~~ **DONE** 2026-05-17. Stage1 99.998% LLM-only + stage2 100.000%. NEWS 0.0.0.9017 esteso, tag `p4-beta-rescue-complete` (pending Task 15 close), ff-merge → master locale. Discovery paper-grade H2 (72 mouse-mislabeled GSE) + strategie rescue consolidate in `docs/findings/2026-05-17-p4-beta-rescue-strategies.md`.

### Post-β + P5 Stadio 4 Layer A (immediato)

1. ~~**Stadio 3 raggruppamento cross-studio**~~ **DONE** pre-fullrun (Stage 3 build `2153addc` da cui parte il fullrun: 267.056 cluster, 707.595 assignment, 39.247 stage2 studies).
2. ~~**Stadio 4 Layer A** (`build_stage4_results`)~~ **DONE 2026-05-23** (run_id `96c43acb`, 622/622 cluster OK).
3. **Stadio 4 Layer B** + **Stadio 5 meta-analisi**: prossimo step su `cluster_pooled.parquet` (13.7M righe). Spec design da scrivere.
4. **Rename pacchetto** (ADR-0003) prima del primo `install_github` pubblico.
5. **Migrazione a `ellmer`** come ADR separato.
6. **γ ARCHS4 mouse** (post-human consolidato). NO γ in pianificazione attiva — gestito come variante futura.

## Dove vivere i dati che il repo NON contiene

| Asset                       | Location                                                          | Come ottenerlo / ricostruirlo                                            |
|-----------------------------|-------------------------------------------------------------------|--------------------------------------------------------------------------|
| `OPENAI_API_KEY`            | `.Renviron.local` (gitignored)                                    | Utente ricrea manualmente. Riga `OPENAI_API_KEY="sk-..."`.               |
| renv libreria               | `~/Library/Caches/.../renv/` (macOS) o `~/.cache/R/renv/` (Linux) | `renv::restore()` da `renv.lock` committato.                             |
| HGNC dump completo          | `tools::R_user_dir("simulomicsr", which="cache")/hgnc_complete_set.tsv` | Download manuale da `https://www.genenames.org/download/archive/`.   |
| Cache LLM                   | `analysis/cache/` (gitignored)                                    | Auto-popolata dai run di `tar_make`. Trasferibile via `rsync`.           |
| Pipeline state              | `analysis/_targets/` (gitignored)                                 | Auto-popolato da `tar_make`. Trasferibile via `rsync`.                   |
| ARCHS4 H5 human v2.5        | `analysis/input/human_gene_v2.5.h5` (47.86GB, gitignored)         | `wget -c https://mssm-data.s3.amazonaws.com/human_gene_v2.5.h5` (~1.5h wall). SHA256 + provenance in `analysis/p4-output/p4-beta-archs4-source.json`. |
| File risultato α stage1/2   | `analysis/p4-output/*.rds` (gitignored)                           | Output dei job DGX, ricostruibili da `analysis/p4-bundles/*-job.rds`.    |
| β ETL output JSONL          | `analysis/input/archs4-human-stage1-input.jsonl` (262MB, gitignored) | Re-generato da `Rscript analysis/p4-beta-etl-build.R` (richiede H5 + cache Entrez). Stage 4 vectorizzato ~3 sec con cache full, ~5min Stage 2 H5 re-read. |
| β cache Entrez resolver     | `tools::R_user_dir("simulomicsr", which="cache")/geo-series-resolver-cache.rds` | Re-buildabile via `entrez_lookup_gse_metadata` (~5-6h wall per 32.9k GSE @ ~1.5 GSE/s con NCBI_API_KEY). |
| Bundle/runtime DGX          | `analysis/p4-bundles/` (gitignored)                               | Generati da `dgx_p4_build_bundle()`.                                     |

## Riferimenti chiave

### ADR (decisioni architetturali, in `docs/decisions/`)

- 0001 sistema-tracking · 0002 struttura-research-compendium · 0004 renv-riconciliato · 0005 server-migration-trigger
- **0006 stato-arte-vs-simulomicsr** — analisi competitor 2024-2026 + benchmark RummaGEO + decisione P3-B
- **0007 dgx-self-host-vllm** — bespoke minimale dentro simulomicsr + workflow Docker→DockerHub→Singularity
- **0008 vllm-sampling-defaults** — temperature=0.0, repetition_penalty=1.1 stage1+stage2
- **0009 stage2-safe-mode-vllm-deadlock** — `max_num_seqs=1, microbatch=1` stage2 deadlock-proof Issue #39734
- **0011 tier-based-max-tokens** — single-pass strategy per stage2 con per-record max_tokens proporzionato
- **0012 stage2-schema-multi-axis-limitation** — known limit `primary_role` mono-axis vs design factoriali (paper-grade note)

### Specs / plans (in `docs/superpowers/`)

- Spec classificatore: `specs/2026-04-29-classificatore-llm-design.md` (v5 approvata 2026-04-29).
- Plan P1-P4: `plans/<date>-p<N>-*.md` + companion HUMANE.
- Spec investigation Task 22: `specs/2026-05-08-task22-stage2-vllm-stalls-investigation.md` (RESOLVED).

### Report Quarto

- `analysis/eval/p35-benchmark.html` (838 KB) — P3.5-B prototipo (15 GSE, 197 sample).
- `analysis/eval/p35a-benchmark.html` (980 KB) — P3.5-A scaled (100 GSE, 1507 sample, paper-ready: Wilson CI + McNemar + bootstrap + Holm).

### Documentazione storica

- **`docs/model-evaluation-history.md`** — valutazioni P3.5-C (5 modelli closed) + P3.5-D (21 modelli OpenRouter) + pattern strutturali + decisione mistral-small-3.2.

### Vignette + utenti

- `vignettes/p4-dgx-setup.Rmd` — one-time guide setup DGX.
- `README.md`, `NEWS.md` — entry point utente + storia versioni.
