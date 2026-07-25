# ADR-0025: Stadio 3 — i record di gruppo nascono dal CONTRASTO, non dalla perturbazione del campione

- **Status:** Proposed
- **Date:** 2026-07-27
- **Deciders:** lucavd, Claude (audit RED_ALERT — rework dell'ancoraggio)
- **Supersedes:** la **selezione** di ADR-0022 (il *pooling* `rem_group` resta invariato)
- **Superseded by:** —

## Context and Problem Statement

Per mesi l'audit v5→v10 ha ottimizzato i **nomi** dei cluster e ha dichiarato "publication-grade"
senza mai verificare la **coerenza di contrasto** — l'obiettivo stesso dello studio: che gli studi
raggruppati misurino lo **stesso** contrasto. Quando è stata finalmente verificata (2026-07-23,
finding `2026-07-23-stage3-cluster-coherence.md`): **157/184 (85%) del deliverable sono minestroni**,
la vetrina Layer B 0/9.

La causa radice è nel build. `.build_group_records()` (`R/stage3-build.R:473`) costruisce un record
per **replicate_group** e ne prende l'anchor dal **primo campione**
(`.extract_anchor_segments`, `R/stage3-anchor-levels.R:60`): l'anchor descrive la **perturbazione del
campione trattato**, e il **controllo non entra mai nella chiave**. Sotto lo stesso anchor
"SARS-CoV-2" convivono così "infezione vs mock", "farmaco vs DMSO in cellule infette" (dove
SARS è tenuto costante) e un knock-out genetico: tre contrasti diversi in una sola meta-analisi.

Tre sessioni di lavoro hanno prodotto le regole che separano i contrasti — derivate dai dati veri,
verificate una per una, scritte come codice di pacchetto (`R/stage3-contrast-gate.R` 102 test,
`R/stage3-row-pairing.R` 67 test), verificate equivalenti allo script su 19.863 etichette / 38.440
contrasti e rimisurate col codice di produzione: **144 gruppi poolabili k≥3, 141 coerenti (97,9%)**,
866/875 studi-slot. **Ma la pipeline non le chiama**: quel risultato vive in una simulazione.

## Decision Drivers

- La **coerenza** è il gate; il numero di gruppi non è mai un criterio.
- Il fix deve stare **alla radice** (nel modo in cui nasce il raggruppamento), non essere un filtro
  a valle: un filtro lascia il difetto nel dato, non fonde i frammenti e non corregge le etichette.
- **Non rompere** i rami che non c'entrano (`rem`, `mega`, `mega_aug`): non sono oggetto di questa
  verifica e non vanno danneggiati da un refactor.
- Pipeline e gate **deterministici**: nessun LLM a runtime (l'unico LLM della pipeline resta Mistral
  self-hosted, negli Stadi 1-2). Se la coerenza avesse bisogno di un giudice LLM a valle, l'anchor
  sarebbe mal progettato.
- Un **solo** re-cluster: le decisioni che richiedono di ri-ancorare vanno prese prima del run.

## Considered Options

1. **Filtro di contrasto a valle** (opzione C della spec 2026-07-24): tenere gli anchor attuali e
   spezzare i cluster al momento del pooling. Costa solo il re-pool, ma è un cerotto: non fonde i
   frammenti cross-cluster (k strettamente inferiore), lascia gli anchor sbagliati nel catalogo e
   nelle etichette. Misurato come **lower bound** dell'opzione 2.
2. **Anchor derivato dal contrasto, a monte** (opzione B): l'entità del cluster è ciò che il
   confronto isola — il delta trattato↔controllo, canonicalizzato col resolver esistente — più il
   verso e il tipo di controllo. **Scelta dall'utente il 2026-07-24.**
3. Dentro l'opzione 2, due forme: **(a) sostituire** `.build_group_records()`, oppure **(b)
   affiancare** un modo nuovo. La sostituzione toglie l'input al ramo `mega` (99 meta-analisi
   poolate in v10): un danno collaterale, non un effetto voluto del rework.

## Decision

**Opzione 2b — affiancamento.** Si aggiunge `.build_contrast_group_records()`, che produce record
`mode = "cgroup"`, **uno per comparison** dello Stadio 2, con:

```
anchor_key = <entità del delta, canonicalizzata> || <verso> || <tipo di controllo (+materiale, baseline, contesto d'infezione)>
```

- L'entità viene, in ordine: dal nome già risolto nell'anchor **di quel record** quando il delta lo
  nomina (*on-contrast*, decisione utente 2026-07-27); altrimenti dalla risoluzione del **delta** con
  candidati blindati; altrimenti da un ripiego `STR:` non generico; se il trattato contiene ≥2 agenti
  canonici assenti dal controllo, l'entità è la combinazione intera (`COMBO:a+b`).
- Le regole del gate (`.cg_*`) e dell'appaiamento della riga (`.rp_row_defect`) sono **richiamate,
  non riscritte**. Ogni scarto è registrato in `non_clusterable` con la sua ragione.
- I cluster `cgroup` hanno **un solo livello**, marcato `level = 5L`, e nessuna partizione per hard
  filter. Conseguenza voluta: non possono entrare nel ramo `mega` (che richiede `level ∈ {0,1}`).
- Nello Stadio 4 il ramo `rem_group` seleziona `mode == "cgroup"` invece di `mode == "group"` e
  risolve i campioni **per comparison**. Pooling, collasso dei bracci intra-studio e soglia
  `k_eff ≥ 3` restano quelli di ADR-0022.

`.build_pair_records()` e `.build_group_records()` **non vengono modificati**; `rem`, `mega` e
`mega_aug` ricevono esattamente gli stessi record di oggi.

## Consequences

### Positive

- Il deliverable nasce dal contrasto: i minestroni noti si sciolgono per **costruzione**, non per
  filtro (SARS ricomposto k=28 su un contrasto solo, LPS 26, TGFB1 27, enzalutamide 21).
- Le entità sinonime non frammentano più (il resolver lavora sul delta), quindi si recuperano
  fusioni che un filtro a valle non può fare.
- Additivo e reversibile: nessun ramo esistente cambia comportamento; con `mode = "cgroup"` assente
  il codice si comporta come oggi.

### Negative / rischi dichiarati

- **Il numero 144 non sopravviverà identico.** Il builder gira su tutti i confronti dello Stadio 2 e
  senza la scorciatoia del nome-cluster; il controfattuale misurato dà 149 chiavi (5 perse, fra cui
  `hypoxia` k=9 e `radiation` k=4; 10 nuove, quasi tutte `STR:` di malattia). Il numero vero si saprà
  solo dopo il re-cluster e va **ri-censito su TUTTI i gruppi**.
- **Meno gruppi, più piccoli**: molti k=3-4. Accettato dall'utente (2026-07-24): ~140 meta-analisi
  difendibili valgono più di 184 minestroni. La consistenza si riporta come forza, non come gate.
- **I gruppi senza comparison non producono record** (279 casi, limite **L7** già documentato): oggi
  non sono poolabili, quindi non si perde niente di poolato, ma il limite va ripetuto nei Methods.
- **La chiave non contiene il tessuto**: due studi sullo stesso farmaco in tessuti diversi finiscono
  nella stessa meta-analisi. È la chiave con cui sono stati letti e giudicati i 141 gruppi; va
  dichiarata nei Methods, non lasciata implicita.
- **Il ramo `mega` resta non verificato**: 39 delle 99 poolate in v10 non hanno un nome e 28 hanno
  `kind = none` — lo stesso meccanismo del minestrone, mai misurato. Questa ADR **non** lo risolve;
  il censimento (fattibile al 49% sui dati attuali) va fatto **prima** del GO sul re-cluster.

### Neutre

- Al prossimo re-cluster i cluster `pair` e `group` cambieranno comunque, per le guardie del resolver
  entrate in produzione il 2026-07-25 (949 identità sbagliate rimosse). Va attribuito a quelle, non
  al builder.

## Validation

Nessun run pesante senza GO esplicito. Prima del GO:

1. TDD su ogni funzione nuova, con casi presi da righe vere.
2. Equivalenza per-membro col gate misurato (`109-fase1-v11-gate.R`) sui 38.440 contrasti; ogni
   differenza spiegata singolarmente.
3. Smoke sui gruppi bandiera con i pavimenti misurati (SARS 28, LPS 26, TGFB1 27, JQ1 24,
   enzalutamide 21, vemurafenib 13).
4. Censimento di coerenza del ramo `mega`.

Dopo il re-cluster + re-pool: **ri-censimento della coerenza sui dati veri, su TUTTI i gruppi**,
prima di qualunque dichiarazione. Il 97,9% della simulazione è un pavimento da riverificare.

## Links

- Spec di design: `docs/superpowers/specs/2026-07-27-stage3-contrast-group-builder-design.md`
- Spec precedente (decisioni §6): `docs/superpowers/specs/2026-07-24-stage3-contrast-anchor-design.md`
- Finding coerenza: `docs/findings/2026-07-23-stage3-cluster-coherence.md`
- Finding regole di riga: `docs/findings/2026-07-26-stage3-row-pairing-rules.md`
- ADR-0022 (pooling `rem_group`, conservato): `docs/decisions/0022-stage4-rem-group-named-metaanalyses.md`
