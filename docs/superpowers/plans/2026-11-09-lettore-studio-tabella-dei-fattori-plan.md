# Lettore dello studio e tabella dei fattori — piano di implementazione

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or
> superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
> Prima di tutto carica la skill di progetto `simulomicsr-session` e leggi `CLAUDE.md`.
> **Scelta del PI (2026-11-10):** piano approvato; esecuzione con `superpowers:executing-plans` da un solo agente in
> una sessione nuova (S12r), senza subagenti per i task, e una revisione indipendente di tutto il branch alla fine.
> **Stato del piano:** dopo il commit di ogni Task aggiorna `2026-11-09-lettore-studio-mappa/stato.json` e rigenera
> `stato-del-piano.pdf` (procedura nel `README.md` di quella cartella).

**Goal:** costruire gli strumenti che misurano un lettore dello studio contro la curazione umana di Expression
Atlas, misurare con gli stessi strumenti la pipeline di oggi, e fare la prova piccola da buttare che dice al PI
se la strada regge.

**Architecture:** questo documento ha due parti. La **Parte A** è il programma: le dieci fasi della spec divise
in quattro piani, ognuno scritto quando il precedente ha dato i suoi numeri. La **Parte B** è il **Piano 1,
«fondamenta e prova»**, dettagliato: il costruttore dei confronti (la definizione del §2 della spec, codice di
pacchetto con TDD), il lettore dei file di Atlas, le tre misure, la misura della pipeline di oggi, e la prova da
buttare con Mistral-Small 3.2 sui 47 studi di sviluppo. Lo stesso costruttore lavora sulla tabella scritta dal
modello e sui fattori scritti dai curatori: per questo viene prima della prova.

**Tech Stack:** R (pacchetto `simulomicsr`, `testthat`, `jsonlite`, `xml2`, `rhdf5`, `digest`), Python 3 con
`-I` per gli scarichi, vLLM `v0.20.2` su `poddgx02` attraverso `dgx_p4_build_bundle()` / `dgx_p4_submit()`.

**Spec:** `docs/superpowers/specs/2026-11-09-lettore-studio-tabella-dei-fattori-design.md` (approvata dal PI il
2026-11-09). Decisione: `docs/decisions/0029-lettore-dello-studio-tabella-dei-fattori.md`. Versione leggibile di
questo piano: `2026-11-09-lettore-studio-tabella-dei-fattori-HUMANE.md`.

## Global Constraints

- Solo `poddgx02`: `cfg <- dgx_config(nodelist = "poddgx02")` e `stopifnot(identical(cfg$nodelist, "poddgx02"))`.
  Mai `poddgx01`, mai `nodelist = NULL`. Prima di sottomettere verifica il mount con un `srun` breve.
- Mai `git push`. Mai `--no-verify`, mai `--no-gpg-sign`. Commit atomici, messaggi in italiano, chiusi da
  `Co-Authored-By: Claude <noreply@anthropic.com>` e dalla riga `Claude-Session:` della sessione.
- Prima di ogni commit: `renv/settings.json` pulito, `analysis/_targets/.gitignore` e
  `analysis/_targets/meta/meta` ripristinati.
- Il deliverable v16, la copia su `/mnt/micron/` e i master (A3 e S14) non si modificano.
- Nessun Claude nella pipeline e nelle misure dell'articolo. Le misure (a), (b), (c) sono numeri deterministici.
  La lettura delle cause dei disaccordi è audit interno.
- **Studi di giudizio chiusi.** Degli 82 studi di giudizio (42 A, 40 B) non si leggono fattori, livelli, confronti
  e uscite del modello. Sono ammessi solo i passi che usano identificativi, con script che non stampano nomi di
  fattori o di confronti. Vale per ogni agente e subagente: non aprire i loro file a mano.
- Previsioni e cancelli committati prima di ogni calcolo (Task 1). Dopo il risultato non si cambiano.
- Nessuna regola «se… allora» dopo il modello per correggerne gli errori. Se un tipo di errore resta, si cambia
  la vista, lo schema o il modello, e si rimisura.
- Nessun taglio silenzioso: uno studio fuori contesto, un valore non coperto dalla mappa, un campione fuori da
  Atlas si contano e si scrivono.
- `Rscript` senza `--vanilla`. Suite senza `head` in pipe. `rhdf5::h5read(..., index=)` sulle stringhe di
  `meta/samples` va in segfault: leggi il campo intero. Dentro `dt[...]` non usare una variabile esterna con il
  nome di una colonna.
- File scaricati: dati non fidati. Cartella propria e vuota sotto `analysis/input/`, script altrove, Python con
  `-I`, un file per risposta, manifesto con URL, data UTC, byte e SHA-256 (modello:
  `analysis/audit/2026-11-07-S12-stadio2b-disegno/26-scarica-geo.py`).
- Codice di pacchetto: italiano in commenti, docstring ed errori, ASCII per gli accenti nei `.Rd`,
  `@keywords internal` (nessun `@export` in questo piano), errori con classe `simulomicsr_tf_*`, TDD a piccoli
  passi, `devtools::document()` dopo ogni file nuovo.
- La prova (Task 9 e 10) è materiale da buttare: sta in `analysis/audit/2026-11-09-lettore-studio/`, ogni file
  si apre con `# PROVA DA BUTTARE`, nessun file in `R/`, nessun test. Tenerne un pezzo è una decisione nuova.

## Review Focus

Classi di ingresso che la spec implica e che è facile dimenticare. Ognuna ha il suo test nel task indicato.

1. **`sample_ids` scalare nel master dello Stadio 2.** Un gruppo con un solo campione ha `sample_ids` stringa e
   non lista. Deve dare un vettore di lunghezza 1, non un gruppo vuoto e non un errore (Task 8).
2. **Più SRR per lo stesso GSM, o un GSM in due gruppi di Atlas.** Le corsie tecniche si riducono al GSM. Un GSM
   in due gruppi di Atlas ferma lo studio con un errore di classe, contato (Task 5).
3. **Universi diversi.** Atlas esclude campioni e il nostro bacino ne esclude altri. Le misure lavorano sui
   campioni comuni, contano gli esclusi dei due lati, e un braccio che scende sotto 2 campioni va in una classe a
   parte, non fra i confronti mancati (Task 7).
4. **Studio senza confronti possibili.** Un solo gruppo, o tutti i fattori senza livello di base:
   `tf_confronti()` restituisce due tabelle vuote con le colonne giuste, non un errore (Task 3).
5. **Nomi di livello con caratteri del separatore.** Due livelli come `a|b` e `a` in fattori diversi non devono
   fondere due gruppi: la chiave del gruppo si costruisce per colonna, non incollando stringhe (Task 2).

---

# Parte A — Il programma

| piano | fasi della spec (§5.8) | che cosa dà | quando si scrive |
|---|---|---|---|
| **1 · fondamenta e prova** (Parte B) | 0, e in anticipo il costruttore della fase 2 e gli strumenti di Atlas della fase 3 | misura di oggi sui 47 studi di sviluppo, misura del lettore v0, cause dei disaccordi, decisione del PI | ora |
| **2 · il lettore nel pacchetto** | 1, 2, resto della 3 (gold, conte, i 1.903), 4, 5 | testi GEO dei 24.393 studi, vista, schema e prompt congelati, modello scelto, cancello (giudizio A, poi B). STOP | dopo la decisione del PI sul Piano 1 |
| **3 · corsa intera e deliverable v17** | 6, 7, 8 | master nuovo, nomi delle entità (sessioni S12c, S12b, S12d dell'handout), Stadio 3 e Stadio 4 con le correzioni decise, gate di coerenza | dopo il cancello |
| **4 · validazione del risultato** | 9 | LINCS, Tahoe-100M, TCGA con nullo, meta-analisi contro singolo studio, rilettura cieca interna; poi figure e Methods | dopo il deliverable v17 |

**Perché quattro piani e non uno.** Il formato della vista, lo schema, il modello e il contesto dipendono dalla
prova. Un piano dettagliato delle fasi 1-9 scritto oggi fisserebbe scelte che la prova deve ancora misurare.

**Uno scostamento dalla spec, dichiarato.** La spec mette la prova (fase 0) prima di ogni codice di pacchetto.
Qui il costruttore dei confronti e gli strumenti di Atlas entrano nel pacchetto prima della prova. Motivo: la
prova li usa, non dipendono dal suo esito (la definizione e i file di Atlas sono fissi), e la misura della
pipeline di oggi è un numero che va nell'articolo. Vista, schema, prompt e adattatore restano da buttare.

**Che cosa ogni piano riceve dal precedente.** Piano 2 dal Piano 1: la vista che funziona, i tipi di disaccordo
con le loro cause, la lunghezza vera delle uscite, il tempo per studio, i candidati per i modelli più grandi, la
lettura per intero dei lavori concorrenti. Piano 3 dal Piano 2: vista, schema, prompt e modello congelati e il
numero dell'articolo. Piano 4 dal Piano 3: il deliverable v17 con il gate di coerenza passato.

---

# Parte B — Piano 1: fondamenta e prova

## File

| file | responsabilità |
|---|---|
| `R/tabella-fattori.R` | `tf_tabella()` (oggetto validato campione × fattore), `tf_gruppi()` |
| `R/tabella-fattori-confronti.R` | `tf_confronti()`: la definizione, «non scritto», soggetti, `n_min`, registro |
| `R/atlas-lettura.R` | lettura di `-configuration.xml` e `.condensed-sdrf.tsv`, `atlas_tabella()` |
| `R/tabella-fattori-misure.R` | forma comune dei confronti, misure (a), (b), (c) |
| `R/tabella-fattori-stage2.R` | pipeline di oggi (record del master dello Stadio 2) in forma comune |
| `tests/testthat/helper-tabella-fattori.R`, `test-tabella-fattori*.R`, `test-atlas-lettura.R` | test |
| `tests/testthat/fixtures/atlas/E-GEOD-52778-configuration.xml`, `E-GEOD-52778.condensed-sdrf.tsv` | fixture (studio di sviluppo, dati pubblici EBI, 10 kB) |
| `analysis/audit/2026-11-09-lettore-studio/00-previsioni.md`, `30-…` → `64-…`, `aiuti.R` | divisione, scarichi, misure, prova da buttare |
| `docs/findings/2026-11-09-S12r-prova-lettore-studio.md` | finding con il riassunto «In breve» |

Dati scaricati (fuori dal repository, sotto `analysis/input/`, che è un link a `/mnt/micron/simulomicsr-dati/`):
`atlas-2026-11-09/`, `ena-2026-11-09/`, `geo-testi-lettore-2026-11-09/`. I manifesti stanno nella cartella di audit.

**Costanti condivise** (in `R/tabella-fattori.R`): `TF_NON_SCRITTO <- "non scritto"`;
`TF_TIPI <- c("perturbazione", "stato", "contesto", "tempo", "tecnico")`;
`TF_TIPI_CON_BASE <- c("perturbazione", "stato")`;
`TF_SOGGETTI <- c("donatore", "sesso", "eta", "passaggio", "lotto", "coppia")`.

**Forma comune di un confronto** (usata da Task 5, 7, 8, 10): `data.frame` con `studio` (chr), `id` (chr) e due
colonne-lista `trattato` e `controllo`, ognuna un vettore ordinato di GSM. **Forma comune di una partizione:**
vettore con nome `c(GSM… = "<gruppo>")`.

---

### Task 1: divisione degli studi e previsioni, depositate prima di ogni calcolo

**Files:**
- Create: `analysis/audit/2026-11-09-lettore-studio/30-divisione.R`, `30-divisione.tsv`, `00-previsioni.md`

**Interfaces:**
- Produces: `30-divisione.tsv` con colonne `accession`, `gse`, `nei_993` (0/1), `parte`
  (`sviluppo` | `giudizio_A` | `giudizio_B`). Tutti gli script seguenti leggono `parte` da qui.

- [ ] **Step 1: scrivi `30-divisione.R`.** Legge `20-atlas-studi-nostri.txt` (campi 1-3 separati da spazio; non
  leggere i campi dal 5 in poi). Regola: `nei_993 == 1` → `sviluppo`. Altrimenti, con `n` = numero del GSE:
  `n %% 3 == 0` → `sviluppo`, `== 1` → `giudizio_A`, `== 2` → `giudizio_B`. Chiude con
  `stopifnot(identical(as.integer(table(parte)[c("sviluppo","giudizio_A","giudizio_B")]), c(47L, 42L, 40L)))`.

- [ ] **Step 2: esegui** `Rscript analysis/audit/2026-11-09-lettore-studio/30-divisione.R`.
  Atteso: `sviluppo 47, giudizio_A 42, giudizio_B 40`.

- [ ] **Step 3: scrivi `00-previsioni.md`** con questo contenuto (i valori attesi sono giudizio motivato
  dell'agente: non esiste una misura precedente contro un riferimento esterno; dillo nel file).

  Unità: lo studio. Incertezza: bootstrap sugli studi, B = 2.000, seme 20261109.

  **Che cosa è già stato visto.** `20-atlas-studi-nostri.txt` (committato in 37c882b) contiene i nomi dei tipi di
  fattore di Atlas per tutti i 129 studi, anche quelli di giudizio. `21-atlas-conta.py` ha contato gruppi e
  confronti con espressioni regolari su tutti i 129. Il contenuto (livelli, gruppi, confronti) è stato letto
  solo per `E-GEOD-52778` ed `E-GEOD-65335`, che stanno nello sviluppo.

  **Cancelli.**
  - K1. Il legame SRR → GSM copre tutti gli studi di sviluppo, e dove ENA e il campo `relation` dell'H5 danno
    entrambi un legame, concordano in tutti i casi.
  - K2. Controllo positivo dello strumento: i gruppi e i confronti di Atlas, dati allo strumento come se fossero
    l'uscita del lettore, danno partizione identica in 47 studi su 47 e ritrovano tutti i confronti di Atlas che
    rispettano la definizione.
  - K3. La misura di oggi copre 47 studi su 47 (uno studio senza record nel master S14 si conta come zero
    confronti, non si toglie).
  - K4. Il job gira su `poddgx02`, con `VLLM_BATCH_INVARIANT=1` e `HF_HUB_OFFLINE=1` letti da
    `container-env.txt`, e con `prompt.txt` e `schema.json` del bundle uguali per SHA-256 ai file v0 committati.
  - K5. Nessuno script del piano riceve un contenuto di uno studio di giudizio: i passi sui 129 studi usano
    `solo_id = TRUE` e i loro `*-out.txt` contengono solo identificativi e conteggi.

  **Previsioni** (misure definite nel Task 7; «oggi» è il master S14 dello Stadio 2 con almeno 2 campioni per
  braccio).

  | | quantità, sui 47 studi di sviluppo | atteso | intervallo di rilevanza | perché |
  |---|---|---|---|---|
  | P1 | oggi, confronti di Atlas ritrovati (b) | 35% | 20-50% | il 24,9% dei confronti del deliverable è difettoso, e in `GSE52778` oggi i gruppi hanno un campione |
  | P2 | oggi, studi con partizione identica (a) | 30% | 15-45% | lo Stadio 2 divide per ogni fatto dello Stadio 1 |
  | P3 | lettore meno oggi, confronti ritrovati (b) | +30 punti | l'intervallo al 95% sta sopra 0 | criterio del §5.6 della spec |
  | P4 | lettore, studi con partizione identica (a) | 65% | 50-80% | sotto 50% «ordine» non è sostenibile con questo modello e questa vista |
  | P5 | errori fra i confronti non elencati da Atlas (c): lettore / oggi | 5% / 25% | 0-10% / 15-35% | la definizione toglie i confronti con due differenze |
  | P6 | studi che il lettore non chiude (uscita non valida o troncata, valore non coperto dalla mappa, oltre il contesto) | 4 su 47 | 0-7 | oltre 7 la vista o lo schema v0 vanno cambiati prima di ogni conclusione |
  | P7 | uscite identiche al carattere fra due corse | 47 su 47 | 47 | con `VLLM_BATCH_INVARIANT=1` Mistral ha ripetuto 1.903 uscite su 1.903 |
  | P8 | confronti di Atlas fuori dalla definizione (due fattori che cambiano) | 10% | 5-20% | descrittiva |

  **Regola di esito (spec §5.6).** Si passa al Piano 2 se P3 è confermata, se il lettore fa meglio di oggi anche
  in (a) e in (c), e se ogni disaccordo del lettore ha una causa che la vista, lo schema o un modello più grande
  possono togliere. In ogni altro caso il PI vede numeri e cause e decide.

- [ ] **Step 4: commit** (`git add` dei tre file) con messaggio
  `S12r: divisione sviluppo/giudizio (47/42/40) e previsioni depositate prima del calcolo`.

---

### Task 2: `tf_tabella()` e `tf_gruppi()`

**Files:**
- Create: `R/tabella-fattori.R`, `tests/testthat/helper-tabella-fattori.R`,
  `tests/testthat/test-tabella-fattori.R`

**Interfaces:**
- Produces:
  - `tf_tabella(campioni, livelli, fattori, soggetti = NULL, tipo_soggetto = NULL)` → lista di classe
    `simulomicsr_tf_tabella` con gli stessi campi. `campioni`: chr unico. `livelli`: `data.frame` di chr, una
    riga per campione (`row.names` = campioni), una colonna per fattore. `fattori`: `data.frame` con `nome`,
    `tipo` (in `TF_TIPI`), `base` (chr o `NA`). `soggetti`: `data.frame` di chr come `livelli`, una colonna per
    colonna di soggetto. `tipo_soggetto`: chr con nome, `c(<colonna> = <tipo in TF_SOGGETTI>)`.
  - `tf_gruppi(tabella)` → `data.frame` con `gruppo` (`g1`, `g2`, … nell'ordine delle righe distinte di
    `livelli` ordinate per colonna), una colonna per fattore, `n` (int), `campioni` (colonna-lista, GSM ordinati).
  - `tf_finta()` nel helper (sotto).

- [ ] **Step 1: scrivi il helper e i test che falliscono**

```r
# helper-tabella-fattori.R — studio finto: 2 linee x (veicolo, farmaco) a 24 h, più un tempo zero. 10 campioni.
tf_finta <- function(soggetti = NULL, tipo_soggetto = NULL) {
  campioni <- sprintf("GSM%d", 1:10)
  livelli <- data.frame(
    trattamento = rep(c("veicolo", "farmaco", "veicolo", "farmaco", "veicolo"), each = 2),
    linea       = rep(c("A", "A", "B", "B", "A"), each = 2),
    tempo       = rep(c("24 h", "24 h", "24 h", "24 h", "0 h"), each = 2),
    row.names = campioni, stringsAsFactors = FALSE)
  fattori <- data.frame(nome = c("trattamento", "linea", "tempo"),
                        tipo = c("perturbazione", "contesto", "tempo"),
                        base = c("veicolo", NA, NA), stringsAsFactors = FALSE)
  tf_tabella(campioni, livelli, fattori, soggetti, tipo_soggetto)
}
```

```r
# test-tabella-fattori.R
test_that("tf_gruppi: cinque gruppi da due campioni", {
  g <- tf_gruppi(tf_finta())
  expect_equal(nrow(g), 5L); expect_true(all(g$n == 2L))
  expect_setequal(g$campioni[[which(g$trattamento == "veicolo" & g$tempo == "0 h")]], c("GSM9", "GSM10"))
})
test_that("tf_tabella rifiuta gli ingressi incompleti, con classe", {
  t <- unclass(tf_finta())
  liv <- t$livelli; liv$tempo[3] <- NA
  expect_error(tf_tabella(t$campioni, liv, t$fattori), class = "simulomicsr_tf_campione_senza_livello")
  f <- t$fattori; f$base[1] <- "placebo"
  expect_error(tf_tabella(t$campioni, t$livelli, f), class = "simulomicsr_tf_base_ignota")
  f <- t$fattori; f$base[3] <- "0 h"
  expect_error(tf_tabella(t$campioni, t$livelli, f), class = "simulomicsr_tf_base_non_ammessa")
  f <- t$fattori; f$tipo[2] <- "tessuto"
  expect_error(tf_tabella(t$campioni, t$livelli, f), class = "simulomicsr_tf_tipo_ignoto")
  expect_error(tf_tabella(c(t$campioni[-1], "GSM2"), t$livelli, t$fattori), class = "simulomicsr_tf_campioni_doppi")
  expect_error(tf_tabella(t$campioni, t$livelli, t$fattori,
                          soggetti = data.frame(d = letters[1:10], row.names = t$campioni)),
               class = "simulomicsr_tf_soggetto_senza_tipo")
})
test_that("tf_gruppi: la chiave si costruisce per colonna (Review Focus 5)", {
  campioni <- sprintf("GSM%d", 1:4)
  livelli <- data.frame(x = c("a|b", "a|b", "a", "a"), y = c("c", "c", "b|c", "b|c"),
                        row.names = campioni, stringsAsFactors = FALSE)
  fattori <- data.frame(nome = c("x", "y"), tipo = c("contesto", "contesto"), base = c(NA, NA))
  expect_equal(nrow(tf_gruppi(tf_tabella(campioni, livelli, fattori))), 2L)
})
test_that("tf_gruppi: «non scritto» è un livello come gli altri nella chiave", {
  t <- unclass(tf_finta()); t$livelli$tempo[1] <- TF_NON_SCRITTO      # GSM1 si stacca da GSM2
  expect_equal(nrow(tf_gruppi(tf_tabella(t$campioni, t$livelli, t$fattori))), 6L)
})
```

- [ ] **Step 2: esegui e verifica il fallimento**

Run: `Rscript -e 'devtools::load_all("."); testthat::test_local(filter="tabella-fattori", reporter="summary")'`
Expected: FAIL, `could not find function "tf_tabella"`.

- [ ] **Step 3: implementa `tf_tabella()` e `tf_gruppi()` in `R/tabella-fattori.R`.** `base` è ammessa solo per
  i tipi in `TF_TIPI_CON_BASE`. `TF_NON_SCRITTO` è sempre un livello ammesso e non può essere `base`. I gruppi si
  ottengono dalle righe distinte del `data.frame` (`order()` e `duplicated()` sulle colonne), non da una stringa
  incollata.

- [ ] **Step 4: esegui e verifica che passa.** Stesso comando. Expected: PASS, 0 fallimenti.

- [ ] **Step 5: `devtools::document()` e commit** — `tabella dei fattori: oggetto validato e gruppi (TDD)`.

---

### Task 3: `tf_confronti()` — la definizione, «non scritto», `n_min`, il registro

**Files:**
- Create: `R/tabella-fattori-confronti.R`, `tests/testthat/test-tabella-fattori-confronti.R`

**Interfaces:**
- Consumes: `tf_tabella()`, `tf_gruppi()`, `TF_NON_SCRITTO`, `tf_finta()`.
- Produces: `tf_confronti(tabella, n_min = 2L)` → `list(confronti, registro)`.
  - `confronti`: `id` (`<gruppo_trattato>_<gruppo_controllo>`), `fattore`, `tipo_fattore`, `livello_trattato`,
    `livello_base`, `gruppo_trattato`, `gruppo_controllo`, `trattato` e `controllo` (colonne-lista di GSM
    ordinati), `contesto` (colonna-lista: vettore con nome dei livelli del gruppo trattato negli altri fattori),
    `avvisi` (colonna-lista di chr), `esito` (`"confronto"` | `"confronto con avviso"`).
  - `registro`: una riga per ogni coppia di gruppi che non diventa confronto: `gruppo_a`, `gruppo_b`, `motivo`,
    `dettaglio`. Valori di `motivo`: `piu_di_un_fattore`, `nessuna_differenza`, `fattore_senza_base`,
    `nessuno_al_base`, `n_min`, `soggetti_disgiunti` (Task 4). `dettaglio`: i nomi dei fattori o delle colonne,
    in ordine alfabetico, separati da `", "`.
  - Invariante: `nrow(confronti) + nrow(registro) == choose(n_gruppi, 2)`.

**La regola per una coppia di gruppi (A, B), in quest'ordine:**
1. `D` = i fattori in cui i livelli di A e B sono diversi e nessuno dei due è `TF_NON_SCRITTO`.
   `N` = i fattori in cui i livelli sono diversi e uno dei due è `TF_NON_SCRITTO`.
2. `length(D) == 0` → `nessuna_differenza`. `length(D) > 1` → `piu_di_un_fattore`.
3. Il fattore in `D` non ha `base` → `fattore_senza_base`. Nessuno dei due gruppi è al livello `base` →
   `nessuno_al_base`.
4. Il gruppo al livello `base` è il controllo. Un braccio con meno di `n_min` campioni → `n_min`.
5. Altrimenti è un confronto. Per ogni fattore in `N` aggiungi l'avviso `non_scritto:<fattore>`. Con almeno un
   avviso l'esito è `"confronto con avviso"`.

- [ ] **Step 1: scrivi i test che falliscono**

```r
test_that("la definizione: due confronti, uno per linea, e il conto delle coppie torna", {
  r <- tf_confronti(tf_finta())
  expect_equal(nrow(r$confronti), 2L); expect_equal(nrow(r$registro), 8L)
  a <- r$confronti[vapply(r$confronti$contesto, function(k) k[["linea"]] == "A", TRUE), ]
  expect_equal(a$trattato[[1]], c("GSM3", "GSM4")); expect_equal(a$controllo[[1]], c("GSM1", "GSM2"))
  expect_equal(a$livello_base, "veicolo"); expect_equal(a$esito, "confronto")
})
test_that("il tempo zero non è un controllo", {
  r <- tf_confronti(tf_finta())
  expect_false(any(unlist(r$confronti$controllo) %in% c("GSM9", "GSM10")))
  g <- tf_gruppi(tf_finta())
  zero <- g$gruppo[g$tempo == "0 h"]; farm <- g$gruppo[g$trattamento == "farmaco" & g$linea == "A"]
  riga <- r$registro[(r$registro$gruppo_a %in% c(zero, farm)) & (r$registro$gruppo_b %in% c(zero, farm)), ]
  expect_equal(riga$motivo, "piu_di_un_fattore"); expect_equal(riga$dettaglio, "tempo, trattamento")
})
test_that("la seconda perturbazione: farmaco + siRNA contro veicolo senza siRNA non è un confronto", {
  campioni <- sprintf("GSM%d", 1:6)
  livelli <- data.frame(farmaco = rep(c("veicolo", "X", "veicolo"), each = 2),
                        sirna = rep(c("siCtrl", "siY", "siY"), each = 2), row.names = campioni)
  fattori <- data.frame(nome = c("farmaco", "sirna"), tipo = "perturbazione", base = c("veicolo", "siCtrl"))
  r <- tf_confronti(tf_tabella(campioni, livelli, fattori))
  expect_equal(nrow(r$confronti), 2L)
  expect_setequal(r$confronti$fattore, c("farmaco", "sirna"))
  dentro <- r$confronti[r$confronti$fattore == "farmaco", ]
  expect_equal(dentro$trattato[[1]], c("GSM3", "GSM4")); expect_equal(dentro$controllo[[1]], c("GSM5", "GSM6"))
  expect_equal(dentro$contesto[[1]][["sirna"]], "siY")
  expect_equal(r$registro$motivo, "piu_di_un_fattore")
})
test_that("«non scritto» non è una differenza e si marca", {
  t <- unclass(tf_finta()); t$livelli$tempo[1:2] <- TF_NON_SCRITTO
  r <- tf_confronti(tf_tabella(t$campioni, t$livelli, t$fattori))
  a <- r$confronti[vapply(r$confronti$trattato, function(x) "GSM3" %in% x, TRUE), ]
  expect_equal(a$esito, "confronto con avviso"); expect_equal(a$avvisi[[1]], "non_scritto:tempo")
})
test_that("fattore senza livello di base, nessuno al livello di base, n_min", {
  campioni <- sprintf("GSM%d", 1:5)
  livelli <- data.frame(f = c("A", "A", "B", "B", "veicolo"), piattaforma = "p1", row.names = campioni)
  fattori <- data.frame(nome = c("f", "piattaforma"), tipo = c("perturbazione", "tecnico"), base = c("veicolo", NA))
  r <- tf_confronti(tf_tabella(campioni, livelli, fattori))
  expect_equal(nrow(r$confronti), 0L)
  expect_setequal(r$registro$motivo, c("nessuno_al_base", "n_min", "n_min"))
  livelli$piattaforma <- c("p1", "p1", "p2", "p2", "p1"); livelli$f <- "veicolo"
  r2 <- tf_confronti(tf_tabella(campioni, livelli, fattori))
  expect_true(all(r2$registro$motivo == "fattore_senza_base"))
})
test_that("uno studio con un solo gruppo dà tabelle vuote con le colonne giuste (Review Focus 4)", {
  campioni <- c("GSM1", "GSM2"); livelli <- data.frame(f = c("a", "a"), row.names = campioni)
  r <- tf_confronti(tf_tabella(campioni, livelli, data.frame(nome = "f", tipo = "contesto", base = NA)))
  expect_equal(nrow(r$confronti), 0L); expect_equal(nrow(r$registro), 0L)
  expect_true(all(c("id", "fattore", "trattato", "controllo", "avvisi", "esito") %in% names(r$confronti)))
  expect_true(all(c("gruppo_a", "gruppo_b", "motivo", "dettaglio") %in% names(r$registro)))
})
```

- [ ] **Step 2: esegui e verifica il fallimento.** Expected: FAIL, `could not find function "tf_confronti"`.
- [ ] **Step 3: implementa `tf_confronti(tabella, n_min = 2L)`** con la regola scritta sopra. Chiudi la funzione
  con `stopifnot(nrow(confronti) + nrow(registro) == choose(nrow(gruppi), 2))`.
- [ ] **Step 4: esegui e verifica che passa.** Expected: PASS.
- [ ] **Step 5: `devtools::document()` e commit** — `tabella dei fattori: i confronti dalla definizione, con il registro delle coppie non formate (TDD)`.

---

### Task 4: i soggetti come insiemi

**Files:**
- Modify: `R/tabella-fattori-confronti.R`, `tests/testthat/test-tabella-fattori-confronti.R`

**Interfaces:**
- Consumes: `tabella$soggetti`, `tabella$tipo_soggetto`, il confronto formato dal Task 3.
- Produces: dentro `tf_confronti()`, dopo il passo 4 della regola: motivo `soggetti_disgiunti` nel registro,
  avvisi `soggetti_in_parte:<colonna>` e `soggetti_diversi:<colonna>` nel confronto. Funzione interna
  `.tf_soggetti(valori_trattato, valori_controllo, tipo_soggetto, tipo_fattore)` →
  `"uguali"` | `"avviso_in_parte"` | `"avviso_diversi"` | `"nessun_confronto"`.

**La tabella della regola** (decisione 2 del PI del 2026-11-08; le righe marcate sono dell'agente). Insiemi dei
valori distinti dei due bracci, senza i valori vuoti:

| tipo del fattore che cambia | tipo di soggetto | insiemi uguali | in parte comuni | senza valori comuni |
|---|---|---|---|---|
| perturbazione | donatore, passaggio, lotto, coppia | niente | `soggetti_in_parte` | nessun confronto |
| perturbazione | sesso, età **[agente: come i donatori]** | niente | `soggetti_in_parte` | nessun confronto |
| stato | donatore, passaggio, lotto, coppia | niente | `soggetti_diversi` | `soggetti_diversi` |
| stato | sesso, età | niente | `soggetti_in_parte` | nessun confronto |

**L'età numerica [agente].** Se ogni valore della colonna contiene un solo numero, l'età è numerica: si
confrontano gli intervalli `[min, max]` dei due bracci. Intervalli senza sovrapposizione → «senza valori
comuni». Intervalli che si sovrappongono → «insiemi uguali». Motivo: con un'età diversa per ogni donatore gli
insiemi non hanno mai valori comuni, e la regola degli insiemi toglierebbe ogni confronto fra malati e sani.

- [ ] **Step 1: scrivi i test che falliscono**

```r
sogg <- function(d) data.frame(donatore = d, row.names = sprintf("GSM%d", 1:10), stringsAsFactors = FALSE)
test_that("perturbazione: donatori senza valori comuni, in parte comuni, uguali", {
  # linea A: GSM1-2 veicolo, GSM3-4 farmaco. linea B: GSM5-6 veicolo, GSM7-8 farmaco.
  d <- c("d1", "d2", "d3", "d4",   "d5", "d6", "d5", "d7",   "d1", "d2")
  r <- tf_confronti(tf_finta(sogg(d), c(donatore = "donatore")))
  expect_equal(nrow(r$confronti), 1L)
  expect_equal(r$confronti$avvisi[[1]], "soggetti_in_parte:donatore")
  expect_equal(r$confronti$esito, "confronto con avviso")
  expect_equal(sum(r$registro$motivo == "soggetti_disgiunti"), 1L)
  expect_equal(r$registro$dettaglio[r$registro$motivo == "soggetti_disgiunti"], "donatore")
  d[3:4] <- c("d1", "d2"); d[7:8] <- c("d5", "d6")
  r2 <- tf_confronti(tf_finta(sogg(d), c(donatore = "donatore")))
  expect_equal(r2$confronti$esito, c("confronto", "confronto"))
})
test_that("stato: donatori diversi avviso, sesso senza valori comuni nessun confronto, età per intervalli", {
  campioni <- sprintf("GSM%d", 1:4)
  livelli <- data.frame(malattia = c("sano", "sano", "malato", "malato"), row.names = campioni)
  fattori <- data.frame(nome = "malattia", tipo = "stato", base = "sano")
  tab <- function(s, tipi) tf_confronti(tf_tabella(campioni, livelli, fattori,
                                                   data.frame(s, row.names = campioni), tipi))
  r <- tab(list(don = c("a", "b", "c", "d")), c(don = "donatore"))
  expect_equal(r$confronti$avvisi[[1]], "soggetti_diversi:don")
  r <- tab(list(sex = c("F", "F", "M", "M")), c(sex = "sesso"))
  expect_equal(r$registro$motivo, "soggetti_disgiunti")
  r <- tab(list(sex = c("F", "M", "M", "M")), c(sex = "sesso"))
  expect_equal(r$confronti$avvisi[[1]], "soggetti_in_parte:sex")
  r <- tab(list(eta = c("34 years", "51 years", "40 years", "62 years")), c(eta = "eta"))
  expect_equal(r$confronti$esito, "confronto")
  r <- tab(list(eta = c("4 years", "6 years", "40 years", "62 years")), c(eta = "eta"))
  expect_equal(r$registro$motivo, "soggetti_disgiunti")
  r <- tab(list(eta = c("adult", "adult", "fetal", "fetal")), c(eta = "eta"))
  expect_equal(r$registro$motivo, "soggetti_disgiunti")
})
```

- [ ] **Step 2: esegui e verifica il fallimento.** Expected: FAIL (un confronto in più, avvisi assenti).
- [ ] **Step 3: implementa `.tf_soggetti()` e chiamala in `tf_confronti()`** per ogni colonna di `soggetti`.
  Un solo esito `"nessun_confronto"` basta per mandare la coppia nel registro, con tutte le colonne che lo danno
  in `dettaglio`.
- [ ] **Step 4: esegui e verifica che passa**, compresi i test dei Task 2 e 3. Expected: PASS.
- [ ] **Step 5: `devtools::document()` e commit** — `tabella dei fattori: i soggetti si confrontano come insiemi (decisione del PI del 2026-11-08, TDD)`.

---

### Task 5: il lettore dei file di Expression Atlas

**Files:**
- Create: `R/atlas-lettura.R`, `tests/testthat/test-atlas-lettura.R`,
  `tests/testthat/fixtures/atlas/E-GEOD-52778-configuration.xml`,
  `tests/testthat/fixtures/atlas/E-GEOD-52778.condensed-sdrf.tsv`
- Modify: `DESCRIPTION` (`xml2` in `Suggests`, se non c'è)

**Interfaces:**
- Produces:
  - `atlas_leggi_configurazione(path, solo_id = FALSE)` → `list(gruppi, confronti)`. `gruppi`: `gruppo` (`g1`…),
    `etichetta`, `run` (una riga per coppia gruppo-run). `confronti`: `id`, `nome`, `riferimento`, `test`. Con
    `solo_id = TRUE` le colonne `etichetta` e `nome` sono `NA`: è la sola forma ammessa per uno studio di
    giudizio.
  - `atlas_leggi_sdrf(path)` → `data.frame` con `run`, `ruolo` (`characteristic` | `factor`), `nome`, `valore`.
    Il file è separato da tabulazioni, senza intestazione: colonne 3, 4, 5, 6.
  - `atlas_tabella(config, sdrf, legame)` → `list(tabella, confronti, esclusi)`. `legame`: `data.frame` con
    `run`, `gsm`. `tabella`: una `simulomicsr_tf_tabella` sui GSM dei gruppi di Atlas, un fattore per ogni
    `factor` dell'SDRF, tipo `"contesto"` e `base = NA` (Atlas non dichiara un livello di base: lo dà il
    confronto). `confronti`: forma comune, più `id` di Atlas e `nome`. `esclusi`: i run senza GSM, contati.
  - Errori: `simulomicsr_tf_atlas_gsm_in_due_gruppi`, `simulomicsr_tf_atlas_run_senza_fattori`.

- [ ] **Step 1: copia la fixture** dai file di `E-GEOD-52778` (studio di sviluppo) scaricati dall'FTP di EBI.
- [ ] **Step 2: scrivi i test che falliscono.** Le due funzioni di aiuto vanno in
  `helper-tabella-fattori.R`, perché le usa anche il Task 7.

```r
# in helper-tabella-fattori.R
fx <- function(f) testthat::test_path("fixtures", "atlas", f)
legame_finto <- function(run) data.frame(run = run, gsm = sprintf("GSM%d", 1275862L + as.integer(sub("SRR", "", run)) - 1039508L))
# in test-atlas-lettura.R
test_that("configurazione: 4 gruppi da 4 run, 3 confronti con riferimento g4", {
  k <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml"))
  expect_equal(as.integer(table(k$gruppi$gruppo)), c(4L, 4L, 4L, 4L))
  expect_setequal(k$gruppi$run[k$gruppi$gruppo == "g4"], c("SRR1039508", "SRR1039520", "SRR1039512", "SRR1039516"))
  expect_equal(k$confronti$id, c("g4_g1", "g4_g3", "g4_g2"))
  expect_true(all(k$confronti$riferimento == "g4")); expect_equal(k$confronti$test, c("g1", "g3", "g2"))
  s <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml"), solo_id = TRUE)
  expect_true(all(is.na(s$gruppi$etichetta))); expect_true(all(is.na(s$confronti$nome)))
})
test_that("sdrf: un fattore (treatment), 16 run, 4 livelli", {
  s <- atlas_leggi_sdrf(fx("E-GEOD-52778.condensed-sdrf.tsv"))
  f <- s[s$ruolo == "factor", ]
  expect_equal(unique(f$nome), "treatment"); expect_equal(nrow(f), 16L)
  expect_setequal(f$valore, c("untreated", "dexamethasone", "albuterol", "albuterol and dexamethasone"))
})
test_that("atlas_tabella: GSM al posto dei run, confronti in forma comune", {
  k <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml")); s <- atlas_leggi_sdrf(fx("E-GEOD-52778.condensed-sdrf.tsv"))
  a <- atlas_tabella(k, s, legame_finto(unique(k$gruppi$run)))
  expect_equal(nrow(tf_gruppi(a$tabella)), 4L)
  c1 <- a$confronti[a$confronti$id == "g4_g1", ]
  expect_true("GSM1275862" %in% c1$controllo[[1]]); expect_equal(length(c1$trattato[[1]]), 4L)
})
test_that("più run per GSM si riducono al GSM; un GSM in due gruppi ferma lo studio (Review Focus 2)", {
  k <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml")); s <- atlas_leggi_sdrf(fx("E-GEOD-52778.condensed-sdrf.tsv"))
  l <- legame_finto(unique(k$gruppi$run))
  l$gsm[l$run == "SRR1039520"] <- "GSM1275862"                      # due run di g4 sullo stesso GSM
  expect_equal(length(atlas_tabella(k, s, l)$tabella$campioni), 15L)
  l$gsm[l$run == "SRR1039509"] <- "GSM1275862"                      # un run di g3 sullo stesso GSM
  expect_error(atlas_tabella(k, s, l), class = "simulomicsr_tf_atlas_gsm_in_due_gruppi")
  l2 <- legame_finto(unique(k$gruppi$run)); l2 <- l2[l2$run != "SRR1039508", ]
  expect_equal(atlas_tabella(k, s, l2)$esclusi$run, "SRR1039508")
})
```

- [ ] **Step 3: esegui e verifica il fallimento.**
  Run: `Rscript -e 'devtools::load_all("."); testthat::test_local(filter="atlas-lettura", reporter="summary")'`
- [ ] **Step 4: implementa le tre funzioni** con `xml2` (`rlang::check_installed("xml2")`). Con `solo_id = TRUE`
  non leggere gli attributi `label` e gli elementi `<name>`.
- [ ] **Step 5: esegui e verifica che passa.** Expected: PASS.
- [ ] **Step 6: `devtools::document()` e commit** — `Expression Atlas: lettura della configurazione e dell'SDRF, tabella dei fattori dei curatori (TDD)`.

---

### Task 6: scarico dei file di Atlas e legame SRR → GSM

**Files:**
- Create: `analysis/audit/2026-11-09-lettore-studio/31-scarica-atlas.py`, `31-manifesto-atlas.tsv`,
  `32-scarica-ena.py`, `32-manifesto-ena.tsv`, `33-legame.R`, `33-legame.tsv`, `33-out.txt`

**Interfaces:**
- Consumes: `30-divisione.tsv`, `atlas_leggi_configurazione(path, solo_id = TRUE)`.
- Produces: `33-legame.tsv` con `accession`, `gse`, `run`, `gsm`, `fonte` (`ena` | `relation` | `entrambe`),
  `nel_bacino` (0/1: il GSM sta nell'ingresso dello Stadio 1 `analysis/input/archs4-human-stage1-input-v2.jsonl`).

- [ ] **Step 1: `31-scarica-atlas.py`.** Per ogni riga di `30-divisione.tsv` scarica
  `https://ftp.ebi.ac.uk/pub/databases/microarray/data/atlas/experiments/<accession>/<accession>-configuration.xml`
  in `analysis/input/atlas-2026-11-09/`. Scarica `<accession>.condensed-sdrf.tsv` **solo** per
  `parte == sviluppo`. Riprende, `PAUSA = 0.4`, `TENTATIVI = 5`, manifesto come `26-scarica-geo.py`. Stampa solo
  conteggi. Esegui con `python3 -I`. Atteso: 129 configurazioni, 47 SDRF.
- [ ] **Step 2: `32-scarica-ena.py`.** Per ogni studio legge i run dalla configurazione (solo gli elementi
  `<assay>`). Con il primo run chiede a ENA lo studio
  (`https://www.ebi.ac.uk/ena/portal/api/filereport?accession=<SRR>&result=read_run&fields=run_accession,study_accession&format=tsv`),
  poi tutti i run dello studio (`accession=<study_accession>`,
  `fields=run_accession,experiment_accession,sample_alias,experiment_alias`). Una risposta per file in
  `analysis/input/ena-2026-11-09/`, con manifesto. Nessun contenuto di Atlas in uscita.
- [ ] **Step 3: `33-legame.R`.** Il GSM di un run è il primo fra `sample_alias` ed `experiment_alias` che
  rispetta `^GSM[0-9]+$` (fonte `ena`). Seconda fonte: il campo `relation` dell'H5 contiene l'SRX del campione
  (leggi il campo intero, senza `index=`), da unire con `experiment_accession` (fonte `relation`). Scrive
  `33-legame.tsv` e in `33-out.txt`, per parte: run totali, run con GSM, run senza GSM, GSM nel bacino, studi con
  almeno un run non legato, disaccordi fra le due fonti.
- [ ] **Step 4: cancello K1.** `33-legame.R` chiude con `stopifnot(n_disaccordi == 0L)` e con
  `stopifnot(all(studi_sviluppo %in% legame$gse))`. Controllo positivo: `SRR1039508` → `GSM1275862`
  (`stopifnot`). Se il cancello fallisce, fermati: non correggere il legame a mano, cerca la causa.
- [ ] **Step 5: commit** degli script, dei manifesti, di `33-legame.tsv` e di `33-out.txt` —
  `S12r: file di Atlas congelati e legame SRR-GSM per i 129 studi (solo identificativi per gli studi di giudizio)`.

---

### Task 7: le tre misure

**Files:**
- Create: `R/tabella-fattori-misure.R`, `tests/testthat/test-tabella-fattori-misure.R`

**Interfaces:**
- Consumes: forma comune dei confronti e delle partizioni; `atlas_tabella()`; `tf_gruppi()`.
- Produces (tutte lavorano su **uno** studio; `universo` = GSM presenti sia nei gruppi di Atlas sia nella nostra
  vista dello studio):
  - `tf_misura_gruppi(nostra, atlas)` — due partizioni in forma comune → `list(classe, ari, n_comuni,
    solo_nostri, solo_atlas)`. `classe`: `"identica"` | `"piu_fine"` (ogni nostro gruppo sta in un gruppo di
    Atlas) | `"piu_grossa"` | `"incrociata"`. `ari`: indice di Rand corretto, scritto nel file senza nuove
    dipendenze.
  - `tf_classi_confronti_atlas(atlas, universo, n_min = 2L)` — l'uscita di `atlas_tabella()` → i confronti di
    Atlas con la colonna `classe`: `"rispetta"` (i due gruppi differiscono in un solo fattore di Atlas) |
    `"piu_fattori"` | `"non_formabile"` (dopo il taglio all'universo un braccio ha meno di `n_min` campioni).
  - `tf_misura_ritrovati(nostri, atlas_classi, universo)` → i confronti di Atlas con la colonna `ritrovato`:
    `"uguale"` (stessi due insiemi, stesso verso, dopo il taglio dei nostri bracci all'universo) |
    `"verso_opposto"` | `"no"`.
  - `tf_giudica_non_elencati(nostri, atlas, universo)` → i nostri confronti che non corrispondono a un confronto
    di Atlas, con la colonna `giudizio`: `"coerente"` (ogni braccio ha un solo livello in ogni fattore di Atlas,
    e i due bracci differiscono in un solo fattore di Atlas) | `"piu_fattori"` | `"braccio_misto"` |
    `"nessuna_differenza"` | `"fuori_atlas"` (un braccio non ha campioni nell'universo). Errore =
    `piu_fattori` o `braccio_misto`.
  - `tf_riassumi_misure(per_studio, B = 2000L, seme = 20261109L)` → una riga per misura con numeratore,
    denominatore, quota e intervallo al 95% dal bootstrap sugli studi. **Numeri principali:** (a) studi con
    classe `identica` su studi misurati. (b) confronti `uguale` su confronti di classe `rispetta`. (c) errori su
    confronti giudicabili (tutti meno `fuori_atlas`). A parte: `verso_opposto`, `piu_fattori` di Atlas con
    quanti ne forma ogni pipeline, `non_formabile`, mediana di `ari`.

- [ ] **Step 1: scrivi i test che falliscono**

```r
p <- function(...) { x <- c(...); stats::setNames(unname(x), names(x)) }
test_that("tf_misura_gruppi: le quattro classi e il conto dei campioni non comuni (Review Focus 3)", {
  atlas <- p(GSM1 = "a", GSM2 = "a", GSM3 = "b", GSM4 = "b")
  expect_equal(tf_misura_gruppi(p(GSM1 = "x", GSM2 = "x", GSM3 = "y", GSM4 = "y"), atlas)$classe, "identica")
  expect_equal(tf_misura_gruppi(p(GSM1 = "x", GSM2 = "z", GSM3 = "y", GSM4 = "y"), atlas)$classe, "piu_fine")
  expect_equal(tf_misura_gruppi(p(GSM1 = "x", GSM2 = "x", GSM3 = "x", GSM4 = "x"), atlas)$classe, "piu_grossa")
  expect_equal(tf_misura_gruppi(p(GSM1 = "x", GSM2 = "y", GSM3 = "x", GSM4 = "y"), atlas)$classe, "incrociata")
  m <- tf_misura_gruppi(p(GSM1 = "x", GSM2 = "x", GSM3 = "y", GSM9 = "y"), atlas)
  expect_equal(m$n_comuni, 3L); expect_equal(m$solo_nostri, 1L); expect_equal(m$solo_atlas, 1L)
  expect_equal(tf_misura_gruppi(atlas, atlas)$ari, 1)
  expect_equal(tf_misura_gruppi(p(GSM1 = "x", GSM2 = "y", GSM3 = "x", GSM4 = "y"), atlas)$ari, -0.5)
})
test_that("sul vero E-GEOD-52778: Atlas contro Atlas è perfetto, i confronti di Atlas rispettano la definizione", {
  k <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml")); s <- atlas_leggi_sdrf(fx("E-GEOD-52778.condensed-sdrf.tsv"))
  a <- atlas_tabella(k, s, legame_finto(unique(k$gruppi$run))); u <- a$tabella$campioni
  cl <- tf_classi_confronti_atlas(a, u); expect_equal(cl$classe, rep("rispetta", 3))
  r <- tf_misura_ritrovati(a$confronti, cl, u); expect_equal(r$ritrovato, rep("uguale", 3))
  inv <- a$confronti; inv[c("trattato", "controllo")] <- inv[c("controllo", "trattato")]
  expect_equal(tf_misura_ritrovati(inv, cl, u)$ritrovato, rep("verso_opposto", 3))
  senza <- setdiff(u, a$confronti$trattato[[1]][1:3])
  expect_equal(tf_classi_confronti_atlas(a, senza)$classe[1], "non_formabile")
})
test_that("tf_giudica_non_elencati: le cinque classi", {
  k <- atlas_leggi_configurazione(fx("E-GEOD-52778-configuration.xml")); s <- atlas_leggi_sdrf(fx("E-GEOD-52778.condensed-sdrf.tsv"))
  a <- atlas_tabella(k, s, legame_finto(unique(k$gruppi$run))); u <- a$tabella$campioni
  gr <- function(g) sort(legame_finto(k$gruppi$run[k$gruppi$gruppo == g])$gsm)
  nostro <- function(t, c) { d <- data.frame(studio = "GSE52778", id = "x"); d$trattato <- list(t); d$controllo <- list(c); d }
  expect_equal(tf_giudica_non_elencati(nostro(gr("g2"), gr("g3")), a, u)$giudizio, "coerente")
  expect_equal(tf_giudica_non_elencati(nostro(c(gr("g1"), gr("g2")), gr("g4")), a, u)$giudizio, "braccio_misto")
  expect_equal(tf_giudica_non_elencati(nostro(gr("g1")[1:2], gr("g1")[3:4]), a, u)$giudizio, "nessuna_differenza")
  expect_equal(tf_giudica_non_elencati(nostro(c("GSM1", "GSM2"), gr("g4")), a, u)$giudizio, "fuori_atlas")
  expect_equal(nrow(tf_giudica_non_elencati(a$confronti, a, u)), 0L)
})
```

  Per `"piu_fattori"` aggiungi un test con una tabella di Atlas finta a due fattori (2 × 2 gruppi da due
  campioni): il confronto fra i due gruppi in diagonale dà `piu_fattori` sia in `tf_classi_confronti_atlas()`
  sia in `tf_giudica_non_elencati()`.

- [ ] **Step 2: esegui e verifica il fallimento.** `filter="tabella-fattori-misure"`.
- [ ] **Step 3: implementa le cinque funzioni.**
- [ ] **Step 4: esegui e verifica che passa**, poi tutta la suite del piano:
  `Rscript -e 'devtools::load_all("."); testthat::test_local(filter="tabella-fattori|atlas-lettura", reporter="summary")'`.
- [ ] **Step 5: `devtools::document()` e commit** — `misure contro Expression Atlas: gruppi, confronti ritrovati, confronti non elencati (TDD)`.

---

### Task 8: la pipeline di oggi in forma comune, e la misura di oggi sui 47 studi

**Files:**
- Create: `R/tabella-fattori-stage2.R`, `tests/testthat/test-tabella-fattori-stage2.R`,
  `analysis/audit/2026-11-09-lettore-studio/40-misura-oggi.R`, `40-out.txt`, `40-misure-oggi.csv`,
  `40-per-studio-oggi.csv`

**Interfaces:**
- Consumes: un record di `analysis/p4-output/S14-stage2-master.jsonl` letto con
  `jsonlite::fromJSON(riga, simplifyVector = FALSE)`: `series_id`, `replicate_groups[]` (`group_id`,
  `sample_ids`), `comparisons[]` (`comparison_id`, `treated_group`, `control_group`). Le misure del Task 7.
- Produces: `tf_da_stage2(record)` → `list(partizione, confronti)` in forma comune. Un campione in due gruppi →
  errore `simulomicsr_tf_stage2_campione_in_due_gruppi`.

- [ ] **Step 1: scrivi i test che falliscono**

```r
rec <- function() list(series_id = "GSE1",
  replicate_groups = list(list(group_id = "grp_0001", sample_ids = list("GSM1", "GSM2")),
                          list(group_id = "grp_0002", sample_ids = "GSM3")),      # scalare: Review Focus 1
  comparisons = list(list(comparison_id = "c1", treated_group = "grp_0002", control_group = "grp_0001")))
test_that("tf_da_stage2: sample_ids scalare o lista, confronti in forma comune", {
  r <- tf_da_stage2(rec())
  expect_equal(r$partizione, c(GSM1 = "grp_0001", GSM2 = "grp_0001", GSM3 = "grp_0002"))
  expect_equal(r$confronti$trattato[[1]], "GSM3"); expect_equal(r$confronti$controllo[[1]], c("GSM1", "GSM2"))
  expect_equal(r$confronti$studio, "GSE1")
})
test_that("tf_da_stage2: nessun confronto dà una tabella vuota; un campione in due gruppi è un errore", {
  x <- rec(); x$comparisons <- list()
  expect_equal(nrow(tf_da_stage2(x)$confronti), 0L)
  x <- rec(); x$replicate_groups[[2]]$sample_ids <- "GSM1"
  expect_error(tf_da_stage2(x), class = "simulomicsr_tf_stage2_campione_in_due_gruppi")
})
```

- [ ] **Step 2: esegui e verifica il fallimento**, **Step 3: implementa `tf_da_stage2(record)`**,
  **Step 4: esegui e verifica che passa** (`filter="tabella-fattori-stage2"`), **Step 5: `devtools::document()`
  e commit** — `pipeline di oggi in forma comune per le misure (TDD)`.

- [ ] **Step 6: scrivi `40-misura-oggi.R`.** Solo `parte == sviluppo`. Per ogni studio: `atlas_tabella()` con
  `33-legame.tsv`; universo = GSM dei gruppi di Atlas ∩ GSM dello studio nel bacino; `tf_da_stage2()` sul record
  del master S14 (uno studio senza record = partizione vuota e zero confronti, contato). Calcola due varianti dei
  confronti di oggi: **principale** con almeno 2 campioni per braccio, **secondaria** con tutti. Prima di tutto
  il **cancello K2**: le misure con Atlas al posto dei nostri gruppi e confronti devono dare `identica` in 47
  studi su 47 e `uguale` in tutti i confronti `rispetta` (`stopifnot`). Scrive `40-per-studio-oggi.csv` (una
  riga per studio), `40-misure-oggi.csv` (`tf_riassumi_misure()`), e in `40-out.txt` i conteggi delle classi.
- [ ] **Step 7: esegui** `Rscript analysis/audit/2026-11-09-lettore-studio/40-misura-oggi.R > analysis/audit/2026-11-09-lettore-studio/40-out.txt 2>&1`.
  Atteso: `K2 passato`, `studi 47`, `FINITO`. Giudica P1, P2, P8 con le loro previsioni e scrivi l'esito in
  `40-out.txt`. Non cambiare le misure dopo aver visto i numeri.
- [ ] **Step 8: commit** — `S12r: la misura della pipeline di oggi contro Expression Atlas sui 47 studi di sviluppo`.

---

### Task 9: la prova da buttare — ingresso

**Files:**
- Create (tutti in `analysis/audit/2026-11-09-lettore-studio/`, tutti con `# PROVA DA BUTTARE` in testa):
  `aiuti.R`, `50-scarica-geo-sviluppo.py`, `50-manifesto-geo.tsv`, `60-vista-v0.R`, `60-viste-v0.jsonl`,
  `60-out.txt`, `61-schema-v0.json`, `62-prompt-v0.md`

**Interfaces:**
- Consumes: `30-divisione.tsv`, `.s2b_norm_testo()`, l'H5 `analysis/input/human_gene_v2.5.h5`,
  `analysis/audit/2026-11-07-S12-stadio2b-disegno/20-ingressi.R` (come si leggono i campi dell'H5) e
  `27-estrai-campi-geo.py` (come si leggono i campi dai testi GEO).
- Produces: `60-viste-v0.jsonl`, una riga per studio di sviluppo: `record_id` (il GSE), `testo` (la vista),
  `colonne` (i nomi delle colonne non costanti), `tabella` (per ogni colonna i valori per GSM, dopo la
  riparazione della codifica: serve all'adattatore del Task 10).

- [ ] **Step 1: `aiuti.R`.** `DIR`, `SEME <- 20261109L`, `cfg <- dgx_config(nodelist = "poddgx02")` con lo
  `stopifnot`, `ENV_JOB <- c(VLLM_BATCH_INVARIANT = "1", HF_HUB_OFFLINE = "1")`, e la funzione
  `solo_sviluppo(gse)` che ferma lo script se un GSE non ha `parte == sviluppo`. Copia da
  `analysis/audit/2026-11-08-S12p-prova/aiuti.R` le funzioni `scrivi`, `ferma`, `ssh_ripeti`, `id_job`,
  `stati_sacct`, `cancella`, `attendi`, `raccogli` e la voce `mistral` di `MODELLI` (revisione
  `95a6d26c4bfb886c58daf9d3f7332c857cb27b43`).
- [ ] **Step 2: `50-scarica-geo-sviluppo.py`.** Per i 47 studi di sviluppo scarica da GEO il testo dello studio
  (`acc.cgi?acc=<GSE>&targ=self&form=text&view=brief`) e il testo dei campioni
  (`…&targ=gsm&form=text&view=brief`) in `analysis/input/geo-testi-lettore-2026-11-09/`, con manifesto. Per i 12
  studi dei 993 i testi dei campioni esistono già (`27-campi-geo-campioni.jsonl.gz`): riusali.
- [ ] **Step 3: `60-vista-v0.R`.** Formato v0 della vista, in inglese:
  1. `SERIES <GSE>`, poi `Title:`, `Summary:`, `Overall design:` dal testo dello studio;
  2. `CONSTANT COLUMNS`: una riga `nome: valore` per ogni colonna con un solo valore;
  3. `SAMPLE TABLE`: TSV con intestazione, prima colonna `gsm`, poi `title`, `source_name_ch1`, una colonna per
     ogni chiave di `characteristics_ch1`, i sei campi tecnici della spec §5.1, `description`,
     `treatment_protocol_ch1`, `growth_protocol_ch1`. Solo le colonne non costanti. Una cella assente è vuota.
     Tabulazioni e a capo dentro un valore diventano uno spazio.
  Tutti i testi passano da `.s2b_norm_testo()`. Un campione assente dal testo GEO di oggi (cancellato) esce dallo
  studio e si conta. In `60-out.txt`: per studio campioni, colonne non costanti, caratteri, token stimati
  (caratteri / 2,29), campioni cancellati. Un prompt oltre 49.152 token stimati si segnala: la vista non si
  taglia, il runner lo conterà come «oltre il contesto».
- [ ] **Step 4: `61-schema-v0.json`.** JSON Schema con le convenzioni di
  `inst/schemas/comparison_check.stage2b.v1.json` (`additionalProperties: false`, tutti i campi richiesti,
  stringa vuota al posto di `null`). Campi:
  - `series_id`;
  - `columns[]`: `column`, `role` (`factor` | `subject` | `replicate` | `uninformative`), `subject_kind`
    (`donor` | `sex` | `age` | `passage` | `batch` | `pair` | `""`);
  - `factors[]`: `name`, `type` (`perturbation` | `state` | `context` | `time` | `technical`),
    `source_columns[]` (ordinate), `levels[]` (`level`, `text_as_written`, `entity`, `dose`, `duration`),
    `baseline_level` (`""` se il fattore non ne ha), `baseline_evidence` (citazione dal testo),
    `assignment[]` (`values[]`, nello stesso ordine di `source_columns`; `level`);
  - `not_understood[]`: `what`, `why`.
  Il livello speciale è la stringa `not stated`. Nessun campo per identificativi di ontologia.
- [ ] **Step 5: `62-prompt-v0.md`** (messaggio di sistema, in inglese). Deve dire, e niente di più: il compito
  (scrivere la tabella dei fattori come un curatore, da tutta la serie); i quattro ruoli delle colonne con la
  frase della spec §5.2 sul ruolo `subject`; i cinque tipi di fattore; il livello di base con citazione, mai per
  `context`, `time`, `technical`; `assignment` come mappa dalle combinazioni distinte dei valori delle colonne
  fonte al livello, con i valori copiati carattere per carattere dalla tabella; `not stated` quando il testo non
  dice il livello, e il livello di base quando l'agente è assente; la dose è un attributo del livello e il tempo
  è un fattore quando la serie ha più tempi; nessun identificativo di ontologia; `not_understood` per i buchi.
  **Non** deve chiedere confronti, né un giudizio di qualità, né contenere esempi presi da studi di Atlas.
- [ ] **Step 6: esegui** scarico e vista, controlla `60-out.txt` (47 studi, nessuno saltato in silenzio), e
  **commit** — `S12r: prova da buttare, ingresso: testi GEO dei 47 studi di sviluppo, vista v0, schema v0, prompt v0`.

---

### Task 10: la prova da buttare — corsa, adattatore, misura

**Files:**
- Create (in `analysis/audit/2026-11-09-lettore-studio/`, `# PROVA DA BUTTARE`): `63-lancia.R`, `63-out.txt`,
  `63-uscite-sha256.txt`, `64-adatta-e-misura.R`, `64-out.txt`, `64-per-studio-lettore.csv`,
  `64-misure-lettore.csv`, `64-registro-coppie.csv`, `65-disaccordi.md`

**Interfaces:**
- Consumes: `60-viste-v0.jsonl`, `61-schema-v0.json`, `62-prompt-v0.md`, `aiuti.R`, `tf_tabella()`,
  `tf_confronti()`, le misure del Task 7, `40-per-studio-oggi.csv`.
- Produces: i numeri del lettore v0 accanto ai numeri di oggi, e la lista dei disaccordi con la causa.

- [ ] **Step 1: `63-lancia.R`.** Il bundle si costruisce con lo stadio `stage2b` di `dgx_p4_build_bundle()`
  (ingresso `record_id` + `testo`, il prompt non si taglia, i token si contano prima), con `modello =
  MODELLI$mistral`. Poi, **nella cartella del bundle**, lo script sostituisce `prompt.txt` con i byte di
  `62-prompt-v0.md` e `schema.json` con `61-schema-v0.json`, e in `generation.json` mette
  `max_model_len = 65536` e `max_tokens = 16384` (limite del prompt: 49.152 token). Cancello K4 prima
  dell'invio: SHA-256 dei due file del bundle uguali a quelli committati. Verifica il mount di `poddgx02` con un
  `srun` breve. Invia con `dgx_p4_submit(b, time = "04:00:00", env = ENV_JOB)`. Due corse uguali, una dopo
  l'altra (`corsa1`, `corsa2`). Raccoglie con `raccogli()` (variabili d'ambiente lette da `container-env.txt`).
  Lo script si lancia con `setsid nohup Rscript … < /dev/null &`; controlla `SID == PID`. Nessun poller in
  background: controlli attivi.
- [ ] **Step 2: congela le uscite.** `63-uscite-sha256.txt` con le impronte delle uscite delle due corse,
  committato **prima** di ogni misura — `S12r: prova da buttare, uscite del lettore v0 congelate`.
- [ ] **Step 3: `64-adatta-e-misura.R`.** Per ogni studio, dall'uscita della `corsa1`:
  1. esiti che chiudono lo studio senza misura, contati uno per uno: oltre il contesto (`skipped`), uscita non
     valida per lo schema, uscita troncata (`finish_reason == "length"`), una combinazione di valori della
     tabella non coperta da `assignment`, un `level` di `assignment` assente da `levels`, `baseline_level`
     assente da `levels`, `baseline_level` scritto per un fattore `context`, `time` o `technical`;
  2. adattatore: per ogni fattore unisce `assignment` alla `tabella` della vista sulle `source_columns`
     (confronto esatto delle stringhe); `not stated` → `TF_NON_SCRITTO`; tipi e tipi di soggetto tradotti nelle
     costanti del pacchetto; le colonne di ruolo `subject` diventano `soggetti`;
  3. `tf_confronti(tabella, n_min = 2L)`; il registro di tutti gli studi va in `64-registro-coppie.csv`;
  4. le tre misure contro Atlas, come in `40-misura-oggi.R`, con lo stesso universo.
  Scrive le stesse tabelle del Task 8 per il lettore, il confronto appaiato lettore meno oggi con il bootstrap
  sugli studi, il conteggio dei confronti con avviso e senza, i token veri del prompt e dell'uscita e il tempo
  per studio. Confronta le uscite delle due corse al carattere (P7). Uno studio che il lettore non chiude conta
  come partizione non identica e zero confronti nelle misure principali, e si riporta anche la misura sui soli
  studi chiusi.
- [ ] **Step 4: esegui**, poi giudica P3-P7 contro `00-previsioni.md` e scrivi l'esito in `64-out.txt`.
- [ ] **Step 5: `65-disaccordi.md`.** Leggi **ogni** disaccordo dei 47 studi (non un campione): ogni studio con
  partizione non identica, ogni confronto di Atlas non ritrovato, ogni nostro confronto giudicato errore, ogni
  studio non chiuso. Per ognuno una riga: studio, che cosa differisce, causa. Cause ammesse: `vista` (il testo
  che serviva non era nella vista o era illeggibile), `schema` (il modello non poteva scriverlo: per esempio il
  livello combinato dei curatori), `modello` (il testo c'era e lo schema lo permetteva), `curatore` (scelta o
  errore del curatore, con la prova), `strumento`. Conta a parte la classe «livello combinato» (i curatori
  scrivono due agenti come un livello solo, il lettore come due fattori). Questa lettura è audit interno.
- [ ] **Step 6: commit** — `S12r: prova da buttare, misura del lettore v0 contro Atlas e lettura di tutti i disaccordi`.

---

### Task 11: finding, riassunto, decisione del PI. STOP

**Files:**
- Create: `docs/findings/2026-11-09-S12r-prova-lettore-studio.md`
- Modify: `docs/superpowers/specs/2026-11-07-HANDOUT-PIANO-RIVISTO.md` (riquadro della sessione), `CLAUDE.md` §1,
  `.superpowers/sdd/progress.md`

- [ ] **Step 1: leggi per intero i lavori concorrenti** (GEOAgent, bioRxiv 2026.06.06.730646; il preprint
  Research Square rs-10844781; gli altri citati nel §6 della spec) e riprova l'API di Gemma. Scrivi nel finding
  che cosa fanno, su quali dati, con quale validazione, e che cosa cambia per il nostro contributo. I file
  scaricati vanno in una cartella propria.
- [ ] **Step 2: scrivi il finding** con frontmatter OKF, cancelli, previsioni con l'esito, le tabelle di oggi e
  del lettore, la tabella delle cause, le misure portate al Piano 2 (vista, lunghezza delle uscite, tempo per
  studio, studi oltre il contesto), i limiti (47 studi, più malattia che linee cellulari, un solo modello, un
  solo prompt), e la tabella «Da dove vengono i numeri del riassunto».
- [ ] **Step 3: scrivi `# In breve`** per ultimo, nella forma della skill di progetto, e misuralo:
  `python3 .claude/skills/simulomicsr-session/scripts/controlla_stile.py <file>` (soglia 80%). Le decisioni del
  PI sono al massimo tre: andare al Piano 2 o no (regola di esito del Task 1); che cosa fare dei confronti con
  «livello combinato», se sono molti; i modelli più grandi da provare nel Piano 2.
- [ ] **Step 4: aggiorna handout, `CLAUDE.md` §1 e il ledger. Commit.** Non scrivere il Piano 2 e non aprire gli
  studi di giudizio: STOP, il PI decide.

---

## Copertura della spec

| spec | dove |
|---|---|
| §2 definizione, tabella dei difetti tolti | Task 3 (tempo zero, seconda perturbazione, tecnico), Task 4 (donatori) |
| §5.1 vista | Task 9 (v0, 47 studi). I 24.393 studi, la vista compatta e i token esatti: Piano 2 |
| §5.2 tabella dei fattori | Task 9 (schema e prompt v0). Lo schema di pacchetto: Piano 2 |
| §5.3 dal modello al confronto | Task 2-4 (pacchetto). L'adattatore di pacchetto: Piano 2. Disegno appaiato: Piano 3, cambio separato |
| §5.5 linea 1 (Atlas), divisione, che cosa è chiuso, misure, termine di paragone | Task 1, 5, 6, 7, 8. Il cancello A e B: Piano 2 |
| §5.5 linee 2, 3, 4 | Piano 2. Linea 5: Piano 4 |
| §5.6 prova da buttare | Task 9, 10, 11 |
| §5.7 modelli | Task 10 (Mistral-Small 3.2). I modelli più grandi: Piano 2 |
| §5.8 fasi | Parte A |
| §6 rischi: livello di base ambiguo, uscite troncate, concorrenti | Task 10 (conteggi), Task 11 (lettura per intero) |
