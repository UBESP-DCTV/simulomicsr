# Prompt di apertura per la prossima sessione

> Da incollare come primo messaggio. Copia tutto il blocco qui sotto.

---

Leggi per intero, PRIMA di qualunque azione:
`docs/superpowers/specs/2026-08-03-v15-LANCIO-HANDOUT.md`

È autosufficiente: stato provato, comandi esatti, l'atteso scritto prima del run, e le trappole con la
loro misura.

**IL MANDATO, invariato:** il re-cluster v15 deve essere l'ULTIMO. Se ne serve un sedicesimo, il
progetto è dichiarato fallito.

**LA DIFFERENZA RISPETTO ALLE SESSIONI PRECEDENTI:** questa volta il lavoro di preparazione è **finito
e verificato**, e non c'è niente da correggere prima di lanciare. Ventisette commit, tredici task in
TDD ciascuno con revisione indipendente, una revisione finale sull'intero ramo, e la rilettura dei 49
gruppi che nessuno aveva mai letto. Il cancello è passato su quattro misure: suite intera 0 FAIL /
4153 PASS, regola verificata sui dizionari veri, smoke che esercita davvero la de-frammentazione, e
sul corpus 97 membri cambiati con tutte le invarianti a zero.

**QUINDI IL TUO COMPITO NON È CERCARE ALTRI DIFETTI.** È eseguire, in quest'ordine:

1. **Verifica di partenza** (dieci minuti, non di più): albero pulito, suite verde, e che esistano
   `analysis/audit/2026-08-02-fix/verdetti-poolato-v15.csv` (24 righe) e
   `analysis/audit/2026-08-02-fix/00-atteso-v15.md`.

2. **Lancia il re-cluster** (~9 h) col comando del §3.1 dell'handout. `setsid`, verifica che SID sia
   uguale a PID, **aggiornamento ORARIO** durante il run.
   ⚠️ Per aspettare usa il **PID**, mai un pattern di testo: un ciclo che cerca i processi per nome
   trova se stesso e non esce mai. È già successo.
   ⚠️ Non lanciare suite di verifica mentre il run scrive i file.

3. **Verifica l'output** (§3.2): le cinque invarianti vanno ri-misurate **sull'output vero**, non sul
   dump — il dump non vede il ramo `anchor`. Poi confronta con `00-atteso-v15.md`, che è stato scritto
   **prima** apposta perché il confronto sia con una previsione depositata e non con un ricordo.

4. **Lancia il re-pool** (~28 h) col comando del §3.3, passando **entrambe** le variabili
   (`STAGE3_DIR` e `VERDETTI_PATH`): senza, lo script si ferma al minuto zero, ed è voluto.

5. **Poi** il Layer B, ricostruito sul pool nuovo, con la selezione **rigenerata dal deliverable nuovo**
   (le note del CSV attuale contengono 181 numeri di v13 scritti a mano: è l'unico canale che nessuna
   guardia può intercettare, perché è testo libero).

**SE UN NUMERO NON TORNA, FERMATI E DILLO.** Non aggiustare la regola per far quadrare il conto: è
esattamente il modo in cui si arriva a una sedicesima versione. L'atteso separa **tre** effetti distinti
sul deliverable (de-frammentazione −1 riga, dedup +49 gruppi candidati, `record_id` che cambia il k di
sette gruppi): un conteggio finale diverso da 191 è il risultato voluto, non una regressione.

Regole invariate: branch `review-scientific-consistency-2026-06-10`, master invariato, **no push**. Run
pesanti solo con `setsid`. `Rscript` **senza** `--vanilla`. Nessun LLM dentro la pipeline. Parlami come
a un essere umano: breve, chiaro, senza gergo. Fail onesto coi numeri.
