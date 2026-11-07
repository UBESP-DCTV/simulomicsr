# Piano della sessione di valutazione (autonoma, notturna) — 2026-11-07

## Domanda del PI
Il progetto `simulomicsr` (database RNA-seq umano ARCHS4 → LLM locale legge i metadati GEO → raggruppa studi
confrontabili → meta-analisi) va (a) rifatto da capo, (b) continuato tappando buchi, (c) tenuto in parte?
Serve un giudizio onesto, sui dati. In più: fattibilità del benchmark «le nostre meta-analisi replicano
meta-analisi pubblicate sugli stessi studi GEO?».

## Fatti già raccolti (dal repo e dal deliverable, non da memoria)
- Imbuto: 508.037 campioni → 24.393 studi → 18.746 con ≥1 confronto (86.212 confronti) → ~4.994 studi
  finiscono in un gruppo → 316 gruppi candidati k≥3 → **194 meta-analisi, 993 studi, 1.903 confronti**
  (2,2% dei confronti; 4,1% degli studi).
- Qualità: 116/62/16 corrette/difettose/incerte alla prima lettura; dopo S11 il riferimento dei confronti
  difettosi è 193/1.903 (10,1%). Solo **40/194** passano tutti i controlli (niente difetti, niente dominanza).
  96 delle altre sono dominate da un solo studio: i loro geni non si distinguono da studi non collegati (1,2×).
- Validazione esterna: 14/19 contro LINCS (63–74%), **11/32 contro Tahoe-100M**. Non separa le 40 dalle 132.
- Nomi: **61/194** `canonical_name` sono ID ChEBI sbagliati o NA (es. «D-cycloserine(1+)» = JQ1, «calcium
  atom», «hydron»). L'etichetta di contrasto è giusta nella maggior parte dei casi, ma il livello dei nomi,
  su cui si è lavorato da maggio a luglio, è ancora rotto nel 31% del deliverable.
- Dinamica: handout 2026-08-21 con 13 cose aperte → oggi 17 (nuove classi di difetto scoperte in S9, S10, S11:
  sinonimi, aggancio tabelle, tempo zero, differenze tecniche). Repo: 1.008 commit dal 2023-02, 74 finding,
  25k righe R di pacchetto + 28k di test + 65k di script di analisi/audit, 914 MB di evidenza di audit.
- Ritrattazioni documentate: 3 dichiarazioni di «deliverable finale / publication-grade» ritirate (lug 2026).

## Criteri di decisione (fissati PRIMA di raccogliere il resto)
1. **Dove nascono i difetti**: Stadio 1/2 (LLM legge male), Stadio 3 (chiave deterministica + ontologie),
   Stadio 4 (statistica), o metadato GEO insufficiente. Se la maggioranza nasce nella chiave deterministica,
   il problema è di architettura, non di modello. Se nasce nella lettura, è di modello/prompt.
2. **Convergenza**: la lista delle cose aperte si accorcia o si allunga a ogni sessione di misura?
3. **Resa del corpus**: quante meta-analisi difendibili escono da 24k studi, e la cifra è pubblicabile come
   risultato (metodo) anche se piccola?
4. **Costo di un ricominciare mirato** rispetto a continuare: ore macchina note (S1+S2 = 33–44 h; S3 2,5 h;
   S4 1,25 h), gold esistenti (756 campioni / 72 studi; 100 minigold; 194 verdetti letti), strumenti di audit.
5. **Stato dell'arte**: qualcuno ha fatto la stessa cosa end-to-end nel 2025-2026? Esistono modelli aperti
   migliori per estrazione strutturata biomedica? (ricerca web)

## Che cosa si fa stanotte
A. Attribuire i difetti del riferimento S11 (193 confronti) allo stadio che li ha generati, dai file di audit.
B. Ricerca web (agente): stato dell'arte LLM+GEO+meta-analisi 2025-2026; modelli aperti attuali; competitor.
C. Ricerca web (agente): meta-analisi pubblicate su RNA-seq GEO che usano i nostri stessi GSE (malattie e
   stimoli grandi); tabella GSE condivisi + geni riportati → fattibilità del benchmark del PI; se un caso è
   chiaro, misurare la sovrapposizione con i nostri geni poolati.
D. Revisione del piano e poi del giudizio da parte di agenti indipendenti (critico del piano; avvocato del
   diavolo sul verdetto finale).
E. Report finale in italiano semplice: verdetto (a/b/c) con i numeri, che cosa tenere, che cosa buttare, che
   cosa farei nelle prime 3 sessioni di ognuna delle tre strade, fattibilità del benchmark.

## Che cosa NON si fa
- Nessuna modifica al codice, al deliverable, ai finding. Nessun commit. Nessun push.
- Nessun run su DGX.
- Non si chiede nulla al PI: giudizio autonomo.

## Revisione del piano (agente critico, 2026-11-07) — adottata
- Verdetto PER COMPONENTE (ETL · master S14 · schema Stadio 1/2 · chiave Stadio 3 · pooling Stadio 4 · audit · docs), poi sintesi.
- Mappa origine→verdetto corretta: difetti nella chiave = economici (re-cluster 2,5 h) → continuare; difetti del modello → rifare SOLO se il gold dice che il modello sbaglia più di quanto il metadato permetta; distinguere «metadato GEO assente» (soffitto) da «metadato presente ma non dato al modello» (ingresso incompleto, correggibile con re-run 33 h).
- Convergenza: verdetti cambiati per giro (S9: 7/194; S11: 15/194), non lunghezza della lista. Costi affondati fuori dai fatti.
- Affermazione dell'articolo assunta: «catena end-to-end LLM→meta-analisi con resa ed errore misurati», NON «atlante delle perturbazioni».
- Validazione esterna senza nullo non entra nel verdetto.
- Due avvocati ciechi (caso migliore per «rifare», caso migliore per «tenere») sugli stessi numeri grezzi; per ogni verdetto «che cosa lo ribalterebbe».

## Soglie depositate PRIMA delle verifiche
- S1. Se i campi GEO di serie (`overall_design`, `summary`, protocolli) NON entrano nello Stadio 1/2 → i difetti «solo nei metadati GEO» (31/37 in S11) sono ingresso incompleto → pesa verso «rifare Stadio 1/2 con ingresso più ricco», non verso «cambiare modello».
- S2. Soffitto: entità con ≥3 studi nello Stadio 3 ignorando il tipo di controllo. Se le 194 sono < 50% del soffitto → la chiave perde metà della resa possibile → ridisegno del raggruppamento; se ≥ 70% → la chiave regge, si continua.
- S3. Controllo biologico (bersagli fissati ad agosto): se ≥ 5 dei 7 bersagli escono col segno giusto e DHT/enzalutamide opposti → il motore statistico tiene e NON va rifatto.
- S4. Attribuzione dei 193: se > 60% nasce nella lettura/ingresso (Stadi 1/2) → la correzione va a monte, le regole dello Stadio 3 (S10-S12) sono un cerotto.
