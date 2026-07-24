# PROMPT prossima sessione (copia-incolla)

---

ANCHOR DERIVATO-DAL-CONTRASTO Stadio 3 — chiudere il residuo e RI-CENSIRE. La coerenza è il GATE,
non i conteggi.

LEGGI PRIMA, INTERI: `docs/superpowers/specs/2026-07-25-stage3-contrast-anchor-NEXT-SESSION-HANDOUT.md`
e `analysis/audit/2026-07-24-anchor-coherence-sim/FASE1-RESULT.md`.

CONTESTO SENZA SCONTI. Per mesi questo progetto ha ottimizzato PROXY (nomi dei cluster, conteggi, I² del
pooled) e dichiarato "publication-grade / DELIVERABLE FINALE" mentre 157/184 (85%) del deliverable erano
MINESTRONI e la vetrina Layer B era 0/9. Nella sessione del 2026-07-24 lo stesso errore è stato rifatto
DUE VOLTE: (a) ho scritto "DESIGN VALIDATO / soluzione" avendo misurato solo il k recuperato (287
poolabili) senza verificare la coerenza — che poi è risultata 72%, non 100%; (b) ho lasciato passare come
entità di clustering roba tipo `STR:t`, `STR:d`, `STR:dox` (una lettera!), slop che non doveva esistere.
Non rifarlo.

STATO (misurato, non asserito): il design "anchor derivato-dal-contrasto" (entità = il DELTA
trattato↔controllo, canonicalizzata col resolver, + tipo-controllo) funziona: SARS ricomposto pulito a
k=34; gate v6 hardened = **196 poolabili, coerenza 81% su TUTTI i cluster (159/196), ~89% sul
deliverable**, censiti UNO PER UNO (14 batch), non a campione. Restano **15 falliti veri** (84 studi-slot
su 965, ~9%), catalogati in `v6-census-failures.txt`.

DECISIONI GIÀ PRESE (non ri-litigare): opzione B (re-anchor a monte); ~100 meta-analisi vere > 184
minestroni; soglia k≥3; degeneri (factor_levels identici) e nuisance-only si SCARTANO, loggando la lista;
combo = entità a sé; verifica su TUTTI i cluster mai su campione; pipeline e gate DETERMINISTICI e
pubblicabili (nessun Claude dentro la pipeline né nella validazione: l'evaluator LLM è Mistral
self-hosted).

PRIMA COSA DA FARE: chiedimi la decisione ancora APERTA — se un cluster possa fondere DIREZIONI OPPOSTE
dello stesso bersaglio (agonista+antagonista: DHT+enzalutamide; glucosio deprivazione+aggiunta; TNF
inibitore+stimolo). Tua raccomandazione attesa: NO, separarli per verso. NON decidere da solo.

POI IL LAVORO: implementare la strategia di recupero già quantificata (handout §4) — (A) SPLIT
(materiale del controllo tessuto/plasma; baseline sano vs longitudinale; combo come entità a sé ed
estendere il rilevatore combo a "/" e "and": così sono sfuggite bleomicina/TMZ/vemurafenib), (B)
RIPULITURA (droppa i MEMBRI con controllo incongruo, tieni il cluster), (C) SCARTO (entità inventate da
nomi sbagliati, aggregati vaghi tipo "environmental", trattamento ignoto tipo "on-vs-pre treatment").
Poi **RI-CENSIRE LA COERENZA SU TUTTI I CLUSTER**. Target onesto ≥90-95%; ogni residuo catalogato e
spiegato. Se non ci arrivi, scrivilo coi numeri.

REGOLE, DURE:
1. Il gate è la COERENZA (stesso contrasto = meta-analisi difendibile), MAI il numero di cluster
   poolabili. "N poolabili" ≠ "N coerenti". La consistenza (k, I²) si riporta come forza, non è la barriera.
2. VIETATO scrivere "validato / risolto / soluzione / paper-grade / finale" senza prova di coerenza
   PER-CLUSTER su TUTTI i cluster. È già stato mentito 3 volte + 2 in una sola sessione.
3. Verifica su TUTTI i cluster. MAI su un campione.
4. Zero slop nel gate: entità di 1-3 caratteri, parole generiche (none/high/positive/mutant/chemotherapy),
   veicoli (DMSO), induttori (doxiciclina), classi-ombrello (MeSH:Neoplasms, "steroid") NON sono entità.
   Se una passa, il gate è rotto: fermati e riparalo.
5. La pipeline pubblicata è deterministica: la coerenza nasce PER COSTRUZIONE dell'anchor, non da un
   giudice LLM a runtime. Niente Claude nella pipeline né nella validazione pubblicata.
6. NESSUN re-cluster (~8h) o re-pool (~50h) finché il censimento su tutti non passa e non ti do il GO.
7. Fail onesto coi numeri: se resta il 19% incoerente, scrivi 19%.
8. Non fidarti dei subagent/LLM senza verificare contro i dati veri.

Branch `review-scientific-consistency-2026-06-10`, master invariato, no push salvo richiesta. Voglio un
clustering irreprensibile — ogni cluster che misura davvero la stessa cosa — con la prova, su tutti.
