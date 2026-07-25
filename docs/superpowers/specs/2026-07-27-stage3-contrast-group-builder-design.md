# Spec di design — Il record di gruppo nasce dal CONTRASTO (innesto nel build Stadio 3)

**Data:** 2026-07-27 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Stato:** 🟡 **DESIGN APPROVATO DALL'UTENTE (2026-07-27), NON IMPLEMENTATO.** Nessun re-cluster,
nessun re-pool. I numeri citati vengono da misure, non da stime; quelli attesi dall'innesto sono
**pavimenti da riverificare**, non promesse.

**Predecessori:** spec `2026-07-24-stage3-contrast-anchor-design.md` (§6 = le decisioni dell'utente),
finding `2026-07-26-stage3-row-pairing-rules.md`, handout `2026-07-27-NEXT-SESSION-HANDOUT.md`.
**ADR proposto con questa spec:** **ADR-0025** — la selezione `rem_group` passa ai cluster derivati
dal contrasto (sostituisce la *selezione* di ADR-0022, ne conserva il *pooling*).

---

## 1. Il problema, in una riga

Le regole che producono raggruppamenti coerenti esistono, sono codice di pacchetto con 169 test e
sono state rimisurate col codice di produzione — **ma la pipeline non le chiama**. I 141 gruppi
coerenti vivono in una simulazione (`analysis/audit/2026-07-24-anchor-coherence-sim/`); il
deliverable sul disco è ancora quello vecchio, 184 `rem_group` di cui l'85% minestroni. Finché non si
tocca il build, quel lavoro vale zero per il paper.

**Criterio di accettazione = COERENZA** (ogni gruppo = una meta-analisi difendibile = stesso
contrasto), verificata **su TUTTI i gruppi**, mai a campione. Il numero di gruppi non è un criterio.
La consistenza (k, I², PI) è la forza da riportare accanto, non la barriera.

## 2. La causa radice, nel codice

`.build_group_records()` (`R/stage3-build.R:473`) costruisce **un record per replicate_group** e ne
prende l'anchor dal **primo campione** del gruppo (`.extract_anchor_segments`,
`R/stage3-anchor-levels.R:60`). Il controllo non entra mai nella chiave: resta libero per studio.
Due studi che misurano cose diverse — "SARS-CoV-2 vs mock" e "farmaco vs DMSO in cellule infette da
SARS-CoV-2" — finiscono sotto lo stesso anchor, perché l'anchor guarda la **perturbazione del
campione trattato**, non ciò che il **confronto isola**.

`.build_pair_records()` (`R/stage3-build.R:412`) invece ha già tutto: `treated_anchor_segments`,
`control_anchor_segments`, `control_type`, le liste di GSM dei due bracci. Il builder nuovo nasce
dallo stesso ciclo.

## 3. Il design — il record `cgroup`

### 3.1 Dove nasce

Un record **per ogni comparison** dello Stadio 2 (non per replicate_group). Stesso ciclo di
`.build_pair_records()`: per ogni studio, per ogni `comparison`, si risolvono il gruppo trattato
(`tg`) e il gruppo di controllo (`cg`) via `rg_lookup`.

Da `tg`/`cg` si prendono due cose che oggi il ramo group butta via:

- `label_human` (con `group_id` come ripiego) = l'etichetta leggibile del braccio;
- `factor_levels` = la firma `chiave=valore` del braccio.

Sono le stesse due fonti usate da `.reconstruct_cluster_contrasts()` (`R/stage3-coherence.R:35`) per
ricostruire i 38.440 contrasti su cui è stata misurata tutta la simulazione. Nel build non serve
ricostruire niente: i confronti ci sono già.

### 3.2 Il delta

`delta` = le chiavi dei `factor_levels` il cui valore cambia fra trattato e controllo (normalizzati:
minuscolo, via dosi/tempi/numeri), **meno** le chiavi identitarie (donatore, paziente, età, sesso,
replicato, lotto, linea cellulare, tessuto, passaggio…).

Ogni chiave è classificata (`genetic` / `drug` / `infection` / `disease` / `environment` / `time` /
`other` / `nuisance`) dal **nome della chiave**. La classe dominante segue la priorità
`genetic > drug > infection > disease > environment > time > other`.

Se il delta è vuoto o solo identitario → nessun record (§5).

### 3.3 L'entità — quattro rami, in ordine

1. **On-contrast** — se il valore trattato del delta contiene **tutti** i token distintivi del
   `canonical_name` che il resolver ha già assegnato all'anchor **di quel record** (campo
   `tracking_meta$canonical_name` di `treated_anchor_segments`), l'entità è l'`agent_id_resolved`
   di quell'anchor.
   *Perché:* quando il delta nomina la stessa entità che l'anchor ha già risolto bene, si tiene il
   nome buono invece di ri-risolvere una stringa più povera. È l'analogo **per-record** della regola
   che nella simulazione usava il nome del **cluster** — non disponibile nel build, dove i cluster
   non esistono ancora (decisione utente 2026-07-27).
2. **Delta risolto** — altrimenti si risolve il delta con i **candidati blindati**: via dosi e unità
   di misura, via i token che non sono entità, guardia sulle sigle (un candidato ≤4 caratteri si
   accetta solo se coincide col nome risolto — è la guardia che ha impedito `ml`→THPO), e si prova
   il resolver della classe dominante (ChEBI/ChEMBL → HGNC per `drug`, NCBITaxon per `infection`,
   MeSH per `disease`, HGNC per `genetic`). Il **treated_label intero** è ammesso come candidato
   solo per `infection`/`disease`/`genetic`, mai per `drug`: è la fonte documentata di entità spurie
   (`CD8 T cells` → CD8A).
3. **Ripiego `STR:`** — il valore del delta ripulito, quando nessun resolver risponde. Passa solo se
   non è generico (`.cg_is_generic_token`).
4. **Combinazione** — se nel braccio trattato ci sono **≥2 agenti che risolvono a un ID canonico e
   sono assenti dal controllo**, l'entità è la combinazione intera, `COMBO:a+b` (decisione utente:
   la combo è un'entità a sé). Gli agenti presenti su **entrambi** i bracci non contano: sono tenuti
   costanti, non fanno parte del delta.

### 3.4 Il verso

`.cg_direction()` sul valore trattato del delta → `gain` / `loss` / `block`. Il verso entra nella
chiave (decisione utente: agonista e antagonista non si fondono). **Verso ambiguo → il membro si
scarta.**

### 3.5 Il tipo di controllo

`.normalize_control_type()` (`R/stage3-coherence.R:10`) applicato al **lato-controllo del delta**
(non all'etichetta intera), più tre qualificatori già in `R/stage3-contrast-gate.R`:

- **materiale** del braccio (`_liquid` se plasma/siero/vescicole): tessuto-vs-plasma non è lo stesso
  contrasto;
- **baseline propria** (`_ownbase`): il longitudinale pre-vs-post non è il trasversale;
- **contesto d'infezione** (`_clin`): infezione clinica di un paziente e infezione sperimentale di
  una coltura non sono lo stesso contrasto. Si applica a ogni contrasto su un patogeno, non solo
  quando la chiave si chiama `infection`.

### 3.6 Le regole — riuso, non riscrittura

Nell'ordine in cui girano oggi in `109-fase1-v11-gate.R`, tutte già testate:

| regola | funzione | esito |
|---|---|---|
| contrasto rotto (anatomia/materiale/tipo cellulare disgiunti) | `.cg_broken_contrast` | scarta il membro |
| controllo che non è un controllo (`total RNA`, `input`) | `.cg_is_noncontrol` | scarta il membro |
| resistenza su un braccio solo | `.cg_resistance_mismatch` | scarta il membro |
| delta che muove ≥2 classi perturbative | `.cg_is_multiclass` | scarta il membro |
| etichette dei due bracci identiche | confronto diretto | scarta il membro |
| trattato che è in realtà un controllo (WT, "no mutation") | `.cg_is_control_like_treated` | scarta il membro |
| verso ambiguo | `.cg_direction` | scarta il membro |
| token generico / nome-ombrello / induttore / ID in blacklist / nome generico | `.cg_is_generic_token`, `.cg_is_umbrella_name`, `.cg_is_inducer` | scarta il membro |
| entità tenuta costante fra i due bracci | confronto a parola intera sul controllo | scarta il membro |
| riga mal appaiata (tempo, soggetto/linea, genetica asimmetrica, combinazione non vista) | `.rp_row_defect` | scarta il membro |

Ogni scarto finisce in `non_clusterable` con la sua ragione: la perdita è auditabile, non silenziosa.

### 3.7 La chiave e lo schema del record

```
anchor_key = <entità> || <verso> || <tipo-di-controllo+materiale+baseline+contesto>
```

Nessun tessuto, nessuna linea cellulare nella chiave. **È una scelta scientifica esplicita:** due
studi che misurano lo stesso farmaco in tessuti diversi finiscono nella stessa meta-analisi. È la
chiave con cui sono stati letti e giudicati i 141 gruppi; l'eterogeneità di tessuto si riporta come
forza (I², PI), non come barriera. La regola `contrasto rotto` continua a proteggere il singolo
membro (i due bracci **dello stesso confronto** devono condividere l'anatomia).

Campi del record: `record_id = <series>__<comparison_id>` (stessa convenzione del ramo pair),
`mode = "cgroup"`, `series_id`, `comparison_id`, `treated_anchor_segments` (per le colonne di
tracciatura e per il nome leggibile del cluster), `treated_sample_ids`, `control_sample_ids`,
`n_treated_group`, `n_control_group`, `control_type`, `hard_filters`, `stage1_facts`, più i campi di
contrasto per l'audit: `contrast_entity`, `contrast_direction`, `contrast_control_key`,
`contrast_class`, `contrast_entity_source` (`onto` / `anchor` / `STR` / `COMBO`).

## 4. L'aggregazione

- **Un solo livello.** La chiave del contrasto è già l'identità completa: non c'è una gerarchia
  L0..L4 da percorrere. I cluster `cgroup` sono marcati `level = 5L` — un valore nuovo, non un L4
  travestito. Effetto collaterale voluto: `usable_mega_strict` richiede `level ∈ {0,1}`, quindi i
  `cgroup` **non possono finire nel ramo mega per costruzione**.
- **Nessuna partizione per hard filter.** `subcellular` e `context_kind` non entrano nella chiave
  (la simulazione non li usava; aggiungerli frammenterebbe rispetto ai numeri misurati). Restano nel
  record per l'audit.
- **Dedup una meta-analisi per (entità, verso), al k massimo** — stessa policy ADR-0022, oggi in
  `.dedup_rem_group_by_entity()` (`R/stage4-qc.R:27`), estesa a tenere conto del verso.
- **Soglia k≥3 studi distinti**, già applicata dal gate `rem_group` (`k_eff_min`).

## 5. Che cosa NON produce record — limiti dichiarati

1. **Gruppi senza comparison.** Nessun confronto → nessun contrasto → nessun record `cgroup`. Sono i
   **279** gruppi `rem_group_insufficient_in_study_controls`, il **limite L7** già documentato
   (bracci trattati senza controllo interno collegato dallo Stadio 2): oggi **non sono poolabili**,
   quindi non si perde niente che non fosse già perso. Continuano a esistere come record `group`
   (ramo mega) e restano nel catalogo dello Stadio 3.
2. **Delta vuoto o solo identitario.** Il confronto non isola una perturbazione: scartato con
   ragione `no_delta` / `solo_nuisance`.
3. **Degeneri.** `treated_label == control_label` o `factor_levels` identici: errori dello Stadio 2,
   non contrasti.
4. **Tutti gli scarti delle regole** di §3.6.

## 6. Lo Stadio 4

Due modifiche, entrambe piccole e chirurgiche:

1. **Il gate** (`.identify_layer_a_clusters`, `R/stage4-qc.R:51`): il ramo `rem_group` seleziona
   `mode == "cgroup"` invece di `mode == "group"`. Il vincolo `!usable_mega_strict` diventa
   ridondante (garantito da `level = 5`) ma resta come difesa.
2. **Il dispatch**: i record `cgroup` si risolvono **per comparison** (come il ramo pair), non per
   gruppo-trattato. `.build_group_rem_dispatch_from_stage3()` (`R/stage4-dispatch.R:313`) oggi cerca
   la comparison in cui il gruppo è il trattato (`.lookup_cmp_by_treated_group`); per i `cgroup` il
   `record_id` **è già** la comparison, quindi si usa `.lookup_cmp`. Il resto (REM per studio,
   collasso dei bracci intra-studio, `k_eff ≥ 3`) è invariato.

Tutto il resto dello Stadio 4 — `rem`, `mega`, `mega_aug` — **non viene toccato**: stessi record,
stesso gate, stesso pooling.

## 7. Retrocompatibilità

- `.build_pair_records()` e `.build_group_records()` restano **invariati**: nessuna riga modificata.
- I rami `rem` (pair k=3-9), `mega` (group L0/L1, k≥5) e `mega_aug` (pair k=2 + pool di baseline)
  continuano a ricevere esattamente gli stessi record di oggi.
- Con `mode = "cgroup"` assente (fixture legacy, test esistenti) il comportamento è identico a prima.
- **Nota onesta:** al prossimo re-cluster i cluster `pair` e `group` si muoveranno comunque, **non**
  per questo lavoro ma per le guardie del resolver entrate in produzione il 2026-07-25 (949 identità
  sbagliate rimosse, 3,52%: `Neoplasms` 354→0, `IFNA1` 119→0, `THPO` 36→0; `LPS`, `SARS-CoV-2`,
  `enzalutamide` invariati). Va scritto nel confronto prima/dopo, o si attribuirà al builder un
  effetto che non è suo.

## 8. Come si prova che funziona — prima del GATE UTENTE

1. **TDD** su ogni funzione nuova, con casi presi da **righe vere** (scartate o tenute), mai
   inventati — lo stesso metodo delle regole di riga.
2. **Equivalenza sui dati veri**: il builder gira sui 38.440 contrasti già ricostruiti e il suo
   verdetto per-membro si confronta con `109-fase1-v11-gate.R`. Le differenze si spiegano **una per
   una**; quelle non spiegate bloccano.
3. **Smoke sui gruppi bandiera** — pavimenti misurati in v11: SARS `NCBITaxon:2697049` k≥28 · LPS
   `CHEBI:16412` k≥26 · TGFB1 `HGNC:11766` k≥27 · JQ1 k≥24 · enzalutamide `CHEBI:68534` k≥21 ·
   vemurafenib `CHEBI:63637` k≥13. Se scendono: **fermarsi e misurare**, non aggiustare.
4. **Cache del recupero-nome**: il bump `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION` v7 → v8 serve **solo**
   se cambia `recover_identity()`. Questo design non lo tocca (il codice nuovo sta a valle). Se
   dovesse cambiare, il bump precede il run — è l'errore che è già costato 8 ore.
5. **Ri-censimento della coerenza sui dati VERI, su TUTTI i gruppi**, dopo il re-cluster. Il 97,9%
   della simulazione è un **pavimento da riverificare**, non un risultato acquisito.

## 9. Che cosa questa spec NON fa

- Non lancia re-cluster né re-pool: quelli richiedono il **GO esplicito dell'utente**.
- Non tocca `rem`, `mega`, `mega_aug`.
- Non ri-mappa le sigle bloccate dal resolver (decisione utente 2026-07-26: no, misurato 0 gruppi
  nuovi).
- Non ricostruisce la vetrina Layer B (viene dopo, sui gruppi sopravvissuti).
- Non dichiara nulla "validato / finale / paper-grade": nessun numero di questa spec è un risultato.

## 10. Rischi noti, dichiarati

1. **Il 144 non sopravviverà identico.** Il builder lavora su **tutti** i confronti dello Stadio 2,
   non solo su quelli dentro i cluster vecchi, e senza la scorciatoia del nome-cluster. Il
   controfattuale misurato (stesse regole, entità senza il nome del cluster) dà **149 chiavi: 5 perse
   — fra cui `hypoxia` k=9 e `radiation` k=4, che si sbriciolano in `STR:` diversi — e 10 nuove,
   quasi tutte malattie `STR:`**, da leggere una per una. Il ramo *on-contrast* per-record (§3.3.1)
   serve proprio a limitare questa deriva, ma il suo effetto **va misurato, non promesso**.
2. **Le mega non sono mai state verificate.** 39 delle 99 poolate in v10 non hanno un nome, 28 hanno
   `kind = none`: per loro l'anchor non dice che cosa ha ricevuto il braccio trattato — lo stesso
   meccanismo del minestrone, in un altro ramo, mai misurato. Il censimento è **fattibile a metà sui
   dati attuali** (dei 2.362 membri: 928 trattati, di cui **459 = 49%** agganciati a un confronto
   dello Stadio 2). Va fatto **prima del GO**, così che un eventuale ri-ancoraggio delle mega entri
   nello **stesso** re-cluster invece di richiederne un secondo.
3. **Chiave senza tessuto** (§3.7): scelta esplicita, coerente con i 141 gruppi già letti, ma è una
   scelta — va scritta nei Methods, non lasciata implicita.

## 11. Decisioni registrate

| # | decisione | quando |
|---|---|---|
| 1 | Opzione B: re-anchor a monte (anchor derivato dal contrasto) | utente 2026-07-24 |
| 2 | k ≥ 3; direzione opposta separata; verso non determinabile → scarta; combo = entità a sé; degeneri e nuisance si scartano | utente 2026-07-24 |
| 3 | Le righe mal appaiate si scartano, accettando di perdere i gruppi che scendono sotto 3 studi | utente 2026-07-25 |
| 4 | Nessun ri-mappaggio delle sigle bloccate del resolver (opzione A) | utente 2026-07-26 |
| 5 | **Affiancamento**: modo nuovo `cgroup` accanto a `pair`/`group`; `mega` e `mega_aug` non si toccano | utente 2026-07-27 |
| 6 | **Entità on-contrast dal nome dell'anchor del record**, non dal nome del cluster | utente 2026-07-27 |
| 7 | Pipeline e gate **deterministici**: nessun LLM a runtime; verifica su TUTTI, mai a campione | utente 2026-07-24 |
