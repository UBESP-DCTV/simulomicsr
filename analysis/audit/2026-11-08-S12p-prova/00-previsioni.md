# S12p — La prova cieca dello Stadio 2b: cancelli e previsioni

**Depositate:** 2026-11-08, prima dello smoke e prima di ogni uscita dei modelli. Il riferimento
(`analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv`) non è stato aperto in
questa sessione e non si apre finché le uscite dei tre modelli non sono su disco con SHA-256 committate.

**Oggetto.** I 1.903 confronti del deliverable A3 v16
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d` (194 meta-analisi),
con l'ingresso congelato `analysis/audit/2026-11-07-S12-stadio2b-disegno/28-ingressi-1903.jsonl.gz` (impronte in
`91-sha256.txt`, verificate 8 su 8 all'inizio della sessione). Schema, prompt e regola alle versioni di quelle
impronte. Tecnica dell'H5: `20-campi-h5-campioni.rds`.

**Modelli** (handout S12p, punto 1), revisioni fissate nella cache del progetto:

| modello | revisione | formato |
|---|---|---|
| `mistralai/Mistral-Small-3.2-24B-Instruct-2506` (produzione) | `95a6d26c4bfb886c58daf9d3f7332c857cb27b43` | mistral |
| `mistralai/Magistral-Small-2509` | `a31cc96ab10cf19bc42c628fedf1e359e0853c49` | mistral |
| `google/gemma-4-31B-it` | `842da3794eaa0b77d5f08bae87a17459d91ff475` | HF (`Gemma4ForConditionalGeneration`, servito da vLLM 0.20.2: verificato nel registro dei modelli del container) |

**Configurazione identica** (spec §7): temperatura 0, `repetition_penalty` 1.1, `VLLM_BATCH_INVARIANT=1`,
`max_model_len` 32.768, `max_tokens` 6.144, structured output sullo schema `comparison_check.stage2b.v1`, 4 GPU
per job su `poddgx02`. Cambiano solo i campi del modello (`model_id`, formato del tokenizer e dei pesi, e per
Gemma la parte visiva spenta). **Magistral è un modello che ragiona prima di rispondere**: con l'uscita
strutturata dal primo token e il prompt del progetto (senza il prompt di sistema di Magistral) risponde senza la
fase di ragionamento. La prova misura i tre modelli con la stessa configurazione, come chiede l'handout; non
misura Magistral nel suo modo di ragionamento, e il finding lo dice.

**Conteggio dei token.** Il limite del prompt è 32.768 − 6.144 = 26.624 token. La spec lo stimava con 3
caratteri per token. Qui il runner conta i token di ogni confronto con il tokenizer del modello, nello stesso
percorso di preparazione di `llm.chat()`. Un confronto oltre il limite non va al modello e la regola lo scarta
con `INGRESSO_INCOMPLETO` (handout, dubbio ricevuto b). Il limite si applica quindi per modello.

**Cascata di recupero** (spec §7). Un'uscita che non passa la validazione sullo schema (`jsonvalidate`, motore
`ajv`) si rifà con `repetition_penalty` 1.2, poi 1.3, poi 1.4; se resta non valida, la regola dà
`LISTA_NON_VALIDA`. Il conto la riporta a parte.

**Unità:** il confronto. **Intervallo:** Wilson al 95% su ogni frazione. **Seme:** 20261108 (scelta dei
confronti dello smoke). **Smoke:** 20 confronti per ciascuno dei tre modelli (l'handout ne chiede uno: li
provo tutti e tre, perché un modello che non parte si scopre prima della notte): 18 a caso con il seme, il
confronto più lungo entro il limite stimato (22.547 token stimati, 105 campioni) e l'unico oltre il limite
stimato (40.081 token stimati, 117 campioni). Dopo lo smoke: STOP, rapporto al PI, poi il lancio pieno.

**Che cosa conta come «accusato».** Un confronto è accusato se `stage2b_decide()` dà `passa = FALSE` con la
tabella degli esiti decisa dal PI il 2026-11-08 (`stage2b_esiti_default()`), compresi `INGRESSO_INCOMPLETO` e
`LISTA_NON_VALIDA`. Presi = accusati fra i 193 difettosi; falsi allarmi = accusati fra i 1.710 puliti.

## Cancelli (binari: se uno fallisce la sessione non vale)

| # | cancello | come si verifica |
|---|---|---|
| K1 | Integrità dell'ingresso: le impronte di `91-sha256.txt` passano all'inizio e alla fine; in ogni bundle `prompt.txt` è byte per byte `.s2b_prompt_sistema()`, `schema.json` è lo schema delle impronte, e il `testo` di ogni confronto è identico a quello di `28-ingressi-1903.jsonl.gz` | `sha256sum -c`, script dei bundle |
| K2 | Configurazione verificata sull'artefatto: `VLLM_BATCH_INVARIANT=1` nel `container-env.txt` di ogni run; ogni job su `poddgx02` (`sacct`); `generation.json` uguale fra i tre modelli a meno dei soli campi del modello | script della catena |
| K3 | Copertura: per ogni modello, 1.903 confronti su 1.903 hanno un esito della regola (lista valida, `LISTA_NON_VALIDA` dopo la cascata, o `INGRESSO_INCOMPLETO`); nessun confronto perso o doppio | script della catena |
| K4 | Ripetibilità e conteggio: i 20 confronti dello smoke, rifatti nel run pieno, danno un'uscita byte per byte identica (20 su 20, per modello); il conteggio dei token prima della generazione coincide con quello di vLLM in tutti i confronti generati | script della catena |
| K5 | Cecità e controllo positivo del conto: le SHA-256 delle uscite sono committate prima del commit dello script del conto, che è il primo a leggere il riferimento; lo script, con un esito che accusa esattamente i 193, dà 193 su 193 presi e 0 su 1.710 falsi allarmi, e con un esito che non accusa nessuno dà 0 e 0 | `git log`, script del conto |

## Previsioni

**Già depositate in S12** (`analysis/audit/2026-11-07-S12-stadio2b-disegno/00-previsioni.md`, commit `f8228f5`),
si giudicano qui senza cambi: **P4** difetti presi ≥ 130 su 193 (rilevanza [130, 193], cancello di ADR-0028);
**P5** puliti accusati ≤ 40 su 1.710 (rilevanza [0, 40], cancello di ADR-0028); **P6** quota di assi
`not_stated` < 30% sui 11 × 1.903 assi (rilevanza [0%, 30%]). Le stesse soglie valgono per gli altri due modelli.
Il cancello di ADR-0028 è passato da un modello se P4 e P5 sono confermate per quel modello.

**P11 — Confronti oltre il limite con il conteggio vero.** Quantità: confronti su 1.903 il cui prompt supera
26.624 token con il tokenizer del modello. **Atteso: 1 per Mistral e Magistral** (lo stesso tokenizer; il
confronto da 117 campioni ha circa 120.000 caratteri, e il tokenizer dovrebbe fare più di 3,5 caratteri per
token sul testo dei metadati), **da 0 a 2 per Gemma**. **Intervallo di rilevanza: da 0 a 19.** Motivo: lo
stesso di P1 e P7; ogni confronto oltre il limite è scartato senza lettura, e 19 confronti puliti
consumerebbero metà del margine di 40 falsi allarmi.

**P12 — Liste non valide dopo la cascata.** Quantità: confronti su 1.903, per modello, che restano senza una
lista valida sullo schema dopo i tre giri di recupero. **Atteso: da 0 a 5.** **Intervallo di rilevanza: da 0 a
19.** Motivo: come P11, una lista non valida scarta il confronto senza lettura.

**P13 — Citazioni trovate nel testo.** Quantità: quota delle citazioni non nulle (tutti i campi `evidence*`
della lista) che compaiono per intero nel testo d'ingresso del confronto, per modello. **Atteso: almeno 90%.**
**Intervallo di rilevanza: da 80% a 100%.** Motivo (giudizio, da dire al PI): la regola si fida dei fatti del
modello (spec §8). Sotto l'80%, più di una citazione su cinque non viene dal testo; allora la versione 2 della
regola deve verificare le citazioni prima di usarle, e i Methods non possono dire che la lista è ancorata al
testo. È una diagnostica: non cambia il conto.

**P14 — Durata (informativa).** Quantità: ore di job per modello per i 1.903 confronti, 4 GPU. **Atteso: da 1 a
4 ore** (8,1 milioni di token d'ingresso; risposta attesa intorno ai 1.500 token). **Intervallo di rilevanza:
sopra 24 ore.** Motivo: sopra 24 ore per 1.903 confronti, il ricalcolo finale su tutti i candidati non sta nel
piano dell'handout e va ristimato prima.

## Che cosa la prova non decide

- Non cambia prompt, schema, regola o tabella degli esiti dopo il conto (handout S12p): una versione, un conto.
- Non giudica i due confronti del controllo cancellato da GEO (studio dell'ipossia): il conto li riporta a parte.
- I falsi allarmi del modello migliore si leggono tutti, dopo il conto: errore del modello, della regola, o del
  riferimento (handout, punto 5; dubbio ricevuto d).
