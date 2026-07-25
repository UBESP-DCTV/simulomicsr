# Il builder dice la stessa cosa del gate misurato: 13 differenze su 38.440, e sette bug miei

**Data:** 2026-07-27 · **Branch:** `review-scientific-consistency-2026-06-10`
**Stato:** 🟡 **Equivalenza chiusa. Nessun re-cluster, nessun re-pool: niente e' materializzato.**

---

## 1. La domanda

ADR-0025 ha portato le regole del contrasto dentro la pipeline
(`.ca_member_contrast()`, `R/stage3-contrast-anchor.R`). La domanda che decide se si puo' andare
avanti e' una sola: **il codice che verra' eseguito dice la stessa cosa dello script su cui sono
stati misurati i 144 gruppi?**

Metodo: si gira il verdetto del pacchetto sugli **stessi 38.440 contrasti** del gate v11
(`analysis/audit/2026-07-24-anchor-coherence-sim/109-fase1-v11-gate.R`) e si confronta membro per
membro. Ogni classe di differenza va spiegata; quelle non spiegate bloccano.

## 2. Esito

| | |
|---|---:|
| membri confrontati | 38.440 |
| verdetto identico (tenuto/scartato) | **38.427 (99,97%)** |
| differenze totali | **13** |
| gruppi poolabili k≥3 — gate | 144 |
| gruppi poolabili k≥3 — pacchetto | **146** |
| gruppi del gate presenti nel pacchetto **con k identico** | **144 / 144** |
| gruppi presenti solo nel gate | **0** |

**Gruppi bandiera, pavimenti misurati, tutti rispettati esattamente:** SARS-CoV-2 `NCBITaxon:2697049`
k=28 · TGFB1 `HGNC:11766` k=27 · LPS `CHEBI:16412` k=26 · enzalutamide `CHEBI:68534` k=21 ·
vemurafenib `CHEBI:63637` k=13.

Distribuzione della forza: k=3-4 → 80 · k=5-9 → 47 · k=10-19 → 14 · k≥20 → 5.

## 3. Le 13 differenze residue, spiegate

Sono tutte della stessa classe: `ok → nome_ombrello`. Entita' che il gate teneva e il pacchetto
scarta:

| entita' | membri | studi |
|---|---:|---:|
| `STR:lesional` | 8 | 1 |
| `STR:cytokine` | 3 | 1 |
| `STR:inflammation` | 2 | 1 |

"Lesional", "cytokine", "inflammation" non sono entita': sono parole-ombrello. Il gate applicava il
controllo sull'ombrella **solo** al ramo `NAME:` e non a quello `STR:` — un'incoerenza interna, non
una scelta. Il pacchetto lo applica a entrambi.

**Qui il pacchetto e' piu' severo del gate, di proposito.** Senza questa regola, `lesional` (31
membri su 3 studi contando anche quelli che arrivavano dall'anchor) avrebbe prodotto un gruppo k=3
di sola spazzatura.

## 4. I due gruppi in piu'

| chiave | k | n | che cos'e' |
|---|---:|---:|---|
| `MeSH:D012008\|\|gain\|\|diagnosis` | 3 | 23 | da giudicare nel censimento |
| `STR:fetal\|\|gain\|\|adult` | 3 | 6 | contrasto di sviluppo, entita' debole |

Non sono un guadagno finche' non passano il censimento di coerenza.

## 5. Sette bug MIEI, trovati misurando

Nessuno era visibile dai test unitari: sono emersi tutti dal confronto sui dati veri.

| # | difetto | effetto misurato |
|---|---|---|
| 1 | nome risolto giudicato per **lunghezza** invece che per appartenenza al vocabolario | **565 membri** di entita' vere scartati: TNF (98), RSV, CMV, HBV, M. tuberculosis, IL6 |
| 2 | `{.CA_CONTRAST_LEVEL}` in una riga di log: cli ≥ 3.4 legge `{.x}` come stile | **il build moriva** appena esisteva un record `cgroup` |
| 3 | `.dropped_segments_at_level` pretende un livello 0-4 | errore al livello 5 dei `cgroup` |
| 4 | le dosi si toglievano **insieme ai separatori** | **253 combinazioni** perse: `Bleomycin/Alpha-Lipoic Acid` diventava la sola bleomicina |
| 5 | guardia sulle sigle applicata anche alle parti separate da `+` | sparivano `M.tb + CMV` e `IL2 + IL23` (cmv, m tb, il2, il23 sono tutti sotto i 5 caratteri) |
| 6 | vocabolario diverso da quello del gate per ripulire le parti | **102 membri** in una chiave leggermente diversa (`COMBO:taz sirna+yap` invece di `COMBO:taz+yap`) |
| 7 | si toglieva solo il prefisso `STR:` e non `NAME:` | **66 membri**: la sonda cercava `name training` invece di `training` |
| 8 | entita' risolta da **tutti** i valori del delta invece che da quelli della **classe dominante** | in `APC/TP53 mutant, STAR positive` il gene diventava STAR invece di APC |
| 9 | ombrella controllata solo sul nome risolto, mai sull'entita' stessa | `lesional` restava dentro quando arrivava dall'anchor (23 membri) |
| 10 | vocabolario sbagliato nel rilevatore di combinazioni dalle etichette | combinazione inventata `COMBO:cancer+siINO80` (19 membri) |

Tre di questi (1, 5, 6+10) sono **la stessa lezione ripetuta**: quando si porta una regola da uno
script al codice di pacchetto, il vocabolario e le guardie vanno portati *con* lei, allo stesso
posto. Una guardia giusta al posto sbagliato e' un bug silenzioso.

## 6. Una correzione al metodo, non solo al codice

La prima equivalenza dava **1214 differenze** e sembrava un problema del pacchetto. Ne era in parte
responsabile **il confronto stesso**, sbagliato in due modi:

- teneva **spento** il ramo on-contrast (passava `anchor_id = NA`), mentre nel build quell'ID esiste:
  853 differenze erano solo questo. Ora si usa come proxy il nome del cluster canonicalizzato con gli
  stessi resolver — la stessa fonte da cui l'anchor nasce;
- non distingueva le combinazioni, per cui una combo riscritta appena diversa sembrava una combo
  persa.

Sequenza misurata: **1214 → 515** (proxy dell'anchor) **→ 381** (sigle corte) **→ 99** (vocabolario e
prefisso) **→ 13** (classe dominante, ombrella, combinazioni dalle etichette).

## 7. Che cosa questo NON dimostra

- **Non dimostra che i 146 gruppi siano coerenti.** L'equivalenza dice che il pacchetto riproduce il
  gate, non che il gate produca meta-analisi difendibili. La coerenza si verifica leggendo i gruppi
  uno per uno — e il 97,9% della simulazione **non si trasferisce**, perche' la composizione e'
  cambiata.
- **Non e' una misura sui dati veri della pipeline.** Gira sui contrasti gia' ricostruiti
  (`fase1-v11-results.rds`), non sull'output di un re-cluster. Il numero vero si sapra' dopo.
- Il ramo on-contrast usa qui un **proxy** del nome dell'anchor. Nel build l'ID viene dal
  `tracking_meta` del record: e' la stessa fonte, ma la coincidenza va riverificata dopo il
  re-cluster.

## 8. Riproducibilita'

`analysis/audit/2026-07-27-contrast-builder/`: `10-equivalenza-builder.R` (+ `10.log`) →
`20-differenze-classi.R` (+ `differenze-classi.txt`, `differenze-tutte.csv`) →
`40-bundle-gruppi.R` (+ `bundle-gruppi.txt`, `gruppi-indice.csv`) →
`50-smoke-bandiera.R` (+ `smoke-bandiera.csv`).
