# CLAUDE.md — contesto persistente per Claude Code su `simulomicsr`

> Fonte canonica del contesto del progetto per ogni sessione Claude Code, su
> qualunque macchina. Sostituisce la memoria locale (`~/.claude/projects/<path>/memory/`).
> **Leggi questo file per intero prima di agire.** È corto apposta: la cronologia
> (preambolo RED ALERT + 44 blocchi di «Stato», maggio–agosto 2026) sta in
> **`docs/STORIA.md`**, con l'indice delle ritrattazioni in testa. Qui sta lo
> STATO, non la storia: non riportare qui blocchi di cronologia.
>
> **Protocollo di sessione:** all'inizio di ogni sessione carica la skill
> `simulomicsr-session` (`.claude/skills/simulomicsr-session/`). Rispondi al PI in stile
> ASD-STE100 all'80%, in italiano: le regole stanno nella skill. Vale dalla prima sessione
> dopo il 2026-11-02 e non è retroattivo.

---

## 1. Dove siamo (2026-11-07)

**Branch** `review-scientific-consistency-2026-06-10` · **master invariato** ·
**mai `git push`** (lo fa l'utente).

**Deliverable corrente — A3 v16, 194 meta-analisi:**
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`
(Stadio 3 `analysis/p4-output/20260818T110906Z-stage3-v16-7f986159`; Stadio 1 e 2
**rigenerati** su un sottoinsieme congelato di 2.566 studi con `VLLM_BATCH_INVARIANT=1`).
**Riferimento per i confronti — 211 meta-analisi, master LLM vecchi:**
`.../simulomicsr-stage4-v16/archivio/20260815T193851Z-stage4-v16-3e31e59d` su Stadio 3
`analysis/p4-output/20260815T231154Z-stage3-v16-7f986159` (byte-identico a
`20260814T025911Z-…`, che è quello scritto nel suo `run_metadata.json`).
Le altre due directory omonime (`20260815T121010Z`, v16 senza collasso delle corsie;
`20260819T184204Z`, duplicato byte-identico del deliverable) stanno con il riferimento
in **`archivio/`** dal 2026-08-21 — il `README.md` nella cartella dice che cosa sono;
nella radice resta solo il deliverable. I documenti anteriori le citano senza `archivio/`.
**Copia verificata** (S2, 2026-08-21) in `/mnt/micron/simulomicsr-salvataggio/`
(deliverable, riferimento, Stadio 3, master, dizionari; 9,4 GB) col manifesto
`analysis/audit/2026-08-21-S2-deliverable-in-salvo/SHA256SUMS.txt` — verifica:
`10-manifesto-e-copia.sh verifica [DEST]`. Nei prompt scrivi il percorso per esteso:
il difetto tipico di questo progetto è lavorare sull'oggetto sbagliato.

**Il quadro (S3-S11 chiuse fra il 2026-08-22 e il 2026-11-07; i blocchi di Stato verbatim stanno in
`docs/STORIA.md` Parte V; fa fede il finding):**

| che cosa sappiamo | numero | finding |
|---|---|---|
| Le 194 lette tutte, due volte | 116 corrette / 62 difettose / 16 incerte; test-retest **kappa 0,78**; umano 18/19 | `2026-08-20-rilettura-194-correttezza`, `2026-08-21-S3-il-metro-concorda` |
| Confronti difettosi di riferimento | **193 / 1.903 (10,1%)**, 85 categorie, 55 con un solo caso; origine: 65% bracci non appaiati (tempo zero 48), 23% seconda perturbazione persa, 8% chiave, 4% indecidibili | `2026-11-07-S11-lettura-falsi-allarmi`, `2026-11-07-valutazione-autonoma-del-progetto` |
| Rilevatore a regole | vede **81/193**; non va in produzione (ADR-0028) | `2026-11-07-S10-rilevatore`, `-S10b-rilevatore-metadati` |
| Controllo condiviso | 492/1.118 bracci; errore standard ×1,20; taglio 113 → 41; tre bracci con ruoli sbagliati (`GSE222992`, `GSE208347`, `GSE135485`) | `2026-11-02-S4-controllo-condiviso` |
| Gate e insiemi | gate a **3 studi**; «40 principali + 132 supplementari» **decaduta** in S11: si rifà in S15 | `2026-11-03-S5-gate-e-insiemi` |
| Studi doppi | 13 gruppi (`sirna pool against igf2bp1` = uno studio); si tolgono in S13 con una regola sulle conte | S5 §6 |
| Validazione esterna (senza nullo) | 14/19 LINCS, 11/32 Tahoe-100M; tumori 6/6 su TCGA; il numero dell'articolo è della seconda esecuzione (S7c) | `2026-11-04-S6-…`, `-S7-validazione-esecuzione` |
| Greche, sinonimi, ID | 7/194 cambiano; **il modello scrive il nome giusto con l'ID ChEBI sbagliato** e il codice si fida dell'ID; 61/194 `canonical_name` sbagliati o NA (l'etichetta di contrasto è giusta) | `2026-11-07-S9-greche-e-corsie`, valutazione |
| Inversioni di braccio | `GSE144269` in HCC confermata (gruppo non citabile finché non è corretto) + 4 bracci; lo strumento vede il 52% | `2026-11-02-inversioni-bracci-194` |
| Re-run Stadi 1-2 (S14, prima parte) | 24.393 studi da zero in 33 h; 211.484/211.484 record identici; master `analysis/p4-output/S14-stage{1,2}-master.jsonl` (copia su micron); outlier con `max_model_len` 32768 | `2026-11-07-S14-due-passi-col-modello`, `-S8b-prova-re-run` |
| Soffitto e biologia | **455 entità** con ≥3 studi nello Stadio 3 (deliverable = 43%); controllo biologico **30/31**, DHT contro enzalutamide −0,944 | valutazione |
| Stadio 2b, il disegno (S12) | schema, regola (segnali → tabella errore/avviso), ingresso senza tagli, prompt v1, test verdi; 1.902/1.903 ingressi nel limite (mediana 3.603 token); **codifica UTF-8 doppia e tripla nell'H5**, riparata nell'ingresso; `description` per campione assente dall'H5 (cambia fra i campioni in 22/40 studi) | `2026-11-07-S12-stadio2b-disegno` |

**Decisione del PI (2026-11-07):** strada «tenere e sostituire un pezzo» (ADR-0028). Si tengono ETL,
master S14, Stadio 4, gold, verdetti e strumenti di audit; **si sostituisce il giudice di confrontabilità**
con lo **Stadio 2b**: il modello legge il testo grezzo dei due bracci e compila una lista di controllo, una
regola deterministica decide. Cancello: la prova cieca di S12p (≥130/193 presi, ≤40/1.710 accusati). Il
modello non cambia finché S12p non lo misura. Finding: `docs/findings/2026-11-07-valutazione-autonoma-del-progetto.md`.

**Decisioni del PI che restano valide, una riga ciascuna:** gate a 3 studi · S13 corregge la varianza del
controllo condiviso (T1) e assegna i ruoli per nome · studi doppi tolti con una regola sulle conte · LINCS dà
il verdetto, Tahoe-100M si riporta senza verdetto, soglia 17% · nessuna correzione guarda l'esito di una
singola meta-analisi · tempo zero e differenza tecnica fra i bracci sono **sempre** errori · **nessuna
soglia di errore accettata**: ogni causa si corregge · solo `poddgx02`.

**Che cosa fare adesso:** **`docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md`** comanda
l'ordine: **S12** (Stadio 2b, il disegno: fatto, **4 decisioni del PI in attesa**, riquadro S12) → **S12p** (la prova: tre modelli sui 1.903, conto cieco) →
S12c+S12b, S12d → **S13** (tutto sui master S14, deliverable v17) → S15 (rilettura cieca) → S7c, S7b → S16,
S17. L'handout del 2026-08-21 resta per le sessioni chiuse e per i prompt di S12b, S12c, S12d, S16, S17.
Il deliverable su disco resta A3 v16 fino a S13.

**La regola che governa tutto (RED ALERT 2026-07-24, `docs/RED_ALERT.md`):** per
mesi si sono ottimizzati i NOMI dei cluster dichiarando «finale» senza verificare
la **coerenza di contrasto**; verificata, l'85% del deliverable era minestrone.
Da allora **la coerenza è il gate, non i nomi**; niente si dichiara «finale /
publication-grade» senza il gate; le verifiche si fanno su **tutti** i gruppi,
mai a campione; i numeri si misurano sull'oggetto vero, non su un proxy.

---

## 2. La pipeline in breve

`simulomicsr` è una **pipeline R per meta-analisi RNAseq cross-studio
design-aware** basata su classificazione LLM dei metadati GEO (il nome è legacy:
non simula nulla). Positioning ADR-0006: non un annotatore di GEO ma la catena
end-to-end metadato → comparison appaiate → anchor canonico → pooling REM;
competitor più vicino RummaGEO (gene-set per studio, senza anchor né effect size).

| stadio | che cosa fa | dove |
|---|---|---|
| 0 · ETL | ARCHS4 v2.5 human bulk (H5) → bacino 508.037 campioni; filtro mouse-mislabeled H2; resolver series | `R/etl-*.R`, `analysis/p4-fase-f-etl-build.R` |
| 1 · sample | Mistral classifica ogni campione (`sample_facts.stage1.v3`); guard deterministico `is_zero_timepoint` a valle | `R/stage1-*.R`, `p4-fase-f2-*` |
| 2 · study | Mistral interpreta il disegno: replicate groups, `design_role`, comparison; **un record per studio** (`.assert_stage2_one_record_per_series`) | `R/stage2-*.R`, `p4-fase-f4-stage2-*-v3.R` |
| 3 · cluster | `build_stage3_clusters()`: record `cgroup` **dal contrasto** (ADR-0025), chiave `entità-delta ‖ verso ‖ tipo-di-controllo`; regole di gate (`stage3-contrast-gate.R`) e di riga (`stage3-row-pairing.R`); recupero-nome deterministico + overlay; coerenza `stage3-coherence.R` | `R/stage3-*.R`, `analysis/p4-fase-f13-stage3-v16-tre-cambi.R` |
| 4 · pooling | solo ramo **`rem_group`** (ADR-0022/0026): limma-voom per studio + collasso bracci intra-studio + REM `metafor`; gate `k_eff≥3`, `n_min=2`; corsie di sequenziamento collassate (`stage4-technical-lanes.R`); dedup una meta-analisi per entità; annotazione `k_kish`/dominanza (`stage4-deliverable-annotation.R`); LOO (`stage4-loo-influence.R`) | `R/stage4-*.R`, `analysis/p4-fase-f5-stage4-layer-a-rebuild-v16.R` + `-f5b-stage4-ricomponi-pezzi.R` |
| Layer B | case study per l'articolo (ADR-0017, selezione ADR-0027): 9 bundle, figure, narrative in bozza | `R/layer-b-*.R`, `analysis/p5-stage4-layer-b-build-v*.R` |

Rami `mega`, `mega_aug`, `rem` restano nel codice ma **fuori dal deliverable**
(`stage4_default_config()$deliverable_methods = "rem_group"`).

---

## 3. Comandi che funzionano (verificati)

- **R sul laptop: `Rscript` SENZA `--vanilla`.** Con `--vanilla` mancano `arrow`
  e `devtools` (verificato 2026-08-21). Gli script di audit lo dicono in testata.
  Sul DGX (R 4.6.0) idem: `Rscript -e ...` senza `--vanilla`.
- **Suite di test:** `Rscript -e 'devtools::load_all("."); testthat::test_local(filter="stage4", reporter="summary")'`
  — **senza `head` in pipe** (chiude la pipe e tronca la suite: è già successo).
  Ultima misura: 4.317 asserzioni, 0 fallimenti (2026-08-13).
- **Run multi-ora: `setsid nohup ... < /dev/null &`**, poi verifica `SID == PID`
  (`ps -eo pid,sid,args | grep "[f]13-stage3"`). `run_in_background=true` ha
  **ucciso** un run di ore (stage4 v6 a cluster 76/533, senza OOM né errore).
  Monitorare con `pgrep` sul nome dello script, non col PID.
- **Aggiornamento ORARIO durante i run pesanti**: «fatto + ETA» ogni ora, non
  solo a fine run. Niente poller `until … sleep` in background: check attivi.
- **Re-cluster Stadio 3**: ~2 h 30 m con 32 worker (misurato; a 64 peggiora).
  **Re-pool Stadio 4**: ~75 min in 16 pezzi (`PEZZO`/`N_PEZZI`/`PEZZI_DIR`/
  `STAGE3_DIR`/`VERDETTI_PATH`) + `p4-fase-f5b-stage4-ricomponi-pezzi.R`; in un
  pezzo solo 32 h. Comandi e default: `docs/superpowers/specs/2026-08-16-HANDOUT-PROSSIMA-SESSIONE.md` §6.
  Verdetti da passare: gli **APPLICABILI** (11), non 24 — la guardia è fatale **a fine corsa**.
- **Controllo biologico** (minuti, bersagli fissati dalla letteratura prima di
  guardare): `POOL_DIR=<dir> Rscript analysis/audit/2026-08-02-fix/90-controllo-biologico-v15.R`;
  **annotazione a freddo** dai parquet: `…/80-annotazione-a-freddo-v15.R`.
- Quarto **c'è** (`/usr/local/bin/quarto`): se la dashboard non renderizza non è il binario.

---

## 4. Regole di metodo già pagate (una riga ciascuna, con il prezzo)

- **Nessun errore è accettabile, e le domande al PI devono essere semplici**: in S11 ho chiesto al PI quale precisione accettare per il rilevatore, e ho proposto un'opzione che i numeri decidevano già. Il PI: «La pipeline non deve sbagliare. Sono dati fissi, non ci sono dati nuovi.» Il database è fisso: ogni errore ha una causa che si corregge. Prima di portare una scelta al PI, verifica che ogni opzione possa cambiare l'esito, e scrivila senza sigle.
- **Il costo non vale contro il mandato**: in S8b ho consigliato di non fare il re-run, per il costo e su un campione. Il PI: «Si rifa tutto, siamo scienziati». Un limite si dichiara nei Methods quando il lavoro non si può fare, non quando costa ore.
- **validate-before-fullrun**: smoke + validazione scalata, poi STOP e sessione
  nuova per il run massivo. **Previsioni depositate PRIMA del run**, per iscritto.
- **Lo strumento deve vedere il dato intero**: tre strumenti ciechi in due giorni
  (alias corti, lettere greche cancellate, etichette troncate). Prima di
  giudicare, misura «quante stringhe toccano il limite».
- **Misura l'oggetto giusto**: il censito ≠ il poolato (47 accusati su 85 non
  erano nel deliverable); `k_effective` è **per-gene**, non del cluster; i pesi
  si calcolano sugli studi dopo il collasso dei bracci, non sui bracci; il
  dispatch va **misurato**, non simulato a mano (il k_eff del 13/08).
- **Scalari-come-array**: nei JSON `value_hours` è un array di un elemento;
  `is.numeric(list(0))` è FALSE. `\b` non vede il confine dopo `_` né dopo una
  cifra. I regex con `ignore.case=TRUE` annullano i vincoli `sh[A-Z]`.
- **No whack-a-mole**: dopo 2+ crash dello stesso job, STOP; isola ogni causa con
  una riproduzione minima, poi ri-lancia una volta.
- **Audit-before-patch**: con N≥2 bug dallo stesso audit, cerca il pattern nella
  decision table prima di patchare uno per uno.
- **Bump `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`** (`R/stage3-name-recovery-lookup.R`)
  a ogni cambio di `recover_identity`: senza bump il re-cluster riusa il lookup
  stale (8 h buttate, output identico al precedente). Verifica: build ~1 min, file
  cache nuovo. I percorsi di input del re-cluster vanno passati, non scritti nel codice.
- **Le variabili d'ambiente vanno verificate sul processo**, non nello script
  (`tr '\0' '\n' < /proc/<pid>/environ | grep VLLM`): una flag scritta e non
  passata è come il collasso delle corsie che non si accendeva.
- **Congela l'ambiente, non solo il prompt**: il primo retest di S3 aveva prompt
  byte-identici e 11 agenti su 60 hanno letto file scritti *dopo* il run originale
  (stringhe grezze, verdetti). Gli agenti hanno strumenti: materiale in cartella
  congelata fuori dal repo, e conta le fonti sui transcript **dopo** (`25-cosa-hanno-letto.py`).
- **Una lista scritta a mano non è una regola**: scarta per costruzione, non per
  elenco di chiavi; i verdetti umani si marcano, non si sovrascrivono
  (`canonical_name` non è mai sovrascritto).
- **Domanda ≠ critica**: «perché X?» chiede il razionale, non un cambio. Decisioni
  non banali: spiega, elenca TUTTE le opzioni coi trade-off, dichiara la
  preferenza, aspetta. Paper-grade: nessuna fretta, nessun «v1 accettabile».
- **Nessun Claude nella pipeline né nella validazione pubblicata** (evaluator =
  Mistral self-hosted); pipeline e gate **deterministici**; i subagent Claude
  sono solo audit interno.

---

## 5. Convenzioni

**Tracciabilità — ogni decisione documentata prima del codice che la riflette.**
ADR → `docs/decisions/NNNN-<slug>.md` (template `template.md`) · spec →
`docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` · plan →
`docs/superpowers/plans/…-plan.md` + companion HUMANE · finding →
`docs/findings/YYYY-MM-DD-<topic>.md` · evidenza → `analysis/audit/<data>-<topic>/`
· ledger → `.superpowers/sdd/progress.md`.

**Git.** Branch per fase (`p<N>-<slug>`); merge **fast-forward only** su master
con tag `p<N>-<slug>-complete`. **MAI `git push`** — lo fa l'utente. **MAI
`--no-verify` / `--no-gpg-sign`.** Commit atomici, messaggi in italiano. Prima
di ogni commit: pulire `renv/settings.json` (untracked) e ripristinare
`analysis/_targets/.gitignore` + `analysis/_targets/meta/meta` — **mai** durante
un `tar_make` in corso.

**Codice.** Italiano in commenti, docstring, errori e commit; ASCII per gli
accenti nei `.Rd`. Interne `@keywords internal`, `@export` solo i veri entry
point. **TDD bite-sized** (test → fail → impl → pass → commit). Rigenerare
`NAMESPACE`/`man` dopo ogni cambio (è rimasto indietro due volte). «Codice robusto,
non bello»: errori diagnostici, warning su ogni drop silenzioso, tracce in
`run_metadata`. **Mai tagli silenziosi** nelle figure: ogni filtro in caption.

---

## 6. Configurazione LLM di produzione (invariata da α, ADR-0008/0010/0011/0013)

Container `vllm/vllm-openai:v0.20.2-cu129-ubuntu2404` · modello
`mistralai/Mistral-Small-3.2-24B-Instruct-2506` FP16 su DGX H100, costo $0 ·
`temperature=0.0`, `repetition_penalty=1.1` · Stadio 2 `chunk_size=50`,
`max_num_seqs=6`, `microbatch=50`, tier max_tokens S/M/L/XL → 4K/8K/16K/32K ·
structured outputs · **`VLLM_BATCH_INVARIANT=1`** (rende riproducibile il run
nuovo, **non** lo fa coincidere col vecchio: senza flag due run identici davano lo
stesso record nel 40% dei casi). Rescue a cascata: `rep_pen` 1.2→1.3→1.4,
cs50→cs25, `max_tokens` 32768 (`docs/findings/2026-05-17-p4-beta-rescue-strategies.md`,
`-2026-06-11-f4-stage2-v3-rescue-and-generalization.md`). Config identica su
tutti gli stadi, anche a costo di efficienza.

---

## 7. DGX UniPD (P4 cluster)

- **Usa solo `poddgx02`. Non usare `poddgx01`: lo ha vietato il PI.** Non usare `nodelist = NULL`, perché lo scheduler può scegliere `poddgx01`. Il 2026-11-04 la sessione S8b ha lanciato 4 job su `poddgx01` senza cercare il divieto, e il nodo è caduto con 2 di quei job in corsa (causa non nota). I testi `R/dgx-config.R` e `analysis/p5-name-cleanup-run.R` suggeriscono ancora gli altri nodi: non seguirli. «Tutto il pod» (PI, 2026-11-05) vuol dire le 8 GPU di `poddgx02`, due job da 4 GPU: `poddgx05` sta su `shared-dgx`, con altri utenti, e serve una risposta esplicita del PI.
- Path **`/home/u0044/`**, NON `/mnt/home/u0044/` (i compute node non lo montano;
  sintomo: `ExitCode 0:53` in 2 s senza log).
- **Prima di sottomettere**: `sinfo` = `idle` non basta, verifica il mount con un
  `srun` breve (`/home` non montato → `0:53` e zero log; diagnostica in
  `docs/STORIA.md` Parte IV).
- Dati pesanti su **`/mnt/projects/dctv/dgx/u0044/`** (NFS di gruppo, no cap),
  non in `/home` (quota 500 G). TODO: migrare il workspace `simulomicsr-dgx`.
- ssh non-interattivo non sourca `/etc/profile.d` → `R/dgx-utils.R::.dgx_ssh()`
  wrappa con `bash -lc`. `singularity exec --nv` diretto, **no `srun singularity`**.
- `dgx_p4_submit(time=)`: default 72 h, rispetta il plan; su TIMEOUT resume
  (collect parziale + split residuo), non alert+stop. Partition `dgx12cluster`
  `infinite`; 2 TB RAM / 100 core. Vignette: `vignettes/p4-dgx-setup.Rmd`.

---

## 8. Trappole tecniche ricorrenti

- **renv 0.16.0 (lockfile) vs 1.1.4 (installato)**: il libpath del progetto è
  quello giusto; `--vanilla` lo bypassa ed è il motivo per cui mancano i pacchetti.
- `tar_make`: `callr_function = NULL` se i target chiamano OpenAI (callr non
  eredita la API key); `format = "rds"`; `sample_facts_validator` storizza un
  PATH allo schema (V8 non serializzabile), `compile_schema()` inline.
- **Non re-introdurre `temperature = 0` di default** in `R/llm-client-openai.R`
  (i reasoning model rispondono 400); esplicito dal chiamante. Hang HTTP iniziale
  dopo un glitch di rete: kill + retry.
- `write_parquet` perde gli attributi: i registri vanno in `qc_report`, non come
  `attr()`. La cache delle conte scrive su temporaneo + rename. `h5_metadata`
  senza i cinque campi delle corsie è **fatale** (prima: warning sepolto).
- **La cache delle conte non conserva l'ordine dei campioni** (chiave ordinata) e `.run_per_study_de_all()` assegna
  i ruoli per posizione: se la stessa matrice è stata chiesta con un'altra divisione, i ruoli cadono sui campioni
  sbagliati. **Prima di ogni re-pool** va corretto (S13). Misurato: 3 bracci su 1.903 nel deliverable.
- **`non_processable.rds` non conta tutti gli esclusi dal gate**: `k_eff_min` taglia anche il `k` censito in
  `.identify_layer_a_clusters()`. A k_min=2 i candidati sono 700, non 316. Il registro ne vede 88 su 282.
- **Il deliverable conta studi GEO, non dati distinti**: due numeri GEO possono avere le stesse conte (a meno del
  riallineamento). `k_eff` e `quota_top1` ne risentono (finding S5 §6). Non usare l'impronta esatta: serve la distanza.
- **`data.table`: dentro `dt[...]` un nome di colonna vince sulla variabile esterna**, anche dentro una funzione anonima: `g[cluster_id == cluster_id[i]]` confronta `g` con se stessa. Ha dato 32 su 32 e 3 su 16 falsi in S7. Salva il valore in una variabile con un altro nome. Lo stesso vale per i parametri degli aiutanti (`k`).
- **I testi GEO nell'H5 sono in parte codificati due o tre volte** («Î²» per «β», «Â°C» per «°C»): li hanno letti
  anche gli Stadi 1 e 2. Riparazione: `.s2b_norm_testo()` (`R/stage2b-input.R`). **`rhdf5::h5read(..., index=)`
  sulle stringhe di `meta/samples` va in segfault**: leggi il campo intero (13 s per 13 campi).
- ARCHS4 v2.5: 4.638/67.186 simboli HGNC duplicati → asse dei geni `gene_id`
  Ensembl (`gene_symbol` è etichetta); tabelle per simbolo deduplicate
  (`.rank_and_dedup_genes()`); merge fra gruppi su `gene_id`.

---

## 9. Dove stanno i dati che il repo NON contiene

| asset | dove | come si ottiene |
|---|---|---|
| Deliverable Stadio 4 corrente (194) e riferimento (211) | §1 | re-pool (§3); copia verificata in `/mnt/micron/simulomicsr-salvataggio/` (S2) |
| Stadio 3 A3 / riferimento | `analysis/p4-output/20260818T110906Z-…` / `20260815T231154Z-…` (gitignored) | re-cluster (§3) |
| Master Stadio 1 v2 (508.037) / Stadio 2 v3 (24.394 studi) | `analysis/p4-output/p4-fase-f2-stage1-master-predictions-rescued.jsonl`, `p4-fase-f4-stage2-master-v3.jsonl`; versioni A3 innestate `analysis/p4-output/A3-stage{1,2}-master-innestato.jsonl` (script in `analysis/audit/2026-08-16-A3/`) | run DGX (§6, §7) |
| Master S14, da zero e ripetibili: Stadio 1 (508.037) / Stadio 2 (24.393 studi) | `analysis/p4-output/S14-stage1-master.jsonl`, `S14-stage2-master.jsonl` (SHA-256 in `analysis/audit/2026-11-05-S14-re-run-modello/90-master-sha256.txt`); copia in `/mnt/micron/simulomicsr-salvataggio/S14-master-2026-11-07/` | `analysis/audit/2026-11-05-S14-re-run-modello/50-catena.R` |
| Input Stadio 1 v2 | `analysis/input/archs4-human-stage1-input-v2.jsonl` | `analysis/p4-fase-f-etl-build.R` |
| ARCHS4 H5 human v2.5 (47,86 GB) | `analysis/input/human_gene_v2.5.h5` | `wget -c https://mssm-data.s3.amazonaws.com/human_gene_v2.5.h5`; MD5 in `analysis/p4-output/p4-beta-archs4-source.json` |
| `lib_size` precalcolato | `analysis/audit/A3-libsize-scprob-bacino.tsv` | riusabile senza ri-scansionare l'H5 |
| Dizionari ontologici | `~/.cache/R/simulomicsr/` (ChEBI, HGNC, MeSH, ChEMBL `cache/chembl/chembl-lookup.rds`, taxonomy, ImmPort, UniProt, GO) | `analysis/p5-audit-chembl-build-dict.R` e script di build; HGNC da genenames.org |
| Cache conte Stadio 4 · recupero-nome · Entrez | `stage4-counts/` (chiave method-independent, riusabile fra re-pool) · lookup **v7** (`.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`, §4) · `tools::R_user_dir("simulomicsr","cache")/geo-series-resolver-cache.rds` (~5-6 h con `NCBI_API_KEY`) | auto |
| `OPENAI_API_KEY` · bundle DGX | `.Renviron.local` (gitignored; oggi risponde 401 → smoke E2E solo con `SIMULOMICSR_LLM_SMOKE=1`) · `analysis/p4-bundles/` | utente · `dgx_p4_build_bundle()` |

**Dal 2026-10-27 i dati stanno fisicamente su `/mnt/micron/simulomicsr-dati/`**:
`analysis/input`, `analysis/p4-bundles`, le 416 voci di `analysis/p4-output` e
`~/.cache/R/simulomicsr` sono link (i 17 file tracciati di `p4-output` restano veri). I
percorsi di sempre funzionano; i run **nuovi** in `analysis/p4-output/` cadono ancora
sulla radice. Mai cancellare lì: non è una copia. `analysis/audit/2026-10-27-dati-su-micron/`.

---

## 10. Gold standard

- `data-raw/relevant_sample_classified.xlsx` (committato, ~10 MB): 130.784 righe,
  `trtctr_EP` = gold manuale («qualunque intervento esplicito», diverge da
  `design_role`).
- Gold design-aware: `inst/extdata/p35c-minigold-reviewed-v5.csv` (100 campioni);
  gold LLM-assisted 756 campioni / 72 studi (accuratezza binaria 94,1–96,0%).
- Bersagli biologici fissati dalla letteratura per il controllo di §3 (DHT vs
  enzalutamide di segno opposto, TGF-β1, IFN-γ, LPS, SARS-CoV-2).

---

## 11. Limiti misurati, da scrivere nei Methods (S17)

Puntatori, non numeri nuovi: **L7** controlli prestati bocciati, trattati-solo
irrecuperabili (`docs/findings/2026-07-09-stage4-augmentation-passo3-measurement.md`);
**dominanza** (`k_kish` nel deliverable); **bias concorde** invisibile a ogni
leave-one-out; **16,5%** di verdetti che l'etichetta non chiude (32/194, insieme
diverso dalle 16 incerte); **1.993 campioni** persi dallo Stadio 2 (potenza, non
errori); il gate seleziona per controllo interno e **può concentrare l'errore**;
l'FDR premia i consistenti, non i grandi; la correlazione da controllo condiviso
non è modellata nel deliverable (misurata in S4, si corregge in S13), e il batch fra bracci con campioni diversi resta non modellato comunque; il verdetto sulle etichette **non vede i bracci invertiti**
(`GSE144269`, finding S3 §5); sotto i dieci studi l'I² è poco leggibile e la significatività dipende dal test z; il segno concorde non è una prova, e gli studi doppi non si vedono dalle etichette (finding S5). La validazione esterna riconosce soprattutto i composti forti e molto studiati, e contro Tahoe il valore è molto più basso (finding S7). Il paper è per bioinformatici: niente frizioni
d'infrastruttura salvo impatto biologico diretto.

---

## 12. Riferimenti

- **Storia e ritrattazioni**: `docs/STORIA.md` · **RED ALERT**: `docs/RED_ALERT.md`
  (§«Come Claude si deve comportare con me in questo audit»).
- **Handout corrente**: `docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md` (ordine delle sessioni); quello del 2026-08-21 per le sessioni chiuse e i prompt di S12b-S12d, S16, S17;
  comandi dei run: `-2026-08-16-HANDOUT-PROSSIMA-SESSIONE.md` §6-§8.
- **Findings recenti**: `2026-11-07-S12-stadio2b-disegno` · `2026-11-07-valutazione-autonoma-del-progetto` · `2026-11-07-S11-lettura-falsi-allarmi` · `2026-11-07-S10b-rilevatore-metadati` · `2026-11-07-S10-rilevatore` · `2026-11-07-S9-greche-e-corsie` · `2026-11-07-S14-due-passi-col-modello` · `2026-11-05-S8b-prova-re-run` · `2026-11-04-S8-re-run-decisione` · `2026-11-04-S7-validazione-esecuzione` · `2026-11-04-S6-validazione-disegno` · `2026-11-03-S5-gate-e-insiemi` · `2026-11-02-S4-controllo-condiviso` · `2026-11-02-inversioni-bracci-194` · `2026-08-21-S3-il-metro-concorda` · `2026-08-21-S2-deliverable-in-salvo` · `2026-08-20-rilettura-194-correttezza` · `2026-08-19-a3-movimento-stadio3`
  · `2026-08-16-batch-invarianza-a-shard-diverso` · `2026-08-13-tre-cambi-implementati`
  · `2026-08-13-passo2-il-nome-sbagliato-non-costa` · `2026-08-12-corsie-non-repliche`
  · `2026-08-10-sensitivity-confronti-spuri` · `2026-08-05-confronti-imperfetti`
  · `2026-07-23-stage3-cluster-coherence` (tutti in `docs/findings/`).
- **ADR chiave** (`docs/decisions/`): 0006 positioning · 0008 sampling · 0016
  dream/gene-symbol · 0017 Layer B · 0019 metadati ARCHS4 v2 · 0020 Stadio 2 per
  condizioni · 0021 metrica di consistenza · 0022 ramo `rem_group` · 0023/0024
  overlay e fallback nomi · 0025 record di gruppo dal contrasto · **0028** Stadio 2b, il modello legge e la regola decide · **0026** ramo
  mega fuori dal deliverable — ⚠️ il file sta solo sul branch
  `mega-recovery-2026-07-27` (worktree `/home/user/simulomicsr-mega`), non in
  questo branch: da annotare · 0027 selezione dei case study.
- Valutazione modelli: `docs/model-evaluation-history.md`; report P3.5:
  `analysis/eval/p35a-benchmark.html`. **Decisioni rinviate** (rename ADR-0003,
  `ellmer`, vocabolari extra, gold scalato, MetaHQ, cache cross-modello, server
  ADR-0005) e la vecchia **Roadmap**: `docs/STORIA.md` Parte III, verbatim.
