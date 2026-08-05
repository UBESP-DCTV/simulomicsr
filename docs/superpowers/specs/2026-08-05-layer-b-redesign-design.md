# Ridisegno del report Layer B — la vetrina del progetto

**Data:** 2026-08-05 · **Stato:** design approvato dall'utente, da implementare
**Origine:** l'utente ha aperto `analysis/p4-output/20260805T055939Z-layer-b-bb08afbd/layer_b_report.html`
e lo ha giudicato «indecente e impresentabile». Verificato figura per figura: il
giudizio è fondato, e i difetti sono strutturali, non cosmetici.

---

## 1. Che cosa non funziona, misurato

Le figure sono state aperte e guardate, non dedotte dal codice.

**Il forest** è il caso peggiore, ed è la figura che dovrebbe essere il cuore di una
meta-analisi. Per TGF-β1 con 59 studi mostra **due geni: CD300C e PROK2** — un recettore
immunitario e una prochineticina, senza rapporto con la via del TGF-β. Sono lì perché
hanno l'FDR più basso, ma sono misurati su **5 e 2 studi su 59**: è la catena già
documentata il 2026-07-31 (k basso → τ² stimato 0 → SE collassa → FDR minuscolo). Il
filtro `top_genes_min_k_frac = 0.5`, introdotto proprio contro questo, **non viene
applicato al forest**. Metà pagina resta bianca.

**Il volcano** ha un punto solo (SPINK13, p ≈ 10⁻³¹⁰) che schiaccia il 99% dei geni in
una striscia sul fondo. Le etichette pescano CRNN, GZMK, AMTN, CGB8, CLDN14 — geni
rumorosi — mentre dei bersagli canonici compaiono solo SKIL e PMEPA1.

**La heatmap funziona**: PMEPA1, SKIL, TGFBI, SMAD7, FSTL3, NOX4, IL11, LRRC15 con
separazione netta fra trattati e controlli. È la prova che i dati sono buoni. Ma **un
terzo della figura è una legenda con 47 codici GSE** illeggibili e inutili, e la barra
"Study" in cima è una fascia di 47 colori indistinguibili.

**L'impaginazione**: ogni case study ripete il titolo **tre volte** (`<h2>` poi due
`<h1>`), con l'identificativo interno `cgroup_L5_930c8dcf` in ogni intestazione e nel
sommario.

**La scheda** è un dump di campi tecnici: `safety_min (Stage 3): 0.06`,
`direction_applied distribution: none: 19687`, `n_baseline_studies_augmented: N/A
(non-MEGA-AUG)`, `Anchor: contrast/gain x HGNC:11766 (tissue=control=vehicle_untreated)`.
E `Top gene: CRNN` — cornulina, che col TGF-β non c'entra: è il minimo dell'FDR, non il
risultato. Sotto, un blocco `User notes` ripete in testo grezzo i campi già elencati.

**Le narrative** (Biological context / Findings / Discussion) sono **stub vuoti**.

**Diagnosi:** i dati sono buoni, la loro presentazione no.

---

## 2. Decisioni prese con l'utente

| domanda | decisione |
|---|---|
| destinatario | **vetrina + supplementare insieme**, un documento a due livelli |
| apertura | **agonista contro antagonista** (DHT / enzalutamide) |
| tecnologia | **resta R/Quarto**, figure rifatte da zero, documento statico |
| forest | **pannello dei bersagli + un gene studio-per-studio** |
| narrative | **bozza generata e ancorata ai numeri**, l'utente corregge e firma |
| struttura | **a imbuto**: si scende di dettaglio |
| appendice difetti | **dentro il documento** |

La scelta di restare in R/Quarto è motivata: chiunque rigenera tutto con un comando, e
questo vale come argomento nei Methods. Il prezzo è un documento statico.

---

## 3. La struttura, in quattro tempi

### 3.1 Apertura — una schermata

La prova agonista/antagonista, in grande. Non un grafico generico: i quattro bersagli
canonici del recettore androgenico (KLK3, TMPRSS2, FKBP5, NKX3-1) con le due stime
opposte affiancate, il numero d'insieme (**1.408 geni su 1.441 di segno opposto,
Spearman −0,938**) e una riga che dice perché conta: *i due gruppi sono costruiti
separatamente, da studi diversi, e nulla nella pipeline sa che sono collegati.*

### 3.2 Il corpus — una schermata

Le 214 meta-analisi in una figura sola: distribuzione di `k_effective`, di `I2_med`, dei
geni significativi. Risponde a «quanto è grande questa cosa» senza una tabella.

### 3.3 I nove case study

Per ciascuno, in quest'ordine: **scheda** → **narrativa** → **figure** → **numeri
verificabili**.

### 3.4 Appendice

Metodo di rilevamento dei confronti imperfetti, tabella per gruppo col peso, limiti
dichiarati. Rimanda a `docs/findings/2026-08-05-confronti-imperfetti.md` per il dettaglio
completo.

---

## 4. Le figure

### 4.1 Forest (rifatto)

Due pannelli in una figura:

- **sopra**: 12-15 geni con effetto poolato e intervallo di confidenza, ordinati per
  effetto, **filtrati per essere misurati in almeno metà degli studi** (stessa regola già
  applicata a tabella e heatmap). Si legge il programma biologico in un colpo.
- **sotto**: **un** gene rappresentativo con tutti i suoi studi e la stima poolata in
  fondo, per mostrare l'accordo fra studi — che è ciò che distingue una meta-analisi da
  una lista di geni.

La scelta del gene rappresentativo è **deterministica e dichiarata**: fra i geni misurati
in tutti gli studi, quello con l'effetto assoluto maggiore. La regola va scritta nella
didascalia.

### 4.2 Volcano (corretto)

- asse y **compresso in modo dichiarato** quando un punto domina (soglia esplicita in
  didascalia, mai un taglio silenzioso);
- etichette scelte **solo fra i geni misurati in almeno metà degli studi**;
- il gruppo e il numero di studi nel titolo.

### 4.3 Heatmap (ripulita)

Via la legenda dei 47 codici GSE e la fascia "Study" multicolore; resta la barra
trattato/controllo. Il resto è già corretto e non si tocca.

### 4.4 GO

Resta, con i termini leggibili e non troncati.

### 4.5 Eliminati

**MA plot** (ridondante col volcano) e **pannello di eterogeneità** come figura a sé:
l'I² diventa un numero nella scheda.

Da sei figure a quattro. **Ogni figura porta nel titolo di quale gruppo si tratta e su
quanti studi** — oggi nessuna lo dice.

---

## 5. La scheda

Da elenco di campi a cinque righe che rispondono a cinque domande:

1. **che cosa è stato confrontato** — trattamento contro controllo, in parole;
2. **su quanti studi, e quanto pesano davvero** — `k_effective` e `k_kish` (54,5 su 59),
   più lo studio più pesante se supera una soglia;
3. **quanto concordano** — I² con una parola di lettura;
4. **che cosa si trova** — i bersagli attesi ritrovati, col loro valore;
5. **quanto è sporco** — confronti imperfetti e la loro quota di peso.

Gli identificativi interni (`cluster_id`, `anchor_key`, `run_id`, sha256) escono dalle
intestazioni e finiscono in un blocco di provenienza in fondo alla scheda, dove servono
per la verifica.

**Da rimuovere dalla scheda**: `safety_min`, `direction_applied distribution`,
`n_baseline_studies_augmented`, il blocco `User notes` (ripete i campi già mostrati), e
`Top gene` scelto per solo FDR — sostituito dai bersagli attesi.

---

## 6. Le narrative

Per ognuno dei nove, tre paragrafi brevi:

- **contesto**: cos'è il trattamento e che cosa la letteratura fa attendere;
- **cosa si vede**: i bersagli attesi ritrovati **col loro valore nei dati**, la
  concordanza fra studi, l'eventuale conferma indipendente dall'arricchimento funzionale;
- **limiti di questo gruppo**: confronti imperfetti col peso misurato, dominanza di un
  singolo studio se presente, materiale misto se presente.

**Vincolo:** ogni affermazione numerica deve essere verificabile nel deliverable. Nessuna
affermazione biologica inventata: le attese di letteratura sono dichiarate come tali.
Le narrative restano **marcate come bozza** finché l'utente non le approva.

---

## 7. Che cosa si butta

Titoli triplicati · identificativi `cgroup_L5_*` nelle intestazioni e nel sommario ·
blocco `User notes` · MA plot · pannello di eterogeneità separato · legenda dei 47 studi ·
campi tecnici che non parlano a nessun lettore.

---

## 8. Confini e non-obiettivi

**Non si tocca** nulla a monte delle figure: né il pooling, né il deliverable, né i
verdetti. Questo è un lavoro di presentazione su dati già prodotti e verificati.

**Non si aggiunge interattività** (tabelle filtrabili, grafici navigabili): decisione
esplicita dell'utente per restare nello stack riproducibile.

**Non si ridisegnano** le 214 meta-analisi: il documento ne mostra nove, il resto resta
nel deliverable CSV.

---

## 9. Come si verifica che sia riuscito

Il ridisegno è riuscito se, sull'artefatto prodotto (non sul codice):

1. il forest di TGF-β1 mostra **bersagli della via del TGF-β**, non CD300C e PROK2, e
   ogni gene mostrato è misurato in **almeno 30 studi su 59**;
2. nel volcano nessun punto singolo comprime gli altri sotto il 20% dell'altezza, e
   **tutte** le etichette hanno k ≥ metà degli studi;
3. **zero occorrenze** di `cgroup_L5_` nelle intestazioni e nel sommario;
4. ogni figura ha nel titolo il gruppo e il numero di studi;
5. la heatmap non contiene la legenda dei codici GSE;
6. ogni case study ha la sua narrativa compilata (non uno stub) e la riga dei confronti
   imperfetti col peso;
7. il documento si apre con la prova agonista/antagonista **prima** di qualunque figura
   tecnica.

Ogni criterio è misurabile sull'HTML e sui PNG prodotti, non sul sorgente.

---

## 9bis. Dove si interviene

Codice di pacchetto (con test, come il resto del progetto):

| file | intervento |
|---|---|
| `R/layer-b-plot-forest.R` | riscritto: due pannelli, filtro sul k, scelta deterministica del gene |
| `R/layer-b-plot-volcano.R` | compressione dichiarata dell'asse, etichette filtrate per k |
| `R/layer-b-plot-heatmap.R` | via la legenda degli studi e la fascia multicolore |
| `R/layer-b-summary-card.R` | riscritta: cinque domande, provenienza in fondo |
| `R/layer-b-plot-ma.R`, `-heterogeneity.R` | esclusi dal bundle (codice non rimosso: è selezione, non cancellazione) |
| tema grafico comune | nuovo file, un solo posto per font, colori, griglia |
| template Quarto del report | gerarchia dei titoli corretta, apertura, sezione corpus, appendice |

Il tema grafico va definito **una volta sola** e usato da tutte le figure: oggi ogni
funzione ha il suo, ed è uno dei motivi per cui il documento non sembra un solo oggetto.

---

## 10. Rischi noti

- **Il gene rappresentativo del forest** può cadere su un gene poco interessante se la
  regola è solo «effetto massimo fra i k pieni». Mitigazione: la regola è dichiarata in
  didascalia, e per i nove case study si verifica a occhio che il risultato sia sensato.
- **La compressione dell'asse del volcano** è una manipolazione visiva: va dichiarata in
  didascalia ogni volta che scatta, altrimenti è un taglio silenzioso — la cosa che questo
  progetto ha deciso di non fare mai.
- **Le narrative generate** sono il punto più delicato: affermazioni biologiche su dati
  veri. Restano bozze finché l'utente non le firma.
