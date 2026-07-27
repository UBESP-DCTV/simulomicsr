# HANDOUT — sessione del RE-CLUSTER (preparato 2026-07-27)

**Branch:** `review-scientific-consistency-2026-06-10` (pushato su richiesta dell'utente il
2026-07-27) · master invariato
**Stato:** 🟢 **Tutto pronto. Il codice è innestato, verificato e censito. Manca solo eseguire.**
**Il lavoro di questa sessione è UN RUN PESANTE (~8h) con aggiornamento ORARIO all'utente.**

---

## 0. REGOLE (non negoziabili)

1. Il gate è la **COERENZA**, mai il numero di gruppi.
2. Verifica su **TUTTI**, mai su un campione.
3. Nessun LLM nella pipeline.
4. **Aggiornamento ogni ora** durante il run: "fatto X, mancano Y, ETA Z". Non solo alla fine.
5. Fail onesto coi numeri.
6. **VIETATO** dichiarare "validato / finale / paper-grade" senza prova per-gruppo su TUTTI.
7. Se una misura contraddice una conclusione precedente, si ritratta subito e per iscritto.

## 1. COSA SI ESEGUE E PERCHÉ

Il codice fa nascere i raggruppamenti dal **contrasto** (delta trattato↔controllo) invece che dalla
perturbazione del campione. È verificato contro il gate misurato e censito su tutti i gruppi, ma
**non è mai stato eseguito sulla pipeline vera**: il deliverable sul disco è ancora quello vecchio
(184 gruppi, 85% minestroni). Questo run lo materializza.

**Decisioni già prese dall'utente, non ri-litigare:**

| ramo | destino | dove |
|---|---|---|
| `mega` (99) | **fuori dal deliverable** | ADR-0026 |
| `mega_aug` (419) | **fuori** | decisione utente 2026-07-27 |
| `rem` (12) | **fuori** — verificato: 12 cluster = 6 meta-analisi, 5 minestroni, l'unica pulita (sarcopenia) è già nel ramo nuovo con k=4 invece di 3 | `bundle-rem.txt` |
| `cgroup` (144) | **è il deliverable** | ADR-0025 |

## 2. STATO ATTESO PRIMA DI PARTIRE (verificarlo, non fidarsi)

```r
devtools::test(filter = "stage3-contrast")   # atteso: 228 PASS / 0 FAIL
```

- `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` = **v7**. **NON va bumpato**: verificato il 2026-07-27 che
  dal commit che l'ha messo a v7 l'unica modifica ai file del recupero-nome è `4f4a1c8`, che aggiunge
  **7 righe di solo commento**. Il codice nuovo (`R/stage3-contrast-anchor.R`) non nomina mai
  `recover_identity`.
- Ultimo commit atteso: `9bf0c50` (o successivi di sola documentazione).

## 3. IL RUN

### 3.1 Re-cluster Stadio 3 (~8h)

Script: `analysis/p4-fase-f6-stage3-reclustering.R` (lo stesso di v10; va aggiornato il token di
versione a **v12** e la directory di output).

```bash
# SMOKE prima, sempre: deve mostrare record cgroup e cluster cgroup_L5_*
SMOKE=1 Rscript analysis/p4-fase-f6-stage3-reclustering.R 2>&1 | tail -40

# poi il full, DETACHED (run_in_background uccide i run lunghi)
setsid nohup Rscript analysis/p4-fase-f6-stage3-reclustering.R \
  > analysis/audit/v12-recluster-full.log 2>&1 < /dev/null &
# verificare SID == PID
ps -o pid,sid,cmd -p $(pgrep -f p4-fase-f6-stage3)
```

**Cosa deve comparire nel log (se non c'è, FERMARSI):**

- fase 2: `... pair + ... group + ... cgroup records` — il terzo numero non deve essere zero;
- fase 5: `mode=cgroup L5: N record`;
- a fine run, in `clusters.rds`: `mode == "cgroup"`, `level == 5`, `cluster_id` che inizia con
  `cgroup_L5_`, colonne `contrast_entity` / `contrast_direction` / `contrast_control_key` popolate.

**Controllo bandiera sul risultato vero** (pavimenti misurati in simulazione, `smoke-bandiera.csv`):
SARS-CoV-2 `NCBITaxon:2697049` k≥28 · TGFB1 `HGNC:11766` k≥38 · LPS `CHEBI:16412` k≥26 ·
enzalutamide `CHEBI:68534` k≥24 · vemurafenib `CHEBI:63637` k≥13.
**Se scendono: fermarsi e misurare, non aggiustare.**

### 3.2 Aggiornamento ORARIO (obbligatorio)

Il run dura ~8 ore. Ogni ora: quante fasi fatte, a che punto è, quanto manca. Il poller esce ogni
~60 minuti o a completamento — non si aspetta la fine in silenzio.

### 3.3 Applicare le decisioni sui rami — PRIMA del re-pool

`mega`, `mega_aug` e `rem` escono dal deliverable. È una modifica di **selezione** in
`.identify_layer_a_clusters()` (`R/stage4-qc.R`), **non** una cancellazione di codice: le funzioni di
quei rami restano, con i loro test. Da fare con TDD prima di lanciare il re-pool.

### 3.4 Re-pool Stadio 4 (~50h) — GATE UTENTE SEPARATO

Non parte in automatico dopo il re-cluster: si riporta l'esito del re-cluster e **si chiede il GO**.

Verifica ANTI-STALE sul pooled: `Methods` deve contenere `rem_group` e **non** deve contenere
`mega`, `mega_aug`, `rem`; i `cluster_id` devono essere `cgroup_L5_*`.

### 3.5 Ri-censimento della coerenza sui dati VERI — su TUTTI

**Il 97,2% è un pavimento misurato in simulazione, non un risultato.** Dopo il re-pool si rigenerano
i bundle e si rileggono **tutti** i gruppi, come il 2026-07-27
(`analysis/audit/2026-07-27-contrast-builder/40-bundle-gruppi.R` è riusabile cambiando la sorgente).

## 4. NUMERI DI RIFERIMENTO (dalla simulazione col codice di produzione)

| | |
|---|---:|
| gruppi poolabili k≥3 | **144** |
| coerenti (letti uno per uno) | **140 (97,2%)** |
| studi-slot nei coerenti | 882 / 894 |
| equivalenza col gate misurato | 0 gruppi persi, k identico su 144 |

Incoerenti noti: CSF2 (polarizzazione M1/M0), PTSD (perturbazione dentro-malattia), RSV (clinico +
sperimentale), `MeSH:D012008` Recurrence.

## 5. TRAPPOLE GIÀ PAGATE

- **`setsid`**, mai `run_in_background`: uccide i run lunghi. Verificare SID==PID.
- **`Rscript` senza `--vanilla`** per gli script che caricano il pacchetto (renv).
- **Non bumpare la cache-version** se `recover_identity()` non cambia — e **non dimenticarlo** se
  cambia: è già costato 8 ore.
- **Nella suite completa i dizionari si caricano come fixture**: i test end-to-end vengono saltati.
  Girare anche il singolo file.
- **Un metro sbagliato accusa il codice innocente**: la prima equivalenza dava 1214 differenze, 853
  erano colpa della misura. Prima di correggere, controllare lo strumento.

## 6. SE QUALCOSA VA STORTO

Fermarsi e misurare. Non ri-lanciare in modo reattivo: dopo due fallimenti dello stesso job si isola
la causa con un caso minimale riproducibile (`superpowers:systematic-debugging`), si valida, e solo
allora si ri-tenta.

## 7. ASSET

| cosa | dove |
|---|---|
| verdetti per gruppo | `analysis/audit/2026-07-27-contrast-builder/censimento-verdetti.csv` |
| bundle dei gruppi | `.../bundle-gruppi.txt` |
| censimento del ramo rem | `.../bundle-rem.txt` |
| pavimenti bandiera | `.../smoke-bandiera.csv` |
| equivalenza | `.../10-equivalenza-builder.R`, `10.log` |
| ADR dell'innesto | `docs/decisions/0025-stage3-contrast-derived-group-records.md` |
| ADR mega fuori | `docs/decisions/0026-mega-branch-out-of-deliverable.md` (branch `mega-recovery-2026-07-27`) |
| finding equivalenza | `docs/findings/2026-07-27-equivalenza-builder-contrasto.md` |
| finding censimento | `docs/findings/2026-07-27-censimento-145-gruppi.md` |
