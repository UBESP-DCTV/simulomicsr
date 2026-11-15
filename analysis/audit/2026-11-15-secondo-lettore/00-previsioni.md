# Il secondo lettore: quale modello locale legge gli studi accanto a Mistral-Small 3.2

Depositato il 2026-11-15, prima di ogni corsa. Dopo i numeri questo file non cambia.

## La domanda

Il lavoro è ripreso il 2026-11-15 per decisione del PI. Nella prova coi modelli Claude via API (S12r6) un conto fatto
dopo i numeri ha mostrato questo: se si tengono solo gli studi dove due lettori diversi danno gli stessi gruppi e gli
stessi confronti, fra gli studi tenuti non resta nessuno dei 5 studi dove Mistral-Small 3.2 fa un errore di lettura
che costa (con Opus e Sonnet; con Haiku ne resta 1). Il secondo lettore di quella prova era un modello Claude, a
pagamento. Il PI ha chiesto un secondo lettore locale, che costa solo tempo sul DGX. La domanda è: **quale modello
locale, come secondo lettore accanto a Mistral-Small 3.2 nella forma `B0`, toglie gli studi con un errore di lettura
che costa e tiene abbastanza studi?** In più: un modello locale legge meglio di Mistral-Small 3.2?

## L'oggetto

- I 47 studi di sviluppo, vista v0 (`analysis/audit/2026-11-09-lettore-studio/60-viste-v0.jsonl`), forma `B0`: prompt
  v2 e schema delle uscite a elenco chiuso, uno per studio. L'ingresso è uguale byte per byte a quello della terza
  prova (S12r3), SHA-256 `36285df3…e8c7cba`. Gli 82 studi di giudizio restano chiusi.
- Il primo lettore è la corsa congelata di Mistral-Small 3.2 nella forma `B0` (`analysis/p4-output/S12r5-letture/B0.jsonl`):
  45 studi chiusi, gruppi identici ad Atlas in 36 su 47, 68 confronti ritrovati su 95.
- I candidati di questo primo giro (i primi tre dell'elenco di nove, quelli che il contenitore vLLM 0.20.2 carica):
  `Qwen/Qwen3-30B-A3B-Instruct-2507` (QW), `ibm-granite/granite-4.2-30b` (GR), `google/gemma-4-31B-it` (GE), a
  revisione fissata nel programma di lancio. Gli altri sei chiedono un contenitore più nuovo: avranno la stessa carta.
- Per ogni candidato due corse: `rp11` (`repetition_penalty` 1,1, come Mistral) e `rp0` (senza il parametro). Tutto
  il resto è uguale a Mistral: `temperature` 0, uscite strutturate, `max_model_len` 65536, `max_tokens` 24576,
  `VLLM_BATCH_INVARIANT=1`. Il ragionamento è spento per tutti. Solo `poddgx02`.
- Tentativi: al massimo due per candidato, con un solo cambio fra il primo e il secondo (per esempio senza
  `VLLM_BATCH_INVARIANT`, se il motore non parte). Ogni tentativo si scrive in `23-tentativi.md`. Un candidato che non
  parte in due tentativi è «non misurato», non «bocciato».

## Cancelli

1. **K1, riproduzione.** Lo script di misura ridà per Mistral-Small 3.2 nella forma `B0` 45 chiusi, 36/47, 68/95, e
   vede i 9 errori di lettura di `B0` nelle sue uscite (controllo positivo).
2. **K2, oggetto.** L'ingresso ha lo SHA-256 della terza prova. Prompt, generatore dello schema, vista e programma di
   lancio sono uguali ai file committati.
3. **K3, copertura.** Ogni corsa misurata ha 47 studi di sviluppo su 47, una riga per studio.
4. **K4, ambiente.** Ogni job gira su `poddgx02`. Le variabili d'ambiente chieste si leggono nel contenitore.
   `generation.json` è quello atteso. Ogni worker dichiara lo schema per record. Le uscite si congelano con SHA-256.
5. **K5, solo sviluppo.** Nessun fattore, confronto o uscita del modello sugli 82 studi di giudizio.

## Le misure

Per ogni corsa, con le funzioni della sessione con più letture (S12r5) e il riferimento a 95 confronti:

- (m1) studi chiusi su 47;
- (m2) studi con gruppi identici ad Atlas su 47;
- (m3) confronti di Atlas ritrovati su 95, e la differenza appaiata con Mistral `B0` (IC95 sugli studi);
- (m4) **l'accordo con Mistral `B0`**: uno studio è tenuto se i due lettori lo chiudono e danno gli stessi gruppi e
  gli stessi confronti. Conto: studi tenuti; fra i tenuti, quanti dei 5 studi con un errore di lettura di Mistral
  che costa (`GSE46665`, `GSE57945`, `GSE60340`, `GSE49155`, `GSE147507`); fra i tenuti, gruppi identici ad Atlas e
  confronti ritrovati;
- (m5) i 9 errori di lettura di `B0`: quali ha anche il candidato (predicati della sessione con più letture);
- (m6) per le repliche: studi con la stessa uscita al carattere, e con gli stessi gruppi e confronti, su 47.

Unità: lo studio. Ricampionamento: B = 10.000, seme 20261115.

## La regola di scelta, scritta prima

Per ogni candidato la corsa giudicata è quella con più studi tenuti in (m4). A pari, quella con `rp11`.

**Un candidato è ammesso come secondo lettore se valgono tutte e quattro:**

1. chiude almeno 40 studi su 47 (soglia del progetto: nella prova ripetuta, S12r2, il limite depositato era 7 studi
   non chiusi);
2. nell'accordo con Mistral `B0` tiene almeno 30 studi su 47 (variabilità misurata: Mistral con un altro schema
   contro Mistral `B0` ne tiene 30; i modelli Claude ne tengono 33-35);
3. fra gli studi tenuti non c'è nessuno dei 5 studi con un errore di Mistral che costa (regola del PI: nessuna
   soglia di errore accettata; Opus e Sonnet danno 0, Haiku 1);
4. la replica della corsa giudicata dà gli stessi gruppi e gli stessi confronti in 47 studi su 47 (la pipeline è
   deterministica; l'uguaglianza al carattere si riporta accanto).

La replica si lancia solo per i candidati che passano i punti 1-3. Fra più candidati ammessi si sceglie quello che
tiene più studi; a pari, quello con più confronti ritrovati fra i tenuti.

**Un candidato è un possibile primo lettore** se chiude almeno 45 studi e la differenza appaiata in (m3) con Mistral
`B0` ha l'intervallo al 95% tutto sopra 0. Solo in quel caso leggo tutte le sue schede di disaccordo con Atlas, con
una revisione indipendente, prima di dire qualcosa sui suoi errori di lettura. Senza quella lettura nessun candidato
è dichiarato «migliore di Mistral».

## Previsioni

Le basi sono deboli: nessuno di questi modelli ha mai letto questi studi nella forma `B0`. I margini sono un giudizio
motivato (lo dico al PI), tranne dove è scritta una soglia.

| # | quantità | QW | GR | GE | intervallo di rilevanza |
|---|---|---|---|---|---|
| P1 | studi chiusi su 47 (corsa giudicata) | 41 | 38 | 44 | ≥ 40 (punto 1 della regola) |
| P2 | confronti ritrovati su 95 | 55 | 48 | 66 | differenza appaiata con Mistral: IC95 sopra, sotto o a cavallo di 0. Attesa: QW e GR sotto 0, GE a cavallo |
| P3 | studi tenuti nell'accordo con Mistral `B0` | 27 | 24 | 32 | ≥ 30 (punto 2) |
| P4 | dei 5 studi con un errore che costa, fra i tenuti | 0 | 0 | 1 | 0 (punto 3) |
| P5 | `rp11` contro `rp0`: studi chiusi | differenza entro 3 studi per tutti | | | oltre 3 studi la penalità entra nella scelta della configurazione |
| P6 | replica: stessi gruppi e confronti | 47 | 47 | 47 | 47 su 47 (punto 4). Per GE l'uscita al carattere non è uguale (visto nella prova cieca, S12p) |
| P7 | candidati ammessi dalla regola | 1 dei 3 (GE) | | | 0 ammessi = il secondo lettore locale non c'è in questo giro |
| P8 | possibile primo lettore | nessuno | | | uno o più = si aprono le schede |

Perché questi valori: Gemma-4-31B nella prova cieca (S12p) è stato il modello con meno accuse sbagliate, e ha uscite
stabili nei verdetti. Qwen3-30B-A3B ha 3 miliardi di parametri attivi per token: attendo più errori di forma con uno
schema fino a 222.556 caratteri. Granite è il meno provato su uscite strutturate lunghe. Il modello più grande della
prova ripetuta (Mistral-Small-4-119B) ha fatto peggio di Mistral-Small 3.2: la taglia non è una base per attese alte.

## Limiti dichiarati prima

- I 47 studi di sviluppo sono già serviti a sei prove. La scelta fra tre (poi nove) candidati sugli stessi studi
  gonfia il migliore. La conferma è la misura sugli studi curati da Gemma (UBC), che viene dopo e ha la sua carta.
- I 5 studi con un errore che costa sono pochi: «0 su 5 fra i tenuti» è una prova debole. Non misura gli errori che
  i due lettori fanno uguali.
- L'accordo fra lettori è nato come conto dopo i numeri in S12r6. Questo è il primo uso con la regola scritta prima.
- L'accordo toglie studi, non li corregge. Quanti studi restano su tutto ARCHS4 non si deduce da 47 studi.
- La regola «nessun Claude nella pipeline» resta: qui tutti i lettori sono locali.
