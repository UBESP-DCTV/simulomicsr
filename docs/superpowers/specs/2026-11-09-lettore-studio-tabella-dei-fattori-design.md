# Il lettore dello studio e la tabella dei fattori — il disegno (spec)

**Data:** 2026-11-09 · **Sessione:** S12q (la strada dopo la prova cieca S12p) · **Branch:** `p6-tabella-dei-fattori`
· **Decisione:** ADR-0029, da scrivere dopo l'approvazione del PI (ADR-0028 esce dal piano) · **Stato:** bozza,
in attesa dell'approvazione del PI · **Evidenza:** `analysis/audit/2026-11-09-lettore-studio/` · **Finding di
partenza:** `docs/findings/2026-11-08-S12p-prova-cieca-stadio2b.md` (§14, la diagnosi)

Chi scrive il piano di implementazione parte da questo documento. Le scelte marcate **[PI]** le ha fatte il PI
nella conversazione del 2026-11-09. Le scelte marcate **[agente]** sono mie: il PI non le ha discusse una per una
e le può cambiare.

---

## 1. Perché

**L'affermazione dell'articolo [PI].** Con un modello linguistico locale si può prendere il database GEO, mettere
ordine nei metadati, trovare i confronti che si possono mettere insieme e unire studi singoli in un risultato
che nessuno studio dà da solo. In breve: meta-analisi basata su un modello linguistico.

L'affermazione ha tre parti, e ogni parte vuole la sua prova:

1. **Ordine.** Il modello legge i metadati di uno studio e scrive il disegno sperimentale come lo scriverebbe un
   curatore umano.
2. **Confrontabilità.** Dai disegni escono confronti trattato-controllo corretti, e confronti di studi diversi
   sulla stessa entità si possono unire.
3. **Sinergia.** La meta-analisi trova segnale che concorda con dati esterni e che i singoli studi non danno.

**Perché cambiare strada.** La pipeline di oggi non converge. La diagnosi (finding S12p §14, più la revisione del
2026-11-09) dà tre cause:

- **Il compito dato al modello è sbagliato.** Lo Stadio 1 legge un campione alla volta, senza vedere gli altri
  campioni dello studio. Lo Stadio 2 riceve i fatti dello Stadio 1 e sceglie i confronti liberamente: nessuna
  istruzione chiede due bracci uguali in tutto tranne il trattamento, e una regola del prompt fa del tempo zero
  un controllo. Risultato: 473 confronti difettosi su 1.903 (24,9%). In 240 dei 473 la differenza fra i bracci
  stava nei fatti che lo Stadio 2 aveva ricevuto. 139 nascono nello Stadio 1 (l'informazione era nel titolo e il
  modello non l'ha scritta). Anche nei confronti puliti i fatti dei due bracci differiscono in 499 casi su 1.430.
- **La definizione di «difetto» cambia a ogni lettura.** 193 difetti alla prima lettura, 473 alla seconda, 85
  categorie di cui 55 con un solo caso. Senza una definizione fissa di «confronto» non esiste un numero stabile.
- **Manca un riferimento umano esterno.** Ogni giudizio sui confronti è venuto da agenti Claude (audit interno,
  non pubblicabile) e sugli stessi studi usati per sviluppare.

Un giudice a valle (lo Stadio 2b, ADR-0028) non ha passato il suo cancello con nessun modello. Il PI rifiuta le
pezze a valle e le catene di regole che sostituiscono il modello: l'errore si corregge dove nasce.

---

## 2. L'idea

**Il modello scrive la tabella dei fattori dello studio. Il confronto segue da una sola definizione fissa.**

È il lavoro che fanno i curatori di Expression Atlas (EBI) e di Gemma (Pavlidis): guardano lo studio intero come
una tabella, un campione per riga, e decidono quali colonne sono fattori sperimentali, quali identificano il
donatore o la replica, quali sono rumore. Dove le colonne mancano leggono i titoli dei campioni e il testo
degli autori.

- **Un solo lettore, una chiamata per studio [PI: «anche in un passo solo»].** Sostituisce lo Stadio 1 e lo
  Stadio 2 di oggi. Il modello vede tutti i campioni dello studio insieme e il testo che gli autori hanno
  scritto sullo studio.
- **Il modello non sceglie i confronti.** Scrive i fattori, i loro livelli, quale livello è il livello di base
  e a quale livello appartiene ogni campione. Il codice forma i confronti.
- **La definizione di confronto [PI, accettata il 2026-11-09 come definizione, non come catena di regole]:**
  due gruppi di campioni dello stesso studio sono un confronto se sono **uguali in tutti i fattori tranne uno**,
  e in quel fattore **uno dei due è al livello di base**. Il gruppo al livello di base è il controllo.
  «Uguali» vale anche per i soggetti (donatore, sesso, età, passaggio), che non formano gruppi ma si confrontano
  come insiemi fra i due gruppi (§5.3).

Che cosa la definizione toglie per costruzione, senza regole dedicate:

| difetto di oggi | perché non si forma più |
|---|---|
| bracci non appaiati (linea, tessuto, tipo cellulare, genotipo diversi) | i due gruppi differiscono in più di un fattore |
| trattati e controlli da donatori diversi | gli insiemi dei donatori dei due gruppi non hanno valori in comune (§5.3) |
| tempo zero usato come controllo | trattato a 6 h contro non trattato a 0 h differisce in due fattori (trattamento e tempo) |
| seconda perturbazione persa | farmaco + siRNA contro veicolo differisce in due fattori |
| differenza tecnica fra i bracci (piattaforma, libreria) | una colonna tecnica che varia è un fattore senza livello di base |
| ruoli assegnati per posizione | i gruppi sono liste di campioni per nome |

---

## 3. Obiettivi, non obiettivi, cose da non fare

**Obiettivi**

- O1. Un lettore che, per ogni studio dei 24.393, scrive la tabella dei fattori in uno schema fisso.
- O2. Un costruttore deterministico che dalla tabella forma tutti e soli i confronti della definizione.
- O3. Una misura dell'accordo con la curazione umana esterna (Expression Atlas), su studi mai usati per
  sviluppare, senza Claude.
- O4. Un deliverable nuovo (v17) dalla catena nuova: lettore → confronti → raggruppamento per entità (Stadio 3)
  → meta-analisi a effetti casuali (Stadio 4), con le correzioni già decise per il ricalcolo (varianza del
  controllo condiviso, studi doppi, campioni cancellati da GEO).
- O5. Le tre prove del §1 scritte con numeri che un revisore può rifare.

**Non obiettivi**

- Annotare ogni campo di GEO (sesso, età, tessuto come fine a sé): è il lavoro di altri strumenti. Qui i campi
  servono solo a formare confronti.
- Rifare l'estrazione da ARCHS4 (Stadio 0), la statistica della meta-analisi, i dizionari.
- Topo, single-cell, microarray.
- Recuperare gli studi che hanno solo trattati o solo controlli (limite L7, resta un limite dichiarato).

**Cose da non fare (anche se «funzionano»)**

- Aggiungere regole «se… allora» dopo il modello per correggerne gli errori. Se un tipo di errore resta, si
  cambia la vista, lo schema o il modello, e si rimisura.
- Sviluppare prompt e schema sugli studi che poi misurano il risultato.
- Chiedere al modello la lista dei confronti, o un giudizio di qualità sul proprio lavoro.
- Usare Claude nella pipeline o in una misura che va nell'articolo.
- Guardare l'esito di una singola meta-analisi per decidere una correzione.
- Dichiarare «finale» senza il gate di coerenza su tutti i gruppi.
- Tagliare in silenzio: uno studio che non entra nel contesto, un campione senza livello, una colonna ignorata
  si contano e si scrivono.

---

## 4. Vincoli

- Solo `poddgx02` (8 GPU H100). Mai `poddgx01`, mai `nodelist = NULL`.
- Modello a pesi aperti, locale, revisione fissata. Container `vllm/vllm-openai:v0.20.2-cu129-ubuntu2404`,
  `temperature = 0`, `VLLM_BATCH_INVARIANT=1`, uscite strutturate (CLAUDE.md §6). Stessa configurazione per tutti
  gli studi.
- Il deliverable v16, la copia su `/mnt/micron/` e i master (A3 e S14) non si toccano. Restano come termine di
  paragone.
- Previsioni e cancelli scritti e committati prima di ogni calcolo. Prova piccola, poi validazione scalata, poi
  STOP e sessione nuova per la corsa intera.
- Zero errori accettati: ogni disaccordo con il riferimento si legge e gli si dà una causa. Non esiste una
  soglia di errore «accettabile» da chiedere al PI.
- Il PI non legge niente a mano. La verifica la progetta e la fa l'agente.
- Convenzioni del repository: TDD a piccoli passi, italiano in codice e commit, mai `git push`.

---

## 5. Il come

### 5.1 Che cosa vede il modello (la vista dello studio)

**Testo dello studio.** Titolo, riassunto (`summary`) e disegno complessivo (`overall design`) scritti dagli
autori. Oggi nessun passo li legge e l'H5 di ARCHS4 non li contiene: si scaricano da GEO una volta, un file per
risposta, con URL, data e SHA-256 in un manifesto (come `26-scarica-geo.py` della sessione S12).

**Tabella dei campioni.** Una riga per campione, una colonna per campo:

- dall'H5: `title`, `source_name_ch1`, ogni chiave di `characteristics_ch1` come colonna propria, e i campi
  tecnici (`library_strategy`, `library_selection`, `library_source`, `molecule_ch1`, `instrument_model`,
  `platform_id`);
- da GEO, congelati: `description`, `treatment_protocol_ch1`, `growth_protocol_ch1`. Oggi li abbiamo per 993
  studi: servono per tutti.

Una colonna con lo stesso valore in tutti i campioni si scrive una volta sola, in testa. I testi passano dalla
riparazione della codifica (`.s2b_norm_testo()`). Un campione cancellato da GEO dopo la copia di ARCHS4 esce
dallo studio e si conta.

**Misura del contesto** (esplorativa, `10-out.txt`; solo titolo, sorgente e caratteristiche; token stimati a
2,29 caratteri per token):

| | mediana | 99° percentile | oltre 32.768 token | oltre 128.000 token |
|---|---|---|---|---|
| tutti i 24.393 studi, vista a tabella | 314 | 8.248 | 49 studi (56.503 campioni) | 4 studi |
| gli stessi, testo campione per campione | 638 | 17.176 | 110 studi | 26 studi |

La misura va rifatta con il tokenizzatore vero e con tutti i campi (descrizione, protocolli, testo dello
studio) prima di fissare il contesto.

**Studi molto grandi [agente].** Quando la tabella non entra nel contesto, il modello riceve la vista compatta:
per ogni colonna i valori distinti con il numero di campioni, e le righe distinte delle colonne con pochi valori.
Le colonne con un valore diverso per ogni campione (in 9 dei 15 studi più grandi ce n'è almeno una) si mostrano
con il conteggio e un numero fisso di esempi. Se l'informazione di un fattore sta solo nei titoli di uno studio
che non entra, una seconda chiamata a blocchi di campioni, con la tabella dei fattori già fissata in testa,
assegna i livelli. Nessuno studio si scarta per dimensione senza una riga nel registro.

### 5.2 Che cosa scrive il modello (la tabella dei fattori)

Lo schema esatto lo scrive chi implementa. Deve contenere questo **[agente]**:

1. **Per ogni colonna non costante, un ruolo:**
   `fattore` · `soggetto` (donatore o paziente, sesso, età, passaggio, lotto, coppia: descrive da chi o da quale
   coltura viene il campione) · `replica` (numero di replica, identificativo del campione) · `non informativa`
   (testo libero che non distingue condizioni). Il titolo può essere fonte di un fattore e insieme contenere la
   replica. Il ruolo `soggetto` esiste perché queste colonne hanno spesso un valore per campione: come fattori
   non lascerebbero gruppi con due campioni, come «non informative» farebbero tornare i 36 difetti che la
   diagnosi ha trovato in donatore, età, sesso e passaggio (finding S12p §14.4).
2. **Per ogni fattore:** un nome, un tipo, le colonne da cui viene, i livelli.
   Tipi: perturbazione (composto, citochina o stimolo, perturbazione genetica, infezione, esposizione fisica),
   stato (malattia contro sano, genotipo del donatore), contesto (linea cellulare, tipo cellulare, tessuto),
   tempo, tecnico.
3. **Per ogni livello:** il testo com'è nei metadati, il nome dell'entità (per le perturbazioni e le malattie),
   e per le perturbazioni dose e durata se scritte. **Il modello non scrive identificativi di ontologia**: il
   nome si risolve dopo, nel codice, sui dizionari. Oggi il modello scrive il nome giusto con l'identificativo
   ChEBI sbagliato e il codice si fida dell'identificativo (finding S9).
4. **Il livello di base** di ogni fattore che ne ha uno (veicolo, non trattato, siRNA di controllo, sano, tipo
   selvatico), con la citazione del testo che lo sostiene. Un fattore di tipo contesto, tempo o tecnico **non ha
   livello di base**: stratifica e basta.
5. **L'assegnazione:** per ogni colonna fonte, la mappa «valore distinto → livello». Il modello scrive la mappa,
   non l'elenco dei campioni: per una colonna con 6 valori su 500 campioni sono 6 righe. Per un fattore che sta
   nel titolo la mappa ha una riga per titolo distinto.
6. **Il livello «non scritto».** Quando i metadati non dicono il livello di un fattore per un valore (il caso
   comune: il veicolo senza un tempo, accanto a trattati a 6 h e 24 h), il modello scrive il livello speciale
   `non scritto`. Non indovina. Un fattore che per un campione vale «assente» (nessun secondo agente, nessun
   siRNA) non è «non scritto»: è il livello di base di quel fattore.
7. **Che cosa non ha capito:** campioni o valori che non sa assegnare, con il motivo. Non è un giudizio di
   qualità: è la lista dei buchi.

La dose è un attributo del livello, non un fattore a parte **[agente]**: «farmaco 1 µM» e «farmaco 10 µM» sono
due livelli dello stesso fattore, ognuno confrontabile con il veicolo. La durata del trattamento invece è il
fattore tempo quando lo studio ha più tempi: il confronto vale solo fra gruppi allo stesso tempo.

### 5.3 Dal modello al confronto (codice, deterministico)

1. Applica le mappe e costruisci la matrice «campione × fattore». Ogni campione ha un livello in ogni fattore,
   anche solo `non scritto`. Un campione che la mappa non copre ferma lo studio con un errore diagnostico
   contato, non un salto silenzioso.
2. Un **gruppo** è l'insieme dei campioni con gli stessi livelli in tutti i fattori.
3. Per ogni coppia di gruppi applica la definizione del §2. Il confronto porta: il fattore che cambia, il
   livello trattato con la sua entità, il livello di base, i livelli di tutti gli altri fattori (il contesto), i
   campioni dei due gruppi per nome, le colonne di soggetto, gli avvisi.
4. **«Non scritto» non conta come differenza e si marca.** Due gruppi che differiscono solo perché in un
   fattore uno dei due è `non scritto` restano confrontabili: il confronto passa con un avviso che nomina il
   fattore. È la decisione 3 del PI del 2026-11-08 («non detto» è un avviso, non un errore), portata qui. Un
   tempo zero scritto resta una differenza: nessun confronto.
5. **I soggetti si confrontano come insiemi.** Per ogni colonna di ruolo `soggetto` il codice confronta i valori
   dei due gruppi. Sono le decisioni del PI del 2026-11-08, portate qui:
   - confronto su una perturbazione: donatori senza valori in comune → nessun confronto. Donatori in parte
     comuni → confronto con avviso;
   - confronto su uno stato (malati contro sani): i donatori sono diversi per forza → avviso. Sesso o età senza
     valori in comune → nessun confronto. Sesso o età in parte comuni → avviso;
   - passaggio e lotto seguono la regola dei donatori **[agente]**.
6. Gate di oggi sul numero di campioni per braccio (`n_min = 2`), invariato.

Gli esiti sono tre: confronto, confronto con avviso, nessun confronto. Gli avvisi vanno nel record del confronto
e nel registro. Il deliverable si calcola con tutti i confronti e, come analisi di sensibilità, senza quelli
con avviso. Ogni coppia di gruppi che non diventa confronto ha nel registro il motivo (quali fattori o soggetti
differiscono): serve a contare che cosa la definizione toglie.

Conseguenze da sapere **[agente, da confermare con il PI nel piano]**:

- Uno studio a serie temporale con il solo tempo zero come non trattato non dà confronti. È la decisione del PI
  («tempo zero sempre errore») applicata dalla definizione.
- Un confronto dentro un secondo trattamento (farmaco contro veicolo, tutti con lo stesso siRNA) è valido per la
  definizione. Porta il contesto scritto. Il raggruppamento lo tiene separato dai confronti senza secondo
  trattamento finché il PI non decide diversamente.
- Un fattore di stato (malattia contro sano) dà confronti fra persone diverse: i confondenti non dichiarati
  restano. È un limite già presente oggi, da scrivere nei Methods.

**Disegno appaiato.** Oggi il modello per studio è `~ treatment` (`R/stage4-limma-de.R`). Con il donatore
dichiarato si può stimare `~ donatore + trattamento` quando i due gruppi condividono i donatori. Il piano lo
tratta come un cambio separato, misurato prima e dopo, non come parte del lettore.

### 5.4 Che cosa resta e che cosa esce

| resta | esce dal percorso verso l'articolo |
|---|---|
| Stadio 0 (ARCHS4, bacino di 508.037 campioni, filtri) | Stadio 1 (un campione alla volta) |
| Stadio 3: raggruppamento per entità, recupero del nome, coerenza. L'ingresso si adatta ai confronti nuovi | Stadio 2 (scelta libera dei confronti) |
| Stadio 4: limma-voom per studio, collasso dei bracci, meta-analisi a effetti casuali, gate a 3 studi | Stadio 2b, il giudice a valle (ADR-0028) |
| dizionari, cache delle conte, strumenti di audit, controllo biologico, validazione esterna | il rilevatore a regole (già fuori, S10) |
| master S14 e deliverable v16 come termine di paragone | |

Il codice degli Stadi 1, 2 e 2b non si cancella in questo lavoro: resta nel repository, fuori dal percorso.

### 5.5 Come si misura (senza Claude)

**Linea 1 — la curazione umana di Expression Atlas (la prova di «ordine» e di «confrontabilità»).**
Atlas ha 129 esperimenti umani RNA-seq differenziali che corrispondono a uno studio dei nostri 24.393
(`20-atlas-studi-nostri.txt`). I curatori hanno scritto per ognuno i fattori per campione e i confronti:
325 confronti, 456 gruppi, 8.665 campioni nei gruppi (`21-out.txt`). I file stanno sull'FTP di EBI
(`<accession>-configuration.xml`, `<accession>.condensed-sdrf.tsv`). I campioni di Atlas sono numeri SRR:
il legame con i nostri GSM passa dall'API di ENA (provato: SRR1039508 → GSM1275862) o dal campo `relation`
dell'H5, che contiene l'SRX.

- **Divisione in tre parti, fissata prima di scrivere il prompt [agente].** I 12 studi che stanno anche fra i
  993 già letti vanno nello **sviluppo**, perché li abbiamo già guardati. Gli altri 117 si dividono con una
  regola deterministica sul numero GSE (da depositare nelle previsioni) in tre parti circa uguali: sviluppo,
  **giudizio A**, **giudizio B**. In tutto circa 51 studi di sviluppo, 39 e 39 di giudizio.
- **Che cosa è chiuso.** Degli studi di giudizio non si guardano fattori, livelli, confronti e uscite del
  modello fino all'apertura. Si possono eseguire prima i passi che usano solo identificativi: scarico dei file,
  lettura dell'XML, legame SRR-GSM, conteggio dei campioni legati. Gli script di questi passi non stampano
  nomi di fattori o di confronti. Così un guasto dello strumento non si scopre all'apertura.
- **Misure.** (a) **Gruppi:** la partizione dei campioni in gruppi del modello è la stessa partizione dei
  gruppi di Atlas? È la misura principale di «ordine». Si confrontano le partizioni e non i fattori uno a uno,
  perché i curatori scrivono a volte due trattamenti come un solo fattore con un livello combinato (in
  E-GEOD-52778 «albuterol and dexamethasone») e il lettore li scrive come due fattori: la partizione è la
  stessa. L'accordo fattore per fattore si riporta come misura secondaria. (b) **Confronti ritrovati:** per
  ogni confronto di Atlas (due insiemi di campioni e un verso) esiste lo stesso confronto fra i nostri?
  (c) **Confronti nostri che Atlas non elenca:** i curatori non scrivono tutti i confronti possibili, quindi si
  giudicano applicando la definizione del §2 ai **fattori di Atlas**. Un nostro confronto i cui due gruppi
  differiscono in più di un fattore di Atlas è un errore.
- **Quando il curatore e la definizione non concordano.** Alcuni confronti di Atlas non rispettano la
  definizione: due fattori che cambiano insieme (in E-GEOD-65335 interleuchina 13 a 14 giorni contro non
  trattato a 8 giorni), o un confronto fra due contesti. Il lettore nuovo non li forma per costruzione, la
  pipeline di oggi li può formare. Per i fattori e i gruppi fa fede il curatore. Per i confronti si riportano
  due classi separate: i confronti di Atlas che rispettano la definizione applicata ai fattori di Atlas
  (denominatore della misura b) e quelli che non la rispettano (contati, con quanti ne forma ognuna delle due
  pipeline, fuori dal denominatore). Senza questa separazione la misura premia chi forma confronti con due
  differenze.
- **Il termine di paragone.** La stessa misura si fa sui confronti della pipeline di oggi (master S14 dello
  Stadio 2) sugli stessi studi, con lo stesso script. Il lettore nuovo deve fare meglio di oggi nelle tre misure. Questo
  dà anche il primo numero esterno del progetto.
- **Il cancello, prima della corsa intera [agente].** Con prompt, schema, vista e modello congelati si apre il
  giudizio A. Il suo numero si scrive com'è. Ogni disaccordo si legge e riceve una causa: errore del lettore,
  errore o scelta diversa del curatore, strumento. Se non ci sono errori del lettore, il giudizio B si apre
  subito e i due numeri insieme sono il numero dell'articolo. Se ci sono errori del lettore, la causa si
  corregge (vista, schema o modello, non una regola a valle), si congela di nuovo e si apre il giudizio B: quello
  è il numero dell'articolo, e il numero del giudizio A si riporta come misura prima della correzione. Se anche
  il giudizio B mostra errori del lettore, il PI vede numeri e cause e decide. La corsa intera parte dopo il
  cancello, non prima.
- **Limite da dichiarare.** 129 studi scelti dai curatori: più studi di malattia e meno studi su linee
  cellulari rispetto al nostro bacino. Gemma ne ha di più, ma la sua API non ha risposto il 2026-11-09 (da
  riprovare: se risponde, entra come seconda fonte con la stessa divisione).

**Linea 2 — il gold del PI.** `data-raw/relevant_sample_classified.xlsx`: ruolo trattato o controllo per
130.784 campioni di 5.367 studi. Accordo del ruolo, come misura e non come cancello, perché la definizione del
gold («qualunque intervento esplicito») è diversa.

**Linea 3 — le conte.** Il sesso dai geni (XIST, cromosoma Y) e la struttura dei campioni contro ciò che il
modello ha scritto. Misura indipendente dal testo. Non è un filtro.

**Linea 4 — i 1.903 confronti letti dagli agenti.** Solo per lo sviluppo: quanti dei 473 difettosi si formano
ancora, quanti dei 1.430 puliti restano. Non va nell'articolo come validazione.

**Linea 5 — il risultato (la prova di «sinergia»).** Controllo biologico con i bersagli fissati dalla
letteratura, LINCS, Tahoe-100M, TCGA con un nullo (il disegno della validazione esterna resta quello delle
sessioni S6-S7), più il confronto «meta-analisi contro singolo studio» sugli stessi bersagli.

### 5.6 Prima una prova piccola da buttare

Prima di scrivere codice di pacchetto si fa una prova breve **[PI ha accettato l'ordine; i dettagli sono
dell'agente]**:

- solo gli studi di Atlas dello sviluppo, Mistral-Small 3.2, un prompt e uno schema di prima versione;
- script in `analysis/audit/2026-11-09-lettore-studio/`, nessun file in `R/`, niente test: è materiale da
  buttare e resta marcato così;
- previsioni depositate prima: la misura di oggi (master S14) sugli stessi studi è il riferimento;
- esito: se il lettore ritrova i confronti dei curatori meglio della pipeline di oggi e ogni disaccordo ha una
  causa che la vista, lo schema o un modello più grande possono togliere, si passa al piano. Se no, il PI vede
  i numeri e decide prima di spendere altro.

Che cosa si porta nel piano dalla prova: la vista che funziona, i tipi di disaccordo, la lunghezza vera delle
uscite, il tempo per studio.

### 5.7 I modelli

- Base: `mistralai/Mistral-Small-3.2-24B-Instruct-2506`, configurazione di produzione, contesto da alzare a
  quanto serve per la vista (il modello regge 128.000 token; `max_model_len` oggi è 32.768 o 65.536).
- Modelli più grandi **[PI: d'accordo]**: dopo la prova, uno o due modelli aperti che entrano nelle 8 GPU di
  `poddgx02`, misurati sugli stessi studi di sviluppo con la stessa vista. La diagnosi indica compito e vista,
  non la capacità: per questo vengono dopo. La scelta dei candidati è di chi implementa, con la revisione
  fissata e la prova di ripetibilità al carattere (Gemma-4-31B non era ripetibile).
- Un solo modello va in produzione, lo stesso per tutti gli studi.

### 5.8 Le fasi che il piano deve coprire

| fase | che cosa | chiude con |
|---|---|---|
| 0 | prova da buttare sugli studi di sviluppo (§5.6); lettura per intero dei lavori concorrenti | numeri al PI, decisione di andare avanti |
| 1 | ingresso: scarico e congelamento dei testi GEO di studio e di campione per i 24.393 studi; costruttore della vista; misura esatta dei token | manifesto, test |
| 2 | schema, prompt, costruttore dei confronti (codice di pacchetto, TDD) | test verdi, ADR-0029 |
| 3 | strumenti di misura: Atlas (legame SRR-GSM, tre misure), gold, conte | misura di oggi riprodotta sullo sviluppo |
| 4 | prova scalata su DGX (sviluppo + un campione del bacino), scelta del modello, ripetibilità; congelamento | previsioni per il cancello depositate |
| 5 | il cancello: giudizio A, poi giudizio B (§5.5) | finding con il numero dell'articolo; STOP, sessione nuova |
| 6 | corsa intera sui 24.393 studi | master nuovo, con SHA-256 e copia |
| 7 | i nomi delle entità: la chiave senza identificativi scritti dal modello, lettere greche, latine e negazione, tabelle dei nomi agganciate ai campioni (le sessioni S12c, S12b e S12d dell'handout, che restano prerequisiti del ricalcolo) | misura sui confronti nuovi |
| 8 | Stadio 3 sui confronti nuovi, Stadio 4 con le correzioni già decise, deliverable v17, gate di coerenza su tutti i gruppi | deliverable |
| 9 | validazione del risultato (§5.5 linea 5) e rilettura cieca interna | finding |

**Sulla fase 7.** Oggi lo Stadio 3 costruisce la chiave dai fatti dello Stadio 1, che portano identificativi
scritti dal modello (`R/stage3-build.R` riceve `stage1_master` e `stage2_master`). Con il lettore nuovo la chiave
parte dai nomi dei livelli. Non è un adattatore sottile: è il lavoro che l'handout chiama S12c, con i suoi
cambi già scritti (il modello non scrive mai un identificativo; dove i dizionari danno più candidati sceglie
fra i candidati per indice, quindi una seconda chiamata al modello è ammessa). La seconda perturbazione non
è più compito della chiave: arriva dalla tabella dei fattori.

L'handout (`2026-11-07-HANDOUT-PIANO-RIVISTO.md`), `CLAUDE.md` §1 e lo stato di ADR-0028 si aggiornano quando il
PI approva questo documento. La sessione S12p si chiude nello stesso passo: le sue due decisioni aperte (i 280
difetti nel riferimento, dove correggere per primo) sono superate da questa strada.

---

## 6. Rischi

| rischio | che cosa si fa |
|---|---|
| Il modello non scrive bene la tabella negli studi disordinati | lo dice la fase 0, prima di investire; poi vista, schema, modello più grande |
| La definizione è stretta e i confronti calano (oggi 455 entità hanno almeno 3 studi nel raggruppamento) | si misura il numero di entità con almeno 3 studi prima della corsa dello Stadio 4; il calo si dichiara, non si allarga la definizione |
| Atlas non rappresenta gli studi su linee cellulari | Gemma come seconda fonte; il limite nei Methods |
| Il livello di base è ambiguo (più controlli: veicolo, non trattato, siRNA di controllo) | lo schema ammette un livello di base per fattore con citazione; i casi con più candidati si contano nella fase 0 e si decide lì |
| Uscite lunghe non ripetibili o troncate | mappa per valore distinto, non per campione; prova di ripetibilità; uscite troncate contate come fallimenti |
| Altri gruppi pubblicano prima (GEOAgent, bioRxiv giugno 2026, «resolves experimental design pairings» su oltre 180.000 serie; un preprint Research Square con un modello locale che usa riassunto e disegno complessivo) | letti solo titoli e riassunti: vanno letti per intero nella fase 0. Non ho trovato lavori che uniscono confronti estratti da un modello, meta-analisi a effetti casuali RNA-seq e validazione contro curazione umana: è lì che sta il contributo |

---

## 7. Lasciato a chi implementa

Nomi dei file e delle funzioni, forma esatta dello schema JSON, testo del prompt, formato della vista (TSV,
Markdown o altro: lo decide la fase 0), regola esatta della divisione sviluppo / giudizio (purché deterministica
e depositata prima), soglia di token per passare alla vista compatta, candidati per i modelli grandi, adattatore
fra i confronti nuovi e l'ingresso dello Stadio 3, organizzazione dei job sul DGX.


---

## 8. Che cosa il PI deve controllare leggendo

**Decisioni del PI già prese, portate in questo disegno senza cambi:**

- tempo zero e differenza tecnica fra i bracci sono sempre errori (qui: nessun confronto);
- «non scritto» è un avviso, non un errore (2026-11-08, decisione 3);
- donatori senza valori in comune in un confronto di trattamento: errore. In parte comuni: avviso. Malati contro
  sani: donatori diversi avviso, sesso o età senza valori in comune errore (2026-11-08, decisione 2);
- gate a 3 studi, varianza del controllo condiviso, studi doppi, campioni cancellati da GEO tolti;
- solo `poddgx02`, nessun Claude nella pipeline e nelle misure dell'articolo.

**Scelte dell'agente, in ordine di peso:**

1. Il cancello in due aperture (giudizio A e giudizio B) prima della corsa intera, e che cosa succede se il
   giudizio A mostra errori del lettore (§5.5).
2. Per i fattori fa fede il curatore, per i confronti fa fede la definizione. I confronti di Atlas che non
   rispettano la definizione stanno fuori dal denominatore e si contano a parte (§5.5).
3. Uno studio con il solo tempo zero come non trattato non dà confronti (§5.3).
4. Un confronto dentro un secondo trattamento è valido e sta in un gruppo separato (§5.3).
5. La dose è un attributo del livello, non un fattore (§5.2).
6. Passaggio e lotto seguono la regola dei donatori (§5.3).
7. Il deliverable si calcola con tutti i confronti, e senza quelli con avviso come analisi di sensibilità
   (§5.3).
8. I modelli più grandi vengono dopo la prova piccola (§5.7).
9. Il disegno appaiato per donatore nel modello per studio è un cambio separato (§5.3).

**Revisione.** Un revisore indipendente ha letto questo documento il 2026-11-09 come chi deve scrivere il piano.
Ha posto cinque domande: i livelli non scritti, i soggetti, i confronti di Atlas fuori definizione, il cancello,
i nomi delle entità. Le risposte stanno nei §5.2, §5.3, §5.5 e §5.8. Nessuna richiedeva una decisione nuova del
PI: tre erano già decise dal PI o dall'handout, due sono scelte dell'agente (punti 1 e 2).
