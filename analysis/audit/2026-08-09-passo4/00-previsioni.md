# PASSO 4 — previsioni depositate PRIMA di guardare qualunque incrocio

**Depositato:** 2026-08-09, prima di costruire la matrice di accordo fra giudici.

**Domanda:** il gate di coerenza dà 25, 58 o 97 incoerenti a seconda di chi legge.
Su *che cosa* i giudici divergono, e il consenso è predetto da un segnale deterministico?

## Giudici disponibili (dichiarato, incluso ciò che manca)

| giudice | base | fonte | persistito? |
|---|---:|---|---|
| lettura umana 5 agosto | 214 | `analysis/audit/2026-08-05-rilettura-214/verdetti-rilettura-214.csv` | sì |
| Mistral, 5 giri, **senza** flag | 214 | `mistral/pred5x.jsonl` (1.070 righe) | sì |
| Mistral, 5 giri, **con** flag | 213 | `mistral/bi_coe.jsonl` (1.070 righe) | sì |
| Claude, 2026-08-09 (92/64/58) | 214 | — | **NO: non è stato salvato come tabella** |

⚠️ **Omissione dichiarata:** il giudice Claude non è ricostruibile dai file esistenti.
L'analisi parte dai tre persistiti. Se servirà, si rigenera solo sui casi divergenti,
non su tutti e 213.

⚠️ I due Mistral **non sono giudici indipendenti**: sono lo stesso modello con e senza
la flag di batch-invarianza. Contano come UN giudice con due esecuzioni.

## P1 — il nucleo su cui tutti concordano

Percentuale delle 213 in cui lettura-5-agosto e Mistral-con-flag danno lo **stesso**
verdetto a tre livelli: **35–55%**. (Riferimento noto: Mistral e Claude concordavano
sul 44,1%.)

## P2 — la direzione del disaccordo

Nei casi di disaccordo, la lettura del 5 agosto è **più severa** di Mistral in
**oltre l'85%** dei casi.

## P3 — il predittore

Esiste almeno un segnale del deliverable la cui differenza fra concordi e discordi
supera **d di Cohen 0,5**. Candidati, elencati PRIMA di misurarli:
`k_effective`, `k_kish`, `quota_top1`, `dominato`, `frazione_efficace`, `materiale_misto`,
`I2_med`, `n_sig`, `n_studi_poolati`, `studi_caduti`, `stessi_membri`,
`dominato_da_modello`, tipo di entità (`STR:` contro ID ontologico),
`contrast_entity_source`, numero di confronti imperfetti (audit 5 agosto).

**Il candidato più probabile, dichiarato prima: `k_effective`** — più studi ci sono,
più è probabile che almeno uno sia discutibile, quindi più severità.

## P4 — il gate come codice

Una regola deterministica sui segnali sopra predice il consenso (entrambi i giudici
concordi «coerente») con precisione **> 0,80** e copertura **> 0,50**.

**Falsificata se** nessuna regola a ≤3 condizioni raggiunge quelle due soglie insieme.

## Difesa contro l'auto-inganno

- 213 righe e ~15 predittori: il rischio di trovare per caso un segnale «significativo»
  è alto. Ogni regola trovata va **rimisurata separando i dati in due metà** (per
  `cluster_id` ordinato), e si riporta il risultato sulla metà NON usata per trovarla.
- Nessun p-value verrà usato come criterio di decisione: si riportano dimensioni
  dell'effetto e conteggi, con i denominatori.
- Se la regola non regge sulla seconda metà, si dichiara che **non esiste** un
  predittore deterministico, che è un esito valido e utile.
