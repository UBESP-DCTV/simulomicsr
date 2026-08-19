# HANDOUT — Leggere tutte e 194 le meta-analisi, e dire se sono GIUSTE

**Scritto:** 2026-08-19 · **Branch:** `review-scientific-consistency-2026-06-10` · master invariato
**Deliverable da leggere:** `/mnt/wwn-0x5000039d58caca35/simulomicsr-stage4-v16/20260819T185517Z-stage4-v16-3e31e59d`

> **Questo file è autosufficiente.** Non serve leggere le conversazioni precedenti.

---

## 0. Il mandato, con le parole dell'utente

> «Cosa ci frega del numero. Stiamo sviluppando un metodo. Il numero è totalmente
> inutile. Devono essere corrette e basta, anche se fossero 2.»

La sessione precedente ha misurato **quanto** si muove il deliverable rifacendo
gli stadi LLM: 211 meta-analisi diventano 194, 38 escono, 21 entrano. È una
statistica sull'instabilità, e non è la domanda. La domanda è se le meta-analisi
che il metodo produce siano **giuste**.

**Questa sessione legge tutte e 194 e dà un verdetto per ciascuna.** Non un
campione, non i soli casi che si sono mossi.

---

## 1. Che cosa vuol dire «giusta», operativamente

Una meta-analisi è corretta quando **tutti i confronti che raggruppa misurano lo
stesso contrasto**: la stessa entità, nella stessa direzione, contro un controllo
dello stesso tipo. Non è un giudizio sul risultato biologico — è un giudizio
sull'appaiamento, e si legge sulle **etichette dei bracci**.

Un difetto va dichiarato solo se è **leggibile nell'etichetta che si cita**. Un
sospetto non provabile è un sospetto, e va scritto come tale.

---

## 2. Il vantaggio che questa sessione ha, e le precedenti no

Esistono **due esecuzioni della stessa catena** che differiscono solo per gli
stadi LLM:

| | riferimento v16b | A3 |
|---|---|---|
| pool | `.../20260815T193851Z-stage4-v16-3e31e59d` | `.../20260819T185517Z-stage4-v16-3e31e59d` |
| Stadio 3 | `analysis/p4-output/20260815T231154Z-stage3-v16-7f986159` | `analysis/p4-output/20260818T110906Z-stage3-v16-7f986159` |
| meta-analisi | 211 | 194 |

Dove le due divergono, **il giudizio è comparativo invece che assoluto**, ed è
molto più facile: non «questo gruppo è corretto?» ma «di queste due assegnazioni
dello stesso studio, quale è quella giusta?».

Le tre risposte possibili portano a tre conclusioni diverse sul metodo, e vanno
tenute distinte:

1. **il run nuovo sbaglia dove il vecchio azzeccava** → il problema è la
   variabilità del modello, e va contenuta a monte;
2. **il nuovo azzecca dove il vecchio sbagliava** → il deliverable corrente
   contiene errori che nessuno aveva visto;
3. **sono entrambe difendibili** → l'etichetta sorgente è ambigua, e il metodo
   deve dichiararlo invece di scegliere in silenzio.

Il caso più frequente è già noto: **13 studi delle sole cinque entità bandiera**
si sono spostati perché il tipo di controllo è stato normalizzato diversamente —
da `vehicle_untreated` a `unknown`, `ctrl`, `nt`, `nc`, `sicontrol`, `undiff`,
`pre treatment`. Lì il verdetto si dà: se lo studio ha davvero un braccio veicolo
o non trattato, `vehicle_untreated` è corretto e `unknown` è un peggioramento; se
non ce l'ha, è il contrario.

---

## 3. Il materiale, e come si prepara

**Dimensione del lavoro** (contata sul deliverable A3, non stimata):

| | |
|---|---:|
| meta-analisi da leggere | **194** |
| coppie gruppo-studio | 1.381 |
| k mediano | 4 (min 3, max 54) |
| gruppi con k ≥ 15 | 14 |
| gruppi con k 3-4 | 114 |
| già dichiarate incoerenti | 4 |

**Lo script del materiale esiste già** e va adattato al pool nuovo:
`analysis/audit/2026-08-05-rilettura-214/00-materiale.R`. Estrae, per ogni
gruppo, i confronti **effettivamente poolati** (da `per_study_de.parquet`, non i
membri censiti dallo Stadio 3) con le etichette **intere** dei due bracci,
risolte dallo Stadio 2 via `.split_record_id()` / `.lookup_cmp()`.

Per il giudizio comparativo serve una colonna in più che quello script non ha:
per ogni studio, **dov'era nel run di riferimento e dov'è ora**. Gli strumenti
per ricavarla sono già scritti e funzionanti:
`analysis/audit/2026-08-16-A3/80-movimento-bandiera.R` (fa esattamente questo
sulle cinque bandiera) e `90-confronto-v16b.R` (confronto per chiave del
contrasto).

---

## 4. Le trappole, con la loro misura

Sono tutte già costate al progetto. Non sono ipotesi.

1. **Le etichette troncate.** Tre volte un verdetto è stato dato su mezza frase
   (alias corti, lettere greche cancellate, testo tagliato a 58 caratteri:
   `GSE126517`, dove il pezzo mancante era `and IFN-alpha for 18 hours`). Lo
   script del materiale **misura la distribuzione delle lunghezze e segnala i
   picchi**: i picchi vanno ispezionati uno per uno, non ignorati.
2. **Il censito non è il poolato.** Il 2026-08-05 il materiale elencava i
   confronti di uno studio non appena lo *studio* compariva nel poolato, senza
   `n_min` né dedup: **47 accuse su 85 riguardavano confronti che nel deliverable
   non c'erano**. Il tasso vero era 7,1%, non 10,1%.
3. **Nei caso-controllo di malattia i soggetti diversi sono obbligatori.** Il
   primo rilevatore di righe sbagliava per questo nel **52%** delle segnalazioni.
4. **Contare per studio, non per destinazione.** Uno studio di screening con
   duecento composti (`GSE199800`) da solo domina qualunque conteggio fatto per
   destinazione.
5. **Un critico solo, spinto alla severità, produce solo condanne.** Il
   2026-08-05: 24 verdetti cambiati, **tutti** verso il peggio, zero assoluzioni.
   Il 2026-08-06, con due critici simmetrici: 112 rilievi accettati, 21 respinti
   con argomento, 15 disaccordi escalati. La differenza è nel disegno, non nei
   dati.
6. **`.narrativa_bozza()`**, cioè testo generato da un template a partire dalle
   colonne: formalmente corretto e scientificamente vuoto. Rimossa. Non
   reintrodurla in nessuna forma.

---

## 5. La procedura

Un workflow, per blocchi di gruppi:

1. **lettore** — riceve le etichette intere dei confronti poolati di un blocco e
   dà un verdetto per gruppo, citando l'etichetta;
2. **due critici simmetrici** — uno sostiene che il lettore ha accusato troppo,
   l'altro che ha accusato troppo poco. Simmetrici sul serio: stesso peso, stessa
   lunghezza di prompt, stessa istruzione a non gonfiare;
3. **arbitro** — decide sull'etichetta, non sull'autorevolezza, e dichiara i casi
   che l'etichetta non chiude.

**Sui disaccordi che restano aperti**, la regola è già stata fissata e applicata
il 2026-08-07: **nel dubbio si sceglie la lettura che non sovrastima la qualità
del dato**, e la scelta si dichiara. La regola vale in tutte e due le direzioni:
dove l'etichetta *decide* che il confronto è pulito, resta pulito.

Per i gruppi che divergono fra le due esecuzioni, il lettore riceve **entrambe le
assegnazioni** e risponde alla domanda comparativa del §2.

---

## 6. Il criterio di riuscita

Non «il metodo è validato». La sessione riesce se produce:

1. **un verdetto per ciascuna delle 194**, con l'etichetta citata accanto —
   nessun gruppo lasciato senza lettura, nemmeno i 114 a k=3-4;
2. per i gruppi che divergono fra le due esecuzioni, **quale delle due
   assegnazioni è corretta**, classificata secondo i tre casi del §2;
3. **la tassonomia dei difetti trovati**, che è il risultato utile al metodo: se
   il 70% dei difetti è una sola cosa (per esempio la normalizzazione del
   controllo), quella cosa si corregge a monte;
4. la dichiarazione onesta di **quanti verdetti l'etichetta non ha chiuso**.

---

## 7. Che cosa NON è questo lavoro

- Non è un re-pool né un re-cluster: il deliverable è quello, e si legge quello.
- Non è la conta di quante meta-analisi cambiano: è già stata fatta ed è, con le
  parole dell'utente, «totalmente inutile».
- Non è la scrittura dell'articolo.
- Non è la validazione esterna, che resta il problema aperto separato
  (`docs/superpowers/specs/2026-08-08-validazione-esterna-HANDOUT.md`).

---

## 8. Riferimenti

- Il movimento misurato: `docs/findings/2026-08-19-a3-movimento-stadio3.md`
- Metodo e numeri della rilettura precedente: `docs/findings/2026-08-05-confronti-imperfetti.md`
- La regola conservativa applicata ai disaccordi: `analysis/audit/2026-08-06-layer-b-v3/decisioni-conservative.json`
- Stato del progetto e lezioni pagate: `CLAUDE.md`, `docs/RED_ALERT.md`
