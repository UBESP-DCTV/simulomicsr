# A3 — quanto si muove lo Stadio 3 rifacendo gli stadi LLM

**Data:** 2026-08-19 · **Branch:** `review-scientific-consistency-2026-06-10`
**Misura:** `analysis/audit/2026-08-16-A3/80-movimento-bandiera.R`
**Riferimento:** `20260815T231154Z-stage3-v16-7f986159` (master vecchi)
**A3:** `20260818T110906Z-stage3-v16-7f986159` (Stadio 1 e 2 rigenerati su 2.566 studi)

---

## 1. Il fatto

Rifacendo gli stadi LLM su un sottoinsieme congelato di 2.566 studi, con
`VLLM_BATCH_INVARIANT=1`, **tutte e cinque le entità bandiera perdono studi**.
Nessuna sale.

| entità | riferimento | A3 | usciti | entrati | netto |
|---|---:|---:|---:|---:|---:|
| TGFB1 | 78 | 71 | 9 | 2 | **−7** |
| LPS | 50 | 44 | 9 | 3 | **−6** |
| SARS-CoV-2 | 38 | 32 | 8 | 2 | **−6** |
| vemurafenib | 20 | 15 | 5 | 0 | **−5** |
| enzalutamide | 29 | 26 | 4 | 1 | **−3** |

Il movimento è bidirezionale ma nettamente asimmetrico: **35 usciti contro 8
entrati**. Tre delle cinque finiscono sotto il pavimento del gate (SARS-CoV-2,
enzalutamide, vemurafenib), e il gate si è fermato come doveva.

**Il calo nasce con A3, non era già lì.** Nel run di riferimento tutte e cinque
erano sopra il pavimento: il confronto col pavimento da solo non lo direbbe,
perché quei pavimenti vengono dal censimento di v12 e sarebbero potuti essere
stale. Non lo sono.

---

## 2. Dove vanno gli studi usciti

Nessuno sparisce. Tutti e 35 sono ancora negli assignment: sono **riassegnati**.
Per studio (non per destinazione: uno studio di screening con duecento composti
altrimenti domina il conteggio da solo):

| categoria | studi |
|---|---:|
| **stessa entità, tipo di controllo diverso** | **13** |
| esce dai raggruppamenti per contrasto | 13 |
| entità diversa | 9 |

I tipi di controllo in cui finiscono, partendo tutti da `vehicle_untreated`:
`unknown`, `ctrl`, `nt`, `nc`, `sicontrol`, `undiff`, `pre treatment`,
`vehicle_untreated_clin`, `non targeting`. Sono normalizzazioni diverse della
stessa cosa, prodotte dallo Stadio 2 rigenerato.

**Il 74% dei movimenti non è un errore di identificazione dell'entità.** In 13
casi l'entità resta quella giusta e cambia solo come è stato normalizzato il
controllo; in altri 13 lo studio non produce più un record di gruppo eleggibile.
Solo in 9 casi su 35 l'agente identificato cambia davvero (per esempio LPS →
`STR:gard`, enzalutamide → `COMBO:castration+enzalutamide`).

---

## 3. I due controlli che rendono leggibile il risultato

- **studi usciti che non erano nel sottoinsieme A3: 0.** Il movimento è confinato
  agli studi rigenerati: nessuno studio col record intatto si è spostato. Se ce ne
  fosse stato anche uno, il numero misurerebbe un difetto del processo invece
  dell'effetto del re-run.
- **studi usciti spariti da ogni assignment: 0.** Non è una perdita a monte
  (Stadio 2), è una riassegnazione.

Va detto che i cinque gruppi bandiera sono **rigenerati al 100%** dal
sottoinsieme A3: è il caso più esposto possibile, non un campione qualsiasi del
corpus. Il numero non si estende al resto delle 214 senza misurarlo.

---

## 4. Che cosa questo significa, e che cosa no

**Significa** che la variabilità del modello non si esaurisce nei nomi: sposta
studi fra gruppi. E che la leva principale non è il riconoscimento dell'entità
— quello regge — ma **la normalizzazione del tipo di controllo**, che entra
nella chiave del cluster con lo stesso peso dell'entità.

**Non significa** che il deliverable v16b sia sbagliato. Significa che una
frazione dei suoi raggruppamenti dipende da una scelta lessicale che una seconda
esecuzione degli stessi stadi non riproduce. Quantificarla è esattamente lo
scopo di A3.

**Non è ancora la misura finale.** Questo è lo Stadio 3. Quanto di questo
movimento arrivi fino al deliverable dipende dal pooling: il gate dei controlli
interni potrebbe assorbirne una parte, o amplificarla. Lo dirà il re-pool.

---

## 5. Un errore di processo, registrato

Il primo tentativo di re-cluster (16 agosto) e il secondo (18 agosto, 32 worker)
sono stati **uccisi dall'OOM killer**: 18 processi il 16, 17 il 18. Il commit
`ebf21e5` afferma che il run del 16 si era fermato perché «la sessione è morta,
non c'è stato nessun errore»: **è falso**, ed è stato scritto senza controllare
il log del kernel. La causa era la stessa entrambe le volte.

Ogni worker teneva 16,7 GB residenti: 32 worker ne chiedono oltre 500 su una
macchina da 251 GB. Il valore di taratura registrato per lo Stadio 3 (32 worker,
9,2 GB *in tutto*) non vale per questa fase. Il run è passato con **8 worker**,
in 141,7 minuti — più veloce della stima di 4-6 ore che avevo dato.

**Da fare prima del re-pool:** verificare se la stessa taratura di memoria regge,
o se anche lì il numero di worker di default porta all'OOM.
