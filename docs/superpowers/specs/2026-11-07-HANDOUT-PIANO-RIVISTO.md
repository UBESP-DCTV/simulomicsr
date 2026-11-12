# HANDOUT — Il piano rivisto: lo Stadio 2b e la strada fino all'articolo

**Scritto:** 2026-11-07, dopo la valutazione autonoma
(`docs/findings/2026-11-07-valutazione-autonoma-del-progetto.md`, ADR-0028) · **Branch:**
`review-scientific-consistency-2026-06-10` · master invariato · **Deliverable corrente:** A3 v16
`/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d` (194
meta-analisi) · **Master da usare per ogni ricalcolo:** `analysis/p4-output/S14-stage{1,2}-master.jsonl`.

> **Come si usa.** Una sessione, un obiettivo. Ogni sessione dice perché, che cosa si fa, che cosa NON si
> fa, come si sa che è finita, che cosa decide il PI, e ha il prompt da incollare. Le sessioni già chiuse
> (S1-S11, S14 prima parte) e i prompt di S12b, S12c, S12d, S16, S17 stanno nell'handout del 2026-08-21
> (`2026-08-21-HANDOUT-DIFETTI-APERTI.md`): qui non sono ricopiati. **Questo file comanda l'ordine.**
>
> **Decisione del PI (2026-11-07):** si tiene ETL, master S14, Stadio 4, gold, verdetti e strumenti di
> audit; si **sostituisce** il modo in cui la pipeline decide se due bracci sono confrontabili. Il
> rilevatore a regole di S10-S10b **non va in produzione**: resta strumento di audit, e i 193 confronti
> difettosi (`analysis/audit/2026-11-07-S11-lettura-falsi-allarmi/41-riferimento-dopo-S11.csv`) sono il
> banco di prova **cieco** di ogni modello e di ogni prompt.

## Il quadro in cinque righe

- 194 meta-analisi; 193 confronti difettosi su 1.903 (10,1%), 85 categorie, 55 con un solo caso.
- L'88% dei difetti nasce prima della chiave dello Stadio 3 (65% bracci non appaiati, 23% seconda
  perturbazione persa); la chiave ne spiega l'8%. Le regole a valle ne vedono il 42%.
- Il lettore che guarda il testo grezzo dei due bracci li trova (kappa 0,78; umano 18/19). Non è mai stato
  uno stadio della pipeline. Lo diventa: **Stadio 2b** (ADR-0028).
- La biologia regge (30/31 bersagli; DHT contro enzalutamide −0,944); il motore statistico non si tocca.
- Nessuno ha pubblicato il passo «confronti da LLM → meta-analisi fra studi»; la finestra si stringe
  (Soul & Young, GEOMeta, Wren: agosto 2026).

## La mappa

| # | sessione | tipo | durata stimata (×2 nella pratica) | serve prima |
|---|---|---|---|---|
| **S12** | Stadio 2b: il disegno (ADR già scritto; lista di controllo, regola, prompt, previsioni) — **chiusa il 2026-11-08** (4 decisioni + campioni cancellati da GEO tolti in S13; campi GEO nell'ingresso) | carta + codice della regola (TDD) | ~4 h | — |
| **S12p** | La prova che decide: 3 modelli sui 1.903, conto cieco — **fatta il 2026-11-08: nessun modello passa** (presi 186/177/155 su 193, falsi allarmi 965/887/364 su 1.710); lettura dei falsi allarmi: 318 confronti «puliti» non confrontabili per i lettori (280 confermati); prompt v2 e codice da solo non bastano; **diagnosi: metà dei 473 difetti nasce nella scelta del confronto dello Stadio 2, tre su dieci nello Stadio 1** | DGX + 1 sessione | ~3 h + 1 notte | **S12** |
| **S12q** | La strada dopo S12p: **il lettore dello studio e la tabella dei fattori** (ADR-0029). Disegno approvato dal PI il 2026-11-09, piano approvato il 2026-11-10. **Chiusa il 2026-11-10** | disegno + piano | fatta | **S12p** |
| **S12r** | Piano 1 «fondamenta e prova»: costruttore dei confronti e misure contro Expression Atlas (TDD), misura della pipeline di oggi, prova da buttare con Mistral sui 47 studi di sviluppo. **Fatta il 2026-11-10: i 5 cancelli passano, la regola di esito non è soddisfatta** (gruppi identici 14/47 per il lettore e per oggi; confronti ritrovati 10 contro 19 su 93; 24 studi non chiusi, 18 per la forma delle voci). **Chiusa il 2026-11-10** con due decisioni del PI: prova ripetuta, tempo zero fuori dal riferimento | codice (TDD) + DGX breve | ~2 sessioni | **S12q** |
| **S12r2** | La prova ripetuta sugli stessi 47 studi di sviluppo: schema e prompt corretti, Mistral e uno o due modelli più grandi, riferimento senza il tempo zero come controllo, previsioni nuove prima. STOP: il PI decide se si scrive il Piano 2. **Fatta il 2026-11-10: la regola di esito dà no per i tre modelli; modello deciso (Mistral-Small 3.2), Qwen non si riprova. **Chiusa il 2026-11-11** con la terza decisione del PI: prima del Piano 2 una terza prova piccola** | carta + codice (TDD) + DGX breve | ~1-2 sessioni | **S12r** |
| **S12r3** | La terza prova piccola sugli stessi 47 studi di sviluppo: schema delle uscite generato per ogni studio, con colonne e valori a elenco chiuso e una voce per valore; solo Mistral-Small 3.2; previsioni nuove prima. STOP: il PI decide se si scrive il Piano 2. **Fatta il 2026-11-11: i 5 cancelli passano; 45 studi chiusi su 47, gruppi identici 36/47, confronti ritrovati 68/95 (oggi 13/95); la regola di esito dà no per il solo punto 4 (errori di lettura del modello in 4 studi). **Chiusa il 2026-11-12** con la decisione del PI: prima del Piano 2 una sessione breve sulle cause degli errori di lettura** | carta + codice + DGX breve | ~1 sessione | **S12r2** |
| **S12r4** | Dove nasce ogni errore di lettura del lettore: stessi 47 studi di sviluppo, solo Mistral-Small 3.2, un cambio per volta fra la forma dell'uscita v1 e quella generata per ogni studio (schema e prompt), più le due correzioni di forma dello schema; previsioni nuove prima. STOP: il PI decide se si scrive il Piano 2. **Fatta il 2026-11-12: i 5 cancelli passano; 31 forme, 32 corse; 58 errori di lettura in 32 studi su 47: della forma 14, del modello 2, non deciso 42; col placebo la tabella dei fattori cambia in 5-9 studi su 47; forma finale secondo la regola: quella di S12r3, senza cambi. Chiusa il 2026-11-12** con le due decisioni del PI: la forma dell'uscita è quella di S12r3 senza cambi; prima del Piano 2 la sessione S12r5 | carta + codice + DGX breve | fatta | **S12r3** |
| **S12r5** | Più letture dello stesso studio: stessi 47 studi di sviluppo, solo Mistral-Small 3.2, forma dell'uscita `B0`, frasi del prompt riscritte senza cambiare il senso; una regola sulla discordanza fra le letture, scritta prima, che segnala soltanto; previsioni nuove prima. STOP: il PI decide se si scrive il Piano 2 | carta + codice + DGX breve | ~1 sessione | **S12r4** |
| **S12s** | Piano 2 «il lettore nel pacchetto» (da scrivere dopo S12r5, se il PI lo decide): testi GEO di tutti gli studi, vista, schema, prompt, modello, cancello (giudizio A, poi B). STOP | codice + DGX | da definire | **S12r5** |
| **S12c** (+S12b dentro) | La chiave senza ID del modello; greche, latine, negazione | ADR + codice (TDD) + misura | ~6 h | S9 ✅ |
| **S12d** | Tabelle dei nomi agganciate ai campioni | codice (TDD) + misura | ~4 h | S10 ✅ |
| **S13** | Piano 3 (da scrivere dopo il cancello): corsa del lettore su tutti gli studi, chiave, varianza, ruoli, doppi, re-cluster, re-pool, deliverable v17 | calcolo | da definire | **S12s, S12c, S12d** |
| **S15** | Rilettura cieca delle meta-analisi nuove | lettura | 1 sessione | **S13** |
| **S7c** | Seconda validazione esterna con nullo + firme di consenso | misura | ~6 h | **S13** |
| **S7b** | Meta-analisi pubblicate sugli stessi GSE (supplementare) | misura | ~3 h | **S13** |
| **S16** | Figure | produzione | ~4 h | S15, S7c |
| **S17** | Methods e limiti | scrittura | ~4 h | tutto |

**Cancellate:** «S12 — il rilevatore in produzione» (handout di agosto) e «S14 seconda parte» (assorbita in
S13: il re-cluster si fa una volta sola). **Cancelli veri:** S12r←S12q, S12r2←S12r, S12r3←S12r2, S12r4←S12r3, S12r5←S12r4, S12s←S12r5 (decisione del PI),
S13←S12s (cancello su Atlas)+S12c+S12d, S15←S13, S7c←S13.

**Dal 2026-11-09 (ADR-0029):** lo Stadio 2b esce dal piano. Dove questo handout scrive «Stadio 2b» nelle sezioni
S13, S16 e S17, leggi «il lettore dello studio». Branch di lavoro: `p6-tabella-dei-fattori`.

**Se S12p fallisce** (nessun modello prende ≥130/193 con ≤40 falsi allarmi su 1.710): STOP, ADR-0028 torna
`Proposed`, sessione di decisione del PI fra (i) regole come in agosto, (ii) fine-tuning sul gold del progetto
(756 campioni + 193/1.710), (iii) prompt diverso. Non si va a S13.

---

# S12 — Stadio 2b: il disegno

> **Stato (2026-11-08): sessione chiusa.** Le quattro decisioni sono prese (tutte come raccomandato); l'ingresso
> contiene i campi GEO; decisione del PI: un campione cancellato da GEO **si toglie** nel ricalcolo finale (S13). Parte 2: testi GEO di 993
> studi congelati (`analysis/p4-output/S12-geo-campioni-20261108/`, copia su micron), ingresso nuovo
> `analysis/audit/2026-11-07-S12-stadio2b-disegno/28-ingressi-1903.jsonl.gz` (impronte `91-sha256.txt`); cancello
> G2 fallito come scritto per 2 campioni su 15.559 cancellati dallo staff di GEO il 2024-10-12 (spiegato e marcato
> nell'ingresso); P7-P10 confermate (finding §10).
>
> **Stato (2026-11-07): disegno fatto, in attesa di quattro decisioni del PI.** Spec
> `docs/superpowers/specs/2026-11-07-stadio-2b-design.md`, finding `docs/findings/2026-11-07-S12-stadio2b-disegno.md`
> (riassunto «In breve» in testa). Su disco: schema `inst/schemas/comparison_check.stage2b.v1.json`, prompt
> `inst/prompts/stage2b-v1.md`, regola `R/stage2b-rule.R`, ingresso `R/stage2b-input.R`, test verdi, ingresso
> congelato dei 1.903 confronti con impronte (`analysis/audit/2026-11-07-S12-stadio2b-disegno/90-sha256.txt`).
> Cancelli C1-C5 passati; P1 e P3 confermate, P2 smentita come scritta e spiegata (testo ripetuto, non tagliato;
> codifica UTF-8 doppia e tripla dell'H5 trovata e riparata nell'ingresso). Decisioni del PI: (1) aggiungere
> all'ingresso `description`, `treatment_protocol_ch1`, `growth_protocol_ch1` da GEO; (2) donatori diversi nei
> confronti malati contro sani = avviso; (3) non detto e casi incerti = avviso; (4) voce aperta «altre differenze»
> = errore. Se la (1) è sì, la sessione prepara lo scaricamento congelato per i 993 studi e rifà l'ingresso
> prima di chiudere.

### Perché
Il giudizio di confrontabilità deve vedere il testo intero dei due bracci. Prima del calcolo servono: la
lista di controllo, la regola che decide, il prompt, i campi d'ingresso, e le previsioni depositate.

### Che cosa si fa
1. Leggi ADR-0028 e il finding della valutazione (§3-§5). Non riscriverli.
2. Spec `docs/superpowers/specs/2026-11-XX-stadio-2b-design.md`: schema JSON della lista di controllo
   (`inst/schemas/comparison_check.stage2b.v1.json`), con per ogni voce `uguale | diverso | non_detto` e
   la citazione; elenco agenti per braccio; tempo di raccolta per braccio; entità per nome.
3. Ingresso: per ogni confronto, i campioni dei due bracci con `title`, `source_name_ch1`,
   `characteristics_ch1`, `extract_protocol_ch1`, `instrument_model`, `library_selection`,
   `data_processing` dall'H5. Misura quante stringhe toccano il limite di lunghezza (regola «lo strumento
   deve vedere il dato intero»).
4. La regola deterministica in `R/stage2b-rule.R` con test (TDD): passa / non passa / motivo. Tempo zero
   e differenza tecnica sono sempre errore (decisione del PI, S11).
5. Prompt in `inst/prompts/stage2b-v1.md`. Nessun esempio preso dai 193.
6. Previsioni depositate in `analysis/audit/2026-11-XX-S12-stadio2b-disegno/00-previsioni.md`: «≥130/193
   presi; ≤40/1.710 accusati; `non_detto` sotto il 30% delle voci». Commit prima della prova.

### Che cosa NON si fa
- Non si apre `41-riferimento-dopo-S11.csv` né `difetti.csv` per scrivere il prompt o la regola.
- Nessun run sul DGX. Nessuna modifica allo Stadio 1, 2, 3, 4.

### Come si sa che è finita
Spec, schema, regola con test verdi, prompt, previsioni: tutti committati. Il PI ha letto la lista di
controllo e la regola.

### La decisione che spetta a te
Le voci della lista di controllo e la regola: che cosa è sempre errore, che cosa passa con avviso.

### Prompt
```
sessione simulomicsr S12, leggi prima la skill di progetto.
Il deliverable e' /mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d (194).
Handout: docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md, sezione S12. ADR-0028.
Obiettivo: disegno dello Stadio 2b (schema, regola con test, prompt, previsioni). Nessun run. Non aprire i file dei 193 difetti.
```

---

# S12p — La prova che decide

> **Stato (2026-11-08): prova fatta, cancello di ADR-0028 non passato.** Finding
> `docs/findings/2026-11-08-S12p-prova-cieca-stadio2b.md` (riassunto in testa), evidenza
> `analysis/audit/2026-11-08-S12p-prova/`. Presi su 193 / falsi allarmi su 1.710: Mistral 186 / 965, Magistral 177 /
> 887, Gemma 155 / 364. Lettura cieca (decisione del PI) dei falsi allarmi di Gemma e Mistral: 238 su 360 e 299 su 962
> sono non confrontabili per i lettori (318 confronti in tutto, 197 studi); Mistral scrive la malattia del donatore
> come agente (301 su 315 false); la voce aperta riporta fatti veri che non sono difetti (334 su 606). ADR-0028 torna
> `Proposed`; non si va a S13. Decisioni del PI aperte nel riassunto del finding: controllo a mano dei 318 difetti e
> strada (S12q). La verifica dei 318 l'ha fatta l'agente con una seconda lettura: 280 confermati. Su richiesta del PI:
> prompt v2 di Mistral e confronto per solo codice non bastano (finding §13); **diagnosi** (§14,
> `00-previsioni-diagnosi.md`, `130`-`133`): 240 dei 473 difetti hanno la differenza nei fatti che lo Stadio 2 riceve
> (il prompt dello Stadio 2 non chiede bracci uguali e permette il tempo zero come controllo), 139 nascono nello Stadio 1
> (letta nel titolo o in `characteristics`, non scritta), 36 nella firma, 35 in campi che nessun passo legge, 21 nel
> nome; i master S14 hanno gli stessi gruppi e confronti di A3 in 993 studi su 993. La sessione resta aperta: due
> decisioni del PI nel riassunto (i 280 nel riferimento; dove correggere per primo).

> **Ricevuto da S12 (2026-11-07 e 2026-11-08), da leggere per primo.** (a) Configurazione, ingresso congelato e
> conto: spec `docs/superpowers/specs/2026-11-07-stadio-2b-design.md` §7. **L'ingresso è
> `28-ingressi-1903.jsonl.gz`, non `20-…`**: verifica le impronte di
> `analysis/audit/2026-11-07-S12-stadio2b-disegno/91-sha256.txt` prima del lancio. (b) Il limite di 26.624 token
> usa una stima di 3 caratteri per token: lo smoke misura il conteggio vero di vLLM. Un confronto su 1.903
> (117 campioni; 40.081 token stimati con i campi GEO) è oltre il limite e la regola lo scarta con `INGRESSO_INCOMPLETO`; se il
> conteggio vero lo fa stare nel limite, va mandato al modello. (c) Nel conto, separa i segnali calcolati dal
> codice (`TECNICA_H5_*`) da quelli del modello, e riporta la quota di citazioni trovate per intero
> nell'ingresso. (d) Il PI ha detto sì alla decisione 1 di S12: l'ingresso contiene anche descrizione e protocolli
> presi da GEO, che i lettori dei 193 non hanno visto; i falsi allarmi che nascono da lì si leggono come possibili
> errori del riferimento (punto 5). (e) Due confronti di GSE226005 (`…Hypoxia_vs_Vehicle__1`,
> `…Hypoxia_rep_vs_Vehicle__1`) hanno il controllo fatto da 2 campioni cancellati da GEO: i loro campi GEO valgono
> «(not available: sample deleted from GEO)». Restano nella prova; il conto li riporta a parte.

### Perché
È l'unica misura che dice se lo Stadio 2b funziona: tre modelli, stesso prompt, 1.903 confronti del
deliverable, conto cieco contro 193 difetti e 1.710 puliti. Chiude anche la domanda «cambiamo modello?».

### Che cosa si fa
1. Modelli: `mistralai/Mistral-Small-3.2-24B-Instruct-2506` (produzione), `mistralai/Magistral-Small-2509`,
   `google/gemma-4-31b-it` (licenza da accettare su HF; verificare che vLLM v0.20.2 lo serva, altrimenti
   dichiararlo e tenerne due). Config identica: temperatura 0, `repetition_penalty` 1.1,
   `VLLM_BATCH_INVARIANT=1`, `max_model_len` 32768, structured output sullo schema di S12.
2. **Smoke prima**: 20 confronti, un modello, output valido sullo schema. Poi STOP e lancio pieno.
3. Lancio: `poddgx02` soltanto (`nodelist` mai `NULL`), `/home/u0044/`, `setsid nohup`, SID==PID,
   variabili d'ambiente verificate su `/proc/<pid>/environ`. Aggiornamento ogni ora.
4. Conto cieco (`analysis/audit/2026-11-XX-S12p-prova/`): solo dopo che i tre output sono su disco con
   SHA-256, si apre il riferimento e si contano presi / mancati / falsi allarmi per modello, per categoria
   dei 193, e la quota di `non_detto`. Intervallo di confidenza al 95% su ogni frazione.
5. Lettura dei falsi allarmi del modello migliore (tutti, non a campione): errore del modello, della regola,
   o del riferimento.

### Che cosa NON si fa
- Non si cambia il prompt dopo aver visto il conto. Una versione, un conto. Se serve un prompt nuovo, è un
  giro nuovo con previsioni nuove.
- Non si usa `poddgx01`. Niente `run_in_background`.

### Come si sa che è finita
Tabella modello × (presi su 193, falsi allarmi su 1.710, `non_detto`) con intervalli; finding con la
previsione a fianco; falsi allarmi letti tutti.

### La decisione che spetta a te
Quale modello va in produzione per lo Stadio 2b; se nessuno passa, quale delle tre vie (regole,
fine-tuning, prompt nuovo).

### Prompt
```
sessione simulomicsr S12p, leggi prima la skill di progetto.
Il deliverable e' /mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d (194).
Handout: docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md, sezione S12p. Spec e previsioni di S12.
Obiettivo: smoke su 20 confronti, poi i 1.903 con tre modelli su poddgx02, poi conto cieco contro i 193 e i 1.710.
Il riferimento si apre solo dopo che gli output sono su disco con SHA-256.
```

---

# S12q — La strada dopo S12p

> **Chiusura.** Il PI ha approvato il disegno il 2026-11-09 («approvato»). Documenti: spec
> `docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md`, ADR-0029, piano
> `docs/superpowers/plans/2026-11-09-lettore-studio-tabella-dei-fattori-plan.md` con la versione leggibile
> `…-HUMANE.md`. Le due decisioni aperte di S12p (i 280 difetti nel riferimento, dove correggere per primo) sono
> superate. Il PI ha approvato il piano il 2026-11-10 («va bene procedi»), con le dieci scelte dell'agente e con
> l'esecuzione raccomandata: un solo agente in una sessione nuova (skill `superpowers:executing-plans`), poi una
> revisione indipendente di tutto il branch. **La sessione è chiusa.**

# S12r — Piano 1: fondamenta e prova

> **Ricevuto da S12q, da leggere per primo.** (1) Niente è stato depositato: la divisione degli studi e le
> previsioni sono il Task 1 del piano, e si committano prima di ogni calcolo. (2) Gli 82 studi di giudizio sono
> chiusi: nessun agente e nessun subagente ne legge fattori, livelli, confronti o uscite del modello. (3)
> `analysis/audit/2026-11-09-lettore-studio/20-atlas-studi-nostri.txt` contiene i nomi dei tipi di fattore di Atlas
> per tutti i 129 studi: è una perdita già dichiarata nelle previsioni, non leggere quei campi. (4) Le dieci scelte
> dell'agente elencate nel file HUMANE sono accettate dal PI (2026-11-10). Esecuzione: un solo agente con
> `superpowers:executing-plans`, niente subagenti per i task, una revisione indipendente alla fine. (5) L'API di Gemma è andata due volte
> in timeout: riprova nel Task 11. (6) Classe di disaccordo attesa: i curatori scrivono due agenti come un livello
> solo («albuterol and dexamethasone»), il lettore come due fattori. Si conta a parte e si porta al PI.
> (7) **Stato del piano:** dopo il commit di ogni Task aggiorna
> `docs/superpowers/plans/2026-11-09-lettore-studio-mappa/stato.json`, esegui `genera.py` e committa
> `stato.json` con `stato-del-piano.pdf` (procedura nel `README.md` della cartella). Il PI segue il lavoro su
> quel PDF e sulla mappa stampata `mappa-per-il-PI.pdf`. Se il Task 1 scrive previsioni diverse da quelle di
> `stato.json`, correggi `stato.json` nello stesso commit.

Il piano comanda. Il Task 11 chiude con STOP: il Piano 2 si scrive dopo la decisione del PI.

> **Esito (2026-11-10), finding `docs/findings/2026-11-09-S12r-prova-lettore-studio.md`.** Cancelli K1-K5 passati.
> Previsioni: P2 e P7 confermate; P4 (gruppi identici del lettore, 14/47 contro 65% atteso) e P6 (studi non chiusi,
> 24 contro 4 attesi) smentite; P1, P3, P5, P8 indeterminate. Lettore v0 contro la pipeline di oggi sui 47 studi:
> (a) 14/47 contro 14/47; (b) 10/93 contro 19/93 (−9,7 punti, IC95 −25,3, +4,3); (c) 1/5 contro 19/79. **La regola
> di esito (spec §5.6) non è soddisfatta: ha deciso il PI (vedi sotto).** Cause (145 disaccordi letti tutti, audit interno): forma
> delle voci di `assignment` 68 (18 studi non chiusi; sensibilità dichiarata dopo i numeri: 33 chiusi, (a) 20/47,
> (b) 15/93); fattore letto dal titolo in 13 studi; fattore annidato in 4 studi (lo schema non lo sa scrivere);
> scelte dei curatori 22 (tempo zero come controllo 10). «Livello combinato»: 0 disaccordi.
> **Da fare nella prova ripetuta (dalla revisione finale del branch):** una corsa di controllo senza
> `repetition_penalty` (la penalità 1,1 può disturbare la ripetizione di valori uguali nelle voci: non misurato);
> `minItems`/`maxItems` o una forma a oggetto per le voci di `assignment`; scrivere prima della prova la regola sul
> fattore che i curatori non scrivono per un braccio (lettura larga 93 confronti, stretta 82: oggi 18/82, lettore 8/82).
> **Decisioni del PI (2026-11-10, «ok a tutto»):** (1) si corregge lo schema e si ripete la prova sugli stessi 47
> studi, con Mistral e con uno o due modelli più grandi (spec §5.7), previsioni nuove prima: è la sessione S12r2;
> (2) i confronti di Atlas che usano il tempo zero come controllo escono dal riferimento, con una regola scritta
> prima della prova, e la misura intera si riporta accanto. **La sessione è chiusa.**
> **Dubbi rinviati a S12r2:** Gemma (UBC) non risponde (5 timeout in due sessioni): una sola
> fonte di curazione, da dichiarare come limite; l'uscita più lunga è all'81% di `max_tokens` (16.384); il DOI di
> GEOAgent nel piano è sbagliato (vero: 10.64898/2026.06.06.730646); gli 82 studi di giudizio restano chiusi.
> **Il Piano 2 non è scritto:** si scrive dopo S12r2, se il PI lo decide.

### Prompt
```
sessione simulomicsr S12r, leggi prima la skill di progetto.
Piano: docs/superpowers/plans/2026-11-09-lettore-studio-tabella-dei-fattori-plan.md (Parte B, Piano 1).
Spec: docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md. Branch p6-tabella-dei-fattori.
```

---

# S12r2 — La prova ripetuta del lettore

> **Ricevuto da S12r, da leggere per primo.** (1) **Decisioni del PI del 2026-11-10** («ok a tutto», ADR-0029
> §Aggiornamento): correggere lo schema e ripetere la prova sugli stessi 47 studi di sviluppo, con Mistral e con uno
> o due modelli più grandi; togliere dal riferimento i confronti di Atlas col tempo zero come controllo, con una
> regola scritta prima, e riportare la misura intera accanto. (2) **Dalla revisione finale di S12r:** una corsa di
> controllo senza `repetition_penalty`; `minItems`/`maxItems` o una forma a oggetto per le voci di `assignment`; la
> regola sul fattore che i curatori non scrivono per un braccio va scritta prima (lettura larga 93 confronti,
> stretta 82: oggi 18/82, lettore v0 8/82). (3) **Le cause da togliere** (finding di S12r §5): forma delle voci (68
> unità, 18 studi non chiusi); fattore letto dal titolo con un livello per campione (13 studi); fattore annidato (4
> studi, 16 unità: la spec non dice come scriverlo né come `tf_confronti()` lo confronta); base scritta senza
> campioni (14 studi). **Per il fattore dal titolo e per la base senza campioni, prima la diagnosi di dove nasce
> l'errore (che cosa vede il modello nella vista), poi la correzione:** un errore sistematico del modello non si
> chiude con una frase nel prompt né con una regola che sostituisce il modello. (4) **I modelli più grandi** li
> sceglie l'agente (spec §5.7): aperti, dentro le 8 GPU di `poddgx02`, revisione fissata, due corse identiche al
> carattere (Gemma-4-31B non era ripetibile e chiedeva 2 GPU). (5) **Rinviati:** Gemma (UBC) non risponde (5 timeout
> in due sessioni), una sola fonte di curazione; l'uscita più lunga era all'81% di `max_tokens` (16.384); gli 8
> difetti minori in `analysis/audit/2026-11-09-lettore-studio/68-decisioni-e-minori.md` (il conto degli «identica»
> con campioni di Atlas omessi serve per il cancello). (6) `container-env.txt` delle corse porta il token di
> Hugging Face: non stamparlo e non committarlo.

> **Esito (2026-11-10), finding `docs/findings/2026-11-10-S12r2-prova-ripetuta-lettore-studio.md`.** Cancelli K1-K5
> passati (K4 per M, M0, G1). Lettura principale (97 confronti): pipeline di oggi 14/47 gruppi identici e 13/97
> confronti ritrovati; **Mistral-Small 3.2 con lo schema v1 31/47 e 50/97** (+38,1 punti, IC95 +19,0, +58,2), errori
> fra i non elencati 0/4, due corse identiche al carattere; senza `repetition_penalty` 50/97; Mistral-Small-4-119B
> 32/97 e 25/97 nelle due corse, identiche in 4 studi su 47; Qwen3.5-122B non parte in due tentativi: non misurato.
> **13 studi non chiusi per Mistral-Small 3.2** (previsione L1 smentita: soglia 7). 63 disaccordi letti tutti: forma
> 16, schema o vista con rimedio non misurato 30, lettura del modello 5, curatori 12. **Regola di esito: no per i tre
> modelli** (Mistral-Small 3.2: tre condizioni su quattro; la quarta è no con la lettura severa, sì alla lettera).
> **La sessione non è chiusa: aspetta tre decisioni del PI.** (1) Piano 2 adesso, oppure prima una terza prova
> piccola sugli stessi 47 studi con lo schema generato per ogni studio a elenco chiuso (raccomandata la terza prova);
> (2) quale modello (raccomandato Mistral-Small 3.2); (3) Qwen3.5-122B si riprova con 8 GPU oppure no (raccomandato
> no, e cancellare i pesi). **Il PI ha deciso (2) e (3) il 2026-11-10 come raccomandato:** il modello è
> Mistral-Small 3.2; Qwen3.5-122B non si riprova e i suoi pesi sono cancellati dal DGX (`/home` passa a 167 GB su
> 500). **Il PI ha deciso (1) il 2026-11-11**, dopo la spiegazione della proposta: **si fa la terza prova piccola**
> (sessione S12r3). **La sessione S12r2 è chiusa.**
> **Rinvii per S12r3 (riscritti nella sua sezione, che fa fede):**
> (a) lo schema a elenco chiuso **non è misurato**: colonne e valori presi dalla tabella dei campioni come elenco
> chiuso, una voce per ogni valore distinto; misurare prima la grandezza dello schema generato sugli studi con molte
> colonne; (b) `schema/context_senza_base`: un confronto fra due tipi cellulari o due condizioni di coltura non ha
> una base per schema (`GSE65335`, `GSE75852`): scelta di disegno da portare al PI; (c) `vista/sotto_serie`: in
> `GSE147507` la vista porta 77 campioni contro i 14 di Atlas; (d) i pesi di Qwen3.5-122B sono cancellati dal DGX (2026-11-10, decisione 3): sul DGX resta solo
> Mistral-Small 3.2; (e) Mistral-Small-4-119B non è ripetibile con
> `tensor_parallel_size` 4 anche con la batch invariance: la causa non è diagnosticata, e la diagnosi serve solo se
> il PI sceglie un modello che chiede più GPU per motore; (f) la misura (c) di Mistral-Small 3.2 ha 4 confronti
> giudicabili: sugli 82 studi di giudizio va riportata col suo intervallo; (g) i difetti minori M8-M11 di S12r
> restano come scritti; M12 (token di Hugging Face comparso una volta in S12r) resta una scelta del PI; (h) Gemma
> (UBC) riprovata una volta, nessuna risposta: una sola fonte di curazione.

### Perché
Il lettore v0 non ha fatto meglio della pipeline di oggi (gruppi identici 14/47 contro 14/47, confronti ritrovati
10/93 contro 19/93), ma 18 dei 24 studi non chiusi cadono per la forma della risposta, e 10 dei confronti che un
lettore senza difetti perde usano il tempo zero come controllo. La prova v0 non separa il compito dalla forma.

### Che cosa si fa
1. **Carta, prima di ogni corsa.** Aggiorna la spec (§5.2 forma delle voci e fattore annidato, §5.3 come il
   costruttore confronta dentro un livello, §5.5 il riferimento senza tempo zero e la regola sul fattore non
   scritto). La regola sul tempo zero riconosce il confronto per costruzione, non per elenco di studi.
2. **Deposita** in una cartella di audit nuova `00-previsioni.md` (cancelli, previsioni con intervallo, regola di
   esito, le due regole di lettura) e committalo da solo. Rimisura la pipeline di oggi col riferimento nuovo e con
   quello intero: è il termine di paragone.
3. **Codice del costruttore** solo dove la spec aggiornata lo chiede (TDD). Schema e prompt v1 restano materiale
   da buttare nella cartella di audit.
4. **Corse su `poddgx02`:** Mistral v1 due volte; Mistral v1 senza `repetition_penalty` (controllo); ogni modello
   più grande due volte. Stessa vista per tutti.
5. **Leggi tutti i disaccordi**, con la causa e chi la può togliere, come in S12r.
6. **Finding** con «In breve», poi STOP.

### Che cosa NON si fa
Non si scrive il Piano 2. Non si aprono gli 82 studi di giudizio. Non si cambiano previsioni e regole dopo i
numeri. Non si toccano deliverable e master. Gli stessi 47 studi servono una seconda volta: il risultato vale per
lo sviluppo, non come giudizio, e il finding lo dice.

### Come si sa che è finita
I cancelli passano, ogni previsione ha un esito, ogni disaccordo ha una causa, la regola di esito ha un sì o un no
per ogni modello.

### La decisione che spetta a te
Se si scrive il Piano 2 (il lettore nel pacchetto, S12s) e con quale modello.

### Prompt
```
sessione simulomicsr S12r2, leggi prima la skill di progetto.
Handout: docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md, sezione S12r2. Finding di partenza:
docs/findings/2026-11-09-S12r-prova-lettore-studio.md. Spec:
docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md. Branch p6-tabella-dei-fattori.
```

---

# S12r3 — La terza prova piccola: lo schema delle uscite a elenco chiuso

> **Esito (2026-11-11), finding `docs/findings/2026-11-11-S12r3-terza-prova-lettore-studio.md`.** Decisione del PI
> prima del deposito: un fattore di contesto non ha livello di base; i confronti di Atlas in cui cambia solo
> `cell type`, `cell line` o `organism part` escono dal riferimento per costruzione (97 → **95** confronti; la misura
> su 97 si riporta accanto). I 5 cancelli passano. Mistral-Small 3.2 con lo schema generato per ogni studio, due
> corse identiche al carattere 47/47: **45 studi chiusi su 47** (v1 34), **gruppi identici ad Atlas 36/47** (v1 31,
> oggi 14), **confronti ritrovati 68/95** (v1 50, oggi 13; lettore meno oggi +57,9 punti, IC95 +40,0, +73,2), errori
> fra i non elencati 2/33 (nessuno dei due è del lettore). I 2 non chiusi (`GSE50499`, `GSE63816`) scrivono il nome
> di un livello in una forma che lo schema non lega; sensibilità dichiarata dopo i numeri: 47/47 chiusi, 71/95.
> 40 disaccordi letti tutti (audit interno): non errore 21, vista o schema 6, **lettura del modello 13 in 4 studi**
> (`GSE57945` sesso scritto come fattore; `GSE46665` sigle dei pazienti scritte come malattie; `GSE60340` colonna del
> trattamento non vista; `GSE49155` fattore doppio), **gruppi sbagliati in 3 studi**. **Regola di esito: no**, per
> il solo punto 4 (i punti 1, 2, 3 e 5 sì): è l'esito che l'agente aveva depositato.
> **Decisione del PI (2026-11-12), come raccomandato:** il Piano 2 non si scrive adesso; prima una sessione breve
> che cerca dove nasce ogni errore di lettura (sessione S12r4). **La sessione S12r3 è chiusa.**
> **Rinvii (riscritti nella sezione S12r4, che fa fede; (c), (d) ed (e) valgono anche per S12s):**
> (a) **gli errori di lettura non hanno una diagnosi.** Tre dei 4 non c'erano nelle tabelle scritte con lo schema v1,
> e le 5 unità di lettura di S12r2 (`GSE57116`, `GSE75852`) sono sparite: l'errore si sposta con la forma
> dell'uscita. Candidate non misurate: la tupla `columns` che chiede un ruolo per ogni colonna, un fattore su una
> sola colonna, la cella vuota come valore con un livello. Serve una corsa per ogni cambio, una cosa per volta;
> niente correzioni al prompt per coprire uno studio e niente regole che fanno il lavoro del modello;
> (b) **due correzioni di forma dello schema, nominate e non misurate come corsa:** i livelli presi dalle voci (via
> l'elenco `levels` separato) e i due nomi riservati come valori ammessi di `level`;
> (c) **la regola del riferimento per il contesto** nomina tre fattori di Atlas: `growth condition` (`GSE65335`)
> resta nel riferimento e conta contro il lettore. Chi scrive il cancello decide prima, e per costruzione, se la
> regola segue i nomi di Atlas o il tipo del fattore;
> (d) la misura (c) non vede un fattore di troppo quando ogni confronto resta dentro un livello di quel fattore
> (`GSE57945`: 18 confronti «coerenti» con gruppi sbagliati): sugli 82 studi di giudizio non basta da sola;
> (e) `GSE147507` è identica sui 14 campioni comuni, con 10 confronti fuori dall'universo di Atlas che la prova non
> giudica; il limite «variabile su più colonne» resta dichiarato;
> (f) i 47 studi di sviluppo sono stati letti tre volte: ogni altra prova su di loro aumenta il rischio di
> adattamento, e solo gli 82 studi di giudizio lo misurano;
> (g) `renv/settings.json` è **tracciato** in questo branch: prima di un commit `git checkout -- renv/settings.json`,
> mai `rm`.

> **Ricevuto da S12r2, da leggere per primo.** (1) **Decisioni del PI:** il modello del lettore è Mistral-Small 3.2
> (2026-11-10); Qwen3.5-122B non si riprova, pesi cancellati (2026-11-10); **prima del Piano 2 si fa una terza prova
> piccola sugli stessi 47 studi di sviluppo, con lo schema delle uscite a elenco chiuso (2026-11-11)**. In questa
> prova non entrano modelli più grandi. (2) **Che cosa è la proposta** (finding di S12r2 §7): «schema» è la forma
> JSON delle uscite strutturate, non il disegno dello studio. Un programma la genera per ogni studio dalla tabella
> dei campioni: il campo della colonna ammette solo le colonne che esistono, il campo del valore solo i valori
> distinti che esistono, e ogni valore distinto ha la sua voce. Il modello decide ancora fattori, ruoli, livelli e
> livello di base. **Non è misurata.** Riguarda 10 dei 13 studi non chiusi di S12r2 (`valore_senza_voce` 8,
> `colonna_non_letterale` 1, `valore_non_letterale` 1). (3) **Il rischio da misurare:** l'elenco chiuso toglie gli
> errori di copia e di copertura, non gli errori di lettura. Un modello obbligato a coprire ogni valore può scrivere
> un livello sbagliato (`GSE46665`: livelli solo per i valori `_T0`; `GSE56787`: tre fattori dalla sola colonna
> `tissue`). Uno studio che prima non chiudeva e adesso chiude con gruppi sbagliati è un esito peggiore: va contato
> a parte. (4) **Prima delle corse, senza modello:** la grandezza dello schema generato sui 47 studi (l'ingresso più
> lungo ha 31.271 token; una colonna come il titolo ha un valore per campione) e se vLLM 0.20.2 lo compila.
> (5) **Aperti da S12r2, non toccati dalla proposta:** `schema/context_senza_base` (`GSE65335`, `GSE75852`: un
> confronto fra due tipi cellulari o due condizioni di coltura non ha una base per schema) è una scelta di disegno
> del PI: porta le opzioni prima del deposito delle previsioni; `vista/sotto_serie` (`GSE147507`: la vista porta 77
> campioni contro i 14 di Atlas): prima la diagnosi di dove nasce, poi la correzione; `schema/annidato_colonna_padre`
> (`GSE66207`, `GSE57945`); `modello/forma_voci` (`GSE59781`, `GSE69597`: una voce con più valori); le 5 unità con
> esito «modello» (`GSE57116`, `GSE75852`). (6) **Rinviati oltre:** la misura (c) ha 4 confronti giudicabili e sugli
> 82 studi di giudizio va riportata col suo intervallo (S12s); Mistral-Small-4-119B non ripetibile con
> `tensor_parallel_size` 4: la diagnosi non serve, perché il modello scelto sta su una GPU; M8-M11 di S12r restano
> come scritti; M12 (token di Hugging Face comparso una volta in S12r) resta una scelta del PI; Gemma (UBC) non
> risponde: una sola fonte di curazione. (7) `container-env.txt` delle corse porta il token di Hugging Face: non
> stamparlo e non committarlo.

### Perché
Con lo schema v1 Mistral-Small 3.2 forma gli stessi gruppi dei curatori in 31 studi su 47 e ritrova 50 confronti su
97, ma 13 studi non chiudono contro la soglia depositata di 7, e la regola di esito dà no. In 10 dei 13 il modello
copia male un nome o salta un valore. Il rimedio proposto è nella forma dell'uscita e nessuno lo ha misurato: il
Piano 2 apre gli 82 studi di giudizio una volta sola e non può poggiare su un rimedio non misurato.

### Che cosa si fa
1. **Carta, prima di ogni corsa.** Aggiorna la spec (§5.2): come il programma genera lo schema dalla tabella dei
   campioni (colonne, valori distinti, una voce per valore, valori mancanti, fattore annidato, voce con più
   valori), che cosa fa quando lo schema generato è troppo grande. Porta al PI la scelta sul fattore di contesto
   senza base (punto 5 qui sopra).
2. **Misura senza modello:** grandezza dello schema generato per ognuno dei 47 studi e prova di compilazione in
   vLLM sul più grande.
3. **Deposita** in una cartella di audit nuova `00-previsioni.md` (cancelli, previsioni con intervallo, regola di
   esito, come si conta lo studio che chiude con gruppi sbagliati) e committalo da solo. Riproduci prima i termini
   di paragone: pipeline di oggi 14/47 e 13/97, lettore con lo schema v1 31/47 e 50/97.
4. **Codice:** il generatore dello schema resta materiale da buttare nella cartella di audit. Il costruttore
   cambia solo dove la spec aggiornata lo chiede (TDD).
5. **Corse su `poddgx02`:** Mistral-Small 3.2, configurazione di produzione, due corse, identiche al carattere.
   Stessa vista di S12r2, salvo la correzione della vista decisa nella carta.
6. **Leggi tutti i disaccordi**, con la causa e chi la può togliere. Per ogni studio che chiudeva male o non
   chiudeva in S12r2, di' che cosa è cambiato.
7. **Finding** con «In breve», poi STOP.

### Che cosa NON si fa
Non si scrive il Piano 2. Non si aprono gli 82 studi di giudizio. Non si cambiano previsioni e regole dopo i
numeri. Non si provano altri modelli. Non si toccano deliverable e master. Gli stessi 47 studi servono una terza
volta: il risultato vale per lo sviluppo, non come giudizio, e il finding dichiara il rischio di adattamento ai 47.

### Come si sa che è finita
I cancelli passano, ogni previsione ha un esito, ogni disaccordo ha una causa, la regola di esito ha un sì o un no.

### La decisione che spetta a te
Se si scrive il Piano 2 (il lettore nel pacchetto, S12s).

### Prompt
```
sessione simulomicsr S12r3, leggi prima la skill di progetto.
Handout: docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md, sezione S12r3. Finding di partenza:
docs/findings/2026-11-10-S12r2-prova-ripetuta-lettore-studio.md. Spec:
docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md. Branch p6-tabella-dei-fattori.
```

---

# S12r4 — Dove nasce ogni errore di lettura del lettore

> **Esito (2026-11-12): fatta e chiusa con due decisioni del PI.** Finding
> `docs/findings/2026-11-12-S12r4-cause-errori-di-lettura.md`, evidenza
> `analysis/audit/2026-11-12-S12r4-cause-errori-di-lettura/`. I 5 cancelli passano. 31 forme dell'uscita su tutti i
> 47 studi (32 corse su `poddgx02`, 222 minuti). Letti 58 errori di lettura in 32 studi: la regola di diagnosi dà
> «della forma» 14, «del modello» 2, «non deciso» 42 (lettura severa, dichiarata dopo i numeri: 5, 2, 51).
> `GSE46665` è presente in 31 forme su 31 (del modello); `GSE57945` in 13, `GSE60340` in 8, `GSE49155` in 14. Con
> una frase del prompt riscritta senza cambiare il senso la tabella dei fattori cambia in 5-9 studi su 47. 24
> forme su 29 tolgono almeno un errore e tutte e 24 ne fanno nascere almeno uno in un altro studio. **Forma finale
> secondo la regola: `B0` (quella di S12r3), senza cambi**; le due correzioni di forma (`F1`, `F2`) non entrano.
> **Decisioni del PI (2026-11-12), come raccomandato:** (1) la forma dell'uscita è `B0`, senza cambi; (2) prima
> del Piano 2 una sessione breve con più letture dello stesso studio e una regola sulla discordanza scritta
> prima (sessione S12r5), fra le sette opzioni del finding §9. ADR-0029 §Aggiornamento 2026-11-12 (S12r4).
> **La sessione S12r4 è chiusa. Rinvii (riscritti nella sezione S12r5, che fa fede)** (finding §10 e §11): la regola del
> riferimento per i fattori di contesto (`growth condition`, `GSE65335`); `GSE147507` (non chiude in 15 forme su
> 31); la misura dei confronti non elencati sugli 82 studi; la vista non è stata variata; un errore uguale in
> tutte le forme non è letto dal metodo dei disaccordi che cambiano (esempio: `country` in `GSE69597`); la frase
> di S12r3 «le due correzioni di forma entrano nel passo seguente» non vale più.

> **Ricevuto da S12r3, da leggere per primo.** (1) **Decisione del PI (2026-11-12):** il Piano 2 non si scrive
> adesso; prima questa sessione breve, sugli stessi 47 studi di sviluppo e solo con Mistral-Small 3.2.
> (2) **Che cosa si cerca** (finding di S12r3 §5.3): 13 unità di lettura del modello in 4 studi. `GSE57945`: la
> colonna `Sex` scritta come fattore di contesto, 14 gruppi contro i 7 di Atlas; con lo schema v1 il fattore non
> c'era. `GSE60340`: un solo fattore da `sample group`, la colonna `treated with` giudicata non informativa, tre
> trattamenti in un gruppo; con lo schema v1 i fattori erano due. `GSE49155`: gruppi giusti, ma il contesto
> `cell_type` scrive la cella vuota come livello e ogni confronto differisce in due fattori; con lo schema v1 non
> faceva danno. `GSE46665`: le sigle dei 9 pazienti scritte come malattie, **con tutte e due le forme**. Per
> `GSE57945`, `GSE60340` e `GSE46665` lo studio non chiudeva col v1: i gruppi del v1 non si conoscono. Nella
> direzione opposta, le 5 unità di lettura di S12r2 (`GSE57116`, `GSE75852`) sono sparite con lo schema nuovo.
> (3) **Candidate non misurate:** la tupla `columns` che chiede un ruolo per ogni colonna; un fattore su una sola
> colonna; la cella vuota come valore che deve avere un livello. Anche il prompt è cambiato fra le due prove (v1 →
> v2): è una differenza come le altre. (4) **Due correzioni di forma dello schema, nominate e non misurate come
> corsa** (finding §5.6): i livelli presi dalle voci (via l'elenco `levels` separato, `GSE50499`) e i due nomi
> riservati come valori ammessi di `level` (`GSE63816`). Il calcolo fatto dopo i numeri dà 47/47 chiusi e 71/95:
> non è una misura. (5) **Letture del modello che oggi non costano confronti**, 8 unità fuori dalle 13 (finding §7):
> `source_name_ch1` letta come donatore (`GSE50760`), un contesto che coincide con la diagnosi (`GSE71595`), un
> livello sbagliato a studio non chiuso (`GSE63816`). Con lo studio chiuso possono costare: vanno contate.
> (6) **La misura (c) non vede un fattore di troppo** quando ogni confronto resta dentro un livello di quel fattore
> (`GSE57945`: 18 confronti «coerenti» con gruppi sbagliati): in questa sessione un errore si conta sui gruppi e
> sui fattori, non solo sui confronti. (7) **Il rischio di adattamento:** i 47 studi sono stati letti tre volte.
> Questa è la quarta. Solo gli 82 studi di giudizio lo misurano, e restano chiusi. (8) **Regole del PI in vigore:**
> nessun errore si accetta; un errore del modello non si chiude con il prompt né con regole che sostituiscono il
> modello; prima la diagnosi. (9) **Passano a S12s senza cambi:** la regola del riferimento per il contesto
> (`growth condition`, `GSE65335`: per nomi di Atlas o per tipo del fattore, da decidere prima e per costruzione);
> `GSE147507` (10 confronti fuori dall'universo di Atlas; limite «variabile su più colonne»); la misura (c) sugli
> 82 studi col suo intervallo. (10) `renv/settings.json` è tracciato: prima di un commit `git checkout --`, mai
> `rm`. `container-env.txt` delle corse porta il token di Hugging Face: non stamparlo e non committarlo.

### Perché
Con lo schema generato per ogni studio il lettore ritrova 68 confronti su 95 (oggi 13) e chiude 45 studi su 47, ma
in 3 studi forma gruppi sbagliati per un errore di lettura, e la regola di esito dà no. Gli errori si spostano con
la forma dell'uscita: la causa può stare nella forma, nel prompt, nella vista o nel modello, e nessuno lo ha
misurato. Il Piano 2 fissa schema, prompt e cancello e apre gli 82 studi di giudizio una volta sola: non può
partire da una forma che forse cambia ancora.

### Che cosa si fa
1. **Carta, prima di ogni corsa.** Elenca **tutte** le differenze fra la condizione di S12r2 (schema v1, prompt
   v1) e quella di S12r3 (schema generato, prompt v2), una per riga, dai file congelati delle due sessioni
   (`analysis/audit/2026-11-10-S12r2-prova-ripetuta/`, `analysis/audit/2026-11-11-S12r3-elenco-chiuso/`). Per
   ogni differenza scrivi la variante che cambia solo quella. Scrivi le due correzioni di forma come varianti a sé.
2. **Deposita** in una cartella di audit nuova `00-previsioni.md` e committalo da solo: cancelli (riproduci 45/47,
   36/47, 68/95 e le 13 unità di S12r3; controllo positivo: lo strumento vede i 4 errori nella condizione di
   partenza), previsioni con intervallo, e la **regola di diagnosi** scritta prima: quando un errore è «della
   forma» (un solo cambio lo toglie e il cambio opposto lo rimette), quando è «del modello» (resta con ogni
   variante), quando è «non deciso». Scrivi prima anche come si conta un errore nuovo che una variante fa nascere
   in un altro studio.
3. **Corse su `poddgx02`:** ogni variante su **tutti i 47 studi**, non solo sui 4, con la configurazione di
   produzione; la condizione di partenza e la variante scelta alla fine due volte, identiche al carattere. Una
   corsa dura circa 4 minuti su 4 GPU.
4. **Misura ogni variante** con le stesse misure di S12r3 (riferimento a 95, misura su 97 accanto) e con il conto
   degli errori sui gruppi e sui fattori. **Leggi tutti i disaccordi che cambiano** rispetto a S12r3, non solo
   quelli dei 4 studi.
5. **Per ogni errore di lettura, un esito:** dove nasce, con la corsa che lo mostra; oppure «del modello», con il
   conto. Se resta una causa «del modello», porta al PI il conto e tutte le opzioni: non scegliere tu.
6. **Finding** con «In breve», poi STOP.

### Che cosa NON si fa
Non si scrive il Piano 2. Non si aprono gli 82 studi di giudizio. Non si cambia il prompt per coprire uno studio:
un cambio del prompt è una variante generale, scritta nella carta prima delle corse. Non si aggiungono regole che
fanno il lavoro del modello. Non si provano altri modelli. Non si cambiano previsioni e regole dopo i numeri. Non
si sceglie una variante perché dà il numero più alto sui 47: si sceglie con la regola di diagnosi. Non si toccano
deliverable e master.

### Come si sa che è finita
I cancelli passano, ogni previsione ha un esito, ognuno dei 4 errori di lettura (e ogni errore nuovo) ha un esito
della regola di diagnosi, le due correzioni di forma sono misurate come corsa.

### La decisione che spetta a te
Se si scrive il Piano 2 (il lettore nel pacchetto, S12s), e con quale forma dell'uscita. Se una causa resta nel
modello: che cosa si fa di quegli errori.

### Prompt
```
sessione simulomicsr S12r4, leggi prima la skill di progetto.
Handout: docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md, sezione S12r4. Finding di partenza:
docs/findings/2026-11-11-S12r3-terza-prova-lettore-studio.md. Spec:
docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md. Branch p6-tabella-dei-fattori.
```

---

# S12r5 — Più letture dello stesso studio: la discordanza segnala gli errori di lettura?

> **Ricevuto da S12r4, da leggere per primo.** (1) **Decisioni del PI (2026-11-12):** la forma dell'uscita è `B0`
> (schema generato per ogni studio a elenco chiuso, prompt v2), senza cambi; prima del Piano 2 questa sessione
> breve, sugli stessi 47 studi di sviluppo e solo con Mistral-Small 3.2. (2) **La causa misurata** (finding di
> S12r4 §5 e §9): la lettura del modello cambia con le parole. Con una frase del prompt riscritta senza cambiare
> il senso la tabella dei fattori cambia in 5-9 studi su 47 (4 corse); due corse con le stesse parole sono uguali
> al carattere. (3) **Il calcolo fatto dopo i numeri** (finding §7, `31-out.txt`): con `B0` e i suoi due placebo,
> 12 studi su 47 hanno almeno una lettura diversa; 7 dei 12 hanno in `B0` gruppi identici ai curatori; dei 9
> errori di `B0`, 5 stanno nei 12 studi e 4 negli altri 35; dei 4 errori che costano, 3 stanno in studi discordi
> (`GSE60340`, `GSE49155`, `GSE46665`) e 1 no (`GSE57945`). In `GSE46665` le letture differiscono per un altro
> fattore: l'errore delle sigle è in tutte. **Questo calcolo non è una misura:** tre letture, regola non scritta
> prima, studi già letti. (4) **Che cosa la discordanza non può vedere:** un errore stabile (`GSE46665` in 31
> forme su 31; `GSE57945` in `B0` e nei due placebo di `B0`). La sessione non porta a zero errori: lo dice prima.
> (5) **Gli errori di `B0` da ritrovare** (`29-errori-presenti-per-forma.csv`, `27-stati.csv`): 9 in 8 studi; 4
> che costano (`GSE46665` sigle, `GSE57945` sesso, `GSE60340` trattamento, `GSE49155` fattore doppio) e 5 che non
> costano (`source_name_ch1` come donatore in `GSE50760`, `GSE71595`, `GSE66573`; tempo ripetuto in `GSE46665`;
> tempo che ripete il tipo cellulare in `GSE75852`). (6) **Limiti di S12r4 che restano:** un errore uguale in
> tutte le forme e senza unità di disaccordo non è letto (esempio: `country` come soggetto in `GSE69597`); la
> lettura delle schede è di un solo agente; la vista non è stata variata. (7) **`B0` non chiude 2 studi**
> (`GSE50499`, `GSE63816`): le due correzioni di forma (`F1`, `F2`) non entrano. (8) **Il rischio di
> adattamento:** i 47 studi sono stati letti quattro volte. Questa è la quinta. I due placebo di `B0` sono già
> stati visti: le frasi riscritte di questa sessione sono nuove e scritte prima. (9) **Due conti degli errori
> nuovi** (depositato e per etichetta, finding §5.2): di' prima quale usi. (10) **Regole del PI in vigore:**
> nessun errore si accetta; un errore del modello non si chiude con il prompt né con regole che sostituiscono il
> modello; non spingere il PI a chiudere. (11) **Passano a S12s senza cambi:** la regola del riferimento per i
> fattori di contesto (`growth condition`, `GSE65335`); `GSE147507` (10 confronti fuori dall'universo di Atlas;
> non chiude in 15 forme su 31); la misura dei confronti non elencati sugli 82 studi col suo intervallo.
> (12) `renv/settings.json` è tracciato: prima di un commit `git checkout --`, mai `rm`. `container-env.txt`
> delle corse porta il token di Hugging Face: non stamparlo e non committarlo. (13) Una revisione indipendente
> alla fine ha trovato in S12r4 un errore di lettura dell'agente: si rifà anche qui.

### Perché
Nessun pezzo della forma dell'uscita spiega gli errori di lettura: per 42 errori su 58 la regola di diagnosi non
dà una causa, e la lettura si sposta con una frase che non dice niente di nuovo. Se la lettura sbagliata è anche
la lettura che cambia, più letture dello stesso studio la segnalano senza che una regola faccia il lavoro del
modello. Il calcolo fatto dopo i numeri dice «in parte». Prima del Piano 2 serve la misura, con la regola scritta
prima.

### Che cosa si fa
1. **Carta, prima di ogni corsa.** Scrivi le frasi riscritte: quante letture per studio, quali frasi del prompt
   di `B0` cambiano, con quale criterio una riscrittura «non cambia il senso». Le riscritture sono generali, non
   guardano uno studio. Di' se i due placebo di S12r4 entrano o no, e perché.
2. **Deposita** in una cartella di audit nuova `00-previsioni.md` e committalo da solo: cancelli (la corsa di
   `B0` è identica al carattere alle uscite congelate di S12r4; lo strumento ridà i 9 errori di `B0`; copertura
   47 su 47; ambiente), previsioni con intervallo, e la **regola sulla discordanza** scritta prima: su che cosa
   si confrontano le letture (tabella dei fattori, gruppi, confronti), quando uno studio è «segnalato», come si
   conta «la discordanza segnala un errore». Unità lo studio, B e seme dichiarati.
3. **Corse su `poddgx02`:** ogni lettura su tutti i 47 studi, con la configurazione di produzione. Una corsa dura
   circa 7 minuti su 4 GPU (misurato in S12r4); da 5 a 10 corse, circa un'ora.
4. **Misura:** quanti studi sono segnalati; quanti dei 9 errori di `B0` e dei 4 che costano stanno in studi
   segnalati; quanti studi segnalati hanno gruppi giusti; come cambiano questi conti col numero di letture.
   **Leggi tutti i disaccordi che cambiano** fra le letture nuove e `B0`, con le etichette di S12r4 dove valgono.
5. **Esito:** la regola depositata dà un sì o un no. Che cosa si fa degli studi segnalati e degli errori non
   segnalati lo decide il PI: porta il conto e tutte le opzioni, non scegliere tu.
6. **Revisione indipendente, finding** con «In breve», poi STOP.

### Che cosa NON si fa
Non si scrive il Piano 2. Non si aprono gli 82 studi di giudizio. Non si cambia la forma `B0`. Non si corregge il
prompt per coprire uno studio. La regola sulla discordanza segnala soltanto: non sceglie fra le letture, non vota
e non corregge una tabella. Non si provano altri modelli. Non si varia la vista. Non si cambiano previsioni e
regole dopo i numeri. Non si sceglie il numero di letture perché dà il conto migliore sui 47. Non si toccano
deliverable e master.

### Come si sa che è finita
I cancelli passano, ogni previsione ha un esito, la regola sulla discordanza ha un sì o un no, ogni disaccordo
che cambia è letto, la revisione indipendente è chiusa.

### La decisione che spetta a te
Se si scrive il Piano 2 (il lettore nel pacchetto, S12s). Che cosa si fa degli studi che la discordanza segnala,
e degli errori di lettura che non segnala.

### Prompt
```
sessione simulomicsr S12r5, leggi prima la skill di progetto.
Handout: docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md, sezione S12r5. Finding di partenza:
docs/findings/2026-11-12-S12r4-cause-errori-di-lettura.md. Spec:
docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md. Branch p6-tabella-dei-fattori.
```

---

# S12c (con S12b) e S12d

Prompt e dettagli nell'handout del 2026-08-21 (sezioni S12b, S12c, S12d). Tre cose cambiano:

- **Il modello non scrive mai un ID**: sceglie fra candidati per indice (SPIRES 97/100 contro 3/100). La
  regola generale di S12c si scrive così.
- **La seconda perturbazione arriva dallo Stadio 2b**, non dalla chiave: S12c non deve inseguirla.
- **Si misura sui master S14** con gli script di S9 (`20-ingressi.R`, `30-due-regimi.R`, `40-analisi.R`,
  35 minuti), non sul master A3.

---

# S13 — Applicare tutto sui master S14

> **Ricevuto da S12 (2026-11-07), da leggere per primo. Due rinvii.**
> (1) **Studi doppi**: la regola sulle conte e i suoi test si scrivono qui (rinvio di S5, che lo prevedeva se la
> vecchia S12 non lo faceva). Regola: due campioni sono lo stesso dato se la distanza L1 relativa sta sotto 0,001;
> due studi di un gruppo sono doppi se condividono almeno metà dei campioni dello studio più piccolo; resta lo
> studio con più campioni; `k_eff` si conta dopo. Controllo positivo: `GSE154613`/`GSE159522`,
> `GSE108743`/`GSE89725`, `GSE156038`/`GSE156184`/`GSE222279`. Elenco:
> `analysis/audit/2026-11-03-S5-gate-e-insiemi/48-coppie-di-studi-doppie.csv`.
> (2) **Codifica UTF-8 doppia e tripla nell'H5**: gli Stadi 1 e 2 di produzione hanno letto «TGF-Î²1» e simili
> (finding S12 §4). Lo Stadio 2b la ripara (`.s2b_norm_testo()`). Va deciso se la stessa riparazione entra dove la
> pipeline costruisce nomi e chiavi (Stadio 3, S12b/S12c); rifare i due passi col modello richiede una decisione
> del PI. **L'entità proposta** che lo Stadio 2b riceve in produzione è il nome dell'entità della chiave dello
> Stadio 3 del record (spec §2): va costruita prima di lanciare lo Stadio 2b sui candidati.
> (3) **Testo GEO di tutti i candidati** (rinvio di S12 parte 2, 2026-11-08, finding S12 §10): scaricare e congelare
> descrizione e protocolli di tutti gli studi candidati con `analysis/audit/2026-11-07-S12-stadio2b-disegno/26-scarica-geo.py`
> e `27-estrai-campi-geo.py`, unire con `.s2b_aggiungi_campi_geo()`, elencare i campioni cancellati da GEO e
> **toglierli** (decisione del PI, 2026-11-08: un lettore non li ritrova in GEO). Contarli nelle previsioni. Tempo misurato: 2,5 s per studio con un processo; le pagine HTML di GEO
> hanno mostrato un reCAPTCHA il 2026-11-08 (il formato testo ha risposto): lancio riprendibile. Dichiarare prima
> il numero degli studi candidati.

### Perché
Un ricalcolo solo, sui master definitivi, con tutte le correzioni insieme: Stadio 2b, chiave, varianza del
controllo condiviso (T1), ruoli per nome (ordine della cache), studi doppi tolti, corsie.

### Che cosa si fa
1. Stadio 2b con il modello scelto in S12p su **tutti** i confronti candidati dei master S14 (86.212 o il
   sottoinsieme che entra nei gruppi con ≥3 studi: dichiararlo prima). Ore di macchina su `poddgx02`.
2. Re-cluster (2,5 h, 32 worker; bump di `.NAME_RECOVERY_LOOKUP_SCHEMA_VERSION`; percorsi d'ingresso
   passati, non scritti nel codice). Re-pool a 16 pezzi (75 min) con i verdetti APPLICABILI.
3. Previsioni prima: numero di meta-analisi (sopra o sotto 194), quante delle 194 di oggi sopravvivono,
   quanti dei 193 confronti difettosi sono fuori, TNF/TGF-β1/LPS/ipossia con k atteso.
4. Deliverable nuovo in `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v17/<timestamp>/`, copia su micron
   con manifesto SHA-256.

### Che cosa NON si fa
Nessuna correzione guarda l'esito di una singola meta-analisi. Non si tocca A3 v16 (resta riferimento).

### Come si sa che è finita
Deliverable v17 su disco e in salvo; tabella previsioni/esito; `run_metadata.json` con i master S14.

### Prompt
```
sessione simulomicsr S13, leggi prima la skill di progetto.
Handout: docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md, sezione S13. Master: analysis/p4-output/S14-stage{1,2}-master.jsonl.
Obiettivo: Stadio 2b su tutti i candidati, chiave S12c/S12d, T1, ruoli, doppi; re-cluster e re-pool; deliverable v17. Previsioni prima del run.
```

---

# S15 — Rilettura cieca

Come S3 (ambiente congelato fuori dal repo, blocchi di 13, lettore + due critici + arbitro, poi
`25-cosa-hanno-letto.py`), su **tutte** le meta-analisi di v17, senza che gli agenti vedano i verdetti di
v16 né le liste di controllo dello Stadio 2b. Più 19 schede umane del PI. Numeri che decidono: tasso
residuo di confronti difettosi (con intervallo), verdetti cambiati rispetto a v16, classi di difetto nuove.
**Se compare una classe nuova con più di 5 casi**, si scrive e si rimanda a una S12-bis; non si corregge in
corsa.

---

# S7c — Seconda validazione esterna, con nullo

Stesso codice di S7 su v17: LINCS (verdetto) e Tahoe-100M (senza verdetto), **più le 99 estrazioni
casuali** come nullo, più il controllo di segno con TCGA. In aggiunta, firme di consenso con specificità
incrociata: PROGENy (TGF-β, TNF-α, ipossia, JAK-STAT, androgeni: DHT/R1881 su, enzalutamide giù), ipossia
Buffa 2010 / Ragnum 2015 / Tardon 2020, interferoni Schoggins 2011 e Aybey 2025 (tipo I contro II), LPS Xue
2014. Bersagli e metrica (AUC del nostro z sull'insieme, contro insieme casuale) fissati prima. Il numero
dell'articolo è questo.

---

# S7b — Meta-analisi pubblicate sugli stessi GSE (supplementare)

Tre casi (`analysis/audit/2026-11-07-valutazione-autonoma/R2-metanalisi-pubblicate.md`): NAFLD/MASH (Piras &
DiStefano 2024, REM, `GSE135251` e `GSE126848` in comune, liste complete), IPF (He 2025, tre GSE in
comune), endometriosi (Golinska 2025, tre GSE). Articolo e metrica fissati prima: direzione concorde e AUC
del nostro z sul loro insieme di geni, contro insieme casuale. Nell'articolo va in supplementare, con il
bias dichiarato: coprono 3 entità su ~194, tutte malattie.

---

# S16 e S17

> **Ricevuto da S12 (2026-11-07), per S17.** (1) Lo Stadio 2 di produzione non ha mai ricevuto il riassunto dello
> studio: l'ingresso v3 lo scrive vuoto (24.983 record su 24.983 dell'ingresso S14), senza un motivo scritto. Va
> nei Methods. (2) La codifica UTF-8 doppia e tripla dell'H5 di ARCHS4 (finding S12 §4) e la sua riparazione nello
> Stadio 2b vanno nei Methods. (3) La prova S12p è cieca sugli esempi ma non sulle categorie dei difetti (spec §8).

Prompt nell'handout del 2026-08-21. Nei Methods entrano, in più: lo Stadio 2b (ADR-0028) con il suo tasso
misurato in S12p e il residuo di S15; il soffitto (455 entità con ≥3 studi, resa del deliverable); il
modello non scrive ID; la dominanza come proprietà di GEO; la finestra competitiva (Soul & Young, GEOMeta,
Wren) nella discussione.
