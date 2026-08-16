# A3 — definizione e previsioni, depositate PRIMA del run

**Scritto:** 2026-08-16, prima di qualunque sottomissione al DGX.
**Branch:** `review-scientific-consistency-2026-06-10` · master invariato.

> Questo documento va scritto **prima**, e non si tocca dopo. Se una previsione
> cade, cade: è il solo modo in cui questo strumento serve a qualcosa.

---

## 0. Che cos'è A3, e che cosa NON è

A3 **non è una previsione**: è un **metro**. Rifà gli stadi LLM su una parte
degli studi, tiene fermo il resto, poi ri-clusterizza e ri-poola **tutto**.
Quanto si sposta il deliverable in questa prova è la misura di quanto è normale
che si sposti quando si rifà il modello.

Serve perché dopo il re-run completo il deliverable non sarà 211, e senza un
metro non c'è modo di dire se la differenza è rumore o un guasto.

**Perché non basta il numero già noto.** La variabilità run-to-run è misurata
sui *record* (Stadio 1: record completo identico nel 40,4% dei casi senza flag;
`agent_normalized.id` 86,0%; Stadio 2: confronti per identità dei campioni
92,0%). Il passaggio da lì al *deliverable* non è lineare e **non è mai stato
misurato**. A3 lo misura.

---

## 1. Il sottoinsieme, congelato

| | |
|---|---|
| criterio | studi dei cluster `cgroup` con **k ≥ 2**, uniti agli studi **poolati** nel deliverable v16b |
| studi | **2.566** |
| record Stadio 1 | **86.898** (17,10% di 508.037) |
| lista | `analysis/audit/2026-08-16-A3/A3-studi.txt` |
| sha256 | `f57eb0a22019c9df9f3c158e1e1889970f782e77403a37cb068688bae084e08a` |
| script | `00-definisci-sottoinsieme.R` (4 casi di accettazione, 2 negativi) |

**Perché k ≥ 2.** Perché un gruppo diventi una meta-analisi servono 3 studi
(`k_eff_min = 3`). Solo un gruppo già a 2 può entrare o uscire cambiando **un**
membro. Un gruppo a k=1 dovrebbe guadagnarne due insieme.

**Perché l'unione coi poolati.** Uno studio poolato — **GSE138309** — sta in un
cluster `cgroup` con k=1: è poolato perché `.reassign_absorbed_records()` ha
spostato i suoi record sul vincente di una fusione. Definire il sottoinsieme
dalle sole assegnazioni lo perderebbe **in silenzio**.
⚠️ Correzione a quanto detto prima: contro i soli 350 cluster candidati gli
studi recuperati dall'unione sono **13**; contro tutti i `cgroup` a k≥2, che è
il criterio di A3, è **1**.

**Punto cieco, dichiarato:** ingressi da cluster oggi a k=1. Evento di secondo
ordine (servono due membri nuovi nello stesso cluster), ma **non è zero**, e A3
non lo vede.

**Limite di natura, dichiarato:** il corpus della prova è **misto** — una parte
classificata dal run vecchio, una dal nuovo. Non è un oggetto che la pipeline
produce mai. Per i 211 gruppi esistenti la misura è però a piena scala, perché
la loro composizione dipende solo dagli studi che vengono rigenerati.

---

## 2. La procedura, fissata

1. Stadio 1 sui **86.898** record di `analysis/input/A3-stage1-input.jsonl`
   (sha256 `9d0192ef794c1f7bbcc377cf8e0f916f4a317850a3bf74e1b227153eb0c862c9`),
   con `VLLM_BATCH_INVARIANT=1`, **in blocchi da 10.000 come in F2** (9 blocchi).
   Non è un dettaglio: il runtime assegna il record *i* al worker *i* mod *n* e
   per lo Stadio 1 manda l'intero shard in **una** chiamata, quindi la
   composizione del batch dipende da come è tagliato il job. Tenere il taglio di
   produzione è ciò che rende A3 confrontabile col re-run completo — e quanto
   quel taglio conti davvero è esattamente ciò che misura la prova della
   batch-invarianza (§3, P5).
2. Innesto nel master Stadio 1: quei record **sostituiti**, gli altri intatti.
3. Rebuild input Stadio 2 dal master innestato, **col fix `series_id`**.
4. Stadio 2 sui soli studi di A3.
5. Innesto nel master Stadio 2.
6. Re-cluster **intero** e re-pool **intero** (le fusioni dipendono
   dall'insieme completo: un sottoinsieme applicato prima le falserebbe).
7. Confronto con v16b.

---

## 3. Previsioni con una RISPOSTA GIUSTA (falsificabili senza ambiguità)

Queste non riguardano il rumore: specificano l'effetto di un cambio di codice.
Sono la specie che in questo progetto ha catturato difetti veri.

| # | previsione | come si falsifica |
|---|---|---|
| P1 | Il rebuild dell'input Stadio 2 col fix dà **24.393 studi** (oggi 24.394) e **zero** sigle assenti dall'input Stadio 1 | un numero diverso, o una sigla fantasma |
| P2 | Sul master attuale il fix registra esattamente **3** record con `series_id` alterato (GSM2422631/2/4, `GSE91395` → `GSE9135`) e `GSE9135` sparisce | un conteggio diverso |
| P3 | Per gli studi **fuori** da A3 i record dell'input Stadio 2 sono **byte-identici** a quelli di produzione | una sola differenza: allora il build dipende da stato globale e A3 misura due cose insieme |
| P4 | Il re-cluster parallelo a parità di input dà **322.417 cluster** e **574.799 assignment** | numeri diversi: l'equivalenza dichiarata il 16 agosto non regge |
| P5 | `container-env.txt` del job contiene `VLLM_BATCH_INVARIANT=1` | assente: la flag non è arrivata al processo |

## 4. Previsioni sul MOVIMENTO (stime, non specifiche)

Qui non c'è una risposta giusta: è la scommessa che A3 mette alla prova.
Derivazione esposta, così che se cade si sappia quale passaggio era sbagliato.

**Il dato di partenza:** **77 righe su 211 (36,5%) stanno a `k_eff` = 3**, cioè
a un solo studio dall'uscita. Altre 42 a k_eff = 4. La mediana è 4.

**Il ponte, mai misurato:** al più l'8,0% degli studi cambia insieme dei
confronti fra due giri (Stadio 2, identità dei campioni). Se **ogni** confronto
cambiato togliesse lo studio dal gruppo — il caso peggiore — le 77 righe a
k_eff=3 perderebbero un membro con probabilità ~3 × 8% ≈ 22%, cioè **~17
uscite**. È un limite superiore, perché un confronto diverso resta quasi sempre
nello stesso gruppo.

| | previsto |
|---|---|
| M1 — righe che escono | fra **0 e 17**, atteso ~6 |
| M2 — righe che entrano (dai 83 cluster caduti a k_eff=2) | fra **0 e 10**, atteso ~4 |
| M3 — totale del deliverable | **211 ± 15** (cioè 196–226) |
| M4 — i gruppi di punta sopravvivono tutti | TGF-β1, TNF, ipossia, SARS-CoV-2, LPS, IFN-γ, DHT, enzalutamide |
| M5 — controllo biologico | **≥ 27/31** (v16b: 29/31) |
| M6 — DHT contro enzalutamide | **> 90%** di geni discordanti, Spearman **< −0,85** (v16b: 97,5%, −0,939) |
| M7 — pavimenti Stadio 3 | SARS-CoV-2 ≥ 38, TGFB1 ≥ 78, LPS ≥ 50, enzalutamide ≥ 29, vemurafenib ≥ 20, IL17A ≥ 12 |

## 5. Che cosa falsificherebbe A3 nel suo insieme

- **M3 fuori da 196–226**: il ponte record→deliverable è molto più forte di
  quanto stimato, e allora il re-run completo va trattato come un esperimento
  aperto, non come una conferma.
- **M4 o M7 che cadono**: non è rumore, è un guasto. Fermarsi e leggerlo.
- **M5 sotto 27/31**: la pipeline ha smesso di misurare la cosa giusta.
- **P3 che cade**: A3 non è una misura pulita e va rifatto diversamente.

## 6. Che cosa A3 **non** dirà, comunque vada

- se il re-run completo darà lo stesso numero (A3 rigenera il 17,1% dei record,
  non il 100%);
- se esistono gruppi nuovi nati da cluster oggi a k=1;
- nulla sulla **correttezza**: un movimento piccolo non assolve i difetti, e un
  movimento grande non li dimostra.
