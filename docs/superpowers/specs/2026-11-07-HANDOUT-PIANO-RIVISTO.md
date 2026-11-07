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
| **S12** | Stadio 2b: il disegno (ADR già scritto; lista di controllo, regola, prompt, previsioni) | carta + codice della regola (TDD) | ~4 h | — |
| **S12p** | La prova che decide: 3 modelli sui 1.903, conto cieco | notte DGX + 1 sessione | ~3 h + 1 notte | **S12** |
| **S12c** (+S12b dentro) | La chiave senza ID del modello; greche, latine, negazione | ADR + codice (TDD) + misura | ~6 h | S9 ✅ |
| **S12d** | Tabelle dei nomi agganciate ai campioni | codice (TDD) + misura | ~4 h | S10 ✅ |
| **S13** | Applicare tutto sui master S14: Stadio 2b su tutti i candidati, chiave, varianza, ruoli, doppi, re-cluster, re-pool | calcolo | ~8 h | **S12p, S12c, S12d** |
| **S15** | Rilettura cieca delle meta-analisi nuove | lettura | 1 sessione | **S13** |
| **S7c** | Seconda validazione esterna con nullo + firme di consenso | misura | ~6 h | **S13** |
| **S7b** | Meta-analisi pubblicate sugli stessi GSE (supplementare) | misura | ~3 h | **S13** |
| **S16** | Figure | produzione | ~4 h | S15, S7c |
| **S17** | Methods e limiti | scrittura | ~4 h | tutto |

**Cancellate:** «S12 — il rilevatore in produzione» (handout di agosto) e «S14 seconda parte» (assorbita in
S13: il re-cluster si fa una volta sola, sui master S14). **Cancelli veri:** S12p←S12, S13←S12p+S12c+S12d,
S15←S13, S7c←S13.

**Se S12p fallisce** (nessun modello prende ≥130/193 con ≤40 falsi allarmi su 1.710): STOP, ADR-0028 torna
`Proposed`, sessione di decisione del PI fra (i) regole come in agosto, (ii) fine-tuning sul gold del progetto
(756 campioni + 193/1.710), (iii) prompt diverso. Non si va a S13.

---

# S12 — Stadio 2b: il disegno

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

# S12c (con S12b) e S12d

Prompt e dettagli nell'handout del 2026-08-21 (sezioni S12b, S12c, S12d). Tre cose cambiano:

- **Il modello non scrive mai un ID**: sceglie fra candidati per indice (SPIRES 97/100 contro 3/100). La
  regola generale di S12c si scrive così.
- **La seconda perturbazione arriva dallo Stadio 2b**, non dalla chiave: S12c non deve inseguirla.
- **Si misura sui master S14** con gli script di S9 (`20-ingressi.R`, `30-due-regimi.R`, `40-analisi.R`,
  35 minuti), non sul master A3.

---

# S13 — Applicare tutto sui master S14

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

Prompt nell'handout del 2026-08-21. Nei Methods entrano, in più: lo Stadio 2b (ADR-0028) con il suo tasso
misurato in S12p e il residuo di S15; il soffitto (455 entità con ≥3 studi, resa del deliverable); il
modello non scrive ID; la dominanza come proprietà di GEO; la finestra competitiva (Soul & Young, GEOMeta,
Wren) nella discussione.
