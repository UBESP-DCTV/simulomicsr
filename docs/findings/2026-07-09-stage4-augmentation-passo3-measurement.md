# Finding — Recupero dei farmaci esclusi (augmentation "passo 3"): misura + validazione

**Data:** 2026-07-09
**Branch:** `review-scientific-consistency-2026-06-10` (master invariato, no push)
**Sessione:** notturna autonoma — audit RED_ALERT F6, passo 3 (i 279 `rem_group` caduti)
**Input:** Stadio 3 v7 (`20260703T113045Z-stage3-v7-364547a7`), stage2 master v3, run v8
(`a500d032`, `non_processable.rds`).
**Artefatti:** `analysis/audit/2026-07-09-stage4-279-recovery-classification.csv` (tabella dei 279),
script di misura in `scratchpad/` (measure-*, validate-swap.R).

## In una frase (per lo scienziato)

I 279 gruppi esclusi non sono un blocco omogeneo: **195 sono irrecuperabili** (dati troppo
sottili), **38 si recupererebbero senza prestare nulla** (il controllo esiste già nello stesso
studio, ma la pipeline non lo aveva collegato), e solo **46 richiederebbero davvero di prestare un
controllo da un altro studio** — cioè la parte per cui era pensato il "passo 3". E la validazione
mostra che **prestare un controllo da un altro laboratorio, pur mantenendo la direzione generale
dell'effetto, distrugge la capacità di scoprire geni** (perché la differenza-di-laboratorio gonfia
la variabilità). Conclusione provvisoria: **il "passo 3" così com'era immaginato rende poco ed è
scientificamente debole; la vera occasione è recuperare i controlli interni non collegati.**

## 1. Cosa sono i 279 caduti

Tutti a livello L4 (entità nominata specifica). Per numero di studi con controllo interno usabile:
**131 a k=0, 93 a k=1, 55 a k=2** (soglia per una meta-analisi: k≥3 studi distinti). Per tipo di
perturbazione: **123 malattie** (`disease_vs_normal`), **94 farmaci/piccole molecole**, 62 altri
(ambientale, citochine, patogeni, perturbazioni genetiche). Le bandiere note (enzalutamide,
tamoxifene, olaparib) **non** sono qui: erano già state processate nel v8 con controlli interni
veri. Tra i caduti ci sono farmaci reali (cisplatino, ribociclib) ma anche molte etichette dubbie
(problema di *nome*, non in scope qui).

Fatto chiave: **tutti i 279 hanno già ≥3 studi che contribuiscono campioni** (mediana 3, fino a 17).
Non mancano gli studi — manca, *dentro* ogni studio, il gruppo di controllo appaiato.

## 2. Perché cadono davvero (diagnosi sui dati veri)

Sui 3.044 record membri dei 279 cluster:
- **il 93% appartiene a studi che HANNO un gruppo di controllo** da qualche parte nello studio;
- 1.722 sono gruppi *trattati* in studi *con* controllo, ma **non collegati** da alcun confronto
  interno che lo Stadio 2 abbia costruito.

Ispezione di casi concreti → due meccanismi:
1. **Gruppi a campione singolo** (n=1): ridondanti rispetto a un gruppo gemello già confrontato, o
   inutilizzabili comunque (la statistica richiede repliche). Es. GSE95078, un quarto gruppo
   "TNF-malato" a 1 campione mentre lo Stadio 2 aveva già confrontato il gemello a 2 campioni.
2. **Controllo a campione singolo o disegno indecidibile**: es. GSE160393 confronta *tutti* i tumori
   contro un unico controllo a 1 campione (cade per n_min≥2); es. uno studio di modelli PDX di
   prostata con controlli grossi (n=23) ma **nessun** confronto costruito (troppi gruppi, disegno che
   lo Stadio 2 non ha saputo sciogliere).

Morale: lo Stadio 2 **codifica già l'abbinamento giusto** trattato-controllo quando c'è; dove non
c'è, spesso è perché i dati sono genuinamente sottili o il disegno è ambiguo.

## 3. Potenziale di recupero (conteggio rigoroso: controllo interno richiede ≥2 campioni)

| Classe | n | Cosa serve | Rischio |
|---|--:|---|---|
| **A — in-studio** | **38** | Solo appaiare trattati (≥2) a controlli interni (≥2) già presenti ma non collegati | Basso (il "batch" si annulla dentro lo studio) |
| **B — solo con prestito** | **46** | Prestare un controllo da un altro studio comparabile | **Alto** (vedi §4) |
| **C — perso** | **195** | Niente aiuta (troppo pochi studi con repliche) | — |

Dei **46 di classe B**, per ancoraggio reale: **13 hanno 2 contrasti veri interni** (un prestito
basta a raggiungere k=3, la meta-analisi resta ancorata al reale → più difendibile), 20 ne hanno 1,
**13 non ne hanno nessuno** (interamente costruiti su controlli prestati → indifendibili). Tabella
completa per cluster nel CSV.

**Attenzione: nemmeno la classe A è "pulita".** Il recupero in-studio richiede di *scegliere* il
controllo giusto tra quelli presenti, in studi che lo Stadio 2 non aveva collegato **spesso perché il
disegno era complesso**. Sugli studi-extra recuperati: solo una minoranza ha un **unico** gruppo di
controllo (abbinamento non ambiguo); molti ne hanno da 2 a 35 tra cui scegliere, e alcuni studi non
hanno **nessun** confronto costruito (disegno che lo Stadio 2 non ha saputo sciogliere). **Solo 3
cluster su 38** hanno tutti gli studi-extra con abbinamento non ambiguo. Quindi anche il recupero
"sicuro" comporta un rischio reale di appaiare il controllo sbagliato (es. sano-veicolo con
malato-trattato) in disegni intricati — proprio dove nasce l'errore biologico.

## 4. Validazione: "i confronti col controllo prestato hanno senso?"

Test decisivo (lo stesso che chiedeva l'utente). Su farmaci **noti-buoni già processati bene nel v8**
(che HANNO controlli interni veri), ricalcolo l'effetto in due modi e li confronto gene per gene:
- **VERO**: trattato-vs-controllo *dentro lo stesso studio* (com'è nel v8);
- **PRESTATO**: trattato di uno studio vs controllo *preso da un altro studio dello stesso cluster*
  (stesso farmaco, stesso tessuto → è il caso *migliore* possibile di prestito).

### Tamoxifene (mammella, 5 studi effettivi)

| Metrica | Esito |
|---|---|
| Correlazione dell'effetto complessivo (vero vs prestato) | **0,83** (Spearman 0,80) — quadro grezzo preservato |
| Concordanza di direzione sui 100 geni a effetto più forte | **100%** |
| Geni significativi (FDR<0,05) | **437 → 130** |
| Recupero dei geni veri significativi | **solo 7%** |
| Sovrapposizione delle liste significative (Jaccard) | 0,06 |
| Eterogeneità I² mediana | 92 → **98** (quasi saturata) |

Lettura: prestare un controllo comparabile **mantiene la direzione** dell'effetto sui geni più forti,
ma **la differenza-di-laboratorio gonfia la varianza** al punto che **si perde il 93% delle scoperte**
e le poche significative che restano sono in larga parte diverse da quelle vere (bassa precisione).

### Enzalutamide (prostata, 18 studi effettivi, k mediano 12)

| Metrica | Esito |
|---|---|
| Correlazione dell'effetto complessivo (vero vs prestato) | **0,65** (Spearman 0,66) |
| Concordanza di direzione sui 100 geni a effetto più forte | 99% (ma ampiezza ridotta del 28%) |
| Geni significativi (FDR<0,05) | **1337 → 57** |
| Recupero dei geni veri significativi | **solo 1%** |
| Sovrapposizione delle liste significative (Jaccard) | 0,01 |
| Eterogeneità I² mediana | 86 → **99** (saturata) |

**L'ipotesi "con più studi il prestito recupera potenza" è SMENTITA in modo netto.** Con 12–25 studi
il prestito va *peggio* del tamoxifene: recupera **l'1%** dei geni veri, satura l'eterogeneità
(I²=99) e riduce l'ampiezza degli effetti forti del 28%. La differenza-di-laboratorio, avendo tante
coppie trattato-studio-X vs controllo-studio-Y, **domina** la varianza tra studi invece di mediarsi.

### Sintesi delle due validazioni

| | tamoxifene (k≈5) | enzalutamide (k≈12) |
|---|---|---|
| correlazione effetto | 0,83 | 0,65 |
| geni sig (vero → prestato) | 437 → 130 | 1337 → 57 |
| **recupero geni veri** | **7%** | **1%** |
| I² (vero → prestato) | 92 → 98 | 86 → 99 |

Entrambi bocciano il prestito su base larga. Più studi **non** aiutano.

## 5. Conclusione e raccomandazione

1. Il "passo 3" propriamente detto (prestito di controlli esterni) recupererebbe **al più 46
   cluster**, di cui solo 13 ben ancorati, e la validazione lo **boccia in modo netto**: le
   meta-analisi prodotte perderebbero **il 93–99% delle scoperte** con I² saturato. Più studi non
   aiutano. **Non è buona scienza** su base larga.
2. Il recupero con soli controlli **interni** (classe A, 38 cluster) non è prestito, ma richiede di
   scegliere il controllo giusto in studi dal disegno complesso: **solo ~3/38 sono chiaramente
   puliti**. Rischio di abbinamento sbagliato non trascurabile.
3. **I 195 restanti sono irrecuperabili** con qualunque metodo (dati troppo sottili).

**Raccomandazione (per il gate utente):** NON lanciare alcun re-pool di produzione stanotte. Il
rendimento onesto e affidabile è piccolo (unità–decine di cluster) e ogni via comporta un rischio
reale di biologia sbagliata. Le opzioni difendibili, in ordine di prudenza, sono: **(4) documentare
i 279 come limite noto** (i pool esistenti restano corretti; è un errore di *omissione*, non di
commissione — la scelta più difendibile); **(1) recuperare solo i ~3–pochi cluster classe A con
abbinamento non ambiguo**, uno per uno, con verifica manuale; **(2)** eventualmente i 13 prestiti
ben ancorati, ma solo con gate empirico per-cluster (recupero geni ≥60% nello swab) — e la
validazione suggerisce che quasi nessuno lo passerebbe. **Il prestito largo (handout originale) è da
scartare.**

Questa misura **riforma il compito** rispetto all'handout: per questo la porto all'utente prima di
implementare (regola: decisioni che cambiano l'approccio → gate utente; dubbio serio sulla qualità
dei confronti → STOP, come da istruzioni della sessione).
