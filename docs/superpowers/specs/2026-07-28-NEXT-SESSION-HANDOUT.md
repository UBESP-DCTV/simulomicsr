# HANDOUT — prossima sessione (preparato 2026-07-27, notte autonoma)

**Branch:** `review-scientific-consistency-2026-06-10` · master invariato · nessun push
**Stato:** 🟡 **L'innesto è fatto: la pipeline chiama le regole. Equivalenza verificata, censimento
fatto su TUTTI. NESSUN run pesante eseguito — il deliverable sul disco è ancora quello vecchio.**

---

## 0. REGOLE (non negoziabili)

1. Il gate è la **COERENZA**, mai il numero di gruppi.
2. Verifica su **TUTTI**, mai su un campione.
3. Zero slop: sigle, parole generiche, veicoli, induttori, classi-ombrello non sono entità.
4. Pipeline pubblicata **deterministica**: nessun LLM a runtime.
5. **Nessun run pesante senza GO esplicito dell'utente.**
6. Fail onesto coi numeri.
7. **VIETATO** dichiarare "validato / finale / paper-grade" senza prova per-gruppo su TUTTI.
8. Se una misura contraddice una conclusione precedente, si ritratta subito e per iscritto.

## 1. CHE COSA È CAMBIATO (codice, non simulazione)

`build_stage3_clusters()` emette **record `cgroup`**, uno per ogni comparison dello Stadio 2:

```
anchor_key = <entità del delta canonicalizzata> || <verso> || <tipo di controllo composito>
level      = 5   (non è un L0..L4: la chiave è già l'identità completa)
```

- **Nuovo:** `R/stage3-contrast-anchor.R` (delta dai `factor_levels`, risoluzione blindata
  dell'entità, combinazioni, verdetto per-membro `.ca_member_contrast()`), 219 test.
- **Modificato:** `R/stage3-build.R` (`.build_contrast_group_records()` + innesto fasi 2/3/5/6/8),
  `R/stage4-qc.R` (il ramo `rem_group` consuma `mode == "cgroup"`; dedup per entità **e verso**),
  `R/stage4-dispatch.R` (i `cgroup` si risolvono per comparison).
- **Non toccati:** `.build_pair_records()`, `.build_group_records()`, i rami `rem`, `mega`,
  `mega_aug`. Test di non-regressione espliciti.

Le regole del gate (`.cg_*`) e dell'appaiamento della riga (`.rp_row_defect`) sono **richiamate, non
riscritte**.

## 2. NUMERI (misurati, mai stimati)

**Equivalenza col gate misurato, sugli stessi 38.440 contrasti**
(`analysis/audit/2026-07-27-contrast-builder/10-equivalenza-builder.R`):

| | |
|---|---:|
| verdetto identico (tenuto/scartato) | 38.198 / 38.440 (**99,4%**) |
| gruppi del gate **persi** | **0** |
| gruppi del gate con **k identico** | **144 / 144** |
| gruppi nuovi | 1 (`MeSH:D012008`, giudicato incoerente) |

Bandiera, pavimenti rispettati esattamente: SARS 28 · TGFB1 27 · LPS 26 · enzalutamide 21 ·
vemurafenib 13.

**Censimento di coerenza, TUTTI i 145 gruppi letti uno per uno**
(`60-verdetti-censimento.R` → `censimento-verdetti.csv`):

| | |
|---|---:|
| gruppi poolabili k≥3 | **145** |
| **coerenti** | **141 (97,2%)** |
| studi-slot nei coerenti | 866 / 878 |

Incoerenti: CSF2 (polarizzazione M1/M0), PTSD (perturbazione dentro-malattia), RSV (clinico +
sperimentale) — **gli stessi tre** del 2026-07-25 — più `MeSH:D012008` Recurrence (nuovo).

⚠️ **Questi numeri girano sui contrasti già ricostruiti, non sull'output di un re-cluster. Sono un
pavimento da riverificare, non un risultato.**

## 3. IL LAVORO DELLA PROSSIMA SESSIONE

### 3.1 Tre decisioni dell'utente, tutte con i numeri già in mano

1. **GO sul re-cluster + re-pool?** È il passo che materializza tutto. ~8h + ~50h.
2. **Ri-mappaggio delle sigle del resolver — da riaprire.** Il 2026-07-26 la decisione fu "no",
   sulla base di "0 gruppi poolabili NUOVI": misura giusta e ancora valida. Ma il censimento ha
   quantificato un'altra cosa, la **potenza persa per frammentazione**: enzalutamide `CHEBI:68534`
   k=21 **+** `STR:enza` k=4; TGFB1 `HGNC:11766` k=27 **+** `STR:tgfb` k=7. Due gruppi puliti che
   sono lo stesso oggetto biologico. (Ipossia e SARS compaiono spezzate nella misura ma sono
   artefatti del proxy: nel build si fondono da sole.)
3. **Soglia k≥3, riaperta da ADR-0026.** Fu fissata quando `mega_aug` (419 cluster a k=2) era ancora
   nel deliverable. Ora `mega` è fuori (ADR-0026) e `mega_aug` è sotto esame: la proposta non decisa
   è un **livello dichiarato a k=2** per il ramo `cgroup`, senza prestito di campioni.

### 3.2 Se arriva il GO

1. **Verificare che `recover_identity()` non sia cambiato** → se è cambiato, bump di
   `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` (oggi **v7**) **prima** del run. È l'errore che è già
   costato 8 ore.
2. **Re-cluster Stadio 3** (~8h, `setsid`, verificare SID==PID). Attesi: record `cgroup` nel log di
   fase 2, cluster `cgroup_L5_*` in `clusters.rds`, colonne `contrast_*` popolate.
3. **Applicare ADR-0026** (il ramo `mega` esce dal deliverable) **prima del re-pool**.
4. **Re-pool Stadio 4** (~50h) + verifica ANTI-STALE (`Methods` deve contenere `rem_group`, i
   cluster devono essere `cgroup_L5_*`, e **non** deve contenere `mega`).
5. **Ri-censimento della coerenza sui dati VERI, su TUTTI i gruppi.** Il 97,2% è un pavimento.

## 4. TRAPPOLE GIÀ PAGATE (dodici bug in una notte)

- **Il vocabolario e le guardie viaggiano CON la regola.** Tre bug su dodici sono la stessa lezione:
  una guardia giusta al posto sbagliato è un bug silenzioso (la guardia sulle sigle corte va sui
  token pescati da un'etichetta libera, **non** sulle parti separate da `+`; il nome risolto si
  giudica per **appartenenza al vocabolario**, non per lunghezza — TNF, RSV, CMV, HBV hanno meno di
  5 caratteri).
- **Togliere le dosi non deve togliere i separatori**: `Bleomycin/Alpha-Lipoic Acid` senza `/` non è
  più una combinazione.
- **`_` è carattere di parola** per le espressioni regolari: normalizzare i separatori prima di `\b`.
- **`cli >= 3.4` legge `{.x}` come stile**: nei log usare `{(.x)}`, altrimenti il build muore.
- **Nella suite completa i dizionari si caricano come fixture**: i test end-to-end vengono saltati e
  possono nascondere un errore. Girare anche il singolo file.
- **L'entità si risolve dai valori della CLASSE DOMINANTE**, non da tutti.
- **`Rscript --vanilla` non trova devtools** (renv): per gli script che caricano il pacchetto usare
  `Rscript` senza `--vanilla`.
- **`run_in_background` uccide i run lunghi**: `setsid`, e verificare SID==PID.
- **Un confronto sbagliato accusa il codice innocente**: la prima equivalenza dava 1214 differenze,
  ma 853 erano colpa della misura (teneva spento il ramo on-contrast). Prima di correggere il
  codice, controllare che il metro sia giusto.

## 5. ASSET

| cosa | dove |
|---|---|
| verdetti per gruppo | `analysis/audit/2026-07-27-contrast-builder/censimento-verdetti.csv` |
| bundle letti uno per uno | `.../bundle-gruppi.txt` (2.679 righe) |
| differenze col gate, per classe | `.../differenze-classi.txt`, `differenze-tutte.csv` |
| smoke bandiera | `.../smoke-bandiera.csv` |
| finding equivalenza | `docs/findings/2026-07-27-equivalenza-builder-contrasto.md` |
| finding censimento | `docs/findings/2026-07-27-censimento-145-gruppi.md` |
| ADR dell'innesto | `docs/decisions/0025-stage3-contrast-derived-group-records.md` (+ Addendum) |
| ADR mega fuori dal deliverable | `docs/decisions/0026-mega-branch-out-of-deliverable.md` (branch `mega-recovery-2026-07-27`) |
| piano eseguito | `docs/superpowers/plans/2026-07-27-stage3-contrast-group-builder-plan.md` |

## 6. STATO DELLA SUITE

`stage3-contrast*`: **219 PASS / 0 FAIL** (dizionari reali, 0 skip).
Stadio 3 completo: 1113 PASS, **1 FAIL pre-esistente** (`test-stage3-perf-budget` punta al master
Stadio 2 β, che viola l'invariante un-record-per-studio di ADR-0020 — verificato in stash su HEAD
pulito: fallisce identico senza le modifiche di questa sessione).
Stadio 4: 787 PASS, **2 FAIL pre-esistenti** (dashboard richiede il CLI quarto; gene-axis E2).
