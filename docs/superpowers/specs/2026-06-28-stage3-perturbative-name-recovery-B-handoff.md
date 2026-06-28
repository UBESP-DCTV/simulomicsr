# Handoff — B: recupero nomi farmaci/composti con DB esterno (Stadio 3 v5)

**Data:** 2026-06-28
**Per:** prossima sessione (esecuzione di "Opzione B")
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato, no push)

> Scritto in prosa semplice di proposito. Leggere tutto prima di toccare codice.

---

## In una frase

I cluster di **malattia** sono a posto (minestrone 64% → 8%). Restano sporchi i
cluster di **farmaci, citochine e patogeni** (mescolano composti diversi). Il
motivo, misurato, è che a quei composti **non sappiamo dare un nome** perché non
stanno nei dizionari che usiamo (ChEBI). B = **aggiungere un dizionario esterno
di farmaci** (oltre a MeSH/ChEBI) per nominarli, esattamente come MeSH ha
risolto le malattie. Poi ri-raggruppare (Stadio 3 v5) e ri-poolare (Stadio 4 v5).

## ⭐ Regola d'oro: riusa la STESSA struttura del rework malattie (non reinventare)

B **non è un nuovo progetto**: è lo *stesso identico schema* già usato e validato per
le malattie con MeSH — **cambia solo il database** (un DB di farmaci al posto di MeSH).
Non ridisegnare l'architettura, non riscrivere da zero: **clona il pattern**.

Mappatura 1:1 di cosa è stato fatto per le malattie → cosa fare per i farmaci:

| Rework MALATTIE (fatto, MeSH) | Rework FARMACI (da fare, DB esterno) |
|---|---|
| dizionario MeSH caricato in `.load_ontology_dicts` | carica il nuovo DB farmaci nello **stesso** loader |
| accessor `.mesh_lookup_term` (nome→id) | nuovo accessor analogo (nome farmaco→id), **stessa firma/stile** |
| ramo malattia in `recover_identity` (`R/stage3-name-recovery.R`) | estendi il **ramo composto** nello stesso file, stessa logica |
| `build_name_recovery_lookup` (GSM→identità) | invariato: usa già il ramo composto, eredita il nuovo DB |
| gate di precisione (match controllato, no fuzzy azzardato) | **identico** principio (ricorda C1) |
| re-cluster `analysis/p4-fase-f6-stage3-reclustering.R` → v4 | stesso script → **v5** |
| re-pool `analysis/p4-fase-f5-stage4-layer-a-rebuild-v4.R` | copia **`-v5`**, cambia solo `stage3_dir` |
| gate omogeneità `analysis/audit/stage3-homogeneity-check.R` | **identico**, su dir v5 |
| spec+plan+TDD task-by-task | **riusa i doc del rework malattie come template** (vedi Riferimenti) |

In pratica: spec e plan della prossima sessione si scrivono **copiando** quelli di
`2026-06-25-stage3-name-recovery-reclustering-*` e sostituendo "MeSH/malattia" con
"DB-farmaci/composto". L'unico pezzo davvero nuovo da progettare è **quale DB** e
**come agganciarne i nomi** (vedi Decisioni aperte).

## Dove siamo (stato di partenza)

- La pipeline è **completa end-to-end su v4**: Stadio 1 → 2 → 3 (v4) → 4 (v4).
- Output Stadio 4 v4: `analysis/p4-output/20260628T043439Z-stage4-v4-4f7ea215/`
  (+ backup `/mnt/wwn-0x5000039d58caca35/simulomicsr_stage4_v4_backup/`).
  532 cluster, 986.733 geni significativi (FDR<0,05).
- Gate omogeneità v4 (Task 16): **disease 7,7%** (ottimo) · small_molecule 49% ·
  cytokine 63,6% · pathogen 38,2%. Questi tre ultimi sono il bersaglio di B.

## Il problema, con l'evidenza (così non si ri-sbaglia strada)

Misura a freddo già fatta (`scratchpad/measure-strnorm-v4.R`, risultato nel ledger):
- **Normalizzare la grafia dei nomi NON serve** (−0,1pp). Non rifarla. I minestroni
  perturbativi sono **mescolanze vere** di composti diversi, non lo stesso
  composto scritto in due modi.
- La causa è la **copertura**: tanti farmaci/stimoli (nomi commerciali, codici,
  sigle) non sono in ChEBI → restano `UNK` o `STR:<slug>` → il cluster collassa
  sul solo tessuto e ci finiscono composti diversi insieme.
- Componente aggiuntiva: **tipo sbagliato dall'LLM** — molti LPS/TNF/IFN/IL
  etichettati "small_molecule" sono in realtà patogeni/citochine (misurato:
  91/1075 cluster small_molecule contengono questi token).

## Principio guida (deciso con l'utente)

**Precisione prima della copertura.** In una meta-analisi, unire due farmaci
diversi è un errore peggiore che lasciare un campione come "ignoto, non
raggruppato". Quindi ogni nuovo aggancio di nome deve avere un **gate di
precisione** (niente match azzardati: ricordare il bug C1, dove una regex troppo
larga flippava composti reali). Gli ignoti restano U1 (non poolati), non forzati.

## Cosa fare in B (sequenza)

1. **Brainstorming (obbligatorio prima del codice)** — è lavoro creativo. Decidere:
   - **quale DB esterno** (vedi decisioni aperte sotto);
   - come integrarlo nel recupero senza perdere precisione.
   Poi spec → plan → TDD (come per il rework malattie).
2. **Integrare il DB** nel modulo di recupero-nome (codice + TDD):
   - `R/stage3-name-recovery.R` (la funzione `recover_identity` + i rami composto);
   - `.load_ontology_dicts` (aggiungere la nuova sorgente) + un nuovo accessor
     nome→id sullo stile di `.chebi_lookup_alias`;
   - eventuale correzione del **tipo** (LPS/TNF/IL → patogeno/citochina), tipo un
     "K3" deterministico con gli stessi accorgimenti del K2 (case-sensitive,
     confini di parola, canary).
3. **Ri-clusterizzare Stadio 3 → v5**: riusare lo script già pronto
   `analysis/p4-fase-f6-stage3-reclustering.R` (oggi produce v4) puntandolo al
   nuovo lookup. ~ore.
4. **Ri-poolare Stadio 4 → v5**: riusare `analysis/p4-fase-f5-stage4-layer-a-rebuild-v4.R`
   (farne una copia `-v5` col nuovo `stage3_dir`). ~11h. **Scrivere l'output sul
   disco grande** (NVMe ha poco margine).
5. **Ri-gate omogeneità** (`analysis/audit/stage3-homogeneity-check.R` su dir v5):
   verificare che small_molecule/cytokine/pathogen scendano nettamente.

## Decisioni aperte (da affrontare nel brainstorming)

1. **Quale DB esterno?** Tradeoff onesti (da verificare copertura/licenza/formato):
   - **ChEMBL** — grande, gratuito, sinonimi, scaricabile; ID propri (CHEMBL…).
     Buona copertura composti da ricerca.
   - **DrugBank** — ottimi sinonimi, ma **licenza** (gratis accademico con
     registrazione, redistribuzione limitata).
   - **PubChem** — enorme, gratuito, sinonimi via CID; serve sottoinsiemizzare.
   - **RxNorm** — nomi clinici (US), più da prescrizione che da ricerca.
   Punto di partenza ragionevole: ChEMBL (+ eventuale PubChem per i sinonimi),
   ma da confermare con un **sondaggio fattuale di copertura** sui termini
   `STR:`/`UNK` perturbativi che abbiamo già (campionarli e vedere quanti il DB
   nominerebbe).
2. **Come canonicalizzare l'ID** (tenere l'ID del nuovo DB? mapparlo a ChEBI dove
   esiste un cross-reference, per non frammentare?).
3. **Gate di precisione**: match esatto/alias controllato vs fuzzy; soglia.
4. **Fix del tipo** (K3): incluso ora o separato?
5. **Scope**: solo small_molecule, o anche cytokine/pathogen (che hanno copertura
   ontologica debole — forse serve una fonte diversa o l'LLM-fallback DECISIONE C
   solo per quelli)?

## File e funzioni chiave

- `R/stage3-name-recovery.R` — `recover_identity`, rami malattia/composto/genetico.
- `R/stage3-name-recovery-lookup.R` — `build_name_recovery_lookup` (GSM→identità da H5).
- `.load_ontology_dicts` + accessor `.chebi_lookup_alias` / `.mesh_lookup_term` / `.hgnc_lookup_symbol`.
- `analysis/p4-fase-f6-stage3-reclustering.R` — re-cluster (→ farne il v5).
- `analysis/p4-fase-f5-stage4-layer-a-rebuild-v4.R` — re-pool (→ copia v5).
- `analysis/audit/stage3-homogeneity-check.R` — gate omogeneità.
- Misura di riferimento: `scratchpad/measure-strnorm-v4.R`.

## Note operative critiche

- ⚠️ **Il fix df-residui + tryCatch dello Stadio 4 è NON committato** (working tree:
  `R/stage4-limma-de.R`, `R/stage4-orchestrator.R`, 3 test). **Va committato (o
  almeno preservato) PRIMA del re-pool v5**, altrimenti Stadio 4 v5 ri-crasha sullo
  stesso studio degenere. `man/*.Rd` da rigenerare al commit.
- **Disco**: NVMe `/` ha ~90G liberi; il disco grande `/mnt/wwn-0x5000039d58caca35`
  (4TB liberi) è dove mettere gli output pesanti. Niente sta più sull'NVMe per i 2026.*.
- **Osservazione infra non confermata**: durante la scrittura Stadio 4 il FS NVMe ha
  dato ENOENT transitori sotto I/O pesante (FS sano, dati integri). Se ricapita,
  verificare con I/O calmo prima di concludere. Eventuale `smartctl -a /dev/nvme0n1`
  lato utente.
- Run pesanti: lanciare **detached** (`setsid nohup`), monitorare con loop orario
  session-only; la fase per-studio dello Stadio 4 è **muta** ~30-90 min (non è un blocco).
- Master invariato, no push, no `--no-verify`.

## Riferimenti

- Ledger esecuzione: `.superpowers/sdd/progress.md` (storia Task 14/15/16 + misura + decisione B).
- Memoria: `[[project_stage3_minestrone_rework]]`.
- Spec/plan rework malattie (template da riusare per i farmaci):
  `docs/superpowers/{specs,plans}/2026-06-25-stage3-name-recovery-reclustering-*`.
