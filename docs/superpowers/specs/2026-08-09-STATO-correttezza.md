# STATO del programma di correttezza — aggiornato 2026-08-10

> **2026-08-10 — il programma è passato alla SENSITIVITY** (handout
> `2026-08-10-sensitivity-confronti-spuri-HANDOUT.md`), che sostituisce il verdetto di
> coerenza con una misura di influenza. Stato dei suoi sei passi:
>
> | passo | stato | esito |
> |---|---|---|
> | **1** — riderivare gli accusati sui confronti POOLATI | ✅ **CHIUSO** | Il sospetto del revisore era fondato: **47 confronti difettosi su 85 non sono nel deliverable**, tutti scartati da `n_min`. Tasso vero **7,1%**, non 10,1%. **TNF ed enzalutamide hanno peso contaminato 0,0%**, non 13,8% e 12,1%. Mediana 12,0% → **8,8%**. Finding `docs/findings/2026-08-10-passo1-accusati-dentro-il-pooling.md` |
> | **2** — depositare le previsioni | ✅ **FATTO** | 7 previsioni falsificabili + che cosa un esito nullo **non** licenzia. `analysis/audit/2026-08-10-sensitivity/00-previsioni.md` |
> | **3** — strumento LOO in codice di pacchetto | ✅ **FATTO** | `pool_cluster_leaving_out()` + `compute_pooling_influence()` (28 test). **Accettazione sui dati veri: scarto 0 su tutte e otto le quantità**, su k=3, k=15 e **k=59** (532.109 coppie studio-gene a bracci multipli). Nessun re-pool necessario |
> | **4-5** — nullo appaiato + LOO | ✅ **FATTO** | 521 pooling, 6,3 h su 32 worker. Togliere gli accusati costa **10,1% dei geni significativi** (mediana); stanno al **79° percentile** delle rimozioni pulite appaiate (n=17, p=0,109), **6/17** oltre il 90° contro 1,7 attesi. **Due previsioni su cinque falsificate** |
> | **6** — soglia sull'influenza | ✅ **DECISO dall'utente: opzione A** | Nessuna esclusione. L'influenza diventa un risultato misurato dell'articolo. Finding `docs/findings/2026-08-10-sensitivity-confronti-spuri.md`, testo per i Methods in §7 |
>
> **Codice nuovo non committato:** `R/stage4-loo-influence.R`, `compute_pooling_weight_shares()`
> + `.compute_study_gene_weights()` estratti in `R/stage4-pooling-effectiveness.R` (i 38 test
> preesistenti passano invariati). Suite `stage4`: **1038 PASS / 0 FAIL / 1 SKIP**.

---

# STATO precedente — 2026-08-09 sera

Branch `review-scientific-consistency-2026-06-10` · master invariato · **nessun commit,
nessun re-cluster, nessun re-pool**. Riferimento: `2026-08-10-correttezza-passo-passo-HANDOUT.md`.

---

## FATTO

| passo | esito | dove |
|---|---|---|
| **PASSO 0** — riproducibilità | `VLLM_BATCH_INVARIANT=1` → 100% su ogni campo. Ma il verdetto di coerenza **cambia nel 15,5% dei casi** rispetto a prima della flag | handout §3.4 |
| **PASSO 1a** — l'ID sbagliato del modello arriva nel deliverable? | **NO: 0 su 214.** Ogni ID esce da un dizionario. Il modo di fallire di §3.5 non tocca il deliverable | `docs/findings/2026-08-09-passo1-id-modello-nel-deliverable.md` |
| **PASSO 1a bis** — canale residuo | **7 su 214 (3,3%)** hanno l'entità **nominata** da Mistral (nome → dizionario → ID). Su Zika la composizione dipende dal canale: 7 membri su 17 | idem §4.2 |
| **PASSO 1b** — il resolver corregge o propaga? | Misurato. **Trovato un difetto peggiore**: `resolution_source` è **stale su 129.400 cluster (40,1%)** — il recupero-nome riscrive l'ID e non la provenienza | idem §4.1, §9 |
| **Censimento identità** — il nome che l'ID promette compare nei membri? | 351 candidati e 214 poolate. Sulle 214: **170 nome per esteso, 38 solo sigla, 6 nessun nome**. Copertura record_id 5.786/5.786 | `analysis/audit/2026-08-09-passo1/` |
| **Lettura dei 44 filtrati** | **40 identità corrette su 44.** Le 4 difettose (IL3/larve di nematode, IL-10/assenza, Influenza A che contiene Influenza B, CD28/anticorpo) erano **tutte già documentate**; 3 su 4 già marcate `incoerente` | `materiale-44.txt` |
| **Fix 1** — `resolution_source` non mente più | `R/stage3-anchor-levels.R`: dichiara `RECOVERY_<fonte>`. 4 test, suite a 0 fallimenti | — |
| **Fix 2** — IFN-β non più spezzato | `.CA_DEFRAG_ACCEPT` + `"ifnb" = "HGNC:5434"`. Metro identico a `tgfb`/`il17`: alias univoco, guardie spente, stesso verso e controllo, studi disgiunti 5+4 | `R/stage3-defrag-alias.R` |

⚠️ **Un'asserzione capovolta, da sapere:** `ifnb` era esplicitamente nella lista dei token
che «devono tornare `STR:`». Non era un giudizio dato su `ifnb`: era una delle ~918 fusioni
abbandonate **in blocco** con la regola generale, mai valutata singolarmente. Ora lo è.

⚠️ **Un test resta SKIPPED** (`test-stage3-defrag-alias.R:356`, «ogni entità autorizzata è
ancora univoca»): richiede i dizionari veri, che nei test non ci sono. L'univocità di `ifnb`
è stata verificata a mano sui dizionari veri, non dal test.

---

## DA FARE

| passo | stato | nota |
|---|---|---|
| **PASSO 2** — coerenza ID/testo nel resolver | **RIDIMENSIONATO, decisione aperta** | L'handout lo chiamava «il cambiamento più invasivo». Sui dati: **zero** entità ne dipendono per via diretta, ≤55 righe su 214 per via indiretta. Potrebbe non valere la pena |
| **PASSO 3** — filtro repliche biologiche | **non iniziato** | Il rilevatore v4 esiste ed è validato (13 casi). Va portato in codice di pacchetto con TDD e misurato. Previsione depositata: escono le 6 meta-analisi con GSE173902, *S. epidermidis* (k=3) esce dal deliverable |
| **PASSO 4** — che cosa cambia il verdetto di coerenza | **non iniziato** | 25, 58 o 97 incoerenti a seconda del giudice. **È la domanda scientifica più importante del programma** |
| **PASSO 5** — decisioni sulla de-frammentazione | **non iniziato** | Da riaprire solo dopo i primi quattro |
| **Materializzazione** | **nessuna** | Entrambi i fix agiscono solo al prossimo re-cluster (~9 h) + re-pool (~31 h). Serve una decisione esplicita dell'utente |
| **Guardia sui conflitti di ruolo** | scritta, testata, **non committata** | `R/stage4-role-conflict.R` + 52 test |
| **16 gruppi su 44 con identità `STR:`** | documentato, non chiuso | Nessun ID ontologico. Non è un errore di identità: è potenza persa e leggibilità. Solo IFN-β è stato chiuso |

---

## Il conto delle previsioni depositate (PASSO 1)

Quattro falsificate su otto, due non decidibili, due centrate — tutte le falsificate nella
stessa direzione: avevo **sottostimato** quanto il deliverable ri-risolva l'identità dal testo.

## Gli strumenti che sono nati ciechi, oggi

Quattro, tutti trovati e corretti prima dell'uso: un `grep` che non vedeva i valori
costruiti in due passi; un `%in%` O(n²); un metro che contava `RIPK1` come ID numerico
(sbagliato due volte, 48,6% e 41,2%, il vero è 19,0%); e un port di strumento che su v15
avrebbe agganciato zero membri (fermato da un caso di accettazione).

**Due revisori ostili hanno trovato 7 difetti nella prima stesura del finding. Tutti veri,
tutti rimisurati. La conclusione ha retto; la prova con cui la sostenevo no.**
