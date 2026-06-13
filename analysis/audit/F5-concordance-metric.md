# F5 → F6 — metrica di riproducibilità cross-studio (guard di selezione Layer B)

> RED ALERT FASE F5/F6, 2026-06-13. Validazione di una metrica scientifica per
> distinguere cluster Stadio 4 **riproducibili** (showcase-worthy) da artefatti,
> al posto di una soglia arbitraria sulla %DE.
> Run analizzato: `20260613T051637Z-stage4-4f7ea215` (Layer A v3, 776 cluster).

## Problema

Il sanity F5 aveva flaggato ~10% di cluster con >40% di geni DE come "probabili
artefatti da anchor grossolano". La prima idea — un guard che scarta i cluster ad
alta %DE — è **scientificamente sbagliata**: una %DE alta può essere biologia vera
(uno switch di stato cellulare dà legittimamente 40–60% DE). La %DE è un *sintomo*
ambiguo, non la causa. La domanda giusta è: **gli studi dentro il cluster stanno
misurando lo stesso effetto, o si sta mediando biologia diversa?** — l'assunzione
di omogeneità della meta-analisi.

## Metriche (due assi complementari)

**B — concordance.** Dai logFC per-studio (`per_study_de`): matrice gene×studio sui
top-N geni per significatività cross-studio, **mediana delle correlazioni di
Spearman a coppie** fra studi (pairwise complete). Alta = gli studi concordano sul
pattern di geni = effetto riproducibile; bassa/negativa = studi che si
contraddicono = pooling incoerente o nessun segnale. Script
`analysis/p4-fase-f6-concordance.R`.

**Copertura reale di B per metodo (verificata, NON method-agnostic uniforme):**

| metodo | n | k in `per_study_de` | B |
|---|--:|---|---|
| rem | 28 | 3–8 (studi indipendenti) | affidabile (trusted) |
| mega_aug | 575 | **esattamente 2** (i 2 studi della coppia) | check a 2 studi, fragile ma reale |
| mega | 173 | **0** (pooled, no DE per-studio) | **non calcolabile** |

Il modello group MEGA è un fit pooled unico e non emette DE per-studio → B assente.
La sua coerenza starebbe nella varianza dell'effetto-studio random del fit dream,
che **non è salvata** negli output attuali. **Punto chiave:** gli artefatti
high-%DE erano 71/75 mega_aug — cioè dove B *è* disponibile (k=2); i mega sono
conservativi per natura (mediana 0,1% DE), basso rischio artefatto, quindi
l'assenza di B lì pesa poco. Decisione: per i mega si accetta l'assenza di B
(gating via potenza + conservatività), niente ricalcolo dedicato.

**A — med_I2 (complementare, solo rem).** Eterogeneità meta-analitica della
*magnitudine* dell'effect size fra studi (già in `cluster_pooled`, popolato solo
per i 28 rem).

## Finding 1 — la %DE NON è diagnostica (ipotesi ribaltata)

Concordanza per bucket di %DE (601 cluster con k≥2):

| bucket %DE | n | concordanza mediana (q25–q75) |
|---|--:|--:|
| <5% | 271 | 0,03 (−0,13 … 0,18) |
| 5–20% | 147 | 0,12 (−0,02 … 0,45) |
| 20–40% | 110 | 0,26 (0,07 … 0,62) |
| **>40%** | 73 | **0,65** (0,36 … 0,89) |

I cluster ad alta %DE sono per lo più **concordi**, non discordi. L'"artefatto"
sospettato nello smoke (pair_L1_d3f9463d, 80,7% DE) ha concordanza **1,00**: i due
studi sono in pieno accordo → è **biologia forte riproducibile**, non apples-vs-pears.
Un guard sulla %DE avrebbe scartato biologia vera. **La %DE è abbandonata come
criterio.**

## Finding 2 — la concordanza è un criterio POSITIVO di riproducibilità

Alta concordanza = effetto ricatturato da più studi = ciò che vale la pena mostrare.
I veri artefatti sono i cluster con segnale apparente forte **ma** studi discordi:
dei 73 cluster >40% DE → **43 concordi (≥0,5, da tenere)**, **17 discordi (<0,2,
artefatti da scartare)**, 13 intermedi. I 271 cluster a <5% DE con concordanza ~0
sono "nessun effetto riproducibile" (rumore), esclusi per altra ragione.

## Finding 3 — A e B sono ORTOGONALI (non ridondanti)

Sui rem: `cor(concordance, med_I2) = 0,03`. Misurano cose diverse: **B = accordo
sul pattern/direzione** dei geni; **I² = accordo sulla magnitudine**. Un cluster può
concordare su *quali* geni cambiano (B alta) con effect size diversi (I² alta).
Quindi vanno usati **insieme** come due assi di qualità, non uno al posto dell'altro.

## Caveat — k (numero di studi)

La concordanza a **k=2** è una sola correlazione → fragile (conc=1,00 su 2 studi
vale meno di 0,7 su 10). Lo script riporta `k_studies` + `conc_confidence`
(`trusted` se k≥3, `low_conf_k2` se k=2, `no_pairs` se k=1). La soglia di selezione
va fissata tenendo conto di k.

## Uso in F6 (selezione Layer B)

Sostituire la %DE con: **(1) concordanza B come gate di riproducibilità**
(high-pass, condizionata a k≥3 per il livello "trusted"); **(2) med_I2 come flag di
qualità complementare sui rem** (preferire magnitudine coerente); **(3)** più i
criteri di potenza già esistenti (k, effect size, n_sig). Le soglie numeriche si
fissano con l'utente in fase di shortlist, non sono hard-coded.

Deliverable: `cluster_reproducibility.rds` nella dir del run Stadio 4
(cluster_id, method, k_studies, concordance, conc_confidence, med_I2, pct_sig,
n_sig, max_absLFC).
