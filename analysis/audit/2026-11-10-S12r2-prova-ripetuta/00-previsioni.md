# S12r2 — La prova ripetuta del lettore dello studio: cancelli e previsioni

Depositate il 2026-11-10, **prima di ogni calcolo nuovo e prima di ogni corsa**. Dopo il risultato non si
cambiano. La carta sta nella spec `docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md`
(§5.2, §5.3, §5.5, §5.7, blocchi «Aggiornamento 2026-11-10 (S12r2)», commit d59482c).

**Unità:** lo studio. **Incertezza:** bootstrap sugli studi, B = 2.000, seme 20261110. I confronti fra due
lettori, e fra un lettore e la pipeline di oggi, sono appaiati sugli studi.

**Da dove vengono i valori attesi.** Sono giudizio motivato dell'agente, costruito sui numeri della prova v0
(finding `docs/findings/2026-11-09-S12r-prova-lettore-studio.md`). Dove un margine viene da una misura o da una
soglia già usata, la riga lo dice.

**Gli studi.** Gli stessi 47 studi di sviluppo di S12r (`analysis/audit/2026-11-09-lettore-studio/30-divisione.tsv`).
Il risultato vale per lo sviluppo e non è un giudizio: questi studi sono già stati letti una volta. Gli 82 studi
di giudizio restano chiusi.

## Che cosa è già stato visto

- **Tutta la prova v0:** le uscite del lettore v0 sui 47 studi, la curazione di Atlas degli stessi studi, i 145
  disaccordi con la loro causa.
- **In questa sessione, prima del deposito**, solo materiale v0 dei 47 studi, riferimento e metadati:
  `05-diagnosi-v0.py` (da dove nascono il fattore per campione e la base senza campioni), `06-forma-voci-v0.py`
  (forma delle voci), `07-valori-speciali-atlas.R` (dove Atlas scrive «not applicable», valori vuoti e «none»),
  `08-campi-di-tempo.py` (quali studi hanno un campo di tempo in GEO o in Atlas, e con quali valori).
- **La regola del tempo zero e la regola del fattore annidato sono state scritte dopo queste letture.** Sono
  regole per costruzione, ma l'agente sapeva quali studi toccano: tempo zero in `GSE49608`, `GSE103501`,
  `GSE56691`; «not applicable» annidato nella malattia in `GSE57945`, `GSE66207`, `GSE69597`. Per questo i conti
  R1-R3 hanno un valore atteso preciso.
- **Non calcolato prima del deposito:** la classe dei confronti di Atlas con le regole nuove, la misura della
  pipeline di oggi col riferimento nuovo, ogni uscita di un modello con lo schema v1.
- **I modelli più grandi** sono stati scelti dalle schede dei produttori e dai file dei pesi, senza nessuna
  uscita su questi studi.

## Le regole di lettura del riferimento (spec §5.5, aggiornamento)

1. **Tempo zero.** Un confronto di Atlas ha la marca `tempo_zero` quando, in un campo di tempo (fattore di Atlas
   o colonna non costante di GEO col nome che ha «time» all'inizio di una parola), tutti i campioni di un braccio
   hanno un valore zero e l'altro braccio non ha campioni a zero e ne ha almeno uno a un valore successivo.
   Valore zero: un solo numero, uguale a 0. Valore successivo: un solo numero, maggiore di 0. La regola non
   guarda il verso. Nessun elenco di studi.
2. **Fattore non scritto in un braccio.** Non conta come differenza (lettura larga, la stessa regola del
   costruttore). La lettura stretta lo conta come differenza e si riporta accanto.
3. **Fattore annidato.** Il valore «not applicable» di Atlas è il livello riservato «non applicabile»; un fattore
   annidato nel solo fattore che cambia non conta come differenza (spec §5.3).
4. **Identica.** Una partizione vale «identica» solo se non omette campioni di Atlas dell'universo.

| lettura | fattore annidato | tempo zero | fattore non scritto | uso |
|---|---|---|---|---|
| **principale** | regola di §5.3 | fuori dal denominatore | non conta | regola di esito |
| intera | differenza ordinaria | dentro | non conta | la definizione di S12r, accanto |
| stretta | regola di §5.3 | fuori | conta come differenza | sensibilità, accanto |

## Che cosa si corre

Vista: la vista v0, senza cambi (`analysis/audit/2026-11-09-lettore-studio/60-viste-v0.jsonl`, SHA-256
`2382a9ef97cf41d4f487078bd45e2d4c017dda104e8eb002f36881768eb6d86e`). Cambiano lo schema e il prompt (v1), che si
committano prima del primo invio. Per tutti: `temperature = 0`, uscite strutturate, `VLLM_BATCH_INVARIANT=1`,
`HF_HUB_OFFLINE=1`, `max_model_len = 65536`, `max_tokens = 24576` (l'uscita v0 più lunga era di 13.324 token,
l'ingresso v0 più lungo di 30.952), contenitore di produzione vLLM 0.20.2, solo `poddgx02`.

| corsa | modello | revisione | `repetition_penalty` | volte |
|---|---|---|---|---|
| M | `mistralai/Mistral-Small-3.2-24B-Instruct-2506` | `95a6d26c4bfb886c58daf9d3f7332c857cb27b43` | 1,1 | 2 |
| M0 | lo stesso | la stessa | nessuna | 1 |
| G1 | `mistralai/Mistral-Small-4-119B-2603` (ragionamento spento) | `a11f36bebf709121056b1dbcc943d1c6afbe494d` | 1,1 | 2 |
| G2 | `Qwen/Qwen3.5-122B-A10B` (ragionamento spento) | `dc4d348443bc740c68e2d77492492c11606384d5` | 1,1 | 2 |

Un modello che non parte riceve al massimo due tentativi, con la causa letta nel log fra l'uno e l'altro. Se non
parte è «non misurato»: la regola di esito per quel modello è no, e il finding dice perché. Uno studio con
l'uscita troncata, non valida, oltre il contesto, con un campione non coperto o con una mappa ambigua è «non
chiuso»: conta zero gruppi identici e zero confronti, non si toglie.

## Cancelli

- **K1. Riproduzione prima del cambio.** Con la lettura intera il codice aggiornato ridà i numeri di S12r: oggi
  (a) 14/47, (b) 19/93, (c) 19/79; lettore v0 (a) 14/47, (b) 10/93, (c) 1/5.
- **K2. Controllo positivo.** In ognuna delle tre letture, i gruppi e i confronti di Atlas dati allo strumento
  come uscita del lettore danno partizione identica in 47 studi su 47 e ritrovano tutti i confronti del
  denominatore. La marca `tempo_zero` vede il caso noto: i confronti di `GSE49608` contro il tempo «0 hour».
- **K3. Copertura.** Ogni misura copre 47 studi su 47, per ogni corsa e per la pipeline di oggi.
- **K4. Le corse.** Ogni job gira su `poddgx02`, con `VLLM_BATCH_INVARIANT=1` e `HF_HUB_OFFLINE=1` letti da
  `container-env.txt` (solo quelle due righe), con prompt e schema uguali per SHA-256 ai file v1 committati, con
  i 47 testi uguali alla vista v0 e con la revisione del modello fissata qui sopra. Le uscite si congelano con
  SHA-256 prima di ogni misura.
- **K5. Giudizio chiuso.** Nessuno script della sessione legge fattori, livelli, confronti o uscite di uno degli
  82 studi di giudizio.

## Previsioni

**Il riferimento, 47 studi** (conti senza intervallo di confidenza: l'esito è «dentro» o «fuori»).

| | quantità | atteso | intervallo di rilevanza | perché |
|---|---|---|---|---|
| R1 | confronti di Atlas con la marca `tempo_zero`, su 123 | 13 (`GSE49608` 6, `GSE103501` 4, `GSE56691` 3) | 10-16 | S12r ha letto 14 unità «curatore/tempo zero» in 3 studi; fuori dall'intervallo la regola vede una cosa diversa da quella letta, e ogni confronto in più o in meno si legge |
| R2 | denominatore di (b), lettura principale | 97 (93 − 10 + 14) | 83-97 | 10 confronti col tempo zero escono; fino a 14 confronti di `GSE57945`, `GSE66207`, `GSE69597` entrano se «not applicable» era la sola seconda differenza |
| R3 | denominatore di (b), lettura stretta | 86 (82 − 10 + 14) | 72-86 | come R2, partendo dagli 82 di S12r |

**La pipeline di oggi** (master S14 dello Stadio 2, almeno 2 campioni per braccio).

| | quantità | atteso | intervallo di rilevanza | perché |
|---|---|---|---|---|
| O1 | oggi, (b) lettura principale | 15% | 8-25% | dei 19 ritrovati su 93, 6 sono confronti col tempo zero ed escono: 13 su 83; quanti dei 14 nuovi oggi ritrova non è noto |
| O2 | oggi, (a) lettura principale | 14/47 | 14 | la regola «identica» non cambia il conto: 0 partizioni con campioni omessi in S12r |
| O3 | oggi, (c) lettura principale | 22% | 10-35% | 19/79 con la lettura intera; la regola del fattore annidato può togliere alcuni dei 14 «più fattori» |

**Il lettore con lo schema v1.** «Meno oggi» è la differenza appaiata sugli studi. La misura di un modello si fa
sulla prima corsa; se le due corse non sono identiche si riportano tutte e due.

| | quantità | atteso | intervallo di rilevanza | perché |
|---|---|---|---|---|
| L1 | M: studi non chiusi | 5 su 47 | 0-7 | la soglia di S12r (P6): oltre 7 lo schema va cambiato prima di ogni conclusione; v0 ne lasciava 24, 18 per la forma |
| L2 | M: voci di forma sbagliata | 0 | 0 | lo schema v1 non permette la lista per posizione |
| L3 | M: studi con un fattore con un livello per campione | 1 | 0-2 | v0: 7 studi; la causa era nell'ordine e nel testo di schema e prompt |
| L4 | M: studi con una base scritta senza campioni | 1 | 0-2 | v0: 14 studi, 13 per la forma delle voci |
| L5 | M: (a) studi con partizione identica | 55% | 50-80% | la soglia di S12r (P4): sotto il 50% «ordine» non è sostenibile; v0 con la forma tollerata dava 20/47 = 43% con 33 studi chiusi |
| L6 | M meno oggi, (b) lettura principale | +15 punti | l'intervallo al 95% sta sopra 0 | criterio del §5.6 della spec. In S12r l'intervallo era largo circa 15 punti per lato: per Mistral l'esito più probabile è «indeterminata» |
| L7 | M: (c) errori fra i non elencati | 5% | 0-10% | la definizione toglie i confronti con due differenze (S12r P5; v0: 1 su 5) |
| L8 | M: uscite identiche al carattere fra le due corse | 47 su 47 | 47 | misurato in S12r (47/47) e in S12p (1.903/1.903) |
| L9 | M0 meno M, (b) lettura principale | 0 punti | −5, +5 punti | giudizio motivato: se senza penalità il lettore guadagna più di 5 punti, la penalità di produzione va ridiscussa per il lettore (scelta del PI) |
| L10 | M0: uscite troncate (`finish_reason = length`) | 0 | 0-1 | la penalità serve contro le ripetizioni senza fine; con uscite strutturate il rischio è basso |
| L11 | G1 e G2: uscite identiche al carattere fra le due corse | 47 su 47 ciascuno | 47 | richiesta del PI. Giudizio motivato e incerto: Gemma su 2 GPU non era ripetibile, G1 usa 2 GPU e G2 ne usa 4 |
| L12 | G1 e G2: studi non chiusi | 3 su 47 ciascuno | 0-7 | come L1 |
| L13 | G1 e G2: (a) studi con partizione identica | 60% | 50-80% | come L5 |
| L14 | G1 meno oggi e G2 meno oggi, (b) lettura principale | +25 punti | l'intervallo al 95% sta sopra 0 | criterio del §5.6 |
| L15 | G1 meno M e G2 meno M, (b) lettura principale | +10 punti | l'intervallo al 95% sta sopra 0 | se l'intervallo contiene lo 0, la prova non mostra che la capacità del modello è il limite (spec §5.7) |

**Come si giudica.** La stima con il suo intervallo al 95%: tutta dentro l'intervallo di rilevanza = confermata;
tutta fuori = smentita; a cavallo = indeterminata. Per i conti (R1-R3, O2, L1-L4, L8, L10-L12): dentro =
confermata, fuori = smentita.

## Regola di esito, per ogni modello (spec §5.6)

Per un modello la risposta è **sì** quando valgono tutte e quattro:

1. le due corse sono identiche al carattere in 47 studi su 47;
2. nella lettura principale la differenza «lettore meno oggi» dei confronti ritrovati (b) ha l'intervallo al 95%
   sopra 0;
3. nella lettura principale il lettore fa meglio di oggi anche in (a) e in (c), come stima;
4. ogni disaccordo del lettore ha una causa, e ogni causa del lettore ha chi la può togliere: la vista, lo schema
   o, per Mistral-Small 3.2, un modello più grande.

In ogni altro caso la risposta è **no**. Le letture intera e stretta si riportano accanto e non decidono. Con un
sì o con un no il PI vede numeri e cause e decide se si scrive il Piano 2 e con quale modello.

## Che cosa si legge dopo le corse

Tutti i disaccordi di ogni modello misurato, come in S12r: studio non chiuso, partizione non identica, confronto
del riferimento non ritrovato, confronto del lettore giudicato errore. Ogni unità riceve una causa e chi la può
togliere. La lettura la fa l'agente: è audit interno e non entra nell'articolo.
