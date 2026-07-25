# HANDOUT — sessione MEGA (parallela): il ramo mega non ha mai passato il gate di coerenza

**Preparato:** 2026-07-27, dalla sessione "innesto dell'anchor dal contrasto"
**Dove si lavora:** `/home/user/simulomicsr-mega` — **worktree dedicato**, branch
`mega-recovery-2026-07-27` (creato da `review-scientific-consistency-2026-06-10` @ `828fcbe`).
Master invariato · nessun push.
**Stato:** 🔴 **Problema MISURATO, nessuna decisione presa, nessun codice scritto.**

---

## 0. REGOLE (non negoziabili, valgono anche qui)

1. Il gate è la **COERENZA**, mai il numero di meta-analisi.
2. Verifica su **TUTTI**, mai su un campione.
3. Zero slop: sigle, parole generiche, veicoli, induttori, classi-ombrello non sono entità.
4. Pipeline pubblicata **deterministica**: nessun LLM a runtime.
5. **Nessun run pesante senza GO esplicito dell'utente.**
6. Fail onesto coi numeri: se la copertura è il 49%, si scrive 49%.
7. **VIETATO** dichiarare "validato / risolto / finale / paper-grade" senza prova per-gruppo su TUTTI.
8. Se una misura contraddice una conclusione precedente, si ritratta subito e per iscritto.

## 1. Che cos'è una mega (meccanica, verificata nel codice)

Una **mega-analisi** non fa una sintesi degli effetti per studio come le `rem_group`: prende i
**campioni** di tanti studi e li mette in un unico modello misto `~ treatment + (1|study)` (dream).

- Il "trattamento" **non** viene dall'anchor: è l'etichetta `primary_role` che lo Stadio 2 ha dato a
  ogni gruppo di repliche (`treated` / `control`) — `.build_group_dispatch_from_stage3()`,
  `R/stage4-dispatch.R:169`.
- L'appartenenza al cluster richiede **anchor identico a L0/L1** (13 segmenti: dose, durata, linea
  cellulare, tessuto…) e `n_studies ≥ 5` — `.identify_layer_a_clusters()`, `R/stage4-qc.R:70`.
- L'assemblaggio dei campioni (con dedup GSM, conflitti di ruolo, dedup SAMN) è in
  `.build_mega_metadata_safe()`, `R/stage4-mega-safe.R:44`.

**Perché esiste** (`docs/findings/2026-05-19-stadio-4-5-scope-decision.md` + spec Stadio 4): lo
Stadio 3 produceva tre famiglie di cluster e le mega erano di gran lunga la più numerosa (4.163
`usable_mega_relaxed`, 312 strict). Senza il ramo mega, il 99% dell'output dello Stadio 3 restava
inutilizzato.

## 2. Che cosa c'è dentro, oggi (misurato su v10)

Delle **714** meta-analisi poolate in v10, **99 sono mega** (1.748.512 righe in
`cluster_pooled.parquet`).

| | |
|---|---:|
| con un ID ontologico | 60 |
| **senza nome (`agent_id_resolved = UNK`)** | **39** |
| `disease_vs_normal` | 37 |
| `none` | 28 |
| `environmental` | 15 |
| `pathogen_or_aggregate_exposure` | 10 |
| `vehicle_only` | 9 |
| k (studi): mediana / massimo | 8 / 39 (Breast Neoplasms `group_L1_863ad5e6`) |

## 3. IL PROBLEMA, MISURATO (censimento 2026-07-27)

Script: `analysis/audit/2026-07-27-contrast-builder/30-censimento-mega.R` · log `30.log` ·
tabella **`analysis/audit/2026-07-27-contrast-builder/censimento-mega.csv`** (una riga per mega).

Metodo: per ogni braccio **trattato** di ogni mega si ricostruisce il confronto dello Stadio 2 e si
calcola l'**entità del delta** con lo stesso motore del builder nuovo
(`.ca_member_contrast()`, `R/stage3-contrast-anchor.R`). Un cluster è coerente se tutti i suoi bracci
trattati misurano la **stessa** entità.

**COPERTURA DICHIARATA: 457 bracci trattati su 928 = 49%.** Per gli altri non esiste un confronto
nello Stadio 2 (stesso fenomeno del limite L7). Ogni numero va letto con questa copertura accanto.

| | |
|---|---:|
| mega poolate | 99 |
| con almeno un braccio ricostruito | 93 |
| **con almeno un'entità risolta (misurabili)** | **68** |
| **una sola entità del delta** (coerenti, per quanto misurabile) | **36** |
| **due o più entità del delta** (minestrone misurato) | **32** |
| nessuna entità risolta (non misurabili) | 31 |

Misura a copertura piena, descrittiva: **etichette di trattamento distinte per cluster — mediana 4,
massimo 63**.

**I peggiori:**

| cluster | k | kind | nome | entità distinte |
|---|---:|---|---|---:|
| `group_L0_f8e4f330`, `group_L1_70c503a4` | 11 | pathogen | Mycobacterium tuberculosis | **10** |
| `group_L0_687b3425`, `group_L1_29411be9` | 10 | disease_vs_normal | cancer | 7 |
| `group_L0_6c41952f` + altri 3 | 5-6 | environmental | acute myeloid leukemia | 7 |
| `group_L0_05dadd11` | 21 | none | — (senza nome) | 5+ |
| `group_L1_a7f52377` | 25 | none | — (senza nome) | 5+ |

**In una riga: dei mega che si riescono a misurare, il 47% è minestrone.** È lo stesso difetto delle
`rem_group` (157/184 = 85%, finding `2026-07-23-stage3-cluster-coherence.md`), in un altro ramo,
mai verificato prima.

**Perché era prevedibile:** per due gruppi (uno trattato e uno di controllo) che finiscono nello
**stesso** cluster L0/L1, gli anchor devono essere identici — cioè l'anchor **non distingue** il
braccio trattato dal controllo. Questo succede soprattutto quando l'anchor è vuoto (UNK / kind
`none`): 39 su 99. Il "contrasto" poolato diventa allora "quello che ogni studio ha chiamato
trattato contro quello che ha chiamato controllo", dentro un contesto simile.

## 4. IL LAVORO DI QUESTA SESSIONE

**Domanda da rispondere:** le mega si recuperano, e come?

Tre direzioni, da valutare **misurando**, non per principio:

- **(A) Ri-ancorare dal contrasto**, come si è fatto per le `rem_group`. Meccanismo già disponibile:
  una mega ha bracci trattati e controlli, quindi `.ca_member_contrast()` si applica tale e quale.
  Il cluster nasce dalla chiave di contrasto e il pooling resta il modello misto
  `~ treatment + (1|study)`. Nota di design non banale: così mega e `rem_group` consumerebbero gli
  **stessi** cluster con due stimatori diversi (modello congiunto vs sintesi per studio) — va deciso
  se ha senso, e con quale criterio si sceglie l'uno o l'altro.
- **(B) Tenere le mega solo dove il censimento le assolve** (le 36 con una sola entità), scartare le
  32 minestrone e dichiarare le 31 non misurabili come limite. Economico, ma lascia il ramo com'è.
- **(C) Togliere le mega dal deliverable.** Sono 99 su 714. Riduce il perimetro da difendere; è una
  scelta scientifica, non tecnica.

**Prima di scegliere, misurare:**

1. **Chiudere il buco di copertura.** Perché il 51% dei bracci trattati non ha un confronto? È lo
   stesso L7 (trattati senza controllo interno collegato) o c'è dell'altro? Se una parte è
   recuperabile, il censimento diventa più forte.
2. **Guardare i 31 non misurabili uno per uno.** Zero entità risolte non vuol dire incoerenti: vuol
   dire che non lo sappiamo.
3. **Verificare l'ipotesi dell'anchor vuoto**: i cluster con `agent = UNK` sono sistematicamente i
   più eterogenei? La tabella ha tutto per rispondere (`censimento-mega.csv` + `clusters.rds` v10).

## 5. ⚠️ AMBIENTE E COORDINAMENTO CON LA SESSIONE PRINCIPALE — LEGGERE

### L'ambiente è già pronto e verificato

Questa sessione gira in un **worktree separato**, `/home/user/simulomicsr-mega`, sul branch
`mega-recovery-2026-07-27`. Serviva una cartella a sé, non solo un branch: le due sessioni
lavorerebbero altrimenti sugli stessi file, e un cambio di branch cambierebbe i file sotto i piedi
all'altra mentre gira.

Tre cose sono già state sistemate e **verificate girando davvero il codice** (pacchetto caricato,
310.738 cluster letti, dizionari ontologici reali, `.ca_member_contrast()` che risolve
`CHEBI:68534`):

- I dati pesanti sono **gitignored**, quindi non esistono in un worktree nuovo: sono collegati con
  symlink a quelli del checkout principale — `analysis/input`, `analysis/cache`,
  `analysis/p4-output/20260720T180625Z-stage3-v10-364547a7`,
  `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl`.
- **renv indicizza la libreria sul PERCORSO del progetto**: da qui vorrebbe reinstallare tutto e si
  pianta (misurato: > 900 s senza output). Il `.Renviron` locale disattiva l'autoloader
  (`RENV_CONFIG_AUTOLOADER_ENABLED=FALSE`) e punta `R_LIBS_USER` alla libreria del checkout
  principale. **Non toccarlo.**
- `.Renviron` contiene anche le variabili `PROJ_*` richieste da `.Rprofile`, senza le quali R non
  parte.

Comandi R: `Rscript` **senza** `--vanilla` (con `--vanilla` non trova devtools).

### Coordinamento

La sessione principale sta innestando l'anchor dal contrasto per il ramo `rem_group` e, finito
quello, chiederà all'utente il **GO per il re-cluster (~8h) + re-pool (~50h)**.

- **Se le mega vanno ri-ancorate, quel cambio deve entrare nello STESSO re-cluster.** Altrimenti
  serve un secondo giro da 8 ore. Questo è il vincolo temporale che governa la sessione.
- I file `R/stage3-contrast-anchor.R`, `R/stage3-build.R`, `R/stage4-qc.R`, `R/stage4-dispatch.R` e i
  test `test-stage3-contrast-*.R`, `test-stage4-cgroup-branch.R` sono **lavoro in corso dell'altra
  sessione**: qui si **leggono e si riusano**, non si riscrivono. Il worktree ne ha una copia
  congelata a `828fcbe`; se servisse la versione aggiornata, allinearsi con
  `git merge review-scientific-consistency-2026-06-10` invece di riscrivere.
- Le due sessioni **non condividono l'indice git**: qui si committa liberamente sul proprio branch.
  La fusione dei due rami si fa alla fine, con l'utente.

## 6. TRAPPOLE GIÀ PAGATE (non ripeterle)

- **`_` è carattere di parola** per le espressioni regolari: `\bsirna\b` non vede `Control_siRNA_1`.
  Normalizzare i separatori PRIMA di ogni `\b`.
- **Non giudicare un nome risolto dalla sua lunghezza**: l'euristica "< 4 caratteri = generico"
  scarta TNF, IL6, RSV, CMV, HBV (565 membri persi, misurato il 2026-07-27).
- **Togliere le dosi non deve togliere i separatori**: `Bleomycin/Alpha-Lipoic Acid` senza `/` non è
  più una combinazione (253 membri, misurato lo stesso giorno).
- **`gsub("[^a-z ]")` prima di `tolower`** cancella le maiuscole.
- **`cli >= 3.4` interpreta `{.x}` come stile**, non come variabile: nei log usare `{(.x)}`.
- **Nella suite completa i dizionari si caricano come fixture**: i test end-to-end vengono saltati e
  possono nascondere un errore. Girare anche il singolo file.
- **Non bumpare `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`** quando cambia `recover_identity()`: il
  re-cluster riusa il lookup vecchio (già costato 8 ore). Oggi è a **v7**.
- **`run_in_background` uccide i run lunghi**: usare `setsid` e verificare SID==PID.
- **`Rscript --vanilla` non trova devtools** (renv): per gli script che caricano il pacchetto usare
  `Rscript` senza `--vanilla`.

## 7. ASSET

| cosa | dove |
|---|---|
| censimento mega (una riga per cluster) | `analysis/audit/2026-07-27-contrast-builder/censimento-mega.csv` |
| script del censimento + log | `analysis/audit/2026-07-27-contrast-builder/30-censimento-mega.R`, `30.log` |
| motore del delta (codice di pacchetto) | `R/stage3-contrast-anchor.R` (`.ca_member_contrast`) |
| regole del gate e della riga | `R/stage3-contrast-gate.R`, `R/stage3-row-pairing.R` |
| cluster Stadio 3 v10 | `analysis/p4-output/20260720T180625Z-stage3-v10-364547a7/` |
| pool Stadio 4 v10 | `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v10/20260722T210452Z-stage4-v10-a500d032/` |
| master Stadio 2 v3 | `analysis/p4-output/p4-fase-f4-stage2-master-v3.jsonl` |
| macchina mega | `R/stage4-dispatch.R:169`, `R/stage4-mega-safe.R:44`, `R/stage4-qc.R:70` |
| perché le mega esistono | `docs/findings/2026-05-19-stadio-4-5-scope-decision.md` |
| il difetto gemello sulle rem_group | `docs/findings/2026-07-23-stage3-cluster-coherence.md` |
| l'innesto in corso | `docs/decisions/0025-stage3-contrast-derived-group-records.md` |

## 8. PROMPT PER APRIRE LA SESSIONE

> RECUPERO DEL RAMO MEGA — sessione dedicata, in parallelo all'innesto dell'anchor dal contrasto.
>
> LAVORI IN `/home/user/simulomicsr-mega` (worktree dedicato, branch `mega-recovery-2026-07-27`).
> L'ambiente e' gia' pronto e verificato: dati collegati con symlink, `.Renviron` che aggira renv.
> Non toccare `.Renviron` e usa `Rscript` senza `--vanilla`.
>
> LEGGI PRIMA, INTERO: `docs/superpowers/specs/2026-07-27-mega-recovery-HANDOUT.md`, poi
> `docs/findings/2026-05-19-stadio-4-5-scope-decision.md` (perché le mega esistono) e
> `docs/decisions/0025-stage3-contrast-derived-group-records.md` (che cosa si sta facendo alle
> rem_group).
>
> CONTESTO SENZA SCONTI. Per mesi il progetto ha dichiarato "publication-grade" raggruppamenti che
> mettevano nella stessa meta-analisi studi che misurano cose diverse. Sulle `rem_group` è stato
> misurato e ammesso: 157 su 184. Il ramo **mega** — 99 meta-analisi del deliverable — non è mai
> stato verificato. Adesso lo è: dei 68 cluster misurabili, **32 hanno due o più entità del delta**,
> con casi come *M. tuberculosis* che ne mescola 10. Copertura della misura: 49% dei bracci trattati,
> e va ripetuta accanto a ogni numero.
>
> IL LAVORO: capire se e come le mega si recuperano. Prima misurare (perché il 51% dei bracci non ha
> un confronto; che cosa sono i 31 cluster non misurabili; se l'anchor vuoto predice l'eterogeneità),
> poi proporre le opzioni con i tradeoff onesti e la tua preferenza, e FERMARTI: la decisione è mia.
>
> VINCOLO DI TEMPO: se le mega vanno ri-ancorate, il cambio deve entrare nello **stesso** re-cluster
> dell'altra sessione (~8h), altrimenti servono due giri. Quindi il design va chiuso prima che io dia
> il GO là.
>
> NON TOCCARE i file della sessione principale (elencati al §5 dell'handout): leggili e riusali.
> Scrivi in `analysis/audit/2026-07-27-mega-recovery/` e in `docs/`.
>
> REGOLE: il gate è la coerenza, mai il numero. Verifica su TUTTI, mai a campione. Nessun LLM nella
> pipeline. Nessun run pesante senza il mio GO. Fail onesto coi numeri. Vietato scrivere
> "validato/risolto/finale" senza prova per-cluster su tutti. Prima di normalizzare testo ricorda che
> `_` conta come lettera per le espressioni regolari. Parlami come a un essere umano: breve, chiaro,
> senza gergo. Branch `mega-recovery-2026-07-27`, master invariato, no push.
