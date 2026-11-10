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
| **S12r** | Piano 1 «fondamenta e prova»: costruttore dei confronti e misure contro Expression Atlas (TDD), misura della pipeline di oggi, prova da buttare con Mistral sui 47 studi di sviluppo. **Fatta il 2026-11-10: i 5 cancelli passano, la regola di esito non è soddisfatta** (gruppi identici 14/47 per il lettore e per oggi; confronti ritrovati 10 contro 19 su 93; 24 studi non chiusi, 18 per la forma delle voci). **STOP: non chiusa finché il PI non decide** | codice (TDD) + DGX breve | ~2 sessioni | **S12q** |
| **S12s** | Piano 2 «il lettore nel pacchetto» (da scrivere dopo S12r): testi GEO di tutti gli studi, vista, schema, prompt, modello, cancello (giudizio A, poi B). STOP | codice + DGX | da definire | **S12r** |
| **S12c** (+S12b dentro) | La chiave senza ID del modello; greche, latine, negazione | ADR + codice (TDD) + misura | ~6 h | S9 ✅ |
| **S12d** | Tabelle dei nomi agganciate ai campioni | codice (TDD) + misura | ~4 h | S10 ✅ |
| **S13** | Piano 3 (da scrivere dopo il cancello): corsa del lettore su tutti gli studi, chiave, varianza, ruoli, doppi, re-cluster, re-pool, deliverable v17 | calcolo | da definire | **S12s, S12c, S12d** |
| **S15** | Rilettura cieca delle meta-analisi nuove | lettura | 1 sessione | **S13** |
| **S7c** | Seconda validazione esterna con nullo + firme di consenso | misura | ~6 h | **S13** |
| **S7b** | Meta-analisi pubblicate sugli stessi GSE (supplementare) | misura | ~3 h | **S13** |
| **S16** | Figure | produzione | ~4 h | S15, S7c |
| **S17** | Methods e limiti | scrittura | ~4 h | tutto |

**Cancellate:** «S12 — il rilevatore in produzione» (handout di agosto) e «S14 seconda parte» (assorbita in
S13: il re-cluster si fa una volta sola). **Cancelli veri:** S12r←S12q, S12s←S12r (decisione del PI),
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
> di esito (spec §5.6) non è soddisfatta: decide il PI.** Cause (145 disaccordi letti tutti, audit interno): forma
> delle voci di `assignment` 68 (18 studi non chiusi; sensibilità dichiarata dopo i numeri: 33 chiusi, (a) 20/47,
> (b) 15/93); fattore letto dal titolo in 13 studi; fattore annidato in 4 studi (lo schema non lo sa scrivere);
> scelte dei curatori 22 (tempo zero come controllo 10). «Livello combinato»: 0 disaccordi.
> **Da fare nella prova ripetuta (dalla revisione finale del branch):** una corsa di controllo senza
> `repetition_penalty` (la penalità 1,1 può disturbare la ripetizione di valori uguali nelle voci: non misurato);
> `minItems`/`maxItems` o una forma a oggetto per le voci di `assignment`; scrivere prima della prova la regola sul
> fattore che i curatori non scrivono per un braccio (lettura larga 93 confronti, stretta 82: oggi 18/82, lettore 8/82).
> **Decisioni aperte del PI (2):** (1) che cosa fare del lettore: l'agente raccomanda di correggere lo schema e
> ripetere la prova sugli stessi 47 studi, con Mistral e con uno o due modelli più grandi (spec §5.7), previsioni
> nuove prima; (2) togliere dal riferimento i confronti di Atlas che usano il tempo zero come controllo, con una
> regola scritta prima della prossima prova (raccomandato: sì, con la misura intera accanto).
> **Dubbi rinviati a chi riceve la decisione:** Gemma (UBC) non risponde (5 timeout in due sessioni): una sola
> fonte di curazione, da dichiarare come limite; l'uscita più lunga è all'81% di `max_tokens` (16.384); il DOI di
> GEOAgent nel piano è sbagliato (vero: 10.64898/2026.06.06.730646); gli 82 studi di giudizio restano chiusi.
> **Il Piano 2 non è scritto.**

### Prompt
```
sessione simulomicsr S12r, leggi prima la skill di progetto.
Piano: docs/superpowers/plans/2026-11-09-lettore-studio-tabella-dei-fattori-plan.md (Parte B, Piano 1).
Spec: docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md. Branch p6-tabella-dei-fattori.
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
