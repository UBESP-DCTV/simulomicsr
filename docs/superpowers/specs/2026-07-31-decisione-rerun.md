# La decisione sul re-run, rifatta sui numeri

**Data:** 2026-07-31 · **Branch:** `review-scientific-consistency-2026-06-10`
**Perché esiste:** avevo raccomandato «solo re-pool» pesando il costo. Il costo non è un argomento
scientifico, e la raccomandazione era **sbagliata**. Rifatta partendo da una domanda che non mi ero
posto.

---

## 1. RITRATTAZIONE — «solo re-pool» è l'unica opzione senza contenuto

**Che cosa cambia un re-pool?** Se il codice del pooling non è cambiato e i cluster non sono
cambiati, riproduce gli stessi numeri.

Verificato: dal commit del run v13 (2026-07-29), gli unici file `R/stage3-*` o `R/stage4-*`
modificati sono `stage3-entity-label.R` (etichette — verificato il 2026-07-29 che `canonical_name`
non entra nel pooling) e `stage4-coherence-annotation.R` (annotazione), più i tre file nuovi di
oggi, che sono anch'essi annotazione.

> **Nessuna riga del calcolo dell'effetto è cambiata. Un re-pool sarebbe 28 ore per rifare un file
> identico.** L'unico motivo che avevo per proporlo — «così il deliverable esce dalla pipeline» — è
> già soddisfatto: `annotate_stage4_deliverable()` produce lo stesso deliverable dall'output
> esistente, verificato **20 colonne su 20 identiche**.

Le opzioni vere sono due, non tre.

## 2. Le due opzioni

### (A) Nessun re-run

I risultati attuali restano. La frammentazione resta un limite dichiarato (finding 2026-07-28 §8).
Costo: zero.

### (B) Re-cluster + re-pool con una regola di de-frammentazione

~9 h + ~28 h. Cambia i gruppi, quindi ha contenuto. **Quanto?** Misurato con la funzione di
dispatch vera, la stessa del run, sull'unione degli assignment:

| entità | studi-slot censiti | **studi POOLATI** | giudizio |
|---|---:|---:|---|
| **TGF-β1** `HGNC:11766` ← `STR:tgfb` + `STR:tgf_b` | 65 → **79** | **49 → 59 (+10)** | ammissibile |
| **Glioblastoma** `MeSH:D005909` ← `STR:glioblastoma` | 3 → **9** | 2 → **3 (+1)** | ammissibile |
| IL17A `HGNC:5981` ← `STR:il17` | 8 → **11** | 7 → **8 (+1)** | ammissibile per la regola del §4 |
| ~~IFNA1/IFNA2 ← `STR:ifna`~~ | — | — | **NO: ambiguo** |

**TGF-β1 è la figura 2 del main paper: passerebbe da 49 a 59 studi (+20%).** Glioblastoma oggi è
**fuori** dal deliverable (k_eff=2, sotto la soglia): entrerebbe come meta-analisi nuova.

**Non c'è un tesoro nascosto sotto soglia.** Misurato su tutti gli 11.541 `cgroup`: dei 7.756 con
entità `STR`, solo **142 agganciano un ID ontologico in modo univoco** (5 in modo ambiguo, 7.609
nessuno), per **198 studi-slot** in tutto. I gruppi del deliverable sono quasi tutta la storia.

## 3. Che cosa costa la verifica, davvero

Avevo scritto che un re-cluster «riapre il censimento di coerenza». **Sovrastimato.** La procedura
del 2026-07-28 è: si confrontano gli insiemi dei membri gruppo per gruppo, quelli identici tengono
il verdetto, si rileggono solo i cambiati. Qui **cambiano 3 gruppi** e ne spariscono 4 (assorbiti).
Sono un'ora di lettura, non un censimento.

## 4. La regola, e perché non è una lista

> Un'entità `STR` si fonde in un ID ontologico **se e solo se** la sua forma normalizzata coincide
> con un alias **per esteso** (>3 caratteri) di **esattamente una** entità risolta presente nel
> corpus, con lo **stesso verso** e lo **stesso tipo di controllo**. Ambiguo → **non si fonde**, e
> lo si dichiara.

È meccanica e verificabile, non una lista di casi:

- include `il17` perché nel corpus esiste **un solo** gruppo IL17;
- esclude `ifna` perché nel corpus esistono **due** gruppi (IFNA1 e IFNA2) e la stringa non dice
  quale — fonderla in uno dei due sarebbe un errore di identità, la classe che questo rework ha
  eliminato;
- il vincolo «alias per esteso >3 caratteri» è quello già pagato il 2026-07-29, quando un match su
  una **sigla** (`LTA`) fece dare per buono un ID sbagliato.

## 5. L'argomento che pesa di più, e non è la potenza

Il gruppo `HGNC:11766` **contiene già** membri etichettati solo `TGF-beta`, `TGFbeta`, `TGF-Beta`,
`TGF-β` (verificato leggendo i membri). Tenere fuori `TGFb` e `TGF-B` non è una distinzione
scientifica: è un incidente del resolver.

> Nei Methods, «abbiamo trattato `TGF-beta` e `TGFb` come entità diverse» **non si può scrivere**.
> La frammentazione attuale non è un limite del dato: è un'incoerenza interna del metodo, e un
> revisore la trova.

Questo, più della potenza, è il motivo per cui (B) è più difendibile di (A).

## 6. Raccomandazione

**(B), a tre condizioni**, che sono la disciplina già usata il 2026-07-28:

1. **La regola si scrive con i test prima**, e le sue asserzioni si vedono fallire.
2. **Il suo effetto si misura su TUTTI i membri prima del lancio** — non solo sui 5 casi trovati.
   Una regola che agisce su tutto il corpus ha effetti che vanno contati, non supposti.
3. **I 3 gruppi che cambiano composizione si rileggono** dopo il re-cluster, e i verdetti si
   aggiornano solo lì.

Costo prima del lancio: scrittura + misura della regola. Il re-run (~37 h) parte dopo, e in un fine
settimana ci sta.

## 7. Che cosa NON dimostra questa analisi

- **Il guadagno è modesto in valore assoluto**: +11 studi poolati e una meta-analisi nuova su 191.
  Chi preferisse (A) e dichiarasse il limite non farebbe una scelta sbagliata — farebbe una scelta
  più conservativa.
- **Il rilevatore di frammentazione è stato cieco alla prima stesura** (filtrava su un valore di
  `fonte` che non esiste, `"STR"` invece di `"str_literal"`, e trovava zero). Corretto e
  ri-verificato: è il motivo per cui il numero del §2 è 5 entità e non «nessuna».
- **Non ho misurato** se la regola, applicata a tutto il corpus, cambi gruppi che oggi sono sotto
  soglia in modi non previsti. È esattamente la condizione 2.
